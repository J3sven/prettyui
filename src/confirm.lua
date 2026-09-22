local Dialog = require("src/dialog")

local Confirm = {}

Confirm.DEFAULT_TITLE = "CONFIRM"
Confirm.DEFAULT_CONFIRM_LABEL = "CONFIRM"
Confirm.DEFAULT_CANCEL_LABEL = "CANCEL"
Confirm.DEFAULT_CONFIRM_VARIANT = "positive"
Confirm.DEFAULT_WIDTH = Dialog.DEFAULT_WIDTH
Confirm.DEFAULT_HEIGHT = Dialog.DEFAULT_HEIGHT

function Confirm.resolve(options)
    options = options or {}
    return {
        title = options.title or Confirm.DEFAULT_TITLE,
        body = options.body or "",
        cancelLabel = options.cancelLabel or Confirm.DEFAULT_CANCEL_LABEL,
        confirmLabel = options.confirmLabel or Confirm.DEFAULT_CONFIRM_LABEL,
        confirmVariant = options.confirmVariant or Confirm.DEFAULT_CONFIRM_VARIANT,
        width = options.width or Confirm.DEFAULT_WIDTH,
        height = options.height or Confirm.DEFAULT_HEIGHT,
        modal = options.modal ~= false,
        onConfirm = options.onConfirm,
        onCancel = options.onCancel,
    }
end

local function shouldClose(result)
    return result ~= false
end

function Confirm.new(parent, options)
    options = Confirm.resolve(options)
    local body = options.body
    return Dialog.new(parent, {
        title = options.title,
        width = options.width,
        height = options.height,
        modal = options.modal,
        onDismiss = function()
            if options.onCancel ~= nil then options.onCancel() end
        end,
        content = function(window)
            window:AddText(body)
        end,
        actions = {
            {
                label = options.cancelLabel,
                variant = "neutral",
                onClick = function()
                    if options.onCancel == nil then return true end
                    return shouldClose(options.onCancel())
                end,
            },
            {
                label = options.confirmLabel,
                variant = options.confirmVariant,
                onClick = function()
                    if options.onConfirm == nil then return true end
                    return shouldClose(options.onConfirm())
                end,
            },
        },
    })
end

return Confirm
