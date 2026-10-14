# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Talks to the GigaChat API of Sber (decision 2026-10-14: a service that works
# from the Russian server without a VPN and keeps the client data in Russia).
# New users get the free Freemium package here; since 2026-09-01 new clients
# pay for GigaChat on Cloud.ru instead (DomServis::Intake::ChatCompletionsClient).
#
# The authorization key from the GigaChat personal account is exchanged for an
# access token that lives 30 minutes; the token is cached until shortly before
# it expires. The GigaChat servers use a certificate of the Russian Trusted
# Root CA: an admin uploads that root certificate in Manage > Security > SSL
# Certificates, UserAgent then trusts it.
class DomServis::Intake::GigachatClient
  include DomServis::Intake::AIHttp

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

  def service_name
    'GigaChat'
  end

  # Returns the first answer message, e.g. { 'role' => 'assistant',
  # 'function_call' => { 'name' => ..., 'arguments' => {...} } }.
  def chat(messages:, functions: nil, function_call: nil)
    body = { model:, messages:, temperature: 0.1, max_tokens: 1000 }
    body[:functions] = functions if functions
    body[:function_call] = function_call if function_call

    message_from(with_token { |token| UserAgent.post("#{API_URL}/chat/completions", body, json_options(token, read_timeout: 30)) })
  end

  # The model names the key may use; also serves as the connection check.
  def models
    model_ids(with_token { |token| UserAgent.get("#{API_URL}/models", {}, json_options(token, read_timeout: 15)) })
  end

  private

  def with_token
    result = yield(access_token)
    if result.code.to_s == '401'
      Rails.cache.delete(token_cache_key)
      result = yield(access_token)
    end
    raise DomServis::Intake::AIError, failure_message(result) if !result.success?

    result
  end

  def access_token
    cached = Rails.cache.read(token_cache_key)
    return cached if cached.present?

    token, lifetime = fetch_token
    Rails.cache.write(token_cache_key, token, expires_in: lifetime)
    token
  end

  def fetch_token
    raise DomServis::Intake::AIError, 'Не задан ключ авторизации GigaChat.' if auth_key.blank?

    result = UserAgent.post(TOKEN_URL, { scope: }, token_options)
    raise DomServis::Intake::AIError, failure_message(result, key: true) if !result.success?

    data = JSON.parse(result.body.to_s)
    token = data['access_token'].presence
    raise DomServis::Intake::AIError, 'Не удалось получить токен доступа GigaChat.' if !token.is_a?(String)

    [token, token_lifetime(data['expires_at'])]
  rescue JSON::ParserError
    raise DomServis::Intake::AIError, 'Не удалось получить токен доступа GigaChat.'
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
end
