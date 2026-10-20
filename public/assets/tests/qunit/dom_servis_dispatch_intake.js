// Dom-Servis new job form: a client message pasted into the form is read on
// the server and fills the fields the dispatcher has not changed yet.

function intakeBoard(draft) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  const requests = []
  const notes = []
  const delays = {}
  let renders = 0

  Object.assign(board, {
    apiPath: '/api/v1',
    createOpen: true,
    ajax: (options) => requests.push(options),
    notify: (options) => notes.push(options),
    delay: (callback, timeout, key) => { delays[key] = callback },
    clearDelay: (key) => { delete delays[key] },
    render: () => { renders += 1 },
    syncCreateDraftFromForm: () => {},
    extractError: (xhr, fallback) => fallback,
    preventDefaultAndStopPropagation: () => {},
    $: () => ({ length: 1, val: () => board.fieldText }),
  })
  // The defaults of a new job form, then what the dispatcher typed.
  board.createDraft = {
    service_type: '', address: '', client_name: '', client_phone: '', visit_day: 'wed',
    visit_date: '2026-10-14', visit_time: '', priority: 'medium', description: '', comment: '',
  }
  board.resetIntake()
  Object.assign(board.createDraft, draft || {})

  return { board, requests, notes, delays, renders: () => renders }
}

QUnit.test('a reading fills the untouched fields and keeps what the dispatcher typed', assert => {
  const { board } = intakeBoard({ client_name: 'Мария' })

  board.applyIntakeDraft({
    draft: { client_phone: '+79001234567', client_name: 'Ирина', address: 'ул. Ленина 5', priority: 'high', visit_date: '2026-10-15', visit_day: 'thu', comment: 'Исходный текст:\nКотёл' },
    checks: [{ level: 'warning', text: 'В тексте несколько номеров' }, { level: 'bogus', text: 'Прочее' }, { level: 'ok' }],
    client: { last_address: 'Советский пр. 10' },
    ai: { used: true, model: 'GigaChat-2-Pro' },
  })

  assert.strictEqual(board.createDraft.client_phone, '+79001234567')
  assert.strictEqual(board.createDraft.client_name, 'Мария', 'a typed name is kept')
  assert.strictEqual(board.createDraft.address, 'ул. Ленина 5')
  assert.strictEqual(board.createDraft.priority, 'high', 'the default priority is replaced')
  assert.strictEqual(board.createDraft.visit_date, '2026-10-15', 'the default date is replaced')
  assert.strictEqual(board.createDraft.visit_day, 'thu')
  assert.strictEqual(board.createDraft.comment, 'Исходный текст:\nКотёл')
  assert.deepEqual(board.intake.checks, [
    { level: 'warning', mark: '!', text: 'В тексте несколько номеров' },
    { level: 'info', mark: 'i', text: 'Прочее' },
  ], 'unknown levels become info, empty checks are left out')
  assert.strictEqual(board.intake.status, 'Заполнено полей: 4, разбор: ИИ (GigaChat-2-Pro) и правила. Проверьте их перед публикацией.')

  const view = board.buildIntakeView()
  assert.strictEqual(view.filled.client_phone, true)
  assert.strictEqual(view.filled.client_name, undefined, 'the typed name is not marked as read from the text')
  assert.strictEqual(view.lastAddress, 'Советский пр. 10')
});

QUnit.test('a second reading updates its own values but not the edited ones', assert => {
  const { board } = intakeBoard()

  board.applyIntakeDraft({ draft: { client_phone: '+79001234567', address: 'ул. Ленина 5' } })
  board.createDraft.address = 'ул. Ленина 5, кв. 12'
  board.applyIntakeDraft({ draft: { client_phone: '+79007654321', address: 'ул. Мира 3', service_type: 'Сантехника' } })

  assert.strictEqual(board.createDraft.client_phone, '+79007654321', 'the earlier reading is replaced')
  assert.strictEqual(board.createDraft.address, 'ул. Ленина 5, кв. 12', 'the edited address stays')
  assert.strictEqual(board.createDraft.service_type, 'Сантехника')
  assert.strictEqual(board.buildIntakeView().filled.address, undefined)
});

QUnit.test('an empty reading says so', assert => {
  const { board } = intakeBoard()

  board.applyIntakeDraft({ draft: {}, ai: { used: false } })

  assert.strictEqual(board.intake.status, 'В тексте не нашлось новых данных для заявки.')
});

QUnit.test('the text goes to the server once at a time', assert => {
  const { board, requests, notes } = intakeBoard()

  board.fieldText = '   '
  board.parseIntakeText()
  assert.strictEqual(requests.length, 0, 'an empty text is not sent')
  assert.strictEqual(notes[0].msg, 'Вставьте текст от клиента.')

  board.fieldText = 'Котёл не греет, 89001234567'
  board.parseIntakeText()
  assert.strictEqual(requests.length, 1)
  assert.strictEqual(requests[0].url, '/api/v1/dom_servis/dispatch/jobs/parse_input')
  assert.deepEqual(JSON.parse(requests[0].data), { input: 'Котёл не греет, 89001234567' })
  assert.strictEqual(board.buildIntakeView().busy, true)

  board.fieldText = 'Котёл не греет, 89001234567\n\nул. Ленина 5'
  board.parseIntakeText()
  assert.strictEqual(requests.length, 1, 'a reading while busy waits for the running one')

  requests[0].success({ draft: { client_phone: '+79001234567' } })
  assert.strictEqual(requests.length, 2, 'the waiting reading runs after the first one')
  assert.deepEqual(JSON.parse(requests[1].data), { input: 'Котёл не греет, 89001234567\n\nул. Ленина 5' })
});

