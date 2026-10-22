#!/usr/bin/env python3
"""Record an asserted app-only tour in a disposable visionOS simulator."""
import argparse
import json
import datetime
import re
from pathlib import Path
import signal
import subprocess
import time


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, help="New capture directory; existing raw video is never overwritten")
parser.add_argument("--only-testing", action="append", default=[],
    help="Record existing test identifiers instead of adding the default demonstration tour")
args = parser.parse_args()
source = Path(__file__).resolve().parent.parent
output = (args.output or source / "evidence/demo-package").resolve()
output.mkdir(parents=True, exist_ok=True)
if (output / "native-raw.mp4").exists():
    raise SystemExit("Capture already exists. Choose a fresh directory with --output.")
root = Path(subprocess.check_output(["python3", str(source / "scripts/prepare-local-build.py")], text=True).strip())
if not args.only_testing:
    tests = root / "UITests/FareyUITests.swift"
    tests.write_text(tests.read_text() + "\n" + (source / "scripts/demo-tour.swift").read_text())
sim = subprocess.check_output(["xcrun", "simctl", "create", "Farey Demo Recording",
    "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro-4K",
    "com.apple.CoreSimulator.SimRuntime.xrOS-27-2"], text=True).strip()
state = {"buildRoot": str(root), "simulator": sim, "markers": []}
recorder = None
record_log = None
process = None
try:
    subprocess.run(["xcrun", "simctl", "bootstatus", sim, "-b"], check=True)
    common = ["xcodebuild", "-project", str(root / "FareyVision.xcodeproj"), "-scheme", "FareyVision",
        "-configuration", "Debug", "-destination", "platform=visionOS Simulator,id=" + sim,
        "-derivedDataPath", str(root / "DerivedData"), "-jobs", "2", "-parallel-testing-enabled", "NO",
        "CODE_SIGNING_ALLOWED=NO"]
    with (output / "native-build.log").open("w") as log:
        subprocess.run(common + ["build-for-testing"], stdout=log, stderr=subprocess.STDOUT, check=True)
    record_log = (output / "native-record.log").open("w")
    state["recordingCommandAt"] = time.time()
    recorder = subprocess.Popen(["xcrun", "simctl", "io", sim, "recordVideo",
        "--codec=h264", str(output / "native-raw.mp4")], stdout=record_log, stderr=subprocess.STDOUT)
    for _ in range(150):
        if "Recording started" in (output / "native-record.log").read_text():
            break
        if recorder.poll() is not None:
            raise RuntimeError("Simulator recorder exited before capture")
        time.sleep(0.1)
    else:
        raise RuntimeError("Simulator recorder did not become ready")
    selected_tests = args.only_testing or ["FareyVisionUITests/FareyUITests/testRecordedDemonstration"]
    state["selectedTests"] = selected_tests
    command = common + ["test-without-building", "-collect-test-diagnostics", "never",
        "-resultBundlePath", str(root / "Demo.xcresult")]
    command += ["-only-testing:" + target for target in selected_tests]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    with (output / "native-test.log").open("w") as log:
        for line in process.stdout:
            log.write(line)
            log.flush()
            marker = re.search(r"FAREY_CAPTURE:([A-Za-z0-9-]+)", line)
            timestamp = re.match(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+[-+]\d{4})", line)
            if marker and timestamp:
                marker_time = datetime.datetime.strptime(timestamp[1], "%Y-%m-%d %H:%M:%S.%f%z").timestamp()
                state["markers"].append({"name": marker[1], "markerAt": marker_time,
                    "seconds": round(marker_time - state["recordingCommandAt"], 3)})
            if "FAREY_CAPTURE:" in line or "Test Case" in line or "** TEST" in line or "error:" in line:
                print(line.rstrip(), flush=True)
    state["testExit"] = process.wait()
    state["stillImagesRequested"] = False
    state["videoTimeReference"] = "Native marker timestamp relative to host recording command; first-frame alignment is approximate"
    state["resultBundle"] = str(root / "Demo.xcresult")
    if state["testExit"] != 0:
        raise RuntimeError("Recorded native walkthrough failed")
    recorder.send_signal(signal.SIGINT)
    recorder.wait(timeout=40)
    if recorder is None or recorder.returncode != 0 or not (output / "native-raw.mp4").stat().st_size:
        raise RuntimeError("No completed simulator recording")
finally:
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    if recorder is not None and recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
        recorder.wait(timeout=40)
    if record_log is not None:
        record_log.close()
    (output / "native-capture.json").write_text(json.dumps(state, indent=2) + "\n")
    subprocess.run(["xcrun", "simctl", "shutdown", sim], check=False)
    subprocess.run(["xcrun", "simctl", "delete", sim], check=False)
print("Native tour complete: " + str(output / "native-raw.mp4"))
