# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Form', type: :request do

  describe 'request handling' do

    it 'does get config call' do
      post '/api/v1/form_config', params: {}, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(json_response).to be_a(Hash)
      expect(json_response['error']).to eq('Not authorized')
    end

    it 'does get config call with form_ticket_create' do
      Setting.set('form_ticket_create', true)
      post '/api/v1/form_config', params: {}, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(json_response).to be_a(Hash)
      expect(json_response['error']).to eq('Not authorized')

    end

    it 'does get config call & do submit' do
      Setting.set('form_ticket_create', true)
      fingerprint = SecureRandom.hex(40)
      post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
      expect(json_response['enabled']).to be(true)
      expect(json_response['endpoint']).to eq('http://zammad.example.com/api/v1/form_submit')
      expect(json_response['token']).to be_truthy
      token = json_response['token']

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: 'invalid' }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(json_response).to be_a(Hash)
      expect(json_response['error']).to eq('Authorization failed')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_truthy
      expect(json_response['errors']['name']).to eq('required')
      expect(json_response['errors']['email']).to eq('required')
      expect(json_response['errors']['title']).to eq('required')
      expect(json_response['errors']['body']).to eq('required')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, email: 'some' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_truthy
      expect(json_response['errors']['name']).to eq('required')
      expect(json_response['errors']['email']).to eq('invalid')
      expect(json_response['errors']['title']).to eq('required')
      expect(json_response['errors']['body']).to eq('required')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test', body: 'hello' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_falsey
      expect(json_response['ticket']).to be_truthy
      expect(json_response['ticket']['id']).to be_truthy
      expect(json_response['ticket']['number']).to be_truthy

      travel 5.hours

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test', body: 'hello' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_falsey
      expect(json_response['ticket']).to be_truthy
      expect(json_response['ticket']['id']).to be_truthy
      expect(json_response['ticket']['number']).to be_truthy

      travel 20.hours

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test', body: 'hello' }, as: :json
      expect(response).to have_http_status(:unauthorized)

    end

    it 'does get config call & do submit - second test' do
      Setting.set('form_ticket_create', true)
      fingerprint = SecureRandom.hex(40)
      post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
      expect(json_response['enabled']).to be(true)
      expect(json_response['endpoint']).to eq('http://zammad.example.com/api/v1/form_submit')
      expect(json_response['token']).to be_truthy
      token = json_response['token']

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: 'invalid' }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(json_response).to be_a(Hash)
      expect(json_response['error']).to eq('Authorization failed')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_truthy
      expect(json_response['errors']['name']).to eq('required')
      expect(json_response['errors']['email']).to eq('required')
      expect(json_response['errors']['title']).to eq('required')
      expect(json_response['errors']['body']).to eq('required')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, email: 'some' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_truthy
      expect(json_response['errors']['name']).to eq('required')
      expect(json_response['errors']['email']).to eq('invalid')
      expect(json_response['errors']['title']).to eq('required')
      expect(json_response['errors']['body']).to eq('required')

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'somebody@somedomainthatisinvalid.com', title: 'test', body: 'hello' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)

      expect(json_response['errors']).to be_truthy
      expect(json_response['errors']['email']).to eq('invalid')

    end

    it 'does limits', :rack_attack do
      Setting.set('form_ticket_create_by_ip_per_hour', 2)
      Setting.set('form_ticket_create', true)
      fingerprint = SecureRandom.hex(40)

      post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_truthy
      token = json_response['token']

      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test', body: 'hello' }, as: :json
      expect(response).to have_http_status(:ok)

      3.times do |count|
        post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: "test#{count}", body: 'hello' }, as: :json
      end
      expect(response).to have_http_status(:too_many_requests)

      @headers = { 'ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json', 'REMOTE_ADDR' => '1.2.3.5' }
      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test-2', body: 'hello' }, as: :json
      expect(response).to have_http_status(:ok)

      3.times do |count|
        post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: "test-2-#{count}", body: 'hello' }, as: :json
      end
      expect(response).to have_http_status(:too_many_requests)

      @headers = { 'ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json', 'REMOTE_ADDR' => '::1' }
      post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test-3', body: 'hello' }, as: :json

      3.times do |count|
        post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: "test-3-#{count}", body: 'hello' }, as: :json
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'does customer_ticket_create false disables form' do
      Setting.set('form_ticket_create', false)
      Setting.set('customer_ticket_create', true)

      fingerprint = SecureRandom.hex(40)

      post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json

      token = json_response['token']
      params = {
        fingerprint: fingerprint,
        token:       token,
        name:        'Bob Smith',
        email:       'discard@zammad.com',
        title:       'test',
        body:        'hello'
      }

      post '/api/v1/form_submit', params: params, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    describe 'form_allowed_params Setting', db_strategy: :reset do
      let(:fingerprint) { SecureRandom.hex(40) }
      let(:token)       { json_response['token'] }
      let(:ticket)      { Ticket.find json_response.dig('ticket', 'id') }
      let(:custom_attr) { create(:object_manager_attribute_text) }

      before do
        custom_attr
        ObjectManager::Attribute.migration_execute

        Setting.set('form_allowed_params', form_allowed_params)
        Setting.set('form_ticket_create', true)
        post '/api/v1/form_config', params: { fingerprint: }, as: :json

        post '/api/v1/form_submit', params: {
          fingerprint:,
          token:,
          name:  'Bob Smith',
          email: 'discard@zammad.com',
          title: 'test-last',
          body:  'hello',
          custom_attr.name => 'some note'
        }, as: :json
      end

      context 'when blank' do
        let(:form_allowed_params) { [] }

        it 'rejects additional parameters' do
          expect(ticket).to have_attributes(custom_attr.name => be_blank)
        end
      end

      context 'when present' do
        let(:form_allowed_params) { [custom_attr.name] }

        it 'allows additional parameters' do
          expect(ticket).to have_attributes(custom_attr.name => 'some note')
        end
      end
    end

    context 'when ApplicationHandleInfo context' do
      let(:fingerprint) { SecureRandom.hex(40) }
      let(:token)       { json_response['token'] }

      before do
        allow(ApplicationHandleInfo).to receive('context=')
        Setting.set('form_ticket_create', true)
        post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json
      end

      it 'gets switched to "form"' do
        post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test-last', body: 'hello' }, as: :json
        expect(ApplicationHandleInfo).to have_received('context=').with('form').at_least(1)
      end

      it 'reverts back to default' do
        post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test-last', body: 'hello' }, as: :json
        expect(ApplicationHandleInfo.context).not_to eq 'form'
      end

      context 'when form_allowed_params is not blank' do
        before do
          Setting.set('form_allowed_params', %w[note])
        end

        it 'does not switch context to "form"' do
          post '/api/v1/form_submit', params: { fingerprint: fingerprint, token: token, name: 'Bob Smith', email: 'discard@zammad.com', title: 'test-last', body: 'hello' }, as: :json
          expect(ApplicationHandleInfo).not_to have_received('context=').with('form')
        end
      end
    end

    describe 'Dom-Servis intake bridge', db_strategy: :reset do
      let(:fingerprint)  { SecureRandom.hex(40) }
      let(:token)        { json_response['token'] }
      let(:group)        { create(:group, name: '000 Intake Bridge Group') }
      let(:partner_org)  { create(:organization, name: 'Dom-Servis Partner Org') }
      let(:forged_org)   { create(:organization, name: 'Forged Org') }

      before do
        Setting.set('form_ticket_create', true)
        Setting.set('form_ticket_create_group_id', group.id)
        Setting.set('form_allowed_params', %w[
          organization_id
          dom_servis_service_type
          dom_servis_address
          dom_servis_client_name
          dom_servis_client_phone
          dom_servis_visit_day
          dom_servis_visit_date
          dom_servis_visit_time
          dom_servis_dispatch_priority
          dom_servis_description
          dom_servis_comment
          dom_servis_work_tags
        ])
        Setting.set('dom_servis_form_intake_enabled', true)
        Setting.set('dom_servis_form_organization_id', partner_org.id)

        post '/api/v1/form_config', params: { fingerprint: fingerprint }, as: :json
      end

      it 'creates a dispatch job from the form ticket and binds the configured partner organization' do
        params = {
          fingerprint: fingerprint,
          token:       token,
          name:        'Bob Smith',
          email:       'discard@zammad.com',
          title:       'Need help with boiler',
          body:        'The boiler is leaking and needs inspection.',
          organization_id: forged_org.id,
          dom_servis_service_type: 'Boiler repair',
          dom_servis_address:      'Lenina 10',
          dom_servis_client_name:   'Bob Smith',
          dom_servis_client_phone:  '+79001234567',
          dom_servis_visit_day:     'mon',
          dom_servis_visit_date:    '2026-03-23',
          dom_servis_visit_time:    '10:00-12:00',
          dom_servis_dispatch_priority: 'high',
          dom_servis_description:   'Need replacement and inspection.',
          dom_servis_comment:       'Call before arrival',
          dom_servis_work_tags:     'boiler,urgent',
        }

        post '/api/v1/form_submit', params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to be_a(Hash)
        expect(json_response['errors']).to be_falsey
        expect(json_response['ticket']).to be_truthy

        ticket = Ticket.find(json_response['ticket']['id'])
        job = DomServis::DispatchJob.find_by(ticket_id: ticket.id)

        expect(job).to be_persisted
        expect(job.organization_id).to eq(partner_org.id)
        expect(job.request_source_id).to be_present
        expect(job.source).to eq('form')
        expect(job.source_reference).to eq(ticket.number)
        expect(job.intake_channel_key).to eq('zammad_form')
        expect(job.intake_payload).to be_a(Hash)
        expect(job.intake_payload['ticket_number']).to eq(ticket.number)
        expect(job.service_type).to eq('Boiler repair')
        expect(job.address).to eq('Lenina 10')
        expect(job.work_tags).to eq(%w[boiler urgent])
        expect(ticket.preferences.dig('dom_servis_intake', 'partner_org_id')).to eq(partner_org.id)
        expect(ticket.preferences.dig('dom_servis_intake', 'request_source_key')).to eq('legacy-zammad-form')
        expect(ticket.dom_servis_dispatch_source).to eq('form')
        expect(ticket.dom_servis_dispatch_priority).to eq('high')
        expect(ticket.dom_servis_service_type).to eq('Boiler repair')
        expect(ticket.preferences.dig('dom_servis_intake', 'source')).to eq('form')
      end

      it 'infers weekday from visit_date when the partner form does not send visit_day' do
        params = {
          fingerprint: fingerprint,
          token:       token,
          name:        'Bob Smith',
          email:       'discard@zammad.com',
          title:       'Need help with boiler',
          body:        'The boiler is leaking and needs inspection.',
          dom_servis_service_type: 'Boiler repair',
          dom_servis_address:      'Lenina 10',
          dom_servis_client_name:   'Bob Smith',
          dom_servis_client_phone:  '+79001234567',
          dom_servis_visit_date:    '2026-03-23',
          dom_servis_visit_time:    '10:00',
          dom_servis_dispatch_priority: 'high',
          dom_servis_description:   'Need replacement and inspection.',
          dom_servis_comment:       'Call before arrival',
          dom_servis_work_tags:     'boiler,urgent',
        }

        post '/api/v1/form_submit', params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['errors']).to be_falsey

        ticket = Ticket.find(json_response['ticket']['id'])
        job = DomServis::DispatchJob.find_by(ticket_id: ticket.id)

        expect(job).to be_persisted
        expect(job.visit_date).to eq('2026-03-23')
        expect(job.visit_day).to eq('mon')
        expect(ticket.dom_servis_visit_date).to eq('2026-03-23')
      end

      it 'creates a dispatch job when the partner form does not expose an email field' do
        params = {
          fingerprint: fingerprint,
          token:       token,
          name:        'Bob Smith',
          title:       'Need help with boiler',
          body:        'The boiler is leaking and needs inspection.',
          dom_servis_service_type: 'Boiler repair',
          dom_servis_address:      'Lenina 10',
          dom_servis_client_name:   'Bob Smith',
          dom_servis_client_phone:  '+79001234567',
          dom_servis_visit_date:    '2026-03-23',
          dom_servis_visit_time:    '10:00',
          dom_servis_dispatch_priority: 'high',
          dom_servis_description:   'Need replacement and inspection.',
          dom_servis_comment:       'Call before arrival',
          dom_servis_work_tags:     'boiler,urgent',
        }

        post '/api/v1/form_submit', params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['errors']).to be_falsey
        expect(json_response['ticket']).to be_truthy

        ticket = Ticket.find(json_response['ticket']['id'])
        job = DomServis::DispatchJob.find_by(ticket_id: ticket.id)

        expect(job).to be_persisted
        expect(job.organization_id).to eq(partner_org.id)
        expect(ticket.customer.email).to be_present
        expect(ticket.preferences.dig('dom_servis_intake', 'partner_org_id')).to eq(partner_org.id)
      end
    end

    context 'when two partners use the same transport', db_strategy: :reset do
      let(:fingerprint_a)  { SecureRandom.hex(40) }
      let(:fingerprint_b)  { SecureRandom.hex(40) }
      let(:request_source_a) do
        DomServis::RequestSource.create!(
          name:           'Partner A Form',
          partner_key:    'partner-a-form',
          organization:   partner_org,
          transport_kind: 'zammad_form',
          status:         'active',
          allowed_domains: ['partner-a.example.com'],
          privacy_policy_url: 'https://partner-a.example.com/privacy',
        )
      end
      let(:request_source_b) do
        DomServis::RequestSource.create!(
          name:           'Partner B Form',
          partner_key:    'partner-b-form',
          organization:   forged_org,
          transport_kind: 'zammad_form',
          status:         'active',
          allowed_domains: ['partner-b.example.com'],
        )
      end

      before do
        Setting.set('form_ticket_create', true)
        Setting.set('form_ticket_create_group_id', group.id)
        Setting.set('form_allowed_params', %w[
          organization_id
          dom_servis_service_type
          dom_servis_address
          dom_servis_client_name
          dom_servis_client_phone
          dom_servis_visit_day
          dom_servis_visit_date
          dom_servis_visit_time
          dom_servis_dispatch_priority
          dom_servis_description
          dom_servis_comment
          dom_servis_work_tags
        ])

        post '/api/v1/form_config', params: { fingerprint: fingerprint_a, request_source_token: request_source_a.embed_token }, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response.dig('request_source', 'partner_key')).to eq('partner-a-form')
        expect(json_response.dig('request_source', 'privacy_policy_url')).to eq('https://partner-a.example.com/privacy')
      end

      it 'creates distinct dispatch jobs for different partner sources' do
        params_a = {
          fingerprint: fingerprint_a,
          request_source_token: request_source_a.embed_token,
          token: token,
          name: 'Bob Smith',
          email: 'discard@zammad.com',
          title: 'Need help with boiler',
          body: 'The boiler is leaking and needs inspection.',
          dom_servis_service_type: 'Boiler repair',
          dom_servis_address:      'Lenina 10',
          dom_servis_client_name:  'Bob Smith',
          dom_servis_client_phone: '+79001234567',
          dom_servis_visit_day:    'mon',
          dom_servis_visit_date:    '2026-03-23',
          dom_servis_visit_time:    '10:00-12:00',
          dom_servis_dispatch_priority: 'high',
          dom_servis_description:   'Need replacement and inspection.',
          dom_servis_comment:       'Call before arrival',
          dom_servis_work_tags:     'boiler,urgent',
        }

        post '/api/v1/form_submit', params: params_a, as: :json
        first_ticket = Ticket.find(json_response['ticket']['id'])
        first_job = DomServis::DispatchJob.find_by(ticket_id: first_ticket.id)

        post '/api/v1/form_config', params: { fingerprint: fingerprint_b, request_source_token: request_source_b.embed_token }, as: :json
        token_b = json_response['token']

        params_b = params_a.merge(
          fingerprint: fingerprint_b,
          request_source_token: request_source_b.embed_token,
          token: token_b,
          dom_servis_address: 'Karla Marksa 5',
          dom_servis_service_type: 'Electrical repair',
        )
        post '/api/v1/form_submit', params: params_b, as: :json
        second_ticket = Ticket.find(json_response['ticket']['id'])
        second_job = DomServis::DispatchJob.find_by(ticket_id: second_ticket.id)

        expect(first_job.request_source_id).to eq(request_source_a.id)
        expect(first_job.organization_id).to eq(partner_org.id)
        expect(first_job.intake_channel_key).to eq('zammad_form')
        expect(second_job.request_source_id).to eq(request_source_b.id)
        expect(second_job.organization_id).to eq(forged_org.id)
        expect(second_job.intake_channel_key).to eq('zammad_form')
        expect(first_job.id).not_to eq(second_job.id)
      end

      it 'accepts the parent origin explicitly from an iframe embed' do
        partner_origin = 'https://partner-a.example.com/page'

        post '/api/v1/form_config', params: {
          fingerprint: fingerprint_a,
          request_source_token: request_source_a.embed_token,
          request_source_origin: partner_origin,
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response.dig('request_source', 'partner_key')).to eq('partner-a-form')

        post '/api/v1/form_submit', params: {
          fingerprint: fingerprint_a,
          request_source_token: request_source_a.embed_token,
          request_source_origin: partner_origin,
          token: json_response['token'],
          name: 'Bob Smith',
          email: 'discard@zammad.com',
          title: 'Need help with boiler',
          body: 'The boiler is leaking and needs inspection.',
          dom_servis_service_type: 'Boiler repair',
          dom_servis_address: 'Lenina 10',
          dom_servis_client_name: 'Bob Smith',
          dom_servis_client_phone: '+79001234567',
          dom_servis_visit_day: 'mon',
          dom_servis_visit_date: '2026-03-23',
          dom_servis_visit_time: '10:00-12:00',
          dom_servis_dispatch_priority: 'high',
          dom_servis_description: 'Need replacement and inspection.',
          dom_servis_comment: 'Call before arrival',
          dom_servis_work_tags: 'boiler,urgent',
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['errors']).to be_falsey
        expect(json_response['ticket']).to be_truthy

        ticket = Ticket.find(json_response['ticket']['id'])
        job = DomServis::DispatchJob.find_by(ticket_id: ticket.id)

        expect(job).to be_persisted
        expect(job.request_source_id).to eq(request_source_a.id)
        expect(job.organization_id).to eq(partner_org.id)
        expect(job.intake_payload['request_source_origin']).to eq(partner_origin)
        expect(ticket.preferences.dig('dom_servis_intake', 'request_source_origin')).to eq(partner_origin)
      end

      it 'accepts the compact partner callback payload used by the iframe form' do
        post '/api/v1/form_submit', params: {
          fingerprint: fingerprint_a,
          request_source_token: request_source_a.embed_token,
          request_source_origin: 'https://partner-a.example.com',
          token: token,
          name: 'Иван',
          title: 'Заявка на обратный звонок',
          body: 'Клиент оставил заявку на обратный звонок через сайт партнёра. Имя клиента: Иван. Телефон клиента: +79998884455. Нужно уточнить услугу, адрес, дату и время визита.',
          dom_servis_client_name: 'Иван',
          dom_servis_client_phone: '+79998884455',
          dom_servis_service_type: 'Уточнить у клиента',
          dom_servis_address: 'Уточнить у клиента',
          dom_servis_visit_date: '2026-03-23',
          dom_servis_visit_day: 'mon',
          dom_servis_visit_time: 'Уточнить у клиента',
          dom_servis_dispatch_priority: 'medium',
          dom_servis_description: 'Клиент оставил заявку на обратный звонок через сайт партнёра. Имя клиента: Иван. Телефон клиента: +79998884455. Нужно уточнить услугу, адрес, дату и время визита.',
          dom_servis_comment: 'Детали услуги, адрес и время нужно уточнить у клиента.',
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['errors']).to be_falsey

        ticket = Ticket.find(json_response['ticket']['id'])
        job = DomServis::DispatchJob.find_by(ticket_id: ticket.id)

        expect(job).to be_persisted
        expect(job.request_source_id).to eq(request_source_a.id)
        expect(job.organization_id).to eq(partner_org.id)
        expect(job.service_type).to eq('Уточнить у клиента')
        expect(job.address).to eq('Уточнить у клиента')
        expect(job.client_phone).to eq('+79998884455')
        expect(job.priority).to eq('medium')
        expect(job.comment).to eq('Детали услуги, адрес и время нужно уточнить у клиента.')
        expect(ticket.preferences.dig('dom_servis_intake', 'request_source_origin')).to eq('https://partner-a.example.com')
      end
    end
  end
end
