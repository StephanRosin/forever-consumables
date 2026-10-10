-- Choosing an item and the tooltip.
local M = dofile("mock.lua")
print("Picker")
M.spells = { [441] = "Healing Potion" }
M.items = {
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
}
M.bags = { [929] = 2, [13446] = 1 }
local ns = M.LoadAddon()
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
local Bar, S = ns.Bar, ns.Settings
local heal = Bar.ButtonOf("healing")

heal.arrow:GetScript("OnClick")(heal.arrow)
local root = M.menu.root
M.check("title", root.children[1].text, "Healing")
M.check("automatic first", root.children[2].text, "Automatic (best)")
M.check("automatic selected", root.children[2].isSelected(), true)
M.check("two items", #root.children, 4)
M.check("item text has count", root.children[3].text:find("Healing Potion (2)", 1, true) ~= nil, true)
root.children[3].setSelected()
M.check("chosen stored", ns.Choice.Get("healing"), 929)
M.check("button follows", heal:GetAttribute("item"), "item:929")
M.menu = nil
heal.arrow:GetScript("OnClick")(heal.arrow)
M.check("chosen selected", M.menu.root.children[3].isSelected(), true)
M.check("automatic not selected", M.menu.root.children[2].isSelected(), false)
M.menu.root.children[2].setSelected()
M.check("back to automatic", heal:GetAttribute("item"), "item:13446")

-- No menu in combat.
M.menu = nil
M.setCombat(true)
heal.arrow:GetScript("OnClick")(heal.arrow)
M.check("combat: no menu", M.menu, nil)
M.setCombat(false)

-- Right-click mode: right click picks, never uses; modifiers do nothing.
S.Set("arrowMode", "RIGHTCLICK")
M.check("arrow hidden", heal.arrow:IsShown(), false)
M.check("no-op type2", heal:GetAttribute("*type2"), "")
M.used = {}
M.Click(heal, "RightButton", true)
M.Click(heal, "RightButton", false)
M.check("right click: not used", #M.used, 0)
M.check("right click: menu", M.menu ~= nil, true)
M.menu = nil
M.modifier = true
M.Click(heal, "RightButton", false)
M.check("shift right: no menu", M.menu, nil)
M.modifier = false
S.Set("arrowMode", "RIGHT")
M.check("type2 cleared", heal:GetAttribute("*type2"), nil)

-- Tooltip.
heal:GetScript("OnEnter")(heal)
M.check("tooltip item", GameTooltip._item, 13446)
M.check("tooltip hint", GameTooltip._lines[#GameTooltip._lines], "Arrow: choose")
S.Set("tooltip", false)
GameTooltip._item = nil
heal:GetScript("OnEnter")(heal)
M.check("tooltip off", GameTooltip._item, nil)

M.done()
