# GOPALA — Attribution ledger

Maintained from Block 0 onward (per the HUD blueprint). Every entry records:
asset, author, source, license, files, and status. **Unverified means: do not
redistribute until resolved.** Last updated: 2 October 2026.

## Engine and tools

| Item | Author | License | Files / receipt | Status |
|---|---|---|---|---|
| Godot Engine 4.7.2.stable (pinned, `ed1daf0bf`) | Godot Foundation | MIT | `.tools/godot/Godot.app` (local pin, gitignored) | Verified |
| Python tooling (`tools/*.py`) | Project | Project license | `tools/` | Project-authored |
| NPGameDev Godot MCP server/toolkit (vendored) | NPGameDev | Upstream LICENSE + ATTRIBUTIONS preserved | `game/addons/godot_mcp_toolkit/LICENSE`, `…/ATTRIBUTIONS.md`, receipt `tools/godot-mcp-source.json` | Verified — do not patch for gameplay code |

## Fonts (all OFL-1.1, vendored with receipts)

| Font | Files | Receipt | Status |
|---|---|---|---|
| Fraunces | `game/assets/fonts/Fraunces.ttf` | `game/assets/fonts/OFL-Fraunces.txt` | Verified |
| Karla | `game/assets/fonts/Karla.ttf` | `game/assets/fonts/OFL-Karla.txt` | Verified |
| JetBrains Mono | `game/assets/fonts/JetBrainsMono.ttf` | `game/assets/fonts/OFL-JetBrainsMono.txt` | Verified |
| Noto Sans Devanagari | `game/assets/fonts/NotoSansDevanagari.ttf` | `game/assets/fonts/OFL-NotoSansDevanagari.txt` | Verified |

Design rationale and usage: `docs/GOPALA-UI-Font-Receipt.md`.
UI test `game/tests/run_ui_tests.gd` asserts the receipts ship with the fonts.

## 3D models and textures

| Item | Author | License | Files / receipt | Status |
|---|---|---|---|---|
| Poly Haven foliage (13 models + atlases) | Poly Haven | CC0 1.0 | `game/assets/models/trees/PolyHavenFoliage/CC0-1.0.txt`, `source-receipt.json` | Verified |
| Stylized Nature MegaKit (free tier, 68/116 models) | Quaternius (@quaternius) | CC0 1.0 | `game/assets/models/trees/QuaterniusMegaKit/License_Standard.txt` | Verified |
| Stylized Nature MegaKit source zip | Quaternius | CC0 per pack receipt | repo root `Stylized_Nature_MegaKitStandard.zip` (gitignored via `*.zip`) | On disk, not committed |
| ez-tree (Godot port) | Daniel Greenheck | MIT | `game/addons/ez-tree-godot-port/LICENSE` | Verified |
| EmacEArt / CoolWater + Roadside Tales bridges | Maciej EmacArt (EmacEArt), 2026 | EmacEArt Asset License — free in projects, **no resale or standalone redistribution** | `game/LICENSE.txt`, `game/Documentation/LICENSE.txt` | **On disk, NOT committed** — pack excluded from git pending a publishing decision (see contract §14) |

## Editor/runtime addons (committed)

| Addon | Author | License | Receipt | Status |
|---|---|---|---|---|
| `godot_mcp_toolkit` | NPGameDev | upstream terms | `LICENSE`, `ATTRIBUTIONS.md` | Verified, vendored intact |
| `proton_scatter` | HungryProton | MIT | `game/addons/proton_scatter/LICENSE(.md)` | Verified |
| `waterways` | Kasper Arnklit Frandsen | MIT | `game/addons/waterways/LICENSE.md` | Verified |
| `godai` | David Snopek | MIT | `game/addons/godai/LICENSE.txt` | Verified (secret scan: settings-key names only, no credentials) |
| `ez-tree-godot-port` | Daniel Greenheck | MIT | `game/addons/ez-tree-godot-port/LICENSE` | Verified |
| `afmi_godot` (Azgaar map importer) | RPGcraft | MIT | `game/addons/afmi_godot/LICENSE` | Verified |
| `godotiles` (disabled; native `bin/` NOT committed) | see receipt | Apache-2.0 / MIT dual | `game/addons/godotiles/LICENSE-APACHE`, `LICENSE-MIT` | Source verified; binaries excluded from git (32 MB) |
| `flatten_for_llm` | unknown | **none found** | — | **UNVERIFIED — no license file in the package; identify provenance before redistribution or removal** |
| `gopala_mcp` | Project | Project license | `game/addons/gopala_mcp/` | Project-authored |

## Interface art and audio

- HUD theme, palette, panels, icons: **project-authored** (`GopalaTheme`,
  `game/assets/ui/theme/`), except `crest.png`/`minimap_frame.png`/
  `action_bar_bg.jpg` — provenance recorded here when audited (Block 6).
- UI sounds: none yet (Block 6).
- No icon packs adopted yet. If adopted later: **Kenney UI Pack (CC0)** and
  **game-icons.net (CC BY 3.0, attribution required)** are the pre-approved
  candidates; each adoption must add a row here and to the credit screen.

## Reference-material policy

- *Farthest Frontier* (Crate Entertainment): information-architecture study of
  publicly documented UI/UX patterns only. **No texture, icon, wording, sound,
  distinctive panel shape, or pixel-identical layout may be copied.** No assets
  from that game exist in this repository.
- Blueprint reference document: `docs/Farthest Frontier–Inspired HUD UI Blueprint
  for Godot.md` (project-authored, cites official/primary sources).

## Commit hygiene (Block 0 policy)

The checkpoint `checkpoint/pre-hud @ 9be8893` intentionally excludes
third-party binary packs, `godotiles/bin/*`, `.freebuff/`, and
`reports/baseline/*`. Before any `git push`, re-review this ledger: items marked
**NOT committed** or **UNVERIFIED** require a decision (commit with terms,
replace, or remove) — the EmacEArt no-standalone-redistribution clause matters
most for a public remote.

## G1-11 selected downloaded models

KayKit Forest Nature (Kay Lousberg), Styloo Animals (Styloo cow only) and Highlands Fantasy Pack (VisionsMind hut/crate/barrel/fence/axe) are CC0-1.0. See [CREDITS.md](CREDITS.md) and the per-pack LICENSE.txt/RECEIPT.md/source-receipt.json files under game/assets/models/. No restricted or unknown-source pack was admitted. Highlands pieces are European-fantasy placeholders, not final Newari architecture.
