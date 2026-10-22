// SPDX-License-Identifier: GPL-3.0-or-later
// Run with playwright-cli run-code against the source or static app.
async (page) => {
  const ensure = (value, message) => { if (!value) throw Error(message); };
  const button = name => page.getByRole('button', { name, exact: true });
  const equation = () => page.locator('#point-equation').textContent();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.reload(); await page.setViewportSize({ width: 1440, height: 1000 });
  await button('Reset').click();
  // Project the known scene coordinates, then exercise the actual pointer/raycast path.
  const point = await page.evaluate(async () => {
    const THREE = await import('three');
    const rect = document.querySelector('canvas').getBoundingClientRect();
    const camera = new THREE.PerspectiveCamera(48, rect.width / rect.height, 0.05, 60);
    camera.position.set(3.3, 3.1, 2.1); camera.lookAt(0, 1.75, -3.2); camera.updateMatrixWorld();
    const s = 0.25 / Math.sqrt(2);
    const world = new THREE.Vector3((6 - 10) * s, 0, -(6 + 10) * s)
      .applyAxisAngle(new THREE.Vector3(1, 0, 0), Math.PI / 7).add(new THREE.Vector3(0, 1.8, -2.1));
    world.project(camera);
    return { x: rect.left + (world.x + 1) * rect.width / 2, y: rect.top + (1 - world.y) * rect.height / 2 };
  });
  await page.mouse.move(point.x, point.y);
  ensure((await page.locator('#hover').textContent()).includes('6/10'), 'Pointer did not hit the actual 6/10 sphere');
  await page.mouse.click(point.x, point.y);
  ensure((await equation()).includes('(10, 6) = 2 × (5, 3)'), 'Raycast lost the tapped point');
  ensure(await page.locator('#word').textContent() === 'RLR', 'Wrong canonical L/R word');
  await page.locator('#point-equation').click();
  ensure((await page.locator('#point-detail').textContent()).includes('6/10 = 3/5'), 'Reduction explanation missing');
  await page.reload();
  ensure((await equation()).includes('(10, 6) = 2 × (5, 3)'), 'Reload lost the inspected multiple');
  for (const text of ['0/5', '5/0', '1001/1001', '1/1000']) {
    await page.locator('#rational').fill(text); await button('Select').click();
    ensure((await equation()).includes('(10, 6) = 2 × (5, 3)'), `Invalid ${text} changed point identity`);
  }
  await page.locator('#bound').selectOption('6');
  ensure((await page.locator('#point-detail').textContent()).includes('beyond this finite grid'), 'Hidden point was silently clamped');
  await button('Undo').click();
  ensure((await equation()).includes('(3, 2) = 1 × (3, 2)'), 'Undo retained stale point');
  await button('Reset').click();
  ensure((await equation()).includes('(1, 1) = 1 × (1, 1)'), 'Reset retained stale point');
  await page.locator('#bound').selectOption('14');
  await page.locator('#rational').fill('14/14'); await button('Select').click();
  ensure((await equation()).includes('(14, 14) = 14 × (1, 1)'), 'Grid boundary reduction failed');
  await page.locator('#rational').fill('1000/1000'); await button('Select').click();
  ensure((await equation()).includes('(1000, 1000) = 1000 × (1, 1)'), 'Input boundary identity was lost');
  await button('Learn a move').click();
  ensure((await equation()).includes('(2, 1) = 1 × (2, 1)'), 'Lesson kept stale point');
  await button('Close lesson').click();
  const layouts = [];
  for (const size of [{ width: 390, height: 844 }, { width: 844, height: 390 }, { width: 1440, height: 1000 }]) {
    await page.setViewportSize(size); await button('Reset').click();
    await page.locator('#rational').fill('6/10'); await button('Select').click();
    await page.locator('#point-inspection').evaluate(element => { element.open = true; });
    layouts.push(await page.evaluate(() => ({
      width: innerWidth, height: innerHeight,
      sceneHeight: document.getElementById('viewport').clientHeight,
      overflow: document.querySelector('.controls').scrollWidth > document.querySelector('.controls').clientWidth
    })));
  }
  ensure(layouts.every(layout => layout.sceneHeight > 150 && !layout.overflow), 'Inspector broke a responsive layout');
  ensure(errors.length === 0, errors.join('; '));
  return { passed: true, actualPointerRaycast: { fraction: '6/10', ...point },
    canonicalWord: 'RLR', reloadPreservedMultiple: true, invalidInputPreservedMultiple: true,
    gridAndInputBoundaries: true, undoResetLessonClearIdentity: true, layouts,
    pageErrors: errors, actualXRSession: false };
}
