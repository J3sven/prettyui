local Interfaces = require("tests/interface_fixture")

local function expect(actual, expected, message)
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Resolve native size anchors on access, including after an ancestor changes size.
local function component(parent)
    local value = { parent = parent, x = 0, y = 0, hidden = false, subscriptions = {},
        opConfig = { ClearOpCursors = function() end, SetOpCursor = function() end }, cursorConfig = {} }
    setmetatable(value, { __index = function(self, key)
        if key == "width" then return (self.w or 0) + (parent and parent.width or 0) * (self.wa or 0) end
        if key == "height" then return (self.h or 0) + (parent and parent.height or 0) * (self.ha or 0) end
    end })
    function value:SetPos(x, y) self.x, self.y = x, y end
    function value:SetY(y) self.y = y end
    function value:SetSize(w, h, wa, ha) self.w, self.h, self.wa, self.ha = w, h, wa, ha end
    function value:SetWidth(w, wa) self.w, self.wa = w, wa end
    function value:SetHeight(h, ha) self.h, self.ha = h, ha end
    function value:SetScrollSize(w, h) self.scrollWidth, self.scrollHeight = w, h end
    function value:SetScrollPos(x, y) self.scrollX, self.scrollY = x, y end
    function value:Subscribe(hook, name, callback) self.subscriptions[hook] = callback or name end
    function value:Unsubscribe(hook) self.subscriptions[hook] = nil end
    function value:MoveToFront() end
    function value:MoveToBack() end
    function value:Destroy() self.destroyed = true end
    return Interfaces.component(value, parent)
end

local enum = setmetatable({}, { __index = function(_, key) return key end })
ui = {
    Layer = { new = component }, Sprite = { new = component },
    Text = { new = component }, Rectangle = { new = component },
    Hook = enum, AlignMode = enum,
}
id = { Sprite = enum, Font = enum }
local font = {
    baseline = 18,
    GetStringLineCount = function() return 1 end,
    GetStringWidth = function(_, text) return #text * 7 end,
}
config = { Cursor = enum, Font = { MUSEO_SANS_15PT_REGULAR = font, CINZEL_13PT_BOLD = font } }
Keyboard = { IsAvailable = function() return false end }
Event = { Logic = { Subscribe = function() end, Unsubscribe = function() end } }

local Window = require("src/window")
local Panel = require("src/panel")
local SimpleView = require("src/simple_view")
local parent = component()
parent:SetSize(1000, 800)

local window = Window.new(parent, { title = "Resize", width = 400, height = 300, minHeight = 1 })
local section = window:AddCollapseButton("Details", { resizeParent = true })
section:AddText({ text = "Body", height = 80 })
local following = window:AddText({ text = "Following", height = 24 })
local callbackHeight
section.onToggle = function() callbackHeight = window.root.height end
section:SetExpanded(true)
local expandedHeight = window.root.height
expect(expandedHeight, window.contentHeight + 40, "window fits content plus title and borders")
expect(window.root.width, 400, "fitting preserves width")
expect(callbackHeight, expandedHeight, "onToggle observes resized parent")
expect(window.scrollbarVisible, false, "expanded content fits without overflow")
local expandedY = following.y
section.root.subscriptions[ui.Hook.ONCLICK]()
expect(window.root.height, expandedHeight - 84, "clicking closed shrinks the window")
expect(following.y, expandedY - 84, "following row reflows on close")
expect(window.scrollbarVisible, false, "closing leaves no stale overflow")
local collapsedHeight = window.root.height
for _ = 1, 3 do section:Toggle(); section:Toggle() end
expect(window.root.height, collapsedHeight, "repeated toggles do not drift")

local fixed = Window.new(parent, { width = 400, height = 300 })
local fixedSection = fixed:AddCollapseButton("Fixed")
fixedSection:AddText({ text = "Body", height = 500 })
fixedSection:Toggle()
expect(fixed.root.height, 300, "sections without opt-in keep the parent fixed")
expect(fixed.scrollbarVisible, true, "fixed parent retains scrolling")
fixedSection:Toggle()
expect(fixed.scrollbarVisible, false, "closing the last flow row clears overflow")

local limited = Window.new(parent, { width = 400, height = 140, minHeight = 140, maxHeight = 200 })
local limitedSection = limited:AddCollapseButton("Limited", { resizeParent = true })
limitedSection:AddText({ text = "Large", height = 400 })
limitedSection:Toggle()
expect(limited.root.height, 200, "maximum window height is respected")
expect(limited.scrollbarVisible, true, "content beyond maximum height remains scrollable")
limited:SetScrollPosition(1000)
limitedSection:Toggle()
expect(limited.root.height, 140, "minimum window height is respected")
expect(limited.scrollY, 0, "closing clamps stale scroll position")
limitedSection:Toggle()
expect(limited.root.height, 200, "reopening after clamping does not drift")

