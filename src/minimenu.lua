local InterfaceMouse = require("src/core/mouse")
local Sprites = require("src/core/sprites")
local clamp = require("src/core/math").clamp

local PrettyMiniMenu = {}

local EVENT_ID = "prettyui_minimenu"
local HEADER_HEIGHT = 22
local ITEM_HEIGHT = 15
local BOTTOM_PADDING = 7
local TEXT_INSET = 3
local MENU_WIDTH_PADDING = 8
local BORDER_SIZE = 2
local TITLE_CORNER_WIDTH = 3
local SIDE_WIDTH = 3
local BOTTOM_HEIGHT = 3
local BOTTOM_CORNER_SIZE = 8
local TITLEBAR_HEIGHT = 20
local MINIMUM_WIDTH = 60
local NATIVE_HITBOX_PADDING = 10
local TITLE_COLOUR = 0xDBCBA6FF
local TEXT_COLOUR = 0xDBCBA6FF
local HOVER_TEXT_COLOUR = 0xEEE5C6FF
local BACKGROUND_COLOUR = 0x1D1D1DFF
local HOVER_COLOUR = 0x3D3D3DFF
local MENU_FONT = id.Font.NOTOSANS_BOLD_12
local NOOP = function() end

local started = false
local activeMenu = nil
local overlay = nil
local parentsByEntry = setmetatable({}, { __mode = "k" })
local parentsByText = {}

local function diagnostic(registration, message)
    if registration == nil or registration.diagnostics ~= true
            or type(log) ~= "function" then return end
    log("[PrettyUI MiniMenu] " .. message)
end

local function componentDescription(name, componentID)
    if componentID == nil then return name .. ": ID unavailable" end
    local retrieved, component = pcall(function()
        return ui.Interfaces:GetComponent(componentID)
    end)
    if not retrieved then
        return name .. ": lookup failed: " .. tostring(component)
    end
    if component == nil then return name .. ": not loaded" end
    local described, description = pcall(function()
        local origin = component.xyGlobal or { x = "?", y = "?" }
        return name
            .. " id=" .. tostring(componentID)
            .. " staticID=" .. tostring(component.staticID)
            .. " global=(" .. tostring(origin.x) .. "," .. tostring(origin.y) .. ")"
            .. " local=(" .. tostring(component.x) .. "," .. tostring(component.y) .. ")"
            .. " size=(" .. tostring(component.width) .. "," .. tostring(component.height) .. ")"
            .. " enabled=" .. tostring(component.enabled)
            .. " visible=" .. tostring(component.visibleGlobal)
            .. " clickthrough=" .. tostring(component.clickthrough)
            .. " mouseOver=" .. tostring(component.isMouseOver)
            .. " restricted=" .. tostring(component.isRestricted)
    end)
    if described then return description end
    return name .. ": inspection failed: " .. tostring(description)
end

local function dumpNativeLayers(registration)
    local componentIDs = id.Component
    local components = {
        { "CLICKOUT_AND_BLOCKING_LAYER", componentIDs.MINIMENU__CLICKOUT_AND_BLOCKING_LAYER },
        { "PC_MOUSE_LEAVE_LAYER", componentIDs.MINIMENU__PC_MOUSE_LEAVE_LAYER },
        { "SUBMENU_BLOCKING_LAYER", componentIDs.MINIMENU__SUBMENU_BLOCKING_LAYER },
        { "MENU_BLOCKING_LAYER", componentIDs.MINIMENU__MENU_BLOCKING_LAYER },
        { "MENU_LAYER", componentIDs.MINIMENU__MENU_LAYER },
        { "SUBMENU_LAYER", componentIDs.MINIMENU__SUBMENU_LAYER },
    }
    for _, component in ipairs(components) do
        diagnostic(registration, componentDescription(component[1], component[2]))
    end
end

