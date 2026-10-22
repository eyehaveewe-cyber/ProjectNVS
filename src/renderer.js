/** Perspective and depth-buffer rendering adapted from Zendelves lib/lab/surface-renderer.ts,
 * commit 357aa0f77b0c8080074745e3f56b2a7a78241d04. Mesh lighting/instance transforms are new. */
const VERTEX = `attribute vec3 p; attribute vec3 n; attribute vec3 tint;
uniform vec3 eye; uniform vec2 angle; uniform vec2 projection;
uniform vec3 translate; uniform vec3 rotate; uniform vec3 scale;
varying float shade; varying float depth; varying vec3 vTint; varying float worldY;
vec3 turn(vec3 v){
 float s=sin(rotate.x),c=cos(rotate.x); v=vec3(v.x,v.y*c-v.z*s,v.y*s+v.z*c);
 s=sin(rotate.z);c=cos(rotate.z);v=vec3(v.x*c-v.y*s,v.x*s+v.y*c,v.z);
 s=sin(rotate.y);c=cos(rotate.y);return vec3(v.x*c+v.z*s,v.y,-v.x*s+v.z*c);
}
void main(){
 vec3 normal=normalize(turn(n));
 float lit=dot(normal,normalize(vec3(-.45,.85,-.3)));
 shade=.62+.35*max(lit,-lit*.65);vTint=tint;
 vec3 world=turn(p*scale)+translate;worldY=world.y;
 vec3 d=world-eye; float s=sin(angle.x),c=cos(angle.x);
 float h=d.x*s+d.z*c;float cy=d.y*cos(angle.y)-h*sin(angle.y);
 float cz=h*cos(angle.y)+d.y*sin(angle.y);
 gl_Position=vec4((d.x*c-d.z*s)*projection.x,cy*projection.y,1.0016*cz-.16013,cz);
 depth=cz;
}`;
const FRAGMENT = `precision mediump float;
uniform vec3 color;uniform vec3 fog;uniform vec3 focus;uniform float focusRadius;uniform float focusY;uniform float cutout;
varying float shade;varying float depth;varying vec3 vTint;varying float worldY;
void main(){
 float d=distance(gl_FragCoord.xy,focus.xy)/focusRadius;
 if(cutout>.5&&d<1.&&depth<focus.z-.6&&worldY>focusY-.9){
  float coverage=3.*(1.-smoothstep(.6,1.,d));
  if(mod(floor(gl_FragCoord.x)+floor(gl_FragCoord.y)*2.,4.)<coverage)discard;
 }
 vec3 c=color*shade*vTint;float f=smoothstep(28.,100.,depth)*.88;
 gl_FragColor=vec4(mix(c,fog,f),1.);}`;
