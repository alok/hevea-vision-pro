#!/bin/bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$REPO_ROOT/HeveaVision.xcodeproj"
SCHEME="HeveaVision"
BUNDLE_ID="com.alok.HeveaVision"
DERIVED_DATA="$REPO_ROOT/.derivedData"
DEVELOPER_DIR_PATH="/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer"
XCRUN="/usr/bin/xcrun"
XCODEBUILD="/usr/bin/xcodebuild"
RG="/Users/alokbeniwal/.cargo/bin/rg"
UV="/Users/alokbeniwal/.local/bin/uv"
SHA256="/usr/bin/shasum"
RECEIPT_SCRIPT="$REPO_ROOT/Scripts/simulator_receipt.py"

RUNTIME_SELECTION="all"
SCENARIO_CSV="mission-control,stage-sweep,metric-heatmap,scale-microscope"
REPETITIONS=2
SETTLE_SECONDS=6
MIN_FREE_GIB=16
SHOW_SIMULATOR=0
SKIP_BUILD=0
PREFLIGHT_ONLY=0

usage() {
  /bin/cat <<'USAGE'
Usage: Scripts/run-simulator-matrix.sh [options]

Build, install, launch, capture, and receipt a bounded visionOS Simulator matrix.
The script never erases devices, deletes app data, shuts down simulators, or removes
DerivedData. Generated runs are ignored by Git until deliberately curated.

Options:
  --runtime all|26.5|27.0       Runtime matrix (default: all)
  --scenarios CSV              Scenario identifiers (default: four canonical scenes)
  --repetitions N              Runs per scenario, 1...10 (default: 2)
  --settle-seconds N           Delay before capture, 1...30 (default: 6)
  --min-free-gib N             Abort before writes below N GiB, 5...100 (default: 16)
  --developer-dir PATH         Explicit Xcode Developer directory
  --show-simulator             Bring Simulator.app forward for each runtime
  --skip-build                 Reuse the app in the shared .derivedData tree
  --preflight-only             Validate tools, devices, project, and disk; mutate nothing
  -h, --help                   Show this help

Automation contract passed to the app:
  Environment: HEVEA_AUTOMATION=1, HEVEA_SCENARIO, HEVEA_REPETITION
  Arguments:   --hevea-automation --hevea-scenario NAME --hevea-repetition N
USAGE
}

