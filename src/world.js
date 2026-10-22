/**
 * The valley is original ProjectNVS content built with Zendelves' loft/limb
 * geometry vocabulary. Park–Miller seeded placement follows Zendelves game.ts,
 * commit 357aa0f77b0c8080074745e3f56b2a7a78241d04. No external assets.
 * Meshes are merged by color: rebuilding restoration never adds draw calls.
 */
import { box, loft, limb, prism, pyramid, surface } from './geometry.js';
import { SITES } from './simulation.js';

export const BOUNDS = 27;
const TAU = Math.PI * 2;
const P = {
  grass: ['#718b60', '#7d9367', '#879b6b', '#677f57', '#95a777'],
  grove: ['#514657', '#58495f', '#65516c', '#5c4e66', '#483e50'],
  marsh: ['#777654', '#6e7250', '#85835b', '#747c59', '#939267'],
  ash: ['#7a6b61', '#72655e', '#8a7869', '#89796b', '#6c615a'],
  healed: ['#709b62', '#82a76c', '#8eb277', '#729760', '#97b77c'],
  bark: '#6f6047', barkLight: '#887352', dead: '#4b4049', char: '#49433e',
  leaf: ['#62895b', '#749c62', '#88a96a', '#9ab573', '#4c7855'],
  bloom: ['#e5c578', '#dd9f96', '#d1cf9b', '#bcb6d6'],
  stone: '#a5a28b', stoneSide: '#8c8a79', gold: '#dfc47a', water: '#678b8e',
};

// Gentle hills only. All terrain, props, and actors share this same function.
export function heightAt(x, z) {
  return .18 + Math.sin(x * .12 + .5) * .16 + Math.cos(z * .14 - .3) * .12
    + Math.sin((x + z) * .18) * .075;
}

function random(seed = 11709) {
  let s = (Math.abs(Math.trunc(seed)) % 2147483646) + 1;
  return () => { s = s * 48271 % 2147483647; return s / 2147483647; };
}
function distance(a, b, x, z) { return Math.hypot(a - x, b - z); }
function ring(x, y, z, radius, n = 8) {
  return Array.from({ length: n }, (_, i) => [x + Math.cos(i / n * TAU) * radius, y, z + Math.sin(i / n * TAU) * radius]);
}
function disc(x, y, z, radius, n = 10) {
  return surface([[x, y, z], ...ring(x, y, z, radius, n)], Array.from({ length: n }, (_, i) => [0, i + 1, (i + 1) % n + 1]));
}
function canopy(x, y, z, w, h, d, n = 7, tilt = 0) {
  const outline = Array.from({ length: n }, (_, i) => [Math.cos(i / n * TAU), Math.sin(i / n * TAU)]);
  return loft([
    { x: x - tilt, y: y - h * .38, z, w: w * .56, d: d * .56 },
    { x, y: y - h * .05, z, w, d },
    { x: x + tilt, y: y + h * .38, z: z - d * .08, w: w * .63, d: d * .63 },
    { x: x + tilt * .6, y: y + h * .6, z, w: .035, d: .035 },
  ], outline);
}
function transform(g, x, y, z, yaw = 0, scale = 1) {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  return { vertices: g.vertices.map(([a, b, d]) => [x + (a * c - d * s) * scale, y + b * scale, z + (a * s + d * c) * scale]), triangles: g.triangles };
}

// Rebuilt alongside the visible mesh, so collision never has a separate seed.
let latestColliders = [];
/** Call after buildWorld; circles use the same placements as visible solids. */
export function worldColliders() { return latestColliders; }

