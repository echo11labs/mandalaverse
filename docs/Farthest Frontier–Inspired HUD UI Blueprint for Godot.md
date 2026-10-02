# Farthest Frontier–Inspired HUD/UI Blueprint for Godot
## Executive direction
Build a **desktop-first, mouse-and-keyboard settlement-simulation interface** that adopts the information architecture and interaction principles of *Farthest Frontier* while using an original visual identity, original assets, and project-specific terminology. The strongest reference pattern is a persistent top status strip, time controls at the lower left, high-frequency management tools at the lower right, contextual information near the selected world object, overlays that communicate spatial data, and modal windows only for deep management tasks. *Farthest Frontier* itself places town status, season, weather, and essential resources across the top; frequently used construction and management actions occupy the lower HUD; keyboard shortcuts mirror those actions.[^1]

The implementation should use **Godot 4.6.3 stable**, GDScript, `CanvasLayer`, reusable `Control` scenes, nested `Container` layouts, one project-level `Theme`, typed custom `Resource` classes, and a clear presentation layer that observes—not owns—simulation state. Godot 4.6.3 is the current stable maintenance release in the official archive, and its maintainers describe maintenance updates as safe upgrades while still recommending version control and backups.[^2][^3]

The UI must feel like part of a strategy game, not a web dashboard. Avoid floating card grids, excessive rounded pills, equal visual emphasis everywhere, huge margins, glassmorphism, browser-style sidebars, and decorative panels with no gameplay purpose. Preserve as much unobstructed world view as possible and reveal detail progressively: glanceable HUD first, contextual panel second, full management window third.
## Reference analysis
### What the reference does well
The reference interface separates information by urgency and interaction frequency:

| Layer | Player question | Recommended implementation |
|---|---|---|
| Persistent HUD | “Is my settlement safe and stable?” | Population, housing, food, health/happiness warnings, season/weather, core stock, speed |
| Action HUD | “What can I do right now?” | Build, roads, harvest, clear, flatten/terraform, explore, overlays |
| Context panel | “What is this selected thing doing?” | Building/villager/resource details and immediate controls |
| World widgets | “Where is the problem?” | Alert, task, status, resource, production, and selection markers |
| Overlay | “Where should this action happen?” | Fertility, water, desirability, pollution, logistics, defense coverage |
| Management window | “How is the whole system performing?” | Professions, storage, production, population, reports, trade, policies |
| Notification layer | “What changed and must be handled?” | Toasts, event feed, warning banners, camera-jump actions |

The official guide confirms that its top HUD combines people, season/weather, and critical stored resources; the lower controls expose camera centering, professions, storage, building, harvesting, clearing, walls, terrain flattening, roads, and exploration. Its building flow is also explicit: choose a structure, inspect a placement preview and grid, rotate, confirm, then use the selected building UI to manage workers, work areas, priorities, relocation, or salvage.[^1][^4]

The system also uses map overlays as decision tools rather than decoration. Desirability supports housing decisions, fertility supports crop and orchard placement, and irrigation visualizes the water table for well placement. This is a key lesson for the new game: every overlay must answer a specific spatial question and appear automatically when an associated tool requires it.[^5]
### What should improve
Do not reproduce the reference screen pixel-for-pixel. Improve the pattern with:

- A user-configurable HUD scale from 80% to 150%; players have publicly reported readability difficulty with small resource icons and text.[^6]
- Pinning for selected resources, production chains, and settlement metrics. A community enhancement mod adds a pinnable resource overlay, deeper top-bar tooltips, contextual hotkeys, and building counts, indicating practical demand for these features.[^7]
- Search, category filters, favorites, recently used items, and existing-building counts inside the build catalog.
- Distinct severity levels for notifications: information, opportunity, warning, critical, and combat.
- Optional compact and expanded HUD modes.
- Full remapping through named `InputMap` actions rather than checking physical keys directly; Godot supports multiple input events per named action and runtime modification.[^8][^9]
- Keyboard focus indicators, scalable type, color-blind-safe status encoding, localization-safe layout, and icon-plus-text labels for unfamiliar actions. Godot supports Unicode, CSV/gettext localization, bidirectional shaping, right-to-left mirroring, and pseudolocalization.[^10]
## Screen composition
### Base target
Design at a **1920×1080 reference canvas**, test from 1280×720 through 3840×2160, and include 21:9 tests at 2560×1080 and 3440×1440. Use anchored edge regions and container-driven internals; do not scale the entire interface as a single texture.

Suggested safe-area measurements at 1080p:

| Region | Anchor | Suggested size | Behavior |
|---|---|---:|---|
| Top HUD | Top stretch | 64–76 px high | Persistent; compact groups with expandable detail |
| Event feed | Top-left under HUD | 360–440 px wide | Latest 3–5 entries; scrollable history on click |
| Notifications | Top-center | 420–560 px wide | Temporary; never cover season/time controls |
| Context panel | Left or right edge | 360–440 px wide | Visible only with selection; tabs for complex entities |
| Build catalog | Bottom-center or lower-right | 720–1040 px wide, 300–430 px high | Opens over action HUD; searchable and category-based |
| Action dock | Bottom-right | 8–11 buttons, 44–56 px each | Persistent primary tools |
| Time controls | Bottom-left | 220–300 px wide | Pause and 1×/2×/3×/4× controls |
| Minimap | Optional lower corner | 220–280 px square | Collapsible; avoid if world navigation works better without it |
| Tooltip | Cursor-adjacent | 280–420 px max width | Clamped to viewport and delayed 250–400 ms |

Godot anchors define the reference points for control edges, while differing start/end anchors allow a control to resize with its parent. Internally, nested containers should manage rows, columns, padding, scrolling, proportional layouts, and wrapping; direct children of a `Container` surrender manual positioning to that container.[^11][^12]
### Top HUD
Divide the top strip into three readable clusters rather than one uninterrupted list:

