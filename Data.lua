-- Salvage Station: disenchant data for WoW Forever / original-era items.
-- Tables and the WoW Forever specifics (weapon essence quirk, crafted-rare
-- estimates, wands that can't be disenchanted) are adapted from Disenchantry
-- (MIT License, (c) 2026 x_Raven_x, (c) 2026 Rakuga). See NOTICE.txt.
local ADDON, ns = ...
local D = {}
ns.Data = D

ns.MATERIAL_NAMES = {
    [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust",
    [11176] = "Dream Dust", [16204] = "Illusion Dust",
    [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence",
    [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence",
    [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence",
    [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence",
    [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard",
    [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
    [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard",
    [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard",
    [20725] = "Nexus Crystal",
}

-- Uncommon: lo, hi, dust, essence, shard, dust% armor, ess% armor, dust% weapon, ess% weapon,
-- dust min/max, essence min/max. Shards yield one; shard chance = remainder.
local UNCOMMON = {
    { 5, 15, 10940, 10938, nil,   80, 20, 20, 80, 1, 2, 1, 2 },
    { 16, 20, 10940, 10939, 10978, 75, 20, 20, 75, 2, 3, 1, 2 },
    { 21, 25, 10940, 10998, 10978, 75, 15, 15, 75, 4, 6, 1, 2 },
    { 26, 30, 11083, 11082, 11084, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 31, 35, 11083, 11134, 11138, 75, 20, 20, 75, 2, 5, 1, 2 },
    { 36, 40, 11137, 11135, 11139, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 41, 45, 11137, 11174, 11177, 75, 20, 20, 75, 2, 5, 1, 2 },
    { 46, 50, 11176, 11175, 11178, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 51, 55, 11176, 16202, 14343, 75, 20, 22, 75, 2, 5, 1, 2 },
    { 56, 60, 16204, 16203, 14344, 75, 20, 22, 75, 1, 2, 1, 2 },
    { 61, 65, 16204, 16203, 14344, 75, 20, 22, 75, 2, 5, 2, 3 },
}
local RARE = {
    { 1, 25, 10978 }, { 26, 30, 11084 }, { 31, 35, 11138 }, { 36, 40, 11139 },
    { 41, 45, 11177 }, { 46, 50, 11178 }, { 51, 55, 14343 }, { 56, 80, 14344, 20725 },
}
local EPIC = {
    { 1, 45, 11177, 2, 4 }, { 46, 50, 11178, 2, 4 }, { 51, 55, 14343, 2, 4 },
    { 56, 60, 20725, 1, 1 }, { 61, 88, 20725, 1, 2 },
}

-- Enchanter-made wands can't be disenchanted
local NO_DE = { [11287] = true, [11288] = true, [11289] = true, [11290] = true }
local NO_DE_FOREVER = {
    [247789] = true, [249144] = true, [249234] = true, [249232] = true, [249237] = true, [249385] = true,
}

-- Estimates for specific new WoW Forever crafted items
local LOW_CRAFT = { { 10940, 0.80, 2, 3 }, { 10938, 0.20, 2, 3 } }
local MID_CRAFT = { { 10940, 0.75, 3, 4 }, { 10939, 0.20, 2, 3 }, { 10978, 0.05, 2, 2 } }
local OVERRIDES = {}
for _, id in ipairs({ 250620, 250482, 250621, 252424, 252425, 252426, 252427, 253885, 253887 }) do
    OVERRIDES[id] = LOW_CRAFT
end
for _, id in ipairs({ 250513, 250514, 250515, 250516, 250517, 250508, 250509, 250510, 250511, 250512, 250489,
    252428, 252429, 252430, 252431, 252432, 252433, 252494, 252495, 252496, 252497, 252498, 252499,
    253889, 253891, 253893, 253895, 253897, 253899, 253901, 253903, 253905, 253907, 253909, 253911,
    253913, 253915, 253917, 253919, 253921, 253923 }) do
    OVERRIDES[id] = MID_CRAFT
end

function D.IsExcluded(id)
    id = ns.ItemID(id)
    return id ~= nil and (NO_DE[id] or (ns.isForever and NO_DE_FOREVER[id])) and true or false
end

local function find(rows, level)
    for _, r in ipairs(rows) do
        if level >= r[1] and level <= r[2] then return r end
    end
end

-- Estimate for new WoW Forever rares (item IDs 200000+) without a specific entry
local function ForeverRare(classID, level)
    local weapon = classID == 2
    if level <= 15 then
        return { { 10940, weapon and 0.20 or 0.80, 2, 3 }, { 10938, weapon and 0.80 or 0.20, 2, 3 } }
    elseif level <= 20 then
        return { { 10940, weapon and 0.20 or 0.75, 3, 4 }, { 10939, weapon and 0.75 or 0.20, 2, 3 }, { 10978, 0.05, 2, 2 } }
    end
    local r = find(RARE, level)
    if not r then return end
    if r[4] then return { { r[3], 0.995, 1, 1 }, { r[4], 0.005, 1, 1 } } end
    return { { r[3], 1, 1, 1 } }
end

-- Returns a list of { id, chance (0-1), min, max } and a source tag, or nil
function D.Table(itemID, quality, level, classID)
    if not quality or not level or level <= 0 then return end
    if classID ~= 2 and classID ~= 4 then return end
    if D.IsExcluded(itemID) then return end
    if ns.isForever and itemID and OVERRIDES[itemID] then return OVERRIDES[itemID], "forever" end
    if ns.isForever and itemID and itemID >= 200000 and quality == 3 and level >= 5 and level <= 99 then
        local t = ForeverRare(classID, level)
        if t then return t, "forever" end
    end
    if not ns.vanillaData then return end

    if quality == 2 then
        local r = find(UNCOMMON, level)
        if not r then return end
        local weapon = classID == 2
        local dust, ess = r[weapon and 8 or 6], r[weapon and 9 or 7]
        local essID = r[4]
        -- WoW Forever: uncommon weapons ilvl 21-30 give Greater Magic Essence
        if ns.isForever and weapon and level >= 21 and level <= 30 then essID = 10939 end
        local out = { { r[3], dust / 100, r[10], r[11] }, { essID, ess / 100, r[12], r[13] } }
        if r[5] then out[#out + 1] = { r[5], (100 - dust - ess) / 100, 1, 1 } end
        return out, "table"
    elseif quality == 3 then
        local r = find(RARE, level)
        if not r then return end
        if r[4] then return { { r[3], 0.995, 1, 1 }, { r[4], 0.005, 1, 1 } }, "table" end
        return { { r[3], 1, 1, 1 } }, "table"
    elseif quality == 4 then
        if level < 40 then
            local r = find(RARE, level)
            return r and { { r[3], 1, 1, 1 } } or nil, "table"
        end
        local r = find(EPIC, level)
        if r then return { { r[3], 1, r[4], r[5] } }, "table" end
    end
end

-- Item-level band an item belongs to for learning ("21-25"), or a per-item key for
-- WoW Forever items that have their own estimate. Falls back to the exact level.
function D.Band(itemID, quality, level)
    if ns.isForever and itemID and OVERRIDES[itemID] then return "I" .. itemID end
    local r
    if quality == 2 then r = find(UNCOMMON, level)
    elseif quality == 3 then
        if ns.isForever and itemID and itemID >= 200000 and level <= 20 then
            return level <= 15 and "1-15" or "16-20"
        end
        r = find(RARE, level)
    elseif quality == 4 then
        r = level < 40 and find(RARE, level) or find(EPIC, level)
    end
    if r then return r[1] .. "-" .. r[2] end
    return tostring(level)
end

-- Enchanting skill needed by item level (original tables). Soft warning only.
local SKILL = { { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 },
                { 50, 150 }, { 55, 175 }, { 60, 200 }, { 999, 225 } }
function D.RequiredSkill(level)
    for _, s in ipairs(SKILL) do
        if level <= s[1] then return s[2] end
    end
    return 225
end
