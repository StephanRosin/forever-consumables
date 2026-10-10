-- Bag scan and the automatic choice.
local M = dofile("mock.lua")
print("Bags and choice")
M.spells = { [433] = "Food", [430] = "Drink", [441] = "Healing Potion" }
M.items = {
    [118] = { name = "Minor Healing Potion", spell = "Healing Potion", minLevel = 1, itemLevel = 5, icon = 1 },
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
    [5512] = { name = "Minor Healthstone", minLevel = 0, itemLevel = 1, icon = 4 },
    [4599] = { name = "Cured Ham Steak", spell = "Food", minLevel = 35, itemLevel = 45, icon = 5 },
    [21023] = { name = "Dirge's Chops", spell = "Food", minLevel = 55, itemLevel = 65, icon = 6 },
    [8079] = { name = "Conjured Crystal Water", spell = "Drink", minLevel = 55, itemLevel = 65, icon = 7 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", minLevel = 45, itemLevel = 55, icon = 8 },
}
-- The healthstone stays out of the bags here: conjured, it would win every healing pick.
M.bags = { [118] = 4, [929] = 2, [13446] = 1, [4599] = 10, [21023] = 3, [8079] = 20, [8766] = 5 }
local ns = M.LoadAddon()
local B, C = ns.Bags, ns.Choice

M.level = 30
local scan = B.Scan()
M.check("every category present", scan.flasks ~= nil and #scan.flasks, 0)
M.check("healing entries", #scan.healing, 3)
M.check("sorted by name", scan.healing[1].name, "Healing Potion")
M.check("count", scan.food[1].count, 10)
M.check("conjured flag", scan.drink[1].conjured, true)
M.check("buff food flag", scan.food[2].buffFood, true)

M.check("best: highest usable level", C.Best(scan.healing, 30).id, 929)
M.level = 60
scan = B.Scan()
M.check("best at 60", C.Best(scan.healing, 60).id, 13446)
M.check("conjured first", C.Best(scan.drink, 60).id, 8079)
M.check("buff food never automatic", C.Best(scan.food, 60).id, 4599)
M.check("only buff food: none", C.Best({ scan.food[2] }, 60), nil)

-- A chosen item while in the bags; automatic otherwise.
local e, chosen = C.Resolve(scan.healing, 118, 60)
M.check("chosen used", e.id, 118)
M.check("chosen flag", chosen, true)
e, chosen = C.Resolve(scan.healing, 99999, 60)
M.check("gone: automatic", e.id, 13446)
M.check("gone: not chosen", chosen, false)

C.Set("healing", 118)
M.check("stored per character", ns.CharDB().choice.healing, 118)
M.check("get", C.Get("healing"), 118)
C.Set("healing", nil)
M.check("back to automatic", C.Get("healing"), nil)

M.done()
