# Stone resource slice

Stone sources use the installed Proton Scatter rock models, copied to `game/assets/models/stone_scatter/` because its demo directory contains `.gdignore`. The local source receipt records hashes and preserves the MIT license. Decorative MultiMesh stones remain scenery; collectible deposits are registered simulation entities.

The world seed (`vegetation_seed`, default 43129) drives collectible timber, collectible stone and generated detail scenery. Set it to a nonzero integer to reproduce a layout, or zero to roll a new world; the resolved seed appears in resource inspection and on seeded entity records. Existing baked regional forest remains scenery.

`game/data/resource_distribution.json` configures 12 timber stands 20–85 metres from camp (12-metre spacing, 15–30 timber each) and 24 stone patches 10–95 metres away (5-metre spacing, 15–45 stone each). Different resources keep thirty metres apart so tree picking volumes do not cover stone patches. Bounded placement rejects water and slopes over 35 degrees. Counts may be lower on terrain that cannot accommodate all sources. Dimensions and placement distances use the project's metre conversion.

Collectible vegetation currently means timber stands. Each stand uses three normalized pine models, 12–16 metres tall. Harvest removes whole visible trees in proportion to remaining stock; it never shrinks trees. Exhausted stands disable picking. Grass, wild food and fodder harvesting remain separate development-plan work.

Select a villager, right-click a stone deposit, and unpause. A right-click order repeats trips until the source is depleted. Each trip reserves one unit, collects it, and carries it to the scenario camp. Escape stops a selected worker: before pickup the reservation is returned; after pickup the existing load is delivered before the job ends. API requests retain single-trip behaviour unless `repeat: true` is supplied. Only delivery increments the stored stone counter. Inspection shows available/reserved quantities and the worker's carried resource. Deposits lose visible pieces as collected and hide on depletion; each individual stone retains its size. Cancelling before pickup returns the reservation; cancellation after pickup preserves carried goods.

`run_stone_resource_tests.gd` covers deterministic scatter, terrain filtering, spacing, command validation, reservation/cancellation, paused collection, pickup versus stored balances, depletion and exactly-once delivery. Existing timber tests remain in the verification gate.

This extends the gathering slice. Storage capacities, general movement routing, save/load, final art approval and manual acceptance remain separate backlog work.

Historical evidence before local resource distribution: the GPU startup capture is `reports/manual/stone-resources.png` with counts in `reports/manual/stone-resources.json`: 24 deposits, 729 uncollected stone, and 50 starting stored stone. Initial presentation explicitly consumes the starting snapshot so the paused game shows resources immediately.

The live right-click handler successfully created a stone task, and delivery changed stored stone from 50 to 51 with no runtime errors. The headless stone suite includes this same input/physics/selection path (625 checks).

Stone sizing follows [Scale and sizing](GOPALA-Scale-and-Sizing.md) and `game/data/standards/world_scale.json`. Imported models are normalized to small loose stones relative to the villager, grouped in low patches with separate picking bounds. `reports/scale-audit.json` is regenerated on every verification.

Revision 2 corrects the rejected actor/map scaling. All new dimensions are metres converted at 100 m/world-unit. Earlier blue-capsule scale captures are historical and superseded; current references are `physical-human-river.png` and `physical-human-stones.png`.


The current collection suite checks both seeds, metre-based placement, shared seed records, repeated initialization without duplicated/refilled resources, timber tree dimensions and harvest visuals, and actual right-click timber collection through pickup, delivery, exhaustion and disabled picking.


The starting camp now searches deterministically for a nearby dry, low-slope site, with clearance for its footprint and starter entities. The worker starts five metres from camp on each axis, the starter tree ten metres away on each axis, and walking speed is 1.4 m/s. Building and ghost widths match logical footprint dimensions. Seeded resource trips are filtered to remain on the same dry bank; this is a startup placement restriction, not general pathfinding. Move orders cannot overwrite an owned collection/construction task. The repeat/stop suite checks conservation every tick, source depletion, no duplicate delivery, reservation release and safe stopping during a haul.
