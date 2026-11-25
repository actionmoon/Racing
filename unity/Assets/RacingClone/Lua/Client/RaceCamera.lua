local CameraService, InputService = CS.DouyinCameraService, CS.DouyinInputService
local UE = UnityEngine
local looking, lastLook = false, -math.huge
local startHandler, performHandler, cancelHandler
local defaultPitch, defaultYaw, defaultFov, active
local yaw
local offsetCorrection, lastAnchor = UE.Vector3.zero, nil
local function restore()
    if not active then return end
    CameraService.SetDistance(4)
    CameraService.SetOffset(UE.Vector3.zero)
    CameraService.SetPitch(defaultPitch or 0)
    if defaultYaw ~= nil then CameraService.SetYaw(defaultYaw) end
    local camera = CameraService.GetCamera()
    if camera ~= nil and defaultFov ~= nil then camera.fieldOfView = defaultFov end
    active = false
    offsetCorrection, lastAnchor = UE.Vector3.zero, nil
end
function Start()
    if DouyinApplication.isServer then return end
    startHandler = function() looking = true; lastLook = UE.Time.unscaledTime end
    performHandler = function(_) looking = true; lastLook = UE.Time.unscaledTime end
    cancelHandler = function() looking = false; lastLook = UE.Time.unscaledTime end
    InputService.onLookInputStart:AddListener(startHandler)
    InputService.onLookInputPerform:AddListener(performHandler)
    InputService.onLookInputCancel:AddListener(cancelHandler)
end
function getCameraAlignTargetYaw()
    local car = RaceRuntime.localCar
    if car == nil then return nil end
    local heading = car.s >= 0 and car.m + RaceTrackMath.angle(car.h-car.m)*0.35 or car.h
    return 180 - heading * 180 / math.pi
end
function getCameraAlignSpeedScale() return 1 end
local function applyView(car, actor, camera, dt)
    local mode = RaceConfig.cameraModes[RaceRuntime.cameraMode or 1]
    local boostDistance = car.nitroTime > 0 and 1.6 or car.smallBoost > 0 and 0.8 or 0
    local distance = mode.dist + math.abs(car.s)*0.018 + boostDistance + mode.look
    local height = mode.height - mode.lookHeight
    local rad = (180 - (yaw or getCameraAlignTargetYaw())) * math.pi / 180
    local target = UE.Vector3(car.x+math.sin(rad)*mode.look,car.y+mode.lookHeight,-car.z-math.cos(rad)*mode.look)
    local desired = UE.Vector3(car.x-math.sin(rad)*(distance-mode.look),car.y+mode.height,-car.z+math.cos(rad)*(distance-mode.look))
    local observed = camera.transform.position
    if lastAnchor then observed = observed + actor.position - lastAnchor end
    -- Compensate the platform's distance limit through the supported target offset.
    offsetCorrection = offsetCorrection + (desired-observed)*(1-math.exp(-8*dt))
    lastAnchor = actor.position
    -- The platform applies offset in the camera's local coordinate frame.
    CameraService.SetOffset(UE.Quaternion.Inverse(camera.transform.rotation) * (target - actor.position + offsetCorrection))
    CameraService.SetDistance(math.sqrt(distance*distance+height*height))
    CameraService.SetPitch(math.atan(height,distance)*180/math.pi)
    local fov = 66+math.abs(car.s)*0.12+(car.nitroTime>0 and 9 or 0)+(car.smallBoost>0 and 4 or 0)
    camera.fieldOfView = UE.Mathf.Lerp(camera.fieldOfView,fov,1-math.exp(-4*dt))
end
function LateUpdate()
    if DouyinApplication.isServer or not DouyinNetService.isNetworkSettled then return end
    local car = RaceRuntime.localCar
    local actor = DouyinActorService.GetLocalActor()
    if car == nil or actor == nil or not actor.isLocal then return end
    local camera = CameraService.GetCamera()
    if camera == nil then return end
    if not active then
        defaultPitch,defaultYaw,defaultFov = CameraService.GetPitch(),CameraService.GetYaw(),camera.fieldOfView
        active = true
    end
    local dt = math.min(UE.Time.unscaledDeltaTime,RaceConfig.maxFrame)
    if not looking and UE.Time.unscaledTime-lastLook >= 0.5 then
        local target = getCameraAlignTargetYaw()
        local scale = getCameraAlignSpeedScale()
        local current = CameraService.GetYaw()
        if target ~= nil and scale ~= nil and scale > 0 and current ~= nil then
            local delta = UE.Mathf.DeltaAngle(current,target)
            local rate = car.drifting and 4.5 or 7
            local step = RaceTrackMath.clamp(delta*(1-math.exp(-rate*dt)),-360*scale*dt,360*scale*dt)
            CameraService.SetYaw(current+step)
            yaw = current+step
        end
    else yaw = CameraService.GetYaw() end
    applyView(car,actor,camera,dt)
end
function OnDisable() restore() end
function OnDestroy()
    restore()
    if startHandler ~= nil then InputService.onLookInputStart:RemoveListener(startHandler) end
    if performHandler ~= nil then InputService.onLookInputPerform:RemoveListener(performHandler) end
    if cancelHandler ~= nil then InputService.onLookInputCancel:RemoveListener(cancelHandler) end
end
