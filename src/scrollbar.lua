local Sprites = require("src/core/sprites")
local BigSpinner = require("src/big_spinner")
local CheckboxButton = require("src/checkbox_button")
local ColourPicker = require("src/colour_picker")
local ComboBox = require("src/combo_box")
local CollapseButton = require("src/collapse_button")
local Divider = require("src/divider")
local FancyButton = require("src/fancy_button")
local ItemGrid = require("src/item_grid")
local ItemSlot = require("src/item_slot")
local List = require("src/list")
local Panel = require("src/panel")
local Text = require("src/text")
local Tabs = require("src/tabs")
local Tooltip = require("src/tooltip")
local Layout = require("src/core/layout")
local Spinner = require("src/spinner")
local RibbonButton = require("src/ribbon_button")
local RadioButton = require("src/radio_button")
local SimpleButton = require("src/simple_button")
local Slider = require("src/slider")
local SpriteButton = require("src/sprite_button")
local TextField = require("src/text_field")

local Scrollbar = {}
Scrollbar.__index = Scrollbar

local BAR_WIDTH = 16
local ARROW_SIZE = 16
local END_SIZE = 5
local MIN_THUMB_HEIGHT = 24

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function sprite(parent, spriteID)
    local component = ui.Sprite.new(parent)
    component.spriteID = spriteID
    component.clickthrough = false
    return component
end

local function findOwnerWindow(context)
    while context do
        if context.ownerWindow then return context.ownerWindow end
        context = context.parentContext
    end
    return nil
end

