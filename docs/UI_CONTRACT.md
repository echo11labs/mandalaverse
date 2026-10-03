# GOPALA HUD/UI Contract

Status: **Block 0 deliverable — approved conditionally by the mission decider.**
Date: 2 October 2026. Branch: `hud/production`, created from checkpoint
`checkpoint/pre-hud` @ `9be8893` ("checkpoint: preserve inherited pre-HUD working tree").

Amendments to this contract require explicit decider approval. This document is the
authority for all HUD work in Blocks 1–6; where it disagrees with the blueprint
(`docs/Farthest Frontier–Inspired HUD UI Blueprint for Godot.md`), this document wins.

## 0. Locked decisions

1. **Engine target: Godot 4.7.2.stable, GL Compatibility renderer.** The spec line
   "4.6.3" is amended to 4.7.2; the pinned binary (`.tools/godot/Godot.app`) is not
   downgraded and `tools/verify.py` continues to hard-require `4.7.2.stable`.
2. **Inherited working tree is preserved** in `checkpoint/pre-hud` @ `9be8893`.
   No resets, stashes, cleans, or discards of inherited state. The detached worktree
   `.kilo/worktrees/scarlet-walleye` is not touched.
3. **Testing: the SceneTree harness + `tools/verify.py` stay.** GUT is not installed.
   Baseline exceptions are permanent fixtures of the gate:
   - `kathmandu-tests` fails with `"Mesh matches ground model"` (pre-existing,
     reproduces on a clean checkout).
   - Import emits 4 `TerrainStreamer` instantiated-config default-value warnings.
   All new acceptance is **delta-based**: no *new* failing stage, no *new* warning,
   no *new* test failure.
4. **Block 4 building-definition schema extension is approved in principle** under
   backward-compatible defaults, `schema_version` bump when required, migration of
   all six building `.tres`, content-audit/test updates, and no broken callers.
5. **Minimal `kathmandu_valley.gd` edits are authorized from Block 3 only**, limited
   to routing picking, selection, focus requests, and placement commands through
   approved interfaces. Terrain, geography, camera behavior, rendering, and
   unrelated world systems are out of scope.

## 1. Authority and data-flow rule

The simulation is (and when it exists, remains) authoritative. The UI:

- **reads** immutable snapshots and view-models;
- **submits** typed commands through the services in §4;
- **never** mutates simulation state, invents stock, charges resources, or advances
  time by itself.

Local component wiring uses local signals. Cross-system traffic uses the typed
services and the four legacy `UIEvents` signals (§8). `UIEvents` must not grow into
an unrestricted global bus.

## 2. Current real capabilities vs. unavailable simulation features

### 2.1 Real, verified, UI-safe to call (Block 0 audit evidence)

| Capability | Exact API / source |
|---|---|
| Content catalogue | `res://data/catalog.json` → `GopalaBuildingDefinition`, `GopalaResourceDefinition`, `GopalaZoneDefinition` `.tres` (6 buildings, 7 resources, 1 zone); audit via `GopalaContentAudit.run()` (`game/core/content/content_audit.gd`) |
| Terrain query | `GopalaKathmanduTerrain`: `contains(cell)`, `cell_at(point)`, `cell_position(cell)`, `is_buildable(cell)`, `height_at(x,z)`, `elevation_at(x,z)`, `nearest_river(point)`, `GRID_SIZE`, `CELL_SIZE`, `camp` (`game/core/landscape/kathmandu_terrain.gd`) |
| Camera control | `kathmandu_camera.gd`: `overview()`, `focus_point(point, span)`, `zoom_by/zoom_step/zoom_toward`, `turn_by`, `tilt_by`, `pan_ground`, `management_size()`, `maximum_size()` — no signals |
| Picking | `kathmandu_valley.gd:496 pick(screen) -> Dictionary` (physics raycast) |
| Territory overlay | `GopalaMapOverlay`: `cycle_mode()`, `mode_name()`, `region_id_at(x,z)`, `region_record(id)`, `mode`, `regions`, `built` (`game/scenes/landscape/map_overlay_drawer.gd`) |
| Theme/tokens | `GopalaTheme.build()/font()/flat()/lifted()` + palette constants (`game/assets/ui/theme/gopala_theme.gd`) |
| Legacy HUD surface | `GopalaKathmanduHud` — full list in §8 (`game/scenes/landscape/kathmandu_hud.gd`) |
| Minimap | `GopalaMinimap` (`game/scenes/ui/gopala_minimap.gd`) |
| Tests/gate | `tools/verify.py` stages; `tests/run_ui_tests.gd` (111 checks), `run_content_tests.gd` (19), `tests/measure_ui.gd` (layout at 1280×720/1600×900) |
| Event bus (inert) | `UIEvents`: `resource_updated`, `objective_progressed`, `build_action_requested`, `event_logged` — declared, never emitted/connected |

