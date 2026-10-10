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
L.SLASH_HELP = "/fcon — options"
L.IMPORT_FORMAT = "This is not a Forever Consumables profile."
L.TIP_COLLAPSE = "Click: collapse the bar"
L.TIP_EXPAND = "Click: open the bar"
L.CAT_FOOD = "Food"
L.CAT_DRINK = "Drink"
L.CAT_HEALING = "Healing"
L.CAT_MANA = "Mana"
L.CAT_POTIONS = "Potions"
L.CAT_FLASKS = "Flasks"
L.CAT_ELIXIRS = "Elixirs"
L.CAT_PROTECTION = "Protection"
L.CAT_SCROLLS = "Scrolls"
L.CAT_BANDAGES = "Bandages"
L.PICK_AUTO = "Automatic (best)"
L.TIP_USE = "Left-click: use"
L.TIP_PICK_ARROW = "Arrow: choose"
L.TIP_PICK_RIGHT = "Right-click: choose"
L.POINT_TOPLEFT = "Top left"
L.POINT_TOP = "Top"
L.POINT_TOPRIGHT = "Top right"
L.POINT_LEFT = "Left"
L.POINT_CENTER = "Center"
L.POINT_RIGHT = "Right"
L.POINT_BOTTOMLEFT = "Bottom left"
L.POINT_BOTTOM = "Bottom"
L.POINT_BOTTOMRIGHT = "Bottom right"
L.TAB_GENERAL = "General"
L.TAB_BAR = "Bar"
L.TAB_VISIBILITY = "Visibility"
L.TAB_DISPLAY = "Display"
L.TAB_CATEGORIES = "Categories"
L.OPT_MINIMAP = "Minimap button"
L.OPT_MINIMAP_SHOW = "Show"
L.OPT_PROFILE = "Profile"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.OPT_PROFILE_RESET = "Reset"
L.OPT_EXPORT = "Export"
L.OPT_IMPORT = "Import"
L.POPUP_EXPORT = "Copy this text (Ctrl+C):"
L.POPUP_IMPORT = "Paste a profile text:"
L.OPT_LAYOUT = "Layout"
L.OPT_ORIENTATION = "Direction"
L.ORIENT_HORIZONTAL = "Horizontal"
L.ORIENT_VERTICAL = "Vertical"
L.OPT_PER_ROW = "Buttons per row"
L.OPT_SIZE = "Button size"
L.OPT_SPACING = "Spacing"
L.OPT_SCALE = "Scale"
L.OPT_POSITION = "Position"
L.OPT_LOCKED = "Locked"
L.OPT_POINT = "Anchor point"
L.OPT_X = "Horizontal offset"
L.OPT_Y = "Vertical offset"
L.OPT_BORDER = "Border and background"
L.OPT_BORDER_SHOW = "Show border"
L.OPT_BORDER_SIZE = "Border size"
L.OPT_BORDER_COLOR = "Border colour"
L.OPT_BACKGROUND_SHOW = "Show background"
L.OPT_BACKGROUND_COLOR = "Background colour"
L.OPT_WHEN = "When to show"
L.OPT_VIS_MODE = "Show"
L.VIS_ALWAYS = "Always"
L.VIS_COMBAT = "In combat only"
L.VIS_NOCOMBAT = "Out of combat only"
L.VIS_NEVER = "Never"
L.OPT_VIS_INSTANCE = "Only in dungeons and raids"
L.OPT_VIS_GROUP = "Only in a group"
L.OPT_VIS_DEAD = "Hide while dead"
L.OPT_VIS_TAXI = "Hide on a flight path"
L.OPT_OPACITY = "Opacity"
L.OPT_ALPHA_NOCOMBAT = "Out of combat"
L.OPT_ALPHA_COMBAT = "In combat"
L.OPT_FADE_MOUSEOVER = "Fully visible under the mouse"
L.OPT_COUNT = "Count"
L.OPT_FONT = "Font"
L.FONT_DEFAULT = "Game font"
L.OPT_FONT_SIZE = "Size"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_OUTLINE = "Thin"
L.OUTLINE_THICKOUTLINE = "Thick"
L.OPT_COUNT_COLOR = "Colour"
L.OPT_COUNT_POINT = "Point on the button"
L.OPT_CHOOSING = "Choosing"
L.OPT_ARROW = "Choose with"
L.ARROW_RIGHT = "Arrow beside"
L.ARROW_BELOW = "Arrow below"
L.ARROW_RIGHTCLICK = "Right click"
L.OPT_TOOLTIP = "Show tooltips"
L.OPT_CATEGORIES = "Categories"
L.OPT_HIDE_EMPTY = "Hide empty categories"
L.OPT_CAT_SHOW = "Show"
L.OPT_CAT_POSITION = "Position on the bar"
