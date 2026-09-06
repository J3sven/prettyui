local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local rawMousePosition
Mouse = {
    GetPosition = function()
        return rawMousePosition
    end,
}

local function component(parent, kind)
    local result = {
        parent = parent,
        kind = kind,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        hidden = false,
        subscriptions = {},
        opConfig = {
            ClearOpCursors = function() end,
            SetOpCursor = function() end,
        },
        cursorConfig = {},
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
        self.scrollPositionUpdates = (self.scrollPositionUpdates or 0) + 1
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

local function inputField(parent)
    local result = component(parent, "input")
    result.text = {}
    result.containerSprite = {}
    function result:Setup(visibility, filterMode, maxLength)
        self.visibility = visibility
        self.filterMode = filterMode
        self.maxLength = maxLength
    end
    return result
end

ui = {
    Layer = factory("layer"),
    InputField = { new = inputField },
    Margin = {
        new = function(left, top, right, bottom)
            return { left = left, top = top, right = right, bottom = bottom }
        end,
    },
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
        ONCONTENTCHANGED = 9,
    },
    AlignMode = { TOPLEFT = 1, CENTRE = 2 },
    TextContentVisibilityMode = { VISIBLE = 1 },
    InputFieldFilterMode = { NONE = 1 },
    InputFieldKeyHandlingMode = { DEFAULT = 1 },
    InputFieldActionResult = { SUBMIT = 1, CONTENT_CHANGE = 2 },
}

id = {
    Font = {
        MUSEO_SANS_15PT_REGULAR = 1,
        CINZEL_13PT_BOLD = 2,
    },
    StyleSheet = {
        INPUT_DEFAULT = 1,
    },
}

