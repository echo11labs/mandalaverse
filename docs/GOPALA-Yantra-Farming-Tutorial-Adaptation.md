# GOPALA — Yantra

## Farming Tutorial Adaptation

Prepared 29 September 2026. Companion to [Development Vedas](GOPALA-2D-Development-Vedas.md) and [Implementation Backlog](GOPALA-Implementation-Backlog.md).

Basis: the user-supplied transcript of Rapid Vectors' [complete Godot 4.3 farming tutorial](https://www.youtube.com/watch?v=it0lsREGdmc). The chapter mapping uses the previously inspected chapter list; implementation observations use selected transcript sections, including components, animal movement, crops, saving, scene integration, and audio. This is a targeted review, not a claim to have audited every script in the finished tutorial project.

**Use its component-building workflow to accelerate individual systems. Build GOPALA's settlement economy around authoritative jobs, inventories, and simulation time.** No game code or plugin installation is included in this document update.

## 1. What changes when the player manages a settlement

The tutorial's interaction model centers on a player character using tools, collecting items, tending crops, and talking to a guide. GOPALA's player places structures and zones, assigns workers, and sets priorities. Villagers execute the individual actions.

| Tutorial behavior | GOPALA equivalent |
|---|---|
| Keyboard-controlled player | Pan/zoom camera and settlement commands |
| Selected chopping/watering tool | An assigned gathering/farming task with requirements |
| Hit/hurt component triggers an action | Validated work performed at a reachable task location |
| Nearby collectible enters player inventory | Worker collects a reserved amount and physically delivers it |
| Animal wanders toward random targets | Animal stays within assigned pasture; tending and herd support govern production |
| Crop responds to watering/day signals | Crop advances from simulated time, moisture, season, and required work |
| Dialogue enables a toolbar | Scenario requirements unlock structures and zones |
| Chest exchanges player inventory for a reward | Limited barter or a herd-feeding delivery using real inventory transactions |
| Node-based save reconstructs scene objects | A versioned world snapshot reconstructs simulation records and then views |

The tutorial is a useful subsystem reference. It does not supply a complete settlement dispatcher, physical supply network, or safe reservation system.

## 2. Map the 25 episodes to the roadmap

Times identify chapter starts and may precede the relevant spoken introduction by a few seconds.

| Episode | Start | Topic | Application |
|---|---|---|---|
| 1 | 01:35 | Setup and assets | M0: organize approved assets and naming |
| 2 | 05:50 | TileMapLayer | M0: layered terrain and a tiny test map |
| 3 | 21:08 | Player state machine | M1: worker execution states |
| 4 | 53:47 | Tool states | M1/M3: task-driven work animations |
| 5 | 1:06:18 | House styles | M0/M4: building views and variations |
| 6 | 1:31:12 | Choppable trees | M1: gatherable timber sources |
| 7 | 1:56:10 | Tree shake shader | M4: optional visual feedback |
| 8 | 2:04:06 | Mineable rocks | M1: gatherable stone sources |
| 9 | 2:16:13 | Y-sorting | M0: ground anchors and overlap tests |
| 10 | 2:26:42 | Chicken NPC | M1: learn reusable animal movement; chicken content deferred |
| 11 | 3:02:13 | Cow NPC | M1/M2: cattle views and shared behavior |
| 12 | 3:09:10 | Navigation and avoidance | Navigation concepts; retain GOPALA's grid routing |
| 13 | 3:19:25 | Tools panel | M0/M1: structure and zone controls |
| 14 | 3:45:27 | Collectibles | M1: pickup/delivery presentation |
| 15 | 3:55:59 | Inventory panel | M1: local stock, available stock, and reservations |
| 16 | 4:15:19 | Day/night | M2/M4: time-linked daylight and UI |
| 17 | 4:46:27 | Crops | M3: reusable growth-state views |
| 18 | 5:16:25 | Tilling and dynamic tiles | M3: worker-prepared field zones |
| 19 | 5:37:08 | Save data | M1 onward: learn serialization; use world snapshots |
| 20 | 6:01:55 | Guide interaction | M4: lightweight onboarding guidance |
| 21 | 6:19:47 | Dialogue balloons | Optional presentation after objectives function |
| 22 | 6:53:21 | Interactive chest | M3: exchange/feeding concepts with atomic transfers |
| 23 | 7:23:44 | First assembled level | Integration practice throughout all milestones |
| 24 | 7:43:53 | Main menu | M4: new/load/pause/settings flow |
| 25 | 8:15:08 | Audio and buses | M4: music, ambience, UI, and work sound |

Watch or revisit a lesson when its milestone needs it. Integrate an exported playable increment after each system; do not postpone the first combined settlement until all tutorial episodes have been reproduced.

## 3. Worker AI: separate task choice from execution

A dispatcher chooses an eligible task using need urgency, profession, priority, source stock, destination capacity, and route access. A small state machine executes the chosen task:

**Idle → reserve → travel to source → collect → travel to destination → deliver → work → finish.**

Not every task requires every state. A tending task may travel directly to its work cell; construction may depend on separate delivery jobs. Needs interruptions are explicit transitions, with carried goods and reservations handled before another assignment begins.

The tutorial's enter/exit and transition concepts are useful. Its keyboard checks become task/path conditions. Work animations follow simulation progress. An animation finishing cannot independently produce resources, finish a structure, or advance a field twice.

