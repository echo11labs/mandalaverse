"""Launch the tested server. stdout belongs exclusively to MCP JSON-RPC."""
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / ".tools/research/NPGameDev--godot-mcp-server/dist/index.js"
PINNED_NODE = Path("/Users/devendrashahithakuri/.nvm/versions/node/v22.18.0/bin/node")

if __name__ == "__main__":
    node = str(PINNED_NODE) if PINNED_NODE.is_file() else shutil.which("node")
    if not node or not SERVER.is_file():
        sys.exit("Tested MCP runtime is missing. See docs/GOPALA-Toolchain.md.")
    environment = os.environ.copy()
    environment["GODOT_MCP_PROJECT_PATH"] = str(ROOT / "game")
    if sys.argv[1:] == ["--read-only"]:
        environment["GODOT_MCP_READ_ONLY"] = "1"
    elif sys.argv[1:]:
        sys.exit("Supported option: --read-only")
    os.chdir(ROOT / "game")
    os.execve(node, [node, str(SERVER)], environment)

