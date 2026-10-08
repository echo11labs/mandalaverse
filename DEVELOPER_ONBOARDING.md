# GOPALA - Developer Onboarding & Project Status

Welcome to the GOPALA project! This document serves as a master reference to help new developers understand the current state of the project, the repository structure, and the immediate development roadmap.

## 1. Project Overview & Status

**Current Phase:** Foundation & Landscape implementation (M0 to M1 transition).
**Status:** **GREEN (All automated tests passing)**

We have recently completed the core mechanics for **Block 5C** (Resource Gathering) and **Block 5D** (Blueprint Delivery and Construction). The game engine successfully processes our authoritative simulation tick, entity placement, and basic villager automation.

* **Automated Logic:** Passing (`tools/verify.py` reports 100% success on the headless test suite).
* **Live Visual/Input:** Currently being verified by the user in the live Godot editor. A recent input-timing bug related to the HUD (`_placement_active`) was just patched and stabilized.

## 2. Directory Structure

The project follows a strict separation between the core simulation layer and the Godot presentation layer.

* **`game/`**: The primary Godot project directory.
  * **`core/`**: The authoritative, headless game simulation logic (written in GDScript). This logic is deterministic and decoupled from the 3D scene.
    * `simulation/`: Core game loop, command queue, state snapshots, and entity services.
    * `construction/`: Blueprint placement, grid validation, and building logic.
  * **`scenes/`**: Godot presentation layer (nodes, 3D meshes, UI).
    * `landscape/`: Contains `kathmandu_valley.tscn/gd`, which handles the 3D rendering of the world, terrain generation, and visual sync with the simulation.
    * `ui/`: HUD and interface components.
  * **`tests/`**: A robust suite of headless simulation tests. Run these constantly using the verification tool.
  * **`data/`**: Configuration, definitions, and authored scenario files.
  * **`assets/`**: Images, models, and materials (must follow strict asset pipeline rules).
* **`docs/`**: Master project documentation.
  * `GOPALA-Implementation-Backlog.md`: The definitive project scope and task list (G-001 through G-030).
  * `GOPALA-2D-Development-Vedas.md`: Core architectural principles.
* **`tools/`**: Automation scripts, custom Godot builds, and the project verification script (`verify.py`).
* **`skills/`**: Agent/AI skills and toolchain integrations (e.g., Godot MCP toolkit).

## 3. What is Working / Completed

The following systems are implemented and functioning:

* **Project Setup (G-001, G-002):** Headless test suite, typed content registry, and entity ID allocation are stable.
* **Terrain & Coordinates (G-003):** 3D terrain generation from heightmaps, lakes, rivers, and coordinate mapping to the simulation grid.
* **Camera & HUD (G-004):** Pan/zoom camera, entity selection, inspection panels, resource ledger UI, and placement cancellation.
* **Authoritative Simulation Loop (G-006):** Fixed-tick simulation updates with a command queue.
* **Resource Gathering (Block 5C):** Villagers can be assigned to gather timber from a source. They will extract the resource, display a "carry visual", and deposit it in the camp ledger.
* **Blueprint Delivery & Construction (Block 5D):** 
  * Buildings can be placed as blueprints on valid terrain.
  * Villagers can be assigned to construction tasks via the HUD.
  * Construction flows through precise states: `BLUEPRINT` → `WAITING_FOR_MATERIALS` → `DELIVERING_MATERIALS` → `READY_FOR_LABOR` → `UNDER_CONSTRUCTION` → `COMPLETED`.
  * Visuals scale dynamically as work completes.

## 4. What is Failing / Needs Immediate Attention

* **Nothing is currently "failing"** in the automated test suite. 
* *However*, the live physical visual tests (Gathering, Direct Movement, Pause/Speed scaling, UI responsiveness) are actively being audited by human testers. Based on these manual tests, adjustments may be required to the 3D representation layer.
