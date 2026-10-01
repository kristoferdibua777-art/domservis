# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis::Dispatch::AdminPoliciesController', authenticated_as: :admin, type: :request do
  # Zammad's 'Admin' role alone does not carry 'dom_servis.admin'; see the
  # same setup in spec/requests/dom_servis/dispatch/jobs_controller_spec.rb.
  let(:admin) do
    create(:admin).tap do |user|
      admin_role = Role.find_by(name: 'Dom-Servis Admin')
      user.roles << admin_role if admin_role && !user.roles.exists?(admin_role.id)
    end
  end

  def create_job
    DomServis::DispatchJob.create!(
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      status:       'pool',
      source:       'manual',
    )
  end

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
  end

  it 'counts the jobs whose backing ticket was not updated', :aggregate_failures do
    create_job
    create_job.record_ticket_sync_failure!(StandardError.new('ticket store down'))

    get '/api/v1/dom_servis/dispatch/admin_policy', as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['stats']).to include('total' => 2, 'ticket_sync_failed' => 1)
  end
end
