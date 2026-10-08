# Incomplete bounded-driver attempt — not the eight-run baseline

Source: clean committed checkout `deee17658d37e84840f0df2dc7ef66c4799dcd83`. The approved runner performs at most one unchanged `advance_ticks(1)` per process frame, retains the four-ticks-per-second due schedule, and records overdue work. No simulation, clock, balance, asset or scene changes were included.

Three 1280×800 vsync-off replays completed with valid workload, 12 activity windows, a minimum of 36 productive workers, and actual renderer samples. Frame p95 was 422.928, 421.981 and 421.449 ms; full tick-call p95 was 407.91, 407.84 and 406.33 ms (rounded). Actual sampled rate was approximately 3.02 ticks/s, with final backlogs of 147, 146 and 144. These are honest budget misses, not passing performance results.

The fourth replay, the 1280×800 vsync-on reference, saved its camp capture and then stopped progressing before the pasture capture or timed warm-up. After more than five minutes, a read-only one-second macOS process sample found the runtime mostly sleeping. It has no timing JSON and cannot qualify. Only that stalled runtime was terminated with SIGTERM; the coordinator was asked on G1-12 about yielding between pre-timing capture awaits and adding a finite capture timeout. `runner.log` records the resulting exit -15. The user's separate Godot editor was preserved.

These raw files preserve the incomplete attempt. No complete eight-run summary, 1920×1080 result, valid vsync-on result or regression comparison is claimed. Any approved runner correction requires restarting all eight serial replays from the same new clean source revision.

## Suggestions

Resolve the renderer-capture handoff on the bridge before changing the protocol. Keep the existing simulation/clock/balance intact and preserve budget misses. Do not start G1-11 or add assets before the required eight-run submission.
