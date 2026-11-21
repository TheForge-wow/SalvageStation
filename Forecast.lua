-- Salvage Station: what an item turns into, learned results, expected values.
local ADDON, ns = ...
local F = {}
ns.Forecast = F

-- Learned results take over from the tables once a bucket has this many samples
F.LEARN_MIN = 10

-- Learning groups items by quality, item-level band and armor/weapon (like the drop tables)
local function Bucket(item, boosted)
    if not item or not item.quality or not item.baseIlvl then return end
    local band = ns.Data.Band(item.itemID, item.quality, item.baseIlvl)
    return table.concat({ item.quality, band, item.classID == 2 and "W" or "A", boosted and "S" or "N" }, ":")
end
F.Bucket = Bucket

local QNAME = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }
-- "Uncommon armor 21-25" for a bucket key
function F.BucketName(key)
    local q, band, kind, boost = key:match("^(%d):([^:]+):([AW]):([SN])$")
    if not q then return key end
    local name
    local id = tonumber(band:match("^I(%d+)$") or "")
    if id then name = ns.ItemName(id)
    else name = (QNAME[tonumber(q)] or "") .. " " .. (kind == "W" and "weapon" or "armor") .. " " .. band end
    if boost == "S" then name = name .. " (Salvager)" end
    return name, tonumber(q)
end

-- How far learning has come for an item: samples, learned?
function F.Progress(item)
    local key = Bucket(item, ns.HasSalvagerBuff())
    local s = key and ns.db.samples[key]
    local n = s and s.n or 0
    return n, n >= F.LEARN_MIN, key
end

-- One-time: merge results saved per exact item level into item-level bands
function F.Migrate()
    if ns.db.samplesVersion == 2 then return end
    local old = ns.db.samples
    local new = {}
    for key, s in pairs(old) do
        local q, lvl, kind, boost = key:match("^(%d):(%d+):([AW]):([SN])$")
        local nk = key
        if q then
            nk = table.concat({ q, ns.Data.Band(nil, tonumber(q), tonumber(lvl)), kind, boost }, ":")
        end
        local t = new[nk]
        if not t then t = { n = 0, items = {} }; new[nk] = t end
        t.n = t.n + (s.n or 0)
        for id, r in pairs(s.items or {}) do
            local m = t.items[id]
            if not m then m = { total = 0, hits = 0, min = r.min, max = r.max }; t.items[id] = m end
            m.total, m.hits = m.total + (r.total or 0), m.hits + (r.hits or 0)
            m.min, m.max = math.min(m.min or r.min, r.min or m.min), math.max(m.max or r.max, r.max or m.max)
        end
    end
    ns.db.samples = new
    ns.db.samplesVersion = 2
end
ns.Listen("LOADED", F.Migrate)

