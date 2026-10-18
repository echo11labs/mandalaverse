# GOPALA — developer onboarding

Start with [current status](docs/STATUS.md) for the verified revision, latest gate result, playable scope and remaining work. That page is the status authority; this guide describes how to work on the project. The [coordinator lead plan](docs/GOPALA_LEAD_PLAN.md) sets direction, while the [design contract](docs/GAME_DESIGN_CONTRACT.md), [UI contract](docs/UI_CONTRACT.md) and [implementation backlog](docs/GOPALA-Implementation-Backlog.md) define scope and acceptance.

## Run and verify

From the repository root:

```sh
python3 tools/godot.py
python3 tools/verify.py
```

The player scene is `game/scenes/mvp.tscn`. Read `reports/verification.json` and the linked logs after verification: require `ok=true` and every stage passing, and inspect warnings, timeouts and any allowed errors. A successful engine exit alone is insufficient. Automated checks do not establish a completed human playtest, approved artwork or acceptable performance. See [toolchain](docs/GOPALA-Toolchain.md) for setup and acceptance scope.

## Repository layout

| Path | Purpose |
|---|---|
| `game/core/` | Authoritative fixed-tick simulation, commands, inventories, construction, routes and runtime records |
| `game/scenes/` | Player scene, terrain and UI presentation observing simulation state |
| `game/data/` | Definitions and policies; balance values belong here |
| `game/assets/` | Selected admitted art, models, materials and provenance |
| `game/tests/` | Headless acceptance and regression runners |
| `game/bench/`, `tools/bench.py` | Separate forty-settler fixture and rendered performance runner; smoke only in the normal gate |
| `game/addons/gopala_mcp/` | Project-owned MCP extensions |
| `docs/` | Design, current status, evidence and workflow |
| `tools/` | Pinned-engine wrappers and verification automation |
| `.tools/` | Ignored pinned local dependencies |

## Development rules

Read `AGENTS.md` and [Godot workflow](skills/gopala-godot/SKILL.md). Pull one released bridge task at a time, claim its named branch, ask unclear requirements on the bridge, verify and submit with evidence. Never push without Devendra's instruction. Preserve ongoing user edits and vendored upstream addon sources/licences; project extensions belong in the GOPALA addon.

Rendering observes the deterministic simulation. Inventory transfers, reservations, construction cancellation and save/load must conserve goods. Keep definitions immutable during play. Follow [asset pipeline](docs/GOPALA-Asset-Pipeline.md), [scale standard](docs/GOPALA-Scale-and-Sizing.md) and `game/data/standards/world_scale.json` when admitting models; dimensions are metres with measured bottom-centre ground anchors. Refresh [STATUS](docs/STATUS.md) from the actual report when verification or playable scope changes.