die() {
  echo "error: $*" >&2
  exit 2
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      [[ $# -ge 2 ]] || die "--runtime needs a value"
      RUNTIME_SELECTION="$2"
      shift 2
      ;;
    --scenarios)
      [[ $# -ge 2 ]] || die "--scenarios needs a value"
      SCENARIO_CSV="$2"
      shift 2
      ;;
    --repetitions)
      [[ $# -ge 2 ]] || die "--repetitions needs a value"
      REPETITIONS="$2"
      shift 2
      ;;
    --settle-seconds)
      [[ $# -ge 2 ]] || die "--settle-seconds needs a value"
      SETTLE_SECONDS="$2"
      shift 2
      ;;
    --min-free-gib)
      [[ $# -ge 2 ]] || die "--min-free-gib needs a value"
      MIN_FREE_GIB="$2"
      shift 2
      ;;
    --developer-dir)
      [[ $# -ge 2 ]] || die "--developer-dir needs a value"
      DEVELOPER_DIR_PATH="$2"
      shift 2
      ;;
    --show-simulator)
      SHOW_SIMULATOR=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --preflight-only)
      PREFLIGHT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$RUNTIME_SELECTION" in
  all)
    RUNTIMES=("visionOS-26.5" "visionOS-27.0")
    ;;
  26.5)
    RUNTIMES=("visionOS-26.5")
    ;;
  27.0)
    RUNTIMES=("visionOS-27.0")
    ;;
  *)
    die "--runtime must be all, 26.5, or 27.0"
    ;;
esac

is_integer "$REPETITIONS" || die "--repetitions must be an integer"
(( REPETITIONS >= 1 && REPETITIONS <= 10 )) || die "--repetitions must be between 1 and 10"
is_integer "$SETTLE_SECONDS" || die "--settle-seconds must be an integer"
(( SETTLE_SECONDS >= 1 && SETTLE_SECONDS <= 30 )) || die "--settle-seconds must be between 1 and 30"
is_integer "$MIN_FREE_GIB" || die "--min-free-gib must be an integer"
(( MIN_FREE_GIB >= 5 && MIN_FREE_GIB <= 100 )) || die "--min-free-gib must be between 5 and 100"

IFS=',' read -r -a SCENARIOS <<< "$SCENARIO_CSV"
(( ${#SCENARIOS[@]} >= 1 && ${#SCENARIOS[@]} <= 12 )) || die "provide between 1 and 12 scenarios"
for scenario in "${SCENARIOS[@]}"; do
  [[ "$scenario" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "invalid scenario identifier: $scenario"
done

[[ -d "$DEVELOPER_DIR_PATH" ]] || die "Developer directory does not exist: $DEVELOPER_DIR_PATH"
[[ -x "$XCRUN" ]] || die "xcrun is unavailable at $XCRUN"
[[ -x "$XCODEBUILD" ]] || die "xcodebuild is unavailable at $XCODEBUILD"
[[ -x "$RG" ]] || die "rg is unavailable at $RG"
[[ -x "$UV" ]] || die "uv is unavailable at $UV"
[[ -x "$SHA256" ]] || die "shasum is unavailable at $SHA256"
[[ -f "$RECEIPT_SCRIPT" ]] || die "receipt renderer is missing: $RECEIPT_SCRIPT"
[[ -d "$PROJECT" ]] || die "generate HeveaVision.xcodeproj before running the simulator matrix"

runtime_udid() {
  case "$1" in
    visionOS-26.5) echo "820CCDAA-EA00-41FC-8A4A-675701BD9E33" ;;
    visionOS-27.0) echo "4077DC3A-1866-489B-98AC-206E86DCEB74" ;;
    *) return 1 ;;
  esac
}

runtime_version() {
  case "$1" in
    visionOS-26.5) echo "26.5" ;;
    visionOS-27.0) echo "27.0" ;;
    *) return 1 ;;
  esac
}

simctl() {
  DEVELOPER_DIR="$DEVELOPER_DIR_PATH" "$XCRUN" simctl "$@"
}

free_disk_bytes() {
  /bin/df -Pk "$REPO_ROOT" | /usr/bin/awk 'NR == 2 { printf "%.0f\n", $4 * 1024 }'
}

require_disk_headroom() {
  local context="$1"
  local free_bytes
  local minimum_bytes
  free_bytes="$(free_disk_bytes)"
  minimum_bytes=$(( MIN_FREE_GIB * 1024 * 1024 * 1024 ))
  if (( free_bytes < minimum_bytes )); then
    echo "error: only $free_bytes bytes free $context; minimum is $minimum_bytes" >&2
    return 1
  fi
}

device_line() {
  local udid="$1"
  simctl list devices | "$RG" -m 1 --fixed-strings "$udid" || true
}

device_state() {
  local line
  line="$(device_line "$1")"
  if [[ "$line" == *"(Booted)"* ]]; then
    echo "Booted"
  elif [[ "$line" == *"(Shutdown)"* ]]; then
    echo "Shutdown"
  elif [[ -n "$line" ]]; then
    echo "Other"
  else
    echo "Missing"
  fi
}

require_disk_headroom "during preflight" || exit 2
for runtime in "${RUNTIMES[@]}"; do
  udid="$(runtime_udid "$runtime")"
  line="$(device_line "$udid")"
  [[ -n "$line" ]] || die "$runtime device is not installed: $udid"
done

if (( PREFLIGHT_ONLY == 1 )); then
  echo "Simulator matrix preflight passed."
  echo "Developer directory: $DEVELOPER_DIR_PATH"
  echo "Project: $PROJECT"
  echo "Shared DerivedData: $DERIVED_DATA"
  echo "Free bytes: $(free_disk_bytes)"
  for runtime in "${RUNTIMES[@]}"; do
    udid="$(runtime_udid "$runtime")"
    echo "$runtime: $udid ($(device_state "$udid"))"
  done
  exit 0
fi

RUN_ID="$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$"
OUTPUT_DIR="$REPO_ROOT/docs/simulator-evidence/runs/$RUN_ID"
EVENTS_FILE="$OUTPUT_DIR/events.tsv"
XCODE_VERSION_FILE="$OUTPUT_DIR/xcode-version.txt"
STARTED_AT="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
DISK_BEFORE_BYTES="$(free_disk_bytes)"
OVERALL_FAILED=0
SUCCESSFUL_LAUNCHES=0
RECEIPT_READY=0

/bin/mkdir -p "$OUTPUT_DIR"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  runtime os_version udid initial_state scenario repetition build boot install launch pid \
  screenshot screenshot_path screenshot_sha256 logs log_path log_sha256 note > "$EVENTS_FILE"
DEVELOPER_DIR="$DEVELOPER_DIR_PATH" "$XCODEBUILD" -version > "$XCODE_VERSION_FILE" 2>&1
RECEIPT_READY=1

record_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$EVENTS_FILE"
}

