-- Offline test for moving items.  Run:  lua5.4 tests/test_move.lua  (from the main folder)
-- The client redraws a moved item straight away, but the inventory data only
-- changes when the server confirms. Checks numbers follow the icons at once.

local function obj(id, name, ops) return { id = id, name = name, interfaceOpNames = ops or {} } end
local EMPTY = obj(-1, "")
local NECKLACE = obj(3853, "Games necklace (8)", { "Wear" })
local POTION = obj(2440, "Super strength (2)", { "Drink" })

local backpack = {}
for i = 1, 28 do backpack[i] = { obj = EMPTY, count = 0 } end
backpack[1] = { obj = NECKLACE, count = 1 }
backpack[2] = { obj = POTION, count = 1 }

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

-- Backpack icons, 4 wide from (1000, 500), 40 apart. Each icon reports the
-- item it draws, like the game's item sprites.
local icons = {}
local backpackLayer = comp()
for slot = 0, 27 do
    local s = backpack[slot + 1]
    icons[slot + 1] = comp({ dynamicID = slot,
        xyGlobal = { x = 1000 + (slot % 4) * 40, y = 500 + (slot // 4) * 40 },
        associatedObjectID = s.obj.id, associatedObjectQuantity = s.count })
end
function backpackLayer:IterateDynamicComponents(cb)
    for _, ic in ipairs(icons) do if cb(ic, true) then return end end
end

-- A layer whose icons all report -1 (slot backgrounds, not item pictures)
local slotOnly = comp()
local slotIcons = {}
for slot = 0, 27 do
    slotIcons[slot + 1] = comp({ dynamicID = slot,
        xyGlobal = { x = 2000 + (slot % 4) * 40, y = 500 + (slot // 4) * 40 },
        associatedObjectID = -1 })
end
function slotOnly:IterateDynamicComponents(cb)
    for _, ic in ipairs(slotIcons) do if cb(ic, true) then return end end
end

local hidden = comp({ visibleGlobal = false })
function hidden:IterateDynamicComponents() end
local layers = {
    TOPLEVEL_V2_INVENTORY__ITEM_LAYER = backpackLayer,
    BANK__INVENTORY_SLOTS = slotOnly,
}
-- Action bar 1: slot 3 holds the potion, slot 5 holds a non-charged item.
-- Bar slots report quantity 0 here, to check that doesn't hide numbers.
for n = 1, 14 do
    layers["TOPLEVEL_V2_COMBAT_BAR__GRAPHIC_" .. n] = comp({
        xyGlobal = { x = 500 + (n - 1) * 40, y = 900 },
        associatedObjectID = -1, associatedObjectQuantity = 0 })
end
local bar = function(n) return layers["TOPLEVEL_V2_COMBAT_BAR__GRAPHIC_" .. n] end
bar(3).associatedObjectID = POTION.id
bar(5).associatedObjectID = 995
local pluginLayer = comp()
local texts = {}
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name)
        if layers[name] then return layers[name] end
        if name:find("LAYER") or name:find("BANK") then return hidden end
        return pluginLayer
    end },
    Text = { new = function() local t = comp(); texts[#texts + 1] = t; return t end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), Font = {} }
config = { Inv = { INV = "INV", WORN = "WORN", BANK = "BANK" } }
Player = { IsAvailable = function() return true end }
PersistentDB = {}
function PersistentDB:Get() return nil end
function PersistentDB:Set() return true end
local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn)
        local prev = handlers[evName]
        handlers[evName] = prev and function(...) prev(...); fn(...) end or fn
    end, Unsubscribe = function() end }
end })
Inventory = { Find = function(cfg)
    local contents = cfg == "INV" and backpack or {}
    return { isValid = true, slotCount = #contents,
             GetSlot = function(_, i) return contents[i] end }
end }

local realPrint = print
print = function() end
dofile("main.lua")
print = realPrint

local function visible()
    local out = {}
    for _, t in ipairs(texts) do
        if not t.hidden and t.isShadowed ~= nil and t.posY ~= 916 then   -- skip action bar row
            out[#out + 1] = t.content .. "@" .. t.posX .. "," .. t.posY
        end
    end
    table.sort(out)
    return table.concat(out, " ")
end

local pass, fail = 0, 0
local function check(name, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. name .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. name .. ":\n      got  " .. got .. "\n      want " .. want) end
end

-- Number box = icon + (14, 16). Slot 1 (1000,500), slot 2 (1040,500),
-- slot 6 (1040,540). Bank panel (slot fallback): slot 1 (2000,500), 2 (2040,500).
check("start", visible(), "2@1054,516 2@2054,516 8@1014,516 8@2014,516")

-- Drag the necklace from slot 1 to slot 6. Only the icons change; the
-- inventory data still says slot 1 until the server confirms.
icons[1].associatedObjectID, icons[1].associatedObjectQuantity = -1, 0
icons[6].associatedObjectID, icons[6].associatedObjectQuantity = NECKLACE.id, 1
handlers.Logic()
check("follows the icon before the server confirms", visible(),
      "2@1054,516 2@2054,516 8@1054,556 8@2014,516")

-- Server confirms: the inventory data catches up. Slot-only layer follows now.
backpack[6], backpack[1] = backpack[1], { obj = EMPTY, count = 0 }
handlers.InventoryUpdated()
check("after the server confirms", visible(),
      "2@1054,516 2@2054,516 8@1054,556 8@2054,556")

-- Swap the potion (slot 2) and necklace (slot 6) on screen
icons[2].associatedObjectID, icons[6].associatedObjectID = NECKLACE.id, POTION.id
handlers.Logic()
check("swap two charged items", visible(),
      "2@1054,556 2@2054,516 8@1054,516 8@2054,556")

-- Quantity 0 (a placeholder) shows no number
icons[2].associatedObjectQuantity = 0
handlers.Logic()
check("placeholder hidden", visible(), "2@1054,556 2@2054,516 8@2054,556")

-- Action bar: potion number in bar slot 3 at (580,900) + (14,16) = (594,916)
local function barNumbers()
    local out = {}
    for _, t in ipairs(texts) do
        if not t.hidden and t.isShadowed ~= nil and t.posY == 916 then
            out[#out + 1] = t.content .. "@" .. t.posX
        end
    end
    return table.concat(out, " ")
end
check("action bar shows potion doses", barNumbers(), "2@594")

-- Drag the potion to bar slot 1: follows on the fast path
bar(3).associatedObjectID, bar(1).associatedObjectID = -1, POTION.id
handlers.Logic()
check("action bar follows moved item", barNumbers(), "2@514")

-- No endless redraws from bar slots reporting quantity 0: a quiet fast tick
-- shouldn't look up any components (only a full redraw does that)
local lookups = 0
local realGet = ui.Interfaces.GetComponent
ui.Interfaces.GetComponent = function(...) lookups = lookups + 1; return realGet(...) end
handlers.Logic()
handlers.Logic()
check("no redraw on quiet ticks", lookups, "0")
check("bar number still there", barNumbers(), "2@514")

print(string.format("\n%d passed, %d failed", pass, fail))
