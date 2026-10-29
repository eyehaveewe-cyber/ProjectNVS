# Project NVS progress

## Woodland life and frog band, 2026-10-29

- Artemis now speaks to the faun about the current stage of her quest, bows at an audience, and stands in layered moonlight with drifting motes. The pre-existing quest and saves remain unchanged.
- Three animated frogs sit together at the western wetland bend. Press E to start or stop their banjo tune; it stops on departure, pause, mute, or when the pipes are raised. The journal marks their location.
- Five squirrels hop and move their tails along the routes. Five distance-culled particle fields add glade pollen, spring glints, wetland fireflies, cinder embers and ridge petals. Ambient motion pauses with the game.
- Frog Lantern Rag is an original 16-bar, 116 BPM composition, authored and validated in MBean1's event model. MBean1 has no banjo patch, so the editable score uses guitar proxies. A deterministic plucked-string renderer, separate from MBean1's audio engine, creates the banjo-like WAV used by the game and a standalone MP3. The score, generator and renderer are included. The audio was checked by score, waveform and native playback tests, but has not been human-listened.
- Native tests cover the new interactions, audio playback and cleanup, quest-stage dialogue, ambient culling and pause behavior. The existing continuous 104-check Artemis quest still passes with zero relocations. Three Godot screenshots were visually inspected using arranged positions. First-time wayfinding, human listening and target-hardware frame rate remain unmeasured.

## Artemis expansion implemented 2026-10-28

H009's second-level expansion is now playable in the native Godot source. The old core, original tool/site IDs, first valley and independent saves remain intact. The earlier revision 0.5 handoff is retained as design history; `docs/ARTEMIS_IMPLEMENTATION.md` records the delivered behavior and evidence.

- [x] Expanded bounds to 312 by 312 units, 97,344 square units, 3.004 times the old area. Fourteen primary walks and nine shortcuts total 3,114.33 units, 2.914 times the old centerline length. Western wetlands, eastern burned woodland, a northern ridge and southern return walks extend the old core.
- [x] Added six permanent bidirectional links. A one-unit floor raster finds 50.9–97.1 percent shorter endpoint trips for the six new links, with every other route already available. All nine links improve their measured endpoint trip by at least 50 percent.
- [x] Implemented the Moon Lens, restored-source attunement, focused natural-D sustain across octaves, visible tracing beam/progress meter and accessible Hold D toggle. Release, wrong notes, lowering pipes, pause, mute and focus loss clear incomplete holds without deleting permanent progress.
- [x] Implemented reusable Root Spool repairs with three spatial anchors per bridge, numbered stumps, next-anchor highlighting, partial save/resume and a second repair at the healed Ash Scar.
- [x] Artemis gives the local quest in her giant-deer form. Heal three wounds, follow either relic branch first, mend both ridge crossings, receive her unique acorn, plant it with the Spindle, return by the new ridge descent and answer Q E U I U E Q. The reward is a young canopy, returning creatures and free exploration.
- [x] Version 2 saves preserve version 1 tools, healings, valid positions and the old grove completion. Artemis's acceptance, relics, partial repairs, unique acorn and new finale persist independently. Invalid positions use the nearest authored safe vertex.
- [x] Native verification passes 104 continuous progression checks, 137 route checks and 48 isolated relic/save checks. The controller quest walks 4,866.29 units with zero relocations. Route sweeps walk all 23 routes both ways, using one starting fixture per route. Seven native screenshots were inspected. The original five Godot suites and 14 browser tests also pass.

These checks establish implemented progression, collision, persistence and appearance. The raster measures unique floor cells, not exact continuous area. Human wayfinding, human listening and target-hardware frame rate remain unmeasured. Screenshots use arranged fixtures; the continuous quest report does not.

## Level select and second woodland 2026-10-28

- [x] Added startup level cards for The Quiet Bloom and The Returning Wood, with Begin and Continue per journey. Replacing a saved journey requires a second click for that selected level; both pause menus can return to level select.
- [x] Kept the original valley source, discoveries and `user://journey.json` intact. The second level owns its layout, quest state and `user://secondwood.json`, reusing the procedural faun, MBean1 keyboard and pipe audio, and woodland cast.
- [x] Built a second bordered route network inside 180 by 180 unit bounds. Eight authored paths and three permanent shortcuts total 1,068.86 units of centerline. Western and eastern curls branch from the Turning Glade; a restored source opens the northern spiral.
- [x] Added the Spring Vessel, Living Spore and Rootheart Spindle. The matching return objectives heal the Dry Source, Sealed Hollow and Ash Scar. Tools are collected by approach and applied with E; they remain reusable and cannot be consumed on a wrong interaction.
- [x] Healing the three places opens three crosslinks, with the northern branch gated by source recovery. Once all places recover, the final curl opens to the Joined Grove; Q E U I U E Q completes the journey in any octave.
- [x] Added a journal route overview, inventory descriptions, places to revisit, a dryad keeper, returning small animals, visible water or growth and healing particles. Locked paths and opened paths have separate map presentation.
- [x] Appended H008 and the second-level implementation record to the existing design document as version 0.4, retaining the earlier contribution history and map evidence.
- [x] Native progression passes 82 checks. The real controller walks 2,304.85 units in 14,440 fixed steps, from startup selection through all tools, healing, return visits and the physical-key finale, with no spatial relocation or direct quest mutation. Actual saves, Continue, level selection and save isolation are exercised.
- [x] Native route verification passes 71 checks across 2,233 centerline samples and full-floor gate reachability at three progression states. Reachable grid cells increase from 3,292 to 4,676 after the source heals, then to 5,846 after all healings. The controller walks all eleven route sections out and back over 2,137.25 units in 13,382 steps, using one starting relocation per route.

These tests establish physical progression, gate behavior and persistence. First-time navigation and target-hardware performance remain unmeasured. All five original Godot suites pass again. Eight native screenshots of the level selector, map, routes, healing and finale were inspected using software graphics. A gate sign now disappears along with the roots it labels. No new mythology or wider Artemis storyline is adopted by these route and quest choices.

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

