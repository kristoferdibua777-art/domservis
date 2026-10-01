// Dom-Servis dispatcher calendar: an exact visit time is a 2-hour visit, the
// day shows 08:00-20:00, "today" follows Zammad's timezone_default and
// overlapping jobs of one master are flagged, never blocked.

const Calendar = App.DomServisDispatchCalendar

const rounded = (value) => Math.round(value * 100) / 100

QUnit.test('visit interval of an exact time, a window and free text', assert => {
  assert.deepEqual(Calendar.visitInterval('09:05'), { start: 545, end: 665 }, 'exact time is a 2-hour visit')
  assert.deepEqual(Calendar.visitInterval('09:00-11:30'), { start: 540, end: 690 }, 'window as is')
  assert.deepEqual(Calendar.visitInterval('11:00-10:00'), { start: 660, end: 780 }, 'window ending before its start')
  assert.strictEqual(Calendar.visitInterval(''), null, 'empty')
  assert.strictEqual(Calendar.visitInterval(null), null, 'missing')
  assert.strictEqual(Calendar.visitInterval('после обеда'), null, 'free-text intake time')
  assert.equal(Calendar.timeLabel({ start: 545, end: 665 }), '09:05–11:05')
});

QUnit.test('day layout places visits and keeps untimed and late jobs aside', assert => {
  const [pool, ivan, petr] = Calendar.buildDay(
    [
      { id: 1, assignee_id: 5, visit_time: '08:00-10:00' },
      { id: 2, assignee_id: null, visit_time: '14:00' },
      { id: 3, assignee_id: 5, visit_time: 'после обеда' },
      { id: 4, assignee_id: 5, visit_time: '21:00' },
    ],
    [{ id: null, label: 'Без мастера' }, { id: 5, label: 'Иван' }, { id: 6, label: 'Пётр' }],
  )

  assert.deepEqual([pool.label, ivan.label, petr.label], ['Без мастера', 'Иван', 'Пётр'])
  assert.deepEqual(ivan.entries.map((entry) => [entry.job.id, rounded(entry.top), rounded(entry.height)]), [[1, 0, 16.67]])
  assert.deepEqual(pool.entries.map((entry) => [entry.job.id, rounded(entry.top)]), [[2, 50]])
  assert.deepEqual(ivan.untimed.map((entry) => entry.job.id), [3], 'free text has no place in the grid')
  assert.deepEqual(ivan.outside.map((entry) => [entry.job.id, entry.timeLabel]), [[4, '21:00–23:00']])
  assert.deepEqual(petr.entries, [], 'a free master still gets a column')
});

QUnit.test('overlapping visits of one master are flagged and put side by side', assert => {
  const [pool, ivan] = Calendar.buildDay(
    [
      { id: 1, assignee_id: 5, visit_time: '09:00' },
      { id: 2, assignee_id: 5, visit_time: '10:00-10:30' },
      { id: 3, assignee_id: 5, visit_time: '11:00' },
      { id: 4, assignee_id: null, visit_time: '09:00' },
      { id: 5, assignee_id: null, visit_time: '09:30' },
      { id: 6, assignee_id: 5, visit_time: '20:30' },
    ],
    [{ id: null, label: 'Без мастера' }, { id: 5, label: 'Иван' }],
  )

  assert.deepEqual(ivan.entries.map((entry) => [entry.job.id, entry.conflict]), [[1, true], [2, true], [3, false]])
  assert.deepEqual(ivan.outside.map((entry) => [entry.job.id, entry.conflict]), [[6, false]], 'after 20:00, no overlap')
  assert.deepEqual(ivan.entries.map((entry) => [entry.job.id, entry.left, entry.width]), [[1, 0, 50], [2, 50, 50], [3, 0, 50]])
  assert.deepEqual(pool.entries.map((entry) => entry.conflict), [false, false], 'jobs without a master do not conflict')
});

