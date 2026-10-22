// SPDX-License-Identifier: GPL-3.0-or-later
export const sideBySideViewport = (width, height) => width > 700 && height <= 700;

// Applied only at launch, Reset or the user's Front view action.
export function initialDesktopView(latticeCenter, compact, front = false) {
  const target = compact ? [...latticeCenter] : [0, 1.75, -3.2];
  const offset = front ? [0, 0.75, 6.4] : [3.3, 1.35, 5.3];
  return { target, position: target.map((value, index) => value + offset[index] * (compact ? 0.85 : 1)),
    minimumAspect: compact ? 1.3 : 0.85 };
}

export const viewDistanceScale = (aspect, minimumAspect) => Math.max(1, minimumAspect / aspect);

// A 28px sprite contains a roughly 12px letter in the existing label texture.
export function axisLabelWorldSize(depth, viewportHeight, fov, zoom = 1) {
  if (viewportHeight <= 0 || depth <= 0) return 0;
  return 28 * 2 * depth * Math.tan(fov * Math.PI / 360) / (viewportHeight * zoom);
}
