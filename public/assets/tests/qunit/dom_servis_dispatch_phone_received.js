// Client phone and arrival time on the Dom-Servis dispatch board: the phone
// dials on a tap and copies whole, the job shows when it came in.

function phoneBoard(overrides) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.organizations = []
  board.dispatcherAccess = () => true
  board.adminAccess = () => false

  return Object.assign(board, overrides)
}

QUnit.test('phone link dials the first number of the field', assert => {
  const board = phoneBoard()

  assert.equal(board.phoneHref('+79001234567'), 'tel:+79001234567')
  assert.equal(board.phoneHref('8 (900) 123-45-67'), 'tel:+79001234567', 'leading 8')
  assert.equal(board.phoneHref('900 123 45 67'), 'tel:+79001234567', 'ten digits')
  assert.equal(board.phoneHref('+375 29 123-45-67'), 'tel:+375291234567', 'another country')
  assert.equal(board.phoneHref('8 900 123-45-67, 8 911 111-22-33'), 'tel:+79001234567', 'first of two numbers')
  assert.equal(board.phoneHref('22-33-44'), 'tel:223344', 'short local number')
  assert.strictEqual(board.phoneHref(''), null)
  assert.strictEqual(board.phoneHref('уточнить'), null)
  assert.strictEqual(board.phoneHref('кв 12'), null, 'too short for a phone')
});

QUnit.test('arrival time names today and yesterday', assert => {
  const board = phoneBoard()
  const now = new Date(2026, 9, 28, 23, 40)
  const at = (...parts) => new Date(...parts).toISOString()

  assert.equal(board.receivedLabel(at(2026, 9, 28, 23, 25), now), 'сегодня в 23:25')
  assert.equal(board.receivedLabel(at(2026, 9, 27, 9, 5), now), 'вчера в 09:05')
  assert.equal(board.receivedLabel(at(2026, 9, 20, 14, 0), now), '20.10 в 14:00')
  assert.equal(board.receivedLabel(at(2025, 11, 31, 8, 0), now), '31.12.2025 в 08:00', 'another year')
  assert.equal(board.receivedLabel(at(2026, 9, 31, 22, 0), new Date(2026, 10, 1, 8, 0)), 'вчера в 22:00', 'across a month')
  assert.equal(board.receivedLabel(null, now), '')
  assert.equal(board.receivedLabel('not a date', now), '')
});

QUnit.test('job detail dials and copies the phone and shows the arrival time', assert => {
  const board = phoneBoard()
  const groups = (job) => board.buildDetailGroups(job)
  const phoneItem = (job) => groups(job).find((group) => group.id === 'client').items.find((item) => item.label === 'Телефон')
  const createdAt = new Date(2026, 9, 28, 23, 25).toISOString()

  const phone = phoneItem({ id: 3, source: 'manual', client_phone: '8 900 123-45-67', created_at: createdAt })
  assert.equal(phone.value, '8 900 123-45-67', 'shown as typed')
  assert.equal(phone.href, 'tel:+79001234567')
  assert.true(phone.phone, 'with the copy button')

  const noPhone = phoneItem({ id: 4, source: 'manual' })
  assert.equal(noPhone.value, 'Не указан')
  assert.false(noPhone.phone, 'no link and no copy button')

  const meta = groups({ id: 3, source: 'manual', created_at: createdAt }).find((group) => group.id === 'meta').items
  assert.equal(meta[0].label, 'Поступила')
  assert.equal(meta[0].value, '28.10.2026 23:25')
});

QUnit.test('copy puts the dialled number into the clipboard', assert => {
  const copied = []
  const notes = []
  const original = window.clipboard
  window.clipboard = { writeText: (text) => { copied.push(text); return Promise.resolve() } }

  const board = phoneBoard({
    preventDefaultAndStopPropagation: () => {},
    notify: (note) => notes.push(note.msg),
  })
  const button = $('<button data-phone="8 (900) 123-45-67"></button>')[0]
  const odd = $('<button data-phone="уточнить"></button>')[0]

  try {
    board.copyPhone({ currentTarget: button })
    board.copyPhone({ currentTarget: odd })
  }
  finally {
    window.clipboard = original
  }

  assert.deepEqual(copied, ['+79001234567', 'уточнить'])
  assert.deepEqual(notes, ['Номер скопирован.', 'Номер скопирован.'])
});
