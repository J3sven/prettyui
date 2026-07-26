local SimpleView = require("src/simple_view")

local Scrollbar = {}
Scrollbar.__index = Scrollbar
setmetatable(Scrollbar, { __index = SimpleView })

local deprecationLogged = false

local function warnDeprecated()
    if deprecationLogged then return end
    deprecationLogged = true
    if type(log) == "function" then
        log(
            "PrettyUI.Scrollbar is deprecated and will be removed in v1.0.0; " ..
            "content wrappers are scrollable by default."
        )
    end
end

function Scrollbar.new(parent, options)
    warnDeprecated()
    local self = SimpleView.new(parent, options)
    setmetatable(self, Scrollbar)
    return self
end

return Scrollbar
