// SPDX-License-Identifier: GPL-3.0-or-later
export const MAX_STEPS = 24;
export const add = (a, b) => ({ p: a.p + b.p, q: a.q + b.q });
export const fraction = ({ p, q }) => q === 0 ? '∞' : `${p}/${q}`;
export const onRay = (point, direction) => point.p * direction.q === point.q * direction.p;
export function primitive({ p, q }) {
  while (q) [p, q] = [q, p % q];
  return p === 1;
}
export function inspectPoint(point) {
  if (![point?.p, point?.q].every(n => Number.isSafeInteger(n) && n > 0)) return null;
  let a = point.p, b = point.q;
  while (b) [a, b] = [b, a % b];
  const primitive = { p: point.p / a, q: point.q / a };
  return { point: { ...point }, divisor: a, primitive,
    equation: `(${point.q}, ${point.p}) = ${a} × (${primitive.q}, ${primitive.p})`,
    reduction: `${fraction(point)} = ${fraction(primitive)}` };
}
export function position({ p, q }) {
  const s = 0.25 / Math.sqrt(2);
  return [(p - q) * s, 0, -(p + q) * s];
}
export function grid(bound) {
  const n = Math.min(14, Math.max(6, bound));
  const points = [];
  for (let q = 0; q <= n; q++) for (let p = 0; p <= n; p++) {
    if (p || q) points.push({ p, q });
  }
  return points;
}
export class FareyState {
  constructor() { this.reset(); }
  reset() { this.word = ''; this.left = { p: 0, q: 1 }; this.right = { p: 1, q: 0 }; this.selectedPoint = null; }
  get mediant() { return add(this.left, this.right); }
  get inspection() { return inspectPoint(this.selectedPoint ?? this.mediant); }
  get determinant() { return this.right.p * this.left.q - this.left.p * this.right.q; }
  step(turn) {
    if (!['L', 'R'].includes(turn) || this.word.length >= MAX_STEPS) return false;
    this.selectedPoint = null;
    if (turn === 'L') this.left = this.mediant;
    else this.right = this.mediant;
    this.word += turn;
    return true;
  }
  undo() { const word = this.word.slice(0, -1); this.reset(); for (const turn of word) this.step(turn); }
  select(p, q) {
    if (![p, q].every(n => Number.isInteger(n) && n > 0 && n <= 1000)) return false;
    const candidate = new FareyState();
    while (!onRay(candidate.mediant, { p, q })) {
      if (!candidate.step(candidate.mediant.p * q < p * candidate.mediant.q ? 'L' : 'R')) return false;
    }
    this.word = candidate.word; this.left = candidate.left; this.right = candidate.right;
    this.selectedPoint = { p, q };
    return true;
  }
}
