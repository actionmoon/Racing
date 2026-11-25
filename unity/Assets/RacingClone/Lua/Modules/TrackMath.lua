local Track = {}
Track.__index = Track
function Track.angle(v)
    while v > math.pi do v = v - math.pi * 2 end
    while v < -math.pi do v = v + math.pi * 2 end
    return v
end
function Track.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function Track.smooth(v, target, rate, dt)
    return v + (target - v) * (1 - math.exp(-rate * dt))
end
function Track.new(data)
    local t = setmetatable({}, Track)
    for k, v in pairs(data.arrays) do t[k] = v end
    t.N, t.length, t.ds, t.halfW = data.samples, data.length, data.sampleDistance, data.halfWidth
    t.boostPads = data.boostPads
    return t
end
function Track:sample(distance, out)
    local p = out or {}
    -- Keep the source's two modulo operations, including positive distances.
    -- The addition affects rounding at sample boundaries.
    local remainder = distance - math.modf(distance / self.length) * self.length
    local d = (remainder + self.length) % self.length
    local f = d / self.ds
    local i = math.floor(f) % self.N + 1
    local j, a = i % self.N + 1, f - math.floor(f)
    p.i, p.t, p.d = i, a, d
    p.x = self.px[i] + (self.px[j] - self.px[i]) * a
    p.y = self.py[i] + (self.py[j] - self.py[i]) * a
    p.z = self.pz[i] + (self.pz[j] - self.pz[i]) * a
    p.hd = self.hd[i] + Track.angle(self.hd[j] - self.hd[i]) * a
    p.tx, p.tz = math.sin(p.hd), math.cos(p.hd)
    p.rx, p.rz = -p.tz, p.tx
    p.bank = self.bank[i] + (self.bank[j] - self.bank[i]) * a
    p.lat = 0
    return p
end
function Track:curvAhead(distance, ahead)
    local i = math.floor((distance % self.length) / self.ds)
    local curvature = 0
    for offset = 0, math.max(1, math.floor(ahead / self.ds)) - 1, 2 do
        local value = self.curv[(i + offset) % self.N + 1]
        if math.abs(value) > math.abs(curvature) then curvature = value end
    end
    return curvature
end
function Track:project(x, y, z, hint, out)
    local nearest, best = 1, math.huge
    local function check(i, vertical)
        local dx, dz = self.px[i] - x, self.pz[i] - z
        local dy = vertical and (self.py[i] - y) * 3 or 0
        local q = dx * dx + dz * dz + dy * dy
        if q < best then best, nearest = q, i end
    end
    if hint == nil or hint < 1 then
        for i = 1, self.N do check(i, true) end
    else
        for offset = -30, 30 do check((hint - 1 + offset) % self.N + 1, false) end
    end
    local i, j = nearest, nearest % self.N + 1
    local dx, dz = self.px[j] - self.px[i], self.pz[j] - self.pz[i]
    local f = ((x - self.px[i]) * dx + (z - self.pz[i]) * dz) / (dx * dx + dz * dz)
    if f < 0 then
        i, j = (nearest - 2) % self.N + 1, nearest
        dx, dz = self.px[j] - self.px[i], self.pz[j] - self.pz[i]
        f = ((x - self.px[i]) * dx + (z - self.pz[i]) * dz) / (dx * dx + dz * dz)
    end
    local p = self:sample((i - 1 + Track.clamp(f, 0, 1)) * self.ds, out)
    p.lat = (x - p.x) * p.rx + (z - p.z) * p.rz
    p.surfY = p.y + p.lat * math.sin(p.bank)
    return p
end
return Track
