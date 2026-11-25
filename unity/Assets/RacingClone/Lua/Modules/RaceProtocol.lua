local Protocol = {}
local allowed = {"up","down","left","right","shift","upPressed","wPressed","nitroPressed","resetPressed"}
function Protocol.input(value)
    local out = {}
    for _, k in ipairs(allowed) do out[k] = value[k] == true end
    return out
end
function Protocol.step(car, command, clock)
    if clock.phase and clock.phase ~= "race" then
        if clock.phase == "countdown" and command.upPressed and not clock.startTried then
            clock.startTried = true
            clock.startReady = (clock.countdown or 3) <= 0.28
        end
        return
    end
    if command.resetPressed then car:resetOnTrack() end
    if clock.startReady then car:applyStartBoost(); clock.startReady = false end
    if command.upPressed and not clock.startTried then
        clock.startTried = true
        if clock.time < 0.28 then car:applyStartBoost() end
    end
    car:update(RaceConfig.dt, command, true, false)
    clock.time = clock.time + RaceConfig.dt
end
return Protocol
