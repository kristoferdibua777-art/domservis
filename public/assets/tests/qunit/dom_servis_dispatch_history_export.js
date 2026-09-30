// Dom-Servis job history export (decision 2026-09-28): admins export the
// history every 30 days; when it is due, the board reminds them once.

QUnit.test('the board reminds an admin once when the history export is due', assert => {
  const requests = []
  const notes = []
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    apiPath: '/api/v1',
    loading: true,
    ajax: (options) => requests.push(options),
    notify: (options) => notes.push(options),
    render: () => {},
  })

  board.loadEffectivePolicy()
  requests[0].success({ role_key: 'dispatcher' })
  assert.equal(notes.length, 0, 'no reminder without the flag')

  board.loadEffectivePolicy()
  requests[1].success({ role_key: 'admin', history_export_due: false })
  assert.equal(notes.length, 0, 'no reminder when not due')

  board.loadEffectivePolicy()
  requests[2].success({ role_key: 'admin', history_export_due: true })
  assert.equal(notes.length, 1)
  assert.equal(notes[0].type, 'info')
  assert.ok(notes[0].msg.includes('Пора выгрузить историю заявок'))

  board.loadEffectivePolicy()
  requests[3].success({ role_key: 'admin', history_export_due: true })
  assert.equal(notes.length, 1, 'only once per visit')
});
