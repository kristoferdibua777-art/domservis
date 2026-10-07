// Runs axe-core (WCAG 2.0/2.1/2.2 A+AA rules) on the dispatch board harness screens and on
// every step of the partner request wizard at a mobile width.
// Usage: node axe-test.js <board.html> <repo> [width=360] > axe-report.json
// Needs `npm i axe-core playwright` next to the script (see README.md).
const { chromium } = require('playwright')
const fs = require('fs')
const path = require('path')
const [,, boardHtml, repo, widthArg = '360'] = process.argv
const width = Number(widthArg)
const axeSrc = fs.readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8')
const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']

const BOARD = [
  { name: 'доска / мастер', q: 'role=master&screen=board', scope: '.dom-servis-dispatch-board' },
  { name: 'доска / диспетчер', q: 'role=dispatcher&screen=board', scope: '.dom-servis-dispatch-board' },
  { name: 'стенд / мастер', q: 'role=master&screen=pool', scope: '.dom-servis-dispatch-board' },
  { name: 'меню', q: 'role=master&screen=menu', scope: '.dom-servis-dispatch-mobile-menu' },
  { name: 'новая заявка', q: 'role=dispatcher&screen=create', scope: '.dom-servis-dispatch-modal' },
  { name: 'карточка / диспетчер', q: 'role=dispatcher&screen=detail', scope: '.dom-servis-dispatch-drawer' },
]

const run = (p, scope) => p.evaluate(async ({ scope, tags }) => {
  const r = await window.axe.run(scope ? { include: [scope] } : document, { runOnly: { type: 'tag', values: tags } })
  return r.violations.map((v) => ({
    id: v.id, impact: v.impact, help: v.help,
    nodes: v.nodes.slice(0, 6).map((n) => ({ target: n.target.join(' '), summary: n.failureSummary.split('\n').slice(1, 3).join(' ').trim() })),
    count: v.nodes.length,
  }))
}, { scope, tags: TAGS })

;(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' })
  const out = []
  const ctx = await browser.newContext({ viewport: { width, height: 800 }, isMobile: true, hasTouch: true, locale: 'ru-RU' })
  for (const s of BOARD) {
    const p = await ctx.newPage()
    await p.goto(`file://${boardHtml}?${s.q}`)
    await p.addScriptTag({ content: axeSrc })
    out.push({ screen: s.name, violations: await run(p, s.scope) })
    await p.close()
  }

  const wizard = fs.readFileSync(path.join(repo, 'public/assets/form/dom-servis-partner-embed.html'), 'utf8')
  const p = await ctx.newPage()
  await p.route('https://stand.test/**', (route) => {
    const url = route.request().url()
    if (url.includes('/assets/form/')) return route.fulfill({ contentType: 'text/html', body: wizard })
    if (url.endsWith('/api/v1/form_config')) return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ enabled: true, token: 't', endpoint: 'https://stand.test/api/v1/form_submit' }) })
    route.fulfill({ status: 404, body: '' })
  })
  await p.goto('https://stand.test/assets/form/dom-servis-partner-embed.html')
  await p.waitForSelector('.wizard')
  await p.addScriptTag({ content: axeSrc })
  const step = async (name) => { await p.waitForTimeout(350); out.push({ screen: `мастер заявки: ${name}`, violations: await run(p) }) }
  await step('шаг 1')
  await p.click('.js-next')
  await step('шаг 1 с ошибками')
  await p.fill('#name', 'Иван Петров')
  await p.fill('#dom_servis_client_phone', '9001234567')
  await p.click('.js-next'); await step('шаг 2')
  await p.click('.js-next'); await step('шаг 3')
  await p.click('.js-next'); await step('шаг 4')
  await browser.close()
  console.log(JSON.stringify(out, null, 1))
})()
