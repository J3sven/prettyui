local InterfaceMouse = {}

local DEFAULT_SCALE_PERCENT = 100

local function getInterfaceScale()
    local options = game and game.options
    local interfaceScale = options and options.InterfaceScale
    local percent = interfaceScale and tonumber(interfaceScale.setting) or DEFAULT_SCALE_PERCENT
    if percent <= 0 then percent = DEFAULT_SCALE_PERCENT end
    return percent / DEFAULT_SCALE_PERCENT
end

-- Mouse.GetPosition() returns window pixels, while component positions and sizes
-- use interface units. Convert at the API boundary so every mouse-driven control
-- uses the same coordinate space.
function InterfaceMouse.GetPosition()
    local position = Mouse.GetPosition()
    if position == nil then return nil end

    local scale = getInterfaceScale()
    return {
        x = position.x / scale,
        y = position.y / scale,
    }
end

return InterfaceMouse
