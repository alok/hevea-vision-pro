// SPDX-License-Identifier: GPL-3.0-or-later
// The roots of the upper interior forms in the upper half-plane, as the right-hand diagram of Stange's viewer
// presents them, in original code. Each base form (a, b, c), a > 0, Δ < 0, is drawn at the root of its image under
// the current g ∈ SL₂(ℝ): with (a′, b′, c′) = g·(a, b, c), the root is −b′/2a′ + i√|Δ|/2a′. Its radius is
// 0.03·σ·scale/a′ px, the rule her viewer follows (a fixed hyperbolic size shrinking as 1/√|Δ| along a ray of
// multiples). Dragging applies her transvection drag (mobius.dragStep); the pane itself never changes base identities.
import { pushforward } from './mobius.js';

const minPixels = 0.6, pickPixels = 7, threshold = 4;

export class RootsPane {
  constructor(canvas, { onDragStep, onDragEnd, onPick, label, colorOf }) {
    this.canvas = canvas; this.onDragStep = onDragStep; this.onDragEnd = onDragEnd; this.onPick = onPick;
    this.label = label; this.colorOf = colorOf;
    this.ctx = canvas.getContext('2d');
    this.view = null; this.data = null; this.down = null; this.hover = -1; this.stars = null;
    canvas.addEventListener('pointerdown', e => this.pointerDown(e));
    canvas.addEventListener('pointermove', e => this.pointerMove(e));
    canvas.addEventListener('pointerup', e => this.pointerUp(e));
    canvas.addEventListener('pointercancel', () => { this.down = null; this.canvas.classList.remove('is-dragging'); });
    canvas.addEventListener('pointerleave', () => { if (!this.down && this.hover >= 0) { this.hover = -1; this.draw(); } });
    canvas.addEventListener('wheel', e => this.wheel(e), { passive: false });
    // A resize keeps the current pan and zoom, rescaled to the new width.
    this.width = 0;
    new ResizeObserver(() => {
      const { w } = this.size();
      if (this.view && this.width > 0 && w > 0) this.view = { ...this.view, scale: this.view.scale * w / this.width };
      this.width = w; this.draw();
    }).observe(canvas);
  }
  /** abc: the lattice's Int16Array of base triples; g: the current group element; selected/second: base triples. */
  setData(data) { this.data = data; this.stars = null; this.draw(); }
  size() { const r = this.canvas.getBoundingClientRect(); return { w: r.width, h: r.height, left: r.left, top: r.top }; }
  fitView() { const { w, h } = this.size(); const scale = w / 2.4; return { cx: 0, cy: (h / 2 - 28) / scale, scale }; }
  ensureView() { if (!this.view) this.view = this.fitView(); return this.view; }
  toScreen(z) { const { w, h } = this.size(), v = this.ensureView(); return [w / 2 + (z.x - v.cx) * v.scale, h / 2 - (z.y - v.cy) * v.scale]; }
  /** The upper half-plane point under canvas pixel (x, y), or null on or below the real axis. */
  toH(x, y) {
    const { w, h } = this.size(), v = this.ensureView(), z = { x: v.cx + (x - w / 2) / v.scale, y: v.cy - (y - h / 2) / v.scale };
    return z.y > 1e-6 ? z : null;
  }
  /** Screen position and radius of every upper interior base form under g; the pane draws and picks from these. */
  computeStars() {
    // Bounds and view are read once per draw; the loop does no DOM geometry reads.
    const { abc, count, g } = this.data, m = pushforward(g), v = this.ensureView(), { w, h } = this.size();
    const ox = w / 2 - v.cx * v.scale, oy = h / 2 + v.cy * v.scale, k = 0.03 * this.data.sigma * v.scale;
    const index = [], x = [], y = [], r = [];
    for (let i = 0; i < count; i++) {
      const a = abc[3 * i], b = abc[3 * i + 1], c = abc[3 * i + 2], delta = b * b - 4 * a * c;
      if (!(a > 0 && delta < 0)) continue;
      const a1 = m[0] * a + m[1] * b + m[2] * c, b1 = m[3] * a + m[4] * b + m[5] * c;
      const sx = ox + (-b1 / (2 * a1)) * v.scale, sy = oy - (Math.sqrt(-delta) / (2 * a1)) * v.scale;
      const radius = k / a1;
      if (sx < -radius || sx > w + radius || sy < -radius || sy > h + radius) continue;
      index.push(i); x.push(sx); y.push(sy); r.push(radius);
    }
    const order = index.map((_, k) => k).sort((p, q) => r[p] - r[q]);  // larger stars drawn last, on top
    return { index: order.map(k => index[k]), x: order.map(k => x[k]), y: order.map(k => y[k]), r: order.map(k => r[k]) };
  }
  draw() {
    if (!this.data) return;
    const { w, h } = this.size(), dpr = Math.min(devicePixelRatio, 2), ctx = this.ctx;
    if (this.canvas.width !== Math.round(w * dpr) || this.canvas.height !== Math.round(h * dpr)) {
      this.canvas.width = Math.round(w * dpr); this.canvas.height = Math.round(h * dpr);
    }
    if (!(w > 0 && h > 0)) return;  // hidden at narrow widths
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
    const stars = this.stars = this.computeStars(), { abc } = this.data;
    for (let k = 0; k < stars.index.length; k++) {
      const i = stars.index[k], radius = stars.r[k];
      if (radius < 0.08) continue;
      const [cr, cg, cb] = this.colorOf(i);
      ctx.globalAlpha = radius < minPixels ? (radius / minPixels) ** 2 : 1;
      ctx.fillStyle = `rgb(${cr},${cg},${cb})`;
      const drawn = Math.max(radius, minPixels);
      if (drawn < 1.5) ctx.fillRect(stars.x[k] - drawn, stars.y[k] - drawn, 2 * drawn, 2 * drawn);
      else { ctx.beginPath(); ctx.arc(stars.x[k], stars.y[k], drawn, 0, 2 * Math.PI); ctx.fill(); }
    }
    ctx.globalAlpha = 1;
    // The real axis, the projective line's finite part, with ticks at −1, −½, 0, ½, 1.
    const [, axisY] = this.toScreen({ x: 0, y: 0 });
    ctx.strokeStyle = '#7896a8'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(w, axisY); ctx.stroke();
    ctx.font = '11px system-ui,-apple-system,sans-serif'; ctx.fillStyle = '#9fb2bd'; ctx.textAlign = 'center';
    for (const [t, text] of [[-1, '−1'], [-0.5, '−½'], [0, '0'], [0.5, '½'], [1, '1']]) {
      const [sx] = this.toScreen({ x: t, y: 0 });
      ctx.fillRect(sx - 0.5, axisY, 1, 5); ctx.fillText(text, sx, axisY + 17);
    }
    ctx.textAlign = 'left';
    ctx.fillText(`roots · upper half-plane · ${stars.index.length.toLocaleString()} stars`, 10, 18);
    const { selected, second } = this.data;
    for (const [point, color] of [[selected, '#f0f5f8'], [second, '#ffba6b']]) {
      const k = point && this.find(point);
      if (k === null || k === undefined) continue;
      this.ring(k, color); this.text(this.label(point), k, color);
    }
    if (this.hover >= 0) {
      const i = stars.index[this.hover], point = [abc[3 * i], abc[3 * i + 1], abc[3 * i + 2]];
      if (!(selected && point.join() === selected.join())) {
        this.ring(this.hover, '#f0f5f8bf'); this.text(this.label(point), this.hover, '#f0f5f8bf');
      }
    }
  }
  /** Position (in the drawn order) of a base triple among the visible stars, or null. */
  find(point) {
    const { abc } = this.data, { index } = this.stars;
    for (let k = 0; k < index.length; k++) {
      const i = index[k];
      if (abc[3 * i] === point[0] && abc[3 * i + 1] === point[1] && abc[3 * i + 2] === point[2]) return k;
    }
    return null;
  }
  ring(k, color) {
    const ctx = this.ctx; ctx.strokeStyle = color; ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.arc(this.stars.x[k], this.stars.y[k], Math.max(this.stars.r[k], minPixels) + 3, 0, 2 * Math.PI); ctx.stroke();
  }
  /** Her label manner: one 12 px line below right of the star, stroked with a halo, then filled. */
  text(text, k, color) {
    const ctx = this.ctx, r = this.stars.r[k], offset = Math.max(8, r + 7), y = this.stars.y[k] + Math.max(8, r + 6);
    ctx.font = '12px system-ui,-apple-system,sans-serif'; ctx.textAlign = 'left';
    // Flip left at the pane's right edge so the label is never clipped.
    const width = ctx.measureText(text).width, { w } = this.size();
    const x = this.stars.x[k] + offset + width > w - 4 ? this.stars.x[k] - offset - width : this.stars.x[k] + offset;
    ctx.lineWidth = 4; ctx.lineJoin = 'round'; ctx.strokeStyle = 'rgba(5,9,12,0.92)'; ctx.strokeText(text, x, y);
    ctx.fillStyle = color; ctx.fillText(text, x, y);
  }
  /** The star nearest (x, y) within max(7 px, its radius), preferring larger stars on ties; −1 if none. */
  pick(x, y) {
    if (!this.stars) return -1;
    let best = -1, bestDistance = Infinity;
    const { r } = this.stars;
    for (let k = 0; k < r.length; k++) {
      const d = Math.hypot(this.stars.x[k] - x, this.stars.y[k] - y);
      if (d <= Math.max(pickPixels, r[k]) && (d < bestDistance || (d === bestDistance && r[k] > r[best]))) { best = k; bestDistance = d; }
    }
    return best;
  }
  local(e) { const { left, top } = this.size(); return [e.clientX - left, e.clientY - top]; }
  pointerDown(e) {
    this.canvas.setPointerCapture(e.pointerId);
    const [x, y] = this.local(e);
    this.down = { x, y, moved: false, shift: e.shiftKey, z: this.toH(x, y), view: { ...this.ensureView() } };
  }
  pointerMove(e) {
    const [x, y] = this.local(e);
    if (!this.down) {
      if (e.pointerType !== 'mouse') return;
      const k = this.pick(x, y); if (k !== this.hover) { this.hover = k; this.draw(); } return;
    }
    if (!this.down.moved && Math.hypot(x - this.down.x, y - this.down.y) < threshold) return;
    if (!this.down.moved) { this.down.moved = true; this.hover = -1; this.canvas.classList.add('is-dragging'); }
    if (this.down.shift) {  // Shift-drag pans the picture; g is unchanged.
      const v = this.down.view;
      this.view = { ...v, cx: v.cx - (x - this.down.x) / v.scale, cy: v.cy + (y - this.down.y) / v.scale };
      this.draw(); return;
    }
    // Outside the model domain there is no anchor; the drag resumes once the pointer returns.
    const z = this.toH(x, y);
    if (this.down.z && z) this.onDragStep(this.down.z, z);
    if (z) this.down.z = z;
  }
  pointerUp(e) {
    const down = this.down; this.down = null; this.canvas.classList.remove('is-dragging');
    if (!down) return;
    if (down.moved) { if (!down.shift) this.onDragEnd(); return; }
    const [x, y] = this.local(e), k = this.pick(x, y);
    this.onPick(k >= 0 ? this.stars.index[k] : -1, e.shiftKey);
  }
  wheel(e) {
    e.preventDefault();
    const [x, y] = this.local(e), v = this.ensureView(), fit = this.fitView().scale, { w, h } = this.size();
    const scale = Math.min(8 * fit, Math.max(0.5 * fit, v.scale * Math.exp(-e.deltaY * 0.0015)));
    const zx = v.cx + (x - w / 2) / v.scale, zy = v.cy - (y - h / 2) / v.scale;
    this.view = { scale, cx: zx - (x - w / 2) / scale, cy: zy + (y - h / 2) / scale };
    this.draw();
  }
  reset() { this.view = null; this.hover = -1; this.draw(); }
}
