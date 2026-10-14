# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::ChatCompletionsClient do
  subject(:client) { described_class.new(api_key: api_key, base_url: "#{described_class::DEFAULT_URL}/", model: 'ai-sage/GigaChat3-10B-A1.8B') }

  let(:api_key)   { 'cloud-ru-api-key-0123456789' }
  let(:chat_url)  { "#{described_class::DEFAULT_URL}/chat/completions" }
  let(:json)      { { 'Content-Type' => 'application/json' } }
  let(:tool_call) { { 'id' => 'call-1', 'type' => 'function', 'function' => { 'name' => 'fill_dispatch_job', 'arguments' => '{"client_phone":"89001234567"}' } } }

  def chat
    client.chat(messages: [{ role: 'user', content: 'Котёл не греет' }], functions: [{ name: 'fill_dispatch_job', parameters: { type: 'object' } }], function_call: { name: 'fill_dispatch_job' })
  end

  it 'asks for the function as a tool and hands the call on like GigaChat', :aggregate_failures do
    request = stub_request(:post, chat_url)
      .with(
        headers: { 'Authorization' => "Bearer #{api_key}" },
        body:    hash_including(
          'model'       => 'ai-sage/GigaChat3-10B-A1.8B',
          'tools'       => [{ 'type' => 'function', 'function' => { 'name' => 'fill_dispatch_job', 'parameters' => { 'type' => 'object' } } }],
          'tool_choice' => { 'type' => 'function', 'function' => { 'name' => 'fill_dispatch_job' } },
        ),
      )
      .to_return(status: 200, body: { choices: [{ message: { role: 'assistant', content: nil, tool_calls: [tool_call] } }] }.to_json, headers: json)

    expect(chat).to eq('role' => 'assistant', 'function_call' => tool_call['function'])
    expect(request).to have_been_requested.once
  end

  it 'returns a plain answer as it is' do
    stub_request(:post, chat_url).to_return(status: 200, body: { choices: [{ message: { role: 'assistant', content: '{"client_phone":"89001234567"}' } }] }.to_json, headers: json)

    expect(chat).to eq('role' => 'assistant', 'content' => '{"client_phone":"89001234567"}')
  end

  it 'lists the models' do
    stub_request(:get, "#{described_class::DEFAULT_URL}/models").to_return(status: 200, body: { data: [{ id: 'ai-sage/GigaChat3-10B-A1.8B' }, { id: 'Qwen/Qwen3-235B' }] }.to_json, headers: json)

    expect(client.models).to eq(%w[ai-sage/GigaChat3-10B-A1.8B Qwen/Qwen3-235B])
  end

  it 'explains a rejected key and a rejected request', :aggregate_failures do
    stub_request(:post, chat_url).to_return({ status: 401, body: '{}' }, { status: 400, body: '{}' })

    expect { chat }.to raise_error(DomServis::Intake::AIError, 'Ключ Cloud.ru не принят: проверьте ключ и тип доступа.')
    expect { chat }.to raise_error(DomServis::Intake::AIError, 'Запрос к Cloud.ru не принят (код 400).')
  end

  it 'needs a key' do
    expect { described_class.new(api_key: '', base_url: described_class::DEFAULT_URL, model: 'x').models }.to raise_error(DomServis::Intake::AIError, 'Не задан API-ключ Cloud.ru.')
  end
end
