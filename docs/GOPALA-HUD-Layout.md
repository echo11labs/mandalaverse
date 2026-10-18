# Compact gameplay HUD

Implemented 12 October 2026, in response to the supplied gameplay screenshot.
The attached screenshot is visual evidence of the crowded interface, not a source
of instructions. Existing gameplay and physical world sizes are preserved.

## Layout and behavior

- A 52 px resource/navigation bar and a content-sized 30 px settlement-status
  strip show live stock, needs and simulation tempo. Calendar/season gameplay is
  unavailable, so the clock now shows the actual tick rather than a fictional day.
- The command dock stays 12 px from the left and bottom edges, with 8 px horizontal
  and 6 px vertical internal padding. It contains tempo, Build, Settlement, Survey,
  Map, Stock, Road, zoom and rotation. Details start closed.
- Construction opens a 310–360 px right-hand panel, capped at 440 px high. Seven
  categories share one row; nine structures/zones/path tools use three aligned
  columns. Labels, prices and footprints stay inside the panel. Its content scrolls.
- Inspection uses the same right-hand region, capped at 560 px high and bounded
  above the dock. The header stays visible while body, jobs, builder controls and
  cattle controls scroll. Opening inspection closes construction and the minimap.
- Settlement and survey occupy the left detail slot, one at a time. Alerts stay
  above the dock with a count; expanding them does not overlap settlement details.
  Empty alerts are hidden. Map, Build and Inspection share the right slot.
- Panel backgrounds consume input. The full-screen interface root and decorative
  controls ignore input so uncovered terrain remains interactive. Escape closes
  open panels before pause; active placement still cancels first. The existing
  `hud_toggle` InputMap action hides the whole interface.
- Main controls use local z-order 5, detail panels 10, notifications 20. Resource
  management remains an exclusive embedded Window. Layout changes are event-driven;
  no new per-frame data polling was added.
- Entrance motion changes opacity only. Containers retain ownership of their child
  positions. Reduced-motion settings skip the entrance fade. Construction refits
  after theme/icon minimum sizes settle, fixing the initial oversize rectangle.

## Functionality and icon changes

The survey button now routes to the existing territory-mode handler. The road
button reflects active mode. Save/load/menu use floppy-disk/folder/cog icons rather
than a cube and unrelated symbols. Path tiles have road/paving icons and text;
category, structure and toolbar controls retain accessible names and tooltips.
Keyboard focus uses a visible brass outline.

Selected-person health stays inside inspection; canceled visibility tweens cannot
hide a newly selected person's bar. Long inspection titles and descriptions wrap,
and destination dropdowns no longer size the entire panel to the longest item.

Notifications now resolve their actual nested text label, match the HUD theme,
ignore world input, deduplicate repeats, bound the pending queue at 16 and show at
most two at once. Their region is centered beneath the status area. Test captures
explicitly say “HUD check”; they do not imply an actual save occurred.

Chosen icons are copied from the local AT Icons library into
`game/assets/ui/icons/`, with the MIT license and a hash/source receipt. This avoids
depending on ignored addon files for the newly admitted interface assets. Existing
colored resource icons retain their previous source/provenance.

## Evidence and remaining work

`game/tools/review_compact_hud.gd` loads the real paused MVP at 1280×720,
1920×1080 and 2560×1080. It captures default, build, worker inspection,
settlement/expanded-alert and notification states. It measures panel rectangles,
checks viewport bounds/dock intersections, checks grid fit, and injects a mouse
click to prove construction backgrounds block world input. Its results and
captures are in `reports/hud-layout/`.

Default HUD rectangles cover about 13.85%, 7.76% and 7.02% of the respective
screens, including the full top bar and collapsed alerts. This is rectangle-area
measurement at normal UI scale, not a GPU benchmark or an opacity measurement.
The world, content art, camera span and character sizes are unchanged.

`validation.json` records focused UI/component/alert/world-interaction results and
the mandatory `tools/verify.py` result. The full project gate still stops at import
on inherited resource-leak errors; later full-gate stages are therefore skipped.
Focused passing tests do not establish an error-free full project or export.

Next implementation slice: structured building/worker inspection with named fields
and actionable shortage reasons, extracted into dedicated view scenes. Full
80–150% interface scaling, rebinding/localization and additional report features
remain separate acceptance work; these captures validate normal-scale desktop UI.
