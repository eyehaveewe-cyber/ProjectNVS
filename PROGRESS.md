# Project NVS progress

## Far woodland map expansion 2026-10-28

- [x] Recovered the complete editable woodland source from `ProjectNVS_Woodland_Source_74fb1e5.zip`, retaining the full MBean1 keyboard, squirrel, Raincall, nursery, fox, restoration dances and giant-deer Artemis.
- [x] Expanded native bounds from 150 by 150 to 250 by 250 units. Bounded surface grows from 22,500 to 62,500 square units, about 2.78 times the recovered woodland.
- [x] Added five connected outer trail sections. The original six routes retain their positions; total authored route length grows from 557.65 to 1,602.91 units, an additional 1,045.26 units.
- [x] Added Fern Hollow, Wind Stones, Willow Pool, Sunwash Meadow and the Elder Ring. These eleven total clearings form a continuous circuit with inward return paths and signs at familiar landmarks.
- [x] Added twelve optional seeds for thirty total, retaining the exact original eighteen positions and IDs. Save format remains version two; saved positions use the expanded authoritative bounds and collectible validation uses the actual seed registry.
- [x] Added a labeled full woodland map and route guide to the journal, resized minimap coverage, outer-country HUD hints and a camera far plane suited to the wider bounds.
- [x] Kept open walking space around trails, clearings and discoveries. Terrain extends past the playable edge and distant silhouettes sit outside the new boundary. The expansion mesh has 74,882 triangles; the full collision world contains 807 obstacles.
- [x] Native Godot 4.7.2 verification passes 264 assertions: 36 core, 83 keyboard, 14 route, 81 controller traversal and 50 woodland integration checks. The browser prototype's 14 tests and syntax check also pass.
- [x] The collision audit samples 3,513 points with no blocked samples. The actual controller walks all eleven routes forward and backward through 148 waypoints, plus a small off-trail circuit and four world-edge roundtrips. The measured distance is 3,249.08 units over 20,408 fixed simulated steps, with eleven starting relocations and no relocation between directions.
- [x] Actual save and Continue restore the outer-country position and both old and new seed IDs; version-one and older version-two saves retain safe behavior.
- [x] Updated the existing design addendum to version 0.3, preserving the earlier contribution record and separating historical verification from the current map results.

This pass expands walking space and route choices. The controller checks establish physical traversal, not first-time wayfinding or frame rate. Construction took 1,132 ms in the test environment, which is a local observation rather than a target-hardware budget. Native renders of all five added landmarks and the journal map were inspected. A local foreground clearing and distant elder arc corrected the initially obscured Elder Ring view. Publication remains separate from these implementation and verification results.

## Woodland and music expansion 2026-10-23

- [x] Expanded native playable bounds from 52.4 units per side to 150 per side: 8.2 times the bounded surface, with six connected trails totaling 557.65 units, six named clearings, and eighteen optional wild seeds.
- [x] Squirrel pursuit with six collision-checked trail waypoints, waiting when the faun falls behind, persistent progress, and a reusable Raincall unlock.
- [x] Forty-five-second local showers and gradual nursery regrowth. An oiled fox has its own listening/cleansing encounter and recovered animation. Two dryads have short contextual dialogue.
- [x] Giant deer Artemis first appears in the southern meadow after three sanctuary restorations, with antlers, moon crown, eye/hoof detail and a short story hint. The wider cause of the damage is unresolved.
- [x] Eight-second restoration performances with animals, a dryad, expanding rings and petals, plus persistent residents. Distant residents are culled. Scorched sanctuary stumps grow small flowering shoots over five seconds.
- [x] Actual MBean1-Astra piano-performance.js key layout, all four note rows, Space sharp modifier, octave controls, sustained chords, individual note release, and pause/mute cleanup. Tab now changes pipes mode so musical E/J do not trigger rest/journal.
- [x] Included bank expanded to 61 chromatic PCM tones and seamless sustain loops, with tuned transposition at its boundaries and bounded voice-bus gain. Different areas use sparse recurring motifs.
- [x] Hear-the-melody prompts and optional hidden note hints support playing by ear. A full note highway is deferred.
- [x] Whole-woodland map, contextual discovery hints, journal notes, and save version two with safe version-one defaults.
- [x] Root project.godot, scenes, editable scripts, source assets and generation tools retained. The browser prototype remains at its earlier scope.

