---
name: gopala-godot
description: Build and verify GOPALA's Godot 2D settlement systems, scenes and authored content using this project's pinned toolchain. Use for GOPALA implementation and debugging, not unrelated Godot projects.
---

# GOPALA Godot

Read `docs/GOPALA-Implementation-Backlog.md` and the relevant section of `docs/GOPALA-2D-Development-Vedas.md` from the project root. The scene in `game/scenes/content_lab.tscn` is a content laboratory, not implemented gameplay. Do not count it as the first playable settlement.

Use `tools/godot.py` for the pinned Godot Standard build and `tools/start_mcp.py` for the tested editor bridge. Run `python3 tools/verify.py` after authored GDScript or content changes; inspect `reports/verification.json` and failure logs. A zero Godot exit code alone does not establish success: the gate also rejects script and engine errors and requires a structured test result.

If the Godot MCP tools are attached, use `gopala_content_audit` to check definitions and image provenance. Load needed optional tool groups together with `discover_tools`; check the returned catalogue for current schemas. Use live scene tools when editing a scene already open in Godot, and save through the editor. Direct file changes require an editor refresh before evaluating the result. Avoid two writers to the same scene.

Keep `.tres` definitions immutable during play. Stable IDs identify goods/buildings/zones; actor and inventory state belongs to separate runtime records. ResourceLoader shares Resource instances, so duplicating a view must never create or erase inventory. Keep authoritative simulation on a fixed tick; rendering and animation observe it. Construction receives physically reserved and delivered materials. Transfers, cancellation and save/load must conserve goods.

The catalogue at `game/data/catalog.json` names every admitted definition. The manifest at `game/assets/manifest.json` records prototype image dimensions, hashes and provenance. Existing geometric sprites are test fixtures. Do not relabel them as final Nepali artwork or historical evidence. For production art, follow `docs/GOPALA-Kala-2D-Art-Direction.md` and `docs/GOPALA-Asset-Pipeline.md`, preserving generator prompts/source files, rights, anchors, footprints, construction stages and visual review evidence.

For the project-specific MCP extension, use the toolkit's bundled `CompanionSkills/mcp-extension-creator/SKILL.md` under `game/addons/godot_mcp_toolkit/`. Declare read-only tools accurately, guard caller-supplied file paths, and wrap project-derived output with its Untrusted helper. Keep authored tools in `game/addons/gopala_mcp/`; do not patch upstream toolkit code to implement gameplay.

Report what was implemented, what tests actually cover, and remaining requirements. A clean import is not save integrity, a screenshot is not performance evidence, and a content audit is not a playable economy.
