# Source reuse record

Project NVS adapts inspected code from the three projects requested for this game. It does not vendor their complete repositories or depend on their running services. The source repositories are private. The immutable links below require an account with access.

## MBean1

Inspected branch `MBean1-Astra` at commit [`ecd441fe29118995e7036df46ec80fefe8738e9e`](https://github.com/eyehaveewe-cyber/MBean1/commit/ecd441fe29118995e7036df46ec80fefe8738e9e).

| Source | Retained algorithm | Project NVS destination |
| --- | --- | --- |
| [`reed-audio.js`](https://github.com/eyehaveewe-cyber/MBean1/blob/ecd441fe29118995e7036df46ec80fefe8738e9e/reed-audio.js), `playReed` | Periodic reed harmonics, lowpass filtering, delayed vibrato, bandpass air layer, finite source lifecycle | `src/audio.js` |
| [`chip-audio.js`](https://github.com/eyehaveewe-cyber/MBean1/blob/ecd441fe29118995e7036df46ec80fefe8738e9e/chip-audio.js), `chipEnvelope`, `chipNoise` | Audio-time ADSR envelope, FNV seed, xorshift noise | `src/audio.js` |
| [`audio.js`](https://github.com/eyehaveewe-cyber/MBean1/blob/ecd441fe29118995e7036df46ec80fefe8738e9e/audio.js) | Oscillator event scheduling and tracked voice cleanup | `src/audio.js` |

The game changes harmonic falloff, amplitude, filtering, and air balance for wooden-pipe tones. It adds its own audio bus, gesture unlock, melody scheduling, mute, pause handling, and restoration-dependent ambience.

The instrument is an authored synthesizer. It is not a sampled panpipe or a physical acoustic model. MBean1's recorded instrument banks, third-party samples, Faust runtime, DSP, and imported audio packs are not included. No MBean1 music recordings are copied.

## Zendelves

Inspected branch `main` at commit [`357aa0f77b0c8080074745e3f56b2a7a78241d04`](https://github.com/eyehaveewe-cyber/Zendelves/commit/357aa0f77b0c8080074745e3f56b2a7a78241d04).

| Source | Retained algorithm or convention | Project NVS destination |
| --- | --- | --- |
| [`lib/xen/actor-models.ts`](https://github.com/eyehaveewe-cyber/Zendelves/blob/357aa0f77b0c8080074745e3f56b2a7a78241d04/lib/xen/actor-models.ts) | `part`, `loft`, `limb`, `prism`, `box`, `surface`, `pyramid`, local vertices and named joint pivots | `src/geometry.js` |
| [`lib/xen/renderer.ts`](https://github.com/eyehaveewe-cyber/Zendelves/blob/357aa0f77b0c8080074745e3f56b2a7a78241d04/lib/xen/renderer.ts), `actor` | Opposing sine-wave leg and arm motion around named pivots | `src/main.js` |
| [`lib/lab/surface-renderer.ts`](https://github.com/eyehaveewe-cyber/Zendelves/blob/357aa0f77b0c8080074745e3f56b2a7a78241d04/lib/lab/surface-renderer.ts) | Yaw-and-pitch perspective transform and depth-buffer rendering approach | `src/renderer.js` |
| [`lib/xen/game.ts`](https://github.com/eyehaveewe-cyber/Zendelves/blob/357aa0f77b0c8080074745e3f56b2a7a78241d04/lib/xen/game.ts), `seeded` | Park-Miller generator with multiplier 48271 and modulus 2147483647 | `src/world.js` |

The faun model, panpipes, valley, restoration scenery, instance transforms, lighting, and game UI are new Project NVS work. Zendelves combat state, enemy catalogs, downloaded art, recorded soundtrack, database, and deployment configuration are not included.

## Lifesim

Inspected branch `main` at commit [`8fc9de1c32076ae381fddb9f70b5195b52975e72`](https://github.com/eyehaveewe-cyber/Lifesim/commit/8fc9de1c32076ae381fddb9f70b5195b52975e72).

| Source | Ported behavior | Project NVS destination |
| --- | --- | --- |
| [`scripts/world_simulation.gd`](https://github.com/eyehaveewe-cyber/Lifesim/blob/8fc9de1c32076ae381fddb9f70b5195b52975e72/scripts/world_simulation.gd), `update_needs`, `mood_for` | Normalized energy and comfort decay, frustration recovery, mood priority and thresholds | `src/simulation.js` |
| [`scripts/object_interactions.gd`](https://github.com/eyehaveewe-cyber/Lifesim/blob/8fc9de1c32076ae381fddb9f70b5195b52975e72/scripts/object_interactions.gd) | Cancellable timed interaction and 0.35 need recovery amount | `src/simulation.js`, lantern rest |

Lifesim is a Godot project. These rules are ported into JavaScript, rather than importing its runtime. Lot building, route reservations, network ownership, multiplayer simulation, and character asset dependencies are not included.

## New game rules

Sanctuary recipes, free-rhythm phrase matching, the final heart song, procedural faun anatomy, biome restoration, the authored valley, journal waypoints, and the save schema are Project NVS additions.

This record identifies the actual source paths and boundaries. It does not assign a blanket license to the source projects. No new license grant is inferred from repository metadata or from the absence of a license file.
