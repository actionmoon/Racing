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
    button.interactable=action=="skin" or match.host==RaceRuntime.localId
    local selected=(action=="laps" and match.settings.laps==value) or
        (action=="diff" and match.settings.diff==value) or
        (action=="skin" and RaceRuntime.localEntry and RaceRuntime.localEntry.skin==value)
    image.color=selected and UnityEngine.Color(0.08,0.65,0.75,1) or UnityEngine.Color(0.05,0.32,0.48,1)
end
function Click()
    if not DouyinApplication.isServer and RaceRuntime.control then
        print("[RacingClone][Input] MENU_CLICK action="..action)
        RaceRuntime.control(action,value)
    end
end
