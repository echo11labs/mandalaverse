# GOPALA — Game Design Contract

Status: **Block 2 design decisions locked; implementation not started.**

Date: 3 October 2026. Locked baseline: `7547aa843c7834a7963e5396e627c39870f0a7d9` (`feat(simulation): add deterministic settlement spine`).

Scope: product/gameplay authority and dependency roadmap. This is a documentation-only deliverable; it authorizes no gameplay, scene, script, InputMap, autoload, or asset edits.

This contract records approved product intent and target behavior, not a claim that those features exist. Current capabilities and gaps are described explicitly. For HUD-specific implementation details, [UI_CONTRACT.md](UI_CONTRACT.md) remains the subordinate interface specification; its block table is a HUD sub-roadmap, not the whole game's dependency order. The historical and implementation documents cited below remain unchanged unless a later task explicitly authorizes edits.

## 1. Product statement

GOPALA is a historically inspired Himalayan settlement survival simulator set in Kathmandu Valley–inspired geography. The player establishes and sustains one settlement through materially conserved gathering, transport, construction, work, and care. It is an original game and interface, not a recreation of another game's identity, text, layouts, or art.

The existing 3D geographic scene is the presentation foundation. Game systems described here are future acceptance targets; the current landscape and simulation spine do not yet implement the settlement loop.

## 2. Player fantasy

The player is the founder and chief of one settlement: choosing where to build, organizing villagers and shared work, and keeping the community supplied as it grows. Agency comes from understandable priorities and physical consequences, not from direct avatar control or abstract stock totals detached from the world.

The first playable focuses on one community and its local survival. A regional view may supply geographic context, but its overlays do not confer ownership or authorize expansion by conquest.

## 3. Historical-fiction boundary

Player-facing historical material must identify which statements are **documented evidence**, **traditional account**, or **gameplay reconstruction/fiction**. Proposed period, buildings, crops, labor practices, names, and dates are not established historical facts merely because they appear in the game. A period-specific claim requires review against identified sources; uncertainty is stated rather than hidden.

Existing inferred chiefdom/frontier overlays are informational geography only in the first playable. They must not cause territorial ownership, conquest, borders-as-fact claims, or simulated historical control. The amber inferred headwater already depicted in the landscape must remain distinguishable from mapped waterways. A specific settlement date and historical interpretation remain subject to review; neither is locked here.

## 4. Core loop

**Gather → haul → store → build → assign → produce → satisfy needs → expand.**

Each transition is supported by authoritative simulation state and visible feedback. Gathering has a valid source and quantity; hauling moves actual integer units; storage has capacity; construction consumes delivered materials and labor; production consumes inputs or source capacity; needs consume valid supplies. Expansion follows the same rules rather than creating free resources.

## 5. First playable milestone

The first playable is a real integrated, running game—not a test-only simulation, gallery, or UI demonstration. A player must be able to:

1. Start from one camp.
2. Inspect individual villagers and their actual state.
3. Gather wood, stone, and food from valid sources.
4. See villagers physically carry resources.
5. Store carried resources in valid storage.
6. Place a road, house, storehouse, and well.
7. Receive terrain, footprint, access, and occupancy validation before committing placement.
8. Reserve and deliver the required construction materials without duplicate claims.
9. Assign workers to relevant jobs.
10. See construction advance through visible labor stages to completion.
11. Meet food, water, and shelter needs over several game days.
12. Understand and recover from a shortage using an identified action.
13. Save while tasks are active.
14. Reload and continue without duplicated or lost resources, invalid entity references, or corrupted task/build state.

Required first-playable content comprises the starting camp, house, storehouse/stockpile, well/water point, wood-gathering source/workplace, stone-gathering source/workplace, food-gathering source/workplace, and road. The starting camp and other visible objects must be connected to authoritative gameplay records. Acceptance requires performing the sequence in the playable build; passing unit tests or displaying controls alone is insufficient.

## 6. Player actions

The first-playable command surface includes inspecting individual villagers and relevant buildings/sources; selecting gathering, construction, and production work; assigning workers; choosing and rotating building blueprints; placing roads and required structures; viewing why an action is invalid or blocked; pausing/changing simulation speed; saving and loading; and acting on actionable shortage feedback.

