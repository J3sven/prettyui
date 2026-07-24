local Layout = {}

local DEFAULT_PADDING = 14
local DEFAULT_START_Y = 12
local DEFAULT_COLUMN_GAP = 8
local DEFAULT_ROW_GAP = 8

local function copyOptions(value)
    local copy = {}
    if type(value) == "table" then
        for key, option in pairs(value) do copy[key] = option end
    end
    return copy
end

local function finalizeRow(layout)
    if layout.row == nil then return end
    layout.nextY = layout.row.y + layout.row.height + layout.row.gap
    layout.row = nil
end

local function growContent(owner, bottom)
    if owner.SetContentHeight == nil then return end
    local layout = owner._flowLayout
    owner:SetContentHeight(math.max(owner.contentHeight, bottom + layout.paddingBottom))
end

function Layout.configure(owner, options)
    options = options or {}
    owner._flowLayout = {
        nextY = options.startY or DEFAULT_START_Y,
        paddingLeft = options.paddingLeft or options.padding or DEFAULT_PADDING,
        paddingRight = options.paddingRight or options.padding or DEFAULT_PADDING,
        paddingBottom = options.paddingBottom or options.padding or DEFAULT_PADDING,
        columnGap = options.columnGap or DEFAULT_COLUMN_GAP,
        rowGap = options.rowGap or DEFAULT_ROW_GAP,
        row = nil,
        hasItems = false,
    }
    owner._managedFlowComponents = {}
    owner._managedFlowEntries = {}
end

function Layout.place(owner, value, defaults)
    defaults = defaults or {}
    if owner._flowLayout == nil then Layout.configure(owner) end

    local layout = owner._flowLayout
    local options = copyOptions(value)
    if options._onScrollWheel == nil then options._onScrollWheel = owner._onScrollWheel end
    local width = options.width or options.size or defaults.width or 0
    local height = options.height or options.size or defaults.height or 0
    local gap = options.marginBottom
    if gap == nil then gap = defaults.gap or layout.rowGap end

    local absolute = options.absolute == true or options.y ~= nil
    options._flowAbsolute = absolute
    if absolute then
        options.x = options.x or layout.paddingLeft
        options.y = options.y or layout.nextY
    elseif options.inline == true and layout.row ~= nil then
        options.x = options.x or layout.row.nextX
        options.y = layout.row.y + (options.offsetY or 0)
        layout.row.height = math.max(layout.row.height, (options.offsetY or 0) + height)
        layout.row.gap = math.max(layout.row.gap, gap)
        layout.row.nextX = options.x + math.max(0, width) + (options.columnGap or layout.columnGap)
    else
        finalizeRow(layout)
        local marginTop = options.marginTop
        if marginTop == nil then
            marginTop = layout.hasItems and (defaults.marginTop or 0) or (defaults.firstMarginTop or 0)
        end
        options.x = options.x or layout.paddingLeft
        options.y = layout.nextY + marginTop
        layout.row = {
            y = options.y,
            height = height,
            gap = gap,
            nextX = options.x + math.max(0, width) + (options.columnGap or layout.columnGap),
        }
        layout.hasItems = true
    end

    if options.width == nil then
        if defaults.fillWidth == true then
            options.width = -(layout.paddingLeft + layout.paddingRight)
            options.widthAnchor = options.widthAnchor == nil and 1.0 or options.widthAnchor
        else
            options.width = width
        end
    end
    if options.height == nil then options.height = height end

    growContent(owner, options.y + height)
    return options
end

function Layout.manage(owner, component, placement)
    table.insert(owner._managedFlowComponents, component)
    return Layout.track(owner, component, placement)
end

function Layout.track(owner, component, placement)
    table.insert(owner._managedFlowEntries, {
        component = component,
        placement = placement or {},
    })
    return component
end

local function componentRoot(component)
    return component and (component.root or component) or nil
end

function Layout.resize(owner, component, height)
    local root = componentRoot(component)
    if root == nil then return end

    local oldHeight = root.height or 0
    height = math.max(0, math.floor(height))
    local delta = height - oldHeight
    if delta == 0 then return end
    root:SetHeight(height)

    local layout = owner._flowLayout
    if layout == nil then return end
    if layout.row and layout.row.y == root.y then
        layout.row.height = height
        growContent(owner, root.y + height)
        return
    end

    local entries = owner._managedFlowEntries or {}
    local found = false
    for _, entry in ipairs(entries) do
        if entry.component == component then
            found = true
        elseif found and entry.placement._flowAbsolute ~= true then
            local followingRoot = componentRoot(entry.component)
            if followingRoot and followingRoot.y > root.y then
                followingRoot:SetY(followingRoot.y + delta)
            end
        end
    end
    layout.nextY = layout.nextY + delta
    if owner.SetContentHeight then owner:SetContentHeight(owner.contentHeight + delta) end
end

function Layout.destroyManaged(owner)
    local components = owner._managedFlowComponents or {}
    for index = #components, 1, -1 do
        local component = components[index]
        if component and component.Destroy then component:Destroy() end
    end
    owner._managedFlowComponents = {}
    owner._managedFlowEntries = {}
end

return Layout
