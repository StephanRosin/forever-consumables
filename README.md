# Forever Consumables

A small bar for WoW: Forever with one button per consumable category: food, drink, healing, mana, potions,
flasks, elixirs, protection potions, scrolls and bandages. A left click uses the item; the arrow beside a button
(or a right click, if you choose) picks which item of the category it uses, or "Automatic (best)". Empty
categories are hidden. The bar can always be collapsed to a small button, also in combat.

Everything is configurable in the options window (`/fcon`, the minimap button or the addon compartment):
direction, buttons per row, size, spacing, scale, border and background, position and lock, when the bar shows
(always, in or out of combat, only in instances or groups, hidden while dead or on a taxi), opacity in and out
of combat, the count's font and place, which categories show and in which order, profiles with export and
import. English, German, Spanish and French.

## How items are sorted

1. Hand-made ID lists (`Data/Items.lua`): runes, gems, healthstones, Juju, Zanza, Blasted Lands buffs,
   protection and combat potions, flasks, elixirs, scrolls, bandages.
2. The item's use spell, compared by name with reference spells in the client's language
   (Food, Drink, Refreshment, Healing Potion, Restore Mana, First Aid).
3. The item subclass (Forever uses the modern ones: potion 1, elixir 2, flask 3, scroll 4, food and drink 5,
   bandage 7). Any other potion goes to "Potions", so new Forever potions show without a list update.

`/fcon scan` and `/fcon ids` record what the client says about the items in your bags and the listed IDs into
the saved variables (after `/reload`), for checking the lists.

## Development

    tests/run                    # Lua 5.1, as in the game; tests/run <name> runs tests/run_<name>.lua
    ./install "<WoW>/_classic_beta_/Interface/AddOns"
    tools/package                # dist/ForeverConsumables-<version>.zip
    tools/release release "<changelog>"    # CurseForge 1736889; bump ## Version first

Design: `docs/specs/2026-10-10-forever-consumables-design.md`; plan: `docs/plans/2026-10-10-plan-forever-consumables.md`.