1. **Settlement condition, left:** settlement name/tier, population, housing capacity, labor availability, health, happiness/morale, food months, and active critical alerts.
2. **Calendar, center:** year, season, day/progress, weather, temperature if relevant, and forecast warning.
3. **Tracked stock, right:** 6–10 pinned resources with quantity, trend arrow, recent delta, reserve threshold, and click-to-open storage detail.

Use semantic state colors sparingly. Neutral values remain parchment/ivory; positive trends use muted green; constrained values use amber; danger uses desaturated red; paused or disabled states use gray. Never rely on color alone—add an icon, shape, label, or trend direction.
### Action dock
The primary tool dock should contain actions used repeatedly while looking at the world:

- Select/inspect
- Build catalog
- Road/path
- Harvest/gather
- Clear/demolish
- Zone/district
- Terraform/flatten, if supported
- Explore/flag
- Overlays
- Settlement management
- Photo/UI-hide mode

Each button needs an icon, short tooltip, current shortcut, selected state, disabled state, reason for disabled state, and optional attention badge. The reference proves the value of pairing clickable tools with keyboard shortcuts, including build, harvest, roads, clearing, overlays, speed, pause, and UI visibility.[^1][^13]
### Context panel
One reusable shell should host entity-specific content. Its header contains portrait/icon, name, type, level, status, favorite/pin, camera focus, rename, and close. Its body changes by selection type:

| Selection | Primary content | Immediate actions |
|---|---|---|
| Construction site | Progress, missing materials, assigned builders, blockers | Prioritize, pause, cancel |
| Production building | Inputs/outputs, inventory, cycle, workers, efficiency | Worker slots, recipe, work area, priority, pause |
| Storage building | Capacity, allowed categories, stock, incoming/outgoing | Filters, reserve targets, empty, priority |
| Residence | Occupants, needs, desirability, upgrade requirements | Upgrade policy, alerts, focus resident |
| Villager | Name, age, household, profession, task, needs, health | Follow, locate home/work, reassign if allowed |
| Resource node | Remaining quantity, gather rate, accessibility | Mark harvest, prioritize, unmark |
| Farm/field | Rotation, fertility, weeds, rocks, yield forecast | Edit rotation, compost, worker count |
| Military building/unit | Readiness, equipment, health, coverage | Rally, patrol/defend, garrison |

Complexity should be progressive. The reference selected-building UI exposes workers, work area, production priorities, relocation, and salvage only after the building is selected. Farming deserves a specialized panel because fertility, soil mixture, weeds, rocks, crop rotation, and forecasted yield create a denser decision model.[^4][^14]
## Interaction model
### Global UI modes
Use an explicit state machine so incompatible tools cannot remain active together:

```text
NORMAL
├── BUILD_CATALOG
├── PLACING_BUILDING
├── DRAWING_ROAD
├── MARKING_HARVEST
├── MARKING_CLEAR
├── PLACING_ZONE
├── TERRAFORMING
├── PLACING_EXPLORE_MARKER
├── COMMANDING_UNITS
└── MODAL_WINDOW
```

Rules:

- Only one world tool may be active at a time.
- `Esc` cancels the current step; a second `Esc` closes the current panel; only then does it open the pause menu.
- Right-click cancels a world tool or steps back one level, but never silently destroys committed work.
- Opening a modal management screen suspends world-tool input.
- Selecting another action dock tool cleanly exits the previous mode through one `exit_mode()` path.
- The active mode owns its preview, cursor, overlay requests, instructional footer, and confirm/cancel behavior.
- UI controls consume handled input; world systems receive only unhandled input. Godot sends events through GUI controls, and `Control.accept_event()` plus `mouse_filter` determine whether those events propagate.[^15]
### Build-and-place flow
1. Player opens Build with button or action shortcut.
2. Catalog restores the last category and focus position.
3. Search, categories, favorites, or recent items narrow the list.
4. Each card shows icon, name, tier, footprint, cost, upkeep, worker slots, count already built, lock state, and one-line purpose.
5. Hover or focus opens a richer tooltip with prerequisites, production, desirability/pollution, and upgrade path.
6. Selecting a valid item closes or collapses the catalog and enters `PLACING_BUILDING`.
7. Ghost preview snaps to the world grid and reports validity continuously.
8. Placement automatically enables the relevant overlay: desirability for housing, fertility for farms, water for wells, deposit overlay for mines, service coverage for amenities.
9. The placement HUD shows cost, rotation, local modifiers, blockers, confirm, cancel, and multi-place modifier.
10. Left-click commits only if the validator returns valid; invalid clicks produce a restrained sound, brief shake, and exact reason.
11. `Shift` keeps placement active for repeated placement; otherwise return to the previous catalog state or normal mode.
12. Undo applies only to reversible planning actions and must disclose any refund or penalty.

Placement validity should return structured data, not a Boolean:

```gdscript
class_name PlacementResult
extends RefCounted

var valid: bool
var severity: int
var reason_key: StringName
var blocking_cells: Array[Vector2i]
var warnings: Array[StringName]
var cost_state: Dictionary
var local_modifiers: Dictionary
```
### Tooltips
Tooltips are part of the information architecture, not decoration. Godot supports default tooltip text and completely custom tooltip controls via `_make_custom_tooltip()`.[^16]

Use three levels:

- **Fast hint:** name, purpose, shortcut.
- **Detailed hover:** current value, trend, thresholds, causes, and click behavior.
- **Deep link:** “Click for storage report” or “Open settlement health.”

Clamp tooltips to the viewport, never place them beneath the cursor hotspot, and avoid covering the target. Use stable width, short paragraphs, labeled values, and no raw internal identifiers.
### Notifications
Create one notification service with deduplication, throttling, severity, lifetime, persistence, and optional world position.

