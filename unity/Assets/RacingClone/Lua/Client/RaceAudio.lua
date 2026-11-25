---@var root:GameObject
---@end
local sources,started,playedAt={},{},{}
local song,epoch,lastCount,lastLap,finished,phase,logTime=nil,-1,nil,0,false,nil,0
local eventSounds={nitro="nitro",smallBoost="small",landBoost="small",double="double",
    gaugeFull="gauge",startBoost="nitro",pad="pad",crash="crash",scrape="scrape"}
function Play(name)
    local now=UnityEngine.Time.unscaledTime
    if sources[name] and now-(playedAt[name] or -100)>(name=="scrape" and .12 or .04) then
        playedAt[name]=now
        sources[name]:PlayOneShot(sources[name].clip)
        if name~="scrape" then print("[RacingClone][Client] AUDIO_EVENT name="..name) end
    end
end
function VehicleEvent(event)
    local name=eventSounds[event.type]
    if event.type=="land" and event.data.air>.25 then name="land" end
    if name then Play(name) end
end
function ItemEvent(event)
    local name=event.type=="get" and "item" or event.type=="swap" and "click"
    if event.type=="use" then
        name=({nitro="nitro",shield="shield",magnet="item",banana="banana",missile="missile"})[event.item]
    elseif event.type=="block" then name="shield"
    elseif event.type=="lock" then name="wrong"
    elseif event.type=="hit" then name=event.item=="missile" and "boom" or "banana" end
    if name then Play(name) end
end
function Start()
    if DouyinApplication.isServer then root:SetActive(false); return end
    for i=0,root.transform.childCount-1 do
        local child=root.transform:GetChild(i)
        sources[child.name]=child:GetComponent(typeof(UnityEngine.AudioSource))
    end
    RaceRuntime.audio={Play=Play,VehicleEvent=VehicleEvent,ItemEvent=ItemEvent}
    for _,name in ipairs({"engine","skid","wind"}) do sources[name]:Play() end
end
function Update()
    if DouyinApplication.isServer then return end
    local selected=RaceRuntime.song or 0
    if song~=selected then
        if song~=nil then sources[string.format("music%d",song)]:Stop(); started[song]=nil end
        song=selected
    end
    local music=sources[string.format("music%d",song)]
    if RaceRuntime.music then
        if not music.isPlaying then
            if started[song] then music:UnPause() else music:Play(); started[song]=true end
        end
    elseif music.isPlaying then music:Pause() end
    local match,entry,car=RaceRuntime.match,RaceRuntime.localEntry,RaceRuntime.localCar
    local driving=match and (match.phase=="race" or match.phase=="countdown") and entry and not entry.finished
    local speed=car and math.min(1.2,math.abs(car.s)/RaceConfig.vmaxNitro) or 0
    local smoothing=math.min(1,UnityEngine.Time.unscaledDeltaTime*10)
    local function volume(name,target)
        sources[name].volume=sources[name].volume+(target-sources[name].volume)*smoothing
    end
    local gear=math.min(5,math.floor(speed*6*.999))
    local rpm=.3+(speed*6-gear)*.7*(.75+gear*.05)
    sources.engine.pitch=(55+rpm*130+(car and car:boosting() and 35 or 0))/55
    local throttle=car and car.throttle>0
    if match and match.phase=="countdown" and RaceRuntime.input then throttle=RaceRuntime.input.Frame().up end
    volume("engine",driving and (.085+(throttle and .05 or 0))/.135 or 0)
    sources.skid.pitch=1+speed*.66
    volume("skid",driving and car and car.drifting and not car.airborne and 1 or 0)
    volume("wind",driving and (speed*.05+(car:boosting() and .18 or 0))/.24 or 0)
    if match and entry then
        if epoch~=RaceRuntime.epoch then
            epoch=RaceRuntime.epoch
            if match.phase=="menu" or match.phase=="countdown" and phase~="pause" then
                lastCount=nil
                lastLap=0
                finished=false
            end
        end
        if match.phase=="countdown" then
            local count=math.max(1,math.ceil(match.countdown))
            if count~=lastCount then Play("count"); lastCount=count end
        elseif match.phase=="race" and phase=="countdown" then Play("go") end
        if entry.lapsDone>lastLap and not entry.finished then Play("lap") end
        if entry.finished and not finished then Play("finish") end
        lastLap,finished,phase=entry.lapsDone,entry.finished,match.phase
    end
    logTime=logTime+UnityEngine.Time.unscaledDeltaTime
    if logTime>5 then
        logTime=0
        print(string.format("[RacingClone][Client] AUDIO song=%d playing=%s engine=%.3f pitch=%.3f skid=%.3f wind=%.3f",
            song,tostring(music.isPlaying),sources.engine.volume,sources.engine.pitch,sources.skid.volume,sources.wind.volume))
    end
end
function OnDestroy()
    RaceRuntime.audio=nil
end