Commands request state changes through typed authoritative services. A visual preview is not a committed order. The UI reports accepted, rejected, unsupported, and completed outcomes from the simulation rather than predicting success as fact.

## 7. Simulation rules

The simulation owns gameplay state and advances on a fixed authoritative tick, independent of rendering cadence. Commands have deterministic ordering and explicit results. Integer resource quantities, stable identities, validated transitions, and recoverable task state are required. State-changing operations must be atomic where a partial transfer could duplicate or lose stock.

Determinism means identical starting state, ordered commands, and logical ticks yield logically equivalent outcomes. Cross-hardware bit-identical replay is not required. Randomness that affects gameplay must be owned and persisted by simulation state once introduced; rendering, camera motion, frame rate, and UI polling cannot change outcomes.

The current [SettlementSimulation](../game/core/simulation/settlement_simulation.gd) is a foundation for clock, FIFO commands, empty ledger, ID allocation, and defensive snapshots. It has no population, inventory locations, jobs, needs, gathering, production, construction lifecycle, or persistence. Its current public `apply_authorized_transaction(delta)` is not an acceptable gameplay mint/spend API: validated, typed, ownership-checked transaction services and their callers must be designed before live economy use.

## 8. Entity ownership

A settlement session owns the authoritative registry and records for villagers, households, buildings, sources, roads, construction sites, tasks, and inventories. Scene nodes and UI components are presentation/adapters; they must not be the durable source of economic truth. Scene-scoped simulation ownership is consistent with the current Kathmandu scene's child simulation instance, not a global simulation autoload.

Entities use stable IDs. References between records resolve through the registry and validate liveness; removing an entity clears or safely resolves dependent assignments, tasks, selection, and UI views. Snapshots/commands crossing service boundaries contain plain data and IDs, not retained scene-node references. Settlement totals are computed from the owned records, not independently editable counters.

## 9. Spatial model

Three coordinate concerns remain distinct:

1. **Regional space:** existing terrain and geography, measured as a 40 × 40 km scene centered near Kathmandu; at 100 m per Godot world unit, the sampled square spans 400 world units (±200 units per horizontal axis). The existing terrain model also provides a camp-centered 48 × 48 inspection/planning grid with 0.2 world-unit cells (20 m each), about 960 m square. This grid is for regional inspection/geography, not construction.
2. **Settlement space:** a separate, configurable 2 m gameplay grid for building footprints, roads, occupancy, access, and navigation. At the current geographic scale, a nominal 2 m cell is 0.02 world units. Building rotation is restricted to 90-degree increments.
3. **Conversion service:** provide the named operations `world_to_settlement_cell`, `settlement_cell_to_world`, and `regional_cell_from_world`. Define the origin, axis orientation, cell-center convention, bounds, and rounding once; use the same implementation in placement, navigation, inspection, and saving. Validate in-bounds behavior, negative coordinates, rotation, and cell-center round trips.

The conversion contract must not silently alias the coarse regional inspection cells to settlement cells. Terrain modification, bridges, walls, free rotation, and multi-level structures are outside the first playable.

## 10. Resource conservation

Initial gameplay candidates are integer quantities of **timber, stone, food, water, and thatch**. The existing catalog's `wild_food` may provide a concrete food definition; final naming/definition mapping is a content decision. Fodder and milk are deferred unless cattle are explicitly admitted to this first milestone.

Every unit has exactly one authoritative location/state: world source, building inventory, construction site, carrier load, or a recorded consumed/removed transaction. A transfer changes source and destination atomically. Production can add units only through a validated source-yield or recipe transaction; consumption/removal must be recorded with its cause. Reservations identify owner, quantity, source/destination, and lifecycle; reserved stock remains accounted for and cannot be claimed twice. Cancellation, worker failure, destruction, save/load, and recovery must preserve the same accounting invariant.

Settlement-wide cached totals are derived from physical records and may be rebuilt. No UI, arbitrary caller, animation, or unvalidated command may mint/remove stock or override reservations. Storage/carry limits and overflow behavior must be explicit before balances are approved. The current empty catalog-keyed delta ledger is only a working foundation, not a complete or secure economy.

