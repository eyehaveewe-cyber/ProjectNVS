/**
 * Restoration and faun needs, independent of rendering and audio.
 *
 * The normalized energy/comfort decay, mood thresholds and timed recovery adapt
 * Lifesim scripts/world_simulation.gd and scripts/object_interactions.gd at
 * 8fc9de1c32076ae381fddb9f70b5195b52975e72. The single-faun restoration rules,
 * melodies and save schema are original ProjectNVS code.
 *
 * Time inputs are seconds. serializeState returns a JSON-safe object.
 * createState/loadState accept that object or its JSON string, and sanitize it
 * at this persistence boundary. Session-only melody and rest progress restart
 * on load. Needs never prevent walking or playing music.
 */

const clamp01 = (value) => Math.max(0, Math.min(1, value));
const finite = (value) => typeof value === 'number' && Number.isFinite(value);
const finiteWithin = (value, min, max, fallback) => finite(value) && value >= min && value <= max ? value : fallback;
const distanceTo = (player, x, z) => Math.hypot(player.x - x, player.z - z);
const NOTE_PITCHES = Object.freeze([60, 62, 64, 67, 69]);
const NOTE_KEYS = Object.freeze(['Q', 'W', 'E', 'R', 'T']);

export const SONGS = Object.freeze({
  corruption: Object.freeze({
    name: 'Rootsong',
    notes: NOTE_PITCHES,
    keys: NOTE_KEYS,
    sequence: Object.freeze([0, 2, 4, 2]),
    description: 'Wake the roots beneath the violet blight.',
  }),
  pollution: Object.freeze({
    name: 'Clearwater Round',
    notes: NOTE_PITCHES,
    keys: NOTE_KEYS,
    sequence: Object.freeze([1, 3, 2, 1]),
    description: 'Invite the reeds to filter the poisoned water.',
  }),
  scorch: Object.freeze({
    name: 'Ember Lullaby',
    notes: NOTE_PITCHES,
    keys: NOTE_KEYS,
    sequence: Object.freeze([4, 3, 2, 0]),
    description: 'Return shade and rain to the burned orchard.',
  }),
});

export const SITES = Object.freeze([
  { id: 'grove-roots', name: 'The Bound Roots', kind: 'corruption', x: -12, z: -11, radius: 4.3, sequence: [0, 2, 4, 2], reward: 0.12, description: 'Thorn ropes have closed around the old roots. A rising phrase loosens their grip.' },
  { id: 'grove-fungi', name: 'The Silent Mycelium', kind: 'corruption', x: -18, z: -7, radius: 3.8, sequence: [0, 1, 2, 4, 2], reward: 0.12, description: 'The fungal choir has fallen quiet. Follow the small lights upward, then answer them.' },
  { id: 'grove-willow', name: 'The Violet Willow', kind: 'corruption', x: -16, z: -17, radius: 4.5, sequence: [0, 2, 4, 3, 2, 0], reward: 0.16, description: 'The willow remembers an entire verse. Carry its song home to the root note.' },
  { id: 'marsh-spring', name: 'The Bitter Spring', kind: 'pollution', x: 11, z: -6, radius: 3.8, sequence: [1, 3, 2, 1], reward: 0.12, description: 'Oily water bubbles from the spring. Let a round descend through the reeds.' },
  { id: 'marsh-reeds', name: 'The Choked Reedbed', kind: 'pollution', x: 18, z: -12, radius: 4.5, sequence: [1, 3, 4, 3, 1], reward: 0.12, description: 'The reedbed can clean the marsh again. Give it room to rise before returning.' },
  { id: 'marsh-pool', name: 'The Glassless Pool', kind: 'pollution', x: 18, z: -2, radius: 4.2, sequence: [1, 3, 2, 0, 2, 1], reward: 0.16, description: 'No sky reflects here. Send a ripple down to the depths and back.' },
  { id: 'orchard-ash', name: 'The Ash Garden', kind: 'scorch', x: -5, z: 13, radius: 4.0, sequence: [4, 3, 2, 0], reward: 0.12, description: 'Seeds sleep below the ash. A gentle falling melody calls them into the light.' },
  { id: 'orchard-stump', name: 'The Charred Elder', kind: 'scorch', x: 4, z: 18, radius: 4.4, sequence: [4, 2, 3, 2, 0], reward: 0.12, description: 'One green branch survives. Let the melody lean toward it before settling.' },
  { id: 'orchard-seeds', name: 'The Last Seedbed', kind: 'scorch', x: -4, z: 21, radius: 4.2, sequence: [4, 3, 2, 1, 2, 0], reward: 0.16, description: 'These seeds need the longest lullaby. Finish softly on the lowest pipe.' },
].map((site) => Object.freeze({ ...site, sequence: Object.freeze(site.sequence) })));

const SITE_IDS = new Set(SITES.map((site) => site.id));

