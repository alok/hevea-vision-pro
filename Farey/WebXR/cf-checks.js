// SPDX-License-Identifier: GPL-3.0-or-later
// Run with playwright-cli run-code against the source or built artifact.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const button = name => page.getByRole('button', { name, exact: true });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.reload(); await page.setViewportSize({ width: 1440, height: 1000 });
  await button('Reset').click();
  await page.locator('#rational').fill('6/10'); await button('Select').click();
  await page.locator('#cf-summary').click();
  const kind = value => page.locator(`#cf-path li[data-fraction="${value}"]`);
  ensure((await page.locator('#cf-summary').textContent()).includes('[0; 1, 1, 2]'), 'Wrong canonical expansion');
  ensure((await kind('2/3').textContent()).includes('Intermediate mediant'), '2/3 wrongly labeled a canonical convergent');
  ensure((await kind('1/2').textContent()).includes('Convergent'), '1/2 must be a canonical convergent');
  const clip = { x: 520, y: 150, width: 800, height: 360 };
  const canonicalPixels = await page.screenshot({ clip });
  await page.locator('#cf-alternate').check();
  ensure((await page.locator('#cf-summary').textContent()).includes('[0; 1, 1, 1, 1]'), 'Wrong alternate expansion');
  ensure((await kind('2/3').textContent()).includes('Convergent'), 'Alternate 2/3 classification did not change');
  const alternatePixels = await page.screenshot({ clip });
  ensure(!canonicalPixels.equals(alternatePixels), 'The unobscured 3D rings did not change');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Expansion toggle changed the L/R word');
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6) = 2 × (5, 3)'), 'Expansion toggle changed inspected point');
  await page.reload();
  ensure(!await page.locator('#cf-alternate').isChecked(), 'Reload should restore canonical display');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Reload lost the rational');
  for (const [input, label] of [['1/1', '[1]'], ['3/1', '[3]'], ['1/5', '[0; 5]'], ['5/3', '[1; 1, 2]']]) {
    await page.locator('#rational').fill(input); await button('Select').click();
    ensure((await page.locator('#cf-summary').textContent()).includes(label), `Wrong expansion for ${input}`);
  }
  await button('Learn a move').click(); await button('2/3').click(); await button('Apply L').click();
  ensure((await page.locator('#cf-summary').textContent()).includes('[0; 1, 2]'), 'Lesson CF not synchronized');
  await button('Close lesson').click();
  const layouts = [];
  for (const size of [{ width: 390, height: 844 }, { width: 844, height: 390 }, { width: 1440, height: 1000 }]) {
    await page.setViewportSize(size); await button('Reset').click(); await button('3/5 example').click();
    if (!await page.locator('#cf-alternate').isVisible()) await page.locator('#cf-summary').click();
    await page.locator('#cf-alternate').check();
    layouts.push(await page.evaluate(() => ({ width: innerWidth, sceneHeight: document.getElementById('viewport').clientHeight,
      overflow: document.querySelector('.controls').scrollWidth > document.querySelector('.controls').clientWidth })));
  }
  ensure(layouts.every(l => l.sceneHeight > 150 && !l.overflow), 'CF inspector broke a supported layout');
  ensure(!errors.length, errors.join('; '));
  return { passed: true, canonical: '[0; 1, 1, 2]', alternate: '[0; 1, 1, 1, 1]',
    twoThirdsChangesClassification: true, exactStatePreserved: true, unobscuredRingPixelsChanged: true,
    integersUnitFractionsAndImproperFractions: true, lessonSynchronized: true, layouts, pageErrors: errors, actualXRSession: false };
}
