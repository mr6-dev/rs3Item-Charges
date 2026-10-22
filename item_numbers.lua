-- Item Charges: item_numbers.lua
-- Finds charged items (jewellery, potions and the Spring cleaner) in your
-- inventories and draws their charges or doses on their icons, in the
-- backpack, worn equipment, bank, beast of burden and action bars.

local core = require("core")
local widgets = require("widgets")
local positioning = require("positioning")

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

-- For items in VAR_CHARGED_ITEMS: their charges, or nil.
local function varCharges(itemName)
    local varName = VAR_CHARGED_ITEMS[string.lower(itemName)]
    return varName and core.readVarPlayer(varName)
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
                            baseName = baseName and string.lower(baseName),
                            count = slot.count,
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
-- Charge numbers on item icons
-------------------------------------------------------------------------------

local OVERLAY_W, OVERLAY_H = 22, 16

local overlayLabels = {}   -- keyed "<icon layer index>:<slot>"

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
        group = widgets.newOutlinedText(widgets.parentLayer, OVERLAY_W, OVERLAY_H)
        overlayLabels[key] = group
    end
    return group
end

-- Returns the visible icon layer for an entry and its icons, or nil. With a
-- list of candidates, the first visible one that has icons is used.

local function findIconLayer(entry)
    local names = entry.layers or { entry.layer }
    for _, name in ipairs(names) do
        local layer = widgets.findComponentByName(name)
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

-- Action bar potions show the total doses of that potion in the backpack,
-- every dose size together ("Super restore (4)" and "(2)" make 6). This finds
-- the potion's name without the dose for a bar item, or nil if it isn't a
-- potion. The item may not be carried, so it's looked up if need be.
local function barPotionName(objID)
    local known = chargesByObjID[objID]
    if known ~= nil then
        return known.kind == "potion" and known.baseName or nil
    end
    local ok, base = pcall(function()
        local obj = config.Obj.FromID(objID)
        local name = parseCharges(obj.name)
        return name and itemKind(obj, name) == "potion" and string.lower(name) or nil
    end)
    return ok and base or nil
end

local function hideChargeNumbers()
    for _, group in pairs(overlayLabels) do
        widgets.hideOutlinedText(group)
    end
end

local function renderChargeNumbers(items)
    -- Slot -> item for each inventory, for icons that don't report an item.
    -- Also the backpack's total doses of each potion, for action bars.
    local itemsBySlot, backpackDoses = {}, {}
    for _, item in ipairs(items) do
        itemsBySlot[item.invName] = itemsBySlot[item.invName] or {}
        itemsBySlot[item.invName][item.slotIndex] = item
        if item.invName == "INV" and item.kind == "potion" then
            backpackDoses[item.baseName] = (backpackDoses[item.baseName] or 0) + item.charges * (item.count or 1)
        end
    end

    for layerIndex, entry in ipairs(ICON_LAYERS) do
        local icons, clip, slotItems, reportsItems = nil, nil, {}, false
        if entry.bar ~= nil then
            if core.showOnActionBars then
                icons = {}
                for n = 1, ACTION_BAR_SLOTS do
                    local icon = widgets.findComponentByName(entry.bar .. "__GRAPHIC_" .. n)
                    if icon ~= nil and icon.visibleGlobal then
                        icons[n] = icon
                    end
                end
                reportsItems = true   -- bars can only be matched by item
            end
        elseif entry.inv ~= "BANK" or core.showInBank then
            local layer, layerIcons = findIconLayer(entry)
            if layer ~= nil then
                clip = entry.clip and widgets.findComponentByName(entry.clip)
                slotItems = itemsBySlot[entry.inv] or {}
                icons = layerIcons
                -- Only trust item IDs if this layer's icons report real items
                -- (an ID of -1 means empty); otherwise fall back to slots.
                for _, icon in pairs(icons) do
                    local id = widgets.iconObjectID(icon)
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
                local objID = reportsItems and widgets.iconObjectID(icon) or nil
                local item = nil
                -- Action bar slots may report 0 for items you aren't carrying.
                local checkQuantity = entry.bar == nil
                local barPotion = entry.bar ~= nil and objID ~= nil and barPotionName(objID)
                if barPotion then
                    -- No number when none of that potion is in the backpack.
                    local total = backpackDoses[barPotion]
                    item = total and { charges = total, kind = "potion" }
                elseif objID ~= nil then
                    if not checkQuantity or widgets.iconQuantity(icon) ~= 0 then
                        item = chargesByObjID[objID]
                    end
                else
                    item = slotItems[slotIndex]
                end
                if item ~= nil then
                    local colour = core.colours.normal
                    local low = core.lowThresholds[item.kind]   -- nil for "stored" items
                    if low ~= nil and item.charges <= low then
                        colour = core.colours.low
                    end
                    local group = getOverlayLabel(layerIndex .. ":" .. slotIndex)
                    widgets.setOutlinedContent(group, shortNumber(item.charges), core.toVector4(colour))
                    -- Bottom-right of the icon, clear of the game's stack count.
                    positioning.addPlacement(group, icon, icon.width - OVERLAY_W, icon.height - OVERLAY_H,
                        OVERLAY_W, OVERLAY_H, clip, objID, checkQuantity, inBank)
                end
            end
        end
    end
end

return {
    VAR_CHARGED_ITEMS = VAR_CHARGED_ITEMS,
    collectChargedItems = collectChargedItems,
    findInventory = findInventory,
    hideChargeNumbers = hideChargeNumbers,
    isPotion = isPotion,
    parseCharges = parseCharges,
    renderChargeNumbers = renderChargeNumbers,
}
