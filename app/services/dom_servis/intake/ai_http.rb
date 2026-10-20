# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# What the AI clients of the pasted text reading share: the request options
# and the messages for failed requests. Request bodies are never logged,
# they contain client data.
module DomServis::Intake::AIHttp
  private

  def json_options(token, read_timeout:, headers: {})
    {
      json:          true,
      bearer_token:  token,
      headers:       { 'Accept' => 'application/json' }.merge(headers),
      open_timeout:  5,
      read_timeout:  read_timeout,
      total_timeout: read_timeout + 5,
    }
  end

  def message_from(result)
    message = result.data.is_a?(Hash) ? result.data.dig('choices', 0, 'message') : nil
    raise DomServis::Intake::AIError, "Пустой ответ от #{service_name}." if !message.is_a?(Hash)

    message
  end

  def model_ids(result)
    data = result.data.is_a?(Hash) ? result.data['data'] : nil

    Array(data).filter_map { |entry| entry['id'] if entry.is_a?(Hash) }
  end

  def failure_message(result, key: false)
    return "Ключ #{service_name} не принят: проверьте ключ и тип доступа." if key && %w[400 401 403].include?(result.code.to_s)

    case result.code.to_s
    when '401', '403'
      "Доступ к #{service_name} запрещён (код #{result.code})."
    when '402'
      "В #{service_name} закончились оплаченные токены."
    when '404'
      "Модель #{service_name} не найдена: проверьте её название."
    when '400', '422'
      "Запрос к #{service_name} не принят (код #{result.code})."
    when '429'
      "Слишком много запросов к #{service_name}, повторите через минуту."
    when '0'
      connection_failure(result.error.to_s)
    else
      "Ошибка #{service_name} (код #{result.code})."
    end
  end

  def connection_failure(error)
    return "Нет доверия к сертификату #{service_name}: загрузите его корневой сертификат (для GigaChat — Russian Trusted Root CA Минцифры) в Управление → Безопасность → SSL-сертификаты." if error.match?(%r{certificate|SSL}i)
    return "Нет ответа от #{service_name}: время ожидания истекло." if error.match?(%r{timeout|timed out}i)

    "Не удалось связаться с #{service_name}."
  end
end
