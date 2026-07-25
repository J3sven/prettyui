local Sprites = require("src/core/sprites")
local ContentMethods = require("src/core/content_methods")
local Text = require("src/text")
local Tooltip = require("src/tooltip")
local Layout = require("src/core/layout")
local InterfaceMouse = require("src/core/mouse")

local Window = {}
Window.__index = Window

local BORDER = 8
local CORNER_SIZE = 16
local TITLE_HEIGHT = 32
local TITLE_LEFT_WIDTH = 28
local TITLE_INNER_WIDTH = 64
local TITLE_RIGHT_WIDTH = 64
local CLOSE_SIZE = 20
local CLOSE_RIGHT = 8
local MIN_WIDTH = 220
local MIN_HEIGHT = 140

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if maximum ~= nil and value > maximum then return maximum end
    return value
end

local function sprite(parent, spriteID)
    local component = ui.Sprite.new(parent)
    component.spriteID = spriteID
    component.clickthrough = false
    return component
end

function Window.new(parent, options)
    options = options or {}

    local self = setmetatable({}, Window)
    self.parent = parent
    self.title = options.title
    self.onClose = options.onClose
    self.destroyOnClose = options.destroyOnClose == true
    self.minWidth = options.minWidth or MIN_WIDTH
    self.minHeight = options.minHeight or MIN_HEIGHT
    self.maxWidth = options.maxWidth
    self.maxHeight = options.maxHeight
    self.overlays = {}

    self.root = ui.Layer.new(parent)
    self.root.clickthrough = false
    self.root:SetPos(
        options.x or 80,
        options.y or 80,
        options.xAnchor or 0,
        options.yAnchor or 0
    )
    self.root:SetSize(
        clamp(options.width or 480, self.minWidth, self.maxWidth),
        clamp(options.height or 340, self.minHeight, self.maxHeight)
    )
    self.contentWidth = self.root.width - BORDER * 2
    self.root:MoveToFront()

    local top = self.title and TITLE_HEIGHT or BORDER
    local sideTop = self.title and TITLE_HEIGHT or CORNER_SIZE

    self.background = sprite(self.root, Sprites.WINDOW_BACKGROUND)
    self.background:SetPos(BORDER, top)
    self.background:SetSize(-BORDER * 2, -top - BORDER, 1.0, 1.0)
    self.background.isTiling = true

    self.leftBorder = sprite(self.root, Sprites.BORDER_LEFT)
    self.leftBorder:SetPos(0, sideTop)
    self.leftBorder:SetSize(BORDER, -sideTop - CORNER_SIZE, 0, 1.0)

    self.rightBorder = sprite(self.root, Sprites.BORDER_LEFT)
    self.rightBorder:SetPos(-BORDER, sideTop, 1.0)
    self.rightBorder:SetSize(BORDER, -sideTop - CORNER_SIZE, 0, 1.0)
    self.rightBorder.isFlippedHorizontally = true

    self.bottomBorder = sprite(self.root, Sprites.BORDER_BOTTOM)
    self.bottomBorder:SetPos(CORNER_SIZE, -BORDER, 0, 1.0)
    self.bottomBorder:SetSize(-CORNER_SIZE * 2, BORDER, 1.0)
    self.bottomBorder.isTiling = true

    self.bottomLeft = sprite(self.root, Sprites.BORDER_CORNER)
    self.bottomLeft:SetPos(0, -CORNER_SIZE, 0, 1.0)
    self.bottomLeft:SetSize(CORNER_SIZE, CORNER_SIZE)

    self.bottomRight = sprite(self.root, Sprites.BORDER_CORNER)
    self.bottomRight:SetPos(-CORNER_SIZE, -CORNER_SIZE, 1.0, 1.0)
    self.bottomRight:SetSize(CORNER_SIZE, CORNER_SIZE)
    self.bottomRight.isFlippedHorizontally = true

    if self.title then
        self.titleLeft = sprite(self.root, Sprites.TITLEBAR_LEFT)
        self.titleLeft:SetSize(TITLE_LEFT_WIDTH, TITLE_HEIGHT)

        self.titleCentreLeft = sprite(self.root, Sprites.TITLEBAR_CENTRE_LEFT)
        self.titleCentreLeft:SetPos(TITLE_LEFT_WIDTH, 0)
        self.titleCentreLeft:SetSize(TITLE_INNER_WIDTH, TITLE_HEIGHT)

        self.titleCentre = sprite(self.root, Sprites.TITLEBAR_CENTRE)
        self.titleCentre:SetPos(TITLE_LEFT_WIDTH + TITLE_INNER_WIDTH, 0)
        self.titleCentre:SetSize(
            -(TITLE_LEFT_WIDTH + TITLE_INNER_WIDTH + TITLE_INNER_WIDTH + TITLE_RIGHT_WIDTH),
            TITLE_HEIGHT,
            1.0
        )
        self.titleCentre.isTiling = true

        self.titleCentreRight = sprite(self.root, Sprites.TITLEBAR_CENTRE_RIGHT)
        self.titleCentreRight:SetPos(-TITLE_RIGHT_WIDTH - TITLE_INNER_WIDTH, 0, 1.0)
        self.titleCentreRight:SetSize(TITLE_INNER_WIDTH, TITLE_HEIGHT)

        self.titleRight = sprite(self.root, Sprites.TITLEBAR_RIGHT)
        self.titleRight:SetPos(-TITLE_RIGHT_WIDTH, 0, 1.0)
        self.titleRight:SetSize(TITLE_RIGHT_WIDTH, TITLE_HEIGHT)

        self.titleLeft:MoveToFront()
        self.titleRight:MoveToFront()

        self.titleText = Text.title(self.root, {
            text = self.title,
            x = 12,
            y = 2,
            width = -48,
            height = TITLE_HEIGHT - 4,
            colour = 0xF4E4B8FF,
            font = id.Font.CINZEL_13PT_BOLD,
            alignHorizontal = ui.AlignMode.CENTRE,
        })

        self.titleDrag = ui.Layer.new(self.parent)
        self.titleDrag:MoveToFront()
        self.titleDrag:SetPos(self.root.x, self.root.y)
        self.titleDrag:SetSize(self.root.width - CLOSE_SIZE - 14, TITLE_HEIGHT)
        self.titleDrag.clickthrough = false

        local dragStart = nil
        local captureExpanded = false

        local function stopDrag()
            dragStart = nil
            captureExpanded = false
            InterfaceMouse.EndCapture(self.titleDrag)
            self.titleDrag:SetPos(self.root.x, self.root.y)
            self.titleDrag:SetSize(self.root.width - CLOSE_SIZE - 14, TITLE_HEIGHT)
            self:_SyncOverlays(false)
            return false
        end

        local function moveDrag(component, x, y)
            local mouse = InterfaceMouse.GetPosition(component, x, y)
            if dragStart and mouse then
                if not captureExpanded then
                    captureExpanded = true
                    dragStart.mouseX = mouse.x
                    dragStart.mouseY = mouse.y
                    dragStart.windowX = self.root.x
                    dragStart.windowY = self.root.y
                    self.titleDrag:SetPos(0, 0)
                    self.titleDrag:SetSize(0, 0, 1.0, 1.0)
                    self.titleDrag:MoveToFront()
                    return false
                end
                self.root:SetPos(
                    dragStart.windowX + mouse.x - dragStart.mouseX,
                    dragStart.windowY + mouse.y - dragStart.mouseY
                )
            end
            return false
        end

        self.titleDrag:Subscribe(ui.Hook.ONCLICK, function(component, x, y)
            InterfaceMouse.BeginScreenCapture(component, x, y)
            local mouse = InterfaceMouse.GetPosition(component, x, y)
            dragStart = {
                mouseX = mouse and mouse.x or 0,
                mouseY = mouse and mouse.y or 0,
                windowX = self.root.x,
                windowY = self.root.y,
            }
            self.root:MoveToFront()
            self.titleDrag:MoveToFront()
            return false
        end)
        self.titleDrag:Subscribe(ui.Hook.ONHOLD, moveDrag)
        self.titleDrag:Subscribe(ui.Hook.ONRELEASE, stopDrag)
        self.titleDrag:Subscribe(ui.Hook.ONDRAGCOMPLETE, stopDrag)
    else
        self.topBorder = sprite(self.root, Sprites.BORDER_BOTTOM)
        self.topBorder:SetPos(CORNER_SIZE, 0)
        self.topBorder:SetSize(-CORNER_SIZE * 2, BORDER, 1.0)
        self.topBorder.isTiling = true
        self.topBorder.isFlippedVertical = true

        self.topLeft = sprite(self.root, Sprites.BORDER_CORNER)
        self.topLeft:SetSize(CORNER_SIZE, CORNER_SIZE)
        self.topLeft.isFlippedVertical = true

        self.topRight = sprite(self.root, Sprites.BORDER_CORNER)
        self.topRight:SetPos(-CORNER_SIZE, 0, 1.0)
        self.topRight:SetSize(CORNER_SIZE, CORNER_SIZE)
        self.topRight.isFlippedHorizontally = true
        self.topRight.isFlippedVertical = true
    end

    self.closeButton = sprite(self.root, Sprites.CLOSE)
    self.closeButton:SetPos(-CLOSE_SIZE - CLOSE_RIGHT, 7, 1.0)
    self.closeButton:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    self.closeButton:Subscribe(ui.Hook.ONMOUSEOVER, function()
        self.closeButton.spriteID = Sprites.CLOSE_ACTIVE
    end)
    self.closeButton:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        self.closeButton.spriteID = Sprites.CLOSE
    end)
    self.closeButton:Subscribe(ui.Hook.ONCLICK, function()
        self:Close()
        return false
    end)

    self.content = ui.Layer.new(self.root)
    self.content:SetPos(BORDER, top)
    self.content:SetSize(-BORDER * 2, -top - BORDER, 1.0, 1.0)
    self.content.clickthrough = false
    self.closeButton:MoveToFront()
    local parentTooltipContext = Tooltip.getContext(parent)
    local tooltipParent = parentTooltipContext and parentTooltipContext.parent or parent
    self.tooltipContext = Tooltip.registerContext(self.content, tooltipParent, function(target)
        local rootX = self.root.x or 0
        local rootY = self.root.y or 0
        if parentTooltipContext then rootX, rootY = parentTooltipContext.position(self.root) end
        return rootX + (self.content.x or 0) + (target.x or 0),
            rootY + (self.content.y or 0) + (target.y or 0)
    end, parentTooltipContext)
    self.tooltipContext.ownerWindow = self
    Layout.configure(self, options.layout or options.textLayout)
    self.tooltip = Tooltip.attach(self.root, parent, options.tooltip)

    return self
