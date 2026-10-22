# How the restoration game fits together

Project NVS uses a small browser runtime because the three source projects do not share an engine. MBean1 supplies browser audio ideas, Zendelves supplies browser mesh techniques, and Lifesim supplies Godot simulation rules. The game adapts those parts into JavaScript modules with one owner for restoration state.

## One simulation, several views

`src/simulation.js` owns the faun's needs, sanctuary recipes, phrase progress, rest timer, ending condition, and save representation. It has no DOM, rendering, or audio dependency.

`src/main.js` owns the active session and passes that state to the other systems. A note always plays through `GroveAudio`. The same note reaches `playNote` to check the nearest unrestored sanctuary. Successful restoration changes `state.healed`, triggers effects, rebuilds the world, and saves progress.

| Module | Responsibility |
| --- | --- |
| `src/simulation.js` | Sanctuary definitions, phrase matching, needs, mood, timed rest, ending eligibility, save parsing |
| `src/main.js` | Input modes, movement, camera, HUD, minimap, journal, character pose, particles, pause, save timing |
| `src/audio.js` | Web Audio unlock, finite reed voices, note scheduling, ambience, mute, voice cleanup |
| `src/geometry.js` | Procedural mesh builders and named faun joint geometry |
| `src/world.js` | Terrain height, seeded scenery, biome appearance, restored scenery, static color batches |
| `src/renderer.js` | WebGL buffers, depth testing, transforms, perspective, flat lighting, distance fog |
| `index.html` and `styles.css` | Menu, HUD, dialogs, controls, responsive presentation |
| `tools/serve.mjs` | Local static HTTP server |

## Music changes the state

`SITES` defines nine sanctuaries with positions, kinds, and note-index sequences. `SONGS` defines the common five-note palette. Each site accepts its own four-to-six-note phrase.

`nearestSite` chooses an unrestored sanctuary within four world units. `playNote` accepts note indices zero through four. A wrong note retains the longest suffix that can begin the expected phrase, so the player can restart without a reset command. Moving or lowering the pipes clears an incomplete phrase.

Rhythm is free. The Listen button schedules the example through audio time, but listening does not heal a site. Healing requires the player's notes.

The final heart phrase belongs to the session controller. Once all sites are healed, the controller accepts that phrase only near the central heart tree. `completeHeart` verifies the healed count and distance before recording the ending.

## Needs support the journey

Energy and comfort use Lifesim's normalized decay rates. Mood checks frustration first, then fatigue and discomfort, then happiness. Needs never gate movement or notes.

`startRest` begins a four-second timed action within three units of the lantern camp. `tickRest` completes recovery or cancels it if the faun leaves. Repeated requests do not restart an active rest. This retains the useful timed interaction behavior without Lifesim's lot reservations or multiplayer ownership.

## Geometry stays procedural

The faun uses Zendelves' mesh-part convention. Every part has local vertices and a named pivot. The controller adds opposing leg swings, arm swings, a breathing motion, and a raised-pipes pose before the renderer applies the character's yaw.

Terrain, plants, stones, reeds, ruins, and the heart tree use the same geometry builders. A deterministic Park-Miller generator keeps scenery placement stable when restoration changes its appearance. `heightAt` supplies the ground elevation for terrain, scenery, actors, and effects.

`buildWorld` combines static meshes by color. The renderer combines those groups into one static draw with face colors. Identically colored pieces of each faun joint share a draw. The renderer caches uploaded geometry buffers, and restoring a site releases old static buffers before rebuilding them. Dynamic characters and effects remain separate. The renderer caps the pixel ratio at 1.5 to limit framebuffer cost on large displays.

World colliders are recorded alongside the actual mesh placements. Axis-separated movement slides the faun around solid scenery. Healing preserves their positions. Foreground scenery between the camera and the faun uses a small dithered opening so foliage cannot hide the character. The terrain continues to use normal depth testing.

Completing one site restores its surroundings. Completing all three sites of a biome restores its outer boundary too. Independent placement seeds prevent one site's new flowers from moving unrelated scenery.

## Audio has its own clock

`GroveAudio` creates a harmonic reed oscillator with a filtered air layer and delayed vibrato. Each note has a finite lifetime and tracked cleanup. The synthesized sound borrows MBean1 algorithms, but its voicing and arrangement fit this game.

The first Start or Resume gesture unlocks the audio context. Muting changes the game-owned audio bus. Pausing, hiding the document, or losing focus stops active voices. The game requires no network audio requests.

## Save data crosses one boundary

`serializeState` returns a JSON-safe versioned record. `createState` accepts that record or its JSON text, selects known fields, validates finite ranges, and removes unknown or duplicated sanctuary IDs. Incomplete phrases and rest timers restart on load.

`main.js` writes that record to the browser's `localStorage` under `project-nvs-journey-v1`. Saves are local to the browser and origin. There is no server account, cloud synchronization, or save export in this version.

## The chosen boundary

Importing the entire source games would bring three runtimes, combat systems, lot simulation, editors, and unrelated assets into one project. Project NVS instead keeps the inspected algorithms close to their original roles and gives the new restoration rules one owner.

That choice limits the first playable game to one valley and one faun. Expanding it should begin with new sanctuary data and world content. A full arrangement editor or building system would need its own design before integration.

Exact source references are in [SOURCE_REUSE.md](SOURCE_REUSE.md).
