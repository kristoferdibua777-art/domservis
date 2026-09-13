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

    @render()
    @loadPolicy()

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

  openBoard: (e) =>
    @preventDefault(e)
    @navigate '#dom_servis/dispatch'

  normalizePolicy: (policy) =>
    policy ||= {}
    policy.actions ?= {}
    policy.statuses ?= {}
    policy.fields ?= {}
    policy.settings ?= {}
    policy.settings.deadline_warning_minutes ?= 120
    policy

App.Config.set('DomServisDispatch', { prio: 3600, name: __('Dispatch Admin'), parent: '#manage', target: '#manage/dom_servis_dispatch', controller: DomServisDispatch, permission: ['dom_servis.admin'] }, 'NavBarAdmin')
