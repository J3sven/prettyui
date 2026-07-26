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
    function result:SetPos(x, y, xAnchor, yAnchor)
        self.x = x + ((parent and parent.width or 0) * (xAnchor or 0))
        self.y = y + ((parent and parent.height or 0) * (yAnchor or 0))
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
    function result:Subscribe(hook, callback)
        self.subscriptions[hook] = callback
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
    Sprite = factory("sprite"),
    Text = factory("text"),
    Hook = {
        ONCLICK = 1,
        ONHOLD = 2,
        ONDRAG = 3,
        ONRELEASE = 4,
        ONDRAGCOMPLETE = 5,
        ONSCROLLWHEEL = 6,
        ONMOUSEOVER = 7,
        ONMOUSELEAVE = 8,
    },
    AlignMode = { TOPLEFT = 1, CENTRE = 2 },
}

id = {
    Font = {
        MUSEO_SANS_15PT_REGULAR = 1,
        CINZEL_13PT_BOLD = 2,
    },
}

local font = {
    baseline = 18,
    GetStringLineCount = function() return 1 end,
    GetStringWidth = function(_, text) return #text * 7 end,
}
config = {
    Font = {
        MUSEO_SANS_15PT_REGULAR = font,
        CINZEL_13PT_BOLD = font,
    },
}

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

local Scroll = require("src/core/scroll")
local parent = component(nil, "parent")
parent.width = 640
parent.height = 480

local forwarded = 0
local scroll = Scroll.new(parent, {
    width = 300,
    height = 100,
    _onScrollWheel = function()
        forwarded = forwarded + 1
        return false
    end,
})

expect(scroll.scrollable, true, "scrolling defaults to enabled")
expect(scroll.scrollbarVisible, false, "bar starts hidden without overflow")
expect(scroll.contentWidth, 300, "hidden bar does not reserve width")

scroll:SetContentHeight(180)
expect(scroll.scrollbarVisible, true, "bar appears when content overflows")
expect(scroll.contentWidth, 282, "visible bar reserves its width and gap")
expect(scroll.track.hidden, false, "track is visible during overflow")

local handled = scroll.content.subscriptions[ui.Hook.ONSCROLLWHEEL](scroll.content, 1)
expect(handled, false, "wheel input is consumed while scrolling")
expect(scroll.scrollY, 32, "wheel input advances by the configured step")

scroll:SetScrollPosition(0)
scroll.content.subscriptions[ui.Hook.ONSCROLLWHEEL](scroll.content, -1)
expect(forwarded, 1, "wheel input forwards to a parent at the scroll boundary")

scroll:SetScrollable(false)
expect(scroll.scrollbarVisible, false, "disabled scrolling hides the bar")
expect(scroll.scrollY, 0, "disabled scrolling resets the viewport")
expect(scroll.contentWidth, 300, "disabled scrolling restores content width")

scroll:SetScrollable(true)
expect(scroll.scrollbarVisible, true, "re-enabling restores overflow behavior")
scroll:SetContentHeight(100)
expect(scroll.scrollbarVisible, false, "bar hides again when overflow is removed")
scroll:SetContentHeight(0)
scroll:SetSize(300, 50)
expect(scroll.scrollbarVisible, false, "resizing an empty view does not create false overflow")

scroll:Destroy()
expect(scroll.root, nil, "destroy releases the scroll surface")

local SimpleView = require("src/simple_view")
local simpleView = SimpleView.new(parent, { width = 120, height = 80 })
expect(simpleView.scrollbarVisible, false, "simple views start without a scrollbar")
simpleView:SetContentHeight(120)
expect(simpleView.scrollbarVisible, true, "simple views expose shared overflow behavior")
simpleView:Destroy()

local messages = {}
log = function(message) table.insert(messages, message) end
local Scrollbar = require("src/scrollbar")
local legacyA = Scrollbar.new(parent, { width = 120, height = 80 })
local legacyB = Scrollbar.new(parent, { width = 120, height = 80 })
expect(#messages, 1, "legacy scrollbar logs its deprecation once")
expect(
    messages[1]:find("removed in v1.0.0", 1, true) ~= nil,
    true,
    "deprecation identifies the removal version"
)
legacyA:Destroy()
legacyB:Destroy()

local Window = require("src/window")
local window = Window.new(parent, { width = 300, height = 150 })
expect(window.scrollable, true, "window content defaults to scrollable")
expect(window.scrollbarVisible, false, "window bar starts hidden")
for index = 1, 5 do
    window:AddText({ text = "Row " .. index, height = 30 })
end
expect(window.scrollbarVisible, true, "flow layout overflow reveals the window bar")
window:SetScrollPosition(10)
expect(window.scrollY, 10, "installed host methods keep public scroll state synchronized")

local thumbDrag = window._scroll.thumbDrag
thumbDrag.subscriptions[ui.Hook.ONCLICK](thumbDrag, 1, 1)
expect(thumbDrag.width, parent.width, "thumb capture expands across its overlay parent")
thumbDrag.subscriptions[ui.Hook.ONHOLD](thumbDrag, 1, 40)
expect(
    thumbDrag.width,
    parent.width,
    "window overlay synchronization preserves the expanded thumb capture"
)
thumbDrag.subscriptions[ui.Hook.ONRELEASE]()
expect(thumbDrag.width, 16, "thumb capture returns to the visual thumb after release")

local fixedWindow = Window.new(parent, {
    width = 300,
    height = 150,
    scrollable = false,
})
for index = 1, 5 do
    fixedWindow:AddText({ text = "Row " .. index, height = 30 })
end
expect(fixedWindow.scrollbarVisible, false, "scrollable=false keeps a wrapper unscrolled")
window:Destroy()
fixedWindow:Destroy()

print("scroll_test: ok")
