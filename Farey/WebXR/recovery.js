// SPDX-License-Identifier: GPL-3.0-or-later
import { FareyState, onRay } from './core.js';
const key = 'farey.selection.v1';
function valid(value) {
  if (value?.version !== 1 || typeof value.word !== 'string'
    || !/^[LR]{0,24}$/.test(value.word) || ![6, 8, 10, 12, 14].includes(value.grid)) return false;
  if (value.point == null) return true;
  if (![value.point.p, value.point.q].every(n => Number.isInteger(n) && n > 0 && n <= 1000)) return false;
  const state = new FareyState();
  for (const turn of value.word) state.step(turn);
  return onRay(value.point, state.mediant);
}

export function readSelection(storage = () => globalThis.sessionStorage) {
  try {
    const raw = storage().getItem(key);
    if (!raw || raw.length > 256) return null;
    const value = JSON.parse(raw);
    if (!valid(value)) return null;
    return { word: value.word, grid: value.grid,
      ...(value.point ? { point: { p: value.point.p, q: value.point.q } } : {}) };
  } catch { return null; }
}

export function writeSelection(word, grid, storage = () => globalThis.sessionStorage, point = null) {
  const value = { version: 1, word, grid, ...(point ? { point } : {}) };
  if (!valid(value)) return false;
  try { storage().setItem(key, JSON.stringify(value)); return true; }
  catch { return false; }
}
