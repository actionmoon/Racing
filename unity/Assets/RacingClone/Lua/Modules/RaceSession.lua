-- Pure authoritative room state. SDK calls live in RaceServer only.
local Config = require "RaceConfig"
local Vehicle = require "VehicleSimulation"
local AI = require "RaceAI"
local Protocol = require "RaceProtocol"
local Collision = require "RaceCollision"
local Session = {}
Session.__index = Session
local difficulty = {
    {skill={0.55,0.75},rubber={0.88,1.03}},
    {skill={0.85,1.05},rubber={0.93,1.06}},
    {skill={1.2,1.38},rubber={0.97,1.1}}
}
local names = {"追风少年","极速流星","弯道高手","疾风车手","城市猎手","闪电骑士"}
function Session.new(track)
    local self=setmetatable({track=track,entries={},host="",phase="menu",epoch=0,tick=0,
        time=0,countdown=3,firstFinish=-1,settings={laps=2,diff=1,map="city",mode="race"},
        controlAcks={},controls={}},Session)
    self:resetGrid()
    return self
end
function Session:resetEntry(entry)
    local d,lat=-14-math.floor((entry.slot-1)/2)*11,entry.slot%2==1 and -5.5 or 5.5
    entry.car=Vehicle.new(self.track,d,lat)
    entry.ai=nil
    if entry.isAI then
        local range=difficulty[self.settings.diff+1].skill
        entry.ai=AI.new(self.track,d,lat,range[1]+(range[2]-range[1])*((entry.slot*37%101)/100),1237+entry.slot*7919)
        entry.car=entry.ai.car
    end
    entry.lapsDone,entry.owed,entry.half,entry.lastD=-1,true,false,entry.car.d
    entry.progress=d; entry.finished=false; entry.finishTime=0; entry.lapStart=0; entry.lapTimes={}
    entry.stats={drift=0,small=0,perfect=0,double=0,nitro=0,crash=0,land=0,top=0}
    entry.clock={time=0,phase=self.phase,countdown=3,startTried=false,startReady=false}
    entry.queue,entry.ack,entry.credit={},0,12
end
function Session:resetGrid()
    for slot=1,6 do
        local entry=self.entries[slot]
        if not entry then
            entry={slot=slot,id="ai:"..slot,name=names[slot],isAI=true,skin=(slot-1)%8}
            self.entries[slot]=entry
        end
        self:resetEntry(entry)
    end
    self:rank()
end
function Session:find(id)
    for _,entry in ipairs(self.entries) do if entry.id==id then return entry end end
end
function Session:roster(players)
    local live={}
    for _,player in ipairs(players) do live[player.id]=true end
    for _,entry in ipairs(self.entries) do
        if not entry.isAI and not live[entry.id] then
            self.controls[entry.id]=nil
            entry.id,entry.name,entry.isAI="ai:"..entry.slot,names[entry.slot],true
            local range=difficulty[self.settings.diff+1].skill
            entry.ai=AI.new(self.track,entry.progress,entry.car.lat,(range[1]+range[2])/2,entry.slot*7919+1237)
            entry.ai.car:restore(entry.car:snapshot()); entry.car=entry.ai.car
            entry.queue,entry.ack={},0
        end
    end
    for _,player in ipairs(players) do
        if not self:find(player.id) then
            for _,entry in ipairs(self.entries) do
                if entry.isAI then
                    entry.id,entry.name,entry.isAI,entry.ai=player.id,string.sub(player.name,1,72),false,nil
                    entry.queue,entry.ack,entry.credit={},0,12
                    entry.car.m=entry.car.h
                    entry.lastD=entry.car.d
                    entry.owed=entry.progress<0
                    entry.half=entry.car.d>self.track.length*0.4
                    break
                end
            end
        end
    end
    if not live[self.host] then
        self.host=""
        for _,entry in ipairs(self.entries) do if not entry.isAI then self.host=entry.id; break end end
    end
end
function Session:transition(phase)
    self.phase,self.epoch=phase,self.epoch+1
    for _,entry in ipairs(self.entries) do
        entry.queue,entry.ack,entry.credit={},0,12
        entry.clock.phase,entry.clock.time,entry.clock.countdown=phase,self.time,self.countdown
    end
end
function Session:control(id, request)
    if type(request)~="table" or type(request.seq)~="number" or request.seq%1~=0 then return false end
    local ack=self.controlAcks[id] or 0
    if request.seq<=ack or request.seq>ack+64 then return false end
    self.controlAcks[id]=request.seq
    local entry=self:find(id)
    if not entry or entry.isAI or request.epoch~=self.epoch then return false end
    local action=request.action
    if action=="skin" and self.phase=="menu" and type(request.value)=="number" and request.value%1==0 and request.value>=0 and request.value<8 then
        entry.skin=request.value; return true
    end
    if id~=self.host then return false end
    if action=="laps" and self.phase=="menu" then
        for _,n in ipairs({1,2,3,5}) do if request.value==n then self.settings.laps=n; return true end end
    elseif action=="diff" and self.phase=="menu" and (request.value==0 or request.value==1 or request.value==2) then
        self.settings.diff=request.value; self:resetGrid(); return true
    elseif (action=="start" and self.phase=="menu") or (action=="restart" and (self.phase=="pause" or self.phase=="result")) then
        self.time,self.countdown,self.firstFinish=0,3,-1
        self:transition("countdown"); self:resetGrid(); return true
    elseif action=="pause" and (self.phase=="countdown" or self.phase=="race") then
        self.resumePhase=self.phase; self:transition("pause"); return true
    elseif action=="resume" and self.phase=="pause" then
        self:transition(self.resumePhase); return true
    elseif action=="quit" and (self.phase=="pause" or self.phase=="result") then
        self.time,self.countdown,self.firstFinish=0,3,-1
        self:transition("menu"); self:resetGrid(); return true
    end
    return false
