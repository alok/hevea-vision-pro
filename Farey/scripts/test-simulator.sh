#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin
simulator_id="${SIMULATOR_UDID:-D2ECE520-ED92-4A38-A990-AE65431DF562}"
build_root="$(python3 scripts/prepare-local-build.py)"
swift test --jobs 3 --package-path "$build_root/Packages/FareyCore" --scratch-path "$build_root/CoreBuild"
xcodebuild -project "$build_root/FareyVision.xcodeproj" -scheme FareyVision \
  -destination "platform=visionOS Simulator,id=$simulator_id" \
  -derivedDataPath "$build_root/DerivedData" -jobs 3 -parallel-testing-enabled NO \
  -resultBundlePath "evidence/Simulator-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