end

function Window:SetSize(width, height)
    self.root:SetSize(
        clamp(math.floor(width), self.minWidth, self.maxWidth),
        clamp(math.floor(height), self.minHeight, self.maxHeight)
    )
    self.contentWidth = self.root.width - BORDER * 2
    self:_SyncOverlays(self.root.hidden == true)
end

function Window:SetTitle(title)
    self.title = title
    if self.titleText then self.titleText.content = title or "" end
end

-- A window is a standard single-surface content host. Component definitions and
-- flow defaults live in content_methods rather than being repeated here.
ContentMethods.installSingle(Window)

function Window:_RegisterOverlay(component, isVisible, layout)
    self.overlays[component] = { isVisible = isVisible, layout = layout }
end

function Window:_UnregisterOverlay(component)
    self.overlays[component] = nil
end

function Window:_SyncOverlays(hidden)
    for component, overlay in pairs(self.overlays) do
        if not hidden and overlay.layout then overlay.layout() end
        component.hidden = hidden or
            (overlay.isVisible and not overlay.isVisible() or false)
        if not component.hidden then component:MoveToFront() end
    end
end

function Window:Show()
    self.root.hidden = false
    self.root:MoveToFront()
    if self.titleDrag then
        self.titleDrag.hidden = false
        self.titleDrag:MoveToFront()
    end
    self:_SyncOverlays(false)
end

function Window:Close()
    if self.onClose then self.onClose(self) end
    if self.destroyOnClose then
        self:Destroy()
    else
        self.root.hidden = true
        if self.titleDrag then self.titleDrag.hidden = true end
        self:_SyncOverlays(true)
    end
end

function Window:Destroy()
    self:_SyncOverlays(true)
    Layout.destroyManaged(self)
    if self.content then
        Tooltip.unregisterContext(self.content)
        self.tooltipContext = nil
    end
    if self.tooltip then
        self.tooltip:Destroy()
        self.tooltip = nil
    end
    if self.root then
        self.root:Destroy()
        self.root = nil
    end
    if self.titleDrag then
        self.titleDrag:Destroy()
        self.titleDrag = nil
    end
    self.overlays = {}
end

return Window
