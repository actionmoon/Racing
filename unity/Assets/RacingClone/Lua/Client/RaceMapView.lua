---@var city:GameObject
---@var aegean:GameObject
---@var egypt:GameObject
---@var snow:GameObject
---@var citySky:UnityEngine.Material
---@var aegeanSky:UnityEngine.Material
---@var egyptSky:UnityEngine.Material
---@var snowSky:UnityEngine.Material
---@var sun:UnityEngine.Light
---@end
local current,maps,skies
local env=require "RaceMapEnvironment"
local function color(hex)
    local r,g,b=string.sub(hex,2,3),string.sub(hex,4,5),string.sub(hex,6,7)
    return UnityEngine.Color(tonumber(r,16)/255,tonumber(g,16)/255,tonumber(b,16)/255,1)
end
function Start()
    maps={city=city,aegean=aegean,egypt=egypt,snow=snow}
    skies={city=citySky,aegean=aegeanSky,egypt=egyptSky,snow=snowSky}
    if DouyinApplication.isServer then
        for _,map in pairs(maps) do map:SetActive(false) end
    end
end
function Update()
    if DouyinApplication.isServer or not maps or not RaceRuntime.match then return end
    local id=RaceRuntime.match.settings.map
    if id==current then return end
    local changing=current~=nil
    current=id
    for key,map in pairs(maps) do map:SetActive(key==id) end
    local config=env[id]
    UnityEngine.RenderSettings.skybox=skies[id]
    UnityEngine.RenderSettings.fog=true
    UnityEngine.RenderSettings.fogColor=color(config.fog[1])
    UnityEngine.RenderSettings.fogStartDistance=config.fog[2]
    UnityEngine.RenderSettings.fogEndDistance=config.fog[3]
    UnityEngine.RenderSettings.ambientSkyColor=color(config.hemi[1])
    UnityEngine.RenderSettings.ambientEquatorColor=UnityEngine.Color.Lerp(color(config.hemi[1]),color(config.hemi[2]),.5)
    UnityEngine.RenderSettings.ambientGroundColor=color(config.hemi[2])
    UnityEngine.RenderSettings.ambientIntensity=config.hemi[3]
    local direction=config.sky.sun
    sun.transform.rotation=UnityEngine.Quaternion.LookRotation(UnityEngine.Vector3(-direction[1],-direction[2],direction[3]))
    sun.color=color(config.sky.sunColor)
    sun.intensity=config.sky.sunI/math.pi
    if changing and RaceRuntime.setting then RaceRuntime.setting("mapSong",config.bgm) end
    print("[RacingClone][Client] MAP_VISIBLE id="..id)
end
