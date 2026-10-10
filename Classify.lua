--[[---------------------------------------------------------------------------
Classify.lua -- an item's categories. Many Classic consumables carry the
subclass "Consumable" (0), so the subclass alone cannot sort them. In order:
the hand-made lists (Data/Items.lua), the use spell's name compared with
reference spells in the client's language (Food, Drink, Refreshment,
Healing Potion, Restore Mana, First Aid), then the subclass. Any other
potion goes to "potions", so new potions show without a list update.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Items = ns.Items

local Classify = {}
ns.Classify = Classify

Classify.SPELLS = { food = 433, drink = 430, refreshment = 167152, healingPotion = 441, restoreMana = 437,
    firstAid = 746, wellFed = 19705 }

-- Retail-style consumable subclasses; Forever's data uses them (checked
-- with /fcon scan: potions 1, food and drink 5).
local SUBCLASS = { [1] = "potions", [2] = "elixirs", [3] = "flasks", [4] = "scrolls", [5] = "food", [7] = "bandages" }

local names, cache = nil, {}

-- The reference names, and whether all of them resolved. The client may
-- not know some spells right after login; a table with holes is not kept,
-- so the next call asks again.
local function Names()
    if names then return names, true end
    local found, complete = {}, true
    for key, id in pairs(Classify.SPELLS) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
        found[key] = name
        if not name then complete = false end
    end
    if complete then names = found end
    return found, complete
end

function Classify.Reset() names, cache = nil, {} end

local BY_SPELL = {
    { "refreshment", { "food", "drink" } },
    { "food", { "food" } },
    { "drink", { "drink" } },
    { "healingPotion", { "healing" } },
    { "restoreMana", { "mana" } },
    { "firstAid", { "bandages" } },
}

local function copy(t) local c = {} for i, v in ipairs(t) do c[i] = v end return c end

local function compute(id)
    if Items.CATEGORY[id] then return copy(Items.CATEGORY[id]), true end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    if classID ~= 0 then return {}, classID ~= nil end
    local spell = C_Item.GetItemSpell(id)
    local complete = true
    if spell then
        local n
        n, complete = Names()
        for _, rule in ipairs(BY_SPELL) do
            if n[rule[1]] and spell == n[rule[1]] then return copy(rule[2]), true end
        end
    end
    -- Without all reference names the subclass guess may be wrong: not final.
    local cat = SUBCLASS[subclassID]
    if cat then return { cat }, complete end
    return {}, spell ~= nil and complete
end

-- Cached once the client knows the item well enough to decide.
function Classify.Of(id)
    if cache[id] then return copy(cache[id]) end
    local cats, sure = compute(id)
    if sure then cache[id] = cats end
    return copy(cats)
end

function Classify.IsConjured(id) return Items.CONJURED[id] == true end

-- Listed, or its use spell's text names the "Well Fed" buff.
function Classify.IsBuffFood(id)
    if Items.BUFF_FOOD[id] then return true end
    local _, spellID = C_Item.GetItemSpell(id)
    local wellFed = Names().wellFed
    if not spellID or not wellFed then return false end
    local desc = C_Spell.GetSpellDescription(spellID)
    return type(desc) == "string" and desc:lower():find(wellFed:lower(), 1, true) ~= nil
end
