-- Another addon brings LibStub but Masque is not installed: the bar works as usual.
local M = dofile("mock.lua")
print("No Masque")
M.spells = { [441] = "Healing Potion" }
M.items = { [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 } }
M.bags = { [929] = 2 }
LibStub = function() return nil end

local ns = M.LoadAddon()
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
M.flush()

local heal = ns.Bar.ButtonOf("healing")
M.check("no group", ns.Bar.skins, nil)
M.check("button shown", heal:IsShown(), true)
M.check("icon", heal.icon:GetTexture(), 2)
M.check("default icon crop", heal.icon._coords[1], 0.07)
ns.Settings.Set("size", 40)
M.flush()
M.check("resizes", heal:GetWidth(), 40)
M.Click(heal, "LeftButton", true)
M.Click(heal, "LeftButton", false)
M.check("click uses the item", M.used[1], "item:929")

M.done()
