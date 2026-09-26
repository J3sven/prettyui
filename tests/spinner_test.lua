local Interfaces = require("tests/interface_fixture")

local function expect(actual, expected, message)
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function component(parent)
    local value = {}
    function value:SetPos() end
    function value:SetSize() end
    function value:Destroy() self.destroyed = true end
    return Interfaces.component(value, parent)
end

ui = { Sprite = { new = component }, Layer = { new = component } }
id = { Sprite = setmetatable({}, { __index = function(_, name) return name end }) }
local subscribers = {}
Event = { Logic = {
    Subscribe = function(name, callback) subscribers[name] = callback end,
    Unsubscribe = function(name) subscribers[name] = nil end,
} }
package.loaded["src/tooltip"] = { bind = function() end, unbind = function() end }
package.loaded["src/core/wheel"] = { bind = function() end }

local function advance(updates)
    for _ = 1, updates do
        for _, callback in pairs(subscribers) do callback() end
    end
end

local Spinner = require("src/spinner")
local BigSpinner = require("src/big_spinner")
local parent = component()
local spinner = Spinner.new(parent, { logicUpdatesPerFrame = 2 })
local function frame(index)
    return "RS3_LOGIN_THROBBER_LARGE_" .. tostring(index)
end

-- Exercise two complete cycles, including the old large-to-small transition.
for index = 0, 15 do
    expect(spinner.root.spriteID, frame(index % 8), "animation stays within one sprite family")
    advance(1)
    expect(spinner.root.spriteID, frame(index % 8), "frame remains until its interval completes")
    advance(1)
end
expect(spinner.root.spriteID, frame(0), "eight frames wrap back to the first sprite")

advance(1)
spinner:SetLogicUpdatesPerFrame(3)
advance(2)
expect(spinner.root.spriteID, frame(0), "changing speed starts a fresh frame interval")
advance(1)
expect(spinner.root.spriteID, frame(1), "new speed controls frame progression")
spinner:Stop()
advance(10)
expect(spinner.root.spriteID, frame(1), "paused spinner does not advance")
spinner:Start()
spinner:Start()
advance(3)
expect(spinner.root.spriteID, frame(2), "resuming advances once per interval")
advance(2)
spinner:Reset()
advance(1)
expect(spinner.root.spriteID, frame(0), "reset restarts both the animation and its interval")
advance(2)
expect(spinner.root.spriteID, frame(1), "reset animation continues at the configured speed")
spinner:SetFrame(9)
expect(spinner.root.spriteID, frame(0), "manual frames wrap at eight")
spinner:SetFrame(0)
expect(spinner.root.spriteID, frame(7), "manual frames wrap backwards")

local big = BigSpinner.new(parent, { rotation = 350, degreesPerLogicUpdate = 15, autoPlay = false })
advance(1)
expect(big.rotating.rotationDegrees, 350, "paused large spinner holds its rotation")
big:Start()
advance(1)
expect(big.rotating.rotationDegrees, 5, "rotation advances per logic update and wraps")
big:SetDegreesPerLogicUpdate(-10)
advance(1)
expect(big.rotating.rotationDegrees, 355, "rotation speed can reverse direction")
big:Stop()
advance(1)
expect(big.rotating.rotationDegrees, 355, "stopped large spinner holds its rotation")

local root = spinner.root
spinner:Destroy()
big:Destroy()
expect(root.destroyed, true, "destroy removes the spinner surface")
expect(next(subscribers), nil, "destroy removes animation subscriptions")

print("spinner_test: frame family, logic-update cadence, wrapping, playback and rotation passed")
