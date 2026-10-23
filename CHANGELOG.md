# Changelog

## 1.3.5

- **Filter your bank to potions.** The potion supplies box beside the bank has a new "Filter bank" button. Each click steps through: all potions, potions to restock, stocked potions, then off. A line under the buttons shows which one is active. The matching potions are packed together at the top of your bank, and everything else (including the tab dividers) is hidden. These are the bank's own slots, so you withdraw as normal. Potions you've run out of (only a placeholder left) count as needing a restock.
- **Click a potion in the supplies list** to show just that potion in your bank. Click it again to show everything.
- The bank goes back to normal when you turn the filter off or close the bank. Your bank's real layout is never changed, only how it's shown.
- **Ring of retribution charges** on its icon, for the plain and overcharged rings (damage left to reflect).
- **Camulet charges** on its icon (teleports left, 0 to 4).
- **Fix:** reloading the plugin while inside your house no longer hides the cauldron icons and panel until you leave and come back.

## 1.3.4

- **Cauldron doses over each cauldron.** A new setting shows each cauldron's doses above it: under the potion icon, or after the cauldron number. It's off by default.

## 1.3.3

- **Potion icons over cauldrons.** Each cauldron in your house shows its potion's own icon above it, drawn by the game, so you can tell them apart at a glance. A setting switches back to showing the cauldron's number instead.
- **Cauldrons number themselves.** A newly built cauldron gets its number the moment it's built, and a cauldron you move keeps its number. If only one cauldron is still unmatched, it's filled in automatically.
- **Action bar potions show your backpack total.** A potion on an action bar shows the total doses of that potion in your backpack, all dose sizes added together.
- **Hidden behind walls.** Icons hide while you're outside the cauldron's building, so they no longer show through walls.
- **Fix:** removing a cauldron no longer leaves its label floating where it stood.

## 1.3.2

- **Cauldron refill warning.** Cauldrons at or below your refill level (default 20 doses) are marked "(refill)" and shown in the refill colour, in the panel and over the cauldron. The level and colour are adjustable.
- **Restock colour.** Potions that need restocking are shown in their own colour in the supplies list.
- **Restore defaults** buttons for each section of the settings page.
- Its own colour for the numbers over cauldrons.
- The cauldron panel is wider, so long lines aren't cut off.
- **Fix:** the supplies panel's "Off" button was cut off on the settings page.
- Code tidy-up: about 115 fewer lines, no change in behaviour.

## 1.3.1

- **Cauldron panel updates live** as you drink, fill or build cauldrons, without leaving the house.
- **The cauldron panel remembers where you moved it**, even after logging out.
- Panel lines are numbered, and each cauldron in your house shows its number above it.

## 1.3.0

- **Potion supplies (restock) list.** The total doses of each potion across your backpack, beast of burden and bank, lowest first, with potions at or below your restock level marked. When you open your bank, a small summary beside it says how many need restocking, with a button for the full list. Your bank totals are remembered, so the list works away from the bank.
- **Spring cleaner charges** on its icon, for every tier (7,501 shows as "7K").
- Numbers the bank window would cover are hidden instead of showing through it.
- **Fix:** a closed bank was sometimes still treated as open.
