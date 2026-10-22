// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { TapSelection, visibleIntersections, nearestToRay } from './input.js';
import * as THREE from 'three';

const event = (pointerId = 1, clientX = 0, button = 0) => ({ pointerId, clientX, clientY: 0, button });
test('hidden projected-lattice markers cannot intercept a visible point', () => {
  const geometry = new THREE.SphereGeometry(0.3), material = new THREE.MeshBasicMaterial();
  const hidden = new THREE.Mesh(geometry, material), visible = new THREE.Mesh(geometry, material);
  hidden.position.z = 1; hidden.visible = false;
  hidden.updateMatrixWorld(); visible.updateMatrixWorld();
  const ray = new THREE.Raycaster(new THREE.Vector3(0.1, 0.1, 3), new THREE.Vector3(0, 0, -1));
  assert.equal(ray.intersectObjects([hidden, visible])[0].object, hidden);
  assert.equal(visibleIntersections(ray, [hidden, visible])[0].object, visible);
  visible.visible = false;
  assert.equal(visibleIntersections(ray, [hidden, visible]).length, 0);
  geometry.dispose(); material.dispose();
});
test('a primary tap selects once', () => {
  const tap = new TapSelection(); tap.begin(event());
  assert.equal(tap.end(event(1, 3)), true);
  assert.equal(tap.end(event()), false);
});
test('two fingers never select, regardless of lift order', () => {
  for (const order of [[1, 2], [2, 1]]) {
    const tap = new TapSelection(); tap.begin(event(1)); tap.begin(event(2, 50));
    for (const id of order) assert.equal(tap.end(event(id, id === 1 ? 0 : 50)), false);
  }
});
test('a drag returning to its start is still a drag', () => {
  const tap = new TapSelection(); tap.begin(event()); tap.move(event(1, 40)); tap.move(event());
  assert.equal(tap.end(event()), false);
});
test('cancelled gestures do not select and a later tap recovers', () => {
  const tap = new TapSelection(); tap.begin(event()); tap.cancel(event());
  assert.equal(tap.end(event()), false);
  tap.begin(event(2)); assert.equal(tap.end(event(2)), true);
});
test('secondary mouse buttons do not select', () => {
  const tap = new TapSelection(); tap.begin(event(1, 0, 2));
  assert.equal(tap.end(event(1, 0, 2)), false);
});

test('ray picking chooses the center with the smallest angle and ignores points behind the eye', () => {
  const centers = [[0, 0, -5], [0.2, 0, -5], [0, 0, 5], [0.01, 0, -1]];
  assert.equal(nearestToRay([0, 0, 0], [0, 0, -1], centers, 0.05), 0);
  assert.equal(nearestToRay([0, 0, 0], [0.04, 0, -1], centers, 0.05), 1);
  assert.equal(nearestToRay([0, 0, 0], [0, 0, 1], centers.slice(1), 0.05), 1);
  assert.equal(nearestToRay([0, 0, 0], [1, 0, 0], centers, 0.05), -1);
  assert.equal(nearestToRay([0, 0, 0], [0, 0, -1], [[0, 0, -5], [0, 0, -2]], 0.05), 1);
  assert.equal(nearestToRay([0, 0, 0], [0, 0, -1], [[0, 0, -5], [0, 0, -0.01]], 0.05, 0.05), 0);
});
