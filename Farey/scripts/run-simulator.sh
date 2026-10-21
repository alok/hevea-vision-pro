#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin
simulator_id="${SIMULATOR_UDID:-D2ECE520-ED92-4A38-A990-AE65431DF562}"
/opt/homebrew/bin/xcodegen generate --spec project.yml
xcodebuild -project FareyVision.xcodeproj -scheme FareyVision \
  -destination "platform=visionOS Simulator,id=$simulator_id" \
  -configuration Release -derivedDataPath .derivedData-native -jobs 3 CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" .derivedData-native/Build/Products/Release-xrsimulator/FareyVision.app
xcrun simctl launch "$simulator_id" com.alok.FareyVision
open "$(xcode-select -p)/../Applications/DeviceHub.app"
