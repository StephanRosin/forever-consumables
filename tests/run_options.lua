-- The option pages: every setting has a row; rows read and write settings.
local M = dofile("mock.lua")
print("Options")
local ns = M.LoadAddon()
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
local S = ns.Settings
local spec = ns.OptionsSpec()

-- Rows by label key.
local rows, tabs = {}, {}
for _, opt in ipairs(spec) do
    if opt.type == "tab" then tabs[#tabs + 1] = opt.label end
    if opt.label then rows[opt.label] = rows[opt.label] or opt end
end
M.check("tabs", table.concat(tabs, ","), "TAB_GENERAL,TAB_BAR,TAB_VISIBILITY,TAB_DISPLAY,TAB_CATEGORIES")

-- Every setting is reachable (keys covered by some row's settingKey).
local covered = {}
for _, opt in ipairs(spec) do if opt.settingKey then covered[opt.settingKey] = true end end
local missing = {}
for _, def in ipairs(S.All()) do
    if not covered[def.key] and def.key ~= "minimapAngle" then
        missing[#missing + 1] = def.key
    end
end
M.check("every setting has a row", table.concat(missing, ","), "")

-- A row writes through Settings.
rows.OPT_SIZE.set(48)
M.check("size via options", S.Get("size"), 48)
M.check("size row reads", rows.OPT_SIZE.get(), 48)
rows.OPT_VIS_MODE.set("NOCOMBAT")
M.check("mode via options", S.Get("visMode"), "NOCOMBAT")

-- Category position rows move categories.
local pos
for _, opt in ipairs(spec) do if opt.settingKey == "order" and opt.cat == "scrolls" then pos = opt end end
pos.set(1)
M.check("moved by position row", S.Order()[1], "scrolls")
M.check("position row reads", pos.get(), 1)

-- Every label key exists in English.
local bad = {}
for _, opt in ipairs(spec) do
    if type(opt.label) == "string" and not ns.Locales.enUS[opt.label] then bad[#bad + 1] = opt.label end
end
M.check("labels translated", table.concat(bad, ","), "")

-- Slash opens the window.
SlashCmdList.FOREVERCONSUMABLES("")
M.check("window open", ns.Window.IsShown(), true)

-- Compartment globals named by the TOC exist and do not raise.
M.check("compartment click", type(ForeverConsumables_OnAddonCompartmentClick), "function")
ForeverConsumables_OnAddonCompartmentClick()
ForeverConsumables_OnAddonCompartmentEnter(nil, M.newWidget("menu"))
ForeverConsumables_OnAddonCompartmentLeave(nil, M.newWidget("menu"))

-- The minimap button follows the setting; Media.FontPath is Media.lua's.
local button = ns.MinimapButton.button
M.check("minimap button made", button ~= nil, true)
S.Set("minimapShow", false); ns.MinimapButton.Place()
M.check("minimap button hidden", button:IsShown(), false)
M.check("font path from Media", ns.Media.FontPath("Morpheus"), "Fonts\\MORPHEUS.TTF")

M.done()
