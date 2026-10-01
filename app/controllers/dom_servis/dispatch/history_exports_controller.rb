# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Excel export of the job history and its removal afterwards (decision
# 2026-09-28): an admin exports, downloads the file and is then asked to
# allow removing exactly the downloaded events.
class DomServis::Dispatch::HistoryExportsController < DomServis::Dispatch::BaseController
  def index
    render json: DomServis::DispatchHistoryExport.status, status: :ok
  end

  def create
    last_event_id = DomServis::DispatchEvent.maximum(:id)
    raise Exceptions::UnprocessableEntity, 'Истории для выгрузки нет.' if !last_event_id

    export = DomServis::DispatchHistoryExport.create!(
      created_by:    current_user,
      last_event_id: last_event_id,
      event_count:   DomServis::DispatchEvent.where(id: ..last_event_id).count,
    )

    render json: export.status, status: :created
  end

  # The row count of the file is stored, so a purge can check that it
  # removes exactly the downloaded events.
  def download
    export = find_export
    raise Exceptions::UnprocessableEntity, 'Эта выгрузка уже удалена.' if export.purged?

    workbook = DomServis::Dispatch::HistoryWorkbook.new(export:, locale: current_user.locale)
    content  = workbook.content
    export.update!(downloaded_at: Time.zone.now, event_count: workbook.row_count)

    send_data(
      content,
      filename:    workbook.filename,
      type:        ExcelSheet::CONTENT_TYPE,
      disposition: 'attachment'
    )
  end

  def purge
    export = find_export

    export.with_lock do
      raise Exceptions::UnprocessableEntity, 'Эта выгрузка уже удалена.' if export.purged?
      raise Exceptions::UnprocessableEntity, 'Сначала скачайте файл выгрузки.' if export.downloaded_at.blank?
      raise Exceptions::UnprocessableEntity, 'С момента скачивания история изменилась. Выгрузите её ещё раз.' if export.events.count != export.event_count

      purged_count = export.events.delete_all
      export.update!(purged_at: Time.zone.now, purged_by: current_user, purged_count: purged_count)
    end

    render json: export.status, status: :ok
  end

  private

  def find_export
    DomServis::DispatchHistoryExport.find(params[:id])
  end
end