# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis report export', type: :request do
  let(:admin) do
    create(:admin).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Admin')
    end
  end
  let(:dispatcher_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end
  let(:url) { '/api/v1/dom_servis/dispatch/report_export' }

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
  end

  it 'gives the admin the table of the period', :aggregate_failures, authenticated_as: :admin do
    get url, params: { from: '2026-10-01', to: '2026-10-31', date_field: 'completed' }

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq(ExcelSheet::CONTENT_TYPE)
    expect(response.headers['Content-Disposition']).to include('dom-servis-reports-2026-10-01-2026-10-31.xlsx')
  end

  it 'refuses a wrong date', authenticated_as: :admin do
    get url, params: { from: '01.10.2026', to: '2026-10-31' }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'is only for the admin', authenticated_as: :dispatcher_user do
    get url, params: { from: '2026-10-01', to: '2026-10-31' }

    expect(response).to have_http_status(:forbidden)
  end
end
