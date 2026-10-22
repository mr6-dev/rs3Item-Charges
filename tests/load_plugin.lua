-- Loads the plugin the way the game does: plugin/main.lua, which requires the
-- other files in plugin/. Clears Lua's module cache first, so a test can load
-- a fresh copy. Run the tests from the repository's top folder.
package.path = "plugin/?.lua;" .. package.path
for _, name in ipairs({ "core", "widgets", "positioning", "item_numbers", "invention",
    "display", "cauldrons", "supplies", "settings_page" }) do
    package.loaded[name] = nil
end
dofile("plugin/main.lua")