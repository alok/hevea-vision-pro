// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { FareyState } from './core.js';
import { readSelection, writeSelection } from './recovery.js';

function memory() {
  let value = null;
  return { getItem: () => value, setItem: (_, next) => { value = next; } };
}
test('reload restores the exact word and finite grid', () => {
  const store = memory();
  assert.equal(writeSelection('RLR', 14, () => store), true);
  const saved = readSelection(() => store), state = new FareyState();
  for (const turn of saved.word) state.step(turn);
  assert.deepEqual(state.mediant, { p: 3, q: 5 });
  assert.equal(saved.grid, 14);
  assert.equal(writeSelection('', 12, () => store), true);
  assert.deepEqual(readSelection(() => store), { word: '', grid: 12 });
});
test('untrusted saved state cannot exceed navigation or geometry limits', () => {
  for (const value of [null, {}, { version: 2, word: 'R', grid: 12 },
    { version: 1, word: 'X', grid: 12 }, { version: 1, word: 'L'.repeat(25), grid: 12 },
    { version: 1, word: 'R', grid: 999 }]) {
    assert.equal(readSelection(() => ({ getItem: () => JSON.stringify(value) })), null);
  }
});
test('corrupt or unavailable storage does not break the live demo', () => {
  assert.equal(readSelection(() => ({ getItem: () => '{broken' })), null);
  const unavailable = () => { throw Error('storage blocked'); };
  assert.equal(readSelection(unavailable), null);
  assert.equal(writeSelection('R', 12, unavailable), false);
  assert.equal(writeSelection('X', 12, () => memory()), false);
});
