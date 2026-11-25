// Run the captured ta unchanged with lightweight rendering substitutes.
const fs=require('fs');
const source=fs.readFileSync('docs/reference/qqfeiche3d/readable-script.js','utf8');
const start=source.indexOf('  var Vc = {');
const end=source.indexOf('  var Xt = ',start);
const trackStart=source.indexOf('      sample(t, e = this._tmp)');
const trackEnd=source.indexOf('      surfaceY(',trackStart);
const helpers=source.slice(source.indexOf('  var he = '),source.indexOf('  function bn('));
const configStart=source.indexOf('  var qn = {');
const configEnd=source.indexOf('  function kc(',configStart);
const hitStart=source.indexOf('      hitRacer(t, e) {');
class Vector {
  constructor(x=0,y=0,z=0){this.set(x,y,z);}
  set(x,y,z){this.x=x;this.y=y;this.z=z;return this;}
  length(){return Math.hypot(this.x,this.y,this.z);}
  normalize(){const n=this.length();if(n){this.x/=n;this.y/=n;this.z/=n;}return this;}
  lerp(v,a){this.x+=(v.x-this.x)*a;this.y+=(v.y-this.y)*a;this.z+=(v.z-this.z)*a;return this;}
  addScaledVector(v,a){this.x+=v.x*a;this.y+=v.y*a;this.z+=v.z*a;return this;}
}
class Group {
  constructor(){this.position=new Vector();this.rotation={x:0,y:0,z:0};this.scale={setScalar(){}};this.visible=true;}
  add(){} remove(){} lookAt(){}
}
class Geometry {rotateX(){return this;}}
const prelude='var $t=Group,k=Group,I=Vector,Dt=Geometry,Ce=Geometry,Tt=Geometry,Se=Geometry,Zt=Geometry,Rn=Geometry,Me=Geometry,se=0;function Wn(){}';
// Extract just the hit method with balanced braces.
let depth=0,close=source.indexOf('{',hitStart);
for(let i=close;i<source.length;i++){if(source[i]==='{')depth++;if(source[i]==='}'&&--depth===0){close=i+1;break;}}
const api=new Function('Group','Vector','Geometry',prelude+helpers+source.slice(configStart,configEnd)+
  source.slice(start,end)+'; class Track {'+source.slice(trackStart,trackEnd)+'}; class Game {'+
  source.slice(hitStart,close)+'};return {Items:ta,Track,Yo,Game};')(Group,Vector,Geometry);
const data=JSON.parse(fs.readFileSync('docs/reference/qqfeiche3d/tracks/city.json','utf8'));
const requests=JSON.parse(fs.readFileSync(0,'utf8'));
const output=requests.map(request=>{
  const track=Object.assign(new api.Track(),data.track.arrays,{N:data.track.samples,length:data.track.length,
    ds:data.track.sampleDistance,halfW:data.track.halfWidth,boostPads:data.boostPads,_tmp:{}});
  const entries=request.entries.map((e,index)=>{
    const car=new api.Yo(track,null,'reference');
    car.reset(e.distance||0,e.lateral||0);
    Object.assign(car,e.car||{}, {isPlayer:!e.isAI,items:[...(e.items||[])],rank:e.rank||index+1,
      progress:e.progress||0,finished:false,slot:index+1,itemTimer:e.itemTimer??0});
    return car;
  });
  const game=new api.Game();
  const noop=()=>{};
  game.sfx=game.onItemGet=game.onMissileLock=noop;
  game.hud={message:noop,flash:noop}; game.fx={burst:noop,explode:noop,trail:noop};
  game.racerAhead=car=>entries.find(e=>e.rank===car.rank-1)||null;
  let seed=request.seed||20261;
  const rnd=()=>{seed=seed*16807%2147483647;return (seed-1)/2147483646;};
  const items=new api.Items(new Group(),track,game,rnd);
  const sorted=()=>[...entries].sort((a,b)=>a.rank-b.rank);
  return request.actions.map(action=>{
    const car=entries[(action.slot||1)-1];
    if(action.type==='set') Object.assign(car,action.value);
    if(action.type==='give') items.giveRandom(car,car.rank,entries.length);
    if(action.type==='use') items.use(car);
    if(action.type==='swap') items.swap(car);
    if(action.type==='hit') game.hitRacer(car,action.kind);
    if(action.type==='update') items.update(action.dt||1/120,entries,sorted());
    if(action.type==='think') items.aiThink(car,action.dt||1/120,entries);
    return {
      cars:entries.map(e=>Object.fromEntries(['items','s','spin','shield','magnet','nitroTime','airborne','vy','drifting','itemTimer'].map(k=>[k,k==='items'?[...e.items]:e[k]]))),
      boxes:items.boxes.map(b=>Math.max(0,b.respawn)),
      bananas:items.bananas.map(b=>({x:b.mesh.position.x,y:b.mesh.position.y,z:b.mesh.position.z,age:b.age,owner:b.owner.slot})),
      missiles:items.missiles.map(m=>({x:m.mesh.position.x,y:m.mesh.position.y,z:m.mesh.position.z,life:m.life,
        v:m.v,dx:m.dir.x,dy:m.dir.y,dz:m.dir.z,owner:m.owner.slot,target:m.target?.slot||0}))
    };
  });
});
process.stdout.write(JSON.stringify(output));
