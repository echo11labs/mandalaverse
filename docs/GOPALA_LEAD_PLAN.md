# GOPALA — Lead Plan (game direction, roadmap, resources)

Author: Grok Bot (game lead / coordinator). Date: 8 October 2026. Coding agent: Codex via gopala-bridge.
This plan sits on top of the existing docs (`GAME_DESIGN_CONTRACT.md`, `GOPALA-Implementation-Backlog.md`,
`UI_CONTRACT.md`). Where they disagree, the design contract wins until a task changes it.

## 1. Where the game is (8 Oct 2026)
- Strong engineering spine: deterministic fixed tick, command queue, conserved inventories, reservations,
  grid routing, blueprint → delivery → labour construction, persistent gather roles, food/water needs, health,
  dwellings (4 per home), water points, two cattle with pasture/fodder/milk, schema-2 saves, a fifteen-minute
  objective, signed local macOS build.
- Gaps: the full gate is red (3 of 158 stages: ui-tests, mvp-scenario-tests reload, local-view timeout),
  ~3,000 lines are uncommitted on `hud/production`, nobody has played it end to end, and there's no front door
  (menu, settings), no alerts, no seasons, no farming, no growth, no threats. It is a simulation, not yet a game.

## 2. The game we're making
**Fantasy:** you are the cowherd-chief founding a settlement in the Kathmandu Valley. The herd is the heart of the
village; the valley's rivers and monsoon give and take.

**Design pillars**
1. **Readable cause and effect.** Every shortage has a visible reason and a fix (alerts, inspect panel, overlay).
2. **The herd is the economy.** Cattle give milk, dung (fuel/fertiliser) and draught labour later; protecting and
   growing the herd is the long-term goal. This is GOPALA's hook versus generic town builders.
3. **The valley is alive.** Seasons, monsoon rain, river floods, grass regrowth; good land is near water but riskier.
4. **Calm with spikes.** Long peaceful building punctuated by forecast events (flood, dry spell, sickness,
   predator on the herd), always warned in advance and recoverable.
5. **Honest history.** Nepali flavour throughout, labelled per contract §3 (documented / traditional / reconstruction).

**Core loop (unchanged):** gather → haul → store → build → assign → produce → satisfy needs → expand.
**Session arc:** Camp (8 settlers) → Village (households, fields, herd of 6+) → Town (crafts, trade, shrine/festival).

## 3. What makes it fun (feature priorities)
| Priority | Feature | Why it matters |
|---|---|---|
| Must | Green gate + playable build every phase | Nothing else counts if it doesn't run |
| Must | Main menu, pause/save/load, settings | A game, not an editor scene |
| Must | Alerts feed (food/water low, sick, idle, storage full, blocked site) with click-to-focus | Readable cause and effect |
| Must | Guided first 15 minutes from real sim events | New players finish the objective |
| Must | Seasons + monsoon weather + grass regrowth (G-017) | Gives the year a rhythm and planning |
| Must | Fields & two crops, cooking (G-019/G-020) | Food beyond foraging; real economy |
| Must | Households, satisfaction, immigration (G-021, M5 item 3) | The village grows — the main reward |
| Should | Herd growth: calving, herder hut, dung as fuel/fertiliser | GOPALA's signature system |
| Should | Knowledge unlocks + 3 settlement stages (G-023) | Long-term goals |
| Should | Forecast flood event + recovery (G-026), sickness tied to water/sanitation | Tension spikes |
| Should | Barter caravan (G-022) | Outlet for surplus, unlocks goods |
| Could | Predators threatening the herd (leopard) with herder response, festivals as morale events, Chronicle entries | Flavour and stakes |
| Later | Irrigation, pottery/tools, second scenario, Nepali localisation, Android | After the vertical slice |

## 4. Roadmap (phases = bridge task prefixes)
- **G1 — Stabilise & make it a game (≈1.5–2 weeks):** checkpoint commit, green gate, honest status docs, alerts,
  front door/menus, guided onboarding, debug overlay, tick-spike fix, playtest build. *Exit: Devendra plays a
  15-minute session from the menu without help and the gate is green.*
- **G2 — Seasons & farming (≈2–3 weeks):** calendar + seasons, monsoon/dry weather, grass regrowth, fields with two
  crops, granary/cooking recipe, food variety. *Exit: survive a full year.*
- **G3 — A growing village (≈2–3 weeks):** households & satisfaction, immigration gated by housing/food, herd growth
  (calving, herder hut, dung), knowledge unlocks, three stages. *Exit: grow from 8 to 30+ settlers.*
- **G4 — Stakes (≈2 weeks):** forecast flood + recovery, sickness/sanitation, predator on the herd, barter caravan.
- **G5 — Look, sound, feel (≈2–3 weeks, overlaps):** approved art pass on the style test, ambient audio + UI sounds,
  music, juice (build/complete effects), accessibility (UI scale, colour-safe alerts), performance on low-end Mac.
- **G6 — Vertical slice playtest:** five players, fix criticals, decide on Steam page / Next Fest demo.
Roughly 12–15 weeks to a polished vertical slice at the current pace. Tasks for G2+ are written after each phase review.

## 5. Tools & resources (recommended)
**Engine & code**
- Godot 4.7.2 (already pinned) — official docs: https://docs.godotengine.org/en/stable/
- Keep the project's own headless test runners; GUT or gdUnit4 only if a task needs mocking they lack.
- Godot profiler + Monitors for tick spikes; a custom F3 debug overlay (task G1-07).
- Existing Godot MCP toolkit in `game/addons/godot_mcp_toolkit/` for Codex to inspect live scenes.
**Free assets (check each licence; CC0 is safest)**
- Kenney — https://kenney.nl/assets (CC0 UI, audio, models)
- Quaternius — https://quaternius.com (CC0 low-poly nature, animals, characters)
- Poly Haven — https://polyhaven.com (CC0 textures, HDRIs, models)
- Freesound — https://freesound.org (check per-sound licence; prefer CC0)
- Sonniss GDC audio bundles — https://sonniss.com/gameaudiogdc (royalty-free)
**Design references** (study systems, never copy art/text/UI): Farthest Frontier (seasons, herd, threats),
Banished (needs + growth pacing), Townsmen (accessible economy), Kingdoms and Castles (readability),
Against the Storm (alerts and clear goals), Manor Lords (calm presentation).
**Culture & sound:** commission or license field recordings and instruments (madal, bansuri, sarangi); have a
Nepali historian/reviewer check Chronicle text before release.

## 6. How we work
Codex pulls one task at a time from gopala-bridge, runs `python3 tools/verify.py`, commits on `lead/v1`, submits.
Grok Bot reviews diffs and the verification report, approves or requests changes. Devendra plays each phase build
and says "check the GOPALA bridge" when Codex submits or is stuck. Nothing is pushed without Devendra's say-so.

