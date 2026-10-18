# GOPALA MVP Build Plan

## Active Block Discipline

We maintain exactly **one active block** at a time. A block is only closed when it passes automated tests and is accepted by manual visual QA. Any defects found post-lock become narrow fixes, rather than indefinitely stopping the sequence.

---

## Locked Block Sequence

### Block 5C — Timber Gathering
**Status:** Engineering complete; manual visual QA pending.

### Block 5D — Construction
**Status:** Engineering complete; passes automated verification suite (verify.py 100% green). Manual visual QA pending.
**Player outcome:** Place a Dwelling blueprint, deliver materials, perform labor and complete it.
**Deliverables:**
- Blueprint instead of instant completion (COMPLETED)
- Material requirements and reservations (COMPLETED)
- Camp-to-site material delivery (COMPLETED)
- One assigned builder via right-click (COMPLETED)
- Labor progress and live ticks (COMPLETED)
- Cancellation and refunds (COMPLETED)
- Blueprint, progress foundation and completed visuals (COMPLETED)
- Construction inspection card in HUD (COMPLETED)

### Block 5E — Movement decision
**Status:** Local grid routing implemented and tested; broader routing and manual acceptance remain.
**Player outcome:** Villagers reach tasks reliably.
*(Only implemented if live gameplay shows direct movement crossing buildings/water/unusable slopes).*

### Block 5F — Storage economy
**Status:** Individual-store inventories, destination promises and physical builder pickup implemented; store-to-store hauling and filters remain. See [storage slice](GOPALA-Storage-and-Worker-Jobs.md).
**Player outcome:** Resources exist in identifiable locations and move safely.

### Block 5G — Villager jobs
**Status:** Persistent timber, stone, thatch, wild-food, fodder and water collection roles implemented; general job priorities/professions remain.
**Player outcome:** Several villagers perform persistent work without manual orders each time.

### Block 5H — Survival loop
**Status:** ACTIVE. Physical food/water consumption, home capacity, health shortage/recovery, safe work interruption and water-point collection implemented; cattle, pasture, physical feed/milk transport and the fifteen-minute objective implemented; macOS package and packaged-data acceptance implemented. Human gameplay/art acceptance remains.
**Player outcome:** The settlement can survive or decline.

### Block 5I — Persistence
**Status:** Local settlement save/load and backup recovery implemented and tested; broader compatibility and remaining-system saves remain.
**Player outcome:** Save during active work and continue correctly.

### Block 6 — MVP HUD
**Status:** Supply roles, build bar, tempo, survival summary and separate MVP save slot implemented; scenario/herd controls and onboarding implemented. All active panels follow the accepted navbar theme; captures reviewed at 1280×800 and 1920×1080. Human acceptance remains.
**Player outcome:** The complete MVP can be operated without debug controls.

### Block 7 — Scenario
**Status:** Engineering implemented within active Block 5H; actual-valley construction and fifteen-minute save/reload acceptance tested. Human acceptance pending.
**Player outcome:** A new player can understand and finish a small objective.

### Block 8 — Release gate
**Status:** Local macOS engineering gate implemented; broader release acceptance remains.
**Deliverables:**
- Initial eight-worker, 4× speed profiling on Apple M4 Pro recorded in `reports/mvp-render-review.json`; tick spikes remain.
- Render captures reviewed at 1280×800 and 1920×1080; human interaction acceptance remains.
- Accessibility/localization
- Local ad-hoc signed macOS package in `builds/mvp/GOPALA-MVP.zip`; other platforms and notarized distribution remain.

Required verification: 158 stages passed, with four existing TerrainStreamer import warnings. Scaling: revision 10, 136 checks passed. See the packaged-data acceptance receipt for the packaged scenario result. These checks do not mark manual QA complete or lock additional blocks.
