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

export function kind(point) {
  const delta = discriminant(point);
  return delta === 0 ? 'null' : delta > 0 ? 'exterior' : point[0] > 0 ? 'upper' : 'lower';
}

// A finite Euclidean ball in the displayed coefficient coordinates, centered at the origin.
// The coefficient triples themselves remain integral; the transformed lattice has covolume 2.
export function coefficientLattice(radius = 6) {
  if (!Number.isInteger(radius) || radius < 4 || radius > 12) return [];
  const result = [];
  for (let a = -radius; a <= radius; a++) for (let b = -radius; b <= radius; b++) {
    for (let c = -radius; c <= radius; c++) {
      if (a === 0 && b === 0 && c === 0) continue;
      const v = vector([a,b,c]);
      if (v.reduce((sum,x)=>sum+x*x,0) <= radius*radius) result.push([a,b,c]);
    }
  }
  return result;
}
export function positiveRepresentative(point) {
  if (discriminant(point) >= 0) return null;
  return point[0] < 0 ? point.map(x=>-x) : [...point];
}
export function projectedRepresentative(point, h = height) {
  const p = positiveRepresentative(point);
  return p ? project(p,h) : null;
}