```text
INFO         completed construction, policy changed
OPPORTUNITY  immigrants, trader, unlocked building
WARNING      low reserve, idle production, housing pressure
CRITICAL     starvation risk, fire, disease outbreak
COMBAT       raid detected, structure under attack
```

Clicking a location-aware notification should move the camera and select the relevant entity. Repeated notices should aggregate (“3 wells lack workers”) rather than flood the screen. Critical notices remain in the event history until acknowledged or resolved.
## Godot architecture
### Core principle
The simulation is authoritative. UI scripts display immutable snapshots or read-only view models and submit commands through services. They must not directly change building inventories, villagers, construction progress, or simulation time.

Godot UI is built from `Control` nodes, with content controls such as buttons and labels and layout controls such as box, margin, scroll, tab, and popup containers. A `CanvasLayer` keeps the HUD fixed in screen space independently of the moving world camera.[^17][^18]
### Scene tree
```text
GameRoot (Node)
├── World (Node3D)
│   ├── Terrain
│   ├── Entities
│   ├── CameraRig
│   ├── SelectionController
│   ├── PlacementController
│   └── OverlayRenderer
├── Simulation (Node)
│   ├── TimeSystem
│   ├── SettlementSystem
│   ├── PopulationSystem
│   ├── ResourceSystem
│   ├── ConstructionSystem
│   ├── ProductionSystem
│   ├── LogisticsSystem
│   └── AlertSystem
└── InterfaceLayer (CanvasLayer, layer 20)
    └── GameUI (Control, Full Rect)
        ├── WorldInputGuard (Control, Full Rect, mouse_filter IGNORE)
        ├── TopHUD
        ├── EventFeed
        ├── NotificationStack
        ├── ContextPanelHost
        ├── BuildCatalogHost
        ├── ToolModeHUD
        ├── TimeControls
        ├── ActionDock
        ├── OverlayLegend
        ├── WorldWidgetLayer
        ├── TooltipService
        ├── ModalHost
        └── TransitionLayer
```

Use additional `CanvasLayer` levels only when ordering cannot be handled inside the interface tree, for example world-space labels at layer 10, game HUD at 20, modals at 30, and fade/loading at 40. Canvas layers render according to numeric layer rather than tree order.[^17]
### Project structure
```text
res://
├── autoload/
│   ├── app_state.gd
│   ├── ui_router.gd
│   ├── ui_events.gd
│   ├── input_service.gd
│   ├── notification_service.gd
│   └── settings_service.gd
├── ui/
│   ├── game_ui.tscn
│   ├── theme/
│   │   ├── settlement_theme.tres
│   │   ├── ui_tokens.gd
│   │   ├── styles/
│   │   ├── fonts/
│   │   └── cursors/
│   ├── components/
│   │   ├── icon_button/
│   │   ├── resource_chip/
│   │   ├── stat_row/
│   │   ├── status_badge/
│   │   ├── alert_item/
│   │   ├── tab_button/
│   │   ├── progress_meter/
│   │   ├── building_card/
│   │   └── tooltip/
│   ├── hud/
│   │   ├── top_hud/
│   │   ├── action_dock/
│   │   ├── time_controls/
│   │   ├── event_feed/
│   │   └── notifications/
│   ├── panels/
│   │   ├── context_shell/
│   │   ├── building_panel/
│   │   ├── villager_panel/
│   │   ├── storage_panel/
│   │   └── farm_panel/
│   ├── windows/
│   │   ├── settlement_overview/
│   │   ├── professions/
│   │   ├── resources/
│   │   ├── production/
│   │   ├── reports/
│   │   ├── options/
│   │   └── keybindings/
│   └── tools/
│       ├── build_catalog/
│       ├── placement_hud/
│       ├── overlay_legend/
│       └── selection_box/
├── data/
│   ├── buildings/
│   ├── resources/
│   ├── professions/
│   ├── notifications/
│   └── ui/
├── systems/
├── world/
├── audio/ui/
├── localization/
└── tests/
    ├── unit/
    ├── integration/
    └── scenes/
```
### Data resources
Use typed custom `Resource` definitions for game content and UI presentation metadata. Godot resources are data containers and are loaded once per path, making them appropriate for reusable definitions.[^19]

```gdscript
class_name BuildingDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export_multiline var description_key: String
@export var category: StringName
@export var icon: Texture2D
@export var scene: PackedScene
@export var footprint: Vector2i
@export var cost: Dictionary[StringName, int]
@export var upkeep: Dictionary[StringName, int]
@export var worker_slots: int
@export var tier: int
@export var prerequisites: Array[StringName]
@export var placement_rules: Array[PlacementRule]
@export var automatic_overlay: StringName
@export var tags: Array[StringName]
```

Create equivalent definitions for `ResourceDefinition`, `ProfessionDefinition`, `OverlayDefinition`, `NotificationDefinition`, and `UIActionDefinition`. Never hard-code build cards or resource chips individually in scenes; instantiate them from these definitions.
### Communication boundaries
Use signals or a typed event bus for coarse events, direct method calls for local component behavior, and query services for snapshots.

```text
Simulation emits:
settlement_snapshot_changed(snapshot)
resource_amount_changed(resource_id, old_value, new_value)
selection_changed(selection_ref)
construction_started(entity_id)
notification_raised(notification_data)
time_scale_changed(scale)

UI submits:
request_set_time_scale(scale)
request_activate_tool(tool_id)
request_place_building(building_id, transform)
request_set_worker_slots(entity_id, count)
request_set_production_priority(entity_id, value)
request_focus_world_position(position)
```

Do not make a universal event bus for every button click. Local button-to-panel wiring remains local. Global services are reserved for cross-system communication.
### UI router
`UIRouter` owns mutually exclusive screens and tool modes:

