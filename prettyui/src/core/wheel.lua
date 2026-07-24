local Wheel = {}

local HOOK_ID = "prettyui_scroll_forward"

function Wheel.bind(component, options)
    local handler = options and options._onScrollWheel
    if component == nil or handler == nil then return end
    component:Subscribe(ui.Hook.ONSCROLLWHEEL, HOOK_ID, handler)
end

return Wheel
