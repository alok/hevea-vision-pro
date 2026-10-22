// SPDX-License-Identifier: GPL-3.0-or-later
async page => {
  const ensure = (condition, message) => { if (!condition) throw Error(message); };
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.reload();
  await page.setViewportSize({ width: 1440, height: 1000 });
  const artifact = new URL(page.url()).pathname.includes('/dist/') ? 'static' : 'source';
  await page.locator('#reset').click();
  await page.locator('#example').click();
  ensure(!(await page.locator('#precision-notice').isVisible()), 'Ordinary 3/5 must stay quiet');
  await page.locator('#reset').click();
  for (let i = 0; i < 24; i++) await page.locator(i % 2 ? '#right' : '#left').click();
  const exact = await page.locator('#fraction').textContent();
  ensure(exact.includes('121393/75025'), 'Incorrect deep target');
  ensure(await page.locator('#precision-notice').isVisible(), 'Missing collision notice');
  ensure((await page.locator('#precision-notice').getAttribute('role')) === 'status', 'Notice must be accessible');
  ensure((await page.locator('#geometry-description').textContent()).includes('Display overlap'), 'Missing canvas description');
  for (const bound of ['6', '14']) {
    await page.locator('#bound').selectOption(bound);
    ensure(await page.locator('#precision-notice').isVisible(), 'Grid change lost the notice');
    ensure((await page.locator('#fraction').textContent()) === exact, 'Grid change changed exact values');
  }
  await page.locator('#cf-summary').click();
  await page.locator('#cf-alternate').check();
  ensure((await page.locator('#fraction').textContent()) === exact, 'Expansion changed the target');
  ensure(await page.locator('#precision-notice').isVisible(), 'Expansion lost the notice');
  await page.locator('#cf-summary').click();
  await page.locator('#construction-start').click();
  ensure(!(await page.locator('#precision-notice').isVisible()), 'Do not diagnose the illustrative construction with the plane test');
  await page.locator('#construction-close').click();
  ensure(await page.locator('#precision-notice').isVisible(), 'Closing construction lost the notice');
  await page.locator('#precision-notice').scrollIntoViewIfNeeded();
  await page.screenshot({ path: `output/playwright/precision-${artifact}-desktop.png`, fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.locator('#precision-notice').scrollIntoViewIfNeeded();
  ensure(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), 'Phone overflow');
  const phoneNotice = await page.locator('#precision-notice').boundingBox();
  ensure(phoneNotice.width <= 390 && phoneNotice.height > 0, 'Phone notice clipped');
  await page.screenshot({ path: `output/playwright/precision-${artifact}-phone.png`, fullPage: true });
  await page.locator('#reset').click();
  ensure(!(await page.locator('#precision-notice').isVisible()), 'Reset left a stale notice');
  await page.locator('#rational').fill('6/10');
  await page.getByRole('button', { name: 'Select', exact: true }).click();
  ensure(!(await page.locator('#precision-notice').isVisible()), 'A scalar multiple is not a precision collision');
  ensure(errors.length === 0, errors.join('\n'));
  return { passed: true, exact, phoneNotice, pageErrors: errors, actualXRSession: false };
}
