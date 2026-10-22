/**
 * Procedural mesh builders adapted from Zendelves/lib/xen/actor-models.ts,
 * eyehaveewe-cyber/Zendelves @ 357aa0f77b0c8080074745e3f56b2a7a78241d04.
 * Original part/loft/limb/prism/box/surface/pyramid algorithms retained in JS.
 * New faun model and instrument created for ProjectNVS. No external art assets.
 * +Y is up, +Z is forward. Vertices are local to each named joint's pivot.
 */
const chamfer = [[-.6,-1],[.6,-1],[1,-.6],[1,.6],[.6,1],[-.6,1],[-1,.6],[-1,-.6]];
const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]];
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]];
const mul=(a,s)=>[a[0]*s,a[1]*s,a[2]*s];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const unit=v=>mul(v,1/(Math.hypot(...v)||1));

export function merge(...pieces){
  const vertices=[],triangles=[];
  for(const piece of pieces){const offset=vertices.length;vertices.push(...piece.vertices);triangles.push(...piece.triangles.map(([a,b,c])=>[a+offset,b+offset,c+offset]));}
  return {vertices,triangles};
}
export function part(name,color,pivot,...pieces){
  const geometry=merge(...pieces);
  return {name,color,pivot:[...pivot],vertices:geometry.vertices.map(v=>sub(v,pivot)),triangles:geometry.triangles};
}
export function loft(rings,outline=chamfer){
  const vertices=rings.flatMap(r=>outline.map(([x,z])=>[r.x+x*r.w,r.y,r.z+z*r.d]));
  const triangles=[],n=outline.length;
  for(let r=0;r<rings.length-1;r++)for(let i=0;i<n;i++){const j=(i+1)%n,a=r*n+i,b=r*n+j,c=(r+1)*n+j,d=(r+1)*n+i;triangles.push([a,b,c],[a,c,d]);}
  for(let i=1;i<n-1;i++){triangles.push([0,i+1,i]);const end=(rings.length-1)*n;triangles.push([end,end+i,end+i+1]);}
  return {vertices,triangles};
}
export function limb(a,b,ra,rb,depth,sides=4){
  const direction=unit(sub(b,a)),u=unit(cross(direction,Math.abs(direction[2])>.9?[0,1,0]:[0,0,1])),v=unit(cross(direction,u));
  const vertices=[],triangles=[];
  for(const [center,radius] of [[a,ra],[b,rb]])for(let i=0;i<sides;i++){const angle=i/sides*Math.PI*2+Math.PI/4;vertices.push(add(center,add(mul(u,Math.cos(angle)*radius),mul(v,Math.sin(angle)*depth))));}
  for(let i=0;i<sides;i++){const j=(i+1)%sides;triangles.push([i,j,sides+j],[i,sides+j,sides+i]);}
  for(let i=1;i<sides-1;i++)triangles.push([0,i+1,i],[sides,sides+i,sides+i+1]);
  return {vertices,triangles};
}
export function prism(points,back,front){
  const n=points.length,vertices=[back,front].flatMap(z=>points.map(([x,y])=>[x,y,z])),triangles=[];
  for(let i=1;i<n-1;i++)triangles.push([0,i+1,i],[n,n+i,n+i+1]);
  for(let i=0;i<n;i++){const j=(i+1)%n;triangles.push([i,j,n+j],[i,n+j,n+i]);}
  return {vertices,triangles};
}
export function box(center,size){const [x,y,z]=center,[w,h,d]=size.map(n=>n/2);return prism([[x-w,y-h],[x+w,y-h],[x+w,y+h],[x-w,y+h]],z-d,z+d);}
export function surface(vertices,triangles){return {vertices,triangles:triangles??vertices.slice(2).map((_,i)=>[0,i+1,i+2])};}
export function pyramid(base,tip){const vertices=[...base,tip],n=base.length,triangles=[];for(let i=0;i<n;i++)triangles.push([i,(i+1)%n,n]);for(let i=1;i<n-1;i++)triangles.push([0,i+1,i]);return {vertices,triangles};}

function pebble(x,y,z,w,h,d){return loft([{x,y:y-h/2,z,w:w*.45,d:d*.45},{x,y:y-h*.15,z,w,d},{x,y:y+h*.28,z,w:w*.75,d:d*.75},{x,y:y+h/2,z,w:w*.24,d:d*.24}]);}

