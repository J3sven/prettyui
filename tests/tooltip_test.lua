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
        subscriptions = {},
    }
    function result:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function result:SetPos(x, y)
        self.x = x
        self.y = y
    end
    function result:Subscribe(hook, id, callback)
        self.subscriptions[tostring(hook) .. ":" .. id] = callback
    end
    function result:Unsubscribe(hook, id)
        self.subscriptions[tostring(hook) .. ":" .. id] = nil
    end
    function result:MoveToFront()
        self.frontCount = (self.frontCount or 0) + 1
    end
    function result:Destroy()
        self.destroyed = true
    end
    if parent then table.insert(parent.children, result) end
    return result
end

local parent = component()
parent.width = 600
parent.height = 400

ui = {
    Hook = { ONMOUSEOVER = 1, ONMOUSELEAVE = 2 },
    Layer = { new = function(owner) return component(owner) end },
    Sprite = { new = function(owner) return component(owner) end },
    Text = { new = function(owner) return component(owner) end },
}

id = {
    Font = { MUSEO_SANS_15PT_REGULAR = 1 },
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
    CONTENT_FRAME = {
        centre = 1,
        top = 2,
        bottom = 3,
        right = 4,
        left = 5,
        topRight = 6,
        topLeft = 7,
        bottomRight = 8,
        bottomLeft = 9,
    },
}

local Tooltip = require("src/tooltip")
local target = component()
target.x = 20
target.y = 30
target.width = 40
target.height = 20
target.clickthrough = true

local tooltip = Tooltip.attach(target, parent, "Hi")
expect(tooltip.width, 26, "initial text is measured")
expect(tooltip.root.hidden, true, "tooltip starts hidden")

expect(tooltip:SetText("A longer tooltip"), true, "tooltip text can be updated")
expect(tooltip.label.content, "A longer tooltip", "the label content is updated")
expect(tooltip.width, 96, "updated text is remeasured")
expect(tooltip.root.width, 96, "the tooltip root is resized")
expect(tooltip.root.hidden, true, "updating a hidden tooltip keeps it hidden")

tooltip:Show()
expect(tooltip.root.x, 66, "tooltip uses the target placement")
local frontCount = tooltip.root.frontCount
expect(tooltip:SetText("Small"), true, "a visible tooltip can be updated")
expect(tooltip.width, 41, "a visible tooltip is remeasured")
expect(tooltip.root.x, 66, "a visible tooltip is repositioned")
expect(tooltip.root.frontCount, frontCount + 1, "a visible tooltip remains in front")

tooltip:Destroy()
expect(tooltip:SetText("Ignored"), false, "destroyed tooltips reject updates")

local owner = {}
local boundTarget = component()
boundTarget.width = 20
boundTarget.height = 20
boundTarget.clickthrough = true
Tooltip.bind(owner, boundTarget, parent, nil)
expect(owner.tooltip, nil, "bindings can start without a tooltip")
expect(Tooltip.set(owner, "Added later"), true, "bindings add tooltips dynamically")
local firstAttachment = owner.tooltip
expect(firstAttachment.label.content, "Added later", "a dynamically added tooltip has the requested text")
expect(Tooltip.set(owner, "Updated in place"), true, "plain text updates an existing attachment")
expect(owner.tooltip, firstAttachment, "plain text preserves the attachment")
expect(firstAttachment.label.content, "Updated in place", "plain text updates its label")
expect(Tooltip.set(owner, { text = "Replacement", width = 140 }), true, "options replace an attachment")
expect(owner.tooltip == firstAttachment, false, "options create a fresh attachment")
expect(firstAttachment.root, nil, "the replaced attachment is destroyed")
expect(owner.tooltip.width, 140, "replacement options take effect")
expect(Tooltip.set(owner, nil), true, "nil removes a bound tooltip")
expect(owner.tooltip, nil, "the removed attachment is cleared")
expect(boundTarget.clickthrough, true, "removing restores the original target interaction")
expect(Tooltip.set(owner, "Added again"), true, "a removed tooltip can be added again")
expect(Tooltip.unbind(owner), true, "bindings can be destroyed")
expect(Tooltip.set(owner, "Ignored"), false, "destroyed bindings reject updates")

print("tooltip_test: ok")