Verification is recorded by the native smoke, music, route and woodland integration reports in docs. The route audit checks 1,359 points with no blocked samples. A separate controller test traversed all 33 trail waypoints over 557.49 units, using six starting relocations and the actual movement update. Native screenshots use Godot GL Compatibility on software graphics. The integration tests relocate the faun; they exercise real input and squirrel movement but do not establish first-time route finding, human musical enjoyment or Windows hardware performance. Audio was checked numerically with a dummy playback device, not by human listening.

Deferred: rhythm highway, Artemis' woman form, full mythological conflict and an absent familiar melody as a scripted story event. These remain in the design addendum instead of being treated as finished features.


## Native Godot edition correction 2026-10-22

The initial delivery used a browser runtime and omitted the Godot project the user expected. A real native Godot 4.7.2 edition now exists at the repository root.

- [x] Root `project.godot`, playable `main.tscn`, native GDScript gameplay, UI, save system, camera, and character animation.
- [x] Existing valley and faun geometry reused as native ArrayMesh data. All nine restoration sites, regional regrowth, butterflies, camp, and heart-tree ending carried over.
- [x] MBean-derived pipe synthesis baked into included native PCM, played by AudioStreamPlayer. No browser or Node runtime required.
- [x] Godot 4.7.2 editor import and native game boot completed.
- [x] Native integration checks passed, including keyboard walking, all nine songs, final ceremony, actual save/Continue, malformed save filtering, timed rest, and voice cleanup.
- [x] Native screenshots rendered with Godot GL Compatibility and inspected. The verification environment used software graphics and a dummy audio driver; PCM signal content was checked, not human listening.
- [x] Exported resource pack booted separately with included native mesh and audio assets.
- [x] README now starts with Godot import and F5 instructions. The browser version remains available.

The Channel Hideo design review remains a proposal record. This correction carries over the current restoration rules and does not adopt the proposed new expressive-music mechanics.

## First playable, 2026-10-22

The first implementation is **Project NVS: The Quiet Bloom**, a provisional title for a faun's musical restoration journey.

- [x] One explorable 3D valley with the Hollow Wood, Bitter Marsh, Ember Orchard, and central lantern clearing.
- [x] Nine sanctuary sites with individual phrases, visible restoration, and a final heart-tree melody.
- [x] Live five-note panpipe synthesis adapted from inspected MBean1 reed and envelope code.
- [x] Procedural adult faun with curled horns, goat legs, cloven hooves, walking joints, and a raised-pipes pose.
- [x] Procedural terrain and scenery using adapted Zendelves mesh builders, perspective, and seeded placement.
- [x] Lifesim-derived energy, comfort, mood, and cancellable timed rest without movement or music lockouts.
- [x] Walk and music input modes, camera orbit and zoom, melody hints, Listen playback, minimap, and journal waypoints.
- [x] Browser-local automatic saves, Continue, pause, mute, and a confirmed new-journey action.
- [x] Dependency-free static runtime, Node HTTP server, source reuse record, and architecture notes.

## Verification record

- [x] All 14 simulation, save, geometry, restoration stability, and route reachability tests pass with `npm test`.
- [x] Every game module passes `npm run check`.
- [x] Chromium passes 25 browser checks covering keyboard movement, all nine restoration phrases, the final song, Continue, pause, rest, mobile controls, and no uncaught errors. See [browser-verification.json](docs/browser-verification.json).
- [x] The actual Web Audio graph produces finite nonzero output, an A4 peak near 440 Hz, silent mute, and complete voice cleanup. See [audio-verification.json](docs/audio-verification.json).
- [x] Captured and visually inspected the menu, valley, restoration before/after, marsh, orchard, ending, and mobile presentation. Screenshots are in `docs/`.
- [x] Fixed foreground character occlusion, stable obstacle placement through healing, and complete biome renewal including outer boundaries.

The browser journey uses actual keyboard notes and relocates the player between sites in explicit test mode. Movement has a separate input check, and the world tests check all camp-to-site routes around solid scenery. Audio checks inspect the signal; they do not claim a human listening assessment. Software-rendered Chromium is not a hardware benchmark.

## Current limits

This version has one authored valley and one local player. It has no combat, building mode, multiplayer, full music editor, cloud saves, or imported music recordings. The musical instrument is synthesized. Desktop controls are the primary play path, with on-screen note and movement controls for smaller screens.

