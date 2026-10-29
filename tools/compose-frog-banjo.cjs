// Run: node tools/compose-frog-banjo.cjs /path/to/MBean1/model.js
// Compose directly in MBean1's event model; its guitar patches are editing
// proxies because the current MBean1 instrument catalog has no banjo.
const fs = require('fs'), vm = require('vm');
const modelPath = process.argv[2];
if (!modelPath) throw Error('Provide the current MBean1 model.js path');
const ctx = vm.createContext({console, Date, JSON, Math});
vm.runInContext(fs.readFileSync(modelPath,'utf8')+'\nthis.MusicModel = MusicModel;',ctx);
const M = ctx.MusicModel, p = M.defaultProject();
p.bars = 16; p.bpm = 116; p.arrangement.endTick = 16*M.BAR;
p.brief.title = 'Frog Lantern Rag';
p.brief.description = 'Original playful wetland banjo-band tune. MBean1 guitar instruments are edit-time proxies; the game renders the authored note events with its own modeled banjo.';
const lead = M.track('Banjo melody (proxy)','archtopGuitarSample',0.72); lead.role='lead';
const rolls = M.track('Second banjo (proxy)','archtopGuitarSample',0.39); rolls.role='harmony';
const bass = M.track('Plucked bass','uprightBassSample',0.42); bass.role='bass';
// A and answering A', then a rising, rhythmically altered B. The return borrows
// the opening rhythm but changes its melody and lands on a sustained G.
const melody = [
 [67,71,74,71,69,67,62,67], [71,74,76,74,71,69,67,null],
 [69,72,76,72,71,69,67,69], [74,72,71,69,67,null,62,null],
 [67,71,74,71,69,67,62,67], [71,74,79,76,74,71,69,null],
 [72,76,79,76,74,72,71,69], [74,78,81,78,76,74,71,null],
 [79,null,78,76,74,76,79,null], [81,79,76,74,72,null,74,76],
 [79,76,72,null,76,74,72,71], [69,71,74,76,78,null,74,null],
 [67,71,74,71,69,67,64,67], [72,76,79,76,74,72,71,null],
 [69,71,74,78,76,74,71,69], [67,71,74,67,null,null,null,null]
];
const chords=[[55,59,62],[55,59,62],[48,52,55],[50,54,57],[55,59,62],[55,59,62],[48,52,55],[50,54,57],[52,55,59],[48,52,55],[48,52,55],[50,54,57],[55,59,62],[48,52,55],[50,54,57],[55,59,62]];
for (let bar=0;bar<16;bar++) {
 for(let i=0;i<8;i++) {
   const pitch=melody[bar][i]; if(pitch!==null) {
    const duration=(bar===15 && i===3)?900:([0,4].includes(i)?205:165);
    lead.notes.push(M.note(bar*1920+i*240,duration,pitch,i===0?0.85:i%2?0.66:0.74));
   }
   if(!(bar===15 && i>=4)) {
    const c=chords[bar], pattern=[0,2,1,2,0,2,1,2], pitch=c[pattern[i]]+(i%2?12:0);
    rolls.notes.push(M.note(bar*1920+i*240+30,145,pitch,i%2?0.43:0.52));
   }
 }
 const root=chords[bar][0]-12;
 for(const beat of [0,2]) bass.notes.push(M.note(bar*1920+beat*480,650,beat===0?root:root+7,0.62));
}
p.tracks=[lead,rolls,bass];
const valid=M.validate(p);fs.writeFileSync('assets/frog-lantern-rag.mbean.json',JSON.stringify(valid,null,2)+'\n');
console.log(JSON.stringify({bars:valid.bars,bpm:valid.bpm,tracks:valid.tracks.map(t=>({name:t.name,notes:t.notes.length})),endTick:valid.arrangement.endTick}));
