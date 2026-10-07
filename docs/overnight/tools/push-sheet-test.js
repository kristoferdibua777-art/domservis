// Click test for the Web Push permission sheet from layouts/dispatch_board.html.erb.
// Cuts the sheet (style + markup + script) out of the real layout, serves it on
// http://localhost (a secure context, like HTTPS on the phone) and fakes the
// browser push APIs, so the real sheet code runs end to end.
// Usage: node push-sheet-test.js <repo> <screenshot dir> > push-sheet-report.json
const { chromium } = require('playwright');
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const [repo, outDir] = process.argv.slice(2);

const erb = fs.readFileSync(path.join(repo, 'app/views/layouts/dispatch_board.html.erb'), 'utf8');
const start = erb.indexOf('<%# Web Push onboarding');
const sheet = erb.slice(erb.indexOf('%>', start) + 2, erb.lastIndexOf('</body>'))
  .replace(/<%= content_security_policy_nonce %>/g, '')
  .replace(/<%= javascript_tag nonce: true do -%>/g, '<script>')
  .replace(/<% end -%>/g, '</script>');
const ecdh = crypto.createECDH('prime256v1'); ecdh.generateKeys();
const vapid = ecdh.getPublicKey().toString('base64url');
const page = `<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="csrf-token" content="csrf-test">
<meta name="dom-servis-vapid-public-key" content="${vapid}"></head>
<body style="margin:0;font-family:sans-serif"><div style="padding:16px;height:1200px;background:#eee">Доска</div>
${sheet}</body></html>`;

// Fakes for Notification / serviceWorker / PushManager. Records whether
// requestPermission ran inside a user gesture (navigator.userActivation).
const fakes = (state) => {
  window.__log = { permissionCalls: [], subscribeKeyBytes: null };
  const reg = { pushManager: {
    getSubscription: () => Promise.resolve(null),
    subscribe: (opts) => {
      window.__log.subscribeKeyBytes = opts.applicationServerKey.length;
      window.__log.userVisibleOnly = opts.userVisibleOnly;
      return Promise.resolve({ toJSON: () => ({ endpoint: 'https://fcm.googleapis.com/fcm/send/test', keys: { p256dh: 'p', auth: 'a' } }) });
    },
  } };
  Object.defineProperty(navigator, 'serviceWorker', { value: { ready: Promise.resolve(reg) } });
  window.PushManager = window.PushManager || function () {};
  window.Notification = { permission: state.permission, requestPermission: () => {
    window.__log.permissionCalls.push({ gesture: navigator.userActivation.isActive });
    return Promise.resolve(state.answer);
  } };
};

(async () => {
  const server = http.createServer((req, res) => {
    if (req.url === '/dispatch/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end(page); }
    res.statusCode = 404; res.end();
  }).listen(0);
  const base = `http://localhost:${server.address().port}`;
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const report = [];
  const scenarios = [
    { name: 'allow', permission: 'default', answer: 'granted', click: '#dom-servis-push-onboarding-enable' },
    { name: 'later', permission: 'default', answer: 'default', click: '#dom-servis-push-onboarding-later' },
    { name: 'deny', permission: 'default', answer: 'denied', click: '#dom-servis-push-onboarding-enable' },
    { name: 'already-denied', permission: 'denied' },
    { name: 'signed-out', permission: 'default', signedIn: false },
  ];
  for (const [width, height] of [[360, 640], [390, 844], [412, 915]]) {
    for (const s of scenarios) {
      const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
      const p = await ctx.newPage();
      const errors = [];
      p.on('pageerror', (e) => errors.push(String(e)));
      await p.addInitScript(fakes, s);
      const posted = [];
      await p.route('**/api/v1/users/me', (r) => r.fulfill(s.signedIn === false ? { status: 401, body: '{}' } : { contentType: 'application/json', body: '{"id":1}' }));
      await p.route('**/api/v1/dom_servis/dispatch/push_subscriptions', (r) => {
        posted.push({ body: JSON.parse(r.request().postData()), csrf: r.request().headers()['x-csrf-token'] });
        r.fulfill({ status: 201, contentType: 'application/json', body: '{}' });
      });
      await p.goto(`${base}/dispatch/`);
      await p.waitForTimeout(1200);
      const open = () => p.evaluate(() => document.getElementById('dom-servis-push-onboarding').classList.contains('is-open'));
      const r = { width, scenario: s.name, shownOnLoad: await open() };
      if (r.shownOnLoad) {
        r.layout = await p.evaluate(() => {
          const vw = document.documentElement.clientWidth, vh = window.innerHeight;
          const card = document.getElementById('dom-servis-push-onboarding-card').getBoundingClientRect();
          const buttons = [...document.querySelectorAll('#dom-servis-push-onboarding button')].map((b) => {
            const rect = b.getBoundingClientRect();
            const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
            return { text: b.textContent.trim(), w: Math.round(rect.width), h: Math.round(rect.height), covered: hit !== b, disabled: b.disabled };
          });
          return { cardFits: card.left >= 0 && card.right <= vw && card.top >= 0 && card.bottom <= vh, cardHeight: Math.round(card.height), hscroll: document.documentElement.scrollWidth > vw, buttons };
        });
        if (s.name === 'allow' || s.name === 'already-denied') await p.screenshot({ path: `${outDir}/sheet-${s.name}-${width}.png` });
      }
      if (s.click && r.shownOnLoad) {
        await p.click(s.click);
        await p.waitForTimeout(300);
        r.afterClick = await p.evaluate(() => ({
          enableText: document.getElementById('dom-servis-push-onboarding-enable').textContent,
          status: document.getElementById('dom-servis-push-onboarding-status').textContent,
          snoozed: Number(localStorage.getItem('domServisPushSnoozedUntil') || 0) > Date.now(),
        }));
        if (s.name === 'deny') await p.screenshot({ path: `${outDir}/sheet-deny-${width}.png` });
        await p.waitForTimeout(1000);
        r.openAfterClick = await open();
      }
      r.log = await p.evaluate(() => window.__log);
      r.posted = posted;
      r.errors = errors;
      report.push(r);
      await ctx.close();
    }
  }
  await browser.close();
  server.close();
  console.log(JSON.stringify(report, null, 1));
})();