## 11. Construction lifecycle

Construction follows **Blueprint → validation → resource reservation → hauling → labor stages → completion**. Blueprint display and previews are non-authoritative. Validation checks regional bounds, terrain/slope and water constraints selected for the settlement grid, every footprint cell, access/entrance, existing and reserved occupancy, and any required route. Material costs are reserved once, hauled as physical loads, delivered to the site, and consumed only under the site's authoritative work/completion rules. A building cannot operate before completion.

Cancellation/failure must specify and test all of the following: release occupied/reserved cells; release uncollected resource reservations; recover, return, or explicitly account for already delivered material without loss or duplication; cancel/reassign worker tasks; remove or tombstone transient site/task IDs and dependent references; and return a localized, inspectable UI result. Instant construction is allowed only in explicit test/debug fixtures and is not first-playable behavior.

## 12. Villager model

Every villager record must contain:

- Stable entity ID.
- Household ID.
- Home ID or explicit homeless state.
- Job assignment.
- Current task.
- World and settlement-grid position.
- Health, hunger, and thirst.
- Carry inventory.
- Movement/path state.

Household and settlement-wide statistics are derived from individual records. Assignment, movement, carrying, task interruption, and task recovery must keep those records consistent. Names, demographics, starting population, and household distribution remain balance/content decisions, not factual historical claims.

## 13. Needs and failure

First-playable needs are food, water, shelter, and basic health consequences. A shortage message must identify its cause, current severity, recoverable action, and a grace period when one is appropriate. The player can inspect affected villagers and take a practical response; failure may not be an unexplained global counter or instant hidden punishment.

Need rates, thresholds, grace durations, health effects, and recoveries are tunable values, listed as unresolved balance decisions in §22. No warfare, raids, religion, advanced happiness, clothing, education, taxes, or dynasty politics belongs to the first-playable acceptance scope.

## 14. Time model

The approved target is an authoritative simulation frequency of **10 Hz**, with **paused, 1×, 2×, and 4×** controls. Rendering frame rate must not affect authoritative outcomes. Manual stepping remains available for deterministic tests. Validated commands may process while paused; pausing stops world-time progression, not command handling.

Calendar/day/season conversion remains configurable and deferred. The current [simulation configuration](../game/core/simulation/simulation_config.gd) defaults to one logical second per tick; that prototype is migration debt, not the approved target. Block 2 changes no simulation code. Tick interval, calendar conversion, season lengths, and need cadence require implementation and tests before gameplay claims can rely on them.

## 15. Persistence

Target manual save and quick save. Periodic autosave begins only after state schemas and recovery behavior are stable. Save data has a versioned schema and stable IDs; saving during active movement, hauling, reservations, and construction is a first-playable requirement.

Implementation requirements: snapshot at a defined authoritative boundary; serialize plain data rather than scene nodes; validate IDs, quantities, ownership, reservations, tasks, and schema before replacing active state; write through an atomic replacement strategy; retain a recoverable backup; define failure reporting and migration policy; and test interrupted/invalid writes and mid-task round trips. A load that fails validation must not partially overwrite the active settlement. Identical command/tick sequences must reload into logically equivalent state. Autosave interval and backup retention remain open balance/technical-policy values.

## 16. UI authority boundary

The UI reads immutable simulation snapshots/view models and submits typed commands. It does not own inventories, totals, task progress, need severity, construction completion, or time advancement; it cannot fabricate success or resources. Unavailable capabilities remain visibly unavailable with an explanation, never populated by plausible-looking fake values.

Use original, game-native HUD and contextual panels in the existing 3D world. Legacy HUD surfaces and approved interface-specific constraints remain governed by [UI_CONTRACT.md](UI_CONTRACT.md), but gameplay authority and this whole-game dependency order are governed here. HUD integration is scheduled after real domain APIs exist; a mock/gallery can support development but is not evidence of first-playable completion.

## 17. Platform and performance assumptions

Development is on macOS. Intended desktop validation platforms are macOS, Windows, and Linux. No release target is approved until matching export templates, packaged builds, and minimum-hardware performance have been tested. The current pinned Godot version and Compatibility renderer are described in [GOPALA-Toolchain.md](GOPALA-Toolchain.md); toolchain readiness is not export readiness.

