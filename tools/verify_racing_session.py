"""Verify authoritative races on the captured city track with ordinary inputs."""
import argparse
import json
from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", default="/tmp/racing-step5-logic.json")
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = " + json.dumps(str(ROOT / "unity/Assets/RacingClone/Lua/Modules/?.lua")) + " .. ';' .. package.path")
lua.execute('RaceConfig=require("RaceConfig"); RaceTrackMath=require("TrackMath"); Session=require("RaceSession")')
city = json.loads((ROOT / "docs/reference/qqfeiche3d/tracks/city.json").read_text())

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

lua.globals().data = table({**city["track"], "boostPads": city["boostPads"]})
result = lua.execute("""
local track=RaceTrackMath.new(data)
local checks={}
local function check(name,value) assert(value,name); checks[#checks+1]=name end
local function control(s,id,action,value)
    return s:control(id,{seq=(s.controlAcks[id] or 0)+1,epoch=s.epoch,action=action,value=value})
end
local protocol=require("RaceProtocol")
local vehicle=require("VehicleSimulation")
local starter=vehicle.new(track,-14,-5.5)
local clock={phase="countdown",time=0,countdown=0.2,startTried=false}
local x,z=starter.x,starter.z
protocol.step(starter,{up=true,upPressed=true},clock)
check("countdown locks vehicle",starter.x==x and starter.z==z and starter.s==0)
clock.phase="race"
protocol.step(starter,{up=true},clock)
check("last 0.28 second throttle primes start boost",starter.startBoost>0)
starter=vehicle.new(track,-14,-5.5)
clock={phase="countdown",time=0,countdown=2,startTried=false}
protocol.step(starter,{up=true,upPressed=true},clock)
clock.phase="race"
protocol.step(starter,{up=true},clock)
check("early countdown throttle gets no start boost",starter.startBoost==0)
starter=vehicle.new(track,-14,-5.5)
clock={phase="race",time=0.2,startTried=false}
protocol.step(starter,{up=true,upPressed=true},clock)
check("first throttle within GO window boosts",starter.startBoost>0)
local s=Session.new(track)
s:roster({{id="p1",name="玩家一"}})
check("one human + five AI",not s.entries[1].isAI and s.entries[2].isAI and #s.entries==6)
s:roster({{id="p1",name="玩家一"},{id="p2",name="玩家二"}})
check("two humans + four AI",not s.entries[2].isAI and s.entries[3].isAI)
check("host authority",not control(s,"p2","laps",5) and s.settings.laps==2)
check("allowed lap choices",not control(s,"p1","laps",4) and control(s,"p1","laps",1))
check("skin selection",control(s,"p2","skin",7) and s.entries[2].skin==7)
control(s,"p1","start")
local previous=s.epoch
local request={seq=(s.controlAcks.p1 or 0)+1,epoch=s.epoch,action="pause"}
check("pause countdown",s:control("p1",request) and s.phase=="pause")
check("control idempotence",not s:control("p1",request) and s.phase=="pause")
local countdown=s.countdown
for _=1,360 do s:update() end
check("pause freezes countdown",s.countdown==countdown and s.time==0)
control(s,"p1","resume")
s:input("p1",{epoch=previous,commands={{seq=1,input={up=true}}}})
check("stale inputs rejected",next(s.entries[1].queue)==nil)
for _=1,361 do s:update() end
check("three second countdown",s.phase=="race" and s.time<0.03)
local e=s.entries[1]
e.car.d=1; s:progress(e)
check("initial crossing is not a lap",e.lapsDone==0 and #e.lapTimes==0)
e.car.d=track.length*0.5; s:progress(e)
e.car.d=track.length-1; s:progress(e)
e.car.d=1; s:progress(e)
check("halfway then crossing counts",e.lapsDone==1 and e.finished)
-- Fresh race for reverse/reset rules.
control(s,"p1","pause"); control(s,"p1","restart")
for _=1,361 do s:update() end
e=s.entries[1]
e.car.d=1; s:progress(e)
e.car.d=track.length-1; s:progress(e)
e.car.d=1; s:progress(e)
check("reverse crossing cannot farm laps",e.lapsDone==0 and not e.finished and #e.lapTimes==0)
e.car.gauge,e.car.nitroCount=0.65,2
local progress=e.progress
e.car:resetOnTrack(); s:progress(e)
check("reset preserves progress and inventory",math.abs(e.progress-progress)<0.01 and e.car.nitroCount==2 and e.car.gauge==0.65)
local before=s.time
control(s,"p1","pause")
for _=1,600 do s:update() end
check("pause freezes race time",s.time==before)
control(s,"p1","resume"); s:update()
check("resume advances one fixed step",math.abs(s.time-before-1/120)<1e-10)
control(s,"p1","pause"); control(s,"p1","quit")
check("quit returns lobby",s.phase=="menu" and s.time==0)
s:roster({{id="p1",name="玩家一"}})
check("departing driver becomes AI",s.entries[2].isAI)
local contact=Session.new(track)
contact:roster({{id="p1",name="一"},{id="p2",name="二"}})
local a,b=contact.entries[1],contact.entries[2]
a.car.x,a.car.z,a.car.y,a.car.m,a.car.s=0,0,0,0,20
b.car.x,b.car.z,b.car.y,b.car.m,b.car.s=0,2,0,0,0
local collision=require("RaceCollision")
collision.resolve({a,b},track)
check("contact separates cars and transfers speed",math.abs(b.car.z-a.car.z-3.1)<1e-10 and a.car.s==10 and b.car.s==10)
b.car.y=3
local z=a.car.z
collision.resolve({a,b},track)
check("different road heights do not collide",a.car.z==z)
local newcomer=Session.new(track)
local ai=newcomer.entries[1]
ai.progress,ai.lapsDone,ai.car.d=track.length*1.8,1,track.length*0.8
newcomer:roster({{id="late",name="晚加入"}})
check("late join preserves AI race progress",newcomer.entries[1].lapsDone==1 and not newcomer.entries[1].owed and newcomer.entries[1].half)
-- Complete races by steering the real Vehicle simulation; no teleport/finish override.
local races={}
for _,scenario in ipairs({{diff=0,laps=1,humans=2},{diff=1,laps=1,humans=2},{diff=2,laps=1,humans=2},
    {diff=0,laps=2,humans=2},{diff=0,laps=3,humans=2},{diff=0,laps=5,humans=2},{diff=0,laps=1,humans=1}}) do
    local diff,laps=scenario.diff,scenario.laps
    local r=Session.new(track)
    local players={{id="p1",name="玩家一"}}
    if scenario.humans==2 then players[2]={id="p2",name="玩家二"} end
    r:roster(players)
    control(r,"p1","diff",diff); control(r,"p1","laps",laps); control(r,"p1","start")
    local ticks=0
    while r.phase~="result" and ticks<120*100*laps do
        for _,driver in ipairs(r.entries) do
            if not driver.isAI and not driver.finished then
                local car=driver.car
                local p=track:sample(car.d+18)
                local direction=math.atan(p.x-car.x,p.z-car.z)
                local angle=RaceTrackMath.angle(direction-car.h)
                r:input(driver.id,{epoch=r.epoch,commands={{seq=driver.ack+1,input={
                    up=math.abs(car.s)<38,left=angle>0.04,right=angle< -0.04}}}})
            end
        end
        r:update(); ticks=ticks+1
    end
    check("difficulty "..diff.." completes naturally",r.phase=="result")
    local finished=0
    local order={}
    for _,driver in ipairs(r.entries) do
        if driver.finished then finished=finished+1 end
        order[driver.rank]={name=driver.name,isAI=driver.isAI,finished=driver.finished,time=driver.finishTime}
    end
    if diff==0 and laps==1 then check("humans complete easy race",r.entries[1].finished and (scenario.humans==1 or r.entries[2].finished))
    else check("finish deadline bounds difficulty "..diff,r.time-r.firstFinish<=10+1/120) end
    for _,driver in ipairs(r.entries) do
        if driver.finished then check("finisher completes specified "..laps.." laps",driver.lapsDone==laps and #driver.lapTimes==laps) end
    end
    races[#races+1]={difficulty=diff,laps=laps,humans=scenario.humans,time=r.time,ticks=ticks,finishers=finished,order=order}
    local frozen=r.time
    for _=1,120 do r:update() end
    check("result time remains fixed "..diff,r.time==frozen)
    control(r,"p1","restart")
    check("restart resets clock and progress "..diff,r.phase=="countdown" and r.time==0 and not r.entries[1].finished and r.entries[1].lapsDone== -1)
end
return {checks=checks,races=races}
""")

def plain(value):
    if hasattr(value, "items"):
        entries = list(value.items())
        if entries and all(isinstance(k, int) for k, _ in entries):
            return [plain(value[i]) for i in range(1, len(entries)+1)]
        return {k: plain(v) for k, v in entries}
    return value

report = {"passed": True, **plain(result)}
Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps(report, ensure_ascii=False, indent=2))
