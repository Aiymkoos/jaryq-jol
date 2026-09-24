import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {Progress,guidance} from '../navigation.js';
const read=name=>readFileSync(new URL('../../docs/js/'+name,import.meta.url),'utf8');
function context(values={}){return vm.createContext({console,setTimeout,clearTimeout,...values});}
function load(c,file,expression){vm.runInContext(read(file),c);return vm.runInContext(expression,c);}
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject};}
test('OCR rejects whole uncertain phrase without deleting negation',async()=>{
 const c=context({Tesseract:{createWorker:async()=>({recognize:async()=>({data:{text:'не переходите дорогу',confidence:85,words:[{text:'не',confidence:30},{text:'переходите',confidence:95},{text:'дорогу',confidence:95}]}})})}});
 const o=load(c,'ocr.js','OCR');assert.equal((await o.read({})).text,'');
});
test('OCR preserves full text and retries model download after failure',async()=>{
 let calls=0;const c=context({Tesseract:{createWorker:async()=>{if(++calls===1)throw Error('offline');return {recognize:async()=>({data:{text:'Первая строка\nВторая строка',confidence:90,words:[{text:'строка',confidence:90}]}})}}}});
 const o=load(c,'ocr.js','OCR');await assert.rejects(o.read({}));assert.equal((await o.read({})).text,'Первая строка\nВторая строка');assert.equal(calls,2);
});
test('object recognition retries failed model download and never estimates distance',async()=>{
 let calls=0;const c=context({cocoSsd:{load:async()=>{if(++calls===1)throw Error('offline');return {detect:async()=>[{bbox:[0,0,100,100],class:'car',score:.9}]}}}});
 load(c,'i18n.js','I18N');load(c,'labels.js','LABELS');const v=load(c,'vision.js','Vision');await assert.rejects(v.observe({width:100,height:100}));const result=v.describe(await v.observe({width:100,height:100}),'ru');assert.match(result,/Машина/);assert.doesNotMatch(result,/близко|далеко/);
});
function webVision(data){
 let output;const tags={
  video:()=>({style:{},setAttribute(){},async play(){},remove(){},videoWidth:1280,videoHeight:960}),
  canvas:()=>({getContext:()=>({drawImage(){},getImageData:(x,y,w,h)=>({data:new Uint8ClampedArray(w*h*4).fill(255)})})}),
  script:()=>({})};
 const c=context({window:{},Tesseract:{createWorker:async()=>({recognize:async(image,options,out)=>{output=out;return {data};}})},
  navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop(){}}]})}},
  document:{createElement:t=>tags[t](),body:{append(){}},head:{appendChild:s=>queueMicrotask(()=>s.onload())}}});
 vm.runInContext(readFileSync(new URL('../vision.js',import.meta.url),'utf8'),c);
 return {read:async()=>JSON.parse(await c.window.jaryq.capture('text','rus+kaz')),output:()=>output};
}
const blocks=words=>[{paragraphs:[{lines:[{words}]}]}];
test('published OCR rejects a confident average that hides an unsure dosage digit',async()=>{
 const v=webVision({text:'Аспирин 100 мг',confidence:80,blocks:blocks([{text:'Аспирин',confidence:95},{text:'100',confidence:30},{text:'мг',confidence:94}])});
 assert.equal((await v.read()).text,'');assert.equal(v.output()?.blocks,true);
});
test('published OCR reads a fully confident label with its line breaks',async()=>{
 const v=webVision({text:'Аспирин 100 мг\nДәрілік зат\n',confidence:95,blocks:blocks([{text:'Аспирин',confidence:96},{text:'100',confidence:95},{text:'мг',confidence:94},{text:'Дәрілік',confidence:94},{text:'зат',confidence:96}])});
 assert.equal((await v.read()).text,'Аспирин 100 мг\nДәрілік зат');
});
test('camera releases tracks after failed video playback',async()=>{
 let stopped=0;const video={setAttribute(){},play:async()=>{throw Error('play failed')}};
 const c=context({navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop(){stopped++}}]})}},document:{getElementById:()=>video}});
 const camera=load(c,'camera.js','Camera');await assert.rejects(camera.capture());assert.equal(stopped,1);assert.equal(video.srcObject,null);
});
test('camera releases a late permission result after Stop',async()=>{
 let stopped=0;const request=deferred();const c=context({navigator:{mediaDevices:{getUserMedia:()=>request.promise}},document:{getElementById:()=>({})}});
 const camera=load(c,'camera.js','Camera');const pending=camera.capture();camera.stop();request.resolve({getTracks:()=>[{stop(){stopped++}}]});await assert.rejects(pending);assert.equal(stopped,1);
});
function appContext(){
 const elements=new Map();const el=id=>{if(!elements.has(id))elements.set(id,{textContent:'',disabled:false,classList:{toggle(){}},setAttribute(){},querySelector(){return {textContent:''}},addEventListener(){}});return elements.get(id)};
 const spoken=[],capture=deferred();let rate='normal';const c=context({window:{addEventListener(){}},document:{documentElement:{},getElementById:el,addEventListener(){}},localStorage:{getItem:k=>k==='rate'?'broken':null,setItem(){}},Speech:{get rate(){return rate},cycleRate(){rate=rate==='normal'?'fast':rate==='fast'?'slow':'normal'},setLanguage(){},supported:true,speak:t=>spoken.push(t),stop(){}},Camera:{capture:()=>capture.promise,stop(){}},Vision:{observe:async()=>({}),describe:()=> 'LATE RESULT'}});
 load(c,'i18n.js','I18N');vm.runInContext(read('app.js').replace('  init();','  globalThis.actions={describeScene,stop};\n  init();'),c,{timeout:100});return {c,spoken,capture};
}
test('invalid saved speech rate cannot hang startup',()=>{appContext()});
test('Stop suppresses an in-flight camera result',async()=>{
 const {c,spoken,capture}=appContext();const pending=c.actions.describeScene();c.actions.stop();capture.resolve({});await pending;assert.ok(!spoken.includes('LATE RESULT'));
});
const p=x=>({lat:43.25,lon:76.94+x/(111320*Math.cos(43.25*Math.PI/180))});
const route={points:[p(0),p(100),p(300)],steps:[{point:p(0),type:'depart',bearing:90},{point:p(100),type:'turn',modifier:'left'},{point:p(300),type:'arrive'}],destination:{point:p(300)}};
test('turn is announced with distance and retained until passed',()=>{const g=new Progress(route);g.update(p(10),5,1000,1000);assert.equal(g.step,1);assert.match(guidance(g),/через 90 метров/);g.update(p(90),5,2000,2000);assert.equal(g.step,1);assert.match(guidance(g),/Поворот рядом/);g.update(p(115),5,3000,3000);assert.equal(g.step,2)});
test('nonfinite and future GPS timestamps do not advance',()=>{const g=new Progress(route);assert.equal(g.update(p(100),5,NaN,1000).state,'uncertain');assert.equal(g.update(p(100),5,50000,1000).state,'uncertain');assert.equal(g.along,0)});

