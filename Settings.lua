--[[---------------------------------------------------------------------------
Settings.lua -- every setting of the bar: its type, default and limits, read
and written through the active profile (Profiles.lua). Invalid values are
refused, numbers clamped and rounded. Also the order of the categories and
the profile as text for export and import.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Settings = {}
ns.Settings = Settings

Settings.CATEGORIES = { "food", "drink", "healing", "healthstone", "mana", "potions", "flasks", "elixirs", "protection",
    "scrolls", "bandages" }
Settings.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local DEFS = {
    -- The bar
    { key = "orientation", type = "enum", values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" },
    { key = "perRow", type = "int", min = 1, max = 10, default = 10 },
    { key = "size", type = "int", min = 20, max = 64, default = 36 },
    { key = "spacing", type = "int", min = 0, max = 20, default = 4 },
    { key = "scale", type = "int", min = 50, max = 200, default = 100 },
    { key = "borderShow", type = "bool", default = true },
    { key = "borderSize", type = "int", min = 1, max = 4, default = 1 },
    { key = "borderColor", type = "color", default = { 0, 0, 0, 1 } },
    { key = "backgroundShow", type = "bool", default = true },
    { key = "backgroundColor", type = "color", default = { 0, 0, 0, 0.5 } },
    { key = "point", type = "enum", values = Settings.POINTS, default = "CENTER" },
    { key = "x", type = "int", min = -2000, max = 2000, default = 0 },
    { key = "y", type = "int", min = -2000, max = 2000, default = -200 },
    { key = "locked", type = "bool", default = true },
    -- Visibility
    { key = "visMode", type = "enum", values = { "ALWAYS", "COMBAT", "NOCOMBAT", "NEVER" }, default = "ALWAYS" },
    { key = "visInstance", type = "bool", default = false },
    { key = "visGroup", type = "bool", default = false },
    { key = "visHideDead", type = "bool", default = true },
    { key = "visHideTaxi", type = "bool", default = true },
    { key = "alphaCombat", type = "int", min = 0, max = 100, default = 100 },
    { key = "alphaNoCombat", type = "int", min = 0, max = 100, default = 100 },
    { key = "fadeMouseover", type = "bool", default = false },
    -- Display
    { key = "countFont", type = "text", default = "DEFAULT" },
    { key = "countSize", type = "int", min = 6, max = 24, default = 12 },
    { key = "countOutline", type = "enum", values = { "NONE", "OUTLINE", "THICKOUTLINE" }, default = "OUTLINE" },
    { key = "countColor", type = "color", default = { 1, 1, 1, 1 } },
    { key = "countPoint", type = "enum", values = Settings.POINTS, default = "BOTTOMRIGHT" },
    { key = "countX", type = "int", min = -30, max = 30, default = -2 },
    { key = "countY", type = "int", min = -30, max = 30, default = 2 },
    { key = "arrowMode", type = "enum", values = { "RIGHT", "BELOW", "RIGHTCLICK" }, default = "RIGHTCLICK" },
    { key = "tooltip", type = "bool", default = true },
    -- Categories
    { key = "hideEmpty", type = "bool", default = true },
    { key = "order", type = "text", default = table.concat(Settings.CATEGORIES, ",") },
    -- Minimap button
    { key = "minimapShow", type = "bool", default = true },
    { key = "minimapAngle", type = "int", min = 0, max = 359, default = 225 },
}
for _, cat in ipairs(Settings.CATEGORIES) do
    DEFS[#DEFS + 1] = { key = "show_" .. cat, type = "bool", default = true }
end

local byKey = {}
for _, def in ipairs(DEFS) do byKey[def.key] = def end

function Settings.Def(key) return byKey[key] end
function Settings.All() return DEFS end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = x end
    return c
end

-- The value to store, or nil when v is not one of def's values.
local function validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" or v ~= v then return nil end
        v = math.floor(v + 0.5)
        return math.max(def.min, math.min(def.max, v))
    elseif t == "bool" then
        if type(v) == "boolean" then return v end
    elseif t == "enum" then
        for _, name in ipairs(def.values) do if name == v then return v end end
    elseif t == "color" then
        if type(v) ~= "table" or #v ~= 4 then return nil end
        for i = 1, 4 do
            if type(v[i]) ~= "number" or v[i] < 0 or v[i] > 1 then return nil end
        end
        return { v[1], v[2], v[3], v[4] }
    elseif t == "text" then
        if type(v) == "string" then return v end
    end
    return nil
end
Settings.Validate = validate

function Settings.Get(key)
    local def = byKey[key]
    if not def then return nil end
    local v = validate(def, ns.DB()[key])
    if v ~= nil then return copy(v) end
    return copy(def.default)
end

local listeners = {}
function Settings.OnChange(fn) listeners[#listeners + 1] = fn end

function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Set(key, value)
    local def = byKey[key]
    local v = def and validate(def, value)
    if v == nil then return false end
    ns.DB()[key] = v
    Settings.Changed(key)
    return true
end

-- Category order -----------------------------------------------------------

-- The stored order without unknown or repeated keys; categories it lacks
-- follow in their default order, so an older profile gains new ones.
function Settings.Order()
    local list, seen = {}, {}
    local known = {}
    for _, cat in ipairs(Settings.CATEGORIES) do known[cat] = true end
    for cat in tostring(Settings.Get("order")):gmatch("[^,]+") do
        if known[cat] and not seen[cat] then list[#list + 1] = cat; seen[cat] = true end
    end
    for _, cat in ipairs(Settings.CATEGORIES) do
        if not seen[cat] then list[#list + 1] = cat end
    end
    return list
end

function Settings.Position(cat)
    for i, c in ipairs(Settings.Order()) do if c == cat then return i end end
end

function Settings.MoveTo(cat, index)
    local list = Settings.Order()
    local from = Settings.Position(cat)
    if not from then return end
    index = math.max(1, math.min(#list, math.floor(index)))
    table.remove(list, from)
    table.insert(list, index, cat)
    Settings.Set("order", table.concat(list, ","))
end

-- Export / import -----------------------------------------------------------
-- "FC1;key=value;..." with only the values the profile holds. Text escapes
-- %, ; and = as %XX.

local FORMAT = "FC1"
local END_MARK = "end"   -- last entry: a cut-off string lacks it and is refused

local function escape(s)
    return (s:gsub("[%%;=]", function(c) return ("%%%02X"):format(c:byte()) end))
end
local function unescape(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function hex(c) return ("%02x"):format(math.floor(c * 255 + 0.5)) end

local function encode(def, v)
    local t = def.type
    if t == "int" then return ("%d"):format(v) end
    if t == "bool" then return v and "1" or "0" end
    if t == "enum" then return v end
    if t == "color" then return "#" .. hex(v[1]) .. hex(v[2]) .. hex(v[3]) .. hex(v[4]) end
    return escape(v)
end

local function decode(def, raw)
    local t = def.type
    if t == "int" then return raw:match("^%-?%d+$") and tonumber(raw) end
    if t == "bool" then
        if raw == "1" then return true elseif raw == "0" then return false end
        return nil
    end
    if t == "enum" then return raw end
    if t == "color" then
        local r, g, b, a = raw:match("^#(%x%x)(%x%x)(%x%x)(%x%x)$")
        if not r then return nil end
        return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
    end
    return unescape(raw)
end

function Settings.Export()
    local db, parts = ns.DB(), {}
    for _, def in ipairs(DEFS) do
        local v = db[def.key]
        if v ~= nil and validate(def, v) ~= nil then
            parts[#parts + 1] = def.key .. "=" .. encode(def, v)
        end
    end
    table.sort(parts)
    table.insert(parts, 1, FORMAT)
    parts[#parts + 1] = END_MARK
    return table.concat(parts, ";")
end

-- The active profile back to the defaults.
function Settings.Reset()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end

-- Replaces the active profile's values with the string's. Unknown keys
-- (a newer version's) are skipped; a string that is not ours changes
-- nothing.
function Settings.Import(str)
    if type(str) ~= "string" then return false, "IMPORT_FORMAT" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str ~= FORMAT then
        if str:sub(1, #FORMAT + 1) ~= FORMAT .. ";" or str:sub(-(#END_MARK + 1)) ~= ";" .. END_MARK then
            return false, "IMPORT_FORMAT"
        end
    end
    local values = {}
    for entry in str:sub(#FORMAT + 2):gmatch("[^;]+") do
        local key, raw = entry:match("^([%w_]+)=(.*)$")
        local def = key and byKey[key]
        local v = def and decode(def, raw)
        if v ~= nil then v = validate(def, v) end
        if v ~= nil then values[key] = v end
    end
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(values) do db[k] = v end
    Settings.Changed(nil)
    return true
end
