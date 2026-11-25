-- Verification scenes only: ordinary inputs and control RPCs, no state overrides.
local stage,lastRequest,pausedAt=0,-100,0
local track
function Start()
    if not DouyinApplication.isServer then track=RaceTrackMath.new(RaceTrackData) end
end
local function request(action,value)
    if UnityEngine.Time.unscaledTime-lastRequest<0.5 then return false end
    RaceRuntime.control(action,value)
    lastRequest=UnityEngine.Time.unscaledTime
    return true
end
function Frame()
    local car=RaceRuntime.localCar
    local match=RaceRuntime.match
    if not car or not match or match.phase~="race" then return {} end
    local p=track:sample(car.d+18)
    local direction=math.atan(p.x-car.x,p.z-car.z)
    local angle=RaceTrackMath.angle(direction-car.h)
    return {up=math.abs(car.s)<38,left=angle>0.04,right=angle< -0.04}
end
function Clear() end
function ConsumeEdges() end
function Update()
    if DouyinApplication.isServer or not RaceRuntime.match or not RaceRuntime.control then return end
    local match=RaceRuntime.match
    if match.host~=RaceRuntime.localId then return end
    if stage==0 and match.phase=="menu" then
        if match.settings.laps~=1 then request("laps",1)
        elseif match.settings.diff~=0 then request("diff",0)
        else
            local humans=0
            for _,entry in ipairs(RaceRuntime.cars) do if not entry.isAI then humans=humans+1 end end
            if humans==2 and request("start") then stage=1 end
        end
    elseif stage==1 and match.phase=="race" and match.time>=5 then
        if request("pause") then stage=2 end
    elseif stage==2 and match.phase=="pause" then
        pausedAt=UnityEngine.Time.unscaledTime; stage=3
        print("[RacingClone][Fixture] PAUSE_OBSERVED time="..match.time)
    elseif stage==3 and UnityEngine.Time.unscaledTime-pausedAt>=3 then
        if request("resume") then stage=4 end
    elseif stage==4 and match.phase=="result" then
        print("[RacingClone][Fixture] NATURAL_RESULT time="..match.time)
        pausedAt=UnityEngine.Time.unscaledTime; stage=5
    elseif stage==5 and UnityEngine.Time.unscaledTime-pausedAt>=4 then
        if request("restart") then stage=6 end
    elseif stage==6 and match.phase=="countdown" then
        if request("pause") then stage=7 end
    elseif stage==7 and match.phase=="pause" then
        if request("quit") then stage=8 end
    elseif stage==8 and match.phase=="menu" then
        stage=9; print("[RacingClone][Fixture] FLOW_COMPLETE lobby=true")
    end
end
