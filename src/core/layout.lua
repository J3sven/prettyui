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
    local startY = options.startY or DEFAULT_START_Y
    owner._flowLayout = {
        startY = startY,
        nextY = startY,
        paddingLeft = options.paddingLeft or options.padding or DEFAULT_PADDING,
        paddingRight = options.paddingRight or options.padding or DEFAULT_PADDING,
        paddingBottom = options.paddingBottom or options.padding or DEFAULT_PADDING,
        columnGap = options.columnGap or DEFAULT_COLUMN_GAP,
        rowGap = options.rowGap or DEFAULT_ROW_GAP,
        row = nil,
        hasItems = false,
        minimumContentHeight = owner.contentHeight or 0,
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
    options._flowGap = gap

    local absolute = options.absolute == true or options.y ~= nil
    options._flowAbsolute = absolute
    options._flowExplicitX = options.x ~= nil
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
        options._flowMarginTop = marginTop
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
    Layout.track(owner, component, placement)

    -- Component:Destroy() removes the native UI object, but the flow layout also
    -- needs to forget its row. Decorate managed Lua components so callers do not
    -- need a separate layout cleanup operation.
    if type(component) == "table" and type(component.Destroy) == "function" then
        local destroy = component.Destroy
        component.Destroy = function(self, ...)
            if owner._destroyingManagedFlow ~= true then Layout.remove(owner, self) end
            return destroy(self, ...)
        end
    end

    return component
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

local function setFlowPosition(root, placement, x, y)
    root:SetPos(x, y, placement.xAnchor or 0, placement.yAnchor or 0)
end

local function reflow(owner)
    local layout = owner._flowLayout
    if layout == nil then return end

    layout.nextY = layout.startY
    layout.row = nil
    layout.hasItems = false
    local contentBottom = layout.startY
    for _, entry in ipairs(owner._managedFlowEntries or {}) do
        local root = componentRoot(entry.component)
        local placement = entry.placement
        if root ~= nil then
            local height = root.height or placement.height or 0
            local width = root.width or placement.width or placement.size or 0
            local gap = placement._flowGap or layout.rowGap

            if placement._flowAbsolute == true then
                contentBottom = math.max(contentBottom, (root.y or placement.y or 0) + height)
            elseif placement.inline == true and layout.row ~= nil then
                local x = placement._flowExplicitX and placement.x or layout.row.nextX
                local y = layout.row.y + (placement.offsetY or 0)
                setFlowPosition(root, placement, x, y)
                layout.row.height = math.max(layout.row.height, (placement.offsetY or 0) + height)
                layout.row.gap = math.max(layout.row.gap, gap)
                layout.row.nextX = x + math.max(0, width) +
                    (placement.columnGap or layout.columnGap)
                contentBottom = math.max(contentBottom, y + height)
            else
                finalizeRow(layout)
                local marginTop = placement._flowMarginTop or 0
                local x = placement._flowExplicitX and placement.x or layout.paddingLeft
                local y = layout.nextY + marginTop
                setFlowPosition(root, placement, x, y)
                layout.row = {
                    y = y,
                    height = height,
                    gap = gap,
                    nextX = x + math.max(0, width) +
                        (placement.columnGap or layout.columnGap),
                }
                layout.hasItems = true
                contentBottom = math.max(contentBottom, y + height)
            end
        end
    end

    if owner.SetContentHeight then
        owner:SetContentHeight(math.max(
            layout.minimumContentHeight,
            contentBottom + layout.paddingBottom
        ))
    end
end

function Layout.remove(owner, component)
    local removed = false
    local entries = owner._managedFlowEntries or {}
    for index = #entries, 1, -1 do
        if entries[index].component == component then
            table.remove(entries, index)
            removed = true
        end
    end

    local components = owner._managedFlowComponents or {}
    for index = #components, 1, -1 do
        if components[index] == component then table.remove(components, index) end
    end

    if removed then reflow(owner) end
    return removed
end

local function refreshRowBackgrounds(owner)
    if type(owner.RefreshRowBackgrounds) == "function" then
        owner:RefreshRowBackgrounds()
    end
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
        refreshRowBackgrounds(owner)
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
    refreshRowBackgrounds(owner)
end

function Layout.destroyManaged(owner)
    local components = owner._managedFlowComponents or {}
    owner._destroyingManagedFlow = true
    for index = #components, 1, -1 do
        local component = components[index]
        if component and component.Destroy then component:Destroy() end
    end
    owner._destroyingManagedFlow = nil
    owner._managedFlowComponents = {}
    owner._managedFlowEntries = {}
end

return Layout
