// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { position } from './core.js';
import { sideBySideViewport, initialDesktopView, viewDistanceScale, axisLabelWorldSize } from './view.js';

function lattice() {
  const object = new THREE.Object3D(); object.position.set(0, 1.8, -2.1); object.rotation.x = Math.PI / 7;
  object.updateMatrixWorld(); return object;
}
test('compact framing contains the maximum grid and direction plane at phone aspect ratios', () => {
  const object = lattice(), center = object.localToWorld(new THREE.Vector3(...position({ p: 6, q: 6 })));
  for (const front of [false, true]) for (const aspect of [0.6, 0.85, 1, 1.2, 1.4, 2, 3]) {
    const view = initialDesktopView(center.toArray(), true, front);
    const camera = new THREE.PerspectiveCamera(48, aspect, 0.05, 60);
    const target = new THREE.Vector3(...view.target);
    camera.position.fromArray(view.position).sub(target).multiplyScalar(viewDistanceScale(aspect, view.minimumAspect)).add(target);
    camera.lookAt(target); camera.updateMatrixWorld();
    for (const p of [0, 14]) for (const q of [0, 14]) for (const height of [0, 0.65]) {
      const point = new THREE.Vector3(...position({ p, q })); point.y = height;
      object.localToWorld(point); point.project(camera);
      assert.ok(Math.abs(point.x) < 0.95 && Math.abs(point.y) < 0.95, `Clipped at ${aspect}, front=${front}: ${point.toArray()}`);
    }
  }
});
test('axis letters retain their screen size across depth, zoom and viewport height', () => {
  for (const height of [180, 300, 700]) for (const depth of [1, 4, 12]) for (const zoom of [1, 1.5]) {
    const camera = new THREE.PerspectiveCamera(48, 1.5, 0.05, 60); camera.zoom = zoom; camera.updateProjectionMatrix();
    const size = axisLabelWorldSize(depth, height, camera.fov, camera.zoom);
    const bottom = new THREE.Vector3(0, 0, -depth).project(camera);
    const top = new THREE.Vector3(0, size, -depth).project(camera);
    assert.ok(Math.abs((top.y - bottom.y) * height / 2 - 28) < 1e-10);
  }
  assert.equal(axisLabelWorldSize(2, 0, 48), 0);
});
test('short wide windows use a separate scene while portrait and full desktop retain their layouts', () => {
  assert.equal(sideBySideViewport(848, 562), true);
  assert.equal(sideBySideViewport(844, 390), true);
  assert.equal(sideBySideViewport(390, 699), false);
  assert.equal(sideBySideViewport(1440, 1000), false);
});
