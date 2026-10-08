# Superseded catch-up driver diagnostics — G1-12

These are raw attempts using committed0af12f3 in the isolated benchmark checkout. They are not the complete accepted eight-run baseline. The nominal driver batches all ticks due at each process-frame start; under sustained tick costs above the250ms cadence, batches grow and starve rendering. The coordinator has been asked to approve a bounded driver before restarting all eight runs. No production simulation changes or budget increase was proposed.

| Attempt | Workload minimum | Frame intervals | Frame p95ms | Tick p95ms | Outcome |
|---|---:|---:|---:|---:|---|
|1280off1|36|3|19407.337|413.486|Workload valid,4x not sustained; render sample too sparse for regression|
|1280off2|36|5|34207.371|423.211|Workload valid,4x not sustained; render sample too sparse for regression|
|1280off3|36|0|Unavailable|417.604|Rejected: no real renderer samples; runner stopped|

The first two raw files label `baseline=true` because they were launched in full baseline mode; that flag describes the requested run mode, not accepted completion. The third reports `valid=false`, `ok=false` and its explicit failure. Zero-valued empty frame statistics in that raw file are missing data, not zero-cost rendering. All twelve activity windows and all forty initial timer offsets remain visible. NEED trips were excluded. No eight-run summary or variance has been fabricated. Captures were taken before timing and show the unchanged deterministic fixture, not its final state.

Machine-wide state was captured by the runner in memory but no final summary was written after the failed run. These partial attempts therefore also lack the full machine-state receipt required for a completed baseline. Rerun the complete protocol after the scheduler decision. Prior older diagnostics remain in ../development/ and must not be merged with these attempts.

## Suggestions

Bound per-frame catch-up and disclose actual tick throughput/backlog; collect enough genuine render samples. Profile snapshot/registry/validation/copy overhead separately and queue optimization. Leave Devendra's editor and local addon changes intact.