record_skipped_runtime() {
  local runtime="$1"
  local os_version="$2"
  local udid="$3"
  local initial_state="$4"
  local build_status="$5"
  local boot_status="$6"
  local install_status="$7"
  local note="$8"
  local scenario
  local repetition
  for scenario in "${SCENARIOS[@]}"; do
    repetition=1
    while (( repetition <= REPETITIONS )); do
      record_row "$runtime" "$os_version" "$udid" "$initial_state" "$scenario" "$repetition" \
        "$build_status" "$boot_status" "$install_status" skipped "" skipped "" "" skipped "" "" "$note"
      repetition=$(( repetition + 1 ))
    done
  done
}

finalize_receipt() {
  local shell_status=$?
  trap - EXIT
  if (( RECEIPT_READY == 1 )); then
    local finished_at
    local disk_after_bytes
    local derived_data_bytes=0
    local result_status="passed"
    local runtime_csv
    finished_at="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
    disk_after_bytes="$(free_disk_bytes)"
    if [[ -d "$DERIVED_DATA" ]]; then
      derived_data_bytes="$(/usr/bin/du -sk "$DERIVED_DATA" | /usr/bin/awk '{ printf "%.0f\n", $1 * 1024 }')"
    fi
    if (( shell_status != 0 || OVERALL_FAILED != 0 )); then
      if (( SUCCESSFUL_LAUNCHES > 0 )); then
        result_status="partial"
      else
        result_status="failed"
      fi
    fi
    runtime_csv="$(IFS=','; echo "${RUNTIMES[*]}")"
    "$UV" run "$RECEIPT_SCRIPT" \
      --events "$EVENTS_FILE" \
      --output-dir "$OUTPUT_DIR" \
      --run-id "$RUN_ID" \
      --started-at "$STARTED_AT" \
      --finished-at "$finished_at" \
      --status "$result_status" \
      --repository-revision "$(/usr/bin/git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)" \
      --developer-dir "$DEVELOPER_DIR_PATH" \
      --project "HeveaVision.xcodeproj" \
      --scheme "$SCHEME" \
      --bundle-id "$BUNDLE_ID" \
      --derived-data ".derivedData" \
      --derived-data-bytes "$derived_data_bytes" \
      --repetitions "$REPETITIONS" \
      --scenarios "$SCENARIO_CSV" \
      --runtimes "$runtime_csv" \
      --disk-before-bytes "$DISK_BEFORE_BYTES" \
      --disk-after-bytes "$disk_after_bytes" \
      --xcode-version-file "$XCODE_VERSION_FILE" || shell_status=1
    echo "Simulator evidence: $OUTPUT_DIR"
  fi
  if (( shell_status != 0 || OVERALL_FAILED != 0 )); then
    exit 1
  fi
  exit 0
}
trap finalize_receipt EXIT

