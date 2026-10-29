# Artemis expansion implementation

Implemented 28 October 2026 from H009 and the revision 0.5 handoff. The human requested a roughly threefold second-level expansion, more shortcuts, new relic interactions, and an Artemis questline for Terra to execute. Names, placements and mechanic tuning are implementation choices within that scope. Terra is the implementation handoff role, not a new name for the faun.

The native Godot project remains the playable deliverable. Import the root `project.godot`, press F5 and select The Returning Wood. The browser prototype retains its earlier scope.

## Size and layout

| Measure | Before | Implemented |
| --- | ---: | ---: |
| Bounded dimensions | 180 × 180 | 312 × 312 |
| Bounded area | 32,400 | 97,344, or 3.004× |
| Authored centerline length | 1,068.86 | 3,114.33, or 2.914× |
| Primary walks | 8 | 14 |
| Permanent shortcuts | 3 | 9 |
| Fully open one-unit floor cells | 5,846 | 16,227 |

Bounds describe the containing square, not continuous walkable terrain. Corridors retain a 2.6-unit radius. The 3,050–3,350 provisional route target is met. Unique floor coverage is measured by raster sampling and grows about 2.78 times. Original core vertices, item/site IDs and eight routes remain in place. The wetland curl, cinder curl, two ridge approaches and two southern walks extend the core rather than scaling it. The nested western ridge turn was chosen over a plain ring to offer a long outer approach and a distinct inner relic return.

Wetland pools, burned eastern stumps, numbered root stumps, named clearings and signed branches support navigation. Low banks describe the final corridor network. Roots close both visible approaches to new locked links; opening a link changes the same requirement predicate used by collision and the journal. Reconnected root geometry remains visible.

## Shortcuts

Distances below use an eight-neighbor, one-unit grid over the actual corridor/clearing predicate, with diagonal corner protection. Each before distance excludes only the named link; every other route remains available. Values approximate shortest walking distance, not centerline graph distance. Exact endpoints and flag arrays are exported in `secondwood-layout-data.json`.

| Link | Before | After | Less walking | Unlock |
| --- | ---: | ---: | ---: | --- |
| source-cut | 165.3 | 37.1 | 77.5% | Restore source |
| hollow-cut | 188.5 | 28.1 | 85.1% | Restore hollow |
| ash-cut | 200.0 | 35.8 | 82.1% | Restore ash |
| west-sluice | 345.7 | 133.7 | 61.3% | Vessel at wetland sluice |
| west-ridge-roots | 321.4 | 129.5 | 59.7% | Attuned Lens, focused D sustain |
| east-root-bridge | 236.7 | 116.3 | 50.9% | Spool, three bound anchors |
| ash-east-cut | 332.7 | 110.4 | 66.8% | Healed ash, second Spool repair |
| south-return | 687.7 | 20.0 | 97.1% | Latch at eastern southern endpoint |
| ridge-descent | 387.4 | 53.0 | 86.3% | Plant Artemis's acorn |

## Quest and reusable relics

Artemis appears as the existing giant pale deer at the Turning Glade, independent of the first valley's encounter. E accepts her request. Prior healings count. The quest display derives from saved facts, rather than a separate numeric step.

Restore the Dry Source, Sealed Hollow and Ash Scar using the three existing tools. Find either relic branch first. The Spring Vessel cleans the Moon Lens in the Mirror Wetland; returning to the restored source attunes it. At the western Moon Plinth, press E, raise pipes and sustain natural D in any octave for 1.5 seconds. A beam traces roots while the meter fills. The Hold D button toggles an equivalent sustained note. Free playing without focus does nothing to the crossing. Release or wrong notes clear incomplete progress; lowering pipes, pause, mute and focus loss cancel focus and sustained voices. Completed crossings persist.

The Living Spore releases the Root Spool in the Cinder Loom. Start the eastern bridge repair with E, then walk to each numbered stump and press E to bind it. The next unbound anchor is highlighted. Partial work survives leaving, saving and Continue. The third binding reconnects the route physically. The Spool also repairs the healed Ash Scar's eastern cut. The Vessel has another use at the wetland sluice. Neither tool is consumed. The southern latch requires exploration, not a relic.

After three healings and both required ridge crossings, return to Artemis for one dormant acorn. Carry it to Crown Clearing and plant with the retained Rootheart Spindle. The unique acorn has absent, carried and planted states and cannot be dropped or spent elsewhere. Planting saves before/after, raises a young canopy, returns small animals and opens ridge-descent. Return by that changed route to Artemis and answer Q E U I U E Q. Her new finale and the old Joined Grove song remain independently saved. Further wandering remains available.

## State and saves

`secondwood_layout.gd` owns authored topology and the shared all-of requirement evaluator. `secondwood_state.gd` owns inventory, wounds, attunement, crossings, partial anchors, acorn and finale facts. `secondwood_map.gd` owns drawn terrain, roots, growth and collision presentation; `secondwood_game.gd` dispatches spatial actions, music input, feedback and atomic save rotation. Artemis's shared model construction was extracted from the original cast without changing the original encounter.

Version 2 second-level saves migrate version 1 inventory, healed IDs, old won and valid player coordinates. Old won does not grant relics or the new ending. Restore rejects unknown IDs and impossible prerequisites; JSON numeric anchors are validated and deduplicated. Invalid floor positions use the nearest available authored vertex. Ephemeral lens focus/progress and active voices are excluded. First-valley `journey.json` remains independent from `secondwood.json`.

## Verification and limits

The real selection-to-finale controller journey passes 104 checks, walks 4866.29 units and uses zero spatial relocations. It completes the original healing route, both relics, all new interactions, interrupted holds, a partial repair save/reload, acorn carry/reload, planted reload and the physical-key Artemis song. The relic collection order in that full journey is east then west. Both collection orders are also checked in isolated state fixtures.

Route verification passes 137 checks over 6420 centerline samples. The controller sweeps all 23 routes forward and backward over 6227.68 units, with 23 explicit starting relocations. Full-floor reachability preserves the original spindle and final-grove gates. Long-frame motion cannot tunnel through the northern gate. Relic/save verification passes 48 isolated checks, including v1 finished/unfinished saves, malformed fields, pitch classes across six octaves, duplicate actions and unique-acorn rules.

All five original native suites pass: core 36, keyboard 83, route 14, controller 81, woodland integration 50, 264 total. The browser prototype's 14 tests and syntax check pass. Seven real Godot GL Compatibility screenshots use arranged fixtures and explicit relocations for appearance review. They do not establish gameplay completion; the continuous journey is separate. Software rendering and a dummy audio driver were used for captures.

Human wayfinding, perceived pacing, human listening and target-hardware frame rate remain unmeasured. Automated route traversal cannot establish those qualities. The existing DOCX revision 0.5 is the historical plan; this implementation record and current executable source supersede its pending status.

Reproduce with the commands in README. `tools/audit-secondwood.gd` exports the native registry; `tools/audit-secondwood-shortcuts.py` measures floor coverage and independent link savings with NumPy. `tools/capture-artemis.gd` captures arranged visual fixtures when a display is available. Test reports record their exact scopes.
