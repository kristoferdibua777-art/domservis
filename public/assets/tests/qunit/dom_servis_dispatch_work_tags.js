// Dom-Servis work tags on the board: the dictionary groups in the tag
// selector, the tag filter limit and the tags read from a pasted text.

function tagBoard() {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  Object.assign(board, {
    availableTags: [
      { name: 'Газовый котёл', group: 'direction', dispatch_count: 3 },
      { name: 'Сантехника', group: 'direction', dispatch_count: 1 },
      { name: 'Диагностика', group: 'work', dispatch_count: 0 },
      { name: 'Не греет', group: 'fault', dispatch_count: 2 },
      { name: 'Течёт', group: 'fault', dispatch_count: 0 },
      { name: 'Baxi', group: 'brand', dispatch_count: 1 },
      { name: 'Своя метка', group: 'other', dispatch_count: 0 },
    ],
    tagGroups: [
      { key: 'direction', label: 'Направление' },
      { key: 'work', label: 'Вид работ' },
      { key: 'fault', label: 'Неисправность' },
      { key: 'equipment', label: 'Оборудование' },
      { key: 'brand', label: 'Марка' },
      { key: 'other', label: 'Другие теги' },
    ],
    activeTagFilters: [],
    showAllTagFilters: false,
  })
  return board
}

QUnit.test('the tag selector lists the dictionary groups in their order', assert => {
  const board = tagBoard()
  const groups = board.availableTagGroups('Течёт, Старый тег')

  assert.deepEqual(groups.map((group) => group.key), ['direction', 'work', 'fault', 'brand', 'other'], 'groups without tags are left out')
  assert.deepEqual(groups[0].options.map((option) => option.id), ['Газовый котёл', 'Сантехника'], 'dictionary order, not by name')
  assert.deepEqual(groups[2].options.map((option) => [option.id, option.selected]), [['Не греет', false], ['Течёт', true]])
  assert.deepEqual(groups.map((group) => group.open), [true, true, true, false, true], 'main groups and groups with a chosen tag start open')
  assert.deepEqual(groups.map((group) => group.selectedCount), [0, 0, 1, 0, 1])
  assert.deepEqual(groups[4].options.map((option) => option.id), ['Своя метка', 'Старый тег'], 'a chosen tag missing from the list goes to the other tags')
})

QUnit.test('without the server groups every tag is still offered', assert => {
  const board = tagBoard()
  board.availableTags = []
  board.tagGroups = []

  const groups = board.availableTagGroups(['Течёт'])

  assert.strictEqual(groups.length, 1)
  assert.deepEqual(groups[0].options.map((option) => option.id), ['Течёт'])
})

QUnit.test('the tag filter shows the most used tags and the chosen ones', assert => {
  const board = tagBoard()
  const items = Array.from({ length: 15 }, (_, index) => ({ id: `t${index}`, label: `t${index}`, count: 15 - index, active: false }))
  items[14].active = true
  board.buildTagFilters = () => items

  let view = board.tagFilterView()
  assert.strictEqual(view.items.length, 13, '12 most used and the chosen one')
  assert.ok(view.items.includes(items[14]))
  assert.strictEqual(view.hidden, 2)
  assert.strictEqual(view.collapsible, true)

  board.showAllTagFilters = true
  view = board.tagFilterView()
  assert.strictEqual(view.items.length, 15)
  assert.strictEqual(view.hidden, 0)

  board.buildTagFilters = () => items.slice(0, 5)
  board.showAllTagFilters = false
  view = board.tagFilterView()
  assert.deepEqual([view.items.length, view.hidden, view.collapsible], [5, 0, false])
})

QUnit.test('a pasted text fills the work tags unless the dispatcher chose some', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  Object.assign(board, {
    createOpen: true,
    mobileView: false,
    render: () => {},
    syncCreateDraftFromForm: () => {},
  })
  board.createDraft = { service_type: '', priority: 'medium', work_tags: '' }
  board.resetIntake()

  board.applyIntakeDraft({ draft: { service_type: 'Газовый котёл: Не греет', work_tags: ['Газовый котёл', 'Не греет'] } })
  assert.strictEqual(board.createDraft.work_tags, 'Газовый котёл, Не греет')

  board.applyIntakeDraft({ draft: { work_tags: ['Сантехника'] } })
  assert.strictEqual(board.createDraft.work_tags, 'Сантехника', 'tags of an earlier reading are replaced')

  board.createDraft.work_tags = 'Жалоба'
  board.applyIntakeDraft({ draft: { work_tags: ['Электрика'] } })
  assert.strictEqual(board.createDraft.work_tags, 'Жалоба', 'tags the dispatcher chose are kept')
})