### 2.2 Not available — UI must capability-gate, never fake

| Feature | Status | Backlog |
|---|---|---|
| Tick loop, pause/speed authority, day/season/year advancement | does not exist | G-006 |
| Inventory, transfers, reservations, stock levels | does not exist | G-007 |
| Population, households, needs, professions | does not exist | G-012/021 |
| Construction lifecycle, occupancy, placement commit/charge | does not exist | G-010 |
| Production, recipes, trade, reports | does not exist | G-020/022 |
| Alerts/notification producers, weather, events | does not exist | G-017/026 |
| Save/load of any UI or simulation state | does not exist | G-014/028 |
| Selection service, entity registry | does not exist (ad-hoc pick only) | G-004/G-010 |
| Fertility/desirability/water/logistics/pollution/coverage data | does not exist | G-017/018 |

Rule: a HUD region whose data source is unavailable renders an explicit
**capability-gated empty state** (or a disabled control *with a reason*), never
fabricated numbers. "No simulation data source" is a valid, displayed state.

## 3. Snapshot DTOs — ownership and immutability

- DTOs are typed `RefCounted` (or `Resource` when authored content): at minimum
  `SettlementSnapshot` (identity, population/housing, clock, weather, alerts),
  `StockEntry` (id, amount, delta, threshold), `SelectionSnapshot`,
  `PlacementResult` (valid, severity, reason_key, blocking_cells, warnings,
  cost_state, local_modifiers), `NotificationData` (severity, reason_key,
  position, entity_id, count), `CommandResult` (ok, code, reason_key, payload).
- **Ownership:** DTOs are constructed by their provider (simulation or an
  explicitly injected mock), handed to the UI by value/signal, and are
  **immutable from the UI's perspective** — the UI never writes fields on a
  received snapshot; it derives view-model copies locally.
- Snapshots carry a monotonically increasing `seq`/`version` so stale emissions
  can be dropped; consumers ignore any snapshot older than the last applied seq.
- DTOs hold **data only** — no `Node` references, no `Object` references.
- Providers live behind one registration point (§7). The UI depends on the DTO
  types and the provider interface, never on scene paths.

## 4. Typed UI commands and results

Every UI-originated world interaction is a named command on a service, returning
or emitting `CommandResult`:

| Command | Service | Notes |
|---|---|---|
| `request_set_time_speed(multiplier: int)` | clock shim → future G-006 | 0 = pause, 1/2/4; result is authoritative only when a real sim acknowledges |
| `request_activate_tool(tool_id: StringName)` | UIRouter | mutually exclusive; see mode table in §10 |
| `request_start_placement(building_id, )` / `request_rotate(delta)` / `request_confirm_placement()` / `request_cancel_tool()` | placement service | confirm is rejected unless `PlacementResult.valid`; **charge happens only on simulation confirmation** |
| `request_select_at(screen_pos)` / `request_select_id(entity_id)` / `request_clear_selection()` | selection service | |
| `request_focus_world_position(position)` | selection/camera adapter | delegates to `camera.focus_point()` |
| `request_set_overlay(overlay_id)` / `request_cycle_overlay()` | overlay manager | unsupported ids return `UNSUPPORTED` |
| `request_open_window(window_id)` / `request_close_window(window_id)` | UIRouter | modal windows suspend world tools |
| `request_acknowledge_notification(notification_id)` | notification service | |

`CommandResult.ok == false` always carries a machine `code` and a localization
`reason_key`; the UI displays the reason (disabled-with-reason rule). Commands
never block the frame; simulation acknowledgements arrive by signal.

## 5. Entity IDs and lifecycle rules

- Entities are referenced by **stable IDs** (`StringName` or `int`), never by
  retained `Node` references, in any service, router, DTO, or view-model held
  across frames.
- Services resolve IDs through a registry with validity-safe lookup; every
  resolution path checks liveness (`is_instance_valid` or registry membership)
  and returns a typed "gone" result instead of crashing.
