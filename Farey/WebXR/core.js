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
export function continuedFraction({ p, q }, alternate = false) {
  if (![p, q].every(n => Number.isSafeInteger(n) && n > 0)) return null;
  const terms = [];
  while (q) { terms.push(Math.floor(p / q)); [p, q] = [q, p % q]; }
  if (alternate) terms.splice(terms.length - 1, 1, terms.at(-1) - 1, 1);
  let previous = { p: 1, q: 0 }, before = { p: 0, q: 1 };
  const convergents = terms.map(term => {
    const next = { p: term * previous.p + before.p, q: term * previous.q + before.q };
    before = previous; previous = next; return next;
  });
  const label = terms.length === 1 ? `[${terms[0]}]` : `[${terms[0]}; ${terms.slice(1).join(', ')}]`;
  return { terms, convergents, label };
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
  cfPoints(alternate = false) {
    const convergents = continuedFraction(this.mediant, alternate).convergents;
    const walk = new FareyState(), visited = [walk.mediant];
    for (const turn of this.word) { walk.step(turn); visited.push(walk.mediant); }
    return [...convergents.filter(point => point.p === 0), ...visited].map(rational => ({
      rational, isConvergent: convergents.some(c => c.p === rational.p && c.q === rational.q)
    }));
  }
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
export class ApproximantSpotlight {
  constructor() { this.clear(); }
  clear() { this.rational = null; this.target = null; }
  focus(rational, state, alternate = false) {
    if (!state.cfPoints(alternate).some(p => p.rational.p === rational.p && p.rational.q === rational.q)) return false;
    this.rational = { ...rational }; this.target = state.mediant; return true;
  }
  reconcile(state, alternate = false) {
    if (!this.rational) return;
    if (this.target.p !== state.mediant.p || this.target.q !== state.mediant.q
      || !state.cfPoints(alternate).some(p => p.rational.p === this.rational.p && p.rational.q === this.rational.q)) this.clear();
  }
}
