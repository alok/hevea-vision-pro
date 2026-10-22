#!/usr/bin/env python3
"""Stage source files outside synced Documents; retain the checked-in build specification."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parent.parent
target = Path(tempfile.mkdtemp(prefix="farey-build-", dir="/tmp"))
for name in ("Sources", "Tests", "UITests", "Packages/FareyCore"):
    shutil.copytree(source / name, target / name, ignore=shutil.ignore_patterns(".build", ".DS_Store"))
shutil.copy2(source / "project.yml", target / "project.yml")
subprocess.run(["/opt/homebrew/bin/xcodegen", "generate", "--spec", str(target / "project.yml")],
               check=True, stdout=sys.stderr)
print(target)
