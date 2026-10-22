-- Item Charges: positioning.lua
-- Keeps the numbers on item icons and the Invention lines following what
-- they belong to as windows scroll and move, and hides them where the bank
-- window covers them.

local widgets = require("widgets")

-- A full render decides what to show and records a "placement" for each text:
-- the component it follows and its offset from that component. reposition()
-- then moves the texts to follow their components. It's cheap, so it runs
-- 50 times a second to keep up with scrolling and window dragging, while the
-- full render only runs on game ticks and changes.

local placements = {}

local function clearPlacements()
    placements = {}
end

-- objID: the item the component was showing at the last full render, if known.
-- checkQuantity: whether a quantity of 0 (a bank placeholder) hides the number.
-- inBank: true for numbers drawn inside the bank window itself. All others
-- are hidden where the bank window covers them, since the plugin layer is
-- drawn on top of every game interface.
local function addPlacement(group, comp, offX, offY, w, h, clip, objID, checkQuantity, inBank)
    placements[#placements + 1] = {
        group = group, comp = comp, offX = offX, offY = offY, w = w, h = h,
        clip = clip, objID = objID, checkQuantity = checkQuantity, inBank = inBank,
    }
end

-- True if a w x h box at (x, y) lies inside the component's on-screen area.
local function insideComponent(comp, x, y, w, h)
    local pos = comp.xyGlobal
    return x >= pos.x and y >= pos.y
        and x + w <= pos.x + comp.width and y + h <= pos.y + comp.height
end

-- The bank window's on-screen rectangle, or nil if the bank is closed. There's
-- no known component for the whole window, so it's worked out from its item
-- area and backpack panel plus the frame around them (measured from a
-- screenshot): about 16 pixels at the sides, 95 above (title and tabs) and
-- 60 below (search bar).
-- The two components are looked up on each full render (findBankComponents)
-- rather than 50 times a second; reposition() just reads their positions.
local BANK_FRAME = { left = 16, top = 95, right = 16, bottom = 60 }
local bankItems, bankBackpack = nil, nil

local function findBankComponents()
    bankItems = widgets.findComponentByName("BANK__BANK_ITEMS_CONTAINER")
    bankBackpack = widgets.findComponentByName("BANK__INVENTORY_SLOTS")
end

-- A closed bank's components still report visibleGlobal = true, but with a
-- size of 0 at (0, 0) (seen with a probe), so size is checked too.
local function bankPartShown(comp)
    return comp ~= nil and comp.visibleGlobal == true and comp.width > 0 and comp.height > 0
end

local function bankRect()
    local items, backpack = bankItems, bankBackpack
    if not bankPartShown(items) then return nil end
    local right = items.xyGlobal.x + items.width
    if bankPartShown(backpack) then
        right = math.max(right, backpack.xyGlobal.x + backpack.width)
    end
    return {
        x1 = items.xyGlobal.x - BANK_FRAME.left,
        y1 = items.xyGlobal.y - BANK_FRAME.top,
        x2 = right + BANK_FRAME.right,
        y2 = items.xyGlobal.y + items.height + BANK_FRAME.bottom,
    }
end

-- True if a w x h box at (x, y) overlaps the rectangle at all.
local function overlaps(rect, x, y, w, h)
    return x < rect.x2 and x + w > rect.x1 and y < rect.y2 and y + h > rect.y1
end

-- Returns true if an icon now shows a different item (or became a bank
-- placeholder), meaning a full render is needed.
local function reposition()
    local origin = widgets.parentLayer.xyGlobal
    local bank = bankRect()
    for _, p in ipairs(placements) do
        if p.objID ~= nil and (widgets.iconObjectID(p.comp) ~= p.objID
            or (p.checkQuantity and widgets.iconQuantity(p.comp) == 0)) then
            return true
        end
        local x, y, show = nil, nil, p.comp.visibleGlobal
        if show then
            local pos = p.comp.xyGlobal
            x, y = pos.x + p.offX, pos.y + p.offY
            if p.clip ~= nil then
                -- Positions inside a scrolled area don't include the scroll.
                x = x - (p.clip.scrollX or 0)
                y = y - (p.clip.scrollY or 0)
                show = insideComponent(p.clip, x, y, p.w, p.h)
            end
            if show and bank ~= nil and not p.inBank then
                show = not overlaps(bank, x, y, p.w, p.h)
            end
        end
        if not show then
            if p.shown ~= false then
                widgets.hideOutlinedText(p.group)
                p.shown = false
            end
        elseif not p.shown or x ~= p.lastX or y ~= p.lastY then
            widgets.placeOutlinedText(p.group, x - origin.x, y - origin.y)
            p.shown, p.lastX, p.lastY = true, x, y
        end
    end
    return false
end

return {
    addPlacement = addPlacement,
    bankPartShown = bankPartShown,
    clearPlacements = clearPlacements,
    findBankComponents = findBankComponents,
    reposition = reposition,
}