function Scrollbar.new(parent, options)
    options = options or {}

    local self = setmetatable({}, Scrollbar)
    self.width = options.width or 300
    self.height = options.height or 240
    self.contentHeight = math.max(options.contentHeight or self.height, self.height)
    self.scrollbarVisible = self.contentHeight > self.height
    self.contentWidth = self.width - (self.scrollbarVisible and BAR_WIDTH + 2 or 0)
    self.scrollStep = options.scrollStep or 32
    self.scrollY = 0
    self.trackHeight = math.max(1, self.height - ARROW_SIZE * 2)

    self.root = ui.Layer.new(parent)
    self.root.clickthrough = false
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(self.width, self.height)

    self.viewport = ui.Layer.new(self.root)
    self.viewport.clickthrough = false
    self.viewport:SetSize(self.contentWidth, 0, 0, 1.0)
    self.viewport:SetScrollSize(self.contentWidth, self.contentHeight)

    self.content = ui.Layer.new(self.viewport)
    self.content.clickthrough = false
    self.content:SetSize(self.contentWidth, self.contentHeight)
    local parentTooltipContext = Tooltip.getContext(parent)
    local tooltipParent = parentTooltipContext and parentTooltipContext.parent or parent
    self.ownerWindow = findOwnerWindow(parentTooltipContext)
    self.overlayContext = self.ownerWindow and parentTooltipContext or nil
    self.tooltipContext = Tooltip.registerContext(self.content, tooltipParent, function(target)
        local rootX = self.root.x or 0
        local rootY = self.root.y or 0
        if parentTooltipContext then rootX, rootY = parentTooltipContext.position(self.root) end
        return rootX + (target.x or 0), rootY + (target.y or 0) - self.scrollY
    end, parentTooltipContext)
    Layout.configure(self, options.layout or options.textLayout)

    self.upArrow = sprite(self.root, Sprites.SCROLL_ARROW_UP)
    self.upArrow:SetPos(-BAR_WIDTH, 0, 1.0)
    self.upArrow:SetSize(BAR_WIDTH, ARROW_SIZE)
    self.upArrow:Subscribe(ui.Hook.ONCLICK, function()
        self:ScrollBy(-self.scrollStep)
        return false
    end)

    self.downArrow = sprite(self.root, Sprites.SCROLL_ARROW_DOWN)
    self.downArrow:SetPos(-BAR_WIDTH, -ARROW_SIZE, 1.0, 1.0)
    self.downArrow:SetSize(BAR_WIDTH, ARROW_SIZE)
    self.downArrow:Subscribe(ui.Hook.ONCLICK, function()
        self:ScrollBy(self.scrollStep)
        return false
    end)

    self.track = ui.Layer.new(self.root)
    self.track.clickthrough = false
    self.track:SetPos(-BAR_WIDTH, ARROW_SIZE, 1.0)
    self.track:SetSize(BAR_WIDTH, -ARROW_SIZE * 2, 0, 1.0)

    self.trackTop = sprite(self.track, Sprites.SCROLL_TRACK_TOP)
    self.trackTop:SetSize(BAR_WIDTH, END_SIZE)
    self.trackCentre = sprite(self.track, Sprites.SCROLL_TRACK_CENTRE)
    self.trackCentre:SetPos(0, END_SIZE)
    self.trackCentre:SetSize(BAR_WIDTH, -END_SIZE * 2, 0, 1.0)
    self.trackCentre.isTiling = true
    self.trackBottom = sprite(self.track, Sprites.SCROLL_TRACK_BOTTOM)
    self.trackBottom:SetPos(0, -END_SIZE, 0, 1.0)
    self.trackBottom:SetSize(BAR_WIDTH, END_SIZE)

    self.thumb = ui.Layer.new(self.track)
    self.thumb.clickthrough = true
    self.thumbTop = sprite(self.thumb, Sprites.SCROLL_THUMB_TOP)
    self.thumbTop.clickthrough = true
    self.thumbTop:SetSize(BAR_WIDTH, END_SIZE)
    self.thumbCentre = sprite(self.thumb, Sprites.SCROLL_THUMB_CENTRE)
    self.thumbCentre.clickthrough = true
    self.thumbCentre:SetPos(0, END_SIZE)
    self.thumbCentre:SetSize(BAR_WIDTH, -END_SIZE * 2, 0, 1.0)
    self.thumbCentre.isTiling = true
    self.thumbBottom = sprite(self.thumb, Sprites.SCROLL_THUMB_BOTTOM)
    self.thumbBottom.clickthrough = true
    self.thumbBottom:SetPos(0, -END_SIZE, 0, 1.0)
    self.thumbBottom:SetSize(BAR_WIDTH, END_SIZE)

    self.thumbDrag = ui.Layer.new(self.overlayContext and tooltipParent or parent)
    self.thumbDrag.clickthrough = false
    self.thumbDrag:MoveToFront()
    if self.ownerWindow then
        self.ownerWindow:_RegisterOverlay(self.thumbDrag, function()
            return self.scrollbarVisible
        end, function()
            self:_LayoutThumbDrag()
        end)
    end

    self.thumbDrag:Subscribe(ui.Hook.ONCLICK, function()
        local mouse = Mouse.GetPosition()
        if mouse then self.dragStart = { mouseY = mouse.y, scrollY = self.scrollY } end
        self.thumbDrag:SetPos(0, 0)
        self.thumbDrag:SetSize(0, 0, 1.0, 1.0)
        self.thumbDrag:MoveToFront()
        return false
    end)
    self.thumbDrag:Subscribe(ui.Hook.ONHOLD, function() return self:_UpdateDrag() end)
    self.thumbDrag:Subscribe(ui.Hook.ONDRAG, function() return self:_UpdateDrag() end)
    self.thumbDrag:Subscribe(ui.Hook.ONRELEASE, function() return self:_StopDrag() end)
    self.thumbDrag:Subscribe(ui.Hook.ONDRAGCOMPLETE, function() return self:_StopDrag() end)

    self.track:Subscribe(ui.Hook.ONCLICK, function(_, _, clickY)
        local thumbTravel = self.trackHeight - self.thumbHeight
        local maxScroll = self.contentHeight - self.height
        if thumbTravel > 0 then
            self:SetScrollPosition((clickY - self.thumbHeight / 2) * maxScroll / thumbTravel)
        end
        return false
    end)

    local function onWheel(_, delta)
        self:ScrollBy(delta * self.scrollStep)
        return false
    end
    self._onScrollWheel = onWheel
    self.viewport:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    self.content:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    self.track:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    self.thumbDrag:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    self.upArrow:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    self.downArrow:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)

    self:_LayoutThumb()
    self.tooltip = Tooltip.attach(self.root, parent, options.tooltip)
    return self
end

