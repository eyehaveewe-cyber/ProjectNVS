# Native Godot edition

## Open and play

Download a fresh ZIP, extract it, import the root `project.godot` in Godot 4.7.2, then press F5. The main scene is `main.tscn`. Its GDScript builds the procedural 3D world and native UI when played. No browser plugin, WebView, Node server or external runtime is required.

## Woodland update 23 October 2026

The native version now extends beyond the browser prototype. `wildwood.gd` builds the surrounding woodland and trails; `woodland_journey.gd` owns optional discoveries and weather; `woodland_cast.gd` builds animated creatures, dryads and Artemis. `keyboard.gd` adapts the actual MBean1 computer layout. Tab raises/lowers pipes; Space sharpens notes. See the README for all controls.

The audio bank now includes 61 finite chromatic notes and seamless sustains. Native saves are version two; the old sanctuary save fields and version-one defaults remain compatible. Run the music, woodland route and woodland integration tests alongside godot_smoke.gd.

## Content carried over

The native edition uses the existing faun geometry, named joint pivots, authored valley, three damaged regions, nine phrases, local and region recovery, heart-tree growth, butterflies, camp recovery, map, journal, save/Continue and ending. Restoration remains the original forgiving order-matching game. The Channel Hideo proposals for new expressive healing mechanics are not implemented by this correction.

## Included assets

`assets/valley.nvs.gz` is a deduplicated native geometry bank generated from the browser source at the original delivery revision ec955e61d0cf29d5400866786cb8b5cfbb284dd9. `scripts/valley.gd` constructs native ArrayMesh resources and changes visible variants when sites heal. The geometry retains the Zendelves-derived builders and authored faun.

`assets/pipe_bank.nvs.gz` contains finite 16-bit mono PCM tones generated from the MBean-derived reed harmonics, ADSR, vibrato and seeded air. It contains no third-party recorded samples. `scripts/music.gd` uses AudioStreamWAV and AudioStreamPlayer, so no Web Audio engine is required. Lifesim-derived needs and recovery amounts are ported into `scripts/grove_state.gd`.

Regenerate meshes with `node tools/bake-native.mjs` and audio with `python tools/bake-native-audio.py` only when developing those assets. The included banks are sufficient for running the game.

## Verification

The native project was imported and run with Godot 4.7.2 stable. `godot --headless --path . --script tests/godot_smoke.gd` checks the actual native scene, walking and note input, all nine restorations, final song, native save/Continue, malformed saves, timed recovery and PCM content. Passing assertions and screenshots are recorded in `docs/godot-verification.json`.

Native screenshots were rendered with GL Compatibility using a software graphics driver. The verification machine had no speaker device and used a dummy audio driver; PCM contents were checked numerically. This is not a Windows hardware or human-listening test.

The Windows Desktop preset was used to export a resource pack, and that pack booted separately with the native assets. A standalone Windows executable is not included. Exporting one requires Godot's normal Windows export templates.

## Saves

Godot stores progress in `user://journey.json` and keeps a previous-save backup. Browser saves remain in browser localStorage and are not automatically migrated. Verification uses a separate temporary save file, leaving the player's journey alone.

