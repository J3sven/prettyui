local Sprites = require("src/core/sprites")
local ColourPicker = require("src/colour_picker")
local ComboBox = require("src/combo_box")
local ContentMethods = require("src/core/content_methods")
local Cursor = require("src/core/cursor")
local InterfaceMouse = require("src/core/mouse")
local List = require("src/list")
local Layout = require("src/core/layout")
local Scroll = require("src/core/scroll")
local Slider = require("src/slider")
local TextField = require("src/text_field")
local Tabs = require("src/tabs")
local Tooltip = require("src/tooltip")
local Wheel = require("src/core/wheel")

local Panel = {}
Panel.__index = Panel

local PanelContent = {}
PanelContent.__index = PanelContent
Scroll.install(PanelContent)

local BORDER_SIZE = 4
local TOGGLE_SIZE = 20
local TOGGLE_INSET = 4
local DEFAULT_WIDTH = 300
local DEFAULT_HEIGHT = 160
local DEFAULT_POPOUT_X = 80
local DEFAULT_POPOUT_Y = 80
local nextInstanceID = 0

local function isAltDown()
    return Keyboard.IsAvailable() and not Keyboard.IsBlocked() and Keyboard.IsAltDown()
end

local function clampAlpha(value)
    return math.max(0, math.min(1, tonumber(value) or 1))
end

local function copyOptions(value)
    local copy = {}
    if type(value) == "table" then
        for key, option in pairs(value) do copy[key] = option end
    end
    return copy
end

local function sprite(parent, spriteID)
    local component = ui.Sprite.new(parent)
    component.spriteID = spriteID
    component.clickthrough = true
    return component
end

local function createSurface(parent, options)
    local surface = {}
    local frame = Sprites.HUD_WINDOW
    surface.root = ui.Layer.new(parent)
    surface.root:SetPos(options.x, options.y, options.xAnchor or 0, options.yAnchor or 0)
    surface.root:SetSize(options.width, options.height, options.widthAnchor or 0, options.heightAnchor or 0)
    surface.root.clickthrough = options.clickthrough == true

    surface.background = sprite(surface.root, frame.content)
    surface.background:SetPos(BORDER_SIZE, BORDER_SIZE)
    surface.background:SetSize(-BORDER_SIZE * 2, -BORDER_SIZE * 2, 1.0, 1.0)
    surface.background.isTiling = true
    surface.background.alpha = clampAlpha(options.backgroundAlpha)
    surface.background.clickthrough = options.clickthrough == true

    surface.top = sprite(surface.root, frame.top)
    surface.top:SetPos(BORDER_SIZE, 0)
    surface.top:SetSize(-BORDER_SIZE * 2, BORDER_SIZE, 1.0)
    surface.top.isTiling = true

    surface.bottom = sprite(surface.root, frame.bottom)
    surface.bottom:SetPos(BORDER_SIZE, -BORDER_SIZE, 0, 1.0)
    surface.bottom:SetSize(-BORDER_SIZE * 2, BORDER_SIZE, 1.0)
    surface.bottom.isTiling = true

    surface.right = sprite(surface.root, frame.side)
    surface.right:SetPos(-BORDER_SIZE, BORDER_SIZE, 1.0)
    surface.right:SetSize(BORDER_SIZE, -BORDER_SIZE * 2, 0, 1.0)
    surface.right.isTiling = true

    surface.left = sprite(surface.root, frame.side)
    surface.left:SetPos(0, BORDER_SIZE)
    surface.left:SetSize(BORDER_SIZE, -BORDER_SIZE * 2, 0, 1.0)
    surface.left.isTiling = true
    surface.right.isFlippedHorizontally = true

    surface.topRight = sprite(surface.root, frame.cornerTop)
    surface.topRight:SetPos(-BORDER_SIZE, 0, 1.0)
    surface.topRight:SetSize(BORDER_SIZE, BORDER_SIZE)
    surface.topRight.isFlippedHorizontally = true

    surface.topLeft = sprite(surface.root, frame.cornerTop)
    surface.topLeft:SetSize(BORDER_SIZE, BORDER_SIZE)

    surface.bottomRight = sprite(surface.root, frame.cornerBottom)
    surface.bottomRight:SetPos(-BORDER_SIZE, -BORDER_SIZE, 1.0, 1.0)
    surface.bottomRight:SetSize(BORDER_SIZE, BORDER_SIZE)
    surface.bottomRight.isFlippedHorizontally = true

    surface.bottomLeft = sprite(surface.root, frame.cornerBottom)
    surface.bottomLeft:SetPos(0, -BORDER_SIZE, 0, 1.0)
    surface.bottomLeft:SetSize(BORDER_SIZE, BORDER_SIZE)

    surface.container = ui.Layer.new(surface.root)
    surface.container:SetPos(BORDER_SIZE, BORDER_SIZE)
    surface.container:SetSize(-BORDER_SIZE * 2, -BORDER_SIZE * 2, 1.0, 1.0)
    surface.container.clickthrough = options.clickthrough == true
    surface.container.enabled = options.clickthrough ~= true

    return surface
