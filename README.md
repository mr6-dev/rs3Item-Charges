# Item Charges

Shows how many charges or doses an item has left, as a small number on the
item's icon in your backpack, worn equipment, bank, beast of burden and action
bars. Also shows your Invention charge, and lists your house's potion
cauldrons.

## What it tracks

- **Potions, flasks, brews and mixes**: every drinkable item with doses,
  including new ones added to the game later.
- **Charged jewellery**: games necklace, amulet of glory, ring of duelling,
  skills necklace, combat bracelet, Dig Site pendant, ring of slaying,
  ferocious ring, ring of wealth, Kethsi ring, Forinthry bracelet and Castle
  wars brace.

- **Invention charge**: shown in the top-left corner of the worn equipment
  tab: combat time left, current charge and drain rate (for example
  "Time left 6h 38m", "Charge 167,795", "Drain 7.01/s"). These match the
  game's own tooltip, so perks and research are already included. They turn
  the low charge colour under 30 minutes, and hide when you aren't wearing
  augmented gear.

Items that are running low show their number in a separate "low charge"
colour. What counts as low is set separately for potions and jewellery (1 to 5).

- **Potion cauldrons**: when you enter your house, a panel lists each potion
  cauldron, its potion and the doses left.

## Where numbers appear

- **Backpack and worn equipment**
- **Bank**: numbers follow items as you scroll, switch tabs or rearrange them.
  Placeholders don't get a number. While banking, backpack items show numbers
  in the bank's backpack panel.
- **Beast of burden**: the familiar tab, the bank's familiar panel and the
  familiar storage window.
- **Action bars**: items on an action bar show the same number as in your
  backpack.

Numbers move with their items straight away when you drag them.

## Settings

Open the settings with the cog icon next to Item Charges in the Plugin Hub's
Manage tab.

- **Charge number colour**: the colour of the numbers.
- **Low charge colour**: the colour used when an item is at or below its low threshold.
- **Outline the numbers**: adds an outline so numbers stand out on busy icons.
- **Outline colour**: the colour of that outline.
- **Show numbers in the bank** / **Show numbers on action bars**: turn these
  off for a cleaner bank or action bar.
- **Invention charge**: turn the time left, current charge and drain rate
  lines on or off individually.
- **Invention text size**: Normal, Small or XS, if the lines feel too big.
- **Low charge thresholds**: separate sliders for potions and jewellery, 1 to 5.
- **Invention text colour** / **Invention colour under 30 minutes**: separate
  from the item number colours.
- **Potion cauldron panel**: when you enter your house, or off. "Show cauldron
  panel now" opens it anywhere.

Changes apply straight away and are saved for next time.

## Limitations

Some items store their charges in a way plugins can't currently read (for
example, the ring of recoil, whose charges are tracked on your character, or
the Botanist's amulet, which keeps a count on each amulet). These don't show
a number.

## Credits

The settings page is built with **PrettyUI** by rsnJ3
(https://prettyui.j3.gg/).
