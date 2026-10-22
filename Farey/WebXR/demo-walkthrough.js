// SPDX-License-Identifier: GPL-3.0-or-later
// Run with the Playwright CLI after video-start. Captures only the local app page.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const button = name => page.getByRole('button', { name, exact: true });
  const row = value => page.locator(`#cf-path li[data-fraction="${value}"] button`);
  const marks = [], errors = [], started = Date.now();
  page.on('pageerror', error => errors.push(error.message));
  const hold = async (name, seconds = 3) => {
    marks.push({ name, seconds: (Date.now() - started) / 1000 });
    await page.screenshot({ path: `output/playwright/browser-demo-${name}.png` });
    await page.waitForTimeout(seconds * 1000);
  };
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.reload(); await button('Reset').click();
  ensure((await page.locator('header').textContent()).includes('Katherine Stange'), 'Missing attribution');
  await hold('start');
  await page.mouse.move(1050, 310); await page.mouse.down();
  for (let step = 1; step <= 30; step++) {
    await page.mouse.move(1050 + step, 310 + step / 3);
    await page.waitForTimeout(40);
  }
  await page.mouse.up(); await hold('orbit');
  await button('Learn a move').click(); await button('2/3').click(); await button('Apply L').click();
  ensure((await page.locator('#fraction').textContent()).includes('2/3'), 'L did not reach 2/3');
  await hold('lesson-L');
  await button('Predict R next').click(); await button('3/5').click(); await button('Apply R').click();
  ensure((await page.locator('#fraction').textContent()).includes('3/5'), 'R did not reach 3/5');
  await hold('lesson-R'); await button('Close lesson').click();
  await page.locator('#rational').fill('6/10'); await button('Select').click();
  await page.locator('#point-equation').click();
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6) = 2 × (5, 3)'), 'Wrong reduction');
  await hold('point-reduction', 4);
  await page.locator('#point-equation').click(); await page.locator('#cf-summary').click();
  await row('2/3').click();
  ensure((await page.locator('#spotlight-status').textContent()).includes('intermediate mediant'), 'Wrong canonical label');
  await hold('intermediate', 4);
  await page.locator('#cf-alternate').check();
  ensure((await page.locator('#spotlight-status').textContent()).includes('Spotlight 2/3: convergent'), 'Wrong alternate label');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Expansion changed target');
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6)'), 'Expansion changed inspection');
  await hold('convergent', 4);
  await row('1/2').click(); await hold('spotlight');
  await page.locator('#cf-summary').click();
  await page.getByText('Mathematics & sources', { exact: true }).click();
  ensure(await page.getByRole('link', { name: 'Caroline Series (1985) ↗' }).isVisible(), 'Missing Series credit');
  await hold('sources', 4);
  await page.getByText('Mathematics & sources', { exact: true }).click();
  await button('Reset').click(); await button('3/5 example').click();
  await hold('finish');
  ensure(errors.length === 0, errors.join('; '));
  return { passed: true, marks, durationSeconds: (Date.now() - started) / 1000,
    browser: await page.evaluate(() => navigator.userAgent), pageErrors: errors, actualXRSession: false };
}
