-- Source Zo: sampled track motion, curve anticipation and lateral spring.
local Vehicle = require "VehicleSimulation"
local Math = require "TrackMath"
local AI = {}
AI.__index = AI
local function sign(v) return v > 0 and 1 or v < 0 and -1 or 0 end
function AI.new(track, distance, lateral, skill, seed)
    local self = setmetatable({track=track,skill=skill,seed=seed}, AI)
    self.car = Vehicle.new(track, distance, lateral)
    self.car.lat = lateral
    self.dist, self.latV, self.yawOff = distance, 0, 0
    self.pushD = 0
    self.personal = (self:random()-0.5)*0.6
    self.nitroCd = 6+self:random()*6
    self.startDelay = 0.05+self:random()*0.25
    return self
end
function AI:random()
    self.seed = (self.seed*16807)%2147483647
    return (self.seed-1)/2147483646
end
function AI:update(dt, enabled, time, rubber)
    local t, v = self.track, self.car
    local maximum = 55*(0.8+0.2*self.skill)*rubber
    if v.nitroTime > 0 then maximum = maximum+17; v.nitroTime = v.nitroTime-dt end
    if v.magnet>0 then maximum=maximum+10; v.magnet=v.magnet-dt end
    if v.slowTime>0 then maximum=maximum*0.55; v.slowTime=v.slowTime-dt end
    if v.shield>0 then v.shield=v.shield-dt end
    local spinning=v.spin>0
    if spinning then v.spin=v.spin-dt end
    local near = t:curvAhead(self.dist,8)
    local ahead = t:curvAhead(self.dist,18+v.s*1.25)
    local target = math.min(maximum,math.sqrt((16+30*self.skill)/math.max(math.abs(ahead),0.0001))+(v.nitroTime>0 and 6 or 0))
    if not enabled or time < self.startDelay then target = 0 end
    if spinning then target=5 end
    if v.s < target then
        v.s = v.s+(v.nitroTime>0 and 34 or 20+4*self.skill)*(1-(v.s/math.max(target,1))^2*0.7)*dt
    else v.s = v.s-math.min(v.s-target,30*dt) end
    v.s = math.max(0,v.s)
    self.nitroCd = self.nitroCd-dt
    if enabled and self.nitroCd<=0 and math.abs(t:curvAhead(self.dist,140))<0.006 and v.s>35 then
        v.nitroTime, self.nitroCd = 2.6,(6+self:random()*8)/self.skill
    end
    local limit = t.halfW-2.2
    local desired = Math.clamp(-sign(ahead)*Math.clamp(math.abs(ahead)*45,0,1)*limit*0.8+self.personal*limit*0.8,-limit,limit)
    self.latV = self.latV+Math.clamp((desired-v.lat)*2.2-self.latV*2.4,-14,14)*dt
    v.lat = v.lat+self.latV*dt
    if math.abs(v.lat)>limit then v.lat=sign(v.lat)*limit; self.latV=self.latV*-0.3 end
    self.dist = self.dist+v.s*dt+self.pushD
    self.pushD = 0
    local p = t:sample(self.dist)
    v.d,v.hint,v.x,v.z = p.d,p.i,p.x+p.rx*v.lat,p.z+p.rz*v.lat
    local ground = p.y+v.lat*math.sin(p.bank)
    if v.airborne then
        v.vy=v.vy-30*dt; v.y=v.y+v.vy*dt
        if v.y<=ground then v.y,v.airborne,v.vy,v.vyGround=ground,false,0,0 end
    elseif v.s>18 and v.s*v.s*-t.vcurv[p.i]>30 then
        v.airborne,v.vy=true,t.sslope[p.i]*v.s; v.y=ground+v.vy*dt
    else v.y=ground end
    v.drifting=math.abs(near)>0.012 and v.s>26
    v.driftDir=sign(near)
    self.yawOff=Math.smooth(self.yawOff,v.drifting and sign(near)*math.min(0.62,math.abs(near)*22) or 0,5,dt)
    v.h=p.hd+math.atan(self.latV,math.max(v.s,3))+self.yawOff
end
return AI
