-- Item Charges: widgets.lua
-- Drawing helpers shared by the other files: outlined text on the plugin
-- layer, fonts, reading which item an icon shows, and ListWindow (the
-- PrettyUI window used by the cauldron and potion supplies panels).

local core = require("core")

-- All text is drawn on the plugin layer rather than inside game interfaces,
-- which the game rebuilds when items move.
local parentLayer = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
if parentLayer == nil then
    print("Item Charges: could not find the plugin UI layer. Display disabled.")
end

local function findComponentByName(componentName)
    local ok, comp = pcall(function()
        return ui.Interfaces:GetComponent(id.Component[componentName])
    end)
    if ok then return comp end
    return nil
end

-- Fonts. Unknown names in id.Font still return a value, so a name is only
-- treated as real if it differs from a name that can't exist.
local NORMAL_FONT = id.Font.MUSEO_SANS_15PT_REGULAR

local function fontByName(name)
    local ok, font = pcall(function() return id.Font[name] end)
    if ok then return font end
    return nil
end

local FAKE_FONT = fontByName("ITEM_CHARGES_NOT_A_REAL_FONT")

local function looksReal(font)
    return font ~= nil and font ~= FAKE_FONT and type(font) == type(NORMAL_FONT)
end

local function firstRealFont(names)
    for _, name in ipairs(names) do
        local font = fontByName(name)
        if looksReal(font) then
            return font
        end
    end
    return nil
end

-- "MUSEO_SANS_8PT_REGULAR" -> 8, "NOTOSANS_BOLD_12" -> 12
local function fontSize(name)
    return tonumber(name:match("_(%d+)PT") or name:match("_(%d+)$"))
end

