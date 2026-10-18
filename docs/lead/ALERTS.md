# G1-04 settlement alerts

The scene-owned `GopalaAlertService` reads authoritative entities, balances, jobs and saved task state after the simulation's new read-only `fixed_tick_completed` signal. It does not mutate inventories, rules or the clock. The original pre-tick signal and snapshot interfaces remain unchanged. The valley owns the notifier, reconnects it when loading a replacement simulation, and frees it with the scene.

`game/data/alerts.json` contains the coordinator-approved thresholds, severity and ordering: food (wild food plus milk) and water below five logical minutes using current population and existing consumption cadence; health below 50. The JSON's keep import mode prevents a local map importer from treating this policy as a map. No addon configuration or upstream addon source changes are required.

Food, water, homelessness and unemployment are aggregated, focused on the first stable live entity ID in registry order. Low health, blocked stores, blocked construction and cattle inputs use per-subject keys. Unemployed idle excludes assigned roles, live tasks, carried goods, movement, NEED trips and shortage runs. Cattle input warnings derive only from NO_WATER or NO_FEED; feed warnings also require depleted pasture and no fed fodder. Store warnings require a worker blocked by full storage and an authoritative full store for that resource. Construction warnings use WAITING_FOR_MATERIALS or a live builder's blocked route/access/task state.

Each condition has one entry until resolution, with no toast, cooldown or historical queue. Notifications are evaluated once per completed tick; identical display sets produce no publication. Alert history is not saved: binding to a loaded simulation immediately recomputes the same keys, order and plain focus payloads. Row data is defensively copied. Clicking resolves the current live subject again, selects through the existing selection service, calls the camera's focus_point using the shared inspection-span standard, and opens inspection. Gone subjects return false without jumping.

The scrollable feed is part of the existing HUD CanvasLayer, uses the navbar theme and 32px controls, consumes input with STOP, and shows a severity glyph plus its written name. Existing row controls survive updates; only new/removed/changed display entries are updated, preserving keyboard focus. The feed sits below the inspection area and above camera controls at the required 1280×800 viewport.

## Verification

- `run_alert_tests.gd`: 33 deterministic state, boundary, resolution, deduplication, defensive-copy, completed-tick, save/load, selection and stale-subject checks.
- `run_alert_ui_tests.gd`: 10 real paused-MVP UI, glyph/text/input, keyed-row identity, insertion/removal and actual click-to-selection/camera checks. Both focused suites passed with engine exit 0 and no captured warnings or errors.
- The rendered `--capture-alerts` replay passed 11 checks and recorded [1280×800 evidence](../../reports/manual/alerts-1280x800.png). The capture precedes synthetic test mutations and shows the actual starting settlement's housing and idle alerts.
- Full `python3 tools/verify.py` passed **166/166 stages**, `ok=true`, **0 captured warnings**, **0 timeouts**, and no known-engine-error allowances. See [verification receipt](../../reports/G1-04-verification.json). It covers implementation commit `4e2424b` plus the user's preserved local addon/project experiments. Focused checks and the capture ran during untimed benchmark fixture preparation; the full gate ran after benchmark timing had stopped.
- Remaining human review: play with the scrollable feed, keyboard focus and tooltip readability over extended sessions and other display sizes. The automated gate and capture do not establish final accessibility or gameplay acceptance.

## Suggestions

Keep shortage thresholds in data and notifier history out of saves. Add localisation and accessibility variants through the existing theme/settings work rather than duplicating HUD controls. Before raising population or adding scene density, profile the measured snapshot/registry costs separately from this read-only notifier.