/** An adult woodland faun, with a human torso and digitigrade goat legs. */
export function createFaunParts(){
  const skin='#bc825a',lightSkin='#d39c6c',skinShade='#996344',fur='#674631',furLight='#8b6240',hair='#302c26',horn='#c0ac7c';
  const torso=[0,1.16,0],head=[0,1.61,.015],parts=[];
  // Sculpted chest and waist remain bare around the diagonal woodland sash.
  parts.push(part('torso',skin,torso,loft([
    {x:0,y:.91,z:-.01,w:.18,d:.14},{x:0,y:1.10,z:0,w:.17,d:.115},
    {x:0,y:1.30,z:.005,w:.235,d:.16},{x:0,y:1.46,z:0,w:.28,d:.145},
    {x:0,y:1.50,z:0,w:.17,d:.115}
  ])),part('torso',lightSkin,torso,
    pebble(-.115,1.36,.145,.105,.13,.026),pebble(.115,1.36,.145,.105,.13,.026)),
    part('torso',skinShade,torso,prism([[-.012,1.20],[.012,1.20],[.018,1.44],[-.018,1.44]],.147,.153)),
    part('torso',skin,torso,limb([0,1.46,0],[0,1.66,.015],.091,.08,.08,6)));
  // Goat fur at the hips, with uneven tufts rather than a straight garment hem.
  parts.push(part('torso',fur,torso,loft([{x:0,y:.86,z:0,w:.22,d:.18},{x:0,y:1.00,z:0,w:.205,d:.16},{x:0,y:1.06,z:0,w:.17,d:.13}])));
  for(let i=0;i<7;i++){const x=(i-3)*.062;parts.push(part('torso',i%2?furLight:fur,torso,prism([[x-.035,.98],[x+.035,.98],[x+.025,.80+(i%3)*.025]],.13,.19)));}
  // Mossy sash crosses the shoulder and wraps the waist. Leaf tips catch light.
  parts.push(part('torso','#526b3d',torso,prism([[-.26,1.47],[-.16,1.51],[.21,1.06],[.13,1.01]],.16,.19),
    loft([{x:0,y:1.00,z:0,w:.215,d:.175},{x:0,y:1.07,z:0,w:.19,d:.16}])),
    part('torso','#8d9f52',torso,prism([[-.245,1.46],[-.206,1.47],[.173,1.045],[.143,1.025]],.192,.199)));
  for(let i=0;i<5;i++){const x=-.20+i*.08,y=1.44-i*.087;parts.push(part('torso',i%2?'#73904b':'#405d3b',torso,prism([[x,y],[x+.06,y+.018],[x+.025,y-.09]],.196,.211)));}
  parts.push(part('torso','#d2b16a',torso,pebble(.15,1.085,.19,.055,.073,.027)));
  // Face has a mature jaw, brows, high cheekbones and a pointed goatee.
  parts.push(part('head',skin,head,loft([
    {x:0,y:1.59,z:.035,w:.065,d:.075},{x:0,y:1.64,z:.035,w:.108,d:.105},
    {x:0,y:1.77,z:.01,w:.142,d:.127},{x:0,y:1.86,z:-.005,w:.10,d:.10}
  ])),part('head',lightSkin,head,pebble(-.09,1.72,.117,.037,.046,.017),pebble(.09,1.72,.117,.037,.046,.017)),
    part('head',skinShade,head,pyramid([[-.025,1.755,.135],[.025,1.755,.135],[.022,1.692,.142],[-.022,1.692,.142]],[0,1.699,.194])),
    part('head','#ebe5ba',head,box([-.061,1.765,.139],[.061,.025,.012]),box([.061,1.765,.139],[.061,.025,.012])),
    part('head','#476449',head,box([-.060,1.765,.149],[.025,.027,.010]),box([.060,1.765,.149],[.025,.027,.010])),
    part('head','#252c25',head,box([-.060,1.765,.155],[.010,.021,.008]),box([.060,1.765,.155],[.010,.021,.008])),
    part('head',hair,head,prism([[-.107,1.798],[-.033,1.788],[-.031,1.805],[-.108,1.815]],.139,.154),prism([[.033,1.788],[.107,1.798],[.108,1.815],[.031,1.805]],.139,.154),
    prism([[-.061,1.647],[.061,1.647],[.043,1.591],[0,1.555],[-.044,1.59]],.085,.128)),
    part('head','#784c3c',head,box([0,1.658,.145],[.071,.012,.012])));
  // Long pointed ears and swept horns form a recognizable silhouette.
  for(const s of [-1,1]){
    const ear=[[s*.105,1.80],[s*.31,1.85],[s*.255,1.72],[s*.12,1.70]];
    parts.push(part('head',skin,head,prism(ear,-.035,.035)),part('head','#d9a080',head,prism([[s*.15,1.78],[s*.27,1.82],[s*.225,1.745]],.037,.043)));
    const hornPath=[[s*.105,1.86,-.045,.077],[s*.17,1.99,-.065,.068],[s*.23,2.04,-.13,.057],[s*.27,2.00,-.225,.047],[s*.245,1.92,-.29,.035],[s*.205,1.85,-.275,.022],[s*.181,1.86,-.22,.005]];
    for(let i=1;i<hornPath.length;i++){const a=hornPath[i-1],b=hornPath[i];parts.push(part('head',i%2?horn:'#a39369',head,limb(a.slice(0,3),b.slice(0,3),a[3],b[3],(a[3]+b[3])*.45,7)));}
    // Shoulder to elbow to relaxed, bent wrist. Music pose rotates around shoulder.
    const arm=[s*.27,1.44,0],elbow=[s*.37,1.18,.06],hand=[s*.28,1.08,.28],an=s<0?'leftArm':'rightArm';
    parts.push(part(an,skin,arm,limb(arm,elbow,.095,.067,.082,6),limb(elbow,hand,.069,.047,.059,6),pebble(hand[0],hand[1],hand[2],.059,.10,.051)),
      part(an,'#4b6541',arm,limb([s*.305,1.103,.238],[s*.28,1.077,.283],.062,.059,.063,6)));
    // Powerful furry thighs, forward knees, backward hocks, and cloven hooves.
    const leg=[s*.14,.95,-.005],knee=[s*.19,.63,.115],hock=[s*.205,.28,-.125],ankle=[s*.205,.12,.045],ln=s<0?'leftLeg':'rightLeg';
    parts.push(part(ln,fur,leg,limb(leg,knee,.135,.10,.13,7),limb(knee,hock,.10,.065,.095,7)),
      part(ln,furLight,leg,limb([s*.18,.70,.12],[s*.20,.57,.075],.087,.074,.088,6)),
      part(ln,'#513b2d',leg,limb(hock,ankle,.064,.057,.063,6)));
    for(const toe of [-1,1]){const x=s*.205+toe*.042;parts.push(part(ln,'#2c302a',leg,loft([{x,y:.02,z:.08,w:.037,d:.105},{x,y:.13,z:.062,w:.04,d:.085},{x,y:.17,z:.035,w:.025,d:.04}])));}
    for(let i=0;i<3;i++)parts.push(part(ln,furLight,leg,prism([[s*.14-.045+i*.04,.91],[s*.14-.009+i*.04,.91],[s*.14-.025+i*.04,.75+(i%2)*.035]],.12,.145)));
  }
  // Tight dark curls cluster around the crown and continue down the nape.
  for(let i=0;i<15;i++){const angle=i*Math.PI*2/11,r=i<11?.12:.065,x=Math.sin(angle)*r,y=i<11?1.84+(i%3)*.014:1.90,z=Math.cos(angle)*r-.01;parts.push(part('head',i%3===0?'#453a2b':hair,head,pebble(x,y,z,.055,.073,.052)));}
  parts.push(part('head',hair,head,pebble(-.11,1.73,-.08,.037,.11,.053),pebble(.11,1.73,-.08,.037,.11,.053)));
  // Seven unequal reeds, tied by two bindings, held between the bent hands.
  // Same shoulder pivot as rightArm lets the renderer raise both together.
  const pipesPivot=[.27,1.44,0];
  for(let i=0;i<7;i++){const x=-.16+i*.052,top=1.19,bottom=.88+i*.027;parts.push(part('pipes',i%2?'#bb8f42':'#d1ad60',pipesPivot,limb([x,bottom,.337],[x,top,.337],.025,.025,.025,7)),part('pipes','#5b472c',pipesPivot,box([x,top+.002,.337],[.026,.006,.024])));}
  parts.push(part('pipes','#56734b',pipesPivot,box([-.005,1.12,.369],[.385,.035,.025]),box([-.005,1.02,.369],[.385,.027,.025])),
    part('pipes','#e0c982',pipesPivot,box([-.005,1.12,.386],[.044,.048,.012])));
  return parts;
}
