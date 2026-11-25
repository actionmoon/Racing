"""Compare authoritative items with the captured JavaScript and test room boundaries."""
import argparse
import json
import subprocess
from pathlib import Path
from lupa import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument("--output",default="/tmp/racing-step6-items.json")
args=parser.parse_args()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path="+json.dumps(str(ROOT/"unity/Assets/RacingClone/Lua/Modules/?.lua"))+"..';'..package.path")
def table(value):
    if isinstance(value,dict): return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([table(v) for v in value])
    return value
data=json.loads((ROOT/"docs/reference/qqfeiche3d/tracks/city.json").read_text())
lua.globals().data=table({**data["track"],"boostPads":data["boostPads"]})
lua.execute('RaceConfig=require("RaceConfig"); Track=require("TrackMath"); Vehicle=require("VehicleSimulation"); Items=require("RaceItems"); Session=require("RaceSession"); track=Track.new(data)')
run=lua.eval("""function(request)
    local entries={}
    for i,e in ipairs(request.entries) do
        local car=Vehicle.new(track,e.distance or 0,e.lateral or 0)
        for k,v in pairs(e.car or {}) do car[k]=v end
        entries[i]={slot=i,car=car,isAI=e.isAI==true,items=e.items or {},rank=e.rank or i,
            progress=e.progress or 0,itemTimer=e.itemTimer or 0,finished=false}
    end
    local items=Items.new(track); items:reset(request.seed or 20261)
    local out={}
    for _,a in ipairs(request.actions) do
        local e=entries[a.slot or 1]
        if a.type=="set" then
            for k,v in pairs(a.value) do
                if k=="items" or k=="progress" or k=="rank" or k=="itemTimer" or k=="finished" then e[k]=v else e.car[k]=v end
            end
        elseif a.type=="give" then items:give(e,#entries)
        elseif a.type=="use" then items:use(e,entries)
        elseif a.type=="swap" then items:swap(e)
        elseif a.type=="hit" then items:hit(e,a.kind)
        elseif a.type=="update" then items:update(a.dt or 1/120,entries)
        elseif a.type=="think" then items:think(e,a.dt or 1/120,entries) end
        local frame={cars={},boxes={},bananas={},missiles={}}
        for _,entry in ipairs(entries) do
            local car={}
            for _,k in ipairs({"s","spin","shield","magnet","nitroTime","airborne","vy","drifting"}) do car[k]=entry.car[k] end
            car.items={};for i,item in ipairs(entry.items) do car.items[i]=item end
            car.itemTimer=entry.itemTimer;frame.cars[#frame.cars+1]=car
        end
        for i,b in ipairs(items.boxes) do frame.boxes[i]=b.respawn end
        for _,b in ipairs(items.bananas) do frame.bananas[#frame.bananas+1]={x=b.x,y=b.y,z=b.z,age=b.age,owner=b.owner} end
        for _,m in ipairs(items.missiles) do
            local copy={}
            for _,k in ipairs({"x","y","z","life","v","dx","dy","dz","owner","target"}) do copy[k]=m[k] end
            frame.missiles[#frame.missiles+1]=copy
        end
        out[#out+1]=frame
    end
    return out
end""")
entries=[{"rank":i+1,"distance":100-i*20,"progress":100-i*20} for i in range(6)]
cases=[]
def case(name,entry_overrides,actions):
    e=json.loads(json.dumps(entries))
    for index,overrides in entry_overrides.items(): e[index].update(overrides)
    cases.append({"name":name,"entries":e,"actions":actions})
for rank in (1,3,5,6):
    case(f"rank {rank} weighted 100 draws",{0:{"rank":rank}},[
        a for _ in range(100) for a in ({"type":"set","value":{"items":[]}},{"type":"give"})])
for item in ("nitro","shield","magnet","banana","missile"):
    case(item+" use and expiry",{0:{"items":[item]}},[{"type":"use"}]+[{"type":"update"}]*730)
case("AI nitro",{0:{"items":["nitro"],"isAI":True}},[{"type":"use"}])
case("two slots FIFO and swap",{0:{"items":["shield","magnet"]}},[{"type":"give"},{"type":"swap"},{"type":"use"},{"type":"use"},{"type":"use"}])
case("missile shield absorption",{0:{"items":["shield"],"car":{"s":40,"drifting":True}}},[
    {"type":"use"},{"type":"hit","kind":"missile"},{"type":"hit","kind":"banana"}])
