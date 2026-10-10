--[[---------------------------------------------------------------------------
Picker.lua -- the list behind a button's arrow (or its right click):
"Automatic (best)" and every item of the category in the bags with its
count. Out of combat only, as choosing changes a secure button. Also the
buttons' tooltip.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local S, Choice, Bar = ns.Settings, ns.Choice, ns.Bar

local Picker = {}
ns.Picker = Picker

local function catLabel(cat) return L["CAT_" .. cat:upper()] end

local function choose(cat, id)
    Choice.Set(cat, id)
    Bar.Refresh()
end

function Picker.Open(owner, cat)
    if InCombatLockdown() then return end
    local list = Bar.ListOf(cat)
    local function chosenHere()
        local id = Choice.Get(cat)
        for _, e in ipairs(list) do if e.id == id then return id end end
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(catLabel(cat))
        root:CreateRadio(L.PICK_AUTO, function() return chosenHere() == nil end, function() choose(cat, nil) end)
        for _, e in ipairs(list) do
            local text = ("|T%s:16|t %s (%d)"):format(tostring(e.icon), e.name, C_Item.GetItemCount(e.id) or 0)
            root:CreateRadio(text, function() return chosenHere() == e.id end, function() choose(cat, e.id) end)
        end
    end)
end

function Picker.Tooltip(button)
    if not S.Get("tooltip") then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.entry then
        GameTooltip:SetItemByID(button.entry.id)
    else
        GameTooltip:SetText(catLabel(button.cat))
    end
    GameTooltip:AddLine(L.TIP_USE, 1, 1, 1)
    GameTooltip:AddLine(S.Get("arrowMode") == "RIGHTCLICK" and L.TIP_PICK_RIGHT or L.TIP_PICK_ARROW, 1, 1, 1)
    GameTooltip:Show()
end

Bar.onPick = Picker.Open
Bar.onEnter = Picker.Tooltip
