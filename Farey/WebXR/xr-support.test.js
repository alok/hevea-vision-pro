import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';

test('missing, insecure and unsupported XR preserve a useful desktop fallback', async () => {
  const unavailable = await xrAvailability(undefined, true);
  assert.equal(unavailable.supported, false);
  assert.match(unavailable.message, /Desktop/);
  assert.match((await xrAvailability({}, false)).message, /HTTPS/);
  assert.equal((await xrAvailability({ isSessionSupported: async () => false }, true)).supported, false);
});
test('support detection handles browser rejection and reports supported devices', async () => {
  const rejected = await xrAvailability({ isSessionSupported: async () => { throw Error('denied'); } }, true);
  assert.equal(rejected.supported, false);
  assert.match(rejected.message, /could not check/);
  assert.equal((await xrAvailability({ isSessionSupported: async mode => mode === 'immersive-vr' }, true)).supported, true);
});
test('a transient ray uses its new pose before the next rendered frame', () => {
  const parent = new THREE.Group(), controller = new THREE.Group();
  parent.add(controller); parent.updateMatrixWorld(true);
  parent.position.set(3, 0, 0);
  controller.position.set(0, 1, 0);
  controller.rotation.y = Math.PI / 2;
  const raycaster = new THREE.Raycaster();
  controllerRay(controller, raycaster);
  assert.deepEqual(raycaster.ray.origin.toArray(), [3, 1, 0]);
  assert.ok(raycaster.ray.direction.distanceTo(new THREE.Vector3(-1, 0, 0)) < 1e-12);
});
test('desktop camera and orbit target recover after XR changes the camera pose', () => {
  const camera = new THREE.PerspectiveCamera(); camera.position.set(3, 2, 4);
  const controls = { target: new THREE.Vector3(0, 1, -3), update() { camera.lookAt(this.target); } };
  controls.update(); const view = captureView(camera, controls);
  camera.position.set(0, 1.6, 0); controls.target.set(0, 0, 0);
  restoreView(view, camera, controls);
  assert.deepEqual(camera.position.toArray(), [3, 2, 4]);
  assert.deepEqual(controls.target.toArray(), [0, 1, -3]);
  assert.ok(camera.quaternion.angleTo(view.quaternion) < 1e-7);
});
