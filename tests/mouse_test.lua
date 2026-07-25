local rawPosition

Mouse = {
    GetPosition = function()
        return rawPosition
    end,
}

game = {
    options = {
        InterfaceScale = {
            setting = 100,
        },
    },
}

local InterfaceMouse = require("src/core/mouse")

local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

rawPosition = { x = 600, y = 300 }
local position = InterfaceMouse.GetPosition()
expect(position.x, 600, "100% scale preserves x")
expect(position.y, 300, "100% scale preserves y")

game.options.InterfaceScale.setting = 150
position = InterfaceMouse.GetPosition()
expect(position.x, 400, "150% scale converts x to interface units")
expect(position.y, 200, "150% scale converts y to interface units")

game.options.InterfaceScale.setting = 300
position = InterfaceMouse.GetPosition()
expect(position.x, 200, "300% scale converts x to interface units")
expect(position.y, 100, "300% scale converts y to interface units")

rawPosition = nil
expect(InterfaceMouse.GetPosition(), nil, "unavailable mouse remains nil")

print("mouse_test: ok")