```gdscript
signal mode_changed(previous: StringName, current: StringName)

var current_mode: StringName = &"normal"
var panel_stack: Array[StringName] = []

func request_mode(next_mode: StringName, payload := {}) -> bool:
    if not _can_enter(next_mode, payload):
        return false
    _exit_mode(current_mode)
    var previous := current_mode
    current_mode = next_mode
    _enter_mode(current_mode, payload)
    mode_changed.emit(previous, current_mode)
    return true
```

Define transitions in one place. No component may set another major panel’s visibility directly. Components request navigation through the router.
## Theme and art direction
### Original identity
Choose a distinctive settlement culture and material language before drawing panels. A strong option for this project is a **Himalayan frontier ledger** aesthetic: dark walnut, hammered iron, muted red textile accents, aged cream paper, carved geometric border motifs, and restrained brass—not generic European fantasy wood. This fits the broader Kathmandu/settlement direction while remaining readable and legally distinct from the reference.

Art rules:

- World view stays dominant; opaque ornament is concentrated at edges.
- Panels use squared or lightly chamfered silhouettes, not web-style rounded cards.
- Borders use nine-slice textures with subtle material variation.
- Important controls use 44–56 px targets at the 1080p baseline.
- Primary body text targets 16–18 px; metadata 14–16 px; headings 20–28 px before user scaling.
- Icons share one stroke weight, perspective, padding grid, and light direction.
- Use short 80–140 ms hover/press transitions; major panels use 140–220 ms slide/fade transitions.
- Never animate constantly changing resource numbers with distracting bounce effects.
- UI sound groups: hover, confirm, cancel, invalid, panel open/close, warning, critical, construction complete.
### Design tokens
Keep all visual constants in one token source and mirror them into the `Theme` resource:

```gdscript
class_name UITokens
extends Resource

@export_group("Spacing")
@export var space_1 := 4
@export var space_2 := 8
@export var space_3 := 12
@export var space_4 := 16
@export var space_5 := 24
@export var space_6 := 32

@export_group("Sizing")
@export var control_height_sm := 32
@export var control_height_md := 40
@export var control_height_lg := 52
@export var icon_sm := 16
@export var icon_md := 24
@export var icon_lg := 32

@export_group("Motion")
@export var motion_fast := 0.10
@export var motion_normal := 0.18
@export var motion_slow := 0.26
```

A project-wide `Theme` can be created and edited through Godot’s Theme editor, which supports live preview and bulk management of theme items. Theme propagation lets a parent control affect descendant controls, which prevents per-component styling drift.[^20][^21]
### Nine-slice construction
Create panel assets as corner-safe nine-slice textures:

- 24–32 px protected corners at 1×.
- Repeatable or stretch-safe center and edges.
- Separate normal, raised, inset, selected, warning, and disabled styles.
- Keep ornaments out of stretch regions.
- Export 1× and 2× PNG or import SVG where appropriate.
- Test at minimum, typical, and maximum panel dimensions.
## Responsiveness and accessibility
### Layout rules
- Top-level HUD regions use anchors; children use containers.
- Never manually reposition a child controlled by a `Container`, because the container will overwrite it on resize.[^21][^12]
- Build cards use a `GridContainer` or flow layout with breakpoint-based columns.
- Long inventories use virtualized or recycled rows if counts become large.
- Every scrollable area has visible scroll feedback and keyboard navigation.
- Ultrawide layouts preserve edge attachment; they do not stretch text lines across the whole screen.
- At 720p, collapse descriptive labels before shrinking icons or essential values.
- Modal windows cap their width and height, with internal scrolling.
### Accessibility settings
Include from the start:

- UI scale: 80%, 90%, 100%, 110%, 125%, 150%.
- Text size modifier independent of ornament scale if feasible.
- High-contrast mode.
- Reduced motion.
- Color-blind palettes for overlays and alerts.
- Toggle or hold behavior for selection tools.
- Edge scrolling toggle and speed.
- Tooltip delay.
- Notification duration.
- Pause-on-critical-event preference.
- Full key rebinding with conflict detection.
- Screen shake and camera motion controls.

Do not remove focus outlines. Godot’s documentation explicitly warns that disabling the focus visual harms keyboard/controller navigation usability. Verify focus neighbors, tab order, escape behavior, initial focus, and focus restoration whenever panels open or close.[^22]
## Input map
Define actions, not keys:

```text
ui_cancel
ui_confirm
camera_pan_left/right/up/down
camera_rotate_left/right
camera_zoom_in/out
camera_focus_settlement
simulation_pause
simulation_speed_1/2/3/4
hud_toggle
build_menu_toggle
management_toggle
resources_toggle
professions_toggle
tool_select
tool_build
tool_road
tool_harvest
tool_clear
tool_zone
tool_terraform
tool_explore
overlay_cycle
overlay_desirability
overlay_fertility
overlay_water
placement_rotate_cw
placement_rotate_ccw
placement_repeat_modifier
placement_precision_modifier
notification_next
```

Physical defaults may resemble familiar city-builder controls, but display the resolved binding dynamically in every tooltip. Godot’s input mapping supports remappable actions and sharing code between keyboard and gamepad inputs.[^10]
## Asset and resource plan
### Recommended sources
| Source | Best use | License/constraint | Recommendation |
|---|---|---|---|
| Godot documentation | Architecture, controls, themes, input, resolution | Official documentation | Primary implementation reference |
| Kenney UI Pack | Prototype controls and neutral placeholders | CC0; 430 files[^23] | Use during gray-box phase; restyle before final identity |
| Game-icons.net | Resource, profession, tool, and alert icon starting points | CC BY 3.0; attribution required[^24][^25] | Curate and redraw into one consistent visual family |
| Godot Asset Library | Plugins, themes, utilities, test tools | Per-asset license | Verify exact engine compatibility and license before adoption[^26] |
| Pixel UI Free | Theme structure and Godot setup reference | CC BY 4.0; compatible with Godot 4.3–4.7[^27] | Useful technical reference, but pixel art is not the target look |
| Fantasy Wood UI Kit | Rapid medieval/fantasy component reference | Commercial asset; verify purchased terms | Optional prototype, not a final identity[^28] |
| GUT | GDScript unit, signal, scene, mock, and CLI testing | Open-source plugin; version must match Godot[^29][^30] | Adopt for view-model, router, formatter, and signal tests |
| Awesome Godot | Curated free/libre tools and templates | Mixed; inspect each project | Use for discovery, not blind dependency installation[^31] |