case("missile homing moving target",{1:{"items":["missile"]}},[{"type":"use","slot":2}]+[
    a for i in range(90) for a in ({"type":"set","value":{"x":50+i*.4,"y":i*.01,"z":30+i*.2,"s":70}},{"type":"update"})])
case("AI swaps missile without target",{0:{"items":["missile","shield"],"isAI":True}},[{"type":"think"},{"type":"set","value":{"itemTimer":0}},{"type":"think"}])
case("AI magnet range",{1:{"items":["magnet"],"isAI":True,"progress":-200}},[
    {"type":"think","slot":2},{"type":"set","slot":2,"value":{"itemTimer":0,"progress":50}},{"type":"think","slot":2}])
point=lua.globals().track.sample(lua.globals().track,lua.globals().track.length*.1)
pickup={"x":point.x,"y":point.y,"z":point.z,"s":0}
case("same box contested and full slots",{0:{"items":["shield","nitro"],"car":pickup},1:{"car":pickup}},[
    {"type":"update"},{"type":"update","dt":2.5},{"type":"update"},{"type":"set","value":{"x":-10000}},{"type":"update","dt":2.5},{"type":"update"}])
case("banana self immunity and one hit",{0:{"items":["banana"],"car":{"x":0,"y":0,"z":0,"h":0,"s":40}}},[
    {"type":"use"},{"type":"set","value":{"z":-3.2}},{"type":"update","dt":1.19},{"type":"update","dt":.02},{"type":"update"}])
original=subprocess.run(["node","tools/racing_items_reference.cjs"],input=json.dumps(cases),text=True,capture_output=True,cwd=ROOT)
if original.returncode:
    Path("/tmp/racing-step6-reference-error.log").write_text(original.stdout+original.stderr)
    raise RuntimeError(original.stderr)
reference=json.loads(original.stdout)
maximum=0
comparisons=0
def compare(actual,expected,path):
    global maximum,comparisons
    if isinstance(expected,list):
        assert len(actual)==len(expected),(path,len(actual),len(expected))
        for i,v in enumerate(expected): compare(actual[i+1],v,path+f"[{i}]")
    elif isinstance(expected,dict):
        for k,v in expected.items(): compare(actual[k],v,path+"."+k)
    elif isinstance(expected,(float,int)) and not isinstance(expected,bool):
        error=abs(actual-expected);maximum=max(maximum,error);comparisons+=1
        assert error<1e-8,(path,actual,expected,error)
    else: assert actual==expected,(path,actual,expected)