-- Picks the real font closest to 8pt (7 to 10) from the client's font list,
-- preferring Museo Sans. Returns nil if the list can't be read.
local function closestFontTo8pt()
    local ok, names = pcall(function()
        local found = {}
        for name in pairs(id.Font) do found[#found + 1] = tostring(name) end
        return found
    end)
    if not ok then return nil end
    local best, bestName, bestScore = nil, nil, nil
    for _, name in ipairs(names) do
        local size = fontSize(name)
        if size ~= nil and size >= 7 and size <= 10 and looksReal(fontByName(name)) then
            local score = math.abs(size - 8) * 10
            if not name:find("MUSEO") then score = score + 5 end
            if bestScore == nil or score < bestScore
                or (score == bestScore and name < bestName) then
                best, bestName, bestScore = fontByName(name), name, score
            end
        end
    end
    return best
end

local SMALL_FONT = firstRealFont({
    "MUSEO_SANS_12PT_REGULAR", "MUSEO_SANS_13PT_REGULAR",
    "MUSEO_SANS_11PT_REGULAR", "NOTOSANS_BOLD_12",
}) or NORMAL_FONT

local XS_FONT = closestFontTo8pt() or firstRealFont({
    "MUSEO_SANS_8PT_REGULAR", "MUSEO_SANS_9PT_REGULAR", "MUSEO_SANS_10PT_REGULAR",
    "NOTOSANS_REGULAR_8", "NOTOSANS_BOLD_8", "NOTOSANS_REGULAR_9", "NOTOSANS_BOLD_9",
    "NOTOSANS_REGULAR_10", "NOTOSANS_BOLD_10",
}) or SMALL_FONT

local function newText(parent, w, h)
    local t = ui.Text.new(parent)
    t.font = NORMAL_FONT
    t:AlignTo(ui.AlignMode.CENTRE)
    t.clickthrough = true
    t:SetSize(w, h)
    return t
end

-- Text has no outline option, so an outline is drawn as 8 copies offset by
-- 1 unit in each direction, with the main text created last so it's on top.
-- Note: calling MoveToFront() on these texts makes them invisible.
local OUTLINE_OFFSETS = {
    { -1, -1 }, { 0, -1 }, { 1, -1 },
    { -1,  0 },            { 1,  0 },
    { -1,  1 }, { 0,  1 }, { 1,  1 },
}

local function newOutlinedText(parent, w, h)
    local group = { outlines = {} }
    for i = 1, #OUTLINE_OFFSETS do
        local t = newText(parent, w, h)
        t.hidden = true
        group.outlines[i] = t
    end
    group.main = newText(parent, w, h)
    return group
end

local function setOutlinedContent(group, content, colourVec)
    group.main.content = content
    group.main.colour = colourVec
    group.main.isShadowed = not core.outlineEnabled
    local outlineVec = core.toVector4(core.colours.outline)
    for _, t in ipairs(group.outlines) do
        t.content = content
        t.colour = outlineVec
    end
end

local function placeOutlinedText(group, x, y)
    group.main:SetPos(x, y)
    group.main.hidden = false
    for i, offset in ipairs(OUTLINE_OFFSETS) do
        local t = group.outlines[i]
        t:SetPos(x + offset[1], y + offset[2])
        t.hidden = not core.outlineEnabled
    end
end

local function hideOutlinedText(group)
    group.main.hidden = true
    for _, t in ipairs(group.outlines) do
        t.hidden = true
    end
end

local function setOutlinedFont(group, font)
    group.main.font = font
    for _, t in ipairs(group.outlines) do
        t.font = font
    end
end

-- Item icons report the item they're drawing. The client updates this as soon
-- as an item is moved, before the server confirms the move and the inventory
-- data catches up. Returns nil for icons that don't report one.
local function iconObjectID(icon)
    local ok, objID = pcall(function() return icon.associatedObjectID end)
    if ok and type(objID) == "number" then return objID end
    return nil
end

local function iconQuantity(icon)
    local ok, quantity = pcall(function() return icon.associatedObjectQuantity end)
    if ok and type(quantity) == "number" then return quantity end
    return nil
end

-------------------------------------------------------------------------------
-- List windows (built with PrettyUI)
-------------------------------------------------------------------------------
-- A window showing one line of text per row, used by the cauldron and potion
-- supplies panels. It's sized to its lines (up to maxLines, then it scrolls)
-- and rebuilt when the number of lines changes.

local ListWindow = { PADDING = 52, LINE_HEIGHT = 28 }
ListWindow.__index = ListWindow

-- saveKey names the settings ("<saveKey>_x", "_y") that remember where the
-- window was last dragged to, so it reopens there even after a logout.
-- moved is true once it has a saved position.
function ListWindow.new(title, width, x, y, maxLines, saveKey)
    local savedX = core.loadSetting(saveKey .. "_x", core.isCoord, nil)
    local savedY = core.loadSetting(saveKey .. "_y", core.isCoord, nil)
    local moved = savedX ~= nil and savedY ~= nil
    return setmetatable({ title = title, width = width,
        x = moved and savedX or x, y = moved and savedY or y, saveKey = saveKey, moved = moved,
        maxLines = maxLines or math.huge, rows = {}, open = false }, ListWindow)
end

function ListWindow:build(lineCount)
    -- Destroying the old window may run its onClose, so keep the open state.
    local wasOpen = self.open
    self:destroy()
    self.window = prettyui.Window.new(parentLayer, {
        title = self.title, x = self.x, y = self.y, width = self.width,
        height = ListWindow.PADDING + math.min(lineCount, self.maxLines) * ListWindow.LINE_HEIGHT,
        onClose = function() self.open = false end,
    })
    self.open = wasOpen
    -- PrettyUI's own text colour, so a coloured line can be put back. White
    -- if it can't be read.
    self.rows, self.defaultColour, self.offset = {}, Vector4.new(1, 1, 1, 1), nil
    for i = 1, lineCount do
        self.rows[i] = self.window:AddText("")
    end
    pcall(function() self.defaultColour = self.rows[1].colour or self.defaultColour end)
end

-- lineColours is optional: a colour per line, or nil for PrettyUI's own colour.
function ListWindow:setLines(lines, lineColours)
    if self.window == nil then return end
    if #lines ~= #self.rows then
        self:build(#lines)
        if self.open then self.window:Show() end
    end
    for i, line in ipairs(lines) do
        self.rows[i].content = line
        local colour = lineColours and lineColours[i] or self.defaultColour
        if colour ~= nil then self.rows[i].colour = colour end
    end
end

function ListWindow:show(lines, lineColours)
    if parentLayer == nil or prettyui == nil then return end
    if self.window == nil then self:build(#lines) end
    self.open = true
    self:setLines(lines, lineColours)
    self.window:Show()
end

function ListWindow:close()
    if self.window ~= nil and self.open then
        pcall(function() self.window:Close() end)
    end
    self.open = false
end

function ListWindow:destroy()
    if self.window ~= nil then
        pcall(function() self.window:Destroy() end)
    end
    self.window = nil
end

-- PrettyUI can't report where a window has been dragged, so the position is
-- worked out from the window's viewport component: its screen position now,
-- minus how far it sat from the window's x, y when it was first shown.
-- Returns true when the window has moved.
function ListWindow:trackPosition()
    local p = self.window.viewport.xyGlobal
    if self.offset == nil then
        self.offset = { x = p.x - self.x, y = p.y - self.y }
        return false
    end
    local x = math.max(0, math.floor(p.x - self.offset.x))
    local y = math.max(0, math.floor(p.y - self.offset.y))
    if x == self.x and y == self.y then return false end
    self.x, self.y = x, y
    return true
end

-- Called every game tick while the window is open.
function ListWindow:savePosition()
    if self.window == nil or not self.open or not self:trackPosition() then return end
    self.moved = true
    core.saveSetting(self.saveKey .. "_x", self.x)
    core.saveSetting(self.saveKey .. "_y", self.y)
end

return {
    ListWindow = ListWindow,
    NORMAL_FONT = NORMAL_FONT,
    SMALL_FONT = SMALL_FONT,
    XS_FONT = XS_FONT,
    findComponentByName = findComponentByName,
    hideOutlinedText = hideOutlinedText,
    iconObjectID = iconObjectID,
    iconQuantity = iconQuantity,
    newOutlinedText = newOutlinedText,
    parentLayer = parentLayer,
    placeOutlinedText = placeOutlinedText,
    setOutlinedContent = setOutlinedContent,
    setOutlinedFont = setOutlinedFont,
}
