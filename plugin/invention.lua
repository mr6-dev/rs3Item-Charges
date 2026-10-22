-- Item Charges: invention.lua
-- Invention charge in the corner of the worn equipment tab: time left,
-- current charge and drain rate, matching the game's own tooltip.

local core = require("core")
local widgets = require("widgets")
local positioning = require("positioning")

-- INVENT_CHARGE is charge x 3000. INVENT_COMBAT_CHARGE_DRAIN is drain per game
-- tick in the same units, with perks and research already applied. These
-- match the game's tooltip: charge / 3000, drain / 3000 / 0.6 per second, and
-- time left = charge / drain x 0.6 seconds.

local WORN_ITEM_LAYER = "TOPLEVEL_V2_WORN__ITEM_LAYER"
local WORN_CONTENT_LAYER = "TOPLEVEL_V2_WORN__CONTENT_LAYER"
local SECONDS_PER_TICK = 0.6
local INVENTION_LOW_SECONDS = 30 * 60
local INVENTION_W, INVENTION_H = 130, 18
local INVENTION_STYLES = {
    normal = { font = widgets.NORMAL_FONT, gap = 16 },
    small  = { font = widgets.SMALL_FONT,  gap = 12 },
    xs     = { font = widgets.XS_FONT,     gap = 10 },
}

local inventionLabels = nil

local function hideInvention()
    for _, group in ipairs(inventionLabels or {}) do
        widgets.hideOutlinedText(group)
    end
end

-- "6h 38m", "38m 50s" or "45s"
local function formatDuration(seconds)
    seconds = math.floor(seconds)
    local h = seconds // 3600
    local m = (seconds % 3600) // 60
    local sec = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    elseif m > 0 then
        return string.format("%dm %02ds", m, sec)
    end
    return string.format("%ds", sec)
end

-- 167795 -> "167,795"
local function withCommas(n)
    local text = tostring(math.floor(n))
    local count
    repeat
        text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until count == 0
    return text
end

-- Returns nil when there's nothing to show: drain is 0 when no augmented
-- gear is worn, and the variables may be unreadable after a game update.
local function readInvention()
    local charge = core.readVarPlayer("INVENT_CHARGE")
    local drain = core.readVarPlayer("INVENT_COMBAT_CHARGE_DRAIN")
    if charge == nil or drain == nil or drain <= 0 then
        return nil
    end
    return {
        charge = charge / 3000,
        perSecond = drain / 3000 / SECONDS_PER_TICK,
        secondsLeft = charge / drain * SECONDS_PER_TICK,
    }
end

local function renderInvention()
    if inventionLabels == nil then
        inventionLabels = {}
        for i = 1, #core.INVENTION_LINES do
            inventionLabels[i] = widgets.newOutlinedText(widgets.parentLayer, INVENTION_W, INVENTION_H)
        end
    end
    -- Anchored to the whole worn tab rather than the item grid, which the
    -- game re-centres when the window is resized.
    local info = readInvention()
    local layer = widgets.findComponentByName(WORN_CONTENT_LAYER)
        or widgets.findComponentByName(WORN_ITEM_LAYER)
    if info == nil or layer == nil or not layer.visibleGlobal then
        return
    end

    local texts = {}
    if core.showInventionLine.time then
        texts[#texts + 1] = "Time left " .. formatDuration(info.secondsLeft)
    end
    if core.showInventionLine.charge then
        texts[#texts + 1] = "Charge " .. withCommas(info.charge)
    end
    if core.showInventionLine.drain then
        texts[#texts + 1] = string.format("Drain %.2f/s", info.perSecond)
    end

    local colour = core.colours.invention
    if info.secondsLeft < INVENTION_LOW_SECONDS then
        colour = core.colours.invention_low
    end
    local colourVec = core.toVector4(colour)
    local style = INVENTION_STYLES[core.inventionTextSize]

    for i, text in ipairs(texts) do
        widgets.setOutlinedFont(inventionLabels[i], style.font)
        widgets.setOutlinedContent(inventionLabels[i], text, colourVec)
        positioning.addPlacement(inventionLabels[i], layer, 4, 4 + (i - 1) * style.gap,
            INVENTION_W, INVENTION_H)
    end
end

return {
    hideInvention = hideInvention,
    renderInvention = renderInvention,
}
