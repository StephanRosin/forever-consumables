-- Core: event bus, deferred work, slash command, locales, profiles.
local M = dofile("mock.lua")
print("Core, locales, profiles")
local ns = M.LoadAddon()

-- AfterCombat runs at once out of combat, once after combat in it.
local runs = 0
ns.AfterCombat("x", function() runs = runs + 1 end)
M.check("out of combat: at once", runs, 1)
M.setCombat(true)
ns.AfterCombat("x", function() runs = runs + 1 end)
ns.AfterCombat("x", function() runs = runs + 10 end)
M.check("in combat: waits", runs, 1)
M.setCombat(false)
M.check("after combat: the latest once", runs, 11)

-- Slash: unknown sub prints the help.
SlashCmdList.FOREVERCONSUMABLES("nonsense")
M.check("help printed", M.chat[#M.chat]:find("/fcon", 1, true) ~= nil, true)

-- Every language has the same keys as English.
local function keys(t) local k = {} for key in pairs(t) do k[#k + 1] = key end table.sort(k) return table.concat(k, ",") end
local en = keys(ns.Locales.enUS)
for _, code in ipairs({ "deDE", "esES", "frFR" }) do
    M.check("same keys: " .. code, keys(ns.Locales[code]), en)
end

-- Profiles: a character starts on Default; CharDB is its own.
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.check("default profile", ns.ActiveProfile(), "Default")
ns.DB().size = 40
ns.SwitchProfile("Raid")
M.check("save as copies", ns.DB().size, 40)
M.check("char db", type(ns.CharDB()), "table")

M.done()
