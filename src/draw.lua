local TileModule = assert(
    require("src/draw/tile"),
    "PrettyUI could not load the Draw.Tile implementation")

local Draw = {
    Tile = assert(
        TileModule.Draw,
        "PrettyUI Draw.Tile implementation is invalid"),
}

return Draw
