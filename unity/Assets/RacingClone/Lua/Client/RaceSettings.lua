---@var post:GameObject
---@var panel:GameObject
---@var settingInfo:UnityEngine.UI.Text
---@var quality0:UnityEngine.ScriptableObject
---@var quality1:UnityEngine.ScriptableObject
---@var quality2:UnityEngine.ScriptableObject
---@end
local prefs=UnityEngine.PlayerPrefs
local songs={"极速都市","海风假日","沙漠疾驰","雪境飞跃"}
local function save()
    prefs.SetInt("RacingClone.quality",RaceRuntime.quality)
    prefs.SetInt("RacingClone.camera",RaceRuntime.cameraMode)
    prefs.SetInt("RacingClone.music",RaceRuntime.music and 1 or 0)
    prefs.SetInt("RacingClone.song",RaceRuntime.song)
    prefs.Save()
end
function Change(action,value)
    if action=="settings" then panel:SetActive(not panel.activeSelf); return end
    if action=="closeSettings" then panel:SetActive(false); return end
    if action=="quality" then
        RaceRuntime.quality=math.max(0,math.min(2,value))
        UnityEngine.QualitySettings.SetQualityLevel(RaceRuntime.quality,true)
        UnityEngine.QualitySettings.renderPipeline=({quality0,quality1,quality2})[RaceRuntime.quality+1]
        post:SetActive(RaceRuntime.quality==2)
    elseif action=="camera" then RaceRuntime.cameraMode=value+1
    elseif action=="music" then RaceRuntime.music=not RaceRuntime.music
    elseif action=="song" then RaceRuntime.song=(RaceRuntime.song+value)%4
    elseif action=="mapSong" then RaceRuntime.song=value
    else return end
    save()
    print(string.format("[RacingClone][Client] SETTING action=%s quality=%d camera=%d music=%s song=%d post=%s",
        action,RaceRuntime.quality,RaceRuntime.cameraMode,tostring(RaceRuntime.music),RaceRuntime.song,tostring(post.activeSelf)))
end
function Start()
    if DouyinApplication.isServer then panel:SetActive(false); post:SetActive(false); return end
    RaceRuntime.cameraMode=math.max(1,math.min(3,prefs.GetInt("RacingClone.camera",1)))
    RaceRuntime.music=prefs.GetInt("RacingClone.music",1)==1
    RaceRuntime.song=prefs.GetInt("RacingClone.song",0)%4
    RaceRuntime.setting=Change
    Change("quality",prefs.GetInt("RacingClone.quality",1))
end
function Update()
    if DouyinApplication.isServer then return end
    settingInfo.text=string.format("画质：%s    镜头：%s\n音乐：%s · %s\nM 开关音乐 · PgUp/PgDn 切歌 · C 镜头",
        ({"流畅","均衡","精致"})[RaceRuntime.quality+1],
        ({"追逐","远景","近景"})[RaceRuntime.cameraMode],
        RaceRuntime.music and "开" or "关",songs[RaceRuntime.song+1])
end
function OnDestroy()
    RaceRuntime.setting=nil
end