local font = {
    baseline = 18,
    GetStringLineCount = function() return 1 end,
    GetStringWidth = function(_, text) return #text * 7 end,
}
config = {
    Cursor = { CURSOR_GOTO = 1 },
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
    DIVIDER = 9,
    TEXT_TAB = {
        inactive = { left = 10, middle = 11, right = 12 },
        active = { left = 13, middle = 14, right = 15 },
        disabled = { left = 16, middle = 17, right = 18 },
    },
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

local anchor = component(scroll.content, "anchor")
anchor:SetPos(0, 90)
scroll:ScrollToChild(anchor)
expect(scroll.scrollY, 78, "scroll-to-child leaves the default inset above a native child")
scroll:ScrollToChild({ root = anchor }, 24)
expect(scroll.scrollY, 66, "scroll-to-child accepts control wrappers and a custom inset")
anchor:SetPos(0, 175)
scroll:ScrollToChild(anchor)
expect(scroll.scrollY, 80, "scroll-to-child clamps anchors near the end of the content")
anchor:SetPos(0, 5)
scroll:ScrollToChild(anchor)
expect(scroll.scrollY, 0, "scroll-to-child clamps anchors near the start of the content")

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
local rows = {}
for index = 1, 5 do
    rows[index] = window:AddText({ text = "Row " .. index, height = 30 })
end
expect(window.scrollbarVisible, true, "flow layout overflow reveals the window bar")
local removedY = rows[2].y
rows[2]:Destroy()
expect(rows[3].y, removedY, "destroying text reclaims its flow row")
expect(#window._managedFlowEntries, 4, "destroyed text leaves the flow registry")
local replacement = window:AddText({ text = "Replacement", height = 30 })
expect(replacement.y, rows[5].y + rows[5].height + 2, "new text follows the reflowed rows")
local clippedField = window:AddTextField({ text = "Viewport clipping regression" })
expect(clippedField.root.hidden, true, "text fields below the viewport are hidden")
window:ScrollToChild(clippedField, 0)
expect(clippedField.root.hidden, false, "text fields are restored when scrolled into view")
window:SetScrollPosition(0)
expect(clippedField.root.hidden, true, "text fields are hidden again after leaving the viewport")
window:SetScrollPosition(10)
expect(window.scrollY, 10, "installed host methods keep public scroll state synchronized")
window:ScrollToChild(rows[4], 4)
expect(
    window.scrollY,
    math.min(rows[4].y - 4, window._scroll.scrollHeight - window._scroll.height),
    "installed hosts expose scroll-to-child"
)

window:SetScrollPosition(0)
local thumbDrag = window._scroll.thumbDrag
local clickX, clickY = 1, 1
rawMousePosition = {
    x = thumbDrag.x + clickX,
    y = thumbDrag.y + clickY,
}
thumbDrag.subscriptions[ui.Hook.ONCLICK](thumbDrag, clickX, clickY)
expect(thumbDrag.width, 16, "thumb capture stays local until the first hold")
local scrollPositionUpdates = window._scroll.viewport.scrollPositionUpdates
thumbDrag.subscriptions[ui.Hook.ONHOLD](thumbDrag, clickX, clickY)
expect(thumbDrag.width, parent.width, "first hold expands the thumb capture")
expect(window.scrollY, 0, "capture expansion does not rewind or advance scrolling")
expect(
    window._scroll.viewport.scrollPositionUpdates,
    scrollPositionUpdates,
    "capture expansion skips native scroll writes"
)

rawMousePosition = {
    x = rawMousePosition.x,
    y = rawMousePosition.y + 40,
}
thumbDrag.subscriptions[ui.Hook.ONHOLD](
    thumbDrag,
    rawMousePosition.x,
    rawMousePosition.y
)
expect(
    thumbDrag.width,
    parent.width,
    "window overlay synchronization preserves the expanded thumb capture"
)
local draggedScrollY = window.scrollY
expect(draggedScrollY > 0, true, "thumb hold advances the scroll position")
local dragStartHandler = thumbDrag.subscriptions[ui.Hook.ONDRAG]
if dragStartHandler then dragStartHandler(thumbDrag, clickX, clickY) end
expect(
    window.scrollY,
    draggedScrollY,
    "drag-start coordinates do not rewind an active thumb drag"
)
scrollPositionUpdates = window._scroll.viewport.scrollPositionUpdates
thumbDrag.subscriptions[ui.Hook.ONHOLD](
    thumbDrag,
    rawMousePosition.x,
    rawMousePosition.y
)
expect(
    window._scroll.viewport.scrollPositionUpdates,
    scrollPositionUpdates,
    "a stationary scrollbar drag skips duplicate native scroll writes"
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

local Panel = require("src/panel")
local panelTargets = {}
local fakePanel = {
    dock = { scroll = { ScrollToChild = function(_, child, offset)
        panelTargets.dock, panelTargets.dockOffset = child, offset
    end } },
    overlay = { scroll = { ScrollToChild = function(_, child, offset)
        panelTargets.overlay, panelTargets.overlayOffset = child, offset
    end } },
}
local pairedChild = { dock = {}, overlay = {} }
Panel.ScrollToChild(fakePanel, pairedChild, 9)
expect(panelTargets.dock, pairedChild.dock, "panels scroll their dock child")
expect(panelTargets.overlay, pairedChild.overlay, "panels scroll their popout child")
expect(panelTargets.dockOffset, 9, "panels forward the dock inset")
expect(panelTargets.overlayOffset, 9, "panels forward the popout inset")

local trackerWindow = Window.new(parent, {
    title = "Achievement Tracker",
    width = 600,
    height = 600,
})
local trackerTabs = trackerWindow:AddTabs(
    { "General", "Debug" },
    { height = -20, heightAnchor = 1.0 }
)
local generalPage = trackerTabs:GetPage(1)
expect(
    trackerTabs.root.height,
    trackerWindow.content.height - 20,
    "anchored tab height preserves its negative parent offset"
)

for index = 1, 13 do
    generalPage:AddText({
        text = index == 13 and "Add server" or "Server row " .. index,
        height = 30,
        marginBottom = 8,
    })
end
expect(
    generalPage.scrollbarVisible,
    true,
    "tab page scrolling starts when tracker rows exceed the visible page"
)
generalPage:SetScrollPosition(10000)
local addRow = generalPage._managedFlowEntries[#generalPage._managedFlowEntries].component
expect(
    addRow.y + addRow.height - generalPage.scrollY <= generalPage._scroll.height,
    true,
    "the final add row is reachable at the bottom of the scroll range"
)
trackerWindow:Destroy()

print("scroll_test: ok")
