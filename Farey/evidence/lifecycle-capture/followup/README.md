# Controlled capture follow-up

These are additional diagnostics of native 0.8/build 10 with unchanged runtime code. They do not supersede the failing captures in the parent directory or establish a root cause.

- [Summary and qualifications](summary.json).
- Idle: [timing](idle-timing.json), [region comparison](idle-region-comparison.json), [full pixel comparison](idle-full-pixel-comparison.json), and [representative combined video/still capture](idle-combined.png). The first four startup frames differed; the subsequent 40 differed by at most one channel value. 31 of all 44 were pixel-identical to the final reference.
- Individual changes: [UI fixture](single-change-test.swift), [timing](single-change-captures.json), and [whole/region comparisons](single-change-full-region-comparison.json). Five fixed-state groups, 12 captures each.
- Popovers/Home: [UI fixture](popover-test.swift), [timing](popover-captures.json), and [comparisons](popover-full-region-comparison.json). Six fixed-state groups, 12 captures each, with 3/5 retained.
- Picker commits: [UI fixture](picker-commit-test.swift), [timing](picker-commit-captures.json), and [comparisons](picker-commit-full-region-comparison.json). Three fixed-state groups, 12 captures each.

The fixtures ran only in a temporary build. A temporary host driver extended the capture handshake to take 12 images, separated by 0.25 seconds plus acquisition time, before acknowledging each request. This holds following input while sampling; it is not an artificial delay added to the app. Comparisons use a 960×540 analysis copy and a luminance difference threshold of 6 against the final image of each group; raw images and videos remain local. Timing files contain the actual sampling intervals. [Hashes](hashes.json) identify the archived data and fixtures.

All three temporary UI tests passed. The previously committed 28-test regression remains the latest complete suite; no production or normal-test code changed in this follow-up. The main simulator was preserved and temporary simulators removed. XR, hardware and upload permissions remain unchanged.
