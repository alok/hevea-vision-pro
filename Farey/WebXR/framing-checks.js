// SPDX-License-Identifier: GPL-3.0-or-later
// Exposes existing renderer state only in this test; no hook is shipped.
async (page) => {
  const ensure = (ok, message) => { if (!ok) throw Error(message); };
  const hook = async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await response.text() + '\nwindow.__viewAudit={camera,controls,lattice,axisLabels};\n' });
  };
  await page.route('**/app.js*', hook);
  try {
    await page.reload();
    const cases = [];
    const pose = () => page.evaluate(() => JSON.stringify({ position: __viewAudit.camera.position,
      target: __viewAudit.controls.target, quaternion: __viewAudit.camera.quaternion }));
    for (const size of [{ width: 390, height: 699 }, { width: 390, height: 844 },
      { width: 844, height: 390 }, { width: 848, height: 562 }]) {
      await page.setViewportSize(size);
      await page.locator('#reset').click(); await page.locator('#bound').selectOption('14');
      const before = await pose();
      await page.locator('#example').click(); await page.locator('#left').click(); await page.locator('#undo').click();
      ensure(await pose() === before, 'Selecting a direction moved the camera');
      const measured = await page.evaluate(async () => {
        const THREE = await import('three');
        const { camera, lattice, axisLabels } = __viewAudit;
        const scene = document.querySelector('canvas').getBoundingClientRect();
        const panel = document.querySelector('.controls').getBoundingClientRect();
        let maxExtent = 0;
        for (const p of [0, 14]) for (const q of [0, 14]) for (const height of [0, 0.65]) {
          const s = 0.25 / Math.sqrt(2);
          const point = lattice.localToWorld(new THREE.Vector3((p-q)*s, height, -(p+q)*s)).project(camera);
          maxExtent = Math.max(maxExtent, Math.abs(point.x), Math.abs(point.y));
        }
        const labelPixels = axisLabels.map(label => {
          const bottom = label.getWorldPosition(new THREE.Vector3());
          const top = bottom.clone().add(new THREE.Vector3(0, label.scale.y, 0).applyQuaternion(camera.quaternion));
          return (top.project(camera).y - bottom.project(camera).y) * scene.height / 2;
        });
        return { scene: scene.toJSON(), panel: panel.toJSON(), maxExtent, labelPixels };
      });
      ensure(measured.scene.bottom <= measured.panel.top || measured.scene.left >= measured.panel.right, 'Controls obscure compact scene');
      ensure(measured.maxExtent < 0.95, 'Maximum grid or plane clips at default view');
      ensure(measured.labelPixels.every(size => Math.abs(size - 28) < 0.01), 'Axis lettering varies with camera depth');
      await page.locator('canvas').focus(); await page.locator('canvas').press('+');
      ensure(await pose() !== before, 'Explicit zoom did not change the view');
      ensure(await page.locator('#word').textContent() === 'RLR', 'Camera controls changed the rational');
      await page.locator('#view').click();
      await page.screenshot({ path: `output/playwright/framing-${size.width}-${size.height}.png` });
      cases.push({ viewport: size, ...measured, selectionPreservedCamera: true, explicitZoomWorked: true });
    }
    return { passed: true, cases, instrumentedRendererInspection: true, actualXRSession: false };
  } finally {
    await page.unroute('**/app.js*', hook);
  }
}
