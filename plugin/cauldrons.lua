-- Item Charges: cauldrons.lua
-- Potion cauldrons in your player-owned house: a panel listing each one's
-- potion and doses, and each potion's icon (or the cauldron's number) above
-- its cauldron.

local core = require("core")
local widgets = require("widgets")

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
local potionItems = {}     -- potion ID -> item ID of its highest dose, for its icon
-- Wide enough for "1. Elder overload salve: 107 doses  (refill)". Opens where
-- it was last dragged to, even after a logout.
local cauldronPanel = widgets.ListWindow.new("Potion cauldrons", 400, 40, 200, nil, "cauldron")
local cauldronShownThisVisit = false
local lastCauldronValues = nil -- raw cauldron variables at the last update
local inHouse = false
local cauldronLabels = {}      -- spot -> outlined number over a cauldron
local lastSlotValues = {}      -- cauldron number -> raw variable at the last tick
local houseTicks = 0           -- game ticks since entering the house
local inLargeInstance = false
local houseWallsSeen = 0

-- A label over a cauldron: its number (outlined text) and maybe an icon.
local function hideCauldronLabel(label)
    widgets.hideOutlinedText(label)
    if label.icon ~= nil then label.icon.hidden = true end
end

local function readCauldronVar(n)
    return core.readVarPlayer("CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n)
end

local function readCauldrons()
    local list = {}
    for n = 1, CAULDRON_COUNT do
        local raw = readCauldronVar(n)
        if raw ~= nil and raw & 1 == 1 then
            list[#list + 1] = { number = n, potionID = (raw >> 1) & 0xFFF, doses = (raw >> 13) & 0xFFF }
        end
    end
    return list
end

-- The struct also holds each dose's item (params POTIONDOSES_4 down to _1;
-- some potions only have a 1-dose item, and some only come in flasks), used
-- to draw the potion's icon. Missing params are skipped.
local POTION_DOSE_PARAMS = { "POTIONDOSES_4", "POTIONDOSES_3", "POTIONDOSES_2", "POTIONDOSES_1",
    "BIGPOT_DOSES6", "BIGPOT_DOSES5", "BIGPOT_DOSES4", "BIGPOT_DOSES3", "BIGPOT_DOSES2", "BIGPOT_DOSES1" }

-- Returns potion ID -> name, and potion ID -> item ID.
local function buildPotionNames()
    local names, items = {}, {}
    local seed = nil
    pcall(function() seed = config.DBRow[SEED_POTION_ROW] end)
    if seed == nil then
        pcall(function() seed = config.DBRow.FromID(SEED_POTION_ROW_ID) end)
    end
    if seed == nil then return names, items end
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
            for _, paramName in ipairs(POTION_DOSE_PARAMS) do
                local okItem, item = pcall(function() return struct:GetParamValue(config.Param[paramName]).id end)
                if okItem and item ~= nil and item > 0 then
                    items[potionID] = item
                    break
                end
            end
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
    return names, items
end

local function loadPotions()
    if potionNames == nil then
        potionNames, potionItems = buildPotionNames()
    end
end

-- Numbered by the game's cauldron number, which the labels over the cauldrons
-- in the house also show. Lines needing a refill get the refill colour.
local function cauldronLines()
    loadPotions()
    local lines, lineColours = {}, {}
    for _, c in ipairs(readCauldrons()) do
        local refill = c.doses <= core.refillAt and "  (refill)" or ""
        if c.doses == 0 then
            lines[#lines + 1] = c.number .. ". Empty" .. refill
        else
            local name = potionNames[c.potionID] or ("Unknown potion (" .. c.potionID .. ")")
            lines[#lines + 1] = string.format("%d. %s: %d dose%s%s", c.number, name, c.doses,
                c.doses == 1 and "" or "s", refill)
        end
        if refill ~= "" then lineColours[#lines] = core.toVector4(core.colours.cauldron_low) end
    end
    if #lines == 0 then
        lines[1] = "No potion cauldrons built."
    end
    return lines, lineColours
end

local function cauldronValuesKey()
    local values = {}
    for n = 1, CAULDRON_COUNT do
        values[n] = tostring(readCauldronVar(n))
    end
    return table.concat(values, ",")
end

local function updateCauldronWindow()
    lastCauldronValues = cauldronValuesKey()
    cauldronPanel:setLines(cauldronLines())
end

local function showCauldronWindow()
    lastCauldronValues = cauldronValuesKey()
    cauldronPanel:show(cauldronLines())
end

local function enteredHouse()
    inHouse = true
    if core.cauldronMode ~= "house" or cauldronShownThisVisit then return end
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
    cauldronPanel:close()
    inHouse = false
    houseTicks = 0
    lastSlotValues = {}
    for _, label in pairs(cauldronLabels) do
        pcall(hideCauldronLabel, label)
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

-- Every game tick while the window is open: save its position if it was
-- dragged, and update it if a cauldron changed. Checking every tick also
-- catches changes that arrive without a VarTransmit event, such as a newly
-- built cauldron.
Event.ServerLogic.Subscribe("itemChargesCauldronTick", function()
    if cauldronPanel.window == nil or not cauldronPanel.open then return end
    pcall(cauldronPanel.savePosition, cauldronPanel)
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
-- between visits. Unmatched cauldrons show "?". By default the potion's own
-- item icon floats above the number (drawn by the game, not a custom image).

local LABEL_MODES = { icon = true, number = true }
local LABEL = {
    RANGE_SQ = 5,              -- squared tiles: next to it, including diagonally
    HEIGHT = 700,              -- fine units above the tile (a tile is 512)
    W = 40, H = 24,
    ICON_W = 36, ICON_H = 32,  -- the size of an inventory icon
    LEARN_AFTER_TICKS = 5,     -- ignore the variables arriving as the house loads
    mode = core.loadSetting("cauldron_labels", function(v) return LABEL_MODES[v] == true end, "icon"),
}

local function isMap(v) return type(v) == "table" end
local cauldronMap = core.loadSetting("cauldron_map", isMap, {})  -- spot -> number
local cauldronLocs = {}        -- spot -> cauldron object, refreshed every tick

-- A cauldron's spot: its kind (scenery ID) and its tile within the house,
-- which stays the same between visits even if the house instance is placed
-- elsewhere in the world. For example "138360@0:22:7".
local function spotKey(loc, locID)
    local c = loc.coordGrid
    return locID .. "@" .. c.level .. ":" .. c.localX .. ":" .. c.localZ
end

local function spotKind(key) return key:match("^(%d+)@") end

local function findCauldronLocs()
    local found = {}
    for locID in pairs(CAULDRON_LOC_IDS) do
        local ok, locs = pcall(function() return LocList.ByConfigID(locID) end)
        if ok and locs ~= nil then
            for _, loc in ipairs(locs) do
                -- A removed cauldron can linger in the list, hidden or invalid.
                local okShown, shown = pcall(function() return loc.isValid ~= false and not loc.isHidden end)
                local okKey, key = pcall(spotKey, loc, locID)
                if okKey and (not okShown or shown) then found[key] = loc end
            end
        end
    end
    return found
end

-- Fills in unmatched cauldrons without the player having to use them:
--  * Moved: a matched spot that no longer has a cauldron passes its number to
--    the one unmatched cauldron of the same kind.
--  * Last one left: if one cauldron is unmatched and one built cauldron
--    number isn't used, they go together.
-- Only run once the house has fully loaded, so a cauldron that hasn't loaded
-- yet isn't mistaken for a moved one.
local function fillUnmatchedCauldrons()
    local unmatched, gone, used = {}, {}, {}
    for key in pairs(cauldronLocs) do
        if cauldronMap[key] == nil then unmatched[#unmatched + 1] = key end
    end
    for key, n in pairs(cauldronMap) do
        if cauldronLocs[key] == nil then gone[#gone + 1] = key else used[n] = true end
    end
    if #unmatched == 0 then return end
    local changed = false

    for _, key in ipairs(unmatched) do
        local kind, from, kindCount = spotKind(key), {}, 0
        for _, other in ipairs(unmatched) do
            if spotKind(other) == kind then kindCount = kindCount + 1 end
        end
        for _, old in ipairs(gone) do
            if spotKind(old) == kind then from[#from + 1] = old end
        end
        if kindCount == 1 and #from == 1 and not used[cauldronMap[from[1]]] then
            cauldronMap[key], cauldronMap[from[1]] = cauldronMap[from[1]], nil
            used[cauldronMap[key]] = true
            changed = true
        end
    end

    local stillUnmatched, free = {}, {}
    for _, key in ipairs(unmatched) do
        if cauldronMap[key] == nil then stillUnmatched[#stillUnmatched + 1] = key end
    end
    for _, c in ipairs(readCauldrons()) do
        if not used[c.number] then free[#free + 1] = c.number end
    end
    if #stillUnmatched == 1 and #free == 1 then
        cauldronMap[stillUnmatched[1]] = free[1]
        changed = true
    end

    if changed then core.saveSetting("cauldron_map", cauldronMap) end
end

-- The one cauldron closest to the player, if it's next to them. Nil when two
-- are equally close, since then it can't be told which one was used.
local function cauldronNextToPlayer()
    local p = Player.GetEntity().coordGrid
    local bestKey, bestDist, tied = nil, LABEL.RANGE_SQ + 1, false
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
    core.saveSetting("cauldron_map", cauldronMap)
end

-- Plugin overlays always draw on top of the world, so a label would show
-- through walls. Instead: when a cauldron has roof scenery above it and that
-- roof is still showing, the player is outside its building, so the label
-- is hidden. (The game removes a building's roof while you're inside it.)
-- Cauldrons with no roof above them are always shown.
local function roofShowingOver(loc)
    local c = loc.coordGrid
    local roofs, removed = 0, 0
    for _, above in ipairs(LocList.ByDistance(c, 1, false)) do
        if above.coordGrid.level > c.level then
            roofs = roofs + 1
            if above.isRoofRemoved then removed = removed + 1 end
        end
    end
    return roofs > 0 and removed == 0
end

-- The icon or the number (whichever is shown) is centred on the spot above
-- the cauldron.
local function placeCauldronLabels()
    for key, label in pairs(cauldronLabels) do
        local loc = cauldronLocs[key]
        local pos = nil
        if loc ~= nil and not label.behindWall then
            pcall(function() pos = ScreenConvert.CoordGridToScreen(loc.coordGrid, LABEL.HEIGHT) end)
        end
        if pos == nil then
            hideCauldronLabel(label)
        else
            local x, y = math.floor(pos.x), math.floor(pos.y)
            if label.showIcon and label.icon ~= nil then
                label.icon:SetPos(x - LABEL.ICON_W // 2, y - LABEL.ICON_H // 2)
                label.icon.hidden = false
            elseif label.icon ~= nil then
                label.icon.hidden = true
            end
            widgets.placeOutlinedText(label, x - LABEL.W // 2, y - LABEL.H // 2)
        end
    end
end

-- Shows a potion's icon on a label, creating the icon the first time.
local function setLabelIcon(label, item)
    label.showIcon = item ~= nil
    if item == nil or label.item == item then return end
    if label.icon == nil then
        label.icon = ui.Sprite.new(widgets.parentLayer)
        label.icon:SetSize(LABEL.ICON_W, LABEL.ICON_H)
        label.icon.clickthrough = true
    end
    label.icon:SetAssociatedObject(item)
    label.item = item
end

-- A newly built cauldron: its number's variable turns on (built) and a new
-- cauldron appears in the house within a few ticks of each other, so the two
-- go together wherever the player is standing. LABEL.built and
-- LABEL.appeared hold the tick each was seen.
LABEL.BUILD_WINDOW = 2
LABEL.built, LABEL.appeared = {}, {}

local function matchNewBuilds()
    for _, events in ipairs({ LABEL.built, LABEL.appeared }) do
        for k, tick in pairs(events) do
            if houseTicks - tick > LABEL.BUILD_WINDOW then events[k] = nil end
        end
    end
    -- A built number already matched to a cauldron in the house (learned
    -- because the player built it standing next to it) is settled.
    for k, n in pairs(cauldronMap) do
        if cauldronLocs[k] ~= nil then LABEL.built[n] = nil end
    end
    local number, spot, count = nil, nil, 0
    for n in pairs(LABEL.built) do number, count = n, count + 1 end
    for k in pairs(LABEL.appeared) do spot, count = k, count + 1 end
    -- Exactly one of each, or it's unclear which goes with which.
    if count ~= 2 or number == nil or spot == nil then return end
    for k, n in pairs(cauldronMap) do
        if n == number then cauldronMap[k] = nil end
    end
    cauldronMap[spot] = number
    core.saveSetting("cauldron_map", cauldronMap)
    LABEL.built, LABEL.appeared = {}, {}
end

local function cauldronLabelTick()
    houseTicks = houseTicks + 1
    local settled = houseTicks > LABEL.LEARN_AFTER_TICKS
    if not settled then LABEL.built, LABEL.appeared = {}, {} end
    local previousLocs = cauldronLocs
    cauldronLocs = findCauldronLocs()
    if settled then
        for key in pairs(cauldronLocs) do
            if previousLocs[key] == nil then LABEL.appeared[key] = houseTicks end
        end
    end

    for n = 1, CAULDRON_COUNT do
        local raw = readCauldronVar(n)
        local was = lastSlotValues[n]
        if settled and was ~= nil and was & 1 == 0 and raw ~= nil and raw & 1 == 1 then
            LABEL.built[n] = houseTicks
        end
        -- Only learn from a cauldron that's still built, so removing one
        -- doesn't credit a neighbour with its number.
        if houseTicks > LABEL.LEARN_AFTER_TICKS and lastSlotValues[n] ~= nil and raw ~= lastSlotValues[n]
            and raw ~= nil and raw & 1 == 1 then
            pcall(learnCauldron, n)
        end
        lastSlotValues[n] = raw
    end
    if settled then
        pcall(matchNewBuilds)
        pcall(fillUnmatchedCauldrons)
    end

    loadPotions()
    for key in pairs(cauldronLocs) do
        if cauldronLabels[key] == nil then
            cauldronLabels[key] = widgets.newOutlinedText(widgets.parentLayer, LABEL.W, LABEL.H)
        end
        local label = cauldronLabels[key]
        local number = cauldronMap[key]
        local colour = core.colours.cauldron
        local raw = number and lastSlotValues[number]
        local doses = raw and (raw >> 13) & 0xFFF
        if doses ~= nil and doses <= core.refillAt then
            colour = core.colours.cauldron_low
        end
        -- An icon only for a matched cauldron with a potion in it. The number
        -- shows instead when there's no icon, and "?" until it's matched.
        local item = nil
        if LABEL.mode == "icon" and doses ~= nil and doses > 0 then
            item = potionItems[(raw >> 1) & 0xFFF]
        end
        pcall(setLabelIcon, label, item)
        local okRoof, behind = pcall(roofShowingOver, cauldronLocs[key])
        label.behindWall = okRoof and behind
        local text = "?"
        if number ~= nil then
            text = (label.showIcon and label.icon ~= nil) and "" or tostring(number)
            -- Its number isn't built any more: the cauldron was removed, even
            -- if its scenery hasn't gone from the list yet.
            if raw == nil or raw & 1 == 0 then text = "" end
        end
        widgets.setOutlinedContent(label, text, core.toVector4(colour))
    end
    placeCauldronLabels()
end

Event.ServerLogic.Subscribe("itemChargesCauldronLabels", function()
    if not inHouse or widgets.parentLayer == nil then return end
    pcall(cauldronLabelTick)
end)

-- Labels follow the camera smoothly between game ticks.
Event.Logic.Subscribe("itemChargesCauldronLabelsMove", function()
    if not inHouse then return end
    pcall(placeCauldronLabels)
end)

-- Called when the plugin is turned off or reloaded.
local function shutdown()
    cauldronPanel:destroy()
    for _, label in pairs(cauldronLabels) do
        pcall(hideCauldronLabel, label)
    end
end

return {
    shutdown = shutdown,
    LABEL = LABEL,
    LABEL_MODES = LABEL_MODES,
    showCauldronWindow = showCauldronWindow,
    updateCauldronWindow = updateCauldronWindow,
}
