# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::YandexClient do
  subject(:client) { described_class.new(api_key:, folder_id: 'b1gtestfolder01', model: 'yandexgpt/latest') }

  let(:api_key)  { 'AQVN-yandex-api-key-0123456789' }
  let(:chat_url) { "#{described_class::URL}/chat/completions" }
  let(:json)     { { 'Content-Type' => 'application/json' } }
  let(:function) { { name: 'fill_dispatch_job', parameters: { type: 'object', properties: { client_phone: { type: 'string' } } } } }

  def chat
    client.chat(messages: [{ role: 'system', content: 'Вызови функцию.' }, { role: 'user', content: 'Котёл не греет' }], functions: [function], function_call: { name: 'fill_dispatch_job' })
  end

  def answer(content)
    { status: 200, body: { choices: [{ message: { role: 'assistant', content: } }] }.to_json, headers: json }
  end

  it 'asks for the fields as a JSON schema of the folder model without keeping the data', :aggregate_failures do
    request = stub_request(:post, chat_url)
      .with(
        headers: { 'Authorization' => "Bearer #{api_key}", 'OpenAI-Project' => 'b1gtestfolder01', 'X-Folder-Id' => 'b1gtestfolder01', 'X-Data-Logging-Enabled' => 'false' },
        body:    hash_including(
          'model'           => 'gpt://b1gtestfolder01/yandexgpt/latest',
          'response_format' => { 'type' => 'json_schema', 'json_schema' => { 'name' => 'fill_dispatch_job', 'schema' => function[:parameters].deep_stringify_keys } },
        ),
      )
      .to_return(answer('{"client_phone":"89001234567"}'))

    expect(chat).to eq('role' => 'assistant', 'content' => '{"client_phone":"89001234567"}')
    expect(request).to have_been_requested.once
  end

  it 'asks for a plain JSON object when the schema is not accepted', :aggregate_failures do
    stub_request(:post, chat_url).to_return({ status: 400, body: '{}' }, answer('{}'))

    expect(chat).to eq('role' => 'assistant', 'content' => '{}')
    expect(a_request(:post, chat_url).with(body: hash_including('response_format' => { 'type' => 'json_object' }))).to have_been_made.once
  end

  it 'does not repeat a request with a rejected key', :aggregate_failures do
    stub_request(:post, chat_url).to_return(status: 401, body: '{}')

    expect { chat }.to raise_error(DomServis::Intake::AIError, 'Ключ YandexGPT не принят: проверьте ключ и тип доступа.')
    expect(a_request(:post, chat_url)).to have_been_made.once
  end

  it 'takes the folder from a full model address' do
    expect(described_class.new(api_key:, folder_id: '', model: 'gpt://b1gother0folder/yandexgpt-lite/latest')).to have_attributes(folder_id: 'b1gother0folder', model: 'gpt://b1gother0folder/yandexgpt-lite/latest')
  end

  it 'has no model list to ask for' do
    expect(client.models).to eq([])
  end
end
