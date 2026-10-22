// SPDX-License-Identifier: GPL-3.0-or-later
export class TapSelection {
  active = new Set();
  candidate = null;
  begin(event) {
    this.active.add(event.pointerId);
    this.candidate = this.active.size === 1 && event.button === 0
      ? { id: event.pointerId, x: event.clientX, y: event.clientY } : null;
  }
  move(event) {
    if (this.candidate && Math.hypot(event.clientX - this.candidate.x, event.clientY - this.candidate.y) > 5) this.candidate = null;
  }
  end(event) {
    const candidate = this.candidate, single = this.active.size === 1;
    this.candidate = null;
    this.active.delete(event.pointerId);
    return !!(candidate && candidate.id === event.pointerId && single
      && Math.hypot(event.clientX - candidate.x, event.clientY - candidate.y) <= 5);
  }
  cancel(event) {
    this.active.delete(event.pointerId);
    this.candidate = null;
  }
}
