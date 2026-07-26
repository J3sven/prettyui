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
        hidden = false,
        subscriptions = {},
    }
    function result:SetPos(x, y)
        self.x, self.y = x, y
    end
    function result:SetSize(width, height, widthAnchor, heightAnchor)
        self.width = width + ((parent and parent.width or 0) * (widthAnchor or 0))
        self.height = height + ((parent and parent.height or 0) * (heightAnchor or 0))
    end
    function result:SetScrollSize(width, height)
        self.scrollWidth, self.scrollHeight = width, height
    end
    function result:SetScrollPos(x, y)
        self.scrollX, self.scrollY = x, y
    end
    function result:Subscribe(hook, idOrCallback, callback)
        self.subscriptions[hook] = callback or idOrCallback
    end
    function result:MoveToFront() end
    function result:Destroy() self.destroyed = true end
    if parent then
        parent.children = parent.children or {}
        table.insert(parent.children, result)
    end
    return result
end

local function factory(kind)
    return { new = function(parent) return component(parent, kind) end }
end

ui = {
    Layer = factory("layer"),
    Rectangle = factory("rectangle"),
    Sprite = factory("sprite"),
    Text = factory("text"),
    Hook = {
        ONCLICK = 1,
        ONHOLD = 2,
        ONRELEASE = 3,
        ONSCROLLWHEEL = 4,
        ONMOUSEOVER = 5,
        ONMOUSELEAVE = 6,
    },
    AlignMode = { CENTRE = 1 },
    SelectionChangeEvent = {
        SELECTED = 1,
        DESELECTED = 2,
        ERROR_MAX_SELECTED = 3,
    },
}

id = { Font = { MUSEO_SANS_15PT_REGULAR = 1 } }
config = { Cursor = { CURSOR_TICK = 1 } }

package.loaded["src/core/control_palette"] = {
    TEXT = 1,
    DISABLED_TEXT = 2,
    HOVER = 3,
    SELECTED = 4,
}
package.loaded["src/core/cursor"] = { apply = function() end }
package.loaded["src/core/mouse"] = { GetPosition = function() return nil end }
package.loaded["src/core/sprites"] = {
    SCROLL_ARROW_UP = 1,
    SCROLL_ARROW_DOWN = 2,
    SCROLL_TRACK_TOP = 3,
    SCROLL_TRACK_CENTRE = 4,
    SCROLL_TRACK_BOTTOM = 5,
    SCROLL_THUMB_TOP = 6,
    SCROLL_THUMB_CENTRE = 7,
    SCROLL_THUMB_BOTTOM = 8,
}
package.loaded["src/tooltip"] = { attach = function() return nil end }

local List = require("src/list")
local parent = component(nil, "parent")
parent.width = 400
parent.height = 300

local list = List.new(parent, {
    width = 240,
    height = 96,
    entries = {
        { label = "Selected", id = 1, selected = true },
        { label = "Enabled", id = 2 },
        { label = "Unavailable", id = 3, disabled = true },
        { label = "Fourth", id = 4 },
        { label = "Fifth", id = 5 },
        { label = "Sixth", id = 6 },
    },
})

local wheel = ui.Hook.ONSCROLLWHEEL
list.rows[1].background.subscriptions[wheel](list.rows[1].background, 1)
expect(list.scrollY, 24, "selected row backgrounds forward wheel scrolling")

list.rows[3].label.subscriptions[wheel](list.rows[3].label, 1)
expect(list.scrollY, 48, "disabled row labels forward wheel scrolling")

list.viewport.subscriptions[wheel](list.viewport, 1)
expect(list.scrollY, 50, "the exposed viewport forwards wheel scrolling to the limit")

print("list_test: ok")
