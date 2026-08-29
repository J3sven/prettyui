local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

id = {
    Sprite = setmetatable({}, {
        __index = function(_, name) return name end,
    }),
}

package.loaded["src/core/sprites"] = nil
local Sprites = require("src/core/sprites")

expect(Sprites.SCROLL_ARROW_UP, "SCROLLBAR_V2_0", "scrollbar uses V2 up arrow")
expect(Sprites.SCROLL_ARROW_DOWN, "SCROLLBAR_V2_1", "scrollbar uses V2 down arrow")
expect(Sprites.SCROLL_TRACK_TOP, "SCROLLBAR_DRAGGER_V2_3", "scrollbar track top uses V2 tile")
expect(Sprites.SCROLL_TRACK_CENTRE, "SCROLLBAR_DRAGGER_V2_3", "scrollbar track centre uses V2 tile")
expect(Sprites.SCROLL_TRACK_BOTTOM, "SCROLLBAR_DRAGGER_V2_3", "scrollbar track bottom uses V2 tile")
expect(Sprites.SCROLL_THUMB_TOP, "SCROLLBAR_DRAGGER_V2_0", "scrollbar thumb uses V2 top")
expect(Sprites.SCROLL_THUMB_CENTRE, "SCROLLBAR_DRAGGER_V2_1", "scrollbar thumb uses V2 centre")
expect(Sprites.SCROLL_THUMB_BOTTOM, "SCROLLBAR_DRAGGER_V2_2", "scrollbar thumb uses V2 bottom")

print("sprites_test: ok")
