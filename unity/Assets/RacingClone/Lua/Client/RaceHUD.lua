---@var lobby:GameObject
---@var modal:GameObject
---@var raceInfo:UnityEngine.UI.Text
---@var countdownLabel:UnityEngine.UI.Text
---@var lobbyInfo:UnityEngine.UI.Text
---@var modalInfo:UnityEngine.UI.Text
---@var resumeButton:GameObject
---@var minimap:GameObject
---@var gaugeFill:UnityEngine.UI.Image
---@var itemSlots:UnityEngine.UI.Text
---@var itemNotice:UnityEngine.UI.Text
---@var useLabel:UnityEngine.UI.Text
---@var swapButton:GameObject
---@end
local minX,maxX,minZ,maxZ,scale,markers,mapId
local epoch,lastEvent,noticeUntil=-1,0,0
local itemNames={nitro="氮气",shield="天使护盾",magnet="磁铁",banana="香蕉",missile="导弹"}
function Start()
    if DouyinApplication.isServer then return end
    minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
    for i,x in ipairs(RaceTrackData.arrays.px) do
        local z=RaceTrackData.arrays.pz[i]
        minX,maxX,minZ,maxZ=math.min(minX,x),math.max(maxX,x),math.min(minZ,z),math.max(maxZ,z)
    end
    scale=145/math.max(maxX-minX,maxZ-minZ)
    markers={}
    for i=1,6 do markers[i]=minimap.transform:Find("Marker "..i) end
