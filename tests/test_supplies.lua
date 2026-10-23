-- Offline test for the potion supplies panel.  Run:  lua5.4 tests/test_supplies.lua  (from the main folder)
-- Doses are added up across the backpack, beast of burden and bank (stacks
-- count fully), the bank is remembered after it closes, and potions at or
-- below the restock level are marked.

local function item(name, ops) return { name = name, interfaceOpNames = ops or {} } end
local function slot(obj, count) return { obj = obj, count = count } end
local EMPTY = slot(item(""), 0)

local backpack = { slot(item("Super restore (4)", { "Drink" }), 1), slot(item("Super restore (2)", { "Drink" }), 1),
                   slot(item("Games necklace (8)", { "Wear" }), 1), EMPTY }
local bob = { slot(item("Prayer potion (3)", { "Drink" }), 1) }
local bank = { slot(item("Super restore (4)", { "Drink" }), 10),     -- a stack: 40 doses
               slot(item("Prayer potion (4)", { "Drink" }), 0),      -- placeholder: ignored
               slot(item("Saradomin brew flask (6)", { "Drink" }), 2),
               slot(item("Bones", { "Bury" }), 100) }
local bankOpen = true

local function comp(extra)
    local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = false }
    function c:SetPos() end
    function c:SetSize() end
    function c:AlignTo() end
    function c:IterateDynamicComponents() end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local pluginLayer = comp({ visibleGlobal = true })