Maintain `ATTRIBUTION.md` from day one with asset name, author, source URL, version/date, license, modified files, and required credit text. Do not mix icon packs casually; inconsistency in perspective, line weight, padding, and contrast makes a HUD look assembled rather than designed.
### Asset production list
Create the final custom set in this order:

1. Typography pair and numeric style.
2. Color and material tokens.
3. Panel nine-slices: base, raised, inset, selected, warning, modal.
4. Buttons: primary, secondary, icon, tab, destructive, toggle.
5. Core action icons.
6. Core resource icons.
7. Status and alert icons.
8. Cursors: default, select, build valid/invalid, road, harvest, clear, attack, forbidden.
9. Progress fills, separators, badges, and selection frames.
10. UI sounds.
11. Overlay gradients, patterns, legends, and color-blind alternatives.
12. Building thumbnails or renders generated from the actual 3D models for visual consistency.
## Development blocks
### Block 0 — Audit and contract
Deliverables:

- Confirm Godot version and renderer.
- Inventory existing simulation signals, data models, selection, placement, camera, and input code.
- Write `UI_CONTRACT.md` defining snapshots, commands, and ownership.
- Capture baseline screenshots at all target resolutions.
- Create a Git branch and ensure the project opens without parser errors.

Exit criteria: no implementation begins until the UI can obtain settlement, resource, time, selection, and alert data without reaching into arbitrary scene nodes.
### Block 1 — UI foundation
Deliverables:

- `CanvasLayer` and full-rect UI root.
- Theme, tokens, typography, prototype styles.
- Input actions and router.
- Reusable button, stat row, resource chip, status badge, tooltip, and panel shell.
- UI scale setting.

Exit criteria: component gallery scene displays all states at 720p, 1080p, 1440p, 4K, and ultrawide with no clipping.
### Block 2 — Persistent HUD
Deliverables:

- Top HUD.
- Time controls.
- Action dock.
- Event feed and notification stack.
- Mock snapshot provider for development.

Exit criteria: changing mock data updates only affected components, no `_process()` polling is used for ordinary values, and all controls expose shortcuts and tooltips.
### Block 3 — Selection and context
Deliverables:

- Selection service integration.
- Context panel shell.
- Construction, production, villager, storage, and resource panels.
- Camera focus and world highlight.
- World widgets with distance/zoom culling.

Exit criteria: selection changes panels without stale data, deleted entities close safely, and clicking UI never triggers world selection.
### Block 4 — Build loop
Deliverables:

- Data-driven catalog with search, categories, filters, favorites, recent items, locked states, and counts.
- Placement ghost and grid.
- Structured validation messages.
- Rotation, repeat placement, cancel, confirm, and automatic overlays.
- Placement instruction HUD.

Exit criteria: a player can open Build, choose a house, inspect cost and requirements, place validly, understand an invalid location, repeat placement, cancel, and select the resulting site.
### Block 5 — Overlays and management
Deliverables:

- Overlay manager with mutual exclusivity and legends.
- Desirability, fertility, water, logistics, pollution, and service-coverage hooks as supported by simulation data.
- Resources, professions, population, and production windows.

Exit criteria: each overlay answers a named player question, has a legend, works during its relevant placement mode, and can be closed without leaving modified world materials behind.
### Block 6 — Polish and hardening
Deliverables:

- Final custom art and sound.
- Accessibility options.
- Localization and pseudolocalization pass.
- Save/restore of UI settings, pinned resources, last category, and window positions if movable.
- Automated tests, profiling, input conflict review, and clean error log.

Exit criteria: no missing resources, parser warnings promoted by the project, orphan nodes, broken focus paths, clipped localization strings, or repeated critical notifications.
## Verification matrix
### Functional tests
- Every dock action enters exactly one mode.
- `Esc` follows the same back/cancel hierarchy everywhere.
- Right-click cancellation never leaks a world order.
- Tooltips display current bindings after rebinding.
- Disabled actions show a reason.
- Deleting a selected entity cannot leave a dangling reference.
- Reopening a panel restores intentional state, not stale entity data.
- Build search is case-insensitive and supports tags/synonyms.
- Placement reports every blocker and does not charge resources before confirmed success.
- Multi-placement stops cleanly when requirements are no longer met.
- Overlay state is restored after leaving temporary placement overlays.
- Notifications deduplicate and camera-jump correctly.
- UI scale persists across sessions.
- Save/load restores only durable UI preferences, not unsafe transient modes.
### Visual tests
- 1280×720: no essential control clips or overlaps.
- 1920×1080: intended reference composition.
- 2560×1080 and 3440×1440: edge clusters remain anchored; center content remains readable.
- 3840×2160: text and icons remain crisp at 100% and usable at larger scale.
- Long translated strings: buttons grow or wrap intentionally.
- 150% UI scale: modal content scrolls instead of overflowing.
- High contrast: focus, hover, selected, disabled, warning, and critical remain distinguishable.
- Color-blind simulation: overlays remain distinguishable by pattern, value, or labels.
### Automated tests
Use GUT for:

- Number and duration formatting.
- Resource trend calculations.
- Router transition validity.
- Notification grouping and throttling.
- Search/filter results.
- Placement result-to-message mapping.
- Snapshot-to-view-model conversion.
- Signals emitted by worker, recipe, priority, and time controls.
- Scene-tree smoke tests for required named nodes.

