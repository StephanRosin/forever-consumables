-- Settings: defaults, validation, order, export/import.
local M = dofile("mock.lua")
print("Settings")
local ns = M.LoadAddon()
local S = ns.Settings

M.check("default size", S.Get("size"), 36)
M.check("default mode", S.Get("visMode"), "ALWAYS")
M.check("default category on", S.Get("show_food"), true)
M.check("default colour alpha", S.Get("backgroundColor")[4], 0.5)

local changed
S.OnChange(function(key) changed = key end)
M.check("set valid", S.Set("size", 40), true)
M.check("stored", S.Get("size"), 40)
M.check("listener", changed, "size")
M.check("clamped high", (S.Set("size", 999) and S.Get("size")), 64)
M.check("rounded", (S.Set("size", 30.6) and S.Get("size")), 31)
M.check("wrong type refused", S.Set("size", "big"), false)
M.check("enum refused", S.Set("visMode", "SOMETIMES"), false)
M.check("enum kept", S.Get("visMode"), "ALWAYS")
M.check("colour refused", S.Set("borderColor", { 1, 2 }), false)

-- Order: default, moving, unknown and missing keys.
M.check("default order", table.concat(S.Order(), ","),
    "food,drink,healing,mana,potions,flasks,elixirs,protection,scrolls,bandages")
S.MoveTo("bandages", 1)
M.check("moved to front", S.Order()[1], "bandages")
M.check("position", S.Position("food"), 2)
ns.DB().order = "mana,junk,mana,food"
M.check("cleaned order", table.concat(S.Order(), ","),
    "mana,food,drink,healing,potions,flasks,elixirs,protection,scrolls,bandages")

-- Export / import round trip.
S.Set("visMode", "COMBAT")
S.Set("borderColor", { 1, 0, 0, 1 })
S.Set("countFont", "Arial; Narrow=1")
local text = S.Export()
M.check("export prefix", text:sub(1, 4), "FC1;")
ns.SwitchProfile("Other")
S.Set("visMode", "NEVER")
M.check("import ok", (S.Import(text)), true)
M.check("import mode", S.Get("visMode"), "COMBAT")
M.check("import colour", S.Get("borderColor")[1], 1)
M.check("import text escaped", S.Get("countFont"), "Arial; Narrow=1")
M.check("import order", S.Order()[1], "mana")
local ok, err = S.Import("garbage")
M.check("bad import refused", ok, false)
M.check("bad import reason", err, "IMPORT_FORMAT")
M.check("bad import keeps profile", S.Get("visMode"), "COMBAT")
M.check("unknown keys skipped", (S.Import("FC1;nosuch=1;size=50")), true)
M.check("known key after unknown", S.Get("size"), 50)

M.done()
