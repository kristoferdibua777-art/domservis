// Visit time editor of the Dom-Servis dispatch board (Scheduling Core v1):
// empty, HH:MM or HH:MM-HH:MM; untouched free-text intake time is never sent;
// editing the time needs move_job_day, as on the server.

function dispatchBoard(overrides) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.notices = []
  board.notify = (data) => board.notices.push(data)
  board.effectivePolicy = {
    fields: {
      visit_time: { editable: true },
      visit_day: { editable: true },
      comment: { editable: true },
    },
    actions: {
      edit_all_fields: true,
      move_job_day: true,
      add_comment: true,
    },
  }

  return Object.assign(board, overrides)
}

function fakeInput(value) {
  const state = { value: value, invalid: false, focused: false }
  const group = {
    addClass: () => { state.invalid = true; return group },
    removeClass: () => { state.invalid = false; return group },
  }

  return {
    length: 1,
    state: state,
    val: function (next) {
      if (arguments.length) {
        state.value = next
        return this
      }
      return state.value
    },
    closest: () => group,
    trigger: (event) => { if (event === 'focus') state.focused = true },
  }
}

function editBoard(inputs) {
  return dispatchBoard({
    editableEditFields: () => [
      { key: 'visit_time', type: 'time' },
      { key: 'comment', type: 'textarea' },
    ],
    $: (selector) => {
      const match = selector.match(/data-field='([^']+)'/)
      return (match && inputs[match[1]]) || { length: 0 }
    },
  })
}

function createBoard(visitTime) {
  const inputs = {
    '.js-create-service-type': fakeInput('Boiler repair'),
    '.js-create-address': fakeInput('Lenina 10'),
    '.js-create-client-phone': fakeInput('+79001234567'),
    '.js-create-visit-day': fakeInput('mon'),
    '.js-create-visit-date': fakeInput('2026-09-28'),
    '.js-create-visit-time': fakeInput(visitTime),
  }

  const board = dispatchBoard({
    createOpen: true,
    createDraft: {},
    organizations: [],
    $: (selector) => inputs[selector] || fakeInput(''),
  })

  return { board: board, inputs: inputs }
}

QUnit.test('visit time format follows the backend contract', assert => {
  const board = dispatchBoard()
  const accepts = (value) => board.validVisitTime(board.normalizeVisitTimeInput(value))

  assert.ok(accepts(''), 'empty')
  assert.ok(accepts('09:05'), 'exact time')
  assert.ok(accepts('09:00-11:30'), 'window')
  assert.ok(accepts('00:00-23:59'), 'full day window')

  assert.equal(board.normalizeVisitTimeInput(' 9:05 '), '09:05', 'one-digit hour and spaces')
  assert.equal(board.normalizeVisitTimeInput('09:00 – 11:30'), '09:00-11:30', 'en dash')
  assert.equal(board.normalizeVisitTimeInput('09:00—11:30'), '09:00-11:30', 'em dash')
  assert.equal(board.normalizeVisitTimeInput('9:00-9:30'), '09:00-09:30', 'one-digit hours in a window')

  assert.notOk(accepts('25:00'), '25:00')
  assert.notOk(accepts('24:00'), '24:00')
  assert.notOk(accepts('09:60'), '09:60')
  assert.notOk(accepts('0905'), 'no colon')
  assert.notOk(accepts('09:00-'), 'open window')
  assert.notOk(accepts('09:00-11:30-12:00'), 'three bounds')
  assert.notOk(accepts('после обеда'), 'free text')
});

QUnit.test('edit sends an exact time, a window and an empty time', assert => {
  let payload = editBoard({ visit_time: fakeInput('09:05') }).buildEditPayload({ visit_time: '' })
  assert.deepEqual(payload, { visit_time: '09:05' }, 'exact time')

  payload = editBoard({ visit_time: fakeInput('09:00-11:30') }).buildEditPayload({ visit_time: '09:05' })
  assert.deepEqual(payload, { visit_time: '09:00-11:30' }, 'window')

  payload = editBoard({ visit_time: fakeInput('') }).buildEditPayload({ visit_time: '09:00-11:30' })
  assert.deepEqual(payload, { visit_time: '' }, 'cleared time')

  payload = editBoard({ visit_time: fakeInput('9:05') }).buildEditPayload({ visit_time: '09:05' })
  assert.deepEqual(payload, {}, 'same time typed differently is not a change')
});

