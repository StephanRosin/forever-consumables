-- The bar's frames: refresh, combat, collapse, visibility, mover.
local M = dofile("mock.lua")
print("Bar")
M.spells = { [433] = "Food", [430] = "Drink", [441] = "Healing Potion" }
M.items = {
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
    [4599] = { name = "Cured Ham Steak", spell = "Food", minLevel = 35, itemLevel = 45, icon = 5 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", minLevel = 45, itemLevel = 55, icon = 8 },
    [13444] = { name = "Major Mana Potion", minLevel = 49, itemLevel = 59, icon = 9 },
    [19006] = { name = "Lesser Healthstone", minLevel = 0, itemLevel = 1, icon = 10 },
}
M.bags = { [929] = 2, [13446] = 1, [4599] = 10, [8766] = 5, [13444] = 3, [19006] = 1 }
local ns = M.LoadAddon()
local Bar, S = ns.Bar, ns.Settings
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
M.flush()

local function shown(cat) local b = Bar.ButtonOf(cat); return b ~= nil and b:IsShown() end
M.check("food shown", shown("food"), true)
M.check("drink shown", shown("drink"), true)
M.check("healing shown", shown("healing"), true)
M.check("healthstone beside it", shown("healthstone"), true)
M.check("healing keeps the potion", Bar.ButtonOf("healing"):GetAttribute("item"), "item:13446")
M.check("mana shown", shown("mana"), true)
M.check("empty flasks hidden", shown("flasks"), false)
local heal = Bar.ButtonOf("healing")
M.check("item attribute", heal:GetAttribute("item"), "item:13446")
M.check("type item", heal:GetAttribute("type"), "item")
M.check("count text", heal.count:GetText(), "1")
M.check("icon", heal.icon:GetTexture(), 3)
M.check("order: food first", select(4, Bar.ButtonOf("food"):GetPoint()), 3)

M.Click(heal, "LeftButton", true)
M.Click(heal, "LeftButton", false)
M.check("left click uses once", #M.used, 1)
M.check("used the potion", M.used[1], "item:13446")

-- Empty categories kept when asked.
S.Set("hideEmpty", false)
M.check("empty flasks kept", shown("flasks"), true)
M.check("empty: category icon", Bar.ButtonOf("flasks").icon:GetTexture(), Bar.ICONS.flasks)
M.check("empty: greyed", Bar.ButtonOf("flasks").icon:IsDesaturated(), true)
S.Set("hideEmpty", true)
S.Set("show_drink", false)
M.check("switched off", shown("drink"), false)
S.Set("show_drink", true)

-- In combat: nothing protected changes; the last potion is used up.
M.setCombat(true)
M.bags[13446] = 0
M.Fire("BAG_UPDATE_DELAYED")
M.check("combat: button stays", heal:IsShown(), true)
M.check("combat: attribute unchanged", heal:GetAttribute("item"), "item:13446")
M.check("combat: greyed", heal.icon:IsDesaturated(), true)
M.check("combat: count 0", heal.count:GetText(), "0")
M.check("combat: arrow disabled (set at combat start)", heal.arrow:IsEnabled(), false)
M.check("combat: arrow icon greyed", heal.arrow.icon:IsDesaturated(), true)
M.check("combat: food greyed", Bar.ButtonOf("food").icon:IsDesaturated(), true)
M.check("combat: drink greyed", Bar.ButtonOf("drink").icon:IsDesaturated(), true)
M.check("combat: cooldown update makes no protected call", pcall(M.Fire, "BAG_UPDATE_COOLDOWN"), true)
M.setCombat(false)
M.check("after combat: next best", heal:GetAttribute("item"), "item:929")
M.check("after combat: arrow enabled", heal.arrow:IsEnabled(), true)
M.check("after combat: food in colour", Bar.ButtonOf("food").icon:IsDesaturated(), false)

-- No mana, no drink.
M.class = "WARRIOR"
M.Fire("BAG_UPDATE_DELAYED")
M.check("warrior: no drink", shown("drink"), false)
M.check("warrior: no mana", shown("mana"), false)
M.check("warrior: food stays", shown("food"), true)
M.class = nil
M.Fire("BAG_UPDATE_DELAYED")
M.check("priest: drink", shown("drink"), true)

-- Settings changed in combat apply after it.
M.setCombat(true)
S.Set("size", 40)
M.check("combat: size waits", heal:GetWidth(), 36)
M.setCombat(false)
M.check("after combat: size", heal:GetWidth(), 40)

-- Collapse: also in combat, saved per character.
local toggle = Bar.toggle
M.setCombat(true)
M.Click(toggle, "LeftButton")
M.check("collapsed in combat", Bar.bar:IsShown(), false)
M.check("saved", ns.CharDB().collapsed, true)
M.Click(toggle, "LeftButton")
M.check("opened again", Bar.bar:IsShown(), true)
M.check("saved open", ns.CharDB().collapsed, false)
M.setCombat(false)
M.Click(toggle, "LeftButton")
M.Fire("BAG_UPDATE_DELAYED")
M.check("refresh keeps it collapsed", Bar.bar:IsShown(), false)
M.Click(toggle, "LeftButton")

-- Visibility driver.
S.Set("visMode", "COMBAT")
M.check("driver", M.drivers[Bar.holder].visibility, "[@player,dead] hide; [combat] show; hide")
S.Set("visInstance", true)
M.check("instance only, outside", M.drivers[Bar.holder].visibility, "hide")
M.instance = "party"
M.Fire("PLAYER_ENTERING_WORLD")
M.flush()
M.check("instance only, inside", M.drivers[Bar.holder].visibility, "[@player,dead] hide; [combat] show; hide")
S.Set("visInstance", false); S.Set("visMode", "ALWAYS")

-- Alpha follows combat.
S.Set("alphaNoCombat", 50)
M.check("alpha out of combat", Bar.holder:GetAlpha(), 0.5)
M.setCombat(true)
M.check("alpha in combat", Bar.holder:GetAlpha(), 1)
M.setCombat(false)

-- Position and the mover.
S.Set("point", "TOPLEFT"); S.Set("x", 100); S.Set("y", -50)
local p, rel, p2, x, y = Bar.holder:GetPoint()
M.check("point", p .. ":" .. p2 .. ":" .. x .. ":" .. y, "TOPLEFT:TOPLEFT:100:-50")
S.Set("locked", false)
M.check("mover shown", Bar.mover:IsShown(), true)
S.Set("locked", true)
M.check("mover hidden", Bar.mover:IsShown(), false)


-- Combat start: between REGEN_DISABLED and the lockdown the combat state holds.
S.Set("alphaCombat", 100); S.Set("alphaNoCombat", 50)
M.Fire("PLAYER_REGEN_DISABLED")
M.Fire("BAG_UPDATE_COOLDOWN")
M.check("combat alpha before lockdown", Bar.holder:GetAlpha(), 1)
M.check("arrow greyed before lockdown", heal.arrow.icon:IsDesaturated(), true)
M.combat = true
M.setCombat(false)
M.check("alpha back after combat", Bar.holder:GetAlpha(), 0.5)

-- Count text: grey at zero, configured colour otherwise.
S.Set("countColor", { 1, 0, 0, 1 })
M.check("count colour", heal.count._textColor[1], 1)
M.check("count colour g", heal.count._textColor[2], 0)
M.setCombat(true)
M.bags[929] = 0
M.Fire("BAG_UPDATE_DELAYED")
M.check("count grey at zero", heal.count._textColor[2], 0.5)
M.bags[929] = 2
M.Fire("BAG_UPDATE_DELAYED")
M.check("count colour restored", heal.count._textColor[2], 0)
M.setCombat(false)

-- Minimap keys do not refresh the bar.
local scans, realScan = 0, ns.Bags.Scan
ns.Bags.Scan = function() scans = scans + 1; return realScan() end
S.Set("minimapAngle", 100); S.Set("minimapShow", false)
M.check("minimap keys skip refresh", scans, 0)
S.Set("size", 42)
M.check("other keys refresh", scans, 1)
ns.Bags.Scan = realScan

-- Late item data: one throttled refresh for many events.
scans = 0
ns.Bags.Scan = function() scans = scans + 1; return realScan() end
M.flush()
M.Fire("GET_ITEM_INFO_RECEIVED", 1); M.Fire("GET_ITEM_INFO_RECEIVED", 2)
M.check("no refresh before timer", scans, 0)
M.flush()
M.check("one throttled refresh", scans, 1)
M.Fire("GET_ITEM_INFO_RECEIVED", 3); M.flush()
M.check("next event refreshes again", scans, 2)
ns.Bags.Scan = realScan

-- Default arrow mode: right click, no arrow.
M.check("arrowMode default", S.Def("arrowMode").default, "RIGHTCLICK")
ns.DB().arrowMode = nil
M.check("fresh arrowMode", S.Get("arrowMode"), "RIGHTCLICK")
S.Set("size", 36)
M.check("default: *type2 empty", heal:GetAttribute("*type2"), "")
M.check("default: no arrow", heal.arrow:IsShown(), false)
S.Set("arrowMode", "RIGHT")
M.check("RIGHT mode shows arrow", heal.arrow:IsShown(), true)
M.check("RIGHT arrow atlas", heal.arrow.icon:GetAtlas(), "friendslist-categorybutton-arrow-right")
M.check("arrow icon width", heal.arrow.icon:GetWidth(), 12)
M.check("arrow icon height", heal.arrow.icon:GetHeight(), 12)
S.Set("arrowMode", "BELOW")
M.check("BELOW arrow atlas", heal.arrow.icon:GetAtlas(), "friendslist-categorybutton-arrow-down")
M.check("BELOW icon width", heal.arrow.icon:GetWidth(), 12)
M.check("BELOW icon height", heal.arrow.icon:GetHeight(), 12)
S.Set("arrowMode", "RIGHT")

M.check("holder does not save position", Bar.holder._dontSave, true)

-- Login timing: delayed rescans, one SPELLS_CHANGED rescan, /fcon debug.
M.flush()
M.Fire("PLAYER_LOGIN")
local d = {}
for _, x in ipairs(M.delays) do d[x] = (d[x] or 0) + 1 end
M.check("login: rescan after 1 s", d[1], 1)
M.check("login: rescan after 5 s", d[5], 1)
M.flush()
M.Fire("PLAYER_ENTERING_WORLD")
d = {}
for _, x in ipairs(M.delays) do d[x] = (d[x] or 0) + 1 end
M.check("entering world: rescan after 1 s", d[1], 1)
M.check("entering world: rescan after 5 s", d[5], 1)
M.flush()
M.bags[8766] = 0
M.Fire("SPELLS_CHANGED")
M.check("SPELLS_CHANGED rescans", shown("drink"), false)
M.bags[8766] = 5
M.Fire("SPELLS_CHANGED")
M.check("SPELLS_CHANGED only once", shown("drink"), false)
M.Fire("BAG_UPDATE_DELAYED")
S.Set("show_drink", true)
S.Set("show_flasks", false)
local line = Bar.DebugLine()
M.check("debug line short", #line < 200, true)
M.check("debug line format", line:match("^FC holder=%a+ alpha=%S+ bar=%a+ items=%d+ collapsed=%a+ driver=.+ food=%d") ~= nil, true)
M.check("debug line counts", line:match("food=1 drink=1 healing=1") ~= nil, true)
M.check("debug skips disabled", line:find("flasks=", 1, true), nil)
SlashCmdList.FOREVERCONSUMABLES("debug")
M.check("debug prints", M.chat[#M.chat]:find("FC holder=", 1, true) ~= nil, true)

M.done()
