--[[---------------------------------------------------------------------------
Bags.lua -- the consumables in the bags, per category. One entry per item
ID with its total count over all bags; an item of two categories stands in
both lists.
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
                    for _, cat in ipairs(cats) do table.insert(byCat[cat], entry) end
                end
            end
        end
    end
    for _, list in pairs(byCat) do
        table.sort(list, function(a, b) return a.name < b.name end)
    end
    return byCat
end
