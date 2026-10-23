"""Serialize simulator screenshots with the XCTest runner that requested them."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid


def enable_capture(xctestrun, destination):
    if Path(xctestrun).parent.resolve() != Path(destination).parent.resolve():
        raise ValueError("Keep the configured .xctestrun beside the original so __TESTROOT__ still resolves")
    data = plistlib.loads(Path(xctestrun).read_bytes())
    targets = [value for value in data.values() if isinstance(value, dict) and "BlueprintName" in value]
    for configuration in data.get("TestConfigurations", []):
        targets.extend(configuration.get("TestTargets", []))
    enabled = 0
    for target in targets:
        if target.get("BlueprintName") == "FareyVisionUITests":
            target.setdefault("EnvironmentVariables", {})["FAREY_CAPTURE_HANDSHAKE"] = "1"
            enabled += 1
    if not enabled:
        raise ValueError("The generated test run contains no FareyVisionUITests target")
    Path(destination).write_bytes(plistlib.dumps(data))


class CaptureCoordinator:
    """Takes each requested screenshot before acknowledging it. With `record=(start, stop)`, it also records this
    simulator's own display (silent, via simctl recordVideo) from the named start capture through the named stop
    capture: recording begins before the start capture is acknowledged, so the test cannot move on unrecorded."""

    def __init__(self, simulator, output, record=None, video=None):
        self.simulator = simulator
        self.record = record
        self.video = Path(video) if video else None
        self.recorder = None
        self.recording = {}
        self.output = Path(output)
        self.output.mkdir(parents=True, exist_ok=True)
        self.started = time.time()
        self.captures = []
        self.error = None
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self.thread.start()

    def stop(self):
        self.stop_event.set()
        self.thread.join(timeout=40)
        # A failed or shortened test never reaches the stop capture; finish the video anyway, marked incomplete.
        self._stop_recording(complete=False)
        if self.thread.is_alive():
            raise RuntimeError("The screenshot worker did not finish")
        if self.error:
            raise RuntimeError(self.error)

    def _run(self):
        seen = set()
        directory = None
        last_lookup = 0
        try:
            while not self.stop_event.is_set():
                if time.monotonic() - last_lookup >= 1:
                    last_lookup = time.monotonic()
                    result = subprocess.run(
                        ["xcrun", "simctl", "get_app_container", self.simulator,
                         "com.alok.FareyVisionUITests.xctrunner", "data"],
                        capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        directory = Path(result.stdout.strip()) / "tmp/farey-capture"
                if directory:
                    try:
                        request = json.loads((directory / "request.json").read_text())
                    except (OSError, ValueError):
                        request = None
                    if request and request.get("createdAt", 0) >= self.started and request.get("id") not in seen:
                        identifier = str(uuid.UUID(request["id"]))
                        name = request["name"]
                        if not re.fullmatch(r"[A-Za-z0-9-]{1,100}", name):
                            raise ValueError("Invalid screenshot name")
                        seen.add(request["id"])
                        self._capture(request, identifier, directory)
                self.stop_event.wait(0.03)
        except Exception as error:
            self.error = str(error)

    def _start_recording(self, name):
        if self.recorder or not self.video:
            return
        self.recorder = subprocess.Popen(
            ["xcrun", "simctl", "io", self.simulator, "recordVideo", "--codec=h264", "--force", str(self.video)],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        started = threading.Event()

        def watch():
            for line in self.recorder.stderr:
                if "Recording started" in line:
                    started.set()
        threading.Thread(target=watch, daemon=True).start()
        if not started.wait(15):
            raise RuntimeError("simctl recordVideo did not report that recording started")
        self.recording = {"file": self.video.name, "startCapture": name, "startedAt": time.time()}

    def _stop_recording(self, complete, name=None):
        if not self.recorder:
            return
        recorder, self.recorder = self.recorder, None
        recorder.send_signal(signal.SIGINT)
        try:
            exit_code = recorder.wait(timeout=60)
        except subprocess.TimeoutExpired:
            recorder.kill()
            exit_code = recorder.wait()
        self.recording.update(stopCapture=name, stoppedAt=time.time(), exitCode=exit_code, complete=complete)
        if self.video.exists():
            self.recording["sha256"] = hashlib.sha256(self.video.read_bytes()).hexdigest()
        (self.video.parent / "recording.json").write_text(json.dumps(self.recording, indent=2) + "\n")

    def _capture(self, request, identifier, directory):
        if self.record and request["name"] == self.record[0]:
            self._start_recording(request["name"])
        filename = f"{len(self.captures) + 1:03d}-{request['name']}.png"
        image = self.output / filename
        record = dict(request, file=filename, startedAt=time.time())
        try:
            result = subprocess.run(
                ["xcrun", "simctl", "io", self.simulator, "screenshot", str(image)],
                capture_output=True, text=True, timeout=25)
            record.update(exitCode=result.returncode,
                          error=result.stderr.strip() if result.returncode else None)
            if result.returncode == 0:
                record["sha256"] = hashlib.sha256(image.read_bytes()).hexdigest()
                shutil.copyfile(image, directory / (request["id"] + ".png"))
        except (OSError, subprocess.TimeoutExpired) as error:
            record.update(exitCode=124, error=str(error))
        record["finishedAt"] = time.time()
        if self.record and request["name"] == self.record[1]:
            self._stop_recording(complete=True, name=request["name"])
        self.captures.append(record)
        (self.output / "captures.json").write_text(json.dumps(self.captures, indent=2) + "\n")
        temporary = directory / (identifier + ".tmp")
        temporary.write_text(json.dumps(record))
        temporary.replace(directory / (request["id"] + ".json"))
