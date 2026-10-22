// SPDX-License-Identifier: GPL-3.0-or-later
// Playwright CLI walkthrough. Open a loopback-served artifact before running.
async (page) => {
  const url = new URL(page.url());
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname)) throw Error('Use a loopback preview, not a deployed site.');
  const browser = page.context().browser();
  const ensure = (condition, message) => { if (!condition) throw Error(message); };
  const contexts = [];
  const requests = [], externalRequests = [], badResponses = [], errors = [], badMimeTypes = [];
  const mimeTypes = {};
  const fresh = async options => {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block', ...options });
    contexts.push(context);
    await context.route('**/*', route => {
      const requestURL = new URL(route.request().url());
      requests.push(requestURL.href);
      if (requestURL.origin !== url.origin) {
        externalRequests.push(requestURL.href);
        return route.abort();
      }
      return route.continue();
    });
    const tab = await context.newPage();
    tab.on('response', response => {
      const path = new URL(response.url()).pathname;
      const type = response.headers()['content-type'] ?? '';
      mimeTypes[path] = type;
      if (response.status() >= 400) badResponses.push(`${response.status()} ${response.url()}`);
      if (path.endsWith('.js') && !/^(text|application)\/javascript/.test(type) || path.endsWith('.css') && !type.startsWith('text/css')) {
        badMimeTypes.push(`${path}: ${type}`);
      }
    });
    return { context, tab };
  };
  const ready = async tab => {
    await tab.locator('#xr').filter({ hasText: /VR unavailable here|Enter VR/ }).waitFor();
    ensure(await tab.locator('canvas').count() === 1, 'No lattice canvas');
    ensure(await tab.locator('#fatal').isHidden(), 'Graphics failed to initialize');
    ensure(await tab.evaluate(() => !document.querySelector('canvas').getContext('webgl2').isContextLost()), 'WebGL context is lost');
  };
  try {
    const { context, tab } = await fresh();
    tab.on('pageerror', error => errors.push(error.message));
    await tab.goto(url.href); await ready(tab);
    ensure(await tab.locator('#word').textContent() === 'Start', 'A clean profile inherited a path');
    ensure(await tab.locator('#bound').inputValue() === '12', 'Incorrect fresh grid');
    ensure((await tab.locator('.credit').textContent()).includes('Katherine Stange'), 'Missing prominent credit');
    ensure(await tab.locator('a[href="https://doi.org/10.1112/jlms/s2-31.1.69"]').count() === 1, 'Missing Series reference');
    await tab.locator('#rational').fill('6/10'); await tab.locator('#rational').press('Enter');
    await tab.locator('#bound').selectOption('14'); await tab.reload(); await ready(tab);
    ensure(await tab.locator('#word').textContent() === 'RLR', 'Reload lost the exact path');
    ensure((await tab.locator('#point-equation').textContent()).includes('(10, 6) = 2 × (5, 3)'), 'Reload lost inspected multiple');
    ensure(await tab.locator('#bound').inputValue() === '14', 'Reload lost the grid');
    ensure(await tab.locator('#lesson').isHidden() && await tab.locator('#spotlight-readout').isHidden(), 'Reload restored temporary learning state');
    await context.setOffline(true);
    ensure(await tab.evaluate(() => navigator.onLine) === false, 'Browser offline emulation is inactive');
    await tab.locator('#left').click();
    ensure(await tab.locator('#fraction').textContent() === '3/5 < 5/8 < 2/3', 'Loaded page failed offline L');
    await tab.locator('#undo').click();
    ensure(await tab.locator('#word').textContent() === 'RLR', 'Offline Undo failed');
    await tab.locator('#reset').click();
    ensure(await tab.locator('#word').textContent() === 'Start', 'Offline Reset failed');
    await tab.screenshot({ path: 'output/playwright/offline-desktop.png' });
    let offlineReloadError = '';
    try { await tab.reload({ timeout: 10000 }); } catch (error) { offlineReloadError = error.message.split('\n')[0]; }
    ensure(offlineReloadError.includes('ERR_INTERNET_DISCONNECTED'), 'Fully offline reload unexpectedly reached the local server; record the changed browser behavior');
    await context.setOffline(false); await tab.goto(url.href); await ready(tab);
    ensure(await tab.locator('#word').textContent() === 'Start' && await tab.locator('#bound').inputValue() === '12', 'Reset did not replace saved state');
    await tab.evaluate(() => sessionStorage.setItem('farey.selection.v1', '{broken'));
    await tab.reload(); await ready(tab);
    ensure(await tab.locator('#word').textContent() === 'Start', 'Malformed storage broke fresh state');

    const mobile = await fresh({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
    mobile.tab.on('pageerror', error => errors.push(error.message));
    await mobile.tab.goto(url.href); await ready(mobile.tab);
    ensure(await mobile.tab.locator('#word').textContent() === 'Start', 'A new profile inherited another profile’s state');
    await mobile.context.setOffline(true);
    const layouts = [];
    for (const size of [{ width: 390, height: 844 }, { width: 844, height: 390 }]) {
      await mobile.tab.setViewportSize(size);
      await mobile.tab.locator('#example').click();
      const layout = await mobile.tab.evaluate(() => {
        const scene = document.querySelector('#viewport').getBoundingClientRect();
        return { width: innerWidth, height: innerHeight, scrollWidth: document.documentElement.scrollWidth,
          sceneWidth: scene.width, sceneHeight: scene.height,
          inputFontSize: parseFloat(getComputedStyle(document.querySelector('#rational')).fontSize) };
      });
      ensure(layout.scrollWidth <= layout.width && layout.sceneHeight > 80 && layout.sceneWidth > 80, 'Mobile layout hides the scene or overflows');
      ensure(layout.inputFontSize >= 16, 'Small touch input can trigger Safari automatic zoom');
      ensure(await mobile.tab.locator('#word').textContent() === 'RLR', 'Offline mobile selection failed');
      layouts.push(layout);
      await mobile.tab.screenshot({ path: `output/playwright/offline-mobile-${size.width}.png` });
      await mobile.tab.locator('#reset').click();
    }

    const unavailable = await fresh();
    const expectedErrors = [];
    unavailable.tab.on('pageerror', error => expectedErrors.push(error.message));
    await unavailable.context.addInitScript(() => {
      const getContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function (type, ...args) {
        return /webgl/.test(type) ? null : getContext.call(this, type, ...args);
      };
    });
    await unavailable.tab.goto(url.href);
    await unavailable.tab.locator('#fatal').waitFor({ state: 'visible' });
    ensure((await unavailable.tab.locator('#fatal').textContent()).includes('WebGL-capable browser'), 'Missing unsupported graphics explanation');
    ensure(await unavailable.tab.locator('#xr').textContent() === 'VR unavailable without WebGL', 'Graphics failure left WebXR checking indefinitely');
    ensure(await unavailable.tab.locator('.controls button:not([disabled]),.controls input:not([disabled]),.controls select:not([disabled])').count() === 0, 'Unusable graphics controls remain enabled');
    ensure(await unavailable.tab.getByRole('link', { name: 'Original talk' }).isVisible(), 'Fallback hides the source reference');
    ensure(expectedErrors.every(message => message.includes('WebGL unavailable')), `Unexpected fallback error: ${expectedErrors}`);
    await unavailable.tab.screenshot({ path: 'output/playwright/offline-no-webgl.png' });
    const xrStatus = await tab.locator('#xr-status').textContent();
    ensure(await tab.locator('#xr').isDisabled() && xrStatus.length > 10, 'Expected a useful unsupported-XR fallback in this browser');
    ensure(externalRequests.length === 0, `External runtime requests: ${externalRequests}`);
    ensure(badResponses.length === 0, `Missing assets: ${badResponses}`);
    ensure(badMimeTypes.length === 0, `Incorrect asset MIME types: ${badMimeTypes}`);
    ensure(errors.length === 0, `Unexpected page errors: ${errors}`);
    return { passed: true, browser: browser.version(), origin: url.origin, path: url.pathname,
      freshProfile: true, savedPointAndGridRestored: true, malformedStorageRejected: true,
      loadedPageWorksWithBrowserOffline: true, offlineReloadError, layouts,
      unavailableWebGL: 'mocked context creation failure', expectedErrors, xrStatus,
      runtimeRequests: requests.length, uniqueRuntimePaths: [...new Set(requests.map(value => new URL(value).pathname))],
      externalRequests, badResponses, mimeTypes, errors, actualXRSession: false };
  } finally {
    for (const context of contexts.reverse()) await context.close();
  }
}
