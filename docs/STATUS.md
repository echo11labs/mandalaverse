# GOPALA — current status

Updated 2026-10-08. Branch: `lead/v1`. Implementation checkpoint: `d5d8db6`; this documentation update follows that checkpoint. Use `git rev-parse HEAD` for the current checkout revision. Verification covers the workspace, including Devendra's uncommitted editor/addon experiments; the committed performance checkout excludes those experiments.

## Verification

Latest `python3 tools/verify.py`: **175/175 stages passed**, `ok=true`, **0 captured warnings**, no reported timeouts or known-engine-error allowances. Source: [latest report](../reports/verification.json); [G1-07 diagnostic receipt](../reports/G1-07-verification.json). Report SHA-256: `59b0c1b620a26f4feaefc2ecc087040c0691b125c5e6fdaada184af7cf013602`. The preceding asset checkpoint had fresh committed-source verification at d25bbd1 that passed **166/166 stages, 0 captured warnings**, including the public worker fallback; [clean receipt](../reports/G1-11-clean-verification.json). Run the command again after code/content changes and update this page from the actual report and logs. This result establishes only the gate's covered checks, not final art, smooth performance or human gameplay acceptance.

## Playable now

The project now launches a [main menu](GOPALA-Game-Menus.md) with Continue, New settlement, three named save slots and persistent settings. Escape cancels placement, closes inspection, then opens pause; menus freeze logical time and block camera/world input. New settlement uses `game/scenes/mvp.tscn`, which starts eight settlers and two cattle in the Kathmandu Valley. Implemented systems include fixed-tick commands, physically located goods/reservations, grid placement, material delivery and construction labour, repeat collection roles, routing around occupied plots, food/water consumption and health, dwelling capacity, pasture assignment/fodder/milk, schema-2 save/load and a fifteen-minute settlement objective. The local camera, planning grid, selection, resource/structure HUD and scenery culling support that settlement. The scene-owned alerts feed derives food/water/health, idle, housing, blocked-store/construction and cattle-input conditions from completed ticks, clears resolved entries and selects/focuses their live subjects. F3 adds [read-only diagnostics](GOPALA-Diagnostics.md): observed tick timing, entity counts, selected jobs/waiting reasons, actual routes and physical store/site claims. Releases require the saved settings flag. The gate covers simulation, save/conservation, route, alerts/UI, scale and presentation checks plus a forty-settler benchmark smoke.

## Remaining work and failures

- The rendered forty-settler workload does **not** meet performance budgets. The approved bounded driver completed three valid clean-source 1280×800 vsync-off replays: minimum36 active, frame p95 421–423ms and full-tick p95 406–408ms against4ms. The fourth vsync-on replay stalled before timing after its first capture, so G1-12 awaits a bridge answer on the capture handoff. The [incomplete attempt](../reports/bench/bounded-driver-diagnostics/README.md) is preserved as diagnostics. No complete eight-run baseline or passing regression comparison is claimed; smoke makes no headless FPS claim. See [benchmark protocol](lead/BENCHMARK.md).
- Devendra's direct request superseded the earlier asset hold. G1-11 replacements are implemented: KayKit trees, vegetation and stones, Styloo cattle, Highlands huts and functional props. Locally downloaded Craftpix villagers have idle/walk/pickup animations and correct 1.75m scale; restricted models remain gitignored, with Kenney workers used in public checkouts. Highlands huts are European-fantasy placeholders, not Newari architecture. See [asset upgrade](lead/ASSET_UPGRADE.md). Human visual approval and matched benchmark acceptance remain outstanding; the bridge dependency remains blocked.
- Guided onboarding, seasons/monsoon/grass recovery, fields/cooking, households/immigration, herd growth, unlocks, flood recovery, sickness and barter remain queued. The full game/vertical-slice phase exits are not complete.
- End-to-end human playtest and phase acceptance remain pending. Prior local packaging evidence does not establish a current verified release build.

## Direction and next work

The [coordinator lead plan](GOPALA_LEAD_PLAN.md) sets priorities and phase exits. Its opening red-gate status is the original8October planning snapshot, not this latest gate result. Resolve the renderer-capture question and record an honest complete baseline plus matched asset comparison. The separate baseline checkout remains at deee176. Follow released bridge tasks rather than treating prototypes or tooling as gameplay progress.

## Suggestions

Keep this page as the sole short status summary; README and onboarding link here. Record the verification receipt, implementation revision, warning count and unfulfilled acceptance conditions whenever status changes. Optimize measured simulation hotspots before increasing scene density.
