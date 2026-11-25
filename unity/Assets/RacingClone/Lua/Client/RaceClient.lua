---@var inputScript:DouyinScript
---@var telemetry:UnityEngine.UI.Text
---@var eventLabel:UnityEngine.UI.Text
---@var controls:GameObject
---@varSync raceSnapshot:string
---@end
local json = RaceJson
local channel = DouyinRemoteEvent("RacingClone.Input.v1")
local track, localId, car, clock
local seq, ack, accumulator, sendTime, lastTick, logTime = 0, 0, 0, 0, -1, 0
local pending, targets, visuals = {}, {}, {}
local actor, eventUntil
local networkReady = false
local epoch,match,localEntry,controlSeq = -1,nil,nil,0
local controlPending = {}
local function control(action,value)
    if not match then return end
    controlSeq=controlSeq+1
    controlPending[controlSeq]={seq=controlSeq,epoch=epoch,action=action,value=value}
end
local messages = {driftStart="漂移",driftEnd="小喷窗口",gaugeFull="氮气 +1",nitro="氮气喷射",
    smallBoost="小喷",landBoost="落地喷",double="双喷",startBoost="起步喷",pad="加速带",crash="碰墙",reset="复位"}
local function showEvents()
    if not car then return end
    for _, event in ipairs(car.events) do
        local text = messages[event.type]
        if text then print("[RacingClone][Client] EVENT type=" .. event.type .. " data=" .. json.encode(event.data)) end
        if text and eventLabel then
            if event.data.perfect then text = "完美" .. text end
            eventLabel.text, eventUntil = text, UnityEngine.Time.unscaledTime + 1.2
        end
    end
    car.events = {}
end
local function applySnapshot(payload)
    if DouyinApplication.isServer or type(payload) ~= "string" or payload == "" then return end
    local packet = json.decode(payload)
    if type(packet) ~= "table" or packet.version ~= 2 or type(packet.tick) ~= "number" or packet.tick <= lastTick then return end
    lastTick = packet.tick
    local changed=epoch~=packet.epoch
    epoch,match=packet.epoch,packet.match
    RaceRuntime.match,RaceRuntime.cars,RaceRuntime.localId=match,packet.cars,localId
    local controlAck=match.controlAcks[localId] or 0
    controlSeq=math.max(controlSeq,controlAck)
    for i in pairs(controlPending) do if i<=controlAck then controlPending[i]=nil end end
    if changed then
        pending,accumulator={},0
        if RaceRuntime.input then RaceRuntime.input.Clear() end
        print("[RacingClone][Client] PHASE epoch="..epoch.." phase="..match.phase.." time="..match.time)
    end
    local live = {}
    for _, entry in ipairs(packet.cars or {}) do
        live[entry.slot] = true
        targets[entry.slot] = entry
        if packet.tick % 600 < 6 then
            print(string.format("[RacingClone][Client] SNAPSHOT tick=%d id=%s ack=%d x=%.6f z=%.6f speed=%.6f",packet.tick,entry.id,entry.ack,entry.state.x,entry.state.z,entry.state.s))
        end
        if entry.id == localId and (changed or entry.ack >= ack) then
            localEntry=entry
            RaceRuntime.localEntry=entry
            if not car then
                car = RaceVehicleSimulation.new(track)
                seq = entry.ack
                RaceRuntime.localCar = car
            end
            if changed or entry.finished then seq=entry.ack; pending={} end
            ack = entry.ack
            car:restore(entry.state)
            clock = {time=entry.clock.time,startTried=entry.clock.startTried,startReady=entry.clock.startReady,
                phase=match.phase,countdown=match.countdown}
            for i = ack + 1, seq do
                if pending[i] then RaceProtocol.step(car,pending[i].input,clock) end
            end
            car.events = {}
            for i in pairs(pending) do if i <= ack then pending[i] = nil end end
            RaceRuntime.localSlot = entry.slot
        end
    end
    if controls then controls:SetActive(match.phase=="race" or match.phase=="countdown") end
    if packet.tick%600<6 or (match.phase=="pause" or match.phase=="result") and packet.tick%120<6 then
        print("[RacingClone][Client] MATCH "..json.encode(packet))
    end
    for slot in pairs(targets) do if not live[slot] then targets[slot] = nil end end
