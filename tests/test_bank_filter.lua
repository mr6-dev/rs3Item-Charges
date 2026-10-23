-- Offline test for filtering the bank (bank_filter.lua).  Run:  lua tests/test_bank_filter.lua  (from the main folder)
package.path = "plugin/?.lua;" .. package.path
-- Stubs: 30 slots in 10 columns of 44x40 (slot size 40x36); slot 0 far down.
local function comp(dyn, x, y)
  local c = { interfaceID = 517, staticID = 1, dynamicID = dyn, width = 40, height = 36, xyLocal = { x = x, y = y } }
  function c:SetPos(nx, ny) self.xyLocal = { x = nx, y = ny } end
  return c
end
local container = { interfaceID = 517, staticID = 9, dynamicID = -1 }
local divider = { interfaceID = 517, staticID = 200, dynamicID = -1 }
local inv = { interfaceID = 517, staticID = 1, dynamicID = -1, width = 449, parent = container, slots = {} }
for i = 0, 29 do inv.slots[#inv.slots + 1] = comp(i, (i % 10) * 44, 400 - (i // 10) * 40) end
-- Two empty slots at odd positions, like the real bank's.
inv.slots[#inv.slots + 1] = comp(30, 2, 0)
inv.slots[#inv.slots + 1] = comp(31, 3, 0)
function inv:IterateDynamicComponents(f) for _, c in ipairs(self.slots) do if f(c) then return end end end
function container:IterateStaticComponents(f) f(inv); f(divider) end
function container:IterateDynamicComponents(f) end
function inv:IterateStaticComponents(f) end
-- Items: even slots are "Super restore (4)", slot 3 is "Overload (2)", rest a ring.
local items = {}
for i, c in ipairs(inv.slots) do c.associatedObjectID = (c.dynamicID % 2 == 0) and 1 or (c.dynamicID == 3 and 2 or 3) end
inv.slots[31].associatedObjectID, inv.slots[32].associatedObjectID = -1, -1
config = { Obj = { FromID = function(id) return ({ { name = "Super restore (4)", interfaceOpNames = { "Drink" } },
  { name = "Overload (2)", interfaceOpNames = { "Drink" } }, { name = "Ring of duelling (5)", interfaceOpNames = { "Rub" } } })[id] end } }
package.loaded.widgets = {
  findComponentByName = function(n) return n == "BANK__BANK_INV" and inv or container end,
  iconObjectID = function(c) return c.associatedObjectID end,
}
package.loaded.item_numbers = {
  parseCharges = function(n) local b, d = n:match("^(.-)%s*%((%d+)%)$") return b, tonumber(d) end,
  isPotion = function(obj) for _, o in ipairs(obj.interfaceOpNames) do if o == "Drink" then return true end end return false end,
}
local bf = require("bank_filter")
local function check(cond, msg) print((cond and "ok   " or "FAIL ") .. msg) if not cond then failed = true end end

bf.set(function() return true end)
local shown = {}
for _, c in ipairs(inv.slots) do if not c.hidden then shown[#shown + 1] = c end end
check(#shown == 16, "all potions: 16 shown (15 restores + 1 overload), got " .. #shown)
check(shown[1].xyLocal.x == 0 and shown[1].xyLocal.y == 0, "first packed at top-left 0,0")
check(shown[2].xyLocal.x == 44, "second one slot (44 px) to the right, got " .. shown[2].xyLocal.x)
check(shown[11].xyLocal.x == 0 and shown[11].xyLocal.y == 40, "11th wraps to row 2")
check(divider.hidden == true, "divider hidden")
check(bf.active(), "active")

bf.set(function(n) return n == "Overload" end)
shown = {}
for _, c in ipairs(inv.slots) do if not c.hidden then shown[#shown + 1] = c end end
check(#shown == 1 and shown[1].dynamicID == 3 and shown[1].xyLocal.x == 0 and shown[1].xyLocal.y == 0, "Overload only, at top-left")

bf.set(nil)
local back = true
for _, c in ipairs(inv.slots) do
  if c.dynamicID < 30 and (c.hidden or c.xyLocal.x ~= (c.dynamicID % 10) * 44 or c.xyLocal.y ~= 400 - (c.dynamicID // 10) * 40) then back = false end
end
check(back and divider.hidden == false and not bf.active(), "off: everything back in place")

-- Game re-lays out while filtered: tick rebuilds from new positions.
bf.set(function() return true end)
for _, c in ipairs(inv.slots) do c:SetPos((c.dynamicID % 10) * 44 + 1000, (c.dynamicID // 10) * 40) end
bf.tick()
local first
for _, c in ipairs(inv.slots) do if not c.hidden then first = first or c end end
check(first.xyLocal.x == 1000 and first.xyLocal.y == 0, "after relayout, packs from the new top-left")
if failed then error("tests failed") end

-- Closing the bank while filtered shows the dividers again (they outlast it).
bf.set(nil)
bf.set(function() return true end)
check(divider.hidden == true, "divider hidden while filtered")
bf.bankClosed()
check(divider.hidden == false and not bf.active(), "bank closed while filtered: divider shown again")

-- A relayout while filtered doesn't forget the hidden divider.
bf.set(function() return true end)
for _, c in ipairs(inv.slots) do c:SetPos(c.xyLocal.x + 500, c.xyLocal.y) end
bf.tick()
bf.set(nil)
check(divider.hidden == false, "relayout then off: divider shown again")
if failed then error("tests failed") end
