local Math = {}

function Math.clamp(value, minimum, maximum)
    if maximum == nil then return math.max(minimum, value) end
    return math.max(minimum, math.min(maximum, value))
end

return Math
