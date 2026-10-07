// Clicks every visible button/link of the dispatch board harness (board.html from build.js)
// at mobile widths and records what each click did: state change, API call, navigation.
// Playwright's real click fails if another element covers the button, so a pass also
// proves the button is reachable. Usage: node click-test.js <board.html> > clicks.json
const { chromium } = require('playwright')
const [,, page_, widthsArg = '360,390,412'] = process.argv

// Screens: role + harness screen + optional extra state applied before re-render.
const SCREENS = [
  { name: 'доска', role: 'master', screen: 'board' },
  { name: 'доска', role: 'dispatcher', screen: 'board' },
  { name: 'стенд', role: 'master', screen: 'pool' },
  { name: 'фильтры', role: 'dispatcher', screen: 'board', pre: '.dom-servis-dispatch-board__mobile-filters > summary', scope: '.dom-servis-dispatch-board__mobile-filters > :not(summary)' },
  { name: 'меню', role: 'master', screen: 'menu' },
  { name: 'новая заявка', role: 'dispatcher', screen: 'create' },
  { name: 'карточка (стенд)', role: 'master', screen: 'detail' },
  { name: 'карточка (моя)', role: 'master', screen: 'detail', set: { detailJobId: 102 } },
  { name: 'карточка', role: 'dispatcher', screen: 'detail' },
  { name: 'правка', role: 'dispatcher', screen: 'detail', set: { editOpen: true, editingJobId: 101 } },
]

const CLICKABLE = ':is(button, a[href], summary, [role=button], .js-job-card)'
// With a sheet open only its own controls are tested; the board behind it is meant to be covered.
const scopeFor = (sc) => sc.scope || (sc.screen === 'menu' ? '.dom-servis-dispatch-mobile-menu' : sc.screen === 'create' ? '.dom-servis-dispatch-modal' : sc.screen === 'detail' ? '.dom-servis-dispatch-drawer' : '.dom-servis-dispatch-board')

// Instrument the harness: delegate the controller's Spine `events` map with jQuery
// and record side effects instead of performing them.
const instrument = (set) => {
  const b = window.board
  window.__log = { ajax: [], nav: [], notify: [] }
  b.preventDefault = (e) => e && e.preventDefault()
  b.ajax = (o) => window.__log.ajax.push(`${o.type || 'GET'} ${o.url.replace(/^.*\/api\/v1/, '')}`)
  b.navigate = (t) => window.__log.nav.push(t)
  b.formDisable = b.formEnable = () => {}
  b.notify = (o) => window.__log.notify.push(`${o.type}: ${o.msg}`)
  b.apiPath = '/api/v1'
  // Default policy from DomServis::DispatchPolicy (action_default / status_default / field_*_default).
  const role = b.permissionCheck('dom_servis.dispatcher') ? 'dispatcher' : 'master'
  const actions = {
    master: 'take_job release_to_pool set_status_in_progress set_status_done add_comment add_attachment',
    dispatcher: 'create_job publish_to_pool take_job release_to_pool set_status_in_progress set_status_done close_job cancel_job transfer_to_partner reopen_job move_job_day move_job_week change_priority change_assignee edit_all_fields add_comment add_attachment remove_attachment delete_job',
  }[role].split(' ')
  const statuses = { master: ['in_progress', 'done'], dispatcher: ['pool', 'taken', 'in_progress', 'done', 'closed', 'cancelled', 'transferred_to_partner'] }[role]
  const readOnly = ['id', 'job_code', 'created_at', 'updated_at', 'created_by_id', 'updated_by_id', 'published_at', 'taken_at', 'completed_at', 'closed_at', 'cancelled_at', 'assignee_id']
  const fields = new Proxy({}, { get: (_t, k) => typeof k !== 'string' ? undefined : ({
    visible: !(role === 'master' && k === 'ticket_id'), editable: role !== 'master' && !readOnly.includes(k) }) })
  b.effectivePolicy = { role_key: role, actions: Object.fromEntries(actions.map((a) => [a, true])), statuses: Object.fromEntries(statuses.map((a) => [a, true])), fields, settings: {} }
  Object.assign(b, set || {})
  b.render()
  const events = Object.getPrototypeOf(b).events
  for (const key of Object.keys(events)) {
    const i = key.indexOf(' ')
    const fn = b[events[key]]
    b.el.on(key.slice(0, i), key.slice(i + 1), (e) => fn.call(b, e))
  }
}