local function nativeHitboxDescription(nativeHitbox)
    local described, description = pcall(function()
        local component = nativeHitbox.component
        local origin = component.xyGlobal or { x = "?", y = "?" }
        local retained = origin.x == nativeHitbox.expectedX
            and origin.y == nativeHitbox.expectedY
            and component.width == nativeHitbox.expectedWidth
            and component.height == nativeHitbox.expectedHeight
        return "component=" .. nativeHitbox.componentName
            .. " global=(" .. tostring(origin.x) .. "," .. tostring(origin.y) .. ")"
            .. " size=(" .. tostring(component.width) .. "," .. tostring(component.height) .. ")"
            .. " expected=(" .. tostring(nativeHitbox.expectedX)
            .. "," .. tostring(nativeHitbox.expectedY)
            .. "," .. tostring(nativeHitbox.expectedWidth)
            .. "," .. tostring(nativeHitbox.expectedHeight) .. ")"
            .. " retained=" .. tostring(retained)
            .. " clickthrough=" .. tostring(component.clickthrough)
            .. " originalClickthrough=" .. tostring(nativeHitbox.clickthrough)
            .. " mouseOver=" .. tostring(component.isMouseOver)
    end)
    if described then return description end
    return "inspection failed: " .. tostring(description)
end

local function diagnosticRegistrations(registrations, message)
    for _, registration in pairs(registrations) do
        diagnostic(registration, message)
    end
end

local function verifyNativeMouseLeaveLayer(menuOverlay, phase)
    local nativeHitbox = menuOverlay and menuOverlay.nativeHitbox
    if nativeHitbox == nil then return end
    diagnostic(menuOverlay.registration,
        "hitbox " .. phase .. " " .. nativeHitboxDescription(nativeHitbox))
end



local function sprite(parent, spriteID)
    local component = ui.Sprite.new(parent)
    component.spriteID = spriteID
    component.clickthrough = true
    return component
end

local function plainText(value)
    return tostring(value or ""):gsub("<gt>", ">"):gsub("<lt>", "<"):gsub("<[^>]*>", "")
end

local function textKey(value)
    return plainText(value):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function measureWithFont(value, font, fallbackCharacterWidth)
    local text = tostring(value or "")
    local succeeded, width = pcall(function() return font:GetStringWidth(text, false) end)
    if succeeded and type(width) == "number" then return width end
    return #plainText(text) * fallbackCharacterWidth
end

local function measureMenuText(value)
    return measureWithFont(value, config.Font.NOTOSANS_BOLD_12, 7)
end

local function measureNativeText(value)
    return measureWithFont(value, config.Font.MUSEO_SANS_15PT_REGULAR, 7)
end

local function entryText(entry)
    if entry.overrideText ~= nil and entry.overrideText ~= "" then return entry.overrideText end
    if entry.fullText ~= nil and entry.fullText ~= "" then return entry.fullText end
    return table.concat({ entry.verbText or "", entry.subjectText or "", entry.extraText or "" }, " ")
end

local function frame(root, width, height)
    local sprites = Sprites.MINIMENU
    local background = ui.Rectangle.new(root)
    background:SetPos(BORDER_SIZE, TITLEBAR_HEIGHT)
    background:SetSize(width - BORDER_SIZE * 2, height - TITLEBAR_HEIGHT - BORDER_SIZE)
    background.fill = true
    background.rgba = BACKGROUND_COLOUR
    background.clickthrough = true

    local title = sprite(root, sprites.title)
    title:SetPos(BORDER_SIZE, 0)
    title:SetSize(width - BORDER_SIZE * 2, TITLEBAR_HEIGHT)
    title.isTiling = true

    local titleLeft = sprite(root, sprites.titleCorner)
    titleLeft:SetSize(TITLE_CORNER_WIDTH, TITLEBAR_HEIGHT)

    local titleRight = sprite(root, sprites.titleCorner)
    titleRight:SetPos(width - TITLE_CORNER_WIDTH, 0)
    titleRight:SetSize(TITLE_CORNER_WIDTH, TITLEBAR_HEIGHT)
    titleRight.isFlippedHorizontally = true

    local sideHeight = height - TITLEBAR_HEIGHT - BOTTOM_CORNER_SIZE
    local left = sprite(root, sprites.side)
    left:SetPos(0, TITLEBAR_HEIGHT)
    left:SetSize(SIDE_WIDTH, sideHeight)
    left.isTiling = true

    local right = sprite(root, sprites.side)
    right:SetPos(width - SIDE_WIDTH, TITLEBAR_HEIGHT)
    right:SetSize(SIDE_WIDTH, sideHeight)
    right.isTiling = true
    right.isFlippedHorizontally = true

    local bottom = sprite(root, sprites.bottom)
    bottom:SetPos(BOTTOM_CORNER_SIZE, height - BOTTOM_HEIGHT)
    bottom:SetSize(width - BOTTOM_CORNER_SIZE * 2, BOTTOM_HEIGHT)
    bottom.isTiling = true

    local bottomLeft = sprite(root, sprites.bottomCorner)
    bottomLeft:SetPos(0, height - BOTTOM_CORNER_SIZE)
    bottomLeft:SetSize(BOTTOM_CORNER_SIZE, BOTTOM_CORNER_SIZE)

    local bottomRight = sprite(root, sprites.bottomCorner)
    bottomRight:SetPos(width - BOTTOM_CORNER_SIZE, height - BOTTOM_CORNER_SIZE)
    bottomRight:SetSize(BOTTOM_CORNER_SIZE, BOTTOM_CORNER_SIZE)
    bottomRight.isFlippedHorizontally = true

    return { left, right, bottom, bottomLeft, bottomRight }
