local SelectionButton = require("src/selection_button")

local CheckboxButton = {}

function CheckboxButton.getSize(choices, options)
    return SelectionButton.getSize("checkbox", choices, options)
end

function CheckboxButton.new(parent, choices, options)
    return SelectionButton.new("checkbox", parent, choices, options)
end

return CheckboxButton
