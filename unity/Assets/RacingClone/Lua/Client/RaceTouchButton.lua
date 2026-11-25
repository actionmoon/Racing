---@var action:string
---@end
local function set(held)
    if not DouyinApplication.isServer and RaceRuntime.input then
        RaceRuntime.input.SetTouch(action, held)
    end
end
function OnPointerDown(_) set(true) end
function OnPointerUp(_) set(false) end
function OnPointerExit(_) set(false) end
function Press() set(true) end
function Release() set(false) end
function OnDisable() set(false) end
function OnDestroy() set(false) end
