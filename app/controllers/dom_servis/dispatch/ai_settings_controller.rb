# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# GigaChat settings of the pasted text reading in Dispatch Admin. The
# authorization key can be replaced or removed here but is never sent back.
class DomServis::Dispatch::AiSettingsController < DomServis::Dispatch::BaseController
  def show
    render json: DomServis::Intake::AiSettings.current.admin_attributes, status: :ok
  end

  def update
    settings = DomServis::Intake::AiSettings.update!(params.permit(:enabled, :auth_key, :clear_auth_key, :scope, :model).to_h)

    render json: settings.admin_attributes, status: :ok
  end

  # Gets a token and the model list, so the admin sees right away whether the
  # key, the access type and the certificate work.
  def check
    settings = DomServis::Intake::AiSettings.current
    raise Exceptions::UnprocessableEntity, 'Сначала сохраните ключ авторизации GigaChat.' if settings.auth_key.blank?

    models = DomServis::Intake::GigachatClient.new(auth_key: settings.auth_key, scope: settings.scope, model: settings.model).models

    render json: { ok: true, models:, model_available: models.include?(settings.model) }, status: :ok
  rescue DomServis::Intake::GigachatClient::Error => e
    render json: { ok: false, error: e.message }, status: :ok
  end
end
