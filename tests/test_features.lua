-- Offline test for 1.2.0 features.  Run:  lua5.4 tests/test_features.lua  (from the main folder)
-- New jewellery (any capitalisation), beast of burden, the low charge
-- threshold slider, and separate Invention colours.

local function item(name, ops) return { name = name, interfaceOpNames = ops or {}, id = nil } end

local backpack = {}
for i = 1, 28 do backpack[i] = item("") end
backpack[1] = item("Ferocious ring (5)", { "Wear" })
backpack[2] = item("Ring of Wealth (2)", { "Wear" })   -- capital W, as on the wiki
backpack[3] = item("Kethsi ring (1)", { "Wear" })
backpack[4] = item("Super restore (2)", { "Drink" })
backpack[5] = item("Ring of respawn (new)", { "Wear" })   -- no number: ignored

local bob = {}
for i = 1, 32 do bob[i] = item("") end
bob[1] = item("Prayer potion (3)", { "Drink" })

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

local function makeLayer(count, x0, y0)
    local icons = {}
    for slot = 0, count - 1 do
        icons[#icons + 1] = comp({ dynamicID = slot,
            xyGlobal = { x = x0 + (slot % 4) * 40, y = y0 + (slot // 4) * 40 } })
    end
    local layer = comp()
    function layer:IterateDynamicComponents(cb)
        for _, ic in ipairs(icons) do if cb(ic, true) then return end end
    end
    return layer
end

local empty = comp({ visibleGlobal = true })
function empty:IterateDynamicComponents() end
local hidden = comp({ visibleGlobal = false })
function hidden:IterateDynamicComponents() end

-- The beast of burden window: the first candidate layer is visible but has no
-- icons, the second has them. The plugin should pick the second.
local layers = {
    TOPLEVEL_V2_INVENTORY__ITEM_LAYER = makeLayer(28, 1000, 500),
    LORE_BANK__LORE_BOB_INV_SLOTLAYER = empty,
    LORE_BANK__LORE_BOB_LAYER = makeLayer(32, 300, 300),
}
local pluginLayer = comp()
local texts = {}
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name)
        if layers[name] then return layers[name] end
        if name:find("LAYER") or name:find("BANK") or name:find("BAR") or name:find("SLOT") then
            return hidden
        end
        return pluginLayer
    end },
    Text = { new = function() local t = comp(); texts[#texts + 1] = t; return t end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), Font = {} }
config = { Inv = { INV = "INV", WORN = "WORN", BANK = "BANK", LORE_BOB = "LORE_BOB" } }
Player = { IsAvailable = function() return true end }
local CHARGE, DRAIN = { value = 3000 * 1000000 }, { value = 3000 * 0.6 }   -- 1,000,000 charge, 1/s
var = { VarPlayer = { INVENT_CHARGE = CHARGE, INVENT_COMBAT_CHARGE_DRAIN = DRAIN } }
layers.TOPLEVEL_V2_WORN__CONTENT_LAYER = comp({ xyGlobal = { x = 1500, y = 100 } })
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
    local contents = ({ INV = backpack, LORE_BOB = bob })[cfg] or {}
    return { isValid = true, slotCount = #contents,
             GetSlot = function(_, i) return { obj = contents[i], count = 1 } end }
end }

local printed = {}
local realPrint = print
print = function(msg) printed[#printed + 1] = tostring(msg) end
dofile("main.lua")
print = realPrint

local function rgb(v)
    return string.format("%d,%d,%d", math.floor(v.r * 255 + 0.5),
        math.floor(v.g * 255 + 0.5), math.floor(v.b * 255 + 0.5))
end
local function numbersAt(y0, y1)
    local out = {}
    for _, t in ipairs(texts) do
        if not t.hidden and t.isShadowed ~= nil and t.posY >= y0 and t.posY < y1 then
            out[#out + 1] = t.content .. "(" .. rgb(t.colour) .. ")@" .. t.posX
        end
    end
    table.sort(out)
    return table.concat(out, " ")
end
local function inventionColour()
    for _, t in ipairs(texts) do
        if not t.hidden and t.isShadowed ~= nil and type(t.content) == "string"
            and t.content:find("^Time") then
            return rgb(t.colour)
        end
    end
    return "hidden"
end

local pass, fail = 0, 0
local function check(name, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. name .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. name .. ":\n      got  " .. got .. "\n      want " .. want) end
end

-- Backpack row 1 is at y 500 -> numbers at y 516. Low threshold is 1:
-- only the Kethsi ring (1) is red.
check("new jewellery, low = 1", numbersAt(516, 517),
      "1(255,64,64)@1094 2(255,255,0)@1054 2(255,255,0)@1134 5(255,255,0)@1014")

-- Beast of burden window: the second candidate layer has the icons
check("beast of burden numbers", numbersAt(316, 317), "3(255,255,0)@314")

-- Settings page with a slider and separate Invention colours
prettyui = { SimpleView = { new = function()
    local v = { pickers = {}, texts = {} }
    function v:AddTitle() end
    function v:AddText(t) local tx = { content = t }; self.texts[#self.texts + 1] = tx; return tx end
    function v:AddDivider() end
    function v:AddRadioButton() end
    function v:AddCheckboxButton() end
    function v:AddSlider(o) self.sliders = self.sliders or {}; self.sliders[#self.sliders + 1] = o end
    function v:AddColourPicker(o) self.pickers[#self.pickers + 1] = o end
    function v:Destroy() end
    prettyui.lastView = v
    return v
end } }
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local view = prettyui.lastView
-- Three sliders: potion and jewellery thresholds (start at 1), then the
-- potion supplies restock level (starts at 50)
check("three sliders", #view.sliders .. ":" .. view.sliders[1].value .. "," .. view.sliders[2].value
      .. "," .. view.sliders[3].value, "3:1,1,50")

-- Potions slider (first) to 2: only the Super restore (2) at x 1134 turns red
view.sliders[1].onChange(nil, 2)
check("potion threshold 2", numbersAt(516, 517),
      "1(255,64,64)@1094 2(255,255,0)@1054 2(255,64,64)@1134 5(255,255,0)@1014")
check("potion threshold saved", saved.low_threshold_potion, "2")

-- Jewellery slider (second) to 2: now the Ring of Wealth (2) at x 1054 too
view.sliders[2].onChange(nil, 2)
check("jewellery threshold 2", numbersAt(516, 517),
      "1(255,64,64)@1094 2(255,64,64)@1054 2(255,64,64)@1134 5(255,255,0)@1014")
check("jewellery threshold saved", saved.low_threshold_jewellery, "2")
local labelUpdated = false
for _, t in ipairs(view.texts) do
    if t.content == "Jewellery: low charge colour at 2 charges or fewer" then labelUpdated = true end
end
check("slider label updated", labelUpdated, "true")

-- Invention colour is separate from the item colour
check("invention starts yellow", inventionColour(), "255,255,0")
local inventionPicker
for _, p in ipairs(view.pickers) do
    if p.windowTitle == "Invention text colour" then inventionPicker = p end
end
inventionPicker.onChange(nil, 0x00FF00FF)   -- green
check("invention text now green", inventionColour(), "0,255,0")
check("item numbers unchanged", numbersAt(516, 517),
      "1(255,64,64)@1094 2(255,64,64)@1054 2(255,64,64)@1134 5(255,255,0)@1014")

-- Under 30 minutes uses the Invention low colour, not the item low colour
for _, p in ipairs(view.pickers) do
    if p.windowTitle == "Invention colour under 30 minutes" then p.onChange(nil, 0xFF00FFFF) end
end
CHARGE.value = 3000 * 1000
handlers.ServerLogic()   -- 1000 charge at 1/s = 16m 40s
check("invention low colour", inventionColour(), "255,0,255")

print(string.format("\n%d passed, %d failed", pass, fail))
