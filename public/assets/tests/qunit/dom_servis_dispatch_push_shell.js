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