end

local function createToggle(surface, panel, popoutMode)
    local button = ui.Sprite.new(surface.root)
    button:SetPos(-TOGGLE_SIZE - TOGGLE_INSET, TOGGLE_INSET, 1.0)
    button:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
    button.clickthrough = false
    local hovered = false
    local pressed = false

    local function update()
        local states = popoutMode and Sprites.PANEL_POPOUT_BUTTON or Sprites.PANEL_DOCK_BUTTON
        if pressed then
            button.spriteID = states.mousedown
        elseif hovered then
            button.spriteID = states.hovered
        else
            button.spriteID = states.neutral
        end
    end

    button:Subscribe(ui.Hook.ONMOUSEOVER, function()
        hovered = true
        update()
        return true
    end)
    button:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        hovered = false
        pressed = false
        update()
        return true
    end)
    button:Subscribe(ui.Hook.ONCLICK, function()
        pressed = true
        update()
        return false
    end)
    button:Subscribe(ui.Hook.ONRELEASE, function()
        local activate = pressed
        pressed = false
        update()
        if activate then panel:SetPoppedOut(popoutMode) end
        return false
    end)
    update()
    button:MoveToFront()
    return button
end

local function createDragLayer(parent, surface, panel)
    local layer = ui.Layer.new(parent)
    layer:SetPos(surface.root.x, surface.root.y)
    layer:SetSize(surface.root.width, surface.root.height)
    layer.clickthrough = true
    layer.enabled = false
    layer.hidden = true

    layer:Subscribe(ui.Hook.ONCLICK, function(component, x, y)
        if not isAltDown() then return true end
        panel:_BeginDrag(surface, component, x, y)
        return false
    end)
    layer:Subscribe(ui.Hook.ONHOLD, function(component, x, y)
        return panel:_MoveDrag(component, x, y)
    end)
    layer:Subscribe(ui.Hook.ONDRAG, function(component, x, y)
        return panel:_MoveDrag(component, x, y)
    end)
    layer:Subscribe(ui.Hook.ONRELEASE, function()
        return panel:_StopDrag()
    end)
    layer:Subscribe(ui.Hook.ONDRAGCOMPLETE, function()
        return panel:_StopDrag()
    end)
    return layer
end

local function pairObjects(panel, dock, overlay)
    local proxy = {}
    rawset(proxy, "dock", dock)
    rawset(proxy, "overlay", overlay)
    return setmetatable(proxy, {
        __index = function(_, key)
            if key == "dock" or key == "overlay" then return rawget(proxy, key) end
            local active = panel.poppedOut and overlay or dock
            local value = active[key]
            if type(value) ~= "function" then return value end
            return function(_, ...)
                local dockResult = dock[key](dock, ...)
                local overlayResult = overlay[key](overlay, ...)
                local result = panel.poppedOut and overlayResult or dockResult
                if dockResult ~= nil and overlayResult ~= nil and
                    (type(dockResult) == "table" or type(dockResult) == "userdata") and
                    (type(overlayResult) == "table" or type(overlayResult) == "userdata") then
                    return pairObjects(panel, dockResult, overlayResult)
                end
                return result
            end
        end,
        __newindex = function(_, key, value)
            dock[key] = value
            overlay[key] = value
        end,
    })
end