const snapshot = () => {
  const b = window.board
  return JSON.stringify({
    statusFilter: b.statusFilter, dayFilter: b.dayFilter, viewMode: b.viewMode, week: String(b.selectedWeekStart),
    createOpen: b.createOpen, detailOpen: b.detailOpen, detailJobId: b.detailJobId, editOpen: b.editOpen,
    menu: b.mobileWorkspaceMenuOpen, tags: b.activeTagFilters, draftTags: (b.createDraft || {}).work_tags,
    calendarDate: String(b.calendarDate), hash: location.hash,
  })
}

const label = (el) => {
  const cls = [...el.classList].find((c) => c.startsWith('js-')) || el.tagName.toLowerCase()
  const data = ['filter', 'status', 'offset', 'mode', 'target', 'tag', 'id'].map((k) => el.dataset[k] !== undefined ? `${k}=${el.dataset[k]}` : null).filter(Boolean).join(' ')
  const text = (el.getAttribute('aria-label') || el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 40)
  return { cls, data, text, href: el.getAttribute('href') || '' }
}

;(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' })
  const rows = []
  for (const width of widthsArg.split(',').map(Number))
  for (const sc of SCREENS) {
    const ctx = await browser.newContext({ viewport: { width, height: 800 }, isMobile: true, hasTouch: true, locale: 'ru-RU' })
    const p = await ctx.newPage()
    const errs = []
    p.on('pageerror', (e) => errs.push(e.message))
    const open = async () => {
      await p.goto(`file://${page_}?role=${sc.role}&screen=${sc.screen}`)
      await p.evaluate(instrument, sc.set)
      if (sc.pre) await p.click(sc.pre)
    }
    await open()
    const sel = `${scopeFor(sc)} ${CLICKABLE}`
    const items = await p.evaluate(({ sel, labelSrc }) => {
      const label = eval(labelSrc)
      return [...document.querySelectorAll(sel)].map((el, i) => {
        const r = el.getBoundingClientRect(), s = getComputedStyle(el)
        return { i, ...label(el), w: Math.round(r.width), h: Math.round(r.height), visible: r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' }
      })
    }, { sel, labelSrc: `(${label})` })
    for (const it of items) {
      if (!it.visible) continue
      await open()
      const before = await p.evaluate(snapshot)
      const loc = p.locator(sel).nth(it.i)
      let clickErr = null, chooser = false
      const fc = !/upload/.test(it.cls) ? Promise.resolve() : p.waitForEvent('filechooser', { timeout: 800 }).then(() => { chooser = true }).catch(() => {})
      // Links leaving the board (tel:, ticket) are not followed, only checked for reachability.
      const external = it.href && !it.href.startsWith('#') || it.href.startsWith('#ticket')
      try {
        await loc.scrollIntoViewIfNeeded()
        await loc.click({ timeout: 1500, trial: !!external })
      } catch (e) { clickErr = e.message.split('\n').find((l) => /intercepts|not visible|outside/.test(l)) || e.message.split('\n')[0] }
      await fc
      const after = await p.evaluate(snapshot)
      const log = await p.evaluate(() => window.__log)
      const a = JSON.parse(before), b = JSON.parse(after)
      const diff = Object.keys(b).filter((k) => JSON.stringify(a[k]) !== JSON.stringify(b[k])).map((k) => `${k}: ${JSON.stringify(a[k])}→${JSON.stringify(b[k])}`)
      rows.push({ width, screen: sc.name, role: sc.role, ...it, clickErr, diff, ajax: log.ajax, nav: log.nav, notify: log.notify, chooser, errs: errs.splice(0) })
    }
    await ctx.close()
  }
  await browser.close()
  console.log(JSON.stringify(rows, null, 1))
})()
