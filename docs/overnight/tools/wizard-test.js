const { chromium } = require('playwright');
const fs = require('fs');
const [file, outDir, tag] = process.argv.slice(2);
const html = fs.readFileSync(file, 'utf8');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const results = [];
  for (const width of [360, 390, 412]) {
    const page = await browser.newPage({ viewport: { width, height: 800 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
    const errs = [];
    page.on('pageerror', (e) => errs.push(String(e)));
    let submitted = null;
    await page.route('https://stand.test/**', async (route) => {
      const url = route.request().url();
      if (url.endsWith('/form.html') || url.includes('/assets/form/')) return route.fulfill({ contentType: 'text/html', body: html });
      if (url.endsWith('/api/v1/form_config')) return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ enabled: true, token: 't', endpoint: 'https://stand.test/api/v1/form_submit' }) });
      if (url.endsWith('/api/v1/form_submit')) {
        const req = route.request();
        submitted = req.postDataBuffer().toString('utf8');
        return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ ticket: { number: '71042' } }) });
      }
      route.fulfill({ status: 404, body: '' });
    });
    await page.goto('https://stand.test/assets/form/dom-servis-partner-embed.html');
    await page.waitForSelector('.wizard');
    const shot = async (name) => { if (tag) await page.screenshot({ path: `${outDir}/${tag}-${name}-${width}.png`, fullPage: true }); };
    const metrics = async (step) => page.evaluate((step) => {
      const vw = document.documentElement.clientWidth;
      const small = [];
      document.querySelectorAll('button, .chip span, input:not([type=radio]), textarea, a').forEach((el) => {
        const r = el.getBoundingClientRect();
        if (!r.width || !r.height) return;
        if (el.matches('a') || el.matches('input[type=checkbox]')) return;
        if (r.height < 44 || r.width < 44) small.push(`${el.tagName.toLowerCase()}.${el.className} "${(el.textContent||'').trim().slice(0,20)}" ${Math.round(r.width)}x${Math.round(r.height)}`);
      });
      const overflow = [...document.querySelectorAll('.shell *')].filter((el) => { const r = el.getBoundingClientRect(); return r.width && r.right > vw + 0.5; }).map((el) => el.className || el.tagName).slice(0, 5);
      return { step, hscroll: document.documentElement.scrollWidth > vw, overflow, small };
    }, step);
    const r = { width, steps: [] };
    r.steps.push(await metrics('1-empty')); await shot('step1');
    // empty submit -> errors stay on step 1
    await page.click('.js-next');
    r.emptyErrors = await page.$$eval('[data-error-for]', (els) => els.filter((e) => e.textContent).map((e) => e.dataset.errorFor));
    r.stayedOnStep1 = await page.isVisible('[data-step="0"]');
    await shot('step1-errors');
    await page.fill('#name', 'Мария');
    await page.fill('#dom_servis_client_phone', '9001234567');
    await page.fill('#address', 'Калининград, ул. Ленина, 5, кв. 12');
    await page.click('.js-next');
    await page.waitForSelector('[data-step="1"]:not([hidden])');
    await page.waitForTimeout(350);
    r.steps.push(await metrics('2')); 
    await page.click('.js-next');
    r.step2Error = await page.textContent('[data-error-for="problem"]');
    await shot('step2');
    await page.click('text=Течёт вода');
    await page.fill('#problem_details', 'Стиральная машина течёт снизу');
    await page.click('.js-next');
    await page.waitForSelector('[data-step="2"]:not([hidden])');
    await page.waitForTimeout(350);
    r.steps.push(await metrics('3')); await shot('step3');
    // back keeps values
    await page.click('.js-back'); await page.waitForTimeout(350);
    r.backKeepsProblem = await page.isChecked('input[name=problem][value="Течёт вода"]') && (await page.inputValue('#problem_details')) === 'Стиральная машина течёт снизу';
    await page.click('.js-back'); await page.waitForTimeout(350);
    r.backKeepsContacts = (await page.inputValue('#address')).includes('Ленина') && (await page.inputValue('#dom_servis_client_phone')) === '(900) 123-45-67';
    await page.click('.js-next'); await page.waitForTimeout(350);
    await page.click('.js-next'); await page.waitForTimeout(350);
    await page.click('.js-next');
    r.step3Error = await page.textContent('[data-error-for="brand"]');
    await page.click('text=Bosch');
    await page.click('.js-next');
    await page.waitForSelector('[data-step="3"]:not([hidden])');
    await page.waitForTimeout(350);
    r.submitDisabledBeforeConsent = await page.isDisabled('.js-next');
    r.steps.push(await metrics('4')); await shot('step4');
    // edit link jumps to step
    await page.click('[data-goto="2"]'); await page.waitForTimeout(350);
    r.editJumps = await page.isVisible('[data-step="2"]');
    await page.click('.js-next'); await page.waitForTimeout(350);
    await page.check('#privacy_accepted');
    await page.click('.js-next');
    await page.waitForSelector('.success');
    await shot('success');
    const params = new URLSearchParams();
    const fields = {};
    (submitted || '').split(/------\S+/).forEach((part) => { const m = part.match(/name="([^"]+)"\r\n\r\n([\s\S]*?)\r\n$/); if (m) fields[m[1]] = m[2]; });
    r.payload = fields;
    r.errs = errs;
    results.push(r);
    await page.close();
  }
  console.log(JSON.stringify(results, null, 1));
  await browser.close();
})();
