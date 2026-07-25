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

local eventPosition = InterfaceMouse.GetPosition({ x = 20, y = 30 }, 5, 7)
expect(eventPosition.x, 25, "hook coordinates include the component x position")
expect(eventPosition.y, 37, "hook coordinates include the component y position")

local capture = { x = 100, y = 80 }
InterfaceMouse.BeginCapture(capture)
capture.x, capture.y = 0, 0
eventPosition = InterfaceMouse.GetPosition(capture, 8, 9)
expect(eventPosition.x, 108, "capture preserves the original component x position")
expect(eventPosition.y, 89, "capture preserves the original component y position")
InterfaceMouse.EndCapture(capture)

rawPosition = { x = 250, y = 125 }
capture = { x = 100, y = 50 }
InterfaceMouse.BeginScreenCapture(capture, 100, 50)
capture.x, capture.y = 0, 0
rawPosition = { x = 275, y = 150 }
eventPosition = InterfaceMouse.GetPosition(capture, 0, 0)
expect(eventPosition.x, 220, "screen capture accounts for OS scaling on x")
expect(eventPosition.y, 120, "screen capture accounts for OS scaling on y")
InterfaceMouse.EndCapture(capture)

print("mouse_test: ok")
