local InterfaceMouse = {}

local DEFAULT_SCALE_PERCENT = 100
local eventOrigins = setmetatable({}, { __mode = "k" })

local function getInterfaceScale()
    local options = game and game.options
    local interfaceScale = options and options.InterfaceScale
    local percent = interfaceScale and tonumber(interfaceScale.setting) or DEFAULT_SCALE_PERCENT
    if percent <= 0 then percent = DEFAULT_SCALE_PERCENT end
    return percent / DEFAULT_SCALE_PERCENT
end

local function screenScale(raw, expectedX, expectedY)
    local candidates = {}
    if math.abs(expectedX) >= 32 then
        table.insert(candidates, raw.x / expectedX)
    end
    if math.abs(expectedY) >= 32 then
        table.insert(candidates, raw.y / expectedY)
    end
    if #candidates == 2 then
        local difference = math.abs(candidates[1] - candidates[2])
        local average = (candidates[1] + candidates[2]) / 2
        if difference <= average * 0.1 then return average end
    elseif #candidates == 1 and candidates[1] >= 0.5 and candidates[1] <= 4 then
        return candidates[1]
    end
    return getInterfaceScale()
end

-- Pointer hooks supply coordinates in interface units relative to their
-- component. Prefer those coordinates when available because raw window pixels
-- are also affected by OS display scaling. Adding the component position returns
-- coordinates in its parent's interface space.
function InterfaceMouse.GetPosition(component, x, y)
    if component ~= nil and type(x) == "number" and type(y) == "number" then
        local origin = eventOrigins[component]
        if origin and origin.screenScale then
            local raw = Mouse.GetPosition()
            if raw ~= nil then
                return {
                    x = raw.x / origin.screenScale,
                    y = raw.y / origin.screenScale,
                }
            end
        end
        return {
            x = (origin and origin.x or component.x or 0) + x,
            y = (origin and origin.y or component.y or 0) + y,
        }
    end

    local position = Mouse.GetPosition()
    if position == nil then return nil end

    local scale = getInterfaceScale()
    return {
        x = position.x / scale,
        y = position.y / scale,
    }
end

function InterfaceMouse.BeginScreenCapture(component, x, y)
    if component == nil then return end
    local originX = component.x or 0
    local originY = component.y or 0
    local raw = Mouse.GetPosition()
    eventOrigins[component] = {
        x = originX,
        y = originY,
        screenScale = raw and screenScale(raw, originX + x, originY + y) or nil,
    }
end

function InterfaceMouse.BeginCapture(component)
    if component == nil then return end
    eventOrigins[component] = {
        x = component.x or 0,
        y = component.y or 0,
    }
end

function InterfaceMouse.EndCapture(component)
    if component ~= nil then eventOrigins[component] = nil end
end

return InterfaceMouse
