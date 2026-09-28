// Job history in the Dom-Servis dispatch board card: DispatchEvent records
// rendered as a title, the changed values and who did it when.

function historyBoard(overrides) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.organizations = [{ id: 7, name: 'Управляющая компания' }]
  board.historyUserName = (userId) => ({ 12: 'Иван Мастер', 13: 'Пётр Мастер' })[userId] || `#${userId}`

  return Object.assign(board, overrides)
}

QUnit.test('history shows old and new values of a field update', assert => {
  const entry = historyBoard().historyEntry({
    event_type: 'updated',
    actor_name: 'Диспетчер Анна',
    created_at: '2026-09-27T09:05:00',
    meta: {
      changes: {
        address: { from: 'Lenina 10', to: 'Lenina 12' },
        visit_time: { from: null, to: '09:00-11:30' },
        assignee_id: { from: 12, to: null },
      },
    },
  })

  assert.equal(entry.title, 'Изменены данные заявки')
  assert.deepEqual(entry.lines, [
    'Адрес: Lenina 10 → Lenina 12',
    'Время визита: — → 09:00-11:30',
    'Исполнитель: Иван Мастер → —',
  ])
  assert.equal(entry.actor, 'Диспетчер Анна')
  assert.equal(entry.time, '27.09.2026 09:05')
});

QUnit.test('history labels transitions of status, day, priority and customer', assert => {
  const board = historyBoard()

  assert.equal(board.historyEntry({ event_type: 'status_changed', meta: { from: 'taken', to: 'in_progress' } }).title, 'Статус: Взята → В работе')
  assert.equal(board.historyEntry({ event_type: 'priority_changed', meta: { from: 'medium', to: 'high' } }).title, 'Приоритет: Средний → Высокий')
  assert.equal(board.historyEntry({ event_type: 'organization_changed', meta: { from: null, to: 7 } }).title, 'Заказчик: — → Управляющая компания')
  assert.equal(board.historyEntry({ event_type: 'moved_weekday', meta: { from: 'mon', to: 'wed' } }).title, 'День визита: Пн → Ср')
});

QUnit.test('history shows the master and the status change of assign and release', assert => {
  const board = historyBoard()

  const assigned = board.historyEntry({ event_type: 'assigned', meta: { from: null, to: 13, status: { from: 'pool', to: 'taken' } } })
  assert.equal(assigned.title, 'Назначен мастер')
  assert.deepEqual(assigned.lines, ['Мастер: — → Пётр Мастер', 'Статус: В пуле → Взята'])

  const released = board.historyEntry({ event_type: 'released', meta: { from: 12, status: { from: 'in_progress', to: 'pool' } } })
  assert.equal(released.title, 'Возвращена в пул')
  assert.deepEqual(released.lines, ['Мастер: Иван Мастер', 'Статус: В работе → В пуле'])
});

QUnit.test('history keeps the previous comment and the intake source', assert => {
  const board = historyBoard()

  const comment = board.historyEntry({ event_type: 'comment_added', meta: { comment: 'Код домофона 12', from: 'Позвонить заранее' } })
  assert.deepEqual(comment.lines, ['Комментарий: Позвонить заранее → Код домофона 12'])

  const created = board.historyEntry({ event_type: 'created', meta: { source: 'form', request_source_id: 3 } })
  assert.equal(created.title, 'Заявка создана')
  assert.deepEqual(created.lines, ['Источник: Форма Zammad'])
});

QUnit.test('history copes with events written before the full audit trail', assert => {
  const board = historyBoard()

  const status = board.historyEntry({ event_type: 'status_changed', meta: {} })
  assert.equal(status.title, 'Статус', 'no invented transition')
  assert.deepEqual(status.lines, [])

  const updated = board.historyEntry({ event_type: 'updated', meta: null, actor_name: null, created_at: null })
  assert.equal(updated.title, 'Изменены данные заявки')
  assert.deepEqual(updated.lines, [])
  assert.equal(updated.actor, 'Система')
  assert.equal(updated.time, '')

  assert.equal(board.historyEntry({ event_type: 'something_new', meta: {} }).title, 'something_new', 'unknown type is shown as is')
});

QUnit.test('history lists the loaded events of the open job only', assert => {
  const board = historyBoard({ eventCollections: { 5: [{ event_type: 'published', meta: {} }] } })

  assert.deepEqual(board.buildHistoryEntries({ id: 5 }).map((entry) => entry.title), ['Опубликована в пул'])
  assert.deepEqual(board.buildHistoryEntries({ id: 6 }), [])
  assert.deepEqual(board.buildHistoryEntries(null), [])
});
