local Sprites = require("src/core/sprites")
local Tooltip = require("src/tooltip")
local Wheel = require("src/core/wheel")

local Spinner = {}
Spinner.__index = Spinner

local FRAMES = Sprites.LOADING_SPINNER_FRAMES
local FRAME_COUNT = #FRAMES
local DEFAULT_SIZE = 29
local DEFAULT_LOGIC_UPDATES_PER_FRAME = 5
local nextInstanceID = 0

local function normaliseLogicUpdates(value)
    return math.max(1, math.floor(value or DEFAULT_LOGIC_UPDATES_PER_FRAME))
end

function Spinner.new(parent, options)
    options = options or {}

    nextInstanceID = nextInstanceID + 1

    local self = setmetatable({}, Spinner)
    self.eventID = "prettyui_spinner_" .. tostring(nextInstanceID)
    self.frame = 1
    self.logicUpdateAccumulator = 0
    self.logicUpdatesPerFrame = normaliseLogicUpdates(options.logicUpdatesPerFrame)
    self.running = false

    self.interfaceID = parent.interfaceID
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
    Tooltip.bind(self, self.root, parent, options.tooltip)

    if options.autoPlay ~= false then self:Start() end
    return self
end

function Spinner:SetFrame(frame)
    self.frame = ((math.floor(frame) - 1) % FRAME_COUNT) + 1
    if self.root then self.root.spriteID = FRAMES[self.frame] end
end

function Spinner:SetLogicUpdatesPerFrame(updates)
    self.logicUpdatesPerFrame = normaliseLogicUpdates(updates)
    self.logicUpdateAccumulator = 0
end

function Spinner:SetTooltip(value)
    return Tooltip.set(self, value)
end

function Spinner:Start()
    if self.running or self.root == nil then return end

    self.running = true
    self.logicUpdateAccumulator = 0
    Event.Logic.Subscribe(self.eventID, function()
        self.logicUpdateAccumulator = self.logicUpdateAccumulator + 1
        if self.logicUpdateAccumulator >= self.logicUpdatesPerFrame then
            self.logicUpdateAccumulator = 0
            self:SetFrame(self.frame + 1)
        end
    end)
end

function Spinner:Stop()
    if not self.running then return end
    Event.Logic.Unsubscribe(self.eventID)
    self.running = false
    self.logicUpdateAccumulator = 0
end

function Spinner:Reset()
    self.logicUpdateAccumulator = 0
    self:SetFrame(1)
end

function Spinner:Destroy()
    self:Stop()
    Tooltip.unbind(self)
    if self.root then
        if ui.Interfaces:GetInterface(self.interfaceID) ~= nil then self.root:Destroy() end
        self.root = nil
    end
end

return Spinner
