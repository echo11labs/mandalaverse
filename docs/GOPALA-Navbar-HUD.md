# Gameplay navbar

The top navbar is 52 px high, with 12 px outer horizontal margins and 6 px vertical
padding. It uses three container-managed regions: settlement identity on the left,
resource counters centered, and simulation clock plus Save/Load/Menu on the right.
Equal 272 px side slots keep the resource rail centered even when the settlement
name or tick text changes. Group spacing is 12 px; resources and actions use 8 px.

All three action buttons have 32×32 px hit targets, 18 px icons, accessible names,
tooltips and keyboard focus outlines. Floppy disk, folder and cog icons identify
Save, Load and Menu. The hourglass denotes simulation time. The clock shows actual
pause/speed and tick state; it does not imply an implemented calendar or seasons.

Seven resource counters remain timber, stone, thatch, water, wild_food, fodder and
milk. Amounts below 10,000 remain exact; larger values use K/M/B labels to keep the
rail bounded. Tooltips and resource management retain exact quantities. Names
ellipsize inside the identity slot, with their full value in a tooltip. Clicking a
resource opens its overview. Navbar controls and background block world input.

`game/tools/review_navbar.gd` checks alignment, bounds, equal action sizing, long
names, large balances, exact tooltips, and actual mouse request routing at
1280×720, 1920×1080, 2560×1080 and 3840×2160. Cropped normal/stress images are
controlled UI fixtures; `reports/navbar/gameplay-1920.png` captures the actual
paused MVP with real starting balances. Results live in `reports/navbar/`.

The shared warm charcoal/brass theme and licensed fonts remain unchanged. Icon
sources, hashes and MIT license are in `game/assets/ui/icons/`. See
[GOPALA HUD layout](GOPALA-HUD-Layout.md) for the rest of the gameplay interface.
