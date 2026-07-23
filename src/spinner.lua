local Sprites = require("src/core/sprites")
local Tooltip = require("src/tooltip")
local Wheel = require("src/core/wheel")

local Spinner = {}
Spinner.__index = Spinner

local FRAMES = Sprites.LOADING_SPINNER_FRAMES
local FRAME_COUNT = #FRAMES
local DEFAULT_SIZE = 29
local DEFAULT_TICKS_PER_FRAME = 5
local nextInstanceID = 0

local function clampTicks(value)
    return math.max(1, math.floor(value or DEFAULT_TICKS_PER_FRAME))
end

function Spinner.new(parent, options)
    options = options or {}

    nextInstanceID = nextInstanceID + 1

    local self = setmetatable({}, Spinner)
    self.eventID = "prettyui_spinner_" .. tostring(nextInstanceID)
    self.frame = 1
    self.tickAccumulator = 0
    self.ticksPerFrame = clampTicks(options.ticksPerFrame)
    self.running = false

    self.root = ui.Sprite.new(parent)
    self.root:SetPos(
        options.x or 0,
        options.y or 0,
        options.xAnchor or 0,
        options.yAnchor or 0
    )
    self.root:SetSize(options.width or options.size or DEFAULT_SIZE, options.height or options.size or DEFAULT_SIZE)
    self.root.spriteID = FRAMES[1]
    self.root.clickthrough = true
    Wheel.bind(self.root, options)
    self.tooltip = Tooltip.attach(self.root, parent, options.tooltip)

    if options.autoPlay ~= false then self:Start() end
    return self
end

function Spinner:SetFrame(frame)
    self.frame = ((math.floor(frame) - 1) % FRAME_COUNT) + 1
    if self.root then self.root.spriteID = FRAMES[self.frame] end
end

function Spinner:SetTicksPerFrame(ticks)
    self.ticksPerFrame = clampTicks(ticks)
    self.tickAccumulator = 0
end

function Spinner:Start()
    if self.running or self.root == nil then return end

    self.running = true
    self.tickAccumulator = 0
    Event.Logic.Subscribe(self.eventID, function()
        self.tickAccumulator = self.tickAccumulator + 1
        if self.tickAccumulator >= self.ticksPerFrame then
            self.tickAccumulator = 0
            self:SetFrame(self.frame + 1)
        end
    end)
end

function Spinner:Stop()
    if not self.running then return end
    Event.Logic.Unsubscribe(self.eventID)
    self.running = false
    self.tickAccumulator = 0
end

function Spinner:Reset()
    self.tickAccumulator = 0
    self:SetFrame(1)
end

function Spinner:Destroy()
    self:Stop()
    if self.tooltip then
        self.tooltip:Destroy()
        self.tooltip = nil
    end
    if self.root then
        self.root:Destroy()
        self.root = nil
    end
end

return Spinner
