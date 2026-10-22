import plistlib
from pathlib import Path
import tempfile
import unittest

from capture_coordinator import enable_capture


class CaptureConfigurationTests(unittest.TestCase):
    def configure(self, data):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.xctestrun"
            destination = Path(folder) / "capture.xctestrun"
            source.write_bytes(plistlib.dumps(data))
            enable_capture(source, destination)
            self.assertEqual(plistlib.loads(source.read_bytes()), data)
            return plistlib.loads(destination.read_bytes())

    def test_legacy_format_preserves_other_targets_and_environment(self):
        data = {
            "Unit": {"BlueprintName": "FareyVisionTests", "EnvironmentVariables": {"KEEP": "unit"}},
            "UI": {"BlueprintName": "FareyVisionUITests", "EnvironmentVariables": {"KEEP": "ui"}},
            "__xctestrun_metadata__": {"FormatVersion": 1},
        }
        result = self.configure(data)
        self.assertEqual(result["Unit"], data["Unit"])
        self.assertEqual(result["UI"]["EnvironmentVariables"], {"KEEP": "ui", "FAREY_CAPTURE_HANDSHAKE": "1"})

    def test_configuration_format_enables_only_ui_target(self):
        data = {"TestConfigurations": [{"TestTargets": [
            {"BlueprintName": "FareyVisionTests"}, {"BlueprintName": "FareyVisionUITests"},
        ]}]}
        targets = self.configure(data)["TestConfigurations"][0]["TestTargets"]
        self.assertNotIn("EnvironmentVariables", targets[0])
        self.assertEqual(targets[1]["EnvironmentVariables"], {"FAREY_CAPTURE_HANDSHAKE": "1"})

    def test_relocation_cannot_break_relative_product_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "original.xctestrun"
            source.write_bytes(plistlib.dumps({"UI": {"BlueprintName": "FareyVisionUITests"}}))
            with self.assertRaisesRegex(ValueError, "__TESTROOT__"):
                enable_capture(source, Path(folder) / "elsewhere/configured.xctestrun")


if __name__ == "__main__":
    unittest.main()
