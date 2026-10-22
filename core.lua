-- Item Charges: core.lua
-- Saved settings and colours, shared by every other file, plus reading a
-- player variable. Settings are kept with PersistentDB between sessions.

local core = {}

function core.loadSetting(key, isValid, default)
    local ok, saved = pcall(function() return PersistentDB:Get(key) end)
    if ok and isValid(saved) then
        return saved
    end
    return default
end

function core.saveSetting(key, value)
    pcall(function() PersistentDB:Set(key, value) end)
end

function core.isBoolean(v) return type(v) == "boolean" end

-- Colours are stored as { r, g, b } in 0-255.
core.DEFAULT_COLOURS = {
    normal         = { r = 255, g = 255, b = 0 },   -- yellow
    low            = { r = 255, g = 64,  b = 64 },  -- red
    outline        = { r = 0,   g = 0,   b = 0 },   -- black
    invention      = { r = 255, g = 255, b = 0 },
    invention_low  = { r = 255, g = 64,  b = 64 },
    cauldron       = { r = 255, g = 255, b = 0 },   -- numbers over cauldrons
    cauldron_low   = { r = 255, g = 64,  b = 64 },
    restock        = { r = 255, g = 64,  b = 64 },
}

function core.isColour(v)
    return type(v) == "table" and v.r ~= nil and v.g ~= nil and v.b ~= nil
end

core.colours = {}
for which, d in pairs(core.DEFAULT_COLOURS) do
    local c = core.loadSetting("colour_" .. which, core.isColour, d)
    core.colours[which] = { r = c.r, g = c.g, b = c.b }
end

core.outlineEnabled = core.loadSetting("outline_enabled", core.isBoolean, false)
core.showInBank = core.loadSetting("show_in_bank", core.isBoolean, true)
core.showOnActionBars = core.loadSetting("show_on_action_bars", core.isBoolean, true)

core.CAULDRON_MODES = { house = true, off = true }
core.cauldronMode = core.loadSetting("cauldron_panel", function(v) return core.CAULDRON_MODES[v] == true end, "house")

-- A saved window position.
function core.isCoord(v) return type(v) == "number" and v >= 0 end

-- At or below these, numbers use the low colour. Separate for potions (doses)
-- and jewellery (charges).
core.LOW_THRESHOLD_MAX = 5
function core.isThreshold(v)
    return math.type(v) == "integer" and v >= 1 and v <= core.LOW_THRESHOLD_MAX
end
core.lowThresholds = {
    potion    = core.loadSetting("low_threshold_potion", core.isThreshold, 1),
    jewellery = core.loadSetting("low_threshold_jewellery", core.isThreshold, 1),
}

-- The potion supplies panel marks a potion for restocking at or below this
-- many doses in total.
core.RESTOCK_MAX = 500
core.RESTOCK_STEP = 10
core.restockAt = core.loadSetting("supplies_restock_at", function(v)
    return math.type(v) == "integer" and v >= 0 and v <= core.RESTOCK_MAX
end, 50)

-- A potion cauldron is marked for refilling at or below this many doses.
core.REFILL_MAX = 500
core.REFILL_STEP = 10
core.refillAt = core.loadSetting("cauldron_refill_at", function(v)
    return math.type(v) == "integer" and v >= 0 and v <= core.REFILL_MAX
end, 20)

core.SUPPLIES_MODES = { bank = true, off = true }
core.suppliesMode = core.loadSetting("supplies_panel", function(v) return core.SUPPLIES_MODES[v] == true end, "bank")

core.INVENTION_LINES = {
    { value = "time",   key = "show_invention",        text = "Show time left" },
    { value = "charge", key = "show_invention_charge", text = "Show current charge" },
    { value = "drain",  key = "show_invention_drain",  text = "Show drain rate" },
}
core.showInventionLine = {}
core.inventionLineKeys = {}
for _, line in ipairs(core.INVENTION_LINES) do
    core.showInventionLine[line.value] = core.loadSetting(line.key, core.isBoolean, true)
    core.inventionLineKeys[line.value] = line.key
end

core.TEXT_SIZES = { normal = true, small = true, xs = true }
core.inventionTextSize = core.loadSetting("invention_text_size",
    function(v) return core.TEXT_SIZES[v] == true end, "normal")

function core.toVector4(c)
    return Vector4.new(c.r / 255, c.g / 255, c.b / 255, 1.0)
end

-- PrettyUI colour pickers use 0xRRGGBBAA.
function core.toHex(c)
    return (c.r << 24) | (c.g << 16) | (c.b << 8) | 0xFF
end

function core.fromHex(hex)
    hex = math.tointeger(hex) or math.floor(hex)
    return { r = (hex >> 24) & 0xFF, g = (hex >> 16) & 0xFF, b = (hex >> 8) & 0xFF }
end

-- A player variable's value, or nil if it can't be read.
function core.readVarPlayer(name)
    local ok, value = pcall(function() return var.VarPlayer[name].value end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

return core
