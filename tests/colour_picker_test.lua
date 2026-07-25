local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local mousePosition
local lastWindowOptions

local function component(parent, kind)
    local result = {
        kind = kind,
        hidden = false,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        subscriptions = {},
    }
    function result:SetPos(x, y)
        self.x, self.y = x, y
    end
    function result:SetSize(width, height)
        self.width, self.height = width, height
    end
    function result:SetX(x) self.x = x end
    function result:SetY(y) self.y = y end
    function result:Subscribe(hook, callback)
        self.subscriptions[hook] = callback
    end
    function result:Unsubscribe(hook)
        self.subscriptions[hook] = nil
    end
    function result:MoveToFront() self.movedToFront = true end
    function result:Destroy() self.destroyed = true end
    if parent then
        parent.children = parent.children or {}
        table.insert(parent.children, result)
    end
    return result
end

local function canvas(parent)
    local result = component(parent, "canvas")
    result.rectangles = {}
    function result:Clear()
        self.rectangles = {}
        self.horizontalGradient = nil
        self.verticalGradients = {}
    end
    function result:AddRectangle(x, y, width, height, colour)
        table.insert(self.rectangles, {
            x = x, y = y, width = width, height = height, colour = colour,
        })
    end
    function result:AddGradientH(x, y, width, height, startColour, endColour)
        self.horizontalGradient = {
            x = x, y = y, width = width, height = height,
            startColour = startColour, endColour = endColour,
        }
    end
    function result:AddGradientV(x, y, width, height, startColour, endColour)
        table.insert(self.verticalGradients, {
            x = x, y = y, width = width, height = height,
            startColour = startColour, endColour = endColour,
        })
    end
    return result
end

local function simpleButton(parent, options)
    local root = component(parent, "button")
    root:SetPos(options and options.x or 0, options and options.y or 0)
    root:SetSize(options and options.width or 24, options and options.height or 24)
    local content = component(root, "button-content")
    return {
        root = root,
        content = content,
        SetDisabled = function(self, disabled) self.disabled = disabled end,
        SetHoverCursor = function() end,
        Destroy = function(self) self.root:Destroy() end,
    }
end

ui = {
    Rectangle = { new = function(parent) return component(parent, "rectangle") end },
    Canvas = { new = canvas },
    Layer = { new = function(parent) return component(parent, "layer") end },
    Hook = {
        ONCLICK = 1,
        ONHOLD = 2,
        ONDRAG = 3,
        ONRELEASE = 4,
        ONDRAGCOMPLETE = 5,
        ONMOUSEOVER = 6,
        ONMOUSELEAVE = 7,
    },
}

package.loaded["src/fancy_button"] = {
    getSize = function(_, options) return options.width end,
}
local mouseCaptureOrigins = {}
package.loaded["src/core/mouse"] = {
    GetPosition = function(component, x, y)
        if component and x ~= nil and y ~= nil then
            local origin = mouseCaptureOrigins[component] or component
            return { x = origin.x + x, y = origin.y + y }
        end
        return mousePosition
    end,
    BeginCapture = function(component)
        mouseCaptureOrigins[component] = { x = component.x, y = component.y }
    end,
    EndCapture = function(component)
        mouseCaptureOrigins[component] = nil
    end,
}
package.loaded["src/simple_button"] = {
    new = function(parent, _, _, options) return simpleButton(parent, options) end,
}
package.loaded["src/core/sprites"] = { CLOSE = 1 }
package.loaded["src/tooltip"] = {
    getContext = function() return nil end,
}
package.loaded["src/window"] = {
    new = function(parent, options)
        lastWindowOptions = options
        local root = component(parent, "window")
        root:SetPos(options.x, options.y)
        root:SetSize(options.width, options.height)
        local content = component(root, "window-content")
        content:SetPos(8, 32)
        content:SetSize(options.width - 16, options.height - 40)
        local window = {
            root = root,
            content = content,
            AddSimpleButton = function(_, _, _, buttonOptions)
                return simpleButton(content, buttonOptions)
            end,
            AddFancyButton = function(_, _, action, buttonOptions)
                local button = simpleButton(content, buttonOptions)
                button.action = action
                return button
            end,
            Show = function() end,
            Close = function() end,
            Destroy = function() end,
        }
        return window
    end,
}

package.loaded["src/colour_picker"] = nil
local ColourPicker = require("src/colour_picker")
local parent = component(nil, "parent")

local standard = ColourPicker.new(parent, { value = 0x33669980 })
expect(standard:Open(), true, "a standard picker opens")
expect(lastWindowOptions.height, 300, "the standard picker keeps its original height")
expect(standard.alphaCanvas, nil, "the alpha slider is opt-in")

mousePosition = { x = 1000, y = 1000 }
standard.fieldHit.subscriptions[ui.Hook.ONCLICK](standard.fieldHit, 63, 63)
expect(
    standard.fieldMarkerVertical.x,
    79,
    "the field marker uses the hook's component-local x coordinate"
)
expect(
    standard.fieldMarkerHorizontal.y,
    75,
    "the field marker uses the hook's component-local y coordinate"
)
standard.fieldHit.subscriptions[ui.Hook.ONRELEASE](standard.fieldHit, 63, 63)

local accepted
local picker = ColourPicker.new(parent, {
    value = 0x33669980,
    alphaSlider = true,
    onChange = function(_, colour) accepted = colour end,
})
expect(picker:Open(), true, "an alpha picker opens")
expect(lastWindowOptions.height, 336, "the alpha picker makes room below the palette")
expect(picker.alphaCanvas.x, 16, "the alpha bar aligns with the palette")
expect(picker.alphaCanvas.y, 152, "the alpha bar sits below the palette")
expect(picker.alphaCanvas.width, 128, "the alpha bar matches the palette width")
expect(picker.alphaCanvas.height, 24, "the alpha bar matches the hue bar thickness")
expect(#picker.alphaCheckerCanvas.rectangles, 48, "the alpha bar draws a checkerboard")
expect(
    picker.alphaCanvas.horizontalGradient.startColour,
    0x33669900,
    "the alpha gradient starts transparent"
)
expect(
    picker.alphaCanvas.horizontalGradient.endColour,
    0x336699FF,
    "the alpha gradient ends opaque"
)
expect(picker.alphaMarker.x, 79, "the alpha marker reflects the initial alpha")

local contentX = picker.pickerWindow.root.x + picker.pickerWindow.content.x
mousePosition = { x = contentX, y = 0 }
picker.alphaHit.subscriptions[ui.Hook.ONCLICK](picker.alphaHit, 127, 12)
expect(picker.dragTarget, "alpha", "pressing the alpha bar begins an alpha drag")
expect(picker.alphaHit.width, 128, "the hit area remains stable on the initial click")
picker.alphaHit.subscriptions[ui.Hook.ONHOLD](picker.alphaHit, 127, 12)
expect(picker.alphaHit.width, 0, "the drag target expands across the picker")
expect(picker.pendingColour, 0x336699FF, "the right edge selects full opacity")

picker.alphaHit.subscriptions[ui.Hook.ONRELEASE](picker.alphaHit, 0, 12)
expect(picker.dragTarget, nil, "releasing the alpha bar ends the drag")
expect(picker.alphaHit.x, 16, "the alpha hit area returns to the bar")
expect(picker.alphaHit.width, 128, "the alpha hit area restores its width")
expect(picker.pendingColour, 0x33669900, "the left edge selects full transparency")

picker.acceptButton.action()
expect(accepted, 0x33669900, "accepting reports the selected alpha")

print("colour_picker_test: ok")
