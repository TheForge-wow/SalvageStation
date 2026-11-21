-- Salvage Station: market prices (TSM first, then Auctionator), vendor prices.
-- Adapter approach adapted from Disenchantry (MIT). See NOTICE.txt.
local ADDON, ns = ...
local P = {}
ns.Prices = P

local function positive(v)
    if issecretvalue and issecretvalue(v) then return end
    if type(v) == "number" and v > 0 and v < math.huge then return v end
end

local function AuctionatorDays()
    local cfg = Auctionator and Auctionator.Config
    if cfg and type(cfg.Get) == "function" and cfg.Options and cfg.Options.AUCTION_MEAN_DAYS_LIMIT then
        local ok, d = pcall(cfg.Get, cfg.Options.AUCTION_MEAN_DAYS_LIMIT)
        if ok and type(d) == "number" and d >= 1 then return math.floor(d) end
    end
    return 21
end
P.AuctionatorDays = AuctionatorDays

local adapters = {
    tsm = {
        label = "TSM",
        present = function()
            return TSM_API and type(TSM_API.ToItemString) == "function" and type(TSM_API.GetCustomPriceValue) == "function"
        end,
        quote = function(id)
            local s = TSM_API.ToItemString("item:" .. id)
            if s then return TSM_API.GetCustomPriceValue("DBMarket", s) end
        end,
    },
    auctionator = {
        label = "Auctionator",
        present = function()
            if ns.opts.auctionatorMode == "average" then
                return Auctionator and Auctionator.Database and type(Auctionator.Database.GetMeanPrice) == "function"
            end
            local api = Auctionator and Auctionator.API and Auctionator.API.v1
            return api and type(api.GetAuctionPriceByItemID) == "function"
        end,
        quote = function(id)
            if ns.opts.auctionatorMode == "average" then
                return Auctionator.Database:GetMeanPrice(tostring(id), AuctionatorDays())
            end
            return Auctionator.API.v1.GetAuctionPriceByItemID(ADDON, id)
        end,
    },
}
local ORDER = { "tsm", "auctionator" }

local function available(a)
    local ok, yes = pcall(a.present)
    return ok and yes and true or false
end

local cache = {}
function P.ClearCache() wipe(cache) end

-- Market value of an item (copper), plus the source label
function P.Market(ref)
    local id = ns.ItemID(ref)
    if not id then return end
    local now = GetTime()
    local key = (ns.opts.priceSource or "auto") .. ":" .. (ns.opts.auctionatorMode or "last") .. ":" .. id
    local c = cache[key]
    if c and c.t > now then return c.v, c.label end
    local order = ORDER
    if ns.opts.priceSource == "tsm" or ns.opts.priceSource == "auctionator" then order = { ns.opts.priceSource } end
    local value, label
    for _, k in ipairs(order) do
        local a = adapters[k]
        if available(a) then
            local ok, v = pcall(a.quote, id)
            v = ok and positive(v) or nil
            if v then value, label = v, a.label; break end
        end
    end
    cache[key] = { v = value, label = label, t = now + 60 }
    return value, label
end

function P.Vendor(ref)
    local v = select(11, ns.ItemInfo(ref))
    return v or 0
end

-- Name of the source that will be used, or nil
function P.Source()
    local order = ORDER
    if ns.opts.priceSource == "tsm" or ns.opts.priceSource == "auctionator" then order = { ns.opts.priceSource } end
    for _, k in ipairs(order) do
        if available(adapters[k]) then return adapters[k].label end
    end
end

function P.Status()
    local s = {}
    for _, k in ipairs(ORDER) do s[#s + 1] = adapters[k].label .. "=" .. (available(adapters[k]) and "yes" or "no") end
    return table.concat(s, ", ")
end