import {spokenAddress} from '../address.js';
test('address names a footway and house without unnecessary country',()=>{assert.equal(spokenAddress({footway:'Аллея',house_number:'12',suburb:'Центр',country:'Казахстан'}),'Аллея, 12, Центр');assert.equal(spokenAddress(null),'');});

function mainApp(){
 const elements=new Map();const el=id=>{if(!elements.has(id))elements.set(id,{value:'',dataset:{},hidden:false,open:false,classList:{remove(){},add(){},toggle(){},contains(){return false}},replaceChildren(){},append(){},setAttribute(){},removeAttribute(){},showModal(){this.open=true},close(){this.open=false},focus(){}});return elements.get(id)};
 const fix=deferred();let watches=0;const c=context({URL,URLSearchParams,AbortController,setInterval,clearInterval,Progress,guidance,meters:(a,b)=>0,parseRoute(){},instruction:()=>'',command(){},announcementKey:()=>'',spokenAddress,fetch:async()=>({json:async()=>({})}),localStorage:{getItem:()=>null},navigator:{onLine:true,geolocation:{getCurrentPosition:resolve=>fix.promise.then(resolve),watchPosition(){watches++;return 1},clearWatch(){}}},document:{hidden:false,documentElement:{classList:{contains(){return false}}},querySelectorAll:()=>[],querySelector:()=>el('searchbutton'),getElementById:el,addEventListener(){}},window:{addEventListener(){},jaryq:{cancel(){}}}});
 const code=readFileSync(new URL('../app.js',import.meta.url),'utf8').replace(/^import .*;\r?\n/gm,'');
 vm.runInContext(code+"\nglobalThis.hooks={startGuidance,stopAll,setRoute:r=>{route=r;progress=new Progress(r)}};",c);return {c,fix,watches:()=>watches};
}
test('Stop during GPS startup cannot reactivate guidance',async()=>{const {c,fix,watches}=mainApp();c.hooks.setRoute(route);const pending=c.hooks.startGuidance();c.hooks.stopAll();fix.resolve({coords:{latitude:43.25,longitude:76.94,accuracy:5},timestamp:Date.now()});await pending;assert.equal(watches(),0)});
