// SPDX-License-Identifier: GPL-3.0-or-later
// Main-thread event timing, not GPU frame rate or physical input latency.
async (page) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.reload(); await page.bringToFront();
  return await page.evaluate(async () => {
    const timings = [], frames = [];
    for (let index = 0; index < 120; index++) {
      if (index % 20 === 0) {
        document.getElementById('reset').click();
        const bound = document.getElementById('bound'); bound.value = '14';
        bound.dispatchEvent(new Event('change'));
      }
      await new Promise(requestAnimationFrame);
      const start = performance.now();
      document.getElementById(index % 2 ? 'left' : 'right').click();
      timings.push(performance.now() - start);
      await new Promise(requestAnimationFrame);
      frames.push(performance.now() - start);
    }
    const summarize = samples => {
      const sorted = [...samples].sort((a, b) => a - b);
      return { medianMs: sorted[Math.floor(sorted.length / 2)], p95Ms: sorted[Math.ceil(sorted.length * 0.95) - 1], maxMs: sorted.at(-1) };
    };
    return { samples: timings.length, maximumGrid: 14, synchronousMove: summarize(timings),
      nextAnimationFrame: summarize(frames), input: 'programmatic DOM clicks, paced by animation frames',
      scope: 'desktop main-thread submission; not GPU completion, headset FPS or physical interaction latency', actualXRSession: false };
  });
}
