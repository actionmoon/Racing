"""Verify map authority, height isolation and complete races using ordinary inputs."""
import argparse
import json
from pathlib import Path
from lupa import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument("--output",default="/tmp/racing-step7-maps.json")
args=parser.parse_args()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path="+json.dumps(str(ROOT/"unity/Assets/RacingClone/Lua/Modules/?.lua"))+"..';'..package.path")
result=lua.execute("""
RaceConfig=require "RaceConfig"
local Maps=require "RaceMaps"
local Track=require "TrackMath"
local Session=require "RaceSession"
local Collision=require "RaceCollision"
local checks,races={},{}
local function check(name,value) assert(value,name); checks[#checks+1]=name end
local function control(s,id,action,value)
    return s:control(id,{seq=(s.controlAcks[id] or 0)+1,epoch=s.epoch,action=action,value=value})
end
local s=Session.new(Track.new(Maps.data.city))
s:roster({{id="p1",name="一"},{id="p2",name="二"}})
check("only host changes map",not control(s,"p2","map",1) and s.track.id=="city")
for _,bad in ipairs({-1,4,1.5,"snow"}) do check("reject invalid map "..tostring(bad),not control(s,"p1","map",bad)) end
for index,id in ipairs(Maps.ids) do
    local before=s.epoch
    check("select "..id,control(s,"p1","map",index-1) and s.track.id==id and s.settings.map==id)
    check("epoch and inventory reset "..id,s.epoch==before+1 and s.entries[1].ack==0 and #s.entries[1].items==0)
    check("items follow new track "..id,s.items.track==s.track)
    local track=s.track
    local error=0
    for i=1,track.N do
        local p=track:sample((i-1)*track.ds+track.ds*.3)
        local q=track:project(p.x,p.y,p.z,i)
        error=math.max(error,math.abs(q.y-p.y),math.abs(q.lat))
    end
    check("all centerline projections "..id,error<.05)
    control(s,"p1","laps",1);control(s,"p1","diff",0);control(s,"p1","mode",0)
    control(s,"p1","start")
    check("no race map change "..id,not control(s,"p1","map",0))
    local ticks,air,land=0,0,0
    while s.phase~="result" and ticks<120*150 do
        for _,entry in ipairs(s.entries) do
            if not entry.isAI and not entry.finished then
                local car=entry.car
                local p=track:sample(car.d+18)
                local angle=Track.angle(math.atan(p.x-car.x,p.z-car.z)-car.h)
                local target=id=="egypt" and math.abs(track:curvAhead(car.d,80))<.008 and 55 or 41
                local input={up=math.abs(car.s)<target,left=angle>.04,right=angle<-.04,
                    wPressed=car.smallWindow>0 and car.windowKind=="land"}
                s:input(entry.id,{epoch=s.epoch,commands={{seq=entry.ack+1,input=input}}})
                if car.airborne then air=air+1 end
            end
        end
        s:update();ticks=ticks+1
    end
    local finishers=0
    for _,e in ipairs(s.entries) do if e.finished then finishers=finishers+1 end;land=land+e.stats.land end
    print(id,s.time,finishers,s.entries[1].progress,s.entries[2].progress,air,land)
    check("natural race completes "..id,s.phase=="result" and finishers>=1)
    check("both drivers complete "..id,s.entries[1].finished and s.entries[2].finished)
    if id=="egypt" then check("egypt naturally airborne",air>0) end
    races[#races+1]={id=id,ticks=ticks,time=s.time,finishers=finishers,airborneTicks=air,landingBoosts=land,projectionError=error}
    control(s,"p1","quit")
end
local egypt=Track.new(Maps.data.egypt)
local car=require("VehicleSimulation").new(egypt,150,0)
car.nitroCount=2
local launched,landed,boosted,maxAir=false,false,false,0
for _=1,120*12 do
    local p=egypt:sample(car.d+18)
    local angle=Track.angle(math.atan(p.x-car.x,p.z-car.z)-car.h)
    car:update(1/120,{up=true,left=angle>.04,right=angle<-.04,
        nitroPressed=car.nitroCount>0 and car.s>45 and car.d<340,
        wPressed=car.smallWindow>0 and car.windowKind=="land"})
    if car.airborne then launched=true;maxAir=math.max(maxAir,car.airTime) end
    for _,event in ipairs(car.events) do
        if event.type=="land" then landed=true end
        if event.type=="landBoost" then boosted=true end
    end
    car.events={}
end
check("egypt nitro ramp launches and lands",launched and landed and maxAir>.3)
check("egypt landing window triggers boost",boosted)
local track=Track.new(Maps.data.snow)
local crossings={}
for i=1,track.N,3 do
    for j=i+90,track.N,3 do
        if math.min(j-i,track.N-j+i)>90 then
            local dx,dz=track.px[i]-track.px[j],track.pz[i]-track.pz[j]
            local dy=math.abs(track.py[i]-track.py[j])
            if dx*dx+dz*dz<4 and dy>5 then
                local a=track:project(track.px[i],track.py[i],track.pz[i],nil)
                local b=track:project(track.px[j],track.py[j],track.pz[j],nil)
                check("snow global projection separates layers",math.abs(a.y-b.y)>5)
                local localA=track:project(track.px[i],track.py[j],track.pz[i],i)
                check("snow continuous hint stays on layer",math.abs(localA.y-track.py[i])<.1)
                local s=Session.new(track)
                local e,f=s.entries[1],s.entries[2]
                e.car.x,e.car.z,e.car.y=track.px[i],track.pz[i],track.py[i]
                f.car.x,f.car.z,f.car.y=e.car.x,e.car.z,track.py[j]
                local x,z=e.car.x,e.car.z
                Collision.resolve({e,f},track)
                check("snow cars on separate layers do not collide",e.car.x==x and e.car.z==z)
                crossings[#crossings+1]={lower=i,upper=j,height=dy}
            end
        end
    end
end
check("snow crossing examined",#crossings>0)
return {checks=checks,races=races,crossings=crossings,egyptJump={airTime=maxAir,landingBoost=boosted}}
""")
def plain(value):
    if hasattr(value,"items"):
        pairs=list(value.items())
        if pairs and all(isinstance(k,int) for k,_ in pairs):
            return [plain(value[i]) for i in range(1,len(pairs)+1)]
        return {k:plain(v) for k,v in pairs}
    return value
report={"passed":True,**plain(result)}
Path(args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