Agree on minimum hardware, target frame/tick performance, representative settlement size, and test conditions before a performance gate. No population cap, FPS target, export success, or supported release platform is asserted by this contract.

## 18. Accessibility and localization

Desktop mouse/keyboard is first. Controller, mobile, and web are excluded initially. Controls need clear focus/selection and actionable invalid/shortage feedback; critical information cannot rely on color alone. Keep player-facing text behind localization keys from the start. English ships first; Nepali is planned after terminology and translation review. Historical terminology, transliteration, and fonts require fluent review before release.

## 19. Explicit exclusions

The first playable excludes combat and raids; regional conquest; dynasty politics; advanced trade; currency and taxation; religion; technology tree; complex happiness; pollution/desirability; terrain sculpting; bridges and walls; multiplayer; mobile/web release; and final production art. Cattle/fodder/milk are deferred unless cattle are expressly admitted by a later decision. Deferral means no acceptance criteria, UI promise, simulated effect, or release claim for these systems in this milestone.

## 20. Definition of done

Block 2 is done when this contract is committed and its sections, local links, scope boundaries, current-state facts, and baseline verification delta are checked. That documentation completion does **not** mean the first playable is implemented.

The first playable is done only when the complete §5 scenario works in the integrated running game, all economic and cancellation/save invariants in §§7–15 hold under normal and interrupted actions, player-facing causes and recovery are understandable, and the result is demonstrated through actual game interaction rather than tests or UI alone. Code/tests can support proof but cannot replace it.

## 21. Decision log

| Decision | Locked outcome | Evidence/current-state note |
|---|---|---|
| Product and player role | Historically inspired Himalayan settlement survival; Kathmandu Valley–inspired setting; one settlement's founder/chief | Historical claims must be separated from tradition and reconstruction. |
| Presentation and identity | Preserve current 3D geographic Kathmandu scene; original game/interface identity | Current project main scene is [`kathmandu_valley.tscn`](../game/scenes/landscape/kathmandu_valley.tscn), not the legacy isometric proposal. |
| Territory | Informational overlays only in first playable | Inferred frontiers cannot drive ownership, conquest, or historical assertions. |
| Core loop and economy | Gather → haul → store → build → assign → produce → satisfy needs → expand; physical conservation | The current ledger is empty and does not implement these systems. |
| First-playable content | Camp; villagers; gathering/hauling/storage; road, house, storehouse, well; validated construction; workers/labor; needs/recovery; mid-task save/load | See the fourteen observable checks in §5. |
| Spatial scale | Separate 20 m regional inspection grid from configurable 2 m settlement grid; 90-degree rotation | Conversion APIs and tests are target requirements, not present APIs. |
| Time | 10 Hz; paused/1×/2×/4×; deterministic manual stepping; commands while paused | Current default is a 1-second tick; migration required. |
| Persistence | Manual/quick save; autosave after schema stability; versioning, atomicity, backup, validation, migrations | No save/load capability exists in the current simulation spine. |
| Platform/language | Desktop mouse/keyboard first; English first; Nepali after review | Export and minimum-hardware validation remain unapproved/unproven. |
| Scope authority | This document controls game rules/dependencies; UI contract controls HUD-specific implementation | Earlier documents remain visible and are reconciled in §22–24, not silently rewritten. |

## 22. Open balance variables

These are explicitly **owner-tunable unresolved values**, not missing design decisions or implementation placeholders. Do not hard-code them as approved values. Product owner approval and playtesting must set them before the affected balance gate:

- Starting population, household distribution, and any initial homeless state.
- Initial resource quantities; source availability, depletion/regrowth, and gather rates; carry capacity.
- Building footprints, entrances, material costs, labor duration, storage capacities, worker slots, recipes/gather operations, and upgrade links.
- Settlement-grid bounds/local playable extent; terrain slope and water-clearance thresholds.
- Whether roads consume construction inventory or are a non-storage buildable surface; road construction cost and movement benefit.
- Tick-to-game-day conversion, season lengths, and need-update cadence.
- Need thresholds, shortage severity, grace periods, health effects, and recovery values.
- Autosave cadence and backup-retention policy.
- First-playable objective duration and explicit victory/failure/continue behavior.
- Minimum test hardware, target performance/FPS, representative population and workload budget.

