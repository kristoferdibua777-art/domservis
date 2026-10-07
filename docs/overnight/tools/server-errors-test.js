// Server-side validation errors in the request wizard must always be visible to the visitor.
const { chromium } = require('playwright');
const fs = require('fs');
const [file] = process.argv.slice(2);
const html = fs.readFileSync(file, 'utf8');
const CASES = [
  { key: 'email-invalid', errors: { email: 'invalid' } },
  { key: 'email-dns', errors: { email: 'getaddrinfo: Name or service not known' } },
  { key: 'title-body', errors: { title: 'required', body: 'required' } },
  { key: 'name-required', errors: { name: 'required' } },
  { key: 'base', errors: { base: 'Form is paused' } },
];
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const results = [];
  for (const c of CASES) {
    const page = await browser.newPage({ viewport: { width: 360, height: 800 }, isMobile: true, hasTouch: true });
    const errs = [];
    page.on('pageerror', (e) => errs.push(String(e)));
    await page.route('https://stand.test/**', (route) => {
      const url = route.request().url();
      if (url.includes('/assets/form/')) return route.fulfill({ contentType: 'text/html', body: html });
      if (url.endsWith('/api/v1/form_config')) return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ enabled: true, token: 't', endpoint: 'https://stand.test/api/v1/form_submit' }) });
      if (url.endsWith('/api/v1/form_submit')) return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ errors: c.errors }) });
      return route.fulfill({ status: 404, body: '' });
    });
    await page.goto('https://stand.test/assets/form/dom-servis-partner-embed.html');
    await page.waitForSelector('.wizard');
    await page.fill('#name', 'Пётр');
    await page.fill('#dom_servis_client_phone', '9007654321');
    for (let i = 0; i < 3; i += 1) { await page.click('.js-next'); await page.waitForTimeout(350); }
    await page.check('#privacy_accepted');
    await page.click('.js-next');
    await page.waitForTimeout(400);
    const r = await page.evaluate(() => {
      const banner = document.querySelector('.banner');
      const visibleStep = [...document.querySelectorAll('[data-step]')].find((s) => !s.hidden);
      return {
        banner: banner && banner.textContent.trim(),
        fieldErrors: [...document.querySelectorAll('[data-error-for]')].filter((e) => e.textContent.trim()).map((e) => `${e.dataset.errorFor}: ${e.textContent.trim()}`),
        step: visibleStep && visibleStep.dataset.step,
        submitEnabled: !document.querySelector('.js-next').disabled,
      };
    });
    r.case = c.key;
    r.visibleMessage = Boolean(r.banner || r.fieldErrors.length);
    r.errs = errs;
    results.push(r);
    await page.close();
  }
  console.log(JSON.stringify(results, null, 1));
  await browser.close();
})();