/** Sanitize external saves without carrying arbitrary properties into state. */
export function createState(saved) {
  let source = saved;
  if (typeof source === 'string') {
    try { source = JSON.parse(source); } catch { source = null; }
  }
  if (!source || typeof source !== 'object' || Array.isArray(source)) source = {};
  const record = source.player && typeof source.player === 'object' && !Array.isArray(source.player) ? source.player : {};
  const healed = Array.isArray(source.healed) ? [...new Set(source.healed.filter((id) => SITE_IDS.has(id)))] : [];
  const player = {
    x: finiteWithin(record.x, -32, 32, 0),
    z: finiteWithin(record.z, -32, 32, 4),
    yaw: finiteWithin(record.yaw, -1e6, 1e6, 0),
    energy: finiteWithin(record.energy, 0, 1, 1),
    comfort: finiteWithin(record.comfort, 0, 1, 1),
    frustration: finiteWithin(record.frustration, 0, 1, 0),
  };
  return {
    player,
    healed,
    sequence: [],
    activeSite: null,
    elapsed: finiteWithin(source.elapsed, 0, 1e9, 0),
    resting: 0,
    won: source.won === true && healed.length === SITES.length,
  };
}

export const loadState = createState;

/** Mood ordering and thresholds are retained from Lifesim's mood_for. */
export function moodFor(record) {
  if (record.frustration >= 0.55) return 'Frustrated';
  if (record.energy <= 0.25) return 'Tired';
  if (record.comfort <= 0.25) return 'Uncomfortable';
  if (record.energy >= 0.7 && record.comfort >= 0.7 && record.frustration < 0.2) return 'Happy';
  return 'Content';
}

/** These rates match Lifesim's update_needs; elapsed is world play time. */
export function updateNeeds(state, dt) {
  if (!finite(dt) || dt <= 0) return;
  state.elapsed += dt;
  state.player.energy = clamp01(state.player.energy - dt / 900);
  state.player.comfort = clamp01(state.player.comfort - dt / 750);
  state.player.frustration = clamp01(state.player.frustration - dt / 100);
}

/** Returns the closest unrestored site, or null. Healing reach is four units. */
export function nearestSite(state, maxDistance = 4) {
  let nearest = null;
  let bestDistance = maxDistance;
  for (const site of SITES) {
    if (state.healed.includes(site.id)) continue;
    const distance = distanceTo(state.player, site.x, site.z);
    if (distance <= bestDistance) {
      nearest = site;
      bestDistance = distance;
    }
  }
  return nearest;
}

/**
 * Notes are pipe indices 0..4. Wrong notes retain the longest suffix that is
 * also a recipe prefix, so a player can immediately begin the phrase again.
 * Audio should play every keypress, including free or wrong notes.
 */
export function playNote(state, index) {
  const site = nearestSite(state);
  if (!Number.isInteger(index) || index < 0 || index >= NOTE_PITCHES.length || !site) {
    state.sequence = [];
    state.activeSite = null;
    return { type: 'free', site: null, matched: 0, total: 0 };
  }
  state.resting = 0;
  if (state.activeSite !== site.id) {
    state.sequence = [];
    state.activeSite = site.id;
  }
  const expected = site.sequence;
  const correct = index === expected[state.sequence.length];
  const attempted = [...state.sequence, index];
  let accepted = [];
  for (let count = Math.min(attempted.length, expected.length); count > 0; count--) {
    const suffix = attempted.slice(-count);
    if (suffix.every((note, i) => note === expected[i])) {
      accepted = suffix;
      break;
    }
  }
  state.sequence = accepted;
  if (accepted.length === expected.length) {
    state.healed.push(site.id);
    state.player.energy = clamp01(state.player.energy + site.reward);
    state.player.comfort = clamp01(state.player.comfort + site.reward);
    state.player.frustration = clamp01(state.player.frustration - 0.4);
    state.sequence = [];
    state.activeSite = null;
    return { type: 'healed', site, matched: expected.length, total: expected.length };
  }
  if (!correct) state.player.frustration = clamp01(state.player.frustration + 0.03);
  return { type: correct ? 'progress' : 'wrong', site, matched: accepted.length, total: expected.length };
}

/** Start a four-second camp rest. Calling again does not restart its timer. */
export function startRest(state) {
  if (distanceTo(state.player, 0, 4) > 3) return false;
  if (state.resting <= 0) state.resting = 4;
  state.sequence = [];
  state.activeSite = null;
  return true;
}

/** Returns true only on completion. Leaving camp cancels the timed action. */
export function tickRest(state, dt) {
  if (!finite(dt) || dt <= 0 || state.resting <= 0) return false;
  if (distanceTo(state.player, 0, 4) > 3) {
    state.resting = 0;
    return false;
  }
  state.resting = Math.max(0, state.resting - dt);
  if (state.resting > 0) return false;
  state.player.energy = clamp01(state.player.energy + 0.35);
  state.player.comfort = clamp01(state.player.comfort + 0.35);
  state.player.frustration = clamp01(state.player.frustration - 0.4);
  return true;
}

/** The ending requires an intentional return to the central heart. */
export function completeHeart(state) {
  if (state.healed.length !== SITES.length || distanceTo(state.player, 0, 0) > 4) return false;
  state.won = true;
  return true;
}

export function serializeState(state) {
  return {
    version: 1,
    player: {
      x: state.player.x,
      z: state.player.z,
      yaw: state.player.yaw,
      energy: state.player.energy,
      comfort: state.player.comfort,
      frustration: state.player.frustration,
    },
    healed: [...state.healed],
    elapsed: state.elapsed,
    won: state.won,
  };
}
