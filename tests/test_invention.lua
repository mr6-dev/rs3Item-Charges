-- Offline test for the Invention charge time.  Run:  lua5.4 tests/test_invention.lua  (from the main folder)
-- Uses fake game values to check the maths, the formatting, the low colour,
-- and that the label hides when the worn tab closes or the setting is off.

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
    function c:SetHeaderLayout() end
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

local wornLayer = comp({ xyGlobal = { x = 1300, y = 400 } })        -- item grid (centred)
local contentLayer = comp({ xyGlobal = { x = 1250, y = 360 } })     -- whole worn tab box
local useContent = true
function wornLayer:IterateDynamicComponents() end
local backpackLayer = comp()
function backpackLayer:IterateDynamicComponents() end
local pluginLayer = comp({ xyGlobal = { x = 100, y = 50 } })

local texts = {}
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name)
        if name == "TOPLEVEL_V2_WORN__ITEM_LAYER" then return wornLayer end
        if name == "TOPLEVEL_V2_WORN__CONTENT_LAYER" then
            if useContent then return contentLayer end
            return nil
        end
        if name == "TOPLEVEL_V2_INVENTORY__ITEM_LAYER" then return backpackLayer end
        return pluginLayer
    end },
    GroupBox = { new = function() return comp() end },
    Text = { new = function() local t = comp(); texts[#texts + 1] = t; return t end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), StyleSheet = {},
       Font = { MUSEO_SANS_15PT_REGULAR = "M15", NOTOSANS_BOLD_12 = "N12",
                NOTOSANS_BOLD_10 = "N10", MUSEO_SANS_9PT_REGULAR = "M9", NOTOSANS_BOLD_8 = "N8" } }
config = { Inv = { INV = "INV", WORN = "WORN" } }
Player = { IsAvailable = function() return true end }

-- Fake player variables, starting with the real values from the game
local CHARGE = { value = 503387964 }
local DRAIN  = { value = 12621 }
var = { VarPlayer = { INVENT_CHARGE = CHARGE, INVENT_COMBAT_CHARGE_DRAIN = DRAIN } }

local saved = {}
PersistentDB = {}
function PersistentDB:Get(k) return saved[k] end
function PersistentDB:Set(k, v) saved[k] = v; return true end

local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn) local prev = handlers[evName]; handlers[evName] = prev and function(...) prev(...); fn(...) end or fn end, Unsubscribe = function() end }
end })
Inventory = { Find = function()
    return { isValid = true, slotCount = 1, usedSlotCount = 0,
             GetSlot = function() return { obj = { name = "" } } end }
end }

local realPrint = print
print = function() end
dofile("tests/load_plugin.lua")
print = realPrint