QUnit.test('edit re-opens stored times unchanged', assert => {
  const board = dispatchBoard()

  assert.equal(board.fieldInputValue({ visit_time: '09:05' }, 'visit_time'), '09:05')
  assert.equal(board.fieldInputValue({ visit_time: '09:00-11:30' }, 'visit_time'), '09:00-11:30')
  assert.equal(board.fieldInputValue({ visit_time: null }, 'visit_time'), '')
});

QUnit.test('edit keeps a free-text intake time when another field changes', assert => {
  const job = { visit_time: 'после обеда, позвонить заранее', comment: 'old' }
  const inputs = {
    visit_time: fakeInput('после обеда, позвонить заранее'),
    comment: fakeInput('new'),
  }

  assert.deepEqual(editBoard(inputs).buildEditPayload(job), { comment: 'new' }, 'visit_time is not sent')

  // The text input drops line breaks of a multi-line snapshot.
  const multiLineJob = { visit_time: 'после обеда\nпозвонить', comment: 'old' }
  const multiLineInputs = {
    visit_time: fakeInput('после обедапозвонить'),
    comment: fakeInput('new'),
  }

  assert.deepEqual(editBoard(multiLineInputs).buildEditPayload(multiLineJob), { comment: 'new' }, 'multi-line snapshot is not sent')
});

QUnit.test('edit rejects 25:00 and keeps the input for correction', assert => {
  const input = fakeInput('25:00')
  const board = editBoard({ visit_time: input, comment: fakeInput('new') })

  assert.strictEqual(board.buildEditPayload({ visit_time: '09:05', comment: 'old' }), false, 'nothing is saved')
  assert.equal(input.val(), '25:00', 'typed value stays')
  assert.ok(input.state.invalid, 'field is marked invalid')
  assert.ok(input.state.focused, 'field gets focus')
  assert.equal(board.notices.length, 1, 'one error notice')
  assert.equal(board.notices[0].type, 'error')

  const group = $('<div class="form-group has-error"><input class="js-visit-time-input"></div>')
  board.clearVisitTimeError({ currentTarget: group.find('input').get(0) })
  assert.notOk(group.hasClass('has-error'), 'mark is cleared when typing')
});

QUnit.test('time is editable on the board only with move_job_day', assert => {
  const board = dispatchBoard()
  assert.ok(board.fieldEditableOnBoard('visit_time'), 'with move_job_day')

  board.effectivePolicy.actions = { edit_all_fields: true, move_job_week: true }
  assert.notOk(board.fieldEditableOnBoard('visit_time'), 'move_job_week alone is not enough')
  assert.ok(board.fieldEditableOnBoard('visit_day'), 'the day stays editable with move_job_week')

  board.effectivePolicy.actions = { edit_all_fields: true, move_job_day: true }
  board.effectivePolicy.fields.visit_time = { editable: false }
  assert.notOk(board.fieldEditableOnBoard('visit_time'), 'field matrix still applies')
});

QUnit.test('create sends a window and an empty time and rejects 25:00', assert => {
  let setup = createBoard('09:00 - 11:30')
  assert.equal(setup.board.createPayload().visit_time, '09:00-11:30', 'window')

  setup = createBoard('')
  assert.equal(setup.board.createPayload().visit_time, '', 'empty time')

  setup = createBoard('25:00')
  assert.strictEqual(setup.board.createPayload(), null, 'nothing is created')
  assert.equal(setup.inputs['.js-create-visit-time'].val(), '25:00', 'typed value stays')
  assert.ok(setup.inputs['.js-create-visit-time'].state.invalid, 'field is marked invalid')
  assert.equal(setup.board.notices[0].type, 'error')
});
