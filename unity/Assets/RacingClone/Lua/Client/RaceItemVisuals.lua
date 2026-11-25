---@var root:GameObject
---@end
local boxes,shields,magnets,bananaTemplate,missileTemplate
local bananas,missiles={},{}
local positions
local mapId
function Start()
    if DouyinApplication.isServer then root:SetActive(false); return end
    boxes=root.transform:Find("Boxes")
    shields=root.transform:Find("Shields")
    magnets=root.transform:Find("Magnets")
    bananaTemplate=root.transform:Find("Banana Template").gameObject
    missileTemplate=root.transform:Find("Missile Template").gameObject
    positions=require("RaceItems").new(RaceTrackMath.new(RaceTrackData)).boxes
end
local function render(objects,cache,template,rotating)
    local live={}
    for _,object in ipairs(objects) do
        live[object.id]=true
        local go=cache[object.id]
        if not go then
            go=UnityEngine.Object.Instantiate(template,root.transform)
            cache[object.id]=go
            go:SetActive(true)
        end
        go.transform.position=UnityEngine.Vector3(object.x,object.y,-object.z)
        if rotating then go.transform.rotation=UnityEngine.Quaternion.Euler(0,object.age*180/math.pi,0)
        else
            go.transform.rotation=UnityEngine.Quaternion.LookRotation(UnityEngine.Vector3(object.dx,object.dy,-object.dz))
        end
    end
    for id,go in pairs(cache) do
        if not live[id] then UnityEngine.Object.Destroy(go); cache[id]=nil end
    end
end
function LateUpdate()
    if DouyinApplication.isServer or not boxes or not RaceRuntime.match then return end
    local match,state=RaceRuntime.match,RaceRuntime.items
    if mapId~=match.settings.map then
        mapId=match.settings.map
        positions=require("RaceItems").new(RaceRuntime.track).boxes
    end
    local active=match.settings.mode=="item" and match.phase~="menu"
    root:SetActive(active)
    if not state then return end
    local t=match.time
    for i,p in ipairs(positions) do
        local box=boxes:GetChild(i-1)
        box.gameObject:SetActive(active and state.boxes[i]<=0)
        box.position=UnityEngine.Vector3(p.x,p.y+math.sin(t*2+p.x)*0.2,-p.z)
        box.rotation=UnityEngine.Quaternion.Euler(math.sin(t*1.3)*.25*180/math.pi,t*1.6*180/math.pi,0)
    end
    render(state.bananas,bananas,bananaTemplate,true)
    render(state.missiles,missiles,missileTemplate,false)
    for _,entry in ipairs(RaceRuntime.cars) do
        local v=entry.state
        local shield=shields:GetChild(entry.slot-1)
        shield.gameObject:SetActive(active and v.shield>0)
        shield.position=UnityEngine.Vector3(v.x,v.y+1,-v.z)
        local magnet=magnets:GetChild(entry.slot-1)
        local target=RaceRuntime.cars[entry.magnetTarget]
        magnet.gameObject:SetActive(active and v.magnet>0 and target~=nil)
        if target then
            local line=magnet:GetComponent(typeof(UnityEngine.LineRenderer))
            line:SetPosition(0,UnityEngine.Vector3(v.x,v.y+1,-v.z))
            line:SetPosition(1,UnityEngine.Vector3(target.state.x,target.state.y+1,-target.state.z))
        end
    end
end
function OnDestroy()
    for _,go in pairs(bananas) do UnityEngine.Object.Destroy(go) end
    for _,go in pairs(missiles) do UnityEngine.Object.Destroy(go) end
    bananas,missiles={},{}
end
