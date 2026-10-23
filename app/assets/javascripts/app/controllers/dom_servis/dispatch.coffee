class DomServisDispatch extends App.ControllerSubContent
  @requiredPermission: 'dom_servis.admin'
  header: __('Dispatch admin')

  events:
    'click .js-open-dispatch-board': 'openBoard'
    'click .js-refresh-dispatch-admin': 'refresh'
    'click .js-save-dispatch-policy': 'savePolicy'
    'click .js-reset-dispatch-policy': 'resetPolicy'
    'change .js-policy-toggle': 'togglePolicy'
    'change .js-policy-setting': 'updatePolicySetting'
    'click .js-history-export': 'exportHistory'
    'click .js-history-purge': 'purgeLastExport'
    'click .js-ai-save': 'saveAISettings'
    'click .js-ai-check': 'checkAISettings'
    'click .js-ai-clear-key': 'clearAiKey'
    'change .js-ai-provider': 'changeAIProvider'
    'input .js-price-field': 'changePriceField'
    'change .js-price-field': 'changePriceField'
    'click .js-price-add': 'addPriceItem'
    'click .js-price-template': 'addPriceTemplate'
    'click .js-price-remove': 'removePriceItem'
    'click .js-price-save': 'savePriceList'
    'input .js-rate-field': 'changeRateField'
    'change .js-rate-field': 'changeRateField'
    'click .js-rates-save': 'saveRates'
    'change .js-report-export-field': 'changeReportExportField'
    'click .js-report-export-download': 'downloadReportExport'

  constructor: ->
    super

    @stats =
      total: 0
      pool: 0
      active: 0
      done: 0

    @registry =
      roles: []
      action_groups: []
      statuses: []
      field_groups: []

    @policy =
      actions: {}
      statuses: {}
      fields: {}
      settings:
        deadline_warning_minutes: 120
        visit_duration_minutes: 120
        calendar_day_start_hour: 8
        calendar_day_end_hour: 20

    @tags = []
    @loading = true
    @saving = false
    @dirty = false
    @errorMessage = null
    @history = null
    @historyBusy = false
    @aiSettings = null
    @aiBusy = false
    @aiCheck = null
    @finance =
      items: []
      kinds: []
      directions: []
      masters: []
      partners: []
      bases: []
      priceLoaded: false
      ratesLoaded: false
      busy: false
    @reportExport = @defaultReportExport()

    @render()
    @loadPolicy()
    @loadHistory()
    @loadAISettings()
    @loadFinance()

  show: (params) =>
    @navupdate '#manage/dom_servis_dispatch'
    super(params)

  render: ->
    @html App.view('dom_servis_dispatch/admin')(
      loading:  @loading
      saving:   @saving
      dirty:    @dirty
      error:    @errorMessage
      stats:    @stats
      tags:     @tags
      registry: @registry
      policy:   @policy
      history:  @historyView()
      ai:       @aiSettingsView()
      finance:  @financeView()
      reportExport: @reportExport
    )

  loadPolicy: ->
    @loading = true
    @errorMessage = null
    @render()

    @ajax(
      id:   'dom_servis_dispatch_admin_policy'
      type: 'GET'
      url:  "#{@apiPath}/dom_servis/dispatch/admin_policy"
      success: (data) =>
        @stats = data?.stats || @stats
        @tags = data?.tags || @tags
        @registry = data?.registry || @registry
        @policy = @normalizePolicy(data?.policy || @policy)
        @loading = false
        @saving = false
        @dirty = false
        @render()
      error: (xhr) =>
        @loading = false
        @saving = false
        @errorMessage = xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || __('Could not load dispatch policy.')
        @render()
    )

  refresh: (e) =>
    @preventDefault(e)
    @loadPolicy()
    @loadHistory()

  savePolicy: (e) =>
    @preventDefault(e)
    return if @saving

    @saving = true
    @errorMessage = null
    @render()

    @ajax(
      id:   'dom_servis_dispatch_admin_policy_save'
      type: 'PUT'
      url:  "#{@apiPath}/dom_servis/dispatch/admin_policy"
      data: JSON.stringify(policy: @policy)
      processData: true
      success: (data) =>
        @stats = data?.stats || @stats
        @registry = data?.registry || @registry
        @policy = @normalizePolicy(data?.policy || @policy)
        @saving = false
        @dirty = false
        @notify(type: 'success', msg: __('Dispatch policy saved.'), timeout: 3000)
        @render()
      error: (xhr) =>
        @saving = false
        @errorMessage = xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || __('Could not save dispatch policy.')
        @notify(type: 'error', msg: @errorMessage, timeout: 6000)
        @render()
    )

  resetPolicy: (e) =>
    @preventDefault(e)
    return if @saving

    @saving = true
    @errorMessage = null
    @render()

    @ajax(
      id:   'dom_servis_dispatch_admin_policy_reset'
      type: 'POST'
      url:  "#{@apiPath}/dom_servis/dispatch/admin_policy/reset"
      success: (data) =>
        @stats = data?.stats || @stats
        @registry = data?.registry || @registry
        @policy = @normalizePolicy(data?.policy || @policy)
        @saving = false
        @dirty = false
        @notify(type: 'success', msg: __('Dispatch policy reset to defaults.'), timeout: 3000)
        @render()
      error: (xhr) =>
        @saving = false
        @errorMessage = xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || __('Could not reset dispatch policy.')
        @notify(type: 'error', msg: @errorMessage, timeout: 6000)
        @render()
    )

  togglePolicy: (e) =>
    input = $(e.currentTarget)
    section = input.data('section')
    item = input.data('item')
    role = input.data('role')
    mode = input.data('mode')
    checked = input.prop('checked')

    return if !section || !item || !role

    if section is 'fields'
      @policy.fields[item] ?= {}
      @policy.fields[item][role] ?= {}
      @policy.fields[item][role][mode] = checked

      if mode is 'editable' && checked
        @policy.fields[item][role].visible = true

      if mode is 'visible' && !checked
        @policy.fields[item][role].editable = false
    else
      @policy[section][item] ?= {}
      @policy[section][item][role] = checked
    @dirty = true
    @render()

  updatePolicySetting: (e) =>
    input = $(e.currentTarget)
    key = input.data('setting')
    return if !key

    @policy.settings ?= {}
    value = parseInt(input.val(), 10)
    @policy.settings[key] = if isNaN(value) then null else value
    @dirty = true
    @render()

  # Price list and shares of the master report (decision 2026-10-24). Fields
  # change the state as they are typed; a render only follows adding or
  # removing a line and the answers of the server.
  PRICE_TEMPLATE: [
    { name: 'Выезд мастера', kind: 'work', direction: '', unit: 'выезд' }
    { name: 'Диагностика', kind: 'work', direction: '', unit: 'шт' }
    { name: 'Плановое ТО котла', kind: 'work', direction: 'Газовый котёл', unit: 'шт' }
    { name: 'Чистка теплообменника', kind: 'work', direction: 'Газовый котёл', unit: 'шт' }
    { name: 'Замена датчика или термопары', kind: 'work', direction: 'Газовый котёл', unit: 'шт' }
    { name: 'Чистка бойлера от накипи', kind: 'work', direction: 'Бойлер и колонка', unit: 'шт' }
    { name: 'Замена ТЭНа или анода', kind: 'work', direction: 'Бойлер и колонка', unit: 'шт' }
    { name: 'Устранение протечки', kind: 'work', direction: 'Сантехника', unit: 'шт' }
    { name: 'Прочистка засора', kind: 'work', direction: 'Сантехника', unit: 'шт' }
    { name: 'Замена смесителя', kind: 'work', direction: 'Сантехника', unit: 'шт' }
    { name: 'Замена розетки или выключателя', kind: 'work', direction: 'Электрика', unit: 'шт' }
    { name: 'Установка светильника', kind: 'work', direction: 'Электрика', unit: 'шт' }
    { name: 'Ремонт стиральной машины', kind: 'work', direction: 'Бытовая техника', unit: 'шт' }
    { name: 'Ремонт холодильника', kind: 'work', direction: 'Бытовая техника', unit: 'шт' }
    { name: 'Мелкий ремонт', kind: 'work', direction: 'Работы по дому', unit: 'час' }
  ]

  loadFinance: ->
    @ajax(
      id:   'dom_servis_dispatch_price_list'
      type: 'GET'
      url:  "#{@apiPath}/dom_servis/dispatch/price_list"
      success: (data) =>
        @setPriceList(data)
        @render()
    )
    @ajax(
      id:   'dom_servis_dispatch_finance_rates'
      type: 'GET'
      url:  "#{@apiPath}/dom_servis/dispatch/finance_rates"
      success: (data) =>
        @setRates(data)
        @render()
    )

  setPriceList: (data) ->
    @finance.items = _.map(data?.items || [], (item) -> _.extend({}, item, price: "#{item.price}", direction: item.direction || ''))
    @finance.kinds = data?.kinds || []
    @finance.directions = data?.directions || []
    @finance.priceLoaded = true
    @finance.priceDirty = false

  setRates: (data) ->
    @finance.masters = _.map(data?.masters || [], (row) -> _.extend({}, row, work_percent: "#{row.work_percent}"))
    @finance.partners = _.map(data?.partners || [], (row) -> _.extend({}, row, percent: "#{row.percent}"))
    @finance.bases = data?.bases || []
    @finance.ratesLoaded = true
    @finance.ratesDirty = false

  financeView: ->
    _.extend({}, @finance,
      items: _.map(@finance.items, (item, index) -> _.extend({ index: index }, item))
      masters: _.map(@finance.masters, (row, index) -> _.extend({ index: index }, row))
      partners: _.map(@finance.partners, (row, index) -> _.extend({ index: index }, row))
    )

  changePriceField: (e) =>
    field = $(e.currentTarget)
    item = @finance.items[parseInt(field.data('index'), 10)]
    return if !item

    item[field.data('field')] = if field.is(':checkbox') then field.prop('checked') else field.val()
    @finance.priceDirty = true

  addPriceItem: (e) =>
    @preventDefault(e)
    @finance.items.push({ id: null, name: '', kind: 'work', direction: '', unit: 'шт', price: '', active: true })
    @finance.priceDirty = true
    @render()

  addPriceTemplate: (e) =>
    @preventDefault(e)
    names = _.map(@finance.items, (item) -> "#{item.name}".toLowerCase())
    for row in @PRICE_TEMPLATE when !_.contains(names, row.name.toLowerCase())
      @finance.items.push(_.extend({ id: null, price: '', active: true }, row))
    @finance.priceDirty = true
    @render()

  removePriceItem: (e) =>
    @preventDefault(e)
    index = parseInt($(e.currentTarget).data('index'), 10)
    return if _.isNaN(index)

    @finance.items.splice(index, 1)
    @finance.priceDirty = true
    @render()

  savePriceList: (e) =>
    @preventDefault(e)
    return if @finance.busy

    @finance.busy = true
    @render()

    @ajax(
      id:   'dom_servis_dispatch_price_list_save'
      type: 'PUT'
      url:  "#{@apiPath}/dom_servis/dispatch/price_list"
      data: JSON.stringify(items: _.map(@finance.items, (item) -> _.pick(item, 'id', 'name', 'kind', 'direction', 'unit', 'price', 'active')))
      processData: true
      success: (data) =>
        @finance.busy = false
        @setPriceList(data)
        @notify(type: 'success', msg: 'Прайс сохранён.', timeout: 3000)
        @render()
      error: (xhr) =>
        @finance.busy = false
        @notify(type: 'error', msg: @financeError(xhr, 'Не удалось сохранить прайс.'), timeout: 8000)
        @render()
    )

  changeRateField: (e) =>
    field = $(e.currentTarget)
    list = if field.data('type') is 'partner' then @finance.partners else @finance.masters
    row = list[parseInt(field.data('index'), 10)]
    return if !row

    row[field.data('field')] = field.val()
    @finance.ratesDirty = true

  saveRates: (e) =>
    @preventDefault(e)
    return if @finance.busy

    @finance.busy = true
    @render()

    @ajax(
      id:   'dom_servis_dispatch_finance_rates_save'
      type: 'PUT'
      url:  "#{@apiPath}/dom_servis/dispatch/finance_rates"
      data: JSON.stringify(
        masters: _.map(@finance.masters, (row) -> _.pick(row, 'user_id', 'work_percent'))
        partners: _.map(@finance.partners, (row) -> _.pick(row, 'organization_id', 'percent', 'base'))
      )
      processData: true
      success: (data) =>
        @finance.busy = false
        @setRates(data)
        @notify(type: 'success', msg: 'Проценты сохранены.', timeout: 3000)
        @render()
      error: (xhr) =>
        @finance.busy = false
        @notify(type: 'error', msg: @financeError(xhr, 'Не удалось сохранить проценты.'), timeout: 8000)
        @render()
    )

  # The table of jobs with their master reports for a period, by default the
  # current month by the day the jobs were created.
  defaultReportExport: ->
    pad = (number) -> ("0#{number}").slice(-2)
    today = new Date()
    format = (date) -> "#{date.getFullYear()}-#{pad(date.getMonth() + 1)}-#{pad(date.getDate())}"
    {
      from: format(new Date(today.getFullYear(), today.getMonth(), 1))
      to: format(today)
      date_field: 'created'
      master_id: ''
      busy: false
    }

  changeReportExportField: (e) =>
    field = $(e.currentTarget)
    @reportExport[field.data('field')] = field.val()

  downloadReportExport: (e) =>
    @preventDefault(e)
    return if @reportExport.busy

    params = $.param(_.pick(@reportExport, 'from', 'to', 'date_field', 'master_id'))
    @reportExport.busy = true
    @render()

    App.Ajax.request(
      id:          'dom_servis_dispatch_report_export'
      type:        'GET'
      url:         "#{@apiPath}/dom_servis/dispatch/report_export?#{params}"
      processData: true
      dataType:    'binary'
      contentType: 'application/octet-stream'
      xhrFields:
        responseType: 'blob'
      success: (data, status, xhr) =>
        App.Utils.downloadFileFromBlob(data, xhr, { fallbackFilename: 'dom-servis-reports.xlsx' })
        @reportExport.busy = false
        @render()
      error: (xhr) =>
        @reportExport.busy = false
        @notify(type: 'error', msg: @financeError(xhr, 'Не удалось выгрузить таблицу.'), timeout: 8000)
        @render()
    )

  financeError: (xhr, fallback) ->
    xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || fallback

  # Job history (decision 2026-09-28): an admin exports it to Excel every 30
  # days; right after the download the admin is asked to allow removing
  # exactly the downloaded events.
  loadHistory: ->
    @ajax(
      id:   'dom_servis_dispatch_history_status'
      type: 'GET'
      url:  "#{@apiPath}/dom_servis/dispatch/history_exports"
      success: (data) =>
        @history = data || null
        @render()
      error: =>
        @history = null
        @render()
    )

  historyView: ->
    return null if !@history

    last = @history.last_export
    {
      eventCount: @history.event_count || 0
      due: @history.due is true
      reminderDays: @history.reminder_days || 30
      busy: @historyBusy
      lastExport: if last
        createdAt: @historyTime(last.created_at)
        createdBy: last.created_by_name || '—'
        eventCount: last.event_count
        downloaded: !!last.downloaded_at
        purgedAt: if last.purged_at then @historyTime(last.purged_at) else null
        purgedBy: last.purged_by_name || '—'
        purgedCount: last.purged_count || 0
        purgeable: last.purgeable is true
      else
        null
    }

  historyTime: (value) ->
    date = new Date(value)
    return '—' if !value || isNaN(date.getTime())

    pad = (number) -> ("0#{number}").slice(-2)
    "#{pad(date.getDate())}.#{pad(date.getMonth() + 1)}.#{date.getFullYear()} #{pad(date.getHours())}:#{pad(date.getMinutes())}"

  exportHistory: (e) =>
    @preventDefault(e)
    return if @historyBusy

    @historyBusy = true
    @render()

    @ajax(
      id:   'dom_servis_dispatch_history_export'
      type: 'POST'
      url:  "#{@apiPath}/dom_servis/dispatch/history_exports"
      success: (data) =>
        @downloadHistory(data)
      error: (xhr) =>
        @historyFailed(xhr, 'Не удалось выгрузить историю.')
    )

  downloadHistory: (historyExport) =>
    App.Ajax.request(
      id:          'dom_servis_dispatch_history_download'
      type:        'GET'
      url:         "#{@apiPath}/dom_servis/dispatch/history_exports/#{historyExport.id}/download"
      processData: true
      dataType:    'binary'
      contentType: 'application/octet-stream'
      xhrFields:
        responseType: 'blob'
      success: (data, status, xhr) =>
        App.Utils.downloadFileFromBlob(data, xhr, { fallbackFilename: 'dom-servis-history.xlsx' })
        @historyBusy = false
        @loadHistory()
        @askHistoryPurge(historyExport)
      error: (xhr) =>
        @historyFailed(xhr, 'Не удалось скачать файл истории.')
    )

  # The permission to remove the history pops up right after the download.
  askHistoryPurge: (historyExport) =>
    new App.ControllerConfirm(
      head:         'Удалить выгруженную историю?'
      message:      "Файл с историей заявок скачан. Разрешить удаление выгруженных событий (#{historyExport.event_count})? События, появившиеся после выгрузки, останутся."
      buttonSubmit: 'Удалить историю'
      buttonClass:  'btn--danger'
      callback:     => @purgeHistory(historyExport.id)
      container:    @el.closest('.content')
    )

  purgeLastExport: (e) =>
    @preventDefault(e)
    last = @history?.last_export
    return if !last?.purgeable || @historyBusy

    @askHistoryPurge(last)

  purgeHistory: (id) =>
    @historyBusy = true
    @render()

    @ajax(
      id:   'dom_servis_dispatch_history_purge'
      type: 'POST'
      url:  "#{@apiPath}/dom_servis/dispatch/history_exports/#{id}/purge"
      success: (data) =>
        @historyBusy = false
        @notify(type: 'success', msg: "Выгруженная история удалена, событий: #{data?.purged_count || 0}.", timeout: 4000)
        @loadHistory()
      error: (xhr) =>
        @historyFailed(xhr, 'Не удалось удалить историю.')
    )

  historyFailed: (xhr, fallback) ->
    @historyBusy = false
    message = xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || fallback
    @notify(type: 'error', msg: message, timeout: 6000)
    @loadHistory()

  # GigaChat settings of the pasted text reading on the board. The server
  # only tells whether a key is saved; a new key is sent once and the field
  # is emptied right after.
  AI_SCOPE_LABELS:
    GIGACHAT_API_PERS: 'Физическое лицо (GIGACHAT_API_PERS)'
    GIGACHAT_API_B2B: 'ИП или юрлицо, пакеты или оплата по факту (GIGACHAT_API_B2B)'
    GIGACHAT_API_CORP: 'Юрлицо по договору (GIGACHAT_API_CORP)'

  loadAISettings: ->
    @ajax(
      id:   'dom_servis_dispatch_ai_settings'
      type: 'GET'
      url:  "#{@apiPath}/dom_servis/dispatch/ai_settings"
      success: (data) =>
        @aiSettings = data || null
        @render()
      error: =>
        @aiSettings = null
        @render()
    )

  aiSettingsView: ->
    settings = @aiSettings
    return { loaded: false } if !settings

    form = @aiForm || {}
    sample = @aiCheck?.sample
    provider = form.provider || settings.provider
    {
      loaded: true
      busy: @aiBusy
      enabled: if form.enabled? then form.enabled else settings.enabled is true
      authKeySet: settings.auth_key_set is true
      provider: provider
      scope: form.scope || settings.scope
      model: if form.model? then form.model else settings.model
      baseUrl: form.base_url || settings.base_url
      folderId: if form.folder_id? then form.folder_id else (settings.folder_id || '')
      models: _.uniq(@aiProviderModels(provider).concat(@aiCheck?.models || []))
      providerOptions: ({ id: provider, label: @AI_PROVIDER_LABELS[provider] || provider } for provider in (settings.providers || []))
      scopeOptions: ({ id: scope, label: @AI_SCOPE_LABELS[scope] || scope } for scope in (settings.scopes || []))
      check: if @aiCheck
        ok: @aiCheck.ok is true
        error: @aiCheck.error || 'Проверка не удалась.'
        models: @aiCheck.models || []
        modelAvailable: @aiCheck.model_available is true
        sample: if sample then _.compact([sample.service_type, sample.address, sample.client_phone]).join('; ') else null
      else
        null
    }

  AI_PROVIDER_LABELS:
    gigachat: 'Сбер, GigaChat API — ключ авторизации (Freemium для новых пользователей)'
    yandex: 'Яндекс, YandexGPT в AI Studio — API-ключ сервисного аккаунта'
    chat_completions: 'Через Cloud.ru Foundation Models или другой API как у OpenAI — API-ключ'

  AI_DEFAULT_MODELS:
    gigachat: 'GigaChat-2-Pro'
    yandex: 'yandexgpt/latest'

  aiProviderModels: (provider) ->
    switch provider
      when 'gigachat' then @aiSettings?.models || []
      when 'yandex' then @aiSettings?.yandex_models || []
      else []

  # Switching the way re-renders the form; what was typed stays, except a
  # model name the new way does not know.
  changeAIProvider: (e) =>
    @aiForm = @aiSettingsForm()
    provider = @aiForm.provider = $(e.currentTarget).val()
    if @AI_DEFAULT_MODELS[provider]
      fullYandexUri = provider is 'yandex' && /^gpt:\/\//.test(@aiForm.model)
      @aiForm.model = @AI_DEFAULT_MODELS[provider] if @aiForm.model not in @aiProviderModels(provider) && !fullYandexUri
    else
      @aiForm.model = '' if @aiForm.model in @aiProviderModels('gigachat').concat(@aiProviderModels('yandex'))
    typedKey = @aiForm.auth_key
    @render()
    @$('.js-ai-auth-key').val(typedKey) if typedKey

  aiSettingsForm: ->
    form =
      enabled: @$('.js-ai-enabled').prop('checked') is true
      provider: @$('.js-ai-provider').val()
      model: (@$('.js-ai-model').val() || '').trim()
      auth_key: (@$('.js-ai-auth-key').val() || '').trim()
    form.scope = @$('.js-ai-scope').val() if @$('.js-ai-scope').length
    form.base_url = (@$('.js-ai-base-url').val() || '').trim() if @$('.js-ai-base-url').length
    form.folder_id = (@$('.js-ai-folder-id').val() || '').trim() if @$('.js-ai-folder-id').length
    form

  saveAISettings: (e) =>
    @preventDefault(e)
    return if @aiBusy

    form = @aiSettingsForm()
    # A newly saved key turns the reading on, so one click is enough.
    form.enabled = true if form.auth_key && !@aiSettings?.auth_key_set
    @sendAISettings(form, 'Настройки ИИ-разбора сохранены.')

  clearAiKey: (e) =>
    @preventDefault(e)
    return if @aiBusy

    @sendAISettings({ clear_auth_key: true, enabled: false }, 'Ключ удалён, ИИ-разбор выключен.')

  sendAISettings: (data, successMessage) ->
    @aiBusy = true
    @aiCheck = null
    @render()

    @ajax(
      id:   'dom_servis_dispatch_ai_settings_save'
      type: 'PUT'
      url:  "#{@apiPath}/dom_servis/dispatch/ai_settings"
      data: JSON.stringify(data)
      processData: true
      success: (result) =>
        @aiSettings = result || @aiSettings
        @aiForm = null
        @aiBusy = false
        @notify(type: 'success', msg: successMessage, timeout: 3000)
        @render()
      error: (xhr) =>
        @aiBusy = false
        message = xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || 'Не удалось сохранить настройки ИИ-разбора.'
        @notify(type: 'error', msg: message, timeout: 6000)
        @render()
    )

  checkAISettings: (e) =>
    @preventDefault(e)
    return if @aiBusy

    @aiBusy = true
    @aiCheck = null
    @render()

    @ajax(
      id:   'dom_servis_dispatch_ai_settings_check'
      type: 'POST'
      url:  "#{@apiPath}/dom_servis/dispatch/ai_settings/check"
      success: (result) =>
        @aiBusy = false
        @aiCheck = result || { ok: false }
        @render()
      error: (xhr) =>
        @aiBusy = false
        @aiCheck = { ok: false, error: xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || 'Проверка не удалась.' }
        @render()
    )

  openBoard: (e) =>
    @preventDefault(e)
    @navigate '#dom_servis/dispatch'

  normalizePolicy: (policy) ->
    policy ||= {}
    policy.actions ?= {}
    policy.statuses ?= {}
    policy.fields ?= {}
    policy.settings ?= {}
    policy.settings.deadline_warning_minutes ?= 120
    policy.settings.visit_duration_minutes ?= 120
    policy.settings.calendar_day_start_hour ?= 8
    policy.settings.calendar_day_end_hour ?= 20
    policy

App.Config.set('DomServisDispatch', { prio: 3600, name: __('Dispatch Admin'), parent: '#manage', target: '#manage/dom_servis_dispatch', controller: DomServisDispatch, permission: ['dom_servis.admin'] }, 'NavBarAdmin')
