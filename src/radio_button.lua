local SelectionButton = require("src/selection_button")

local RadioButton = {}

function RadioButton.getSize(choices, options)
    return SelectionButton.getSize("radio", choices, options)
end

function RadioButton.new(parent, choices, options)
    return SelectionButton.new("radio", parent, choices, options)
end

return RadioButton