local function configureOwner(surface, options, context, overlayParent)
    local owner = setmetatable({}, PanelContent)
    local scroll = Scroll.attach(owner, surface.container, {
        width = 0,
        height = 0,
        widthAnchor = 1.0,
        heightAnchor = 1.0,
        contentHeight = options.contentHeight,
        scrollable = options.scrollable,
        scrollStep = options.scrollStep,
        _onScrollWheel = options._onScrollWheel,
        clickthrough = surface.root.clickthrough == true,
        parentContext = context,
        overlayParent = overlayParent,
        isVisible = function() return surface.root.hidden ~= true end,
        position = function(scrollRoot)
            local rootX = surface.root.x or 0
            local rootY = surface.root.y or 0
            if context then rootX, rootY = context.position(surface.root) end
            return rootX + (surface.container.x or 0) + (scrollRoot.x or 0),
                rootY + (surface.container.y or 0) + (scrollRoot.y or 0)
        end,
    })
    surface.scroll = scroll
    surface.viewport = scroll.viewport
    surface.content = scroll.content
    Layout.configure(owner, options.layout or options.textLayout)
    return owner
end

function Panel.getSize(options)
    options = options or {}
    return options.width or DEFAULT_WIDTH, options.height or DEFAULT_HEIGHT
end

function Panel.new(parent, options, flowManaged)
    options = options or {}
    local width, height = Panel.getSize(options)
    local parentContext = Tooltip.getContext(parent)
    local overlayParent = options.overlayParent or (parentContext and parentContext.parent) or parent

    local self = setmetatable({}, Panel)
    nextInstanceID = nextInstanceID + 1
    self.dragEventID = "prettyui_panel_drag_" .. tostring(nextInstanceID)
    self.parent = parent
    self.overlayParent = overlayParent
    self._dockDraggable = flowManaged ~= true
    self._canPopout = options.popout == true
    self.popoutClickthrough = options.popoutClickthrough == true
    self.popoutBackgroundAlpha = clampAlpha(options.popoutBackgroundAlpha or options.backgroundAlpha)
    self.onPopoutChange = options.onPopoutChange
    self.poppedOut = self._canPopout and options.poppedOut == true

    self.dock = createSurface(parent, {
        x = options.x or 0,
        y = options.y or 0,
        xAnchor = options.xAnchor,
        yAnchor = options.yAnchor,
        widthAnchor = options.widthAnchor,
        heightAnchor = options.heightAnchor,
        width = width,
        height = height,
        backgroundAlpha = options.backgroundAlpha,
        clickthrough = false,
    })
    self.width = self.dock.root.width
    self.height = self.dock.root.height
    self.contentWidth = self.width - BORDER_SIZE * 2
    self.overlay = createSurface(overlayParent, {
        x = options.popoutX or DEFAULT_POPOUT_X,
        y = options.popoutY or DEFAULT_POPOUT_Y,
        xAnchor = options.popoutXAnchor,
        yAnchor = options.popoutYAnchor,
        width = options.popoutWidth or self.width,
        height = options.popoutHeight or self.height,
        backgroundAlpha = self.popoutBackgroundAlpha,
        clickthrough = self.popoutClickthrough,
    })
    local dockTooltipParent = parentContext and parentContext.parent or parent
    self.dockOwner = configureOwner(self.dock, options, parentContext, dockTooltipParent)
    self.overlayOwner = configureOwner(self.overlay, options, nil, overlayParent)
    self.root = self.dock.root
    self.content = self.dock.content
    self.overlayContent = self.overlay.content
    self.scrollable = self.dock.scroll.scrollable
    Wheel.bind(self.dock.root, options)
    Wheel.bind(self.dock.background, options)

    self.dockTooltipContext = Tooltip.registerContext(self.dock.content, dockTooltipParent, function(target)
        local rootX, rootY = self.dock.scroll:_AbsolutePosition()
        return rootX + (target.x or 0),
            rootY + (target.y or 0) - self.dock.scroll.scrollY
    end, parentContext)
    self.overlayTooltipContext = Tooltip.registerContext(self.overlay.content, overlayParent, function(target)
        local rootX, rootY = self.overlay.scroll:_AbsolutePosition()
        return rootX + (target.x or 0),
            rootY + (target.y or 0) - self.overlay.scroll.scrollY
    end, nil)

    if self._canPopout then
        self.popoutButton = createToggle(self.dock, self, true)
        self.dockButton = createToggle(self.overlay, self, false)
        Wheel.bind(self.popoutButton, options)
    end
    if self._dockDraggable then
        self.dockDragLayer = createDragLayer(self.parent, self.dock, self)
    end
    if self._canPopout then
        self.overlayDragLayer = createDragLayer(self.overlayParent, self.overlay, self)
    end
    self.dockTooltip = Tooltip.attach(self.dock.root, parent, options.tooltip)
    self.overlayTooltip = Tooltip.attach(self.overlay.root, overlayParent, options.tooltip)
    self:SetPopoutClickthrough(self.popoutClickthrough)
    self:SetPoppedOut(self.poppedOut, false)
    self:_SetAltDragActive(isAltDown())
    Event.Logic.Subscribe(self.dragEventID, function()
        self:_SetAltDragActive(isAltDown())
    end)
    return self
