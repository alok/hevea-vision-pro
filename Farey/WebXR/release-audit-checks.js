// SPDX-License-Identifier: GPL-3.0-or-later
// Integration audit of saved state and viewport recovery; no XR session is requested.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  const frame = () => page.screenshot({ clip: { x: 700, y: 150, width: 600, height: 400 } });
  const settle = () => page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.setViewportSize({ width: 1440, height: 1000 }); await page.reload();
  await page.getByRole('button', { name: 'Reset', exact: true }).click();
  await page.getByRole('button', { name: '3/5 example', exact: true }).click(); await settle();
  const before = await frame();
  const viewports = [];
  for (const size of [{ width: 10, height: 1 }, { width: 1, height: 1 }, { width: 390, height: 844 },
    { width: 844, height: 390 }, { width: 1440, height: 1000 }]) {
    await page.setViewportSize(size); await settle();
    viewports.push(await page.evaluate(() => ({ width: innerWidth, height: innerHeight,
      sceneWidth: document.getElementById('viewport').clientWidth, sceneHeight: document.getElementById('viewport').clientHeight })));
  }
  ensure(before.equals(await frame()), 'The 3D view did not recover from a zero-size viewport');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Resize changed the mathematical state');
  const malformed = [null, {}, { version: 1, word: 'X', grid: 12 },
    { version: 1, word: 'L'.repeat(25), grid: 12 }, { version: 1, word: 'RLR', grid: 999 },
    { version: 1, word: 'RLR', grid: 12, point: { p: 5, q: 6 } },
    { version: 1, word: 'RLR', grid: 12, point: { p: 0, q: 0 } },
    { version: 1, word: 'RLR', grid: 12, point: { p: 1001, q: 1001 } }];
  for (const value of malformed) {
    await page.evaluate(value => sessionStorage.setItem('farey.selection.v1', JSON.stringify(value)), value);
    await page.reload();
    ensure(await page.locator('#word').textContent() === 'Start', 'Malformed saved state was accepted');
  }
  await page.evaluate(() => sessionStorage.setItem('farey.selection.v1', JSON.stringify({ version: 1, word: 'RLR', grid: 14, point: { p: 6, q: 10 } })));
  await page.reload();
  ensure(await page.locator('#word').textContent() === 'RLR', 'Valid saved path was lost');
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6) = 2 × (5, 3)'), 'Saved point identity was lost');
  const backgroundFrame = await frame();
  const other = await page.context().newPage();
  await other.goto('about:blank'); await other.bringToFront(); await other.waitForTimeout(300);
  await page.bringToFront(); await other.close(); await settle();
  ensure(backgroundFrame.equals(await frame()), 'Tab foregrounding changed the 3D view');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Tab foregrounding changed the path');
  ensure(errors.length === 0, errors.join('; '));
  return { passed: true, viewports, zeroSizeRecoveryPixelsMatched: true,
    malformedStatesRejected: malformed.length, validSavedSelectionRestored: true,
    tabBackgroundForegroundPreservedView: true, pageErrors: errors, actualXRSession: false };
}
