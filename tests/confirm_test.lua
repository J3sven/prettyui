local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

local function expectTrue(actual, message)
    if actual ~= true then
        error(message .. ": expected true, got " .. tostring(actual))
    end
end

local function expectFalse(actual, message)
    if actual then
        error(message .. ": expected false, got " .. tostring(actual))
    end
end

Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }

local windows = {}

local function fakeLayer(parent)
    local layer = { parent = parent, clickthrough = false, destroyed = false }
    function layer:SetPos() end
    function layer:SetSize() end
    function layer:MoveToFront() end
    function layer:Destroy()
        self.destroyed = true
    end
    return layer
end

local function fakeRect(parent)
    local rect = { parent = parent, fill = false, clickthrough = false, colour = nil }
    function rect:SetPos() end
    function rect:SetSize() end
    return rect
end

local function fakeWindow(parent, options)
    local window = {
        parent = parent,
        options = options,
        title = options.title,
        onClose = options.onClose,
        destroyOnClose = options.destroyOnClose == true,
        buttons = {},
        texts = {},
        destroyed = false,
    }
    function window:AddText(text)
        self.texts[#self.texts + 1] = text
    end
    function window:AddFancyButton(label, action, opts)
        local button = { label = label, action = action, opts = opts or {} }
        self.buttons[#self.buttons + 1] = button
        return button
    end
    function window:Show() end
    function window:Close()
        if self.onClose then self.onClose(self) end
        if self.destroyOnClose then self:Destroy() end
    end
    function window:Destroy()
        self.destroyed = true
    end
    windows[#windows + 1] = window
    return window
end

ui = {
    Layer = { new = fakeLayer },
    Rectangle = { new = fakeRect },
}

package.loaded["src/window"] = { new = fakeWindow }
package.loaded["src/fancy_button"] = {
    getSize = function(_text, _opts) return 80, 27 end,
}
package.loaded["src/dialog"] = nil
package.loaded["src/confirm"] = nil

local Dialog = require("src/dialog")
local Confirm = require("src/confirm")

local function button(window, label)
    for _, item in ipairs(window.buttons) do
        if item.label == label then return item end
    end
    return nil
end

local parent = { id = "c" }

local resolved = Confirm.resolve({})
expect(resolved.title, Confirm.DEFAULT_TITLE, "resolve title")
expect(resolved.confirmLabel, Confirm.DEFAULT_CONFIRM_LABEL, "resolve confirm")
expect(resolved.cancelLabel, Confirm.DEFAULT_CANCEL_LABEL, "resolve cancel")
expect(resolved.confirmVariant, Confirm.DEFAULT_CONFIRM_VARIANT, "resolve variant")
expectTrue(resolved.modal, "resolve modal")

Dialog.dismissAll(parent)
local saw = {}
local dialog = Confirm.new(parent, {
    body = "Delete?",
    onConfirm = function()
        saw[#saw + 1] = "ok"
    end,
    onCancel = function()
        saw[#saw + 1] = "no"
    end,
})
expect(dialog.window.texts[1], "Delete?", "confirm body")
button(dialog.window, "CANCEL").action()
expect(#saw, 1, "cancel callback count")
expect(saw[1], "no", "cancel callback")
expect(Dialog.depth(parent), 0, "cancel pops")

saw = {}
dialog = Confirm.new(parent, {
    onConfirm = function()
        saw[#saw + 1] = "ok"
    end,
    onCancel = function()
        saw[#saw + 1] = "no"
    end,
})
button(dialog.window, "CONFIRM").action()
expect(#saw, 1, "confirm callback count")
expect(saw[1], "ok", "confirm callback")
expect(Dialog.depth(parent), 0, "confirm pops")

saw = {}
dialog = Confirm.new(parent, {
    onConfirm = function() saw[#saw + 1] = "ok" end,
    onCancel = function() saw[#saw + 1] = "no" end,
})
dialog.window:Close()
expect(#saw, 1, "X callback count")
expect(saw[1], "no", "X is cancel")
expect(Dialog.depth(parent), 0, "X pops")

dialog = Confirm.new(parent, {
    onConfirm = function() return false end,
})
button(dialog.window, "CONFIRM").action()
expect(Dialog.depth(parent), 1, "false onConfirm stays")
expectFalse(dialog.window.destroyed, "false onConfirm does not destroy")
Dialog.dismissAll(parent)

print("confirm_test: ok")