end

function Panel:_SetAltDragActive(active)
    local activeSurface
    if active == true then
        if self.poppedOut and self._canPopout then
            activeSurface = self.overlay
        elseif self._dockDraggable then
            activeSurface = self.dock
        end
    end
    if self.altDragSurface == activeSurface then return end
    self.altDragSurface = activeSurface

    local function updateLayer(layer, surface)
        if not layer then return end
        local enabled = activeSurface == surface
        layer.enabled = enabled
        layer.clickthrough = not enabled
        layer.hidden = not enabled
        Cursor.apply(layer, config.Cursor.CURSOR_USE, enabled)
        if enabled then
            layer:SetPos(surface.root.x, surface.root.y)
            layer:SetSize(surface.root.width, surface.root.height)
            layer:MoveToFront()
        end
    end
    updateLayer(self.dockDragLayer, self.dock)
    updateLayer(self.overlayDragLayer, self.overlay)

    if not activeSurface then
        self:_StopDrag()
        if self.popoutButton then self.popoutButton:MoveToFront() end
        if self.dockButton then self.dockButton:MoveToFront() end
    end
end

function Panel:_BeginDrag(surface, component, x, y)
    if surface ~= self.altDragSurface or not isAltDown() then return false end
    InterfaceMouse.BeginCapture(component)
    local mouse = InterfaceMouse.GetPosition(component, x, y)
    if not mouse then
        InterfaceMouse.EndCapture(component)
        return false
    end
    self.dragState = {
        surface = surface,
        mouseX = mouse.x,
        mouseY = mouse.y,
        panelX = surface.root.x,
        panelY = surface.root.y,
        captureExpanded = false,
    }
    surface.root:MoveToFront()
    return false
end

function Panel:_MoveDrag(component, x, y)
    if not self.dragState then return false end
    if not isAltDown() then return self:_StopDrag() end
    local mouse = InterfaceMouse.GetPosition(component, x, y)
    if mouse then
        local drag = self.dragState
        if not drag.captureExpanded then
            drag.captureExpanded = true
            drag.mouseX = mouse.x
            drag.mouseY = mouse.y
            drag.panelX = drag.surface.root.x
            drag.panelY = drag.surface.root.y
            component:SetPos(0, 0)
            component:SetSize(0, 0, 1.0, 1.0)
            component:MoveToFront()
            return false
        end
        drag.surface.root:SetPos(
            drag.panelX + mouse.x - drag.mouseX,
            drag.panelY + mouse.y - drag.mouseY
        )
    end
    return false
end

function Panel:_StopDrag()
    local surface = self.dragState and self.dragState.surface or nil
    local dragLayer = surface == self.overlay and self.overlayDragLayer or self.dockDragLayer
    InterfaceMouse.EndCapture(dragLayer)
    self.dragState = nil
    if surface then
        if dragLayer then
            dragLayer:SetPos(surface.root.x, surface.root.y)
            dragLayer:SetSize(surface.root.width, surface.root.height)
        end
    end
    return false
end

