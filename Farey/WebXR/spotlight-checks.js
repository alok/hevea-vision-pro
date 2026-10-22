// SPDX-License-Identifier: GPL-3.0-or-later
// Fresh browser walkthrough plus spotlight state and layout regressions.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const button = name => page.getByRole('button', { name, exact: true });
  const row = value => page.locator(`#cf-path li[data-fraction="${value}"] button`);
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.evaluate(() => sessionStorage.clear()); await page.reload();
  await page.setViewportSize({ width: 1440, height: 1000 });
  ensure((await page.locator('header').textContent()).includes('Katherine Stange'), 'Missing credit');
  ensure(await page.locator('#word').textContent() === 'Start', 'Fresh browser state was not reset');
  await button('Learn a move').click(); await button('2/3').click(); await button('Apply L').click();
  await button('Predict R next').click(); await button('3/5').click(); await button('Apply R').click();
  await button('Close lesson').click();
  await page.locator('#rational').fill('6/10'); await button('Select').click();
  await page.locator('#cf-summary').click();
  const before = await page.screenshot({ clip: { x: 520, y: 150, width: 800, height: 360 } });
  await row('2/3').click();
  ensure((await page.locator('#spotlight-status').textContent()).includes('Spotlight 2/3: intermediate mediant'), 'Wrong spotlight');
  ensure((await page.locator('#spotlight-status').textContent()).includes('Inspected (10, 6) unchanged'), 'Missing inspected-point context');
  const after = await page.screenshot({ clip: { x: 520, y: 150, width: 800, height: 360 } });
  ensure(!before.equals(after), 'No visible spotlight appeared in the unobscured scene');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Spotlight changed L/R');
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6)'), 'Spotlight changed the inspected point');
  await page.locator('#cf-alternate').check();
  ensure((await page.locator('#spotlight-status').textContent()).includes('Spotlight 2/3: convergent'), 'Reclassification lost spotlight');
  await row('1/2').click();
  ensure(await page.evaluate(() => document.activeElement.dataset.cfFraction) === '1/2', 'Row focus was lost after rendering');
  await button('Clear spotlight').click();
  ensure(!await page.locator('#spotlight-readout').isVisible(), 'Clear failed');
  await row('0/1').click();
  ensure(await page.locator('#word').textContent() === 'RLR', 'Boundary spotlight changed the target');
  await button('Undo').click();
  ensure(!await page.locator('#spotlight-readout').isVisible(), 'Undo kept a stale spotlight');
  await button('Reset').click(); await page.locator('#cf-alternate').check(); await row('0/1').click();
  await page.locator('#cf-alternate').uncheck();
  ensure(!await page.locator('#spotlight-readout').isVisible(), 'Removed boundary row retained its spotlight');
  await page.locator('#rational').fill('13/17'); await button('Select').click(); await row('13/17').click();
  ensure((await page.locator('#spotlight-status').textContent()).includes('Outside grid 12'), 'Missing outside-grid explanation');
  await page.locator('#bound').selectOption('6');
  ensure((await page.locator('#spotlight-status').textContent()).includes('Outside grid 6'), 'Grid change moved or lost spotlight');
  await page.locator('#rational').fill('1/0'); await button('Select').click();
  ensure((await page.locator('#spotlight-status').textContent()).includes('Spotlight 13/17'), 'Invalid input changed spotlight');
  await page.reload();
  ensure(!await page.locator('#spotlight-readout').isVisible(), 'Reload retained transient spotlight');
  ensure((await page.locator('#fraction').textContent()).includes('13/17'), 'Reload lost target');
  await button('Learn a move').click(); await button('2/3').click();
  if (!await row('1/1').isVisible()) await page.locator('#cf-summary').click();
  const question = await page.locator('#lesson-question').textContent();
  await row('1/1').click();
  ensure(await page.locator('#lesson-question').textContent() === question, 'Spotlight changed the lesson');
  ensure(await button('2/3').getAttribute('aria-pressed') === 'true', 'Spotlight lost prediction');
  await button('Apply L').click();
  ensure(!await page.locator('#spotlight-readout').isVisible(), 'Lesson move kept stale spotlight');
  await button('Close lesson').click();
  const layouts = [];
  for (const size of [{ width: 390, height: 844 }, { width: 844, height: 390 }, { width: 1440, height: 1000 }]) {
    await page.setViewportSize(size); await button('Reset').click(); await button('3/5 example').click();
    if (!await row('2/3').isVisible()) await page.locator('#cf-summary').click();
    await row('2/3').click();
    layouts.push(await page.evaluate(() => {
      const controls = document.querySelector('.controls'), rect = controls.getBoundingClientRect();
      const status = document.getElementById('spotlight-status').getBoundingClientRect();
      return { width: innerWidth, sceneHeight: document.getElementById('viewport').clientHeight,
        overflow: controls.scrollWidth > controls.clientWidth,
        spotlightContextVisible: status.top >= rect.top && status.bottom <= rect.bottom };
    }));
  }
  ensure(layouts.every(l => l.sceneHeight > 150 && !l.overflow), 'Spotlight broke scene layout');
  ensure(layouts.every(l => l.spotlightContextVisible), 'Spotlight context scrolled out of view');
  ensure(errors.length === 0, errors.join('; '));
  return { passed: true, freshWalkthrough: true, visibleSpotlightPixelsChanged: true, targetAndInspectedPointPreserved: true,
    convergentIntermediateAndBoundaryRows: true, expansionToggle: true, undoResetAndTargetChanges: true,
    outsideGridRetained: true, lessonPredictionPreserved: true, keyboardRowFocusPreserved: true,
    reloadPreservedTargetAndClearedTransientSpotlight: true, layouts, pageErrors: errors, actualXRSession: false };
}
