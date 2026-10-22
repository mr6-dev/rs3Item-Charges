-- Loads the plugin the way the game does: main.lua, which requires the other
-- files. Clears Lua's module cache first, so a test can load a fresh copy.
for _, name in ipairs({ "core", "widgets", "positioning", "item_numbers", "invention",
    "display", "cauldrons", "supplies", "settings_page" }) do
    package.loaded[name] = nil
end
dofile("main.lua")