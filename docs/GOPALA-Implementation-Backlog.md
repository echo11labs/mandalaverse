# GOPALA — Implementation Backlog

Companion to [2D Development Vedas](GOPALA-2D-Development-Vedas.md). Prepared 29 September 2026. Foundation and landscape work have started; see the status below. This file is a local project backlog; no external issues have been created.

## Current status

G-001: project/engine/templates pinned; local macOS export and startup smoke tested. G-002: typed content registry and rejection checks implemented. G-003: logical coordinates, occupancy and terrain physics picking have regression suites. G-004: camera pan/zoom/orbit, terrain-height tracking, corrected culling, selection and the resource/structure/inspection HUD are implemented. G-005: physical actor/prop sizing and building footprint dimensions are checked; final art and occlusion acceptance remain outstanding.

The fixed tick, registry, ledger/reservations, placement/construction labour and timber/stone/thatch/wild-food/fodder pickup/delivery slices now exist and have verification suites. The Kathmandu view starts on dry ground with nearby workers and seeded collectible sources. Right-click gathering repeats until depletion and Escape stops safely. These are partial implementations of G-006–G-011, not completion of the settlement milestone: regional routes, store-to-store transport, broader save compatibility and human gameplay/art acceptance remain outstanding. Cattle, the fifteen-minute scenario, mid-objective load and exported-data acceptance are now implemented.

The separate `scenes/mvp.tscn` starts eight settlers with protected food/water reserves. Needs now physically consume store stock, completed dwellings house four people each, shortages reduce health, and builders return carried goods before needs breaks and resume afterward. Built water points expose bounded refillable collection sources. See [MVP survival](GOPALA-MVP-Survival.md) for implemented scope and remaining acceptance.

The individual stockpile-inventory and persistent collection job slices reserve room in specific stores, pause at full storage and switch depleted sources. Builders fetch all required materials from recorded stores; cancellation and store removal preserve goods at physical locations. Schema 2 validates and saves inventory partitions and construction origins. [Storage and worker jobs](GOPALA-Storage-and-Worker-Jobs.md) records coverage and remaining store-to-store transport/filter/general-dispatcher requirements.

The settlement-wide [worker management](GOPALA-Worker-Management.md) slice adds staffing targets, priority dispatch, safe automatic/manual ownership, blocked-job reasons and saved policy state for existing gathering, building/path and herd work. Store-to-store hauling, per-store filters and processing remain separate requirements.

The local worker-routing slice now uses four-neighbour paths around occupied/reserved plots and displayed water, with access cells beside buildings, occupancy-change replanning and conservation-safe blocked delivery retries. [Worker routes](GOPALA-Worker-Routes.md) records coverage and remaining routing requirements.

The local camera now frames current workers/buildings at a 40 m default span. The visible 2 m planning grid matches logical occupancy, and terrain/scenery rendering is spatially culled with a bounded local scenery cache. GPU comparison and regression scope are recorded in [Local settlement view](GOPALA-Local-Settlement-View.md); this does not implement disk streaming or general worker routes.

The interface layer is recorded in [Interface layer](GOPALA-Interface-Layer.md) and font provenance in [UI font receipt](GOPALA-UI-Font-Receipt.md). Part of G-004 is satisfied; its acceptance still requires that clicking UI does not issue world commands, which is only partly testable before placement exists.

The authorized mixed 2D/3D landscape direction is recorded in [Landscape layer](GOPALA-Landscape-Layer.md). Historical timeline estimates below have not been validated as delivery commitments.

## Working rules

Finish each acceptance condition before treating an item as complete. Implement the smallest end-to-end behavior first. Use temporary original shapes or commercially eligible placeholder art. Each milestone ends with an exported playable build, a short defect list, and an updated estimate.

## M0 — foundation, target week 1

