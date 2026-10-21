#!/usr/bin/env python3
"""Run native UI tests while recording only the simulator display."""
import datetime
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path(__file__).resolve().parent.parent
os.chdir(root)
env = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin")
udid = env.get("SIMULATOR_UDID", "D2ECE520-ED92-4A38-A990-AE65431DF562")
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
evidence = root / "evidence"
evidence.mkdir(exist_ok=True)
command = ["xcodebuild", "-project", "FareyVision.xcodeproj", "-scheme", "FareyVision",
           "-destination", f"platform=visionOS Simulator,id={udid}",
           "-derivedDataPath", ".derivedData-native", "-parallel-testing-enabled", "NO",
           "-jobs", "3", "-resultBundlePath", str(evidence / f"Simulator-{stamp}.xcresult"),
           "CODE_SIGNING_ALLOWED=NO", "test", *sys.argv[1:]]
video = evidence / f"tour-{stamp}.mp4"
record_log_path = evidence / f"record-{stamp}.log"
record_log = record_log_path.open("w")
recorder = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264", str(video)],
                            env=env, stdout=record_log, stderr=subprocess.STDOUT)
process = None
result = 1
recording_ready = False

def timeout_handler(signum, frame):
    raise TimeoutError("Simulator test run exceeded five minutes")

signal.signal(signal.SIGALRM, timeout_handler)
signal.alarm(300)
try:
    # A busy or unavailable recorder must not be reported as a saved video.
    for _ in range(150):
        if "Recording started" in record_log_path.read_text():
            recording_ready = True
            break
        if recorder.poll() is not None:
            raise RuntimeError(record_log_path.read_text().strip())
        time.sleep(0.1)
    if not recording_ready:
        raise RuntimeError("The simulator recorder did not become ready within 15 seconds")
    with (evidence / f"simulator-{stamp}.log").open("w") as log:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
        for line in process.stdout:
            log.write(line)
            log.flush()
            if any(token in line for token in ["Test Case", "TEST SUCCEEDED", "TEST FAILED", "error:", "FAREY_CAPTURE"]):
                print(line, end="", flush=True)
            if "Test Suite 'Selected tests' failed" in line or "Test Suite 'All tests' failed" in line:
                break
        else:
            result = process.wait()
except (TimeoutError, RuntimeError) as error:
    print(error, flush=True)
    result = 124
finally:
    signal.alarm(0)
    if process is not None and process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
    if recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
        try:
            recorder.wait(timeout=120)
        except subprocess.TimeoutExpired:
            # Killing simctl during finalization can orphan the render-server recording.
            print(f"Recording is still finalizing (PID {recorder.pid}); wait for it before recording again.", flush=True)
            result = 1
    record_log.close()
if recording_ready and recorder.poll() == 0 and video.exists() and video.stat().st_size > 0:
    print(f"Simulator recording: {video}", flush=True)
else:
    print(f"No completed recording. Inspect {record_log_path}", flush=True)
    result = 1
sys.exit(result)
