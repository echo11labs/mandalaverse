"""Run the workspace-pinned engine with GOPALA selected; no shell evaluation."""
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".tools/godot/Godot.app/Contents/MacOS/Godot"

if __name__ == "__main__":
    if not ENGINE.is_file():
        sys.exit("Pinned Godot is missing. See docs/GOPALA-Toolchain.md.")
    os.execv(str(ENGINE), [str(ENGINE), "--path", str(ROOT / "game"), *sys.argv[1:]])

