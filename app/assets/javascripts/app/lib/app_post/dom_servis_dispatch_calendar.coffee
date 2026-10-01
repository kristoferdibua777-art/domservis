# Scheduling helpers for the Dom-Servis dispatcher calendar. Product
# decisions (2026-09-28): an exact visit time means a 2-hour visit, the
# calendar shows 08:00-20:00, "today" follows Zammad's timezone_default and
# overlapping jobs of one master are flagged, never blocked.
class App.DomServisDispatchCalendar
  @DEFAULT_VISIT_MINUTES: 120
  @DAY_START_MINUTES: 8 * 60
  @DAY_END_MINUTES: 20 * 60

  # Cancelled and partner-transferred jobs no longer occupy a master's time.
  @HIDDEN_STATUSES: ['cancelled', 'transferred_to_partner']

  @TIME_PATTERN: /^([01]\d|2[0-3]):([0-5]\d)$/
  @WINDOW_PATTERN: /^([01]\d|2[0-3]):([0-5]\d)-([01]\d|2[0-3]):([0-5]\d)$/

  # { start, end } in minutes after midnight, or null for an empty or
  # free-text (intake) visit time. A window whose end is not after its start
  # is shown as a default-length visit from its start.
  @visitInterval: (visitTime) ->
    value = "#{visitTime || ''}".trim()
    toMinutes = (hours, minutes) -> parseInt(hours, 10) * 60 + parseInt(minutes, 10)

    if (match = value.match(@WINDOW_PATTERN))
      start = toMinutes(match[1], match[2])
      end = toMinutes(match[3], match[4])
      end = start + @DEFAULT_VISIT_MINUTES if end <= start
      return { start: start, end: end }

    if (match = value.match(@TIME_PATTERN))
      start = toMinutes(match[1], match[2])
      return { start: start, end: start + @DEFAULT_VISIT_MINUTES }

    null

  @timeLabel: (interval) ->
    pad = (number) -> ("0#{number}").slice(-2)
    format = (minutes) ->
      minutes = minutes % (24 * 60)
      "#{pad(Math.floor(minutes / 60))}:#{pad(minutes % 60)}"
    "#{format(interval.start)}–#{format(interval.end)}"

  @overlaps: (first, second) ->
    first.start < second.end && second.start < first.end

  # The master's other jobs on the job's day whose time overlaps the job's
  # time, as [{ job, interval, timeLabel }]. Empty when the job has no date
  # or no canonical time.
  @overlappingJobs: (job, masterId, jobs) ->
    interval = @visitInterval(job?.visit_time)
    return [] if !interval || !job.visit_date

    result = []
    for other in jobs || []
      continue if "#{other.id}" is "#{job.id}"
      continue if "#{other.assignee_id}" isnt "#{masterId}"
      continue if "#{other.visit_date || ''}" isnt "#{job.visit_date}"
      continue if other.status in @HIDDEN_STATUSES

      otherInterval = @visitInterval(other.visit_time)
      continue if !otherInterval || !@overlaps(interval, otherInterval)

      result.push({ job: other, interval: otherInterval, timeLabel: @timeLabel(otherInterval) })

    result

  # Lays out one day. columns: [{ id, label }] where id is a master's id or
  # null for jobs without a master. Returns the columns with timed entries
  # (percent geometry within the visible hours, side-by-side lanes for
  # overlapping entries), untimed jobs, jobs outside the visible hours, and
  # a conflict flag on every job of a master that overlaps another one.
  @buildDay: (jobs, columns) ->
    span = @DAY_END_MINUTES - @DAY_START_MINUTES
    byColumn = {}
    byColumn["#{column.id}"] = { id: column.id, label: column.label, entries: [], untimed: [], outside: [] } for column in columns

    for job in jobs
      key = "#{job.assignee_id ? null}"
      column = byColumn[key]
      if !column
        column = byColumn[key] = { id: job.assignee_id, label: "##{job.assignee_id}", entries: [], untimed: [], outside: [] }
        columns = columns.concat([{ id: job.assignee_id }])

      interval = @visitInterval(job.visit_time)
      if !interval
        column.untimed.push({ job: job })
      else if interval.end <= @DAY_START_MINUTES || interval.start >= @DAY_END_MINUTES
        column.outside.push({ job: job, interval: interval, timeLabel: @timeLabel(interval), conflict: false })
      else
        visibleStart = Math.max(interval.start, @DAY_START_MINUTES)
        visibleEnd = Math.min(interval.end, @DAY_END_MINUTES)
        column.entries.push(
          job: job
          interval: interval
          timeLabel: @timeLabel(interval)
          top: (visibleStart - @DAY_START_MINUTES) / span * 100
          height: (visibleEnd - visibleStart) / span * 100
          conflict: false
        )

    for key, column of byColumn
      @markConflicts(column) if column.id?
      @assignLanes(column.entries)

    _.map(columns, (column) -> byColumn["#{column.id}"])

  @markConflicts: (column) ->
    timed = column.entries.concat(column.outside)
    for first, index in timed
      for second in timed[(index + 1)..]
        continue if !@overlaps(first.interval, second.interval)
        first.conflict = true
        second.conflict = true

  # Greedy lanes: an entry takes the first lane that is free at its start;
  # all entries of a column share the width of its widest overlap.
  @assignLanes: (entries) ->
    laneEnds = []
    for entry in _.sortBy(entries, (entry) -> entry.interval.start)
      lane = _.findIndex(laneEnds, (end) -> end <= entry.interval.start)
      lane = laneEnds.length if lane < 0
      laneEnds[lane] = entry.interval.end
      entry.lane = lane

    lanes = Math.max(laneEnds.length, 1)
    for entry in entries
      entry.width = 100 / lanes
      entry.left = entry.lane * entry.width

    entries

  # Date ("YYYY-MM-DD") and minutes after midnight of `now` in the given
  # IANA zone; falls back to the browser's zone when the zone is missing or
  # unknown.
  @zonedNow: (timeZone, now = new Date()) ->
    try
      formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone: timeZone || undefined
        year: 'numeric'
        month: '2-digit'
        day: '2-digit'
        hour: '2-digit'
        minute: '2-digit'
        hourCycle: 'h23'
      })
      parts = {}
      parts[part.type] = part.value for part in formatter.formatToParts(now)
      return {
        date: "#{parts.year}-#{parts.month}-#{parts.day}"
        minutes: parseInt(parts.hour, 10) * 60 + parseInt(parts.minute, 10)
      }
    catch error
      return @zonedNow(null, now) if timeZone

      pad = (number) -> ("0#{number}").slice(-2)
      {
        date: "#{now.getFullYear()}-#{pad(now.getMonth() + 1)}-#{pad(now.getDate())}"
        minutes: now.getHours() * 60 + now.getMinutes()
      }

  @shiftDate: (date, days) ->
    [year, month, day] = _.map("#{date}".split('-'), (part) -> parseInt(part, 10))
    shifted = new Date(Date.UTC(year, month - 1, day + days))
    shifted.toISOString().slice(0, 10)

  @weekdayKey: (date) ->
    [year, month, day] = _.map("#{date}".split('-'), (part) -> parseInt(part, 10))
    ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][new Date(Date.UTC(year, month - 1, day)).getUTCDay()]
