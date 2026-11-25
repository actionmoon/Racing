---@var action:string
---@var value:number
---@end
local button,image
function Start()
    if DouyinApplication.isServer then return end
    button=self.gameObject:GetComponent(typeof(UnityEngine.UI.Button))
    image=self.gameObject:GetComponent(typeof(UnityEngine.UI.Image))
end
function Update()
    local match=RaceRuntime.match
    if not match or not button then return end
    local personal=action=="skin" or action=="quality" or action=="music" or action=="song" or action=="camera" or action=="settings" or action=="closeSettings"
    button.interactable=personal or match.host==RaceRuntime.localId
    local selected=(action=="laps" and match.settings.laps==value) or
        (action=="mode" and match.settings.mode==(value==1 and "item" or "race")) or
        (action=="diff" and match.settings.diff==value) or
        (action=="skin" and RaceRuntime.localEntry and RaceRuntime.localEntry.skin==value)
        or (action=="map" and match.settings.map==RaceMaps.ids[value+1])
        or (action=="quality" and RaceRuntime.quality==value)
        or (action=="camera" and RaceRuntime.cameraMode==value+1)
    image.color=selected and UnityEngine.Color(0.08,0.65,0.75,1) or UnityEngine.Color(0.05,0.32,0.48,1)
end
function Click()
    if not DouyinApplication.isServer and RaceRuntime.control then
        print("[RacingClone][Input] MENU_CLICK action="..action)
        if RaceRuntime.audio then RaceRuntime.audio.Play("click") end
        if action=="quality" or action=="music" or action=="song" or action=="camera" or action=="settings" or action=="closeSettings" then
            if RaceRuntime.setting then RaceRuntime.setting(action,value) end
        else RaceRuntime.control(action,value) end
    end
end
