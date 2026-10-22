-- Offline test for bank numbers.  Run:  lua5.4 tests/test_bank.lua  (from the main folder)
-- Checks numbers land on the right bank icons, hide outside the bank's
-- scroll area, show on the bank's backpack panel, and follow the setting.

local function item(name, ops) return { name = name, interfaceOpNames = ops or {} } end

local backpack = {}
for i = 1, 28 do backpack[i] = item("") end
backpack[2] = item("Games necklace (5)", { "Wear" })

-- Bank: charged items at slots 3, 5 and 9 (slot 9 is scrolled out of view)
local bank = {}
for i = 1, 12 do bank[i] = item("Bones", { "Bury" }) end
bank[3] = item("Super restore (4)", { "Drink" })
bank[5] = item("Ring of duelling (1)", { "Wear" })
bank[9] = item("Attack potion (3)", { "Drink" })
local bankCounts = {}

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

local function makeLayer(count, posFn)
    local icons = {}
    for slot = 0, count - 1 do
        local x, y = posFn(slot)
        icons[#icons + 1] = comp({ dynamicID = slot, xyGlobal = { x = x, y = y } })
    end
    local layer = comp({ icons = icons })
    function layer:IterateDynamicComponents(cb)
        for _, ic in ipairs(icons) do if cb(ic, true) then return end end
    end
    return layer
end

-- Bank grid: 4 wide from (800, 400), 40 apart. Rows 0-1 are in view; row 2
-- (slots 9-12) is below the scroll area, which ends at y = 480.
local bankLayer = makeLayer(12, function(s) return 800 + (s % 4) * 40, 400 + (s // 4) * 40 end)
local bankClip = comp({ xyGlobal = { x = 800, y = 400 }, width = 160, height = 80 })
local bankBackpack = makeLayer(28, function(s) return 1300 + (s % 4) * 47, 370 + (s // 4) * 47 end)
local backpackLayer = makeLayer(28, function(s) return 1650 + (s % 4) * 40, 720 + (s // 4) * 36 end)
local wornLayer = makeLayer(19, function(s) return 0, 0 end)

local bankOpen = true
local layers = {
    TOPLEVEL_V2_INVENTORY__ITEM_LAYER = backpackLayer,
    TOPLEVEL_V2_WORN__ITEM_LAYER = wornLayer,
    BANK__BANK_INV = bankLayer,
    BANK__BANK_ITEMS_CONTAINER = bankClip,
    BANK__INVENTORY_SLOTS = bankBackpack,
}
local pluginLayer = comp()
local texts = {}
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name) return layers[name] or pluginLayer end },
    Text = { new = function() local t = comp(); texts[#texts + 1] = t; return t end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), Font = {} }
config = { Inv = { INV = "INV", WORN = "WORN", BANK = "BANK" } }
Player = { IsAvailable = function() return true end }
local saved = {}
PersistentDB = {}
function PersistentDB:Get(k) return saved[k] end
function PersistentDB:Set(k, v) saved[k] = v; return true end
local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn)
        local prev = handlers[evName]
        handlers[evName] = prev and function(...) prev(...); fn(...) end or fn
    end, Unsubscribe = function() end }
end })
Inventory = { Find = function(cfg)
    local contents = ({ INV = backpack, WORN = {}, BANK = bank })[cfg]
    return { isValid = true, slotCount = #contents,
             GetSlot = function(_, i)
                 local count = 1
                 if contents == bank and bankCounts[i] ~= nil then count = bankCounts[i] end
                 return { obj = contents[i], count = count }
             end }
end }

local realPrint = print
print = function() end
dofile("tests/load_plugin.lua")
print = realPrint

local function visible()
    local out = {}
    for _, t in ipairs(texts) do
        if not t.hidden and t.isShadowed ~= nil then
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

-- Number box sits at icon + (36 - 22, 32 - 16) = icon + (14, 16).
-- Backpack slot 2 -> normal backpack (1704,736) and bank panel (1361,386).
-- Bank slot 3 -> (894,416), slot 5 -> (814,456). Slot 9 is out of view.
check("bank, both backpacks", visible(),
      "1@814,456 4@894,416 5@1361,386 5@1704,736")

-- Scroll down one row. As in-game, icon positions don't change; only the
-- container's scrollY does. Slot 9 comes into view, slot 3 scrolls out.
bankClip.scrollY = 40
handlers.Logic()   -- only the fast 50-per-second event, no full redraw
check("after scrolling (fast path only)", visible(), "1@814,416 3@814,456 5@1361,386 5@1704,736")

-- Half a row: slot 3 and slot 9 are both partly cut off, so both hide
bankClip.scrollY = 20
handlers.Logic()
check("partial scroll (fast path)", visible(), "1@814,436 5@1361,386 5@1704,736")
bankClip.scrollY = 40
handlers.ServerLogic()
check("full redraw agrees", visible(), "1@814,416 3@814,456 5@1361,386 5@1704,736")

-- Turn the bank setting off: bank numbers go, backpack ones stay
prettyui = { SimpleView = { new = function()
    local v = { checks = {} }
    function v:AddTitle() end
    function v:AddText() end
    function v:AddDivider() end
    function v:AddColourPicker() end
    function v:AddRadioButton() end
    function v:AddCheckboxButton(choices, o) self.checks[#self.checks + 1] = { choices = choices, opts = o } end
    function v:Destroy() end
    prettyui.lastView = v
    return v
end } }
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local box = prettyui.lastView.checks[1]
check("bank checkbox exists, ticked", box.choices[2].value .. "=" .. tostring(box.choices[2].selected), "bank=true")
box.opts.onChange(nil, { "outline" }, "bank", false)
check("bank numbers off", visible(), "5@1361,386 5@1704,736")
check("bank setting saved", saved.show_in_bank, "false")
check("outline untouched", saved.outline_enabled, "nil")
box.opts.onChange(nil, { "bank" }, "bank", true)

-- Withdraw the ring: the bank keeps a placeholder with count 0, no number
bankCounts[5] = 0
handlers.InventoryUpdated()
check("placeholder has no number", visible(), "3@814,456 5@1361,386 5@1704,736")

-- The normal backpack is dragged under the bank window (which spans about
-- x 784-976, y 305-540 here): its number hides instead of drawing on top,
-- while the bank's own numbers stay.
local necklaceIcon = backpackLayer.icons[2]
necklaceIcon.xyGlobal = { x = 850, y = 420 }
handlers.Logic()
check("hidden under the bank", visible(), "3@814,456 5@1361,386")

-- Close the bank: its layers go invisible, and the backpack number returns
bankLayer.visibleGlobal = false
bankBackpack.visibleGlobal = false
bankClip.visibleGlobal = false
handlers.ServerLogic()
check("bank closed", visible(), "5@864,436")

print(string.format("\n%d passed, %d failed", pass, fail))
