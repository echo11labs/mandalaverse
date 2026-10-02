# EZ-Tree Integration Plan for GOPALA

## Context

Two tree systems exist in the project:

| System | Type | Count | Use Case |
|--------|------|-------|----------|
| **ProtonScatter (current)** | External GLB models (PolyHavenFoliage, 16 variants) | 100,940 trees | Regional forest, biome-driven (elevation/slope), baked to `kathmandu_forest.scn` |
| **EZ-Tree (addon)** | Procedural meshes (EZTree + EZTreeDraw) | Unlimited, generated at runtime | Editor-painted forests, hero trees, procedural close-up detail |

The ProtonScatter system was just built and verified. EZ-Tree-Godot-Port is already installed at `game/addons/EZ-Tree-Godot-Port/`.

## Design Decisions Required

### 1. Role Split: What does each system own?

**Recommendation: Hybrid approach**

| Layer | System | Reason |
|-------|--------|--------|
| **Regional forest** (70m spacing, 100k trees) | **ProtonScatter** | Already baked, biome/elevation rules work, handles massive scale efficiently |
| **Detail forest** (18m spacing, ~8k trees) | **EZ-Tree via EZTreeDraw** | Procedural trees look better up close, wind sway shader works, no external assets needed |
| **Hero / landmark trees** | **EZ-Tree manual placement** | Unique memorable trees at temples, passes, viewpoints |

This keeps the verified ProtonScatter pipeline for the heavy lifting while upgrading the close-up experience where the current GLB models show their triangle budget limits.

### 2. Detail Layer Replacement Strategy

Replace the ProtonScatter "detail" candidate generation (18m spacing, ~8,300 trees) with an `EZTreeDraw` node painted over the detail extent.

**Implementation approach:**
- Keep `bake_forest.gd` regional generation (70m spacing) unchanged
- Remove the `detail` candidate generation from `bake_forest.gd`
- Add an `EZTreeDraw` node to `kathmandu_valley.tscn` covering the detail extent
- Paint trees in editor (or procedurally generate positions at runtime matching the detail grid)

**Open question:** Editor painting vs procedural runtime placement?
- **Editor painting** — Artistic control, saved in scene, but manual work for ~8k trees
- **Procedural at runtime** — Matches current detail grid exactly, but loses editor undo/redo and brush UX

**Recommendation:** Procedural at startup matching the detail grid, using EZTreeDraw's API (`paint_at`) programmatically. Best of both: deterministic, no manual labor, uses the same MultiMesh rendering.

### 3. Tree Templates for Kathmandu Valley

Need EZTree parameter sets matching local species:
- **Chir Pine (Pinus roxburghii)** — evergreen, 15–25m, conical, common 1200–2000m
- **Blue Pine (Pinus wallichiana)** — evergreen, 20–35m, longer needles, 2000–3500m
- **Himalayan Oak (Quercus semecarpifolia)** — evergreen broadleaf, 15–25m, 2000–3000m
- **Rhododendron** — broadleaf, 5–15m, understory, 2500–4000m
- **Alder (Alnus nepalensis)** — deciduous broadleaf, 10–20m, riparian

Each needs an `EZTree` parameter set (seed, branch angles, lengths, radii, leaf count/size). Can derive from the existing GLB model measurements.

### 4. Wind System Integration

EZ-Tree has its own leaf wind shader (`leaf_wind.gdshader`) driven by `TIME`. The current ProtonScatter trees have no wind. Two options:
- **Add wind to ProtonScatter trees** — Requires modifying their materials to use a similar vertex shader
- **Accept different wind behavior** — EZ-Tree trees sway, ProtonScatter trees static (acceptable if layers are visually separated by distance)

**Recommendation:** Accept difference for now; regional forest at 70m+ is too far for wind to be noticeable.

### 5. Asset Pipeline & Review Gate

Current review gate (`game/data/forest/review.json`) only covers ProtonScatter bake. EZ-Tree trees:
- Don't need external assets (procedural)
- Don't need a bake step
- Are configured via scene/editor

**No changes to review.json needed.** EZ-Tree is code + editor config, not an external asset pack.

---

## Implementation Plan

