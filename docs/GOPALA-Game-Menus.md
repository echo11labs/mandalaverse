# GOPALA game menus — G1-05

The project launches `scenes/ui/front_door.tscn`. The main menu offers Continue, New settlement, Load settlement, Settings and Quit. Continue chooses the most recently written readable MVP save; it is disabled when none is available. New settlement starts the existing eight-settler, two-cattle scenario paused. The simulation, objective, supplies and resource distribution rules are unchanged.

In the settlement, **Menu** or Escape opens the pause menu. Escape first cancels placement, then closes inspection, then opens pause. It does not stop an assigned supply job. While a menu is open, logical time is paused and world/camera input is blocked. Resume restores the prior paused/running state and speed. Controls & credits also pauses the managed session. Direct developer scene launches retain their prior standalone controls.

## Saving and continuing

Save/Load buttons and F5/F9 open the slot picker. Three slots have editable names, shown with logical tick when loading. Slot one retains `user://saves/mvp.json`; additional slots are `mvp-2.json` and `mvp-3.json`. All use the existing checksummed schema 2 and atomic replacement, with `.bak` retaining the preceding file. Names and last-save order live in `user://saves/slots.cfg`. A malformed save is shown as unavailable and never replaces the live simulation. Incompatible world/scale/content data is rejected by the existing restore validation, with an error shown in the load screen.

Overwriting asks for confirmation. Leaving for the main menu, starting another settlement, loading another save or quitting asks before discarding unsaved progress. Cancel keeps the current settlement. Pause/resume alone does not create unsaved gameplay. Save from a menu preserves the paused state; Continue restores that state, and tempo buttons start time when ready. Save data includes the logical clock, entities, inventories, reservations, construction and worker tasks, rather than node references or visuals.

## Settings

`user://settings.cfg` stores master/music/effects volumes, UI text scale (80–150%), edge panning, camera pan speed (25–300%) and fullscreen/windowed mode. Preferences load and apply on launch and update immediately. Master, Music and SFX buses are configured without adding audio content; music/sound production remains a separate task. UI text scaling applies to menus and the active HUD. Camera settings affect presentation only. Edge panning is off by default and requires the focused window, a pointer over the world, and no placement or open menu. Existing accessibility preferences in UISettings remain available.

The scene-owned front door resets UIRouter before swapping worlds. Save restore rebuilds existing query adapters and visual caches. No new autoload or addon is installed. Devendra's other project/editor/addon and scene edits remain unstaged; only the main-scene configuration line belongs to this task.

## Acceptance evidence

`game/tests/run_front_door_tests.gd` uses isolated paths under `user://tests/front-door`, compares complete captured state after Save → main menu → Continue, tests Escape priority, menu pause/resume and input locks, overwrite and unsaved confirmation, all three slots, corruption recovery, volume application and preference reload through a new menu instance. `tools/verify.py` requires its structured report.

Rendered 1280×800 screenshots: `reports/manual/front-door-main-1280x800.png`, `front-door-pause-1280x800.png`, `front-door-settings-1280x800.png`, and `front-door-scale150-1280x800.png`. `tools/capture_front_door.gd` uses isolated capture preferences and synchronous drawing, not benchmark telemetry. Full gate results are recorded in `reports/G1-05-verification.json` — all 171 stages passed with 0 captured warnings, no timeouts and no known-engine-error allowances. The front-door suite passed all 28 checks.

Human playtesting of navigation, fullscreen on the target display and large HUD text across the broader resolution matrix remains necessary. These checks do not establish export acceptance, historical art approval or smooth performance.

## Suggestions

Build guided onboarding from real simulation events next so a first-time player can finish the objective. Use the existing buses for the later licensed ambient/UI audio pass. Keep save metadata and UI preferences separate from authoritative settlement data, and finish the pending matched performance benchmark before making an FPS claim.
