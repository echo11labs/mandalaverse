# GOPALA development

For Godot implementation, use the project workflow at [skills/gopala-godot/SKILL.md](skills/gopala-godot/SKILL.md). The development plan remains the scope authority. Keep tools and generated content separate from gameplay progress.

The engine and MCP repositories in `.tools/` are local pinned dependencies, excluded from version control. The toolkit in `game/addons/godot_mcp_toolkit/` is vendored upstream code; preserve its license and source receipt. GOPALA extensions belong in `game/addons/gopala_mcp/`.

Run `python3 tools/verify.py` for authored content/code changes. Check actual reports, including warnings or skipped tests; never claim an error-free toolchain based only on build success. Refer to `docs/GOPALA-Toolchain.md` for setup and the acceptance scope.

<!-- BEGIN blender-mcp-bridge v2 (managed locally; keep this block current) -->
## Blender MCP Bridge 0.4.1

When a task concerns Blender in `/Users/devendrashahithakuri/ME/Blender`, use only the
profile-bound secure bridge registrations `blender-main`, `blender-render`, and
`blender-sandbox`. Load the canonical operating instructions from
`/Users/devendrashahithakuri/ME/Blender/Addons/blender-mcp-bridge/skills/blender-mcp-bridge/SKILL.md`
before using Blender tools.

Start with `bridge_profile_status()`, `blender_status()`, `blender_capabilities()`,
`scene_inspect()`, and `collection_list()`. Use `main` for the interactive scene unless the user
explicitly identifies another profile. Use `blender_python_execute(code)` with full `bpy` access
for Geometry Nodes and workflows not covered by a typed tool. Do not silently switch bridge
implementations or profiles. Use asynchronous render jobs for image validation and call
`landscape_capabilities()` before ANT Landscape work.

The tool catalog is identical across all profiles. After a bridge upgrade, start a fresh Codex
task or restart Codex so its stdio workers and cached `tools/list` are rebuilt. A 46-tool response
with `arbitrary_python: false` is a stale 0.4.0 task, not a restricted profile.
<!-- END blender-mcp-bridge -->

## Scaling and sizing

For authored scaling/sizing changes, use `game/data/standards/world_scale.json` and `docs/GOPALA-Scale-and-Sizing.md`. Express sizes as target dimensions, normalize imported mesh bounds including child transforms, and preserve bottom-centre ground anchors. Add a standard profile and measured checks for new object categories. Update the standard revision when its dimensions or unit contract change. Run `python3 tools/verify.py`; it regenerates `reports/scale-audit.json` with standard/asset hashes and measured sizes. Inspect that report after every scaling change. World-object dimensions must be authored in metres and converted through the terrain metres-per-world-unit setting. Check people against rivers and terrain, not only against props. Do not enlarge physical meshes into map markers.