end

local function nativeComponent(componentID)
    if componentID == nil then return nil, "component ID unavailable" end
    local succeeded, component = pcall(function()
        return ui.Interfaces:GetComponent(componentID)
    end)
    if not succeeded then return nil, "lookup failed: " .. tostring(component) end
    if component == nil then return nil, "component not loaded" end
    return component
end

local function nativeMouseLeaveLayer()
    local candidates = {
        {
            name = "PC_MOUSE_LEAVE_LAYER",
            id = id.Component.MINIMENU__PC_MOUSE_LEAVE_LAYER,
        },
        {
            name = "MENU_BLOCKING_LAYER",
            id = id.Component.MINIMENU__MENU_BLOCKING_LAYER,
        },
    }
    local failures = {}
    for _, candidate in ipairs(candidates) do
        local component, failure = nativeComponent(candidate.id)
        if component ~= nil then return component, candidate.name, candidate.id end
        failures[#failures + 1] = candidate.name .. ": " .. tostring(failure)
    end
    return nil, table.concat(failures, "; ")
end

local function restoreNativeMouseLeaveLayer(menuOverlay)
    local nativeHitbox = menuOverlay.nativeHitbox
    if nativeHitbox == nil then return end
    menuOverlay.nativeHitbox = nil
    if nativeComponent(nativeHitbox.componentID) ~= nativeHitbox.component then
        diagnostic(menuOverlay.registration,
            "hitbox restore skipped because " .. nativeHitbox.componentName
            .. " is no longer loaded")
        return
    end
    local succeeded, failure = pcall(function()
        local position = nativeHitbox.position
        local size = nativeHitbox.size
        nativeHitbox.component:SetPos(
            position.x,
            position.y,
            position.xParentPc,
            position.yParentPc,
            position.xSelfPc,
            position.ySelfPc)
        nativeHitbox.component:SetSize(
            size.width,
            size.height,
            size.widthParentPc,
            size.heightParentPc)
        nativeHitbox.component.clickthrough = nativeHitbox.clickthrough
    end)
    if succeeded then
        diagnostic(menuOverlay.registration,
            "hitbox restored " .. nativeHitboxDescription(nativeHitbox))
    else
        diagnostic(menuOverlay.registration, "hitbox restore failed: " .. tostring(failure))
    end
end

local function extendNativeMouseLeaveLayer(menuOverlay, state)
    dumpNativeLayers(menuOverlay.registration)
    local component, componentName, componentID = nativeMouseLeaveLayer()
    if component == nil then
        diagnostic(menuOverlay.registration,
            "hitbox extension unavailable: " .. tostring(componentName))
        return
    end
    diagnostic(menuOverlay.registration, "using " .. componentName .. " as native hover bounds")

    local succeeded, nativeHitbox = pcall(function()
        assert(component.width > 0 and component.height > 0,
            "native mouse-leave layer has zero bounds")
        local position = component.position
        local size = component.size
        local componentOrigin = component.xyGlobal
        local componentParentOrigin = component.parent and component.parent.xyGlobal
            or { x = 0, y = 0 }
        local viewportOrigin = state.parent.xyGlobal or { x = 0, y = 0 }
        return {
            component = component,
            componentName = componentName,
            componentID = componentID,
            clickthrough = component.clickthrough,
            position = {
                x = position.x,
                y = position.y,
                xParentPc = position.xParentPc,
                yParentPc = position.yParentPc,
                xSelfPc = position.xSelfPc,
                ySelfPc = position.ySelfPc,
            },
            size = {
                width = size.width,
                height = size.height,
                widthParentPc = size.widthParentPc,
                heightParentPc = size.heightParentPc,
            },
            globalX = componentOrigin.x,
            globalY = componentOrigin.y,
            parentGlobalX = componentParentOrigin.x,
            parentGlobalY = componentParentOrigin.y,
            submenuGlobalX = viewportOrigin.x + menuOverlay.x,
            submenuGlobalY = viewportOrigin.y + menuOverlay.y,
        }
    end)
    if not succeeded or nativeHitbox == nil then
        diagnostic(menuOverlay.registration,
            "hitbox snapshot failed: " .. tostring(nativeHitbox))
        return
    end

    menuOverlay.nativeHitbox = nativeHitbox
    local left = math.min(
        nativeHitbox.globalX,
        nativeHitbox.submenuGlobalX - NATIVE_HITBOX_PADDING)
    local top = math.min(
        nativeHitbox.globalY,
        nativeHitbox.submenuGlobalY - NATIVE_HITBOX_PADDING)
    local right = math.max(
        nativeHitbox.globalX + component.width,
        nativeHitbox.submenuGlobalX + menuOverlay.width + NATIVE_HITBOX_PADDING)
    local bottom = math.max(
        nativeHitbox.globalY + component.height,
        nativeHitbox.submenuGlobalY + menuOverlay.height + NATIVE_HITBOX_PADDING)
    nativeHitbox.expectedX = left
    nativeHitbox.expectedY = top
    nativeHitbox.expectedWidth = right - left
    nativeHitbox.expectedHeight = bottom - top
    diagnostic(menuOverlay.registration,
        "hitbox before global=(" .. tostring(nativeHitbox.globalX)
        .. "," .. tostring(nativeHitbox.globalY)
        .. ") size=(" .. tostring(component.width)
        .. "," .. tostring(component.height)
        .. "); submenu global=(" .. tostring(nativeHitbox.submenuGlobalX)
        .. "," .. tostring(nativeHitbox.submenuGlobalY)
        .. ") size=(" .. tostring(menuOverlay.width)
        .. "," .. tostring(menuOverlay.height) .. ")")
    local failure
    succeeded, failure = pcall(function()
        component:SetPos(
            left - nativeHitbox.parentGlobalX,
            top - nativeHitbox.parentGlobalY)
        component:SetSize(right - left, bottom - top)
    end)
    if succeeded then
        diagnostic(menuOverlay.registration,
            "hitbox immediately after extension " .. nativeHitboxDescription(nativeHitbox))
    else
        diagnostic(menuOverlay.registration, "hitbox extension failed: " .. tostring(failure))
        restoreNativeMouseLeaveLayer(menuOverlay)
    end
end





local function destroyOverlay()
    if overlay == nil then return end
    if ui.Interfaces:GetInterface(overlay.interfaceID) ~= nil and overlay.root ~= nil then
        overlay.root:Destroy()
    end
    restoreNativeMouseLeaveLayer(overlay)
    overlay = nil
end

local function reset()
    destroyOverlay()
    activeMenu = nil
end

local function setRowHovered(row, hovered)
    row.background.hidden = not hovered
    row.label.rgba = hovered and HOVER_TEXT_COLOUR or TEXT_COLOUR
end

local function refreshRows(menuOverlay)
    local children = menuOverlay.registration.children
    for rowIndex, row in ipairs(menuOverlay.rows) do
        local childIndex = menuOverlay.scrollOffset + rowIndex
        local child = children[childIndex]
        row.childIndex = childIndex
        row.root.hidden = child == nil
        row.label.content = child and tostring(child.label) or ""
        setRowHovered(row, false)
    end
end

local function scrollRows(menuOverlay, delta)
    if delta == 0 then return false end
    local maximum = math.max(0, #menuOverlay.registration.children - menuOverlay.visibleRows)
    local direction = delta > 0 and 1 or -1
    local nextOffset = clamp(menuOverlay.scrollOffset + direction, 0, maximum)
    if nextOffset ~= menuOverlay.scrollOffset then
        menuOverlay.scrollOffset = nextOffset
        refreshRows(menuOverlay)
    end
    return false
end

local function selectChild(menuOverlay, row)
    local child = menuOverlay.registration.children[row.childIndex]
    if child == nil then return false end
    local action = child.action
    local arguments = child.arguments or child.args
    reset()
    if arguments ~= nil then
        action(table.unpack(arguments))
    else
        action()
    end
    return false
end

local function submenuWidth(registration)
    local width = measureMenuText(registration.title or "Choose Option")
    for _, child in ipairs(registration.children) do
        width = math.max(width, measureMenuText(child.label))
    end
    return math.max(MINIMUM_WIDTH, math.ceil(width) + MENU_WIDTH_PADDING)
end

local function createOverlay(registration, parentRow)
    destroyOverlay()

    local state = activeMenu
    local width = math.min(submenuWidth(registration), state.viewportWidth)
    local maximumRows = math.max(1,
        math.floor((state.viewportHeight - HEADER_HEIGHT - BOTTOM_PADDING) / ITEM_HEIGHT))
    local visibleRows = math.min(#registration.children, maximumRows)
    local height = math.max(46, HEADER_HEIGHT + visibleRows * ITEM_HEIGHT + BOTTOM_PADDING)

    local rightX = state.rootX + state.rootWidth
    local leftX = state.rootX - width
    local rightSpace = state.viewportWidth - rightX
    local leftSpace = state.rootX
    local x
    if rightSpace >= width then
        x = rightX
    elseif leftSpace >= width then
        x = leftX
    elseif rightSpace >= leftSpace then
        x = clamp(rightX, 0, state.viewportWidth - width)
    else
        x = clamp(leftX, 0, state.viewportWidth - width)
    end

    local parentRowTop = state.rootY + HEADER_HEIGHT + parentRow * ITEM_HEIGHT
    local y = clamp(parentRowTop - HEADER_HEIGHT, 0, state.viewportHeight - height)
    diagnostic(registration,
        "submenu created side=" .. (x >= rightX and "right" or "left")
        .. " local=(" .. tostring(x) .. "," .. tostring(y)
        .. ") size=(" .. tostring(width) .. "," .. tostring(height)
        .. ") parentRow=" .. tostring(parentRow))

    local menuOverlay = {
        registration = registration,
        x = x,
        y = y,
        width = width,
        height = height,
        visibleRows = visibleRows,
        scrollOffset = 0,
        rows = {},
    }
    extendNativeMouseLeaveLayer(menuOverlay, state)

    local rootParent = state.parent
    local rootX, rootY = x, y
    if menuOverlay.nativeHitbox ~= nil
            and menuOverlay.nativeHitbox.componentName == "MENU_BLOCKING_LAYER" then
        rootParent = menuOverlay.nativeHitbox.component
        local hostOrigin = rootParent.xyGlobal or { x = 0, y = 0 }
        local viewportOrigin = state.parent.xyGlobal or { x = 0, y = 0 }
        rootX = viewportOrigin.x + x - hostOrigin.x
        rootY = viewportOrigin.y + y - hostOrigin.y
        menuOverlay.hostedNative = true
        diagnostic(registration,
            "custom submenu hosted in MENU_BLOCKING_LAYER local=("
            .. tostring(rootX) .. "," .. tostring(rootY) .. ")")
    end

    local root = ui.Layer.new(rootParent)
    root:SetPos(rootX, rootY)
    root:SetSize(width, height)
    root.clickthrough = true
    menuOverlay.root = root
    menuOverlay.interfaceID = root.interfaceID or state.interfaceID
    local frameEdges = frame(root, width, height)

    local title = ui.Text.new(root)
    title:SetPos(TEXT_INSET, 0)
    title:SetSize(width - TEXT_INSET * 2, TITLEBAR_HEIGHT)
    title.content = tostring(registration.title or "Choose Option")
    title.font = MENU_FONT
    title.rgba = TITLE_COLOUR
    title.alignHorizontal = ui.AlignMode.TOPLEFT
    title.alignVertical = ui.AlignMode.CENTRE
    title.maxLines = 1
    title.isShadowed = false
    title.clickthrough = true

    for rowIndex = 1, visibleRows do
        local rowRoot = ui.Layer.new(root)
        rowRoot:SetPos(0, HEADER_HEIGHT + (rowIndex - 1) * ITEM_HEIGHT)
        rowRoot:SetSize(width, ITEM_HEIGHT)
        rowRoot.clickthrough = false

        local background = ui.Rectangle.new(rowRoot)
        background:SetSize(0, 0, 1.0, 1.0)
        background.fill = true
        background.rgba = HOVER_COLOUR
        background.hidden = true
        background.clickthrough = true

        local label = ui.Text.new(rowRoot)
        label:SetPos(TEXT_INSET, 0)
        label:SetSize(-TEXT_INSET * 2, ITEM_HEIGHT, 1.0)
        label.font = MENU_FONT
        label.rgba = TEXT_COLOUR
        label.alignHorizontal = ui.AlignMode.TOPLEFT
        label.alignVertical = ui.AlignMode.CENTRE
        label.maxLines = 1
        label.isShadowed = true
        label.clickthrough = true

        local row = { root = rowRoot, background = background, label = label }
        menuOverlay.rows[rowIndex] = row
        rowRoot:Subscribe(ui.Hook.ONMOUSEOVER, function()
            setRowHovered(row, true)
            local child = menuOverlay.registration.children[row.childIndex]
            diagnostic(menuOverlay.registration,
                "child mouseover index=" .. tostring(row.childIndex)
                .. " label=" .. tostring(child and child.label))
            return false
        end)
        rowRoot:Subscribe(ui.Hook.ONMOUSEREPEAT, function()
            setRowHovered(row, true)
            return false
        end)
        rowRoot:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            setRowHovered(row, false)
            return false
        end)
        rowRoot:Subscribe(ui.Hook.ONCLICK, function()
            diagnostic(menuOverlay.registration,
                "child click index=" .. tostring(row.childIndex))
            return selectChild(menuOverlay, row)
        end)
        rowRoot:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
            return scrollRows(menuOverlay, delta)
        end)
    end

    for _, edge in ipairs(frameEdges) do edge:MoveToFront() end

    root:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
        return scrollRows(menuOverlay, delta)
    end)
    refreshRows(menuOverlay)
    root:MoveToFront()
    overlay = menuOverlay
