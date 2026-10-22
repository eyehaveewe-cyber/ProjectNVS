import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createFaunParts } from '../src/geometry.js';
import { BOUNDS, buildWorld, heightAt, worldColliders } from '../src/world.js';
import { SITES } from '../src/simulation.js';

function signature(value) {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function assertRenderable(geometry, label) {
  assert.ok(geometry.vertices.length > 0, `${label} has vertices`);
  assert.ok(geometry.triangles.length > 0, `${label} has triangles`);
  for (const vertex of geometry.vertices) {
    assert.equal(vertex.length, 3, `${label} has three-dimensional vertices`);
    assert.ok(vertex.every(Number.isFinite), `${label} has finite vertex coordinates`);
  }
  for (const indices of geometry.triangles) {
    assert.equal(indices.length, 3, `${label} triangles have three corners`);
    assert.equal(new Set(indices).size, 3, `${label} triangles have distinct corners`);
    assert.ok(indices.every((i) => Number.isInteger(i) && i >= 0 && i < geometry.vertices.length), `${label} indices address existing vertices`);
    const [a, b, c] = indices.map((i) => geometry.vertices[i]);
    const u = b.map((v, i) => v - a[i]), v = c.map((n, i) => n - a[i]);
    const cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
    assert.ok(Math.hypot(...cross) > 1e-12, `${label} has no zero-area triangles that break face normals`);
  }
}

function localTriangles(world, site) {
  const triangles = [];
  for (const batch of world) for (const indices of batch.geometry.triangles) {
    const vertices = indices.map((i) => batch.geometry.vertices[i]);
    const x = vertices.reduce((sum, vertex) => sum + vertex[0], 0) / 3;
    const z = vertices.reduce((sum, vertex) => sum + vertex[2], 0) / 3;
    if (Math.hypot(x - site.x, z - site.z) < 4) triangles.push({ color: batch.color, vertices });
  }
  return triangles;
}

test('the faun is finite, drawable geometry around all animated joints', () => {
  const parts = createFaunParts();
  for (const joint of ['head', 'torso', 'leftLeg', 'rightLeg', 'leftArm', 'rightArm', 'pipes']) {
    assert.ok(parts.some((part) => part.name === joint), `${joint} has visible geometry`);
  }
  for (const [index, part] of parts.entries()) {
    assert.ok(part.pivot.length === 3 && part.pivot.every(Number.isFinite), `part ${index} has a finite pivot`);
    assertRenderable(part, `faun ${part.name} ${index}`);
  }
});

test('every restoration state produces finite meshes with valid face normals', () => {
  const states = [[], ...SITES.map((site) => [site.id]), SITES.map((site) => site.id)];
  for (const healed of states) {
    const world = buildWorld(healed);
    assert.ok(world.length > 0);
    for (const [index, batch] of world.entries()) {
      assert.match(batch.color, /^#[0-9a-f]{6}$/i);
      assertRenderable(batch.geometry, `${healed.join(',') || 'damaged'} batch ${index}`);
    }
  }
});

test('each of the nine sanctuaries changes its own visible surroundings when healed', () => {
  const damaged = buildWorld([]), damagedSignature = signature(damaged);
  for (const site of SITES) {
    const before = localTriangles(damaged, site);
    const healed = localTriangles(buildWorld([site.id]), site);
    assert.ok(before.length > 0, `${site.name} is visible before restoration`);
    assert.notEqual(signature(healed), signature(before), `${site.name} visibly changes`);
    assert.ok(healed.length > before.length, `${site.name} gains visible growth`);
  }
  assert.equal(signature(damaged), damagedSignature, 'building a healed world does not mutate the old scene');
});

test('seeded placement recreates the same world and ignores restoration list order', () => {
  assert.equal(signature(buildWorld([])), signature(buildWorld([])), 'the initial valley is reproducible');
  const ids = [SITES[1].id, SITES[4].id, SITES[7].id];
  assert.equal(signature(buildWorld(ids)), signature(buildWorld([...ids].reverse())), 'save ordering does not rearrange the valley');
  assert.notEqual(signature(buildWorld(ids)), signature(buildWorld([])), 'restoration is part of the generated scene');
});

test('restoration preserves solid landmarks and a single song leaves distant trees unchanged', () => {
  // Inspect actual visible faces above ground, beyond every sanctuary and the
  // central heart. Canonical ordering permits batches to change as colors heal.
  const outerTrees = (world) => {
    const faces = [];
    for (const batch of world) for (const triangle of batch.geometry.triangles) {
      const vertices = triangle.map((index) => batch.geometry.vertices[index]);
      if (vertices.every(([x, y, z]) => Math.abs(x) < BOUNDS + 1 && Math.abs(z) < BOUNDS + 1
        && y > heightAt(x, z) + 1 && Math.hypot(x, z) > 6
        && SITES.every((site) => Math.hypot(x - site.x, z - site.z) > 10))) {
        faces.push(JSON.stringify([batch.color, vertices]));
      }
    }
    return faces.sort();
  };
  const beforeWorld = buildWorld([]);
  const beforeColliders = structuredClone(worldColliders());
  const beforeTrees = outerTrees(beforeWorld);
  assert.ok(beforeColliders.length > 20, 'landmark and woodland solids exist');
  assert.ok(beforeTrees.length > 100, 'the comparison contains visible woodland geometry');
  for (const healed of [[SITES[0].id], SITES.map((site) => site.id)]) {
    const afterWorld = buildWorld(healed);
    assert.deepEqual(worldColliders(), beforeColliders, 'healing never moves a solid landmark into the player');
    // Completing a whole biome intentionally renews its outer woodland too.
    // A single song must still leave unrelated woodland completely unchanged.
    if (healed.length === 1) assert.deepEqual(outerTrees(afterWorld), beforeTrees, 'distant trees keep the same positions and shapes');
  }
});

test('walkable terrain stays finite and gentle across the entire valley', () => {
  for (let x = -BOUNDS; x <= BOUNDS; x += 0.5) for (let z = -BOUNDS; z <= BOUNDS; z += 0.5) {
    const y = heightAt(x, z);
    assert.ok(Number.isFinite(y) && y > -1 && y < 1, `valid terrain at ${x}, ${z}`);
    assert.ok(Math.abs(heightAt(x + 0.5, z) - y) / 0.5 < 0.15, `gentle east-west grade at ${x}, ${z}`);
    assert.ok(Math.abs(heightAt(x, z + 0.5) - y) / 0.5 < 0.15, `gentle north-south grade at ${x}, ${z}`);
  }
});

test('every site is reachable from camp with a faun-sized clearance around solid landmarks', () => {
  const step = 0.5, limit = Math.floor((BOUNDS - 1) / step), colliders = worldColliders();
  const key = (x, z) => `${x},${z}`;
  const open = (x, z) => Math.abs(x) <= limit && Math.abs(z) <= limit
    && colliders.every((obstacle) => Math.hypot(x * step - obstacle.x, z * step - obstacle.z) >= obstacle.radius + 0.3);
  const visited = new Set([key(0, 8)]), pending = [[0, 8]];
  for (let index = 0; index < pending.length; index++) {
    const [x, z] = pending[index];
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const X = x + dx, Z = z + dz, id = key(X, Z);
      if (visited.has(id) || !open(X, Z)) continue;
      visited.add(id);
      pending.push([X, Z]);
    }
  }
  for (const site of SITES) {
    assert.ok(Math.abs(site.x) < BOUNDS - 1 && Math.abs(site.z) < BOUNDS - 1, `${site.name} stays inside the playable valley`);
    assert.ok(pending.some(([x, z]) => Math.hypot(x * step - site.x, z * step - site.z) < 0.75), `${site.name} has an accessible healing position`);
  }
});
