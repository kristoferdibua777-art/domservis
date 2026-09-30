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

    @tags = []
    @loading = true
    @saving = false
    @dirty = false
    @errorMessage = null
    @history = null
    @historyBusy = false

    @render()
    @loadPolicy()
    @loadHistory()

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
    policy

App.Config.set('DomServisDispatch', { prio: 3600, name: __('Dispatch Admin'), parent: '#manage', target: '#manage/dom_servis_dispatch', controller: DomServisDispatch, permission: ['dom_servis.admin'] }, 'NavBarAdmin')
