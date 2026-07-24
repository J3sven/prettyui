local Sprites = require("src/core/sprites")

local Tooltip = {}
Tooltip.__index = Tooltip

local BORDER_SIZE = 10
local PADDING_X = 8
local PADDING_Y = 5
local OFFSET = 6
local DEFAULT_MAX_WIDTH = 240
local FALLBACK_LINE_HEIGHT = 18
local TEXT_COLOUR = 0xFFFFFFFF
local HOOK_ID = "prettyui_tooltip"
local contexts = setmetatable({}, { __mode = "k" })

local function sprite(parent, spriteID)
    local component = ui.Sprite.new(parent)
    component.spriteID = spriteID
    component.clickthrough = true
    return component
end

local function normalize(value)
    if type(value) == "table" then return value end
    return { text = tostring(value or "") }
end

local function measure(text, options)
    local font = config.Font.MUSEO_SANS_15PT_REGULAR
    local maxWidth = options.maxWidth or DEFAULT_MAX_WIDTH
    local width = options.width
    if width == nil then
        local succeeded, textWidth = pcall(function() return font:GetStringWidth(text, false) end)
        width = math.min(maxWidth, (succeeded and textWidth or #text * 7) + PADDING_X * 2)
    end
    width = math.max(BORDER_SIZE * 2 + 1, width)

    local contentWidth = math.max(1, width - PADDING_X * 2)
    local height = options.height
    if height == nil then
        local succeeded, textHeight = pcall(function()
            return font:GetStringHeightAndLineCount(text, contentWidth, font.baseline, false, false, false)
        end)
        if succeeded then
            height = textHeight + PADDING_Y * 2
        else
            local lines = math.max(1, math.ceil((#text * 7) / contentWidth))
            height = lines * FALLBACK_LINE_HEIGHT + PADDING_Y * 2
        end
    end
    return width, math.max(BORDER_SIZE * 2 + 1, height)
end

local function placementOrder(preferred)
    if preferred == "left" then return { "left", "right", "below", "above" } end
    if preferred == "below" then return { "below", "above", "right", "left" } end
    if preferred == "above" then return { "above", "below", "right", "left" } end
    return { "right", "left", "below", "above" }
end

local function placedPosition(placement, targetX, targetY, targetWidth, targetHeight, width, height)
    if placement == "left" then return targetX - width - OFFSET, targetY end
    if placement == "below" then return targetX, targetY + targetHeight + OFFSET end
    if placement == "above" then return targetX, targetY - height - OFFSET end
    return targetX + targetWidth + OFFSET, targetY
end

local function fitsParent(x, y, width, height, parentWidth, parentHeight, margin)
    return x >= margin and y >= margin and
        x + width <= parentWidth - margin and y + height <= parentHeight - margin
end

function Tooltip.getContext(collection)
    return contexts[collection]
end

function Tooltip.registerContext(collection, parent, position, parentContext)
    local context = {
        collection = collection,
        parent = parent,
        position = position,
        parentContext = parentContext,
        children = {},
        tooltips = {},
        active = true,
    }
    contexts[collection] = context
    if parentContext then table.insert(parentContext.children, context) end
    return context
end

local function destroyContext(context)
    if context == nil or not context.active then return end
    context.active = false
    contexts[context.collection] = nil
    for index = #context.children, 1, -1 do
        destroyContext(context.children[index])
    end
    for index = #context.tooltips, 1, -1 do
        context.tooltips[index]:Destroy()
    end
    context.children = {}
    context.tooltips = {}
end

function Tooltip.unregisterContext(collection)
    destroyContext(contexts[collection])
end

local function moveContextTooltipsToFront(context)
    if context == nil or not context.active then return end
    for _, tooltip in ipairs(context.tooltips) do
        if tooltip.root ~= nil and tooltip.root.hidden ~= true then
            tooltip.root:MoveToFront()
        end
    end
    for _, child in ipairs(context.children) do
        moveContextTooltipsToFront(child)
    end
end

function Tooltip.moveContextTooltipsToFront(collection)
    moveContextTooltipsToFront(contexts[collection])
end

function Tooltip.attach(target, parent, value)
    if value == nil then return nil end
    local options = normalize(value)
    local text = tostring(options.text or "")
    local width, height = measure(text, options)

    local self = setmetatable({}, Tooltip)
    self.target = target
    self.targetClickthrough = target.clickthrough
    self.options = options
    self.width = width
    self.height = height
    self.context = options.parent == nil and contexts[parent] or nil
    self.parent = options.parent or (self.context and self.context.parent) or parent

    self.root = ui.Layer.new(self.parent)
    self.root:SetSize(width, height)
    self.root.hidden = true
    self.root.clickthrough = true

    local frame = Sprites.CONTENT_FRAME

    self.centre = sprite(self.root, frame.centre)
    self.centre:SetPos(BORDER_SIZE, BORDER_SIZE)
    self.centre:SetSize(-BORDER_SIZE * 2, -BORDER_SIZE * 2, 1.0, 1.0)
    self.centre.isTiling = true

    self.top = sprite(self.root, frame.top)
    self.top:SetPos(BORDER_SIZE, 0)
    self.top:SetSize(-BORDER_SIZE * 2, BORDER_SIZE, 1.0)
    self.top.isTiling = true

    self.bottom = sprite(self.root, frame.bottom)
    self.bottom:SetPos(BORDER_SIZE, -BORDER_SIZE, 0, 1.0)
    self.bottom:SetSize(-BORDER_SIZE * 2, BORDER_SIZE, 1.0)
    self.bottom.isTiling = true

    self.right = sprite(self.root, frame.right)
    self.right:SetPos(-BORDER_SIZE, BORDER_SIZE, 1.0)
    self.right:SetSize(BORDER_SIZE, -BORDER_SIZE * 2, 0, 1.0)
    self.right.isTiling = true

    self.left = sprite(self.root, frame.left)
    self.left:SetPos(0, BORDER_SIZE)
    self.left:SetSize(BORDER_SIZE, -BORDER_SIZE * 2, 0, 1.0)
    self.left.isTiling = true

    self.topRight = sprite(self.root, frame.topRight)
    self.topRight:SetPos(-BORDER_SIZE, 0, 1.0)
    self.topRight:SetSize(BORDER_SIZE, BORDER_SIZE)

    self.topLeft = sprite(self.root, frame.topLeft)
    self.topLeft:SetSize(BORDER_SIZE, BORDER_SIZE)

    self.bottomRight = sprite(self.root, frame.bottomRight)
    self.bottomRight:SetPos(-BORDER_SIZE, -BORDER_SIZE, 1.0, 1.0)
    self.bottomRight:SetSize(BORDER_SIZE, BORDER_SIZE)

    self.bottomLeft = sprite(self.root, frame.bottomLeft)
    self.bottomLeft:SetPos(0, -BORDER_SIZE, 0, 1.0)
    self.bottomLeft:SetSize(BORDER_SIZE, BORDER_SIZE)

    self.label = ui.Text.new(self.root)
    self.label:SetPos(PADDING_X, PADDING_Y)
    self.label:SetSize(-PADDING_X * 2, -PADDING_Y * 2, 1.0, 1.0)
    self.label.content = text
    self.label.font = id.Font.MUSEO_SANS_15PT_REGULAR
    self.label.rgba = TEXT_COLOUR
    self.label.maxLines = 0
    self.label.clickthrough = true

    target.clickthrough = false

    target:Subscribe(ui.Hook.ONMOUSEOVER, HOOK_ID, function()
        self:Show()
        return true
    end)
    target:Subscribe(ui.Hook.ONMOUSELEAVE, HOOK_ID, function()
        self:Hide()
        return true
    end)

    if self.context then table.insert(self.context.tooltips, self) end

    return self
end

function Tooltip:Show()
    local targetX = self.target.x or 0
    local targetY = self.target.y or 0
    if self.context and self.context.active then
        targetX, targetY = self.context.position(self.target)
    end
    local targetWidth = self.target.width or 0
    local targetHeight = self.target.height or 0
    local parentWidth = self.parent and (self.parent.width or 0) or 0
    local parentHeight = self.parent and (self.parent.height or 0) or 0
    local margin = self.options.boundsMargin or OFFSET
    local x, y
    for _, placement in ipairs(placementOrder(self.options.placement)) do
        local candidateX, candidateY = placedPosition(
            placement, targetX, targetY, targetWidth, targetHeight, self.width, self.height
        )
        x, y = candidateX, candidateY
        if parentWidth <= 0 or parentHeight <= 0 or
            fitsParent(x, y, self.width, self.height, parentWidth, parentHeight, margin) then
            break
        end
    end
    x = self.options.x or x
    y = self.options.y or y
    if self.options.constrainToParent ~= false and parentWidth > 0 and parentHeight > 0 then
        local maxX = math.max(margin, parentWidth - self.width - margin)
        local maxY = math.max(margin, parentHeight - self.height - margin)
        x = math.max(margin, math.min(x, maxX))
        y = math.max(margin, math.min(y, maxY))
    end
    self.root:SetPos(x, y)
    self.root.hidden = false
    self.root:MoveToFront()
end

function Tooltip:Hide()
    if self.root then self.root.hidden = true end
end

function Tooltip:Destroy()
    if self.target then
        self.target:Unsubscribe(ui.Hook.ONMOUSEOVER, HOOK_ID)
        self.target:Unsubscribe(ui.Hook.ONMOUSELEAVE, HOOK_ID)
        self.target.clickthrough = self.targetClickthrough
        self.target = nil
    end
    if self.root then
        self.root:Destroy()
        self.root = nil
    end
    self.parent = nil
    if self.context then
        local attachments = self.context.tooltips
        for index = #attachments, 1, -1 do
            if attachments[index] == self then
                table.remove(attachments, index)
                break
            end
        end
        self.context = nil
    end
end

return Tooltip
