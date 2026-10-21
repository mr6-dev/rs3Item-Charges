Item Charges shows how many charges or doses your items have left, as a small number on each item's icon in your backpack, worn equipment, bank, beast of burden and action bars. It also shows how much Invention charge you have left, lists what's in your player-owned house's potion cauldrons, and keeps a restock list of your potions.

## What it shows

**Potions, flasks, brews and mixes**
Every drinkable item with doses gets a number, including potions added to the game in future updates.

**Charged jewellery**
Games necklace, amulet of glory, ring of duelling, skills necklace, combat bracelet, Dig Site pendant, ring of slaying, ferocious ring, ring of wealth, Kethsi ring, Forinthry bracelet and Castle wars brace.

**Spring cleaner**
Every tier of the Spring cleaner shows its stored charges, shortened to thousands so it fits on the icon (7,501 shows as "7K").

Items that are running low show their number in a separate "low charge" colour. You choose what counts as low, separately for potions and jewellery (1 to 5 doses or charges).

## Where numbers appear

- **Backpack and worn equipment**
- **Bank**: numbers follow your items as you scroll, switch tabs or rearrange them. Placeholders don't get a number. While the bank is open, your backpack items show numbers in the bank's backpack panel.
- **Beast of burden**: in your familiar's tab, the bank's familiar panel and the familiar storage window.
- **Action bars**: a potion on an action bar shows the total doses of that potion in your backpack, all dose sizes added together. Jewellery shows the same number as in your backpack.

Numbers move with their items straight away when you drag them to a new slot. While the bank is open, numbers that the bank window would cover are hidden so they don't show through it.

**Invention charge**
In the top-left corner of the worn equipment tab:

- **Time left**: how much combat time your charge will last at your current drain rate (for example "6h 38m")
- **Charge**: your current stored charge (for example "167,795")
- **Drain**: your current drain rate per second (for example "7.01/s")

These match the numbers in the game's own Invention charge tooltip, so your perks and research are already included. The lines change colour when under 30 minutes is left, and they hide when you aren't wearing augmented gear. They have their own colours, separate from the item numbers.

**Potion cauldrons**
When you enter your player-owned house, a small panel lists each potion cauldron you've built by number, the potion in it and the doses left (for example "3. Elder overload salve: 15 doses"). It updates as you drink or fill a cauldron, remembers where you last moved it, and you can close it or turn it off. Each cauldron in your house also shows its potion's icon above it (or its number, if you prefer), so you can tell which is which. The icons hide while you're outside the cauldron's building, so they don't show through walls. New cauldrons are numbered as you build them, and moved cauldrons keep their number. Cauldrons you already had when you install the plugin show "?" until you drink from or fill each one once.

**Potion supplies**
When you open your bank, a small panel beside it tells you how many potions need restocking. Its "Show list" button opens the full list: the total doses of each potion across your backpack, beast of burden and bank, lowest first, with anything at or below your restock level marked in the restock colour. Your bank's potion totals are remembered from your last visit, so the list also works away from the bank. Drag the summary or the list anywhere and they open there from then on, even after logging out.

## Settings

Open the settings with the cog icon next to Item Charges in the Plugin Hub's Manage tab. Changes apply straight away and are saved for next time.

- **Outline the numbers**: adds an outline so numbers stand out on busy icons.
- **Show numbers in the bank** and **Show numbers on action bars**: turn these off if you prefer a cleaner bank or action bar.
- **Low charge thresholds**: when potions (1 to 5 doses) and jewellery (1 to 5 charges) count as low.
- **Charge number colour**, **Low charge colour** and **Outline colour**.
- **Invention charge**: turn the time left, charge and drain lines on or off individually.
- **Invention text size**: Normal, Small or XS.
- **Invention text colour** and **Invention colour under 30 minutes**.
- **Potion cauldron panel**: show it when you enter your house, or turn it off. "Show cauldron panel now" opens it anywhere.
- **Cauldron refill level and colour**: cauldrons at or below this many doses (default 20) are marked "(refill)" in the panel, and their line and number use the refill colour. The numbers over cauldrons that don't need a refill have their own colour too.
- **Over each cauldron**: the potion's icon, or the cauldron's number.
- **Potion supplies panel**: show it beside your bank, or turn it off. Set the restock level (0 to 500 doses) and the restock colour. "Show potion supplies" opens the list anywhere.
- **Restore defaults**: each section has a button that puts its settings back to how they started.

## Limitations

Only items that show their charges in their name, or whose charges the game makes available to plugins (such as the Spring cleaner), are supported. Items that keep their charges on the individual item, such as the ring of recoil, the Botanist's amulet or the "Item Charge" percentage on degrading gear, don't show a number.

## Credits

The settings page is built with PrettyUI by rsnJ3 (https://prettyui.j3.gg/). PrettyUI is a required dependency and is installed automatically.

## Email

The contact email address for this plugin is opwanderer10@gmail.com.

## EULA

By submitting this Plugin (as defined in Schedule 4 of the EULA), I acknowledge that I agree to the terms of the Jagex End User License Agreement (EULA) found at https://legal.jagex.com/docs/terms/eula. These terms are incorporated by reference and are legally binding. If you do not agree to the terms of the EULA, you must not submit a Plugin or use the Plugin functionality, and Jagex does not license the software or grant the related rights to anyone who does not agree.

## Permissions

This plugin does not request any permissions.

## Data Protection (case 1)

This plugin uses the following information: the names and right-click options of items in your backpack, worn equipment, bank and beast of burden, which items are shown on your action bars, the on-screen positions of those interfaces, your Invention charge and drain rate, your Spring cleaner's stored charges, the contents of your potion cauldrons, where the cauldrons stand in your house and your own position (to number them), whether the roof above a cauldron is showing (to hide its icon behind walls), and the scenery that loads when you change area (to recognise your house).

This information is not transmitted outside of the plugin under any circumstances.

Plugin settings are stored between sessions. The only game information stored between sessions is the total doses of each potion in your bank (for the potion supplies list), which cauldron number belongs to which spot in your house, and where you last moved the cauldron panel and the potion supplies windows. These are kept on your computer by the game's plugin storage.
