export const meters=(a,b)=>{const R=6371000,toRad=x=>x*Math.PI/180,dl=toRad(b.lat-a.lat),dn=toRad(b.lon-a.lon);const h=Math.sin(dl/2)**2+Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dn/2)**2;return 2*R*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));};
export function parseRoute(data,destination){
 if(data?.code!=='Ok'||!data.routes?.length)throw new Error('no_route');
 const r=data.routes[0],points=r.geometry.coordinates.map(([lon,lat])=>({lat,lon}));
 if(points.length<2||points.some(p=>!Number.isFinite(p.lat)||!Number.isFinite(p.lon)))throw new Error('invalid_route');
 const steps=r.legs.flatMap(l=>l.steps).map(s=>({point:{lat:s.maneuver.location[1],lon:s.maneuver.location[0]},type:s.maneuver.type,modifier:s.maneuver.modifier||'',road:s.name||'',distance:s.distance,bearing:s.maneuver.bearing_after}));
 if(!steps.length||!Number.isFinite(r.distance)||r.distance<=0||!Number.isFinite(r.duration)||r.duration<0||steps.some(s=>!Number.isFinite(s.point.lat)||!Number.isFinite(s.point.lon)||!Number.isFinite(s.distance)||s.distance<0))throw new Error('invalid_route');
 return {points,steps,distance:r.distance,duration:r.duration,destination};
}
export function instruction(s,kk=false){
 const d=kk?{left:'Солға бұрылыңыз',right:'Оңға бұрылыңыз','slight left':'Сәл солға бұрылыңыз','slight right':'Сәл оңға бұрылыңыз','sharp left':'Солға күрт бұрылыңыз','sharp right':'Оңға күрт бұрылыңыз',uturn:'Кері бұрылыңыз'}:{left:'Поверните налево',right:'Поверните направо','slight left':'Немного налево','slight right':'Немного направо','sharp left':'Резко налево','sharp right':'Резко направо',uturn:'Развернитесь'};
 if(s.type==='arrive')return kk?'Межелі жерге жақындадыңыз':'Вы рядом с местом назначения';
 let action=d[s.modifier]||(kk?'Түзу жүріңіз':'Продолжайте прямо');
 if(s.type==='depart'){const dirs=kk?['солтүстік','солтүстік-шығыс','шығыс','оңтүстік-шығыс','оңтүстік','оңтүстік-батыс','батыс','солтүстік-батыс']:['север','северо-восток','восток','юго-восток','юг','юго-запад','запад','северо-запад'];action=kk?`${dirs[Math.round((s.bearing||0)/45)%8]} бағытына қарай жүріңіз`:`Начните движение на ${dirs[Math.round((s.bearing||0)/45)%8]}`;}
 if(['rotary','roundabout','exit roundabout','exit rotary'].includes(s.type))action=kk?'Алда айналма жол. Өткелді тексеріңіз':'Круговой перекрёсток. Проверьте переход';
 return action+(s.road?` · ${s.road}`:'');
}
export function command(text){
 const t=text.toLowerCase().trim();
 if(/^(стоп|останов|замолчи|тоқта)/.test(t))return {action:'stop'};
 if(/повтори|қайтала/.test(t))return {action:'repeat'};
 if(/прочитай|читать|текст|мәтін|оқып/.test(t))return {action:'text'};
 if(/что перед|что вокруг|опиши|обстановк|сипатта|не бар/.test(t))return {action:'scene'};
 if(/где я|моё мест|мое мест|қайдамын/.test(t))return {action:'location'};
 const m=t.match(/^(?:маршрут до|построй маршрут до|проведи до|отведи в|пойти в|иди до|найди|барғым келеді)\s+(.+)$/);
 if(m)return {action:'search',query:m[1]};
 const kk=t.match(/^(.+?)(?:ға|ге|қа|ке) барғым келеді$/);if(kk)return {action:'search',query:kk[1]};
 return {action:'help'};
}
export class Progress{
 constructor(route){this.route=route;this.cumulative=[0];for(let i=1;i<route.points.length;i++)this.cumulative.push(this.cumulative.at(-1)+meters(route.points[i-1],route.points[i]));this.along=0;this.step=0;this.offCount=0;this.arrivalCount=0;this.lastTime=0;this.uncertain=true;this.offRoute=false;this.arrived=false;this.lastAnnouncement='';
 this.stepOffsets=[];let cursor=0;
 for(const step of route.steps){let best=Infinity,index=cursor;for(let i=cursor;i<route.points.length;i++){const d=meters(step.point,route.points[i]);if(d<best){best=d;index=i;}}cursor=index;this.stepOffsets.push(this.cumulative[index]);}
 }
 get toTurn(){return Math.max(0,this.stepOffsets[this.step]-this.along);}
 get remaining(){return Math.max(0,this.cumulative.at(-1)-this.along);}
 update(p,accuracy,timestamp,now=Date.now()){
  if(!Number.isFinite(p?.lat)||!Number.isFinite(p?.lon)||!Number.isFinite(timestamp)||timestamp>now+5000||!Number.isFinite(accuracy)||accuracy<0||accuracy>35||now-timestamp>20000){this.uncertain=true;this.arrivalCount=0;return {state:'uncertain'};}
  if(timestamp<=this.lastTime)return {state:'duplicate'};
  this.lastTime=timestamp;this.uncertain=false;
  let best=Infinity,candidate=this.along;const sx=111320*Math.cos(p.lat*Math.PI/180),sy=111320;
  for(let i=0;i<this.route.points.length-1;i++){
   if(this.cumulative[i+1]<this.along-30||this.cumulative[i]>this.along+200)continue;
   const a=this.route.points[i],b=this.route.points[i+1],ax=(a.lon-p.lon)*sx,ay=(a.lat-p.lat)*sy,dx=(b.lon-a.lon)*sx,dy=(b.lat-a.lat)*sy;
   const span=this.cumulative[i+1]-this.cumulative[i],lo=span?Math.max(0,(this.along-30-this.cumulative[i])/span):0,hi=span?Math.min(1,(this.along+200-this.cumulative[i])/span):1;
   const denom=dx*dx+dy*dy,t=denom?Math.max(lo,Math.min(hi,(-ax*dx-ay*dy)/denom)):0,d=Math.hypot(ax+t*dx,ay+t*dy);
   if(d<best){best=d;candidate=this.cumulative[i]+(this.cumulative[i+1]-this.cumulative[i])*t;}
  }
  this.offCount=best>Math.max(40,accuracy*1.5)?this.offCount+1:0;this.offRoute=this.offCount>=3;
  if(this.offRoute)return {state:'offroute'};
  if(best<=Math.max(25,accuracy))this.along=Math.max(this.along,candidate);
  const old=this.step;
  while(this.step<this.route.steps.length-1&&((this.step===0&&this.along>=5)||this.along>this.stepOffsets[this.step]+10))this.step++;
  const atEnd=this.remaining<25&&meters(p,this.route.points.at(-1))<20&&accuracy<=20;
  this.arrivalCount=atEnd?this.arrivalCount+1:0;this.arrived=this.arrivalCount>=2;
  if(this.arrived)return {state:'arrived'};
  return {state:'tracking',changed:old!==this.step,step:this.route.steps[this.step],remaining:this.remaining};
 }
}

export function guidance(progress,kk=false){
 const step=progress.route.steps[progress.step];
 if(step.type==='depart')return instruction(step,kk);
 const distance=Math.round(progress.toTurn/5)*5;
 if(step.type==='arrive')return kk?`Маршрут соңына шамамен ${distance} метр қалды. Кіреберісті нақтылаңыз.`:`До конца маршрута примерно ${distance} метров. Уточните вход.`;
 if(distance<=15)return kk?`Бұрылыс жақын. GPS бойынша: ${instruction(step,kk)}. Орныңызды нақтылаңыз.`:`Поворот рядом. По GPS: ${instruction(step,kk)}. Уточните положение.`;
 return kk?`Шамамен ${distance} метрден кейін: ${instruction(step,kk)}.`:`Примерно через ${distance} метров: ${instruction(step,kk)}.`;
}
export function announcementKey(progress){return `${progress.step}:${progress.toTurn>100?'far':progress.toTurn>40?'100':progress.toTurn>15?'40':'near'}`;}