Historical date/evidence approval and localization terminology are review gates, not balance values. No other unresolved placeholder is implied.

## 23. Dependency roadmap

Ordering is by prerequisite and acceptance evidence. These are future work packages, not authorization to begin them in Block 2. Save/load groundwork starts with early persistent records; HUD work consumes real APIs only after they stabilize.

| Step | Scope and dependency | Exit evidence |
|---|---|---|
| 3 | Entity/world registry and scene ownership, building on the scene-scoped simulation spine | Stable IDs, ownership/liveness rules, snapshot and scene-lifecycle tests; no gameplay totals duplicated in views. |
| 4 | Selection and inspection, depending on registry and current world picking | Select/inspect stable IDs; removals clear stale selection and panels. |
| 5 | Separate 2 m grid, coordinate conversions, occupancy, footprint/access validation, roads/blueprints; depends on terrain queries and registry | Bounds/round-trip/rotation/occupancy tests; invalid placement explains blockers; no 20 m construction alias. |
| 6 | Villager records, navigation, task assignment and interruption/labor foundations; depends on registry and settlement grid | Villagers move to legal access cells; blocked paths/tasks explain and recover safely. |
| 7 | Physical inventories, typed transactions, reservations, carrying/hauling and storage; depends on entity/task ownership | Conservation, capacity, competing-claim, cancellation, and recovery tests pass. |
| 8 | Gathering operations, construction lifecycle/stages, required buildings and storage/workplace behavior; depends on steps 5–7 | Real end-to-end gather → carry → store → reserve → deliver → labor → complete flow in game. |
| 9 | Households, food/water/shelter needs and understandable recovery; depends on persistent villagers and valid resource/building operations | Several game days sustained; injected shortages have visible cause, grace, and practical recovery. |
| 10 | Calendar/seasons/farming/weather only as separately approved slice scope; depends on stable clock, sources, and needs | Tunable time mapping and deterministic season/source/need tests; no unsupported historical claim. |
| 11 | Economy/progression expansion only after explicit product decisions | Approved systems have finite conserved inputs/outputs, understandable status, and save coverage. |
| 12 | Informational territory to any governance mechanic remains deferred pending explicit product and historical approval | No implementation/acceptance until a separate decision; informational overlays stay non-authoritative. |
| 13 | Threats/raids remain deferred unless explicitly approved later | No threat mechanics in first playable; later work requires separate scope and evidence review. |
| 14 | Save/load schema scaffolding begins during steps 5–7 and finishes after persistent entity/task/resource schemas stabilize | Validated versioned round trips, atomic replacement, backup recovery, migrations, and active-task tests. |
| 15 | HUD integration against real registry, selection, construction, inventory, need, clock, and persistence APIs | UI never fabricates values; in-game §5 actions are operable and report authoritative results. |
| 16 | Content completion, balancing, tutorial, accessibility, localization, and asset-manifest/license review | Approved tuning, English string audit, terminology review, and asset eligibility evidence. |
| 17 | Performance, export templates, packaged builds, and desktop platform validation | Reproducible hardware/build report and tested macOS/Windows/Linux packages before any release target. |

Steps 6–8 have a cross-dependency: task/worker scaffolding can precede inventories, but end-to-end hauling and construction cannot pass until step 7's authoritative transfer and reservation rules exist. This does not permit mock completion.

## 24. Risks and migration debt

### Consistency and migration register

