-- Offline test for the potion cauldron panel.  Run:  lua5.4 tests/test_cauldron.lua  (from the main folder)
-- Uses the real values found in-game: cauldron 1 holds 15 doses of potion
-- ID 182 (elder overload salve), cauldron 2 holds 120 of ID 146 (aggression).

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = false }
    function c:SetPos(x, y) self.posX, self.posY = x, y end
    function c:SetSize() end
    function c:AlignTo() end
    function c:IterateDynamicComponents() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local pluginLayer = comp({ visibleGlobal = true })
local texts = {}   -- every text the plugin creates
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name)
        if name == "TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP" then return pluginLayer end
        return comp()
    end },
    Text = { new = function() local t = comp(); texts[#texts + 1] = t; return t end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), Font = {} }
config = { Inv = { INV = "INV" } }
-- The player and three cauldrons in a row, as seen in-game: Basic, Bubbling
-- and Arcane at local tiles 21, 22 and 23
local function tile(x, z) return { level = 0, x = 10000 + x, z = 3600 + z, localX = x, localZ = z } end
local playerTile = tile(10, 10)
Player = {
    IsAvailable = function() return true end,
    GetEntity = function() return { coordGrid = playerTile } end,
}
local houseLocs = {
    [138359] = { { coordGrid = tile(21, 7) } },
    [138360] = { { coordGrid = tile(22, 7) } },
    [138361] = { { coordGrid = tile(23, 7) } },
}
LocList = { ByConfigID = function(locID) return houseLocs[locID] or {} end }
ScreenConvert = { CoordGridToScreen = function(c) return { x = c.localX * 50, y = 300 } end }
local saved = {}
PersistentDB = {}
function PersistentDB:Get(k) return saved[k] end
function PersistentDB:Set(k, v) saved[k] = v; return true end
Inventory = { Find = function() return { isValid = true, slotCount = 0, GetSlot = function() end } end }
local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn)
        local prev = handlers[evName]
        handlers[evName] = prev and function(...) prev(...); fn(...) end or fn
    end, Unsubscribe = function() end }
end })

-- Player variables: bit 0 built, bits 1-12 potion ID, bits 13-24 doses
local cauldronVars = {}
for n = 1, 5 do cauldronVars[n] = { value = 0 } end
cauldronVars[1].value = 123245   -- built, ID 182, 15 doses
cauldronVars[2].value = 983333   -- built, ID 146, 120 doses
var = { VarPlayer = {} }
for n = 1, 5 do var.VarPlayer["CONSTRUCTION_HOUSE_FURNITURE_POTION_CAULDRON_" .. n] = cauldronVars[n] end

-- Fake HERBLORE_POTION table (ID 378). Rows 19280-19330, with one row from
-- another table at 19300 to check the walk steps over gaps.
local NAME_PARAM = { id = 2524, configName = "POTION_GENERIC_NAME" }
local column3Reads = 0
local rows = {}
local function addRow(rowID, tableID, potionID, name)
    local struct = { GetParamValue = function(_, p) if p == NAME_PARAM then return name end end }
    rows[rowID] = {
        id = rowID, ownerDBTable = { id = tableID },
        GetColumnValues = function(_, c)
            if c == 1 then return { potionID } end
            if c == 2 then return { struct } end
            column3Reads = column3Reads + 1
            error("invalid ValueType")
        end,
    }
end
for rowID = 19280, 19330 do addRow(rowID, 378, rowID - 19000, "Potion " .. rowID) end
addRow(19286, 378, 146, "Aggression Potion")
addRow(19322, 378, 182, "Elder Overload Salve")
addRow(19300, 999, 0, "Not a potion")
config.DBRow = setmetatable({ FromID = function(i) return rows[i] end }, {
    __index = function(_, name)
        if name == "HERBLORE_POTION_WILDERNESS_AGGRESSION_POTION" then return rows[19286] end
    end,
})
config.Param = { POTION_GENERIC_NAME = NAME_PARAM }

