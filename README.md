# Project NVS: The Quiet Bloom

A faun carries a set of wooden pipes into a wounded valley. Play the land's remembered melodies to loosen corruption, clear polluted water, and coax new growth from scorched earth.

**The Quiet Bloom** is the provisional title for Project NVS. This first playable game combines adapted code from MBean1, Zendelves, and Lifesim in a small, complete restoration journey.

![The faun in the valley](docs/valley-start.jpg)

## Play locally

Use Node.js 20 or later. The game has no package dependencies and needs no install step.

```sh
npm start
```

Open [http://localhost:5173](http://localhost:5173), then choose **Begin the journey**. A modern browser with WebGL and Web Audio support is required.

You can also serve this directory with any static HTTP server. Open the game through HTTP or HTTPS. Opening `index.html` through `file://` does not support this ES module setup.

## Restore the valley

Follow the pale paths to the floating sanctuary lights. Raise your pipes with Space, listen to the phrase, then play its displayed keys in order. The melody checks note order at your own pace. There is no timing window, score penalty, or game-over screen.

The Hollow Wood, the Bitter Marsh, and the Ember Orchard each contain three wounded sites. Their melodies grow from four to six notes. Every completed phrase changes the surrounding terrain, plants, and water. Restored sites gain flowers and returning butterflies.

After all nine sanctuaries recover, return to the central heart tree. Play its final seven-note melody to complete the journey. You can continue exploring and playing afterward.

| Control | Action |
| --- | --- |
| W A S D or arrow keys | Walk while your pipes are lowered |
| Left Shift | Walk briskly |
| Drag the scene | Orbit the camera |
| Mouse wheel | Zoom |
| Space | Raise or lower the pipes |
| Q W E R T | Play C, D, E, G, A while the pipes are raised |
| Listen button | Hear the nearby sanctuary's phrase |
| E | Rest beside the lantern camp while the pipes are lowered |
| J | Open the journal and choose a sanctuary waypoint |
| Escape | Pause or resume |
| Sound button | Mute or unmute |

The on-screen note buttons work with a pointer. Small screens also show movement buttons. While the pipes are raised, W and E play notes. Lower the pipes to use walking and resting controls.

Energy, comfort, and frustration change the faun's mood. They never prevent movement or music. A four-second rest at the lantern camp restores energy and comfort. Walking away cancels the rest.

## Your journey is saved here

The game automatically saves in the current browser every five seconds, after restoration, and when paused or closed. **Continue** restores your position, sanctuary progress, needs, and ending state. Clearing site data removes that save. A different browser, device, or server origin has a separate save.

## Watch a place recover

| Before the song | After the song |
| --- | --- |
| ![A wounded sanctuary](docs/restoration-before.jpg) | ![The same sanctuary after restoration](docs/restoration-after.jpg) |

## Scope of this version

This is a single-player exploration game with one authored valley, nine restoration sites, a playable procedural faun, live synthesized music, and an ending. It has no combat, building mode, multiplayer, or full music editor. Its five-note instrument and melody matching are purpose-built for restoration.

All models and terrain are generated in code. The music uses an authored synthesizer adapted from MBean1's reed voice. It contains no borrowed music recordings or downloaded instrument samples.

See [the architecture](docs/ARCHITECTURE.md), [the source reuse record](docs/SOURCE_REUSE.md), and [implementation progress](PROGRESS.md). Source links to the private projects require access to those repositories.

## Development commands

```sh
npm test
npm run check
```

These commands run 14 simulation, save, geometry, restoration, and route reachability checks, plus syntax checks. The browser journey and audio graph have separate replayable checks. For those development checks only, install Playwright and its Chromium browser, then run:

```sh
node tools/browser-smoke.mjs
node tests/audio-browser.cjs
```

Set `CHROMIUM_PATH` to use an existing browser executable. [Browser results](docs/browser-verification.json), [audio results](docs/audio-verification.json), and [PROGRESS.md](PROGRESS.md) record the verification performed on this version.
