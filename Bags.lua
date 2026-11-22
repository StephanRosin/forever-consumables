--[[---------------------------------------------------------------------------
Bags.lua -- the consumables in the bags, per category. One entry per item
ID with its total count over all bags; an item of two categories stands in
both lists. Known spells of Items.SPELLS join their category (no count).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Bags = {}
ns.Bags = Bags

local function newEntry(id, info)
    local name, _, _, itemLevel, minLevel = C_Item.GetItemInfo(id)
    return {
        id = id,
        name = name or info.itemName or ("item:" .. id),
        icon = info.iconFileID,
        count = C_Item.GetItemCount(id) or 0,
        minLevel = minLevel or 0,
        itemLevel = itemLevel or 0,
        conjured = ns.Classify.IsConjured(id),
        buffFood = ns.Classify.IsBuffFood(id),
    }
end

function Bags.Scan()
    local byCat, seen = {}, {}
    for _, cat in ipairs(ns.Settings.CATEGORIES) do byCat[cat] = {} end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local cats = ns.Classify.Of(id)
                if #cats > 0 then
                    local entry = newEntry(id, info)
                    local conjured = entry.conjured and ns.Settings.Get("show_conjured")
                    for _, cat in ipairs(cats) do
                        -- Conjured food and water (also both at once) stand once in their own category.
                        if conjured and (cat == "food" or cat == "drink") then cat = "conjured" end
                        if byCat[cat][#byCat[cat]] ~= entry then table.insert(byCat[cat], entry) end
                    end
                end
            end
        end
    end
    for cat, ids in pairs(ns.Items.SPELLS) do
        for _, id in ipairs(ids) do
            if C_SpellBook.IsSpellKnown(id) then
                table.insert(byCat[cat], { id = id, spell = true, name = C_Spell.GetSpellName(id) or ("spell:" .. id),
                    icon = C_Spell.GetSpellTexture(id), minLevel = 0, itemLevel = 0 })
            end
        end
    end
    for _, list in pairs(byCat) do
        table.sort(list, function(a, b) return a.name < b.name end)
    end
    return byCat
end
