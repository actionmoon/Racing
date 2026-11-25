---@var scenario:string
---@end
-- Controlled initial conditions for the verification scene only.
-- Production input packets, simulation, snapshot and visual scripts stay intact.
local begin, pulse, reportTime = nil, -1, 0
function Start()
    if DouyinApplication.isServer then
        local create = RaceVehicleSimulation.new
        RaceVehicleSimulation.new = function(...)
            local car = create(...)
            car.s = 35
            if scenario == "boost" then
                car.nitroCount,car.smallWindow,car.windowKind = 2,0.5,"drift"
            else
                car.y,car.vy,car.airborne = car.y+3,3,true
            end
            return car
        end
    end
end
function Frame()
    local now = UnityEngine.Time.unscaledTime
    if not begin then begin = now end
    local elapsed = now-begin
    local car = RaceRuntime.localCar
    local landed = car and car.windowKind == "land" and car.smallWindow > 0
    local nextPulse = scenario == "boost" and math.min(2,math.floor(elapsed/0.12)) or ((pulse==1 or landed) and 1 or 0)
    local edge = nextPulse ~= pulse
    local first = pulse == -1
    pulse = nextPulse
    return {up=true,upPressed=first,nitroPressed=scenario=="boost" and edge,
        wPressed=(scenario=="boost" and first) or (scenario=="landing" and edge and nextPulse==1)}
end
function ConsumeEdges() end
function Clear() end
function Update()
    if DouyinApplication.isServer or not RaceRuntime.localCar then return end
    reportTime = reportTime + UnityEngine.Time.unscaledDeltaTime
    if reportTime<0.5 then return end
    reportTime = 0
    local car,flames = RaceRuntime.localCar,0
    local grid = UnityEngine.GameObject.Find("Starting Grid")
    if grid and RaceRuntime.localSlot then
        local children = grid.transform:GetChild(RaceRuntime.localSlot-1):GetComponentsInChildren(typeof(UnityEngine.Transform),true)
        for i=0,children.Length-1 do
            if string.find(children[i].name,"flame") and children[i].gameObject.activeInHierarchy then flames=flames+1 end
        end
    end
    print(string.format("[RacingClone][Fixture] scenario=%s inventory=%d nitro=%.3f small=%.3f start=%.3f airborne=%s visibleFlames=%d",
        scenario,car.nitroCount,car.nitroTime,car.smallBoost,car.startBoost,tostring(car.airborne),flames))
end
