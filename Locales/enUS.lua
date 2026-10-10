local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Consumables"
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."
L.LANGUAGE_AUTO = "Game language"
L.OPT_LANGUAGE = "Language"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Really delete the profile \"%s\"?"
L.OPEN_OPTIONS = "Open options"
L.BUTTON_CLICK = "Click: options"
L.BUTTON_DRAG = "Drag: move the button"
L.INHERITED = "inherited"
L.RESET_OVERRIDE = "Reset"
L.SLASH_HELP = "/fcon — options · /fcon scan — record bag items · /fcon ids — check the item lists"
L.IMPORT_FORMAT = "This is not a Forever Consumables profile."
L.TIP_COLLAPSE = "Click: collapse the bar"
L.TIP_EXPAND = "Click: open the bar"