function Panel:_UpdateFlowHeight()
    local height = self.poppedOut and 0 or self.height
    if self.flowOwner then
        Layout.resize(self.flowOwner, self, height)
    elseif not self.poppedOut then
        self.dock.root:SetHeight(height)
    end
end

function Panel:BindFlow(owner)
    self.flowOwner = owner
    self:_UpdateFlowHeight()
    return self
end

function Panel:SetPoppedOut(poppedOut, notify)
    local previous = self.poppedOut
    self.poppedOut = self._canPopout and poppedOut == true
    self.dock.root.hidden = self.poppedOut
    self.overlay.root.hidden = not self.poppedOut
    self:_UpdateFlowHeight()
    self.dock.scroll:Refresh()
    self.overlay.scroll:Refresh()
    if self.poppedOut then self.overlay.root:MoveToFront() end
    self:_SetAltDragActive(isAltDown())
    if notify ~= false and previous ~= self.poppedOut and self.onPopoutChange then
        self.onPopoutChange(self, self.poppedOut)
    end
end

function Panel:TogglePopout()
    self:SetPoppedOut(not self.poppedOut)
end

function Panel:SetPopoutClickthrough(clickthrough)
    self.popoutClickthrough = clickthrough == true
    self.overlay.root.clickthrough = self.popoutClickthrough
    self.overlay.background.clickthrough = self.popoutClickthrough
    self.overlay.container.clickthrough = self.popoutClickthrough
    self.overlay.container.enabled = not self.popoutClickthrough
    self.overlay.scroll:SetClickthrough(self.popoutClickthrough)
end

function Panel:SetPopoutBackgroundAlpha(alpha)
    self.popoutBackgroundAlpha = clampAlpha(alpha)
    self.overlay.background.alpha = self.popoutBackgroundAlpha
end

function Panel:SetSize(width, height)
    self.width = math.max(BORDER_SIZE * 2 + 1, math.floor(width))
    self.height = math.max(BORDER_SIZE * 2 + 1, math.floor(height))
    self.contentWidth = self.width - BORDER_SIZE * 2
    self.dock.root:SetWidth(self.width)
    self.overlay.root:SetSize(self.width, self.height)
    self:_UpdateFlowHeight()
    self.dockOwner.contentWidth = self.contentWidth
    self.overlayOwner.contentWidth = self.contentWidth
    self.dock.scroll:Refresh()
    self.overlay.scroll:Refresh()
    if self.dragState == nil then
        if self.dockDragLayer then
            self.dockDragLayer:SetPos(self.dock.root.x, self.dock.root.y)
            self.dockDragLayer:SetSize(self.dock.root.width, self.dock.root.height)
        end
        if self.overlayDragLayer then
            self.overlayDragLayer:SetPos(self.overlay.root.x, self.overlay.root.y)
            self.overlayDragLayer:SetSize(self.overlay.root.width, self.overlay.root.height)
        end
    end
end

function Panel:SetScrollable(scrollable)
    self.dock.scroll:SetScrollable(scrollable)
    self.overlay.scroll:SetScrollable(scrollable)
    self.dockOwner.scrollable = self.dock.scroll.scrollable
    self.overlayOwner.scrollable = self.overlay.scroll.scrollable
    self.scrollable = self.dock.scroll.scrollable
end

-- Install the shared Add... API against both panel surfaces. The stateful methods
-- below overwrite their generated counterparts to keep dock and popout state in sync.
ContentMethods.installPaired(Panel, function(panel)
    return {
        { owner = panel.dockOwner, content = panel.dock.content },
        { owner = panel.overlayOwner, content = panel.overlay.content },
    }
end, pairObjects)

function Panel:AddTabs(tabs, options)
    local width, height = Tabs.getSize(tabs, options)
    local proxy
    local syncing = false

    local function placedOptions(owner)
        local copied = Tabs.flowOptions(options)
        copied.onChange = function(_, index, value)
            if syncing then return end
            syncing = true
            proxy.dock:SetActive(index, false)
            proxy.overlay:SetActive(index, false)
            syncing = false
            if options and options.onChange then
                options.onChange(proxy, index, value, proxy:GetPage(index))
            end
        end
        return Layout.place(owner, copied, { width = width, height = height, fillWidth = true })
    end

    local dockOptions = placedOptions(self.dockOwner)
    local overlayOptions = placedOptions(self.overlayOwner)
    proxy = pairObjects(self,
        Layout.manage(self.dockOwner, Tabs.new(self.dock.content, tabs, dockOptions), dockOptions),
        Layout.manage(self.overlayOwner, Tabs.new(self.overlay.content, tabs, overlayOptions), overlayOptions))
    return proxy
