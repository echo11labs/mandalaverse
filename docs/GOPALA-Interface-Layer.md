# GOPALA — Interface layer

Implemented 2 October 2026. Replaces the placeholder HUD with a data-driven,
warm editorial interface. This is presentation only; no settlement economy is
implemented yet.

## Design direction

Chosen direction: **editorial luxury, warm**. Parchment paper plates with carbon
ink type, brass hairlines, and a dark ink band where text sits over the moving 3D
valley. Rationale: the interface is read against a landscape, so light plates give
figure-ground separation from terrain, while the top band stays dark because the
resource rail must stay legible over any part of the valley.

Rejected alternatives, for the record: tactical telemetry was too cold for the
subject; industrial Swiss print fights the landscape's colour; soft structuralism
reads as generic consumer software.

## Type and colour

| Role | Face | Source |
|---|---|---|
| Display / settlement name / panel titles | Fraunces (variable, `SOFT`+`WONK` engaged) | OFL-1.1, vendored |
| Interface body, buttons, tabs | Karla (variable) | OFL-1.1, vendored |
| Resource counts, coordinates | JetBrains Mono (variable) | OFL-1.1, vendored |
| Devanagari fallback | Noto Sans Devanagari (variable) | OFL-1.1, vendored |

Mono is not decoration. Resource counts sit in a rail that updates continuously,
and proportional digits make the whole row twitch on every tick; monospaced digits
hold the row still. A UI test asserts equal advance widths for `0` and `8`.

Palette lives in `GopalaTheme` as constants: `PAPER`, `INK`, `BRASS`, plus
`FOREST`/`RIVER`/`TERRA` for toast tones. Body text is `#1C1A18`, never pure black.

Fonts, licences, and rationale are recorded in
[UI font receipt](GOPALA-UI-Font-Receipt.md). The engine's `Theme` in this pinned
build uses three-argument setters where the first argument is the canonical item
name, so `GopalaTheme` sets `font`/`font_size`/`normal`/`panel` and anything
non-standard is applied per node.

## Composition

- **Double bezel.** Every group is a transparent shell (hairline + ambient lift,
  0.05 alpha) wrapping a paper or ink plate. The shell exists so the plate looks
  seated in a tray rather than pasted on the screen.
- **Hairline rules, not boxes.** Information groups are divided with 1 px
  `HSeparator` lines at 0.4 alpha.
- **Eyebrow tags.** Section labels are 10 px uppercase in brass at wide tracking.
- **Entry choreography.** HUD groups fade and rise 10 px on a 30 ms stagger.
  Only top-level groups animate; descending into containers would fight their
  layout, because a container re-sorts children every frame.

## Layout

| Region | Contents |
|---|---|
| Top band (ink) | Crest, eyebrow, settlement name, seven-goods resource rail, calendar, survey plate |
| Upper left (paper) | Valley summary, grid/names toggles, camera jumps, tempo controls |
| Right (ink, on demand) | Inspection: ground readout, territory summary, or one chiefdom |
| Bottom (paper) | Build detail card, category tabs, structure strip |
| Lower right (paper) | Zoom, turn, and the cancel-placement hint |
| Lower left | Toast stack |

Panels are anchored, so the layout holds at any window size. Decorative plates use
`MOUSE_FILTER_IGNORE` so terrain picking still works underneath; only buttons stop
the mouse. A UI test asserts this.

## Data binding

The interface reads the content catalogue rather than hardcoding:

- Resource rail is built from `data/catalog.json` → `GopalaResourceDefinition`,
  using each definition's own icon and `carry_units`.
- Structure strip is built from the six P0 `GopalaBuildingDefinition` entries plus
  the pasture `GopalaZoneDefinition`, showing authored footprint, `work_ticks`,
  and real material costs.
- Categories are a presentation mapping over stable IDs, so a new definition
  appears without editing the HUD.

## Minimap

`GopalaMinimap` is a schematic survey plate drawn from the same geography as the
3D scene: hillshade sampled from the elevation field, mapped rivers, the inferred
headwater distinguished in amber, the camp marker, and a brass frame showing exactly
what the camera covers. It reads `regions_gopala.json` for chiefdom seats. Cheaper
than a second render pass and stylistically consistent with the paper plates.

It degrades safely: an unloaded terrain draws blank paper instead of sampling past
the end of its arrays.

## Public surface

`GopalaKathmanduHud` keeps the surface `kathmandu_valley.gd` already used:
`valley_requested`, `source_requested`, `camp_requested`, `grid_changed`,
`names_changed`, `zoom_in/out_requested`, `turn_left/right_requested`, plus
`follow()`, `close_build()`, `set_grid()`, `set_names()`, `toggle_grid()`,
`toggle_names()`, `show_place()`, `show_territory()`, `show_chiefdom()`.

Added for the economy layer: `build_selected`, `speed_selected`,
`set_resource()`, `set_clock()`, `set_settlement_name()`, `notify()`.

Keyboard shortcuts now route through the HUD buttons so the plate and the world can
never disagree about whether the grid or labels are showing.

## Verification

`python3 tools/verify.py` runs `ui-tests` (`tests/run_ui_tests.gd`, 111 checks):
fonts load and measure real glyphs, digits are monospaced, licence receipts ship,
every button state has a style, plates stay warm, all seven goods have readouts,
all seven entries are offered, category filtering narrows the strip, choosing a
structure reports it and shows real costs, Escape cancels placement, inspection and
territory panels populate and close, every control is labelled or tooltipped, no
plate overflows the frame, and the minimap maps and degrades safely.

## Not claimed

No screenshot of the new HUD has been captured. Real-graphics capture requires a
display; headless capture hangs on `RenderingServer.frame_post_draw`, which matches
the existing limitation recorded in the landscape layer. Appearance must be judged
by running `python3 tools/godot.py` and looking at the screen. The automated suite
proves structure, binding, and layout bounds, not taste.

Pre-existing unrelated failure: `kathmandu-tests` still reports "Mesh matches ground
model". It fails identically on a clean checkout with no HUD changes, so it is not
caused by this work.