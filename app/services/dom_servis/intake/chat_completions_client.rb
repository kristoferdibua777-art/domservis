# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Talks to an AI service with the OpenAI chat completions API. Since
# 2026-09-01 new GigaChat clients pay on Cloud.ru Foundation Models, which
# has this API (its model ids look like "ai-sage/GigaChat3-10B-A1.8B"); other
# services with the same API work as well. The API key goes into the
# Authorization header as it is.
#
# The answer comes as a tool call; it is handed on in the shape of a GigaChat
# function call, so DomServis::Intake::AIParser reads both services alike.
class DomServis::Intake::ChatCompletionsClient
  include DomServis::Intake::AIHttp

  DEFAULT_URL = 'https://foundation-models.api.cloud.ru/v1'.freeze

  def initialize(api_key:, base_url:, model:)
    @api_key = api_key.to_s
    @base_url = base_url.to_s.chomp('/')
    @model = model.to_s
  end

  attr_reader :api_key, :base_url, :model

  def service_name
    host = URI.parse(base_url).host.to_s
    host.end_with?('cloud.ru') ? 'Cloud.ru' : host
  rescue URI::InvalidURIError
    base_url
  end

  def chat(messages:, functions: nil, function_call: nil)
    body = { model:, messages:, temperature: 0.1, max_tokens: 1000 }
    body[:tools] = functions.map { |function| { type: 'function', function: } } if functions
    body[:tool_choice] = { type: 'function', function: { name: function_call[:name] } } if function_call

    message = message_from(request(:post, 'chat/completions', body, read_timeout: 30))
    tool_call = Array(message['tool_calls']).first
    return message if !tool_call.is_a?(Hash)

    { 'role' => message['role'], 'function_call' => tool_call['function'] }
  end

  def models
    model_ids(request(:get, 'models', {}, read_timeout: 15))
  end

  private

  def request(method, path, body, read_timeout:)
    result = send_request(method, path, body, read_timeout:)
    raise DomServis::Intake::AIError, failure_message(result, key: %w[401 403].include?(result.code.to_s)) if !result.success?

    result
  end

  def send_request(method, path, body, read_timeout:)
    raise DomServis::Intake::AIError, "Не задан API-ключ #{service_name}." if api_key.blank?

    UserAgent.public_send(method, "#{base_url}/#{path}", body, json_options(api_key, read_timeout:, headers: request_headers))
  end

  def request_headers
    {}
  end
end