function Scrollbar:_LayoutThumb()
    self.thumbHeight = clamp(
        math.floor(self.trackHeight * self.height / self.contentHeight),
        math.min(MIN_THUMB_HEIGHT, self.trackHeight),
        self.trackHeight
    )
    self.thumb:SetSize(BAR_WIDTH, self.thumbHeight)
    self:SetScrollPosition(self.scrollY)
    self.scrollbarVisible = self.contentHeight > self.height
    self.contentWidth = self.width - (self.scrollbarVisible and BAR_WIDTH + 2 or 0)
    self.viewport:SetWidth(self.contentWidth)
    self.content:SetWidth(self.contentWidth)
    self.viewport:SetScrollSize(self.contentWidth, self.contentHeight)
    self.track.hidden = not self.scrollbarVisible
    self.upArrow.hidden = not self.scrollbarVisible
    self.downArrow.hidden = not self.scrollbarVisible
    self.thumbDrag.hidden = not self.scrollbarVisible or
        (self.ownerWindow and self.ownerWindow.root and self.ownerWindow.root.hidden == true)
end

function Scrollbar:SetScrollPosition(position)
    local maxScroll = math.max(0, self.contentHeight - self.height)
    self.scrollY = clamp(math.floor(position), 0, maxScroll)
    self.viewport:SetScrollPos(0, self.scrollY)

    local thumbY = 0
    if maxScroll > 0 then
        thumbY = math.floor(self.scrollY / maxScroll * (self.trackHeight - self.thumbHeight))
    end
    self.thumb:SetPos(0, thumbY)
    if self.dragStart == nil then self:_LayoutThumbDrag() end
end

function Scrollbar:_LayoutThumbDrag()
    if self.thumbDrag == nil or self.root == nil then return end
    local rootX = self.root.x or 0
    local rootY = self.root.y or 0
    if self.overlayContext and self.overlayContext.active then
        rootX, rootY = self.overlayContext.position(self.root)
    end
    self.thumbDrag:SetPos(
        rootX + (self.track.x or 0) + (self.thumb.x or 0),
        rootY + (self.track.y or 0) + (self.thumb.y or 0)
    )
    self.thumbDrag:SetSize(BAR_WIDTH, self.thumbHeight)
end

function Scrollbar:_UpdateDrag()
    local mouse = Mouse.GetPosition()
    if self.dragStart and mouse then
        local thumbTravel = self.trackHeight - self.thumbHeight
        local maxScroll = self.contentHeight - self.height
        if thumbTravel > 0 then
            self:SetScrollPosition(
                self.dragStart.scrollY +
                (mouse.y - self.dragStart.mouseY) * maxScroll / thumbTravel
            )
        end
    end
    return false
end

function Scrollbar:_StopDrag()
    self.dragStart = nil
    self:_LayoutThumbDrag()
    return false
end

function Scrollbar:ScrollBy(delta)
    self:SetScrollPosition(self.scrollY + delta)
end

function Scrollbar:SetContentHeight(contentHeight)
    self.contentHeight = math.max(contentHeight, self.height)
    self.content:SetHeight(self.contentHeight)
    self.viewport:SetScrollSize(self.contentWidth, self.contentHeight)
    self:_LayoutThumb()
end

function Scrollbar:SetSize(width, height)
    self.width = width
    self.height = height
    self.trackHeight = math.max(1, height - ARROW_SIZE * 2)
    self.root:SetSize(width, height)
    self.track:SetPos(-BAR_WIDTH, ARROW_SIZE, 1.0)
    self.track:SetSize(BAR_WIDTH, -ARROW_SIZE * 2, 0, 1.0)
    self.content:SetWidth(self.contentWidth)
    self.viewport:SetScrollSize(self.contentWidth, self.contentHeight)
    self:_LayoutThumb()
end

function Scrollbar:AddText(value)
    return Text.append(self, value, false)
end

function Scrollbar:AddTitle(value)
    return Text.append(self, value, true)
end

function Scrollbar:AddSpinner(options)
    local placed = Layout.place(self, options, { width = 29, height = 29 })
    return Layout.manage(self, Spinner.new(self.content, placed), placed)
end

function Scrollbar:AddBigSpinner(options)
    local placed = Layout.place(self, options, { width = 72, height = 72 })
    return Layout.manage(self, BigSpinner.new(self.content, placed), placed)
