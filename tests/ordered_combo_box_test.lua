local Interfaces = require("tests/interface_fixture")

local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function component()
    local result = {
        text = {},
        containerSprite = {},
        hooks = {},
        width = 0,
        height = 0,
    }
    function result:SetPos(x, y) self.x, self.y = x, y end
    function result:SetSize(width, height) self.width, self.height = width, height end
    function result:Setup() end
    function result:Subscribe(hook, callback) self.hooks[hook] = callback end
    function result:MoveToFront() self.movedToFront = true end
    function result:Destroy() self.destroyed = true end
    return Interfaces.component(result)
end

ui = {
    Layer = { new = function() return component() end },
    ComboField = { new = function() return component() end },
    InputField = { new = function() return component() end },
    Margin = { new = function() return {} end },
    Hook = { ONCLICK = 1, ONCONTENTCHANGED = 2 },
    TextContentVisibilityMode = { VISIBLE = 1 },
    InputFieldFilterMode = { NONE = 1 },
    InputFieldKeyHandlingMode = { DEFAULT = 1 },
    InputFieldActionResult = {
        CONTENT_CHANGE = 1,
        SUBMIT = 2,
        SUBMIT_ON_ESCAPE = 3,
        SUBMIT_ON_FOCUS_LOSS = 4,
    },
    SelectionChangeEvent = { SELECTED = 1 },
}
id = {
    StyleSheet = { COMBO_DEFAULT = 1, INPUT_DEFAULT = 2 },
    Font = { MUSEO_SANS_15PT_REGULAR = 1 },
}

local FakeList = {}
FakeList.__index = FakeList
function FakeList.new(_, options)
    local self = setmetatable({ root = component(), options = options }, FakeList)
    self.entries = {}
    return self
end
function FakeList:SetEntries(entries)
    self.entries = {}
    for _, entry in ipairs(entries) do
        self.entries[entry.id] = { label = entry.label, visible = true, selected = false }
    end
end
function FakeList:SetEntryVisible(entryID, visible)
    self.entries[entryID].visible = visible
    return true
end
function FakeList:SetSelected(entryID, selected)
    for _, entry in pairs(self.entries) do entry.selected = false end
    self.entries[entryID].selected = selected
    return true
end
function FakeList:SetScrollPosition(value) self.scrollY = value end
function FakeList:SetSize(width, height) self.root:SetSize(width, height) end
function FakeList:SetDisabled(value) self.disabled = value end
function FakeList:Clear() self.entries = {} end
function FakeList:Destroy() self.root:Destroy() end
function FakeList:Click(entryID)
    self.options._onEntryClick(self, entryID, true)
end

package.loaded["src/list"] = FakeList
package.loaded["src/core/control_palette"] = {
    TEXT = 1,
    DISABLED_TEXT = 2,
    CARET = 3,
    SELECTED = 4,
}
package.loaded["src/core/wheel"] = { bind = function() end }
package.loaded["src/tooltip"] = {
    getContext = function() return nil end,
    bind = function() end,
    set = function() return true end,
    unbind = function() end,
}
package.loaded["src/ordered_combo_box"] = nil

local OrderedComboBox = require("src/ordered_combo_box")
local changes = {}
local combo = OrderedComboBox.new(component(), {
    entries = {
        { label = "Zulu", id = 10 },
        { label = "Beta", id = 20, order = 2 },
        { label = "Alpha", id = 30, order = 2 },
        { label = "First", id = 40, order = 1 },
    },
    selectedID = 20,
    onChange = function(_, entryID, label, eventType)
        changes[#changes + 1] = { entryID, label, eventType }
    end,
})

expect(combo.entries[1].label, "First", "lowest order appears first")
expect(combo.entries[2].label, "Alpha", "equal orders sort alphabetically")
expect(combo.entries[4].label, "Zulu", "unordered entries appear last")
expect(combo:GetSelectedID(), 20, "constructor preserves selected ID")
expect(combo:GetSelectedLabel(), "Beta", "constructor preserves selected label")
expect(combo.input.content, "Beta", "closed input displays selected label")
expect(combo.input.stylesheetID, id.StyleSheet.INPUT_DEFAULT,
    "header input uses the native input text configuration")

combo:_Open()
expect(combo.open, true, "opening shows custom dropdown")
expect(combo.dropdown.root.hidden, false, "open dropdown is visible")
combo.input.hooks[ui.Hook.ONCONTENTCHANGED](combo.input, ui.InputFieldActionResult.CONTENT_CHANGE, "alp")
expect(combo.dropdown.entries[30].visible, true, "filter keeps matching entry")
expect(combo.dropdown.entries[20].visible, false, "filter hides non-matching entry")

combo.dropdown:Click(30)
expect(combo:GetSelectedID(), 30, "row click changes selection")
expect(combo:GetSelectedLabel(), "Alpha", "row click restores clean label")
expect(combo.open, false, "row click closes dropdown")
expect(changes[1][1], 30, "row click reports selected ID")
expect(changes[1][2], "Alpha", "row click reports selected label")
combo.input.hooks[ui.Hook.ONCONTENTCHANGED](
    combo.input,
    ui.InputFieldActionResult.CONTENT_CHANGE,
    "Alpha"
)
expect(combo.open, false, "programmatic selected-label event does not reopen dropdown")
expect(#combo._pendingInputContents, 0, "acknowledgement clears skipped intermediate values")

expect(combo:Select(40, false), true, "programmatic selection succeeds")
expect(#changes, 1, "silent programmatic selection does not emit callback")
combo:SetDisabled(true)
expect(combo.input.enabled, false, "disabled state reaches input")
expect(combo.dropdown.disabled, true, "disabled state reaches dropdown")

local validOrder, orderError = pcall(function()
    OrderedComboBox.sortEntries({ { label = "Invalid", order = 1.5 } })
end)
expect(validOrder, false, "fractional order is rejected")
expect(orderError:find("must be an integer", 1, true) ~= nil, true,
    "invalid order explains the requirement")

combo:Destroy()
expect(combo.root, nil, "destroy releases root")
print("ordered_combo_box_test: ok")