-- Visible Invention lines (main texts only, top to bottom), joined with " | "
local function lines()
    local found = {}
    for _, t in ipairs(texts) do
        if t.isShadowed ~= nil and not t.hidden and type(t.content) == "string"
            and (t.content:find("^Time") or t.content:find("^Charge") or t.content:find("^Drain")) then
            found[#found + 1] = t
        end
    end
    table.sort(found, function(a, b) return a.posY < b.posY end)
    return found
end
local function shown()
    local parts = {}
    for _, t in ipairs(lines()) do parts[#parts + 1] = t.content end
    if #parts == 0 then return "hidden" end
    return table.concat(parts, " | ")
end
local function firstPos()
    local t = lines()[1]
    return t.posX .. "," .. t.posY
end
local function rgb(v)
    return string.format("%d,%d,%d", math.floor(v.r * 255 + 0.5),
        math.floor(v.g * 255 + 0.5), math.floor(v.b * 255 + 0.5))
end

local pass, fail = 0, 0
local function check(name, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. name .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. name .. ": got " .. got .. ", want " .. want) end
end

handlers.ServerLogic()
-- Real values. Tooltip said: 167,795 charge, 7.01/s, 6h 38m 50s
check("real game values", shown(), "Time left 6h 38m | Charge 167,795 | Drain 7.01/s")
-- Box top-left (1250,360) minus plugin layer (100,50) plus 4px padding
check("position: top-left of worn box", firstPos(), "1154,314")
local l = lines()
check("lines stacked 16px apart", (l[2].posY - l[1].posY) .. "," .. (l[3].posY - l[2].posY), "16,16")
check("lines left-aligned together", l[1].posX == l[2].posX and l[2].posX == l[3].posX, "true")

-- Window moved and resized: the grid re-centres, but the lines follow the box
contentLayer.xyGlobal = { x = 600, y = 200 }
wornLayer.xyGlobal = { x = 700, y = 260 }
handlers.ServerLogic()
check("follows the box after move/resize", firstPos(), "504,154")

-- If the content box can't be found, fall back to the item grid
useContent = false
handlers.ServerLogic()
check("fallback to item grid", firstPos(), "604,214")
useContent = true
handlers.ServerLogic()
check("normal colour when plenty left", rgb(lines()[1].colour), "255,255,0")

-- Under an hour: shows minutes and seconds
CHARGE.value = 12621 * 4100            -- 4100 ticks = 2460 s = 41m 00s
handlers.VarTransmit({ var = CHARGE, oldValue = 0, newValue = CHARGE.value })
check("updates on VarTransmit", shown(), "Time left 41m 00s | Charge 17,248 | Drain 7.01/s")

-- Under 30 minutes: every line turns the low colour
CHARGE.value = 12621 * 1500            -- 900 s = 15m 00s
handlers.ServerLogic()
check("15 minutes left", lines()[1].content, "Time left 15m 00s")
check("low colour on all lines", rgb(lines()[1].colour) .. " " .. rgb(lines()[3].colour),
      "255,64,64 255,64,64")

CHARGE.value = 12621 * 75              -- 45 s
handlers.ServerLogic()
check("seconds only", lines()[1].content, "Time left 45s")

-- Big numbers get commas, small ones don't
CHARGE.value = 3000 * 1234567
handlers.ServerLogic()
check("commas in millions", lines()[2].content, "Charge 1,234,567")
CHARGE.value = 3000 * 950
handlers.ServerLogic()
check("no comma under 1000", lines()[2].content, "Charge 950")

-- Drain changes when gear changes (17211 was the reading with the weapon on)
DRAIN.value = 17211
handlers.VarTransmit({ var = DRAIN, oldValue = 12621, newValue = 17211 })
check("drain updates", lines()[3].content, "Drain 9.56/s")

-- No augmented gear worn: drain is 0, nothing to show (and no divide by zero)
DRAIN.value = 0
handlers.ServerLogic()
check("hidden when drain is 0", shown(), "hidden")
DRAIN.value = 12621
CHARGE.value = 503387964

-- Worn tab closed: hidden
contentLayer.visibleGlobal = false
handlers.ServerLogic()
check("hidden when worn tab closed", shown(), "hidden")
contentLayer.visibleGlobal = true
handlers.ServerLogic()
check("back when worn tab reopens", shown(), "Time left 6h 38m | Charge 167,795 | Drain 7.01/s")

-- Settings page: one checkbox per line
prettyui = { SimpleView = { new = function()
    local v = { checks = {} }
    function v:AddTitle() end
    function v:AddText() end
    function v:AddDivider() end
    function v:AddColourPicker() end
    function v:AddCheckboxButton(choices, o) self.checks[#self.checks + 1] = { choices = choices, opts = o } end
    function v:AddRadioButton(choices, o) if choices[1].value == "normal" then self.radio = { choices = choices, opts = o } end end
    function v:Destroy() end
    prettyui.lastView = v
    return v
end } }
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local box
for _, c in ipairs(prettyui.lastView.checks) do
    if c.choices[1].value == "time" then box = c end
end
local function ticks()
    local t = {}
    for _, ch in ipairs(box.choices) do t[#t + 1] = ch.value .. "=" .. tostring(ch.selected) end
    return table.concat(t, " ")
end
check("three boxes, all ticked", ticks(), "time=true charge=true drain=true")

-- Untick the charge line: the drain line moves up to fill the gap
box.opts.onChange(nil, { "time", "drain" }, "charge", false)
check("charge line off", shown(), "Time left 6h 38m | Drain 7.01/s")
check("drain moved up", (lines()[2].posY - lines()[1].posY), "16")
check("charge off saved", saved.show_invention_charge, "false")

-- Untick time: only drain left, and it sits in the corner
box.opts.onChange(nil, { "drain" }, "time", false)
check("only drain", shown(), "Drain 7.01/s")
check("drain now in the corner", firstPos(), "504,154")
check("time off saved (old key)", saved.show_invention, "false")

-- Untick everything: nothing shown
box.opts.onChange(nil, {}, "drain", false)
check("all off", shown(), "hidden")

-- Reopen the page: boxes remember their state
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
for _, c in ipairs(prettyui.lastView.checks) do
    if c.choices[1].value == "time" then box = c end
end
check("reopened page remembers", ticks(), "time=false charge=false drain=false")

-- Text size
for _, v in ipairs({ "time", "charge", "drain" }) do box.opts.onChange(nil, {}, v, true) end
check("normal font by default", lines()[1].font, "M15")
local radio = prettyui.lastView.radio
check("size radio starts on normal", radio and radio.opts.selectedValue, "normal")
radio.opts.onChange(nil, "small")
-- No smaller Museo Sans in the fake font list, so it falls back to Noto 12
check("small font (fallback)", lines()[1].font .. "," .. lines()[3].font, "N12,N12")
check("small lines packed closer", lines()[2].posY - lines()[1].posY, "12")
check("small size saved", saved.invention_text_size, "small")
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
check("reopened radio remembers small", prettyui.lastView.radio.opts.selectedValue, "small")
-- Turn the outline on so the 8 copies get text, then count fonts
for _, c in ipairs(prettyui.lastView.checks) do
    if c.choices[1].value == "outline" then c.opts.onChange(nil, { "outline" }, "outline", true) end
end
local mainCount, mainFonts = 0, 0
for _, t in ipairs(texts) do
    if t.content and t.content:find("^Time") then
        mainCount = mainCount + 1
        if t.font == "N12" then mainFonts = mainFonts + 1 end
    end
end
check("outline copies use small font too", mainFonts .. "/" .. mainCount, "9/9")
-- XS: from the font list, closest to 8pt wins (N8), even though M9 is Museo
check("radio has XS", prettyui.lastView.radio.choices[3].value, "xs")
prettyui.lastView.radio.opts.onChange(nil, "xs")
check("xs font", lines()[1].font, "N8")
check("xs lines packed closer", lines()[2].posY - lines()[1].posY, "10")
check("xs saved", saved.invention_text_size, "xs")
prettyui.lastView.radio.opts.onChange(nil, "normal")
check("back to normal", lines()[1].font .. " gap " .. (lines()[2].posY - lines()[1].posY), "M15 gap 16")

-- Variables unreadable (e.g. renamed in a game update): hidden, no error
var = { VarPlayer = {} }
handlers.ServerLogic()
check("hidden when variables unreadable", shown(), "hidden")

print(string.format("\n%d passed, %d failed", pass, fail))
