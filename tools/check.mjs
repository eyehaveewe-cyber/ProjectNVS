import {readdir} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
for(const f of await readdir(new URL('../src/',import.meta.url))){
  if(!f.endsWith('.js'))continue;
  const result=spawnSync(process.execPath,['--check',fileURLToPath(new URL('../src/'+f,import.meta.url))],{stdio:'inherit'});
  if(result.status)process.exit(result.status);
}
console.log('All game modules passed syntax checking.');