end
function OnNetSpawned()
    networkReady = true
end
function OnNetDestroy()
    networkReady = false
    RaceRuntime.publish = nil
end
function Start()
    if DouyinApplication.isServer then
        RaceRuntime.publish = function(payload)
            if networkReady and DouyinNetService.isNetworkSettled and self:HasOwnership() then raceSnapshot:SetValue(payload) end
        end
        return
    end
    track = RaceTrackMath.new(RaceTrackData)
    RaceRuntime.control=control
    local grid = UnityEngine.GameObject.Find("Starting Grid")
    if grid then
        for i = 0, grid.transform.childCount - 1 do
            local tr = grid.transform:GetChild(i)
            visuals[i+1] = {transform=tr,flames={},skins={}}
            for skin=0,tr.childCount-1 do
                local child=tr:GetChild(skin)
                if string.sub(child.name,1,5)=="Skin_" then visuals[i+1].skins[tonumber(string.sub(child.name,6))]=child.gameObject end
            end
            local children = tr:GetComponentsInChildren(typeof(UnityEngine.Transform),true)
            for j = 0, children.Length - 1 do
                if string.find(children[j].name,"flame") then visuals[i+1].flames[#visuals[i+1].flames+1] = children[j].gameObject end
            end
        end
    end
    print("[RacingClone][Client] SCENE_LOADED")
end
local function lockActor()
    local current = DouyinActorService.GetLocalActor()
    if current and current.isLocal and current ~= actor and car then
        actor = current
        actor:Immobilize(true)
        actor:SetVisible(false)
    end
end
function Update()
    if DouyinApplication.isServer or not networkReady or not DouyinNetService.isNetworkSettled then return end
    local player = DouyinPlayerService.GetLocalPlayer()
    if not player then return end
    if localId == nil then
        localId = tostring(player.playerID)
        print("[RacingClone][Client] CLIENT_READY name=" .. player.playerName .. " id=" .. localId)
    end
    applySnapshot(raceSnapshot:GetValue())
    lockActor()
    local dt = math.min(UnityEngine.Time.unscaledDeltaTime,RaceConfig.maxFrame)
    if car and inputScript then
        local input = inputScript.script.Frame()
        if input.cameraPressed then
            RaceRuntime.cameraMode = ((RaceRuntime.cameraMode or 1) % 3) + 1
        end
        if input.pausePressed then control(match.phase=="pause" and "resume" or "pause") end
        if input.startPressed and match.phase=="menu" then control("start") end
        local driving=(match.phase=="countdown" or match.phase=="race") and localEntry and not localEntry.finished
        accumulator = driving and accumulator + dt or 0
        local first = true
        while accumulator >= RaceConfig.dt and seq - ack < 240 do
            accumulator = accumulator - RaceConfig.dt
            local command = RaceProtocol.input(input)
            if not first then command.upPressed,command.wPressed,command.nitroPressed,command.resetPressed = false,false,false,false end
            seq = seq + 1
            pending[seq] = {seq=seq,input=command}
            RaceProtocol.step(car,command,clock)
            first = false
        end
        if not first then inputScript.script.ConsumeEdges() end
        if first and (input.pausePressed or input.startPressed or input.cameraPressed) then inputScript.script.ConsumeEdges() end
        showEvents()
        if eventLabel and eventUntil and UnityEngine.Time.unscaledTime > eventUntil then eventLabel.text = "" end
        if telemetry then
            telemetry.text = string.format("%03d km/h    集气 %02d%%    氮气 %d/2\n%s    小喷窗口 %.2fs",
                math.floor(math.abs(car.s)*3.6),math.floor(car.gauge*100),car.nitroCount,
                car.drifting and "漂移中" or car.airborne and "腾空" or "驾驶",math.max(0,car.smallWindow))
        end
    end
    sendTime,logTime = sendTime + dt,logTime + dt
    if sendTime >= 1/RaceConfig.inputHz then
        sendTime = sendTime % (1/RaceConfig.inputHz)
        local commands = {}
        for i = ack+1,seq do if pending[i] then commands[#commands+1] = pending[i] end end
        local requests={}
        for i=1,controlSeq do if controlPending[i] then requests[#requests+1]=controlPending[i] end end
        channel:FireServer(json.encode({version=2,epoch=epoch,commands=commands,controls=requests}))
    end
    if logTime >= 5 then
        logTime = 0
        if car then
            local input = inputScript.script.Frame()
            local camera = CS.DouyinCameraService.GetCamera()
            print(string.format("[RacingClone][Client] PREDICT seq=%d ack=%d focused=%s up=%s down=%s left=%s right=%s shift=%s cameraMode=%d speed=%.3f car=(%.3f,%.3f,%.3f) camera=%s yaw=%s pitch=%s",
                seq,ack,tostring(UnityEngine.Application.isFocused),tostring(input.up),tostring(input.down),
                tostring(input.left),tostring(input.right),tostring(input.shift),RaceRuntime.cameraMode or 1,car.s,car.x,car.y,-car.z,
                camera and tostring(camera.transform.position) or "nil",tostring(CS.DouyinCameraService.GetYaw()),tostring(CS.DouyinCameraService.GetPitch())))
        end
        for _, entry in pairs(targets) do
            print(string.format("[RacingClone][Client] STATE tick=%d id=%s ack=%d x=%.6f z=%.6f speed=%.6f",lastTick,entry.id,entry.ack,entry.state.x,entry.state.z,entry.state.s))
        end
    end
end
function LateUpdate()
    if DouyinApplication.isServer or not networkReady or not DouyinNetService.isNetworkSettled then return end
    if actor and car and DouyinActorService.GetLocalActor() == actor then
        actor.position = UnityEngine.Vector3(car.x,car.y,-car.z)
    end
    local dt = math.min(UnityEngine.Time.unscaledDeltaTime,RaceConfig.maxFrame)
    for slot, visual in ipairs(visuals) do
        local entry = targets[slot]
        if entry then
            for skin,go in pairs(visual.skins) do go:SetActive(skin==entry.skin) end
        end
        local v = slot == RaceRuntime.localSlot and car or entry and entry.state
        if v then
            local position = UnityEngine.Vector3(v.x,v.y,-v.z)
            local p = track:sample(v.d)
            local pitch = v.airborne and RaceTrackMath.clamp(-v.vy*0.012,-0.3,0.3) or -math.atan(track.slope[v.hint]*math.cos(v.h-p.hd))
            local roll = -track.bank[v.hint]*math.cos(v.h-p.hd)
            local rotation = UnityEngine.Quaternion.Euler(-pitch*180/math.pi,180-v.h*180/math.pi,roll*180/math.pi)
            if slot == RaceRuntime.localSlot then visual.transform:SetPositionAndRotation(position,rotation)
            else
                visual.transform.position = UnityEngine.Vector3.Lerp(visual.transform.position,position,1-math.exp(-20*dt))
                visual.transform.rotation = UnityEngine.Quaternion.Slerp(visual.transform.rotation,rotation,1-math.exp(-20*dt))
            end
            for _, flame in ipairs(visual.flames) do
                flame:SetActive(v.nitroTime>0 or v.smallBoost>0 or v.padTime>0 or v.startBoost>0)
            end
        end
    end
end
function OnDisable()
    if RaceRuntime.input then RaceRuntime.input.Clear() end
    if actor and DouyinNetService.isNetworkSettled and DouyinActorService.GetLocalActor() == actor then
        actor:Immobilize(false)
        actor:SetVisible(true)
    end
    actor = nil
end
function OnDestroy()
    OnDisable()
    RaceRuntime.localCar, RaceRuntime.publish, RaceRuntime.control = nil, nil, nil
    channel:Dispose()
    channel = nil
end
