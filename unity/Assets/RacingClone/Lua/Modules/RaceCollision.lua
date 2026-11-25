-- Source qc.collide / vel / pushRacer / kick.
local Collision={}
local function velocity(entry,track)
    local car=entry.car
    if not entry.isAI then return math.sin(car.m)*car.s,math.cos(car.m)*car.s end
    local p=track:sample(entry.ai.dist)
    return p.tx*car.s+p.rx*entry.ai.latV,p.tz*car.s+p.rz*entry.ai.latV
end
local function push(entry,track,x,z)
    local car=entry.car
    if not entry.isAI then car.x,car.z=car.x+x,car.z+z; return end
    local p=track:sample(entry.ai.dist)
    car.lat=car.lat+x*p.rx+z*p.rz
    entry.ai.pushD=entry.ai.pushD+x*p.tx+z*p.tz
end
local function kick(entry,track,x,z)
    local car=entry.car
    if not entry.isAI then
        local vx,vz=math.sin(car.m)*car.s+x,math.cos(car.m)*car.s+z
        local speed=math.sqrt(vx*vx+vz*vz)
        if car.s>=0 and speed>0.5 then car.s,car.m=speed,math.atan(vx,vz) end
    else
        local p=track:sample(entry.ai.dist)
        car.s=math.max(0,car.s+x*p.tx+z*p.tz)
        entry.ai.latV=entry.ai.latV+x*p.rx+z*p.rz
    end
end
function Collision.resolve(entries,track)
    for i=1,#entries do
        for j=i+1,#entries do
            local a,b=entries[i],entries[j]
            local x,z=b.car.x-a.car.x,b.car.z-a.car.z
            local squared=x*x+z*z
            if not a.finished and not b.finished and squared<=3.1^2 and math.abs(a.car.y-b.car.y)<=2.5 then
                local distance=math.sqrt(squared)
                if distance==0 then distance=0.01 end
                local nx,nz=x/distance,z/distance
                local penetration=3.1-distance
                push(a,track,-nx*penetration*0.5,-nz*penetration*0.5)
                push(b,track,nx*penetration*0.5,nz*penetration*0.5)
                local ax,az=velocity(a,track)
                local bx,bz=velocity(b,track)
                local relative=(bx-ax)*nx+(bz-az)*nz
                if relative<0 then
                    local impulse=-relative*0.5
                    kick(a,track,-nx*impulse,-nz*impulse)
                    kick(b,track,nx*impulse,nz*impulse)
                end
            end
        end
    end
end
return Collision
