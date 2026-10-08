# GOPALA — current status

Updated2026-10-08. Branch: `lead/v1`. Implementation checkpoint: `0af12f3d2c6666da95f4daa9cb553725ed6b06da`; this documentation update follows that checkpoint. Use `git rev-parse HEAD` for the current checkout revision. Verification covers the workspace, including Devendra's uncommitted editor/addon experiments; the committed performance checkout excludes those experiments.

## Verification

Latest `python3 tools/verify.py`: **161/161 stages passed**, `ok=true`, **0 captured warnings**, no reported timeouts or known-engine-error allowances. Source: [latest report](../reports/verification.json); [G1-03 receipt](../reports/G1-03-verification.json). Report SHA-256: `9a3f7c609bf6bc2536b2fda93421408bc65aec00e50e524c9fc91fd64785c44b`. Run the command again after code/content changes and update this page from the actual report and logs. This result establishes only the gate's covered checks, not final art, smooth performance or human gameplay acceptance.

## Playable now

`game/scenes/mvp.tscn` starts eight settlers and two cattle in the Kathmandu Valley. Implemented systems include fixed-tick commands, physically located goods/reservations, grid placement, material delivery and construction labour, repeat collection roles, routing around occupied plots, food/water consumption and health, dwelling capacity, pasture assignment/fodder/milk, schema-2 save/load and a fifteen-minute settlement objective. The local camera, planning grid, selection, resource/structure HUD and scenery culling support that settlement. The gate covers simulation, save/conservation, route, UI, scale and presentation checks plus a forty-settler benchmark smoke.

## Remaining work and failures

- The rendered forty-settler workload does **not** meet performance budgets. Two completed development-driver attempts had full-tick p95 above400ms against4ms and severe catch-up rendering stalls; a third had no renderer samples and was rejected. No complete eight-run baseline or passing regression comparison is claimed. G1-12 awaits the coordinator's answer on bounded benchmark scheduling; smoke success makes no headless FPS claim. See [benchmark protocol](lead/BENCHMARK.md).
- G1-11 asset replacements await the measured map answer and G1-12 approval. The [Resources survey](lead/RESOURCE_SURVEY.md) identifies candidates and excludes restricted/unknown packs. Existing visuals are prototypes; human review and final Nepali architecture remain outstanding.
- Main menu/settings, alerts, guided onboarding, seasons/monsoon/grass recovery, fields/cooking, households/immigration, herd growth, unlocks, flood recovery, sickness and barter remain queued. The full game/vertical-slice phase exits are not complete.
- End-to-end human playtest and phase acceptance remain pending. Prior local packaging evidence does not establish a current verified release build.

## Direction and next work

The [coordinator lead plan](GOPALA_LEAD_PLAN.md) sets priorities and phase exits. Its opening red-gate status is the original8October planning snapshot, not this latest gate result. Resolve the benchmark-driver question, record an honest complete baseline, then admit the approved asset replacements and measure their effect. Follow released bridge tasks rather than treating prototypes or tooling as gameplay progress.

## Suggestions

Keep this page as the sole short status summary; README and onboarding link here. Record the verification receipt, implementation revision, warning count and unfulfilled acceptance conditions whenever status changes. Optimize measured simulation hotspots before increasing scene density.
