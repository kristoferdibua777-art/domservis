# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# GigaChat settings of the pasted text reading, kept in the setting
# dom_servis_ai_intake_config (its name ends in _config, so the system report
# leaves it out). An admin enters them in Dispatch Admin. The
# authorization key is stored on the server only: the admin screen learns
# whether a key is saved, never the key itself.
class DomServis::Intake::AISettings
  SETTING_NAME = 'dom_servis_ai_intake_config'.freeze

  # GIGACHAT_API_PERS - a private person, GIGACHAT_API_B2B - a business paying
  # for packages or by use, GIGACHAT_API_CORP - a business with a contract.
  SCOPES = %w[GIGACHAT_API_PERS GIGACHAT_API_B2B GIGACHAT_API_CORP].freeze
  MODELS = %w[GigaChat-2 GigaChat-2-Pro GigaChat-2-Max].freeze

  DEFAULTS = {
    'enabled'  => false,
    'auth_key' => '',
    'scope'    => 'GIGACHAT_API_PERS',
    'model'    => 'GigaChat-2-Pro',
  }.freeze

  def self.current
    new(Setting.get(SETTING_NAME))
  end

  # params: enabled, scope, model, auth_key (a new key; blank keeps the saved
  # one) and clear_auth_key.
  def self.update!(params)
    settings = current
    values = settings.values.merge(
      'enabled' => params.key?('enabled') ? boolean(params['enabled']) : settings.enabled?,
      'scope'   => params['scope'].presence || settings.scope,
      'model'   => params['model'].to_s.strip.presence || settings.model,
    )

    new_key = params['auth_key'].to_s.gsub(%r{\s+}, '')
    values['auth_key'] = new_key if new_key.present?
    values['auth_key'] = '' if boolean(params['clear_auth_key'])
    values['enabled'] = false if values['auth_key'].blank?

    validate!(values, new_key)
    Setting.set(SETTING_NAME, values)
    new(values)
  end

  def self.boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def self.validate!(values, new_key)
    raise Exceptions::UnprocessableEntity, 'Неизвестный тип доступа GigaChat.' if SCOPES.exclude?(values['scope'])
    raise Exceptions::UnprocessableEntity, 'Неверное название модели GigaChat.' if !values['model'].match?(%r{\A[\w.:-]{1,64}\z})
    return if new_key.blank? || new_key.match?(%r{\A[A-Za-z0-9+/=_-]{16,1024}\z})

    raise Exceptions::UnprocessableEntity, 'Ключ авторизации выглядит неверно: скопируйте его целиком из личного кабинета GigaChat.'
  end
  private_class_method :boolean, :validate!

  def initialize(values)
    stored = values.respond_to?(:to_h) ? values.to_h.stringify_keys : {}
    @values = DEFAULTS.merge(stored.slice(*DEFAULTS.keys))
  end

  attr_reader :values

  def enabled?
    values['enabled'] == true
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

  def usable?
    enabled? && auth_key.present?
  end

  def admin_attributes
    {
      enabled:      enabled?,
      scope:        scope,
      model:        model,
      auth_key_set: auth_key.present?,
      scopes:       SCOPES,
      models:       MODELS,
    }
  end
end
