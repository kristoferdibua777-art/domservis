# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::GigachatClient do
  subject(:client) { described_class.new(auth_key: auth_key, scope: 'GIGACHAT_API_PERS', model: 'GigaChat-2-Pro') }

  let(:auth_key)       { 'a2V5OnNlY3JldGtleTEyMzQ=' }
  let(:token_url)      { described_class::TOKEN_URL }
  let(:chat_url)       { "#{described_class::API_URL}/chat/completions" }
  let(:expires_at)     { 30.minutes.from_now.to_i * 1000 }
  let(:token_response) { { status: 200, body: { access_token: 'token-1', expires_at: expires_at }.to_json, headers: { 'Content-Type' => 'application/json' } } }
  let(:answer)         { { 'role' => 'assistant', 'function_call' => { 'name' => 'fill_dispatch_job', 'arguments' => { 'client_phone' => '89001234567' } } } }
  let(:chat_response)  { { status: 200, body: { choices: [{ message: answer }] }.to_json, headers: { 'Content-Type' => 'application/json' } } }

  before { Rails.cache.clear }

  def chat
    client.chat(messages: [{ role: 'user', content: 'Котёл не греет' }], functions: [{ name: 'fill_dispatch_job' }], function_call: { name: 'fill_dispatch_job' })
  end

  it 'gets a token with the authorization key and asks the model', :aggregate_failures do
    token_request = stub_request(:post, token_url)
      .with(body: { scope: 'GIGACHAT_API_PERS' }, headers: { 'Authorization' => "Basic #{auth_key}" })
      .to_return(token_response)
    chat_request = stub_request(:post, chat_url)
      .with(headers: { 'Authorization' => 'Bearer token-1' }, body: hash_including('model' => 'GigaChat-2-Pro', 'function_call' => { 'name' => 'fill_dispatch_job' }))
      .to_return(chat_response)

    expect(chat).to eq(answer)
    expect(token_request).to have_been_requested.once
    expect(chat_request).to have_been_requested.once
    expect(WebMock).to have_requested(:post, token_url).with { |request| request.headers['Rquid'].present? }
  end

  it 'keeps the token between requests' do
    stub_request(:post, token_url).to_return(token_response)
    stub_request(:post, chat_url).to_return(chat_response)

    2.times { chat }

    expect(WebMock).to have_requested(:post, token_url).once
  end

  it 'gets a new token when the old one is no longer accepted' do
    stub_request(:post, token_url).to_return(token_response)
    stub_request(:post, chat_url).to_return({ status: 401, body: '{}' }, chat_response)

    expect(chat).to eq(answer)
  end

  it 'explains a rejected key' do
    stub_request(:post, token_url).to_return(status: 401, body: '{}')

    expect { chat }.to raise_error(DomServis::Intake::AIError, 'Ключ GigaChat не принят: проверьте ключ и тип доступа.')
  end

  it 'explains a missing certificate' do
    stub_request(:post, token_url).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed (self-signed certificate in certificate chain)'))

    expect { chat }.to raise_error(DomServis::Intake::AIError, %r{Russian Trusted Root CA})
  end

  it 'explains used up tokens' do
    stub_request(:post, token_url).to_return(token_response)
    stub_request(:post, chat_url).to_return(status: 402, body: '{}')

    expect { chat }.to raise_error(DomServis::Intake::AIError, 'В GigaChat закончились оплаченные токены.')
  end

  it 'lists the models' do
    stub_request(:post, token_url).to_return(token_response)
    stub_request(:get, "#{described_class::API_URL}/models").to_return(status: 200, body: { data: [{ id: 'GigaChat-2' }, { id: 'GigaChat-2-Pro' }] }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(client.models).to eq(%w[GigaChat-2 GigaChat-2-Pro])
  end
end
