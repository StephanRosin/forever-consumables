# Forever Consumables — Design (1.0)

Date: 2026-10-10 · Status: approved in conversation, spec to be reviewed.
In short: **a small movable bar with one button per consumable category; the arrow beside a button picks the item,
a left click uses it; everything about the bar is configurable, and it can always be collapsed to a small button.**

## 1. Facts and limits

- WoW: Forever is a modern client (Interface 16001) with Classic content. Addons live in
  `_classic_beta_/Interface/AddOns`. Same toolchain as the other Forever addons (tests with Lua 5.1 mocks,
  `tools/package`, `tools/release`, CurseForge, a Vault page).
- Using an item needs a secure action button (`type = "item"`). Its attributes, size, position and visibility can
  change only out of combat — except through secure handlers and state drivers (`RegisterStateDriver`,
  `SecureHandlerClickTemplate`), which run in combat.
- Many Classic consumables have the item subclass "Consumable" (0) rather than Potion/Elixir/Flask/Food. The
  subclass alone cannot sort them; the item's use spell and a curated ID list do the rest. To be confirmed in the
  client with `C_Item.GetItemInfoInstant` and `C_Item.GetItemSpell` before the classifier is written.
- Settings live in SavedVariables, as in the other Forever addons.

## 2. Decisions

1. **Own addon**, "Forever Consumables", own repo (`~/Dokumente/ForeverConsumables`), own CurseForge project.
   Options window in the style of Forever Unit Frames (its `Options/Style.lua` and `Widgets.lua`, as Forever Square
   Minimap and Forever Progress Bars use them).
2. **Bar**: one button per enabled category, showing the chosen item's icon and count (stack total over all bags).
   - Left click uses the item (secure `type = "item"`, `item = "item:<id>"`).
   - A small arrow beside the icon opens the category's pick list (Blizzard's menu system): every item of that
     category in the bags with its count, plus "Automatic (best)" at the top, checked when active. Choosing sets the
     button. Out of combat only: in combat the arrow is greyed and does nothing.
   - Option: open the list with a right click instead of the arrow (the arrow then is hidden).
   - Tooltip: the item's tooltip, below it "Left-click: use", "Arrow: choose" (switchable).
3. **Categories** (1.0, ten; weapon buffs and explosives come later):

   | Category | Contents |
   |---|---|
   | Food | food and buff food |
   | Drink | water and drinks, conjured water |
   | Healing | healing potions, healthstones, Whipper Root Tuber |
   | Mana | mana potions, mana gems, Night Dragon's Breath, Dark Rune, Demonic Rune |
   | Flasks | flasks |
   | Elixirs | elixirs, Juju, Zanza, the Blasted Lands buffs (R.O.I.D.S., Ground Scorpok Assay, …) |
   | Potions | combat and utility potions: Rage, Great and Mighty Rage; Forever's Frenzy (attack power), Spellblasting (spell damage) and Mender's (healing) potions in all ranks; Beast Culling, Elemental Siphoning; Swiftness, Invisibility, Lesser Invisibility, Limited Invulnerability, Magic Resistance; Dragonfire, Caustic Smog, Disorienting Smog; Thistle Tea |
   | Protection | protection potions (fire, shadow, nature, frost, arcane, holy), Free Action, Restorative, Living Action |
   | Scrolls | scrolls |
   | Bandages | bandages |

   - Order of classification: a curated ID list first (Data/Items.lua: Felwood, Juju, Zanza, runes, gems,
     healthstones, Blasted Lands, protection potions, the named combat potions), then the use spell (Food / Drink /
     Refreshment — the latter in both Food and Drink), then the subclass (Elixir, Flask, Scroll, Bandage), then
     potions by their use spell's effect (restores health → Healing, restores mana → Mana, both → both; Forever's
     Discolored, Perishable and Restored healing potions and Tessa's Tonic included). Any other potion goes to
     **Potions**, so new Forever potions show without a list update. Anything left over is not shown.
   - Forever adds items Classic Era lacks (beta data, fan databases, 2026-10): Frenzy, Spellblasting and Mender's
     potions, slayer potions, smog potions, Dragonfire Potion, Discolored/Perishable/Restored healing potions,
     Tessa's Tonic, and zone flasks (Natural Swiftness/Accuracy/Aggression/Precision: +60 Stamina, bonus only in
     Hyjal and the Barrow Deeps) — those go to Flasks. There is no haste potion as in TBC. The ID list is checked
     against the client before release.
   - Thrown potions (Caustic Smog, Disorienting Smog) use the item like the bag does: the client then asks for
     the ground target.
   - Each category can be switched on or off and moved in the order (Options > Categories).
   - **Empty categories** are hidden (switchable). Hiding and showing happen out of combat only; a button that runs
     empty in combat stays, greyed, until combat ends.
4. **Automatic (best)** — the default of every category:
   - Usable now (level requirement met), highest required level first, then the higher item level.
   - Conjured items first (they vanish otherwise).
   - Buff food is never chosen automatically, only by hand.
   - A chosen item that runs out falls back to automatic; the choice is kept and returns when the item is back in
     the bags.
5. **Cooldown** on each button (`CooldownFrameTemplate`, from `C_Container.GetItemCooldown`), so the shared potion
   cooldown shows on Healing, Mana and Protection alike.
6. **Collapse**: a small collapse button is always part of the bar (not optional).
   - A click collapses the bar to just this button and opens it again; also in combat (secure click handler).
   - Its place (one of the bar's ends) and its look follow the bar's orientation; the collapsed state is saved per
     character.
   - It follows the visibility rule: when the rule hides the bar, the collapse button hides too.
7. **Visibility** — all configurable, driven by a state driver (works in combat):
   - Mode: always / in combat only / out of combat only / never (bar off).
   - Extra conditions, each switchable: only in instances (dungeon or raid), only in a group, hide while dead or a
     ghost, hide in a vehicle or on a taxi.
   - Opacity: one value in combat, one out of combat; optionally fade in on mouse over.
8. **Layout options** (Options > Bar): orientation (horizontal/vertical), buttons per row, button size, spacing,
   scale, border (show, size, colour), background (show, colour), position x/y, anchor point, lock/unlock (unlocked:
   drag by a handle; the position boxes follow).
9. **Display options** (Options > Display): count — font, size, outline, colour, point and offset; arrow — beside
   (right) or below, or right click instead; tooltip on/off; grey count at zero.
10. **Storage**: layout and look in an account-wide profile (export, import, reset; as in FUF); the chosen items and
    the collapsed state per character.
11. **Minimap button and addon compartment**: open the options; shown by default, switchable.
12. **Languages**: German, English, Spanish, French; same keys in all four (tested).

## 3. Not in 1.0

- Weapon buffs (whetstones, oils, poisons) with left/right hand and time left.
- Explosives (grenades, dynamite, sapper charges).
- Glow when a flask/elixir/food buff is missing.
- Key bindings per category.
- Low-stock warning.

## 4. Tests

Classification (ID list, Food/Drink/Refreshment, subclasses, potions by effect, any other potion to Potions, leftover items not shown); automatic choice (level,
item level, conjured first, buff food never automatic, fallback and return of a chosen item); count over several
bags; empty categories hidden out of combat, kept greyed in combat; arrow and menu disabled in combat; collapse and
reopen, also in combat, saved per character; the visibility driver's string for every mode and condition; layout
(orientation, rows, size, spacing) and the options window's keys; profile export/import; all four languages.
