# G1-10 tooling proposal

Research date: 8 October 2026. Scope: proposal only; no installations or game/configuration changes. Read the bridge ASSET_CATALOG and GOPALA_LEAD_PLAN. Links below were opened against primary sources; local addon licences and code were inspected. Compatibility statements distinguish upstream support from actual GOPALA testing.

## What we have measured

G1-02’s committed fresh checkout passed 158 stages in 171.35 seconds, including import 6.33 s, settlement scenario 51.15 s, local view 6.10 s and UI 0.45 s/184 checks. Workspace scenario was 51.07 s and local view 6.49 s. The historical failing scenario took 166 s; that was a correctness failure, not a normal performance baseline. The historical local-view timeout did not recur under the unchanged 60 s budget. These wall times are not frame-time or tick-p95 measurements.

What I actually exercised: pinned Godot commands, structured headless reports, a real viewport mouse dropdown test, fresh managed worktrees, selective config staging, asset/runtime-reference scans, and the bridge through its existing Node MCP client. The current tool catalogue does not expose gopala-bridge or Godot editor tools directly; the client adapter works but makes discovery and screenshots cumbersome. Renderer tests cover buffers/culling, not subjective art. Forest output still says pending visual review. Concurrent editor experiments make workspace validation different from committed-content validation.

I inspected local Sky3D 2.1 and SimpleGrassTextured 2.1.0 source/licences. I have not benchmarked either addon at 40 settlers, tested the proposed frameworks, converted the newly staged FBX assets, or validated their animations. No claimed speedups below are measurements.

## Ranked first five changes

| Rank | Proposal | Impact / effort | Tasks accelerated | Decision |
|---|---|---|---|---|
| 1 | Expose existing bridge/toolkit registrations and project screenshot/scene tools in the agent catalogue | High / low to medium | G1-11 asset review; G1 menus, alerts, onboarding; G2 field placement | Approve registration and define editor ownership; reuse installed dependencies |
| 2 | Reproducible 40-settler replay with frame/tick timings and fixed-camera captures | High / medium | G1-11 before/after; G1 debug overlay/tick-spike work; G2 weather/farming | Approve a bounded benchmark and machine/frame budget |
| 3 | Curate the staged CC0 packs with a bounds/triangle/texture/receipt audit | High / medium | G1-11; G2 fields; G3 herd; G5 art | Approve the replacement map before scene edits |
| 4 | Focused test selection plus mandatory full clean-checkout gate at submission | Medium / low | All G1 fixes and G2 season/crop iterations | Preserve every assertion; parallelise only proven independent CPU suites |
| 5 | Optional gdtoolkit lint checks on authored changes | Medium / low | G1 maintenance; G2 data/scripts | Pin after approval; check-only first, no wholesale formatting |

These name roadmap work rather than inventing IDs for unissued G2 tasks. Grass/sky admission comes after the benchmark, not before it.

## Addons: candidates, replacements and risks

All MIT candidates require retaining copyright/licence notices. Unless explicitly stated, upstream Godot-4 positioning is not proof of 4.7.2 compatibility: require import, UI/headless and export smoke tests on the pinned engine before admission. These are documentation-reviewed candidates, not installed or tried here.