export function buildWorld(healedIds = []) {
  const restored = new Set(healedIds), rand = random(), batches = new Map(), colliders = [];
  const collider = (x, z, radius) => {
    // Small shrines are walkable. Their musical interaction centers remain clear.
    if (SITES.some(site => Math.hypot(site.x - x, site.z - z) < radius + .8)) return;
    if (Math.hypot(x, z - 4) < radius + .65) return;
    colliders.push({ x, z, radius });
  };
  const colliderLine = (ax, az, bx, bz, radius) => {
    const steps = Math.max(1, Math.ceil(Math.hypot(bx - ax, bz - az) / (radius * 1.3)));
    for (let i = 0; i <= steps; i++) collider(ax + (bx - ax) * i / steps, az + (bz - az) * i / steps, radius);
  };
  const add = (g, color) => {
    if (!g || !g.vertices.length) return;
    let b = batches.get(color);
    if (!b) batches.set(color, b = { geometry: { vertices: [], triangles: [] }, color });
    const offset = b.geometry.vertices.length;
    b.geometry.vertices.push(...g.vertices);
    b.geometry.triangles.push(...g.triangles.map(t => t.map(i => i + offset)));
  };
  const put = (g, color, x, z, yaw = 0, scale = 1) => add(transform(g, x, heightAt(x, z), z, yaw, scale), color);
  const nearest = (x, z) => SITES.reduce((best, site) => {
    const d = distance(site.x, site.z, x, z);
    return !best || d < best.distance ? { site, distance: d } : best;
  }, null);
  // A completed biome heals to its original boundary, including the outer belt.
  // Partial progress remains a local patch around each restored sanctuary.
  const completedKinds = new Set(['corruption', 'pollution', 'scorch'].filter(kind =>
    SITES.filter(site => site.kind === kind).every(site => restored.has(site.id))));
  const healedAt = (x, z) => {
    const n = nearest(x, z);
    return !!n && restored.has(n.site.id) && n.distance < (completedKinds.has(n.site.kind) ? 9 : 7.4);
  };
  const kindAt = (x, z) => {
    const n = nearest(x, z);
    return n && n.distance < 9 ? n.site.kind : null;
  };
  const pick = a => a[Math.floor(rand() * a.length)];

  // A faceted island, with a quiet water horizon and a stone shore below it.
  add(surface([[-120, -.82, -120], [120, -.82, -120], [120, -.82, 120], [-120, -.82, 120]]), '#557f85');
  const grid = 1.9, min = -28.5;
  for (let ix = 0; ix < 30; ix++) for (let iz = 0; iz < 30; iz++) {
    const x = min + ix * grid, z = min + iz * grid, X = x + grid, Z = z + grid;
    const mx = x + grid * .5, mz = z + grid * .5, k = kindAt(mx, mz), heal = healedAt(mx, mz);
    const colors = heal ? P.healed : k === 'corruption' ? P.grove : k === 'pollution' ? P.marsh : k === 'scorch' ? P.ash : P.grass;
    const points = [[x, heightAt(x, z), z], [X, heightAt(X, z), z], [X, heightAt(X, Z), Z], [x, heightAt(x, Z), Z]];
    add(surface(points, [[0, 1, 2]]), pick(colors));
    add(surface(points, [[0, 2, 3]]), pick(colors));
  }
  for (let i = 0; i < 60; i++) {
    const t = i / 60 * TAU, radius = 37 + rand() * 7, x = Math.sin(t) * radius, z = Math.cos(t) * radius;
    const w = 4 + rand() * 6, h = 5 + rand() * 11;
    add(canopy(x, h * .08 - 2, z, w, h, w * .7, 5, 1.5), pick(['#66766b', '#768173', '#7b8677', '#859080']));
  }
  for (let edge = 0; edge < 4; edge++) for (let i = 0; i < 19; i++) {
    const a = -28.5 + i * 3, b = a + 3;
    const p = edge === 0 ? [[a, -28.5], [b, -28.5]] : edge === 1 ? [[28.5, a], [28.5, b]] : edge === 2 ? [[b, 28.5], [a, 28.5]] : [[-28.5, b], [-28.5, a]];
    add(surface([[p[0][0], heightAt(...p[0]), p[0][1]], [p[1][0], heightAt(...p[1]), p[1][1]], [p[1][0], -1.2, p[1][1]], [p[0][0], -1.2, p[0][1]]]), i % 2 ? '#8d8d76' : '#9a987e');
  }

  // Raised, continuous trails let the player read the whole valley at a glance.
  function path(points, width = 1.35) {
    for (let i = 1; i < points.length; i++) {
      const [ax, az] = points[i - 1], [bx, bz] = points[i], d = Math.hypot(bx - ax, bz - az);
      if (d < .001) continue;
      const nx = -(bz - az) / d * width / 2, nz = (bx - ax) / d * width / 2;
      const pts = [[ax + nx, az + nz], [bx + nx, bz + nz], [bx - nx, bz - nz], [ax - nx, az - nz]];
      add(surface(pts.map(([x, z]) => [x, heightAt(x, z) + .022, z])), '#b6ad88');
      for (let k = .9; k < d; k += 1.8) {
        const x = ax + (bx - ax) * k / d, z = az + (bz - az) * k / d;
        add(box([x, heightAt(x, z) + .037, z], [.45, .018, .3]), '#c7bd98');
      }
    }
  }
  path([[0, 5], [0, 1], [-3, -2], [-7, -5], [-11, -9], [-15, -13], [-19, -17]]);
  path([[0, 3], [4, 0], [8, -2], [12, -5], [17, -9], [20, -13]]);
  path([[0, 6], [-2, 9], [-1, 12], [1, 16], [5, 20]]);
  for (const site of SITES) {
    const regionStart = site.kind === 'corruption' ? [-13, -10] : site.kind === 'pollution' ? [14, -7] : [0, 16];
    path([regionStart, [site.x, site.z]], .85);
  }

  function tree(x, z, scale, kind = null, healthy = false, variant = 0) {
    collider(x, z, .27 * scale);
    const y = heightAt(x, z), bark = kind === 'scorch' && !healthy ? P.char : kind === 'corruption' && !healthy ? P.dead : P.bark;
    const local = g => add(transform(g, x, y, z, variant * .7, scale), bark);
    local(limb([0, 0, 0], [.12, 2.9, .06], .25, .14, .24, 6));
    local(limb([.05, 1.25, 0], [-.85, 2.6, .17], .12, .055, .12, 5));
    local(limb([.11, 1.9, .03], [.89, 3.2, .08], .12, .04, .11, 5));
    local(limb([-.47, 2.1, .1], [-1.13, 2.57, .6], .08, .025, .07, 4));
    for (const side of [-1, 1]) local(limb([0, .15, .03], [side * .6, .04, side * .22], .18, .025, .12, 5));
    const leaf = kind === 'corruption' && !healthy ? ['#70536f', '#846582', '#a17b94'] : P.leaf;
    if (kind !== 'scorch' || healthy) {
      for (const [cx, cy, cz, w, h] of [[0, 3.4, 0, 1.45, 1.9], [-.88, 2.8, .24, .95, 1.45], [.9, 3.15, .08, 1.03, 1.5]]) {
        add(transform(canopy(cx, cy, cz, w, h, w * .85, 7, .13), x, y, z, variant * .7, scale), leaf[(variant + Math.floor(cy * 2)) % leaf.length]);
      }
      if (healthy && kind === 'scorch') for (let i = 0; i < 6; i++) {
        const a = i * TAU / 6, cx = Math.cos(a) * 1.03, cz = Math.sin(a) * .7;
        add(transform(canopy(cx, 2.7 + (i % 2) * .45, cz, .13, .2, .13, 5), x, y, z, variant * .7, scale), '#e5b86f');
      }
    } else {
      local(limb([.1, 2.7, .05], [-.25, 3.4, -.1], .07, .015, .06, 4));
    }
  }
  function flower(x, z, color, scale = 1) {
    const y = heightAt(x, z);
    add(limb([x, y, z], [x + .035, y + .34 * scale, z], .015, .012, .015, 4), '#72894e');
    add(canopy(x + .035, y + .36 * scale, z, .12 * scale, .1 * scale, .12 * scale, 5), color);
  }
  function rock(x, z, size = 1) {
    const y = heightAt(x, z);
    add(canopy(x, y + size * .12, z, size * .7, size * .85, size * .55, 5, size * .1), pick(['#9a9981', '#a6a28a', '#8c8c79']));
    if (healedAt(x, z)) add(canopy(x - .1, y + size * .42, z, size * .42, .08, size * .35, 5), '#8eaa72');
  }

  // Each wound owns an immediately visible grove, pool, or orchard tree.
  for (const [index, site] of SITES.entries()) {
    const { x, z, kind, id } = site, y = heightAt(x, z), heal = restored.has(id);
    const runeColor = heal ? '#b4dca2' : kind === 'corruption' ? '#b88db3' : kind === 'pollution' ? '#d5c779' : '#e6a17d';
    add(disc(x, y + .045, z, 1.45, 12), heal ? '#86ab72' : kind === 'corruption' ? '#735873' : kind === 'pollution' ? '#8b8759' : '#9a7864');
    // Broken circular sanctuary, readable in both the damaged and healed state.
    for (let i = 0; i < 8; i++) {
      const a = i / 8 * TAU, sx = x + Math.cos(a) * 1.38, sz = z + Math.sin(a) * 1.38;
      add(box([sx, heightAt(sx, sz) + .12, sz], [.3, .18 + (i % 3) * .04, .27]), i % 3 ? '#acaa8d' : runeColor);
    }
    add(loft([{ x, y: y + .04, z, w: .37, d: .37 }, { x, y: y + .32, z, w: .3, d: .3 }, { x, y: y + .41, z, w: .23, d: .23 }]), '#b5af91');
    add(pyramid([[x - .14, y + .4, z - .14], [x + .14, y + .4, z - .14], [x + .14, y + .4, z + .14], [x - .14, y + .4, z + .14]], [x, y + .98, z]), runeColor);
    if (kind === 'corruption') {
      tree(x - 2.3, z - 1.2, .95 + index * .04, kind, heal, index);
      tree(x + 2.3, z + .2, .75, kind, heal, index + 1);
      if (!heal) for (let i = 0; i < 6; i++) {
        const a = i / 6 * TAU, px = x + Math.cos(a) * (2 + i * .12), pz = z + Math.sin(a) * 2;
        add(limb([px, heightAt(px, pz), pz], [px - .3, heightAt(px, pz) + .75, pz + .2], .11, .01, .09, 4), '#5d3d60');
      }
    } else if (kind === 'pollution') {
      const px = x + 2.8, pz = z + .3, py = heightAt(px, pz) + .022;
      add(disc(px, py, pz, 2.2, 12), heal ? '#7fa9a0' : '#777c4e');
      add(disc(px + .2, py + .006, pz, 1.5, 9), heal ? '#8cb7aa' : '#a1a263');
      for (let i = 0; i < 9; i++) {
        const a = i / 9 * TAU, rx = px + Math.cos(a) * 2.2, rz = pz + Math.sin(a) * 1.9, ry = heightAt(rx, rz);
        add(limb([rx, ry, rz], [rx + .1, ry + .75 + i % 3 * .13, rz], .022, .02, .022, 4), heal ? '#8ba26b' : '#8a8154');
        add(limb([rx + .08, ry + .55, rz], [rx + .1, ry + .82, rz], .07, .07, .055, 5), heal ? '#c5b17b' : '#696849');
      }
      const bx = x - 2.2, bz = z - 1.1;
      put(loft([{ x: 0, y: .03, z: 0, w: .32, d: .32 }, { x: 0, y: .18, z: 0, w: .39, d: .39 }, { x: 0, y: .75, z: 0, w: .39, d: .39 }, { x: 0, y: .9, z: 0, w: .32, d: .32 }]), heal ? '#a6a18a' : '#85634b', bx, bz, .5);
      for (const h of [.2, .7]) put(loft([{ x: 0, y: h, z: 0, w: .397, d: .397 }, { x: 0, y: h + .06, z: 0, w: .397, d: .397 }]), '#5c6259', bx, bz);
      if (heal) flower(bx, bz, '#e4d9a3', 2.2);
    } else {
      tree(x - 2.5, z - .2, .88, kind, heal, index);
      tree(x + 2.3, z + .9, .77, kind, heal, index + 2);
      for (let i = 0; i < 4; i++) {
        const px = x - 2 + i * .8, pz = z + 2.1;
        add(limb([px, heightAt(px, pz), pz], [px + .35, heightAt(px, pz) + .14, pz - .1], .11, .07, .1, 5), heal ? '#8a8a62' : '#48433c');
      }
    }
    for (let i = 0; i < (heal ? 24 : 5); i++) {
      const flowerRand = random(31061 + index * 1009 + i * 79);
      const a = flowerRand() * TAU, r = 1.8 + flowerRand() * 3.3, fx = x + Math.cos(a) * r, fz = z + Math.sin(a) * r;
      const size = .65 + flowerRand() * .9;
      if (heal) flower(fx, fz, P.bloom[i % P.bloom.length], size);
      else if (kind !== 'scorch') {
        add(limb([fx, heightAt(fx, fz), fz], [fx + .1, heightAt(fx, fz) + .4, fz], .025, .005, .02, 3), kind === 'corruption' ? '#665074' : '#8d8b5b');
      }
    }
  }

  // Woodland margin, small grass tufts, broad boulders, and returning flowers.
  for (let i = 0; i < 95; i++) {
    const x = (rand() - .5) * 52, z = (rand() - .5) * 52;
    if (Math.hypot(x, z) < 7 || nearest(x, z).distance < 4.9) continue;
    const k = kindAt(x, z), healed = healedAt(x, z);
    if (rand() < .67) tree(x, z, .64 + rand() * .65, k, healed || !k, i);
    else rock(x, z, .65 + rand() * .8);
  }
  for (let i = 0; i < 560; i++) {
    const grassRand = random(282013 + i * 971);
    const x = (grassRand() - .5) * 55, z = (grassRand() - .5) * 55, k = kindAt(x, z), heal = healedAt(x, z);
    if (Math.hypot(x, z) < 3 || nearest(x, z).distance < 1.6) continue;
    if (!k || heal) {
      if (grassRand() < .22) flower(x, z, P.bloom[Math.floor(grassRand() * P.bloom.length)], .5 + grassRand() * .7);
      else for (const dx of [-.09, .08]) add(surface([[x + dx - .06, heightAt(x, z), z], [x + dx + .08, heightAt(x, z), z], [x + dx, heightAt(x, z) + .18 + grassRand() * .14, z + .05]]), ['#8aa06a', '#a4b377', '#738f59'][Math.floor(grassRand() * 3)]);
    }
  }

  // The Heart: a bare old tree gains leaves as the valley is repaired.
  const heartY = heightAt(0, 0), recovery = restored.size / SITES.length;
  collider(0, 0, .5);
  add(disc(0, heartY + .03, 0, 2.8, 18), '#a8aa81');
  for (let i = 0; i < 7; i++) {
    const a = i / 7 * TAU + .18, x = Math.cos(a) * 2.5, z = Math.sin(a) * 2.5;
    collider(x, z, .25);
    add(loft([{ x, y: heightAt(x, z), z, w: .23, d: .2 }, { x: x + .06, y: heightAt(x, z) + .9 + i % 3 * .13, z, w: .19, d: .17 }, { x, y: heightAt(x, z) + 1.15 + i % 3 * .13, z: z + .03, w: .13, d: .14 }]), i % 2 ? '#a9a78c' : '#b7b298');
    add(box([x, heightAt(x, z) + .64, z + .19], [.08, .32, .025]), recovery > .6 ? '#dfd4a1' : '#777c65');
  }
  add(limb([0, heartY, 0], [.15, heartY + 4.7, 0], .48, .21, .44, 7), '#74624c');
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * TAU, bx = Math.cos(a) * (1.8 + i % 2 * .4), bz = Math.sin(a) * (1.8 + i % 2 * .4), by = heartY + 3.3 + i % 3 * .4;
    add(limb([.1, heartY + 2.1 + i % 2 * .8, 0], [bx, by, bz], .22, .06, .18, 6), '#74624c');
    add(limb([bx * .6, by - .35, bz * .6], [bx * 1.3, by + .6, bz * 1.15], .08, .018, .07, 5), '#897356');
    if (i < Math.ceil(recovery * 6)) add(canopy(bx, by + .4, bz, 1.25, 1.6, 1.1, 7), P.leaf[(i + 1) % P.leaf.length]);
    add(limb([0, heartY + .18, 0], [Math.cos(a) * 1.5, heartY + .03, Math.sin(a) * 1.5], .28, .03, .2, 5), '#887451');
  }
  add(canopy(.05, heartY + 1.65, .34, .16, .36, .09, 5), recovery >= 1 ? '#e9d68a' : '#9fae86');

  // A compact but lived-in faun camp. The resting spot at (0,4) stays clear.
  const tentX = 3.1, tentZ = 5.4, tentY = heightAt(tentX, tentZ);
  for (const tx of [-.7, 0, .7]) for (const tz of [-.55, .15, .75]) {
    collider(tentX + tx * Math.cos(-.4) - tz * Math.sin(-.4), tentZ + tx * Math.sin(-.4) + tz * Math.cos(-.4), .43);
  }
  colliderLine(-1.3 - .8 * Math.cos(.15), 4.7 - .8 * Math.sin(.15), -1.3 + .8 * Math.cos(.15), 4.7 + .8 * Math.sin(.15), .28);
  collider(-3.7, 5.1, .56);
  add(transform(prism([[-1.25, .05], [0, 1.8], [1.25, .05]], -.95, 1.05), tentX, tentY, tentZ, -.4), '#b3b386');
  put(surface([[-1.2, .08, 1.07], [0, 1.77, 1.07], [-.3, .08, 1.07]]), '#939870', tentX, tentZ, -.4);
  put(surface([[.3, .08, 1.08], [0, 1.77, 1.08], [1.2, .08, 1.08]]), '#c6bc8c', tentX, tentZ, -.4);
  put(surface([[-.3, .06, 1.09], [0, 1.58, 1.09], [.3, .06, 1.09]]), '#555f50', tentX, tentZ, -.4);
  put(limb([0, .04, -1.2], [0, 1.9, 0], .045, .045, .045, 5), '#716146', tentX, tentZ, -.4);
  put(limb([0, 1.82, -1.2], [0, 1.82, 1.23], .055, .055, .055, 5), '#716146', tentX, tentZ, -.4);
  // Resting log and woven blanket.
  put(limb([-.92, .32, 0], [.92, .32, 0], .3, .28, .29, 8), '#7e6a4c', -1.3, 4.7, .15);
  put(box([0, .56, .015], [.8, .04, .55]), '#9dafa0', -1.3, 4.7, .15);
  for (const dx of [-.28, -.1, .1, .28]) put(box([dx, .585, .015], [.045, .015, .53]), '#c8c4a1', -1.3, 4.7, .15);
  // Tea table, ceramic cup, satchel, and warm lantern.
  put(box([0, .62, 0], [1.05, .1, .65]), '#9d8760', -3.7, 5.1, -.2);
  for (const dx of [-.38, .38]) put(box([dx, .3, 0], [.1, .6, .48]), '#78664c', -3.7, 5.1, -.2);
  put(loft([{ x: .2, y: .68, z: 0, w: .1, d: .1 }, { x: .2, y: .88, z: 0, w: .13, d: .13 }]), '#c7bb91', -3.7, 5.1, -.2);
  put(box([-.19, .7, .05], [.3, .08, .24]), '#c7ba85', -3.7, 5.1, -.2);
  put(box([0, .16, 0], [.55, .3, .35]), '#8a7251', 1.4, 5.2, .3);
  const lx = 1.6, lz = 2.7, ly = heightAt(lx, lz);
  add(limb([lx, ly, lz], [lx, ly + 1.55, lz], .035, .035, .035, 5), '#706749');
  add(limb([lx, ly + 1.5, lz], [lx - .32, ly + 1.5, lz], .03, .03, .03, 5), '#706749');
  add(box([lx - .32, ly + 1.21, lz], [.22, .34, .22]), '#e8cf88');
  add(pyramid(ring(lx - .32, ly + 1.4, lz, .2, 4), [lx - .32, ly + 1.54, lz]), '#827657');

  // Stone entrance arch and the remnants of the wetland's old aqueduct.
  for (const sx of [-1, 1]) {
    const x = sx * 2.1, z = 9.1, y = heightAt(x, z);
    collider(x, z, .43);
    add(loft([{ x, y, z, w: .4, d: .43 }, { x: x - sx * .08, y: y + 2.5, z, w: .35, d: .38 }]), '#a3a18a');
    add(limb([x, y + 2.4, z], [sx * 1.08, y + 3.08, z], .36, .31, .38, 4), '#b6af93');
  }
  add(box([0, heightAt(0, 9.1) + 3.05, 9.1], [2.25, .5, .82]), '#c0b69a');
  for (let i = 0; i < 5; i++) {
    const x = 19.3, z = -17 + i * 2.25, y = heightAt(x, z);
    collider(x, z, .5);
    add(box([x, y + 1.4, z], [.75, 2.8, .9]), '#a9a48d');
    add(box([x, y + 2.93, z], [1.1, .3, 1.13]), '#b6ae92');
    if (i < 4 && i !== 2) add(box([x, y + 3.2, z + 1.1], [.8, .4, 2.2]), '#afa98f');
  }
  for (let i = 0; i < 6; i++) {
    const x = 7.5 + rand() * 2, z = 18 + rand() * 4;
    add(box([x, heightAt(x, z) + .15, z], [.65, .3, .6]), '#938676');
  }
  add(box([8.4, heightAt(8.4, 21) + .7, 21], [3.5, 1.4, .45]), '#8e8272');
  add(box([10, heightAt(10, 19.8) + .5, 19.8], [.45, 1, 2.6]), '#9b8e7a');

  colliderLine(6.9, 21, 9.9, 21, .29);
  colliderLine(10, 18.7, 10, 20.9, .28);
  latestColliders = colliders;
  return [...batches.values()];
}
