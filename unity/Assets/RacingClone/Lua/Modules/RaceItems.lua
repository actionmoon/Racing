-- Original ta rules, evaluated only by the authoritative Session.
local Items = {}
Items.__index = Items
local weights = {
    lead={{"banana",35},{"shield",30},{"nitro",20},{"missile",10},{"magnet",5}},
    mid={{"missile",25},{"nitro",25},{"banana",20},{"magnet",15},{"shield",15}},
    back={{"missile",32},{"nitro",30},{"magnet",25},{"shield",10},{"banana",3}}
}
function Items.new(track)
    local self=setmetatable({track=track,boxes={}},Items)
    for _,fraction in ipairs({0.1,0.35,0.6,0.85}) do
        local p=track:sample(fraction*track.length)
        for _,offset in ipairs({-0.6,-0.3,0,0.3,0.6}) do
            local lat=offset*track.halfW
            self.boxes[#self.boxes+1]={x=p.x+p.rx*lat,y=p.y+lat*math.sin(p.bank)+1.6,z=p.z+p.rz*lat,respawn=0}
        end
    end
    self:reset(20261)
    return self
end
function Items:reset(seed)
    self.seed,self.serial,self.eventSerial=seed,0,0
    self.bananas,self.missiles,self.events={},{},{}
    for _,box in ipairs(self.boxes) do box.respawn=0 end
end
function Items:random()
    self.seed=(self.seed*16807)%2147483647
    return (self.seed-1)/2147483646
end
function Items:emit(kind,entry,item,object)
    self.eventSerial=self.eventSerial+1
    self.events[#self.events+1]={id=self.eventSerial,type=kind,slot=entry.slot,item=item,object=object or 0}
    if #self.events>64 then table.remove(self.events,1) end
end
function Items:give(entry,count)
    if #entry.items>=2 then return end
    local group=entry.rank==1 and weights.lead or entry.rank>=count-1 and weights.back or weights.mid
    local n=self:random()*100
    for _,pair in ipairs(group) do
        n=n-pair[2]
        if n<=0 then
            entry.items[#entry.items+1]=pair[1]
            self:emit("get",entry,pair[1])
            return
        end
    end
end
function Items:swap(entry)
    if #entry.items~=2 then return end
    entry.items[1],entry.items[2]=entry.items[2],entry.items[1]
    self:emit("swap",entry,entry.items[1])
end
function Items:ahead(entry,entries)
    for _,other in ipairs(entries) do if other.rank==entry.rank-1 then return other end end
end
function Items:use(entry,entries)
    local item=table.remove(entry.items,1)
    if not item then return end
    local v=entry.car
    self:emit("use",entry,item)
    if item=="nitro" then
        if entry.isAI then v.nitroTime=2.6 else v:triggerNitro(true) end
    elseif item=="shield" then v.shield=7
    elseif item=="magnet" then
        v.magnet=3
        local target=self:ahead(entry,entries)
        entry.magnetTarget=target and target.slot or 0
    elseif item=="banana" then
        local x,z=v.x-math.sin(v.h)*3.2,v.z-math.cos(v.h)*3.2
        local p=self.track:project(x,v.y,z,v.hint,{})
        self.serial=self.serial+1
        self.bananas[#self.bananas+1]={id=self.serial,owner=entry.slot,age=0,x=x,y=p.y+p.lat*math.sin(p.bank)+0.25,z=z}
    elseif item=="missile" then
        local target=self:ahead(entry,entries)
        self.serial=self.serial+1
        self.missiles[#self.missiles+1]={id=self.serial,owner=entry.slot,target=target and target.slot or 0,
            x=v.x,y=v.y+1.8,z=v.z,dx=math.sin(v.h),dy=0,dz=math.cos(v.h),life=6,v=math.max(80,math.abs(v.s)+30)}
        if target then self:emit("lock",target,item,self.serial) end
    end
    return item
end
function Items:hit(entry,kind,object)
    local v=entry.car
    if v.shield>0 then
        v.shield=0
        self:emit("block",entry,kind,object)
        return false
    end
    v.spin=kind=="missile" and 1.3 or 1
    v.s=v.s*0.35
    if kind=="missile" then v.airborne,v.vy=true,8 end
    if not entry.isAI then v:endDrift(false) end
    self:emit("hit",entry,kind,object)
    return true
end
function Items:update(dt,entries)
    for index,box in ipairs(self.boxes) do
        if box.respawn>0 then box.respawn=math.max(0,box.respawn-dt)
        else
            for _,entry in ipairs(entries) do
                local v=entry.car
                local dx,dz=v.x-box.x,v.z-box.z
                if dx*dx+dz*dz<6.5 and math.abs(v.y+0.8-box.y)<3 then
                    box.respawn=2.5
                    self:give(entry,#entries)
                    self:emit("pickup",entry,"box",index)
                    break
                end
            end
        end
    end
    for i=#self.bananas,1,-1 do
        local b=self.bananas[i]
        b.age=b.age+dt
        local hit
        for _,entry in ipairs(entries) do
            local v=entry.car
            if entry.slot~=b.owner or b.age>=1.2 then
                local dx,dz=v.x-b.x,v.z-b.z
                if dx*dx+dz*dz<4.4 and math.abs(v.y-b.y)<2.5 then hit=entry; break end
            end
        end
        if hit or b.age>90 then
            if hit then self:hit(hit,"banana",b.id) end
            table.remove(self.bananas,i)
        end
    end
    for i=#self.missiles,1,-1 do
        local m=self.missiles[i]
        m.life=m.life-dt
        local target=entries[m.target]
        local hit=false
        if target and not target.finished then
            local v=target.car
            local dx,dy,dz=v.x-m.x,v.y+0.8-m.y,v.z-m.z
            local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
            if distance>0 then
                local alpha=math.min(1,dt*6)
                m.dx,m.dy,m.dz=m.dx+(dx/distance-m.dx)*alpha,m.dy+(dy/distance-m.dy)*alpha,m.dz+(dz/distance-m.dz)*alpha
                local norm=math.sqrt(m.dx*m.dx+m.dy*m.dy+m.dz*m.dz)
                if norm>0 then m.dx,m.dy,m.dz=m.dx/norm,m.dy/norm,m.dz/norm end
            end
            m.v=math.max(m.v,math.abs(v.s)+35)
            if distance<2.6 then self:hit(target,"missile",m.id); hit=true end
        end
        if not hit then m.x,m.y,m.z=m.x+m.dx*m.v*dt,m.y+m.dy*m.v*dt,m.z+m.dz*m.v*dt end
        if hit or m.life<=0 then table.remove(self.missiles,i) end
    end
end
function Items:think(entry,dt,entries)
    if #entry.items==0 then return end
    entry.itemTimer=entry.itemTimer-dt
    if entry.itemTimer>0 then return end
    entry.itemTimer=1+self:random()*3
    local item,target=entry.items[1],self:ahead(entry,entries)
    local gap=target and target.progress-entry.progress or 1e9
    if item=="missile" and (not target or gap>350) then
        if #entry.items>1 then self:swap(entry) end
        return
    end
    if item=="magnet" and (not target or gap>150) then return end
    self:use(entry,entries)
end
function Items:snapshot()
    local boxes={}
    for i,box in ipairs(self.boxes) do boxes[i]=box.respawn end
    return {boxes=boxes,bananas=self.bananas,missiles=self.missiles,events=self.events}
end
return Items
