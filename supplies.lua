-- Item Charges: supplies.lua
-- Potion supplies: a restock list of the total doses of each potion in your
-- backpack, beast of burden and bank, with a small summary beside the bank.

local core = require("core")
local widgets = require("widgets")
local positioning = require("positioning")
local numbers = require("item_numbers")

-- A restock list: the total doses of each potion across the backpack, beast
-- of burden and bank, lowest first. The bank's contents are only sent while
-- it's open, so its totals are saved and reused until the next visit.
-- Potions are grouped by name without the dose, so "Super restore (4)" and
-- "Super restore (2)" add together, but flasks are counted separately.

local SUPPLY_LIVE_INVENTORIES = { "INV", "LORE_BOB" }

local savedBankDoses = core.loadSetting("supplies_bank_doses",
    function(v) return type(v) == "table" end, {})
-- Grows to fit up to 15 lines, then scrolls. Opens on the left of the screen
-- from the settings page, or under the summary beside the bank, until the
-- player drags it somewhere; then it always opens there.
local suppliesPanel = widgets.ListWindow.new("Potion supplies", 440, 40, 200, 15, "supplies")

-- Adds each potion's doses in one inventory to totals (a stack of 10
-- "Super restore (4)" adds 40). Returns how many filled slots it saw, so an
-- unavailable or empty bank can be told apart from a bank with no potions.
local function addPotionDoses(invName, totals)
    local inv = numbers.findInventory(invName)
    if inv == nil then return 0 end
    local filled = 0
    for slotIndex = 1, inv.slotCount do
        local slot = inv:GetSlot(slotIndex)
        if slot ~= nil and slot.obj ~= nil and slot.obj.name ~= "" and (slot.count or 0) > 0 then
            filled = filled + 1
            local baseName, doses = numbers.parseCharges(slot.obj.name)
            if baseName ~= nil and numbers.isPotion(slot.obj, baseName) then
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
        core.saveSetting("supplies_bank_doses", bank)
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

    -- Potions needing a restock get the restock colour.
    local lines, lineColours = {}, {}
    local restockCount = 0
    for _, potion in ipairs(list) do
        local restock = ""
        if potion.doses <= core.restockAt then
            restock = "  (restock)"
            restockCount = restockCount + 1
            lineColours[#lines + 1] = core.toVector4(core.colours.restock)
        end
        lines[#lines + 1] = string.format("%s: %d dose%s%s", potion.name, potion.doses,
            potion.doses == 1 and "" or "s", restock)
    end
    if #lines == 0 then
        lines[1] = "No potions found. Open your bank once to include it."
    end
    return lines, lineColours, restockCount
end

-- x and y are optional, and ignored once the player has dragged the window;
-- it's rebuilt if it should open elsewhere.
local function showSuppliesWindow(x, y)
    if not suppliesPanel.moved then
        x, y = x or 40, y or 200
        if x ~= suppliesPanel.x or y ~= suppliesPanel.y then
            suppliesPanel:destroy()
            suppliesPanel.x, suppliesPanel.y = x, y
        end
    end
    suppliesPanel:show(supplyLines())
end

Event.ServerLogic.Subscribe("itemChargesSuppliesPosition", function()
    pcall(suppliesPanel.savePosition, suppliesPanel)
end)

-- The summary beside the bank: how many potions need restocking, and a
-- button that opens the full list underneath it. It opens beside the bank
-- until the player drags it; then it always opens where it was left. It's a
-- ListWindow only for that position saving; its contents are built here.
local SUMMARY_W, SUMMARY_H = 260, 120
local summary = widgets.ListWindow.new("Potion supplies", SUMMARY_W, 0, 0, nil, "summary")

local function summaryLine()
    local _, _, restockCount = supplyLines()
    if restockCount == 0 then return "Nothing to restock." end
    return string.format("%d potion%s to restock.", restockCount, restockCount == 1 and "" or "s")
end

local function updateSummary()
    if summary.text ~= nil then
        summary.text.content = summaryLine()
    end
end

local function closeSummary()
    summary:destroy()
    summary.open, summary.text = false, nil
end

local function showSummary(x, y)
    closeSummary()
    if not summary.moved then summary.x, summary.y = x, y end
    summary.window = prettyui.Window.new(widgets.parentLayer, {
        title = summary.title, x = summary.x, y = summary.y, width = SUMMARY_W, height = SUMMARY_H,
    })
    summary.offset = nil
    summary.text = summary.window:AddText(summaryLine())
    summary.window:AddFancyButton("Show list", function()
        local ok, err = pcall(showSuppliesWindow, summary.x, summary.y + SUMMARY_H + 10)
        if not ok then print("Item Charges: supplies panel error: " .. tostring(err)) end
    end)
    summary.window:Show()
    summary.open = true
end

Event.ServerLogic.Subscribe("itemChargesSummaryPosition", function()
    pcall(summary.savePosition, summary)
end)
local function onSuppliesChanged()
    pcall(function()
        saveBankIfOpen()
        if suppliesPanel.open then suppliesPanel:setLines(supplyLines()) end
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
    local backpack = widgets.findComponentByName(BANK_BACKPACK_COMPONENT)
    local right = items.xyGlobal.x + items.width
    if positioning.bankPartShown(backpack) then
        right = backpack.xyGlobal.x + backpack.width
    end
    return right + BANK_RIGHT_GAP, math.max(0, items.xyGlobal.y - BANK_TOP_OFFSET)
end

Event.ServerLogic.Subscribe("itemChargesSuppliesBank", function()
    pcall(function()
        local items = widgets.findComponentByName(BANK_OPEN_COMPONENT)
        local bankOpen = positioning.bankPartShown(items)
        if core.suppliesMode == "bank" then
            if bankOpen and not bankWasOpen then
                showSummary(besideBank(items))
            elseif bankWasOpen and not bankOpen then
                closeSummary()
                suppliesPanel:close()
            end
        end
        bankWasOpen = bankOpen
    end)
end)

-- Called when the plugin is turned off or reloaded.
local function shutdown()
    suppliesPanel:destroy()
    closeSummary()
end

return {
    shutdown = shutdown,
    onSuppliesChanged = onSuppliesChanged,
    showSuppliesWindow = showSuppliesWindow,
}
