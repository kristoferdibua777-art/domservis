// Job number on the Dom-Servis dispatch board: Ticket.number once the backing
// ticket exists (job_code only until then) and a ticket link for dispatchers.

function numberBoard(overrides) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.organizations = []
  board.dispatcherAccess = () => true
  board.adminAccess = () => false

  return Object.assign(board, overrides)
}

QUnit.test('job number is the ticket number once the backing ticket exists', assert => {
  const board = numberBoard()

  assert.equal(board.jobNumber({ ticket_number: '10042', job_code: '20260927-1234' }), '10042')
  assert.equal(board.jobNumber({ job_code: '20260927-1234' }), '20260927-1234', 'job_code until then')
  assert.equal(board.jobNumber({ id: 7, created_at: '2026-09-27T10:00:00Z' }), '20260927-0007', 'fallback code')
});

QUnit.test('ticket link is for dispatchers and admins only', assert => {
  const board = numberBoard()

  assert.equal(board.ticketHref({ ticket_id: 55 }), '#ticket/zoom/55', 'dispatcher')
  assert.strictEqual(board.ticketHref({}), null, 'no ticket yet')

  board.dispatcherAccess = () => false
  assert.strictEqual(board.ticketHref({ ticket_id: 55 }), null, 'master')

  board.adminAccess = () => true
  assert.equal(board.ticketHref({ ticket_id: 55 }), '#ticket/zoom/55', 'admin')
});

QUnit.test('system block shows the ticket and keeps the old code aside', assert => {
  const board = numberBoard()
  const metaItems = (job) => board.buildDetailGroups(job).find((group) => group.id === 'meta').items

  const withTicket = metaItems({ id: 1, source: 'manual', ticket_id: 55, ticket_number: '10042', job_code: '20260927-1234' })
  assert.deepEqual(withTicket.map((item) => item.label), ['Источник', 'Партнёр', 'Тикет Zammad', 'Старый код заявки'])
  assert.equal(withTicket[2].value, '10042')
  assert.equal(withTicket[2].href, '#ticket/zoom/55')
  assert.equal(withTicket[3].value, '20260927-1234')

  const withoutTicket = metaItems({ id: 2, source: 'form', job_code: '20260927-5678' })
  assert.deepEqual(withoutTicket.map((item) => item.label), ['Источник', 'Партнёр', 'Тикет Zammad'])
  assert.equal(withoutTicket[2].value, 'Ещё не создан')
  assert.strictEqual(withoutTicket[2].href, null)
});
