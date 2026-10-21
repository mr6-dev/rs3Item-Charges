-- Offline tests for the name-parsing logic in main.lua.
-- Runs with plain Lua on your computer (no game needed):
--     lua5.4 test_parse.lua
--
-- Why this exists: the parsing is pure logic (string in, values out), so it
-- can be tested without launching RuneScape. Testing it here means that when
-- something breaks in-game, you know the bug is in the game-facing parts.
--
-- NOTE: this is a copy of parseCharges from main.lua. If you change one,
-- change the other.

local function parseCharges(itemName)
    local baseName, digits = string.match(itemName, "^(.-)%s*%(%a*(%d+)%)$")
    if baseName == nil then
        return nil
    end
    return baseName, tonumber(digits)
end

-- Each test: an input name, and what we expect back.
-- expectedName = nil means "this should NOT be treated as a charged item".
local tests = {
    { input = "Games necklace (8)",     expectedName = "Games necklace",   charges = 8 },
    { input = "Ring of duelling (1)",   expectedName = "Ring of duelling", charges = 1 },
    { input = "Dig Site pendant (5)",   expectedName = "Dig Site pendant", charges = 5 },
    { input = "Amulet of glory (t4)",   expectedName = "Amulet of glory",  charges = 4 },
    { input = "Games necklace(8)",      expectedName = "Games necklace",   charges = 8 },  -- no space
    { input = "Ring of slaying (10)",   expectedName = "Ring of slaying",  charges = 10 }, -- two digits
    { input = "Amulet of glory",        expectedName = nil },  -- uncharged: no number
    { input = "Amulet of glory (c)",    expectedName = nil },  -- compacted: no number
    { input = "Bones",                  expectedName = nil },  -- ordinary item
    { input = "Reaper necklace (or)",   expectedName = nil },  -- letters only
}

local passed, failed = 0, 0

for _, t in ipairs(tests) do
    local name, charges = parseCharges(t.input)

    local ok
    if t.expectedName == nil then
        ok = (name == nil)
    else
        ok = (name == t.expectedName and charges == t.charges)
    end

    if ok then
        passed = passed + 1
        print("PASS  " .. t.input)
    else
        failed = failed + 1
        print("FAIL  " .. t.input .. "  -> got: " .. tostring(name) .. ", " .. tostring(charges))
    end
end

print(string.format("\n%d passed, %d failed", passed, failed))