-- Fake PrettyUI window and settings page
local windows = {}
prettyui = {
    Window = { new = function(parent, opts)
        local w = { opts = opts, rows = {}, shown = false, destroyed = false }
        function w:AddText(t) local r = { content = t }; self.rows[#self.rows + 1] = r; return r end
        function w:Show() self.shown = true end
        function w:Close() self.shown = false; if self.opts.onClose then self.opts.onClose(self) end end
        -- The worst case: destroying also runs onClose
        function w:Destroy() self.destroyed = true; if self.opts.onClose then self.opts.onClose(self) end end
        w.viewport = { xyGlobal = { x = opts.x + 4, y = opts.y + 30 } }
        windows[#windows + 1] = w
        return w
    end },
    SimpleView = { new = function()
        local v = { radios = {}, buttons = {} }
        function v:AddTitle() end
        function v:AddText() end
        function v:AddDivider() end
        function v:AddSlider() end
        function v:AddColourPicker() end
        function v:AddCheckboxButton() end
        function v:AddRadioButton(choices, o) self.radios[choices[1].value] = o end
        function v:AddFancyButton(text, action) self.buttons[text] = action end
        function v:Destroy() end
        prettyui.lastView = v
        return v
    end },
}

local realPrint = print
print = function() end
dofile("main.lua")
print = realPrint

local pass, fail = 0, 0
local function check(name, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. name .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. name .. ":\n      got  " .. got .. "\n      want " .. want) end
end
local function win() return windows[#windows] end
local function lines()
    local w = win()
    if w == nil then return "no window" end
    local out = {}
    for _, r in ipairs(w.rows) do if r.content ~= "" then out[#out + 1] = r.content end end
    return table.concat(out, " | ")
end
local function shown() return win() ~= nil and win().shown end

check("no window before entering the house", #windows, "0")

-- Unrelated scenery loads: nothing happens
handlers.LocAdded({ config = { id = 12345 } })
check("other scenery ignored", #windows, "0")

-- A bubbling cauldron loads: the panel opens
handlers.LocAdded({ config = { id = 138360 } })
check("panel opens in the house", shown(), "true")
check("panel title", win().opts.title, "Potion cauldrons")
check("sized for 2 lines", win().opts.height, "96")
check("cauldron lines", lines(), "1. Elder Overload Salve: 15 doses  (refill) | 2. Aggression Potion: 120 doses")
check("column 3 never read", column3Reads, "0")

-- Close it; more cauldrons loading in the same visit don't reopen it
win():Close()
handlers.LocAdded({ config = { id = 138361 } })
check("stays closed this visit", shown(), "false")

-- Drink from cauldron 1 while it's open: 15 -> 14 doses, updates live
handlers.LocAdded({ config = { id = 138359 } })
handlers.WorldCreated({})
check("closes on leaving", shown(), "false")
handlers.LocAdded({ config = { id = 138359 } })
check("reopens next visit", shown(), "true")
cauldronVars[1].value = (182 << 1) | 1 | (14 << 13)
handlers.VarTransmit({ var = cauldronVars[1] })
check("updates live", lines(), "1. Elder Overload Salve: 14 doses  (refill) | 2. Aggression Potion: 120 doses")

-- An empty built cauldron, a single dose, and an unknown potion ID
cauldronVars[3].value = 1                               -- built, empty
cauldronVars[4].value = (182 << 1) | 1 | (1 << 13)      -- 1 dose
cauldronVars[5].value = (4000 << 1) | 1 | (50 << 13)    -- ID not in the table
handlers.VarTransmit({ var = cauldronVars[3] })
check("empty, singular, unknown", lines(),
      "1. Elder Overload Salve: 14 doses  (refill) | 2. Aggression Potion: 120 doses | 3. Empty  (refill) | "
      .. "4. Elder Overload Salve: 1 dose  (refill) | 5. Unknown potion (4000): 50 doses")

check("rebuilt taller for 5 lines", win().opts.height, "174")

-- Closed by the player, then a cauldron changes: it must not reopen
win():Close()
cauldronVars[3].value = 0
handlers.VarTransmit({ var = cauldronVars[3] })
check("stays closed after a change", shown(), "false")

-- Empty house: a 256x256 instance with the plot's invisible boundary walls
handlers.WorldCreated({})
handlers.RegionCreated({ regionGridWidth = 256, regionGridLength = 256 })
for i = 1, 3 do handlers.LocAdded({ config = { id = 139139 } }) end
check("3 walls: not yet", shown(), "false")
handlers.LocAdded({ config = { id = 139139 } })
check("4 walls in a 256x256 instance: house", shown(), "true")

-- A boss instance (128x64) with the same walls doesn't count
handlers.RegionCreated({ regionGridWidth = 128, regionGridLength = 64 })
check("closed on changing area", shown(), "false")
for i = 1, 10 do handlers.LocAdded({ config = { id = 139139 } }) end
check("walls in a small instance ignored", shown(), "false")

-- Walls in the normal world don't count either
handlers.WorldCreated({})
for i = 1, 10 do handlers.LocAdded({ config = { id = 139139 } }) end
check("walls in the normal world ignored", shown(), "false")

-- Setting it to Off: entering the house no longer opens it
handlers.WorldCreated({})
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local view = prettyui.lastView
view.radios.house.onChange(nil, "off")
check("mode saved", saved.cauldron_panel, "off")
handlers.RegionCreated({ regionGridWidth = 256, regionGridLength = 256 })
for i = 1, 5 do handlers.LocAdded({ config = { id = 139139 } }) end
handlers.LocAdded({ config = { id = 138360 } })
check("off: stays closed", shown(), "false")

-- The settings button opens it anyway
view.buttons["Show cauldron panel now"]()
check("show now button", shown(), "true")

-- A cauldron built while the panel is open, with no VarTransmit: the next
-- game tick picks it up, and the taller rebuilt window stays open
local before = #windows
cauldronVars[3].value = 1
handlers.ServerLogic()
check("new cauldron found on the next tick", #windows, tostring(before + 1))
check("rebuilt window still open", shown(), "true")
check("new cauldron listed", lines(),
      "1. Elder Overload Salve: 14 doses  (refill) | 2. Aggression Potion: 120 doses | 3. Empty  (refill) | "
      .. "4. Elder Overload Salve: 1 dose  (refill) | 5. Unknown potion (4000): 50 doses")

-- Nothing changed: no rebuild
handlers.ServerLogic()
check("no rebuild without a change", #windows, tostring(before + 1))

-- Dragging the window: its position is saved and used for the next window
handlers.ServerLogic()   -- first tick after showing records the offset
win().viewport.xyGlobal = { x = 504, y = 330 }
handlers.ServerLogic()
check("dragged position saved", tostring(saved.cauldron_x) .. "," .. tostring(saved.cauldron_y), "500,300")
cauldronVars[3].value = 0
handlers.ServerLogic()
check("rebuilt window opens where it was left", win().opts.x .. "," .. win().opts.y, "500,300")

-- Number labels over the cauldrons: the visible text centred over a tile.
local function labelAt(x)
    for _, t in ipairs(texts) do
        if t.posX == x - 20 and not t.hidden and t.isShadowed ~= nil then return t.content end
    end
    return "none"
end

handlers.WorldCreated({})
handlers.LocAdded({ config = { id = 138359 } })        -- entering the house
for i = 1, 6 do handlers.ServerLogic() end
check("unmatched cauldrons show ?", labelAt(21 * 50) .. labelAt(22 * 50) .. labelAt(23 * 50), "???")

-- Drink from the middle cauldron while standing in front of it: it's number 4
playerTile = tile(22, 6)
cauldronVars[4].value = (182 << 1) | 1 | (106 << 13)
handlers.ServerLogic()
check("middle learned as 4", labelAt(22 * 50), "4")
check("others still ?", labelAt(21 * 50) .. labelAt(23 * 50), "??")
check("match saved", saved.cauldron_map["0:22:7"], "4")

-- Filling the left cauldron while standing in front of it: it's number 3
cauldronVars[3].value = 1
playerTile = tile(21, 6)
handlers.ServerLogic()
check("left learned as 3", labelAt(21 * 50), "3")

-- Far from every cauldron: a change isn't credited to any of them
playerTile = tile(10, 10)
cauldronVars[5].value = (146 << 1) | 1 | (2 << 13)
handlers.ServerLogic()
check("far away: right still ?", labelAt(23 * 50), "?")

-- Equally close to two cauldrons: not learned
playerTile = { level = 0, x = 10000 + 22, z = 3600 + 6, localX = 22, localZ = 6 }
houseLocs[138361] = { { coordGrid = tile(22, 5) } }    -- move Arcane opposite Bubbling
handlers.ServerLogic()
cauldronVars[5].value = (146 << 1) | 1 | (1 << 13)
handlers.ServerLogic()
check("tie: nothing learned", saved.cauldron_map["0:22:5"], "nil")
houseLocs[138361] = { { coordGrid = tile(23, 7) } }

-- Leaving hides the labels; the house loading again doesn't learn anything
handlers.WorldCreated({})
check("labels hidden after leaving", labelAt(22 * 50), "none")
handlers.LocAdded({ config = { id = 138359 } })
playerTile = tile(23, 6)
cauldronVars[2].value = (146 << 1) | 1 | (99 << 13)    -- arrives as the house loads
handlers.ServerLogic()
check("no learning while loading", saved.cauldron_map["0:23:7"], "nil")
check("matches kept between visits", labelAt(22 * 50) .. labelAt(21 * 50), "43")

-- Refill colour: cauldron 3 is empty (at or below the default 20), so its
-- number is red; cauldron 4 has 106 doses, so it stays yellow
local function labelColourAt(x)
    for _, t in ipairs(texts) do
        if t.posX == x - 20 and not t.hidden and t.isShadowed ~= nil then
            return string.format("%.2f,%.2f,%.2f", t.colour.r, t.colour.g, t.colour.b)
        end
    end
    return "none"
end
check("empty cauldron's number in refill colour", labelColourAt(21 * 50), "1.00,0.25,0.25")
check("full cauldron's number in normal colour", labelColourAt(22 * 50), "1.00,1.00,0.00")

-- Reloading the plugin destroys the window
PluginShutdown()
check("destroyed on shutdown", win().destroyed, "true")

print(string.format("\n%d passed, %d failed", pass, fail))
