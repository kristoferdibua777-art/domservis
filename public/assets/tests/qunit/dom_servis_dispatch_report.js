// Dom-Servis master report on the board: the calculator, the hints before
// saving and the report form of a job.

const Report = () => App.DomServisDispatchReport

QUnit.test('the calculator splits the sums like the server', assert => {
  const draft = {
    items: [
      { kind: 'work', quantity: '1', price: '2000' },
      { kind: 'work', quantity: 1, price: 500 },
      { kind: 'part', quantity: '1', price: '1 800', bought_by_master: true },
      { kind: 'part', quantity: '2', price: '50,5', bought_by_master: false },
    ],
    payment_method: 'cash',
    amount_paid: '4401',
  }

  const sums = Report().calculate(draft, { master_percent: 30, partner_percent: 5, partner_base: 'total' })

  assert.deepEqual(sums, {
    works_total: 2500,
    parts_total: 1901,
    total: 4401,
    master_percent: 30,
    master_amount: 750,
    parts_reimbursement: 1800,
    master_payout: 2550,
    partner_percent: 5,
    partner_amount: 220.05,
    company_amount: 1630.95,
    money_at_master: 4401,
    master_settlement: -1851,
  })

  const byCard = Report().calculate(Object.assign({}, draft, { payment_method: 'card' }), { master_percent: 30 })
  assert.strictEqual(byCard.money_at_master, 0, 'a card payment does not stay with the master')
  assert.strictEqual(byCard.master_settlement, 2550)
  assert.strictEqual(byCard.partner_amount, 0, 'no partner rate, no partner share')
})

QUnit.test('numbers and money read and print as on a phone', assert => {
  assert.strictEqual(Report().number('1 500,50'), 1500.5)
  assert.strictEqual(Report().number(''), 0)
  assert.strictEqual(Report().number('abc'), 0)
  assert.strictEqual(Report().money(1500), '1 500 ₽')
  assert.strictEqual(Report().money(1234567.5), '1 234 567,50 ₽')
  assert.strictEqual(Report().money(-1851), '−1 851 ₽')
})

QUnit.test('the hints name what the report still lacks', assert => {
  assert.deepEqual(Report().missing({ items: [], payment_method: 'cash' }, false), [
    'добавьте хотя бы одну работу или запчасть',
    'напишите, что сделано',
    'напишите рекомендации клиенту (если их нет — «нет»)',
    'укажите сумму, полученную от клиента',
    'приложите фото результата или акт выполненных работ',
  ])
  assert.deepEqual(Report().missing({ items: [{}], work_summary: 'x', recommendations: 'нет', payment_method: 'partner' }, true), [], 'no amount when the partner pays')
  assert.strictEqual(Report().evidenceCount([{ kind: 'diagnostic_photo' }, { kind: 'completion_act' }, { kind: 'intake_attachment' }]), 2)
})

QUnit.test('the price list puts the lines of the job first', assert => {
  const priceItems = [
    { id: 1, name: 'Чистка теплообменника', kind: 'work', direction: 'Газовый котёл', unit: 'шт', price: 2500 },
    { id: 2, name: 'Выезд', kind: 'work', direction: null, unit: 'выезд', price: 500 },
    { id: 3, name: 'Смеситель', kind: 'part', direction: 'Сантехника', unit: 'шт', price: 3000 },
  ]

  const groups = Report().priceGroups(priceItems, ['Газовый котёл', 'Не греет'])

  assert.deepEqual(groups.map((group) => [group.label, group.items.map((item) => item.id)]), [
    ['По этой заявке', [1]],
    ['Общие', [2]],
    ['Сантехника', [3]],
  ])
  assert.deepEqual(Report().itemFromPrice(priceItems[2]), {
    price_item_id: 3, kind: 'part', name: 'Смеситель', quantity: 1, unit: 'шт', list_price: 3000, price: 3000, bought_by_master: true,
  })
})

