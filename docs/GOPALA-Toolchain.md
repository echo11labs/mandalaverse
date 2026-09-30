# GOPALA toolchain and acceptance

The local engine is Godot 4.7.2 Standard, official build `ed1daf0bf`, under `.tools/godot/Godot.app`. Use `python3 tools/godot.py` to run it against `game/`. `.tools/` contains pinned local dependencies and is excluded from version control. Export templates have not been installed or export-tested.

## Verification

Run `python3 tools/verify.py` after authored code/content changes. Inspect `reports/verification.json` and referenced logs. The gate rejects engine/script errors even when a process exits successfully. It covers imports, authored script parsing, typed content invariants, 2D map regressions, scenic and Kathmandu landscape invariants, independent river-coordinate checks and headless main-scene execution. GPU captures are additional evidence; they do not replace tests or establish a frame-rate target.

The final Kathmandu run passed 53,002 checks; its referenced logs contain no engine errors or warnings. A restricted execution attempt failed on macOS certificate access and MCP registry/port access before the successful unrestricted run. That attempt is not accepted as a passing import. The visual review uses Compatibility rendering (OpenGL 4.1 via Metal on Apple M4 Pro). Forward+ has not been accepted; its earlier startup stall remains unresolved. See `reports/kathmandu-render-review.json` for capture evidence and limits.

## Editor bridge

NPGameDev's MIT Godot MCP server/toolkit were selected after comparison with Coding-Solo and YasiruRF implementations. Server revision: `e966eba5409ca0ce7f34a084e5fbd5644183e365`. Toolkit revision: `7e801d7b6603eb908dfb7e58bd497daa74a6502b`. Source receipt is `tools/godot-mcp-source.json`; the vendored toolkit retains its LICENSE and ATTRIBUTIONS. Do not patch it to implement GOPALA gameplay. Authored extensions belong to `game/addons/gopala_mcp/`.

`python3 tools/start_mcp.py` launches the built local server with a project-bound environment. It prefers local Node 22.18.0. `--read-only` enables the server's read-only mode. The bridge is authenticated over loopback; keep session files out of version control and do not expose the listener publicly.

The local SDK roundtrip is recorded in `reports/mcp-verification.json` (19 checks). Upstream server testing passed 52 test files; macOS-inapplicable registry assertions were skipped. The production dependency audit reported no known advisories at installation, while the development dependency installation reported one moderate advisory. This is not a security certification. No Codex app registration or callable Godot connector in the current chat is implied.

On macOS the upstream toolkit can report a stale process-ID error if an editor was forcibly terminated. Inspect actual logs; never suppress that error or count a affected run as clean. A normal import/editor shutdown refreshes and removes this project's registry entry. Avoid terminating unrelated editors or changing vendored registry code.

## Acceptance boundary

The content lab, tested tooling and generated sprites are development infrastructure. The landscape is an interactive environment. Neither establishes a working hauling, construction, cattle or save/load loop. Report these milestones separately.

## Geographic import environment

The project-local Python environment includes NumPy 2.5.3, Rasterio 1.5.1 and SciPy 1.18.1. Installation initially failed due to intermittent disk-full errors, then completed after space became available. The final pip dependency check reported no broken requirements. Geographic conversion and source-coordinate tests are described in docs/GOPALA-Kathmandu-Geography.md. Original terrain-download and country-archive caches were removed after processing; their SHA-256 receipts and download URLs are retained.