for request,expected in zip(cases,reference): compare(run(table(request)),expected,request["name"])
checks=lua.execute("""
local checks={}
local function check(name,value) assert(value,name); checks[#checks+1]=name end
local function control(s,id,action,value)
    return s:control(id,{seq=(s.controlAcks[id] or 0)+1,epoch=s.epoch,action=action,value=value})
end
local s=Session.new(track);s:roster({{id="p1",name="一"},{id="p2",name="二"}})
check("20 boxes and original offsets",#s.items.boxes==20 and math.abs(s.items.boxes[3].x-track:sample(track.length*.1).x)<1e-10)
check("only host selects mode",not control(s,"p2","mode",1) and control(s,"p1","mode",1))
check("mode values validated",not control(s,"p1","mode",2) and s.settings.mode=="item")
control(s,"p1","start");for _=1,361 do s:update() end
local e=s.entries[1]; e.items={"shield","magnet"}
local command={seq=1,input={nitroPressed=true}}
s:input("p1",{epoch=s.epoch,commands={command,command}});s:update()
check("repeated sequence uses one slot",#e.items==1 and e.items[1]=="magnet" and e.car.shield>6.9)
s:input("p1",{epoch=s.epoch,commands={command}});s:update()
check("acknowledged command is idempotent",#e.items==1)
e.items={"shield","nitro"}
s:input("p1",{epoch=s.epoch,commands={{seq=2,input={swapPressed=true}}}});s:update()
check("network swap edge reverses two slots",e.items[1]=="nitro" and e.items[2]=="shield")
local protocol=require("RaceProtocol")
local predicted=Vehicle.new(track,0,0);predicted.nitroCount=2
protocol.step(predicted,{nitroPressed=true},{phase="race",time=1,mode="item",startTried=true})
check("item prediction cannot consume nitro inventory",predicted.nitroCount==2 and predicted.nitroTime==0)
local race=Vehicle.new(track,0,0);race.nitroCount=2
protocol.step(race,{nitroPressed=true},{phase="race",time=1,mode="race",startTried=true})
check("race nitro inventory unchanged behavior",race.nitroCount==1 and race.nitroTime>0)
local old=s.epoch;control(s,"p1","pause")
local time,shield=s.time,e.car.shield
s.items.boxes[1].respawn=1.5
for _=1,120 do s:update() end
check("pause freezes car effects and box refresh",s.time==time and e.car.shield==shield and s.items.boxes[1].respawn==1.5)
control(s,"p1","resume")
s:input("p1",{epoch=old,commands={{seq=1,input={nitroPressed=true}}}})
check("stale epoch cannot consume inventory",next(e.queue)==nil)
local before=#e.items
s:roster({{id="p2",name="二"}})
check("disconnect AI inherits slot inventory",s.entries[1].isAI and #s.entries[1].items==before)
check("mode locked during race",not control(s,"p2","mode",0))
control(s,"p2","pause");control(s,"p2","restart")
check("restart clears slots and projectiles",#s.entries[1].items==0 and #s.items.missiles==0 and #s.items.bananas==0 and s.entries[1].car.shield==0)
check("restart resets all box timers",s.items.boxes[1].respawn==0)
check("snapshot version and authoritative slots",s:snapshot().version==3 and s:snapshot().cars[1].items~=nil)
local ai=s.entries[1].ai
ai.car.shield,ai.car.magnet,ai.car.spin,ai.car.slowTime=7,3,1.3,2
ai:update(1/120,true,10,1)
check("AI decays all effect timers",ai.car.shield<7 and ai.car.magnet<3 and ai.car.spin<1.3 and ai.car.slowTime<2)
local allUses={}
for _,humans in ipairs({1,2}) do
    local race=Session.new(track)
    local players={{id="p1",name="一"}}
    if humans==2 then players[2]={id="p2",name="二"} end
    race:roster(players);control(race,"p1","mode",1);control(race,"p1","diff",0)
    control(race,"p1","laps",1);control(race,"p1","start")
    local ticks,seen,gets,uses=0,0,0,0
    while race.phase~="result" and ticks<120*100 do
        for _,driver in ipairs(race.entries) do
            if not driver.isAI and not driver.finished then
                local car=driver.car
                local p=track:sample(car.d+18)
                local angle=Track.angle(math.atan(p.x-car.x,p.z-car.z)-car.h)
                race:input(driver.id,{epoch=race.epoch,commands={{seq=driver.ack+1,input={
                    up=math.abs(car.s)<38,left=angle>0.04,right=angle< -0.04,
                    nitroPressed=#driver.items>0 and ticks%120==0}}}})
            end
        end
        race:update();ticks=ticks+1
        for _,event in ipairs(race.items.events) do
            if event.id>seen then
                if event.type=="get" then gets=gets+1 end
                if event.type=="use" then uses=uses+1;allUses[event.item]=true end
                seen=event.id
            end
        end
    end
    check("natural item race "..humans.." humans finishes with pickups and AI uses",race.phase=="result" and gets>=6 and uses>=4)
    check("item race keeps drift gauge disabled "..humans,race.entries[1].car.gauge==0)
end
check("natural races exercise all five items",allUses.nitro and allUses.shield and allUses.magnet and allUses.banana and allUses.missile)
return checks
""")
for path in (ROOT/"unity/Assets/RacingClone/Lua").rglob("*.lua"):
    lua.eval("function(s) local f,e=load(s); assert(f,e); return true end")(path.read_text())
report={"passed":True,"referenceCases":[c["name"] for c in cases],"comparedNumbers":comparisons,"maxError":maximum,
        "roomChecks":[checks[i] for i in range(1,len(checks)+1)],"luaSyntaxFiles":len(list((ROOT/"unity/Assets/RacingClone/Lua").rglob("*.lua")))}
Path(args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
