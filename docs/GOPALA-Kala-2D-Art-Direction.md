# GOPALA — Kala

## 2D Art and Camera Direction

Prepared 29 September 2026. Companion to [Development Vedas](GOPALA-2D-Development-Vedas.md). Design specification only; no art or Godot implementation has been produced by this update.

Basis: the user-supplied transcript of Eastshade Studios' [Making Beautiful Top-down Worlds](https://www.youtube.com/watch?v=JPQ2NVwm1Xk). The timestamped lessons below are paraphrased from that transcript. The GOPALA applications and acceptance criteria are our proposed design choices, not claims made by the video.

**Treat the settlement as a living illustration built for one viewing direction. Keep its economy, routes, and selection understandable while adding atmosphere.**

## 1. Camera and projection contract

Fixed orientation means the viewpoint never rotates. The player can still pan and zoom over the valley. Our 2D camera does not acquire a 3D tilt; the view angle is drawn into terrain and sprites.

Retain the proposed 2:1 diamond ground projection. Buildings, props, and characters must use a compatible projection and ground scale. Do not mix it casually with a different angle just because the source game's art pipeline uses one.

Validate a 128×64 ground tile with one worker and one dwelling before locking dimensions. Record reference images at three views: close inspection, ordinary management, and overview. Support a bounded zoom range chosen from those readability tests. UI text stays at its own readable scale.

One viewing direction does not require one building orientation. For the first release, author a small number of approved orientations with matching footprints and entrance positions. Do not expose free rotation without the necessary sprite views. Mirroring must not accidentally move an entrance while leaving its simulation access cell unchanged.

## 2. Translate each lesson into a production decision

| Transcript point | GOPALA application | Boundary |
|---|---|---|
| 00:56–02:57: compose for the viewpoint | Spend art effort on visible roof, facade, silhouette, and working area | Avoid producing unseen back views or interiors for the initial release |
| 03:16–04:12: design assets for their angle | Give dwelling, stockpile, and cattle shelter different silhouettes; make entrances readable | Fine detail cannot substitute for a recognizable function at management zoom |
| 04:12–04:46: prevent hidden movement | Use visible terrain boundaries where appropriate; fade roofs/canopies or outline inspected workers when necessary | Invisible walls around freely placed buildings would undermine hauling and player layout choices |
| 04:54–05:39: camera magnets | Offer an optional focus action for a milestone, arrival, or weather warning | Camera motion is cancellable; ordinary management retains direct player control |
| 05:39–05:58: stable orientation helps navigation | Organize the map around a river bend, meadow, grove, and clear village center | A minimap remains available later if settlement management needs it |
| 06:04–07:13: perspective and scale illusions | Paint distant hills and soften decorative map boundaries with atmospheric layers | Keep playable tiles, movement distances, and character sizes consistent |
| 07:13–07:38: projected texture meshes | Learn the general principle of making art for its final view | The sprite release does not require projected 3D meshes or a new rendering pipeline |
| 07:42–08:15: lighting overlays | Use restrained gradients, ground shadows, hearth glows, and drifting mist | Critical stock, paths, entrances, and status must remain readable |
| 10:21–12:17: choose mechanics for their purpose | Borrow construction, jobs, and storage because they support community logistics | Avoid avatar-specific bedtime resets; worker rest and changing daylight can still serve the economy |

The video's reported production savings describe that studio's experience. They are not a guaranteed multiplier for GOPALA. Creating consistent animation, testing many player-built layouts, and maintaining readable logistics remain real work.

## 3. The first style test

Create one small scene containing a river edge, meadow, woodland corner, dwelling, stockpile, cattle shelter, villager, and cow. Reuse the existing M0 style-test milestone; this does not add a separate release phase.

**Palette:** earth and ochre for structures, straw gold for roofing, muted green for vegetation, cooler restrained river colors. Use brightness, outline, and silhouette to distinguish interaction states; color alone is insufficient.

**Building identity:** a dwelling reads as an enclosed home; stockpiles reveal their stored material shapes; cattle shelters show an open working edge and a clear enclosure entrance. Containers and tools belong to a shared scale. Props stay decorative unless a gameplay system needs them.

**Density:** cluster small decorations near buildings and groves; leave routes and work areas visually open. The player should see a carrier and identify its destination without decorative foliage overwhelming the scene.

**Variations:** derive a few dwelling variants from shared roof/wall elements after the base version passes. Keep their footprint and operating behavior consistent. Unique art for every instance is unnecessary.

**Historical direction:** use the roadmap's early Gopala-inspired materials and research process. A large landscape landmark can be a river bend, rock outcrop, or grove. Do not depend on an elaborate monument to establish Nepali identity before its period suitability has been reviewed.

## 4. Godot presentation structure

Use the existing simulation/view separation. The following is a proposed scene organization, not completed code:

```text
WorldView
  GroundLayers             terrain, water, paths, field markings
  SortedWorld              ground-anchored buildings, trees, villagers, cattle
  Atmosphere               restrained world-space mist/light decoration
  SelectionAndPlacement    clear footprint and selection presentation
  Camera2D                 player pan/zoom, fixed orientation
HUD                        screen-space controls and text
```

Place each object's visual anchor at ground contact. Keep compatible Y-sort and Z-index settings for objects that must interleave. Oversized roofs and canopies may need separate visual pieces: one pivot cannot represent every overlap of a large structure.

Terrain silhouettes, building footprints, navigation obstacles, and selection shapes should describe the same space. Shadows and decorative effects must not imply an impassable route when the simulation permits travel. Fog and light overlays ignore pointer input; selection and placement feedback remain visible above them.

Decorative mountains belong beyond the playable boundary. Treat that boundary honestly: players should not mistake painted distant fields for buildable land. Avoid parallax on the interactive ground or buildings, because it would separate their apparent positions from grid cells.

## 5. Visibility and camera behavior

When a selected worker or essential entrance is occluded, temporarily fade the covering visual or show a restrained outline. Test this with adjacent player-built structures, not only the carefully composed demonstration scene.

The focus camera is optional. A notification can offer “View arrival” or “View affected fields.” Selecting it moves to the subject using the current fixed orientation; dragging, zooming, or canceling immediately returns control. Important information also appears in the HUD, so camera movement is never the only way to understand an event.

For night, reduce world brightness moderately and retain readable work areas and icons. Rest is a villager task governed by simulation rules. There is no automatic settlement reset or requirement for the player to put an avatar to bed.

## 6. Acceptance before expanding the art set

- At normal management zoom, a viewer distinguishes all three prototype structures without labels.
- A worker remains inspectable while passing behind the dwelling and grove.
- Building entrance, legal access route, and placement footprint agree at every tested zoom.
- An adjacent-building arrangement and a dense cluster remain selectable and navigable.
- Selection, invalid placement, and warnings remain legible during rain, mist, and night.
- Camera focusing is optional and immediately interruptible.
- Terrain, building, character, and prop projections agree; footprints do not drift under zoom.
- An overview communicates woodland, river, settlement, fields, and pasture through visual grouping.
- Representative touch controls remain usable on the small layout already planned for M0/M4.
- A populated scene meets the roadmap's measured performance target with atmosphere enabled.

Approve the visual contract after these checks. Then expand building variants, construction states, animals, and crops using the same scale and lighting rules.
