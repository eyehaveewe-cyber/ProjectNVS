/** Run with CHROMIUM_PATH=/path/to/chromium node tools/browser-smoke.mjs.
 * Requires Playwright for development QA; the game itself has no dependencies. */
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {SITES} from '../src/simulation.js';
const require=createRequire(import.meta.url);
const {chromium}=require('playwright');
process.env.PORT ||= '5187';
const {server}=await import('./serve.mjs');
const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const errors=[],checks=[];
const context=await browser.newContext({viewport:{width:1440,height:900}});
const page=await context.newPage();
page.on('pageerror',e=>errors.push(e.message));
const origin='http://127.0.0.1:'+process.env.PORT;
const capture=async(name)=>page.screenshot({path:fileURLToPath(new URL('../docs/'+name+'.jpg',import.meta.url)),type:'jpeg',quality:90});
const check=(name,condition=true)=>{assert.ok(condition,name);checks.push(name);};
try{
  await mkdir(new URL('../docs/',import.meta.url),{recursive:true});
  await page.goto(origin+'/?test=1');await page.waitForFunction(()=>window.__NVS__?.renderer.stats);
  await capture('menu');
  await page.click('#begin');await page.waitForFunction(()=>!document.querySelector('#hud').hidden);
  check('WebGL renders a real depth-buffer scene',await page.evaluate(()=>__NVS__.renderer.stats.triangles>25000));
  check('Audio context unlocked from Begin gesture',await page.evaluate(()=>__NVS__.audio.context?.state==='running'));
  const start=await page.evaluate(()=>({...__NVS__.state.player}));
  await page.keyboard.down('ArrowLeft');
  await page.waitForFunction(p=>Math.hypot(__NVS__.state.player.x-p.x,__NVS__.state.player.z-p.z)>.3,start,{timeout:7000});
  await page.keyboard.up('ArrowLeft');
  check('Arrow movement changes the faun position',await page.evaluate(p=>Math.hypot(__NVS__.state.player.x-p.x,__NVS__.state.player.z-p.z)>.3,start));
  await capture('valley-start');
  await page.keyboard.press('Space');
  const beforePipe=await page.evaluate(()=>({...__NVS__.state.player}));
  await page.keyboard.press('w');
  check('W plays a note instead of walking with pipes raised',await page.evaluate(p=>__NVS__.playing&&__NVS__.state.player.x===p.x&&__NVS__.state.player.z===p.z,beforePipe));
  await page.keyboard.press('Space');
  await page.click('#journal-toggle');
  check('Journal pauses gameplay',await page.evaluate(()=>__NVS__.paused&&!document.querySelector('#journal').hidden));
  await page.click('[data-waypoint="grove-roots"]');
  check('Journal destination returns to gameplay',await page.evaluate(()=>!__NVS__.paused));
  await page.evaluate(()=>{__NVS__.state.player.x=-12;__NVS__.state.player.z=-9;__NVS__.state.player.yaw=Math.PI;});
  await page.waitForTimeout(1200);await page.keyboard.press('Space');await page.waitForTimeout(350);await capture('restoration-before');
  await page.keyboard.press('r');
  check('Wrong note does not heal a site',await page.evaluate(()=>__NVS__.state.healed.length===0));
  let count=0;
  for(const site of SITES){
    await page.evaluate(s=>{__NVS__.state.player.x=s.x;__NVS__.state.player.z=s.z+1.5;__NVS__.state.player.yaw=Math.PI;__NVS__.setPipes(true);},site);
    for(const index of site.sequence)await page.keyboard.press(['q','w','e','r','t'][index]);
    count++;await page.waitForFunction(n=>__NVS__.state.healed.length===n,count);
    check('Keyboard melody restores '+site.id);
    if(count===1){await page.waitForTimeout(500);await capture('restoration-after');}
    if(count===4){await page.waitForTimeout(500);await capture('marsh-restoration');}
    if(count===7){await page.waitForTimeout(500);await capture('orchard-restoration');}
  }
  check('Nine healed sites still require the heart song',await page.evaluate(()=>!__NVS__.state.won));
  await page.evaluate(()=>{__NVS__.state.player.x=0;__NVS__.state.player.z=2;__NVS__.setPipes(true);});
  for(const key of ['q','e','r','t','r','e','q'])await page.keyboard.press(key);
  await page.waitForFunction(()=>__NVS__.state.won);
  check('Final heart song completes the journey');
  await page.waitForTimeout(2400);await capture('ending');
  await page.click('#return');
  await page.evaluate(()=>__NVS__.save());
  await page.reload();await page.click('#begin');
  check('Starting over requires a second click when a save exists',await page.evaluate(()=>!document.querySelector('#menu').hidden&&JSON.parse(localStorage.getItem('project-nvs-journey-v1')).won));
  await page.click('#continue');
  check('Continue restores completed journey',await page.evaluate(()=>__NVS__.state.won&&__NVS__.state.healed.length===9));
  await page.click('#pause-toggle');await page.keyboard.press('Escape');
  check('Pause resumes with Escape',await page.evaluate(()=>!__NVS__.paused));
  await page.evaluate(()=>{__NVS__.state.player.x=0;__NVS__.state.player.z=4;__NVS__.state.player.energy=.2;__NVS__.state.player.comfort=.2;});
  await page.keyboard.press('e');
  await page.waitForFunction(()=>__NVS__.state.resting===0&&__NVS__.state.player.energy>.5,null,{timeout:20000});
  check('Timed camp rest restores needs');
  await page.setViewportSize({width:390,height:844});await page.waitForTimeout(600);await capture('mobile');
  check('Mobile controls visible',await page.locator('#touch-move').isVisible());
  const overlaps=await page.evaluate(()=>{
    const ids=['music-panel','touch-move','wellbeing'];
    const boxes=[document.querySelector('#music-panel'),document.querySelector('#touch-move'),document.querySelector('.wellbeing')].map(e=>e.getBoundingClientRect());
    const out=[];for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++){const a=boxes[i],b=boxes[j];if(a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top)out.push(ids[i]+' overlaps '+ids[j]);}return out;
  });
  check('Mobile primary controls do not overlap',!overlaps.length);
  check('No uncaught browser errors',errors.length===0);
  const result={status:'passed',checks,errors,renderer:await page.evaluate(()=>__NVS__.renderer.stats),note:'Keyboard input exercises all melodies. Test mode relocates the player between sanctuaries to keep coverage repeatable; movement is separately exercised.'};
  await writeFile(new URL('../docs/browser-verification.json',import.meta.url),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
}finally{await browser.close();server.close();}
