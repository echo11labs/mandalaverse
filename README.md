# GOPALA — Dawn of the Valley

A Nepali-themed settlement game in development with Godot, inspired by the accessible economy and village management of Townsmen 6 Premium.

## Project planning

- [2D Godot Development Vedas](docs/GOPALA-2D-Development-Vedas.md): design direction, original-plan conversion, scope, architecture, researched resources, timeline, and verification gates.
- [Implementation Backlog](docs/GOPALA-Implementation-Backlog.md): ordered work items, dependencies, and concrete acceptance conditions.
- [Interface layer](docs/GOPALA-Interface-Layer.md): the HUD design direction, composition, data binding, and its verification.
- [Kala — 2D Art and Camera Direction](docs/GOPALA-Kala-2D-Art-Direction.md): practical application of the supplied top-down-world transcript to GOPALA's style test, visibility, atmosphere, and camera controls.
- [Yantra — Farming Tutorial Adaptation](docs/GOPALA-Yantra-Farming-Tutorial-Adaptation.md): all 25 chapters mapped to milestones, with changes needed for worker jobs, hauling, cattle, crops, save/load, and presentation.

Current status: pinned Godot project, typed prototype content and verified tooling are implemented. The interactive landscape now uses Kathmandu Valley elevation and mapped rivers, with an orthographic management view, downstream animation, camera controls, a local planning grid and ground inspection. The interface layer has been rebuilt as a warm editorial HUD bound to the content catalogue: a resource rail, structure strip, inspection and chiefdom panels, a schematic survey minimap, and tempo controls. Historical interpretation and uncertain headwaters are documented separately. Village construction and economy are the next layers; they are not implemented yet. Existing root PNG files remain concept references.

Run `python3 tools/godot.py` to explore the valley. Scroll to zoom, middle-drag or WASD to pan, and click ground to inspect. Use “Bagdwar” for the mapped source landmark and “Local ground” for the prototype settlement area. `G` toggles the planning grid, `N` the place names, `F` the chiefdom survey, and `Esc` cancels placement.

- [Landscape layer](docs/GOPALA-Landscape-Layer.md): delivered scene, acceptance evidence and next layer.
- [Toolchain](docs/GOPALA-Toolchain.md): pinned tools, verification and limitations.
- [Asset pipeline](docs/GOPALA-Asset-Pipeline.md): provenance and production review.

First implementation milestone: gather resources, reserve materials, carry them to a site, complete a dwelling, and save/reload the result. The first functioning settlement then adds food, water, and basic cattle.

Current geographic update: the default scene now uses Kathmandu Valley elevation and mapped river courses. See [Kathmandu geography and historical interpretation](docs/GOPALA-Kathmandu-Geography.md) for source accuracy, the separately marked headwater estimate, scale, rights and verification. The earlier invented valley remains a diagnostic scene.
