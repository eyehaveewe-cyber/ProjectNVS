import {GroveRenderer} from './renderer.js';
import {createFaunParts, surface, pyramid, merge} from './geometry.js';
import {buildWorld, heightAt, BOUNDS, worldColliders} from './world.js';
import {GroveAudio} from './audio.js';
import {SITES, SONGS, createState, serializeState, updateNeeds, moodFor, nearestSite, playNote, startRest, tickRest, completeHeart} from './simulation.js';

const $=id=>document.getElementById(id), clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const SAVE='project-nvs-journey-v1', NOTES=[60,62,64,67,69], KEYS=['Q','W','E','R','T'], NAMES=['C','D','E','G','A'];
const HEART=[0,2,3,4,3,2,0];
let state=createState(), started=false, paused=false, playing=false, muted=false, toastTimer=0;
let world=[], colliders=[], renderer, waypoint=null, heartPhrase=[], lastRecipe='', saveTimer=0;
let cameraYaw=Math.PI+.18, cameraDistance=15, cameraPitch=-.57, walkPhase=0, walkSpeed=0, musicPose=0, noteFlash=0;
let cameraTarget={x:0,z:4}, currentCamera=null, lastTime=performance.now(), particles=[], totalFrames=0;
const held=new Set(), audio=new GroveAudio();
// Identically posed pieces share a draw, while joints retain independent motion.
const groups=new Map();
for(const p of createFaunParts()){
  const key=p.name+':'+p.color;
  if(!groups.has(key))groups.set(key,{name:p.name,color:p.color,pivot:p.pivot,pieces:[]});
  groups.get(key).pieces.push(p);
}
const parts=[...groups.values()].map(p=>({...p,...merge(...p.pieces)}));
let stored=null;
try{stored=localStorage.getItem(SAVE);muted=localStorage.getItem('project-nvs-muted')==='true';}catch{}
if(stored){
  $('continue').hidden=false;$('continue').className='button-primary';$('begin').className='button-quiet';
  $('begin').textContent='Begin a new journey';$('continue').parentNode.prepend($('continue'));
}
audio.setMuted(muted);
function toast(text){$('toast').textContent=text;$('toast').classList.add('visible');toastTimer=5;}
function save(){
  if(!started)return;
  try{stored=JSON.stringify(serializeState(state));localStorage.setItem(SAVE,stored);}catch{toast('Your browser could not save this journey. Keep this tab open to continue.');}
}
function rebuild(){if(renderer)renderer.release(world);const meshes=buildWorld(state.healed);world=renderer?renderer.batch(meshes):meshes;colliders=worldColliders();audio.setRestoration(state.healed.length/9);}
function targetSite(){return SITES.find(s=>s.id===waypoint&&!state.healed.includes(s.id))??SITES.filter(s=>!state.healed.includes(s.id)).sort((a,b)=>Math.hypot(a.x-state.player.x,a.z-state.player.z)-Math.hypot(b.x-state.player.x,b.z-state.player.z))[0]??null;}
function atHeart(){return state.healed.length===9&&Math.hypot(state.player.x,state.player.z)<4&&!state.won;}
function recipe(){return atHeart()?HEART:nearestSite(state)?.sequence??targetSite()?.sequence??[];}
function setPipes(value){
  playing=value;held.clear();state.resting=0;heartPhrase=[];state.sequence=[];state.activeSite=null;lastRecipe='';
  $('music-panel').classList.toggle('playing',playing);
  $('pipes-toggle').textContent=playing?'Space · Lower pipes':'Space · Raise pipes';
  $('pipes-toggle').setAttribute('aria-pressed',String(playing));
  if(playing)audio.unlock();
  renderHud();
}
async function begin(resume=false){
  state=resume?createState(stored):createState();state.player.x=clamp(state.player.x,-BOUNDS+.6,BOUNDS-.6);state.player.z=clamp(state.player.z,-BOUNDS+.6,BOUNDS-.6);
  if(!resume)state.player.yaw=cameraYaw+Math.PI;
  cameraTarget={x:state.player.x,z:state.player.z};
  started=true;paused=false;playing=false;waypoint=null;particles=[];heartPhrase=[];
  $('menu').hidden=true;$('hud').hidden=false;$('pause').hidden=true;$('ending').hidden=true;
  await audio.unlock();rebuild();setPipes(false);save();
  toast(resume?'Your footsteps and songs are remembered.':'Follow a pale path to a wounded place. Space raises your pipes.');
}
function setPause(value,dialog='pause'){
  paused=value;held.clear();
  if(value){audio.stop();save();$(dialog).hidden=false;}
  else{$('pause').hidden=true;$('journal').hidden=true;$('ending').hidden=true;audio.unlock();lastTime=performance.now();}
}
function burst(x,z,color='#eacb79',count=22){
  for(let i=0;i<count;i++){const a=Math.random()*Math.PI*2,r=.2+Math.random()*.6;particles.push({x:x+Math.sin(a)*r,z:z+Math.cos(a)*r,y:heightAt(x,z)+.3,age:0,life:1.5+Math.random()*1.4,vx:Math.sin(a)*(.3+Math.random()),vz:Math.cos(a)*(.3+Math.random()),vy:1+Math.random(),color,size:.045+Math.random()*.05});}
}
function finish(){
  if(!completeHeart(state))return;
  save();burst(0,0,'#fff2bb',75);audio.playMelody([60,64,67,69,72],.32);
  $('ending').querySelector('.small-dialog > p:not(.eyebrow)').textContent=`Every wounded place is singing again. You restored nine sanctuaries in ${Math.max(1,Math.round(state.elapsed/60))} minutes. The valley is yours to wander, and the pipes are yours to play.`;
  setTimeout(()=>{if(started&&!paused)setPause(true,'ending');},2200);
  toast('The heart answers. The valley remembers your song.');
}
function note(index){
  if(!started||paused)return;
  if(!playing)setPipes(true);
  audio.unlock().then(()=>audio.note(NOTES[index],{duration:.48,velocity:.75}));
  noteFlash=.35;
  const button=document.querySelector(`[data-note="${index}"]`);button.classList.add('struck');setTimeout(()=>button.classList.remove('struck'),230);
  burst(state.player.x,state.player.z,['#e6c275','#9ecfc6','#c9d98c','#b5acdc','#e8b5a3'][index],3);
  if(atHeart()){
    if(index===HEART[heartPhrase.length])heartPhrase.push(index);else heartPhrase=index===HEART[0]?[index]:[];
    if(heartPhrase.length===HEART.length)finish();lastRecipe='';renderHud();return;
  }
  const result=playNote(state,index);
  if(result.type==='healed'){
    burst(result.site.x,result.site.z,'#e4e8a1',50);rebuild();save();lastRecipe='';
    toast(state.healed.length===9?'All nine sanctuaries are awake. Return to the heart tree for the final song.':`${result.site.name} is alive again. ${state.healed.length} of 9 sanctuaries restored.`);
    if(waypoint===result.site.id)waypoint=null;
  }else if(result.type==='wrong'){
    $('phrase-progress').textContent='Let the phrase begin again. There is no hurry.';
    $('melody').classList.add('mistake');setTimeout(()=>$('melody').classList.remove('mistake'),320);
  }
  renderHud();
}
function listen(){
  if(!started||paused)return;
  audio.unlock().then(()=>audio.playMelody(recipe().map(n=>NOTES[n]),.47));
  toast('Listen, then answer with the glowing keys. Your own notes heal the land.');
}
function interact(){
  if(!started||paused)return;
  if(startRest(state)){playing=false;$('music-panel').classList.remove('playing');$('pipes-toggle').textContent='Space · Raise pipes';$('pipes-toggle').setAttribute('aria-pressed','false');held.clear();toast('Resting beside the lantern. Stay still for four seconds.');}
}
function journal(){
  const regions=[['corruption','The Hollow Wood'],['pollution','The Bitter Marsh'],['scorch','The Ember Orchard']];
  $('journal-content').innerHTML='<p class="journal-intro">The valley asks for music, not battle. Walk to a marked sanctuary, raise your pipes, listen to its phrase, and play the keys in order. Rhythm is yours to choose.</p>'+regions.map(([kind,name])=>`<section><h3>${name}</h3><p>${SONGS[kind].description}</p>${SITES.filter(s=>s.kind===kind).map(s=>`<button class="journal-site ${state.healed.includes(s.id)?'complete':''}" data-waypoint="${s.id}"><span>${state.healed.includes(s.id)?'✓':'◇'} ${s.name}</span><small>${state.healed.includes(s.id)?'Restored':'Mark on your map'}</small></button>`).join('')}</section>`).join('')+'<p class="journal-intro">Rest at the lantern camp to recover energy and comfort. These needs change your mood, but never take away your ability to walk or play. Your journey saves automatically in this browser.</p>';
  for(const b of $('journal-content').querySelectorAll('[data-waypoint]'))b.onclick=()=>{waypoint=b.dataset.waypoint;setPause(false);renderHud();toast('A path to '+SITES.find(s=>s.id===waypoint).name+' is marked on your map.');};
  setPause(true,'journal');
}

