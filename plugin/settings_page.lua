-- Item Charges: settings_page.lua
-- The settings page (the cog next to Item Charges in the Plugin Hub's
-- Manage tab), built with PrettyUI by rsnJ3 (https://prettyui.j3.gg/).

local core = require("core")
local display = require("display")
local cauldrons = require("cauldrons")
local supplies = require("supplies")

local settingsView = nil

-- Small helpers for the settings page's controls. Sliders, radio buttons and
-- fancy buttons may be missing from older PrettyUI versions, so each is only
-- added when PrettyUI has it.
local add = {}

-- A colour picker under a label. after() runs once the colour is saved.
function add.colour(key, label, after)
    settingsView:AddText(label)
    settingsView:AddColourPicker({
        value = core.toHex(core.colours[key]),
        buttonSize = 32,
        windowTitle = label,
        onChange = function(picker, colour)
            core.colours[key] = core.fromHex(colour)
            core.saveSetting("colour_" .. key, core.colours[key])
            pcall(after or display.safeRender)
        end,
    })
end

-- A slider under a label that text() writes, so the label shows the value.
-- set(value) gets each new whole-number value.
function add.slider(text, min, max, step, value, set)
    if settingsView.AddSlider == nil then return end
    local label = settingsView:AddText(text())
    settingsView:AddSlider({
        min = min, max = max, step = step, value = value,
        onChange = function(slider, v)
            v = math.tointeger(v) or math.floor(v + 0.5)
            if v < min or v > max then return end
            set(v)
            if label ~= nil then label.content = text() end
        end,
    })
end

-- A row of radio buttons after a label. set(value) gets the chosen value.
function add.radio(label, choices, selected, set)
    settingsView:AddText(label)
    if settingsView.AddRadioButton == nil then return end
    settingsView:AddRadioButton(choices, {
        selectedValue = selected,
        inline = true,
        onChange = function(group, value) set(value) end,
    })
end

function add.button(text, action)
    if settingsView.AddFancyButton == nil then return end
    settingsView:AddFancyButton(text, function()
        local ok, err = pcall(action)
        if not ok then print("Item Charges: " .. text .. ": " .. tostring(err)) end
    end)
end

local THRESHOLD_SETTINGS = {
    { kind = "potion",    key = "low_threshold_potion",    unit = "doses",   label = "Potions" },
    { kind = "jewellery", key = "low_threshold_jewellery", unit = "charges", label = "Jewellery" },
}

-- "Restore defaults" buttons, one per section. Each puts its section's
-- settings back to how a new install starts. Learned cauldron numbers and the
-- cauldron window's position aren't settings, so they're kept.
local restore = {
    parent = nil,          -- the settings page area, for rebuilding it
    rebuildPending = false,
}

function restore.colours(keys)
    for _, key in ipairs(keys) do
        local d = core.DEFAULT_COLOURS[key]
        core.colours[key] = { r = d.r, g = d.g, b = d.b }
        core.saveSetting("colour_" .. key, core.colours[key])
    end
end

function restore.numbers()
    core.outlineEnabled, core.showInBank, showOnActionBars = false, true, true
    core.saveSetting("outline_enabled", core.outlineEnabled)
    core.saveSetting("show_in_bank", core.showInBank)
    core.saveSetting("show_on_action_bars", core.showOnActionBars)
    for _, setting in ipairs(THRESHOLD_SETTINGS) do
        core.lowThresholds[setting.kind] = 1
        core.saveSetting(setting.key, 1)
    end
    restore.colours({ "normal", "low", "outline" })
end

function restore.invention()
    for _, line in ipairs(core.INVENTION_LINES) do
        core.showInventionLine[line.value] = true
        core.saveSetting(line.key, true)
    end
    core.inventionTextSize = "normal"
    core.saveSetting("invention_text_size", core.inventionTextSize)
    restore.colours({ "invention", "invention_low" })
end

function restore.cauldrons()
    core.cauldronMode = "house"
    core.saveSetting("cauldron_panel", core.cauldronMode)
    core.refillAt = 20
    core.saveSetting("cauldron_refill_at", core.refillAt)
    cauldrons.LABEL.mode = "icon"
    core.saveSetting("cauldron_labels", cauldrons.LABEL.mode)
    cauldrons.LABEL.showDoses = false
    core.saveSetting("cauldron_show_doses", false)
    restore.colours({ "cauldron", "cauldron_low" })
end

function restore.supplies()
    core.suppliesMode = "bank"
    core.saveSetting("supplies_panel", core.suppliesMode)
    core.restockAt = 50
    core.saveSetting("supplies_restock_at", core.restockAt)
    restore.colours({ "restock" })
end

-- The page is rebuilt so its controls show the restored values. That's done
-- on the next Logic update rather than inside the button's own click, since
-- rebuilding destroys the button.
function restore.addButton(text, reset)
    add.button(text, function()
        reset()
        display.safeRender()
        pcall(cauldrons.updateCauldronWindow)
        pcall(supplies.onSuppliesChanged)
        restore.rebuildPending = true
    end)
end

local function buildSettingsPage(parent)
    restore.parent = parent
    if settingsView ~= nil then
        pcall(function() settingsView:Destroy() end)
        settingsView = nil
    end

    settingsView = prettyui.SimpleView.new(parent, {
        width = parent.width,
        height = parent.height,
    })

    settingsView:AddTitle("Item Charges")
    settingsView:AddText("Changes are saved immediately.")

    settingsView:AddCheckboxButton({
        { text = "Outline the numbers", value = "outline", selected = core.outlineEnabled },
        { text = "Show numbers in the bank", value = "bank", selected = core.showInBank },
        { text = "Show numbers on action bars", value = "bars", selected = core.showOnActionBars },
    }, {
        onChange = function(group, values, changedValue, selected)
            if changedValue == "outline" then
                core.outlineEnabled = selected == true
                core.saveSetting("outline_enabled", core.outlineEnabled)
            elseif changedValue == "bank" then
                core.showInBank = selected == true
                core.saveSetting("show_in_bank", core.showInBank)
            elseif changedValue == "bars" then
                core.showOnActionBars = selected == true
                core.saveSetting("show_on_action_bars", core.showOnActionBars)
            end
            display.safeRender()
        end,
    })

    for _, setting in ipairs(THRESHOLD_SETTINGS) do
        add.slider(function()
            return string.format("%s: low charge colour at %d %s or fewer", setting.label,
                core.lowThresholds[setting.kind], setting.unit)
        end, 1, core.LOW_THRESHOLD_MAX, 1, core.lowThresholds[setting.kind], function(v)
            core.lowThresholds[setting.kind] = v
            core.saveSetting(setting.key, v)
            display.safeRender()
        end)
    end

    add.colour("normal", "Charge number colour")
    add.colour("low", "Low charge colour")
    add.colour("outline", "Outline colour (numbers and Invention text)")
    restore.addButton("Restore number defaults", restore.numbers)

    settingsView:AddDivider()
    settingsView:AddText("Invention charge (worn equipment tab):")
    local inventionChoices = {}
    for _, line in ipairs(core.INVENTION_LINES) do
        inventionChoices[#inventionChoices + 1] = {
            text = line.text, value = line.value, selected = core.showInventionLine[line.value],
        }
    end
    settingsView:AddCheckboxButton(inventionChoices, {
        onChange = function(group, values, changedValue, selected)
            if core.inventionLineKeys[changedValue] == nil then return end
            core.showInventionLine[changedValue] = selected == true
            core.saveSetting(core.inventionLineKeys[changedValue], core.showInventionLine[changedValue])
            display.safeRender()
        end,
    })

    add.radio("Invention text size:", {
        { text = "Normal", value = "normal" },
        { text = "Small",  value = "small" },
        { text = "XS",     value = "xs" },
    }, core.inventionTextSize, function(value)
        if not core.TEXT_SIZES[value] then return end
        core.inventionTextSize = value
        core.saveSetting("invention_text_size", core.inventionTextSize)
        display.safeRender()
    end)

    add.colour("invention", "Invention text colour")
    add.colour("invention_low", "Invention colour under 30 minutes")
    restore.addButton("Restore Invention defaults", restore.invention)

    settingsView:AddDivider()
    add.radio("Potion cauldron panel:", {
        { text = "When I enter my house", value = "house" },
        { text = "Off", value = "off" },
    }, core.cauldronMode, function(value)
        if not core.CAULDRON_MODES[value] then return end
        core.cauldronMode = value
        core.saveSetting("cauldron_panel", core.cauldronMode)
    end)
    add.button("Show cauldron panel now", cauldrons.showCauldronWindow)
    add.radio("Over each cauldron:", {
        { text = "Potion icon", value = "icon" },
        { text = "Number", value = "number" },
    }, cauldrons.LABEL.mode, function(value)
        if not cauldrons.LABEL_MODES[value] then return end
        cauldrons.LABEL.mode = value
        core.saveSetting("cauldron_labels", value)
    end)
    settingsView:AddCheckboxButton({
        { text = "Show doses over each cauldron", value = "doses", selected = cauldrons.LABEL.showDoses },
    }, {
        onChange = function(group, values, changedValue, selected)
            cauldrons.LABEL.showDoses = selected == true
            core.saveSetting("cauldron_show_doses", cauldrons.LABEL.showDoses)
        end,
    })
    add.slider(function()
        return string.format("Mark cauldrons for refill at %d doses or fewer", core.refillAt)
    end, 0, core.REFILL_MAX, core.REFILL_STEP, core.refillAt, function(v)
        core.refillAt = v
        core.saveSetting("cauldron_refill_at", v)
        cauldrons.updateCauldronWindow()
    end)
    -- The numbers over cauldrons pick up a new colour on the next game tick.
    add.colour("cauldron", "Number over each cauldron", function() end)
    add.colour("cauldron_low", "Cauldron refill colour (panel and numbers over cauldrons)", cauldrons.updateCauldronWindow)
    restore.addButton("Restore cauldron defaults", restore.cauldrons)

    settingsView:AddDivider()
    -- Kept short: the radio buttons sit on the same row and get cut off.
    settingsView:AddText("Potion supplies (counts your backpack, beast of burden and bank).")
    add.radio("Potion supplies panel:", {
        { text = "Beside my bank", value = "bank" },
        { text = "Off", value = "off" },
    }, core.suppliesMode, function(value)
        if not core.SUPPLIES_MODES[value] then return end
        core.suppliesMode = value
        core.saveSetting("supplies_panel", core.suppliesMode)
    end)
    add.slider(function()
        return string.format("Mark for restock at %d doses or fewer", core.restockAt)
    end, 0, core.RESTOCK_MAX, core.RESTOCK_STEP, core.restockAt, function(v)
        core.restockAt = v
        core.saveSetting("supplies_restock_at", v)
        supplies.onSuppliesChanged()
    end)
    add.colour("restock", "Restock colour", supplies.onSuppliesChanged)
    add.button("Show potion supplies", supplies.showSuppliesWindow)
    restore.addButton("Restore supplies defaults", restore.supplies)

    settingsView:AddDivider()
    settingsView:AddText("Settings page built with PrettyUI by rsnJ3 (prettyui.j3.gg).")
end

Event.SettingsLayerReady.Subscribe("itemChargesSettings", function(settingsEvent)
    local ok, err = pcall(buildSettingsPage, settingsEvent.component)
    if not ok then
        print("Item Charges: settings page error: " .. tostring(err))
    end
end)

Event.Logic.Subscribe("itemChargesSettingsRebuild", function()
    if not restore.rebuildPending or restore.parent == nil then return end
    restore.rebuildPending = false
    local ok, err = pcall(buildSettingsPage, restore.parent)
    if not ok then
        print("Item Charges: settings page error: " .. tostring(err))
    end
end)

-- Called when the plugin is turned off or reloaded.
local function shutdown()
    Event.SettingsLayerReady.Unsubscribe("itemChargesSettings")
    if settingsView ~= nil then
        pcall(function() settingsView:Destroy() end)
        settingsView = nil
    end
end

return {
    shutdown = shutdown,
}
