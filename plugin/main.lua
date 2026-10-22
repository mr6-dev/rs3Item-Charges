-- Item Charges
--
-- Shows remaining charges and doses as a small number on item icons in the
-- backpack, worn equipment, bank, beast of burden and action bars, Invention
-- charge info in the worn equipment tab, potion cauldron info in your house,
-- and a potion supplies (restock) list.
--
-- Charges are read from item names: "Games necklace (8)" has 8 charges, and
-- using one swaps it for "Games necklace (7)". Potions work the same way.
--
-- Credits: settings page built with PrettyUI by rsnJ3
-- (https://prettyui.j3.gg/).
--
-- The plugin is split into files by feature. Each starts with a short
-- description:
--   core.lua          saved settings and colours
--   widgets.lua       drawing helpers and the panel window
--   positioning.lua   keeping numbers on their icons as windows move
--   item_numbers.lua  charges and doses on item icons
--   invention.lua     Invention charge in the worn equipment tab
--   display.lua       when to rescan and redraw
--   cauldrons.lua     potion cauldrons in your house
--   supplies.lua      potion supplies (restock) list
--   settings_page.lua the settings page

print("Item Charges loaded.")

-- Loading display.lua starts the item numbers and Invention lines; the other
-- features start when their files load.
require("display")
local cauldrons = require("cauldrons")
local supplies = require("supplies")
local settingsPage = require("settings_page")

function PluginShutdown()
    settingsPage.shutdown()
    cauldrons.shutdown()
    supplies.shutdown()
end