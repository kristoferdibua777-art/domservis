// «Сейчас открыто / закрыто» рядом с телефоном и часами работы.
// Считает по времени Калининграда, а не по часам посетителя; праздники не учитывает.
// Без скрипта строки остаются скрытыми (атрибут hidden в разметке).
;(function () {
  'use strict'

  // Часы работы в минутах от полуночи по дням недели (0 — воскресенье, выходной).
  var HOURS = {
    1: [600, 1080],
    2: [600, 1080],
    3: [600, 1080],
    4: [600, 1080],
    5: [600, 1080],
    6: [600, 900],
  }
  var ON_DAY = [
    'в воскресенье',
    'в понедельник',
    'во вторник',
    'в среду',
    'в четверг',
    'в пятницу',
    'в субботу',
  ]
  var WEEKDAY = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }

  var nodes = document.querySelectorAll('[data-open-status]')
  if (!nodes.length || !window.Intl || !Intl.DateTimeFormat.prototype.formatToParts) return

  var format = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Kaliningrad',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  })

  function kaliningradNow() {
    var parts = {}
    format.formatToParts(new Date()).forEach(function (p) {
      parts[p.type] = p.value
    })
    return { day: WEEKDAY[parts.weekday], minutes: Number(parts.hour) * 60 + Number(parts.minute) }
  }

  function clock(minutes) {
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return h + ':' + (m < 10 ? '0' : '') + m
  }

  function status() {
    var now = kaliningradNow()
    var today = HOURS[now.day]
    if (today && now.minutes >= today[0] && now.minutes < today[1]) {
      return { open: true, text: 'Сейчас открыто, до ' + clock(today[1]) }
    }
    var when
    if (today && now.minutes < today[0]) {
      when = 'сегодня в ' + clock(today[0])
    } else {
      for (var i = 1; i <= 7 && !when; i++) {
        var day = (now.day + i) % 7
        if (HOURS[day]) when = (i === 1 ? 'завтра' : ON_DAY[day]) + ' в ' + clock(HOURS[day][0])
      }
    }
    return {
      open: false,
      text: 'Сейчас закрыто. Перезвоним ' + when + ', заявку можно оставить уже сейчас',
    }
  }

  function render() {
    var s = status()
    Array.prototype.forEach.call(nodes, function (node) {
      node.textContent = s.text
      node.classList.toggle('open-status--open', s.open)
      node.hidden = false
    })
  }

  render()
  setInterval(render, 60 * 1000)
})()
