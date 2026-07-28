local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function vector(x, y, z)
    return { x = x, y = y, z = z }
end

Vector3 = { new = vector }

ShapeData = {
    new = function()
        return { positions = {}, rgba = {}, lines = {}, tris = {} }
    end,
}

local draws = {}
ShapeList = {
    Draw = function(settings)
        draws[#draws + 1] = settings
    end,
}

World = {
    GetGroundHeight = function(_, x, z)
        return (x // 512) * 10 + (z // 512), true
    end,
}

local coord = {
    level = 2,
    ToCoordFine = function()
        return { position = vector(5120, 0, 7168) }
    end,
}

package.loaded["src/draw"] = nil
package.loaded["src/draw/tile"] = nil
local Draw = require("src/draw")

expect(type(package.loaded["src/draw/tile"]), "table", "tile module returns a library table")
expect(type(Draw.Tile), "function", "Draw.Tile is exported by the drawing entrypoint")

local drawn = Draw.Tile{
    coordGrid = coord,
    outlineColour = 0x112233,
    fill = true,
}
expect(drawn, true, "map marker draws")
expect(#draws, 1, "one shape submitted")
expect(draws[1].shapeData.rgba[1], 0x112233FF, "outline defaults opaque")
expect(draws[1].shapeData.rgba[5], 0x1122338C, "fill defaults to 55 percent")
expect(#draws[1].shapeData.lines, 8, "outline has four exterior lines")
expect(#draws[1].shapeData.tris, 6, "fill has two triangles")
expect(draws[1].shapeData.positions[1].x, 4864, "mesh starts at the tile edge")
expect(draws[1].shapeData.positions[1].y, 134, "first corner samples terrain")
expect(draws[1].shapeData.positions[2].y, 144, "second corner samples terrain independently")
expect(draws[1].shapeData.positions[5].y, 133, "fill sits below the outline bias")

Draw.Tile{
    coordGrid = coord,
    outlineColour = 0x11223320,
    fill = true,
}
expect(draws[2].shapeData.rgba[1], 0x11223320, "outline honours embedded alpha")
expect(draws[2].shapeData.rgba[5], 0x1122338C, "outline alpha does not replace fill default")

Draw.Tile{
    coordGrid = coord,
    outlineColour = 0x010203,
    outlineOpacity = 0.25,
    fillColour = 0xA0B0C0,
    fillOpacity = 0.75,
    outlineThickness = 7.0,
    lineWidth = 3.0,
}
expect(draws[3].shapeData.rgba[1], 0x01020340, "outline opacity is independent")
expect(draws[3].shapeData.rgba[5], 0xA0B0C0BF, "fill colour and opacity are independent")
expect(draws[3].lineWidth, 7.0, "outline thickness controls line width")

local npc = {
    isValid = true,
    position = vector(10240, 200, 15360),
    coordGrid = { level = 1 },
    config = { gridSize = 4 },
}
Draw.Tile{
    entity = npc,
    outlineColour = 0xFF8800,
    fill = true,
}
local entityDraw = draws[4]
expect(entityDraw.shapeData.positions[1].x, 9216, "four-tile entity left edge")
expect(entityDraw.shapeData.positions[5].x, 11264, "four-tile entity right edge")
expect(#entityDraw.shapeData.lines, 32, "entity outline follows each perimeter segment")
expect(#entityDraw.shapeData.tris, 96, "entity fill tessellates all sixteen tiles")
expect(#entityDraw.shapeData.positions, 41, "entity mesh duplicates perimeter and fill vertices")

local ok, message = Draw.Tile{ outline = false, fill = false, coordGrid = coord }
expect(ok, false, "empty marker is rejected")
expect(message, "outline and fill are both disabled", "empty marker error")

npc.isValid = false
ok, message = Draw.Tile{ entity = npc }
expect(ok, false, "invalid entity is rejected")
expect(message, "entity is no longer valid", "invalid entity error")

print("draw_test: ok")