| ID | Work | Dependencies | Acceptance |
|---|---|---|---|
| G-001 | Create Godot project; pin engine/templates and folders | — | Empty desktop export opens; version/setup instructions are recorded |
| G-002 | Add typed content registry and stable IDs | G-001 | Dwelling, stockpile, timber, and thatch definitions load; duplicate/missing IDs are reported |
| G-003 | Create isometric ground and coordinate conversion | G-001 | Selecting any test-map cell returns its correct logical coordinate at several zoom levels |
| G-004 | Add camera, selection, input actions, basic HUD | G-003 | Pan/zoom stays within limits; clicking UI does not issue world commands; Escape cancels placement |
| G-005 | Validate art scale and Y-sorting | G-003 | Villager walks in front of/behind a dwelling and tree with correct ground anchors; large occlusion behavior is documented |

## M1 — P0 functioning game, target weeks 2–3

| ID | Work | Dependencies | Acceptance |
|---|---|---|---|
| G-006 | Build authoritative tick and command queue | G-002 | Pause freezes state; identical tick counts produce equivalent basic outcomes at supported speeds |
| G-007 | Build inventory transfers and reservations | G-006 | No negative stock; conflicting collection and capacity claims cannot duplicate items |
| G-008 | Add logical occupancy and grid routes | G-003, G-006 | Worker reaches legal access cell; solid destinations and missing paths produce explicit failure |
| G-009 | Build task dispatcher and recovery states | G-007, G-008 | Worker claims, carries, delivers, and releases; interruption/removal returns items or redirects carried stock |
| G-010 | Add footprint preview and construction | G-002, G-009 | Invalid placement explains why; a dwelling needs delivered materials and work before activation |
| G-011 | Add gatherable resources and source depletion | G-009 | Timber/stone/thatch/wild food/fodder reach storage through actual collection and transport |
| G-012 | Add home assignment and food/water needs | G-010, G-011 | Settlers occupy completed homes; needs consume valid stock; shortage interrupts work with a visible reason |
| G-013 | Add minimal cattle, pasture, and milk | G-009, G-012 | Two cattle require grazing or fodder plus water and tending; milk appears only after the production conditions pass |
| G-014 | Add versioned manual save/load | G-006–G-013 | Local Kathmandu slice implemented: [save/load evidence and limits](GOPALA-Save-and-Load.md); mid-haul/mid-build, blocked delivery and cancellation refunds preserve goods and IDs. Full milestone still requires remaining systems and exported acceptance. |
| G-015 | Assemble all six P0 structures and objective | G-010–G-014 | Eight settlers sustain the test settlement for 15 minutes; save/reload and continue without manual repair |

G-014 is a completion item: start its basic schema and snapshots during G-007/G-010, then extend it as needs and cattle arrive.

## M2 — husbandry and environment, target weeks 4–5

| ID | Work | Dependencies | Acceptance |
|---|---|---|---|
| G-016 | Expand pasture capacity, herd assignment, and fodder support | G-013 | Overstocking lowers output; moving cattle or supplying fodder restores support; days remaining are visible |
| G-017 | Add weather phases and vegetation recovery | G-006, G-011, G-016 | Rain/dry modifiers affect grass and travel consistently; rendering/camera position cannot change rates |
| G-018 | Add fodder-store buildable and debug overlay | G-010, G-016 | Local storage capacity works; overlay exposes job reason, reservation, path, and input shortages |

## M3 — village economy, target weeks 6–7

| ID | Work | Dependencies | Acceptance |
|---|---|---|---|
| G-019 | Build field zones and two crop definitions | G-009, G-017 | Workers prepare, plant, tend, harvest, and haul; seasonal timing and yield are data-defined |
| G-020 | Add generic recipe processing | G-007, G-019 | Cooking/dairy inputs, labor, output capacity, and completion are transactional and inspectable |
| G-021 | Add household groups and satisfaction | G-012, G-020 | Every resident belongs to a visible household; unmet needs explain satisfaction changes |
| G-022 | Add barter and surplus limits | G-020 | Trades cannot spend reserved stock; repeated trades do not provide unlimited free goods |
| G-023 | Add six knowledge unlocks and three settlement stages | G-016, G-019–G-022 | Requirements are visible; completed work advances unlocks once; stages survive saving |
| G-024 | Complete twelve P1 structures/spaces and two zones | G-018–G-023 | Every content entry performs its documented role; no placeholder button claims an unimplemented feature |

