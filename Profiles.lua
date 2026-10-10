--[[---------------------------------------------------------------------------
Profiles.lua -- named profiles: the bar's layout and look; the chosen items and
the collapsed state are per character (ns.CharDB).

Split like AceDB and Details! do it:

    ForeverConsumablesProfiles   account wide   the profiles themselves
    ForeverConsumablesChar       per character  which profile is active

A character stores only the NAME of its profile, so two characters can share
one profile: they point to the same entry, not to a copy.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

-- Every character starts on this one.
local DEFAULT = "Default"
ns.DEFAULT_PROFILE = DEFAULT

local ready = false

-- Deep copy. Profiles must not share sub tables, or a change to one would
-- silently change the profile it was copied from.
local function Copy(t)
    if type(t) ~= "table" then return t end
    local new = {}
    for k, v in pairs(t) do new[k] = Copy(v) end
    return new
end

local function Init()
    if ready then return end
    ready = true

    ForeverConsumablesProfiles = ForeverConsumablesProfiles or {}
    ForeverConsumablesProfiles.profiles = ForeverConsumablesProfiles.profiles or {}
    ForeverConsumablesChar = ForeverConsumablesChar or {}

    local profiles, char = ForeverConsumablesProfiles.profiles, ForeverConsumablesChar
    if not char.active then
        char.active = DEFAULT
    end
    -- A new character, or its profile was deleted on another character:
    -- start from an empty profile (the defaults) rather than from nothing.
    if not profiles[char.active] then
        profiles[char.active] = {}
    end
end

-- The active profile's settings. Initialised lazily, so it does not matter
-- who asks first.
function ns.DB()
    Init()
    return ForeverConsumablesProfiles.profiles[ForeverConsumablesChar.active]
end

-- Account wide values outside the profiles (the language).
function ns.AccountDB()
    Init()
    return ForeverConsumablesProfiles
end

-- This character's own values: the chosen item per category, whether the
-- bar is collapsed, the probe's output.
function ns.CharDB()
    Init()
    return ForeverConsumablesChar
end

function ns.ActiveProfile()
    Init()
    return ForeverConsumablesChar.active
end

function ns.ProfileList()
    Init()
    local list = {}
    for name in pairs(ForeverConsumablesProfiles.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

local function applyLook()
    if ns.Settings and ns.Settings.Changed then ns.Settings.Changed(nil) end
end

-- Switches to a profile. A name that does not exist yet is created from the
-- CURRENT settings, so "save as" is the same operation.
function ns.SwitchProfile(name)
    if type(name) ~= "string" or name == "" then return false end
    Init()
    if not ForeverConsumablesProfiles.profiles[name] then
        ForeverConsumablesProfiles.profiles[name] = Copy(ns.DB())
    end
    ForeverConsumablesChar.active = name
    applyLook()
    return true
end

-- Copies another profile into the active one; you stay on your own profile.
function ns.CopyProfileFrom(name)
    Init()
    local source = ForeverConsumablesProfiles.profiles[name]
    if not source or name == ForeverConsumablesChar.active then return false end
    ForeverConsumablesProfiles.profiles[ForeverConsumablesChar.active] = Copy(source)
    applyLook()
    return true
end

-- Deletes a profile. If it was the active one, the character falls back to
-- the default profile instead of pointing to nothing.
function ns.DeleteProfile(name)
    Init()
    local profiles = ForeverConsumablesProfiles.profiles
    if not profiles[name] then return false end
    local wasActive = (ForeverConsumablesChar.active == name)
    profiles[name] = nil
    if wasActive then
        profiles[DEFAULT] = profiles[DEFAULT] or {}
        ForeverConsumablesChar.active = DEFAULT
        applyLook()
    end
    return true
end

-- Tests only: forget the lazy start.
function ns.ResetProfileState() ready = false end

-- ---------------------------------------------------------------------------
-- The dialogs behind the two profile buttons in the options. Written after
-- Blizzard's own dialogs: `hasEditBox = 1` and `dialog:GetEditBox()`. Their
-- text is set when they open, so it follows the chosen language.
-- ---------------------------------------------------------------------------
local function refreshOptions()
    if ns.Window and ns.Window.Refresh then pcall(ns.Window.Refresh) end
end

local function saveAs(name)
    if name and name ~= "" then
        ns.SwitchProfile(name)
        refreshOptions()
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs["FOREVERCONSUMABLES_PROFILE_NEW"] = {
        text = "",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 40,
        OnAccept = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            saveAs(box and box:GetText())
        end,
        EditBoxOnEnterPressed = function(editBox)
            saveAs(editBox:GetText())
            editBox:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
    }

    StaticPopupDialogs["FOREVERCONSUMABLES_PROFILE_DELETE"] = {
        text = "",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, name)
            ns.DeleteProfile(name)
            refreshOptions()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
    }
end

function ns.AskProfileName()
    if not StaticPopup_Show then return end
    StaticPopupDialogs["FOREVERCONSUMABLES_PROFILE_NEW"].text = L.POPUP_PROFILE_NAME
    StaticPopup_Show("FOREVERCONSUMABLES_PROFILE_NEW")
end

function ns.AskDeleteProfile()
    local name = ns.ActiveProfile()
    -- The last profile stays, or the character would have none.
    if #ns.ProfileList() <= 1 then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.ADDON_NAME .. ":|r " .. L.MSG_LAST_PROFILE)
        end
        return
    end
    if not StaticPopup_Show then return end
    StaticPopupDialogs["FOREVERCONSUMABLES_PROFILE_DELETE"].text = L.POPUP_PROFILE_DELETE
    StaticPopup_Show("FOREVERCONSUMABLES_PROFILE_DELETE", name, nil, name)
end
