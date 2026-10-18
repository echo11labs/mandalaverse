# Worker management — 12 October 2026

Implemented as the next G-009/G-011 economy slice. The existing fixed-tick services still own movement, reservations, hauling, construction, needs and herd work. This feature allocates staff among those services; it is not store-to-store transport, processing or a new production system.

## Player controls

Open **Workers** in the bottom dock or press **J**. The bounded management window shows nine supported jobs, staffing targets, Off/Low/Normal/High priority, actual assigned staff and blocker reasons. Changes use typed commands and can be configured while paused; assignment begins when time runs.

Enable **Automatic workforce** to enrol available, unassigned settlers. Existing manual jobs count toward the targets and remain under player control. The default editable plan prioritizes water and wild food, allows two construction workers, and reserves roles for timber, stone, thatch and herding when their sources/support exist. Zero targets and Off priority create no new automatic assignments.

In the roster, **Auto** returns a settler to automatic management or takes their current job into manual ownership. The resource-role menu uses the existing safe reassignment mechanism. Specific building assignments and Stop building remain in the settler inspector; click a roster name to open that inspector. Assigned constructors cannot take a different manual role until their build is released. Escape, the window close control and Close dismiss the panel, and tick updates do not reopen it.

## Dispatch contract

Targets include manual staff. Priorities allocate scarce automatic staff deterministically, with a stable role/worker tie-break. Matching workers are retained to avoid churn. Constructor demand is capped by actual unfinished, unstaffed sites and active automatic builders, so a large quota cannot hold an idle crew when there is no work. Buildings and paths share that construction quota, with stable oldest-entity-first site selection.

Automatic reassignment waits until a worker is idle, has no active task/cargo, and is ready for work. An in-flight delivery or active build remains intact when targets, priorities or the master switch change. A builder waiting for materials with no carried load can safely release the site for another role; staged goods/progress and road auto-build intent are retained. This prevents an all-builder crew from deadlocking when supply work is prioritized. The roster shows the next role while the current load/job finishes. Explicit successful gathering, builder and role commands take manual ownership; explicit movement also prevents automatic takeover. Manual overrides clear deferred construction resumption so an old needs break cannot silently undo a new player order.

Needs retain precedence. A worker fetching/eating supplies is not diverted to labor. A hungry/thirsty idle worker can recover the missing food/water using the existing supply fallback, physical collection and delivery. This requires an enabled supply job and an actual available source/storage; the dispatcher never creates supplies.

Before a settlement opts into this feature, legacy dirt-path automatic assignment remains compatible. Once a policy or per-worker automation setting is stored, the workforce master switch also governs road dispatch. Turning it off cannot be bypassed by the old road scheduler.

The panel distinguishes missing sources, full storage, unsupported herds, lack of free staff, no sites, fully staffed sites, material waits and actual routing failures. Tooltips explain how to resolve common blockers. A priority is a staffing preference, not a promise that inaccessible work or missing materials will succeed.

## Persistence and evidence

The policy and worker ownership/pending-role fields live in existing runtime entity records. Save schema 2 is extended additively: old saves without workforce fields remain valid. New policy bounds, types and role IDs are validated before restoration; malformed saves/commands do not replace the active settlement. The panel disconnects the previous snapshot source and binds to the restored simulation.

`run_workforce_tests.gd` exercises scarce-worker priority, paused configuration, physical conservation on each tick, queued reassignment while carrying, JSON save/load during a haul, manual overrides, emergency food recovery, actual road construction, capacity blockers, invalid commands and master-disable behavior. The mandatory gate includes the new suite and requires its structured result. `review_workforce.gd` verifies actual MVP controls, roster navigation, shortcut/closing, inventory safety and restored binding, with captures at 1280×800 and 1920×1080.

Results and logs are in `reports/workforce/validation.json`. The full verification gate remains blocked at the existing import resource/RID leaks; demo script case warnings and the known language-server shutdown condition are retained in its report. No export, GPU performance, general transport or processing acceptance is claimed.
