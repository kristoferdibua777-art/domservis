# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# AI settings of the pasted text reading in Dispatch Admin. The key can be
# replaced or removed here but is never sent back.
class DomServis::Dispatch::AISettingsController < DomServis::Dispatch::BaseController
  CHECK_TEXT = 'Котёл Baxi не греет, ошибка E03. Калининград, ул. Ленина 5, кв. 12. Ирина, 8 900 000-00-00. Можно завтра после 18.'.freeze

  def show
    render json: DomServis::Intake::AISettings.current.admin_attributes, status: :ok
  end

  def update
    settings = DomServis::Intake::AISettings.update!(params.permit(:enabled, :provider, :auth_key, :clear_auth_key, :scope, :model, :base_url).to_h)

    render json: settings.admin_attributes, status: :ok
  end

  # Lists the models and reads a sample message, so the admin sees right
  # away whether the key, the access type, the certificate and the model work.
  def check
    settings = DomServis::Intake::AISettings.current
    raise Exceptions::UnprocessableEntity, 'Сначала сохраните ключ.' if settings.auth_key.blank?

    models = settings.client.models
    sample = DomServis::Intake::AIParser.new(text: CHECK_TEXT, today: Time.zone.today, settings:).call

    render json: { ok: true, models:, model_available: models.include?(settings.model), sample: sample.slice(:client_phone, :address, :service_type) }, status: :ok
  rescue DomServis::Intake::AIError => e
    render json: { ok: false, error: e.message }, status: :ok
  end
end