GUT supports GDScript tests, mocks, spies, parameterized tests, CLI execution, and JUnit XML output, making it suitable for local and CI checks.[^29][^30]
## Error-prevention rules
The implementation agent must obey these constraints:

- Do not invent simulation APIs. Inspect existing scripts and cite the exact class, method, signal, and path before integration.
- Do not rename or delete existing project files unless explicitly required and documented.
- Do not hard-code `NodePath` strings across unrelated systems; use exported references, groups, service registration, or stable interfaces.
- Do not use `_process()` to poll values that can be updated through signals.
- Do not let UI code mutate simulation data directly.
- Do not use absolute positioning inside complex panels; use containers and minimum sizes.
- Do not mix anchors with container-controlled child positioning incorrectly.
- Do not make decorative controls intercept world input; set `mouse_filter = IGNORE` where appropriate.
- Do not call `get_node()` repeatedly in per-frame code.
- Do not create one monolithic `game_ui.gd`; keep components focused.
- Do not connect the same signal multiple times when reopening panels.
- Do not keep strong references to entities that may be freed; validate with `is_instance_valid()` or use IDs resolved by a service.
- Do not load final art before the gray-box loop is validated.
- Do not add a plugin without checking Godot compatibility, maintenance status, license, and whether equivalent native functionality is sufficient.
- Do not claim completion while the Godot debugger contains parser errors, invalid calls, missing resources, orphan warnings, or recurring input errors.
- Do not copy *Farthest Frontier* textures, icons, names, sounds, exact compositions, or proprietary assets.
## Copy-ready master prompt
```text
You are the lead Godot UI engineer and strategy-game UX implementer for an original 3D medieval/Himalayan settlement simulator. The interface may study the information architecture of games such as Farthest Frontier, but it must not copy any proprietary texture, icon, wording, sound, distinctive panel shape, or pixel-identical layout. Build an original, game-native HUD/UI, not a web dashboard.

PRIMARY GOAL
Create a production-ready desktop HUD/UI in Godot 4.6.3 stable using GDScript. Target mouse and keyboard first, a 1920×1080 design reference, and reliable layouts from 1280×720 to 3840×2160, including 21:9. Preserve the world view, keep critical settlement information glanceable, and reveal deeper information progressively.

BEFORE WRITING CODE
1. Inspect the current project tree, project.godot, autoloads, input actions, simulation systems, selection system, placement system, camera controller, data resources, themes, and existing UI scenes.
2. Produce an audit listing exact file paths, classes, signals, callable methods, and data models that the UI can safely use.
3. Identify missing APIs. Do not invent method or signal names and do not assume a system exists.
4. Propose the smallest adapter or read-only snapshot API for any missing integration.
5. List files to create, files to modify, risks, and acceptance tests.
6. Stop for approval if implementation would delete, rename, replace, or broadly refactor existing systems.

ARCHITECTURE
- Put screen UI under a CanvasLayer and a full-rect Control root.
- Use anchors for top-level edge regions and nested Containers for internal layout.
- Use one project Theme and centralized UI tokens for colors, type, spacing, sizes, style boxes, and motion.
- Build reusable scenes for icon buttons, stat rows, resource chips, status badges, alerts, tooltips, building cards, progress meters, tabs, and panel shells.
- Use typed custom Resource classes for building, resource, profession, overlay, notification, and UI-action definitions.
- Generate lists and cards from data; do not hand-author duplicate nodes for each resource or building.
- The simulation remains authoritative. UI observes snapshots/view models and submits typed commands; UI must not modify simulation internals directly.
- Use local signals for component behavior and a limited typed event/service layer for cross-system communication.
- Use one UIRouter to own major panels, modal screens, and mutually exclusive world-tool modes.

REQUIRED SCREEN STRUCTURE
1. Top HUD: settlement condition on the left, season/calendar/weather in the center, pinned resources on the right.
2. Bottom-left time controls: pause and simulation speeds with clear active state.
3. Bottom-right action dock: select, build, road, harvest, clear, zone, terraform if supported, explore, overlays, and management.
4. Event feed and severity-based notification stack with camera-jump actions.
5. Context panel host for construction sites, production buildings, storage, residences, villagers, resource nodes, farms, and military entities.
6. Build catalog with categories, search, favorites, recent items, locked states, prerequisites, footprint, costs, upkeep, worker slots, and count already built.
7. Placement HUD with cost, rotation, confirm/cancel, repeat modifier, automatic relevant overlay, local modifiers, and exact invalid-placement reasons.
8. Overlay manager and legend for supported spatial systems such as desirability, fertility, water, logistics, pollution, and service coverage.
9. Full management windows for population, professions, resources/storage, production, reports, and settings.
10. Custom tooltips that show purpose, current value, trend, threshold, cause, click behavior, and resolved shortcut where relevant.

MODE STATE MACHINE
Implement explicit modes: NORMAL, BUILD_CATALOG, PLACING_BUILDING, DRAWING_ROAD, MARKING_HARVEST, MARKING_CLEAR, PLACING_ZONE, TERRAFORMING, PLACING_EXPLORE_MARKER, COMMANDING_UNITS, and MODAL_WINDOW. Only one world tool may be active. All transitions must pass through UIRouter. Esc cancels the current operation, then closes the current panel, then opens the pause menu. Right-click steps back or cancels safely. Exiting a mode must remove previews, temporary overlays, cursors, input locks, and instructional HUD.

BUILD FLOW
Open catalog -> filter/search -> inspect building card -> select definition -> enter placement -> show ghost/grid/cost -> validate continuously -> show structured blockers and warnings -> rotate -> confirm if valid -> optionally repeat while modifier is held -> return cleanly to catalog or normal mode. Placement validation must return structured data including validity, reason key, blocking cells, warnings, cost state, and local modifiers. Never charge resources before the simulation confirms placement.

VISUAL DIRECTION
Use an original Himalayan frontier ledger style: dark walnut, hammered iron, aged cream paper, muted red woven accents, restrained brass, and subtle carved geometric borders. Use squared or lightly chamfered panels, nine-slice textures, consistent icon geometry, restrained shadows, and short responsive transitions. Avoid glassmorphism, large rounded web cards, excessive pills, giant margins, browser sidebars, neon accents, and ornamental clutter over the world.

ACCESSIBILITY AND RESPONSIVENESS
- UI scale options: 80%, 90%, 100%, 110%, 125%, 150%.
- High contrast, reduced motion, color-blind overlay palettes, tooltip delay, notification duration, camera motion settings, and full key rebinding.
- Do not rely on color alone.
- Preserve visible keyboard focus; define focus neighbors and restore focus when panels close.
- Use localization keys for all player-facing text and test pseudolocalized long strings.
- At small resolutions, collapse secondary labels before shrinking essential values.
- Clamp tooltips and windows to the viewport; scroll internal content instead of clipping.

INPUT
Use named InputMap actions only. Never hard-code gameplay keys in component scripts. Tooltips must display the current resolved binding and update after rebinding. UI controls must consume handled events so clicks do not leak into world selection or orders. Decorative controls must ignore mouse input.

PERFORMANCE
- Update ordinary UI through signals or snapshot changes, not per-frame polling.
- Throttle high-frequency values and animate displayed values without modifying authoritative data.
- Pool or recycle world widgets and large list rows where useful.
- Cull world widgets by camera distance, zoom, visibility, and importance.
- Avoid repeated get_node calls and avoid rebuilding entire panels for one changed value.

ERROR HANDLING
- Validate exported references in _ready and fail with actionable messages.
- Guard freed entities and asynchronous callbacks.
- Prevent duplicate signal connections.
- Gracefully handle missing icons, missing localization keys, empty data, locked content, insufficient resources, and unavailable simulation systems.
- Do not hide errors with broad null checks; fix ownership and lifecycle problems.
- Keep the Godot debugger free of parser errors, invalid calls, missing resources, orphan nodes, and repeated warnings.

IMPLEMENTATION METHOD
Work in small blocks. For each block:
1. State the objective and touched files.
2. Implement only that block.
3. Run parser/startup checks and relevant automated tests.
4. Test at 1280×720, 1920×1080, 2560×1080, and 3840×2160.
5. Report changed files, decisions, unresolved risks, and exact manual test steps.
6. Do not proceed to the next block until acceptance criteria pass.

BLOCK ORDER
Block 0: project audit and UI/simulation contract.
Block 1: CanvasLayer, theme/tokens, router, input actions, component gallery.
Block 2: top HUD, time controls, action dock, events, notifications.
Block 3: selection integration, context panels, world widgets.
Block 4: build catalog and complete building placement loop.
Block 5: overlays and management windows.
Block 6: final custom art, audio, accessibility, localization, save/restore, optimization, and regression tests.

TESTING
Use GUT when compatible with the installed Godot version. Add unit tests for formatting, trends, router transitions, notification grouping, search/filtering, placement-message mapping, snapshot/view-model conversion, and emitted commands. Add scene smoke tests for required nodes. Create a manual matrix covering all target resolutions, UI scales, input rebinding, long localized strings, deleted selections, rapid mode switching, save/load, empty states, and insufficient-resource states.

DEFINITION OF DONE
A feature is complete only when it is data-driven, themed, keyboard accessible, responsive, localized, integrated through existing verified APIs, covered by relevant tests, manually verified at target resolutions, documented, and produces no debugger errors or input leaks. A screenshot alone is not completion.

START NOW WITH BLOCK 0 ONLY. Return the audit, proposed architecture map, exact files to create/modify, dependency and license risks, and acceptance checklist. Do not implement later blocks until Block 0 is approved.
```
## Reviewer prompt
Use a separate review pass after each implementation block:

