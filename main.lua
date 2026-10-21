-- Item Charges
--
-- Shows remaining charges and doses as a small number on item icons in the
-- backpack, worn equipment, bank, beast of burden and action bars, Invention
-- charge info in the worn equipment tab, a panel listing the potions in
-- your house's potion cauldrons, and a potion supplies (restock) panel.
--
-- Charges are read from item names: "Games necklace (8)" has 8 charges, and
-- using one swaps it for "Games necklace (7)". Potions work the same way.
--
-- Credits: settings page built with PrettyUI by rsnJ3
-- (https://prettyui.j3.gg/).

print("Item Charges loaded.")

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Jewellery to track, by name without the charge suffix, in lowercase (names
-- are compared ignoring capitals). RS3 spellings.
local TRACKED_ITEMS = {
    ["games necklace"]     = true,
    ["amulet of glory"]    = true,
    ["ring of duelling"]   = true,
    ["skills necklace"]    = true,
    ["combat bracelet"]    = true,
    ["dig site pendant"]   = true,
    ["ring of slaying"]    = true,
    ["ferocious ring"]     = true,
    ["ring of wealth"]     = true,
    ["kethsi ring"]        = true,
    ["forinthry bracelet"] = true,
    ["castle wars brace"]  = true,
}

-- Items whose charges aren't in their name but in a player variable (found
-- with `pan VarPlayer` and confirmed in-game). Lowercase name -> variable.
-- These have no low charge colour, since their counts are far above 1 to 5.
local VAR_CHARGED_ITEMS = {
    -- Every upgrade tier shares the same count (you only ever own one).
    ["spring cleaner"]      = "TRH53_SPRING_CLEANER_STORED_CHARGES",
    ["spring cleaner 2000"] = "TRH53_SPRING_CLEANER_STORED_CHARGES",
    ["spring cleaner 3000"] = "TRH53_SPRING_CLEANER_STORED_CHARGES",
    ["spring cleaner 5000"] = "TRH53_SPRING_CLEANER_STORED_CHARGES",
    ["spring cleaner 9000"] = "TRH53_SPRING_CLEANER_STORED_CHARGES",
    ["spring cleaner 9001"] = "TRH53_SPRING_CLEANER_STORED_CHARGES",
}

-- Potions are detected by their "Drink" option (see isPotion). These words
-- are a fallback if the option list can't be read. Lowercase.
local POTION_NAME_WORDS = {
    "potion", "flask", "brew", "mix", "salve", "overload", "serum",
    "antifire", "antipoison", "antidote", "restore", "renewal",
}

local INVENTORY_NAMES = { "INV", "WORN", "BANK", "LORE_BOB" }

-- Components whose dynamic children are item icons, one per slot, with
-- dynamicID = slot - 1. While banking, the backpack is shown in the bank's
-- own panel. The bank scrolls inside "clip": icon positions don't include the
-- scroll offset, so it's subtracted, and numbers outside the clip are hidden.
--
-- inBank marks the bank window's own layers; numbers anywhere else are hidden
-- where the bank window covers them.
--
-- Action bars ("bar") aren't tied to an inventory: each of their 14 slots is
-- a separate component that shows whichever item was put there.
local ICON_LAYERS = {
    { inv = "INV",  layer = "TOPLEVEL_V2_INVENTORY__ITEM_LAYER" },
    { inv = "INV",  layer = "BANK__INVENTORY_SLOTS", inBank = true },
    { inv = "WORN", layer = "TOPLEVEL_V2_WORN__ITEM_LAYER" },
    { inv = "BANK", layer = "BANK__BANK_INV", clip = "BANK__BANK_ITEMS_CONTAINER", inBank = true },
    -- Beast of burden: the familiar ribbon tab, the bank's familiar panel, and
    -- the familiar storage window (which also shows the backpack). Where the
    -- icon layer is uncertain, candidates are listed and the first visible one
    -- with icons is used.
    { inv = "LORE_BOB", layers = {
        "LORE_STATS_SIDE__INVENTORY_INVLAYER", "LORE_STATS_SIDE__INVENTORY_SLOTLAYER",
    }, clip = "LORE_STATS_SIDE__INVENTORY_SCROLL_LAYER" },
    { inv = "LORE_BOB", layer = "BANK__BOB_SLOTS", clip = "BANK__BOB_SCROLLING", inBank = true },
    { inv = "LORE_BOB", layers = {
        "LORE_BANK__LORE_BOB_INV_SLOTLAYER", "LORE_BANK__LORE_BOB_LAYER",
        "LORE_BANK__BOB_ICON_LAYER", "LORE_BANK__LORE_BOB_INV_OPLAYER",
    } },
    { inv = "INV", layers = { "LORE_BANK__INV_INVLAYER", "LORE_BANK__INV_SLOTLAYER" } },
    { bar = "TOPLEVEL_V2_COMBAT_BAR" },
    { bar = "TOPLEVEL_V2_COMBAT_BAR2" },
    { bar = "TOPLEVEL_V2_COMBAT_BAR3" },
    { bar = "TOPLEVEL_V2_COMBAT_BAR4" },
    { bar = "TOPLEVEL_V2_COMBAT_BAR5" },
    { bar = "TOPLEVEL_V2_PARENT_SUBOVERLAY_ACTION_BAR" },
}
local ACTION_BAR_SLOTS = 14
local WORN_ITEM_LAYER = "TOPLEVEL_V2_WORN__ITEM_LAYER"
local WORN_CONTENT_LAYER = "TOPLEVEL_V2_WORN__CONTENT_LAYER"

-------------------------------------------------------------------------------
-- Saved settings
-------------------------------------------------------------------------------

local function loadSetting(key, isValid, default)
    local ok, saved = pcall(function() return PersistentDB:Get(key) end)
    if ok and isValid(saved) then
        return saved
    end
    return default
end

local function saveSetting(key, value)
    pcall(function() PersistentDB:Set(key, value) end)
end

local function isBoolean(v) return type(v) == "boolean" end

-- Colours are stored as { r, g, b } in 0-255.
local DEFAULT_COLOURS = {
    normal         = { r = 255, g = 255, b = 0 },   -- yellow
    low            = { r = 255, g = 64,  b = 64 },  -- red
    outline        = { r = 0,   g = 0,   b = 0 },   -- black
    invention      = { r = 255, g = 255, b = 0 },
    invention_low  = { r = 255, g = 64,  b = 64 },
    cauldron_low   = { r = 255, g = 64,  b = 64 },
}

local function isColour(v)
    return type(v) == "table" and v.r ~= nil and v.g ~= nil and v.b ~= nil
end

local colours = {}
for which, d in pairs(DEFAULT_COLOURS) do
    local c = loadSetting("colour_" .. which, isColour, d)
    colours[which] = { r = c.r, g = c.g, b = c.b }
end

local outlineEnabled = loadSetting("outline_enabled", isBoolean, false)
local showInBank = loadSetting("show_in_bank", isBoolean, true)
local showOnActionBars = loadSetting("show_on_action_bars", isBoolean, true)

local CAULDRON_MODES = { house = true, off = true }
local cauldronMode = loadSetting("cauldron_panel", function(v) return CAULDRON_MODES[v] == true end, "house")

-- Where the cauldron window was last dragged to, so it reopens there after a
-- logout.
local function isCoord(v) return type(v) == "number" and v >= 0 end
local cauldronX = loadSetting("cauldron_x", isCoord, 40)
local cauldronY = loadSetting("cauldron_y", isCoord, 200)

-- At or below these, numbers use the low colour. Separate for potions (doses)
-- and jewellery (charges).
local LOW_THRESHOLD_MAX = 5
local function isThreshold(v)
    return math.type(v) == "integer" and v >= 1 and v <= LOW_THRESHOLD_MAX
end
local lowThresholds = {
    potion    = loadSetting("low_threshold_potion", isThreshold, 1),
    jewellery = loadSetting("low_threshold_jewellery", isThreshold, 1),
}

-- The potion supplies panel marks a potion for restocking at or below this
-- many doses in total.
local RESTOCK_MAX = 500
local RESTOCK_STEP = 10
local restockAt = loadSetting("supplies_restock_at", function(v)
    return math.type(v) == "integer" and v >= 0 and v <= RESTOCK_MAX
end, 50)

