--[[---------------------------------------------------------------------------
Visibility.lua -- when the bar shows. The state driver handles what macro
conditions can say ([combat], [dead], [nogroup]) and so works in combat.
Instance and taxi have no condition: they are decided here and the driver
is rebuilt when they change (always out of combat in practice).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Visibility = {}
ns.Visibility = Visibility

local BASE = { ALWAYS = "show", COMBAT = "[combat] show; hide", NOCOMBAT = "[combat] hide; show", NEVER = "hide" }

function Visibility.Driver(get, env)
    local mode = get("visMode")
    if mode == "NEVER" then return "hide" end
    if get("visInstance") and not env.inInstance then return "hide" end
    if get("visHideTaxi") and env.onTaxi then return "hide" end
    local parts = {}
    if get("visHideDead") then parts[#parts + 1] = "[dead] hide" end
    if get("visGroup") then parts[#parts + 1] = "[nogroup] hide" end
    parts[#parts + 1] = BASE[mode] or "show"
    return table.concat(parts, "; ")
end

-- Dungeons and raids count; battlegrounds and arenas do not.
function Visibility.Env()
    local inside, kind = IsInInstance()
    return {
        inInstance = (inside and (kind == "party" or kind == "raid")) and true or false,
        onTaxi = UnitOnTaxi("player") and true or false,
    }
end

function Visibility.Alpha(get, inCombat, mouseOver)
    if mouseOver and get("fadeMouseover") then return 1 end
    return (inCombat and get("alphaCombat") or get("alphaNoCombat")) / 100
end
