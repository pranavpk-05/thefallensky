# Solstice of the Sunken Spire · Dark Frontier

## Play the build

Open `project.godot` in Godot 4.7.2 and press F5. Choose **New Game** to begin at Mara's expedition camp. **Continue** resumes the latest checkpoint with the case, supplies, and seal progress intact.

| On foot | In the Peregrine |
| --- | --- |
| WASD move, mouse look | W/S nose down/up, A/D bank or steer |
| Space jump, hold in the air to glide | I ignition, R/F increase/decrease throttle |
| Shift sprint, Ctrl crouch | Q/C rudder, Space brake |
| E interact, J journal, Esc pause | E board or exit when stopped, V reset chase camera |
| H heal, G use a recovered flare, R checkpoint | Follow the cyan waypoint east of the Spire, then land at the amber runway |

After inspecting Mara's journal, radio, and tracks, look for the signed trail and amber lamps on the river side of the west runway near Windgate. Use **E** to investigate the scene or speak to Iven, and **J** to read the evidence. In a storm, find Iven under the roof by the gauge. Once you recover the dispatch, check the gauge's green indicator or ask Iven what he changed.

## Development record

- Preserved the original files in Git checkpoint `a33a045`. Kept the existing main scene, terrain collision, glider, updrafts, and three-seal route.
- Reworked the Forward+ environment with dynamic daylight, moonlight, moving clouds, gusts, distance fog, rain, layered stone and river shaders, instanced vegetation, and an updated adventurer and glider.
- Authored four investigation acts around Mara's expedition. The tunnel, Hanging Court, observatory, and Spire provide distinct evidence. The journal requires three records to establish sabotage. The final relay gives the player two outcomes.
- Added supplies, healing, exposure, stamina, safe rest, a rune cache, and a sentinel that responds to line of sight, crouching, pursuit, and flares.
- Built the original Peregrine and an independently playable recorder mission. Two working west-valley strips support taxi, takeoff, a river-side detour, landing, and on-foot investigation.
- Added the title menu, journal, pause, settings, quality presets, separate flight instruments, original procedural audio, and checkpoint saves with a previous-save fallback.
- Continued from the working tree after verifying it launches in Godot 4.7.2 Forward+. Added **The Flood Gauge Robbery**, an optional case that connects a local theft to Intake Four. Iven reacts to a sprinting approach and moves to shelter in heavy rain. Rain can wash away an uncollected clue, while Iven's testimony offers another route through the case. Checkpoints retain the evidence, witness location, and rain damage. Existing format 1 saves pick up the new case after the camp investigation.
- Polished the Windgate trail, survey site, and gauge shelter with wet ruts, gravel, riverbank conifers, weathered materials, fixed work lamps, roof rain audio, and foreground shelter collision. Iven walks a circuit between the survey site, the landing, and the shelter. He stops to speak, remembers the evidence discussed, and works at the gauge once the dispatch has been recovered. The same checkpoint format now retains his routine, alarm, and conversation memory. A solved case restores the gauge's indicator and status plate from the recorded dispatch.
- Backed up the pre-polish working files under `build/flood-gauge-before/`, with the Git base and status recorded alongside the snapshot.

## Verification

| Test | Coverage |
| --- | --- |
| `tests/playable_smoke.gd` | Original movement, glider, every seal and checkpoint |
| `tests/frontier_story_smoke.gd` | Evidence, walkable tunnel, deduction, cache, survival and both endings, save/load |
| `tests/aircraft_smoke.gd` | Flight physics and actual valley route with `-- --valley` |
| `tests/frontier_ui_smoke.gd` | Menu focus and navigation, settings, journal, flight HUD and audio routing |
| `tests/frontier_incident_smoke.gd` | Walkable approach, sprint reaction, offscreen rain and late arrival, each evidence route, Iven's work round and dialogue, repaired gauge after Continue, and old checkpoint compatibility. Pass `-- --capture` in a Forward+ window for four captures under `build/screenshots/flood-gauge/` and a short sample of all four graphics presets |
| `tests/visual_frontier.gd` | Actual Forward+ viewport captures |

`references/visual_target.png` was absent. The original art follows the written fantasy valley and dark frontier direction. The local creative pipeline is procedural and requires no external services during play. The installed Godot 4.7.2 template directory contained Web templates. The Windows x86-64 preset and packaged-data smoke test cover resource packaging.

- Godot 4.7.2 imported the project and the installed GDScript checker found zero broken scripts. The existing nested scaffold is skipped by the editor.
- The legacy traversal, story and survival, aircraft fixture and real runway mission, and UI suites completed with zero failures. The story and aircraft missions were also exercised with a desktop Forward+ window.
- Runtime captures are in `build/screenshots/`. The test machine was an RTX 3050 6 GB laptop. Short 1080p samples varied by scene and are insufficient to claim a sustained frame rate. Low and Medium use lower 3D render resolution and preserve native HUD resolution.
- The Flood Gauge milestone passed the headless startup and all existing gameplay suites, including the live valley flight route. Both Flood Gauge paths also passed in a desktop Forward+ window. Four reviewed captures and the performance log are under `build/screenshots/flood-gauge/` and `build/flood-gauge-forward.log`. After warm-up, 45-frame samples at a fixed survey-site view on the RTX 3050 laptop measured 119, 118, 117, and 98 FPS from Low through Ultra. The first approach capture registered 14 FPS. These are short samples, and streaming and traversal performance remain unmeasured.
- The export preset lives in `export_presets.cfg`. Godot booted directly from the earlier `build/windows/Solstice - Dark Frontier.pck`. The Flood Gauge Robbery is in the current project source. The matching Windows release template was absent, so there is no standalone Windows executable.

## Skills applied

Godot game director, efficient coding agent, Godot 4 game developer, GDScript, 3D essentials, gameplay systems, game designer, horror narrative designer, AAA graphics builder, shaders, Godot physics, game UI designer, UI Control, audio, audio generator, game QA, debug profiler, QA release, and export.
