const { chromium } = require('playwright')
const [,, page_, outDir, tag, screens = 'board,create,detail,menu', roles = 'master,dispatcher'] = process.argv
;(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' })
  const report = []
  for (const role of roles.split(','))
  for (const screen of screens.split(','))
  for (const width of [360, 390, 412]) {
    const ctx = await browser.newContext({ viewport: { width, height: 800 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'ru-RU' })
    const p = await ctx.newPage()
    const errs = []
    p.on('pageerror', (e) => errs.push(e.message))
    await p.goto(`file://${page_}?role=${role}&screen=${screen}`)
    await p.waitForTimeout(300)
    const h = await p.evaluate(() => Math.max(...[...document.querySelectorAll('.dom-servis-dispatch-board, .dom-servis-dispatch-board *')].map((e) => e.scrollHeight), 800))
    await p.setViewportSize({ width, height: Math.min(h, 6000) }); await p.waitForTimeout(150)
    const m = await p.evaluate((W) => {
      const de = document.documentElement
      const vis = (el) => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' }
      const overflow = []
      document.querySelectorAll('.dom-servis-dispatch-board *').forEach((el) => {
        if (!vis(el)) return
        const r = el.getBoundingClientRect()
        if (r.right > W + 1 || r.left < -1) {
          // only report the outermost offender
          if (!el.parentElement || el.parentElement.getBoundingClientRect().right <= W + 1)
            overflow.push(`${el.tagName.toLowerCase()}.${[...el.classList].join('.')} [${Math.round(r.left)}..${Math.round(r.right)}]`)
        }
      })
      const clipped = []
      document.querySelectorAll('.dom-servis-dispatch-board button, .dom-servis-dispatch-board a, .dom-servis-dispatch-board strong, .dom-servis-dispatch-board span, .dom-servis-dispatch-board h1, .dom-servis-dispatch-board h2, .dom-servis-dispatch-board h3, .dom-servis-dispatch-board label').forEach((el) => {
        if (!vis(el)) return
        const s = getComputedStyle(el)
        if (el.scrollWidth > el.clientWidth + 1 && s.overflow !== 'visible' && s.textOverflow !== 'ellipsis' && el.clientWidth > 0)
          clipped.push(`${el.tagName.toLowerCase()}.${[...el.classList].join('.')} "${el.textContent.trim().slice(0, 30)}"`)
      })
      const small = []
      document.querySelectorAll('.dom-servis-dispatch-board button, .dom-servis-dispatch-board a[href], .dom-servis-dispatch-board summary, .dom-servis-dispatch-board select, .dom-servis-dispatch-board input:not([type=file]):not([type=hidden]), .dom-servis-dispatch-board [role=button]').forEach((el) => {
        if (!vis(el)) return
        const r = el.getBoundingClientRect()
        if (r.width < 44 || r.height < 44) small.push(`${el.tagName.toLowerCase()}.${[...el.classList].slice(0, 2).join('.')} "${(el.textContent || el.getAttribute('aria-label') || el.name || '').trim().slice(0, 20)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
      })
      const btns = [...document.querySelectorAll('.dom-servis-dispatch-board button, .dom-servis-dispatch-board a[href], .dom-servis-dispatch-board summary')].filter(vis).filter((el) => {
        const r = el.getBoundingClientRect()
        const x = Math.min(Math.max(r.left + r.width / 2, 0), W - 1), y = r.top + Math.min(r.height / 2, 10)
        if (y < 0 || y > innerHeight) return true
        const top = document.elementFromPoint(x, y); return top && (el === top || el.contains(top) || top.contains(el))
      })
      const overlap = []
      for (let i = 0; i < btns.length; i++) for (let j = i + 1; j < btns.length; j++) {
        const a = btns[i].getBoundingClientRect(), c = btns[j].getBoundingClientRect()
        if (btns[i].contains(btns[j]) || btns[j].contains(btns[i])) continue
        const ix = Math.min(a.right, c.right) - Math.max(a.left, c.left), iy = Math.min(a.bottom, c.bottom) - Math.max(a.top, c.top)
        if (ix > 2 && iy > 2) overlap.push(`"${btns[i].textContent.trim().slice(0, 15)}" x "${btns[j].textContent.trim().slice(0, 15)}" ${Math.round(ix)}x${Math.round(iy)}`)
      }
      return { overlapCount: overlap.length, overlap: overlap.slice(0, 10), scrollW: de.scrollWidth, overflow: overflow.slice(0, 15), clipped: clipped.slice(0, 15), small, err: window.__err || null }
    }, width)
    await p.screenshot({ path: `${outDir}/${tag}-${role}-${screen}-${width}.png`, fullPage: true })
    report.push({ role, screen, width, hscroll: m.scrollW > width, ...m, errs })
    await ctx.close()
  }
  await browser.close()
  console.log(JSON.stringify(report, null, 1))
})()