end

function Scrollbar:AddDivider(options)
    local placed = Layout.place(self, Divider.flowOptions(options), { width = 0, height = 60, fillWidth = true })
    return Layout.manage(self, Divider.new(self.content, placed), placed)
end

function Scrollbar:AddItemSlot(object, options)
    local placed = Layout.place(self, options, { width = 40, height = 40 })
    return Layout.manage(self, ItemSlot.new(self.content, object, placed), placed)
end

function Scrollbar:AddItemGrid(objects, options)
    local width, height = ItemGrid.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height })
    return Layout.manage(self, ItemGrid.new(self.content, objects, placed), placed)
end

function Scrollbar:AddTabs(tabs, options)
    local width, height = Tabs.getSize(tabs, options)
    local placed = Layout.place(
        self,
        Tabs.flowOptions(options),
        { width = width, height = height, fillWidth = true }
    )
    return Layout.manage(self, Tabs.new(self.content, tabs, placed), placed)
end

function Scrollbar:AddCollapseButton(text, options)
    local width, height = CollapseButton.getSize(text, options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    local button = Layout.manage(self, CollapseButton.new(self.content, text, placed), placed)
    return button:BindFlow(self)
end

function Scrollbar:AddPanel(options)
    local width, height = Panel.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    local panel = Layout.manage(self, Panel.new(self.content, placed, true), placed)
    return panel:BindFlow(self)
end

function Scrollbar:AddRadioButton(choices, options)
    local width, height = RadioButton.getSize(choices, options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, RadioButton.new(self.content, choices, placed), placed)
end

function Scrollbar:AddCheckboxButton(choices, options)
    local width, height = CheckboxButton.getSize(choices, options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, CheckboxButton.new(self.content, choices, placed), placed)
end

function Scrollbar:AddColourPicker(options)
    local width, height = ColourPicker.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height })
    return Layout.manage(self, ColourPicker.new(self.content, placed), placed)
end

function Scrollbar:AddTextField(options)
    local width, height = TextField.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, TextField.new(self.content, placed), placed)
end

function Scrollbar:AddComboBox(options)
    local width, height = ComboBox.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, ComboBox.new(self.content, placed), placed)
end

function Scrollbar:AddList(options)
    local width, height = List.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, List.new(self.content, placed), placed)
end

function Scrollbar:AddRibbonButton(spriteID, action, options)
    local placed = Layout.place(self, options, { width = 32, height = 32 })
    return Layout.manage(self, RibbonButton.new(self.content, spriteID, action, placed), placed)
end

function Scrollbar:AddSimpleButton(content, action, options)
    local width, height = SimpleButton.getSize(content, options)
    local placed = Layout.place(self, options, { width = width, height = height })
    return Layout.manage(self, SimpleButton.new(self.content, content, action, placed), placed)
end

function Scrollbar:AddSlider(options)
    local width, height = Slider.getSize(options)
    local placed = Layout.place(self, options, { width = width, height = height, fillWidth = true })
    return Layout.manage(self, Slider.new(self.content, placed), placed)
end

function Scrollbar:AddFancyButton(text, action, options)
    local width, height = FancyButton.getSize(text, options)
    local placed = Layout.place(self, options, { width = width, height = height })
    return Layout.manage(self, FancyButton.new(self.content, text, action, placed), placed)
end

function Scrollbar:AddSpriteButton(spriteName, action, options)
    local placed = Layout.place(self, options, { width = 24, height = 24 })
    return Layout.manage(self, SpriteButton.new(self.content, spriteName, action, placed), placed)
end

function Scrollbar:Destroy()
    self:_StopDrag()
    Layout.destroyManaged(self)
    if self.content then
        Tooltip.unregisterContext(self.content)
        self.tooltipContext = nil
    end
    if self.tooltip then
        self.tooltip:Destroy()
        self.tooltip = nil
    end
    if self.thumbDrag then
        if self.ownerWindow then self.ownerWindow:_UnregisterOverlay(self.thumbDrag) end
        self.thumbDrag:Destroy()
        self.thumbDrag = nil
    end
    if self.root then
        self.root:Destroy()
        self.root = nil
    end
    self.overlayContext = nil
    self.ownerWindow = nil
end

return Scrollbar
