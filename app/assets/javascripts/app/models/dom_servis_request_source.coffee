class App.DomServisRequestSource extends App.Model
  @configure 'DomServisRequestSource', 'name', 'partner_key', 'organization_id', 'organization_name', 'transport_kind', 'status', 'allowed_domains', 'privacy_policy_url', 'notes', 'embed_token', 'embed_url', 'embed_snippet', 'embed_js_snippet', 'request_source_type', 'display_name', 'rotate_embed_token', 'updated_at', 'created_at'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/dom_servis/request_sources'
  @configure_attributes = [
    { name: 'name', display: __('Название'), tag: 'input', type: 'text', limit: 150, null: false }
    { name: 'partner_key', display: __('Ключ партнёра'), tag: 'input', type: 'text', limit: 120, null: false, note: __('Стабильный внутренний идентификатор. Партнёр его не вводит в форму, а менеджер использует только для поддержки и проверки интеграции.') }
    { name: 'organization_id', display: __('Организация партнёра'), tag: 'select', multiple: false, null: true, relation: 'Organization', note: __('Организация используется для статистики, привязки источника и маршрутизации заявок.') }
    { name: 'transport_kind', display: __('Тип канала'), tag: 'select', null: false, translate: false, options: { zammad_form: 'Форма Zammad', webhook: 'Вебхук', ai: 'AI' }, default: 'zammad_form', note: __('Класс входящего транспорта. Сейчас используется форма Zammad, позже сюда можно добавить вебхуки и AI-источники.') }
    { name: 'status', display: __('Статус'), tag: 'select', null: false, translate: false, options: { active: 'Активен', paused: 'Приостановлен' }, default: 'paused', note: __('Активный источник принимает заявки. Приостановленный источник блокирует отправку.') }
    { name: 'allowed_domains', display: __('Разрешённые домены'), tag: 'textarea', rows: 4, limit: 1000, null: true, note: __('Укажите домены сайта партнёра через запятую или с новой строки. Например: partner.ru, www.partner.ru.') }
    { name: 'privacy_policy_url', display: __('Ссылка на политику конфиденциальности'), tag: 'input', type: 'url', limit: 2000, null: true, note: __('Укажите страницу партнёра с политикой обработки персональных данных. Ссылка появится рядом с чекбоксом согласия в iframe-форме.') }
    { name: 'notes', display: __('Примечание'), tag: 'textarea', rows: 4, limit: 4000, null: true, note: __('Внутренние заметки менеджера: откуда пришёл партнёр, кто согласовал запуск, что проверить перед выдачей кода.') }
    { name: 'embed_token', display: __('Токен встраивания'), tag: 'input', type: 'text', limit: 200, null: false, readonly: 1, skipRendering: 1 }
    { name: 'rotate_embed_token', display: __('Сменить токен встраивания при сохранении'), tag: 'boolean', null: true, default: false, note: __('Создаёт новый токен. Старые ссылки и сниппеты перестанут работать.') }
    { name: 'embed_url', display: __('URL встраивания'), tag: 'copy_field', type: 'text', limit: 2000, null: true, readonly: 1, multiline: false, note: __('Готовый URL, который можно отправить партнёру или вставить в iframe.') }
    { name: 'embed_snippet', display: __('Iframe-код'), tag: 'copy_field', rows: 10, limit: 8000, null: true, readonly: 1, multiline: true, note: __('Готовый iframe-вариант. Его проще всего вставить на сайт партнёра.') }
    { name: 'embed_js_snippet', display: __('JS-код'), tag: 'copy_field', rows: 18, limit: 12000, null: true, readonly: 1, multiline: true, note: __('JS-вариант для сайтов, где удобнее подключать форму скриптом.') }
    { name: 'display_name', display: __('Отображаемое имя'), tag: 'input', type: 'text', limit: 250, null: true, readonly: 1, skipRendering: 1 }
    { name: 'updated_at', display: __('Обновлено'), tag: 'datetime', readonly: 1, skipRendering: 1 }
    { name: 'created_at', display: __('Создано'), tag: 'datetime', readonly: 1, skipRendering: 1 }
  ]
  @configure_delete = true
  @configure_clone = false
  @configure_overview = [
    'name'
    'partner_key'
    'organization_name'
    'transport_kind'
    'status'
  ]

  @description = __('''
Источники заявок партнёров определяют, как внешние сайты партнёров, вебхуки и будущие AI-точки входа попадают в Дом-Сервис. Используйте их, чтобы привязывать транспорт к организации партнёра без передачи идентичности партнёра в payload.

Операционный слой по-прежнему живёт в DispatchJob. Этот реестр управляет только привязкой входящего канала, безопасностью и генерацией встраивания.
''')

  displayName: ->
    return @name if !@partner_key
    "#{@name} (#{@partner_key})"

  uiUrl: ->
    "#manage/dom_servis_request_sources/id:#{@id}"
