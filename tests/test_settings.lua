-- Offline test for the PrettyUI settings page.  Run:  lua5.4 tests/test_settings.lua  (from the main folder)
-- Uses fake versions of the game API, PrettyUI and PersistentDB to check:
--   1. each colour picker starts on the saved colour (as an RGBA hex number)
--   2. accepting a colour in a picker recolours the right numbers and saves it
--   3. the outline checkbox turns the outline copies on/off and saves it
--   4. every setting comes back after a "restart"
--   5. reopening the page destroys the old view first

local savedData = {}

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = x end
    return t
end

local function fresh()
    local overlayTexts, handlers, views = {}, {}, {}

    local function comp(extra)
        local c = { xyGlobal = { x = 0, y = 0 }, width = 36, height = 32, visibleGlobal = true }
        function c:SetHeaderLayout() end
        function c:SetPos(x, y) self.posX, self.posY = x, y end
        function c:SetSize(w, h) self.w, self.h = w, h end
        function c:AlignTo() end
        for k, v in pairs(extra or {}) do c[k] = v end
        return c
    end

    local icons = {
        comp({ dynamicID = 0, xyGlobal = { x = 1650, y = 720 } }),
        comp({ dynamicID = 1, xyGlobal = { x = 1690, y = 720 } }),
    }
    local itemLayer = comp()
    function itemLayer:IterateDynamicComponents(cb)
        for _, ic in ipairs(icons) do cb(ic, true) end
    end
    local pluginLayer = comp()

    Vector4 = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
    ui = {
        Interfaces = { GetComponent = function(_, name)
            if name == "TOPLEVEL_V2_INVENTORY__ITEM_LAYER" then return itemLayer end
            return pluginLayer
        end },
        GroupBox = { new = function() return comp() end },
        Text = { new = function(parent)
            local t = comp()
            if parent == pluginLayer then overlayTexts[#overlayTexts + 1] = t end
            return t
        end },
        AlignMode = { CENTRE = 0 },
    }

    -- Fake PrettyUI: records what the plugin asks for, so we can poke it
    prettyui = { SimpleView = { new = function(parent, opts)
        local v = { items = {}, destroyed = false, opts = opts }
        function v:AddTitle(t) table.insert(self.items, { kind = "title", text = t }) end
        function v:AddText(t) table.insert(self.items, { kind = "text", text = t }) end
        function v:AddCheckboxButton(choices, o)
            table.insert(self.items, { kind = "check", choices = choices, opts = o })
        end
        function v:AddColourPicker(o) table.insert(self.items, { kind = "picker", opts = o }) end
        function v:AddDivider() table.insert(self.items, { kind = "divider" }) end
        function v:AddFancyButton(t, fn) table.insert(self.items, { kind = "button", text = t, fn = fn }) end
        function v:Destroy() self.destroyed = true end
        views[#views + 1] = v
        return v
    end } }

    id = { Component = setmetatable({}, { __index = function(_, k) return k end }),
           StyleSheet = {}, Font = {} }
    config = { Inv = { INV = "INV" } }
    Player = { IsAvailable = function() return true end }
    PersistentDB = {}
    function PersistentDB:Get(k) return copy(savedData[k]) end
    function PersistentDB:Set(k, v) savedData[k] = copy(v); return true end
    Event = setmetatable({}, { __index = function(_, evName)
        return { Subscribe = function(_, fn) local prev = handlers[evName]; handlers[evName] = prev and function(...) prev(...); fn(...) end or fn end, Unsubscribe = function() end }
    end })
    Inventory = { Find = function()
        return { isValid = true, slotCount = 2, usedSlotCount = 2,
                 GetSlot = function(_, i)
                     local names = { "Games necklace (8)", "Games necklace (1)" }
                     return { obj = { name = names[i] } }
                 end }
    end }

    local realPrint = print
    print = function() end
    dofile("main.lua")
    print = realPrint

    -- Each slot's number: 8 outline copies, then the main text
    local function slot(n)
        local base = (n - 1) * 9
        local outlines = {}
        for i = 1, 8 do outlines[i] = overlayTexts[base + i] end
        return { main = overlayTexts[base + 9], outlines = outlines }
    end

    return { handlers = handlers, views = views, slot = slot }
end

local function rgb(v)
    return string.format("%d,%d,%d", math.floor(v.r * 255 + 0.5),
        math.floor(v.g * 255 + 0.5), math.floor(v.b * 255 + 0.5))
end
local function visibleOutlines(s)
    local n = 0
    for _, t in ipairs(s.outlines) do if not t.hidden then n = n + 1 end end
    return n
end
local function findItems(view, kind)
    local out = {}
    for _, it in ipairs(view.items) do if it.kind == kind then out[#out + 1] = it end end
    return out
end
local pass, fail = 0, 0
local function check(label, got, want)
    got = tostring(got)
    if got == want then pass = pass + 1; print("PASS  " .. label .. " = " .. got)
    else fail = fail + 1; print("FAIL  " .. label .. ": got " .. got .. ", want " .. want) end
end

------------------------------------------------------------------ first load
local p = fresh()
local full, low = p.slot(1), p.slot(2)
check("main number visible", full.main.hidden ~= true, "true")
check("full necklace colour (yellow)", rgb(full.main.colour), "255,255,0")
check("low necklace colour (red)", rgb(low.main.colour), "255,64,64")
check("outline copies hidden by default", visibleOutlines(full), "0")

p.handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local view = p.views[1]
local pickers = findItems(view, "picker")
local checkbox = findItems(view, "check")[1]
check("view sized to the page", view.opts.width .. "x" .. view.opts.height, "640x340")
check("number of colour pickers", #pickers, "7")
check("normal picker starts yellow", string.format("0x%08X", pickers[1].opts.value), "0xFFFF00FF")
check("low picker starts red", string.format("0x%08X", pickers[2].opts.value), "0xFF4040FF")
check("outline picker starts black", string.format("0x%08X", pickers[3].opts.value), "0x000000FF")
check("checkbox starts unticked", checkbox.choices[1].selected, "false")

------------------------------------------------------------------ pick colours
pickers[1].opts.onChange(nil, 0x00E6FFFF)          -- accept cyan for normal
check("full necklace now cyan", rgb(full.main.colour), "0,230,255")
check("low necklace unchanged", rgb(low.main.colour), "255,64,64")
check("normal colour saved", savedData.colour_normal.r .. "," .. savedData.colour_normal.g ..
      "," .. savedData.colour_normal.b, "0,230,255")

------------------------------------------------------------------ outline
checkbox.opts.onChange(nil, { "outline" }, "outline", true)
check("outline copies visible", visibleOutlines(full), "8")
check("shadow off with outline", full.main.isShadowed, "false")
pickers[3].opts.onChange(nil, 0xFFFFFFFF)          -- accept white outline
check("outline copies white", rgb(full.outlines[1].colour), "255,255,255")
check("outline setting saved", savedData.outline_enabled, "true")

------------------------------------------------------------------ reopen the page
p.handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
check("old view destroyed on reopen", view.destroyed, "true")
check("new view built", #p.views, "2")

------------------------------------------------------------------ restart
local p2 = fresh()
check("after restart: number colour", rgb(p2.slot(1).main.colour), "0,230,255")
check("after restart: outline on", visibleOutlines(p2.slot(1)), "8")
check("after restart: outline colour", rgb(p2.slot(1).outlines[1].colour), "255,255,255")
p2.handlers.SettingsLayerReady({ component = { width = 640, height = 340 } })
local cb2 = findItems(p2.views[1], "check")[1]
check("after restart: checkbox ticked", cb2.choices[1].selected, "true")

------------------------------------------------------------------ restore defaults
local restore
for _, b in ipairs(findItems(p2.views[1], "button")) do
    if b.text == "Restore number defaults" then restore = b end
end
check("restore button present", restore ~= nil, "true")
check("four restore buttons", (function() local n = 0; for _, b in ipairs(findItems(p2.views[1], "button")) do if b.text:find("^Restore") then n = n + 1 end end; return n end)(), "4")
restore.fn()
check("restored: number colour yellow", rgb(p2.slot(1).main.colour), "255,255,0")
check("restored: outline off", visibleOutlines(p2.slot(1)), "0")
check("restored: saved", tostring(savedData.outline_enabled) .. " " .. savedData.colour_normal.b, "false 0")
p2.handlers.Logic()
check("page rebuilt after restoring", #p2.views, "2")
check("rebuilt checkbox unticked", findItems(p2.views[2], "check")[1].choices[1].selected, "false")

print(string.format("\n%d passed, %d failed", pass, fail))
