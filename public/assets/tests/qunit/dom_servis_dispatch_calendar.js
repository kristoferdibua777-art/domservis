// Dom-Servis dispatcher calendar: an exact visit time is a 2-hour visit, the
// day shows 08:00-20:00 (defaults of the dispatch policy settings), "today"
// follows Zammad's timezone_default and overlapping jobs of one master are
// flagged, never blocked.

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

QUnit.test('visit length and calendar hours come from the policy settings', assert => {
  const current = () => [Calendar.DAY_START_MINUTES, Calendar.DAY_END_MINUTES, Calendar.DEFAULT_VISIT_MINUTES]

  try {
    Calendar.configure({ visit_duration_minutes: 90, calendar_day_start_hour: 6, calendar_day_end_hour: 22 })
    assert.deepEqual(Calendar.visitInterval('09:00'), { start: 540, end: 630 }, 'an exact time lasts the set length')
    assert.deepEqual(Calendar.visitInterval('09:00-12:00'), { start: 540, end: 720 }, 'a window stays as is')

    const [, ivan] = Calendar.buildDay(
      [
        { id: 1, assignee_id: 5, visit_time: '06:00' },
        { id: 2, assignee_id: 5, visit_time: '21:00' },
        { id: 3, assignee_id: 5, visit_time: '22:00' },
      ],
      [{ id: null, label: 'Без мастера' }, { id: 5, label: 'Иван' }],
    )
    assert.deepEqual(ivan.entries.map((entry) => [entry.job.id, rounded(entry.top), rounded(entry.height)]), [[1, 0, 9.38], [2, 93.75, 6.25]], 'placed within 06:00-22:00')
    assert.deepEqual(ivan.outside.map((entry) => entry.job.id), [3], 'from 22:00 on the job is outside the day')

    Calendar.configure({ visit_duration_minutes: 'abc', calendar_day_start_hour: 18, calendar_day_end_hour: 9 })
    assert.deepEqual(current(), [480, 1200, 120], 'unusable values and a day ending before it starts fall back to the defaults')

    Calendar.configure({ visit_duration_minutes: 720, calendar_day_start_hour: 0, calendar_day_end_hour: 24 })
    assert.deepEqual(current(), [0, 1440, 720], 'the whole day and the longest visit')
  } finally {
    Calendar.configure(null)
  }

  assert.deepEqual(current(), [480, 1200, 120], 'without settings the defaults apply')
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

QUnit.test('the board applies the policy settings to the calendar', assert => {
  const requests = []
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    apiPath: '/api/v1',
    viewMode: 'calendar',
    loading: false,
    mobileView: false,
    calendarDate: '2026-09-28',
    dispatcherAccess: () => true,
    adminAccess: () => false,
    companyNow: () => ({ date: '2026-09-28', minutes: 7 * 60 }),
    masterAssigneeOptions: () => [],
    jobs: [],
    ajax: (options) => requests.push(options),
    render: () => {},
  })

  try {
    assert.equal(board.buildCalendarView().bodyHeight, 672, 'default 12 hours, 56 px each')

    board.loadEffectivePolicy()
    requests[0].success({ role_key: 'dispatcher', settings: { visit_duration_minutes: 60, calendar_day_start_hour: 6, calendar_day_end_hour: 22 } })

    const view = board.buildCalendarView()
    assert.deepEqual([view.hours[0].label, view.hours[view.hours.length - 1].label, view.hours.length], ['06:00', '22:00', 17])
    assert.equal(view.bodyHeight, 16 * 56, 'the grid grows with the visible hours')
    assert.equal(view.nowTop, 6.25, 'now line at 07:00 within 06:00-22:00')
    assert.equal(App.DomServisDispatchCalendar.DEFAULT_VISIT_MINUTES, 60)

    board.loadEffectivePolicy()
    requests[1].error()
    assert.equal(board.buildCalendarView().hours[0].label, '08:00', 'a failed policy load keeps the defaults')
  } finally {
    Calendar.configure(null)
  }
});

QUnit.test('calendar uses the day loaded from the server', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    viewMode: 'calendar',
    loading: false,
    mobileView: false,
    calendarDate: '2026-09-28',
    dispatcherAccess: () => true,
    adminAccess: () => false,
    companyNow: () => ({ date: '2026-09-27', minutes: 0 }),
    masterAssigneeOptions: () => [],
    jobs: [{ id: 1, visit_date: '2026-09-28', visit_time: '09:00', status: 'pool', service_type: 'From the board page' }],
    calendarJobs: { '2026-09-28': [{ id: 2, visit_date: '2026-09-28', visit_time: '10:00', status: 'pool', service_type: 'From the server' }] },
  })

  assert.deepEqual(board.buildCalendarView().columns[0].entries.map((entry) => entry.title), ['From the server'])
});