```text
Act as a strict senior Godot 4.6 UI reviewer. Do not redesign or implement immediately. Inspect the changed files, scene trees, signals, input handling, theme usage, containers/anchors, lifecycle behavior, performance, accessibility, localization, and tests.

Compare the result against the approved block contract and acceptance criteria. Find concrete defects: invented APIs, direct simulation mutation, duplicate signal connections, stale entity references, input leakage, incompatible active modes, absolute-position layout fragility, clipping at target resolutions, missing focus paths, hard-coded text or keys, per-frame polling, missing empty/error states, inconsistent theme overrides, plugin/license risk, and debugger warnings.

Return:
1. PASS or FAIL.
2. Critical defects that block approval.
3. Major defects that should be fixed in this block.
4. Minor polish items that may wait.
5. Exact file path and node/function for each defect.
6. Reproduction steps.
7. Smallest safe correction.
8. Regression tests to add.
9. A final approval checklist.

Do not approve based on screenshots. Require a runnable project, clean debugger, target-resolution checks, and completed tests. Do not expand scope beyond the current block unless a foundational defect makes later work unsafe.
```
## Immediate starting milestone
The first playable UI milestone should be intentionally narrow:

- Persistent top HUD fed by a mock settlement snapshot.
- Pause and four time speeds.
- Action dock with Build active.
- Build catalog containing House, Storehouse, Well, Road, and Gatherer as data resources.
- One complete House flow: open catalog, read cost, preview footprint, see valid/invalid feedback, rotate, place, repeat with modifier, cancel, then select the construction site.
- Context panel showing progress, required materials, assigned builders, prioritize, pause, and cancel.
- One automatic placement overlay and one critical notification.

This vertical slice validates the architecture, visual language, input routing, simulation contract, and most failure-prone interaction boundaries before expanding into every management screen. It also follows the proven reference loop of opening the build menu, previewing a grid-aligned structure, rotating it, placing it, and managing the selected result.[^4]
## Final recommendation
Treat the HUD as a set of **player decisions**, not a collection of panels. Persistent elements should answer immediate settlement questions; contextual panels should expose controls for the selected object; overlays should explain the map; management windows should support analysis. Implement the gray-box vertical slice first, approve its interaction quality, then replace placeholders with an original Himalayan frontier theme and a consistently authored icon set.

