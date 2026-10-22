// SPDX-License-Identifier: GPL-3.0-or-later
const key = 'farey.selection.v1';
const valid = value => value?.version === 1 && typeof value.word === 'string'
  && /^[LR]{0,24}$/.test(value.word) && [6, 8, 10, 12, 14].includes(value.grid);

export function readSelection(storage = () => globalThis.sessionStorage) {
  try {
    const raw = storage().getItem(key);
    if (!raw || raw.length > 256) return null;
    const value = JSON.parse(raw);
    return valid(value) ? { word: value.word, grid: value.grid } : null;
  } catch { return null; }
}

export function writeSelection(word, grid, storage = () => globalThis.sessionStorage) {
  const value = { version: 1, word, grid };
  if (!valid(value)) return false;
  try { storage().setItem(key, JSON.stringify(value)); return true; }
  catch { return false; }
}
