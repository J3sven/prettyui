local TILE_SIZE = 512.0
local OUTLINE_HEIGHT_BIAS = 1.0
local DEFAULT_HEIGHT_OFFSET = 30.0
local DEFAULT_FILL_OPACITY = 0.55
local DEFAULT_LINE_WIDTH = 2.0

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function alphaByte(opacity)
    return math.floor(clamp(tonumber(opacity) or 1.0, 0.0, 1.0) * 255.0 + 0.5)
end

local function splitColour(colour, fallback, opacity, defaultOpacity)
    colour = math.floor(tonumber(colour) or fallback)
    local rgb
    local embeddedOpacity
    if colour > 0xFFFFFF then
        rgb = (colour >> 8) & 0xFFFFFF
        embeddedOpacity = (colour & 0xFF) / 255.0
    else
        rgb = colour & 0xFFFFFF
    end
    return rgb, alphaByte(opacity ~= nil and opacity or embeddedOpacity or defaultOpacity)
end

local function copyPosition(position, heightBias)
    return Vector3.new(position.x, position.y + (heightBias or 0.0), position.z)
end

local function buildShape(
    centre, level, width, depth, heightOffset, outlineRGBA, fillRGBA)
    local minX = math.floor(centre.x - width * TILE_SIZE * 0.5 + 0.5)
    local minZ = math.floor(centre.z - depth * TILE_SIZE * 0.5 + 0.5)
    local stride = width + 1
    local grid = {}

    for z = 0, depth do
        for x = 0, width do
            local worldX = minX + x * TILE_SIZE
            local worldZ = minZ + z * TILE_SIZE
            local height, available = World.GetGroundHeight(level, worldX, worldZ)
            if not available then
                return nil, "ground height is unavailable"
            end
            grid[z * stride + x + 1] = Vector3.new(
                worldX, height + heightOffset, worldZ)
        end
    end

    local function gridPosition(x, z)
        return grid[z * stride + x + 1]
    end

    local positions = {}
    local rgba = {}
    local lines = {}
    local tris = {}

    if outlineRGBA ~= nil then
        local perimeter = {}
        for x = 0, width do perimeter[#perimeter + 1] = gridPosition(x, 0) end
        for z = 1, depth do perimeter[#perimeter + 1] = gridPosition(width, z) end
        for x = width - 1, 0, -1 do
            perimeter[#perimeter + 1] = gridPosition(x, depth)
        end
        for z = depth - 1, 1, -1 do
            perimeter[#perimeter + 1] = gridPosition(0, z)
        end

        for index, position in ipairs(perimeter) do
            positions[#positions + 1] = copyPosition(position, OUTLINE_HEIGHT_BIAS)
            rgba[#rgba + 1] = outlineRGBA
            lines[#lines + 1] = index - 1
            lines[#lines + 1] = index % #perimeter
        end
    end

    if fillRGBA ~= nil then
        local offset = #positions
        for _, position in ipairs(grid) do
            positions[#positions + 1] = copyPosition(position)
            rgba[#rgba + 1] = fillRGBA
        end
        for z = 0, depth - 1 do
            for x = 0, width - 1 do
                local bottomLeft = offset + z * stride + x
                local bottomRight = bottomLeft + 1
                local topLeft = bottomLeft + stride
                local topRight = topLeft + 1
                tris[#tris + 1] = bottomLeft
                tris[#tris + 1] = bottomRight
                tris[#tris + 1] = topRight
                tris[#tris + 1] = bottomLeft
                tris[#tris + 1] = topRight
                tris[#tris + 1] = topLeft
            end
        end
    end

    local shape = ShapeData.new()
    shape.positions = positions
    shape.rgba = rgba
    shape.lines = lines
    shape.tris = tris
    return shape
end

local function entityGridSize(entity)
    local success, size = pcall(function()
        return entity.config and entity.config.gridSize
    end)
    if not success then return 1 end
    return math.max(1, math.floor(tonumber(size) or 1))
end

local function positiveSize(value, fallback)
    return math.max(1, math.floor(tonumber(value) or fallback))
end

local function drawTarget(settings)
    local entity = settings.entity
    if entity ~= nil then
        local valid, isValid = pcall(function() return entity.isValid end)
        if not valid or not isValid then
            return nil, nil, nil, nil, "entity is no longer valid"
        end
        local targetAvailable, position, level = pcall(function()
            return entity.position, entity.coordGrid.level
        end)
        if not targetAvailable then
            return nil, nil, nil, nil, "entity position is unavailable"
        end
        local size = positiveSize(settings.size, entityGridSize(entity))
        return position, level,
            positiveSize(settings.width, size),
            positiveSize(settings.depth, size)
    end

    local coord = settings.coordGrid
    if coord == nil then
        return nil, nil, nil, nil, "coordGrid or entity is required"
    end
    local position = coord:ToCoordFine(true).position
    local size = positiveSize(settings.size, 1)
    return position, coord.level,
        positiveSize(settings.width, size),
        positiveSize(settings.depth, size)
end

-- Draw must be called from Event.Draw or Event.EntityDraw.
--
-- Colours may be RGB (0xRRGGBB) or RGBA (0xRRGGBBAA). Explicit opacity
-- values are in the 0.0-1.0 range and override an embedded alpha channel.
local function Tile(settings)
    settings = settings or {}

    local outlineEnabled = settings.outline ~= false
    local fillEnabled = settings.fill == true
        or (settings.fill == nil and settings.fillColour ~= nil)
    if not outlineEnabled and not fillEnabled then
        return false, "outline and fill are both disabled"
    end

    local outlineRGB, outlineAlpha = splitColour(
        settings.outlineColour or settings.colour,
        0xFFFFFFFF,
        settings.outlineOpacity or settings.opacity,
        1.0)
    local fillRGB, fillAlpha = splitColour(
        settings.fillColour or outlineRGB,
        outlineRGB,
        settings.fillOpacity,
        DEFAULT_FILL_OPACITY)
    local outlineRGBA = outlineEnabled and ((outlineRGB << 8) | outlineAlpha) or nil
    local fillRGBA = fillEnabled and ((fillRGB << 8) | fillAlpha) or nil

    local centre, level, width, depth, targetError = drawTarget(settings)
    if centre == nil then return false, targetError end
    local shape, shapeError = buildShape(
        centre,
        level,
        width,
        depth,
        tonumber(settings.heightOffset) or DEFAULT_HEIGHT_OFFSET,
        outlineRGBA,
        fillRGBA)
    if shape == nil then return false, shapeError end

    ShapeList.Draw{
        shapeData = shape,
        ignoreDepth = settings.ignoreDepth == true,
        lineWidth = clamp(
            tonumber(settings.outlineThickness)
                or tonumber(settings.lineWidth)
                or DEFAULT_LINE_WIDTH,
            0.0,
            10.0),
    }
    return true
end

return Tile
