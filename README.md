# Item Charges

A RuneScape 3 plugin that shows how many charges or doses an item has left, as
a small number on the item's icon. It also shows your Invention charge, your
house's potion cauldrons and a potion restock list.

## What it shows

- **Potions, flasks, brews and mixes**: every drinkable item with doses,
  including new ones added to the game later.
- **Charged jewellery**: games necklace, amulet of glory, ring of duelling,
  skills necklace, combat bracelet, Dig Site pendant, ring of slaying,
  ferocious ring, ring of wealth, Kethsi ring, Forinthry bracelet and Castle
  wars brace.
- **Ring of retribution**: the damage it has left to reflect, for the plain
  and overcharged rings.
- **Camulet**: teleports left (0 to 4).
- **Spring cleaner**: its stored charges, shortened to thousands (7,501 shows
  as "7K").
- **Invention charge**: in the top-left corner of the worn equipment tab, the
  combat time left, current charge and drain rate (for example "Time left
  6h 38m"). These match the game's own tooltip. They change colour under 30
  minutes and hide when you aren't wearing augmented gear.
- **Potion cauldrons**: when you enter your house, a panel lists each potion
  cauldron by number with its potion and doses, updating as you drink or fill
  them. Each cauldron shows its potion's icon above it (or its number). New
  cauldrons are numbered as you build them and moved ones keep their number;
  cauldrons you already had show "?" until you use each one once. Icons hide
  while you're outside the cauldron's building.
- **Potion supplies**: a restock list of the total doses of each potion in
  your backpack, beast of burden and bank (remembered from your last bank
  visit), lowest first. When you open your bank, a small summary beside it
  says how many potions need restocking, with a button for the full list.
- **Bank filter**: the summary's "Filter bank" button steps through showing
  only all potions, potions to restock or stocked potions, packed at the top
  of your bank. Clicking a potion in the supplies list shows just that
  potion. The bank goes back to normal when you turn the filter off or close
  the bank.

Items that are running low show their number in a separate "low charge"
colour. The panels remember where you last moved them.

## Where numbers appear

- **Backpack and worn equipment**
- **Bank**: numbers follow items as you scroll, switch tabs or rearrange them.
  Placeholders don't get a number.
- **Beast of burden**: the familiar tab, the bank's familiar panel and the
  familiar storage window.
- **Action bars**: a potion shows the total doses of that potion in your
  backpack, all dose sizes added together; jewellery shows its charges.

## Settings

Open the settings with the cog next to Item Charges in the Plugin Hub's
Manage tab. Changes apply straight away and are saved for next time.

- **Item numbers**: outline, show in the bank, show on action bars, low charge
  thresholds for potions and jewellery (1 to 5), and the number, low and
  outline colours.
- **Invention charge**: which lines to show, text size (Normal, Small or XS)
  and colours.
- **Potion cauldrons**: show the panel when you enter your house or not, icon
  or number over each cauldron, whether to show its doses too, the refill level (default 20 doses) and the
  number and refill colours.
- **Potion supplies**: show the summary beside your bank or not, the restock
  level (default 50 doses) and the restock colour.
- Each section has a **Restore defaults** button.

## Limitations

Items that keep their charges on the individual item, such as the ring of
recoil, the Botanist's amulet or the "Item Charge" percentage on degrading
gear, can't be read by plugins yet, so they don't show a number.

## Repository layout

- `plugin/`: the plugin itself. These are the only files that go in the
  mod.io zip, all at the top level of the zip. `main.lua` lists what each
  of the other files does.
- `modio/`: the mod.io listing text (`description.md` and `summary.txt`).
- `tests/`: offline tests that run the plugin against a fake game API.
- `CHANGELOG.md`: what changed in each version.

## Running the tests

With Lua 5.4 installed, from this folder:

```
lua tests/test_cauldron.lua
```

Each test file prints its checks and a "passed, failed" total.

## Credits

The settings page and panels are built with **PrettyUI** by rsnJ3
(https://prettyui.j3.gg/).
