-- Optional Masque skinning: which buttons join the group, and when they are reskinned.
local M = dofile("mock.lua")
print("Masque")
M.spells = { [441] = "Healing Potion" }
M.items = { [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 } }
M.bags = { [929] = 2 }

local group = { added = {}, reskinned = {} }
function group:AddButton(b, regions, kind)
    assert(not M.combat, "AddButton in combat")
    self.added[#self.added + 1] = { button = b, regions = regions, kind = kind, width = b:GetWidth() }
end
function group:ReSkin(b)
    assert(not M.combat, "ReSkin in combat")
    self.reskinned[#self.reskinned + 1] = { button = b, width = b:GetWidth() }
end
local groupName
LibStub = function(name, silent)
    if name ~= "Masque" then return nil end
    M.check("asks for Masque silently", silent, true)
    return { Group = function(_, addon) groupName = addon; return group end }
end

local ns = M.LoadAddon()
local Bar, S = ns.Bar, ns.Settings
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
M.flush()

local heal = Bar.ButtonOf("healing")
M.check("group name", groupName, "Forever Consumables")
M.check("only the shown button joins", #group.added, 1)
local added = group.added[1]
M.check("healing joined", added.button, heal)
M.check("as an item button", added.kind, "Item")
M.check("icon handed over", added.regions.Icon, heal.icon)
M.check("cooldown handed over", added.regions.Cooldown, heal.cooldown)
M.check("count stays ours", added.regions.Count, false)
M.check("joined at its real size", added.width, S.Get("size"))

M.Fire("BAG_UPDATE_DELAYED")
M.flush()
M.check("same size: no reskin", #group.reskinned, 0)
M.check("same size: not added again", #group.added, 1)

M.setCombat(true)
S.Set("size", 40)
M.flush()
M.check("combat: reskin waits", #group.reskinned, 0)
M.setCombat(false)
M.flush()
M.check("after combat: one reskin", #group.reskinned, 1)
M.check("reskins that button", group.reskinned[1].button, heal)
M.check("reskins at the new size", group.reskinned[1].width, 40)

M.bags[4599] = 1
M.items[4599] = { name = "Cured Ham Steak", spell = "Food", minLevel = 35, itemLevel = 45, icon = 5 }
M.spells[433] = "Food"
M.Fire("BAG_UPDATE_DELAYED")
M.flush()
M.check("a newly shown button joins", #group.added, 2)
M.check("at the current size", group.added[2].width, 40)

M.done()
