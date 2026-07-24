local Cursor = {}

function Cursor.id(value)
    if type(value) == "number" then return value end
    return value and value.id or nil
end

function Cursor.apply(component, value, enabled)
    component.opConfig:ClearOpCursors()
    if not enabled then
        component.cursorConfig.mouseOverCursor = -1
        return
    end

    local resolvedID = Cursor.id(value)
    component.cursorConfig.mouseOverCursor = resolvedID or -1
    if resolvedID then component.opConfig:SetOpCursor(0, resolvedID) end
end

return Cursor
