# Lifecycle capture evidence

The [audit](../../LIFECYCLE_CAPTURE_AUDIT.md) distinguishes a verified synchronization defect from remaining simulator capture-path uncertainty. Native 0.8/build 10 runtime source is unchanged.

- [Late “confirmed” screenshot](late-confirmed.png) shows the later lattice/exit state. [Timing measurements](unsynchronized-timing.json) record the lag.
- [Video with still-image requests](video-with-stills.png), [video-only foreground](video-only-foreground.png), and [video-only confirmed selection](video-only-confirmed.png) were sampled from local simulator recordings, not hardware.
- [Synchronized selection](synchronized-confirmed.png) and [partial composite](partial-composite.png): synchronization keeps state labels accurate but cannot guarantee the simulator composites every layer correctly.
- [Probe summary](probe-summary.json), [probe events](probe-events.json) and [synchronized capture timings](synchronized-probe-captures.json).
- [Video screening measurements](video-screening.json) use a fixed region away from the center popover; they are not a complete visibility oracle.
- [Manifest](manifest.json) includes hashes, local video paths, sampling method and observed blank intervals. Raw videos remain local, outside Git, and were not uploaded.

One probe setup timed out after Xcode replaced the test runner container; it collected no scene evidence. Two full-suite setups stopped before testing because of legacy `.xctestrun` handling and relative product paths. These capture-tool failures were corrected. They are not app test failures; the corrected complete-suite result is recorded separately.

## Complete regression run

[Native summary](native-full-summary.json): 28 passed, zero failed. [All 62 captures](native-full-captures.json) completed successfully. [Validation](validation.json) records the three configuration tests and full-size exported attachments. [Tested source hashes](tested-source-hashes.json) identify the exact native and test files. The app runtime is unchanged.

The standalone still run captured [foreground](full-foreground.png), [confirmed selection](full-confirmed.png), and [idle after re-entry](full-reentered-idle.png). The confirmed frame still contains a partial composite; it is retained as a limitation, not presented as a complete rendering.

## Video-only tour

The revised recorder passed its [asserted walkthrough](video-tour-summary.json). [Video metadata](video-tour.json) records the raw capture, chapter timestamps and a fully decoded 86-second 1080p export (1.21 MB). It stays local at `/tmp/farey-lifecycle-video-demo/native-demo-trimmed.mp4`; no video was uploaded or committed. [An actual video frame](video-tour-oblique.png) shows the oblique lattice and inspected multiple. Playback frame rate is not a headset performance measurement.

[Controlled follow-up](followup/README.md) records idle, individual-change, popover and picker-commit experiments. These negative controls further constrain the issue without identifying its cause.
