-- Which category an item belongs to.
local M = dofile("mock.lua")
print("Classification")
-- Reference spells in the client's language.
M.spells = { [433] = "Food", [430] = "Drink", [167152] = "Refreshment", [441] = "Healing Potion",
    [437] = "Restore Mana", [746] = "First Aid", [19705] = "Well Fed" }
M.items = {
    [4599] = { name = "Cured Ham Steak", spell = "Food", spellID = 1131 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", spellID = 1137 },
    [90001] = { name = "Mage Biscuit", spell = "Refreshment", spellID = 900 },
    [13446] = { name = "Major Healing Potion", subclassID = 1, spell = "Healing Potion" },
    [90002] = { name = "Unknown Healing Draught", spell = "Healing Potion" },
    [90003] = { name = "Unknown Mana Draught", spell = "Restore Mana" },
    [90004] = { name = "Frenzy Potion", subclassID = 1, spell = "Frenzy" },
    [90005] = { name = "Some Elixir", subclassID = 2, spell = "Strength" },
    [90006] = { name = "Some Flask", subclassID = 3 },
    [90007] = { name = "Some Scroll", subclassID = 4 },
    [90008] = { name = "Some Bandage", spell = "First Aid" },
    [90009] = { name = "Hearthstone", classID = 15 },
    [90010] = { name = "Unused Consumable", subclassID = 0, spell = "Something" },
    [12451] = { name = "Juju Power", subclassID = 0, spell = "Juju Power" },
    [18253] = { name = "Major Rejuvenation Potion", subclassID = 1, spell = "Rejuvenation" },
    [21023] = { name = "Dirge's Chops", spell = "Food", spellID = 9001 },
    [90011] = { name = "Spicy Thing", spell = "Food", spellID = 9002, desc = "If you spend 10 seconds eating you will become well fed." },
    [5350] = { name = "Conjured Water", spell = "Drink" },
}
local ns = M.LoadAddon()
local C = ns.Classify
local function of(id) return table.concat(C.Of(id), ",") end

M.check("food by spell", of(4599), "food")
M.check("drink by spell", of(8766), "drink")
M.check("refreshment in both", of(90001), "food,drink")
M.check("healing potion by spell", of(90002), "healing")
M.check("mana potion by spell", of(90003), "mana")
M.check("listed healing potion", of(13446), "healing")
M.check("other potion -> potions", of(90004), "potions")
M.check("elixir by subclass", of(90005), "elixirs")
M.check("flask by subclass", of(90006), "flasks")
M.check("scroll by subclass", of(90007), "scrolls")
M.check("bandage by spell", of(90008), "bandages")
M.check("not a consumable", of(90009), "")
M.check("leftover not shown", of(90010), "")
M.check("listed juju -> elixirs", of(12451), "elixirs")
M.check("rejuvenation in both", of(18253), "healing,mana")
M.check("buff food listed", C.IsBuffFood(21023), true)
M.check("buff food by description", C.IsBuffFood(90011), true)
M.check("plain food is not buff food", C.IsBuffFood(4599), false)
M.check("conjured listed", C.IsConjured(5350), true)
M.check("not conjured", C.IsConjured(8766), false)

-- Every category key used in the lists is a real category.
local known = {}
for _, cat in ipairs(ns.Settings.CATEGORIES) do known[cat] = true end
local bad = 0
for cat in pairs(ns.Items.LISTS) do if not known[cat] then bad = bad + 1 end end
M.check("list keys are categories", bad, 0)

-- The probe stores the bag items with their data.
M.bags = { [4599] = 5, [13446] = 3 }
SlashCmdList.FOREVERCONSUMABLES("scan")
local scan = ns.CharDB().scan
M.check("scan stored", scan and #scan, 2)
M.check("scan has categories", scan[2].cats, "healing")
SlashCmdList.FOREVERCONSUMABLES("ids")
M.flush()
M.check("ids checked: known", ns.CharDB().ids[13446], "Major Healing Potion")
M.check("ids checked: unknown", ns.CharDB().ids[13510], false)

M.done()
