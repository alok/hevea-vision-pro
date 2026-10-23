#!/usr/bin/env python3
"""Run native tests with synchronized screenshots in a disposable simulator."""
import argparse
import plistlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile

from capture_coordinator import CaptureCoordinator, enable_capture


def enable_spatial_probe(xctestrun):
    """Sets FAREY_SPATIAL_PROBE=1 for the UI test target, which otherwise skips the spatial tap diagnostic."""
    with xctestrun.open("rb") as file:
        plan = plistlib.load(file)
    # The same two xctestrun layouts capture_coordinator.enable_capture handles.
    targets = [value for value in plan.values() if isinstance(value, dict) and "BlueprintName" in value]
    for configuration in plan.get("TestConfigurations", []):
        targets.extend(configuration.get("TestTargets", []))
    for target in targets:
        if target.get("BlueprintName") == "FareyVisionUITests":
            target.setdefault("EnvironmentVariables", {})["FAREY_SPATIAL_PROBE"] = "1"
    with xctestrun.open("wb") as file:
        plistlib.dump(plan, file)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", help="Use an existing simulator instead of creating one")
    parser.add_argument("--output", type=Path, help="A new output directory")
    parser.add_argument("--only-testing", action="append", default=[])
    parser.add_argument("--record-video", nargs=2, metavar=("START", "STOP"),
                        help="Record the simulator display from capture START through capture STOP to recording.mp4")
    parser.add_argument("--spatial-probe", action="store_true",
                        help="Also run the opt-in spatial tap diagnostic (FAREY_SPATIAL_PROBE=1)")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    os.environ["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="farey-capture-"))
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise SystemExit("Choose a new output directory; existing evidence is not overwritten")
    build = Path(subprocess.check_output(
        ["python3", str(source / "scripts/prepare-local-build.py")], text=True).strip())
    simulator = args.simulator or subprocess.check_output(
        ["xcrun", "simctl", "create", "Farey Capture Check",
         "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro-4K",
         "com.apple.CoreSimulator.SimRuntime.xrOS-27-2"], text=True).strip()
    state = {"buildRoot": str(build), "simulator": simulator, "screenshotsSynchronized": True}
    coordinator = None
    process = None
    try:
        if not args.simulator:
            subprocess.run(["xcrun", "simctl", "boot", simulator], check=True)
        subprocess.run(["xcrun", "simctl", "bootstatus", simulator, "-b"], check=True)
        common = ["xcodebuild", "-project", str(build / "FareyVision.xcodeproj"),
                  "-scheme", "FareyVision", "-destination", "platform=visionOS Simulator,id=" + simulator,
                  "-derivedDataPath", str(build / "DerivedData"), "-jobs", "2",
                  "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]
        with (output / "build.log").open("w") as log:
            subprocess.run(common + ["build-for-testing"], stdout=log, stderr=subprocess.STDOUT, check=True)
        candidates = list((build / "DerivedData/Build/Products").glob("*.xctestrun"))
        if len(candidates) != 1:
            raise RuntimeError("Expected one generated .xctestrun file")
        configured = candidates[0].parent / "Captured.xctestrun"
        enable_capture(candidates[0], configured)
        if args.spatial_probe:
            enable_spatial_probe(configured)
        coordinator = CaptureCoordinator(
            simulator, output / "screenshots", record=args.record_video,
            video=output / "recording.mp4" if args.record_video else None)
        coordinator.start()
        result = output / "Tests.xcresult"
        command = ["xcodebuild", "test-without-building", "-xctestrun", str(configured),
                   "-destination", "platform=visionOS Simulator,id=" + simulator,
                   "-parallel-testing-enabled", "NO", "-jobs", "2",
                   "-collect-test-diagnostics", "never", "-resultBundlePath", str(result)]
        command += ["-only-testing:" + target for target in args.only_testing]
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
        with (output / "test.log").open("w") as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if "Test Case" in line or "error:" in line or "** TEST" in line:
                    print(line.rstrip(), flush=True)
        state["testExit"] = process.wait()
        completed_coordinator, coordinator = coordinator, None
        completed_coordinator.stop()
        with (output / "test-summary.json").open("w") as summary:
            subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)],
                           stdout=summary, check=True)
        print("Evidence: " + str(output), flush=True)
        return state["testExit"]
    finally:
        try:
            if process is not None and process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
            if coordinator is not None:
                coordinator.stop()
        finally:
            (output / "run.json").write_text(json.dumps(state, indent=2) + "\n")
            if not args.simulator:
                subprocess.run(["xcrun", "simctl", "shutdown", simulator], check=False)
                subprocess.run(["xcrun", "simctl", "delete", simulator], check=False)


if __name__ == "__main__":
    raise SystemExit(main())
