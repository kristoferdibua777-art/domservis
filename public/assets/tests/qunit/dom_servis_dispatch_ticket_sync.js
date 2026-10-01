// Dom-Servis backing ticket sync failures on the dispatch board: the card
// shows the recorded failure and a dispatcher can retry the sync.

QUnit.test('the failure label has the time and the error', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  assert.strictEqual(board.ticketSyncErrorLabel({ id: 1 }), null, 'no failure recorded')
  assert.strictEqual(board.ticketSyncErrorLabel(null), null)

  const label = board.ticketSyncErrorLabel({ id: 1, ticket_sync_failed_at: '2026-10-01T09:30:00Z', ticket_sync_error: 'ActiveRecord::RecordInvalid: Group missing' })
  assert.ok(/^\d{2}\.\d{2}\.2026 \d{2}:\d{2} · ActiveRecord::RecordInvalid: Group missing$/.test(label), label)
});

QUnit.test('the card offers the retry to a dispatcher', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  const originalCurrent = App.User.current
  App.User.current = () => null

  Object.assign(board, {
    dispatcherAccess: () => true,
    actionAllowed: () => true,
    statusAllowed: () => true,
    masterAssigneeOptions: () => [],
    jobDeadlineState: () => null,
    resolveOrganizationName: () => '',
    resolveAssigneeName: () => '',
    canOpenEdit: () => false,
    organizations: [],
  })

  try {
    const failed = board.buildDetailJobView({ id: 5, status: 'pool', ticket_sync_failed_at: '2026-10-01T09:30:00Z', ticket_sync_error: 'Boom' })
    assert.ok(failed.ticketSyncError.endsWith(' · Boom'))
    assert.strictEqual(failed.canResyncTicket, true)
    assert.strictEqual(failed.ticketResyncing, false)

    board.ticketResyncingId = 5
    assert.strictEqual(board.buildDetailJobView({ id: 5, status: 'pool' }).ticketResyncing, true)
    assert.strictEqual(board.buildDetailJobView({ id: 5, status: 'pool' }).ticketSyncError, null, 'nothing to show without a failure')
  } finally {
    App.User.current = originalCurrent
  }
});

QUnit.test('retrying the sync asks the server and reloads the board', assert => {
  const requests = []
  const notes = []
  let renders = 0
  let reloads = 0
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    apiPath: '/api/v1',
    ajax: (options) => requests.push(options),
    notify: (options) => notes.push(options),
    render: () => { renders += 1 },
    loadJobs: () => { reloads += 1 },
    preventDefaultAndStopPropagation: () => {},
  })

  const button = $('<button data-id="5"></button>')[0]
  board.resyncTicket({ currentTarget: button })

  assert.equal(requests.length, 1)
  assert.equal(requests[0].type, 'POST')
  assert.equal(requests[0].url, '/api/v1/dom_servis/dispatch/jobs/5/resync_ticket')
  assert.equal(board.ticketResyncingId, 5, 'marked as running')
  assert.equal(renders, 1)

  board.resyncTicket({ currentTarget: button })
  assert.equal(requests.length, 1, 'no second request while one is running')

  requests[0].success({})
  assert.strictEqual(board.ticketResyncingId, null)
  assert.equal(notes.pop().type, 'success')
  assert.equal(reloads, 1)

  board.resyncTicket({ currentTarget: button })
  requests[1].error({ responseJSON: { error: 'Тикет не обновлён: Boom' } })
  assert.strictEqual(board.ticketResyncingId, null)
  const error = notes.pop()
  assert.equal(error.type, 'error')
  assert.equal(reloads, 2)
});