---

## References

1. [Guide – About – Basics - Farthest Frontier](https://www.farthestfrontier.com/guide/about/basics/) - Bottom-Right HUD. The bottom of the screen offers an array of useful menus and controls. Note that t...

2. [Godot download archive](https://godotengine.org/download/archive/) - Download any officially published version of Godot for Linux, macOS, Windows, or Android. Godot 4.6 ...

3. [Maintenance release: Godot 4.6.3](https://godotengine.org/article/maintenance-release-godot-4-6-3/) - The stability has tripled! 4.6 maintenance releases remains ever-present. Download Godot 4.6.3 now o...

4. [Buildings - Guide – Gameplay - Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/buildings/) - Welcome to the Farthest Frontier, a Town Builder from Crate Entertainment!

5. [Guide – Information – Overlays - Farthest Frontier](https://www.farthestfrontier.com/guide/information/overlays/) - The Desirability overlay (default hotkey: G) shows the most desirable areas ... The Irrigation overl...

6. [steamcommunity.com · app · 1044720UI Scaling and Icon size :: Farthest Frontier General Discussions](https://steamcommunity.com/app/1044720/discussions/0/4362374970375379899/) - I would like to request the above please. I have old eyes and can barely make out the UI information...

7. [github.com · sagedragoon79 · KeepClarityA UI Enhancement for Farthest Frontier - GitHub](https://github.com/sagedragoon79/KeepClarity) - A UI Enhancement for Farthest Frontier A comprehensive quality-of-life mod that adds context-aware h...

8. [docs.godotengine.org › en › stableInput examples — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html) - Introduction: In this tutorial, you'll learn how to use Godot's InputEvent system to capture player ...

9. [InputMap — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) - Inherits: Object A singleton that manages all InputEventAction s. Description: Manages all InputEven...

10. [List of features - Godot Docs](https://docs.godotengine.org/en/stable/about/list_of_features.html) - This page aims to list all features currently supported by Godot. Platforms: Can run both the editor...

11. [Size and anchors - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html) - ... anchor values, you can use the toolbar's Anchor menu, above the viewport. Besides centering, it ...

12. [Using Containers - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) - Anchors are an efficient way. When a Container-derived node is used, all children Control nodes give...

13. [Default & Hidden Controls - Farthest Frontier Wiki](https://farthestfrontier.wiki/wiki/Default_&_Hidden_Controls) - Below is a list of all documented controls in the game as of version 0.8.1. Move Camera Forward S Mo...

14. [Guide – Gameplay – Farming – Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/) - Welcome to the Farthest Frontier, a Town Builder from Crate Entertainment!

15. [Using InputEvent — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) - What is it?: Managing input is usually complex, no matter the OS or platform. To ease this a little,...

16. [Control — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/classes/class_control.html?highlight=get_global_rect) - Inherits: CanvasItem< Node< Object Inherited By: BaseButton, ColorRect, Container, GraphEdit, ItemLi...

17. [Canvas layers - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html) - CanvasLayer, which is a node that adds a separate 2D rendering layer. This allows the UI to be fixed...

18. [User interface (UI) - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) - In this section of the tutorial, we explain the basics of creating a graphical user interface (GUI) ...

19. [Resources — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) - To make the new resource class appear in the Create Resource GUI you need to provide a class name fo...

20. [Using the theme editor - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_theme_editor.html) - This article explains how to create and manage UI themes using the Godot editor and its theme editor...

21. [Control — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/classes/class_control.html) - To build flexible UIs, you'll need a mix of UI elements that inherit from Control and Container node...

22. [TextEdit — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/classes/class_textedit.html) - If true , allow drag and drop of selected text. Text can still be dropped from other sources. contro...

23. [UI Pack - Kenney](https://kenney.nl/assets/ui-pack) - The game assets you're about to download are available for free, thanks to the generosity of our ama...

24. [Game-icons.net: 4180 free SVG and PNG icons for your games or ...](https://game-icons.net/) - free SVG and PNG icons for your games or apps. An ever growing collection of free game icons … image...

25. [F.A.Q.](https://game-icons.net/faq.html) - Game-icons.net. They are provided under the CC-BY license … you can use them freely in your projects...

26. [Godot Asset Library](https://godotengine.org/asset-library/) - Scalable Vector Shapes 2D - Draw and Animate Curves · PSD to Godot Scene Importer · Blendot - Edit G...

27. [Pixel UI Free - Godot Asset Library](https://godotengine.org/asset-library/asset/5494) - **A free pixel-art GUI theme for Godot 4.** Set it in Project Settings and every Button, slider, tab...

28. [Fantasy Wood — Game UI Kit (Godot 4 + Unity) - DRStudios](https://deerrockstudios.itch.io/fantasy-wood) - Fantasy Wood — Game UI Kit (Godot 4 + Unity). A downloadable asset pack. Get this asset pack and 8 m...

29. [github.com · bitwes · GutGitHub - bitwes/Gut: Godot Unit Test. Unit testing tool for ...](https://github.com/bitwes/Gut) - GUT (Godot Unit Test) is a unit testing framework for the Godot Engine. It allows you to write tests...

30. [store.godotengine.org · asset · bitwesGUT - Godot Asset Store](https://store.godotengine.org/asset/bitwes/gut/) - Easily execute a single test, inner class, full script, or the entire suite with context sensitive b...

31. [Calinou/awesome-godot: A curated list of free/libre plugins, scripts ...](https://github.com/calinou/awesome-godot) - Godot Asset Library - Official Godot Asset Library. Includes user-created games, projects, templates...

