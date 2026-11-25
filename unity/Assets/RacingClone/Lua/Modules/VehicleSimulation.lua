local Config = require "RaceConfig"
local Math = require "TrackMath"
local clamp, angle, smooth = Math.clamp, Math.angle, Math.smooth
local abs, sin, cos, exp = math.abs, math.sin, math.cos, math.exp
local function sign(v) return v > 0 and 1 or v < 0 and -1 or 0 end
local function hypot(x, z) return math.sqrt(x * x + z * z) end
local Vehicle = {}
Vehicle.__index = Vehicle
function Vehicle.new(track, distance, lateral)
    local v = setmetatable({track = track}, Vehicle)
    v:reset(distance or 0, lateral or 0)
    return v
end
function Vehicle:reset(distance, lateral)
    local p = self.track:sample(distance)
    self.x, self.y, self.z = p.x + p.rx * lateral, p.y + 0.05, p.z + p.rz * lateral
    self.h, self.m = p.hd, p.hd
    for _, k in ipairs({"s","vy","vyGround","airTime","steer","driftDir","driftTime",
        "driftAngle","gauge","nitroCount","nitroTime","smallBoost","smallBoostPower",
        "smallWindow","padTime","startBoost","spin","shield","slowTime","magnet",
        "impact","wrongWay","pitchVis","rollVis","throttle","releaseTime"}) do self[k] = 0 end
    self.airborne, self.drifting, self.windowKind = false, false, ""
    self.events, self.proj = {}, {}
    self.track:project(self.x, self.y, self.z, -1, self.proj)
    self.hint, self.d, self.lat = self.proj.i, self.proj.d, self.proj.lat
