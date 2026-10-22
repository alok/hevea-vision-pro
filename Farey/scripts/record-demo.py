#!/usr/bin/env python3
"""Record an asserted app-only tour in a disposable visionOS simulator."""
import argparse
import json
from pathlib import Path
import re
import signal
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, help="New capture directory; existing raw video is never overwritten")
args = parser.parse_args()
source = Path(__file__).resolve().parent.parent
output = (args.output or source / "evidence/demo-package").resolve()
output.mkdir(parents=True, exist_ok=True)
if (output / "native-raw.mp4").exists():
    raise SystemExit("Capture already exists. Choose a fresh directory with --output.")
root = Path(subprocess.check_output(["python3", str(source / "scripts/prepare-local-build.py")], text=True).strip())
tests = root / "UITests/FareyUITests.swift"
tests.write_text(tests.read_text() + "\n" + (source / "scripts/demo-tour.swift").read_text())
sim = subprocess.check_output(["xcrun", "simctl", "create", "Farey Demo Recording",
    "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro-4K",
    "com.apple.CoreSimulator.SimRuntime.xrOS-27-2"], text=True).strip()
state = {"buildRoot": str(root), "simulator": sim, "markers": []}
recorder = None
started = None
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
    command = common + ["-only-testing:FareyVisionUITests/FareyUITests/testRecordedDemonstration",
        "-resultBundlePath", str(root / "Demo.xcresult"), "test-without-building"]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    with (output / "native-test.log").open("w") as log:
        for line in process.stdout:
            log.write(line)
            log.flush()
            match = re.search(r"FAREY_CAPTURE:(demo-[A-Za-z0-9-]+)", line)
            if match:
                name = match[1]
                if name == "demo-start-credit":
                    record_log = (output / "native-record.log").open("w")
                    recorder = subprocess.Popen(["xcrun", "simctl", "io", sim, "recordVideo",
                        "--codec=h264", str(output / "native-raw.mp4")], stdout=record_log, stderr=subprocess.STDOUT)
                    for _ in range(100):
                        if "Recording started" in (output / "native-record.log").read_text():
                            break
                        if recorder.poll() is not None:
                            raise RuntimeError("Simulator recorder exited before capture")
                        time.sleep(0.1)
                    else:
                        raise RuntimeError("Simulator recorder did not become ready")
                    started = time.monotonic()
                if started is not None:
                    state["markers"].append({"name": name, "seconds": round(time.monotonic() - started, 2)})
                    if name == "demo-stop":
                        recorder.send_signal(signal.SIGINT)
                        recorder.wait(timeout=40)
                    else:
                        time.sleep(0.8)
                        subprocess.run(["xcrun", "simctl", "io", sim, "screenshot", str(output / (name + ".png"))],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                print("Captured " + name, flush=True)
            elif "Test Case" in line or "** TEST" in line or "error:" in line:
                print(line.rstrip(), flush=True)
    state["testExit"] = process.wait()
    state["resultBundle"] = str(root / "Demo.xcresult")
    if state["testExit"] != 0:
        raise RuntimeError("Recorded native walkthrough failed")
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
