--[[---------------------------------------------------------------------------
Media.lua -- the fonts to choose from: the game's four and any that
LibSharedMedia knows. "DEFAULT" is the game's normal font.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Media = ns.Media or {}
ns.Media = Media

Media.FONTS = {
    { key = "DEFAULT" },
    { key = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
}

function Media.Fonts()
    local list, seen = {}, {}
    for _, f in ipairs(Media.FONTS) do list[#list + 1] = f; seen[f.key] = true end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List("font") or {}
        table.sort(names)
        for _, name in ipairs(names) do
            if not seen[name] then list[#list + 1] = { key = name, path = LSM:Fetch("font", name) } end
        end
    end
    return list
end

function Media.FontPath(key)
    for _, f in ipairs(Media.Fonts()) do
        if f.key == key and f.path then return f.path end
    end
    return "Fonts\\FRIZQT__.TTF"
end
