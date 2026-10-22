-- Item Charges: display.lua
-- When to redraw: rescans your items when an inventory changes, redraws the
-- numbers and Invention lines every game tick, and keeps them following
-- their icons between ticks.

local widgets = require("widgets")
local positioning = require("positioning")
local numbers = require("item_numbers")
local invention = require("invention")

local lastItems = {}   -- charged items from the last scan

local function render()
    if widgets.parentLayer == nil then return end
    numbers.hideChargeNumbers()
    invention.hideInvention()
    positioning.clearPlacements()
    positioning.findBankComponents()
    numbers.renderChargeNumbers(lastItems)
    invention.renderInvention()
    positioning.reposition()
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
        lastItems = numbers.collectChargedItems()
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
    if widgets.parentLayer == nil then return end
    local ok, changed = pcall(positioning.reposition)
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
        for _, varName in pairs(numbers.VAR_CHARGED_ITEMS) do
            if e.var == var.VarPlayer[varName] then return true end
        end
        return false
    end)
    if ok and relevant then
        refresh()
    end
end)

refresh()

return {
    safeRender = safeRender,
}