let menuRestartReady=false;
$('begin').onclick=()=>{
  if(stored&&!menuRestartReady){menuRestartReady=true;$('begin').textContent='Replace your saved journey? Click again';setTimeout(()=>{menuRestartReady=false;$('begin').textContent='Begin a new journey';},4000);return;}
  menuRestartReady=false;begin(false);
};
$('continue').onclick=()=>begin(true);
$('pipes-toggle').onclick=()=>setPipes(!playing);$('listen').onclick=listen;$('interact').onclick=interact;
$('pause-toggle').onclick=()=>setPause(!paused);$('resume').onclick=()=>setPause(false);$('journal-toggle').onclick=journal;$('journal-close').onclick=()=>setPause(false);$('return').onclick=()=>setPause(false);
$('sound-toggle').onclick=()=>{muted=!muted;audio.setMuted(muted);$('sound-toggle').textContent=muted?'Sound off':'Sound on';$('sound-toggle').setAttribute('aria-pressed',String(!muted));try{localStorage.setItem('project-nvs-muted',String(muted));}catch{}};
$('sound-toggle').textContent=muted?'Sound off':'Sound on';
let restartReady=false;
$('restart').onclick=()=>{if(!restartReady){restartReady=true;$('restart').textContent='Start over? Click again';setTimeout(()=>{restartReady=false;$('restart').textContent='Start a new journey';},4000);return;}restartReady=false;begin(false);};
for(const b of document.querySelectorAll('[data-note]'))b.addEventListener('pointerdown',e=>{e.preventDefault();note(Number(b.dataset.note));});
for(const b of document.querySelectorAll('[data-move]')){
  const k={forward:'ArrowUp',back:'ArrowDown',left:'ArrowLeft',right:'ArrowRight'}[b.dataset.move];
  b.addEventListener('pointerdown',e=>{e.preventDefault();if(playing)setPipes(false);held.add(k);b.setPointerCapture(e.pointerId);});
  for(const ev of ['pointerup','pointercancel','lostpointercapture'])b.addEventListener(ev,()=>held.delete(k));
}
document.addEventListener('keydown',e=>{
  if(!started)return;
  if(['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();
  if(e.code==='Escape'){if(e.repeat)return;setPause(!paused);return;}
  if(paused)return;
  if(e.code==='Space'){if(!e.repeat)setPipes(!playing);return;}
  if(e.code==='KeyJ'&&!e.repeat){journal();return;}
  if(playing&&KEYS.includes(e.key.toUpperCase())){if(!e.repeat)note(KEYS.indexOf(e.key.toUpperCase()));return;}
  if(e.code==='KeyE'&&!e.repeat){interact();return;}
  held.add(e.code);
});
document.addEventListener('keyup',e=>held.delete(e.code));
window.addEventListener('blur',()=>{held.clear();if(started&&!paused)setPause(true);});
document.addEventListener('visibilitychange',()=>{if(document.hidden&&started&&!paused)setPause(true);});
window.addEventListener('pagehide',save);
let drag=null;
$('world').addEventListener('pointerdown',e=>{drag={x:e.clientX,y:e.clientY};$('world').setPointerCapture(e.pointerId);});
$('world').addEventListener('pointermove',e=>{if(!drag)return;cameraYaw-=(e.clientX-drag.x)*.006;cameraPitch=clamp(cameraPitch-(e.clientY-drag.y)*.003,-1.08,-.28);drag={x:e.clientX,y:e.clientY};});
for(const name of ['pointerup','pointercancel'])$('world').addEventListener(name,()=>drag=null);
$('world').addEventListener('wheel',e=>{e.preventDefault();cameraDistance=clamp(cameraDistance+e.deltaY*.014,8,32);},{passive:false});

const ring=(r,width=.05)=>{
  const vertices=[],triangles=[];
  for(let i=0;i<48;i++){const a=i/48*Math.PI*2;vertices.push([Math.sin(a)*r,0,Math.cos(a)*r],[Math.sin(a)*(r+width),0,Math.cos(a)*(r+width)]);}
  for(let i=0;i<48;i++){const j=(i+1)%48;triangles.push([i*2,j*2,j*2+1],[i*2,j*2+1,i*2+1]);}
  return{vertices,triangles};
};
const siteRing=ring(1,.07),shadow=ring(.04,.32),pulseRing=ring(1,.025);
const spark=pyramid([[-.6,0,0],[0,0,.6],[.6,0,0],[0,0,-.6]],[0,1,0]);
const wing=surface([[0,0,0],[-.25,.1,.1],[-.12,.02,-.13],[0,0,0],[.25,.1,.1],[.12,.02,-.13]],[[0,1,2],[3,4,5]]);
function character(time,dt){
  const p=state.player, yaw=p.yaw, height=heightAt(p.x,p.z),c=Math.cos(yaw),s=Math.sin(yaw);
  musicPose+=(Number(playing)-musicPose)*Math.min(1,dt*7);
  const bob=Math.sin(walkPhase*2)*.035*walkSpeed+(playing?Math.sin(time*2)*.015:0);
  const out=[{geometry:shadow,color:'#374438',position:[p.x,height+.035,p.z],scale:[1.5,1,1]}];
  for(const part of parts){
    const pivot=part.pivot??[0,0,0];
    let rx=0,rz=0;
    if(part.name==='leftLeg')rx=Math.sin(walkPhase)*.48*walkSpeed;
    if(part.name==='rightLeg')rx=-Math.sin(walkPhase)*.48*walkSpeed;
    if(part.name==='leftArm')rx=-Math.sin(walkPhase)*.28*walkSpeed-musicPose*1.03,rz=musicPose*-.12;
    if(part.name==='rightArm'||part.name==='pipes')rx=Math.sin(walkPhase)*.28*walkSpeed-musicPose*1.03,rz=musicPose*.12;
    if(part.name==='head')rx=musicPose*.09;
    const rest=state.resting>0?-.23:0;
    out.push({geometry:part,color:part.color,position:[p.x+pivot[0]*c+pivot[2]*s,height+pivot[1]+bob+rest,p.z-pivot[0]*s+pivot[2]*c],rotation:[rx,yaw,rz]});
  }
  return out;
}
function effects(time,dt){
  const out=[],nearest=nearestSite(state);
  for(const site of SITES){
    const healed=state.healed.includes(site.id),color=healed?'#b9d9a3':site.kind==='corruption'?'#ba8bd9':site.kind==='pollution'?'#a5c6ad':'#dfad7c';
    out.push({geometry:siteRing,color,position:[site.x,heightAt(site.x,site.z)+.07,site.z],scale:healed?.65:1});
    if(!healed){const y=heightAt(site.x,site.z)+1.2+Math.sin(time*1.7+site.x)*.14;out.push({geometry:spark,color,position:[site.x,y,site.z],rotation:[0,time*.55,0],scale:nearest?.id===site.id ? .36 : .22});}
    else for(let i=0;i<2;i++){const a=time*.6+i*3+site.x;out.push({geometry:wing,color:i?'#dfc48a':'#a7d9d0',position:[site.x+Math.sin(a)*1.5,heightAt(site.x,site.z)+1.2+Math.sin(time*2+i)*.3,site.z+Math.cos(a)*1.5],rotation:[Math.sin(time*14+i)*.5,a,0]});}
  }
  if(playing){const size=.7+(time%1)*1.7;out.push({geometry:pulseRing,color:noteFlash>0?'#ffe1a0':'#b0c9b2',position:[state.player.x,heightAt(state.player.x,state.player.z)+.1,state.player.z],scale:size});}
  if(state.healed.length===9){out.push({geometry:siteRing,color:'#ebd897',position:[0,heightAt(0,0)+.1,0],scale:2.4});}
  particles=particles.filter(p=>p.age<p.life);
  for(const p of particles){p.age+=dt;p.x+=p.vx*dt;p.z+=p.vz*dt;p.y+=p.vy*dt;p.vy-=dt*.4;out.push({geometry:spark,color:p.color,position:[p.x,p.y,p.z],rotation:[0,time,0],scale:p.size*(1-p.age/p.life)});}
  return out;
}
function renderHud(){
  if(!started)return;
  const nearby=nearestSite(state),target=targetSite(),heart=atHeart(),n=state.healed.length;
  const biome=nearby?.kind??(state.player.x<-6&&state.player.z<0?'corruption':state.player.x>7&&state.player.z<3?'pollution':state.player.z>9?'scorch':null);
  $('region').textContent=biome?{corruption:'The Hollow Wood',pollution:'The Bitter Marsh',scorch:'The Ember Orchard'}[biome]:'The Lantern Clearing';
  $('healed-count').textContent=`${n} / 9 sanctuaries`;$('land-meter').value=n;
  $('energy-meter').value=state.player.energy;$('comfort-meter').value=state.player.comfort;$('mood').textContent=moodFor(state.player);
  $('objective').textContent=state.won?'The valley sings again':n===9?'Return to the heart tree':nearby?'Let the land hear you':'Find the wounded sanctuaries';
  const dist=target?Math.round(Math.hypot(target.x-state.player.x,target.z-state.player.z)):Math.round(Math.hypot(state.player.x,state.player.z));
  $('objective-hint').textContent=state.won?'Wander, rest, and play freely in the restored valley.':n===9?(heart?'Raise your pipes and play the final song.':`Heart tree · ${dist} paces · in the central clearing`):nearby?`${nearby.name} · Space raises your pipes`:`${target?.name??'Explore the restored valley'} · ${dist} paces · follow your map`;
  $('site-name').textContent=heart?'The Heart Song':nearby?SONGS[nearby.kind].name:playing?'A song for the open air':'Carry a little music';
  $('site-description').textContent=heart?'All the valley’s melodies return to one root.':nearby?nearby.description:playing?'Every pipe is yours to play. Find a wounded sanctuary to restore it.':'Walk to a floating light, then raise your pipes to hear and answer its melody.';
  $('context-hint').textContent=playing?'Q W E R T play · Space lowers pipes':state.resting>0?`Resting · ${Math.ceil(state.resting)} seconds`:'W A S D / arrows walk · Drag to look · Wheel to zoom';
  const r=heart?HEART:nearby?.sequence??[],matched=heart?heartPhrase.length:state.activeSite===nearby?.id?state.sequence.length:0;
  const key=r.join(',')+':'+matched+':'+(nearby?.id??'heart');
  if(lastRecipe!==key){lastRecipe=key;$('melody').innerHTML=r.length?r.map((v,i)=>`<span class="melody-note ${i<matched?'done':''} ${i===matched?'next':''}"><b>${KEYS[v]}</b><small>${NAMES[v]}</small></span>`).join('<i>·</i>'):'<span class="freeplay-label">Five pipes. A valley to wake.</span>';}
  $('phrase-progress').textContent=r.length?`${matched} / ${r.length} notes · ${playing?'Play at your own pace':'Space to begin'}`:'No timing test. Listen, explore, and play.';
  $('listen').hidden=!r.length;$('interact').hidden=Math.hypot(state.player.x,state.player.z-4)>3;
  $('interact').textContent=state.resting>0?`Resting… ${Math.ceil(state.resting)}s`:'E · Rest by the lantern';
}
function drawMap(){
  const canvas=$('map'),ctx=canvas.getContext('2d'),w=canvas.width,c=w/2,k=(w-24)/56;
  ctx.clearRect(0,0,w,w);ctx.fillStyle='#162e2ce6';ctx.beginPath();ctx.arc(c,c,c-2,0,Math.PI*2);ctx.fill();
  ctx.save();ctx.beginPath();ctx.arc(c,c,c-8,0,Math.PI*2);ctx.clip();
  for(const [x,z,r,color] of [[-15,-12,13,'#625267'],[15,-7,13,'#496c68'],[-1,17,12,'#80624e']]){ctx.fillStyle=color;ctx.beginPath();ctx.arc(c+x*k,c+z*k,r*k,0,Math.PI*2);ctx.fill();}
  ctx.strokeStyle='#d1c39660';ctx.lineWidth=2;
  for(const site of SITES){ctx.beginPath();ctx.moveTo(c,c+4*k);ctx.lineTo(c+site.x*k,c+site.z*k);ctx.stroke();}
  const target=targetSite();if(target){ctx.setLineDash([3,4]);ctx.strokeStyle='#eee2ac';ctx.beginPath();ctx.moveTo(c+state.player.x*k,c+state.player.z*k);ctx.lineTo(c+target.x*k,c+target.z*k);ctx.stroke();ctx.setLineDash([]);}
  for(const site of SITES){ctx.fillStyle=state.healed.includes(site.id)?'#b9d8a0':'#e5d7b1';ctx.beginPath();ctx.arc(c+site.x*k,c+site.z*k,site.id===target?.id?4:2.5,0,Math.PI*2);ctx.fill();}
  ctx.fillStyle='#eac97a';ctx.fillRect(c-2,c-2,4,4);ctx.fillStyle='#eee9d3';ctx.font='11px Georgia';ctx.fillText('N',c-4,15);
  ctx.translate(c+state.player.x*k,c+state.player.z*k);ctx.rotate(-state.player.yaw);ctx.fillStyle='#fff9df';ctx.beginPath();ctx.moveTo(0,6);ctx.lineTo(-4,-4);ctx.lineTo(4,-4);ctx.closePath();ctx.fill();ctx.restore();
}
function frame(now){
  const dt=Math.min((now-lastTime)/1000,.045);lastTime=now;const time=now/1000;
  if(started&&!paused){
    updateNeeds(state,dt);audio.tick(dt);saveTimer+=dt;
    if(saveTimer>5){save();saveTimer=0;}
    if(tickRest(state,dt)){toast('Warmth returns. Energy and comfort restored.');save();}
    let x=0,z=0;
    if(!playing){x=Number(held.has('KeyD')||held.has('ArrowRight'))-Number(held.has('KeyA')||held.has('ArrowLeft'));z=Number(held.has('KeyW')||held.has('ArrowUp'))-Number(held.has('KeyS')||held.has('ArrowDown'));}
    const len=Math.hypot(x,z),p=state.player;
    if(len){state.resting=0;const speed=(held.has('ShiftLeft')?4.5:3.2)*dt,dx=(x*Math.cos(cameraYaw)+z*Math.sin(cameraYaw))/len,dz=(-x*Math.sin(cameraYaw)+z*Math.cos(cameraYaw))/len;
      const nx=clamp(p.x+dx*speed,-BOUNDS+.8,BOUNDS-.8),nz=clamp(p.z+dz*speed,-BOUNDS+.8,BOUNDS-.8);
      const clear=(x,z)=>colliders.every(o=>Math.hypot(x-o.x,z-o.z)>=o.radius+.23);
      if(clear(nx,p.z))p.x=nx;
      if(clear(p.x,nz))p.z=nz;
      const target=Math.atan2(dx,dz),delta=Math.atan2(Math.sin(target-p.yaw),Math.cos(target-p.yaw));p.yaw+=delta*Math.min(1,dt*13);
      walkPhase+=dt*9;walkSpeed+=(1-walkSpeed)*Math.min(1,dt*10);
      state.sequence=[];state.activeSite=null;
    }else walkSpeed*=Math.max(0,1-dt*10);
    if(toastTimer>0){toastTimer-=dt;if(toastTimer<=0)$('toast').classList.remove('visible');}
    noteFlash=Math.max(0,noteFlash-dt);
  }
  if(!started){cameraYaw=Math.PI+.18+Math.sin(time*.06)*.14;}
  const p=state.player;cameraTarget.x+=(p.x-cameraTarget.x)*Math.min(1,dt*5);cameraTarget.z+=(p.z-cameraTarget.z)*Math.min(1,dt*5);
  const targetY=heightAt(cameraTarget.x,cameraTarget.z)+.8,hor=cameraDistance*Math.cos(cameraPitch);
  currentCamera={eye:[cameraTarget.x-Math.sin(cameraYaw)*hor,targetY-Math.sin(cameraPitch)*cameraDistance,cameraTarget.z-Math.cos(cameraYaw)*hor],yaw:cameraYaw,pitch:cameraPitch,focus:[p.x,heightAt(p.x,p.z)+1,p.z]};
  const animDt=paused?0:dt;
  renderer.draw(currentCamera,[...world,...effects(time,animDt),...character(time,animDt)]);
  if(totalFrames++%6===0){renderHud();drawMap();}
  requestAnimationFrame(frame);
}
try{renderer=new GroveRenderer($('world'));rebuild();requestAnimationFrame(frame);}catch(error){$('error').hidden=false;$('error-message').textContent=error.message;console.error(error);}

// Explicit test mode exposes state for reproducible end-to-end coverage. No saved cheat flags.
if(new URLSearchParams(location.search).has('test'))window.__NVS__={get state(){return state;},get renderer(){return renderer;},get playing(){return playing;},get audio(){return audio;},begin,note,setPipes,rebuild,save,get paused(){return paused;},get camera(){return currentCamera;}};