| Candidate and primary source | Licence / 4.7 note | Would replace or add | Risk / recommendation |
|---|---|---|---|
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | MIT; 6.2.x matrix lists 4.7/4.7.1, not explicitly 4.7.2 | Scene-input runners, mocking and parameterised checks now authored manually | Migration and editor dependencies; pilot only if a queued task needs mocks. Keep current gate and no retries masking failures |
| [GUT](https://github.com/bitwes/Gut) | MIT; Godot-4 branch, pin release and verify 4.7.2 | Alternate unit assertions/test discovery | Two frameworks duplicate work; prefer existing runners, choose one only after a small comparison |
| [Debug Draw 3D](https://github.com/DmitriySalnikov/godot_debug_draw_3d) | MIT; native C++ addon, exact 4.7.2/macOS binary untested | Route/grid/footprint overlays for the G1 debug task | Native distribution repeats Godotiles’ clean-checkout risk; prefer simple project-owned ImmediateMesh overlays first |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT; Godot 4, exact release compatibility untested | Cinematic/tutorial camera transitions | Existing orthographic terrain anchoring/clipping is already tested; defer replacement of gameplay camera |
| [Beehave](https://github.com/bitbrain/beehave) | MIT; Godot 4, 4.7.2 pilot needed | Future visual behaviour authoring | Render/process-driven AI must not replace conserved fixed-tick jobs; defer until a documented need |
| [LimboAI](https://github.com/limbonaut/limboai) | MIT; native extension/module releases need exact engine/architecture match | Behaviour trees/state-machine debugging | Binary/toolchain cost and save determinism; do not admit alongside Beehave without a specific task |
| [Dialogic](https://github.com/dialogic-godot/dialogic) | MIT; Godot-4 branch, 4.7.2 not locally tested | Later Chronicle/dialogue authoring | More UI/content machinery than onboarding needs; preserve historical evidence labels and defer |

Terrain/scatter: retain the existing project terrain, ProtonScatter, baked vegetation and resource seeding. Adding a second terrain authority now would invalidate measured anchors/grid tests. KayKit is a model source, not a substitute for deterministic resource placement.

## Devendra’s grass and sky experiments

[Sky3D](https://github.com/TokisanGames/Sky3D) advertises Godot 4.3+ and Compatibility renderer support. Local code is MIT; moon texture has its own MIT notice; Milkyway/StarField are CC-BY 4.0 with required ESO/S. Brunier attribution and modification acknowledgement. The latter are not covered by the addon’s MIT licence. See the [bundled attribution receipt](https://github.com/TokisanGames/Sky3D/blob/main/addons/sky_3d/assets/thirdparty/textures/milkyway/LICENSE.md). It would replace the static ProceduralSkyMaterial/WorldEnvironment lighting presentation, not the authoritative season/calendar. Risks: sky/cloud shader cost, shadow updates and two competing clocks. Drive its presentation from simulation time; do not let its wall clock determine crop or weather rules.

[SimpleGrassTextured](https://github.com/IcterusGames/SimpleGrassTextured) is MIT, with a separately documented CC0 grass/bush texture. Local singleton explicitly detects gl_compatibility, but that is not a 4.7.2 performance guarantee. It would replace only decorative near-camera grass. Keep pasture rations and resource counts in the existing simulation. Risks: transparency overdraw, extra interactive SubViewports, shadows and a single player-position input that does not naturally represent 40 settlers. Start noninteractive with grass shadows disabled and local chunk culling; benchmark interactive mode separately.

Admission proposal, not applied: pin exact upstream revisions and hashes; vendor only addon runtime/editor sources, textures and all notices, excluding demo/. Commit plugin entries `res://addons/sky_3d/plugin.cfg` and `res://addons/simplegrasstextured/plugin.cfg` only in that admission task. Use an explicit resource-path SimpleGrass autoload `*res://addons/simplegrasstextured/singleton.tscn` if the pinned package confirms that scene. Reconcile the shader globals generated by that pinned plugin: `sgt_legacy_renderer` int=1 for Compatibility, player_position/player_mov/wind_direction/wind_movement vec3 (wind_movement=Vector3.ZERO, not the current experiment’s Vector2), normal_displacement/motion_texture/wind_pattern sampler2D paths to admitted textures, wind_strength/wind_turbulence floats. Keep layer 17’s interaction label only if needed; do not commit brush-key editor shortcuts as gameplay controls. Preserve UI/MCP autoloads and other approved plugin entries. afmi_godot/godoban admission is separate. No changes to Devendra’s local entries are made here.

Benchmark contract proposed for approval: same machine, renderer, resolution, camera path, seed and 40-settler workload; 30 s warmup then 120 s collection, three baseline and three candidate runs. Report frame and fixed-tick median/p95, instance counts, draw calls and memory; show both 1280×800 and 1920×1080. Compare sky-only, grass-only and combined. Propose a <=5% p95 regression budget plus an absolute frame budget chosen by Devendra. This is a proposed criterion, not an agreed budget or completed benchmark.

## Tools and MCP

| Tool/source | Licence and compatibility | New capability / risk / experience |
|---|---|---|
| [Existing Godot MCP Toolkit](https://github.com/NPGameDev/godot-mcp-toolkit) | MIT code; branding excluded. Advertises 4.2+; vendored 1.0.2 imports on 4.7.2 | Connect installed server for live tree/properties/playtests and supported capture; avoids blind file edits. Risk: two scene writers; reserve editor ownership and expose read-only tools first. Runtime registration observed; current turn has not driven live editor tools |
| Existing gopala-bridge, local `~/Work/gopala-bridge/src/server.mjs` | Local workflow code: external redistribution licence not verified, do not vendor it. Protocol use engine-independent | Direct registration would replace temporary MCP-client shell calls, improving tool discovery and coordination. Adapter exercised; direct registration not yet tried |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | MIT; Python GDScript parser, exact 4.7 syntax support must be checked | gdlint/gdformat check-only on authored files, not vendor code. Risk: false positives/style churn; engine parser remains authority. Not tried |
| [Godot profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) and project telemetry export | Engine MIT; built into pinned 4.7.2 | Attribute tick spikes and export comparable timings instead of inferring from test wall time. Risk: instrumentation overhead; compare disabled/enabled. No 40-settler capture yet |
| [Blender](https://github.com/blender/blender), [licence](https://github.com/blender/blender/blob/main/COPYING) | GPL software; generated original/CC0 models do not become GPL merely by export. GLB output requires 4.7 import/bounds/animation check | Existing `/Applications/Blender.app/Contents/MacOS/Blender` found; batch FBX conversion, UCX removal, texture resize and measured bounds. No conversion performed in G1-10. Risks: axis/bone transform errors; preserve source receipts. Use project-required secure bridge for interactive Blender work |
| Project focused/faster runner, `tools/verify.py` | Project licence applies; not separately redistributed. Existing runners demonstrated on 4.7.2 | Run changed suites while iterating, always full gate before submission. Future bounded CPU parallelism could reduce startup overhead; resource/user-data paths need isolation. Keep GPU/import/scenario serial and preserve error/marker detection. Parallel speedup unmeasured |

No new MCP implementation is needed before reconnecting the installed toolkit. A project capture extension should return saved viewport PNG paths, scene/camera identity and timing metadata; use only upstream supported extension points in gopala_mcp.

## Assets and audio for G2–G5

The staged library is outside Godot so its approximately 1.4 GB is not imported wholesale. Public repository admission requires a pack licence, source/hash receipt, selected filenames, transformation record and CREDITS. Normalize full child-transformed bounds to metre targets and bottom-centre anchors, update scale profiles/checks and inspect scale-audit after swaps.

| Source, verified primary page | Licence / attribution | 4.7 suitability and risk |
|---|---|---|
| [KayKit Forest Nature](https://kaylousberg.itch.io/kaykit-forest) | CC0; credit appreciated | Staged 1.0 has 105 meshes, while current webpage describes a newer pack; pin local receipt rather than imply identical inventories. GLTF/GLB for trees/bushes/rocks/grass. Generic vegetation needs Kathmandu species/readability review |
| [Styloo Animals](https://styloo.itch.io/animals) | CC0; credit voluntary | Staged cow is priority for G1-11/G3. Import walk/idle GLB clips and measure skeleton/bounds on 4.7.2; current page has a corrected-GLB devlog but old warning text, so inspect actual files |
| [Highlands Buildings](https://visionsmind.itch.io/highlands-fantasy-pack-3d) | CC0; retain receipt | FBX must be converted/validated; remove UCX collision meshes, use simple Godot collision, downsize textures to1024/hero2048. European silhouettes are provisional kit pieces, not Newari reconstructions |
| [Poly Haven](https://polyhaven.com/license) | CC0 assets, no required attribution; website/code rights separate | PBR textures/HDRI for selected roofs/ground; import into 4.7.2, reduce texture resolution. Photorealistic material can conflict with the low-poly art direction |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds), [Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0; optional credit | Import selected audio and test 4.7.2 AudioStream playback for G5 UI/build feedback; preview levels and repetition. These are not authentic Nepali instrument recordings |

Reject public-source admission of Craftpix people/houses and Unity forest assets (LOCAL-ONLY). Vegetation/tool packs with unknown provenance remain excluded. Everything Library Animals volume002 stays excluded until that exact volume’s CC-BY licence is confirmed; volume001 terms are insufficient. For music/ambience, request commissioned or documented CC0/CC-BY recordings of valley rivers, madal, bansuri and sarangi with performer consent; no unverified “free” track is recommended.

## Requests for coordinator and Devendra

1. Approve the ranked shortlist and an explicit performance budget/device. Supply target Mac model, RAM, desired FPS and whether 40 settlers means loaded world or active jobs.
2. Decide which installed MCP tools may be registered for this agent and who owns the editor while it runs; require supported screenshot output at both review resolutions.
3. Review G1-11’s measured replacement map before edits; authorise only chosen files, not entire staged packs. Confirm whether Sky3D/grass admission is a separate task after benchmarking.
4. Supply dated, sourced Newari dwelling/storage/roof references and a cultural reviewer; label European placeholders and speculative adaptation honestly.
5. Provide crop calendar and monsoon/flood references, gameplay year length and intended crop species before G2 balancing. Evidence sources and gameplay decisions must be distinguishable.
6. Provide field-recording provenance/performer permission and unknown pack source URLs; keep unknown assets excluded meanwhile.

## G1-10 validation

`python3 tools/verify.py` completed after this documentation was authored: 158/158 stages passed, no captured warnings or known-engine-error allowances. Scenario 52.19 s; local view 6.26 s. No game/config files were authored, no tests changed and nothing was installed. Only this document is staged for the G1-10 commit; existing local experiments and generated verification output are not included.

## Suggestions

Prioritise measurements, a small licensed asset subset and direct access to already installed tools. Framework or addon installations need coordinator approval in a queued task. Keep a mandatory fresh-checkout run to catch omitted dependencies while preserving Devendra’s local experiments.