end

local function menuDimensions(entries, viewportHeight)
    local width = measureNativeText("Choose Option")
    for _, entry in ipairs(entries) do
        width = math.max(width, measureNativeText(entryText(entry)))
    end
    width = math.max(MINIMUM_WIDTH, math.ceil(width) + MENU_WIDTH_PADDING)
    local maximumRows = math.max(1,
        math.floor((viewportHeight - HEADER_HEIGHT - BOTTOM_PADDING) / ITEM_HEIGHT))
    local visibleRows = math.min(#entries, maximumRows)
    local height = math.max(46, HEADER_HEIGHT + visibleRows * ITEM_HEIGHT + BOTTOM_PADDING)
    return width, height, visibleRows
end

local function onOpened(event)
    reset()
    local entries = event.miniMenu.entries
    local registrations = {}
    for index, entry in ipairs(entries) do
        local registration = parentsByEntry[entry]
            or parentsByText[textKey(entryText(entry))]
        if registration ~= nil then registrations[index] = registration end
    end
    if next(registrations) == nil then return end

    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__ROOT)
        or ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    local mouse = InterfaceMouse.GetPosition()
    if parent == nil or mouse == nil or parent.width <= 0 or parent.height <= 0 then
        diagnosticRegistrations(registrations,
            "open aborted: viewport parent or mouse position unavailable")
        return
    end

    local origin = parent.xyGlobal or { x = 0, y = 0 }
    local mouseX = mouse.x - origin.x
    local mouseY = mouse.y - origin.y
    local width, height, visibleRows = menuDimensions(entries, parent.height)
    width = math.min(width, parent.width)

    activeMenu = {
        parent = parent,
        interfaceID = parent.interfaceID,
        entries = entries,
        registrations = registrations,
        viewportWidth = parent.width,
        viewportHeight = parent.height,
        rootWidth = width,
        rootHeight = height,
        rootVisibleRows = visibleRows,
        rootX = clamp(math.floor(mouseX - width / 2), 0, parent.width - width),
        rootY = clamp(math.floor(mouseY), 0, parent.height - height),
    }
    diagnosticRegistrations(registrations,
        "opened mouseGlobal=(" .. tostring(mouse.x) .. "," .. tostring(mouse.y)
        .. ") viewportGlobal=(" .. tostring(origin.x) .. "," .. tostring(origin.y)
        .. ") viewportSize=(" .. tostring(parent.width) .. "," .. tostring(parent.height)
        .. ") inferredNativeLocal=(" .. tostring(activeMenu.rootX)
        .. "," .. tostring(activeMenu.rootY)
        .. ") inferredNativeSize=(" .. tostring(width) .. "," .. tostring(height) .. ")")
