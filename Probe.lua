--[[---------------------------------------------------------------------------
Probe.lua -- records what the client says about items, for checking the
lists and the classification: /fcon scan (every item in the bags) and
/fcon ids (every listed ID: its name, or false). Written to
ForeverConsumablesChar; /reload saves it to the WTF folder.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local function bagItems()
    local seen, list = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not seen[info.itemID] then
                seen[info.itemID] = true
                list[#list + 1] = info.itemID
            end
        end
    end
    table.sort(list)
    return list
end

ns.Slash.scan = function()
    local out = {}
    for _, id in ipairs(bagItems()) do
        local name, _, _, itemLevel, minLevel, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(id)
        local spell, spellID = C_Item.GetItemSpell(id)
        out[#out + 1] = { id = id, name = name, classID = classID, subclassID = subclassID, spell = spell,
            spellID = spellID, itemLevel = itemLevel, minLevel = minLevel,
            cats = table.concat(ns.Classify.Of(id), ","), buffFood = ns.Classify.IsBuffFood(id) }
    end
    local spells = {}
    for key, id in pairs(ns.Classify.SPELLS) do spells[key] = C_Spell.GetSpellName(id) or false end
    local db = ns.CharDB()
    db.scan, db.scanSpells = out, spells
    ns.Print(("scan: %d items recorded, /reload to save"):format(#out))
end

ns.Slash.ids = function()
    local ids = {}
    for _, list in pairs(ns.Items.LISTS) do
        for _, id in ipairs(list) do ids[id] = true end
    end
    for id in pairs(ns.Items.BUFF_FOOD) do ids[id] = true end
    for id in pairs(ns.Items.CONJURED) do ids[id] = true end
    for id in pairs(ids) do C_Item.RequestLoadItemDataByID(id) end
    -- Names arrive asynchronously; read them a moment later.
    C_Timer.After(3, function()
        local result, missing = {}, 0
        for id in pairs(ids) do
            local name = C_Item.GetItemInfo(id)
            result[id] = name or false
            if not name then missing = missing + 1 end
        end
        ns.CharDB().ids = result
        ns.Print(("ids: %d missing, /reload to save"):format(missing))
    end)
end
