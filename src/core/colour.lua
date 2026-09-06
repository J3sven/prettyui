local Colour = {}

function Colour.hsvToRgb(hue, saturation, value)
    hue = (hue % 1) * 6
    local sector = math.floor(hue)
    local fraction = hue - sector
    local p = value * (1 - saturation)
    local q = value * (1 - fraction * saturation)
    local t = value * (1 - (1 - fraction) * saturation)
    sector = sector % 6
    if sector == 0 then return value, t, p end
    if sector == 1 then return q, value, p end
    if sector == 2 then return p, value, t end
    if sector == 3 then return p, q, value end
    if sector == 4 then return t, p, value end
    return value, p, q
end

return Colour
