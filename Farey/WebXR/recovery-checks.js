// SPDX-License-Identifier: GPL-3.0-or-later
// Playwright CLI function: requires the browser's actual WEBGL_lose_context extension.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const button = name => page.getByRole('button', { name, exact: true });
  await page.reload(); await page.setViewportSize({ width: 1440, height: 1000 });
  await button('Reset').click(); await button('3/5 example').click();
  await page.locator('#bound').selectOption('14');
  await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    window.recoveryEvents = [];
    for (const type of ['webglcontextlost', 'webglcontextrestored']) {
      canvas.addEventListener(type, event => recoveryEvents.push({ type, trusted: event.isTrusted }));
    }
    window.lossExtension = canvas.getContext('webgl2').getExtension('WEBGL_lose_context');
    if (!lossExtension) throw Error('WEBGL_lose_context unavailable');
  });
  let previousFrame;
  const matchingFrames = [];
  for (let cycle = 0; cycle < 3; cycle++) {
    await page.evaluate(() => lossExtension.loseContext());
    await page.locator('#graphics-notice').waitFor({ state: 'visible' });
    ensure(await page.evaluate(() => document.querySelector('canvas').getContext('webgl2').isContextLost()), 'Context did not actually become lost');
    if (cycle === 0) await button('L').click();
    ensure((await page.locator('#graphics-message').textContent()).includes('5/8'), 'Paused notice lost the exact selection');
    await page.evaluate(() => lossExtension.restoreContext());
    await page.locator('#graphics-notice').waitFor({ state: 'hidden' });
    const frame = await page.screenshot({ clip: { x: 0, y: 0, width: 1440, height: 600 } });
    if (previousFrame) matchingFrames.push(frame.equals(previousFrame));
    previousFrame = frame;
    ensure(await page.locator('#fraction').textContent() === '3/5 < 5/8 < 2/3', 'Restoration changed the mathematical state');
  }
  ensure(matchingFrames.every(Boolean), 'Restored frames differ without a state change');
  const events = await page.evaluate(() => recoveryEvents);
  ensure(events.length === 6 && events.every(event => event.trusted), 'Loss/restoration events were not browser generated');
  await page.evaluate(() => lossExtension.loseContext());
  await page.locator('#graphics-notice').waitFor({ state: 'visible' });
  await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), button('Reload page').click()]);
  ensure(await page.locator('#fraction').textContent() === '3/5 < 5/8 < 2/3', 'Reload lost the selected rational');
  ensure(await page.locator('#bound').inputValue() === '14', 'Reload lost the grid');
  await button('Reset').click(); await page.reload();
  ensure(await page.locator('#fraction').textContent() === '0/1 < 1/1 < ∞', 'Reset did not replace the saved state');
  ensure(await page.locator('#bound').inputValue() === '12', 'Reset did not replace the saved grid');
  return { browserGeneratedEvents: events, cycles: 3, matchingFrames, controlsWorkedDuringLoss: true,
    reloadButtonPreservedSelectionAndGrid: true, resetReplacedSavedState: true, mockedContext: false,
    hardwareFailureSimulated: true, actualXRSession: false };
}
