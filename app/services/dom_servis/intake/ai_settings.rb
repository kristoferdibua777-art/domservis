# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# AI settings of the pasted text reading, kept in the setting
# dom_servis_ai_intake_config (its name ends in _config, so the system report
# leaves it out). An admin enters them in Dispatch Admin. The key is stored
# on the server only: the admin screen learns whether a key is saved, never
# the key itself.
#
# Two ways to reach GigaChat (decision 2026-10-14):
# - gigachat: the GigaChat API of Sber with the authorization key of the
#   personal account - the free Freemium package of a new user is here;
# - chat_completions: Cloud.ru Foundation Models with an API key, where new
#   clients pay for GigaChat since 2026-09-01, or another service with the
#   OpenAI chat completions API.
class DomServis::Intake::AISettings
  SETTING_NAME = 'dom_servis_ai_intake_config'.freeze
  PROVIDERS = %w[gigachat chat_completions].freeze

  # GIGACHAT_API_PERS - a private person, GIGACHAT_API_B2B - a business paying
  # for packages or by use, GIGACHAT_API_CORP - a business with a contract.
  SCOPES = %w[GIGACHAT_API_PERS GIGACHAT_API_B2B GIGACHAT_API_CORP].freeze
  MODELS = %w[GigaChat-2 GigaChat-2-Pro GigaChat-2-Max].freeze

  DEFAULTS = {
    'enabled'  => false,
    'provider' => 'gigachat',
    'auth_key' => '',
    'scope'    => 'GIGACHAT_API_PERS',
    'model'    => 'GigaChat-2-Pro',
    'base_url' => DomServis::Intake::ChatCompletionsClient::DEFAULT_URL,
  }.freeze

  def self.current
    new(Setting.get(SETTING_NAME))
  end

  # params: enabled, provider, scope, model, base_url, auth_key (a new key;
  # blank keeps the saved one) and clear_auth_key.
  def self.update!(params)
    values = merged_values(current, params)
    new_key = params['auth_key'].to_s.gsub(%r{\s+}, '')
    apply_key!(values, new_key, boolean(params['clear_auth_key']))

    validate!(values, new_key)
    Setting.set(SETTING_NAME, values)
    new(values)
  end

  def self.merged_values(settings, params)
    settings.values.merge(
      'enabled'  => params.key?('enabled') ? boolean(params['enabled']) : settings.enabled?,
      'provider' => params['provider'].presence || settings.provider,
      'scope'    => params['scope'].presence || settings.scope,
      'model'    => params['model'].to_s.strip.presence || settings.model,
      'base_url' => params['base_url'].to_s.strip.chomp('/').presence || settings.base_url,
    )
  end

  # A new key replaces the saved one, a blank one keeps it; without a key
  # the reading is switched off.
  def self.apply_key!(values, new_key, clear)
    values['auth_key'] = new_key if new_key.present?
    values['auth_key'] = '' if clear
    values['enabled'] = false if values['auth_key'].blank?
  end

  def self.boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def self.validate!(values, new_key)
    raise Exceptions::UnprocessableEntity, 'Неизвестный способ подключения ИИ.' if PROVIDERS.exclude?(values['provider'])
    raise Exceptions::UnprocessableEntity, 'Неизвестный тип доступа GigaChat.' if SCOPES.exclude?(values['scope'])
    raise Exceptions::UnprocessableEntity, 'Неверное название модели.' if !values['model'].match?(%r{\A[\w.:/-]{1,128}\z})
    raise Exceptions::UnprocessableEntity, 'Адрес API должен начинаться с https://.' if !https_url?(values['base_url'])
    return if new_key.blank? || new_key.match?(%r{\A[\x21-\x7E]{16,2048}\z})

    raise Exceptions::UnprocessableEntity, 'Ключ выглядит неверно: скопируйте его целиком из личного кабинета.'
  end

  def self.https_url?(value)
    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTPS) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
  private_class_method :merged_values, :apply_key!, :boolean, :validate!, :https_url?

  def initialize(values)
    stored = values.respond_to?(:to_h) ? values.to_h.stringify_keys : {}
    @values = DEFAULTS.merge(stored.slice(*DEFAULTS.keys))
  end

  attr_reader :values

  def enabled?
    values['enabled'] == true
  end

  def provider
    values['provider'].to_s
  end

  def auth_key
    values['auth_key'].to_s
  end

  def scope
    values['scope'].to_s
  end

  def model
    values['model'].to_s
  end

  def base_url
    values['base_url'].to_s
  end

  def usable?
    enabled? && auth_key.present?
  end

  def client
    return DomServis::Intake::ChatCompletionsClient.new(api_key: auth_key, base_url:, model:) if provider == 'chat_completions'

    DomServis::Intake::GigachatClient.new(auth_key:, scope:, model:)
  end

  def admin_attributes
    {
      enabled:      enabled?,
      provider:     provider,
      scope:        scope,
      model:        model,
      base_url:     base_url,
      auth_key_set: auth_key.present?,
      providers:    PROVIDERS,
      scopes:       SCOPES,
      models:       MODELS,
    }
  end
end
