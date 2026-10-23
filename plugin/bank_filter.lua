-- Item Charges: bank_filter.lua
-- Filters the open bank to show only some potions. It uses the bank's own
-- item slots, so items are withdrawn as normal: slots that don't match are
-- hidden, and the ones that do are moved into a packed grid at the top.
-- Nothing in the bank itself changes, only where its slots are drawn, and
-- the game lays the bank out afresh each time it opens.

local widgets = require("widgets")
local numbers = require("item_numbers")

local show = nil        -- function(potionName) -> true to show; nil when off
local original = {}     -- slot key -> { slot, x, y } from before it was moved
local hiddenExtras = {} -- key -> tab divider or other piece of the item area
                        -- we hid. They outlast closing the bank, so they're
                        -- always unhidden before being forgotten.
local check = nil       -- one moved slot and where we put it (see tick)
local potionNames = {}  -- item ID -> potion name without the dose, or false

local function key(c)
    return c.interfaceID .. ":" .. c.staticID .. ":" .. c.dynamicID
end

-- The potion's name without its dose ("Super restore"), or nil if the item
-- isn't a potion. Uses the same check as the item numbers, remembered per item.
local function potionName(objID)
    if objID == nil or objID < 0 then return nil end
    if potionNames[objID] == nil then
        potionNames[objID] = false
        pcall(function()
            local obj = config.Obj.FromID(objID)
            local baseName = numbers.parseCharges(obj.name)
            if baseName ~= nil and numbers.isPotion(obj, baseName) then
                potionNames[objID] = baseName
            end
        end)
    end
    return potionNames[objID] or nil
end

-- Hides everything in the bank's item area except the slot grid (and the
-- layers holding it), such as the "Tab 2 - ..." dividers.
local function hideExtras(inv)
    local container = widgets.findComponentByName("BANK__BANK_ITEMS_CONTAINER")
    if container == nil then return end
    local keep = {}
    local c = inv
    while c ~= nil and key(c) ~= key(container) do
        keep[key(c)] = true
        c = c.parent
    end
    local function walk(parent)
        local function visit(child)
            if keep[key(child)] then
                if key(child) ~= key(inv) then walk(child) end
            elseif hiddenExtras[key(child)] == nil and child.hidden ~= true then
                child.hidden = true
                hiddenExtras[key(child)] = child
            end
            return false
        end
        pcall(function() parent:IterateStaticComponents(visit) end)
        pcall(function() parent:IterateDynamicComponents(visit) end)
    end
    walk(container)
end

local function apply()
    local inv = widgets.findComponentByName("BANK__BANK_INV")
    if show == nil or inv == nil or inv.width == 0 then return end
    local slots = {}
    inv:IterateDynamicComponents(function(c)
        slots[#slots + 1] = c
        return false
    end)
    if #slots == 0 then return end
    table.sort(slots, function(a, b) return a.dynamicID < b.dynamicID end)

    -- Remember where each slot was (once), and find the grid's top-left
    -- corner and spacing from those positions. Slot 0 isn't always at the top.
    local left, top = math.huge, math.huge
    for _, c in ipairs(slots) do
        local k = key(c)
        original[k] = original[k] or { slot = c, x = c.xyLocal.x, y = c.xyLocal.y }
        left, top = math.min(left, original[k].x), math.min(top, original[k].y)
    end
    -- The spacing is the most common gap between neighbouring slots on the
    -- same row (a few slots, such as empty ones, can sit at odd positions).
    local gaps, stepX, best = {}, nil, 0
    for i = 2, #slots do
        local a, b = original[key(slots[i - 1])], original[key(slots[i])]
        local gap = b.x - a.x
        if b.y == a.y and gap > 0 then
            gaps[gap] = (gaps[gap] or 0) + 1
            if gaps[gap] > best then stepX, best = gap, gaps[gap] end
        end
    end
    if stepX == nil then return end
    local stepY = slots[1].height + stepX - slots[1].width
    local columns = math.max(1, inv.width // stepX)

    local shown = 0
    check = nil
    for _, c in ipairs(slots) do
        local name = potionName(widgets.iconObjectID(c))
        local match = name ~= nil and show(name)
        c.hidden = not match
        if match then
            local x, y = left + (shown % columns) * stepX, top + (shown // columns) * stepY
            c:SetPos(x, y)
            check = check or { slot = c, x = x, y = y }
            shown = shown + 1
        end
    end
    hideExtras(inv)
end

-- Shows every slot and divider again; moveBack also puts the slots back
-- where they were (not needed once the bank has closed).
local function restore(moveBack)
    for _, pos in pairs(original) do
        pcall(function()
            if moveBack then pos.slot:SetPos(pos.x, pos.y) end
            pos.slot.hidden = false
        end)
    end
    for _, c in pairs(hiddenExtras) do
        pcall(function() c.hidden = false end)
    end
    original, hiddenExtras, check = {}, {}, nil
end

-- fn(potionName) returns true for potions to show; nil turns the filter off.
local function set(fn)
    if fn == nil then
        if show ~= nil then pcall(restore, true) end
        show = nil
        return
    end
    show = fn
    local ok, err = pcall(apply)
    if not ok then print("Item Charges: bank filter error: " .. tostring(err)) end
end

-- Once a game tick while filtering. If the game has laid the bank out again
-- (switching tabs, searching), our grid is gone, so it's rebuilt from the
-- game's new positions.
local function tick()
    if show == nil or check == nil then return end
    local p = check.slot.xyLocal
    if p.x ~= check.x or p.y ~= check.y then
        original = {}
        pcall(apply)
    end
end

-- When the bank closes, the game lays it out afresh next time, but the
-- dividers we hid would stay hidden, so they're shown again.
local function bankClosed()
    if show ~= nil then pcall(restore, false) end
    show = nil
end

return {
    set = set,
    tick = tick,
    bankClosed = bankClosed,
    active = function() return show ~= nil end,
}
