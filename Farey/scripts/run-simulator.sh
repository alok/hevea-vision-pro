#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin
simulator_id="${SIMULATOR_UDID:-D2ECE520-ED92-4A38-A990-AE65431DF562}"
build_root="$(python3 scripts/prepare-local-build.py)"
configuration=Release
if [[ "${1:-}" == "--showcase" ]]; then configuration=Debug; fi
xcodebuild -project "$build_root/FareyVision.xcodeproj" -scheme FareyVision \
  -destination "platform=visionOS Simulator,id=$simulator_id" \
  -configuration "$configuration" -derivedDataPath "$build_root/DerivedData" -jobs 3 CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$build_root/DerivedData/Build/Products/$configuration-xrsimulator/FareyVision.app"
xcrun simctl launch --terminate-running-process "$simulator_id" com.alok.FareyVision "$@"
open "$(xcode-select -p)/../Applications/DeviceHub.app"
