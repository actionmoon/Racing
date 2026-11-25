"""Compare the ported AI with the captured Zo at every fixed step."""
import json
import subprocess
from pathlib import Path
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
js = r"""
const fs=require('fs');
const source=fs.readFileSync('docs/reference/qqfeiche3d/readable-script.js','utf8');
const helpers=source.slice(source.indexOf('  var he = '),source.indexOf('  function bn('));
const config=source.slice(source.indexOf('  var qn = {'),source.indexOf('  function kc(',source.indexOf('  var qn = {')));
const begin=source.indexOf('    Zo = class {');
const ai=source.slice(begin,source.indexOf('  var c_',begin));
const trackBegin=source.indexOf('      sample(t, e = this._tmp)');
const track=source.slice(trackBegin,source.indexOf('      build(t, e)',trackBegin));
const api=new Function(helpers+config+'; var Zo; '+ai+'; class Track {'+track+'};return {Zo,Track};')();
const data=JSON.parse(fs.readFileSync('docs/reference/qqfeiche3d/tracks/city.json','utf8'));
const request=JSON.parse(fs.readFileSync(0,'utf8'));
const t=Object.assign(new api.Track(),data.track.arrays,{N:data.track.samples,length:data.track.length,ds:data.track.sampleDistance,halfW:data.track.halfWidth,_tmp:{}});
let seed=request.seed;
function rnd(){seed=seed*16807%2147483647;return (seed-1)/2147483646;}
const car=new api.Zo(t,null,'AI',request.skill,rnd);
car.reset(-14,-5.5);
// Constructor reset consumed RNG; mirror a single reset used by the port.
seed=request.seed; car.personal=(rnd()-.5)*.6; car.nitroCd=6+rnd()*6; car.startDelay=.05+rnd()*.25;
const output=[];
for(let i=0;i<request.steps;i++){
  car.update(1/120,true,i/120,1);
  output.push(Object.fromEntries(['dist','lat','s','x','y','z','h','d','nitroTime','vy','airborne','drifting','yawOff','latV'].map(k=>[k,car[k]])));
}
process.stdout.write(JSON.stringify(output));
"""
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = " + json.dumps(str(root/"unity/Assets/RacingClone/Lua/Modules/?.lua")) + " .. ';' .. package.path")
def table(value):
    if isinstance(value,dict): return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([table(v) for v in value])
    return value
data=json.loads((root/"docs/reference/qqfeiche3d/tracks/city.json").read_text())
track_type=lua.eval('require("TrackMath")')[0]
ai_type=lua.eval('require("RaceAI")')[0]
track=track_type.new(table({**data["track"],"boostPads":data["boostPads"]}))
cases=[]
for skill in (0.65,0.95,1.29):
    request={"skill":skill,"seed":12345,"steps":120*70}
    result=subprocess.run(["node","-e",js],input=json.dumps(request),text=True,capture_output=True,cwd=root,check=True)
    original=json.loads(result.stdout)
    ai=ai_type.new(track,-14,-5.5,skill,12345)
    maximum=0
    for i,frame in enumerate(original):
        ai.update(ai,1/120,True,i/120,1)
        for key,expected in frame.items():
            actual=ai[key] if key in ("dist","yawOff","latV") else ai.car[key]
            if isinstance(expected,bool): assert expected==actual,(skill,i,key)
            else:
                maximum=max(maximum,abs(actual-expected))
                assert abs(actual-expected)<1e-7,(skill,i,key,actual,expected)
    cases.append({"skill":skill,"steps":request["steps"],"maxError":maximum})
report={"passed":True,"cases":cases,"steps":sum(c["steps"] for c in cases)}
Path("/tmp/racing-step5-ai.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
