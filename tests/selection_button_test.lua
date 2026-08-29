local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function component(parent, kind)
    local result = {
        kind = kind,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        subscriptions = {},
    }
    function result:SetPos(x, y)
        self.x, self.y = x, y
    end
    function result:SetSize(width, height, widthAnchor, heightAnchor)
        self.width = width + ((parent and parent.width or 0) * (widthAnchor or 0))
        self.height = height + ((parent and parent.height or 0) * (heightAnchor or 0))
    end
    function result:Subscribe(hook, idOrCallback, callback)
        self.subscriptions[hook] = callback or idOrCallback
    end
    function result:Destroy()
        self.destroyed = true
    end
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = result
    end
    return result
end

local function factory(kind)
    return { new = function(parent) return component(parent, kind) end }
end

ui = {
    Layer = factory("layer"),
    Sprite = factory("sprite"),
    Text = factory("text"),
    Hook = {
        ONMOUSEOVER = 1,
        ONMOUSELEAVE = 2,
        ONCLICK = 3,
    },
    AlignMode = {
        TOPLEFT = 1,
        CENTRE = 2,
    },
}

local font = {
    GetStringWidth = function(_, text)
        return #text * 10
    end,
}
id = { Font = { MUSEO_SANS_15PT_REGULAR = font } }
config = {
    Font = { MUSEO_SANS_15PT_REGULAR = font },
    Cursor = {
        CURSOR_TICK = 1,
        CURSOR_CROSS = 2,
    },
}

package.loaded["src/core/cursor"] = { apply = function() end }
package.loaded["src/core/sprites"] = {
    CHECKBOX_BUTTON = {
        empty = 1,
        emptyHovered = 2,
        selected = 3,
        selectedHovered = 4,
    },
    RADIO_BUTTON = {
        empty = 5,
        emptyHovered = 6,
        selected = 7,
        selectedHovered = 8,
    },
}
package.loaded["src/core/wheel"] = { bind = function() end }
package.loaded["src/tooltip"] = {
    getContext = function() return nil end,
    registerContext = function() return {} end,
    unregisterContext = function() end,
    bind = function() return nil end,
    set = function() return true end,
    unbind = function() end,
}

package.loaded["src/selection_button"] = nil
package.loaded["src/checkbox_button"] = nil
package.loaded["src/radio_button"] = nil
local CheckboxButton = require("src/checkbox_button")
local RadioButton = require("src/radio_button")

local choices = {
    { text = "Audio", value = "audio" },
    { text = "Animations", value = "animations" },
}

local verticalWidth, verticalHeight = CheckboxButton.getSize(choices, {})
local inlineWidth, inlineHeight = CheckboxButton.getSize(choices, { inline = true })
expect(verticalHeight, 44, "checkbox choices stack by default")
expect(inlineHeight, 22, "inline checkbox choices use one row")
expect(inlineWidth > verticalWidth, true, "inline checkbox width includes every choice")

local parent = component(nil, "parent")
parent.width = 400
parent.height = 300

local inline = CheckboxButton.new(parent, choices, {
    inline = true,
    width = 240,
})
expect(inline.root.height, 22, "inline checkbox root has one-row height")
expect(inline.items[1].row.y, 0, "first inline checkbox starts on the row")
expect(inline.items[2].row.y, 0, "second inline checkbox shares the row")
expect(inline.items[2].row.x > inline.items[1].row.x, true, "inline checkbox choices advance horizontally")

local vertical = CheckboxButton.new(parent, choices, { width = 240 })
expect(vertical.root.height, 44, "default checkbox root retains stacked height")
expect(vertical.items[1].row.x, 0, "stacked checkbox starts at the left edge")
expect(vertical.items[2].row.x, 0, "stacked checkbox choices share the left edge")
expect(vertical.items[2].row.y, 22, "stacked checkbox choices advance vertically")

local radio = RadioButton.new(parent, choices, {
    inline = true,
    width = 240,
})
expect(radio.root.height, 22, "inline radio root has one-row height")
expect(radio.items[1].row.y, 0, "first inline radio starts on the row")
expect(radio.items[2].row.y, 0, "second inline radio shares the row")
expect(radio.items[2].row.x > radio.items[1].row.x, true, "inline radio choices advance horizontally")

print("selection_button_test: ok")