-- A potion cauldron is marked for refilling at or below this many doses.
local REFILL_MAX = 500
local REFILL_STEP = 10
local refillAt = loadSetting("cauldron_refill_at", function(v)
    return math.type(v) == "integer" and v >= 0 and v <= REFILL_MAX
end, 20)

local SUPPLIES_MODES = { bank = true, off = true }
local suppliesMode = loadSetting("supplies_panel", function(v) return SUPPLIES_MODES[v] == true end, "bank")

local INVENTION_LINES = {
    { value = "time",   key = "show_invention",        text = "Show time left" },
    { value = "charge", key = "show_invention_charge", text = "Show current charge" },
    { value = "drain",  key = "show_invention_drain",  text = "Show drain rate" },
}
local showInventionLine = {}
local inventionLineKeys = {}
for _, line in ipairs(INVENTION_LINES) do
    showInventionLine[line.value] = loadSetting(line.key, isBoolean, true)
    inventionLineKeys[line.value] = line.key
end

local TEXT_SIZES = { normal = true, small = true, xs = true }
local inventionTextSize = loadSetting("invention_text_size",
    function(v) return TEXT_SIZES[v] == true end, "normal")

local function toVector4(c)
    return Vector4.new(c.r / 255, c.g / 255, c.b / 255, 1.0)
end

-- PrettyUI colour pickers use 0xRRGGBBAA.
local function toHex(c)
    return (c.r << 24) | (c.g << 16) | (c.b << 8) | 0xFF
end

local function fromHex(hex)
    hex = math.tointeger(hex) or math.floor(hex)
    return { r = (hex >> 24) & 0xFF, g = (hex >> 16) & 0xFF, b = (hex >> 8) & 0xFF }
end

-------------------------------------------------------------------------------
-- Finding charged items
-------------------------------------------------------------------------------

-- "Games necklace (8)" -> "Games necklace", 8
-- "Amulet of glory (t4)" -> "Amulet of glory", 4
-- Returns nil if the name has no charge suffix.
local function parseCharges(itemName)
    local baseName, digits = string.match(itemName, "^(.-)%s*%(%a*(%d+)%)$")
    if baseName == nil then
        return nil
    end
    return baseName, tonumber(digits)
end

-- Only called for items whose name already ends in a dose.
local function isPotion(obj, baseName)
    local ok, ops = pcall(function() return obj.interfaceOpNames end)
    if ok and type(ops) == "table" then
        for _, opName in pairs(ops) do
            if opName == "Drink" then
                return true
            end
        end
    end
    local lower = string.lower(baseName)
    for _, word in ipairs(POTION_NAME_WORDS) do
        if string.find(lower, word, 1, true) then
            return true
        end
    end
    return false
end

-- "jewellery", "potion", or nil if the item isn't tracked.
local function itemKind(obj, baseName)
    if TRACKED_ITEMS[string.lower(baseName)] then return "jewellery" end
    if isPotion(obj, baseName) then return "potion" end
    return nil
end

