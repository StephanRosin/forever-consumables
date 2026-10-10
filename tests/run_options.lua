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
rows.OPT_MINIMAP_SHOW.set(false)
M.check("minimap button hidden", button:IsShown(), false)
S.Set("minimapShow", true)
M.check("minimap button shown again", button:IsShown(), true)
M.check("font path from Media", ns.Media.FontPath("Morpheus"), "Fonts\\MORPHEUS.TTF")

-- Late ns.On handlers still get the event's own arguments (Style.lua must not replace Core's ns.On).
local got
ns.On("FC_TEST_EVENT", function(arg) got = arg end)
M.Fire("FC_TEST_EVENT", "payload")
M.check("ns.On passes event arguments", got, "payload")

-- Every select row's choices carry real translations, not the echoed key.
local raw = {}
for _, opt in ipairs(spec) do
    if opt.type == "select" and opt.choices then
        for _, c in ipairs(opt.choices()) do
            if c.label == nil or c.label:match("^[A-Z][A-Z0-9_]+$") then raw[#raw + 1] = tostring(c.label) end
        end
    end
end
M.check("select choices translated", table.concat(raw, ","), "")

-- The General tab places the bar too.
local general, inGeneral = {}, false
for _, opt in ipairs(spec) do
    if opt.type == "tab" then inGeneral = (opt.label == "TAB_GENERAL") end
    if inGeneral and opt.settingKey then general[opt.settingKey] = opt end
end
for _, key in ipairs({ "locked", "point", "x", "y" }) do
    M.check("general tab row " .. key, general[key] ~= nil, true)
end
general.x.set(77)
M.check("x via general tab", S.Get("x"), 77)


-- Reset button clears the active profile and refreshes the window.
local resetBtn
for _, opt in ipairs(spec) do
    if opt.buttons then for _, b in ipairs(opt.buttons) do if b.label == "OPT_PROFILE_RESET" then resetBtn = b end end end
end
M.check("reset button exists", resetBtn ~= nil, true)
S.Set("size", 55)
resetBtn.onClick()
M.check("reset button restores default", S.Get("size"), 36)

-- Dragging (x/y changes) refreshes an open window.
local refreshed = 0
local realRefresh = ns.RefreshOptions
ns.RefreshOptions = function() refreshed = refreshed + 1 end
ns.Window.Open()
S.Set("x", 12)
M.check("x change refreshes open window", refreshed, 1)
S.Set("size", 30)
M.check("other key does not", refreshed, 1)
ns.Window.Toggle()
S.Set("y", 13)
M.check("closed window not refreshed", refreshed, 1)
ns.RefreshOptions = realRefresh

-- Export/import popups lift the shared edit box's letter limit.
M.check("export maxLetters", StaticPopupDialogs.FOREVERCONSUMABLES_EXPORT.maxLetters, 0)
M.check("import maxLetters", StaticPopupDialogs.FOREVERCONSUMABLES_IMPORT.maxLetters, 0)

M.done()