- `entity_removed(id)` (once it exists) clears: current selection, open context
  panel, world widgets, placement target, notification camera-jump handles.
  Deleting a selected entity must never leave a stale panel: the panel closes or
  switches to a tombstone state within the same frame.
- **Scene-scoped services** (selection, placement) are bound to the world scene:
  either they are scene-scoped nodes, or autoloads expose `bind_world()`,
  `unbind_world()`, `reset()`. `unbind_world()` drops every ID and connection.
- **UIRouter** (autoload) stores only `modes`, `entity IDs`, and plain payload
  dictionaries — never temporary scene-node references. It exposes `reset()` and
  must be reset on scene changes and at test setup/teardown.
- Guards: all signal connections are checked before connect
  (`is_connected`); asynchronous callbacks (tweens, awaits) revalidate their
  target handle before use.

## 6. Service boundaries

- **Selection:** the UI owns the panel and highlight *presentation*; the world
  keeps the raycast implementation. The selection service is the only bridge
  (`selection_changed(snapshot)` out, `request_select_*` in). UI clicks are
  consumed before world picking (see §10 input rules).
- **Placement:** validation-only until G-010. The placement service computes
  `PlacementResult` from footprint + terrain queries (+ occupancy once it exists).
  It cannot charge, spawn, or reserve. Confirm sends a command; the UI updates
  only on the acknowledged result. Repeat-placement stops when a confirm is
  rejected and shows the exact `reason_key`.
- **Notifications:** one service owns severity (INFO/OPPORTUNITY/WARNING/
  CRITICAL/COMBAT), dedupe/throttle, lifetime, persistence, event-history, and
  camera-jump payloads `{position, entity_id}`. Producers are mock-only until
  real systems exist; nothing fabricates CRITICAL gameplay alerts.
- **Overlays:** the overlay manager exposes an overlay **only** with a real data
  source. Currently real: `territory` (GopalaMapOverlay) and `buildable`
  (terrain probe). Everything else returns `UNSUPPORTED` and is shown as
  unavailable in the legend. Unsupported overlays must never fabricate
  fertility, desirability, water, logistics, pollution, or production data.
  Temporary placement overlays restore the previous overlay on exit.
- **Camera:** UI issues only the approved adapter commands
  (`focus_point`, `overview`, `zoom_step`, `turn_by`); no camera-internal state
  is read or written directly; camera behavior itself is not modified (§0.5).
- **CanvasLayer order: HUD stays on its current layer (2)** until every existing
  layer in the main scene is inventoried and a layer plan is approved.

## 7. Mock-source restrictions

- `MockSnapshotSource` (Block 1.5) is **development/test-only**.
- It can only enter the app through **explicit injection** (test setup, component
  gallery scene, or a debug flag that is off by default). It is never registered
  as the default provider for normal gameplay, never shipped enabled, and never
  used to produce gameplay-visible numbers outside tests/gallery.
- With no provider injected, the HUD renders capability-gated empty states (§2.2).
- Mock outputs are visually and structurally identical to real snapshots (same
  DTO types) so tests exercise the production paths.

## 8. Legacy HUD compatibility surface

`GopalaKathmanduHud` (`game/scenes/landscape/kathmandu_hud.gd`) must keep this
surface functional (asserted by `game/tests/run_ui_tests.gd`) until a block
explicitly migrates each item and updates the tests in the same block:

- Signals: `valley_requested`, `source_requested`, `camp_requested`,
  `grid_changed(on)`, `names_changed(on)`, `zoom_in_requested`,
  `zoom_out_requested`, `turn_left_requested`, `turn_right_requested`,
  `build_selected(id)`, `speed_selected(multiplier)`.
- Methods: `follow(camera)`, `close_build()`, `set_grid()`, `set_names()`,
  `toggle_grid()`, `toggle_names()`, `show_place(title, detail)`,
  `show_territory(...)`, `show_chiefdom(...)`, `hide_inspection()`,
  `configure_survey(terrain, regions)`, `set_resource(id, amount)`,
  `set_clock(day, year, season)`, `set_settlement_name(value)`,
  `notify(title, body, tone)`, `button_for(id)`, `clear_build()`.
- The four `UIEvents` signals are **preserved as-is** (§1); they are not expanded.

Migration protocol: a block may replace an internal implementation only if the
legacy surface keeps working (adapter if needed) and the UI test suite stays green
in the same commit. No big-bang replacement of `hud.tscn`/`kathmandu_hud.gd`.