| Existing statement/capability | Contract resolution | Classification |
|---|---|---|
| [2D Development Vedas](GOPALA-2D-Development-Vedas.md) specifies a 2D isometric fixed-view game; current project is a 3D geographic Kathmandu scene. | Keep the current 3D geography; this contract sets future game presentation. Legacy planning remains unedited and subordinate. | **RESOLVED BY THIS CONTRACT** |
| [Landscape Layer](GOPALA-Landscape-Layer.md) has earlier 180 × 180 scenic-valley/main-scene prose and a later Kathmandu revision; [Kathmandu Geography](GOPALA-Kathmandu-Geography.md) identifies the current main scene. | Treat Kathmandu as the project main geography; scenic/isometric prose is legacy/diagnostic, not current main-scene truth. | **RESOLVED BY THIS CONTRACT** |
| [UI_CONTRACT.md](UI_CONTRACT.md) calls its Block 2 HUD work and then numbers later HUD blocks. | Its table is a HUD sub-roadmap; whole-game sequence and current documentary Block 2 are governed here. HUD integration follows real gameplay APIs. | **RESOLVED BY THIS CONTRACT** |
| Current `simulation_config.gd` uses one second per tick; approved target is 10 Hz. | Change clock policy only in a later implementation task and update deterministic/runtime tests then. | **IMPLEMENTATION MIGRATION REQUIRED** |
| Current terrain inspection grid is 48 × 48 at 20 m/cell; contract requires a separate 2 m gameplay grid. | Preserve regional query semantics; add separate conversion, bounds, occupancy, and settlement navigation services. | **IMPLEMENTATION MIGRATION REQUIRED** |
| [Current catalog](../game/data/catalog.json) has seven resources, six buildings, and one pasture zone; resource definitions contain ID/name/icon/carry units, buildings ID/name/footprint/entrance/cost/work ticks/prototype sprite. It lacks worker slots, storage capacity, operations/recipes, upgrades, and localization keys. | Treat current data as prototype definitions, not the approved first-playable roster. Add/migrate schemas deliberately; first-playable resources are timber, stone, food, water, thatch. Fodder/milk and cattle content wait for explicit admission. The required camp/house/storehouse/well, wood/stone/food sources, and road still need validated roles and definitions. Building/source definitions must eventually support footprint, entrance/access cells, costs, construction labor, storage capacity, worker slots, recipe or gathering operation, upgrade links, and localization keys. | **IMPLEMENTATION MIGRATION REQUIRED** |
| [SettlementSimulation](../game/core/simulation/settlement_simulation.gd) supports clock/commands/empty delta ledger/IDs/snapshots; construction is unsupported and other gameplay capabilities are false. | Keep the spine; add authoritative records and typed services in dependency order. Do not describe the spine as a game economy or first playable. | **IMPLEMENTATION MIGRATION REQUIRED** |
| `apply_authorized_transaction(delta)` is callable on the simulation node with arbitrary catalog-keyed deltas. | Replace/encapsulate it behind typed, validated, ownership-aware source/transfer/consume/produce/reservation services before gameplay stock can be trusted. | **IMPLEMENTATION MIGRATION REQUIRED** |
| Current scene has geographic terrain, baked rivers, tree/territory visuals, picking and legacy HUD, but no settlement registry, individual villagers, navigation, placement/occupancy, construction, inventory logistics, or save/load. | Reuse geography/picking as inputs; build integrated simulation and scene presentation without claiming visual objects are gameplay entities. | **IMPLEMENTATION MIGRATION REQUIRED** |
| UI contract describes snapshot/command boundaries while noting selection, placement, logistics, needs, and saves unavailable; legacy HUD may show inspectable prototypes. | Capability-gate until APIs exist; bind HUD actions to authoritative services only after their roadmap dependencies. | **IMPLEMENTATION MIGRATION REQUIRED** |
| Old P0 plan specifies eight settlers, two cattle, cattle shelter, fodder/milk, seven resources, and 15-minute objective; this contract does not lock those values or admit cattle. | Use this contract's first-playable scope and §22 for unresolved quantities. Cattle/fodder/milk remain deferred unless explicitly approved. | **RESOLVED BY THIS CONTRACT** |
| Geographic files include inferred chiefdom/frontier outlines and an explicitly reconstructed headwater; historical date/territorial meaning is not approved. | Preserve uncertainty labels; overlays remain informational; review historical claims before factual presentation. | **HISTORICAL REVIEW REQUIRED** |
| Current [project configuration](../game/project.godot) enables five editor plugins: `flatten_for_llm`, `godai`, `godot_mcp_toolkit`, `proton_scatter`, and `waterways`. It separately declares autoloads `UIEvents`, `UIRouter`, `UISettings`, `MCPRuntimeServer`, and `Godai`. | The earlier audit statement that Waterways was disabled was incorrect: `res://addons/waterways/plugin.cfg` is explicitly enabled in the locked configuration. This is editor-plugin state, not an autoload. The current scene uses pre-baked `mapped_rivers.scn` plus `GopalaWaterNetwork`; do not infer procedural Waterways runtime generation from editor-plugin enablement. No config is changed here. | **RESOLVED BY THIS CONTRACT** |
| `MCPRuntimeServer` and `Godai` are runtime autoload entries; several enabled plugins provide editor/developer tooling. | Review `MCPRuntimeServer`, `Godai`, and similar tool/developer integrations for release-build exclusion; separately assess every enabled editor plugin/addon. No exclusion is claimed to be implemented. | **IMPLEMENTATION MIGRATION REQUIRED** |
| Historical implementation estimates, old content proposals, and the contradictory single-date assumptions in legacy design notes are not approved by this contract. | Do not treat their numbers as commitment or fact; validate period/content claims and settle balance only through review. | **HISTORICAL REVIEW REQUIRED** |
| Starting counts, quantities, rates, costs, dimensions, needs, time/calendar values, objectives, and performance limits remain open as listed in §22. | Product owner and playtests set these values; avoid shipping accidental defaults as locked balance. | **DEFERRED BALANCE VALUE** |
| [Toolchain acceptance](GOPALA-Toolchain.md) records that export templates/desktop packages have not been accepted; minimum-hardware performance is unmeasured. | No release platform or performance promise until step 17 passes. | **OUT OF SCOPE** |

