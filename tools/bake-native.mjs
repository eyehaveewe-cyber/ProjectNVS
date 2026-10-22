/** Generate compact native assets from the existing browser game's actual meshes.
 * Development only. The Godot game has no Node, browser or network dependency. */
import {buildWorld,worldColliders} from '../src/world.js';
import {createFaunParts} from '../src/geometry.js';
import {SITES} from '../src/simulation.js';
import {mkdir,writeFile} from 'node:fs/promises';
import {gzipSync} from 'node:zlib';
const palette=[],indices=new Map();
const colorIndex=color=>{if(!indices.has(color)){indices.set(color,palette.length);palette.push(color);}return indices.get(color);};
const rounded=v=>Math.round(v*10000)/10000;
const faces=[],faceIds=new Map();
const empty=()=>({f:[]});
function partition(world){
 const parts=Object.fromEntries(['base','heart',...SITES.map(s=>s.id)].map(id=>[id,empty()]));
 for(const batch of world)for(const t of batch.geometry.triangles){
  const vs=t.map(i=>batch.geometry.vertices[i]),x=vs.reduce((a,v)=>a+v[0],0)/3,z=vs.reduce((a,v)=>a+v[2],0)/3;
  let id='base';
  const nearest=SITES.map(s=>({s,d:Math.hypot(s.x-x,s.z-z)})).sort((a,b)=>a.d-b.d)[0];
  if(Math.hypot(x,z)<6.2)id='heart';else if(nearest.d<12)id=nearest.s.id;
  const flat=vs.flat().map(rounded),key=batch.color+':'+flat.join(',');
  if(!faceIds.has(key)){faceIds.set(key,faces.length);faces.push([colorIndex(batch.color),...flat]);}
  parts[id].f.push(faceIds.get(key));
 }
 return parts;
}
const initial=partition(buildWorld([])),colliders=worldColliders();
const allIds=SITES.map(s=>s.id),full=partition(buildWorld(allIds));
const sites={};
for(const site of SITES){const local=partition(buildWorld([site.id]));sites[site.id]={damaged:initial[site.id],healed:local[site.id],full:full[site.id]};}
const hearts=[];for(let i=0;i<=9;i++)hearts.push(partition(buildWorld(allIds.slice(0,i))).heart);
const data={version:2,palette,faces,base:initial.base,sites,hearts,colliders,definitions:SITES,faun:createFaunParts()};
const output=new URL('../assets/valley.nvs.gz',import.meta.url);
await mkdir(new URL('../assets/',import.meta.url),{recursive:true});
const json=JSON.stringify(data),compressed=gzipSync(json,{level:9});await writeFile(output,compressed);
console.log(JSON.stringify({jsonBytes:Buffer.byteLength(json),assetBytes:compressed.length,palette:palette.length,sites:Object.keys(sites).length,faunParts:data.faun.length}));
