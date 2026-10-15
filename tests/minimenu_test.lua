local Interfaces = require("tests/interface_fixture")

local function expect(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function component(parent)
    local parentOrigin = parent and parent.xyGlobal or { x = 0, y = 0 }
    local result = {
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        xyGlobal = { x = parentOrigin.x, y = parentOrigin.y },
        position = {
            x = 0,
            y = 0,
            xParentPc = 0,
            yParentPc = 0,
            xSelfPc = 0,
            ySelfPc = 0,
        },
        size = {
            width = 0,
            height = 0,
            widthParentPc = 0,
            heightParentPc = 0,
        },
        children = {},
        subscriptions = {},
        hidden = false,
        parent = parent,
    }
    function result:SetPos(x, y, xParentPc, yParentPc, xSelfPc, ySelfPc)
        self.position = {
            x = x,
            y = y,
            xParentPc = xParentPc or 0,
            yParentPc = yParentPc or 0,
            xSelfPc = xSelfPc or 0,
            ySelfPc = ySelfPc or 0,
        }
        self.x = x
        self.y = y
        local origin = self.parent and self.parent.xyGlobal or { x = 0, y = 0 }
        self.xyGlobal = { x = origin.x + x, y = origin.y + y }
    end
    function result:SetSize(width, height, widthAnchor, heightAnchor)
        self.size = {
            width = width,
            height = height,
            widthParentPc = widthAnchor or 0,
            heightParentPc = heightAnchor or 0,
        }
        self.width = width + (widthAnchor or 0) * (self.parent and self.parent.width or 0)
        self.height = height + (heightAnchor or 0) * (self.parent and self.parent.height or 0)
    end
    function result:Subscribe(hook, id, callback)
        if callback == nil then callback, id = id, "default" end
        self.subscriptions[tostring(hook) .. ":" .. tostring(id)] = callback
    end
    function result:Unsubscribe(hook, id)
        self.subscriptions[tostring(hook) .. ":" .. tostring(id or "default")] = nil
    end
    function result:MoveToFront()
        self.frontCount = (self.frontCount or 0) + 1
    end
    function result:Destroy()
        self.destroyed = true
    end
    if parent then table.insert(parent.children, result) end
    return Interfaces.component(result, parent)
end

local root = component()
root.width = 640
root.height = 480
root.interfaceID = 1
root.xyGlobal = { x = 0, y = 0 }
local nativeHitbox = component(root)
nativeHitbox:SetPos(240, 90, 0.25, 0.125, -0.5, -0.25)
nativeHitbox:SetSize(160, 90, 0.1, 0.2)
nativeHitbox.clickthrough = false
local nativeHitboxPosition = nativeHitbox.position
local nativeHitboxSize = nativeHitbox.size
local nativeSubmenuLayer = component(root)
nativeSubmenuLayer:SetPos(250, 95, 0.1, 0.1, 0, 0)
nativeSubmenuLayer:SetSize(120, 70, 0.05, 0.05)
nativeSubmenuLayer.clickthrough = true
local nativeSubmenuPosition = nativeSubmenuLayer.position
local nativeSubmenuSize = nativeSubmenuLayer.size



ui = {
    AlignMode = { TOPLEFT = 1, CENTRE = 2 },
    Hook = {
        ONMOUSEOVER = 1,
        ONMOUSEREPEAT = 2,
        ONMOUSELEAVE = 3,
        ONCLICK = 4,
        ONSCROLLWHEEL = 5,
    },
    Layer = { new = function(parent) return component(parent) end },
    Rectangle = { new = function(parent) return component(parent) end },
    Sprite = { new = function(parent) return component(parent) end },
    Text = { new = function(parent) return component(parent) end },
    Interfaces = {
        GetComponent = function(_, componentID)
            if componentID == id.Component.MINIMENU__MENU_BLOCKING_LAYER then
                return nativeHitbox
            end
            if componentID == id.Component.MINIMENU__SUBMENU_LAYER then
                return nativeSubmenuLayer
            end
            if componentID == id.Component.TOPLEVEL_V2__ROOT
                    or componentID == id.Component.TOPLEVEL_V2__GAME_AREA then
                return root
            end
            return nil
        end,
        GetInterface = function(_, interfaceID)
            if interfaceID == root.interfaceID then return {} end
            return nil
        end,
    },
}

id = {
    Component = {
        TOPLEVEL_V2__ROOT = 1,
        TOPLEVEL_V2__GAME_AREA = 2,
        MINIMENU__PC_MOUSE_LEAVE_LAYER = 3,
        MINIMENU__MENU_BLOCKING_LAYER = 4,
        MINIMENU__SUBMENU_LAYER = 5,
    },
    Font = {
        NOTOSANS_BOLD_12 = 1,
    },
}

local diagnosticMessages = {}
log = function(message) diagnosticMessages[#diagnosticMessages + 1] = message end

local function hasDiagnostic(fragment)
    for _, message in ipairs(diagnosticMessages) do
        if message:find(fragment, 1, true) ~= nil then return true end
    end
    return false
end

config = {
    Font = {
        NOTOSANS_BOLD_12 = {
            GetStringWidth = function(_, text)
                return #(tostring(text):gsub("<[^>]*>", "")) * 7
            end,
        },
        MUSEO_SANS_15PT_REGULAR = {
            GetStringWidth = function(_, text)
                return #(tostring(text):gsub("<[^>]*>", "")) * 8
            end,
        },
    },
}

game = { options = { InterfaceScale = { setting = 100 } } }
local mouse = { x = 320, y = 100 }
Mouse = {
    GetPosition = function() return { x = mouse.x, y = mouse.y } end,
}

local handlers = {}
local function event(name)
    handlers[name] = {}
    return {
        Subscribe = function(id, callback) handlers[name][id] = callback end,
        Unsubscribe = function(id) handlers[name][id] = nil end,
    }
end
Event = {
    MiniMenuOpened = event("MiniMenuOpened"),
    MiniMenuClosed = event("MiniMenuClosed"),
    MiniMenuEntrySelected = event("MiniMenuEntrySelected"),
    Logic = event("Logic"),
}

local nativeMenuOpen = false
MiniMenu = { IsOpen = function() return nativeMenuOpen end }

package.loaded["src/core/sprites"] = {
    MINIMENU = {
        title = 1,
        titleCorner = 2,
        side = 3,
        bottom = 4,
        bottomCorner = 5,
    },
}

local PrettyMiniMenu = require("src/minimenu")
PrettyMiniMenu.Start()

local function newMenu()
    local menu = {
        entries = {
            { fullText = "Cancel" },
            { fullText = "Walk here" },
        },
    }
    function menu:Add(label, action)
        table.insert(self.entries, 1, {
            overrideText = label,
            callback = action,
        })
        self.entryCount = #self.entries
    end
    function menu:Swap(a, b)
        self.entries[a], self.entries[b] = self.entries[b], self.entries[a]
    end
    menu.entryCount = #menu.entries
    return menu
end

local function emit(name, payload)
    for _, callback in pairs(handlers[name]) do callback(payload) end
end

local function callback(componentValue, hook)
    return componentValue.subscriptions[tostring(hook) .. ":default"]
end


local function latestOverlayIn(parent)
    for index = #parent.children, 1, -1 do
        local child = parent.children[index]
        if child.subscriptions[tostring(ui.Hook.ONSCROLLWHEEL) .. ":default"] ~= nil then
            return child
        end
        local nested = latestOverlayIn(child)
        if nested ~= nil then return nested end
    end
end

local function latestOverlay()
    return latestOverlayIn(root)
end

local function overlayGlobalX(menuOverlay)
    return menuOverlay.xyGlobal.x
end

local function overlayGlobalY(menuOverlay)
    return menuOverlay.xyGlobal.y
end


local function firstRow(menuOverlay)
    for _, child in ipairs(menuOverlay.children) do
        if child.y == 22 and callback(child, ui.Hook.ONCLICK) ~= nil then return child end
    end
end

local selected = nil
local menu = newMenu()
local parentEntry = PrettyMiniMenu.AddSubmenu(menu, "PrettyUI actions", {
    { label = "First child", action = function(value) selected = value end, args = { "first" } },
    { label = "Second child", action = function() selected = "second" end },
}, {
    parentAction = function() selected = "parent" end,
    diagnostics = true,
})
expect(parentEntry, menu.entries[2], "default placement returns the custom parent entry")
expect(menu.entries[1].fullText, "Cancel",
    "default placement preserves Cancel as the final visible entry")
expect(parentEntry.overrideText, "PrettyUI actions <col=ffffff><gt></col>",
    "submenu parents include a native-style direction marker")
parentEntry.callback()
expect(selected, "parent", "submenu parents can preserve their own action")
selected = nil

local topMenu = newMenu()
local topEntry = PrettyMiniMenu.AddSubmenu(topMenu, "Top parent", {
    { label = "Child", action = function() end },
}, { position = "top" })
expect(topMenu.entries[2], topEntry,
    "top places the parent one visible row below the highest-priority entry")
expect(topMenu.entries[1].fullText, "Cancel", "top placement preserves lower native entries")
expect(topMenu.entries[3].fullText, "Walk here",
    "top placement reserves the highest-priority native entry")

local bottomMenu = newMenu()
local bottomEntry = PrettyMiniMenu.AddSubmenu(bottomMenu, "Bottom parent", {
    { label = "Child", action = function() end },
}, { position = "bottom" })
expect(bottomMenu.entries[2], bottomEntry,
    "bottom places the parent directly above Cancel")
expect(bottomMenu.entries[1].fullText, "Cancel",
    "bottom placement preserves Cancel as the final visible entry")

local secondMenu = newMenu()
local secondEntry = PrettyMiniMenu.AddSubmenu(secondMenu, "Second parent", {
    { label = "Child", action = function() end },
}, { position = 2 })
expect(secondMenu.entries[2], secondEntry,
    "numeric placement is a one-based displayed row from the top")
expect(secondMenu.entries[1].fullText, "Cancel",
    "numeric placement preserves lower-priority native entries")
expect(secondMenu.entries[3].fullText, "Walk here",
    "numeric placement preserves higher-priority native entries")

local clampedMenu = newMenu()
local clampedEntry = PrettyMiniMenu.AddSubmenu(clampedMenu, "Clamped parent", {
    { label = "Child", action = function() end },
}, { position = 99 })
expect(clampedMenu.entries[2], clampedEntry,
    "numeric positions beyond the available rows clamp above Cancel")

local validPosition, positionError = pcall(function()
    PrettyMiniMenu.AddSubmenu(newMenu(), "Invalid parent", {
        { label = "Child", action = function() end },
    }, { position = 1 })
end)
expect(validPosition, false, "submenu placement rejects the reserved highest-priority row")
expect(positionError:find("position", 1, true) ~= nil, true,
    "invalid placement identifies the position option")

local validDiagnostics, diagnosticsError = pcall(function()
    PrettyMiniMenu.AddSubmenu(newMenu(), "Invalid diagnostics", {
        { label = "Child", action = function() end },
    }, { diagnostics = "yes" })
end)
expect(validDiagnostics, false, "submenu diagnostics rejects non-boolean values")
expect(diagnosticsError:find("diagnostics", 1, true) ~= nil, true,
    "invalid diagnostics identifies the option")

local openedMenu = {
    entries = {
        { fullText = menu.entries[1].fullText },
        { overrideText = parentEntry.overrideText },
        { fullText = menu.entries[3].fullText },
    },
}
nativeMenuOpen = true
emit("MiniMenuOpened", { miniMenu = openedMenu })
-- Fresh open-time wrappers preserve the parent one visible row above Cancel.
mouse.y = 144
emit("Logic")
local rightOverlay = latestOverlay()
expect(rightOverlay ~= nil, true,
    "hovering resolves a reordered parent recreated for MiniMenuOpened")
expect(rightOverlay.children[1].rgba, 0x1D1D1DFF,
    "submenu content uses the native MiniMenu background colour")
expect(rightOverlay.children[3].width, 3,
    "submenu title corners retain their native sprite width")
expect(rightOverlay.children[5].width, 3,
    "submenu side borders retain their native sprite width")
expect(rightOverlay.children[8].width, 8,
    "submenu bottom corners retain their native sprite dimensions")
expect(rightOverlay.children[10].font, id.Font.NOTOSANS_BOLD_12,
    "submenu title uses the native bold 12px menu font")
expect(rightOverlay.children[10].rgba, 0xDBCBA6FF,
    "submenu title uses the current native MiniMenu foreground colour")
local rightOverlayX = overlayGlobalX(rightOverlay)
local rightOverlayY = overlayGlobalY(rightOverlay)
expect(rightOverlay.parent, nativeHitbox,
    "the custom submenu is hosted above its extended native menu blocker")
expect(rightOverlay.x, rightOverlayX - nativeHitbox.x,
    "a native-hosted submenu uses blocker-relative coordinates")
expect(rightOverlayX > mouse.x, true, "the submenu uses available space on the right")
local expectedNativeWidth = #"PrettyUI actions " * 8 + 8
expect(rightOverlayX, math.floor(mouse.x - expectedNativeWidth / 2) + expectedNativeWidth,
    "submenu placement uses native-menu metrics instead of the custom submenu font")
expect(nativeHitbox.width >= rightOverlayX + rightOverlay.width - nativeHitbox.x, true,
    "opening a submenu extends the loaded native menu blocking layer over its width")
expect(nativeHitbox.height >= rightOverlayY + rightOverlay.height - nativeHitbox.y, true,
    "opening a submenu extends the loaded native menu blocking layer over its height")
expect(nativeHitbox.clickthrough, false,
    "native hosting leaves the menu blocker input behavior unchanged")
expect(hasDiagnostic("opened mouseGlobal="), true,
    "diagnostics report native menu geometry")
expect(hasDiagnostic("using MENU_BLOCKING_LAYER as native hover bounds"), true,
    "diagnostics report fallback to the loaded native menu blocking layer")
expect(hasDiagnostic("hitbox immediately after extension"), true,
    "diagnostics report the immediate hitbox mutation")
emit("Logic")
expect(hasDiagnostic("hitbox on next logic"), true,
    "diagnostics report whether the native hitbox mutation survived a logic cycle")
mouse.x = rightOverlayX + rightOverlay.width + 1
mouse.y = rightOverlayY + 30
emit("Logic")
expect(rightOverlay.destroyed, true,
    "leaving both native and submenu bounds closes the submenu")
expect(nativeHitbox.position.x, nativeHitboxPosition.x,
    "closing the submenu restores the native mouse-leave layer x offset")
expect(nativeHitbox.position.xParentPc, nativeHitboxPosition.xParentPc,
    "closing the submenu restores the native mouse-leave layer position anchors")
expect(nativeHitbox.size.width, nativeHitboxSize.width,
    "closing the submenu restores the native mouse-leave layer width offset")
expect(nativeHitbox.size.widthParentPc, nativeHitboxSize.widthParentPc,
    "closing the submenu restores the native mouse-leave layer size anchors")
expect(nativeHitbox.clickthrough, false,
    "closing the submenu restores native blocking input behavior")
expect(hasDiagnostic("hitbox restored"), true,
    "diagnostics report native hitbox restoration")
expect(nativeSubmenuLayer.position.x, nativeSubmenuPosition.x,
    "opening the custom submenu does not move the inactive native submenu layer")
expect(nativeSubmenuLayer.size.width, nativeSubmenuSize.width,
    "opening the custom submenu does not resize the inactive native submenu layer")
expect(hasDiagnostic("custom submenu hosted in MENU_BLOCKING_LAYER"), true,
    "diagnostics report blocker-local submenu hosting")
mouse.x = rightOverlayX - 5
mouse.y = 144
emit("Logic")
rightOverlay = latestOverlay()
expect(rightOverlay.destroyed == true, false,
    "returning to the parent row can reopen the submenu while the native menu is open")
mouse.x = overlayGlobalX(rightOverlay) + 5
mouse.y = overlayGlobalY(rightOverlay) + 30
emit("Logic")

local row = firstRow(rightOverlay)
expect(row ~= nil, true, "the first child row is interactive while the native menu is open")
expect(row.x, 0, "child hover rows extend beneath the native side sprites")
expect(row.children[2].font, id.Font.NOTOSANS_BOLD_12,
    "submenu entries use the native bold 12px menu font")
expect(row.children[2].rgba, 0xDBCBA6FF,
    "submenu entries use the current native MiniMenu foreground colour")
callback(row, ui.Hook.ONMOUSEOVER)()
expect(hasDiagnostic("child mouseover"), true,
    "diagnostics report whether submenu rows receive pointer events")
expect(row.children[1].rgba, 0x3D3D3DFF,
    "submenu hover uses the current native MiniMenu background colour")
expect(row.children[2].rgba, 0xEEE5C6FF,
    "submenu hover uses the current native MiniMenu foreground colour")
callback(row, ui.Hook.ONMOUSELEAVE)()
callback(row, ui.Hook.ONCLICK)()
expect(selected, "first", "child actions receive their attached arguments")
expect(rightOverlay.destroyed, true, "selecting a child destroys the submenu")

nativeMenuOpen = true
mouse.x = 320
mouse.y = 100
emit("MiniMenuOpened", { miniMenu = openedMenu })
mouse.y = 144
emit("Logic")
local nativeClosedOverlay = latestOverlay()
expect(nativeClosedOverlay.destroyed == true, false,
    "the submenu can reopen before native close")
nativeMenuOpen = false
emit("MiniMenuClosed", { miniMenu = openedMenu })
expect(hasDiagnostic("native MiniMenuClosed event"), true,
    "diagnostics report premature native menu closure")
expect(nativeClosedOverlay.destroyed, true,
    "native close destroys a submenu hosted in the native interface")



root.width = 300
root.height = 180
mouse.x = 285
mouse.y = 100
menu = newMenu()
PrettyMiniMenu.AddSubmenu(menu, "Edge actions", {
    { label = "Left child", action = function() end },
})
nativeMenuOpen = true
emit("MiniMenuOpened", { miniMenu = menu })
mouse.y = 144
emit("Logic")
local leftOverlay = latestOverlay()
local leftOverlayX = overlayGlobalX(leftOverlay)
local leftOverlayY = overlayGlobalY(leftOverlay)
expect(leftOverlayX + leftOverlay.width <= 285, true,
    "a submenu flips left when the right viewport edge has insufficient space")
expect(leftOverlayX >= 0, true, "left-opening submenus remain inside the viewport")
expect(leftOverlayY >= 0 and leftOverlayY + leftOverlay.height <= root.height, true,
    "submenus remain inside vertical viewport bounds")

nativeMenuOpen = false
emit("MiniMenuClosed", { miniMenu = menu })
expect(leftOverlay.destroyed, true,
    "native close destroys the hosted submenu")

root.width = 320
root.height = 80
mouse.x = 160
mouse.y = 10
menu = newMenu()
parentEntry = PrettyMiniMenu.AddSubmenu(menu, "Scrollable", {
    { label = "One", action = function() end },
    { label = "Two", action = function() end },
    { label = "Three", action = function() end },
    { label = "Four", action = function() end },
    { label = "Five", action = function() end },
}, { title = "Child options" })
menu:Swap(2, 3)
nativeMenuOpen = true
emit("MiniMenuOpened", { miniMenu = menu })
-- A caller can still move the returned entry directly; identity survives that swap.
mouse.y = 10 + 22 + 7
emit("Logic")
local scrollOverlay = latestOverlay()
expect(scrollOverlay ~= nil, true, "submenu identity survives MiniMenu:Swap")
expect(scrollOverlay.height <= root.height, true, "large submenus fit the viewport")
local scrollRow = firstRow(scrollOverlay)
expect(scrollRow.children[2].content, "One", "scrolling starts with the first child")
callback(scrollOverlay, ui.Hook.ONSCROLLWHEEL)(scrollOverlay, 1)
expect(scrollRow.children[2].content, "Two", "mouse wheel reveals later child options")
emit("MiniMenuEntrySelected", { entry = {} })
expect(scrollOverlay.destroyed, true, "selecting a native entry dismisses the submenu")

PrettyMiniMenu.Shutdown()
expect(handlers.MiniMenuOpened.prettyui_minimenu, nil, "shutdown removes the open listener")
expect(handlers.MiniMenuClosed.prettyui_minimenu, nil, "shutdown removes the close listener")
expect(handlers.MiniMenuEntrySelected.prettyui_minimenu, nil,
    "shutdown removes the selection listener")
expect(handlers.Logic.prettyui_minimenu, nil, "shutdown removes the logic listener")
expect(scrollOverlay.destroyed, true, "native selection destroys an open submenu")

print("minimenu_test: ok")