end

local function inside(x, y, left, top, width, height)
    return x >= left and x < left + width and y >= top and y < top + height
end


local function onClosed()
    if overlay ~= nil then
        local mouse = InterfaceMouse.GetPosition()
        diagnostic(overlay.registration,
            "native MiniMenuClosed event mouseGlobal=("
            .. tostring(mouse and mouse.x) .. "," .. tostring(mouse and mouse.y)
            .. "); " .. (overlay.nativeHitbox
                and nativeHitboxDescription(overlay.nativeHitbox)
                or "native hitbox unavailable"))
    end
    if overlay == nil or activeMenu == nil or overlay.hostedNative
            or ui.Interfaces:GetInterface(activeMenu.interfaceID) == nil then
        reset()
    end
end

local function onLogic()
    local state = activeMenu
    if state == nil then return end
    if ui.Interfaces:GetInterface(state.interfaceID) == nil then
        reset()
        return
    end

    local nativeOpen = MiniMenu.IsOpen()
    if not nativeOpen and overlay == nil then
        reset()
        return
    end

    local mouse = InterfaceMouse.GetPosition()
    if mouse == nil then return end
    local origin = state.parent.xyGlobal or { x = 0, y = 0 }
    local x = mouse.x - origin.x
    local y = mouse.y - origin.y
    local insideNative = inside(
        x, y, state.rootX, state.rootY, state.rootWidth, state.rootHeight)
    local insideSubmenu = overlay ~= nil and inside(
        x, y, overlay.x, overlay.y, overlay.width, overlay.height)
    if overlay ~= nil and overlay.nativeHitbox ~= nil
            and overlay.nativeHitbox.logicChecked ~= true then
        overlay.nativeHitbox.logicChecked = true
        verifyNativeMouseLeaveLayer(overlay, "on next logic")
    end


    if overlay ~= nil and not insideNative and not insideSubmenu then
        diagnostic(overlay.registration,
            "dismissed outside both bounds nativeOpen=" .. tostring(nativeOpen)
            .. " mouseLocal=(" .. tostring(x) .. "," .. tostring(y)
            .. ") insideNative=" .. tostring(insideNative)
            .. " insideSubmenu=" .. tostring(insideSubmenu))
        if nativeOpen then
            destroyOverlay()
        else
            reset()
        end
        return
    end

    if not nativeOpen or insideSubmenu then return end
    if not insideNative then return end

    local contentY = y - state.rootY - HEADER_HEIGHT
    local row = math.floor(contentY / ITEM_HEIGHT)
    if row < 0 or row >= state.rootVisibleRows then
        destroyOverlay()
        return
    end

    local entryIndex = #state.entries - row
    local registration = state.registrations[entryIndex]
    if registration ~= nil
            and (overlay == nil or overlay.registration ~= registration) then
        diagnostic(registration,
            "parent hover row=" .. tostring(row)
            .. " entryIndex=" .. tostring(entryIndex)
            .. " mouseLocal=(" .. tostring(x) .. "," .. tostring(y) .. ")")
    end
    if registration == nil then
        destroyOverlay()
    elseif overlay == nil or overlay.registration ~= registration then
        createOverlay(registration, row)
    end
