dispatchDesktopRoutePattern = /^#dom_servis\/dispatch(?:$|[/?])/
dispatchShellPathPattern = /^\/dispatch(?:$|\/)/

class App.MobileDetection
  @dispatchShellUrl: '/dispatch/#dom_servis/dispatch'

  @isMobile: ->
    isMobile()

  @isCompactViewport: ->
    window.matchMedia?('(max-width: 767px)').matches is true

  @isForcingDesktopView: ->
    App.LocalStorage.get('forceDesktopApp', false)

  @isSystemInitialized: ->
    App.Config.get('system_init_done')

  @clearForceDesktopApp: ->
    if App.LocalStorage.get('forceDesktopApp', false)
      App.LocalStorage.delete('forceDesktopApp')

  @hasDispatchAccess: ->
    user = App.User.current?()
    return false if !user

    user.permission('dom_servis.admin') ||
      user.permission('dom_servis.dispatcher') ||
      user.permission('dom_servis.master')

  @desktopShellRequiredForHash: (hash = window.location.hash) ->
    dispatchDesktopRoutePattern.test(hash || '')

  @keepDesktopShellOnMobile: (hash = window.location.hash) ->
    @desktopShellRequiredForHash(hash)

  @shouldPreferDispatchLanding: ->
    @hasDispatchAccess() && (@isMobile() || @isCompactViewport() || @isForcingDesktopView())

  @insideDispatchShell: (pathname = window.location.pathname) ->
    dispatchShellPathPattern.test(pathname || '')

  # Web Push can only be turned on in the installable shell at /dispatch/:
  # the main app has neither its service worker nor the onboarding sheet.
  # A phone that opens the board anywhere else would never get a push.
  @shouldUseDispatchShell: (pathname = window.location.pathname) ->
    @isMobile() && !@insideDispatchShell(pathname)

  @redirectToDispatchShell: ->
    return false if !@shouldUseDispatchShell()

    window.location.replace(@dispatchShellUrl)
    true

  @mobileTargetHash: (hash = window.location.hash) ->
    return '' if @desktopShellRequiredForHash(hash)
    hash || ''

  @navigateToMobile: ->
    target = '/mobile'
    hash = @mobileTargetHash()

    if hash
      target += "/#{hash}"

    window.location.href = target

  @redirectToMobile: =>
    @clearForceDesktopApp()
    @navigateToMobile()

  # Automatically redirect to mobile view, if:
  #   - the system was already initialized
  #   - on mobile device
  #   - not forcing desktop view.
  @autoRedirectToMobile: =>
    @redirectToMobile() if @isSystemInitialized() and @isMobile() and !@isForcingDesktopView() and !@keepDesktopShellOnMobile()

class App.MobileDetectionWorker
  clicked: (e) ->
    App.MobileDetection.redirectToMobile()

class App.MobileDetectionPlugin extends App.Controller
  constructor: ->
    super

    App.MobileDetection.autoRedirectToMobile()
    @delay(@launchTaskManagerTask)

  launchTaskManagerTask: ->
    App.TaskManager.execute(
      key:        'MobileDetection'
      controller: 'MobileDetectionWorker'
      params:     {}
      show:       false
      persistent: true
    )

App.Config.set('mobile_detection', App.MobileDetectionPlugin, 'Plugins')

if App.MobileDetection.isMobile() or App.MobileDetection.isCompactViewport() or App.LocalStorage.get('forceDesktopApp', false)
  App.Config.set('Mobile',
    {
      prio: 1500,
      parent: '#current_user',
      name: __('Continue to mobile'),
      translate: true,
      target: '#',
      onclick: true,
      key: 'MobileDetection',
    }
    , 'NavBarRight')
