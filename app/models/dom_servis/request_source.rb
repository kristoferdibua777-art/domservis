# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::RequestSource < ApplicationModel
  include CanSelector
  include HasDefaultModelUserRelations
  include CanSearch

  self.table_name = 'dom_servis_request_sources'

  TRANSPORT_KINDS = %w[zammad_form webhook ai].freeze
  STATUSES = %w[active paused].freeze
  LEGACY_FORM_PARTNER_KEY = 'legacy-zammad-form'.freeze

  belongs_to :organization, optional: true
  has_many :dispatch_jobs, class_name: 'DomServis::DispatchJob', foreign_key: :request_source_id, inverse_of: :request_source

  attr_accessor :rotate_embed_token

  validates :name, presence: true
  validates :partner_key, presence: true, uniqueness: { case_sensitive: false }
  validates :embed_token, presence: true, uniqueness: true
  validates :transport_kind, presence: true, inclusion: { in: TRANSPORT_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :organization, presence: true, if: :active?
  validates :privacy_policy_url, length: { maximum: 2000 }, allow_blank: true
  validate :privacy_policy_url_must_be_http_url

  before_validation :normalize_partner_key
  before_validation :normalize_transport_kind
  before_validation :normalize_status
  before_validation :normalize_allowed_domains
  before_validation :normalize_privacy_policy_url
  before_validation :ensure_embed_token
  before_validation :stamp_token_rotation

  def active?
    status == 'active'
  end

  def paused?
    !active?
  end

  def legacy_form?
    partner_key == LEGACY_FORM_PARTNER_KEY
  end

  def display_name
    organization_name = organization&.name.presence
    organization_name.present? ? "#{name} (#{organization_name})" : name
  end

  def allowed_domains=(value)
    super(normalize_domains(value))
  end

  def embed_url
    query = {
      request_source_token: embed_token,
      v:                   embed_cache_bust,
    }
    query[:privacy_policy_url] = privacy_policy_url if privacy_policy_url.present?

    "#{base_origin}/assets/form/dom-servis-partner-embed.html?#{query.to_query}"
  end

  def embed_snippet
    <<~HTML.strip
      <iframe
        data-dom-servis-partner-embed="true"
        src="#{ERB::Util.html_escape(embed_url)}"
        title="#{ERB::Util.html_escape(display_name)}"
        loading="lazy"
        scrolling="no"
        style="display: block; width: 100%; height: 640px; min-height: 640px; border: 0; overflow: hidden;"
      ></iframe>
      #{partner_embed_resize_listener_script}
    HTML
  end

  def embed_js_snippet
    <<~HTML.strip
      <div id="dom-servis-partner-form"></div>
      <script>
        (function() {
          var container = document.getElementById('dom-servis-partner-form');
          if (!container) {
            return;
          }

          var iframe = document.createElement('iframe');
          iframe.setAttribute('data-dom-servis-partner-embed', 'true');
          iframe.src = #{embed_url.to_json};
          iframe.title = #{display_name.to_json};
          iframe.loading = 'lazy';
          iframe.scrolling = 'no';
          iframe.style.display = 'block';
          iframe.style.width = '100%';
          iframe.style.height = '640px';
          iframe.style.minHeight = '640px';
          iframe.style.border = '0';
          iframe.style.overflow = 'hidden';
          container.appendChild(iframe);

          var origin;
          try {
            origin = new URL(iframe.src, window.location.href).origin;
          } catch (error) {
            origin = #{base_origin.to_json};
          }

          var fallbackHeight = 640;
          var minHeight = 480;

          function applyHeight(height) {
            var nextHeight = Math.max(minHeight, Math.ceil(Number(height) || 0));
            iframe.style.height = nextHeight + 'px';
          }

          applyHeight(fallbackHeight);

          iframe.addEventListener('load', function() {
            applyHeight(fallbackHeight);
          });

          window.addEventListener('message', function(event) {
            if (event.origin !== origin) {
              return;
            }

            var data = event.data || {};
            if (data.type !== 'dom-servis:resize') {
              return;
            }

            applyHeight(data.height);
          });
        })();
      </script>
    HTML
  end

  def embed_cache_bust
    [Version.get.presence, updated_at&.utc&.to_i].compact.join('-')
  end

  def ensure_usable_for_form!(request:)
    raise Exceptions::Forbidden, 'Dom-Servis request source is paused.' if paused?
    raise Exceptions::Forbidden, 'Dom-Servis request source is not configured for Zammad forms.' if transport_kind != 'zammad_form'
    raise Exceptions::UnprocessableEntity, 'Dom-Servis request source requires a partner organization.' if organization_id.blank?
    raise Exceptions::Forbidden, 'Dom-Servis request source is not allowed from this domain.' if !allowed_domain?(request)

    true
  end

  def allowed_domain?(request)
    return true if allowed_domains.blank?

    host = request_origin_host(request)
    return true if host.blank?

    allowed_domains.any? do |domain|
      normalized = domain.to_s.strip.downcase
      next false if normalized.blank?

      host == normalized || host.end_with?(".#{normalized}")
    end
  end

  def attributes_with_association_ids
    super.merge(
      display_name:           display_name,
      organization_name:      Organization.find_by(id: organization_id)&.name,
      embed_url:              embed_url,
      embed_snippet:          embed_snippet,
      embed_js_snippet:       embed_js_snippet,
      privacy_policy_url:     privacy_policy_url,
      allowed_domains_display: allowed_domains.join("\n"),
      request_source_type:    transport_kind,
    ).compact
  end

  class << self
    def legacy_form_source
      source = find_by(partner_key: LEGACY_FORM_PARTNER_KEY)
      return source if source.present?

      intake_enabled = Setting.get('dom_servis_form_intake_enabled') == true
      organization_id = Setting.get('dom_servis_form_organization_id').presence
      return nil if !intake_enabled && organization_id.blank?

      source = find_or_initialize_by(partner_key: LEGACY_FORM_PARTNER_KEY)
      source.name = 'Legacy Zammad Form' if source.name.blank?
      source.embed_token = 'legacy-zammad-form-token' if source.embed_token.blank?
      source.organization_id = organization_id if source.organization_id.blank? && organization_id.present?
      source.transport_kind = 'zammad_form'
      source.status = intake_enabled && organization_id.present? ? 'active' : 'paused'
      source.allowed_domains = source.allowed_domains.presence || []
      source.settings = source.settings.presence || {}
      source.save! if source.changed?
      source
    end

    def resolve_form_source(request_source_token:, request:)
      if request_source_token.present?
        source = find_by(embed_token: request_source_token)
        raise Exceptions::Forbidden, 'Unknown Dom-Servis request source.' if source.blank?

        source.ensure_usable_for_form!(request: request)
        return source
      end

      source = legacy_form_source
      return nil if source.blank? || source.paused?

      source.ensure_usable_for_form!(request: request)
      source
    end
  end

  private

  def normalize_partner_key
    self.partner_key = normalize_slug(partner_key, fallback: name)
  end

  def normalize_transport_kind
    self.transport_kind = transport_kind.to_s.strip.presence || 'zammad_form'
  end

  def normalize_status
    self.status = status.to_s.strip.presence || 'paused'
  end

  def normalize_allowed_domains
    self.allowed_domains = normalize_domains(allowed_domains)
  end

  def normalize_privacy_policy_url
    self.privacy_policy_url = privacy_policy_url.to_s.strip.presence
  end

  def normalize_domains(value)
    Array(value)
      .flat_map { |entry| entry.to_s.split(/[\n,]/) }
      .filter_map do |entry|
        normalized = entry.to_s.strip.downcase
        normalized = normalized.sub(%r{\Ahttps?://}, '')
        normalized = normalized.sub(%r{/.*\z}, '')
        normalized.presence
      end
      .uniq
  end

  def ensure_embed_token
    return if embed_token.present? && !rotate_embed_token

    self.embed_token = generate_token
  end

  def stamp_token_rotation
    self.token_rotated_at = Time.zone.now if new_record? || rotate_embed_token
  end

  def generate_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      return token if self.class.where(embed_token: token).none?
    end
  end

  def normalize_slug(value, fallback:)
    base = value.to_s.strip.downcase
    base = fallback.to_s.strip.downcase.parameterize if base.blank? && fallback.present?
    base = 'partner' if base.blank?

    slug = base.parameterize
    return slug if slug.present? && self.class.where.not(id: id).exists?(partner_key: slug) == false

    loop do
      suffix = SecureRandom.hex(3)
      candidate = "#{slug.presence || 'partner'}-#{suffix}"
      return candidate if self.class.where.not(id: id).exists?(partner_key: candidate) == false
    end
  end

  def base_origin
    http_type = Setting.get('http_type')
    fqdn = Setting.get('fqdn')

    "#{http_type}://#{fqdn}"
  end

  def partner_embed_resize_listener_script
    <<~HTML.strip
      <script>
        (function() {
          var iframe = null;
          if (document.currentScript && document.currentScript.previousElementSibling && document.currentScript.previousElementSibling.matches('iframe[data-dom-servis-partner-embed="true"]')) {
            iframe = document.currentScript.previousElementSibling;
          } else {
            iframe = document.querySelector('iframe[data-dom-servis-partner-embed="true"]');
          }

          if (!iframe) {
            return;
          }

          var origin;
          try {
            origin = new URL(iframe.src, window.location.href).origin;
          } catch (error) {
            origin = #{base_origin.to_json};
          }

          var fallbackHeight = 640;
          var minHeight = 480;

          function applyHeight(height) {
            var nextHeight = Math.max(minHeight, Math.ceil(Number(height) || 0));
            iframe.style.height = nextHeight + 'px';
          }

          applyHeight(fallbackHeight);

          iframe.addEventListener('load', function() {
            applyHeight(fallbackHeight);
          });

          window.addEventListener('message', function(event) {
            if (event.origin !== origin) {
              return;
            }

            var data = event.data || {};
            if (data.type !== 'dom-servis:resize') {
              return;
            }

            applyHeight(data.height);
          });
        })();
      </script>
    HTML
  end

  def request_origin_host(request)
    origin = request_source_origin_param(request).presence || request&.origin.presence || request&.referer.presence
    return nil if origin.blank?

    parsed = URI.parse(origin)
    host = parsed.host.presence || origin.to_s.sub(%r{\Ahttps?://}, '').split(/[\/?#]/, 2).first
    host.to_s.downcase.presence
  rescue URI::InvalidURIError
    nil
  end

  def request_source_origin_param(request)
    request&.params&.[](:request_source_origin) || request&.params&.[]('request_source_origin')
  end

  def privacy_policy_url_must_be_http_url
    return if privacy_policy_url.blank?

    parsed = URI.parse(privacy_policy_url)
    return if %w[http https].include?(parsed.scheme) && parsed.host.present?

    errors.add(:privacy_policy_url, 'must be a valid http or https URL')
  rescue URI::InvalidURIError
    errors.add(:privacy_policy_url, 'must be a valid http or https URL')
  end
end
