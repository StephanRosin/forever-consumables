--[[---------------------------------------------------------------------------
Data/Items.lua -- items sorted by hand: those the use spell and the item
subclass cannot place (runes, gems, healthstones, Juju, Zanza, the Blasted
Lands buffs, protection and combat potions). Checked in the client with
/fcon ids. An item may stand in two lists (Major Rejuvenation Potion).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Items = {}
ns.Items = Items

Items.LISTS = {
    healing = {
        118, 858, 929, 1710, 3928, 13446,           -- Minor .. Major Healing Potion
        5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013, -- healthstones
        11951,                                      -- Whipper Root Tuber (Felwood)
        18253, 9144,                                -- Major Rejuvenation, Wildvine Potion
    },
    mana = {
        2455, 3385, 3827, 6149, 13443, 13444,       -- Minor .. Major Mana Potion
        5514, 5513, 8007, 8008,                     -- Mana Agate, Jade, Citrine, Ruby
        11952,                                      -- Night Dragon's Breath (Felwood)
        20520, 12662,                               -- Dark Rune, Demonic Rune
        18253, 9144,
    },
    potions = {
        5631, 5633, 13442,                          -- Rage, Great Rage, Mighty Rage Potion
        2459, 3823, 9172,                           -- Swiftness, Lesser Invisibility, Invisibility
        3387, 9036,                                 -- Limited Invulnerability, Magic Resistance
        7676,                                       -- Thistle Tea
        12190,                                      -- Dreamless Sleep Potion
    },
    flasks = { 13510, 13511, 13512, 13513, 13506 }, -- Titans, Distilled Wisdom, Supreme Power, Chromatic Resistance, Petrification
    elixirs = {
        12450, 12451, 12455, 12457, 12458, 12459, 12460, -- Juju Flurry, Power, Ember, Chill, Guile, Escape, Might
        20079, 20080, 20081,                        -- Spirit of Zanza, Sheen of Zanza, Swiftness of Zanza
        8410, 8411, 8412, 8423, 8424,               -- R.O.I.D.S., Lung Juice, Ground Scorpok Assay, Cerebral Cortex, Gizzard Gum
        12820,                                      -- Winterfall Firewater
        13452, 9206, 9187, 8949, 3390, 2457,        -- Mongoose, Greater Strength, Greater/-/Lesser/Minor Agility
        9179, 9264, 13454, 9155, 21546, 6373, 17708, -- Greater Intellect, Shadow Power, Greater Arcane, Arcane, Holy Power, Fire Power, Frost Power
        3825, 13445, 8951, 3389, 5997,              -- Lesser Fortitude, Greater/-/Lesser/Minor Defense
        13453, 20007, 20004, 3826, 3388, 3382,      -- Brute Force, Mageblood, Major/Mighty/Strong/Weak Troll's Blood
        9088, 9224, 9154, 9233, 6662, 5996, 18294,  -- Gift of Arthas, Demonslaying, Detect Undead, Detect Demon, Giant Growth, Water Breathing, Greater Water Breathing
        2454, 3391, 3383, 2458, 8529,               -- Lion's Strength, Ogre's Strength, Wisdom, Minor Fortitude, Noggenfogger
    },
    protection = {
        6049, 13457, 6050, 13456, 6052, 13458, 6048, 13459, 13461, 6051, -- Fire, Frost, Nature, Shadow (+Greater), Greater Arcane, Holy
        5634, 20008, 9030, 13462, 13455,            -- Free Action, Living Action, Restorative, Purification, Greater Stoneshield
    },
    scrolls = {
        3012, 1477, 4425, 10309, 955, 2290, 4419, 10308, 3013, 1478, 4421, 10305,
        1181, 1712, 4424, 10306, 1180, 1711, 4422, 10307, 954, 2289, 4426, 10310,
    },
    bandages = { 1251, 2581, 3530, 3531, 6450, 6451, 8544, 8545, 14529, 14530 },
}

-- Conjured items go first: they vanish when you log out long enough.
Items.CONJURED = {}
for _, id in ipairs({
    5350, 2288, 2136, 3772, 8077, 8078, 8079,       -- Conjured Water .. Crystal Water
    5349, 1113, 1114, 1487, 8075, 8076,             -- Conjured Muffin .. Cinnamon Roll
    5514, 5513, 8007, 8008,                         -- mana gems
    5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013,
}) do Items.CONJURED[id] = true end

-- Buff food the automatic choice never takes.
Items.BUFF_FOOD = {}
for _, id in ipairs({
    21023, 20452, 13928, 13931, 18254, 12218, 21072, 21217, 18045, 12216, 12215, 6888, 2680, 13929, 13927,
}) do Items.BUFF_FOOD[id] = true end

Items.CATEGORY = {}
for cat, ids in pairs(Items.LISTS) do
    for _, id in ipairs(ids) do
        local cats = Items.CATEGORY[id] or {}
        cats[#cats + 1] = cat
        Items.CATEGORY[id] = cats
    end
end
-- Two lists: the category order decides the order of the result.
local rank = {}
for i, cat in ipairs(ns.Settings.CATEGORIES) do rank[cat] = i end
for _, cats in pairs(Items.CATEGORY) do
    table.sort(cats, function(a, b) return rank[a] < rank[b] end)
end