## 9. Error, unsupported-capability, and cleanup behavior

- Exported references are validated in `_ready` with actionable `push_error`
  messages; failures name the node and the expected path/type.
- Missing data degrades visibly but safely: missing icon → fallback glyph +
  one log line; missing localization key → key text shown + one log line;
  empty catalogue → empty-state panel; unavailable system → `UNSUPPORTED`
  result surfaced as disabled-with-reason. Broad `null` checks that hide
  ownership bugs are forbidden.
- **No duplicate signal connections**: connect once with ownership documented;
  disconnect in `_exit_tree`/mode exit; tests assert `is_connected` state.
- **Mode cleanup (exit path)**: exiting any world-tool mode must remove ghost
  previews, temporary overlays, cursor changes, input locks, instructional
  footers, and placement HUD state; UIRouter is the sole transition owner.
- **Esc hierarchy** (global): cancel current step → close current panel/window →
  open pause menu. **Right-click**: step back/cancel one level; never silently
  destroys committed work.
- Debugger discipline: no parser errors, invalid calls, missing resources, orphan
  warnings, or repeated input errors. Baseline exceptions are exactly the two
  recorded in §0.3 — anything new is a defect.
- Duplicate notification suppression, notification duration, and tooltip delay
  are settings-driven (Block 1.5/6), not hard-coded per call site.

## 10. Input and layout rules

- Named InputMap actions only. Actions to exist by end of Block 1:
  `simulation_pause`, `simulation_speed_1..4`, `tool_select`, `tool_build`,
  `tool_road`, `tool_harvest`, `tool_clear`, `tool_zone`, `tool_terraform`,
  `tool_explore`, `overlay_cycle`, `placement_rotate_cw/ccw`,
  `hud_toggle`, `build_menu_toggle`, `management_toggle`, `notification_next`,
  `camera_focus_settlement`, `hud_grid`, `hud_names` — plus the existing nine
  camera/territory actions. The hard-coded `KEY_G/KEY_N/KEY_HOME/KEY_ESCAPE`
  checks in `kathmandu_valley.gd:501-510` migrate to actions in Block 3 (first
  authorized world-code edit), except `ui_cancel` handling which the router owns.
- Tooltips display the resolved binding dynamically and refresh after rebinding.
- Input leakage rules: UI controls consume handled events
  (`Control.accept_event()` / `MOUSE_FILTER_STOP`); decorative plates stay
  `MOUSE_FILTER_IGNORE`; **interactive panels/modals use `STOP`** — current
  pass-through of panel backgrounds is a known legacy behavior to fix as panels
  arrive (Block 3).
- Layout: anchors for top-level regions, `Container`s inside; anchors+container
  responsibilities never mixed on one node; no absolute positioning inside
  complex panels; modals cap size and scroll internally; tooltips clamp to the
  viewport. Design reference 1920×1080; verified at 1280×720, 1920×1080,
  2560×1080, 3440×1440/2560×1080, 3840×2160.
- Performance: signals/snapshots drive updates; no `_process()` polling for data;
  no repeated `get_node` in per-frame code; no whole-panel rebuilds for single
  value changes; world widgets pool/cull by distance/zoom/importance.

## 11. Revised roadmap (Block 0 → 6, with Block 1.5)

| Block | Scope | Exit (delta-based) |
|---|---|---|
| **0** | Audit, contract (this file), attribution ledger, checkpoint branch, baseline evidence | All deliverables on disk; gate baseline recorded; approval granted |
| **1** | CanvasLayer/full-rect root, `GopalaTheme` tokens, UIRouter, InputMap actions, reusable component gallery, UI-scale setting | Gallery renders every component state; tests at 720p/1080p/21:9/4K without clipping; router transition tests green |
| **1.5 (new)** | **Minimal simulation spine:** snapshot DTOs + provider injection point, typed command/result types, scene-scoped selection & placement service scaffolding with `bind_world/unbind_world/reset`, notification service shell, overlay capability registry, UIRouter reset integration, mock provider (test/gallery only) | Services pass lifecycle tests (bind/unbind/reset, stale-ID resolution, no Node refs held); mock injection proven test-only; **no gameplay-visible fake data**; HUD can bind to a provider and capability-gate everywhere else |
| **2** | Top HUD, time controls, action dock, event feed, notification stack — **integrated against the 1.5 spine** | Signal-driven updates only; controls expose shortcut+tooltip; empty states shown when no provider |
| **3** | Selection integration, context panel shell (ground first), world widgets; authorized minimal `kathmandu_valley.gd` edits | Selection changes never leave stale panels; UI clicks never reach world; deleted entities close safely |
| **4** | Build catalog, placement ghost/HUD, structured validation, schema extension (approved in principle) | Full flow works end-to-end; **not "production-ready" until command handling, occupancy/reservation, resource authority, and construction lifecycle exist (G-006/007/010)** |
| **5** | Overlay manager + legends (only real sources), management windows capability-gated to available data | Each overlay answers a named question or reports unsupported; no leftover world materials on close |
| **6** | Final art/audio, accessibility (scale 80–150%, high contrast, reduced motion, color-blind palettes), localization + pseudolocalization, UI prefs save/restore, optimization, regression suite | No missing resources/orphans/broken focus/clipped strings; prefs persist; full manual matrix passes |