## M4 — vertical slice, target weeks 8–10

| ID | Work | Dependencies | Acceptance |
|---|---|---|---|
| G-025 | Build authored valley and onboarding objectives | G-024 | Starting resources and source access support several viable layouts; player learns by completing the real economy loop |
| G-026 | Add one forecast rain/flood event and recovery | G-017, G-025 | Event warns the player, changes exposed tiles by rules, and allows practical mitigation/recovery |
| G-027 | Integrate approved art, audio, and UI | G-005, G-024 | Cohesive normal-zoom view; every critical icon has text/tooltip; eligibility ledger covers release assets |
| G-028 | Harden saves and run simulation failure tests | G-014, G-024, G-026 | Interrupted jobs, full storage, unreachable sources, and mid-season snapshots pass; backup load works |
| G-029 | Run performance/device and touch-layout checks | G-027, G-028 | Report names hardware/build/population/speed; meets agreed desktop targets; representative touch interaction is usable |
| G-030 | Run five-player slice playtest and fix critical defects | G-025–G-029 | At least four players finish without developer guidance; remaining problems and next estimates are recorded |

## M5/M6 — expand only after G-030

1. Add irrigation as connected coverage with explicit capacity and breaks; prove that placement changes update affected fields.
2. Add pottery and simple tools using existing recipes; expand buildings/resources without bespoke per-building economic scripts.
3. Add immigration only when housing and food support arrivals; prevent runaway growth or irrecoverable shortages.
4. Add a second scenario before procedural generation; reuse the same systems under different resource/weather constraints.
5. Complete research-backed Chronicle entries and reviewed Nepali localization.
6. Expand to the small V1 scenario count; test campaign completion and sandbox continuation.
7. Validate target desktop platforms; separately validate Android touch, lifecycle, saving, and performance before committing its release date.

## Candidate expansions to retain outside the launch backlog

Traffic-worn trails, deeper livestock reproduction, family life events, more wildlife, procedural maps with reachability checks, regional campaign map, limited defense, later Nepali eras, and a future 3D presentation. None is a prerequisite for the first functioning game.

## Information to settle before implementation commitments

- Confirm desktop-first or Android-first priority; desktop-first is the present assumption.
- Record actual developer hours, experience, and art/research availability.
- Agree on representative low-end hardware and intended interface resolution.
- Approve one small style test before producing the full asset set.
- Confirm the historically inspired scope and review process; select final crops/architecture from research.

Keep progress on a simple board: Ready → In progress → Review → Done. A saved source file is not a completed gameplay feature; acceptance must be demonstrated in the exported game.

## Desktop MVP engineering update

The default MVP scene now includes physical food/water needs, cattle and finite pasture/fodder support, located milk transport, an eight-settler fifteen-minute objective, and mid-objective saving. See [MVP cattle and scenario](GOPALA-MVP-Cattle-and-Scenario.md). Automated acceptance uses actual valley construction and supply jobs. Packaging, visual acceptance and performance receipts must be inspected before closing the active block; human art approval remains pending.

## Herd management continuation

G-016 now includes persistent player pasture assignment, routed cattle relocation, capacity and grazing-minute inspection, crowding penalties and physically supplied fodder support. See [herd management](GOPALA-Herd-Management.md). The two-cow scenario remains unchanged in population; breeding/purchasing, larger configurable plots and calendar-day forecasts remain. G-017 weather and vegetation recovery is the next gameplay slice. The active block remains open for human acceptance.
