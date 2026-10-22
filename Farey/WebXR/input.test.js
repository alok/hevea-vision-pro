// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { TapSelection } from './input.js';

const event = (pointerId = 1, clientX = 0, button = 0) => ({ pointerId, clientX, clientY: 0, button });
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
