import test from 'node:test';
import assert from 'node:assert/strict';
import { SITES, SONGS, createState, loadState, updateNeeds, moodFor, nearestSite, playNote, startRest, tickRest, completeHeart, serializeState } from '../src/simulation.js';

function atSite(state, site) {
  state.player.x = site.x;
  state.player.z = site.z;
}

test('all nine sites have playable recipes and three restoration regions', () => {
  assert.equal(SITES.length, 9);
  assert.equal(new Set(SITES.map((site) => site.id)).size, 9);
  for (const kind of Object.keys(SONGS)) assert.equal(SITES.filter((site) => site.kind === kind).length, 3);
  for (const site of SITES) {
    assert.ok(site.sequence.length >= 4 && site.sequence.length <= 6);
    assert.ok(site.sequence.every((index) => Number.isInteger(index) && index >= 0 && index < 5));
  }
});

test('needs follow the adapted rates and clamp, without stopping music', () => {
  const state = createState();
  updateNeeds(state, 90);
  assert.equal(state.player.energy, 0.9);
  assert.equal(state.player.comfort, 0.88);
  assert.equal(state.elapsed, 90);
  updateNeeds(state, 10000);
  assert.equal(state.player.energy, 0);
  assert.equal(state.player.comfort, 0);
  assert.equal(moodFor(state.player), 'Tired');
  atSite(state, SITES[0]);
  assert.equal(playNote(state, 0).type, 'progress');
  const before = serializeState(state);
  updateNeeds(state, NaN);
  updateNeeds(state, -1);
  assert.deepEqual(serializeState(state), before);
});

test('restoration needs proximity and a complete matching phrase', () => {
  const state = createState();
  assert.equal(playNote(state, 0).type, 'free');
  const site = SITES[0];
  atSite(state, site);
  for (const index of site.sequence.slice(0, -1)) assert.equal(playNote(state, index).type, 'progress');
  assert.equal(state.healed.length, 0);
  const result = playNote(state, site.sequence.at(-1));
  assert.equal(result.type, 'healed');
  assert.equal(result.matched, site.sequence.length);
  assert.deepEqual(state.healed, [site.id]);
  assert.equal(playNote(state, 0).type, 'free');
  assert.equal(state.healed.length, 1);
});

test('wrong notes restart at a valid suffix and moving to a site clears the old phrase', () => {
  const state = createState();
  atSite(state, SITES[0]);
  playNote(state, 0);
  playNote(state, 2);
  const retry = playNote(state, 0);
  assert.equal(retry.type, 'wrong');
  assert.equal(retry.matched, 1);
  assert.deepEqual(state.sequence, [0]);
  for (const index of [2, 4, 2]) playNote(state, index);
  assert.ok(state.healed.includes(SITES[0].id));
  atSite(state, SITES[1]);
  playNote(state, 0);
  atSite(state, SITES[3]);
  const changed = playNote(state, 1);
  assert.equal(changed.type, 'progress');
  assert.deepEqual(state.sequence, [1]);
  state.player.x = 0;
  state.player.z = 4;
  assert.equal(playNote(state, 4).type, 'free');
  assert.deepEqual(state.sequence, []);
});

test('camp rest is timed, cancellable, and awards recovery once', () => {
  const state = createState();
  state.player.energy = 0.2;
  state.player.comfort = 0.1;
  assert.equal(startRest(state), true);
  assert.equal(tickRest(state, 3), false);
  assert.equal(startRest(state), true);
  assert.equal(state.resting, 1);
  assert.equal(tickRest(state, 1), true);
  assert.equal(state.player.energy, 0.55);
  assert.ok(Math.abs(state.player.comfort - 0.45) < 1e-10);
  assert.equal(tickRest(state, 20), false);
  startRest(state);
  state.player.x = 10;
  assert.equal(tickRest(state, 4), false);
  assert.equal(state.resting, 0);
  assert.equal(startRest(state), false);
});

test('nine restorations require a final return to the heart', () => {
  const state = createState();
  assert.equal(completeHeart(state), false);
  for (const site of SITES) {
    atSite(state, site);
    for (const index of site.sequence) playNote(state, index);
  }
  assert.equal(state.healed.length, 9);
  assert.equal(state.won, false);
  assert.equal(completeHeart(state), false);
  state.player.x = 0;
  state.player.z = 0;
  assert.equal(completeHeart(state), true);
  assert.equal(state.won, true);
});

test('saves round-trip durable progress and reject invalid external fields', () => {
  const state = createState();
  atSite(state, SITES[0]);
  for (const index of SITES[0].sequence) playNote(state, index);
  state.elapsed = 153;
  assert.deepEqual(serializeState(loadState(JSON.stringify(serializeState(state)))), serializeState(state));
  const bad = createState({
    player: { x: Infinity, z: 999, yaw: 'north', energy: -5, comfort: NaN, frustration: 1.2 },
    healed: [SITES[0].id, SITES[0].id, 'invented', null],
    won: true,
    elapsed: -1,
    sequence: [1, 2],
    activeSite: 'invented',
    resting: 4,
  });
  assert.deepEqual(bad.player, createState().player);
  assert.deepEqual(bad.healed, [SITES[0].id]);
  assert.equal(bad.won, false);
  assert.equal(bad.elapsed, 0);
  assert.equal(bad.resting, 0);
  assert.deepEqual(bad.sequence, []);
  assert.deepEqual(createState('{broken'), createState());
  assert.equal(nearestSite(bad), null);
});
