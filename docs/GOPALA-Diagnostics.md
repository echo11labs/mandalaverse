# F3 diagnostics — G1-07

F3 toggles a scene-owned read-only overlay. Developer builds allow it; release builds require **Settings → Allow diagnostics (F3)**. The flag is saved to settings.cfg and defaults off. Revoking it in a release hides both panel and route immediately. The overlay starts hidden in every new scene, consumes its own panel input and disconnects observers when the scene closes. It rebinds to the restored authority after loading, clearing the previous timing history.

The panel shows logical tick, speed, paused state, entity counts and average/maximum observed tick-body time over the last 300 completed ticks (or the samples available). Samples come from the existing logical_tick_advanced and fixed_tick_completed signals; no simulation/clock/balance/benchmark-driver edits are needed. This interval includes services and snapshot publication; it excludes clock advancement before the start signal and command draining outside the completion interval. It is a diagnostic indicator, **not the G1-12 full-driver measurement or an FPS claim**. The observer's timer work is kept outside authoritative state and never saved.

Select a villager to see job, movement/task state, waiting/status reason, carried goods, gather/build reservation tasks and remaining route length/revision. A yellow terrain-following line draws the actual remaining route, starting at the current position. It reads a defensive route copy rather than asking navigation to plan again. Missing/finished routes clear the line. It has no collision, occupancy or resource identity.

Select a store/site to see actual physical inventory, outgoing material reservations, incoming collection promises, delivered/site-reserved materials, promises by source store and unreserved shortages. Shortage means required minus delivered minus reserved, bounded at zero; reserved goods still awaiting hauling remain visible separately. These are the same authority and storage partitions used by live jobs, rather than a second inventory.

The overlay refreshes at most four times per second while visible. It submits no commands, advances no ticks and changes no resources, claims or selection. Timing observation continues while hidden so a later F3 toggle can show recent samples. Large selected-task data scrolls inside the panel.

`game/tests/run_debug_overlay_tests.gd` checks complete captured authority equality around toggle/refresh/process/render, actual route vertices around occupied plots, defensive-copy behavior, developer/release gating, exact 300-value timing window, real signal timing, store/site data and observer cleanup. The required structured stage is wired into verify.py. Rendered evidence: `reports/manual/debug-villager-1280x800.png` and `debug-store-1280x800.png`; the capture tool uses an isolated presentation/test settlement and never saves or changes the player's run.

## Suggestions

Use this overlay during guided onboarding and the fifteen-minute playtest to distinguish lack of sources, storage, routes and supplies. Optimize only measured simulation hotspots in a separate approved task. Retain G1-12's separate benchmark protocol for performance acceptance, since instrumentation ranges and render work differ.