export function rgb(hex) {
  const n=parseInt(hex.replace('#',''),16);return [(n>>16)/255,((n>>8)&255)/255,(n&255)/255];
}
export class GroveRenderer {
  constructor(canvas) {
    this.canvas=canvas;
    const gl=canvas.getContext('webgl',{alpha:false,antialias:true,preserveDrawingBuffer:true});
    if(!gl)throw new Error('This game needs WebGL. Enable hardware acceleration and reload.');
    this.gl=gl;this.buffers=new WeakMap();this.lost=false;
    const shader=(type,source)=>{const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s));return s;};
    const program=gl.createProgram(),vs=shader(gl.VERTEX_SHADER,VERTEX),fs=shader(gl.FRAGMENT_SHADER,FRAGMENT);
    gl.attachShader(program,vs);gl.attachShader(program,fs);gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(program));
    gl.deleteShader(vs);gl.deleteShader(fs);this.program=program;
    this.locations=Object.fromEntries(['eye','angle','projection','translate','rotate','scale','color','fog','focus','focusRadius','focusY','cutout'].map(k=>[k,gl.getUniformLocation(program,k)]));
    this.p=gl.getAttribLocation(program,'p');this.n=gl.getAttribLocation(program,'n');this.tint=gl.getAttribLocation(program,'tint');
    canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();this.lost=true;document.querySelector('#error').hidden=false;document.querySelector('#error-message').textContent='The graphics context was interrupted. Reload to resume your saved journey.';});
  }
  buffer(geometry) {
    if(this.buffers.has(geometry))return this.buffers.get(geometry);
    const data=[];
    for(let face=0;face<geometry.triangles.length;face++){
      const t=geometry.triangles[face],tint=geometry.colors?.[face]??[1,1,1];
      const [a,b,c]=t.map(i=>geometry.vertices[i]);
      const u=b.map((v,i)=>v-a[i]),v=c.map((w,i)=>w-a[i]);
      let n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];
      const len=Math.hypot(...n)||1;n=n.map(x=>x/len);
      for(const p of [a,b,c])data.push(...p,...n,...tint);
    }
    const gl=this.gl,buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);
    const record={buffer,count:data.length/9};this.buffers.set(geometry,record);return record;
  }
  batch(meshes){
    const geometry={vertices:[],triangles:[],colors:[]};
    for(const mesh of meshes){
      const offset=geometry.vertices.length,tint=rgb(mesh.color);
      geometry.vertices.push(...mesh.geometry.vertices);
      for(const t of mesh.geometry.triangles){geometry.triangles.push(t.map(i=>i+offset));geometry.colors.push(tint);}
    }
    return [{geometry,color:'#ffffff'}];
  }
  release(meshes) {for(const m of meshes){const b=this.buffers.get(m.geometry);if(b){this.gl.deleteBuffer(b.buffer);this.buffers.delete(m.geometry);}}}
  draw(camera,meshes) {
    if(this.lost)return;
    const gl=this.gl,ratio=Math.min(devicePixelRatio||1,1.5),w=Math.floor(innerWidth*ratio),h=Math.floor(innerHeight*ratio);
    if(this.canvas.width!==w||this.canvas.height!==h){this.canvas.width=w;this.canvas.height=h;}
    gl.viewport(0,0,w,h);gl.clearColor(.59,.72,.69,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.disable(gl.CULL_FACE);gl.useProgram(this.program);
    const u=this.locations;
    gl.uniform3fv(u.eye,camera.eye);gl.uniform2f(u.angle,camera.yaw,camera.pitch);
    const f=1/Math.tan(.47);gl.uniform2f(u.projection,f*h/w,f);
    gl.uniform3f(u.fog,.59,.72,.69);
    const focus=camera.focus??[0,1,4],dx=focus[0]-camera.eye[0],dy=focus[1]-camera.eye[1],dz=focus[2]-camera.eye[2];
    const along=dx*Math.sin(camera.yaw)+dz*Math.cos(camera.yaw),depth=Math.max(.1,along*Math.cos(camera.pitch)+dy*Math.sin(camera.pitch));
    const sx=(dx*Math.cos(camera.yaw)-dz*Math.sin(camera.yaw))*f*h/(2*depth)+w/2;
    const sy=(dy*Math.cos(camera.pitch)-along*Math.sin(camera.pitch))*f*h/(2*depth)+h/2;
    gl.uniform3f(u.focus,sx,sy,depth);gl.uniform1f(u.focusRadius,f*h*.85/depth);gl.uniform1f(u.focusY,focus[1]);
    let triangles=0;
    for(const mesh of meshes){
      const b=this.buffer(mesh.geometry);gl.bindBuffer(gl.ARRAY_BUFFER,b.buffer);
      gl.enableVertexAttribArray(this.p);gl.vertexAttribPointer(this.p,3,gl.FLOAT,false,36,0);
      gl.enableVertexAttribArray(this.n);gl.vertexAttribPointer(this.n,3,gl.FLOAT,false,36,12);
      gl.enableVertexAttribArray(this.tint);gl.vertexAttribPointer(this.tint,3,gl.FLOAT,false,36,24);
      gl.uniform3fv(u.translate,mesh.position??[0,0,0]);gl.uniform3fv(u.rotate,mesh.rotation??[0,0,0]);
      gl.uniform3fv(u.scale,typeof mesh.scale==='number'?[mesh.scale,mesh.scale,mesh.scale]:(mesh.scale??[1,1,1]));
      gl.uniform1f(u.cutout,mesh.geometry.colors?1:0);
      gl.uniform3fv(u.color,Array.isArray(mesh.color)?mesh.color:rgb(mesh.color));gl.drawArrays(gl.TRIANGLES,0,b.count);triangles+=b.count/3;
    }
    this.stats={draws:meshes.length,triangles};
  }
}
