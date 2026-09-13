# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::AttachmentsController < DomServis::Dispatch::BaseController
  def index
    render json: serialized_attachments(job), status: :ok
  end

  def show
    store = attachment

    data =
      if params[:view].to_s == 'preview'
        store.content_preview(silence: true)
      else
        store.content
      end

    send_data(
      data,
      filename:    store.filename,
      type:        attachment_content_type(store),
      disposition: params[:disposition].presence || 'attachment'
    )
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    ensure_action_allowed!('add_attachment')

    file = params.require(:File)
    kind = normalized_attachment_kind(params[:kind])

    ensure_attachment_upload_allowed!(job, kind)

    store = Store.create!(
      object:        DomServis::DispatchJob.to_s,
      o_id:          job.id,
      created_by_id: current_user.id,
      filename:      file.original_filename,
      preferences:   attachment_preferences(file, kind),
      data:          file.read
    )

    create_event!(job, 'attachment_added', attachment_id: store.id, kind: attachment_kind(store), filename: store.filename)

    render json: attachment_payload(job, store), status: :created
  end

  def destroy
    store = attachment

    ensure_action_allowed!('remove_attachment')
    ensure_attachment_delete_allowed!(job, store)

    create_event!(job, 'attachment_removed', attachment_id: store.id, kind: attachment_kind(store), filename: store.filename)
    Store.remove_item(store.id)

    render json: { success: true }, status: :ok
  end

  private

  def job
    @job ||= begin
      record = dispatch_job_scope.find(params[:job_id])
      authorize record, :show?
      record
    end
  end

  def attachment
    @attachment ||= job.attachments.find(params[:id])
  end

  def serialized_attachments(record)
    record.attachments.reorder(created_at: :asc).map do |store|
      attachment_payload(record, store)
    end
  end

  def attachment_payload(record, store)
    {
      id:               store.id,
      filename:         store.filename,
      size:             store.size,
      kind:             attachment_kind(store),
      kind_label:       attachment_kind_label(attachment_kind(store)),
      content_type:     attachment_content_type(store),
      created_at:       store.created_at,
      created_by_id:    store.created_by_id,
      created_by_name:  attachment_actor_name(store.created_by),
      can_delete:       attachment_deletable?(record, store),
      download_url:     "#{Rails.configuration.api_path}/dom_servis/dispatch/jobs/#{record.id}/attachments/#{store.id}",
      preview_url:      previewable_attachment?(store) ? "#{Rails.configuration.api_path}/dom_servis/dispatch/jobs/#{record.id}/attachments/#{store.id}?view=preview&disposition=inline" : nil,
    }
  end

  def attachment_preferences(file, kind)
    content_type = file.content_type.presence
    content_type ||= MIME::Types.type_for(file.original_filename).first&.content_type
    content_type ||= 'application/octet-stream'

    {
      'Content-Type'      => content_type,
      'Mime-Type'         => content_type,
      'dom_servis_kind'   => kind,
      'original_filename' => file.original_filename,
    }
  end

  def attachment_kind(store)
    store.preferences['dom_servis_kind'].presence || 'other'
  end

  def attachment_content_type(store)
    store.preferences['Content-Type'].presence || store.preferences['Mime-Type'].presence || 'application/octet-stream'
  end

  def previewable_attachment?(store)
    mime_type = attachment_content_type(store)
    Store.resizable_mime?(mime_type)
  end

  def normalized_attachment_kind(raw_kind)
    kind = raw_kind.to_s.presence || 'other'
    raise Exceptions::UnprocessableEntity, 'Invalid dispatch attachment kind.' if !DomServis::DispatchJob::ATTACHMENT_KINDS.include?(kind)

    kind
  end

  def ensure_attachment_upload_allowed!(record, kind)
    return true if dispatcher_access?

    if current_user.permissions?('dom_servis.master') && record.assignee_id == current_user.id
      return true if %w[completion_act diagnostic_photo other].include?(kind)
    end

    raise Exceptions::Forbidden, "Attachment kind '#{kind}' is not allowed for the current role."
  end

  def ensure_attachment_delete_allowed!(record, store)
    return true if dispatcher_access?

    raise Exceptions::Forbidden, "Attachment '#{store.id}' cannot be removed by the current role."
  end

  def attachment_deletable?(record, _store)
    return true if dispatcher_access?

    false
  end

  def attachment_kind_label(kind)
    {
      'intake_attachment' => 'Входные материалы',
      'route_info'        => 'Схема / доступ',
      'completion_act'    => 'Акт выполненных работ',
      'diagnostic_photo'  => 'Фото / диагностика',
      'other'             => 'Прочее',
    }[kind] || kind
  end

  def attachment_actor_name(user)
    return nil if !user

    full_name = [user.firstname, user.lastname].compact.join(' ').strip
    return full_name if full_name.present?

    user.login.presence || user.email
  end

  def dispatcher_access?
    current_user.permissions?('dom_servis.admin') || current_user.permissions?('dom_servis.dispatcher')
  end

  def ensure_action_allowed!(action_key)
    return true if DomServis::DispatchPolicy.action_allowed?(current_user, action_key)

    raise Exceptions::Forbidden, "Dispatch action '#{action_key}' is not allowed for the current role."
  end

  def create_event!(record, event_type, meta = {})
    DomServis::DispatchEvent.create!(
      dispatch_job: record,
      actor_user:   current_user,
      event_type:   event_type,
      meta:         meta,
    )
  end
end