### Plugin and autoload inventory at the locked baseline

Read-only facts from [`project.godot`](../game/project.godot); no project configuration was changed:

- **Enabled editor plugins (all five):** Flatten for LLM (`flatten_for_llm`), Godai (`godai`), Godot MCP Toolkit (`godot_mcp_toolkit`), Proton Scatter (`proton_scatter`), and Waterways (`waterways`). Enabled means listed in `[editor_plugins].enabled`; it does not assert runtime feature use or release packaging.
- **Runtime autoloads (all five):** `UIEvents`, `UIRouter`, `UISettings`, `MCPRuntimeServer`, and `Godai`. The first three are project UI services; `MCPRuntimeServer` and `Godai` are tool/developer-facing integration entries requiring an explicit release-build exclusion review. Autoloads and editor-plugin registrations are separate configuration mechanisms; Godai appears in both lists.
- **Waterways correction:** the audit's “disabled” statement conflicts with the actual locked file and is wrong. Waterways is enabled as an editor plugin. The running Kathmandu scene loads baked `mapped_rivers.scn` and constructs `GopalaWaterNetwork`; this is distinct from claiming the Waterways editor plugin generates gameplay rivers at runtime.
- Review all editor addons and similar integrations, not only the two named autoloads, before packaging. This contract neither edits enablement nor claims any tool is already excluded from export.

### Migration risks

- Changing tick duration can alter ordering, catch-up behavior, elapsed-time assumptions, and tests; preserve deterministic outcomes while moving to 10 Hz.
- Splitting regional and settlement cells requires explicit origins/axes and can invalidate old local-grid assumptions; verify bounds and round trips rather than reusing the 20 m cells.
- The public delta API can violate economic ownership if exposed to gameplay callers; close that boundary before resources become authoritative.
- Save schema design must account for reservations and carried/delivered construction stock, not only cached totals. Start scaffolding early and validate the full state before replacement.
- Existing geography has known interpretation limits, including DEM/display simplification, mapped-waterway gaps, and inferred data. Terrain/build validation thresholds are game policy, not survey-grade evidence.
- Legacy 2D plans, old P0 cattle/population assumptions, landscape revisions, HUD contracts, and historic calendar estimates can be mistaken for approved facts. Keep this register and the unedited sources visible until individually migrated or superseded.
- The worktree contains untracked third-party asset-pack material. Production-art approval requires an asset manifest and license review; do not infer rights or include those files through this documentation change.
- No export, cross-platform package, minimum-hardware performance, or final art claim follows from headless verification.
