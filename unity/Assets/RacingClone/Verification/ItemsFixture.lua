---@var realInput:DouyinScript
---@end
-- Isolated verification scene. Only setup mutates state; item actions use normal inputs.
local session,track,lastFrame,lastRequest,stage,pausedAt=nil,nil,-1,-100,0,0
local activeCase,caseStart,moved=nil,0,false
local cases={"manual_slots","shield_missile","missile_hit","magnet_none","magnet_target","banana_other","banana_self"}
local natural=false
local used={}
local function setup(s,name)
    activeCase,caseStart,moved=name,s.time,false
    s.items:reset(9217)
    for _,box in ipairs(s.items.boxes) do box.respawn=999 end
    for _,e in ipairs(s.entries) do
        e.car=RaceVehicleSimulation.new(s.track,e.slot==1 and 100 or e.slot==2 and 80 or -200-e.slot*20,-5)
        e.lastD,e.lapsDone,e.owed,e.half=e.car.d,0,false,false
        e.progress=e.slot<=2 and e.car.d or -200-e.slot*20
        e.items,e.magnetTarget,e.itemTimer={},0,999
        if e.isAI then
            e.ai.car=e.car; e.ai.dist=e.progress
            e.ai.update=function() end
        end
    end
    local a,b=s.entries[1],s.entries[2]
    if name=="manual_slots" then a.items={"nitro","shield"}
    elseif name=="shield_missile" then a.items={"shield"}; b.items={"missile"}
    elseif name=="missile_hit" then b.items={"missile"}
    elseif name=="magnet_none" then a.items={"magnet"}
    elseif name=="magnet_target" then b.items={"magnet"}
    else a.items={"banana"} end
    s:rank()
    print("[RacingClone][Fixture] CASE "..name)
end
function Awake()
    if not DouyinApplication.isServer or realInput then return end
    local originalNew=RaceSession.new
    RaceSession.new=function(t)
        local s=originalNew(t); session=s
        local originalUpdate=s.update
        s.update=function(room)
            if not natural and room.phase=="race" then
                local index=room.time<90 and 1 or math.min(#cases,2+math.floor((room.time-90)/8))
                local name=cases[index]
                if name~=activeCase then setup(room,name) end
                if not moved and room.time-caseStart>=0.4 and #room.items.bananas>0 then
                    local banana=room.items.bananas[1]
                    local e=room.entries[name=="banana_self" and 1 or 2]
                    e.car.x,e.car.y,e.car.z=banana.x,banana.y,banana.z
                    e.car.s=0; moved=true
                    print("[RacingClone][Fixture] BANANA_CONTACT case="..name.." age="..banana.age)
                end
            end
            originalUpdate(room)
        end
        local originalSnapshot=s.snapshot
        s.snapshot=function(room)
            local p=originalSnapshot(room)
            p.match.verification=natural and "natural" or activeCase or "lobby"
            p.match.verificationTime=room.time-caseStart
            if p.tick%30<6 then print("[RacingClone][Fixture] FRAME "..RaceJson.encode(p)) end
            return p
        end
        local originalControl=s.control
        s.control=function(room,id,r)
            local ok=originalControl(room,id,r)
            if ok and r.action=="quit" and not natural then
                natural=true; activeCase=nil
                room:resetGrid()
            end
            return ok
        end
        return s
    end
end
function Start()
    track=RaceTrackMath.new(RaceTrackData)
end
local function request(action,value)
    if UnityEngine.Time.unscaledTime-lastRequest<0.5 then return false end
    RaceRuntime.control(action,value); lastRequest=UnityEngine.Time.unscaledTime
    return true
end
function Frame()
    local match=RaceRuntime.match
    if not match then return {} end
    local name=match.verification
    if name=="manual_slots" then return realInput.script.Frame() end
    if name=="natural" then
        local car=RaceRuntime.localCar
        if not car or match.phase~="race" then return {} end
        local p=track:sample(car.d+18)
        local angle=RaceTrackMath.angle(math.atan(p.x-car.x,p.z-car.z)-car.h)
        local second=math.floor(match.time)
        local use=false
        if used.natural~=second then used.natural=second; use=true end
        return {up=math.abs(car.s)<38,left=angle>0.04,right=angle< -0.04,nitroPressed=use}
    end
    local slot,t=RaceRuntime.localSlot,match.verificationTime or 0
    local should=(slot==1 and (name=="shield_missile" or name=="magnet_none" or name=="banana_other" or name=="banana_self") and t>=0.15)
        or (slot==2 and (name=="missile_hit" or name=="magnet_target") and t>=0.15)
        or (slot==2 and name=="shield_missile" and t>=1.2)
    if should and not used[name] then used[name]=true; return {nitroPressed=true} end
    return {}
end
function Clear()
    if realInput then realInput.script.Clear() end
end
function ConsumeEdges()
    if realInput then realInput.script.ConsumeEdges() end
end
function Update()
    if DouyinApplication.isServer or not realInput or not RaceRuntime.match or not RaceRuntime.control then return end
    local p=RaceRuntime.snapshot
    if p and p.tick~=lastFrame and p.tick%30<6 then
        lastFrame=p.tick; print("[RacingClone][Fixture] FRAME "..RaceJson.encode(p))
    end
    local match=RaceRuntime.match
    if match.host~=RaceRuntime.localId then return end
    if stage==0 and match.phase=="menu" then
        if match.settings.mode~="item" then request("mode",1)
        elseif match.settings.laps~=1 then request("laps",1)
        elseif match.settings.diff~=0 then request("diff",0)
        else
            local humans=0
            for _,e in ipairs(RaceRuntime.cars) do if not e.isAI then humans=humans+1 end end
            if humans==2 and request("start") then stage=1 end
        end
    elseif stage==1 and match.phase=="race" and match.time>=138 then
        if request("pause") then stage=2 end
    elseif stage==2 and match.phase=="pause" then
        if request("quit") then stage=3 end
    elseif stage==3 and match.phase=="menu" then
        if request("start") then stage=4 end
    elseif stage==4 and match.phase=="race" and match.time>=5 then
        if request("pause") then stage=5 end
    elseif stage==5 and match.phase=="pause" then
        pausedAt=UnityEngine.Time.unscaledTime; stage=6
        print("[RacingClone][Fixture] PAUSE_OBSERVED time="..match.time)
    elseif stage==6 and UnityEngine.Time.unscaledTime-pausedAt>=3 then
        if request("resume") then stage=7 end
    elseif stage==7 and match.phase=="result" then
        pausedAt=UnityEngine.Time.unscaledTime; stage=8
        print("[RacingClone][Fixture] NATURAL_RESULT time="..match.time)
    elseif stage==8 and UnityEngine.Time.unscaledTime-pausedAt>=8 then
        if request("restart") then stage=9 end
    elseif stage==9 and match.phase=="countdown" then
        if request("pause") then stage=10 end
    elseif stage==10 and match.phase=="pause" then
        if request("quit") then stage=11 end
    elseif stage==11 and match.phase=="menu" then
        stage=12; print("[RacingClone][Fixture] FLOW_COMPLETE lobby=true")
    end
end
