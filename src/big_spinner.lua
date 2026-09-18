local Sprites = require("src/core/sprites")
local Tooltip = require("src/tooltip")
local Wheel = require("src/core/wheel")

local BigSpinner = {}
BigSpinner.__index = BigSpinner

local DEFAULT_SIZE = 72
local DEFAULT_DEGREES_PER_TICK = -6
local nextInstanceID = 0

local function rotation(value)
    return (tonumber(value) or 0) % 360
end

function BigSpinner.new(parent, options)
    options = options or {}
    nextInstanceID = nextInstanceID + 1

    local self = setmetatable({}, BigSpinner)
    self.eventID = "prettyui_big_spinner_" .. tostring(nextInstanceID)
    self.degreesPerTick = tonumber(options.degreesPerTick) or DEFAULT_DEGREES_PER_TICK
    self.rotation = rotation(options.rotation)
    self.running = false

    self.interfaceID = parent.interfaceID
    self.root = ui.Layer.new(parent)
    self.root:SetPos(
        options.x or 0,
        options.y or 0,
        options.xAnchor or 0,
        options.yAnchor or 0
    )
    self.root:SetSize(options.width or options.size or DEFAULT_SIZE, options.height or options.size or DEFAULT_SIZE)
    self.root.clickthrough = true
    Wheel.bind(self.root, options)

    self.backdrop = ui.Sprite.new(self.root)
    self.backdrop:SetSize(0, 0, 1.0, 1.0)
    self.backdrop.spriteID = Sprites.BIG_SPINNER_BACKDROP
    self.backdrop.clickthrough = true

    self.rotating = ui.Sprite.new(self.root)
    self.rotating:SetSize(0, 0, 1.0, 1.0)
    self.rotating.spriteID = Sprites.BIG_SPINNER_ROTATING
    self.rotating.rotationDegrees = self.rotation
    self.rotating.clickthrough = true

    Tooltip.bind(self, self.root, parent, options.tooltip)
    if options.autoPlay ~= false then self:Start() end
    return self
end

function BigSpinner:SetRotation(degrees)
    self.rotation = rotation(degrees)
    if self.rotating then self.rotating.rotationDegrees = self.rotation end
end

function BigSpinner:SetDegreesPerTick(degrees)
    self.degreesPerTick = tonumber(degrees) or DEFAULT_DEGREES_PER_TICK
end

function BigSpinner:SetTooltip(value)
    return Tooltip.set(self, value)
end

function BigSpinner:Start()
    if self.running or self.root == nil then return end
    self.running = true
    Event.Logic.Subscribe(self.eventID, function()
        self:SetRotation(self.rotation + self.degreesPerTick)
    end)
end

function BigSpinner:Stop()
    if not self.running then return end
    Event.Logic.Unsubscribe(self.eventID)
    self.running = false
end

function BigSpinner:Reset()
    self:SetRotation(0)
end

function BigSpinner:Destroy()
    self:Stop()
    Tooltip.unbind(self)
    if self.root then
        if ui.Interfaces:GetInterface(self.interfaceID) ~= nil then self.root:Destroy() end
        self.root = nil
        self.backdrop = nil
        self.rotating = nil
    end
end

return BigSpinner