end

local function validatePosition(position)
    if position == nil or position == "top" or position == "bottom" then return end
    assert(type(position) == "number"
            and position >= 2
            and position == math.floor(position),
        "MiniMenu submenu position must be \"top\", \"bottom\", or an integer of 2 or greater")
end

local function targetEntryIndex(position, entryCount)
    local lastSafeRow = math.max(1, entryCount - 1)
    local displayedRow
    if position == nil or position == "bottom" then
        displayedRow = lastSafeRow
    else
        displayedRow = position == "top" and 2 or position
        displayedRow = math.min(displayedRow, lastSafeRow)
    end
    return entryCount - displayedRow + 1
end

local function moveEntry(miniMenu, currentIndex, targetIndex)
    while currentIndex < targetIndex do
        miniMenu:Swap(currentIndex, currentIndex + 1)
        currentIndex = currentIndex + 1
    end
    while currentIndex > targetIndex do
        miniMenu:Swap(currentIndex, currentIndex - 1)
        currentIndex = currentIndex - 1
    end
end

local function addParentEntry(miniMenu, label, action)
    local existing = {}
    for _, entry in ipairs(miniMenu.entries) do existing[entry] = true end
    local previousCount = #miniMenu.entries
    miniMenu:Add(label, action)
    assert(#miniMenu.entries == previousCount + 1,
        "MiniMenu:Add did not add the submenu parent entry")
    for index, entry in ipairs(miniMenu.entries) do
        if not existing[entry] then return entry, index end
    end
    error("MiniMenu:Add did not expose the submenu parent entry")
