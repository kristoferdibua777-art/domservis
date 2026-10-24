# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The admin downloads the table of jobs with their master reports for a
# period (see DomServis::Dispatch::ReportsWorkbook).
class DomServis::Dispatch::ReportExportsController < DomServis::Dispatch::BaseController
  def show
    workbook = DomServis::Dispatch::ReportsWorkbook.new(
      from:       date_param(:from),
      to:         date_param(:to),
      date_field: params[:date_field],
      master_id:  params[:master_id],
    )

    send_data(
      workbook.content,
      filename:    workbook.filename,
      type:        ExcelSheet::CONTENT_TYPE,
      disposition: 'attachment'
    )
  end

  private

  def date_param(key)
    Date.iso8601(params.require(key).to_s)
  rescue Date::Error
    raise Exceptions::UnprocessableEntity, 'Даты периода нужны в формате ГГГГ-ММ-ДД.'
  end
end