end

function Panel:AddColourPicker(options)
    local proxy
    local syncing = false
    local function placedOptions(owner)
        local copied = copyOptions(options)
        copied.onChange = function(_, colour)
            if syncing then return end
            syncing = true
            proxy.dock:SetValue(colour, false)
            proxy.overlay:SetValue(colour, false)
            syncing = false
            if options and options.onChange then options.onChange(proxy, colour) end
        end
        local width, height = ColourPicker.getSize(copied)
        return Layout.place(owner, copied, { width = width, height = height })
    end
    local dockOptions = placedOptions(self.dockOwner)
    local overlayOptions = placedOptions(self.overlayOwner)
    proxy = pairObjects(self,
        Layout.manage(
            self.dockOwner,
            ColourPicker.new(self.dock.content, dockOptions),
            dockOptions
        ),
        Layout.manage(
            self.overlayOwner,
            ColourPicker.new(self.overlay.content, overlayOptions),
            overlayOptions
        ))
    rawset(proxy, "Open", function()
        local active = self.poppedOut and proxy.overlay or proxy.dock
        return active:Open()
    end)
    return proxy
end

function Panel:AddTextField(options)
    options = options or {}
    local proxy
    local syncing = false
    local width, height = TextField.getSize(options)
    local function placed(owner, other)
        local copied = copyOptions(options)
        copied.onChange = function(_, reason, content)
            if syncing then return end
            syncing = true
            if other() then other():SetText(content, false) end
            syncing = false
            if options.onChange then options.onChange(proxy, reason, content) end
            if options.onSubmit and reason == ui.InputFieldActionResult.SUBMIT then
                options.onSubmit(proxy, content)
            end
        end
        copied.onSubmit = nil
        return Layout.place(owner, copied, { width = width, height = height, fillWidth = true })
    end
    local dock, overlay
    local dockOptions = placed(self.dockOwner, function() return overlay end)
    local overlayOptions = placed(self.overlayOwner, function() return dock end)
    dock = Layout.manage(self.dockOwner, TextField.new(self.dock.content, dockOptions), dockOptions)
    overlay = Layout.manage(self.overlayOwner, TextField.new(self.overlay.content, overlayOptions), overlayOptions)
    proxy = pairObjects(self, dock, overlay)
    rawset(proxy, "SetText", function(_, value, notify)
        local content = tostring(value or "")
        syncing = true
        dock:SetText(content, false)
        overlay:SetText(content, false)
        syncing = false
        if notify == true and options.onChange then
            options.onChange(proxy, ui.InputFieldActionResult.CONTENT_CHANGE, content)
        end
    end)
    return proxy
end

function Panel:AddComboBox(options)
    options = options or {}
    local proxy
    local syncing = false
    local width, height = ComboBox.getSize(options)
    local function placed(owner, other)
        local copied = copyOptions(options)
        copied.onChange = function(_, entryID, label, eventType)
            if syncing then return end
            syncing = true
            if other() then other():Select(entryID, false) end
            syncing = false
            if options.onChange then options.onChange(proxy, entryID, label, eventType) end
        end
        return Layout.place(owner, copied, { width = width, height = height, fillWidth = true })
    end
    local dock, overlay
    local dockOptions = placed(self.dockOwner, function() return overlay end)
    local overlayOptions = placed(self.overlayOwner, function() return dock end)
    dock = Layout.manage(self.dockOwner, ComboBox.new(self.dock.content, dockOptions), dockOptions)
    overlay = Layout.manage(self.overlayOwner, ComboBox.new(self.overlay.content, overlayOptions), overlayOptions)
    proxy = pairObjects(self, dock, overlay)
    rawset(proxy, "Select", function(_, entryID, notify)
        syncing = true
        local dockResult = dock:Select(entryID, false)
        local overlayResult = overlay:Select(entryID, false)
        syncing = false
        if notify == true and options.onChange then
            local active = self.poppedOut and overlay or dock
            options.onChange(proxy, entryID, active:GetSelectedLabel(), ui.SelectionChangeEvent.SELECTED)
        end
        return self.poppedOut and overlayResult or dockResult
    end)
    return proxy
