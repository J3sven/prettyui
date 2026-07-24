local FancyButton = require("src/fancy_button")
local SimpleButton = require("src/simple_button")
local Sprites = require("src/core/sprites")
local Tooltip = require("src/tooltip")

local ColourPicker = {}
ColourPicker.__index = ColourPicker

local BUTTON_SIZE = 24
local SWATCH_PROPORTION = 0.65
local DEFAULT_COLOUR = 0xFFFFFFFF
local WINDOW_WIDTH = 220
local WINDOW_HEIGHT = 300
local FIELD_SIZE = 128
local FIELD_X = 16
local FIELD_Y = 12
local HUE_WIDTH = 24
local HUE_X = 156
local HUE_Y = FIELD_Y
local PREVIEW_BUTTON_SIZE = 64
local PREVIEW_SWATCH_SIZE = math.floor(PREVIEW_BUTTON_SIZE * SWATCH_PROPORTION)
local PREVIEW_X = 70
local PREVIEW_Y = 152
local ACCEPT_Y = 224
local MARKER_SIZE = 9
local WHITE = 0xFFFFFFFF
local BLACK = 0x000000FF
local FRAME_COLOUR = 0x716B61FF

local HUE_COLOURS = {
    0xFF0000FF,
    0xFF00FFFF,
    0x0000FFFF,
    0x00FFFFFF,
    0x00FF00FF,
    0xFFFF00FF,
    0xFF0000FF,
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function copyOptions(options)
    local copy = {}
    if type(options) == "table" then
        for key, value in pairs(options) do copy[key] = value end
    end
    return copy
end

local function normaliseColour(value)
    value = math.floor(tonumber(value) or DEFAULT_COLOUR)
    return math.tointeger(clamp(value, 0, 0xFFFFFFFF)) or DEFAULT_COLOUR
end

local function unpackColour(colour)
    colour = normaliseColour(colour)
    return math.floor(colour / 0x1000000) % 0x100 / 255,
        math.floor(colour / 0x10000) % 0x100 / 255,
        math.floor(colour / 0x100) % 0x100 / 255,
        colour % 0x100
end

local function packColour(red, green, blue, alpha)
    local r = math.floor(clamp(red, 0, 1) * 255 + 0.5)
    local g = math.floor(clamp(green, 0, 1) * 255 + 0.5)
    local b = math.floor(clamp(blue, 0, 1) * 255 + 0.5)
    local a = clamp(math.floor(alpha or 255), 0, 255)
    return math.tointeger(r * 0x1000000 + g * 0x10000 + b * 0x100 + a)
end

local function rgbToHsv(red, green, blue)
    local maximum = math.max(red, green, blue)
    local minimum = math.min(red, green, blue)
    local delta = maximum - minimum
    local hue = 0
    if delta > 0 then
        if maximum == red then
            hue = ((green - blue) / delta) % 6
        elseif maximum == green then
            hue = (blue - red) / delta + 2
        else
            hue = (red - green) / delta + 4
        end
        hue = hue / 6
    end
    local saturation = maximum == 0 and 0 or delta / maximum
    return hue, saturation, maximum
end

local function hsvToRgb(hue, saturation, value)
    hue = (hue % 1) * 6
    local sector = math.floor(hue)
    local fraction = hue - sector
    local p = value * (1 - saturation)
    local q = value * (1 - fraction * saturation)
    local t = value * (1 - (1 - fraction) * saturation)
    sector = sector % 6
    if sector == 0 then return value, t, p end
    if sector == 1 then return q, value, p end
    if sector == 2 then return p, value, t end
    if sector == 3 then return p, q, value end
    if sector == 4 then return t, p, value end
    return value, p, q
end

local function hsvColour(hue, saturation, value, alpha)
    local red, green, blue = hsvToRgb(hue, saturation, value)
    return packColour(red, green, blue, alpha)
end

local function rectangle(parent, x, y, width, height, colour, fill)
    local component = ui.Rectangle.new(parent)
    component:SetPos(x, y)
    component:SetSize(width, height)
    component.fill = fill ~= false
    component.rgba = colour
    component.clickthrough = true
    return component
end

local function findOwnerWindow(context)
    while context do
        if context.ownerWindow then return context.ownerWindow end
        context = context.parentContext
    end
    return nil
end

function ColourPicker.getSize(options)
    options = options or {}
    local size = options.buttonSize or options.size or BUTTON_SIZE
    return options.width or size, options.height or size
end

function ColourPicker.new(parent, options)
    options = options or {}
    local self = setmetatable({}, ColourPicker)
    self.parent = parent
    self.options = copyOptions(options)
    self.onChange = options.onChange
    self.disabled = options.disabled == true
    self.colour = normaliseColour(
        options.value or options.colour or options.defaultColour
    )
    self.value = self.colour
    local context = Tooltip.getContext(parent)
    self.ownerWindow = options.ownerWindow or findOwnerWindow(context)
    self.windowParent = options.windowParent or options.overlayParent or
        (context and context.parent) or parent

    local buttonOptions = copyOptions(options)
    local width, height = ColourPicker.getSize(options)
    buttonOptions.width = width
    buttonOptions.height = height
    buttonOptions.size = nil
    buttonOptions.buttonSize = nil
    self.button = SimpleButton.new(parent, Sprites.CLOSE, function()
        self:Open()
    end, buttonOptions)
    self.root = self.button.root

    if self.button.content then self.button.content:Destroy() end
    local swatchSize = math.max(
        2,
        math.floor(math.min(width, height) * SWATCH_PROPORTION)
    )
    swatchSize = math.min(swatchSize, math.max(2, math.min(width, height) - 6))
    local swatchX = math.floor((width - swatchSize) / 2)
    local swatchY = math.floor((height - swatchSize) / 2)
    self.swatchFrame = rectangle(
        self.root, swatchX - 1, swatchY - 1, swatchSize + 2, swatchSize + 2, BLACK
    )
    self.swatch = rectangle(
        self.root, swatchX, swatchY, swatchSize, swatchSize, self.colour
    )
    self.button.content = self.swatch
    self:SetDisabled(self.disabled)
    return self
end

function ColourPicker:_PickerWindowBounds()
    local width = math.max(
        WINDOW_WIDTH,
        math.floor(self.options.windowWidth or WINDOW_WIDTH)
    )
    local height = math.max(
        WINDOW_HEIGHT,
        math.floor(self.options.windowHeight or WINDOW_HEIGHT)
    )
    local x = self.options.windowX or self.options.pickerX
    local y = self.options.windowY or self.options.pickerY
    local ownerRoot = self.ownerWindow and self.ownerWindow.root or nil
    if ownerRoot then
        if x == nil then
            x = (ownerRoot.x or 0) + math.floor(((ownerRoot.width or width) - width) / 2)
        end
        if y == nil then
            y = (ownerRoot.y or 0) + math.floor(((ownerRoot.height or height) - height) / 2)
        end
    end
    return x or 80, y or 80, width, height
end

function ColourPicker:_DrawHueSpectrum()
    self.hueCanvas:Clear()
    for index = 1, #HUE_COLOURS - 1 do
        local top = math.floor((index - 1) * FIELD_SIZE / (#HUE_COLOURS - 1))
        local bottom = math.floor(index * FIELD_SIZE / (#HUE_COLOURS - 1))
        self.hueCanvas:AddGradientV(
            0, top, HUE_WIDTH, bottom - top,
            HUE_COLOURS[index], HUE_COLOURS[index + 1]
        )
    end
end

function ColourPicker:_DrawColourField()
    self.fieldCanvas:Clear()
    for x = 0, FIELD_SIZE - 1 do
        local value = x / (FIELD_SIZE - 1)
        self.fieldCanvas:AddGradientV(
            x, 0, 1, FIELD_SIZE,
            hsvColour(self.pendingHue, 1, value, 255),
            hsvColour(self.pendingHue, 0, value, 255)
        )
    end
end

function ColourPicker:_UpdatePickerVisuals(redrawField)
    self.pendingColour = hsvColour(
        self.pendingHue, self.pendingSaturation, self.pendingValue, self.pendingAlpha
    )
    if redrawField then self:_DrawColourField() end

    local fieldMarkerX = math.floor(self.pendingValue * (FIELD_SIZE - 1) + 0.5)
    local fieldMarkerY = math.floor(
        (1 - self.pendingSaturation) * (FIELD_SIZE - 1) + 0.5
    )
    self.fieldMarkerHorizontal:SetPos(
        FIELD_X + fieldMarkerX - math.floor(MARKER_SIZE / 2),
        FIELD_Y + fieldMarkerY
    )
    self.fieldMarkerVertical:SetPos(
        FIELD_X + fieldMarkerX,
        FIELD_Y + fieldMarkerY - math.floor(MARKER_SIZE / 2)
    )

    local hueY = math.floor((1 - self.pendingHue) * (FIELD_SIZE - 1) + 0.5)
    self.hueMarkerShadow:SetY(HUE_Y + hueY - 2)
    self.hueMarker:SetY(HUE_Y + hueY - 1)
    self.preview.rgba = self.pendingColour
end

function ColourPicker:_SetPendingColour(colour)
    local red, green, blue, alpha = unpackColour(colour)
    self.pendingHue, self.pendingSaturation, self.pendingValue =
        rgbToHsv(red, green, blue)
    self.pendingAlpha = alpha
    self:_UpdatePickerVisuals(true)
end

function ColourPicker:_PickerContentPosition()
    return (self.pickerWindow.root.x or 0) + (self.pickerWindow.content.x or 0),
        (self.pickerWindow.root.y or 0) + (self.pickerWindow.content.y or 0)
end

function ColourPicker:_UpdateFieldFromMouse()
    local mouse = Mouse.GetPosition()
    if mouse == nil then return false end
    local contentX, contentY = self:_PickerContentPosition()
    self.pendingValue = clamp(
        (mouse.x - contentX - FIELD_X) / (FIELD_SIZE - 1), 0, 1
    )
    self.pendingSaturation = 1 - clamp(
        (mouse.y - contentY - FIELD_Y) / (FIELD_SIZE - 1), 0, 1
    )
    self:_UpdatePickerVisuals(false)
    return false
end

function ColourPicker:_UpdateHueFromMouse()
    local mouse = Mouse.GetPosition()
    if mouse == nil then return false end
    local _, contentY = self:_PickerContentPosition()
    local ratio = clamp((mouse.y - contentY - HUE_Y) / (FIELD_SIZE - 1), 0, 1)
    local hue = 1 - ratio
    local changed = hue ~= self.pendingHue
    self.pendingHue = hue
    self:_UpdatePickerVisuals(changed)
    return false
end

function ColourPicker:_BeginPickerDrag(kind)
    self.dragTarget = kind
    local layer = kind == "hue" and self.hueHit or self.fieldHit
    if kind == "hue" then
        self:_UpdateHueFromMouse()
    else
        self:_UpdateFieldFromMouse()
    end
    layer:SetPos(0, 0)
    layer:SetSize(0, 0, 1.0, 1.0)
    layer:MoveToFront()
    return false
end

function ColourPicker:_UpdatePickerDrag(kind)
    if self.dragTarget ~= kind then return false end
    if kind == "hue" then return self:_UpdateHueFromMouse() end
    return self:_UpdateFieldFromMouse()
end

function ColourPicker:_StopPickerDrag(kind)
    if self.dragTarget == kind then
        self:_UpdatePickerDrag(kind)
        self.dragTarget = nil
    end
    self.fieldHit:SetPos(FIELD_X, FIELD_Y)
    self.fieldHit:SetSize(FIELD_SIZE, FIELD_SIZE)
    self.hueHit:SetPos(HUE_X, HUE_Y)
    self.hueHit:SetSize(HUE_WIDTH, FIELD_SIZE)
    return false
end

function ColourPicker:_BindPickerDrag(layer, kind)
    layer:Subscribe(ui.Hook.ONCLICK, function() return self:_BeginPickerDrag(kind) end)
    layer:Subscribe(ui.Hook.ONHOLD, function() return self:_UpdatePickerDrag(kind) end)
    layer:Subscribe(ui.Hook.ONDRAG, function() return self:_UpdatePickerDrag(kind) end)
    layer:Subscribe(ui.Hook.ONRELEASE, function() return self:_StopPickerDrag(kind) end)
    layer:Subscribe(ui.Hook.ONDRAGCOMPLETE, function()
        return self:_StopPickerDrag(kind)
    end)
end

function ColourPicker:_ClearPickerReferences()
    self.dragTarget = nil
    self.pickerWindow = nil
    self.fieldCanvas = nil
    self.hueCanvas = nil
    self.fieldHit = nil
    self.hueHit = nil
    self.fieldMarkerHorizontal = nil
    self.fieldMarkerVertical = nil
    self.hueMarkerShadow = nil
    self.hueMarker = nil
    self.previewButton = nil
    self.preview = nil
    self.acceptButton = nil
end

function ColourPicker:Open()
    if self.disabled then return false end
    if self.pickerWindow and self.pickerWindow.root then
        self.pickerWindow:Show()
        return true
    end

    local Window = require("src/window")
    local pickerX, pickerY, pickerWidth, pickerHeight = self:_PickerWindowBounds()
    local picker
    picker = Window.new(self.windowParent, {
        title = self.options.windowTitle or self.options.title or "Colour picker",
        x = pickerX,
        y = pickerY,
        width = pickerWidth,
        height = pickerHeight,
        minWidth = WINDOW_WIDTH,
        minHeight = WINDOW_HEIGHT,
        destroyOnClose = true,
        onClose = function()
            if self.pickerWindow == picker then self:_ClearPickerReferences() end
        end,
    })
    self.pickerWindow = picker

    self.fieldCanvas = ui.Canvas.new(picker.content)
    self.fieldCanvas:SetPos(FIELD_X, FIELD_Y)
    self.fieldCanvas:SetSize(FIELD_SIZE, FIELD_SIZE)
    self.fieldCanvas.clickthrough = true

    self.hueCanvas = ui.Canvas.new(picker.content)
    self.hueCanvas:SetPos(HUE_X, HUE_Y)
    self.hueCanvas:SetSize(HUE_WIDTH, FIELD_SIZE)
    self.hueCanvas.clickthrough = true
    self:_DrawHueSpectrum()

    rectangle(
        picker.content, FIELD_X, FIELD_Y, FIELD_SIZE, FIELD_SIZE, FRAME_COLOUR, false
    )
    rectangle(
        picker.content, HUE_X, HUE_Y, HUE_WIDTH, FIELD_SIZE, FRAME_COLOUR, false
    )

    self.fieldMarkerHorizontal = rectangle(
        picker.content, FIELD_X, FIELD_Y, MARKER_SIZE, 1, WHITE
    )
    self.fieldMarkerVertical = rectangle(
        picker.content, FIELD_X, FIELD_Y, 1, MARKER_SIZE, WHITE
    )
    self.hueMarkerShadow = rectangle(
        picker.content, HUE_X - 3, HUE_Y, HUE_WIDTH + 6, 4, BLACK
    )
    self.hueMarker = rectangle(
        picker.content, HUE_X - 3, HUE_Y, HUE_WIDTH + 6, 2, WHITE
    )

    self.previewButton = picker:AddSimpleButton(
        Sprites.CLOSE,
        nil,
        {
            absolute = true,
            x = PREVIEW_X,
            y = PREVIEW_Y,
            width = PREVIEW_BUTTON_SIZE,
            height = PREVIEW_BUTTON_SIZE,
        }
    )
    if self.previewButton.content then self.previewButton.content:Destroy() end
    local previewInset = math.floor((PREVIEW_BUTTON_SIZE - PREVIEW_SWATCH_SIZE) / 2)
    self.preview = rectangle(
        self.previewButton.root,
        previewInset,
        previewInset,
        PREVIEW_SWATCH_SIZE,
        PREVIEW_SWATCH_SIZE,
        self.colour
    )
    self.previewButton.content = self.preview
    self.previewButton.root.enabled = false
    self.previewButton.root.clickthrough = true

    self.fieldHit = ui.Layer.new(picker.content)
    self.fieldHit:SetPos(FIELD_X, FIELD_Y)
    self.fieldHit:SetSize(FIELD_SIZE, FIELD_SIZE)
    self.fieldHit.clickthrough = false
    self.hueHit = ui.Layer.new(picker.content)
    self.hueHit:SetPos(HUE_X, HUE_Y)
    self.hueHit:SetSize(HUE_WIDTH, FIELD_SIZE)
    self.hueHit.clickthrough = false
    self:_BindPickerDrag(self.fieldHit, "field")
    self:_BindPickerDrag(self.hueHit, "hue")

    local acceptText = self.options.acceptText or "Accept"
    local acceptWidth = FancyButton.getSize(acceptText, {
        width = self.options.acceptWidth or 126,
    })
    self.acceptButton = picker:AddFancyButton(acceptText, function()
        self:SetValue(self.pendingColour)
        if self.pickerWindow == picker then picker:Close() end
    end, {
        absolute = true,
        x = math.floor((picker.content.width - acceptWidth) / 2),
        y = ACCEPT_Y,
        width = acceptWidth,
        variant = self.options.acceptVariant or "positive",
    })

    self:_SetPendingColour(self.colour)
    self.fieldHit:MoveToFront()
    self.hueHit:MoveToFront()
    return true
end

function ColourPicker:GetValue()
    return self.colour
end

function ColourPicker:SetValue(colour, notify)
    colour = normaliseColour(colour)
    local changed = colour ~= self.colour
    self.colour = colour
    self.value = colour
    if self.swatch then
        self.swatch.rgba = colour
        self.swatch:MoveToFront()
    end
    if self.pickerWindow and self.pickerWindow.root then self:_SetPendingColour(colour) end
    if changed and notify ~= false and self.onChange then self.onChange(self, colour) end
    return changed
end

ColourPicker.GetColour = ColourPicker.GetValue
ColourPicker.SetColour = ColourPicker.SetValue

function ColourPicker:SetDisabled(disabled)
    self.disabled = disabled == true
    self.button:SetDisabled(self.disabled)
end

function ColourPicker:Close()
    if self.pickerWindow then self.pickerWindow:Close() end
end

function ColourPicker:Destroy()
    if self.pickerWindow then
        self.pickerWindow:Destroy()
        self:_ClearPickerReferences()
    end
    if self.button then
        self.button:Destroy()
        self.button = nil
    end
    self.root = nil
    self.parent = nil
    self.ownerWindow = nil
    self.windowParent = nil
    self.onChange = nil
end

return ColourPicker
