--[[---------------------------------------------------------------------------
Options.lua -- the option pages (OptionsPanel.lua builds them): General,
Bar, Visibility, Display, Categories. Every row writes through Settings.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local S = ns.Settings

local function add(page, items) for _, item in ipairs(items) do page[#page + 1] = item end end

-- A row bound to one setting.
local function bind(key, row)
    row.settingKey = key
    row.get = row.get or function() return S.Get(key) end
    row.set = row.set or function(v) S.Set(key, v) end
    return row
end
local function check(key, label) return bind(key, { type = "check", label = label }) end
local function slider(key, label, unit, step)
    local def = S.Def(key)
    return bind(key, { label = label, min = def.min, max = def.max, step = step or 1, unit = unit })
end
local function select(key, label, prefix)
    return bind(key, { type = "select", label = label, choices = function()
        local list = {}
        for _, v in ipairs(S.Def(key).values) do list[#list + 1] = { value = v, label = L[prefix .. v] } end
        return list
    end })
end
local function color(key, label) return bind(key, { type = "color", label = label }) end

local function generalTab()
    return {
        { type = "tab", label = "TAB_GENERAL" },
        { type = "select", label = "OPT_LANGUAGE",
          choices = function()
              local list = { { value = "AUTO", label = L.LANGUAGE_AUTO } }
              for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = c end
              return list
          end,
          get = function() return ns.Locale.Setting() end, set = function(v) ns.Locale.Set(v) end },
        { type = "header", label = "OPT_MINIMAP" },
        check("minimapShow", "OPT_MINIMAP_SHOW"),
        { type = "header", label = "OPT_PROFILE" },
        { type = "select", label = "OPT_PROFILE_ACTIVE",
          choices = function()
              local list = {}
              for _, name in ipairs(ns.ProfileList()) do list[#list + 1] = { label = name, value = name } end
              return list
          end,
          get = function() return ns.ActiveProfile() end,
          set = function(name) ns.SwitchProfile(name); ns.RefreshOptions() end },
        { type = "buttons", buttons = {
            { label = "OPT_PROFILE_SAVE_AS", width = 150, onClick = function() ns.AskProfileName() end },
            { label = "OPT_PROFILE_DELETE", width = 100, onClick = function() ns.AskDeleteProfile() end },
        } },
        { type = "buttons", buttons = {
            { label = "OPT_EXPORT", width = 120, onClick = function() ns.ShowExport() end },
            { label = "OPT_IMPORT", width = 120, onClick = function() ns.AskImport() end },
        } },
    }
end

local function barTab()
    return {
        { type = "tab", label = "TAB_BAR" },
        { type = "header", label = "OPT_LAYOUT" },
        select("orientation", "OPT_ORIENTATION", "ORIENT_"),
        slider("perRow", "OPT_PER_ROW"),
        slider("size", "OPT_SIZE", "px"),
        slider("spacing", "OPT_SPACING", "px"),
        slider("scale", "OPT_SCALE", "%", 5),
        { type = "header", label = "OPT_POSITION" },
        check("locked", "OPT_LOCKED"),
        select("point", "OPT_POINT", "POINT_"),
        slider("x", "OPT_X", "px"),
        slider("y", "OPT_Y", "px"),
        { type = "header", label = "OPT_BORDER" },
        check("borderShow", "OPT_BORDER_SHOW"),
        slider("borderSize", "OPT_BORDER_SIZE", "px"),
        color("borderColor", "OPT_BORDER_COLOR"),
        check("backgroundShow", "OPT_BACKGROUND_SHOW"),
        color("backgroundColor", "OPT_BACKGROUND_COLOR"),
    }
end

local function visibilityTab()
    return {
        { type = "tab", label = "TAB_VISIBILITY" },
        { type = "header", label = "OPT_WHEN" },
        select("visMode", "OPT_VIS_MODE", "VIS_"),
        check("visInstance", "OPT_VIS_INSTANCE"),
        check("visGroup", "OPT_VIS_GROUP"),
        check("visHideDead", "OPT_VIS_DEAD"),
        check("visHideTaxi", "OPT_VIS_TAXI"),
        { type = "header", label = "OPT_OPACITY" },
        slider("alphaNoCombat", "OPT_ALPHA_NOCOMBAT", "%", 5),
        slider("alphaCombat", "OPT_ALPHA_COMBAT", "%", 5),
        check("fadeMouseover", "OPT_FADE_MOUSEOVER"),
    }
end

local function displayTab()
    return {
        { type = "tab", label = "TAB_DISPLAY" },
        { type = "header", label = "OPT_COUNT" },
        bind("countFont", { type = "select", label = "OPT_FONT", choices = function()
            local list = {}
            for _, f in ipairs(ns.Media.Fonts()) do
                list[#list + 1] = { value = f.key, label = f.key == "DEFAULT" and L.FONT_DEFAULT or f.key, font = f.key }
            end
            return list
        end }),
        slider("countSize", "OPT_FONT_SIZE", "px"),
        select("countOutline", "OPT_OUTLINE", "OUTLINE_"),
        color("countColor", "OPT_COUNT_COLOR"),
        select("countPoint", "OPT_COUNT_POINT", "POINT_"),
        slider("countX", "OPT_X", "px"),
        slider("countY", "OPT_Y", "px"),
        { type = "header", label = "OPT_CHOOSING" },
        select("arrowMode", "OPT_ARROW", "ARROW_"),
        check("tooltip", "OPT_TOOLTIP"),
    }
end

local function categoriesTab()
    local items = {
        { type = "tab", label = "TAB_CATEGORIES" },
        { type = "header", label = "OPT_CATEGORIES" },
        check("hideEmpty", "OPT_HIDE_EMPTY"),
    }
    for _, cat in ipairs(S.CATEGORIES) do
        local up = cat:upper()
        add(items, {
            { type = "header", label = "CAT_" .. up },
            check("show_" .. cat, "OPT_CAT_SHOW"),
            { label = "OPT_CAT_POSITION", min = 1, max = #S.CATEGORIES, step = 1, settingKey = "order", cat = cat,
              get = function() return S.Position(cat) end,
              set = function(v) S.MoveTo(cat, v); ns.RefreshOptions() end },
        })
    end
    return items
end

local spec
function ns.OptionsSpec()
    if not spec then
        spec = { title = L.ADDON_NAME }
        for _, tab in ipairs({ generalTab, barTab, visibilityTab, displayTab, categoriesTab }) do add(spec, tab()) end
    end
    return spec
end

ns.On("PLAYER_LOGIN", function() ns.BuildOptions(ns.OptionsSpec()) end)
ns.Slash[""] = function() ns.Window.Toggle() end

-- Export and import through Blizzard's text popups.
if StaticPopupDialogs then
    StaticPopupDialogs.FOREVERCONSUMABLES_EXPORT = {
        text = "", button1 = OKAY or "OK", hasEditBox = 1, editBoxWidth = 350,
        OnShow = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            if box then box:SetText(S.Export()); box:HighlightText(); box:SetFocus() end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopupDialogs.FOREVERCONSUMABLES_IMPORT = {
        text = "", button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel", hasEditBox = 1, editBoxWidth = 350,
        OnAccept = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            local ok, err = S.Import(box and box:GetText())
            if not ok then ns.Print(L[err]) end
            ns.RefreshOptions()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end
function ns.ShowExport()
    StaticPopupDialogs.FOREVERCONSUMABLES_EXPORT.text = L.POPUP_EXPORT
    StaticPopup_Show("FOREVERCONSUMABLES_EXPORT")
end
function ns.AskImport()
    StaticPopupDialogs.FOREVERCONSUMABLES_IMPORT.text = L.POPUP_IMPORT
    StaticPopup_Show("FOREVERCONSUMABLES_IMPORT")
end
