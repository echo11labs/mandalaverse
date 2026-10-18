# GOPALA — UI font receipt

Fonts vendored for the GOPALA interface. All four are licensed under the SIL Open
Font License 1.1, which permits commercial use, bundling, and modification. Each
license text is stored beside the font file. No font requires a purchase, and none
is derived from a paid or noncommercial pack.

| File | Family | Designer / copyright | Upstream | License | Role |
|---|---|---|---|---|---|
| `Fraunces.ttf` | Fraunces (variable: opsz, wght, SOFT, WONK) | Copyright 2018 The Fraunces Project Authors (undercasetype/Fraunces) | `google/fonts/ofl/fraunces` | OFL-1.1 (`OFL-Fraunces.txt`) | Display headings, settlement name, panel titles |
| `Karla.ttf` | Karla (variable: wght) | Copyright for the Karla Project Authors | `google/fonts/ofl/karla` | OFL-1.1 (`OFL-Karla.txt`) | Interface body, buttons, tabs, labels |
| `JetBrainsMono.ttf` | JetBrains Mono (variable: wght) | Copyright 2020 The JetBrains Mono Project Authors | `google/fonts/ofl/jetbrainsmono` | OFL-1.1 (`OFL-JetBrainsMono.txt`) | Tabular resource counts, coordinates, telemetry |
| `NotoSansDevanagari.ttf` | Noto Sans Devanagari (variable: wdth, wght) | Copyright 2022 The Noto Project Authors | `google/fonts/ofl/notosansdevanagari` | OFL-1.1 (`OFL-NotoSansDevanagari.txt`) | Devanagari fallback for Nepali localization |

## Why these four

Fraunces is a variable serif with optical sizing and a "wonk" axis; it carries the
warm, printed-ledger character the interface direction calls for without the
generic look of a default UI face. Karla is a grotesque with slightly odd,
humanist terminals that stays readable at 12–16 px over a moving 3D landscape.
JetBrains Mono is used only where digits must align vertically so resource counts
do not jitter while the simulation runs.

Noto Sans Devanagari is included as a fallback so Devanagari text renders instead of
showing tofu boxes. The project requires a Nepali font test during the first UI
milestone; this satisfies rendering, but a fluent reviewer must still verify
translation quality and typography before release.

## Modifications

None. Files are byte-identical to upstream. Variable-font axes are exercised at
runtime through Godot `FontVariation` resources rather than by editing the files.

## Eligibility

All four are eligible for release bundling. See
[GOPALA-Asset-Pipeline](GOPALA-Asset-Pipeline.md) for the general provenance rule and
retain these receipts with the release asset ledger.