end

function PrettyMiniMenu.AddSubmenu(miniMenu, label, children, options)
    assert(miniMenu ~= nil and type(miniMenu.Add) == "function",
        "MiniMenu.AddSubmenu requires a writable MiniMenu from Event.MiniMenuReady")
    assert(type(label) == "string" and label ~= "", "MiniMenu submenu label must be a non-empty string")
    assert(type(children) == "table" and #children > 0, "MiniMenu submenu requires child entries")
    for index, child in ipairs(children) do
        assert(type(child) == "table", "MiniMenu child " .. index .. " must be a table")
        assert(type(child.label) == "string" and child.label ~= "",
            "MiniMenu child " .. index .. " requires a non-empty label")
        assert(type(child.action) == "function", "MiniMenu child " .. index .. " requires an action")
        local arguments = child.arguments or child.args
        assert(arguments == nil or type(arguments) == "table",
            "MiniMenu child " .. index .. " arguments must be a table")
    end

    options = options or {}
    assert(type(options) == "table", "MiniMenu submenu options must be a table")
    assert(options.parentAction == nil or type(options.parentAction) == "function",
        "MiniMenu submenu parentAction must be a function")
    assert(options.diagnostics == nil or type(options.diagnostics) == "boolean",
        "MiniMenu submenu diagnostics must be a boolean")
    validatePosition(options.position)
    local parentLabel = label
    if options.arrow ~= false then parentLabel = parentLabel .. " <col=ffffff><gt></col>" end
    local entry, entryIndex = addParentEntry(
        miniMenu,
        parentLabel,
        options.parentAction or NOOP)
    moveEntry(
        miniMenu,
        entryIndex,
        targetEntryIndex(options.position, #miniMenu.entries))
    local registration = {
        children = children,
        title = options.title,
        label = label,
        diagnostics = options.diagnostics == true,
    }
    parentsByEntry[entry] = registration
    parentsByText[textKey(parentLabel)] = registration
    return entry
end

function PrettyMiniMenu.Start()
    if started then return end
    started = true
    Event.MiniMenuOpened.Subscribe(EVENT_ID, onOpened)
    Event.MiniMenuClosed.Subscribe(EVENT_ID, onClosed)
    Event.MiniMenuEntrySelected.Subscribe(EVENT_ID, reset)
    Event.Logic.Subscribe(EVENT_ID, onLogic)
end

function PrettyMiniMenu.Shutdown()
    if not started then return end
    started = false
    Event.MiniMenuOpened.Unsubscribe(EVENT_ID)
    Event.MiniMenuClosed.Unsubscribe(EVENT_ID)
    Event.MiniMenuEntrySelected.Unsubscribe(EVENT_ID)
    Event.Logic.Unsubscribe(EVENT_ID)
    reset()
    parentsByEntry = setmetatable({}, { __mode = "k" })
    parentsByText = {}
end

return PrettyMiniMenu
