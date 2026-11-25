local channel=DouyinRemoteEvent("RacingClone.Input.v1")
local session,ready
local accumulator,publishTime,rosterTime,lastEpoch=0,0,0,-1
local function roster()
    local players=DouyinPlayerService.GetPlayers()
    if not players then return end
    local live={}
    for i=0,players.Length-1 do
        local p=players[i]
        if p and not p.isServer then live[#live+1]={id=tostring(p.playerID),name=p.playerName} end
    end
    session:roster(live)
end
local function receive(player,...)
    if not session or not DouyinApplication.isServer or not DouyinNetService.isNetworkSettled or not player or player.isServer then return end
    local args={...}
    if type(args[1])~="string" or #args[1]>50000 then return end
    local packet=RaceJson.decode(args[1])
    if type(packet)~="table" or packet.version~=3 then return end
    local id=tostring(player.playerID)
    if not session:find(id) then roster() end
    if type(packet.controls)=="table" then
        for i,request in ipairs(packet.controls) do
            if i>16 then break end
            local previous=session.controlAcks[id] or 0
            local accepted=session:control(id,request)
            if type(request)=="table" and type(request.seq)=="number" and request.seq>previous then
                print("[RacingClone][Server] CONTROL action="..tostring(request.action).." accepted="..tostring(accepted).." epoch="..session.epoch)
            end
        end
    end
    session:input(id,packet)
end
function Start()
    if not DouyinApplication.isServer then return end
    UnityEngine.Application.SetStackTraceLogType(UnityEngine.LogType.Exception,UnityEngine.StackTraceLogType.Full)
    session=RaceSession.new(RaceTrackMath.new(RaceTrackData))
    channel.onServerEvent:AddListener(receive)
    print("[RacingClone][Server] SCENE_LOADED")
end
function Update()
    if not session or not DouyinApplication.isServer or not DouyinNetService.isNetworkSettled then return end
    if not ready then ready=true; print("[RacingClone][Server] SERVER_READY") end
    local dt=math.min(UnityEngine.Time.unscaledDeltaTime,RaceConfig.maxFrame)
    rosterTime=rosterTime+dt
    if rosterTime>=0.25 then rosterTime=0; roster() end
    accumulator,publishTime=accumulator+dt,publishTime+dt
    while accumulator>=RaceConfig.dt do
        accumulator=accumulator-RaceConfig.dt; session:update()
    end
    if session.epoch~=lastEpoch then
        lastEpoch=session.epoch
        print("[RacingClone][Server] PHASE epoch="..lastEpoch.." phase="..session.phase.." time="..session.time)
    end
    if publishTime>=1/RaceConfig.snapshotHz and RaceRuntime.publish then
        publishTime=publishTime%(1/RaceConfig.snapshotHz)
        local packet=session:snapshot()
        RaceRuntime.publish(RaceJson.encode(packet))
        if session.tick%600<6 or (session.phase=="result" or session.phase=="pause") and session.tick%120<6 then
            print("[RacingClone][Server] MATCH "..RaceJson.encode(packet))
        end
    end
end
function OnDestroy()
    if DouyinApplication.isServer then channel.onServerEvent:RemoveListener(receive) end
    channel:Dispose(); channel=nil
end
