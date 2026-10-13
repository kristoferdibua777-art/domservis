// Web Push on the Dom-Servis dispatch board can only be turned on in the
// installable shell at /dispatch/. Phones are sent there from every other
// entry to the board, and the board shows whether the device is subscribed.

QUnit.test('only the /dispatch/ pages are the shell', assert => {
  const detection = App.MobileDetection

  assert.true(detection.insideDispatchShell('/dispatch/'))
  assert.true(detection.insideDispatchShell('/dispatch'))
  assert.true(detection.insideDispatchShell('/dispatch/anything'))

  assert.false(detection.insideDispatchShell('/'))
  assert.false(detection.insideDispatchShell('/mobile/'))
  assert.false(detection.insideDispatchShell('/dispatcher'))
  assert.false(detection.insideDispatchShell(''))
});

QUnit.test('a phone outside the shell is sent to it', assert => {
  const detection = App.MobileDetection
  const originalIsMobile = detection.isMobile

  try {
    detection.isMobile = () => true
    assert.true(detection.shouldUseDispatchShell('/'), 'main app')
    assert.true(detection.shouldUseDispatchShell('/mobile/dom-servis/dispatch'), 'mobile app')
    assert.false(detection.shouldUseDispatchShell('/dispatch/'), 'already in the shell')

    detection.isMobile = () => false
    assert.false(detection.shouldUseDispatchShell('/'), 'desktop keeps the main app')
    assert.false(detection.redirectToDispatchShell(), 'no redirect on desktop')
  } finally {
    detection.isMobile = originalIsMobile
  }

  assert.equal(detection.dispatchShellUrl, '/dispatch/#dom_servis/dispatch')
});

function pushBoard(overrides) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.renders = 0
  board.lookups = 0
  board.pushEnabled = false

  return Object.assign(board, {
    render: () => { board.renders += 1 },
    pushSupported: () => true,
    vapidPublicKey: () => 'vapid-public-key',
    currentPushSubscription: () => {
      board.lookups += 1
      return Promise.resolve({ endpoint: 'https://push.example/1' })
    },
  }, overrides)
}

QUnit.test('a subscribed device is shown as enabled', async assert => {
  const board = pushBoard()

  await board.syncPushState()

  assert.true(board.pushEnabled)
  assert.equal(board.renders, 1)

  await board.syncPushState()
  assert.equal(board.lookups, 1, 'nothing to look up once enabled')
  assert.equal(board.renders, 1)
});

QUnit.test('a device without a subscription keeps the enable button', async assert => {
  const missing = pushBoard({ currentPushSubscription: () => Promise.resolve(null) })
  await missing.syncPushState()
  assert.false(missing.pushEnabled)
  assert.equal(missing.renders, 0)

  const failing = pushBoard({ currentPushSubscription: () => Promise.reject(new Error('no service worker')) })
  await failing.syncPushState()
  assert.false(failing.pushEnabled)
  assert.equal(failing.renders, 0)
});

QUnit.test('the browser is not asked where push cannot work', async assert => {
  const unsupported = pushBoard({ pushSupported: () => false })
  await unsupported.syncPushState()
  assert.equal(unsupported.lookups, 0)

  const withoutKey = pushBoard({ vapidPublicKey: () => '' })
  await withoutKey.syncPushState()
  assert.equal(withoutKey.lookups, 0)
  assert.false(withoutKey.pushEnabled)
});

QUnit.test('the enable button hands over to the onboarding sheet', assert => {
  const board = pushBoard()
  let opened = 0
  const listener = () => { opened += 1 }
  window.addEventListener('dom-servis-push-open', listener)

  try {
    let prevented = 0
    board.enablePushNotifications({ preventDefault: () => { prevented += 1 } })

    assert.equal(opened, 1, 'the sheet is asked to open')
    assert.equal(prevented, 1)
    assert.false(board.pushEnabled, 'only the sheet turns notifications on')
    assert.equal(board.renders, 0)
  } finally {
    window.removeEventListener('dom-servis-push-open', listener)
  }
});

QUnit.test('a sent test says how many devices it went to', assert => {
  const requests = []
  const notes = []
  const errors = []
  const board = pushBoard({
    apiPath: '/api/v1',
    ajax: (options) => requests.push(options),
    notify: (options) => notes.push(options),
    notifyPushError: (message) => errors.push(message),
    extractError: (xhr, fallback) => fallback,
  })

  board.testPushNotification({ preventDefault: () => {} })
  assert.equal(requests[0].url, '/api/v1/dom_servis/dispatch/push_subscriptions/test')
  assert.true(board.pushTesting)

  board.testPushNotification({ preventDefault: () => {} })
  assert.equal(requests.length, 1, 'no second request while one is running')

  requests[0].success({ status: 'ok', sent_to: 2 })
  assert.false(board.pushTesting)
  assert.equal(notes.length, 1)
  assert.equal(notes[0].type, 'success')
  assert.true(notes[0].msg.startsWith('Тест отправлен, устройств: 2.'), notes[0].msg)

  assert.true(board.pushTestSentMessage(undefined).startsWith('Тест отправлен. '), 'no count without a server answer')

  board.testPushNotification({ preventDefault: () => {} })
  requests[1].error({})
  assert.false(board.pushTesting)
  assert.deepEqual(errors, ['Тестовый пуш не отправлен.'])
  assert.equal(notes.length, 1, 'no success note for a failed test')
});

QUnit.test('the onboarding sheet event refreshes the state', async assert => {
  const board = pushBoard()
  let synced = 0
  board.syncPushState = () => { synced += 1 }

  board.bindPushStateWatcher()
  window.dispatchEvent(new Event('dom-servis-push-subscribed'))
  assert.equal(synced, 1)

  board.stopPushStateWatcher()
  window.dispatchEvent(new Event('dom-servis-push-subscribed'))
  assert.equal(synced, 1, 'no longer listening after release')
});