QUnit.test('touching visits do not overlap; late overlaps still count', assert => {
  const [, ivan] = Calendar.buildDay(
    [
      { id: 1, assignee_id: 5, visit_time: '09:00' },
      { id: 2, assignee_id: 5, visit_time: '11:00-12:00' },
      { id: 3, assignee_id: 5, visit_time: '19:00' },
      { id: 4, assignee_id: 5, visit_time: '20:15' },
    ],
    [{ id: null, label: 'Без мастера' }, { id: 5, label: 'Иван' }],
  )

  assert.deepEqual(ivan.entries.map((entry) => [entry.job.id, entry.conflict]), [[1, false], [2, false], [3, true]])
  assert.deepEqual(ivan.outside.map((entry) => [entry.job.id, entry.conflict]), [[4, true]])
});

QUnit.test('today and the current minute follow the company timezone', assert => {
  const now = new Date(Date.UTC(2026, 8, 27, 22, 30))

  assert.deepEqual(Calendar.zonedNow('UTC', now), { date: '2026-09-27', minutes: 1350 })
  assert.deepEqual(Calendar.zonedNow('Europe/Moscow', now), { date: '2026-09-28', minutes: 90 })
  assert.deepEqual(Calendar.zonedNow('Not/AZone', now), Calendar.zonedNow(null, now), 'an unknown zone falls back to the browser zone')
});

QUnit.test('calendar dates', assert => {
  assert.equal(Calendar.shiftDate('2026-09-30', 1), '2026-10-01')
  assert.equal(Calendar.shiftDate('2026-09-28', -1), '2026-09-27')
  assert.equal(Calendar.weekdayKey('2026-09-28'), 'mon')
});

QUnit.test('board calendar view for a dispatcher', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    viewMode: 'calendar',
    loading: false,
    mobileView: false,
    calendarDate: '2026-09-28',
    dispatcherAccess: () => true,
    adminAccess: () => false,
    companyNow: () => ({ date: '2026-09-28', minutes: 14 * 60 }),
    masterAssigneeOptions: () => [{ id: '5', label: 'Иван' }],
    jobs: [
      { id: 1, assignee_id: 5, visit_date: '2026-09-28', visit_time: '09:00', status: 'taken', service_type: 'Котёл', address: 'Ленина 10' },
      { id: 2, assignee_id: 5, visit_date: '2026-09-28', visit_time: '10:00', status: 'in_progress', service_type: 'Кран' },
      { id: 3, assignee_id: null, visit_date: '2026-09-28', visit_time: '12:00', status: 'cancelled', service_type: 'Отменена' },
      { id: 4, assignee_id: 7, assignee: 'Пётр', visit_date: '2026-09-28', visit_time: '15:00', status: 'taken', service_type: 'Счётчик' },
      { id: 5, assignee_id: 5, visit_date: '2026-09-29', visit_time: '09:00', status: 'taken', service_type: 'Завтра' },
    ],
  })

  const view = board.buildCalendarView()

  assert.equal(view.dateLabel, 'Пн, 28.09.2026')
  assert.ok(view.isToday)
  assert.equal(view.nowTop, 50, 'now line at 14:00')
  assert.equal(view.hours.length, 13, '08:00 to 20:00')
  assert.equal(view.jobCount, 3, 'cancelled and other days left out')
  assert.equal(view.conflictCount, 2)
  assert.deepEqual(view.columns.map((column) => column.label), ['Без мастера', 'Иван', 'Пётр'])
  assert.deepEqual(view.columns[1].entries.map((entry) => [entry.id, entry.conflict]), [[1, true], [2, true]])
  assert.equal(view.columns[1].entries[0].tooltip, '09:00–11:00 · Котёл · Ленина 10 · Взята')

  board.calendarDate = '2026-09-29'
  assert.strictEqual(board.buildCalendarView().nowTop, null, 'no now line on another day')

  board.viewMode = 'board'
  assert.strictEqual(board.buildCalendarView(), null, 'board mode')

  board.viewMode = 'calendar'
  board.mobileView = true
  assert.strictEqual(board.buildCalendarView(), null, 'not on the mobile layout')
});
