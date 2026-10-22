# Project NVS progress

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
