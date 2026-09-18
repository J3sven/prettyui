-- Native UI doubles share a loaded interface, not a component-ID registry.
local Interfaces = {}
local loaded = {}
local components = {}

local function getInterface(_, interfaceID)
    assert(type(interfaceID) == "number", "interface lookup requires a cached numeric ID")
    return loaded[interfaceID]
end

function Interfaces.component(component, parent)
    if component.interfaceID ~= nil then return component end
    if parent ~= nil then Interfaces.component(parent) end
    local interfaceID = parent and parent.interfaceID or 1
    component.interfaceID = interfaceID
    loaded[interfaceID] = loaded[interfaceID] or {}
    components[interfaceID] = components[interfaceID] or {}
    table.insert(components[interfaceID], component)
    if ui ~= nil then
        ui.Interfaces = ui.Interfaces or {}
        ui.Interfaces.GetInterface = getInterface
    end
    return component
end

-- Reject every property access after unload, including attempts to read IDs.
function Interfaces.unload(interfaceID)
    for id, handles in pairs(components) do
        if interfaceID == nil or id == interfaceID then
            loaded[id] = nil
            components[id] = nil
            for _, component in ipairs(handles) do
                for key in pairs(component) do component[key] = nil end
                setmetatable(component, {
                    __index = function(_, key) error("read after interface unload: " .. tostring(key)) end,
                    __newindex = function(_, key) error("write after interface unload: " .. tostring(key)) end,
                })
            end
        end
    end
end

return Interfaces
