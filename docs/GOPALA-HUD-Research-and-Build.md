# Farthest Frontier patterns and a Godot implementation for GOPALA

Research date: 12 October 2026. Scope: desktop settlement UI, interaction architecture,
visual treatment, Godot implementation choices, and an initial working slice.
This is a fresh execution plan for the user's requested HUD work. The development
Vedas remain gameplay scope authority. Existing economic state and inherited work
are preserved. This document does not claim Farthest Frontier's private UI code or
engine architecture is known: its public guide establishes observable behavior.

## What Farthest Frontier does

The top HUD groups people and provisions, season/weather, and critical resources.
The bottom-right tools provide building, harvesting, roads and other world actions;
speed controls occupy the bottom-left. Shortcuts supplement visible controls, and
world widgets and the interface can be toggled. The useful pattern is stable
locations for frequent decisions with detail on demand. GOPALA should retain its
own bindings: copying Farthest Frontier's R would conflict with GOPALA's road key.
[Crate: Basics](https://www.farthestfrontier.com/guide/about/basics/).

Its building catalogue groups structures by purpose and exposes prerequisites.
Building inspection includes work area, worker slots and production. Placement
and operation therefore have distinct interfaces. For GOPALA, catalogue entries
must derive footprint and price from definitions; inspection must derive current
jobs and delivered materials from runtime snapshots. A selected building should
explain why it cannot work and offer an applicable command.
[Crate: Buildings](https://www.farthestfrontier.com/guide/gameplay/buildings/).

Resource management is deeper than the persistent counters. The summary includes
goods the town does not yet possess; selecting a good reveals production and
usage relationships. Storage buildings also expose distribution limits. GOPALA's
first slice uses its admitted resource definitions and construction costs; store
limits require actual transport support before the interface offers them.
[Crate: Resources](https://www.farthestfrontier.com/guide/gameplay/resources/).

Professions provide aggregate control over workforce allocations, with laborers
and builders forming an important shared pool. GOPALA currently offers individual
worker jobs. A population panel can first summarize real roles; aggregate changes
must call a validated assignment service rather than rewriting worker records.
[Crate: Population](https://www.farthestfrontier.com/guide/villagers/population/).

The annual report gives production, consumption, losses and population history,
with selectable categories and resources. This is a historical diagnostic tool,
not an alternative stock counter. GOPALA needs an economic event/history recorder
before it can show equivalent graphs. Balance deltas alone would conflate
consumption, construction and transfers.
[Crate: Annual Report](https://www.farthestfrontier.com/guide/information/annual-report/).

Overlays answer spatial questions: desirability, fertility, water and deposits.
Some appear in relation to a placement task. GOPALA should eventually show grazing
support for pasture placement and legal ground/access for structures. Each overlay
needs a legend and authoritative data; decorative terrain shading cannot stand
in for simulated fertility.
[Crate: Overlays](https://www.farthestfrontier.com/guide/information/overlays/).

### Visual interpretation

The official top-bar reference images show dark framed surfaces, icon-led numeric
readouts and compact clusters. This is a visual interpretation, not a measurement
of the latest executable. The guide's images include older material and are not a
complete audit of every current patch or resolution.
[People/status reference](https://www.farthestfrontier.com/wp-content/uploads/sites/2/2022/02/UI-TopBar-01.jpg),
[Resource reference](https://www.farthestfrontier.com/wp-content/uploads/sites/2/2022/02/UI-TopBar-03.jpg).

For GOPALA: keep the existing warm charcoal/brass palette and licensed fonts.
Use restrained borders, consistent padding, a clear title/body/data hierarchy,
and original Nepal-informed ornament only after visual review. Avoid copying
Crate's art. Counters should remain steady and immediately accurate. Reserve
motion for panel transitions and meaningful alerts. Health belongs to the selected
person; a generic score has no defined settlement meaning.

## Which Godot approach to use

| Approach | Use in GOPALA | Tradeoff |
|---|---|---|
| Native Control scenes and Containers | Default for panels, buttons, search, inspector and toolbar | Good focus/input/localization support; requires deliberate minimum sizes |
| Script-built Control components | Catalogue-generated rows and binding logic | Fast for data-driven content; long monolithic builders become hard to inspect |
| Shared Theme with StyleBoxFlat | Current implementation and layout validation | Cheap to iterate, crisp; needs authored artwork for ornamental identity |
| StyleBoxTexture / nine-slice artwork | Final frames and decorative panel borders | Preserves corners during resize; requires original texture assets and margin tuning |
| Custom drawing | Minimap, compact charts and pooled world markers | Efficient for many marks; custom input and accessibility require extra work |
| Tree / ItemList | Larger population/resource tables | Useful built-in selection/columns; bespoke row controls may be easier for a small list |
| SubViewport | Only when a minimap or preview actually needs another render | Additional rendering cost; unnecessary for logical map markers |
| Third-party UI framework or web overlay | No new dependency for this slice | Evaluate only against a proven missing capability; integration and styling have costs |

Godot Containers own child layout. Anchors should place top-level regions; margins,
box/grid containers and scroll containers should arrange their contents. Do not
animate positions of container-owned children. These choices are based on
[Godot: Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html).

A Theme propagates styling through Control branches and supports type variations.
Put fonts, button states, spacing tokens and focus rings in one common theme;
limit local overrides to genuine component differences. CanvasLayer itself does
not provide Control theme inheritance, so its interface root needs the theme.
[Godot: Themes](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html),
[Godot: CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html).

Nine-slice StyleBoxTexture preserves frame corners while the center/edges stretch
or tile. Use it when adding authored frames, instead of scaling a whole painted
window. Native Tree supports hierarchical items and multiple columns; it is an
option for later tables, not evidence of automatic virtualization.
[Godot: StyleBoxTexture](https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html),
[Godot: Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html).

For the 3D game, scale HUD and world resolution deliberately. Canvas-items scaling
can preserve sharp UI while 3D resolution is adjusted independently. Include a
user scale setting; scale padding, icons and hit targets with text. Test compact
layouts and cap/scroll windows. GOPALA's existing text-only scaling is insufficient
as the final system. This slice clamps the management window to the viewport;
it does not claim to solve scaling throughout the legacy HUD.
[Godot: Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

World actions belong in unhandled input, after GUI consumption. Interactive
surfaces consume mouse events; decorations ignore them. Shortcut handling uses
InputMap actions and avoids triggering while text editing. Exclusive embedded
windows are useful for management dialogs. Escape must close the topmost window
before canceling tools or opening pause, and focus must return safely.
[Godot: Input propagation](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html).

## A maintainable architecture

```text
Simulation -> immutable snapshot -> presentation adapter -> persistent controls
Control action -> typed command -> simulation validation -> result -> UI feedback

HUD CanvasLayer
  Interface root + shared theme
    Status/resource rail
    Tool dock
    Inspection panel (selected entity only)
    Alert feed + bounded notifications
  ResourceOverview (exclusive management window)
```

Each feature owns one view and its local signals. The existing HUD public methods
remain an adapter while components move out of the large builder. New views
receive plain data or immutable definitions, never authoritative service internals.
Update only changed text/rows; preserve selection and focus. Do not rebuild the
whole tree each tick. Cache expensive entity queries per simulation sequence.
Pool and cull world badges. Benchmark representative populations before claiming
performance. These are engineering recommendations, not inferred Crate internals.

## Initial implementation

- Resource counters open a dedicated catalogue-driven resource window. M uses the
  existing `management_toggle` action. R retains its road behavior.
- All seven goods appear, including zero balances; rows update through the existing
  `set_resource` snapshot adapter. Search, current stock, carry capacity and actual
  construction uses are available. Definitions remain read-only.
- The window is exclusive, scrolls internally, clamps to the viewport, focuses
  search on open and restores the previous valid focus on close.
- The malformed duplicate HUD scene tree is replaced with its actual script-owned
  root. Gameplay no longer spawns generic score, damage-number or interaction
  prompt fixtures. Selected-person health is placed inside inspection and uses a
  native ProgressBar, so it does not depend on missing textures.
- Notification delivery has one scene owner; optional legacy bus resolution is
  runtime-safe. Reusable fixture scripts remain available.

The current snapshot exposes balances, not reservation partitions. No reserved,
available, production-rate or historical totals are fabricated. The window is a
resource overview, not complete storage management or an annual report.

## Build order with concrete acceptance

| Order | Deliverable | Acceptance |
|---|---|---|
| 1 (built) | Resource overview and HUD load repair | Live balances, catalogue uses, filter, bounded window, input interception |
| 2 | Extract status rail and bottom tool dock into scenes | Critical settlement metrics visible; every control works; no panel collisions at 720p |
| 3 | Structured building/worker inspection | State, shortages, material progress and valid actions; stale selection safely clears |
| 4 | Population/workforce summary | Roles and availability match snapshots; assignments go through real commands |
| 5 | Unified alerts and relevant placement overlays | Deduplicated severity, actionable focus, legends and actual data |
| 6 | Original final skin, full scaling and localization | Focus/contrast, Nepali glyphs, 80–150% scaling, ultrawide/4K captures |
| 7 | Economic history and reports | Correct categorized events across save/load; meaningful production/consumption graphs |

Each slice ends with a working game path, behavioral checks and a rendered receipt.
One feature is implemented through acceptance before starting the next. No new
task-queue machinery or mock gameplay dashboards are required for this plan.

## Verification and limits

See `reports/hud-research/validation.json` for actual results and rendered captures.
`tools/verify.py` is still mandatory. The inherited import currently stops the full
gate on leaked-resource errors; warnings also include case-mismatched demo script
paths. Focused UI results do not imply a clean repository, exported acceptance,
GPU performance or human art approval. The report must name any skipped gates.

## Compact layout continuation

The second implementation slice is recorded in [Compact gameplay HUD](GOPALA-HUD-Layout.md).
Startup details are now closed, commands share a bottom dock, and construction/inspection
share a bounded right-hand slot. Rendered state/interaction checks and current captures
are in `reports/hud-layout/`; earlier `hud-research` images remain first-slice evidence.
Structured inspection fields and component extraction remain the next slice.
