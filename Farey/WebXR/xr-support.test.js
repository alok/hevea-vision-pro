import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { xrAvailability, controllerRay, captureView, restoreView, mirrorFit } from './xr-support.js';

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
test('desktop field of view, zoom and projection recover after XR overwrites them', () => {
  for (const fov of [45, 100]) {
    const camera = new THREE.PerspectiveCamera(fov, 1280 / 900, 0.05, 60); camera.zoom = 1.7; camera.updateProjectionMatrix();
    camera.position.set(3, 2, 4);
    const controls = { target: new THREE.Vector3(0, 1, -3), update() { camera.lookAt(this.target); } };
    controls.update();
    const view = captureView(camera, controls), projection = camera.projectionMatrix.clone();
    for (let session = 0; session < 2; session++) {
      // What Three.js 0.180 WebXRManager.updateUserCamera does each XR frame.
      camera.projectionMatrix.makePerspective(-0.1, 0.1, 0.1, -0.1, 0.05, 60);
      camera.projectionMatrixInverse.copy(camera.projectionMatrix).invert();
      camera.fov = THREE.MathUtils.RAD2DEG * 2 * Math.atan(1 / camera.projectionMatrix.elements[5]); camera.zoom = 1;
      camera.position.set(0, 1.6, 0); controls.target.set(0, 0, 0);
      restoreView(view, camera, controls);
      assert.equal(camera.fov, fov);
      assert.equal(camera.zoom, 1.7);
      assert.deepEqual(camera.projectionMatrix.elements, projection.elements);
      assert.deepEqual(camera.position.toArray(), [3, 2, 4]);
      assert.deepEqual(controls.target.toArray(), [0, 1, -3]);
      assert.ok(camera.quaternion.angleTo(view.quaternion) < 1e-7);
    }
  }
});
test('a disabled orbit controller does not move a restored first-person or Origin pose', () => {
  const camera = new THREE.PerspectiveCamera(100, 1280 / 900, 0.008, 60);
  const target = new THREE.Vector3(0, 1.4, -3.1);
  camera.position.copy(target);
  camera.quaternion.setFromEuler(new THREE.Euler(1.2, -0.7, 0.3, 'YXZ'));
  let updates = 0;
  // Like OrbitControls, update() re-applies orbit clamping and lookAt even when disabled.
  const controls = { enabled: false, target: target.clone(), update() { updates++; camera.position.y += 1; camera.lookAt(this.target); } };
  const view = captureView(camera, controls), position = camera.position.toArray(), quaternion = camera.quaternion.toArray();
  camera.position.set(0, 1.6, 0); camera.quaternion.identity(); camera.fov = 90; camera.zoom = 1;
  restoreView(view, camera, controls);
  assert.equal(updates, 0);
  assert.equal(controls.enabled, false);
  assert.deepEqual(camera.position.toArray(), position);
  assert.deepEqual(camera.quaternion.toArray(), quaternion);
  assert.deepEqual(controls.target.toArray(), target.toArray());
  assert.equal(camera.fov, 100);
  controls.enabled = true;
  restoreView(view, camera, controls);
  assert.equal(updates, 1, 'enabled controls still synchronize');
});

test('the XR mirror keeps the framebuffer aspect inside the viewport, letterboxed', () => {
  const wide = mirrorFit({ width: 3664, height: 1920 }, { width: 1440, height: 900 });
  assert.equal(wide.width, 1440);
  assert.ok(Math.abs(wide.width / wide.height - 3664 / 1920) < 1e-12 && wide.height <= 900);
  const tall = mirrorFit({ width: 3664, height: 1920 }, { width: 390, height: 844 });
  assert.equal(tall.width, 390);
  assert.ok(Math.abs(tall.width / tall.height - 3664 / 1920) < 1e-12);
  const narrow = mirrorFit({ width: 1000, height: 2000 }, { width: 1440, height: 900 });
  assert.equal(narrow.height, 900);
  assert.equal(narrow.width, 450);
  assert.equal(mirrorFit({ width: 0, height: 10 }, { width: 10, height: 10 }), null);
  assert.equal(mirrorFit({ width: 10, height: 10 }, { width: 10, height: 0 }), null);
});
