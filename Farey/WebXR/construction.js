// SPDX-License-Identifier: GPL-3.0-or-later
export const constructionTitles = ['Boundary chart', 'Direction', 'Integer lattice', 'Direction plane'];
export function boundaryProjection({ p, q }) {
  return q > 0 && p >= 0 ? { p: p / q, q: 1 } : null;
}
export class ConstructionWalkthrough {
  constructor() { this.close(); }
  start() { this.stage = 0; this.animate = false; }
  move(delta) { if (this.stage !== null) this.stage = Math.min(3, Math.max(0, this.stage + delta)); }
  close() { this.stage = null; this.animate = false; }
}
