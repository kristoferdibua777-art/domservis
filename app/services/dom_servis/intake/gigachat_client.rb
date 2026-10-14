# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Talks to the GigaChat API of Sber (decision 2026-10-14: a service that works
# from the Russian server without a VPN and keeps the client data in Russia).
#
# The authorization key from the GigaChat personal account is exchanged for an
# access token that lives 30 minutes; the token is cached until shortly before
# it expires. The GigaChat servers use a certificate of the Russian Trusted
# Root CA: an admin uploads that root certificate in Manage > Security > SSL
# Certificates, UserAgent then trusts it. Request bodies are never logged,
# they contain client data.
class DomServis::Intake::GigachatClient
  class Error < StandardError; end

  TOKEN_URL = 'https://ngw.devices.sberbank.ru:9443/api/v2/oauth'.freeze
  API_URL = 'https://api.giga.chat/v1'.freeze
  TOKEN_REFRESH_MARGIN = 60
  MAX_TOKEN_LIFETIME = 25.minutes.to_i

  def initialize(auth_key:, scope:, model:)
    @auth_key = auth_key.to_s
    @scope = scope.to_s
    @model = model.to_s
  end

  attr_reader :auth_key, :scope, :model

  # Returns the first answer message, e.g. { 'role' => 'assistant',
  # 'function_call' => { 'name' => ..., 'arguments' => {...} } }.
  def chat(messages:, functions: nil, function_call: nil)
    body = { model:, messages:, temperature: 0.1, max_tokens: 1000 }
    body[:functions] = functions if functions
    body[:function_call] = function_call if function_call

    result = with_token { |token| UserAgent.post("#{API_URL}/chat/completions", body, api_options(token, read_timeout: 30)) }
    message = result.data.is_a?(Hash) ? result.data.dig('choices', 0, 'message') : nil
    raise Error, 'Пустой ответ от GigaChat.' if !message.is_a?(Hash)

    message
  end

  # The model names the key may use; also serves as the connection check.
  def models
    result = with_token { |token| UserAgent.get("#{API_URL}/models", {}, api_options(token, read_timeout: 15)) }
    data = result.data.is_a?(Hash) ? result.data['data'] : nil

    Array(data).filter_map { |entry| entry['id'] if entry.is_a?(Hash) }
  end

  private

  def with_token
    result = yield(access_token)
    if result.code.to_s == '401'
      Rails.cache.delete(token_cache_key)
      result = yield(access_token)
    end
    raise Error, failure_message(result) if !result.success?

    result
  end

  def api_options(token, read_timeout:)
    {
      json:          true,
      bearer_token:  token,
      headers:       { 'Accept' => 'application/json' },
      open_timeout:  5,
      read_timeout:  read_timeout,
      total_timeout: read_timeout + 5,
    }
  end

  def access_token
    cached = Rails.cache.read(token_cache_key)
    return cached if cached.present?

    token, lifetime = fetch_token
    Rails.cache.write(token_cache_key, token, expires_in: lifetime)
    token
  end

  def fetch_token
    raise Error, 'Не задан ключ авторизации GigaChat.' if auth_key.blank?

    result = UserAgent.post(TOKEN_URL, { scope: }, token_options)
    raise Error, failure_message(result, token: true) if !result.success?

    data = JSON.parse(result.body.to_s)
    token = data['access_token'].presence
    raise Error, 'Не удалось получить токен доступа GigaChat.' if !token.is_a?(String)

    [token, token_lifetime(data['expires_at'])]
  rescue JSON::ParserError
    raise Error, 'Не удалось получить токен доступа GigaChat.'
  end

  def token_options
    {
      headers:       {
        'Authorization' => "Basic #{auth_key}",
        'RqUID'         => SecureRandom.uuid,
        'Accept'        => 'application/json',
      },
      open_timeout:  5,
      read_timeout:  15,
      total_timeout: 20,
    }
  end

  # expires_at is a Unix time, in milliseconds in the older API versions.
  def token_lifetime(expires_at)
    seconds = expires_at.to_i
    seconds /= 1000 if seconds > 10_000_000_000

    (seconds - Time.zone.now.to_i - TOKEN_REFRESH_MARGIN).clamp(60, MAX_TOKEN_LIFETIME)
  end

  # The cache key is a digest, so the key itself never lands in the cache.
  def token_cache_key
    "dom_servis/gigachat_token/#{Digest::SHA256.hexdigest("#{auth_key}|#{scope}")}"
  end

  def failure_message(result, token: false)
    case result.code.to_s
    when '400', '401', '403'
      token ? 'Ключ авторизации GigaChat не принят: проверьте ключ и тип доступа.' : "Доступ к GigaChat запрещён (код #{result.code})."
    when '402'
      'В GigaChat закончились оплаченные токены.'
    when '404'
      'Модель GigaChat не найдена: проверьте её название.'
    when '422'
      'Запрос к GigaChat не принят (код 422).'
    when '429'
      'Слишком много запросов к GigaChat, повторите через минуту.'
    when '0'
      connection_failure(result.error.to_s)
    else
      "Ошибка GigaChat (код #{result.code})."
    end
  end

  def connection_failure(error)
    return 'Нет доверия к сертификату GigaChat: загрузите корневой сертификат Минцифры (Russian Trusted Root CA) в Управление → Безопасность → SSL-сертификаты.' if error.match?(%r{certificate|SSL}i)
    return 'Нет ответа от GigaChat: время ожидания истекло.' if error.match?(%r{timeout|timed out}i)

    'Не удалось связаться с GigaChat.'
  end
end