end

function Panel:AddList(options)
    options = options or {}
    local proxy
    local syncing = false
    local width, height = List.getSize(options)
    local function placed(owner, other)
        local copied = copyOptions(options)
        copied.onChange = function(_, entryID, selected, eventType)
            if syncing then return end
            syncing = true
            if other() then other():SetSelected(entryID, selected, false) end
            syncing = false
            if options.onChange then options.onChange(proxy, entryID, selected, eventType) end
        end
        return Layout.place(owner, copied, { width = width, height = height, fillWidth = true })
    end
    local dock, overlay
    local dockOptions = placed(self.dockOwner, function() return overlay end)
    local overlayOptions = placed(self.overlayOwner, function() return dock end)
    dock = Layout.manage(self.dockOwner, List.new(self.dock.content, dockOptions), dockOptions)
    overlay = Layout.manage(self.overlayOwner, List.new(self.overlay.content, overlayOptions), overlayOptions)
    proxy = pairObjects(self, dock, overlay)
    rawset(proxy, "SetSelected", function(_, entryID, selected, notify)
        syncing = true
        local dockResult = dock:SetSelected(entryID, selected, false)
        local overlayResult = overlay:SetSelected(entryID, selected, false)
        syncing = false
        if notify == true and options.onChange then
            options.onChange(
                proxy,
                entryID,
                selected == true,
                selected and ui.SelectionChangeEvent.SELECTED or ui.SelectionChangeEvent.DESELECTED
            )
        end
        return self.poppedOut and overlayResult or dockResult
    end)
    return proxy
end

function Panel:AddSlider(options)
    local proxy
    local syncing = false
    local function placedOptions(owner)
        local copied = copyOptions(options)
        copied.onChange = function(_, value)
            if syncing then return end
            syncing = true
            proxy.dock:SetValue(value, false)
            proxy.overlay:SetValue(value, false)
            syncing = false
            if options and options.onChange then options.onChange(proxy, value) end
        end
        local width, height = Slider.getSize(copied)
        return Layout.place(owner, copied, { width = width, height = height, fillWidth = true })
    end
    local dockOptions = placedOptions(self.dockOwner)
    local overlayOptions = placedOptions(self.overlayOwner)
    proxy = pairObjects(self,
        Layout.manage(self.dockOwner, Slider.new(self.dock.content, dockOptions), dockOptions),
        Layout.manage(self.overlayOwner, Slider.new(self.overlay.content, overlayOptions), overlayOptions))
    return proxy
end

function Panel:Destroy()
    Event.Logic.Unsubscribe(self.dragEventID)
    self:_StopDrag()
    Layout.destroyManaged(self.dockOwner)
    Layout.destroyManaged(self.overlayOwner)
    if self.dock and self.dock.content then Tooltip.unregisterContext(self.dock.content) end
    if self.overlay and self.overlay.content then Tooltip.unregisterContext(self.overlay.content) end
    if self.dockTooltip then self.dockTooltip:Destroy() self.dockTooltip = nil end
    if self.overlayTooltip then self.overlayTooltip:Destroy() self.overlayTooltip = nil end
    if self.dock and self.dock.scroll then
        self.dock.scroll:Destroy()
        self.dock.scroll = nil
    end
    if self.overlay and self.overlay.scroll then
        self.overlay.scroll:Destroy()
        self.overlay.scroll = nil
    end
    if self.dockDragLayer then self.dockDragLayer:Destroy() self.dockDragLayer = nil end
    if self.overlayDragLayer then
        self.overlayDragLayer:Destroy()
        self.overlayDragLayer = nil
    end
    if self.dock and self.dock.root then self.dock.root:Destroy() end
    if self.overlay and self.overlay.root then self.overlay.root:Destroy() end
    self.root = nil
    self.content = nil
    self.overlayContent = nil
    self.flowOwner = nil
end

return Panel
