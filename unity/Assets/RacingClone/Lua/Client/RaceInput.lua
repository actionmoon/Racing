local moveVec = CS.UnityEngine.Vector2.zero
local onMoveInputStart = nil
local onMoveInputPerform = nil
local onMoveInputCancel = nil
local touch, previous, edges = {}, {}, {}
local Input, Key = UnityEngine.Input, UnityEngine.KeyCode

function Clear()
    moveVec = CS.UnityEngine.Vector2.zero
    touch, previous, edges = {}, {}, {}
end
function SetTouch(action, held)
    touch[action] = held
    print("[RacingClone][Input] TOUCH action=" .. action .. " held=" .. tostring(held))
end
function Start()
    if DouyinApplication.isServer then return end
    onMoveInputStart = function()
    end
    onMoveInputPerform = function(vec)
        moveVec = vec
    end
    onMoveInputCancel = function()
        moveVec = CS.UnityEngine.Vector2.zero
    end
    CS.DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
    CS.DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
    CS.DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
    RaceRuntime.input = {Frame = Frame, Clear = Clear, SetTouch = SetTouch}
end
function Frame()
    local active = UnityEngine.Application.isFocused
    if not active then Clear() end
    local held = {
        up = active and (Input.GetKey(Key.UpArrow) or moveVec.y > 0.1 or touch.up == true),
        down = active and (Input.GetKey(Key.DownArrow) or moveVec.y < -0.1 or touch.down == true),
        left = active and (Input.GetKey(Key.LeftArrow) or moveVec.x < -0.1 or touch.left == true),
        right = active and (Input.GetKey(Key.RightArrow) or moveVec.x > 0.1 or touch.right == true),
        shift = active and (Input.GetKey(Key.LeftShift) or Input.GetKey(Key.RightShift) or touch.shift == true),
        w = active and (Input.GetKey(Key.W) or touch.small == true),
        nitro = active and (Input.GetKey(Key.LeftControl) or Input.GetKey(Key.RightControl) or Input.GetKey(Key.Space) or touch.nitro == true),
        reset = active and (Input.GetKey(Key.R) or touch.reset == true),
        camera = active and (Input.GetKey(Key.C) or touch.camera == true),
        pause = active and Input.GetKey(Key.Escape),
        start = active and Input.GetKey(Key.Return)
    }
    for _, action in ipairs({"up","w","nitro","reset","camera","pause","start"}) do
        if held[action] and not previous[action] then edges[action .. "Pressed"] = true end
    end
    previous = held
    for k, v in pairs(edges) do held[k] = v end
    return held
end
function ConsumeEdges()
    edges = {}
end
function OnDisable() Clear() end
function OnDestroy()
    Clear()
    if onMoveInputStart ~= nil then
        CS.DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart)
    end
    if onMoveInputPerform ~= nil then
        CS.DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform)
    end
    if onMoveInputCancel ~= nil then
        CS.DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel)
    end
    RaceRuntime.input = nil
end