for runtime in "${RUNTIMES[@]}"; do
  os_version="$(runtime_version "$runtime")"
  udid="$(runtime_udid "$runtime")"
  initial_state="$(device_state "$udid")"
  runtime_dir="$OUTPUT_DIR/$runtime"
  build_log_rel="$runtime/build.log"
  build_log_abs="$OUTPUT_DIR/$build_log_rel"
  boot_log_abs="$runtime_dir/boot.log"
  install_log_abs="$runtime_dir/install.log"
  build_status="passed"
  boot_status="passed"
  install_status="passed"
  /bin/mkdir -p "$runtime_dir"

  if ! require_disk_headroom "before building $runtime"; then
    OVERALL_FAILED=1
    record_skipped_runtime "$runtime" "$os_version" "$udid" "$initial_state" failed skipped skipped "disk guard stopped runtime before build"
    continue
  fi

  if (( SKIP_BUILD == 0 )); then
    if ! DEVELOPER_DIR="$DEVELOPER_DIR_PATH" "$XCODEBUILD" \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -sdk xrsimulator \
      -destination "id=$udid" \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      -quiet build > "$build_log_abs" 2>&1; then
      build_status="failed"
      OVERALL_FAILED=1
      record_skipped_runtime "$runtime" "$os_version" "$udid" "$initial_state" "$build_status" skipped skipped "xcodebuild failed; see $build_log_rel"
      continue
    fi
  else
    build_status="reused"
    printf '%s\n' "Build skipped by request; reusing shared DerivedData product." > "$build_log_abs"
  fi

  app_path="$DERIVED_DATA/Build/Products/Debug-xrsimulator/HeveaVision.app"
  if [[ ! -d "$app_path" ]]; then
    OVERALL_FAILED=1
    record_skipped_runtime "$runtime" "$os_version" "$udid" "$initial_state" "$build_status" skipped skipped "app product missing at .derivedData/Build/Products/Debug-xrsimulator/HeveaVision.app"
    continue
  fi

  if [[ "$initial_state" != "Booted" ]]; then
    if ! simctl boot "$udid" > "$boot_log_abs" 2>&1 || ! simctl bootstatus "$udid" -b >> "$boot_log_abs" 2>&1; then
      boot_status="failed"
      OVERALL_FAILED=1
      record_skipped_runtime "$runtime" "$os_version" "$udid" "$initial_state" "$build_status" "$boot_status" skipped "simulator boot failed; see $runtime/boot.log"
      continue
    fi
  else
    boot_status="reused"
    printf '%s\n' "Simulator was already booted." > "$boot_log_abs"
  fi

  if (( SHOW_SIMULATOR == 1 )); then
    if [[ -d "$DEVELOPER_DIR_PATH/Applications/Simulator.app" ]]; then
      /usr/bin/open "$DEVELOPER_DIR_PATH/Applications/Simulator.app" \
        --args -CurrentDeviceUDID "$udid" >> "$boot_log_abs" 2>&1 || true
    else
      /usr/bin/open -a Simulator \
        --args -CurrentDeviceUDID "$udid" >> "$boot_log_abs" 2>&1 || true
    fi
  fi

  if ! simctl install "$udid" "$app_path" > "$install_log_abs" 2>&1; then
    install_status="failed"
    OVERALL_FAILED=1
    record_skipped_runtime "$runtime" "$os_version" "$udid" "$initial_state" "$build_status" "$boot_status" "$install_status" "app installation failed; see $runtime/install.log"
    continue
  fi

  for scenario in "${SCENARIOS[@]}"; do
    repetition=1
    while (( repetition <= REPETITIONS )); do
      if ! require_disk_headroom "before $runtime/$scenario repetition $repetition"; then
        OVERALL_FAILED=1
        record_row "$runtime" "$os_version" "$udid" "$initial_state" "$scenario" "$repetition" \
          "$build_status" "$boot_status" "$install_status" skipped "" skipped "" "" skipped "" "" "disk guard stopped capture"
        repetition=$(( repetition + 1 ))
        continue
      fi

      stem="$scenario-$(printf '%02d' "$repetition")"
      launch_rel="$runtime/$stem-launch.txt"
      launch_abs="$OUTPUT_DIR/$launch_rel"
      screenshot_rel="$runtime/$stem.png"
      screenshot_abs="$OUTPUT_DIR/$screenshot_rel"
      log_rel="$runtime/$stem-unified.log"
      log_abs="$OUTPUT_DIR/$log_rel"
      launch_status="passed"
      screenshot_status="passed"
      logs_status="passed"
      pid=""
      screenshot_sha=""
      log_sha=""
      note=""

      if ! SIMCTL_CHILD_HEVEA_AUTOMATION=1 \
        SIMCTL_CHILD_HEVEA_SCENARIO="$scenario" \
        SIMCTL_CHILD_HEVEA_REPETITION="$repetition" \
        simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
          --hevea-automation --hevea-scenario "$scenario" --hevea-repetition "$repetition" \
          > "$launch_abs" 2>&1; then
        launch_status="failed"
        OVERALL_FAILED=1
        note="launch failed; see $launch_rel"
      else
        SUCCESSFUL_LAUNCHES=$(( SUCCESSFUL_LAUNCHES + 1 ))
        pid="$(/usr/bin/awk -F': ' '/: [0-9]+$/ { print $2; exit }' "$launch_abs")"
      fi

      /bin/sleep "$SETTLE_SECONDS"

      if ! simctl io "$udid" screenshot --type=png "$screenshot_abs" >> "$launch_abs" 2>&1; then
        screenshot_status="failed"
        screenshot_rel=""
        OVERALL_FAILED=1
        note="${note:+$note; }screenshot failed; see $launch_rel"
      else
        screenshot_sha="$($SHA256 -a 256 "$screenshot_abs" | /usr/bin/awk '{ print $1 }')"
      fi

      if ! simctl spawn "$udid" log show --last 2m --style compact --info --debug \
        --predicate 'process == "HeveaVision" || subsystem == "com.alok.HeveaVision"' \
        > "$log_abs" 2>&1; then
        logs_status="failed"
        log_rel=""
        OVERALL_FAILED=1
        note="${note:+$note; }unified log collection failed"
      else
        log_sha="$($SHA256 -a 256 "$log_abs" | /usr/bin/awk '{ print $1 }')"
      fi

      record_row "$runtime" "$os_version" "$udid" "$initial_state" "$scenario" "$repetition" \
        "$build_status" "$boot_status" "$install_status" "$launch_status" "$pid" \
        "$screenshot_status" "$screenshot_rel" "$screenshot_sha" "$logs_status" "$log_rel" "$log_sha" "$note"
      repetition=$(( repetition + 1 ))
    done
  done
done

if (( OVERALL_FAILED != 0 )); then
  exit 1
fi