local function readVarPlayer(name)
    local ok, value = pcall(function() return var.VarPlayer[name].value end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

-- For items in VAR_CHARGED_ITEMS: their charges, or nil.
local function varCharges(itemName)
    local varName = VAR_CHARGED_ITEMS[string.lower(itemName)]
    return varName and readVarPlayer(varName)
end

local warnedInventories = {}

local function findInventory(invName)
    local ok, invConfig = pcall(function() return config.Inv[invName] end)
    if not ok or invConfig == nil then
        if not warnedInventories[invName] then
            print("Item Charges: unknown inventory name '" .. invName .. "'")
            warnedInventories[invName] = true
        end
        return nil
    end
    local inv = Inventory.Find(invConfig)
    if inv == nil or not inv.isValid then
        return nil
    end
    return inv
end

-- Item ID -> { charges, kind } for every tracked item seen in the last scan.
-- Each charge or dose level is a separate item, so an ID always has one count.
local chargesByObjID = {}

-- Returns a list of { charges, kind, invName, slotIndex } for every tracked item.
local function collectChargedItems()
    local results = {}
    chargesByObjID = {}
    for _, invName in ipairs(INVENTORY_NAMES) do
        local inv = findInventory(invName)
        if inv ~= nil then
            for slotIndex = 1, inv.slotCount do
                local slot = inv:GetSlot(slotIndex)
                -- Bank placeholders keep the item's name but have a count of 0.
                if slot ~= nil and slot.obj ~= nil and slot.count ~= 0 then
                    local baseName, charges = parseCharges(slot.obj.name)
                    local kind = baseName and itemKind(slot.obj, baseName)
                    if kind == nil then
                        charges = varCharges(slot.obj.name)
                        kind = charges and "stored"
                    end
                    if kind ~= nil then
                        local item = {
                            charges = charges,
                            kind = kind,
                            invName = invName,
                            slotIndex = slotIndex,
                        }
                        table.insert(results, item)
                        if slot.obj.id ~= nil then
                            chargesByObjID[slot.obj.id] = item
                        end
                    end
                end
            end
        end
    end
    return results
end

-------------------------------------------------------------------------------
-- Text drawing
-------------------------------------------------------------------------------

-- All text is drawn on the plugin layer rather than inside game interfaces,
-- which the game rebuilds when items move.
local parentLayer = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
if parentLayer == nil then
    print("Item Charges: could not find the plugin UI layer. Display disabled.")
end

local function findComponentByName(componentName)
    local ok, comp = pcall(function()
        return ui.Interfaces:GetComponent(id.Component[componentName])
    end)
    if ok then return comp end
    return nil
end

-- Fonts. Unknown names in id.Font still return a value, so a name is only
-- treated as real if it differs from a name that can't exist.
local NORMAL_FONT = id.Font.MUSEO_SANS_15PT_REGULAR

local function fontByName(name)
    local ok, font = pcall(function() return id.Font[name] end)
    if ok then return font end
    return nil
end

local FAKE_FONT = fontByName("ITEM_CHARGES_NOT_A_REAL_FONT")

local function looksReal(font)
    return font ~= nil and font ~= FAKE_FONT and type(font) == type(NORMAL_FONT)
end

local function firstRealFont(names)
    for _, name in ipairs(names) do
        local font = fontByName(name)
        if looksReal(font) then
            return font
        end
    end
    return nil
end

-- "MUSEO_SANS_8PT_REGULAR" -> 8, "NOTOSANS_BOLD_12" -> 12
local function fontSize(name)
    return tonumber(name:match("_(%d+)PT") or name:match("_(%d+)$"))
end

-- Picks the real font closest to 8pt (7 to 10) from the client's font list,
-- preferring Museo Sans. Returns nil if the list can't be read.
local function closestFontTo8pt()
    local ok, names = pcall(function()
        local found = {}
        for name in pairs(id.Font) do found[#found + 1] = tostring(name) end
        return found
    end)
    if not ok then return nil end
    local best, bestName, bestScore = nil, nil, nil
    for _, name in ipairs(names) do
        local size = fontSize(name)
        if size ~= nil and size >= 7 and size <= 10 and looksReal(fontByName(name)) then
            local score = math.abs(size - 8) * 10
            if not name:find("MUSEO") then score = score + 5 end
            if bestScore == nil or score < bestScore
                or (score == bestScore and name < bestName) then
                best, bestName, bestScore = fontByName(name), name, score
            end
        end
    end
    return best
end

local SMALL_FONT = firstRealFont({
    "MUSEO_SANS_12PT_REGULAR", "MUSEO_SANS_13PT_REGULAR",
    "MUSEO_SANS_11PT_REGULAR", "NOTOSANS_BOLD_12",
}) or NORMAL_FONT

local XS_FONT = closestFontTo8pt() or firstRealFont({
    "MUSEO_SANS_8PT_REGULAR", "MUSEO_SANS_9PT_REGULAR", "MUSEO_SANS_10PT_REGULAR",
    "NOTOSANS_REGULAR_8", "NOTOSANS_BOLD_8", "NOTOSANS_REGULAR_9", "NOTOSANS_BOLD_9",
    "NOTOSANS_REGULAR_10", "NOTOSANS_BOLD_10",
}) or SMALL_FONT

local function newText(parent, w, h)
    local t = ui.Text.new(parent)
    t.font = NORMAL_FONT
    t:AlignTo(ui.AlignMode.CENTRE)
    t.clickthrough = true
    t:SetSize(w, h)
    return t
end

-- Text has no outline option, so an outline is drawn as 8 copies offset by
-- 1 unit in each direction, with the main text created last so it's on top.
-- Note: calling MoveToFront() on these texts makes them invisible.
local OUTLINE_OFFSETS = {
    { -1, -1 }, { 0, -1 }, { 1, -1 },
    { -1,  0 },            { 1,  0 },
    { -1,  1 }, { 0,  1 }, { 1,  1 },
}

local function newOutlinedText(parent, w, h)
    local group = { outlines = {} }
    for i = 1, #OUTLINE_OFFSETS do
        local t = newText(parent, w, h)
        t.hidden = true
        group.outlines[i] = t
    end
    group.main = newText(parent, w, h)
    return group
end

local function setOutlinedContent(group, content, colourVec)
    group.main.content = content
    group.main.colour = colourVec
    group.main.isShadowed = not outlineEnabled
    local outlineVec = toVector4(colours.outline)
    for _, t in ipairs(group.outlines) do
        t.content = content
        t.colour = outlineVec
    end
end

local function placeOutlinedText(group, x, y)
    group.main:SetPos(x, y)
    group.main.hidden = false
    for i, offset in ipairs(OUTLINE_OFFSETS) do
        local t = group.outlines[i]
        t:SetPos(x + offset[1], y + offset[2])
        t.hidden = not outlineEnabled
    end
end

local function hideOutlinedText(group)
    group.main.hidden = true
    for _, t in ipairs(group.outlines) do
        t.hidden = true
    end
end

local function setOutlinedFont(group, font)
    group.main.font = font
    for _, t in ipairs(group.outlines) do
        t.font = font
    end
end

-- Item icons report the item they're drawing. The client updates this as soon
-- as an item is moved, before the server confirms the move and the inventory
-- data catches up. Returns nil for icons that don't report one.
local function iconObjectID(icon)
    local ok, objID = pcall(function() return icon.associatedObjectID end)
    if ok and type(objID) == "number" then return objID end
    return nil
end

local function iconQuantity(icon)
    local ok, quantity = pcall(function() return icon.associatedObjectQuantity end)
    if ok and type(quantity) == "number" then return quantity end
    return nil
end

-------------------------------------------------------------------------------
-- Positioning
-------------------------------------------------------------------------------
-- A full render decides what to show and records a "placement" for each text:
-- the component it follows and its offset from that component. reposition()
-- then moves the texts to follow their components. It's cheap, so it runs
-- 50 times a second to keep up with scrolling and window dragging, while the
-- full render only runs on game ticks and changes.

local placements = {}

-- objID: the item the component was showing at the last full render, if known.
-- checkQuantity: whether a quantity of 0 (a bank placeholder) hides the number.
-- inBank: true for numbers drawn inside the bank window itself. All others
-- are hidden where the bank window covers them, since the plugin layer is
-- drawn on top of every game interface.
local function addPlacement(group, comp, offX, offY, w, h, clip, objID, checkQuantity, inBank)
    placements[#placements + 1] = {
        group = group, comp = comp, offX = offX, offY = offY, w = w, h = h,
        clip = clip, objID = objID, checkQuantity = checkQuantity, inBank = inBank,
    }
end

-- True if a w x h box at (x, y) lies inside the component's on-screen area.
local function insideComponent(comp, x, y, w, h)
    local pos = comp.xyGlobal
    return x >= pos.x and y >= pos.y
        and x + w <= pos.x + comp.width and y + h <= pos.y + comp.height
end

-- The bank window's on-screen rectangle, or nil if the bank is closed. There's
-- no known component for the whole window, so it's worked out from its item
-- area and backpack panel plus the frame around them (measured from a
-- screenshot): about 16 pixels at the sides, 95 above (title and tabs) and
-- 60 below (search bar).
-- The two components are looked up on each full render (findBankComponents)
-- rather than 50 times a second; reposition() just reads their positions.
local BANK_FRAME = { left = 16, top = 95, right = 16, bottom = 60 }
local bankItems, bankBackpack = nil, nil

local function findBankComponents()
    bankItems = findComponentByName("BANK__BANK_ITEMS_CONTAINER")
    bankBackpack = findComponentByName("BANK__INVENTORY_SLOTS")
end

-- A closed bank's components still report visibleGlobal = true, but with a
-- size of 0 at (0, 0) (seen with a probe), so size is checked too.
local function bankPartShown(comp)
    return comp ~= nil and comp.visibleGlobal == true and comp.width > 0 and comp.height > 0
end

local function bankRect()
    local items, backpack = bankItems, bankBackpack
    if not bankPartShown(items) then return nil end
    local right = items.xyGlobal.x + items.width
    if bankPartShown(backpack) then
        right = math.max(right, backpack.xyGlobal.x + backpack.width)
    end
    return {
        x1 = items.xyGlobal.x - BANK_FRAME.left,
        y1 = items.xyGlobal.y - BANK_FRAME.top,
        x2 = right + BANK_FRAME.right,
        y2 = items.xyGlobal.y + items.height + BANK_FRAME.bottom,
    }
end

-- True if a w x h box at (x, y) overlaps the rectangle at all.
local function overlaps(rect, x, y, w, h)
    return x < rect.x2 and x + w > rect.x1 and y < rect.y2 and y + h > rect.y1
end

-- Returns true if an icon now shows a different item (or became a bank
-- placeholder), meaning a full render is needed.
local function reposition()
    local origin = parentLayer.xyGlobal
    local bank = bankRect()
    for _, p in ipairs(placements) do
        if p.objID ~= nil and (iconObjectID(p.comp) ~= p.objID
            or (p.checkQuantity and iconQuantity(p.comp) == 0)) then
            return true
        end
        local x, y, show = nil, nil, p.comp.visibleGlobal
        if show then
            local pos = p.comp.xyGlobal
            x, y = pos.x + p.offX, pos.y + p.offY
            if p.clip ~= nil then
                -- Positions inside a scrolled area don't include the scroll.
                x = x - (p.clip.scrollX or 0)
                y = y - (p.clip.scrollY or 0)
                show = insideComponent(p.clip, x, y, p.w, p.h)
            end
            if show and bank ~= nil and not p.inBank then
                show = not overlaps(bank, x, y, p.w, p.h)
            end
        end
        if not show then
            if p.shown ~= false then
                hideOutlinedText(p.group)
                p.shown = false
            end
        elseif not p.shown or x ~= p.lastX or y ~= p.lastY then
            placeOutlinedText(p.group, x - origin.x, y - origin.y)
            p.shown, p.lastX, p.lastY = true, x, y
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Charge numbers on item icons
-------------------------------------------------------------------------------

local OVERLAY_W, OVERLAY_H = 22, 16

local overlayLabels = {}   -- keyed "<icon layer index>:<slot>"
local lastItems = {}

-- Slot number -> icon component. An icon's dynamicID is its slot, from 0.
local function mapSlotIcons(layer)
    local icons = {}
    if layer == nil or layer.IterateDynamicComponents == nil then
        return icons
    end
    layer:IterateDynamicComponents(function(component)
        icons[component.dynamicID + 1] = component
        return false
    end)
    return icons
end

local function getOverlayLabel(key)
    local group = overlayLabels[key]
    if group == nil then
        group = newOutlinedText(parentLayer, OVERLAY_W, OVERLAY_H)
        overlayLabels[key] = group
    end
    return group
end

-- Returns the visible icon layer for an entry and its icons, or nil. With a
-- list of candidates, the first visible one that has icons is used.

local function findIconLayer(entry)
    local names = entry.layers or { entry.layer }
    for _, name in ipairs(names) do
        local layer = findComponentByName(name)
        if layer ~= nil and layer.visibleGlobal then
            local icons = mapSlotIcons(layer)
            if entry.layers == nil or next(icons) ~= nil then
                return layer, icons
            end
        end
    end
    return nil
end

-- Numbers must fit in the corner of an icon: 7501 -> "7K", like the game's
-- own stack counts.
local function shortNumber(n)
    if n >= 1000 then
        return string.format("%dK", n // 1000)
    end
    return tostring(n)
end

local function renderChargeNumbers(items)
    -- Slot -> item for each inventory, for icons that don't report an item.
    local itemsBySlot = {}
    for _, item in ipairs(items) do
        itemsBySlot[item.invName] = itemsBySlot[item.invName] or {}
        itemsBySlot[item.invName][item.slotIndex] = item
    end

    for layerIndex, entry in ipairs(ICON_LAYERS) do
        local icons, clip, slotItems, reportsItems = nil, nil, {}, false
        if entry.bar ~= nil then
            if showOnActionBars then
                icons = {}
                for n = 1, ACTION_BAR_SLOTS do
                    local icon = findComponentByName(entry.bar .. "__GRAPHIC_" .. n)
                    if icon ~= nil and icon.visibleGlobal then
                        icons[n] = icon
                    end
                end
                reportsItems = true   -- bars can only be matched by item
            end
        elseif entry.inv ~= "BANK" or showInBank then
            local layer, layerIcons = findIconLayer(entry)
            if layer ~= nil then
                clip = entry.clip and findComponentByName(entry.clip)
                slotItems = itemsBySlot[entry.inv] or {}
                icons = layerIcons
                -- Only trust item IDs if this layer's icons report real items
                -- (an ID of -1 means empty); otherwise fall back to slots.
                for _, icon in pairs(icons) do
                    local id = iconObjectID(icon)
                    if id ~= nil and id >= 0 then
                        reportsItems = true
                        break
                    end
                end
            end
        end
        if icons ~= nil then
            local inBank = entry.inBank == true
            for slotIndex, icon in pairs(icons) do
                local objID = reportsItems and iconObjectID(icon) or nil
                local item = nil
                -- Action bar slots may report 0 for items you aren't carrying.
                local checkQuantity = entry.bar == nil
                if objID ~= nil then
                    if not checkQuantity or iconQuantity(icon) ~= 0 then
                        item = chargesByObjID[objID]
                    end
                else
                    item = slotItems[slotIndex]
                end
                if item ~= nil then
                    local colour = colours.normal
                    local low = lowThresholds[item.kind]   -- nil for "stored" items
                    if low ~= nil and item.charges <= low then
                        colour = colours.low
                    end
                    local group = getOverlayLabel(layerIndex .. ":" .. slotIndex)
                    setOutlinedContent(group, shortNumber(item.charges), toVector4(colour))
                    -- Bottom-right of the icon, clear of the game's stack count.
                    addPlacement(group, icon, icon.width - OVERLAY_W, icon.height - OVERLAY_H,
                        OVERLAY_W, OVERLAY_H, clip, objID, checkQuantity, inBank)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Invention charge (worn equipment tab)
-------------------------------------------------------------------------------
-- INVENT_CHARGE is charge x 3000. INVENT_COMBAT_CHARGE_DRAIN is drain per game
-- tick in the same units, with perks and research already applied. These
-- match the game's tooltip: charge / 3000, drain / 3000 / 0.6 per second, and
-- time left = charge / drain x 0.6 seconds.

local SECONDS_PER_TICK = 0.6
local INVENTION_LOW_SECONDS = 30 * 60
local INVENTION_W, INVENTION_H = 130, 18
local INVENTION_STYLES = {
    normal = { font = NORMAL_FONT, gap = 16 },
    small  = { font = SMALL_FONT,  gap = 12 },
    xs     = { font = XS_FONT,     gap = 10 },
}

local inventionLabels = nil

-- "6h 38m", "38m 50s" or "45s"
local function formatDuration(seconds)
    seconds = math.floor(seconds)
    local h = seconds // 3600
    local m = (seconds % 3600) // 60
    local sec = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    elseif m > 0 then
        return string.format("%dm %02ds", m, sec)
    end
    return string.format("%ds", sec)
end

-- 167795 -> "167,795"
local function withCommas(n)
    local text = tostring(math.floor(n))
    local count
    repeat
        text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until count == 0
    return text
end

-- Returns nil when there's nothing to show: drain is 0 when no augmented
-- gear is worn, and the variables may be unreadable after a game update.
local function readInvention()
    local charge = readVarPlayer("INVENT_CHARGE")
    local drain = readVarPlayer("INVENT_COMBAT_CHARGE_DRAIN")
    if charge == nil or drain == nil or drain <= 0 then
        return nil
    end
    return {
        charge = charge / 3000,
        perSecond = drain / 3000 / SECONDS_PER_TICK,
        secondsLeft = charge / drain * SECONDS_PER_TICK,
    }
end

local function renderInvention()
    if inventionLabels == nil then
        inventionLabels = {}
        for i = 1, #INVENTION_LINES do
            inventionLabels[i] = newOutlinedText(parentLayer, INVENTION_W, INVENTION_H)
        end
    end
    -- Anchored to the whole worn tab rather than the item grid, which the
    -- game re-centres when the window is resized.
    local info = readInvention()
    local layer = findComponentByName(WORN_CONTENT_LAYER)
        or findComponentByName(WORN_ITEM_LAYER)
    if info == nil or layer == nil or not layer.visibleGlobal then
        return
    end

    local texts = {}
    if showInventionLine.time then
        texts[#texts + 1] = "Time left " .. formatDuration(info.secondsLeft)
    end
    if showInventionLine.charge then
        texts[#texts + 1] = "Charge " .. withCommas(info.charge)
    end
    if showInventionLine.drain then
        texts[#texts + 1] = string.format("Drain %.2f/s", info.perSecond)
    end

    local colour = colours.invention
    if info.secondsLeft < INVENTION_LOW_SECONDS then
        colour = colours.invention_low
    end
    local colourVec = toVector4(colour)
    local style = INVENTION_STYLES[inventionTextSize]

    for i, text in ipairs(texts) do
        setOutlinedFont(inventionLabels[i], style.font)
        setOutlinedContent(inventionLabels[i], text, colourVec)
        addPlacement(inventionLabels[i], layer, 4, 4 + (i - 1) * style.gap,
            INVENTION_W, INVENTION_H)
    end
end

-------------------------------------------------------------------------------
-- Updating
-------------------------------------------------------------------------------

local function render()
    if parentLayer == nil then return end
    for _, group in pairs(overlayLabels) do
        hideOutlinedText(group)
    end
    for _, group in ipairs(inventionLabels or {}) do
        hideOutlinedText(group)
    end
    placements = {}
    findBankComponents()
    renderChargeNumbers(lastItems)
    renderInvention()
    reposition()
end

-- Drawing errors are reported once instead of on every tick.
local renderWarned = false
local function safeRender()
    local ok, err = pcall(render)
    if not ok and not renderWarned then
        print("Item Charges: display error: " .. tostring(err))
        renderWarned = true
    end
end

local function refresh()
    if Player.IsAvailable() then
        lastItems = collectChargedItems()
    else
        lastItems = {}
    end
    safeRender()
end

Event.InventoryAdded.Subscribe("itemChargesAdded", refresh)
Event.InventoryUpdated.Subscribe("itemChargesUpdated", refresh)
Event.InventoryRemoved.Subscribe("itemChargesRemoved", refresh)

-- Windows can be opened or closed at any time, so redraw every game tick
-- from the last scan, and follow scrolling and dragging between ticks.
Event.ServerLogic.Subscribe("itemChargesRedraw", safeRender)

Event.Logic.Subscribe("itemChargesReposition", function()
    if parentLayer == nil then return end
    local ok, changed = pcall(reposition)
    if ok and changed then
        safeRender()   -- an item was moved; redraw without waiting for the server
    end
end)

Event.VarTransmit.Subscribe("itemChargesInvention", function(e)
    local ok, relevant = pcall(function()
        return e.var == var.VarPlayer.INVENT_CHARGE
            or e.var == var.VarPlayer.INVENT_COMBAT_CHARGE_DRAIN
    end)
    if ok and relevant then
        safeRender()
    end
end)

-- Items charged from a player variable: rescan when one of those changes.
Event.VarTransmit.Subscribe("itemChargesStoredCharges", function(e)
    local ok, relevant = pcall(function()
        for _, varName in pairs(VAR_CHARGED_ITEMS) do
            if e.var == var.VarPlayer[varName] then return true end
        end
        return false
    end)
    if ok and relevant then
        refresh()
    end
end)

refresh()


-------------------------------------------------------------------------------
-- Potion cauldrons (player-owned house)
-------------------------------------------------------------------------------
-- Each of the 5 cauldrons is one player variable packing three values:
--   bit 0       built
--   bits 1-12   potion ID, matching column 1 of the HERBLORE_POTION table
--   bits 13-24  doses stored
-- The potion's name comes from that table's row: column 2 is a struct with a
-- POTION_GENERIC_NAME param. The table's rows have consecutive IDs, so they
-- are found by walking outward from one known row. Only columns 1 and 2 are
-- read; other columns hold value types plugins can't receive.

local CAULDRON_COUNT = 5
local CAULDRON_LOC_IDS = { [138359] = true, [138360] = true, [138361] = true }

-- Entering the house: the house is a 256x256 instance (RegionCreated), and its
-- plot boundary is made of server-placed invisible walls (LocAdded, loc
-- 139139). Other instances checked don't have them. A cauldron loading also
-- counts. LocAdded only reports server-placed scenery, not the fixed map.
local HOUSE_REGION_SIZE = 256
local HOUSE_WALL_LOC_ID = 139139
local HOUSE_WALL_MIN = 4
local SEED_POTION_ROW = "HERBLORE_POTION_WILDERNESS_AGGRESSION_POTION"
local SEED_POTION_ROW_ID = 19286
local ROW_GAP_LIMIT = 50   -- stop walking after this many rows from other tables

local potionNames = nil    -- potion ID -> name, built on first use
local cauldronWindow = nil
local cauldronRows = {}
local cauldronRowColour = nil  -- PrettyUI's default text colour, to restore
local cauldronWindowOpen = false
local cauldronShownThisVisit = false
local cauldronOffset = nil     -- viewport screen position minus the window's x, y
local lastCauldronValues = nil -- raw cauldron variables at the last update
local inHouse = false
local cauldronLabels = {}      -- spot -> outlined number over a cauldron
local lastSlotValues = {}      -- cauldron number -> raw variable at the last tick
local houseTicks = 0           -- game ticks since entering the house
local inLargeInstance = false
local houseWallsSeen = 0

local function readCauldrons()
    local list = {}
    for n = 1, CAULDRON_COUNT do
        local raw = readVarPlayer("CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n)
        if raw ~= nil and raw & 1 == 1 then
            list[#list + 1] = { number = n, potionID = (raw >> 1) & 0xFFF, doses = (raw >> 13) & 0xFFF }
        end
    end
    return list
end

local function buildPotionNames()
    local names = {}
    local seed = nil
    pcall(function() seed = config.DBRow[SEED_POTION_ROW] end)
    if seed == nil then
        pcall(function() seed = config.DBRow.FromID(SEED_POTION_ROW_ID) end)
    end
    if seed == nil then return names end
    local tableID = seed.ownerDBTable.id
    local nameParam = config.Param.POTION_GENERIC_NAME

    local function readRow(rowID)
        local ok, row = pcall(function() return config.DBRow.FromID(rowID) end)
        if not ok or row == nil or row.ownerDBTable.id ~= tableID then
            return false
        end
        pcall(function()
            local potionID = row:GetColumnValues(1)[1]
            local struct = row:GetColumnValues(2)[1]
            names[potionID] = struct:GetParamValue(nameParam)
        end)
        return true
    end

    for _, step in ipairs({ -1, 1 }) do
        local rowID, misses = seed.id, 0
        while misses < ROW_GAP_LIMIT do
            if readRow(rowID) then misses = 0 else misses = misses + 1 end
            rowID = rowID + step
        end
    end
    return names
end

local function cauldronLines()
    if potionNames == nil then
        potionNames = buildPotionNames()
    end
    local lines = {}
    -- Numbered by the game's cauldron number, which the labels over the
    -- cauldrons in the house also show. lows[i] is true when line i needs a
    -- refill.
    local lows = {}
    for _, c in ipairs(readCauldrons()) do
        local refill = c.doses <= refillAt and "  (refill)" or ""
        if c.doses == 0 then
            lines[#lines + 1] = c.number .. ". Empty" .. refill
        else
            local name = potionNames[c.potionID] or ("Unknown potion (" .. c.potionID .. ")")
            lines[#lines + 1] = string.format("%d. %s: %d dose%s%s", c.number, name, c.doses,
                c.doses == 1 and "" or "s", refill)
        end
        lows[#lines] = refill ~= ""
    end
    if #lines == 0 then
        lines[1] = "No potion cauldrons built."
    end
    return lines, lows
end

-- The window is sized to its lines, so it's rebuilt if the number of lines
-- changes (for example, a cauldron is built while it's open).
local function buildCauldronWindow(lineCount)
    if cauldronWindow ~= nil then
        pcall(function() cauldronWindow:Destroy() end)
    end
    cauldronWindow = prettyui.Window.new(parentLayer, {
        title = "Potion cauldrons",
        x = cauldronX, y = cauldronY, width = 300, height = 44 + lineCount * 26,
        onClose = function() cauldronWindowOpen = false end,
    })
    cauldronOffset = nil
    cauldronRows = {}
    cauldronRowColour = nil
    for i = 1, lineCount do
        cauldronRows[i] = cauldronWindow:AddText("")
    end
    pcall(function() cauldronRowColour = cauldronRows[1].colour end)
end

local function cauldronValuesKey()
    local values = {}
    for n = 1, CAULDRON_COUNT do
        values[n] = tostring(readVarPlayer("CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n))
    end
    return table.concat(values, ",")
end

local function updateCauldronWindow()
    if cauldronWindow == nil then return end
    lastCauldronValues = cauldronValuesKey()
    local lines, lows = cauldronLines()
    if #lines ~= #cauldronRows then
        -- Destroying the old window may run its onClose, so remember whether
        -- it was open first.
        local wasOpen = cauldronWindowOpen
        buildCauldronWindow(#lines)
        cauldronWindowOpen = wasOpen
        if wasOpen then cauldronWindow:Show() end
    end
    for i, line in ipairs(lines) do
        cauldronRows[i].content = line
        -- Lines needing a refill use the refill colour; the rest keep
        -- PrettyUI's own text colour.
        if lows[i] then
            cauldronRows[i].colour = toVector4(colours.cauldron_low)
        elseif cauldronRowColour ~= nil then
            cauldronRows[i].colour = cauldronRowColour
        end
    end
end

-- PrettyUI can't report where a window has been dragged, so the position is
-- worked out from the window's viewport component: its screen position now,
-- minus how far it sat from the window's x, y when it was first shown.
local function trackCauldronPosition()
    local p = cauldronWindow.viewport.xyGlobal
    if cauldronOffset == nil then
        cauldronOffset = { x = p.x - cauldronX, y = p.y - cauldronY }
        return
    end
    local x = math.max(0, math.floor(p.x - cauldronOffset.x))
    local y = math.max(0, math.floor(p.y - cauldronOffset.y))
    if x ~= cauldronX or y ~= cauldronY then
        cauldronX, cauldronY = x, y
        saveSetting("cauldron_x", x)
        saveSetting("cauldron_y", y)
    end
end

local function showCauldronWindow()
    if parentLayer == nil or prettyui == nil then return end
    if cauldronWindow == nil then
        buildCauldronWindow(#cauldronLines())
    end
    cauldronWindowOpen = true
    updateCauldronWindow()
    cauldronWindow:Show()
end

local function closeCauldronWindow()
    if cauldronWindow ~= nil and cauldronWindowOpen then
        pcall(function() cauldronWindow:Close() end)
    end
    cauldronWindowOpen = false
end

local function enteredHouse()
    inHouse = true
    if cauldronMode ~= "house" or cauldronShownThisVisit then return end
    cauldronShownThisVisit = true
    pcall(showCauldronWindow)
end

Event.LocAdded.Subscribe("itemChargesHouseLoc", function(e)
    local ok, locID = pcall(function() return e.config.id end)
    if not ok then return end
    if CAULDRON_LOC_IDS[locID] then
        enteredHouse()
    elseif locID == HOUSE_WALL_LOC_ID and inLargeInstance then
        houseWallsSeen = houseWallsSeen + 1
        if houseWallsSeen >= HOUSE_WALL_MIN then
            enteredHouse()
        end
    end
end)

local function changedArea(isLargeInstance)
    inLargeInstance = isLargeInstance
    houseWallsSeen = 0
    cauldronShownThisVisit = false
    closeCauldronWindow()
    inHouse = false
    houseTicks = 0
    lastSlotValues = {}
    for _, label in pairs(cauldronLabels) do
        pcall(hideOutlinedText, label)
    end
end
Event.WorldCreated.Subscribe("itemChargesCauldronWorld", function()
    pcall(changedArea, false)
end)
Event.RegionCreated.Subscribe("itemChargesCauldronRegion", function(e)
    pcall(function()
        changedArea(e.regionGridWidth == HOUSE_REGION_SIZE and e.regionGridLength == HOUSE_REGION_SIZE)
    end)
end)

Event.VarTransmit.Subscribe("itemChargesCauldronVars", function(e)
    if cauldronWindow == nil then return end
    pcall(function()
        for n = 1, CAULDRON_COUNT do
            if e.var == var.VarPlayer["CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n] then
                updateCauldronWindow()
                return
            end
        end
    end)
end)

-- Every game tick while the window is open: save its position if it was
-- dragged, and catch cauldron changes that arrived without a VarTransmit
-- (a newly built cauldron didn't show until the house was re-entered).
Event.ServerLogic.Subscribe("itemChargesCauldronTick", function()
    if cauldronWindow == nil or not cauldronWindowOpen then return end
    pcall(trackCauldronPosition)
    pcall(function()
        if cauldronValuesKey() ~= lastCauldronValues then
            updateCauldronWindow()
        end
    end)
end)

-------------------------------------------------------------------------------
-- Cauldron number labels
-------------------------------------------------------------------------------
-- A number over each cauldron in the house, matching the panel's numbering.
-- The game doesn't say which cauldron object is which number, so the plugin
-- learns it: when one cauldron's variable changes (drinking, filling or
-- building), the cauldron the player is standing next to is that number.
-- Matches are saved by the cauldron's spot in the house, so they're kept
-- between visits. Unmatched cauldrons show "?".

local LABEL_RANGE_SQ = 5       -- squared tiles: next to it, including diagonally
local LABEL_HEIGHT = 700       -- fine units above the tile (a tile is 512)
local LABEL_W, LABEL_H = 40, 24
local LEARN_AFTER_TICKS = 5    -- ignore the variables arriving as the house loads

local function isMap(v) return type(v) == "table" end
local cauldronMap = loadSetting("cauldron_map", isMap, {})  -- spot -> number
local cauldronLocs = {}        -- spot -> cauldron object, refreshed every tick

-- A cauldron's spot: its tile within the house, which stays the same between
-- visits even if the house instance is placed elsewhere in the world.
local function spotKey(loc)
    local c = loc.coordGrid
    return c.level .. ":" .. c.localX .. ":" .. c.localZ
end

local function findCauldronLocs()
    local found = {}
    for locID in pairs(CAULDRON_LOC_IDS) do
        local ok, locs = pcall(function() return LocList.ByConfigID(locID) end)
        if ok and locs ~= nil then
            for _, loc in ipairs(locs) do
                local okKey, key = pcall(spotKey, loc)
                if okKey then found[key] = loc end
            end
        end
    end
    return found
end

-- The one cauldron closest to the player, if it's next to them. Nil when two
-- are equally close, since then it can't be told which one was used.
local function cauldronNextToPlayer()
    local p = Player.GetEntity().coordGrid
    local bestKey, bestDist, tied = nil, LABEL_RANGE_SQ + 1, false
    for key, loc in pairs(cauldronLocs) do
        local c = loc.coordGrid
        if c.level == p.level then
            local d = (c.x - p.x) ^ 2 + (c.z - p.z) ^ 2
            if d < bestDist then
                bestKey, bestDist, tied = key, d, false
            elseif d == bestDist then
                tied = true
            end
        end
    end
    if tied then return nil end
    return bestKey
end

local function learnCauldron(number)
    local key = cauldronNextToPlayer()
    if key == nil or cauldronMap[key] == number then return end
    for k, n in pairs(cauldronMap) do
        if n == number then cauldronMap[k] = nil end
    end
    cauldronMap[key] = number
    saveSetting("cauldron_map", cauldronMap)
end

local function placeCauldronLabels()
    for key, label in pairs(cauldronLabels) do
        local loc = cauldronLocs[key]
        local pos = nil
        if loc ~= nil then
            pcall(function() pos = ScreenConvert.CoordGridToScreen(loc.coordGrid, LABEL_HEIGHT) end)
        end
        if pos == nil then
            hideOutlinedText(label)
        else
            placeOutlinedText(label, math.floor(pos.x - LABEL_W / 2), math.floor(pos.y - LABEL_H / 2))
        end
    end
end

local function cauldronLabelTick()
    houseTicks = houseTicks + 1
    cauldronLocs = findCauldronLocs()

    for n = 1, CAULDRON_COUNT do
        local raw = readVarPlayer("CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n)
        if houseTicks > LEARN_AFTER_TICKS and lastSlotValues[n] ~= nil and raw ~= lastSlotValues[n] then
            pcall(learnCauldron, n)
        end
        lastSlotValues[n] = raw
    end

    for key in pairs(cauldronLocs) do
        if cauldronLabels[key] == nil then
            cauldronLabels[key] = newOutlinedText(parentLayer, LABEL_W, LABEL_H)
        end
        local number = cauldronMap[key]
        local colour = colours.normal
        local raw = number and lastSlotValues[number]
        if raw ~= nil and (raw >> 13) & 0xFFF <= refillAt then
            colour = colours.cauldron_low
        end
        setOutlinedContent(cauldronLabels[key], number and tostring(number) or "?", toVector4(colour))
    end
    placeCauldronLabels()
end

Event.ServerLogic.Subscribe("itemChargesCauldronLabels", function()
    if not inHouse or parentLayer == nil then return end
    pcall(cauldronLabelTick)
end)

-- Labels follow the camera smoothly between game ticks.
Event.Logic.Subscribe("itemChargesCauldronLabelsMove", function()
    if not inHouse then return end
    pcall(placeCauldronLabels)
end)

-------------------------------------------------------------------------------
-- Potion supplies
-------------------------------------------------------------------------------
-- A restock list: the total doses of each potion across the backpack, beast
-- of burden and bank, lowest first. The bank's contents are only sent while
-- it's open, so its totals are saved and reused until the next visit.
-- Potions are grouped by name without the dose, so "Super restore (4)" and
-- "Super restore (2)" add together, but flasks are counted separately.

local SUPPLY_LIVE_INVENTORIES = { "INV", "LORE_BOB" }
-- The window grows to fit up to this many lines, then scrolls.
local SUPPLIES_MAX_VISIBLE_LINES = 15

local savedBankDoses = loadSetting("supplies_bank_doses",
    function(v) return type(v) == "table" end, {})
local suppliesWindow = nil
local supplyRows = {}
local suppliesWindowOpen = false

-- Adds each potion's doses in one inventory to totals (a stack of 10
-- "Super restore (4)" adds 40). Returns how many filled slots it saw, so an
-- unavailable or empty bank can be told apart from a bank with no potions.
local function addPotionDoses(invName, totals)
    local inv = findInventory(invName)
    if inv == nil then return 0 end
    local filled = 0
    for slotIndex = 1, inv.slotCount do
        local slot = inv:GetSlot(slotIndex)
        if slot ~= nil and slot.obj ~= nil and slot.obj.name ~= "" and (slot.count or 0) > 0 then
            filled = filled + 1
            local baseName, doses = parseCharges(slot.obj.name)
            if baseName ~= nil and isPotion(slot.obj, baseName) then
                totals[baseName] = (totals[baseName] or 0) + doses * slot.count
            end
        end
    end
    return filled
end

local function sameTotals(a, b)
    for name, doses in pairs(a) do
        if b[name] ~= doses then return false end
    end
    for name in pairs(b) do
        if a[name] == nil then return false end
    end
    return true
end

-- Saves the bank's totals while it's open, only when they've changed.
local function saveBankIfOpen()
    local bank = {}
    if addPotionDoses("BANK", bank) > 0 and not sameTotals(bank, savedBankDoses) then
        savedBankDoses = bank
        saveSetting("supplies_bank_doses", bank)
    end
end

local function supplyLines()
    local totals = {}
    for name, doses in pairs(savedBankDoses) do
        totals[name] = doses
    end
    for _, invName in ipairs(SUPPLY_LIVE_INVENTORIES) do
        addPotionDoses(invName, totals)
    end

    local list = {}
    for name, doses in pairs(totals) do
        list[#list + 1] = { name = name, doses = doses }
    end
    table.sort(list, function(a, b)
        if a.doses ~= b.doses then return a.doses < b.doses end
        return a.name < b.name
    end)

    local lines = {}
    local restockCount = 0
    for _, potion in ipairs(list) do
        local restock = ""
        if potion.doses <= restockAt then
            restock = "  (restock)"
            restockCount = restockCount + 1
        end
        lines[#lines + 1] = string.format("%s: %d dose%s%s", potion.name, potion.doses,
            potion.doses == 1 and "" or "s", restock)
    end
    if #lines == 0 then
        lines[1] = "No potions found. Open your bank once to include it."
    end
    return lines, restockCount
end

-- Where the list window opens: from the settings page, the left edge of the
-- screen; from the bank, under the summary beside the bank.
local suppliesPos = { x = 40, y = 200 }

-- Same approach as the cauldron window: sized to its lines, rebuilt when the
-- number of lines changes. PrettyUI windows have a scroll bar, so long lists
-- are capped at a sensible height and scrolled.
local function buildSuppliesWindow(lineCount)
    if suppliesWindow ~= nil then
        pcall(function() suppliesWindow:Destroy() end)
    end
    suppliesWindow = prettyui.Window.new(parentLayer, {
        title = "Potion supplies",
        x = suppliesPos.x, y = suppliesPos.y, width = 440,
        height = 44 + math.min(lineCount, SUPPLIES_MAX_VISIBLE_LINES) * 26,
        onClose = function() suppliesWindowOpen = false end,
    })
    supplyRows = {}
    for i = 1, lineCount do
        supplyRows[i] = suppliesWindow:AddText("")
    end
end

local function updateSuppliesWindow()
    if suppliesWindow == nil or not suppliesWindowOpen then return end
    local lines = supplyLines()
    if #lines ~= #supplyRows then
        buildSuppliesWindow(#lines)
        suppliesWindow:Show()
    end
    for i, line in ipairs(lines) do
        supplyRows[i].content = line
    end
end

-- x and y are optional; the window is rebuilt if it should open elsewhere.
local function showSuppliesWindow(x, y)
    if parentLayer == nil or prettyui == nil then return end
    x, y = x or 40, y or 200
    if suppliesWindow == nil or x ~= suppliesPos.x or y ~= suppliesPos.y then
        suppliesPos = { x = x, y = y }
        buildSuppliesWindow(#supplyLines())
    end
    suppliesWindowOpen = true
    updateSuppliesWindow()
    suppliesWindow:Show()
end

local function closeSuppliesWindow()
    if suppliesWindow ~= nil and suppliesWindowOpen then
        pcall(function() suppliesWindow:Close() end)
    end
    suppliesWindowOpen = false
end

-- The summary beside the bank: how many potions need restocking, and a
-- button that opens the full list underneath it.
local summaryWindow = nil
local summaryText = nil
local SUMMARY_W, SUMMARY_H = 260, 120

local function summaryLine()
    local _, restockCount = supplyLines()
    if restockCount == 0 then return "Nothing to restock." end
    return string.format("%d potion%s to restock.", restockCount, restockCount == 1 and "" or "s")
end

local function updateSummary()
    if summaryText ~= nil then
        summaryText.content = summaryLine()
    end
end

local function closeSummary()
    if summaryWindow ~= nil then
        pcall(function() summaryWindow:Destroy() end)
    end
    summaryWindow, summaryText = nil, nil
end

local function showSummary(x, y)
    closeSummary()
    summaryWindow = prettyui.Window.new(parentLayer, {
        title = "Potion supplies", x = x, y = y, width = SUMMARY_W, height = SUMMARY_H,
    })
    summaryText = summaryWindow:AddText(summaryLine())
    summaryWindow:AddFancyButton("Show list", function()
        local ok, err = pcall(showSuppliesWindow, x, y + SUMMARY_H + 10)
        if not ok then print("Item Charges: supplies panel error: " .. tostring(err)) end
    end)
    summaryWindow:Show()
end

local function onSuppliesChanged()
    pcall(function()
        saveBankIfOpen()
        updateSuppliesWindow()
        updateSummary()
    end)
end
Event.InventoryAdded.Subscribe("itemChargesSuppliesAdded", onSuppliesChanged)
Event.InventoryUpdated.Subscribe("itemChargesSuppliesUpdated", onSuppliesChanged)
Event.InventoryRemoved.Subscribe("itemChargesSuppliesRemoved", onSuppliesChanged)

-- Opening the bank shows the summary to the right of the bank window, and
-- closing the bank closes it (and the list). The bank counts as open while
-- its item area is on screen (bankPartShown); checked once a game tick. The bank window's
-- right edge is just past its backpack panel, and its top is about 95 pixels
-- above the item area (measured from a screenshot).
local BANK_OPEN_COMPONENT = "BANK__BANK_ITEMS_CONTAINER"
local BANK_BACKPACK_COMPONENT = "BANK__INVENTORY_SLOTS"
local BANK_RIGHT_GAP, BANK_TOP_OFFSET = 40, 95
local bankWasOpen = false

local function besideBank(items)
    local backpack = findComponentByName(BANK_BACKPACK_COMPONENT)
    local right = items.xyGlobal.x + items.width
    if bankPartShown(backpack) then
        right = backpack.xyGlobal.x + backpack.width
    end
    return right + BANK_RIGHT_GAP, math.max(0, items.xyGlobal.y - BANK_TOP_OFFSET)
end

Event.ServerLogic.Subscribe("itemChargesSuppliesBank", function()
    pcall(function()
        local items = findComponentByName(BANK_OPEN_COMPONENT)
        local bankOpen = bankPartShown(items)
        if suppliesMode == "bank" then
            if bankOpen and not bankWasOpen then
                showSummary(besideBank(items))
            elseif bankWasOpen and not bankOpen then
                closeSummary()
                closeSuppliesWindow()
            end
        end
        bankWasOpen = bankOpen
    end)
end)

-------------------------------------------------------------------------------
-- Settings page (built with PrettyUI)
-------------------------------------------------------------------------------

local settingsView = nil

local ITEM_COLOUR_SETTINGS = {
    { key = "normal",  label = "Charge number colour" },
    { key = "low",     label = "Low charge colour" },
    { key = "outline", label = "Outline colour (numbers and Invention text)" },
}
local INVENTION_COLOUR_SETTINGS = {
    { key = "invention",     label = "Invention text colour" },
    { key = "invention_low", label = "Invention colour under 30 minutes" },
}

local function addColourPickers(list)
    for _, setting in ipairs(list) do
        local key = setting.key
        settingsView:AddText(setting.label)
        settingsView:AddColourPicker({
            value = toHex(colours[key]),
            buttonSize = 32,
            windowTitle = setting.label,
            onChange = function(picker, colour)
                colours[key] = fromHex(colour)
                saveSetting("colour_" .. key, colours[key])
                safeRender()
            end,
        })
    end
end

local THRESHOLD_SETTINGS = {
    { kind = "potion",    key = "low_threshold_potion",    unit = "doses" },
    { kind = "jewellery", key = "low_threshold_jewellery", unit = "charges" },
}

local function lowThresholdText(setting)
    local label = setting.kind == "potion" and "Potions" or "Jewellery"
    return string.format("%s: low charge colour at %d %s or fewer", label,
        lowThresholds[setting.kind], setting.unit)
end

local function refillText()
    return string.format("Mark cauldrons for refill at %d doses or fewer", refillAt)
end

local function restockText()
    return string.format("Mark for restock at %d doses or fewer", restockAt)
end

local function buildSettingsPage(parent)
    if settingsView ~= nil then
        pcall(function() settingsView:Destroy() end)
        settingsView = nil
    end

    settingsView = prettyui.SimpleView.new(parent, {
        width = parent.width,
        height = parent.height,
    })

    settingsView:AddTitle("Item Charges")
    settingsView:AddText("Changes are saved immediately.")

    settingsView:AddCheckboxButton({
        { text = "Outline the numbers", value = "outline", selected = outlineEnabled },
        { text = "Show numbers in the bank", value = "bank", selected = showInBank },
        { text = "Show numbers on action bars", value = "bars", selected = showOnActionBars },
    }, {
        onChange = function(group, values, changedValue, selected)
            if changedValue == "outline" then
                outlineEnabled = selected == true
                saveSetting("outline_enabled", outlineEnabled)
            elseif changedValue == "bank" then
                showInBank = selected == true
                saveSetting("show_in_bank", showInBank)
            elseif changedValue == "bars" then
                showOnActionBars = selected == true
                saveSetting("show_on_action_bars", showOnActionBars)
            end
            safeRender()
        end,
    })

    -- Sliders may be missing from older PrettyUI versions.
    if settingsView.AddSlider ~= nil then
        for _, setting in ipairs(THRESHOLD_SETTINGS) do
            local label = settingsView:AddText(lowThresholdText(setting))
            settingsView:AddSlider({
                min = 1, max = LOW_THRESHOLD_MAX, step = 1, value = lowThresholds[setting.kind],
                onChange = function(slider, value)
                    value = math.tointeger(value) or math.floor(value + 0.5)
                    if value < 1 or value > LOW_THRESHOLD_MAX then return end
                    lowThresholds[setting.kind] = value
                    saveSetting(setting.key, value)
                    if label ~= nil then
                        label.content = lowThresholdText(setting)
                    end
                    safeRender()
                end,
            })
        end
    end

    addColourPickers(ITEM_COLOUR_SETTINGS)

    settingsView:AddDivider()
    settingsView:AddText("Invention charge (worn equipment tab):")
    local inventionChoices = {}
    for _, line in ipairs(INVENTION_LINES) do
        inventionChoices[#inventionChoices + 1] = {
            text = line.text, value = line.value, selected = showInventionLine[line.value],
        }
    end
    settingsView:AddCheckboxButton(inventionChoices, {
        onChange = function(group, values, changedValue, selected)
            if inventionLineKeys[changedValue] == nil then return end
            showInventionLine[changedValue] = selected == true
            saveSetting(inventionLineKeys[changedValue], showInventionLine[changedValue])
            safeRender()
        end,
    })

    -- Radio buttons may be missing from older PrettyUI versions.
    if settingsView.AddRadioButton ~= nil then
        settingsView:AddText("Invention text size:")
        settingsView:AddRadioButton({
            { text = "Normal", value = "normal" },
            { text = "Small",  value = "small" },
            { text = "XS",     value = "xs" },
        }, {
            selectedValue = inventionTextSize,
            inline = true,
            onChange = function(group, value)
                if not TEXT_SIZES[value] then return end
                inventionTextSize = value
                saveSetting("invention_text_size", inventionTextSize)
                safeRender()
            end,
        })
    end

    addColourPickers(INVENTION_COLOUR_SETTINGS)

    settingsView:AddDivider()
    settingsView:AddText("Potion cauldron panel:")
    if settingsView.AddRadioButton ~= nil then
        settingsView:AddRadioButton({
            { text = "When I enter my house", value = "house" },
            { text = "Off", value = "off" },
        }, {
            selectedValue = cauldronMode,
            inline = true,
            onChange = function(group, value)
                if not CAULDRON_MODES[value] then return end
                cauldronMode = value
                saveSetting("cauldron_panel", cauldronMode)
            end,
        })
    end
    if settingsView.AddFancyButton ~= nil then
        settingsView:AddFancyButton("Show cauldron panel now", function()
            local ok, err = pcall(showCauldronWindow)
            if not ok then print("Item Charges: cauldron panel error: " .. tostring(err)) end
        end)
    end
    if settingsView.AddSlider ~= nil then
        local label = settingsView:AddText(refillText())
        settingsView:AddSlider({
            min = 0, max = REFILL_MAX, step = REFILL_STEP, value = refillAt,
            onChange = function(slider, value)
                value = math.tointeger(value) or math.floor(value + 0.5)
                if value < 0 or value > REFILL_MAX then return end
                refillAt = value
                saveSetting("cauldron_refill_at", value)
                if label ~= nil then
                    label.content = refillText()
                end
                pcall(updateCauldronWindow)
            end,
        })
    end
    settingsView:AddText("Cauldron refill colour (panel and numbers over cauldrons)")
    settingsView:AddColourPicker({
        value = toHex(colours.cauldron_low),
        buttonSize = 32,
        windowTitle = "Cauldron refill colour",
        onChange = function(picker, colour)
            colours.cauldron_low = fromHex(colour)
            saveSetting("colour_cauldron_low", colours.cauldron_low)
            pcall(updateCauldronWindow)
        end,
    })

    settingsView:AddDivider()
    -- Kept short: the radio buttons sit on the same row and get cut off.
    settingsView:AddText("Potion supplies (counts your backpack, beast of burden and bank).")
    settingsView:AddText("Potion supplies panel:")
    if settingsView.AddRadioButton ~= nil then
        settingsView:AddRadioButton({
            { text = "Beside my bank", value = "bank" },
            { text = "Off", value = "off" },
        }, {
            selectedValue = suppliesMode,
            inline = true,
            onChange = function(group, value)
                if not SUPPLIES_MODES[value] then return end
                suppliesMode = value
                saveSetting("supplies_panel", suppliesMode)
            end,
        })
    end
    if settingsView.AddSlider ~= nil then
        local label = settingsView:AddText(restockText())
        settingsView:AddSlider({
            min = 0, max = RESTOCK_MAX, step = RESTOCK_STEP, value = restockAt,
            onChange = function(slider, value)
                value = math.tointeger(value) or math.floor(value + 0.5)
                if value < 0 or value > RESTOCK_MAX then return end
                restockAt = value
                saveSetting("supplies_restock_at", value)
                if label ~= nil then
                    label.content = restockText()
                end
                onSuppliesChanged()
            end,
        })
    end
    if settingsView.AddFancyButton ~= nil then
        settingsView:AddFancyButton("Show potion supplies", function()
            local ok, err = pcall(showSuppliesWindow)
            if not ok then print("Item Charges: supplies panel error: " .. tostring(err)) end
        end)
    end

    settingsView:AddDivider()
    settingsView:AddText("Settings page built with PrettyUI by rsnJ3 (prettyui.j3.gg).")
end

Event.SettingsLayerReady.Subscribe("itemChargesSettings", function(settingsEvent)
    local ok, err = pcall(buildSettingsPage, settingsEvent.component)
    if not ok then
        print("Item Charges: settings page error: " .. tostring(err))
    end
end)

function PluginShutdown()
    Event.SettingsLayerReady.Unsubscribe("itemChargesSettings")
    if settingsView ~= nil then
        pcall(function() settingsView:Destroy() end)
        settingsView = nil
    end
    if cauldronWindow ~= nil then
        pcall(function() cauldronWindow:Destroy() end)
        cauldronWindow = nil
    end
    for _, label in pairs(cauldronLabels) do
        pcall(hideOutlinedText, label)
    end
    if suppliesWindow ~= nil then
        pcall(function() suppliesWindow:Destroy() end)
        suppliesWindow = nil
    end
    closeSummary()
end
