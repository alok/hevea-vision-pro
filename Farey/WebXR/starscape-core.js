// SPDX-License-Identifier: GPL-3.0-or-later
// Original implementation of the coefficient-space construction in Stange's talk.
export const height = 4;
export const examples = [[1, -1, 2], [2, -2, 4], [2, 1, 1], [1, 0, 1], [3, 2, 2]];
export const discriminant = ([a, b, c]) => b * b - 4 * a * c;
export const vector = ([a, b, c]) => [-b, a + c, c - a];
export function project(point, h = height) {
  if (!point.every(Number.isSafeInteger) || point[0] <= 0 || discriminant(point) >= 0 || !(h > 0)) return null;
  return vector(point).map(value => value * h / (point[0] + point[2]));
}
export function upperRoot(point) {
  if (!project(point)) return null;
  return [-point[1] / (2 * point[0]), Math.sqrt(-discriminant(point)) / (2 * point[0])];
}
export function stars(bound = 8) {
  if (!Number.isInteger(bound) || bound < 2 || bound > 12) return [];
  const result = [];
  for (let a = 1; a < bound; a++) for (let c = 1; c <= bound - a; c++) {
    for (let b = -bound; b <= bound; b++) if (discriminant([a, b, c]) < 0) result.push([a, b, c]);
  }
  return result;
}
