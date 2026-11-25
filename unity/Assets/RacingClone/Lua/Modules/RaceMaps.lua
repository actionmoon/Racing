local Maps = {}
Maps.ids = {"city", "aegean", "egypt", "snow"}
Maps.names = {"11城", "情迷爱琴海", "法老金字塔", "雪地大冒险"}
Maps.data = {
    city=require "TrackData",
    aegean=require "TrackDataAegean",
    egypt=require "TrackDataEgypt",
    snow=require "TrackDataSnow"
}
function Maps.get(index)
    if type(index)~="number" or index%1~=0 then return nil end
    return Maps.data[Maps.ids[index+1]]
end
function Maps.name(id)
    for i,v in ipairs(Maps.ids) do if id==v then return Maps.names[i] end end
    return ""
end
return Maps