Start with a compact shared implementation rather than dozens of behavior nodes per villager. Extend only when distinct behavior requires it.

## 4. Gathering and inventories

Define a gatherable source with ID, logical location, remaining quantity, resource type, required work, and any recovery rule. A worker reserves quantity, reaches a work cell, performs work, and moves the resulting material into its carried inventory. Delivery transfers that inventory to storage.

Keep resource accounting separate from collectible visuals. A basket or bundle shows carried goods; it is not the only record that those goods exist. Do not instantiate a separate economic entity for every grain or timber unit merely to imitate a collection animation.

The inventory panel must distinguish total, reserved, available, carried, and destination capacity. The central inventory service owns changes. A button, dialogue event, or effect cannot also subtract the same item after the simulation has already transferred it.

## 5. Cattle: movement is only the first layer

The animal lessons establish animated NPCs and movement variation. GOPALA adds assigned pasture, grass/fodder availability, water, tending labor, and milk production conditions.

Choose reachable destinations within a pasture. Visual roaming never causes milk output by itself. The herd system evaluates support using simulation time; the dairy/collection task moves produced milk through the inventory system. Lack of water, fodder, or a worker gives a visible operating reason.

Keep the roadmap's AStarGrid2D approach. Do not add a second navigation system just to reuse an NPC scene. Navigation agents and avoidance remain alternatives for a later evaluated design change.

## 6. Crops and dynamic terrain

Model a field's logical cells separately from their TileMapLayer appearance. Worker tasks prepare, plant, tend, and harvest. Each crop definition provides work requirements, phase thresholds, seasonal suitability, moisture response, yield, and harvested resource ID.

Growth uses elapsed simulation time. Day/night color is a visual result of that clock, not the authority for crop maturity. Pause and speed controls affect crops and workers consistently. Harvest consumes a mature state once and produces one transaction; repeated UI signals cannot repeat the yield.

The tutorial's corn and tomato demonstrate reusable crop implementation. GOPALA retains generic cereal and fodder placeholders until its period-specific research selects final species. Do not copy the tutorial's crop list into the historical setting automatically.

The initial economy does not add a new seed inventory just to reproduce the guide's seed-giving sequence. Treat planting as the field recipe's configured action until a seed resource creates a useful, balanced decision.

## 7. Save/load and scene integration

The transcript's save lesson stores Resource data associated with nodes, positions, paths, and parent paths. Its later menu integration also exposes scene naming, load timing, and duplicate-scene issues. These are useful examples of why integration must be tested early.

For GOPALA, stable entity IDs and simulation records are the save authority. Save inventories, carried goods, tasks/reservations, construction, field growth, herd support, needs, clock, random state, and objectives. Rebuild views and paths after loading valid state.

Use an explicit load sequence: validate snapshot → create simulation records → resolve ID references → rebuild occupancy/routes → create views → connect UI → resume. A typed initialization step should establish readiness; relying on a guessed child index or an arbitrary frame wait is fragile.

Content definition Resources remain shared and immutable. Runtime state is per entity. Keep the roadmap's JSON snapshot format and versioning instead of maintaining two competing save authorities.

## 8. Keep settings aligned with GOPALA's art contract

The transcript uses Forward+, a 640×360 pixel-art viewport, nearest filtering, and integer scaling. Those choices serve that tutorial's presentation. GOPALA currently proposes Compatibility and illustrated isometric sprites.

Use [Kala's style test](GOPALA-Kala-2D-Art-Direction.md) to choose resolution, texture filtering, and zoom limits. Pixel-art learning scenes may use different settings in a separate practice project. Do not apply the tutorial's visual configuration blindly to the production assets.

Keep source control and milestone exports. Shared definitions, test scenes, and consistent naming are useful even though the tutorial's initial setup leaves source control optional.

## 9. UI, dialogue, and audio

Adapt the tool panel into build/zone selection, and the inventory panel into inspectable settlement storage. Scenario conditions govern unlocks. A guide can explain an objective, but essential production must not depend on a player locating an NPC or repeatedly dismissing dialogue.

Use separate controls for music, ambience, sound effects, and UI audio. Randomize animal-call timing and limit simultaneous voices; a large herd should not trigger synchronized calls on identical timers. Sound is presentation and does not advance production.

The transcript refers to externally sourced art, UI, fonts, music, scripts, and dialogue tooling. The existing asset-eligibility rules still apply. No new plugin is required for the first functioning settlement, and no tutorial dependency has been installed by this update.

## 10. Small test scenes to build in dependency order

| Test scene | Required proof |
|---|---|
| Grid and selection | Picking/placement stays aligned across zoom and transforms |
| Inventory and reservations | Two workers cannot claim the same last unit or overfill storage |
| Haul and construction | Materials physically arrive before completion; blocked routes recover |
| Needs and households | Food/water consumption is accounted for and shortages are explained |
| Herd and pasture | Unsupported cattle lose output; feed/water/tending restore it |
| Field and processing | Growth and recipes advance by simulated time; harvest is issued once |
| Save round trip | Mid-haul, mid-build, and mid-growth state survives loading |
| Full settlement | All systems run together for the P0 acceptance session |

The highest-value sequence remains: **map → inventory → task reservations → hauling → construction → needs → cattle → fields and processing → scenario presentation.** Follow the project's dependencies rather than the tutorial's viewing order.