local bankContainer = comp()   -- visible while the bank window is open
Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
ui = {
    Interfaces = { GetComponent = function(_, name)
        if name == "TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP" then return pluginLayer end
        if name == "BANK__BANK_ITEMS_CONTAINER" then return bankContainer end
        return comp()
    end },
    Text = { new = function() return comp() end },
    AlignMode = { CENTRE = 0 },
}
id = { Component = setmetatable({}, { __index = function(_, k) return k end }), Font = {} }
config = { Inv = { INV = "INV", WORN = "WORN", BANK = "BANK", LORE_BOB = "LORE_BOB" } }
Player = { IsAvailable = function() return true end }
var = { VarPlayer = {} }
local saved = {}
PersistentDB = {}
function PersistentDB:Get(k) return saved[k] end
function PersistentDB:Set(k, v) saved[k] = v; return true end
Inventory = { Find = function(cfg)
    local contents = ({ INV = backpack, LORE_BOB = bob })[cfg] or {}
    if cfg == "BANK" and bankOpen then contents = bank end
    return { isValid = true, slotCount = #contents, GetSlot = function(_, i) return contents[i] end }
end }
local handlers = {}
Event = setmetatable({}, { __index = function(_, evName)
    return { Subscribe = function(_, fn)
        local prev = handlers[evName]
        handlers[evName] = prev and function(...) prev(...); fn(...) end or fn
    end, Unsubscribe = function() end }
end })

local windows = {}
prettyui = {
    Window = { new = function(parent, opts)
        local w = { opts = opts, rows = {}, shown = false, destroyed = false }
        w.viewport = { xyGlobal = { x = opts.x + 4, y = opts.y + 30 } }
        function w:AddText(t) local r = { content = t }; self.rows[#self.rows + 1] = r; return r end
        function w:AddFancyButton(text, action) if text ~= "Filter bank" then self.button = action end end
        function w:Show() self.shown = true end
        function w:Close() self.shown = false; if self.opts.onClose then self.opts.onClose(self) end end
        function w:Destroy() self.destroyed = true end
        windows[#windows + 1] = w
        return w
    end },
    SimpleView = { new = function()
        local v = { sliders = {}, buttons = {}, texts = {} }
        function v:AddTitle() end
        function v:AddText(t) local tx = { content = t }; self.texts[#self.texts + 1] = tx; return tx end
        function v:AddDivider() end
        function v:AddSlider(o) self.sliders[#self.sliders + 1] = o end
        function v:AddColourPicker() end
        function v:AddCheckboxButton() end
        function v:AddRadioButton() end
        function v:AddFancyButton(text, action) self.buttons[text] = action end
        function v:Destroy() end
        prettyui.lastView = v
        return v
    end },
}

local realPrint = print
print = function() end
dofile("tests/load_plugin.lua")
print = realPrint

local pass, fail = 0, 0
local function check(name, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. name .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. name .. ":\n      got  " .. got .. "\n      want " .. want) end
end
local function win() return windows[#windows] end
local function lines()
    local out = {}
    for _, r in ipairs(win().rows) do out[#out + 1] = r.content end
    return table.concat(out, " | ")
end

-- The bank is open while the plugin loads an inventory event: its totals are saved
handlers.InventoryUpdated({})
check("bank totals saved", saved.supplies_bank_doses ~= nil and saved.supplies_bank_doses["Super restore"], "40")

-- Open the panel from the settings page. Lowest first; at or below 50 marked.
-- Super restore: 4 + 2 (backpack) + 40 (bank) = 46. Prayer potion: 3 (familiar).
-- Saradomin brew flask: 2 x 6 = 12. The necklace, bones and placeholder are left out.
handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local view = prettyui.lastView
view.buttons["Show potion supplies"]()
check("panel title", win().opts.title, "Potion supplies")
check("totals, lowest first", lines(),
      "Prayer potion: 3 doses  (restock) | Saradomin brew flask: 12 doses  (restock) | Super restore: 46 doses  (restock)")

-- Restock slider (the fourth, after the cauldron refill slider) down to 10: only the prayer potion is marked
view.sliders[4].onChange(nil, 10)
check("restock level saved", saved.supplies_restock_at, "10")
check("restock at 10", lines(),
      "Prayer potion: 3 doses  (restock) | Saradomin brew flask: 12 doses | Super restore: 46 doses")
local function rowColour(i)
    local c = win().rows[i].colour
    return string.format("%.2f,%.2f,%.2f", c.r, c.g, c.b)
end
check("restock line in restock colour", rowColour(1), "1.00,0.25,0.25")
check("other lines back to the default white", rowColour(2) .. " " .. rowColour(3), "1.00,1.00,1.00 1.00,1.00,1.00")

-- Close the bank: its saved totals are still used
bankOpen = false
handlers.InventoryUpdated({})
check("bank remembered after closing", lines(),
      "Prayer potion: 3 doses  (restock) | Saradomin brew flask: 12 doses | Super restore: 46 doses")

-- Drink a dose: the backpack's Super restore (2) becomes (1), updates live
backpack[2] = slot(item("Super restore (1)", { "Drink" }), 1)
handlers.InventoryUpdated({})
check("updates live", lines(),
      "Prayer potion: 3 doses  (restock) | Saradomin brew flask: 12 doses | Super restore: 45 doses")

-- Opening the bank shows a small summary to the right of the bank (bank item
-- area at 100,300, 400 wide; no backpack panel in this test -> x 540, y 205)
local list = win()
list:Close()
bankContainer.visibleGlobal = true
bankContainer.xyGlobal = { x = 100, y = 300 }
bankContainer.width = 400
handlers.ServerLogic()
local summary = win()
check("summary beside the bank", summary.shown and summary.opts.x .. "," .. summary.opts.y, "540,205")
check("summary text", summary.rows[1].content, "1 potion to restock.")
check("list stays closed", list.shown, "false")

-- Its button opens the list underneath it
summary.button()
check("list opens under the summary", win().shown and win().opts.x .. "," .. win().opts.y, "540,405")
-- Dragging the list somewhere: it's saved, and from then on the list opens
-- there instead of under the summary (here, 300 right and 100 down)
handlers.ServerLogic()                      -- records where it first sat
win().viewport.xyGlobal = { x = 844, y = 535 }
handlers.ServerLogic()
check("dragged list position saved", tostring(saved.supplies_x) .. "," .. tostring(saved.supplies_y), "840,505")

-- Closing the bank closes both. As in-game, a closed bank's item area still
-- says visible, but with a size of 0 at (0, 0).
local listFromBank = win()
bankContainer.xyGlobal = { x = 0, y = 0 }
bankContainer.width, bankContainer.height = 0, 0
handlers.ServerLogic()
check("closes with the bank", tostring(summary.destroyed) .. "," .. tostring(listFromBank.shown), "true,false")
-- Next bank visit: the same list window reopens, still where it was dragged,
-- instead of being rebuilt under the summary
bankContainer.xyGlobal = { x = 100, y = 300 }
bankContainer.width, bankContainer.height = 400, 400
handlers.ServerLogic()
win().button()
check("list reopens where it was dragged", tostring(listFromBank.shown) .. "," .. tostring(listFromBank.destroyed), "true,false")

-- Dragging the summary too: the next time the bank opens, the summary opens
-- where it was left instead of beside the bank
local secondSummary
for i = #windows, 1, -1 do if windows[i].button ~= nil then secondSummary = windows[i]; break end end
handlers.ServerLogic()                      -- records where it first sat
secondSummary.viewport.xyGlobal = { x = 1004, y = 80 }
handlers.ServerLogic()
check("dragged summary position saved", tostring(saved.summary_x) .. "," .. tostring(saved.summary_y), "1000,50")
bankContainer.xyGlobal = { x = 0, y = 0 }
bankContainer.width, bankContainer.height = 0, 0
handlers.ServerLogic()
bankContainer.xyGlobal = { x = 100, y = 300 }
bankContainer.width, bankContainer.height = 400, 400
handlers.ServerLogic()
check("summary reopens where it was dragged", win().opts.x .. "," .. win().opts.y, "1000,50")

-- Reloading the plugin destroys the window
PluginShutdown()
check("destroyed on shutdown", win().destroyed, "true")

print(string.format("\n%d passed, %d failed", pass, fail))