QUnit.test('calendar asks the server for the chosen day', assert => {
  const requests = []
  let renders = 0
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    apiPath: '/api/v1',
    viewMode: 'calendar',
    mobileView: false,
    calendarDate: '2026-09-28',
    calendarJobs: {},
    dispatcherAccess: () => true,
    adminAccess: () => false,
    ajax: (options) => requests.push(options),
    render: () => { renders += 1 },
  })

  board.loadCalendarJobs()

  assert.equal(requests[0].url, '/api/v1/dom_servis/dispatch/jobs')
  assert.deepEqual(requests[0].data, { expand: true, visit_date: '2026-09-28', per_page: 500 })

  requests[0].success([{ id: 2 }])
  assert.deepEqual(board.calendarJobs['2026-09-28'], [{ id: 2 }])
  assert.equal(renders, 1)

  board.editOpen = true
  board.loadCalendarJobs()
  requests[1].success([])
  assert.equal(renders, 1, 'an open editor is not re-rendered')
  assert.deepEqual(board.calendarJobs['2026-09-28'], [], 'but the day is updated')
});

QUnit.test('the card of a job from a loaded calendar day opens', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    jobs: [{ id: 1, service_type: 'On the board page' }],
    calendarJobs: { '2026-09-28': [{ id: 7, service_type: 'Older than the board page' }] },
  })

  assert.equal(board.findJob(1).service_type, 'On the board page')
  assert.equal(board.findJob('7').service_type, 'Older than the board page')
  assert.strictEqual(board.findJob(9), undefined)
});

QUnit.test('overlapping jobs of a master on the job day', assert => {
  const job = { id: 1, visit_date: '2026-09-28', visit_time: '10:00', status: 'pool' }
  const jobs = [
    job,
    { id: 2, assignee_id: 5, visit_date: '2026-09-28', visit_time: '09:00-10:30', status: 'taken' },
    { id: 3, assignee_id: 5, visit_date: '2026-09-28', visit_time: '12:00', status: 'taken' },
    { id: 4, assignee_id: 5, visit_date: '2026-09-29', visit_time: '10:00', status: 'taken' },
    { id: 5, assignee_id: 6, visit_date: '2026-09-28', visit_time: '10:00', status: 'taken' },
    { id: 6, assignee_id: 5, visit_date: '2026-09-28', visit_time: '11:00', status: 'cancelled' },
  ]

  assert.deepEqual(Calendar.overlappingJobs(job, 5, jobs).map((item) => [item.job.id, item.timeLabel]), [[2, '09:00–10:30']])
  assert.deepEqual(Calendar.overlappingJobs(job, '5', jobs).map((item) => item.job.id), [2], 'master id as a string from the select')
  assert.deepEqual(Calendar.overlappingJobs({ id: 9, visit_date: '2026-09-28', visit_time: 'после обеда' }, 5, jobs), [], 'no canonical time')
  assert.deepEqual(Calendar.overlappingJobs({ ...job, assignee_id: 5, visit_time: '09:00' }, 5, [{ ...job, assignee_id: 5, visit_time: '09:00' }]), [], 'the job itself is no conflict')
});

QUnit.test('assigning warns about the master visits at the same time', assert => {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  const job = { id: 1, visit_date: '2026-09-28', visit_time: '10:00', status: 'pool' }

  Object.assign(board, {
    masterAssigneeOptions: () => [{ id: '5', label: 'Иван' }, { id: '6', label: 'Пётр' }],
    jobs: [],
    calendarJobs: {
      '2026-09-28': [
        job,
        { id: 2, assignee_id: 5, visit_date: '2026-09-28', visit_time: '09:00', status: 'taken', service_type: 'Котёл' },
        { id: 3, assignee_id: 5, visit_date: '2026-09-28', visit_time: '11:00-11:30', status: 'taken', service_type: 'Кран' },
      ],
    },
  })

  assert.equal(board.assignmentWarning(job, '5'), 'У мастера в это время: 09:00–11:00 · Котёл; 11:00–11:30 · Кран')
  assert.strictEqual(board.assignmentWarning(job, '6'), null, 'a free master')
  assert.strictEqual(board.assignmentWarning(job, ''), null, 'nobody chosen yet')
  assert.deepEqual(board.assignOptionsFor(job).map((option) => option.label), ['Иван — занят в это время', 'Пётр'])
});

QUnit.test('choosing a master in the card shows the warning at once', assert => {
  let renders = 0
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  board.render = () => { renders += 1 }
  board.setAssignAssignee({ currentTarget: $('<select><option value="5" selected>Иван</option></select>').get(0) })

  assert.equal(board.detailAssignAssigneeId, '5')
  assert.equal(renders, 1)
});

QUnit.test('the open card gets its whole day from the server', assert => {
  const requests = []
  let renders = 0
  const board = Object.create(App.DomServisDispatchBoard.prototype)

  Object.assign(board, {
    apiPath: '/api/v1',
    viewMode: 'board',
    mobileView: true,
    calendarJobs: {},
    detailOpen: true,
    dispatcherAccess: () => true,
    adminAccess: () => false,
    currentDetailJob: () => ({ id: 1, visit_date: '2026-09-30' }),
    ajax: (options) => requests.push(options),
    render: () => { renders += 1 },
  })

  board.loadCalendarJobs('2026-09-30')
  assert.equal(requests[0].data.visit_date, '2026-09-30', 'also for a dispatcher on the mobile layout')
  requests[0].success([{ id: 2 }])
  assert.equal(renders, 1, 'the card of that day is re-rendered')

  board.loadCalendarJobs('2026-10-01')
  requests[1].success([])
  assert.equal(renders, 1, 'another day does not touch the card')
});