QUnit.test('a long insert is read like a paste, typing is not', assert => {
  const { board, requests, delays } = intakeBoard()

  board.fieldText = 'Кот'
  board.updateIntakeText({ originalEvent: { inputType: 'insertText', data: 'т' } })
  assert.deepEqual(Object.keys(delays), [], 'typing is not read')

  // An Android keyboard pastes from its clipboard strip without a paste event.
  board.fieldText = 'Котёл не греет, ул. Ленина 5, 89001234567'
  board.updateIntakeText({ originalEvent: { inputType: 'insertText', data: 'ёл не греет, ул. Ленина 5, 89001234567' } })
  assert.deepEqual(Object.keys(delays), ['dom_servis_dispatch_intake_reading'])

  board.intakeTextPasted()
  assert.strictEqual(Object.keys(delays).length, 1, 'a paste and its input event lead to one reading')

  delays.dom_servis_dispatch_intake_reading()
  assert.strictEqual(requests.length, 1)
  assert.deepEqual(JSON.parse(requests[0].data), { input: 'Котёл не греет, ул. Ленина 5, 89001234567' })

  // Pasted over the whole text, the new text may be shorter than the old one.
  delete delays.dom_servis_dispatch_intake_reading
  board.fieldText = 'Течёт кран, Мира 3, 89007654321'
  board.updateIntakeText({ originalEvent: { inputType: 'insertText', data: 'Течёт кран, Мира 3, 89007654321' } })
  assert.deepEqual(Object.keys(delays), ['dom_servis_dispatch_intake_reading'])
});

QUnit.test('clearing takes out the text and what its reading filled, not what was typed', assert => {
  const { board, delays } = intakeBoard({ client_name: 'Мария' })

  assert.strictEqual(board.buildIntakeView().canClear, false, 'nothing to clear in a new form')

  board.fieldText = 'Котёл не греет, ул. Ленина 5, 89001234567'
  board.updateIntakeText({ originalEvent: {} })
  board.applyIntakeDraft({
    draft: { client_phone: '+79001234567', address: 'ул. Ленина 5', priority: 'high', visit_date: '2026-10-15', visit_day: 'thu', comment: 'Исходный текст' },
    checks: [{ level: 'info', text: 'Новый клиент' }],
  })
  board.createDraft.address = 'ул. Ленина 5, кв. 12'
  assert.strictEqual(board.buildIntakeView().canClear, true)

  board.intake.busy = true
  board.clearIntakeText()
  assert.strictEqual(board.createDraft.client_phone, '+79001234567', 'nothing is cleared while the text is being read')
  board.intake.busy = false

  board.clearIntakeText()

  assert.strictEqual(board.intake.text, '')
  assert.strictEqual(board.intake.status, null)
  assert.deepEqual(board.intake.checks, [])
  assert.strictEqual(delays.dom_servis_dispatch_intake_reading, undefined, 'a waiting reading is dropped')
  assert.strictEqual(board.createDraft.client_phone, '', 'the read phone goes')
  assert.strictEqual(board.createDraft.priority, 'medium', 'the default priority comes back')
  assert.strictEqual(board.createDraft.visit_date, '2026-10-14')
  assert.strictEqual(board.createDraft.visit_day, 'wed')
  assert.strictEqual(board.createDraft.comment, '')
  assert.strictEqual(board.createDraft.address, 'ул. Ленина 5, кв. 12', 'the edited address stays')
  assert.strictEqual(board.createDraft.client_name, 'Мария', 'the typed name stays')
  assert.strictEqual(board.buildIntakeView().canClear, false)

  board.applyIntakeDraft({ draft: { client_name: 'Ирина', client_phone: '+79007654321' } })
  assert.strictEqual(board.createDraft.client_name, 'Мария', 'the next reading still keeps the typed name')
  assert.strictEqual(board.createDraft.client_phone, '+79007654321')
});

QUnit.test('a reading that comes back after the form was closed is dropped', assert => {
  const { board } = intakeBoard()

  board.createOpen = false
  board.applyIntakeDraft({ draft: { client_phone: '+79001234567' } })

  assert.strictEqual(board.createDraft.client_phone, '')
});

QUnit.test('the last address of the client can be put into the form', assert => {
  const { board } = intakeBoard()

  board.applyIntakeDraft({ draft: {}, client: { last_address: 'Советский пр. 10' } })
  board.useIntakeLastAddress()

  assert.strictEqual(board.createDraft.address, 'Советский пр. 10')
  assert.strictEqual(board.buildIntakeView().lastAddress, null, 'the button goes away once the address is in the form')
});