-- Results for one disenchant: list of { id, chance, min, max, exp }, source, samples
function F.Get(item)
    if not item then return end
    local boosted = ns.HasSalvagerBuff()
    local key = Bucket(item, boosted)
    local s = key and ns.db.samples[key]
    if s and s.n and s.n >= F.LEARN_MIN and type(s.items) == "table" then
        local out = {}
        for id, r in pairs(s.items) do
            out[#out + 1] = { id = id, chance = r.hits / s.n, min = r.min, max = r.max, exp = r.total / s.n }
        end
        table.sort(out, function(a, b) return a.exp > b.exp end)
        return out, "learned", s.n
    end
    local t, src = ns.Data.Table(item.itemID, item.quality, item.baseIlvl, item.classID)
    if not t then return nil, "none", s and s.n or 0 end
    local out = {}
    for _, r in ipairs(t) do
        out[#out + 1] = { id = r[1], chance = r[2], min = r[3], max = r[4], exp = r[2] * (r[3] + r[4]) / 2 }
    end
    table.sort(out, function(a, b) return a.exp > b.exp end)
    return out, src, s and s.n or 0
end

-- Expected market value of the materials from one disenchant (copper), or nil if a price is missing
function F.Value(item)
    local res = F.Get(item)
    if not res then return end
    local total = 0
    for _, r in ipairs(res) do
        local p = ns.Prices.Market(r.id)
        if not p then return nil end
        total = total + r.exp * p
    end
    return total
end

-- Store one real result
function F.Record(item, materials, boosted)
    local key = Bucket(item, boosted)
    if not key or not next(materials) then return end
    local s = ns.db.samples[key]
    if type(s) ~= "table" then s = { n = 0, items = {} }; ns.db.samples[key] = s end
    s.n = s.n + 1
    if s.n == F.LEARN_MIN then ns.Fire("LEARNED", key) end
    for id, qty in pairs(materials) do
        local r = s.items[id]
        if not r then r = { total = 0, hits = 0, min = qty, max = qty }; s.items[id] = r end
        r.total, r.hits = r.total + qty, r.hits + 1
        r.min, r.max = math.min(r.min, qty), math.max(r.max, qty)
    end
end

function F.SourceText(src, n)
    if src == "learned" then return "|cff52de7cBased on " .. n .. " of your own disenchants|r" end
    if src == "forever" then return "|cff8a8b94WoW Forever estimate" .. (n > 0 and (" · learning " .. n .. "/" .. F.LEARN_MIN) or "") .. "|r" end
    if src == "table" then return "|cff8a8b94Estimate from standard drop rates" .. (n > 0 and (" · learning " .. n .. "/" .. F.LEARN_MIN) or "") .. "|r" end
    return "|cff8a8b94No data yet - learns as you disenchant" .. (n > 0 and (" (" .. n .. "/" .. F.LEARN_MIN .. ")") or "") .. "|r"
end

-- "75% Strange Dust x1.85 [2-3]" (TSM style)
function F.LineText(r)
    local q = ns.ItemQuality(r.id)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex or "|cffffffff"
    local range = (r.min == r.max) and ("[" .. r.min .. "]") or ("[" .. r.min .. "-" .. r.max .. "]")
    return color .. ns.Pct(r.chance) .. "% " .. ns.ItemName(r.id) .. " x" .. ns.Num(r.exp) .. "|r |cff616269" .. range .. "|r"
end

-- Auction house cut taken from a sale
F.AH_CUT = 0.05

-- Best way to get gold from an item.
-- Returns { de, vendor, ah (after the cut, or nil), ahGross, ahWhy ("soulbound"/"noprice"/"small"),
--           best = "de"/"vendor"/"ah", second = the runner-up key, gain = best minus runner-up }
function F.Best(itemID, vendor, isBound, de)
    local o = ns.opts
    local r = { de = de, vendor = vendor or 0 }
    if isBound then
        r.ahWhy = "soulbound"
    else
        local gross = ns.Prices.Market(itemID)
        if not gross then
            r.ahWhy = "noprice"
        else
            r.ahGross = gross
            local net = gross * (1 - F.AH_CUT)
            -- only suggest the auction house when it clearly beats a vendor
            local min = (o.ahMinOn and (o.ahMin or 0) > 0) and o.ahMin * 10000 or 0
            if net > r.vendor + min then r.ah = net else r.ahWhy = "small"; r.ahNet = net end
        end
    end
    local options = {}
    if r.de then options[#options + 1] = { "de", r.de } end
    options[#options + 1] = { "vendor", r.vendor }
    if r.ah then options[#options + 1] = { "ah", r.ah } end
    table.sort(options, function(a, b) return a[2] > b[2] end)
    r.best = options[1][1]
    if options[2] then r.second, r.gain = options[2][1], options[1][2] - options[2][2] end
    return r
end

F.USE_LABEL = { de = "disenchanting", vendor = "vendoring", ah = "auctioning" }
F.USE_VERB = { de = "Disenchant", vendor = "Vendor it", ah = "Auction it" }
