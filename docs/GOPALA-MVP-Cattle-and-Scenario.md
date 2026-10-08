# GOPALA playable desktop MVP

The default scene is `res://scenes/mvp.tscn`. It starts paused with eight settlers, two cattle, 48 food and 64 water, plus the existing construction stock. The standalone macOS build has a separate `GOPALA-MVP` user-data directory. Development MVP saves use `user://saves/mvp.json`; the landscape engineering fixture keeps its own save.

## Play

1. Place two dwellings, a water point, cattle shelter, timber camp, gatherer shelter and stockpile. Select a free settler and right-click each blueprint to assign a builder. Materials travel from actual stores before labour starts. Keep one settler collecting wild food while building.
2. Select Pasture from the build bar and place its four-by-four-cell plot. Each cell is two metres; the eight-metre plot supports two cattle and initially has sixteen grazing rations. Pastures cannot overlap buildings or other pastures and stay walkable.
3. Assign supply roles using the selected worker's inspection panel. Two water carriers, two food collectors, a herder, milk carrier and fodder collector are a tested allocation. Completed timber camps, gatherer shelters, water points and cattle shelters also provide contextual role assignment by right-click.
4. Food and water consumption require walking to a real store. Interrupted gathering completes its carried delivery; builders return materials and resume after their break. Interrupted herders leave their carried ration as recoverable stock at their actual position. Food and water collection can recover a final carrier from shortage.
5. Cattle need a completed shelter, a pasture, one water ration, grazing or hauled fodder, and an actual tending visit per cycle. Milk waits beside cattle until carried to storage. Stored milk can feed settlers. Empty grazing stays depleted; fodder supports subsequent cycles.
6. Complete all six building categories, house eight healthy settlers, collect milk, and sustain stored food/water and recent cattle production for fifteen continuous logical minutes. Shortages reset the timer. A settler reaching zero health fails the scenario; reload an earlier save or start again. Success allows sandbox continuation.

The Controls & credits button explains selection, placement, camera, saving and resource jobs. Tempo is pause, 1×, 2× or 4×; all production, needs and the objective use logical ticks. Camera movement and rendering never generate resources. Balance values in `game/data/mvp_policy.json` are prototype settings, not historical claims.

## State and evidence

Cattle, pasture and herding trips are plain registry records. Feed stock leaves its store only at pickup; the carried unit becomes a cattle input only on arrival. Milk is generated as uncollected environmental stock and enters the ledger only after physical delivery. Save validation checks ownership, carried goods, input journals, milk output/source correspondence, pasture shape and grazing totals. Human needs and objective progress survive saving.

`run_herd_tests.gd` checks missing production conditions, physical feeding, in-transit saves, milk transport, interrupted loads and malformed cattle state. `run_mvp_scenario_tests.gd` uses the actual valley, real blueprint construction and jobs; it completes the fifteen-minute objective with a halfway save/reload and then checks the exhausted-pasture transition to fodder. Required verification also measures cattle and milk against scale standard revision 10 and retains the people-to-river regression.

This is a prototype MVP, with original simple cattle geometry and existing free asset receipts. Human art approval remains pending, including the forest family. Advanced job priorities, grazing recovery, farming, weather, immigration, herd breeding, approved historical architecture and Nepali localization belong to later milestones. Target-device acceptance must name the tested machine and renderer; a screenshot alone is not a performance result.