function reportBoard(response) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  const requests = []
  Object.assign(board, {
    apiPath: '/api/v1',
    jobs: [{ id: 7, ticket_number: '10007', service_type: 'Газовый котёл: Не греет', status: 'in_progress', work_tags: ['Газовый котёл'] }],
    priceList: [{ id: 1, name: 'Чистка теплообменника', kind: 'work', direction: 'Газовый котёл', unit: 'шт', price: 2500 }],
    attachmentCollections: { 7: [{ kind: 'diagnostic_photo' }] },
    attachmentLoading: {},
    reportResponses: {},
    reportOpen: false,
    ajax: (options) => requests.push(options),
    render: () => {},
    notify: () => {},
    loadAttachments: () => {},
    loadEvents: () => {},
    loadJobs: () => {},
    preventDefaultAndStopPropagation: () => {},
    $: () => ({ text: () => {}, empty: () => ({ append: () => {}, closest: () => ({ toggleClass: () => {} }) }), trigger: () => {} }),
  })
  board.openReport({ currentTarget: $('<button data-id="7">') })
  const load = requests.find((request) => request.url === '/api/v1/dom_servis/dispatch/jobs/7/report')
  load.success(response)
  return { board, requests }
}

QUnit.test('the report form opens with the saved report and the master share', assert => {
  const { board } = reportBoard({
    report: { items: [{ price_item_id: 1, kind: 'work', name: 'Чистка теплообменника', quantity: 1, unit: 'шт', list_price: 2500, price: 3000 }], work_summary: 'Почистил', recommendations: '', payment_method: 'cash', amount_paid: 3000 },
    can_edit: true,
    can_finish: true,
    rates: { master_percent: 40 },
    payment_methods: [{ id: 'cash', label: 'Наличными мастеру' }],
  })

  const view = board.buildReportView()

  assert.strictEqual(view.jobNumber, '10007')
  assert.strictEqual(view.items[0].priceChanged, true)
  assert.strictEqual(view.items[0].listPriceLabel, '2 500 ₽')
  assert.deepEqual(view.sums.map((entry) => [entry.label, entry.value]), [
    ['Работы', '3 000 ₽'],
    ['Запчасти', '0 ₽'],
    ['Итого клиенту', '3 000 ₽'],
    ['Доля мастера (40% от работ)', '1 200 ₽'],
    ['Возврат за запчасти мастеру', '0 ₽'],
    ['Мастеру всего', '1 200 ₽'],
    ['Деньги клиента у мастера', '3 000 ₽'],
    ['Мастер сдаёт в кассу', '1 800 ₽'],
  ])
  assert.deepEqual(view.missing, ['напишите рекомендации клиенту (если их нет — «нет»)'], 'the photo is already attached')
  assert.strictEqual(view.evidenceCount, 1)
  assert.deepEqual(view.priceGroups.map((group) => group.label), ['По этой заявке'])
})

QUnit.test('a dispatcher sees no shares and the form sends the report with finish', assert => {
  const { board, requests } = reportBoard({ report: null, can_edit: true, can_finish: true, rates: {}, payment_methods: [] })

  board.reportDraft.items.push(App.DomServisDispatchReport.itemFromPrice(board.priceList[0]))
  board.reportDraft.work_summary = 'Почистил'
  board.reportDraft.recommendations = 'нет'
  board.reportDraft.payment_method = 'card'
  board.reportDraft.amount_paid = '2500'

  assert.deepEqual(board.buildReportView().sums.map((entry) => entry.key), ['works_total', 'parts_total', 'total'])

  board.saveReport({ currentTarget: $('<button data-finish="true">') })
  const save = requests.find((request) => request.type === 'PUT')
  const body = JSON.parse(save.data)

  assert.strictEqual(save.url, '/api/v1/dom_servis/dispatch/jobs/7/report')
  assert.strictEqual(body.finish, true)
  assert.deepEqual(body.items, [{ price_item_id: 1, kind: 'work', name: 'Чистка теплообменника', quantity: '1', unit: 'шт', price: '2500', bought_by_master: false }])
  assert.strictEqual(board.reportSaving, true)

  save.success({ report: { complete: true }, status: 'done' })
  assert.strictEqual(board.reportOpen, false, 'the form closes after finishing')
})

QUnit.test('the card asks for the report instead of finishing directly', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  const action = board.buildCardPrimaryAction({ canFinish: true })

  assert.deepEqual(action, { label: 'Отчёт и готово', buttonClass: 'btn--success', handlerClass: 'js-open-report' })
})
