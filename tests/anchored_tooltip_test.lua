local Interfaces = require("tests/interface_fixture")

local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function component(parent)
    local result = {
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        hidden = false,
        children = {},
    }
    function result:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function result:SetPos(x, y)
        self.x = x
        self.y = y
    end
    function result:MoveToBack()
        self.movedToBack = true
    end
    function result:Destroy()
        self.destroyed = true
    end
    if parent then table.insert(parent.children, result) end
    return Interfaces.component(result, parent)
end

local logicHandlers = {}
Event = {
    Logic = {
        Subscribe = function(eventID, callback) logicHandlers[eventID] = callback end,
        Unsubscribe = function(eventID) logicHandlers[eventID] = nil end,
    },
}

ui = {
    Layer = { new = function(owner) return component(owner) end },
    Sprite = { new = function(owner) return component(owner) end },
    Rectangle = { new = function(owner) return component(owner) end },
    Text = { new = function(owner) return component(owner) end },
    AlignMode = { CENTRE = 1 },
}

id = {
    Font = {
        MUSEO_SANS_13PT_BOLD = 1,
    },
}

local font = {
    baseline = 16,
    GetStringWidth = function(_, text) return #text * 5 end,
    GetStringHeightAndLineCount = function() return 18 end,
}
config = {
    Font = { MUSEO_SANS_15PT_REGULAR = font },
}

package.loaded["src/core/sprites"] = {
    ANCHORED_TOOLTIP = {
        border = {
            topLeft = 1,
            top = 2,
            side = 3,
            bottomLeft = 4,
        },
    },
}

local AnchoredTooltip = require("src/anchored_tooltip")
local parent = component()
parent.width = 600
parent.height = 400

local tooltip = AnchoredTooltip.new(parent, {
    anchor = function() return { x = 200, y = 200 } end,
    text = "Hi",
})
expect(tooltip.width, 34, "initial text is measured")
expect(tooltip.root.hidden, false, "anchored tooltip starts visible")

expect(tooltip:SetText("A longer tooltip"), true, "anchored tooltip text can be updated")
expect(tooltip.label.content, "A longer tooltip", "the anchored label is updated")
expect(tooltip.width, 104, "anchored text is remeasured")
expect(tooltip.root.width, 104, "the anchored root is resized")
expect(tooltip.topRight.x, 94, "the top-right border follows the new width")
expect(tooltip.bottomLeft.y, tooltip.height - 10, "the bottom border follows the new height")
expect(tooltip.root.hidden, false, "the updated anchored tooltip stays visible")

tooltip:Destroy()
expect(tooltip:SetText("Ignored"), false, "destroyed anchored tooltips reject updates")

local custom = AnchoredTooltip.new(parent, {
    anchor = function() return { x = 200, y = 200 } end,
    content = function() end,
})
expect(custom:SetText("Unsupported"), false, "custom-content tooltips reject text updates")
custom:Destroy()

print("anchored_tooltip_test: ok")