## 12. "UI-complete" vs "gameplay-integrated"

- **UI-complete:** every screen/component in the required structure exists, is
  data-driven from DTOs/catalog, themed, keyboard-accessible, localized,
  responsive across the resolution/scale matrix, tested (harness + manual
  matrix), documented, and produces no debugger errors or input leaks — with
  data supplied by explicitly injected providers or capability-gated empty
  states. Screenshots are evidence, never proof.
- **gameplay-integrated:** UI-complete **plus** every read and command flows to
  and from the authoritative simulation (G-006+): real clock/speeds acknowledged
  by the sim, real stock and selection, placement validated and committed by the
  sim with occupancy/reservation and resource authority, notifications produced
  by real events, overlays rendered from real spatial data, and save/load
  round-trips durable UI preferences. No mock is involved in gameplay paths.

## 13. Baseline evidence (Block 0, `reports/baseline/`)

- `pre_hud_status.txt` — `git status --porcelain=v2` before the checkpoint.
- `pre_hud_worktree.patch` — binary-safe diff of the inherited worktree (21.7 MB).
  **Not committed** (too large for the evidence commit); kept local and excluded
  via `.git/info/exclude`, integrity recorded in `pre_hud_worktree.sha256`.
- `pre_hud_staged.patch` — empty (nothing was staged at baseline).
- `pre_hud_verification.json` — full `tools/verify.py` record (engine
  `4.7.2.stable.official.ed1daf0bf`; all stages pass except the pre-existing
  `kathmandu-tests` failure; ui-tests 111 checks).
- **Screenshot requirement: PARTIAL.** Resolution requests were exercised
  successfully through the existing `--capture` path with zero engine error
  lines, producing `hud_baseline_1280x720.png` (actual 1152×720),
  `hud_baseline_1920x1080.png` (actual 1728×1080),
  `hud_baseline_2560x1080.png` (actual 1728×1080), and
  `hud_baseline_3840x2160.png` (actual 2675×1672). **Actual PNG dimensions were
  display-clamped** (physical display is 1728 pt wide); **true-pixel 1080p,
  21:9, and 4K capture remains deferred** pending a larger display or an
  approved capture harness (a code addition deferred by instruction).
- Observed legacy-HUD defects at the 720p-class capture (baseline, not fixed in
  Block 0): (a) settlement-name/status-card collision under the top band,
  (b) resource-chip name labels truncated/illegible at 9 px,
  (c) view-tools row overflows its shell and truncates the Esc hint at the
  right screen edge. These enter the Block 1/2 acceptance matrix.

## 14. Excluded from the checkpoint (recorded for audit)

Left on disk, untracked: the EmacEArt/Roadside Tales binary pack
(`game/Meshes/`, `game/Prefabs/`, `game/Materials/EA*`, `game/Textures/EA*`,
`game/Shaders/EA_CoolWater.gdshader`, `game/AssetsPreview_Demo/`,
`game/Documentation/*` except its license, `game/README.txt`,
`game/EA_Shared.material`), pack demo scripts/scenes (`game/Scripts/`,
`game/scenes/WaterDemo.tscn`, `game/scenes/UI_ParameterPanel.tscn`),
`game/addons/godotiles/bin/` (32 MB native binaries, plugin not enabled),
`.freebuff/` (tool metadata), and this pass's `reports/baseline/*` artifacts.
Rationale: third-party redistribution terms need a publishing decision
(see `ATTRIBUTION.md`); nothing was deleted.
