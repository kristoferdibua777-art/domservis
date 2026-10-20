# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Talks to YandexGPT of Yandex AI Studio through its OpenAI-compatible API
# with the API key of a service account (decision 2026-10-16: Yandex instead
# of GigaChat; its certificate is a usual one, the Russian Trusted Root CA is
# not needed).
#
# The model is the URI "gpt://<folder id>/yandexgpt/latest", built from the
# folder id and the short model name the admin enters. The OpenAI-compatible
# API of Yandex takes response_format rather than tools, so the answer fields
# go as a JSON schema; when the schema is not accepted, the client asks for a
# plain JSON object and lists the fields in the prompt. Requests are sent with
# x-data-logging-enabled: false, so Yandex does not keep the client messages.
class DomServis::Intake::YandexClient < DomServis::Intake::ChatCompletionsClient
  URL = 'https://llm.api.cloud.yandex.net/v1'.freeze
  MODELS = %w[yandexgpt/latest yandexgpt-lite/latest yandexgpt/rc].freeze
  MODEL_URI = %r{\Agpt://(?<folder>[^/]+)/}

  def initialize(api_key:, folder_id:, model:)
    @folder_id = folder_id.to_s.strip.presence || model.to_s[MODEL_URI, :folder].to_s
    super(api_key:, base_url: URL, model: model_uri(model.to_s.strip))
  end

  attr_reader :folder_id

  def service_name
    'YandexGPT'
  end

  def chat(messages:, functions: nil, function_call: nil)
    function = Array(functions).first
    return super if function.nil?

    result = send_chat(messages, function, schema: true)
    result = send_chat(messages, function, schema: false) if %w[400 422].include?(result.code.to_s)
    raise DomServis::Intake::AIError, failure_message(result, key: %w[401 403].include?(result.code.to_s)) if !result.success?

    message_from(result)
  end

  # This API of Yandex has no model list: the admin form offers MODELS, and
  # the sample reading of the connection check shows whether the model works.
  def models
    []
  end

  private

  def model_uri(name)
    name.start_with?('gpt://') ? name : "gpt://#{folder_id}/#{name}"
  end

  def request_headers
    { 'OpenAI-Project' => folder_id, 'x-folder-id' => folder_id, 'x-data-logging-enabled' => 'false' }
  end

  def send_chat(messages, function, schema:)
    format = schema ? { type: 'json_schema', json_schema: { name: function[:name], schema: function[:parameters] } } : { type: 'json_object' }
    body = { model:, messages: json_messages(messages, function, schema:), temperature: 0.1, max_tokens: 1000, response_format: format }

    send_request(:post, 'chat/completions', body, read_timeout: 30)
  end

  # The prompt asks for a function call; here the answer is JSON instead.
  def json_messages(messages, function, schema:)
    instruction = "Вместо вызова функции #{function[:name]} ответь одним JSON-объектом с её полями, без пояснений."
    instruction += "\nПоля (JSON Schema): #{function[:parameters].to_json}" if !schema

    messages.map.with_index do |message, index|
      index.zero? && message[:role] == 'system' ? message.merge(content: "#{message[:content]}\n#{instruction}") : message
    end
  end
end
