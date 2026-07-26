local TextField = require("src/text_field")
local RibbonBar = require("src/ribbon_bar")
local BuffBar = require("src/buff_bar")

local resources = Plugin.resources
TextField.SetDefaultSprite(resources and (resources.input_default or resources["input_default.png"]))

local PrettyUI = {
    AchievementPopup = require("src/achievement_popup"),
    AnchoredTooltip = require("src/anchored_tooltip"),
    BigSpinner = require("src/big_spinner"),
    CheckboxButton = require("src/checkbox_button"),
    ColourPicker = require("src/colour_picker"),
    ComboBox = require("src/combo_box"),
    CollapseButton = require("src/collapse_button"),
    Divider = require("src/divider"),
    FancyButton = require("src/fancy_button"),
    ItemSlot = require("src/item_slot"),
    ItemGrid = require("src/item_grid"),
    List = require("src/list"),
    Panel = require("src/panel"),
    Sprites = require("src/core/sprites"),
    RibbonButton = require("src/ribbon_button"),
    RibbonBar = RibbonBar,
    RadioButton = require("src/radio_button"),
    SimpleButton = require("src/simple_button"),
    Slider = require("src/slider"),
    SpriteButton = require("src/sprite_button"),
    Spinner = require("src/spinner"),
    Tabs = require("src/tabs"),
    Text = require("src/text"),
    TextField = TextField,
    Tooltip = require("src/tooltip"),
    Window = require("src/window"),
    Scrollbar = require("src/scrollbar"),
    SimpleView = require("src/simple_view"),
    BuffBar = BuffBar,
}

PrettyUI.version = "0.1.0"

RibbonBar.Start()

function PluginShutdown()
    RibbonBar.Shutdown()
    BuffBar.Shutdown()
end

return PrettyUI
