---@var realInput:DouyinScript
---@var samples:number[]
---@var manual:boolean
---@end
-- Isolated scene: races use ordinary inputs and control RPCs.
local index,stage,lastRequest,changedAt=1,0,-100,0
local phase,logTime,qualityStage=nil,0,-1
local rmsError,nonHostAttempt=false,false
local lastManualInput
function Start()
    if manual then
        stage=9
        UnityEngine.Screen.SetResolution(720,1280,false)
    end
end
local function request(action,value)
    local now=UnityEngine.Time.unscaledTime
    if now-lastRequest<.6 then return false end
    RaceRuntime.control(action,value);lastRequest=now
    return true
end
function Frame()
    if stage==9 then
        local input=realInput.script.Frame()
        local state=string.format("up=%s left=%s right=%s shift=%s",tostring(input.up),tostring(input.left),tostring(input.right),tostring(input.shift))
        if state~=lastManualInput then
            lastManualInput=state
            print("[RacingClone][PresentationFixture] MANUAL_INPUT "..state)
        end
        return input
    end
    local car,match,track=RaceRuntime.localCar,RaceRuntime.match,RaceRuntime.track
    local input=realInput.script.Frame()
    if not car or not match or match.phase~="race" then return input end
    local p=track:sample(car.d+18)
    local angle=RaceTrackMath.angle(math.atan(p.x-car.x,p.z-car.z)-car.h)
    local target=track.id=="egypt" and math.abs(track:curvAhead(car.d,80))<.008 and 55 or 41
    input.up=math.abs(car.s)<target;input.left=angle>.04;input.right=angle<-.04
    input.wPressed=car.smallWindow>0 and car.windowKind=="land"
    return input
end
function Clear() realInput.script.Clear() end
function ConsumeEdges() realInput.script.ConsumeEdges() end
function Update()
    if DouyinApplication.isServer or not RaceRuntime.match or not RaceRuntime.setting then return end
    local match=RaceRuntime.match
    if phase~=match.phase then
        phase=match.phase;changedAt=UnityEngine.Time.unscaledTime
        print("[RacingClone][PresentationFixture] PHASE map="..match.settings.map.." phase="..phase)
        if phase=="race" then qualityStage=-1 end
        if phase=="result" then print("[RacingClone][PresentationFixture] RESULT "..RaceJson.encode(RaceRuntime.snapshot)) end
    end
    if phase=="race" and not manual then
        local q=math.min(2,math.floor(match.time/5))
        if q~=qualityStage then
            qualityStage=q
            RaceRuntime.setting("quality",q)
            RaceRuntime.setting("camera",q)
            print("[RacingClone][PresentationFixture] QUALITY requested="..q.." actual="..UnityEngine.QualitySettings.GetQualityLevel())
        end
    end
    logTime=logTime+UnityEngine.Time.unscaledDeltaTime
    if logTime>2 then
        logTime=0
        local ok,value=pcall(function()
            UnityEngine.AudioListener.GetOutputData(samples,0)
            local sum,peak=0,0
            for i=0,samples.Length-1 do sum=sum+samples[i]*samples[i];peak=math.max(peak,math.abs(samples[i])) end
            return string.format("rms=%.7f peak=%.7f",math.sqrt(sum/samples.Length),peak)
        end)
        if ok then print("[RacingClone][PresentationFixture] OUTPUT "..value)
        elseif not rmsError then rmsError=true;print("[RacingClone][PresentationFixture] OUTPUT_ERROR "..tostring(value)) end
        if manual and RaceRuntime.localCar then
            local car=RaceRuntime.localCar
            print(string.format("[RacingClone][PresentationFixture] MANUAL_CAR speed=%.3f steer=%.3f throttle=%.3f drifting=%s",car.s,car.steer,car.throttle,tostring(car.drifting)))
            local camera=CS.DouyinCameraService.GetCamera()
            local sun=UnityEngine.RenderSettings.sun
            local shadows=UnityEngine.Shader.GetGlobalVector("_MainLightShadowParams")
            print(string.format("[RacingClone][PresentationFixture] RENDER camera=%s hdr=%s sun=%s quality=%s shadows=%s",
                camera and camera.name or "",camera and tostring(camera.allowHDR) or "",
                sun and sun.name or "",UnityEngine.QualitySettings.renderPipeline.name,tostring(shadows)))
        end
    end
    if manual then return end
    if match.host~=RaceRuntime.localId then
        if match.host~="" and RaceRuntime.localEntry and not nonHostAttempt and phase=="menu" and request("map",3) then nonHostAttempt=true end
        return
    end
    if stage==0 and phase=="menu" then
        local humans=0
        for _,entry in ipairs(RaceRuntime.cars) do if not entry.isAI then humans=humans+1 end end
        if humans<2 or UnityEngine.Time.unscaledTime-changedAt<8 then return end
        if match.settings.map~=RaceMaps.ids[index] then request("map",index-1)
        elseif match.settings.laps~=1 then request("laps",1)
        elseif match.settings.diff~=0 then request("diff",0)
        elseif match.settings.mode~="race" then request("mode",0)
        elseif request("start") then stage=1 end
    elseif stage==1 and phase=="result" and UnityEngine.Time.unscaledTime-changedAt>8 then
        if request("quit") then stage=2 end
    elseif stage==2 and phase=="menu" then
        index=index+1
        if index<=4 then
            UnityEngine.Screen.SetResolution(index==2 and 720 or 1280,index==2 and 1280 or 720,false)
            stage=0
        else
            stage=9
            print("[RacingClone][PresentationFixture] FLOW_COMPLETE maps=4")
        end
    end
end
