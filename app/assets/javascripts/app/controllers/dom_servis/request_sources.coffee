buildRequestSourceAttributes = (persisted) ->
  attrs = $.extend(true, [], App.DomServisRequestSource.configure_attributes)

  for attribute in attrs
    switch attribute.name
      when 'partner_key'
        attribute.skipRendering = true
      when 'allowed_domains'
        attribute.renderTarget = '.js-security-fields'
      when 'privacy_policy_url'
        attribute.renderTarget = '.js-security-fields'
      when 'notes'
        attribute.renderTarget = '.js-security-fields'
      when 'rotate_embed_token'
        attribute.renderTarget = '.js-security-fields'
      when 'embed_url'
        if persisted
          attribute.skipRendering = true
        else
          attribute.skipRendering = true
      when 'embed_snippet'
        if persisted
          attribute.skipRendering = true
        else
          attribute.skipRendering = true
      when 'embed_js_snippet'
        if persisted
          attribute.skipRendering = true
        else
          attribute.skipRendering = true
      when 'embed_token', 'display_name', 'updated_at', 'created_at'
        attribute.skipRendering = true
  attrs

renderRequestSourceContent = (item, persisted, owner = null) ->
  content = $(App.view('dom_servis/request_source')(
    item: item
    isNew: !persisted
  ))

  controller = new App.ControllerForm(
    model:
      configure_attributes: buildRequestSourceAttributes(persisted)
    params:    item
    screen:    if persisted then 'edit' else 'create'
    autofocus: true
    handlers:  []
    el:        content
  )

  owner.controller = controller if owner
  content.find('.js-passport-fields').prepend(controller.form.detach())
  content.data('domServisRequestSourceControllerForm', controller)
  content.on('input change', 'input, textarea, select', -> controller.hideAlert())
  content

class DomServisRequestSources extends App.ControllerSubContent
  @requiredPermission: 'dom_servis.admin'
  header: __('Источники заявок партнёров')

  constructor: ->
    super

    @genericController = new Index(
      el: @el
      id: @id
      genericObject: 'DomServisRequestSource'
      defaultSortBy: 'id'
      searchBar: true
      searchQuery: @search_query
      pageData:
        home: 'dom_servis_request_sources'
        object: __('Источник заявки партнёра')
        objects: __('Источники заявок партнёров')
        searchPlaceholder: __('Поиск по источникам заявок партнёров')
        pagerAjax: true
        pagerBaseUrl: '#manage/dom_servis_request_sources/'
        pagerSelected: ( @page || 1 )
        pagerPerPage: 50
        navupdate: '#dom_servis_request_sources'
        buttons: [
          { name: __('Новый источник заявки партнёра'), 'data-type': 'new', class: 'btn--success' }
        ]
      container: @el.closest('.content')
      veryLarge: true
    )

  show: (params) =>
    for key, value of params
      if key isnt 'el' && key isnt 'shown' && key isnt 'match'
        @[key] = value

    @genericController.paginate(@page || 1, params)

class Index extends App.ControllerGenericIndex
  newControllerClass: -> New
  editControllerClass: -> Edit

class New extends App.ControllerGenericNew
  events:
    'click .js-copy':   'copyInputToClipboard'
    'click .js-select': 'selectAll'

  content: =>
    @head = @pageData.head || @pageData.object
    @item = @item || {}
    renderRequestSourceContent(@item, false, @)

  post: ->
    @$('.js-helpMessage').tooltip()

class Edit extends App.ControllerGenericEdit
  events:
    'click .js-copy':   'copyInputToClipboard'
    'click .js-select': 'selectAll'

  content: =>
    @item = App[@genericObject].find(@id)
    @head = @pageData.head || @pageData.object
    renderRequestSourceContent(@item, true, @)

  post: ->
    @$('.js-helpMessage').tooltip()

App.Config.set('DomServisRequestSources', { prio: 3610, name: __('Источники заявок партнёров'), parent: '#manage', target: '#manage/dom_servis_request_sources', controller: DomServisRequestSources, permission: ['dom_servis.admin'] }, 'NavBarAdmin')
