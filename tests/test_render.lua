-- Offline test: runs main.lua against a FAKE game API ("stubs").
-- Checks which items get numbers, where the numbers land, and that they hide
-- when a window closes.  Run:  lua5.4 tests/test_render.lua  (from the main folder)

-- Fake items: name plus the right-click options the item has
local function item(name, ops) return { name = name, interfaceOpNames = ops or {} } end

local backpack = {
    item("Games necklace (8)", { "Wear", "Rub" }),
    item("Games necklace (1)", { "Wear", "Rub" }),
    item("Attack potion (3)", { "Drink", "Empty" }),           -- potion: has Drink
    item("Super restore flask (6)", { "Drink" }),              -- flask: has Drink
    item("Elder overload salve (6)"),                          -- no ops readable: name backup
    item("Bones", { "Bury" }),                                 -- no number: ignored
    item("Mysterious widget (2)", { "Inspect" }),              -- number but not a potion: ignored
    item("Vial", { "Fill" }),                                  -- empty vial: ignored
}
for i = #backpack + 1, 28 do backpack[i] = item("") end        -- empty slots come back as ""

-- Fake worn equipment: slot 3 (neck) has a glory, slot 13 (ring) a duelling ring
local worn = {}
for i = 1, 19 do worn[i] = item("") end
worn[3]  = item("Amulet of glory (t4)", { "Remove" })
worn[13] = item("Ring of duelling (5)", { "Remove" })
worn[4]  = item("Dragon longsword", { "Remove" })              -- no number: ignored

Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
    function c:SetHeaderLayout() end
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

-- Fake icon layers. Backpack: 4-wide grid from (1650, 720), 40 apart.
-- Worn: 3-wide grid from (1300, 400), one icon per slot.
local function makeLayer(count, posFn)
    local icons = {}
    for slot = 0, count - 1 do
        local x, y = posFn(slot)
        icons[#icons + 1] = comp({ dynamicID = slot, xyGlobal = { x = x, y = y } })
    end
    local layer = comp({ visibleGlobal = true })
    function layer:IterateDynamicComponents(cb)
        for _, ic in ipairs(icons) do if cb(ic, true) then return end end
    end
    return layer
end
local backpackLayer = makeLayer(28, function(s) return 1650 + (s % 4) * 40, 720 + (s // 4) * 36 end)
local wornLayer     = makeLayer(19, function(s) return 1300 + (s % 3) * 50, 400 + (s // 3) * 45 end)

local pluginLayer = comp()
local overlayTexts = {}
ui = {
    Interfaces = { GetComponent = function(_, name)
        if name == "TOPLEVEL_V2_INVENTORY__ITEM_LAYER" then return backpackLayer end
        if name == "TOPLEVEL_V2_WORN__ITEM_LAYER" then return wornLayer end
        return pluginLayer
    end },
    Text = { new = function(parent)
        local t = comp()
        overlayTexts[#overlayTexts + 1] = t
        return t
    end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), StyleSheet = {}, Font = {} }
config = { Inv = { INV = "INV", WORN = "WORN" } }
Player = { IsAvailable = function() return true end }
local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn) local prev = handlers[evName]; handlers[evName] = prev and function(...) prev(...); fn(...) end or fn end }
end })
Inventory = { Find = function(cfg)
    local contents = (cfg == "WORN") and worn or backpack
    return {
        isValid = true, slotCount = #contents, usedSlotCount = 0,
        GetSlot = function(_, i) return { obj = contents[i], count = 1 } end,
    }
end }

local realPrint = print
print = function() end
dofile("main.lua")
print = realPrint

-- Collect the visible MAIN numbers. Main texts are the ones that get
-- isShadowed set; outline copies never do.
local function visibleNumbers()
    local out = {}
    for _, t in ipairs(overlayTexts) do
        if not t.hidden and t.isShadowed ~= nil then out[#out + 1] = t end
    end
    return out
end

local pass, fail = 0, 0
local function check(label, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. label .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. label .. ": got " .. got .. ", want " .. want) end
end

local nums = visibleNumbers()
local function has(content, x, y)
    for _, t in ipairs(nums) do
        if t.content == content and t.posX == x and t.posY == y then return "yes" end
    end
    return "no"
end

-- Expected: 2 necklaces + 3 potions in the backpack, 2 worn items.
-- A number sits at the icon's bottom-right: (iconX + 36 - 22, iconY + 32 - 16)
check("total numbers", #nums, "7")
check("necklace 8 on backpack slot 1", has("8", 1664, 736), "yes")
check("necklace 1 on backpack slot 2", has("1", 1704, 736), "yes")
check("attack potion 3 on slot 3 (Drink)", has("3", 1744, 736), "yes")
check("flask 6 on slot 4 (Drink)", has("6", 1784, 736), "yes")
check("salve 6 on slot 5 (name backup)", has("6", 1664, 772), "yes")
check("non-potion widget (2) ignored", has("2", 1744, 772), "no")
check("glory 4 on worn slot 3", has("4", 1414, 416), "yes")
check("duelling 5 on worn slot 13", has("5", 1314, 596), "yes")

-- Closing the worn equipment tab hides only the worn numbers
wornLayer.visibleGlobal = false
handlers.ServerLogic()
check("after closing worn tab", #visibleNumbers(), "5")

-- Closing the backpack too hides everything
backpackLayer.visibleGlobal = false
handlers.ServerLogic()
check("after closing backpack", #visibleNumbers(), "0")

print(string.format("\n%d passed, %d failed", pass, fail))