end
local function mapChanged(id)
    mapId=id
    local data=RaceMaps.data[id].arrays
    minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
    for i,x in ipairs(data.px) do
        local z=data.pz[i]
        minX,maxX,minZ,maxZ=math.min(minX,x),math.max(maxX,x),math.min(minZ,z),math.max(maxZ,z)
    end
    scale=145/math.max(maxX-minX,maxZ-minZ)
    local function point(i)
        return UnityEngine.Vector2((data.px[i]-(minX+maxX)/2)*scale,((minZ+maxZ)/2-data.pz[i])*scale)
    end
    for i=0,127 do
        local a=point(math.floor(i*#data.px/128)+1)
        local b=point(math.floor((i+1)*#data.px/128)%#data.px+1)
        local line=minimap.transform:Find("Road "..i)
        line.anchoredPosition=(a+b)/2
        line.sizeDelta=UnityEngine.Vector2((b-a).magnitude+1,2)
        line.localRotation=UnityEngine.Quaternion.Euler(0,0,math.atan(b.y-a.y,b.x-a.x)*180/math.pi)
    end
end
local function time(t)
    if not t or t<=0 then return "--:--.---" end
    return string.format("%02d:%02d.%03d",math.floor(t/60),math.floor(t%60),math.floor(t%1*1000))
end
function Update()
    if DouyinApplication.isServer then return end
    local match,entry=RaceRuntime.match,RaceRuntime.localEntry
    if not match then return end
    local phase=match.phase
    lobby:SetActive(phase=="menu")
    modal:SetActive(phase=="pause" or phase=="result")
    resumeButton:SetActive(phase=="pause")
    local settings=match.settings
    if mapId~=settings.map then mapChanged(settings.map) end
    local itemMode=settings.mode=="item"
    swapButton:SetActive(itemMode and (phase=="race" or phase=="countdown"))
    useLabel.text=itemMode and "使用道具" or "氮气"
    itemSlots.text=itemMode and entry and string.format("① %s     ② %s\n空格 / Ctrl 使用 · Alt 换位",itemNames[entry.items[1]] or "空槽",itemNames[entry.items[2]] or "空槽") or ""
    if epoch~=RaceRuntime.epoch then
        epoch=RaceRuntime.epoch
        if phase=="menu" or phase=="countdown" then lastEvent=0 end
        itemNotice.text=""
    end
    for _,event in ipairs(RaceRuntime.items and RaceRuntime.items.events or {}) do
        if event.id>lastEvent then
            lastEvent=event.id
            print("[RacingClone][Client] ITEM "..RaceJson.encode(event))
            if entry and event.slot==entry.slot then
                if RaceRuntime.audio then RaceRuntime.audio.ItemEvent(event) end
                local label=itemNames[event.item] or ""
                local text=event.type=="get" and "获得 "..label or event.type=="use" and "使用 "..label
                    or event.type=="swap" and "已换位" or event.type=="lock" and "导弹锁定！"
                    or event.type=="block" and "天使护体！" or event.type=="hit" and (event.item=="missile" and "被导弹击中！" or "踩到香蕉皮！")
                if text then itemNotice.text=text; noticeUntil=UnityEngine.Time.unscaledTime+1.5 end
            end
        end
    end
    if UnityEngine.Time.unscaledTime>noticeUntil then itemNotice.text="" end
    minimap:SetActive(phase=="race" or phase=="countdown")
    if markers then
        for _,car in ipairs(RaceRuntime.cars) do
            local state=car.state
            markers[car.slot].anchoredPosition=UnityEngine.Vector2((state.x-(minX+maxX)/2)*scale,((minZ+maxZ)/2-state.z)*scale)
            markers[car.slot]:GetComponent(typeof(UnityEngine.UI.Image)).color=car.id==RaceRuntime.localId and UnityEngine.Color.yellow or UnityEngine.Color.white
        end
    end
    gaugeFill.gameObject.transform.parent.gameObject:SetActive(not itemMode)
    gaugeFill.fillAmount=RaceRuntime.localCar and RaceRuntime.localCar.gauge or 0
    if phase=="menu" then
        local hostName=""
        local lines={}
        for _,car in ipairs(RaceRuntime.cars) do
            if car.id==match.host then hostName=car.name end
            lines[#lines+1]=car.slot..". "..car.name..(car.isAI and "  AI" or "  玩家")
        end
        lobbyInfo.text="飞车 3D · "..RaceMaps.name(settings.map)..(itemMode and "道具" or "竞速").."\n\n圈数 "..settings.laps.."   难度 "..({"新手","熟练","车神"})[settings.diff+1]..
            "\n房主 "..hostName.." · 房主选择比赛设置\n\n"..table.concat(lines,"\n").."\n\n方向键驾驶 · Shift 漂移 · 空格"..(itemMode and "道具 · Alt 换位" or "氮气").." · ↑/W 小喷"
    end
    raceInfo.text=""
    countdownLabel.text=""
    if entry and (phase=="race" or phase=="countdown") then
        local best=math.huge
        for _,t in ipairs(entry.lapTimes) do best=math.min(best,t) end
        raceInfo.text=string.format("第 %d / 6 名     第 %d / %d 圈     %s\n最佳单圈 %s",entry.rank,
            math.min(settings.laps,math.max(1,entry.lapsDone+1)),settings.laps,time(match.time),time(best<math.huge and best or 0))
        if phase=="countdown" then countdownLabel.text=tostring(math.max(1,math.ceil(match.countdown)))
        elseif match.time<0.8 then countdownLabel.text="GO!"
        elseif entry.finished then countdownLabel.text="完成比赛！"
        elseif match.firstFinish>=0 then countdownLabel.text="已有车手冲线 · 剩余 "..math.max(0,math.ceil(10-match.time+match.firstFinish)).." 秒" end
    end
    if phase=="pause" then
        modalInfo.text="比赛已暂停\n\n计时 "..time(match.time).."\n\n由房主继续比赛、重开或返回大厅"
    elseif phase=="result" then
        local rows={}
        local sorted={}
        for _,car in ipairs(RaceRuntime.cars) do sorted[car.rank]=car end
        for _,car in ipairs(sorted) do
            local best=math.huge
            for _,t in ipairs(car.lapTimes) do best=math.min(best,t) end
            rows[#rows+1]=string.format("%d  %s%s    %s    最佳 %s",car.rank,car.name,
                car.id==RaceRuntime.localId and "（我）" or "",car.finished and time(car.finishTime) or "未完成",time(best<math.huge and best or 0))
        end
        local stats=entry and entry.stats
        modalInfo.text="比赛结果 · "..RaceMaps.name(settings.map).."\n\n"..table.concat(rows,"\n")..(stats and
            string.format("\n\n漂移 %d · 小喷 %d · 完美 %d · 双喷 %d\n氮气 %d · 碰撞 %d · 最高时速 %d",stats.drift,stats.small,stats.perfect,stats.double,stats.nitro,stats.crash,math.floor(stats.top)) or "")
    end
end
