--[[---------------------------------------------------------------------------
Core.lua -- the event bus, work deferred until combat ends, chat output and
the slash command.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
ns.ADDON = ADDON

local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

-- Several modules listen to the same event; each gets it in the order it
-- registered.
function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

-- Runs fn now, or once when combat ends. Protected frames cannot change in
-- combat; the latest fn per key wins, so repeated requests run once.
local pending = {}
function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        pending[key] = nil
        fn()
        return
    end
    pending[key] = fn
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local run = pending
    pending = {}
    for _, fn in pairs(run) do fn() end
end)

function ns.GetAddOnMetadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, field)
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. ns.L.ADDON_NAME .. ":|r " .. tostring(msg))
end

-- Sub-commands: other files add theirs; "" opens the options.
ns.Slash = {}
SLASH_FOREVERCONSUMABLES1 = "/fcon"
SLASH_FOREVERCONSUMABLES2 = "/foreverconsumables"
SlashCmdList.FOREVERCONSUMABLES = function(msg)
    local sub, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    local fn = ns.Slash[sub]
    if fn then fn(rest) else ns.Print(ns.L.SLASH_HELP) end
end