local conflicting = Window.new(parent, {
    width = 400, height = 300,
    minWidth = 220, maxWidth = 100,
    minHeight = 140, maxHeight = 80,
})
expect(conflicting.root.width, 220, "minimum width wins over a conflicting maximum at construction")
expect(conflicting.root.height, 140, "minimum height wins over a conflicting maximum at construction")
conflicting:SetSize(500, 400)
expect(conflicting.root.width, 220, "resizing cannot fall below the minimum width")
expect(conflicting.root.height, 140, "resizing cannot fall below the minimum height")
conflicting:Destroy()

local view = SimpleView.new(parent, { width = -100, widthAnchor = 1, height = 200 })
local first = view:AddCollapseButton("First", { resizeParent = true, expanded = true })
first:AddText({ text = "First body", height = 50 })
local second = view:AddCollapseButton("Second", { resizeParent = true, expanded = true })
second:AddText({ text = "Second body", height = 70 })
expect(view.root.height, view.contentHeight, "initially expanded content fits as it is populated")
local bothHeight = view.root.height
first:Toggle()
expect(view.root.height, bothHeight - 54, "closing one section preserves the other")
second:Toggle()
expect(view.root.height, bothHeight - 54 - 74, "closing the last section shrinks measured content")
parent:SetWidth(1100)
expect(view.root.width, 1000, "fitting preserves the parent's width anchor")

local inline = SimpleView.new(parent, { width = 500, height = 300 })
local inlineSection = inline:AddCollapseButton("Inline", { resizeParent = true, width = 100 })
inlineSection:AddText({ text = "Short", height = 30 })
inline:AddText({ text = "Tall neighbour", inline = true, height = 100, width = 100 })
inlineSection:Toggle()
local inlineHeight = inline.root.height
inlineSection:Toggle()
expect(inline.root.height, inlineHeight, "closing a shorter inline child preserves the row height")

local panel = Panel.new(parent, { width = 320, height = 200, popout = true })
local toggles = 0
local panelSection = panel:AddCollapseButton("Panel", { resizeParent = true,
    onToggle = function() toggles = toggles + 1 end })
panelSection:AddText({ text = "Panel body", height = 60 })
panelSection:Toggle()
local panelHeight = panel.height
expect(panel.dock.scroll.height, panel.dockOwner.contentHeight, "docked panel fits content")
expect(panel.overlay.scroll.height, panel.overlayOwner.contentHeight, "popout panel fits content")
expect(panelSection.dock.expanded, true, "proxy toggle opens dock section")
expect(panelSection.overlay.expanded, true, "proxy toggle opens overlay section")
expect(toggles, 1, "paired toggle notifies once")
panel:SetPoppedOut(true)
panelSection.overlay.root.subscriptions[ui.Hook.ONCLICK]()
expect(panel.height, panelHeight - 64, "clicking popout section shrinks the panel")
expect(panelSection.dock.expanded, false, "popout click synchronizes docked section")
expect(toggles, 2, "popout click notifies once")
panel:SetPoppedOut(false)
expect(panel.dock.root.height, panel.height, "docking restores the fitted height")

local tabs = window:AddTabs({ "One", "Two" }, { height = 200 })
local page = tabs:GetPage(1)
local tabSection = page:AddCollapseButton("Tab", { resizeParent = true })
tabSection:AddText({ text = "Tab body", height = 90 })
local afterTabs = window:AddText({ text = "After tabs", height = 24 })
local outerHeight = window.root.height
tabSection:Toggle()
expect(page._scroll.height, page.contentHeight, "tab container fits its page content")
local afterY = afterTabs.y
local tabHeight = tabs.root.height
tabSection:Toggle()
expect(tabs.root.height, tabHeight - 94, "closing resizes the tab container")
expect(afterTabs.y, afterY - 94, "resizing tabs reflows their following sibling")
expect(window.root.height, outerHeight, "resizing the immediate host leaves ancestors fixed")

window:Destroy()
fixed:Destroy()
limited:Destroy()
view:Destroy()
inline:Destroy()
panel:Destroy()
print("collapse_resize_test: window limits, repeated toggles, inline flow, anchors, panels and tabs passed")
