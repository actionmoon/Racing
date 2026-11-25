---@var matchUI:GameObject
---@var drivingUI:GameObject
---@var settingsUI:GameObject
---@end
local portrait,original=false,{}
local width,height=0,0
local UE=UnityEngine
local function rect(root,path) return root.transform:Find(path) end
local function place(root,path,x,y,w,h,ax,ay)
    local tr=rect(root,path)
    if not tr then return end
    tr.anchorMin=UE.Vector2(ax or .5,ay or .5); tr.anchorMax=tr.anchorMin
    tr.anchoredPosition=UE.Vector2(x,y)
    if w then tr.sizeDelta=UE.Vector2(w,h) end
    local label=tr:Find("Label")
    if label and w then label.sizeDelta=UE.Vector2(w,h) end
end
function Start()
    if DouyinApplication.isServer then return end
    for _,root in ipairs({matchUI,drivingUI,settingsUI}) do
        local all=root:GetComponentsInChildren(typeof(UE.RectTransform),true)
        for i=0,all.Length-1 do
            local tr=all[i]
            original[#original+1]={tr=tr,pos=tr.anchoredPosition,size=tr.sizeDelta,min=tr.anchorMin,max=tr.anchorMax}
        end
    end
end
function Update()
    if DouyinApplication.isServer or width==UE.Screen.width and height==UE.Screen.height then return end
    width,height=UE.Screen.width,UE.Screen.height
    portrait=height>width
    for _,item in ipairs(original) do
        local tr=item.tr
        tr.anchorMin=item.min; tr.anchorMax=item.max
        tr.anchoredPosition=item.pos; tr.sizeDelta=item.size
    end
    for _,root in ipairs({matchUI,drivingUI,settingsUI}) do
        local scaler=root:GetComponent(typeof(UE.UI.CanvasScaler))
        scaler.referenceResolution=portrait and UE.Vector2(720,1280) or UE.Vector2(1280,720)
        scaler.matchWidthOrHeight=width/height<(portrait and 720/1280 or 1280/720) and 0 or 1
    end
    local room=rect(matchUI,"Lobby/Room Settings"):GetComponent(typeof(UE.UI.Text))
    room.fontSize=portrait and 20 or 24
    if not portrait then place(matchUI,"Minimap",480,130,170,170) end
    if portrait then
        place(matchUI,"Lobby",0,0,690,1120)
        place(matchUI,"Lobby/Room Settings",0,355,650,340)
        local lobby=rect(matchUI,"Lobby")
        for i=0,lobby.childCount-1 do
            local child=lobby:GetChild(i)
            if child.name~="Room Settings" and child.name~="个人设置" then
                child.anchoredPosition=UE.Vector2(child.anchoredPosition.x-245,child.anchoredPosition.y-125)
            end
        end
        place(matchUI,"Lobby/个人设置",0,-480,400,55)
        place(matchUI,"Match Modal",0,0,690,1050)
        place(matchUI,"Match Modal/Modal Text",0,110,650,750)
        for i,name in ipairs({"继续比赛","重新开始","返回大厅"}) do
            place(matchUI,"Match Modal/"..name,0,-290-(i-1)*80,540,65)
        end
        place(matchUI,"Race Info",0,-35,670,70,.5,1)
        place(matchUI,"Countdown",0,0,670,90,.5,.58)
        place(matchUI,"Minimap",-105,-245,170,170,1,1)
        place(drivingUI,"Driving Status",0,-125,670,80,.5,1)
        place(drivingUI,"Gauge",0,-180,240,8,.5,1)
        place(drivingUI,"Driving Event",0,0,670,60,.5,.60)
        place(drivingUI,"Item Notice",0,0,670,60,.5,.53)
        place(drivingUI,"油门",-85,225,110,85,1,0)
        place(drivingUI,"制动",-210,225,110,85,1,0)
        place(drivingUI,"漂移",-210,125,110,85,1,0)
        place(drivingUI,"氮气",-85,125,110,85,1,0)
        place(drivingUI,"小喷",-335,125,110,85,1,0)
        place(drivingUI,"左转",80,225,110,85,0,0)
        place(drivingUI,"右转",205,225,110,85,0,0)
        place(drivingUI,"Item Slots",0,55,670,70,.5,0)
        place(drivingUI,"换位 · Alt",85,125,120,55,0,0)
        place(drivingUI,"复位",75,-220,110,50,0,1)
        place(drivingUI,"镜头",200,-220,110,50,0,1)
        place(drivingUI,"暂停 · Esc",-85,-380,140,50,1,1)
        place(drivingUI,"个人设置",-85,-440,140,50,1,1)
        place(settingsUI,"Local Settings",0,0,690,710)
    end
    print(string.format("[RacingClone][Client] LAYOUT width=%d height=%d portrait=%s",width,height,tostring(portrait)))
end
