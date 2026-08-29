# Hevea Vision Pro contributor instructions

This repository is an unofficial, GPL-3.0-or-later tribute and research prototype inspired by the original Hévéa project. Read `SPEC.md`, `NOTICE.md`, and `docs/UPSTREAM.md` before changing geometry, claims, or bundled assets.

## Claim classes

Every visual or result must be identified as one of:

1. **Upstream baseline** - regenerated from a pinned upstream source revision and parameter manifest.
2. **Explanatory proxy** - a lower-frequency, real-time construction that illustrates an idea but is not the Hévéa embedding or its isometric limit.
3. **Hevea Vision experiment** - a new finite-resolution numerical measurement. It is evidence, not a theorem.

Never call a finite mesh the limiting C1 isometric embedding. Never turn a simulator result into a physical-headset comfort, performance, or interaction claim.

## Build and verification

Use the checked-in XcodeGen specification. This machine currently has a
repository-local `PATH` quirk, so automation should use the absolute helper
paths shown below:

```bash
/opt/homebrew/bin/xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer xcodebuild \
  -project HeveaVision.xcodeproj -scheme HeveaVision \
  -sdk xrsimulator26.5 \
  -destination 'platform=visionOS Simulator,id=820CCDAA-EA00-41FC-8A4A-675701BD9E33' \
  -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer xcodebuild \
  -project HeveaVision.xcodeproj -scheme HeveaVision \
  -sdk xrsimulator26.5 \
  -destination 'platform=visionOS Simulator,id=820CCDAA-EA00-41FC-8A4A-675701BD9E33' \
  -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO test
/opt/homebrew/bin/swiftlint lint --strict
```

Run the platform-neutral Swift package tests independently as well:

```bash
swift test --package-path Packages/HeveaCore
```

Use `rg` and `fd`, not `grep` or `find`. Keep commits atomic and push each verified checkpoint to `origin/main` unless an active feature branch is explicitly in use.

## Attribution and assets

- Do not copy website meshes into the repository unless their redistribution license is clarified.
- Gallery images are not app assets by default. Link to them and preserve their stated license/credit.
- Any copied or adapted upstream source must keep its original copyright header and add a modification notice with author, date, and reason.
- Record source URL, revision, parameters, hashes, and generated-file hashes for every upstream baseline.