end
function Vehicle:emit(kind, data)
    self.events[#self.events + 1] = {type = kind, data = data or {}}
end
function Vehicle:boosting()
    return self.nitroTime > 0 or self.smallBoost > 0 or self.padTime > 0 or self.startBoost > 0
end
function Vehicle:triggerNitro(free)
    if not free then
        if self.nitroCount <= 0 then return false end
        self.nitroCount = self.nitroCount - 1
    end
    local double = self.smallBoost > 0.35
    self.nitroTime = math.min(4.5, math.max(0, self.nitroTime) + Config.nitroTime)
    self.s = math.max(self.s, 20) + 4
    self:emit("nitro", {double = double})
    if double then self:emit("double") end
    return true
end
function Vehicle:endDrift(allow)
    if not self.drifting then return end
    self.drifting = false
    if allow ~= false and self.driftTime > 0.22 then
        self.smallWindow, self.windowKind = Config.smallWindow, "drift"
    end
    self:emit("driftEnd", {time = self.driftTime})
end
function Vehicle:applyStartBoost()
    self.startBoost, self.s = 1.4, math.max(self.s, 16)
    self:emit("startBoost")
end
function Vehicle:resetOnTrack()
    local d, lat, gauge, count = self.d, clamp(self.lat, -4, 4), self.gauge, self.nitroCount
    self:reset(d, lat)
    self.gauge, self.nitroCount, self.s = gauge, count, 12
    self:emit("reset")
end
function Vehicle:update(dt, input, enabled, itemMode)
    local r, t = Config, self.track
    local e = enabled == false and {} or input
    local spinning = self.spin > 0
    if spinning then self.spin = self.spin - dt; e = {} end
    local steer = (e.left and 1 or 0) - (e.right and 1 or 0)
    self.steer = smooth(self.steer, steer, 12, dt)
    local vmax, accel = r.vmax, r.accel
    if self.nitroTime > 0 then vmax, accel = r.vmaxNitro, r.nitroAccel; self.nitroTime = self.nitroTime - dt end
    if self.smallBoost > 0 then vmax, accel = vmax + self.smallBoostPower, accel + 14; self.smallBoost = self.smallBoost - dt end
    if self.padTime > 0 then vmax, accel = vmax + 12, accel + 20; self.padTime = self.padTime - dt end
    if self.startBoost > 0 then vmax, accel = vmax + 10, accel + 26; self.startBoost = self.startBoost - dt end
    if self.magnet > 0 then vmax, accel = vmax + 10, accel + 12; self.magnet = self.magnet - dt end
    vmax = math.min(vmax, 86)
    if self.slowTime > 0 then vmax = vmax * 0.55; self.slowTime = self.slowTime - dt end
    if self.shield > 0 then self.shield = self.shield - dt end
    self.vmaxNow = vmax
    if self.smallWindow > 0 then
        self.smallWindow = self.smallWindow - dt
        if e.upPressed or e.wPressed then
            local perfect = (self.windowKind == "drift" and r.smallWindow or 0.45) - self.smallWindow < 0.2
            local double = self.nitroTime > 0
            self.smallBoost = perfect and 1 or 0.75
            self.smallBoostPower = (perfect and 11 or 8) + (double and 5 or 0)
            self.s = self.s + (perfect and 5.5 or 4)
            if double then self.nitroTime = self.nitroTime + 0.3 end
            self:emit(self.windowKind == "land" and "landBoost" or "smallBoost", {perfect = perfect, double = double})
            if double then self:emit("double") end
            self.smallWindow = 0
        end
    end
    if e.nitroPressed and not itemMode then self:triggerNitro() end
    local grounded = not self.airborne
    self.throttle = e.up and 1 or e.down and -1 or 0
    if grounded then
        if e.up then
            if self.s < 0 then self.s = self.s + r.brake * dt
            elseif self.s < vmax then self.s = self.s + accel * (1 - (self.s / vmax)^2 * 0.85) * dt end
        elseif e.down then
            if self.s > 0.5 then self.s = self.s - r.brake * dt
            else self.s = math.max(-r.reverseMax, self.s - 14 * dt) end
        else
            local roll = (r.roll + abs(self.s) * 0.06) * dt
            self.s = abs(self.s) <= roll and 0 or self.s - sign(self.s) * roll
        end
        if self.s > vmax then self.s = self.s - (self.s - vmax) * 1.1 * dt end
        self.s = self.s - t.slope[self.hint] * cos(self.h - t.hd[self.hint]) * 6 * dt
    end
    if not self.drifting and e.shift and steer ~= 0 and self.s > r.driftMinSpeed and grounded and not spinning then
        self.drifting, self.driftDir, self.driftTime, self.releaseTime, self.smallWindow = true, steer, 0, 0, 0
        self.h = self.h + self.driftDir * 0.07
        self:emit("driftStart")
    end
    if self.drifting then
        local align, held = steer * self.driftDir, e.shift
        self.releaseTime = held and 0 or self.releaseTime + dt
        local yaw = held and r.driftYaw + r.driftYawAlign * align or (0.45 + 0.9 * align) * exp(-2.2 * self.releaseTime)
        self.h = self.h + self.driftDir * yaw * clamp(self.s / 26, 0.35, 1) * dt * (grounded and 1 or 0.4)
        local grip = held and r.driftGrip or r.driftGripRelease
        self.m = self.m + angle(self.h - self.m) * (1 - exp(-grip * dt))
        local drift = angle(self.h - self.m)
        if abs(drift) > r.maxDriftAngle then
            self.m = self.h - sign(drift) * r.maxDriftAngle
            drift = sign(drift) * r.maxDriftAngle
        end
        self.driftAngle = drift
        local sideways = abs(sin(drift))
        if grounded then self.s = self.s - (2.5 + 11 * sideways) * dt end
        if not itemMode and grounded then
            self.gauge = self.gauge + dt * r.gaugeRate * (0.3 + sideways * 1.7) * clamp(self.s / 35, 0.3, 1.1)
            while self.gauge >= 1 do
                if self.nitroCount < 2 then
                    self.nitroCount, self.gauge = self.nitroCount + 1, self.gauge - 1
                    self:emit("gaugeFull")
                else self.gauge = 1; break end
            end
        end
        self.driftTime = self.driftTime + dt
        if (not held and (abs(drift) < 0.1 or (align < 0 and abs(drift) < 0.26))) or self.s < 7 then
            self:endDrift(self.s >= 7)
        end
    else
        self.driftAngle = smooth(self.driftAngle, 0, 10, dt)
        local direction, speed = self.s >= 0 and 1 or -1, abs(self.s)
        local yaw = r.turnRate * clamp(speed / 9, 0, 1) * (1 - 0.55 * clamp(speed / r.vmax, 0, 1.3))
        self.h = self.h + self.steer * yaw * dt * direction * (grounded and 1 or 0.35)
        if self.s >= 0 then self.m = self.m + angle(self.h - self.m) * (1 - exp(-r.grip * dt))
        else self.m = self.h end
    end
    if spinning then self.h = self.h + 9 * dt end
    local direction = self.s >= 0 and self.m or self.h
    local vx, vz = sin(direction) * self.s, cos(direction) * self.s
    self.x, self.z = self.x + vx * dt, self.z + vz * dt
    local p = t:project(self.x, self.y, self.z, self.hint, self.proj)
    self.hint, self.d, self.impact = p.i, p.d, 0
    local limit = t.halfW - 1.1
    if abs(p.lat) > limit then
        local side = sign(p.lat)
        local nx, nz, penetration = p.rx * side, p.rz * side, abs(p.lat) - limit
        self.x, self.z = self.x - nx * penetration, self.z - nz * penetration
        local normalSpeed = vx * nx + vz * nz
        if normalSpeed > 0 then
            local speed = math.max(1, hypot(vx, vz))
            local power = normalSpeed / speed
            vx, vz = vx - nx * normalSpeed * 1.25, vz - nz * normalSpeed * 1.25
            vx, vz = vx * (1 - 0.45 * power), vz * (1 - 0.45 * power)
            local newSpeed = hypot(vx, vz)
            if self.s >= 0 then
                self.s = newSpeed
                if newSpeed > 0.5 then self.m = math.atan(vx, vz) end
                local target = abs(angle(self.h - p.hd)) < math.pi / 2 and p.hd or p.hd + math.pi
                self.h = self.h + angle(target - self.h) * math.min(1, 0.6 * power + 0.05)
            else self.s = -newSpeed end
            self.impact = power * speed
            if power > 0.3 and self.drifting then self:endDrift(false) end
            if power * speed > 6 then self:emit("crash", {power = power * speed, x = self.x - nx * 0.9, z = self.z - nz * 0.9})
            elseif speed > 8 then self:emit("scrape", {x = self.x + nx, z = self.z + nz}) end
        end
        p.lat = side * limit
    end
    self.lat = p.lat
    local groundY = p.y + p.lat * sin(p.bank)
    if self.airborne then
        self.vy = self.vy - r.gravity * dt
        self.y, self.airTime = self.y + self.vy * dt, self.airTime + dt
        if self.y <= groundY then
            self.y, self.airborne = groundY, false
            local vertical = self.vy
            self.vy, self.vyGround = 0, 0
            self:emit("land", {air = self.airTime, v = vertical})
            if self.airTime > 0.3 then self.smallWindow, self.windowKind = 0.45, "land" end
            self.airTime = 0
        end
    else
        local forward = self.s * cos(self.m - p.hd)
        if forward > 18 and forward * forward * -t.vcurv[p.i] > r.gravity then
            self.airborne, self.airTime, self.vy = true, 0, t.sslope[p.i] * forward
            self.y = groundY + self.vy * dt
            if self.drifting then self:endDrift(false) end
        else self.y = groundY end
    end
    if cos(angle(self.h - p.hd)) < -0.35 and self.s > 4 then self.wrongWay = self.wrongWay + dt
    else self.wrongWay = math.max(0, self.wrongWay - dt * 2) end
    for _, pad in ipairs(t.boostPads or {}) do
        local distance = (self.d - (pad.d - pad.len / 2)) % t.length
        if distance < pad.len and abs(self.lat - pad.lat) < pad.halfW + 0.6 and not self.airborne then
            if self.padTime < 0.6 then self:emit("pad"); self.s = math.min(self.s + 6, 72) end
            self.padTime = 1.1
        end
    end
end
-- Full prediction state, with no Unity objects or track tables on the wire.
function Vehicle:snapshot()
    local out = {}
    for k, v in pairs(self) do
        if type(v) == "number" or type(v) == "boolean" or type(v) == "string" then out[k] = v end
    end
    return out
end
function Vehicle:restore(state)
    for k, v in pairs(state) do self[k] = v end
    self.events = {}
end
return Vehicle
