# G1-02 verification and self-containment

The committed configuration removes unused GUIDE/Godai autoloads and default editor plugins, and the excluded at-icons editor plugin. The used MIT icons and all addon sources/licences remain. Godotiles extension discovery is disabled by renaming its descriptor; no upstream code is patched and no binary is admitted. A scan of tracked gameplay scripts, scenes, project configuration and .tres resources found no remaining runtime dependency on GUIDE, Godai or Godotiles. Devendra’s local addon entries and files stay uncommitted; validation of committed content uses a fresh checkout with only a .tools symlink.

UI tests retain the coordinator-approved PopupMenu STOP exception while all decorative plates remain IGNORE. The added input test sends real viewport mouse events, proves the world-picking observer receives an unobstructed click, opens the pasture popup, selects South pasture, verifies it closes and confirms no UI click reaches that observer. Existing asynchronous build/inspection checks are now awaited rather than overlapping. Optional labels are populated with territory/build fixtures before the unchanged label assertions. The viewport’s logical size matches the fixture size, so actual click coordinates are valid. No assertions are removed or timeout budgets raised.

Original failures: the UI’s unlabelled OptionButton acquired text/tooltip and its decorative cattle container uses IGNORE; the native interactive popup correctly uses STOP. The scenario fixes in the approved G1-01 checkpoint corrected double conversion of cattle movement units, prevented routes repeatedly returning actors to a cell start, cleared old grid obstacles on route-service reconfiguration, and rejected buildings over cattle. These restore reachable grazing/tending and milk/fodder delivery. The earlier local-view 60-second timeout has not been reproduced; its existing renderer, buffer and culling assertions and 60-second budget remain. Do not attribute that timeout to a proven hang or claim measured GPU optimisation.

Test audit against 9b212df: new scenario, herd, save, route, construction labour, survival, forage, stockpile, assets, scale, stones, local-view and worker-job suites were added. Existing gather checks now advance authoritative ticks; movement fixtures convert distances into world units and add speed conversion checks. Placement now requires a BLUEPRINT and no immediate timber deduction, with actual delivery/labour covered in construction tests. Camera checks use controlled process time and proportional spans, with added cursor anchoring, tilt, clipping and scenery checks. These changes reflect the approved checkpoint’s implemented rules; the popup exception is an explicitly approved correction, not an unchanged test suite.

Whitespace-only cleanup removes all trailing whitespace in construction_placement_service.gd (23 lines in the actual checkpoint, rather than nine in the task note).

No visible product design changed in G1-02; no new visual screenshot claim. Human play is still needed to assess subjective camera/HUD feel and the separate local grass/sky experiments. Verification is a development gate, not a 40-settler performance benchmark or exported-release acceptance.

## Workspace result

`python3 tools/verify.py`: 158/158 stages passed, no captured WARNING lines or known-engine-error allowances. MVP scenario: 51.07 seconds versus the task’s historical failing 166 seconds. Local view: 6.49 seconds under the unchanged 60-second timeout. UI: 184 checks passed. Forest output still declares pending visual review; these tests do not approve final art. An earlier standalone import encountered stale extension-cache errors and JSON import errors from locally enabled plugins; the gate’s subsequent import passed. User/editor scene edits during the run remain uncommitted and were not repaired by this task.

## Fresh-checkout result

Commit 608362d, freshly created managed worktree, no copied assets/caches and only the ignored .tools symlink: `python3 tools/verify.py` passed all 158 stages. MVP scenario: 51.15 seconds; local view: 6.1 seconds. Reports and import/UI/scenario/local-view logs are stored separately with the G1-02-clean prefix. No captured WARNING lines or known-engine-error allowances. No errors or skipped stages. The source revision is unchanged between this run and the submitted report commit.

## Suggestions

Keep the clean-checkout gate as a release check and expose the gopala-bridge tools directly in the MCP catalogue to reduce adapter work. Assess grass/sky addon admission in G1-10 with licence receipts, exact configuration and a 40-settler performance comparison. Coordinator input is needed before any installation or admission.