end
function Session:input(id,packet)
    local entry=self:find(id)
    if not entry or entry.isAI or packet.epoch~=self.epoch or type(packet.commands)~="table"
        or (self.phase~="countdown" and self.phase~="race") or entry.finished then return end
    for index,command in ipairs(packet.commands) do
        if index>240 then break end
        if type(command)=="table" and type(command.seq)=="number" and command.seq%1==0
            and command.seq>entry.ack and command.seq<=entry.ack+240 and type(command.input)=="table" then
            entry.queue[command.seq]=Protocol.input(command.input)
        end
    end
end
function Session:lap(entry)
    entry.lapTimes[#entry.lapTimes+1]=self.time-entry.lapStart
    entry.lapStart=self.time
    if entry.lapsDone>=self.settings.laps and not entry.finished then
        entry.finished,entry.finishTime=true,self.time
        if self.firstFinish<0 then self.firstFinish=self.time end
    end
end
function Session:progress(entry)
    if entry.finished then return end
    local length,d=self.track.length,entry.car.d
    if entry.isAI then
        local lap=math.floor(entry.ai.dist/length)
        if lap>entry.lapsDone and lap>=1 then entry.lapsDone=lap; self:lap(entry) end
        entry.lapsDone,entry.progress=lap,entry.ai.dist
    else
        if entry.lastD>length*0.75 and d<length*0.25 then
            if entry.owed then entry.lapsDone,entry.owed=entry.lapsDone+1,false
            elseif entry.half then entry.lapsDone,entry.half=entry.lapsDone+1,false; self:lap(entry) end
        elseif entry.lastD<length*0.25 and d>length*0.75 then
            entry.lapsDone,entry.owed=entry.lapsDone-1,true
        end
        if d>length*0.4 and d<length*0.6 then entry.half=true end
        entry.lastD,entry.progress=d,entry.lapsDone*length+d
    end
end
function Session:rank()
    local sorted={}
    for _,entry in ipairs(self.entries) do sorted[#sorted+1]=entry end
    table.sort(sorted,function(a,b)
        if a.finished~=b.finished then return a.finished end
        if a.finished and a.finishTime~=b.finishTime then return a.finishTime<b.finishTime end
        if a.progress~=b.progress then return a.progress>b.progress end
        return a.slot<b.slot
    end)
    for rank,entry in ipairs(sorted) do entry.rank=rank end
end
function Session:update()
    local dt=Config.dt
    self.tick=self.tick+1
    if self.phase=="countdown" then
        self.countdown=math.max(0,self.countdown-dt)
        if self.countdown<=0 then self:transition("race") end
    elseif self.phase=="race" then self.time=self.time+dt
    end
    if self.phase=="countdown" or self.phase=="race" then
        local leader=-math.huge
        for _,entry in ipairs(self.entries) do if not entry.isAI then leader=math.max(leader,entry.progress) end end
        for _,entry in ipairs(self.entries) do
            if not entry.finished then
                entry.clock.time,entry.clock.phase,entry.clock.countdown=self.time,self.phase,self.countdown
                if entry.isAI and self.phase=="race" then
                    local range=difficulty[self.settings.diff+1].rubber
                    local gap=entry.progress-leader
                    local rubber=gap>0 and math.max(range[1],1-gap*0.00045) or math.min(range[2],1-gap*0.0004)
                    entry.ai:update(dt,true,self.time,rubber)
                    self:progress(entry)
                elseif not entry.isAI then
                    entry.credit=math.min(24,entry.credit+1)
                    local steps=0
                    while entry.queue[entry.ack+1] and entry.credit>=1 and steps<2 and not entry.finished do
                        local command=entry.queue[entry.ack+1]; entry.queue[entry.ack+1]=nil
                        entry.ack,entry.credit,steps=entry.ack+1,entry.credit-1,steps+1
                        Protocol.step(entry.car,command,entry.clock)
                        if self.phase=="race" then self:progress(entry) end
                        for _,event in ipairs(entry.car.events) do
                            local key=({driftStart="drift",smallBoost="small",double="double",nitro="nitro",crash="crash",landBoost="land"})[event.type]
                            if key then entry.stats[key]=entry.stats[key]+1 end
                            if event.data.perfect then entry.stats.perfect=entry.stats.perfect+1 end
                        end
                        entry.car.events={}
                    end
                end
                entry.stats.top=math.max(entry.stats.top,entry.car.s*3.6)
            end
        end
        if self.phase=="race" then Collision.resolve(self.entries,self.track) end
        self:rank()
        if self.phase=="race" and self.firstFinish>=0 then
            local all=true
            for _,entry in ipairs(self.entries) do if not entry.finished then all=false end end
            if all or self.time-self.firstFinish>=10 then self:transition("result") end
        end
    end
end
function Session:snapshot()
    local cars={}
    for _,entry in ipairs(self.entries) do
        cars[#cars+1]={id=entry.id,name=entry.name,slot=entry.slot,isAI=entry.isAI,skin=entry.skin,
            ack=entry.ack,state=entry.car:snapshot(),clock=entry.clock,rank=entry.rank,
            lapsDone=entry.lapsDone,progress=entry.progress,finished=entry.finished,
            finishTime=entry.finishTime,lapTimes=entry.lapTimes,stats=entry.stats}
    end
    return {version=2,tick=self.tick,epoch=self.epoch,cars=cars,
        match={phase=self.phase,host=self.host,time=self.time,countdown=self.countdown,
            settings=self.settings,firstFinish=self.firstFinish,controlAcks=self.controlAcks}}
end
return Session
