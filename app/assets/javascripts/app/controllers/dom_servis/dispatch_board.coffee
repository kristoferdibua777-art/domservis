class App.DomServisDispatchBoard extends App.Controller
  className: 'dom-servis-dispatch-board'

  events:
    'click .js-status-filter': 'setStatusFilter'
    'click .js-day-filter': 'setDayFilter'
    'click .js-tag-filter-toggle': 'toggleTagFilter'
    'click .js-clear-tag-filters': 'clearTagFilters'
    'click .js-week-shift': 'shiftWeek'
    'click .js-week-reset': 'resetWeek'
    'change .js-week-picker': 'pickWeek'
    'click .js-job-card': 'openDetailFromCard'
    'click .js-close-detail': 'closeDetail'
    'click .js-open-create': 'openCreate'
    'click .js-close-create': 'closeCreate'
    'click .js-open-edit': 'openEdit'
    'click .js-close-edit': 'closeEdit'
    'click .js-refresh-jobs': 'refreshJobs'
    'click .js-open-mobile-account-menu': 'openMobileAccountMenu'
    'click .js-close-mobile-account-menu': 'closeMobileAccountMenu'
    'click .js-mobile-workspace-nav': 'navigateFromMobileWorkspaceMenu'
    'click .js-create-job': 'createJob'
    'input .js-create-draft-field': 'updateCreateDraft'
    'change .js-create-draft-field': 'updateCreateDraft'
    'click .js-create-tag-toggle': 'toggleCreateTag'
    'click .js-trigger-create-attachment-upload': 'triggerCreateAttachmentUpload'
    'change .js-create-attachment-input': 'selectCreateAttachments'
    'click .js-remove-create-attachment': 'removeCreateAttachment'
    'change .js-create-attachment-kind': 'changeCreateAttachmentKind'
    'click .js-save-edit': 'saveEdit'
    'click .js-edit-tag-toggle': 'toggleEditTag'
    'change .js-assign-assignee': 'setAssignAssignee'
    'click .js-assign-job': 'assignJob'
    'click .js-take-job': 'takeJob'
    'click .js-release-job': 'releaseJob'
    'click .js-set-status': 'setStatus'
    'click .js-trigger-attachment-upload': 'triggerAttachmentUpload'
    'change .js-upload-attachment-input': 'uploadAttachments'
    'click .js-remove-attachment': 'removeAttachment'
    'change .js-change-priority': 'changePriority'
    'change .js-change-visit-day': 'changeVisitDay'
    'click .js-enable-push': 'enablePushNotifications'
    'click .js-test-push': 'testPushNotification'

  constructor: ->
    super

    @statusFilter = 'open'
    @dayFilter = 'all'
    @selectedWeekStart = @startOfWeek(new Date())
    @effectivePolicy = null
    @policyRegistry = {}
    @availableTags = []
    @activeTagFilters = []
    @jobs = []
    @loading = true
    @errorMessage = null
    @createOpen = false
    @editOpen = false
    @editingJobId = null
    @editSaving = false
    @detailOpen = false
    @detailJobId = null
    @detailAssignAssigneeId = null
    @organizations = []
    @organizationsLoaded = false
    @attachmentCollections = {}
    @attachmentLoading = {}
    @attachmentUploading = {}
    @createDraft = {}
    @createAttachmentFiles = []
    @createAttachmentUploading = false
    @createAttachmentKind = 'intake_attachment'
    @mobileWorkspaceMenuOpen = false
    @pendingRealtimeRefresh = false
    @realtimeRefreshDelayId = null
    @pushSubscribing = false
    @pushTesting = false
    @pushEnabled = false
    @initViewportMode()
    @statusFilter = 'mine' if @mobileView && @masterAccess()
    @bindRouteWatcher()
    @bindDispatchBoardRealtimeRefresh()
    @resetCreateDraft()

    @render()
    @loadEffectivePolicy()
    @loadTags()
    @loadOrganizations()
    @loadJobs()

  active: (state) =>
    return @shown if state is undefined
    @shown = state

  changed: ->
    false

  show: =>
    @title 'Диспетчеризация'
    @navupdate '#dom_servis/dispatch'
    @render() if !@loading

  release: =>
    @stopViewportWatcher()
    @stopRouteWatcher()
    @syncMobileShellState(false)

  render: ->
    defaultVisitDay = @defaultVisitDay()
    detailJob = @currentDetailJob()
    detailEditing = @detailEditing()

    @html App.view('dom_servis_dispatch/board')(
      loading: @loading
      error: @errorMessage
      mobileView: @mobileView
      mobileWorkspaceMenuOpen: @mobileWorkspaceMenuOpen
      dispatcherAccess: @dispatcherAccess()
      masterAccess: @masterAccess()
      mobileLabels: @mobileLabels()
      mobileShell: @buildMobileShell()
      mobileBoardSummary: @buildMobileBoardSummary()
      mobileWeekDays: @buildMobileWeekDays()
      mobileTagSummary: @buildMobileTagSummary()
      roleLabel: @roleLabel()
      currentUserCard: @buildCurrentUserCard()
      activeFilterSummary: @buildActiveFilterSummary()
      emptyState: @buildEmptyState()
      canCreateJob: @canCreatePublishedJob()
      pushSupported: @pushSupported() && @vapidPublicKey()
      pushEnabled: @pushEnabled
      pushSubscribing: @pushSubscribing
      pushTesting: @pushTesting
      showEnablePush: @vapidPublicKey() && !@pushEnabled
      showTestPush: @pushSupported() && @vapidPublicKey() && @pushEnabled
      createDraft: @createDraft
      createAttachmentKinds: @createAttachmentKindOptions()
      createAttachmentKind: @createAttachmentKind
      createAttachmentFiles: @buildCreateAttachmentDraft()
      createAttachmentUploading: @createAttachmentUploading
      stats: @buildStats()
      statusFilters: @buildScopedStatusFilters()
      weekControls: @buildWeekControls()
      dayFilters: @buildDayFilters()
      tagFilters: @buildTagFilters()
      createOpen: @createOpen
      editOpen: @editOpen
      editSaving: @editSaving
      detailOpen: @detailOpen
      detailEditing: detailEditing
      detailJob: @buildDetailJobView(detailJob)
      detailGroups: @buildDetailGroups(detailJob)
      detailEditGroups: @buildDrawerEditGroups(detailJob)
      detailAttachments: @buildAttachmentList(detailJob)
      detailAttachmentKinds: @attachmentKindOptions(detailJob)
      detailCanAddAttachment: @canAddAttachment(detailJob)
      detailCanDeleteAttachments: @canDeleteAttachments()
      detailAttachmentLoading: @attachmentLoading["#{detailJob?.id}"] is true
      detailAttachmentUploading: @attachmentUploading["#{detailJob?.id}"] is true
      organizationOptions: @organizationOptions()
      privateOrganizationId: @privateOrganizationId()
      jobCards: @buildJobCards()
      createTagOptions: @availableTagOptions(@createDraft.work_tags)
      defaultVisitDay: defaultVisitDay
      defaultVisitDate: @nextDateForDay(defaultVisitDay)
      todayLabel: @weekdayLabel(defaultVisitDay)
    )

    @$('.js-refresh-jobs').text(@mobileLabels().refreshAction)
    @el.toggleClass('is-mobile', @mobileView)
    @syncMobileShellState(@mobileView)

  initViewportMode: ->
    @mobileMediaQuery = window.matchMedia('(max-width: 767px)')
    @mobileView = @mobileMediaQuery.matches
    @viewportModeListener = => @syncViewportMode()

    if typeof @mobileMediaQuery.addEventListener is 'function'
      @mobileMediaQuery.addEventListener('change', @viewportModeListener)
    else if typeof @mobileMediaQuery.addListener is 'function'
      @mobileMediaQuery.addListener(@viewportModeListener)

  stopViewportWatcher: ->
    return if !@mobileMediaQuery || !@viewportModeListener

    if typeof @mobileMediaQuery.removeEventListener is 'function'
      @mobileMediaQuery.removeEventListener('change', @viewportModeListener)
    else if typeof @mobileMediaQuery.removeListener is 'function'
      @mobileMediaQuery.removeListener(@viewportModeListener)

    @viewportModeListener = null

  bindRouteWatcher: ->
    @routeWatcher = => @syncMobileShellState(@mobileView)
    $(window).on('hashchange.domServisDispatchMobileShell', @routeWatcher)

  stopRouteWatcher: ->
    return if !@routeWatcher
    $(window).off('hashchange.domServisDispatchMobileShell', @routeWatcher)
    @routeWatcher = null

  syncViewportMode: ->
    nextValue = @mobileMediaQuery?.matches || window.matchMedia('(max-width: 767px)').matches
    return if @mobileView is nextValue

    @mobileView = nextValue
    @mobileWorkspaceMenuOpen = false if !@mobileView
    @render()

  syncMobileShellState: (enabled) ->
    dispatchRouteActive = App.MobileDetection.desktopShellRequiredForHash(window.location.hash)
    $('body').toggleClass('dom-servis-dispatch-mobile-shell', enabled is true and dispatchRouteActive)

  openMobileAccountMenu: (e) =>
    return if !@mobileView
    @preventDefaultAndStopPropagation(e)
    @mobileWorkspaceMenuOpen = true
    @render()

  closeMobileAccountMenu: (e) =>
    @preventDefaultAndStopPropagation(e) if e
    return if !@mobileWorkspaceMenuOpen
    @mobileWorkspaceMenuOpen = false
    @render()

  navigateFromMobileWorkspaceMenu: (e) =>
    @preventDefaultAndStopPropagation(e)
    target = $(e.currentTarget).data('target')?.toString()?.trim()
    return if !target

    @mobileWorkspaceMenuOpen = false
    @render()

    if target is '#logout'
      window.location.hash = target
      return

    @navigate(target)

  loadJobs: (options = {}) =>
    if options.manualRefresh
      @pendingRealtimeRefresh = false
      if @realtimeRefreshDelayId
        @clearDelay(@realtimeRefreshDelayId)
        @realtimeRefreshDelayId = null

    @loading = true
    @errorMessage = null
    @render()

    @ajax(
      id: 'dom_servis_dispatch_board_index'
      type: 'GET'
      url: "#{@apiPath}/dom_servis/dispatch/jobs"
      data:
        expand: true
        per_page: 200
        sort_by: 'created_at,id'
        order_by: 'DESC,DESC'
      processData: true
      success: (data) =>
        @jobs = @sortJobs(data || [])
        @loading = false
        @render()
        @flushPendingRealtimeRefresh()
      error: (xhr) =>
        @jobs = []
        @loading = false
        @errorMessage = @extractError(xhr, 'Не удалось загрузить заявки диспетчеризации.')
        @render()
        @flushPendingRealtimeRefresh()
    )

  bindDispatchBoardRealtimeRefresh: ->
    @controllerBind('DomServisDispatchJob:create DomServisDispatchJob:update DomServisDispatchJob:destroy DomServisDispatchJob:touch', =>
      @scheduleRealtimeRefresh()
    )

  scheduleRealtimeRefresh: =>
    @pendingRealtimeRefresh = true
    return if @createOpen || @editOpen
    return if @loading

    @realtimeRefreshDelayId = @delay(@performRealtimeRefresh, 1200, 'dom_servis_dispatch_jobs_realtime_refresh')

  performRealtimeRefresh: =>
    @realtimeRefreshDelayId = null
    return if @createOpen || @editOpen

    @pendingRealtimeRefresh = false
    @loadJobs(manualRefresh: true)

  flushPendingRealtimeRefresh: =>
    return if !@pendingRealtimeRefresh
    return if @createOpen || @editOpen
    return if @loading

    @scheduleRealtimeRefresh()

  loadEffectivePolicy: =>
    @ajax(
      id: 'dom_servis_dispatch_effective_policy'
      type: 'GET'
      url: "#{@apiPath}/dom_servis/dispatch/policy"
      success: (data) =>
        data ||= {}
        @policyRegistry = data.registry || {}
        @policySettings = data.settings || {}
        @effectivePolicy =
          role_key: data.role_key
          actions: data.actions || {}
          statuses: data.statuses || {}
          fields: data.fields || {}
          settings: data.settings || {}
        @render() if !@loading
      error: =>
        @policyRegistry = {}
        @policySettings = {}
        @effectivePolicy = null
        @render() if !@loading
    )

  loadTags: =>
    @ajax(
      id: 'dom_servis_dispatch_tags'
      type: 'GET'
      url: "#{@apiPath}/dom_servis/dispatch/tags"
      success: (data) =>
        @availableTags = data?.tags || []
        @render() if !@loading
      error: =>
        @availableTags = []
        @render() if !@loading
    )

  loadOrganizations: =>
    @ajax(
      id: 'dom_servis_dispatch_organizations'
      type: 'GET'
      url: "#{@apiPath}/organizations"
      data:
        per_page: 200
        sort_by: 'name'
        order_by: 'ASC'
      processData: true
      success: (data) =>
        organizations = data
        if data?.assets?.Organization
          organizations = data.assets.Organization

        organizations ||= []
        if _.isObject(organizations) && !_.isArray(organizations)
          organizations = _.values(organizations)

        @organizations = _.sortBy(_.map(organizations, (organization) ->
          id: organization.id
          name: organization.name
        ), (organization) -> "#{organization.name || ''}".toLowerCase())
        @organizationsLoaded = true
        @render() if !@loading
      error: =>
        @organizations = []
        @organizationsLoaded = true
        @render() if !@loading
    )

  loadAttachments: (jobId, force = false) =>
    return if !jobId

    key = "#{jobId}"
    if !force && @attachmentCollections[key]?
      return

    @attachmentLoading[key] = true
    @render() if @detailOpen && "#{@detailJobId}" is key

    @ajax(
      id: "dom_servis_dispatch_attachments_#{jobId}"
      type: 'GET'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{jobId}/attachments"
      success: (data) =>
        @attachmentCollections[key] = data || []
        @attachmentLoading[key] = false
        @render()
      error: =>
        @attachmentCollections[key] = []
        @attachmentLoading[key] = false
        @notify(type: 'error', msg: 'Не удалось загрузить вложения заявки.', timeout: 4000)
        @render()
    )

  refreshJobs: (e) =>
    @preventDefault(e)
    @loadEffectivePolicy()
    @loadTags()
    @loadJobs(manualRefresh: true)

  setStatusFilter: (e) =>
    @preventDefault(e)
    @statusFilter = $(e.currentTarget).data('filter')
    @render()

  setDayFilter: (e) =>
    @preventDefault(e)
    @dayFilter = $(e.currentTarget).data('filter')
    @render()

  toggleTagFilter: (e) =>
    @preventDefaultAndStopPropagation(e)
    tagName = $(e.currentTarget).data('tag')?.toString()?.trim()
    return if !tagName

    if _.contains(@activeTagFilters, tagName)
      @activeTagFilters = _.without(@activeTagFilters, tagName)
    else
      @activeTagFilters = @activeTagFilters.concat([tagName])

    @render()

  clearTagFilters: (e) =>
    @preventDefaultAndStopPropagation(e)
    @activeTagFilters = []
    @render()

  shiftWeek: (e) =>
    @preventDefault(e)
    offset = parseInt($(e.currentTarget).data('offset'), 10) || 0
    @selectedWeekStart = @shiftDate(@selectedWeekStartDate(), offset * 7)
    @dayFilter = 'all'
    @render()

  resetWeek: (e) =>
    @preventDefault(e)
    @selectedWeekStart = @startOfWeek(new Date())
    @dayFilter = 'all'
    @render()

  pickWeek: (e) =>
    pickedDate = @parseDateValue($(e.currentTarget).val())
    return if !pickedDate

    @selectedWeekStart = @startOfWeek(pickedDate)
    @dayFilter = 'all'
    @render()

  openCreate: (e) =>
    @preventDefaultAndStopPropagation(e)
    return if !@canCreatePublishedJob()
    @resetCreateDraft()
    @resetCreateAttachmentDraft()
    @editOpen = false
    @editingJobId = null
    @detailOpen = false
    @detailJobId = null
    @createOpen = true
    @render()

  closeCreate: (e) =>
    @preventDefaultAndStopPropagation(e)
    @createOpen = false
    @resetCreateDraft()
    @resetCreateAttachmentDraft()
    @render()
    @flushPendingRealtimeRefresh()

  openDetailFromCard: (e) =>
    return if $(e.target).closest('.js-no-detail').length > 0

    id = $(e.currentTarget).data('id')
    job = @findJob(id)
    return if !job

    @createOpen = false
    @editOpen = false
    @editingJobId = null
    @detailOpen = true
    @detailJobId = job.id
    @detailAssignAssigneeId = if job.assignee_id? then "#{job.assignee_id}" else ''
    @loadAttachments(job.id)
    @render()

  closeDetail: (e) =>
    @preventDefaultAndStopPropagation(e) if e
    @detailOpen = false
    @detailJobId = null
    @detailAssignAssigneeId = null
    @editOpen = false
    @editingJobId = null
    @editSaving = false
    @render()

  openEdit: (e) =>
    @preventDefaultAndStopPropagation(e)
    id = $(e.currentTarget).data('id')
    job = @findJob(id)
    return if !job
    return if !@canOpenEdit(job)

    @createOpen = false
    @detailOpen = true
    @detailJobId = job.id
    @editingJobId = job.id
    @editOpen = true
    @editSaving = false
    @detailAssignAssigneeId = if job.assignee_id? then "#{job.assignee_id}" else ''
    @loadAttachments(job.id)
    @render()

  closeEdit: (e) =>
    @preventDefaultAndStopPropagation(e) if e
    @editOpen = false
    @editingJobId = null
    @editSaving = false
    @render()
    @flushPendingRealtimeRefresh()

  createJob: (e) =>
    e.preventDefault()
    return if !@canCreatePublishedJob()

    payload = @createPayload()
    return if !payload

    @formDisable(@$('.js-create-job'), 'button')

    @ajax(
      id: 'dom_servis_dispatch_create_job'
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs"
      data: JSON.stringify(payload)
      processData: true
      success: (data) =>
        @finishCreatedJob(data, payload)
      error: (xhr) =>
        @formEnable(@$('.js-create-job'), 'button')
        @notify(
          type: 'error'
          msg: @extractError(xhr, 'Заявку не удалось создать.')
          timeout: 6000
        )
    )
    return

    job = new App.DomServisDispatchJob(payload)
    ui = @

    job.save(
      done: ->
        ui.finishCreatedJob(job, payload)
        return
        ui.notify(
          type: 'success'
          msg: 'Заявка создана и опубликована в пул.'
          timeout: 3000
        )
        ui.createOpen = false
        ui.dayFilter = payload.visit_day || 'all'
        ui.selectedWeekStart = ui.startOfWeek(ui.parseDateValue(payload.visit_date) || new Date())
        ui.loadJobs(manualRefresh: true)
      fail: (settings, details) ->
        ui.formEnable(ui.$('.js-create-job'), 'button')
        ui.notify(
          type: 'error'
          msg: details.error_human || details.error || 'Заявку не удалось создать.'
          timeout: 6000
        )
    )

  finishCreatedJob: (job, payload) =>
    persistedJobId = @resolvePersistedJobId(job, payload)

    finalizeSuccess = =>
      @notify(
        type: 'success'
        msg: 'Заявка создана и опубликована в пул.'
        timeout: 3000
      )
      @createOpen = false
      @resetCreateDraft()
      @resetCreateAttachmentDraft()
      @dayFilter = payload.visit_day || 'all'
      @selectedWeekStart = @startOfWeek(@parseDateValue(payload.visit_date) || new Date())
      @loadJobs(manualRefresh: true)

    finalizePartialFailure = =>
      @notify(
        type: 'error'
        msg: 'Заявка создана, но вложения не загрузились. Их можно добавить потом в карточке заявки.'
        timeout: 7000
      )
      @createOpen = false
      @resetCreateDraft()
      @resetCreateAttachmentDraft()
      @dayFilter = payload.visit_day || 'all'
      @selectedWeekStart = @startOfWeek(@parseDateValue(payload.visit_date) || new Date())
      @loadJobs(manualRefresh: true)

    if @createAttachmentFiles.length < 1
      finalizeSuccess()
      return

    @createAttachmentUploading = true
    @render()

    if !persistedJobId
      finalizePartialFailure()
      return

    @uploadAttachmentBatch(persistedJobId, @createAttachmentFiles, @createAttachmentKind)
      .done =>
        @createAttachmentUploading = false
        finalizeSuccess()
      .fail =>
        @createAttachmentUploading = false
        finalizePartialFailure()

  triggerCreateAttachmentUpload: (e) =>
    @preventDefaultAndStopPropagation(e)
    @$('.js-create-attachment-input').trigger('click')

  selectCreateAttachments: (e) =>
    @syncCreateDraftFromForm()
    input = $(e.currentTarget)
    files = _.toArray(input.prop('files') || [])
    return if files.length < 1

    @createAttachmentFiles = @createAttachmentFiles.concat(files)
    input.val('')
    @render()

  removeCreateAttachment: (e) =>
    @preventDefaultAndStopPropagation(e)
    @syncCreateDraftFromForm()
    index = parseInt($(e.currentTarget).data('index'), 10)
    return if _.isNaN(index) || !@createAttachmentFiles[index]?

    @createAttachmentFiles.splice(index, 1)
    @render()

  changeCreateAttachmentKind: (e) =>
    @createAttachmentKind = $(e.currentTarget).val() || 'intake_attachment'

  resetCreateDraft: ->
    defaultVisitDay = @defaultVisitDay()
    privateOrganizationId = @privateOrganizationId()

    @createDraft =
      service_type: ''
      address: ''
      client_name: ''
      client_phone: ''
      visit_day: defaultVisitDay
      visit_date: @formatDateInput(@nextDateForDay(defaultVisitDay))
      visit_time: ''
      priority: 'medium'
      organization_id: if privateOrganizationId? then "#{privateOrganizationId}" else ''
      work_tags: ''
      description: ''
      comment: ''

  syncCreateDraftFromForm: ->
    return if !@createOpen

    read = (selector) =>
      @$(selector).val()?.toString() || ''

    @createDraft =
      service_type: read('.js-create-service-type').trim()
      address: read('.js-create-address').trim()
      client_name: read('.js-create-client-name').trim()
      client_phone: read('.js-create-client-phone').trim()
      visit_day: read('.js-create-visit-day').trim() || @createDraft.visit_day || @defaultVisitDay()
      visit_date: read('.js-create-visit-date').trim() || @createDraft.visit_date || @formatDateInput(@nextDateForDay(@defaultVisitDay()))
      visit_time: read('.js-create-visit-time').trim()
      priority: read('.js-create-priority').trim() || 'medium'
      organization_id: read('.js-create-organization-id').trim() || @createDraft.organization_id || "#{@privateOrganizationId() || ''}"
      work_tags: read('.js-create-work-tags').trim()
      description: read('.js-create-description').trim()
      comment: read('.js-create-comment').trim()

  updateCreateDraft: ->
    @syncCreateDraftFromForm()

  toggleCreateTag: (e) =>
    @preventDefaultAndStopPropagation(e)
    @syncCreateDraftFromForm()

    button = $(e.currentTarget)
    tagName = button.data('tag')?.toString()?.trim()
    return if !tagName

    tags = @parseTags(@createDraft.work_tags)
    tags = if _.contains(tags, tagName) then _.without(tags, tagName) else tags.concat([tagName])

    @createDraft.work_tags = tags.join(', ')
    @$('.js-create-work-tags').val(@createDraft.work_tags)
    @updateTagToggleGroup(button.closest('.dom-servis-dispatch-tag-selector'), tags)

  formatDateInput: (dateValue) ->
    return '' if !dateValue

    date = @parseDateValue(dateValue) || dateValue
    return '' if !date || !date.getFullYear

    year = "#{date.getFullYear()}"
    month = "#{date.getMonth() + 1}".padStart(2, '0')
    day = "#{date.getDate()}".padStart(2, '0')
    "#{year}-#{month}-#{day}"

  resetCreateAttachmentDraft: ->
    @createAttachmentFiles = []
    @createAttachmentUploading = false
    @createAttachmentKind = 'intake_attachment'

  buildCreateAttachmentDraft: ->
    _.map @createAttachmentFiles, (file, index) ->
      index: index
      name: file.name
      size: file.size

  resolvePersistedJobId: (job, payload) ->
    directId = parseInt(job?.id, 10)
    return directId if !_.isNaN(directId) && directId > 0

    persistedByCode = null
    if job?.job_code
      persistedByCode = App.DomServisDispatchJob.findByAttribute('job_code', job.job_code)
      persistedId = parseInt(persistedByCode?.id, 10)
      return persistedId if !_.isNaN(persistedId) && persistedId > 0

    candidates = App.DomServisDispatchJob.select (item) ->
      item.service_type is payload.service_type &&
        item.address is payload.address &&
        item.client_phone is payload.client_phone &&
        item.visit_date is payload.visit_date

    latestCandidate = _.last(_.sortBy(candidates, (item) -> item.created_at || ''))
    fallbackId = parseInt(latestCandidate?.id, 10)
    return fallbackId if !_.isNaN(fallbackId) && fallbackId > 0

    null

  saveEdit: (e) =>
    e.preventDefault()
    job = @currentEditJob()
    return if !job
    return if !@canOpenEdit(job)

    payload = @buildEditPayload(job)
    return if payload is false

    if _.isEmpty(payload)
      @notify(type: 'success', msg: 'Изменений нет.', timeout: 2500)
      return

    @editSaving = true
    @formDisable(@$('.js-save-edit'), 'button')

    @ajax(
      id: "dom_servis_dispatch_update_#{job.id}"
      type: 'PUT'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{job.id}"
      data: JSON.stringify(payload)
      processData: true
      success: =>
        @notify(type: 'success', msg: 'Заявка сохранена.', timeout: 3000)
        @editOpen = false
        @editingJobId = null
        @editSaving = false
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @editSaving = false
        @formEnable(@$('.js-save-edit'), 'button')
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось сохранить заявку.'), timeout: 6000)
    )

  setAssignAssignee: (e) =>
    @detailAssignAssigneeId = $(e.currentTarget).val()

  assignJob: (e) =>
    @preventDefault(e)
    return if !@actionAllowed('change_assignee')

    id = $(e.currentTarget).data('id') || @detailJobId
    assigneeId = @normalizeNumericId(@detailAssignAssigneeId)
    return if !id

    if !assigneeId
      @notify(type: 'error', msg: 'Выберите мастера для назначения.', timeout: 4000)
      return

    @ajax(
      id: "dom_servis_dispatch_assign_#{id}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/assign"
      data: JSON.stringify(assignee_id: assigneeId)
      processData: true
      success: =>
        @notify(type: 'success', msg: 'Мастер назначен.', timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось назначить мастера.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  takeJob: (e) =>
    @preventDefault(e)
    return if !@actionAllowed('take_job')
    id = $(e.currentTarget).data('id')
    return if !id

    @ajax(
      id: "dom_servis_dispatch_take_#{id}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/take"
      success: =>
        @notify(type: 'success', msg: 'Заявка взята в работу.', timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось взять заявку.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  releaseJob: (e) =>
    @preventDefault(e)
    return if !@actionAllowed('release_to_pool')
    id = $(e.currentTarget).data('id')
    return if !id

    @ajax(
      id: "dom_servis_dispatch_release_#{id}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/release"
      success: =>
        @notify(type: 'success', msg: 'Заявка возвращена в пул.', timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось вернуть заявку в пул.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  setStatus: (e) =>
    @preventDefault(e)
    id = $(e.currentTarget).data('id')
    status = $(e.currentTarget).data('status')
    return if !id || !status
    return if !@statusAllowed(status)

    @ajax(
      id: "dom_servis_dispatch_status_#{id}_#{status}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/status"
      data: JSON.stringify(status: status)
      processData: true
      success: =>
        @notify(type: 'success', msg: "Статус обновлён: #{@statusLabel(status)}.", timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось обновить статус.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  changePriority: (e) =>
    id = $(e.currentTarget).data('id')
    priority = $(e.currentTarget).val()
    return if !id || !priority
    return if !@actionAllowed('change_priority')

    @ajax(
      id: "dom_servis_dispatch_priority_#{id}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/change_priority"
      data: JSON.stringify(priority: priority)
      processData: true
      success: =>
        @notify(type: 'success', msg: 'Приоритет обновлён.', timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось обновить приоритет.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  changeVisitDay: (e) =>
    id = $(e.currentTarget).data('id')
    visitDay = $(e.currentTarget).val()
    return if !id || !visitDay
    return if !@actionAllowed('move_job_day')

    @ajax(
      id: "dom_servis_dispatch_move_day_#{id}"
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{id}/move_day"
      data: JSON.stringify(
        visit_day: visitDay
        visit_date: @nextDateForDay(visitDay)
      )
      processData: true
      success: =>
        @notify(type: 'success', msg: "Заявка перенесена на #{@weekdayLabel(visitDay)}.", timeout: 3000)
        @loadJobs(manualRefresh: true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось перенести заявку.'), timeout: 6000)
        @loadJobs(manualRefresh: true)
    )

  createPayload: ->
    @syncCreateDraftFromForm()

    serviceType = @createDraft.service_type
    address = @createDraft.address
    clientPhone = @createDraft.client_phone
    visitDay = @createDraft.visit_day
    visitDate = @createDraft.visit_date

    if !serviceType
      @notify(type: 'error', msg: 'Укажи тип работ.', timeout: 4000)
      return null

    if !address
      @notify(type: 'error', msg: 'Укажи адрес.', timeout: 4000)
      return null

    if !clientPhone
      @notify(type: 'error', msg: 'Укажи телефон клиента.', timeout: 4000)
      return null

    if !visitDay
      @notify(type: 'error', msg: 'Выбери день недели.', timeout: 4000)
      return null

    {
      service_type: serviceType
      address: address
      client_name: @createDraft.client_name
      client_phone: clientPhone
      organization_id: @normalizeNumericId(@createDraft.organization_id) || @privateOrganizationId()
      visit_day: visitDay
      visit_date: visitDate || @nextDateForDay(visitDay)
      visit_time: @createDraft.visit_time
      priority: @createDraft.priority || 'medium'
      description: @createDraft.description
      comment: @createDraft.comment
      work_tags: @parseTags(@createDraft.work_tags)
      status: 'pool'
      source: 'manual'
    }

  buildEditPayload: (job) ->
    payload = {}

    _.each @editableEditFields(job), (field) =>
      input = @$(".js-edit-field[data-field='#{field.key}']")
      return if input.length < 1

      value = @readEditValue(field, input)
      normalized = @normalizeEditValue(field.key, value)
      return if !@fieldValueChanged(job, field.key, normalized)

      payload[field.key] = normalized

    @normalizeSchedulePayload(job, payload)

  normalizeSchedulePayload: (job, payload) ->
    return payload if _.isEmpty(payload)

    if payload.visit_date?
      payload.visit_day = @weekdayKeyFromDate(payload.visit_date)

    if payload.visit_day? && !payload.visit_date?
      payload.visit_date = @nextDateForDay(payload.visit_day)

    payload

  readEditValue: (field, input) ->
    switch field.type
      when 'textarea'
        input.val()?.trim()
      when 'tag_selector'
        input.val()?.trim()
      when 'user_select', 'organization_select'
        input.val()
      when 'select'
        input.val()
      when 'date', 'time'
        input.val()?.trim()
      else
        input.val()?.trim()

  normalizeEditValue: (fieldKey, value) ->
    switch fieldKey
      when 'work_tags'
        @parseTags(value)
      when 'assignee_id', 'organization_id'
        return null if !value
        parseInt(value, 10)
      when 'client_name', 'client_phone', 'visit_time', 'description', 'comment', 'address', 'service_type', 'source', 'visit_date'
        value || ''
      else
        value

  toggleEditTag: (e) =>
    @preventDefaultAndStopPropagation(e)

    button = $(e.currentTarget)
    container = button.closest('.dom-servis-dispatch-tag-selector')
    hiddenInput = container.find(".js-edit-field[data-field='work_tags']")
    return if hiddenInput.length < 1

    tagName = button.data('tag')?.toString()?.trim()
    return if !tagName

    tags = @parseTags(hiddenInput.val())
    tags = if _.contains(tags, tagName) then _.without(tags, tagName) else tags.concat([tagName])

    hiddenInput.val(tags.join(', '))
    @updateTagToggleGroup(container, tags)

  fieldValueChanged: (job, fieldKey, nextValue) ->
    currentValue = @jobFieldValue(job, fieldKey)

    if fieldKey is 'work_tags'
      return !_.isEqual(@normalizeTags(currentValue).sort(), @normalizeTags(nextValue).sort())

    if fieldKey in ['assignee_id', 'organization_id']
      currentId = if currentValue? then parseInt(currentValue, 10) else null
      nextId = if nextValue? then parseInt(nextValue, 10) else null
      return currentId isnt nextId

    "#{currentValue || ''}" isnt "#{nextValue || ''}"

  buildStats: ->
    currentUserId = App.User.current()?.id
    weekJobs = @jobsForSelectedWeek()

    {
      total: _.size(weekJobs)
      pool: _.filter(weekJobs, (job) -> job.status is 'pool').length
      active: _.filter(weekJobs, (job) -> job.status in ['taken', 'in_progress']).length
      mine: _.filter(weekJobs, (job) -> job.assignee_id is currentUserId).length
      mineActive: _.filter(weekJobs, (job) -> job.assignee_id is currentUserId && job.status in ['taken', 'in_progress']).length
      done: _.filter(weekJobs, (job) -> job.status is 'done').length
      today: _.filter(weekJobs, (job) => @isToday(job)).length
      availableToday: _.filter(weekJobs, (job) => job.status is 'pool' && @isToday(job)).length
    }

  buildScopedStatusFilters: ->
    weekJobs = @jobsForSelectedWeek()

    [
      { id: 'open', label: 'Открытые', count: _.filter(weekJobs, (job) -> job.status in ['pool', 'taken', 'in_progress']).length }
      { id: 'pool', label: 'Пул', count: _.filter(weekJobs, (job) -> job.status is 'pool').length }
      { id: 'active', label: 'В работе', count: _.filter(weekJobs, (job) -> job.status in ['taken', 'in_progress']).length }
      { id: 'mine', label: 'Мои', count: _.filter(weekJobs, (job) -> job.assignee_id is App.User.current()?.id).length }
      { id: 'done', label: 'Готово', count: _.filter(weekJobs, (job) -> job.status is 'done').length }
      { id: 'all', label: 'Все', count: _.size(weekJobs) }
    ].map (item) =>
      item.active = item.id is @statusFilter
      item

  buildWeekControls: ->
    startDate = @selectedWeekStartDate()
    endDate = @shiftDate(startDate, 6)

    {
      startLabel: @formatDate(startDate)
      endLabel: @formatDate(endDate)
      startShortLabel: @formatDayMonth(startDate)
      endShortLabel: @formatDayMonth(endDate)
      pickerValue: @formatDateValue(startDate)
      isCurrent: @isCurrentWeek(startDate)
    }

  buildDayFilters: ->
    filters = [{ id: 'all', label: 'Все дни', count: _.size(@jobsForStatusFilter()) }]

    _.each @weekdayItems(), (item) =>
      count = _.filter(@jobsForStatusFilter(), (job) => @jobVisitDay(job) is item.id).length
      filters.push({ id: item.id, label: item.label, count: count, shortLabel: item.shortLabel })

    _.map filters, (item) =>
      item.active = item.id is @dayFilter
      item

  buildTagFilters: ->
    tagsByName = {}
    baseJobs = @jobsForDayAndStatusFilters()

    _.each baseJobs, (job) =>
      _.each @normalizeTags(job.work_tags), (tagName) ->
        tagsByName[tagName] ?= 0
        tagsByName[tagName] += 1

    _.each @activeTagFilters, (tagName) ->
      tagsByName[tagName] ?= 0

    _.chain(tagsByName)
      .map((count, tagName) =>
        {
          id: tagName
          label: tagName
          count: count
          active: _.contains(@activeTagFilters, tagName)
        }
      )
      .sortBy((item) -> item.label.toLowerCase())
      .sortBy((item) -> -item.count)
      .sortBy((item) -> if item.active then 0 else 1)
      .value()

  buildActiveFilterSummary: ->
    items = []

    statusItem = _.find(@buildScopedStatusFilters(), (item) -> item.active)
    if statusItem?.id && statusItem.id isnt 'open'
      items.push(statusItem.label)

    dayItem = _.find(@buildDayFilters(), (item) -> item.active)
    if dayItem?.id && dayItem.id isnt 'all'
      items.push(dayItem.label)

    items = items.concat(@activeTagFilters) if @activeTagFilters.length > 0
    items

  buildMobileShell: ->
    stats = @buildStats()
    weekControls = @buildWeekControls()
    statusFilters = @buildScopedStatusFilters()
    currentStatus = _.find(statusFilters, (item) -> item.active) || statusFilters[0] || {}
    filteredCount = @filteredJobs().length
    workspaceFilters = @buildMobileWorkspaceFilters(statusFilters)

    {
      title: @mobileQueueTitle(currentStatus.id)
      subtitle: @mobileQueueSubtitle(currentStatus.id)
      activeStatusLabel: currentStatus.label || 'Заявки'
      filteredCountLabel: @jobsCountLabel(filteredCount)
      workspaceFilters: workspaceFilters
      contextBadges: @buildMobileContextBadges(weekControls, stats)
      controlsOpen: @mobileControlsOpen(workspaceFilters, currentStatus.id, weekControls)
      telemetry: [
        { label: 'Мои в работе', value: stats.mineActive }
        { label: 'В пуле', value: stats.pool }
        { label: 'На сегодня', value: stats.today }
      ]
    }

  buildMobileWorkspaceFilters: (statusFilters = @buildScopedStatusFilters()) ->
    preferredIds = if @masterAccess()
      ['mine', 'pool', 'active', 'done']
    else
      ['open', 'mine', 'pool', 'active', 'done', 'all']

    _.chain(statusFilters)
      .filter((item) -> _.contains(preferredIds, item.id))
      .sortBy((item) -> preferredIds.indexOf(item.id))
      .value()

  buildMobileContextBadges: (weekControls = @buildWeekControls(), stats = @buildStats()) ->
    badges = [
      {
        id: 'week'
        tone: 'week'
        label: "Неделя: #{weekControls.startLabel} - #{weekControls.endLabel}"
      }
    ]

    activeSummary = @buildActiveFilterSummary()
    if activeSummary.length > 0
      badges.push(
        id: 'filters'
        tone: 'filters'
        label: activeSummary.join(' / ')
      )

    if @statusFilter is 'pool' && stats.availableToday > 0
      badges.push(
        id: 'today'
        tone: 'today'
        label: "Сегодня в пуле: #{stats.availableToday}"
      )

    badges

  mobileControlsOpen: (workspaceFilters = @buildMobileWorkspaceFilters(), activeStatusId = @statusFilter, weekControls = @buildWeekControls()) ->
    preferredIds = _.pluck(workspaceFilters, 'id')
    return true if !_.contains(preferredIds, activeStatusId)
    return true if @dayFilter isnt 'all'
    return true if @activeTagFilters.length > 0
    !weekControls.isCurrent

  mobileQueueTitle: (statusId) ->
    switch statusId
      when 'mine' then 'Мои заявки'
      when 'pool' then 'Заявки из пула'
      when 'active' then 'Текущая работа'
      when 'done' then 'Завершённые заявки'
      when 'all' then 'Все заявки недели'
      else 'Рабочая доска'

  mobileQueueSubtitle: (statusId) ->
    switch statusId
      when 'mine' then 'Сразу видно, что уже на тебе и что нужно довести до конца.'
      when 'pool' then 'Здесь берут свободные заявки без перехода в ticket-first сценарий.'
      when 'active' then 'Фокус только на заявках, которые сейчас требуют действия.'
      when 'done' then 'Проверка того, что уже закрыто и больше не отвлекает.'
      else 'Мобильный shell собран вокруг работы мастера, а не вокруг оболочки системы.'

  jobsCountLabel: (count) ->
    return 'Нет заявок' if count < 1
    return '1 заявка' if count is 1
    return "#{count} заявки" if count in [2, 3, 4]
    "#{count} заявок"

  buildMobileBoardSummary: ->
    stats = @buildStats()
    "#{stats.mineActive} в работе • #{stats.pool} в пуле"

  buildMobileWeekDays: ->
    _.map @weekdayItems(), (item) =>
      date = @dateForDayInWeek(item.id)
      count = _.filter(@jobsForStatusFilter(), (job) => @jobVisitDay(job) is item.id).length
      {
        id: item.id
        label: item.label
        shortLabel: item.shortLabel
        count: count
        active: item.id is @dayFilter
        hasLoad: count > 0
        isToday: @isTodayDate(date)
        dateNumber: @dayOfMonth(date)
      }

  buildMobileTagSummary: ->
    return 'Все теги' if @activeTagFilters.length < 1
    @activeTagFilters.join(' / ')

  buildEmptyState: ->
    if @masterAccess() && @statusFilter is 'mine'
      return {
        title: 'У вас нет активных заявок.'
        body: 'Переключитесь на пул или измените день, чтобы взять следующую заявку.'
      }

    if @statusFilter is 'pool'
      return {
        title: 'В пуле сейчас нет доступных заявок.'
        body: 'Смените неделю или день, чтобы проверить другой срез.'
      }

    {
      title: 'По текущему срезу заявок нет.'
      body: 'Смените неделю или фильтр, либо создайте первую заявку в пул.'
    }

  mobileLabels: ->
    {
      week: 'Неделя'
      filters: 'Фильтры'
      refreshAction: 'Обновить заявки'
      accountActionsHint: 'Профиль, разделы и выход'
      accountActionsArrow: '→'
      accountMenuEyebrow: 'Рабочее меню'
      accountMenuTitle: 'Аккаунт и разделы'
      profileAction: 'Учётная запись'
      dashboardAction: 'Главная Zammad'
      logoutAction: 'Выйти'
      closeAction: 'Закрыть'
      openDetailsHint: 'Касание по карточке откроет все детали.'
    }

  buildJobCards: ->
    currentUserId = App.User.current()?.id
    dispatcherAccess = @dispatcherAccess()
    adminAccess = @adminAccess()
    masterAccess = @masterAccess()

    _.map @filteredJobs(), (job) =>
      assigneeName = @resolveAssigneeName(job)
      visitDay = @jobVisitDay(job)
      deadlineState = @jobDeadlineState(job)
      canOperate = dispatcherAccess || job.assignee_id is currentUserId

      card =
        id: job.id
        jobCode: job.job_code || @fallbackJobCode(job)
        serviceType: job.service_type || 'Без названия'
        address: job.address || 'Адрес не указан'
        clientName: job.client_name || 'Клиент не указан'
        clientPhone: job.client_phone || ''
        visitDate: job.visit_date || ''
        visitTime: job.visit_time || ''
        visitDay: visitDay
        visitDayLabel: @weekdayLabel(visitDay)
        scheduleLabel: @scheduleLabel(job)
        priority: job.priority || 'medium'
        priorityLabel: @priorityLabel(job.priority)
        status: job.status || 'pool'
        statusLabel: @statusLabel(job.status)
        deadlineState: deadlineState?.state || null
        deadlineLabel: deadlineState?.label || null
        assigneeName: assigneeName
        summaryText: @jobSummaryText(job)
        visibleTags: @tagBadgeItems(job.work_tags, 2)
        moreTagsCount: Math.max(@normalizeTags(job.work_tags).length - 2, 0)
        canTake: job.status is 'pool' && @actionAllowed('take_job')
        canRelease: job.assignee_id? && canOperate && @actionAllowed('release_to_pool')
        canStart: canOperate && job.status is 'taken' && @actionAllowed('set_status_in_progress') && @statusAllowed('in_progress')
        canFinish: canOperate && job.status in ['taken', 'in_progress'] && @actionAllowed('set_status_done') && @statusAllowed('done')
        canCancel: dispatcherAccess && job.status in ['pool', 'taken', 'in_progress'] && @actionAllowed('cancel_job') && @statusAllowed('cancelled')
        canEdit: @canOpenEdit(job)
        adminAccess: adminAccess
        masterAccess: masterAccess
      card.primaryAction = @buildCardPrimaryAction(card)
      card

  buildCardPrimaryAction: (card) ->
    return null if !card

    if card.canTake
      return { label: 'Взять', buttonClass: 'btn--success', handlerClass: 'js-take-job' }

    if card.canStart
      return { label: 'В работу', buttonClass: 'btn--primary', handlerClass: 'js-set-status', status: 'in_progress' }

    if card.canFinish
      return { label: 'Готово', buttonClass: 'btn--success', handlerClass: 'js-set-status', status: 'done' }

    if card.canRelease
      return { label: 'В пул', buttonClass: 'btn--text', handlerClass: 'js-release-job' }

    if card.canEdit
      return { label: 'Редактировать', buttonClass: 'btn--text', handlerClass: 'js-open-edit' }

    null

  buildEditJobView: (job) ->
    return null if !job

    {
      id: job.id
      jobCode: job.job_code || @fallbackJobCode(job)
      title: job.service_type || 'Без названия'
      statusLabel: @statusLabel(job.status)
      scheduleLabel: @scheduleLabel(job)
    }

  detailEditing: ->
    return false if !@detailOpen || !@editOpen
    return false if !@detailJobId || !@editingJobId
    "#{@detailJobId}" is "#{@editingJobId}"

  buildDetailJobView: (job) ->
    return null if !job

    tags = @normalizeTags(job.work_tags)
    currentUserId = App.User.current()?.id
    canOperate = @dispatcherAccess() || job.assignee_id is currentUserId
    deadlineState = @jobDeadlineState(job)
    assignOptions = @masterAssigneeOptions()
    canAssign = @dispatcherAccess() && @actionAllowed('change_assignee') && assignOptions.length > 0
    canTransfer = @dispatcherAccess() && @actionAllowed('transfer_to_partner') && @statusAllowed('transferred_to_partner') && job.status in ['pool', 'taken', 'in_progress']

    {
      id: job.id
      jobCode: job.job_code || @fallbackJobCode(job)
      title: job.service_type || 'Без названия'
      serviceType: job.service_type || 'Без названия'
      address: job.address || 'Адрес не указан'
      clientName: job.client_name || 'Клиент не указан'
      clientPhone: job.client_phone || ''
      organizationName: @resolveOrganizationName(job)
      status: job.status || 'pool'
      statusLabel: @statusLabel(job.status)
      statusClass: job.status || 'pool'
      priority: job.priority || 'medium'
      priorityLabel: @priorityLabel(job.priority)
      scheduleLabel: @scheduleLabel(job)
      deadlineState: deadlineState?.state || null
      deadlineLabel: deadlineState?.label || null
      assigneeName: @resolveAssigneeName(job)
      assigneeOptions: assignOptions
      assignAssigneeId: @detailAssignAssigneeId || if job.assignee_id? then "#{job.assignee_id}" else ''
      visibleTags: @tagBadgeItems(tags, 4)
      hiddenTagsCount: Math.max(tags.length - 4, 0)
      description: job.description || ''
      comment: job.comment || ''
      canEdit: @canOpenEdit(job)
      canAssign: canAssign
      canTransfer: canTransfer
      canTake: job.status is 'pool' && @actionAllowed('take_job')
      canRelease: job.assignee_id? && canOperate && @actionAllowed('release_to_pool')
      canStart: canOperate && job.status is 'taken' && @actionAllowed('set_status_in_progress') && @statusAllowed('in_progress')
      canFinish: canOperate && job.status in ['taken', 'in_progress'] && @actionAllowed('set_status_done') && @statusAllowed('done')
      canCancel: @dispatcherAccess() && job.status in ['pool', 'taken', 'in_progress'] && @actionAllowed('cancel_job') && @statusAllowed('cancelled')
    }

  buildDetailGroups: (job) ->
    return [] if !job

    [
      {
        id: 'job'
        label: 'Планирование'
        items: _.compact([
          @detailItem('Адрес', job.address, true)
          @detailItem('Дата визита', job.visit_date || 'Не указана')
          @detailItem('Время визита', job.visit_time || 'Не указано')
          @detailItem('День недели', @weekdayLabel(@jobVisitDay(job)))
          @detailItem('Статус', @statusLabel(job.status))
          @detailItem('Приоритет', @priorityLabel(job.priority))
          @detailItem('Исполнитель', @resolveAssigneeName(job))
        ])
      }
      {
        id: 'client'
        label: 'Клиент'
        items: _.compact([
          @detailItem('Имя', job.client_name || 'Не указано')
          @detailItem('Телефон', job.client_phone || 'Не указан')
          @detailItem('Заказчик', @resolveOrganizationName(job))
        ])
      }
      {
        id: 'content'
        label: 'Содержание'
        items: _.compact([
          @detailItem('Тип работ', job.service_type || 'Не указан')
          @detailItem('Теги', @normalizeTags(job.work_tags).join(', ') || 'Нет')
          @detailItem('Описание', job.description || 'Нет', true)
          @detailItem('Комментарий диспетчера', job.comment || 'Нет', true)
        ])
      }
      {
        id: 'meta'
        label: 'Системное'
        items: _.compact([
          @detailItem('Код заявки', job.job_code || @fallbackJobCode(job))
          @detailItem('Источник', @sourceLabel(job.source || 'manual'))
          @detailItem('Партнёр', job.request_source_label || job.request_source_partner_key || 'Не задан')
          @detailItem('Backing Ticket', job.ticket_id || 'Ещё не создан')
        ])
      }
    ]

  buildDrawerEditGroups: (job) ->
    return [] if !job

    _.chain(@buildEditGroups(job))
      .map((group) ->
        items = _.filter(group.items, (item) -> item.editable && !item.unsupported && item.key isnt 'attachments')
        return null if items.length < 1

        {
          key: group.key
          label: group.label
          items: items
        }
      )
      .compact()
      .value()

  detailItem: (label, value, wide = false) ->
    return null if !value? || value is ''

    {
      label: label
      value: value
      wide: wide
    }

  buildEditGroups: (job) ->
    return [] if !job

    groups = []
    registryGroups = @policyRegistry.field_groups || []
    fieldIndex = @registryFieldIndex()
    visibleKeys = []

    _.each registryGroups, (group) =>
      items = []
      _.each group.items || [], (entry) =>
        return if !@fieldVisible(entry.key)
        visibleKeys.push(entry.key)
        fieldItem = @buildEditFieldItem(job, entry.key, entry)
        items.push(fieldItem) if fieldItem

      if items.length > 0
        groups.push(
          key: group.key
          label: @fieldGroupLabel(group.key, group.label)
          items: items
        )

    _.each @defaultModalFieldOrder(), (fieldKey) =>
      return if _.contains(visibleKeys, fieldKey)
      return if !@fieldVisible(fieldKey)

      entry = fieldIndex[fieldKey] || { key: fieldKey, label: @fieldLabel(fieldKey), source: 'db', group: @fieldDefinition(fieldKey)?.group || 'other' }
      fieldItem = @buildEditFieldItem(job, fieldKey, entry)
      return if !fieldItem

      groupKey = fieldItem.group
      group = _.find(groups, (candidate) -> candidate.key is groupKey)

      if !group
        group =
          key: groupKey
          label: @fieldGroupLabel(groupKey)
          items: []
        groups.push(group)

      group.items.push(fieldItem)

    _.filter(groups, (group) -> group.items.length > 0)

  buildEditFieldItem: (job, fieldKey, entry = {}) ->
    definition = @fieldDefinition(fieldKey)
    source = entry.source || definition?.source || 'db'
    editable = @fieldEditableOnBoard(fieldKey)
    type = definition?.type || @defaultFieldType(fieldKey, source)
    unsupported = type is 'unsupported'

    {
      key: fieldKey
      label: @fieldLabel(fieldKey, entry.label)
      group: definition?.group || entry.group || 'other'
      type: type
      editable: editable && !unsupported
      unsupported: unsupported
      wide: definition?.wide == true
      value: @fieldInputValue(job, fieldKey)
      displayValue: @fieldDisplayValue(job, fieldKey, unsupported)
      options: if fieldKey is 'work_tags' then @availableTagOptions(@fieldInputValue(job, fieldKey)) else @fieldOptions(fieldKey)
      hint: @fieldHint(fieldKey, unsupported)
    }

  editableEditFields: (job) ->
    fields = []

    _.each @buildEditGroups(job), (group) ->
      _.each group.items, (item) ->
        fields.push(item) if item.editable

    fields

  canOpenEdit: (job) ->
    return false if !job
    return false if !@actionAllowed('edit_all_fields')

    _.some @buildDrawerEditGroups(job), (group) ->
      _.some group.items, (item) -> item.editable

  registryFieldIndex: ->
    result = {}

    _.each @policyRegistry.field_groups || [], (group) ->
      _.each group.items || [], (entry) ->
        result[entry.key] = entry

    result

  fieldDefinition: (fieldKey) ->
    definitions =
      id:
        type: 'readonly'
        group: 'identity'
      job_code:
        type: 'readonly'
        group: 'identity'
      source:
        type: 'select'
        group: 'identity'
      status:
        type: 'readonly'
        group: 'lifecycle'
      priority:
        type: 'select'
        group: 'lifecycle'
      visit_day:
        type: 'select'
        group: 'schedule'
      visit_date:
        type: 'date'
        group: 'schedule'
      visit_time:
        type: 'time'
        group: 'schedule'
      address:
        type: 'text'
        group: 'customer'
      client_name:
        type: 'text'
        group: 'customer'
      client_phone:
        type: 'text'
        group: 'customer'
      service_type:
        type: 'text'
        group: 'job_content'
      description:
        type: 'textarea'
        group: 'job_content'
        wide: true
      comment:
        type: 'textarea'
        group: 'job_content'
        wide: true
      work_tags:
        type: 'tag_selector'
        group: 'job_content'
        wide: true
      assignee_id:
        type: 'user_select'
        group: 'assignment'
      ticket_id:
        type: 'readonly'
        group: 'assignment'
      published_at:
        type: 'readonly'
        group: 'lifecycle'
      created_at:
        type: 'readonly'
        group: 'lifecycle'
      taken_at:
        type: 'readonly'
        group: 'lifecycle'
      updated_at:
        type: 'readonly'
        group: 'lifecycle'
      completed_at:
        type: 'readonly'
        group: 'lifecycle'
      cancelled_at:
        type: 'readonly'
        group: 'lifecycle'
      organization_id:
        type: 'organization_select'
        group: 'customer'
      attachments:
        type: 'unsupported'
        group: 'attachments'

    definitions[fieldKey]

  defaultFieldType: (fieldKey, source) ->
    return 'unsupported' if source is 'virtual'

    switch fieldKey
      when 'description', 'comment' then 'textarea'
      else 'text'

  fieldLabel: (fieldKey, fallback = null) ->
    labels =
      id: 'ID'
      job_code: 'Номер заявки'
      source: 'Источник'
      status: 'Статус'
      priority: 'Приоритет'
      visit_day: 'День недели'
      visit_date: 'Дата визита'
      visit_time: 'Время визита'
      address: 'Адрес'
      client_name: 'Клиент'
      client_phone: 'Телефон'
      service_type: 'Тип работ'
      description: 'Описание задачи'
      comment: 'Комментарий диспетчера'
      work_tags: 'Теги работ'
      assignee_id: 'Исполнитель'
      ticket_id: 'Связанная заявка Zammad'
      published_at: 'Опубликована'
      created_at: 'Создана'
      taken_at: 'Взята'
      updated_at: 'Обновлена'
      completed_at: 'Завершена'
      cancelled_at: 'Отменена'
      organization_id: 'Заказчик'
      attachments: 'Вложения'

    labels[fieldKey] || fallback || fieldKey

  fieldGroupLabel: (groupKey, fallback = null) ->
    labels =
      identity: 'Идентификация'
      customer: 'Клиент'
      schedule: 'Планирование'
      job_content: 'Содержание заявки'
      assignment: 'Назначение'
      lifecycle: 'Жизненный цикл'
      attachments: 'Вложения'
      other: 'Дополнительно'

    labels[groupKey] || fallback || groupKey

  fieldHint: (fieldKey, unsupported = false) ->
    return 'Поле уже есть в матрице доступа, но его хранение или отдельный editor будут подключены следующим шагом.' if unsupported
    return 'Список исполнителей строится по активным пользователям Дом-Сервис.' if fieldKey is 'assignee_id'
    return 'Используется как заказчик / источник заказа: управляющая компания, партнёр или Частный заказ.' if fieldKey is 'organization_id'
    return 'Диспетчер выбирает только существующие теги из общего словаря Zammad. Новые имена создаются через Manage > Tags.' if fieldKey is 'work_tags'
    null

  fieldInputValue: (job, fieldKey) ->
    value = @jobFieldValue(job, fieldKey)

    switch fieldKey
      when 'work_tags'
        @normalizeTags(value).join(', ')
      when 'assignee_id'
        if value? then "#{value}" else ''
      when 'organization_id'
        if value? then "#{value}" else "#{@privateOrganizationId() || ''}"
      when 'source'
        value || 'manual'
      when 'priority'
        value || 'medium'
      when 'visit_day'
        value || @jobVisitDay(job)
      else
        value || ''

  fieldDisplayValue: (job, fieldKey, unsupported = false) ->
    return 'Пока не подключено к рабочей форме.' if unsupported

    value = @jobFieldValue(job, fieldKey)

    switch fieldKey
      when 'status'
        @statusLabel(job.status)
      when 'priority'
        @priorityLabel(job.priority)
      when 'visit_day'
        @weekdayLabel(@jobVisitDay(job))
      when 'assignee_id'
        @resolveAssigneeName(job)
      when 'organization_id'
        @resolveOrganizationName(job)
      when 'source'
        @sourceLabel(job.source)
      when 'work_tags'
        tags = @normalizeTags(value)
        if tags.length > 0 then tags.join(', ') else '—'
      else
        if value? && "#{value}".length > 0 then value else '—'

  fieldOptions: (fieldKey) ->
    switch fieldKey
      when 'priority'
        [
          { id: 'low', label: 'Низкий' }
          { id: 'medium', label: 'Средний' }
          { id: 'high', label: 'Высокий' }
          { id: 'critical', label: 'Критичный' }
        ]
      when 'visit_day'
        _.map @weekdayItems(), (item) -> { id: item.id, label: item.shortLabel }
      when 'source'
        [
          { id: 'manual', label: 'Вручную' }
          { id: 'ai', label: 'AI / разбор' }
        ]
      when 'assignee_id'
        [{ id: '', label: 'Не назначен' }].concat(@assigneeOptions())
      when 'organization_id'
        @organizationOptions()
      else
        []

  assigneeOptions: ->
    users = App.User.all() || []

    _.chain(users)
      .filter((user) ->
        user?.active isnt false && (
          user.permission('dom_servis.master') ||
          user.permission('dom_servis.dispatcher') ||
          user.permission('dom_servis.admin')
        )
      )
      .sortBy((user) -> (user.displayName() || '').toLowerCase())
      .map((user) -> { id: "#{user.id}", label: user.displayName() || user.login || user.email || "##{user.id}" })
      .value()

  organizationOptions: ->
    options = _.map @organizations, (organization) ->
      id: "#{organization.id}"
      label: organization.name || "##{organization.id}"

    privateId = @privateOrganizationId()
    if privateId? && !_.find(options, (option) -> "#{option.id}" is "#{privateId}")
      options.unshift(
        id: "#{privateId}"
        label: 'Частный заказ'
      )

    if options.length < 1
      options.push(
        id: ''
        label: 'Частный заказ'
      )

    options

  privateOrganizationId: ->
    privateOrganization = _.find(@organizations, (organization) -> organization.name is 'Частный заказ')
    privateOrganization?.id || null

  resolveOrganizationName: (job) ->
    organization = job.organization
    if _.isObject(organization) && organization?.name
      return organization.name

    organizationId = @jobFieldValue(job, 'organization_id')
    if organizationId?
      match = _.find(@organizations, (candidate) -> "#{candidate.id}" is "#{organizationId}")
      return match.name if match?.name

    'Частный заказ'

  currentEditJob: ->
    return null if !@editOpen || !@editingJobId
    @findJob(@editingJobId)

  currentDetailJob: ->
    return null if !@detailOpen || !@detailJobId
    @findJob(@detailJobId)

  buildAttachmentList: (job) ->
    return [] if !job
    @attachmentCollections["#{job.id}"] || []

  canAddAttachment: (job) ->
    return false if !job
    return false if !@actionAllowed('add_attachment')

    if @dispatcherAccess() || @adminAccess()
      return true

    @masterAccess() && job.assignee_id is App.User.current()?.id

  canDeleteAttachments: ->
    @actionAllowed('remove_attachment') && (@dispatcherAccess() || @adminAccess())

  attachmentKindOptions: (job) ->
    return [] if !job
    return [] if !@canAddAttachment(job)

    labels =
      intake_attachment: 'Входные материалы'
      route_info: 'Схема / доступ'
      completion_act: 'Акт выполненных работ'
      diagnostic_photo: 'Фото / диагностика'
      other: 'Прочее'

    if @dispatcherAccess() || @adminAccess()
      return _.map(['intake_attachment', 'route_info', 'completion_act', 'diagnostic_photo', 'other'], (kind) ->
        id: kind
        label: labels[kind]
      )

    _.map(['completion_act', 'diagnostic_photo', 'other'], (kind) ->
      id: kind
      label: labels[kind]
    )

  createAttachmentKindOptions: ->
    return [] if !@canCreatePublishedJob()

    [
      { id: 'intake_attachment', label: 'Входные материалы' }
      { id: 'route_info', label: 'Схема / доступ' }
      { id: 'other', label: 'Прочее' }
    ]

  triggerAttachmentUpload: (e) =>
    @preventDefaultAndStopPropagation(e)
    button = $(e.currentTarget)
    jobId = button.data('id')
    @$(".js-upload-attachment-input[data-id='#{jobId}']").trigger('click')

  uploadAttachments: (e) =>
    input = $(e.currentTarget)
    jobId = input.data('id')
    files = input.prop('files')
    return if !jobId || !files || files.length < 1

    kind = @$(".js-attachment-kind[data-id='#{jobId}']").val() || 'other'
    key = "#{jobId}"
    formData = new FormData()
    formData.append('kind', kind)
    formData.append('File', files[0])
    csrfToken = App.Ajax.token() || $('meta[name="csrf-token"]').attr('content')

    @attachmentUploading[key] = true
    @render()

    @uploadAttachmentFile(jobId, files[0], kind)
      .done =>
        input.val('')
        @attachmentUploading[key] = false
        @notify(type: 'success', msg: 'Вложение добавлено к заявке.', timeout: 3000)
        @loadAttachments(jobId, true)
      .fail (xhr) =>
        input.val('')
        @attachmentUploading[key] = false
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось загрузить вложение.'), timeout: 5000)
        @render()
    return

    $.ajax(
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{jobId}/attachments"
      data: formData
      processData: false
      contentType: false
      headers:
        'X-Requested-With': 'XMLHttpRequest'
        'X-CSRF-Token': csrfToken
      success: =>
        input.val('')
        @attachmentUploading[key] = false
        @notify(type: 'success', msg: 'Вложение добавлено к заявке.', timeout: 3000)
        @loadAttachments(jobId, true)
      error: (xhr) =>
        input.val('')
        @attachmentUploading[key] = false
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось загрузить вложение.'), timeout: 5000)
        @render()
    )

  uploadAttachmentBatch: (jobId, files, kind) ->
    deferred = $.Deferred()
    queue = _.toArray(files || [])

    uploadNext = =>
      if queue.length < 1
        deferred.resolve()
        return

      file = queue.shift()
      @uploadAttachmentFile(jobId, file, kind)
        .done(=> uploadNext())
        .fail((xhr) => deferred.reject(xhr))

    uploadNext()
    deferred.promise()

  uploadAttachmentFile: (jobId, file, kind) ->
    formData = new FormData()
    formData.append('kind', kind || 'other')
    formData.append('File', file)
    csrfToken = App.Ajax.token() || $('meta[name="csrf-token"]').attr('content')

    $.ajax(
      type: 'POST'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{jobId}/attachments"
      data: formData
      processData: false
      contentType: false
      headers:
        'X-Requested-With': 'XMLHttpRequest'
        'X-CSRF-Token': csrfToken
    )

  removeAttachment: (e) =>
    @preventDefaultAndStopPropagation(e)
    button = $(e.currentTarget)
    jobId = button.data('job-id')
    attachmentId = button.data('attachment-id')
    return if !jobId || !attachmentId

    @ajax(
      id: "dom_servis_dispatch_attachment_remove_#{attachmentId}"
      type: 'DELETE'
      url: "#{@apiPath}/dom_servis/dispatch/jobs/#{jobId}/attachments/#{attachmentId}"
      success: =>
        @notify(type: 'success', msg: 'Вложение удалено.', timeout: 3000)
        @loadAttachments(jobId, true)
      error: (xhr) =>
        @notify(type: 'error', msg: @extractError(xhr, 'Не удалось удалить вложение.'), timeout: 5000)
    )

  findJob: (id) ->
    _.find @jobs, (job) -> "#{job.id}" is "#{id}"

  filteredJobs: ->
    list = @jobsForDayAndStatusFilters()

    if @activeTagFilters.length > 0
      list = _.filter(list, (job) =>
        jobTags = @normalizeTags(job.work_tags)
        _.some(@activeTagFilters, (tagName) -> _.contains(jobTags, tagName))
      )

    @sortJobs(list)

  jobsForDayAndStatusFilters: ->
    list = @jobsForStatusFilter()

    if @dayFilter isnt 'all'
      list = _.filter(list, (job) => @jobVisitDay(job) is @dayFilter)

    list

  jobsForSelectedWeek: ->
    startDate = @selectedWeekStartDate()
    endDate = @shiftDate(startDate, 6)

    _.filter @jobs, (job) =>
      visitDate = @jobVisitDate(job)
      return false if !visitDate
      visitDate >= startDate && visitDate <= endDate

  jobsForStatusFilter: ->
    currentUserId = App.User.current()?.id
    weekJobs = @jobsForSelectedWeek()

    switch @statusFilter
      when 'all'
        weekJobs
      when 'pool'
        _.filter(weekJobs, (job) -> job.status is 'pool')
      when 'active'
        _.filter(weekJobs, (job) -> job.status in ['taken', 'in_progress'])
      when 'mine'
        _.filter(weekJobs, (job) -> job.assignee_id is currentUserId)
      when 'done'
        _.filter(weekJobs, (job) -> job.status is 'done')
      else
        _.filter(weekJobs, (job) -> job.status in ['pool', 'taken', 'in_progress'])

  sortJobs: (jobs) ->
    _.sortBy jobs, (job) => @jobSortValue(job)

  jobSortValue: (job) ->
    schedule = "#{job.visit_date || '9999-12-31'} #{job.visit_time || '23:59'}"
    "#{schedule}_#{job.created_at || ''}_#{job.id || ''}"

  jobFieldValue: (job, fieldKey) ->
    job[fieldKey]

  resolveAssigneeName: (job) ->
    if _.isObject(job.assignee) && job.assignee?.displayName
      return job.assignee.displayName

    if _.isString(job.assignee) && job.assignee.length > 0
      return job.assignee

    if job.assignee_id && App.User.exists(job.assignee_id)
      return App.User.findNative(job.assignee_id).displayName()

    'Свободна'

  buildCurrentUserCard: ->
    currentUser = App.User.current()
    userNative = if currentUser?.id && App.User.exists(currentUser.id) then App.User.findNative(currentUser.id) else currentUser
    organizationName = userNative?.organization?.name || currentUser?.organization?.name || 'Без организации'
    phoneValue = userNative?.phone || userNative?.mobile || currentUser?.phone || currentUser?.mobile || 'Не указан'

    displayName = if userNative?.displayName then userNative.displayName() else if currentUser?.displayName then currentUser.displayName() else @fallbackUserName(currentUser)
    initials = if userNative?.initials then userNative.initials() else if currentUser?.initials then currentUser.initials() else 'DS'

    {
      name: displayName
      email: userNative?.email || currentUser?.email || currentUser?.login || 'Не указан'
      phone: phoneValue
      organization: organizationName
      initials: initials
    }

  fallbackUserName: (user) ->
    return 'Пользователь Дом-Сервис' if !user

    fullName = _.compact([user.firstname, user.lastname]).join(' ').trim()
    return fullName if fullName.length > 0
    user.login || user.email || "##{user.id}"

  jobSummaryText: (job) ->
    summary = job.description || job.comment || ''
    summary = @normalizeWhitespace(summary)
    return '' if summary.length is 0
    return summary if summary.length <= 110
    "#{summary.slice(0, 107)}..."

  normalizeWhitespace: (value) ->
    "#{value || ''}".replace(/\s+/g, ' ').trim()

  deadlineWarningMinutes: ->
    minutes = parseInt(@policySettings?.deadline_warning_minutes, 10)
    return 120 if isNaN(minutes) || minutes <= 0
    minutes

  jobDeadlineAt: (job) ->
    return null if !job?.visit_date

    visitDate = @parseDateValue(job.visit_date)
    return null if !visitDate

    deadline = new Date(visitDate.getFullYear(), visitDate.getMonth(), visitDate.getDate())
    if job.visit_time? && "#{job.visit_time}".length > 0
      parts = "#{job.visit_time}".split(':')
      hours = parseInt(parts[0], 10)
      minutes = parseInt(parts[1] || '0', 10)
      return null if isNaN(hours) || isNaN(minutes)
      deadline.setHours(hours, minutes, 0, 0)
    else
      deadline.setHours(23, 59, 59, 999)

    deadline

  jobDeadlineState: (job) ->
    return null if !job
    return null if job.status isnt 'pool'

    deadlineAt = @jobDeadlineAt(job)
    return null if !deadlineAt

    minutesLeft = (deadlineAt.getTime() - new Date().getTime()) / 60000
    warningMinutes = @deadlineWarningMinutes()

    return { state: 'overdue', label: 'Просрочено', minutesLeft: Math.floor(minutesLeft) } if minutesLeft <= 0
    return null if minutesLeft > warningMinutes

    { state: 'warning', label: 'Скоро визит', minutesLeft: Math.ceil(minutesLeft) }

  masterAssigneeOptions: ->
    users = App.User.all() || []

    _.chain(users)
      .filter((user) -> user?.active isnt false && user.permission('dom_servis.master'))
      .sortBy((user) -> (user.displayName() || '').toLowerCase())
      .map((user) -> { id: "#{user.id}", label: user.displayName() || user.login || user.email || "##{user.id}" })
      .value()

  roleLabel: ->
    return 'Владелец/администратор' if @adminAccess()
    return 'Диспетчер' if @dispatcherOnlyAccess()
    return 'Мастер' if @masterAccess()
    'Пользователь'

  dispatcherAccess: ->
    @permissionCheck('dom_servis.admin') || @permissionCheck('dom_servis.dispatcher')

  adminAccess: ->
    @permissionCheck('dom_servis.admin')

  dispatcherOnlyAccess: ->
    @permissionCheck('dom_servis.dispatcher')

  masterAccess: ->
    @permissionCheck('dom_servis.master') && !@dispatcherAccess()

  actionAllowed: (actionKey) ->
    return false if !@effectivePolicy?.actions
    @effectivePolicy.actions[actionKey] is true

  canCreatePublishedJob: ->
    @actionAllowed('create_job') && @actionAllowed('publish_to_pool')

  statusAllowed: (statusKey) ->
    return false if !@effectivePolicy?.statuses
    @effectivePolicy.statuses[statusKey] is true

  fieldVisible: (fieldKey) ->
    return false if !@effectivePolicy?.fields
    @effectivePolicy.fields[fieldKey]?.visible is true

  fieldEditable: (fieldKey) ->
    return false if !@effectivePolicy?.fields
    @effectivePolicy.fields[fieldKey]?.editable is true

  fieldEditableOnBoard: (fieldKey) ->
    return false if !@fieldEditable(fieldKey)
    return false if !@actionAllowed('edit_all_fields')

    if fieldKey is 'priority'
      return @actionAllowed('change_priority')

    if fieldKey is 'assignee_id'
      return false

    if fieldKey is 'organization_id'
      return true

    if fieldKey is 'comment'
      return @actionAllowed('add_comment')

    if fieldKey in ['visit_day', 'visit_date']
      return @actionAllowed('move_job_day') || @actionAllowed('move_job_week')

    true

  scheduleLabel: (job) ->
    dayLabel = @weekdayLabel(@jobVisitDay(job))
    datePart = job.visit_date || 'без точной даты'
    timePart = job.visit_time || 'время не задано'
    "#{dayLabel}, #{datePart}, #{timePart}"

  sourceLabel: (source) ->
    switch source
      when 'ai' then 'AI / разбор'
      else 'Вручную'

  jobVisitDay: (job) ->
    job.visit_day || @weekdayKeyFromDate(job.visit_date) || @defaultVisitDay()

  jobVisitDate: (job) ->
    parsedDate = @parseDateValue(job.visit_date)
    return parsedDate if parsedDate

    fallbackDay = @jobVisitDay(job)
    return null if !fallbackDay

    @dateForDayInWeek(fallbackDay)

  defaultVisitDay: ->
    return @dayFilter if @dayFilter && @dayFilter isnt 'all'

    unless @isCurrentWeek(@selectedWeekStartDate())
      return 'mon'

    switch new Date().getDay()
      when 1 then 'mon'
      when 2 then 'tue'
      when 3 then 'wed'
      when 4 then 'thu'
      when 5 then 'fri'
      when 6 then 'sat'
      else 'sun'

  weekdayItems: ->
    [
      { id: 'mon', label: 'Понедельник', shortLabel: 'Пн' }
      { id: 'tue', label: 'Вторник', shortLabel: 'Вт' }
      { id: 'wed', label: 'Среда', shortLabel: 'Ср' }
      { id: 'thu', label: 'Четверг', shortLabel: 'Чт' }
      { id: 'fri', label: 'Пятница', shortLabel: 'Пт' }
      { id: 'sat', label: 'Суббота', shortLabel: 'Сб' }
      { id: 'sun', label: 'Воскресенье', shortLabel: 'Вс' }
    ]

  weekdayLabel: (key) ->
    item = _.find(@weekdayItems(), (weekday) -> weekday.id is key)
    item?.shortLabel || '—'

  weekdayKeyFromDate: (value) ->
    return null if !value

    date = new Date(value)
    return null if isNaN(date.getTime())

    switch date.getDay()
      when 1 then 'mon'
      when 2 then 'tue'
      when 3 then 'wed'
      when 4 then 'thu'
      when 5 then 'fri'
      when 6 then 'sat'
      else 'sun'

  nextDateForDay: (dayKey) ->
    date = @selectedWeekStartDate()
    targetDay =
      switch dayKey
        when 'mon' then 1
        when 'tue' then 2
        when 'wed' then 3
        when 'thu' then 4
        when 'fri' then 5
        when 'sat' then 6
        else 0

    offset = (targetDay - 1 + 7) % 7
    date.setDate(date.getDate() + offset)
    @formatDateValue(date)

  selectedWeekStartDate: ->
    @parseDateValue(@selectedWeekStart) || @startOfWeek(new Date())

  startOfWeek: (dateValue) ->
    date = @parseDateValue(dateValue) || new Date()
    normalized = new Date(date.getFullYear(), date.getMonth(), date.getDate())
    day = normalized.getDay()
    diff = if day is 0 then -6 else 1 - day
    normalized.setDate(normalized.getDate() + diff)
    normalized

  shiftDate: (dateValue, days) ->
    date = @parseDateValue(dateValue) || new Date()
    shifted = new Date(date.getFullYear(), date.getMonth(), date.getDate())
    shifted.setDate(shifted.getDate() + days)
    shifted

  parseDateValue: (value) ->
    return null if !value
    return new Date(value.getFullYear(), value.getMonth(), value.getDate()) if _.isDate(value)
    return null if !_.isString(value) || value.length is 0

    parts = value.split('-')
    return null if parts.length isnt 3

    year = parseInt(parts[0], 10)
    month = parseInt(parts[1], 10) - 1
    day = parseInt(parts[2], 10)
    parsed = new Date(year, month, day)
    return null if isNaN(parsed.getTime())

    parsed

  formatDateValue: (dateValue) ->
    date = @parseDateValue(dateValue) || new Date()
    year = date.getFullYear()
    month = ("0#{date.getMonth() + 1}").slice(-2)
    day = ("0#{date.getDate()}").slice(-2)
    "#{year}-#{month}-#{day}"

  formatDate: (dateValue) ->
    date = @parseDateValue(dateValue) || new Date()
    day = ("0#{date.getDate()}").slice(-2)
    month = ("0#{date.getMonth() + 1}").slice(-2)
    "#{day}.#{month}.#{date.getFullYear()}"

  formatDayMonth: (dateValue) ->
    date = @parseDateValue(dateValue) || new Date()
    day = ("0#{date.getDate()}").slice(-2)
    month = ("0#{date.getMonth() + 1}").slice(-2)
    "#{day}.#{month}"

  dayOfMonth: (dateValue) ->
    date = @parseDateValue(dateValue) || new Date()
    ("0#{date.getDate()}").slice(-2)

  dateForDayInWeek: (dayKey) ->
    startDate = @selectedWeekStartDate()
    index = _.findIndex(@weekdayItems(), (item) -> item.id is dayKey)
    return null if index < 0
    @shiftDate(startDate, index)

  isCurrentWeek: (startDate) ->
    @formatDateValue(startDate) is @formatDateValue(@startOfWeek(new Date()))

  isToday: (job) ->
    visitDate = @jobVisitDate(job)
    return false if !visitDate
    @formatDateValue(visitDate) is @formatDateValue(new Date())

  isTodayDate: (dateValue) ->
    return false if !dateValue
    @formatDateValue(dateValue) is @formatDateValue(new Date())

  parseTags: (value) ->
    return [] if !value

    _.chain(value.split(','))
      .map((item) -> item.trim())
      .filter((item) -> item.length > 0)
      .uniq()
      .value()

  normalizeTags: (value) ->
    if _.isArray(value)
      return _.filter(value, (item) -> item)

    if _.isString(value)
      return @parseTags(value)

    []

  availableTagOptions: (selectedValue = []) ->
    selectedTags = @normalizeTags(selectedValue)
    availableNames = _.map(@availableTags, (tag) -> tag.name)

    _.chain(selectedTags.concat(availableNames))
      .uniq()
      .map((tagName) =>
        tagEntry = _.find(@availableTags, (item) -> item.name is tagName)
        {
          id: tagName
          label: tagName
          count: tagEntry?.dispatch_count || 0
          selected: _.contains(selectedTags, tagName)
        }
      )
      .sortBy((item) -> item.label.toLowerCase())
      .sortBy((item) -> if item.selected then 0 else 1)
      .value()

  tagBadgeItems: (tagValue, limit = 4) ->
    _.map @normalizeTags(tagValue).slice(0, limit), (tagName) =>
      {
        name: tagName
        active: _.contains(@activeTagFilters, tagName)
      }

  updateTagToggleGroup: (container, selectedTags) ->
    container.find('.js-tag-toggle-chip').each (index, element) ->
      chip = $(element)
      tagName = chip.data('tag')?.toString()?.trim()
      chip.toggleClass('is-active', _.contains(selectedTags, tagName))

  fallbackJobCode: (job) ->
    createdAt = new Date(job.created_at || Date.now())
    datePart = createdAt.toISOString().slice(0, 10).replace(/-/g, '')
    rawId = "#{job.id || ''}".replace(/\D/g, '')
    tail = ("0000#{rawId}").slice(-4)
    "#{datePart}-#{tail}"

  defaultModalFieldOrder: ->
    [
      'id'
      'job_code'
      'source'
      'status'
      'priority'
      'visit_day'
      'visit_date'
      'visit_time'
      'address'
      'client_name'
      'client_phone'
      'organization_id'
      'service_type'
      'description'
      'comment'
      'work_tags'
      'assignee_id'
      'ticket_id'
      'published_at'
      'created_at'
      'taken_at'
      'updated_at'
      'completed_at'
      'cancelled_at'
      'attachments'
    ]

  normalizeNumericId: (value) ->
    return null if !value? || "#{value}".length is 0
    parsed = parseInt(value, 10)
    return null if isNaN(parsed)
    parsed

  statusLabel: (status) ->
    switch status
      when 'taken' then 'Взята'
      when 'in_progress' then 'В работе'
      when 'done' then 'Готово'
      when 'cancelled' then 'Отменена'
      when 'transferred_to_partner' then 'Передана партнёру'
      else 'В пуле'

  priorityLabel: (priority) ->
    switch priority
      when 'low' then 'Низкий'
      when 'high' then 'Высокий'
      when 'critical' then 'Критичный'
      else 'Средний'

  extractError: (xhr, fallback) ->
    xhr?.responseJSON?.error_human || xhr?.responseJSON?.error || fallback

  fieldOptions: (fieldKey) ->
    switch fieldKey
      when 'priority'
        [
          { id: 'low', label: 'Низкий' }
          { id: 'medium', label: 'Средний' }
          { id: 'high', label: 'Высокий' }
          { id: 'critical', label: 'Критичный' }
        ]
      when 'visit_day'
        _.map @weekdayItems(), (item) -> { id: item.id, label: item.shortLabel }
      when 'source'
        [
          { id: 'manual', label: 'Вручную' }
          { id: 'form', label: 'Форма Zammad' }
          { id: 'email', label: 'Email' }
          { id: 'webhook', label: 'Webhook / API' }
          { id: 'ai', label: 'AI / разбор' }
        ]
      when 'assignee_id'
        [{ id: '', label: 'Не назначен' }].concat(@assigneeOptions())
      when 'organization_id'
        @organizationOptions()
      else
        []

  sourceLabel: (source) ->
    switch source
      when 'form' then 'Форма Zammad'
      when 'email' then 'Email'
      when 'webhook' then 'Webhook / API'
      when 'ai' then 'AI / разбор'
      else 'Вручную'

  # ---------------------------------------------------------------------
  # Web Push subscription
  # ---------------------------------------------------------------------

  # Returns true if the current browser environment can use Web Push
  # (service worker + Push API + Notification API present).
  pushSupported: =>
    return 'serviceWorker' of navigator && 'PushManager' of window && 'Notification' of window

  # Returns the VAPID public key the server uses to identify itself to
  # the push service. Exposed to the frontend via a meta tag rendered by
  # the dispatch board layout (set by the admin through Settings).
  vapidPublicKey: =>
    return document.querySelector('meta[name="dom-servis-vapid-public-key"]')?.content

  # Request notification permission, subscribe the dispatch service worker
  # to the push service, and persist the subscription on the backend.
  enablePushNotifications: (e) =>
    e?.preventDefault()

    return if !@pushSupported()
    return if @pushSubscribing

    if !@vapidPublicKey()
      @notifyPushError('Push-уведомления не настроены администратором (нет VAPID ключа).')
      return

    @pushSubscribing = true
    @render()

    # Use Promise chains instead of async/await: CoffeeScript 1.x (used by
    # Sprockets eco/coffee compiler) does not understand `await`.
    Notification.requestPermission()
      .then (permission) =>
        if permission != 'granted'
          @pushSubscribing = false
          @render()
          return Promise.reject(new Error('Permission denied'))

        navigator.serviceWorker.ready
      .then (registration) =>
        registration.pushManager.getSubscription()
          .then (subscription) =>
            return subscription if subscription

            registration.pushManager.subscribe(
              userVisibleOnly: true
              applicationServerKey: @urlBase64ToUint8Array(@vapidPublicKey())
            )
      .then (subscription) =>
        @persistPushSubscription(subscription)
      .then =>
        @pushEnabled = true
        @pushSubscribing = false
        @render()
      .catch (error) =>
        @pushSubscribing = false
        @render()
        return if error?.message == 'Permission denied'
        @notifyPushError('Не удалось включить push-уведомления.')

  # Send the browser-generated PushSubscription to the backend.
  persistPushSubscription: (subscription) =>
    payload = subscription.toJSON()

    return new Promise (resolve, reject) =>
      @ajax(
        id:      'dom_servis_push_subscribe'
        type:    'POST'
        url:     "#{@apiPath}/dom_servis/dispatch/push_subscriptions"
        data:    JSON.stringify(payload)
        processData: true
        success: resolve
        error:   (xhr) => reject(new Error(@extractError(xhr, 'Не удалось сохранить подписку.')))
      )

  # Sends a test push to all of the current user's subscriptions, so they
  # can confirm the channel works end-to-end after enabling it.
  testPushNotification: (e) =>
    e?.preventDefault()
    return if @pushTesting

    @pushTesting = true
    @render()

    @ajax(
      id:    'dom_servis_push_test'
      type:  'POST'
      url:   "#{@apiPath}/dom_servis/dispatch/push_subscriptions/test"
      success: =>
        @pushTesting = false
        @render()
      error: (xhr) =>
        @pushTesting = false
        @render()
        @notifyPushError(@extractError(xhr, 'Тестовый пуш не отправлен.'))
    )

  # Decode a base64url VAPID public key into a Uint8Array suitable for
  # `pushManager.subscribe({ applicationServerKey })`.
  urlBase64ToUint8Array: (base64String) ->
    padding = '='.repeat((4 - (base64String.length % 4)) % 4)
    base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')

    rawData = window.atob(base64)
    outputArray = new Uint8Array(rawData.length)

    i = 0
    while i < rawData.length
      outputArray[i] = rawData.charCodeAt(i)
      i++

    outputArray

  notifyPushError: (message) ->
    App.Toast.create
      type:    'error'
      message: message
      timeout: 4000

class DomServisDispatchBoardRouter extends App.ControllerPermanent
  @requiredPermission: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']

  constructor: (params) ->
    super

    @authenticateCheckRedirect()

    App.TaskManager.execute(
      key: 'DomServisDispatchBoard'
      controller: 'DomServisDispatchBoard'
      params: params
      show: true
      persistent: true
    )

App.Config.set('dom_servis/dispatch', DomServisDispatchBoardRouter, 'Routes')
App.Config.set('DomServisDispatchBoard', { controller: 'DomServisDispatchBoard', permission: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master'] }, 'permanentTask')
App.Config.set('DomServisDispatchBoard', { prio: 1200, parent: '', name: 'Диспетчеризация', target: '#dom_servis/dispatch', key: 'DomServisDispatchBoard', permission: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master'], class: 'checklist' }, 'NavBar')
