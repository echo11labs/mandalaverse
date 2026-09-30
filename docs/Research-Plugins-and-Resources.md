# Research: Plugins and Resources for GOPALA Transition (2D Isometric Look in 3D)

To transition from the current macroscopic 3D Kathmandu Valley (`village3.png`) to the highly detailed, isometric city-builder aesthetic (`village1.png`), we need tools that help rapidly place objects and construct natural features like rivers, while maintaining the fixed orthographic camera perspective.

Here are the best free resources and plugins tailored for Godot 4 and the GOPALA project constraints:

## 1. Environment & River Plugins

### **Waterways (Godot 4 Port)**
*   **Overview:** The most popular river generation tool for Godot. It uses Bezier curves to generate flowing water meshes.
*   **Pros:** High quality, integrated flow maps, easy curve-based editing.
*   **Cons:** The official version is for Godot 3. The Godot 4 port (`Tshmofen/waterways-net`) requires .NET/C# support, which conflicts with our pinned **Godot 4.7.2 Standard** build.
*   **Our Solution (Faster Mode):** Instead of fighting compatibility and strict `verify.py` error checks with large plugins, we will implement a lightweight, native `Path3D`-based river mesh generator in GDScript (`RiverPath3D.gd`) paired with a custom shader. This provides the exact same curve-based workflow without the plugin overhead.

### **Scatter Plugins (for Trees, Rocks, Props)**
*   **ProtonScatter (by HungryProton):** The most feature-rich scattering tool, allowing procedural generation of forests and props using a modifier stack.
*   **ScatterBox:** A lighter alternative that uses standard `MeshInstance3D` nodes instead of `MultiMesh`, better for interactive objects but worse for massive forests.
*   **Our Recommendation:** We will implement scattering using Godot's built-in `MultiMeshInstance3D` or adopt a very lightweight GDScript scatter script. Large third-party scatter plugins frequently throw internal Godot editor errors which will cause our strict `verify.py` gate to fail.

## 2. Free 3D Modular Resources (CC0)

To achieve the look of `village1.png` quickly, we need modular, low-poly, textured assets that look good from an orthographic angle. **Kenney.nl** offers the best CC0 (public domain) assets that fit this perfectly.

*   **Kenney Nature Kit:** Over 330+ models including trees, rocks, cliffs, and vegetation. Perfect for the valley's base environment.
*   **Kenney Fantasy Town Kit:** 160+ modular pieces for medieval/fantasy buildings, paths, and docks.
*   **Kenney Survival Kit:** Great for early settlement props (campfires, logs, crude shelters).

**Licensing:** All Kenney assets are Public Domain (CC0). They can be used commercially without attribution, fitting perfectly into `game/assets/prototype` for our rapid development phases.

## 3. Action Plan for `/goal`

To fulfill the goal of developing in "faster mode" while respecting the project's strict verification gates:
1.  **Lightweight Tools:** Create a custom `RiverPath3D` GDScript tool that leverages Godot's built-in `CSGPolygon3D` or procedural `ArrayMesh` along a path, complete with a flowing water shader.
2.  **Asset Integration:** Document the pipeline for pulling Kenney's 3D kits into the `game/assets/prototype/` folder so artists and level designers can immediately begin drag-and-drop construction of the settlement.
3.  **Verification:** Ensure all new scripts and assets pass the `python3 tools/verify.py` test suite with zero engine errors.