### Phase 1: EZTree Parameter Library (1-2 days)
Create `game/data/forest/ez_tree_profiles.json` with parameter sets for 5 local species. Each entry:
```json
{
  "id": "chir_pine",
  "name": "Chir Pine",
  "tree_type": "EVERGREEN",
  "rng_seed": 1001,
  "branch_levels": 3,
  "branch_length": [12, 3, 2, 1],
  "branch_radius": [0.5, 0.85, 0.6, 0.5],
  "branch_angle": [0, 50, 45, 30],
  "branch_children": [6, 4, 3, 0],
  "branch_length": [...],
  "branch_segments": [8, 5, 3, 3],
  "leaf_count": 25,
  "leaf_size": 0.4,
  "leaf_angle": 35,
  "wind_enabled": true,
  "wind_strength": [0.2, 0, 0.2],
  "wind_frequency": 0.4,
  "wind_scale": 25.0
}
```

### Phase 2: Detail Layer Replacement (2-3 days)
1. Modify `bake_forest.gd` — remove `detail` candidate generation, keep only `regional`
2. Add `EZTreeDraw` node to `kathmandu_valley.tscn` as child of terrain
3. At runtime (in `kathmandu_valley.gd` `_ready`):
   - Load profiles from `ez_tree_profiles.json`
   - Create `EZTree` template for each species
   - Generate detail grid positions (same 18m spacing, same detail extent/center)
   - For each position, pick species by elevation/biome rules (reuse `GopalaForestRules`)
   - Call `EZTreeDraw.paint_at()` for each
   - This generates MultiMesh instances per species variant at runtime

### Phase 3: Hero Tree Placement (1 day)
Add a second `EZTreeDraw` node (or manual `EZTree` instances) for hand-placed landmark trees at:
- Swayambhu hilltop
- Pashupati terrace
- Kirtipur ridge viewpoints
- Passes (Phulchowki, Chandragiri)

Use `EZTreeDraw` in editor with Tool Mode = DRAW for artistic placement, or instantiate `EZTree` directly for precise positioning.

### Phase 4: Visual Polish (1 day)
- Ensure EZTree leaf texture reads correctly on the valley terrain lighting
- Tune wind parameters per species (pines stiffer, broadleaf softer)
- Verify LOD behavior — EZTreeDraw creates one MultiMesh per variant; consider adding a distance-based culling or impostor swap for far instances (though detail layer is only 18m spacing, so all are relatively close)

---

## Files to Create/Modify

| File | Change |
|------|--------|
| `game/data/forest/ez_tree_profiles.json` | **NEW** — Species parameter library |
| `game/core/tools/bake_forest.gd` | Remove detail candidate generation |
| `game/scenes/landscape/kathmandu_valley.gd` | Add runtime detail forest generation using EZTreeDraw |
| `game/scenes/landscape/kathmandu_valley.tscn` | Add EZTreeDraw node + EZTree templates |
| `game/data/forest/models.json` | Add note that detail layer moved to EZ-Tree |
| `docs/GOPALA-Forest.md` | **NEW** — Document the hybrid forest architecture |

---

## Validation Checklist

- [ ] ProtonScatter regional bake still works (unchanged)
- [ ] EZTreeDraw generates trees at correct detail grid positions
- [ ] Species selection by elevation matches ProtonScatter biome rules
- [ ] Tree heights respect configured min/max per species
- [ ] Wind sway visible and performant at 60fps with ~8k detail trees
- [ ] No visual seam between regional (ProtonScatter) and detail (EZ-Tree) layers
- [ ] Memory/frame time within budget (target < 16ms frame on M4 Pro)
- [ ] `python3 tools/verify.py` passes (forest-tests should still pass for regional)

---

## Open Questions for User

1. **Confirm the hybrid split** — Regional=ProtonScatter, Detail=EZ-Tree, Heroes=manual?
2. **Editor painting vs procedural for detail layer** — I recommend procedural (deterministic, matches existing grid). Any reason to prefer manual painting?
3. **Species list** — Are the 5 proposed species correct for Kathmandu Valley? Any missing/incorrect?
4. **Wind parity** — Accept that only EZ-Tree trees sway? Or add wind to ProtonScatter materials too?
5. **Review gate** — Confirm no review.json changes needed for procedural trees.
6. **Timeline priority** — Which phase first? (Profiles → Detail replacement → Heroes → Polish)