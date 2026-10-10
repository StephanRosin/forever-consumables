--[[---------------------------------------------------------------------------
Choice.lua -- which item a category's button uses. By hand (stored per
character) while that item is in the bags, otherwise the best one: usable at
your level, conjured first, then the higher required level, then the higher
item level. Buff food is never chosen automatically.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Choice = {}
ns.Choice = Choice

local function better(a, b)
    if a.conjured ~= b.conjured then return a.conjured end
    if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    return a.id > b.id
end

function Choice.Best(list, level)
    local best
    for _, e in ipairs(list) do
        if not e.buffFood and (e.minLevel or 0) <= level and (not best or better(e, best)) then best = e end
    end
    return best
end

function Choice.Resolve(list, chosenID, level)
    if chosenID then
        for _, e in ipairs(list) do
            if e.id == chosenID then return e, true end
        end
    end
    return Choice.Best(list, level), false
end

function Choice.Get(cat)
    local choice = ns.CharDB().choice
    return choice and choice[cat]
end

-- nil: automatic.
function Choice.Set(cat, id)
    local db = ns.CharDB()
    db.choice = db.choice or {}
    db.choice[cat] = id
end
