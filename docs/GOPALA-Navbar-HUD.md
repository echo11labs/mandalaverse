# Navbar-based gameplay HUD

The accepted top navbar is the design reference: 52 px height, dark brown/black surface, brass rules, 16 px display headings, 13 px resource counters and 16–18 px resource icons. Its seven resource IDs remain timber, stone, thatch, water, wild_food, fodder and milk.

`GopalaTheme.navbar()` defines the common gameplay palette and compact control styles. `NAV_*` values are the single source for dark surfaces, text, borders, radius, title/body sizing and 32 px desktop controls. The original reference navbar preserves its dimensions and resource rail. Survey, tempo, survival, inspection, building cards, categories, camera tools, alerts and the help dialog use the same visual language. Supply-role buttons reuse the navbar's actual icon paths; text labels and tooltips keep every action identifiable. Keyboard focus remains visible.

The build strip is 157 px high in the measured 1280×800 layout. Camera controls occupy a separate row above it. Left panels align at 300 px width; the compact inspection starts below the navbar. Inspection fields render as valid coloured BBCode instead of exposing custom tag text.

Rendered captures are `reports/mvp-1280x800.png` and `reports/mvp-1920x1080.png`; measurement and device scope are in `reports/mvp-render-review.json`. Those captures review the active desktop gameplay HUD. The content laboratory/component gallery remain engineering fixtures rather than additional player-facing MVP screens. Future historical art and forest approval remain separate from this UI update.
