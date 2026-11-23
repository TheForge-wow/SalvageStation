-- Salvage Station: auction house scanner for gear worth more disenchanted than its price.
-- Scanning and buying logic adapted from Disenchantry's AuctionScan/AuctionPurchase
-- (MIT License, (c) 2026 x_Raven_x). See NOTICE.txt.
local ADDON, ns = ...
local Scan = { rows = {}, state = "idle", checked = 0, skipped = 0, interval = 5 }
local Buy = { state = "idle" }
ns.AuctionScan, ns.AuctionBuy = Scan, Buy

local function changed() ns.Fire("AUCTION") end

local function identity(key)
    return table.concat({ key.itemID or 0, key.itemLevel or 0, key.itemSuffix or 0, key.battlePetSpeciesID or 0 }, ":")
end

function Scan.Supported()
    local api = C_AuctionHouse
    for _, n in ipairs({ "SendBrowseQuery", "GetBrowseResults", "HasFullBrowseResults", "RequestMoreBrowseResults",
        "SendSearchQuery", "GetNumItemSearchResults", "GetItemSearchResultInfo", "HasFullItemSearchResults",
        "RequestMoreItemSearchResults" }) do
        if not api or type(api[n]) ~= "function" then return false end
    end
    return true
end

local function enqueue(name, ...)
    Scan.pending = { name = name, args = { ... } }
    Scan.deadline = GetTime() + 30
end

-- sort by the column the user picked (click a header; click again to reverse)
local SORT_KEYS = { name = true, quality = true, buyout = true, value = true, profit = true, percent = true }
local function sortRows()
    local o = ns.opts
    local key = SORT_KEYS[o.auctionSort] and o.auctionSort or "profit"
    local asc = o.auctionSortAsc and true or false
    table.sort(Scan.rows, function(a, b)
        local x, y = a[key], b[key]
        if key == "name" then x, y = (x or ""):lower(), (y or ""):lower() end
        if x ~= y and x ~= nil and y ~= nil then
            if asc then return x < y else return x > y end
        end
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.auctionID < b.auctionID
    end)
end
Scan.Sort = function() sortRows(); changed() end

function Scan.Stop(reason)
    Scan.running, Scan.pending, Scan.waiting = false, nil, nil
    Scan.state = reason or "stopped"
    changed()
end

local function ItemFor(id)
    local name, _, quality, level, _, _, _, stack, _, icon, _, class = ns.ItemInfo(id)
    if not name then return nil end
    return { itemID = ns.ItemID(id), quality = quality, baseIlvl = level, classID = class, name = name, icon = icon, stack = stack }
end

local function Blocked(id)
    return ns.Data.IsExcluded(id) or ns.db.noDE[id] or ns.db.ignore[id]
end

-- One listing: is it worth buying to disenchant?
function Scan.Evaluate(result)
    if not result.auctionID or not result.itemLink or result.containsOwnerItem or result.containsAccountItem
        or not result.buyoutAmount or result.buyoutAmount <= 0 then return nil, "ignored" end
    local qty = result.quantity or 1
    if qty <= 0 then return nil, "ignored" end
    local id = ns.ItemID(result.itemLink)
    if not id or Blocked(id) then return nil, "ignored" end
    -- disenchant results depend on the base item (quality, level, type), not the "of the Owl" suffix,
    -- so use the base item's data, which the browse step already loaded; only fall back to the link
    local item = ItemFor(id) or ItemFor(result.itemLink)
    if not item then return nil, "loading" end
    local linkName = result.itemLink:match("%[(.-)%]")
    if linkName and linkName ~= "" then item.name = linkName end
    if item.classID ~= 2 and item.classID ~= 4 then return nil, "ignored" end
    if not Scan.WantsQuality(item.quality) then return nil, "ignored" end
    if ns.TooltipRefuses(id, nil, nil, result.itemLink) then return nil, "ignored" end
    if not ns.Forecast.Get(item) then return nil, "ignored" end
    local value = ns.Forecast.Value(item)
    if not value then return nil, "unpriced" end
    local total = value * qty
    local profit = total - result.buyoutAmount
    if profit <= 0 or profit < (ns.opts.auctionMinProfitCopper or 0) then return nil, "ignored" end
    return { auctionID = result.auctionID, itemKey = result.itemKey, link = result.itemLink, name = item.name,
             icon = item.icon, quality = item.quality, quantity = qty, buyout = result.buyoutAmount, value = total,
             profit = profit, percent = (total / result.buyoutAmount - 1) * 100 }
end

-- Fast check on the browse summary, before searching the item's listings
function Scan.WantsQuality(q)
    return q and q >= 2 and q <= 4 and ns.opts["ahQ" .. q] and true or false
end

function Scan.IsCandidate(result)
    local key = result.itemKey
    if Blocked(key.itemID) then return false end
    -- weapons and armor only: GetItemInfoInstant needs no server data, so other items are dropped at once
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if instant then
        local _, _, _, _, _, classID = instant(key.itemID)
        if classID and classID ~= 2 and classID ~= 4 then return false end
    end
    local item = ItemFor(key.itemID)
    if not item then return nil end
    if item.classID ~= 2 and item.classID ~= 4 then return false end
    if not Scan.WantsQuality(item.quality) then return false end
    local value = ns.Forecast.Value(item)
    if not value then return false, "unpriced" end
    if not result.minPrice or result.minPrice <= 0 then return true, nil, value end
    return result.minPrice < value * math.max(1, item.stack or 1), nil, value
end

local function finishRound()
    local rows = {}
    for _, r in ipairs(Scan.rows) do
        if Scan.confirmed[r.auctionID] or (r.itemKey and Scan.keepKeys[identity(r.itemKey)]) then rows[#rows + 1] = r end
    end
    Scan.rows = rows
    sortRows()
    for k in pairs(Scan.verified) do if not Scan.seen[k] then Scan.verified[k] = nil end end
    if not ns.opts.auctionWatch then
        Scan.running, Scan.pending, Scan.waiting = false, nil, nil
        Scan.state = "done"
        changed()
        return
    end
    Scan.state, Scan.waiting = "monitoring", nil
    Scan.nextRound = GetTime() + Scan.interval
    changed()
end

local function nextItem()
    Scan.index = Scan.index + 1
    Scan.current = Scan.keys[Scan.index]
    Scan.currentIncomplete = false
    if not Scan.current then finishRound(); return end
    Scan.state = "search"
    enqueue("SendSearchQuery", Scan.current, {}, true)
    changed()
end

local function beginRound()
    ns.Prices.ClearCache()
    Scan.keys, Scan.seen, Scan.lots, Scan.confirmed = {}, {}, {}, {}
    Scan.keepKeys, Scan.signatures = {}, {}
    Scan.unchanged, Scan.auditUsed = 0, false
    Scan.summaries, Scan.summaryIndices, Scan.deferred = {}, {}, {}
    Scan.rowsByID = {}
    for _, r in ipairs(Scan.rows) do Scan.rowsByID[r.auctionID] = r end
    Scan.round = (Scan.round or 0) + 1
    Scan.total, Scan.filtered, Scan.filterIndex, Scan.missingData = 0, 0, 1, 0
    Scan.checked, Scan.skipped, Scan.index = 0, 0, 0
    Scan.running, Scan.state = true, "browse"
    Scan.browseProgressAt = GetTime()
    Scan.current = nil
    -- only the Weapons and Armor categories, and only the rarities picked on the Auction page
    local filters = {}
    local q = Enum and Enum.AuctionHouseFilter
    if q then
        local o = ns.opts
        if o.ahQ2 and q.UncommonQuality then filters[#filters + 1] = q.UncommonQuality end
        if o.ahQ3 and q.RareQuality then filters[#filters + 1] = q.RareQuality end
        if o.ahQ4 and q.EpicQuality then filters[#filters + 1] = q.EpicQuality end
    end
    enqueue("SendBrowseQuery", { searchString = "", sorts = {}, filters = filters, itemClassFilters = { { classID = 2 }, { classID = 4 } } })
    changed()
end

-- Buying pauses the scan (both use the same search results); it picks up again afterwards
function Scan.Pause()
    if not Scan.running or Scan.paused then return end
    Scan.paused, Scan.pending, Scan.waiting = true, nil, nil
    changed()
end

function Scan.Resume()
    if not Scan.paused then return end
    Scan.paused = false
    if not Scan.running or not Scan.open then return end
    Scan.deadline = GetTime() + 30
    if Scan.state == "browse" then
        beginRound()
    elseif (Scan.state == "search" or Scan.state == "loading") and Scan.current then
        Scan.state = "search"
        enqueue("SendSearchQuery", Scan.current, {}, true)
    end
    changed()
end

function Scan.Start()
    if Buy.active or Scan.running then return end
    if not (ns.opts.ahQ2 or ns.opts.ahQ3 or ns.opts.ahQ4) then Scan.Stop("norarity"); return end
    if not Scan.Supported() then Scan.Stop("unsupported"); return end
    if not Scan.open then Scan.Stop("closed"); return end
    Scan.rows, Scan.round, Scan.verified = {}, 0, {}
    beginRound()
end

local function filterBatch()
    local done = 0
    while Scan.filterIndex <= #Scan.summaries and done < 100 do
        local result = Scan.summaries[Scan.filterIndex]
        local candidate, reason, value = Scan.IsCandidate(result)
        local key = identity(result.itemKey)
        if candidate == nil then
            Scan.deferred[#Scan.deferred + 1] = result
        elseif candidate then
            local signature = result.minPrice and result.totalQuantity and value
                and table.concat({ result.minPrice, result.totalQuantity, math.floor(value) }, ":")
            Scan.signatures[key] = signature
            local cached = Scan.verified[key]
            local unchanged = signature and cached and cached.signature == signature
            local audit = unchanged and not Scan.auditUsed and GetTime() - cached.checkedAt >= 120
            if unchanged and not audit then
                Scan.keepKeys[key] = true
                Scan.unchanged = Scan.unchanged + 1
            else
                if audit then Scan.auditUsed = true end
                Scan.keys[#Scan.keys + 1] = result.itemKey
            end
        else
            Scan.verified[key] = nil
            Scan.filtered = Scan.filtered + 1
            if reason == "unpriced" then Scan.skipped = Scan.skipped + 1 end
        end
        Scan.filterIndex, done = Scan.filterIndex + 1, done + 1
    end
    if Scan.filterIndex > #Scan.summaries then
        if #Scan.deferred > 0 and GetTime() < Scan.filterDeadline then
            Scan.summaries, Scan.deferred, Scan.filterIndex = Scan.deferred, {}, 1
        else
            Scan.missingData = #Scan.deferred
            Scan.skipped = Scan.skipped + Scan.missingData
            nextItem()
        end
    end
    changed()
end

local function readListings()
    local waiting = false
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(Scan.current) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(Scan.current, i)
        if result and result.auctionID and not Scan.lots[result.auctionID] then
            local row, reason = Scan.Evaluate(result)
            if reason == "loading" and GetTime() < Scan.loadDeadline then
                waiting = true
            else
                Scan.lots[result.auctionID] = true
                Scan.checked = Scan.checked + 1
                if reason == "loading" or reason == "unpriced" then
                    Scan.skipped = Scan.skipped + 1
                    Scan.currentIncomplete = true
                end
                if row then
                    row.itemKey = Scan.current
                    Scan.confirmed[row.auctionID] = true
                    local prev = Scan.rowsByID[row.auctionID]
                    if prev then
                        for k in pairs(prev) do prev[k] = nil end
                        for k, v in pairs(row) do prev[k] = v end
                    else
                        row.foundAt = GetTime()
                        Scan.rows[#Scan.rows + 1] = row
                        Scan.rowsByID[row.auctionID] = row
                    end
                    sortRows()
                end
            end
        end
    end
    if waiting then Scan.state = "loading"; changed(); return end
    if not C_AuctionHouse.HasFullItemSearchResults(Scan.current) then
        Scan.state = "search"
        enqueue("RequestMoreItemSearchResults", Scan.current)
    else
        local key = identity(Scan.current)
        if not Scan.currentIncomplete and Scan.signatures[key] then
            Scan.verified[key] = { signature = Scan.signatures[key], checkedAt = GetTime() }
        else
            Scan.verified[key] = nil
        end
        nextItem()
    end
end

function Scan.OnEvent(event, key)
    if event == "AUCTION_HOUSE_SHOW" then Scan.open = true; changed(); return end
    if event == "AUCTION_HOUSE_CLOSED" then Scan.open = false; Scan.paused = false; Scan.Stop("closed"); return end
    if not Scan.running or Scan.paused then return end
    if event == "AUCTION_HOUSE_BROWSE_FAILURE" then Scan.Stop("failed"); return end
    if Scan.state == "browse" and Scan.waiting and
        (event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED") then
        Scan.waiting = nil
        for _, result in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
            local itemKey = result.itemKey
            if itemKey then
                local id = identity(itemKey)
                local index = Scan.summaryIndices[id]
                if index then
                    Scan.summaries[index] = result
                else
                    Scan.browseProgressAt = GetTime()
                    Scan.seen[id] = true
                    Scan.summaries[#Scan.summaries + 1] = result
                    Scan.summaryIndices[id] = #Scan.summaries
                    Scan.total = Scan.total + 1
                end
            end
        end
        if C_AuctionHouse.HasFullBrowseResults() then
            Scan.state = "filtering"
            Scan.filterDeadline = GetTime() + 5
            filterBatch()
        else
            enqueue("RequestMoreBrowseResults")
            changed()
        end
    elseif Scan.state == "search" and Scan.waiting and event == "ITEM_SEARCH_RESULTS_UPDATED"
        and key and identity(key) == identity(Scan.current) then
        Scan.waiting = nil
        Scan.loadDeadline = GetTime() + 5
        readListings()
    end
end

function Scan.Tick()
    if not Scan.running or Scan.paused then return end
    if Scan.state == "monitoring" then
        if GetTime() >= Scan.nextRound then beginRound() end
        return
    end
    if Scan.state == "filtering" then filterBatch(); return end
    if GetTime() > Scan.deadline then Scan.Stop("timeout"); return end
    if Scan.state == "browse" and GetTime() - Scan.browseProgressAt > 30 then Scan.Stop("stalled"); return end
    if Scan.state == "loading" then readListings(); return end
    if not Scan.pending then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    local req = Scan.pending
    if req.name == "SendSearchQuery" and C_AuctionHouse.GetItemKeyInfo and not C_AuctionHouse.GetItemKeyInfo(Scan.current) then return end
    Scan.pending, Scan.waiting = nil, true
    Scan.deadline = GetTime() + 30
    Scan.ownQuery = true
    local ok, err = pcall(C_AuctionHouse[req.name], unpack(req.args))
    Scan.ownQuery = false
    if not ok then Scan.lastError = tostring(err); Scan.Stop("failed") end
end

------------------------------------------------------------------------
-- Buying one lot (always from a click)
------------------------------------------------------------------------
local function same(a, b)
    return a and b and a.itemID == b.itemID and (a.itemLevel or 0) == (b.itemLevel or 0)
        and (a.itemSuffix or 0) == (b.itemSuffix or 0) and (a.battlePetSpeciesID or 0) == (b.battlePetSpeciesID or 0)
end

function Buy.Cancel(state)
    Buy.active, Buy.pending, Buy.waiting = false, nil, nil
    Buy.state = state or "cancelled"
    changed()
    -- carry on scanning, unless the next lot was picked straight away
    C_Timer.After(0, function() if not Buy.active then Scan.Resume() end end)
end

local function request(name)
    Buy.pending, Buy.waiting = name, nil
    Buy.deadline = GetTime() + 15
end

function Buy.Prepare(row, fromClick)
    if fromClick then Buy.previous = nil end
    if Buy.active or not Scan.open or not row.auctionID or not row.itemKey or not C_AuctionHouse.PlaceBid then return end
    if Scan.running and ns.opts.auctionKeepScanning then Scan.Pause() else Scan.Stop() end
    Buy.row = {}
    for k, v in pairs(row) do Buy.row[k] = v end
    Buy.active, Buy.state = true, "checking"
    request("SendSearchQuery")
    changed()
end

local function currentLot()
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(Buy.row.itemKey) do
        local r = C_AuctionHouse.GetItemSearchResultInfo(Buy.row.itemKey, i)
        if r and r.auctionID == Buy.row.auctionID then return r end
    end
end

local function valid(r)
    return r and r.buyoutAmount == Buy.row.buyout and r.buyoutAmount > 0
        and (r.quantity or 1) == Buy.row.quantity and r.itemLink == Buy.row.link
        and not r.containsOwnerItem and not r.containsAccountItem
end

local function finish(state)
    local at
    for i = #Scan.rows, 1, -1 do
        if Scan.rows[i].auctionID == Buy.row.auctionID then table.remove(Scan.rows, i); at = i end
    end
    Buy.Cancel(state)
    -- move straight on to the next lot in the list (it still needs your click on Buy)
    if at and ns.opts.auctionNext and Scan.open then
        local nextRow = Scan.rows[at] or Scan.rows[at - 1]
        if nextRow then
            Buy.previous = state
            Buy.Prepare(nextRow)
            Buy.nextIndex = at <= #Scan.rows and at or #Scan.rows
        end
    end
end

function Buy.Confirm()
    if not Buy.active or Buy.state ~= "ready" or not Scan.open then return end
    if GetTime() > Buy.deadline or not valid(currentLot()) then Buy.Cancel("stale"); return end
    if GetMoney and GetMoney() < Buy.row.buyout then Buy.Cancel("money"); return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    Buy.state, Buy.deadline = "sent", GetTime() + 8
    local submitted = Buy.row
    C_Timer.After(8, function()
        if Buy.active and Buy.state == "sent" and Buy.row == submitted then Buy.Cancel("unknown") end
    end)
    Buy.ownBid = true
    local ok = pcall(C_AuctionHouse.PlaceBid, Buy.row.auctionID, Buy.row.buyout)
    Buy.ownBid = false
    if not ok then Buy.Cancel("failed") else changed() end
end

function Buy.OnEvent(event, key, message)
    if not Buy.active then return end
    if event == "AUCTION_HOUSE_CLOSED" then Buy.Cancel(); return end
    if event == "UI_ERROR_MESSAGE" and Buy.state == "sent" then Buy.Cancel("failed"); return end
    if event == "UI_INFO_MESSAGE" and Buy.state == "sent" and ERR_AUCTION_BID_PLACED and message == ERR_AUCTION_BID_PLACED then
        finish("bought"); return
    end
    if event == "CHAT_MSG_SYSTEM" and Buy.state == "sent" and ERR_AUCTION_WON_S then
        if key == string.format(ERR_AUCTION_WON_S, Buy.row.link) or (Buy.row.name and key == string.format(ERR_AUCTION_WON_S, Buy.row.name)) then
            finish("bought"); return
        end
    end
    if event == "ITEM_SEARCH_RESULTS_UPDATED" and Buy.state == "sent" and same(key, Buy.row.itemKey) then
        if C_AuctionHouse.HasFullItemSearchResults(key) and not currentLot() then finish("unavailable") end
        return
    end
    if event ~= "ITEM_SEARCH_RESULTS_UPDATED" or not same(key, Buy.row.itemKey) or Buy.state ~= "checking" or not Buy.waiting then return end
    Buy.waiting = nil
    local r = currentLot()
    if r then
        if not valid(r) then Buy.Cancel("stale"); return end
        Buy.state, Buy.deadline = "ready", GetTime() + 15
        changed()
    elseif not C_AuctionHouse.HasFullItemSearchResults(key) then
        request("RequestMoreItemSearchResults")
    else
        Buy.Cancel("stale")
    end
end

function Buy.Tick()
    if not Buy.active then return end
    if GetTime() > Buy.deadline then Buy.Cancel(Buy.state == "sent" and "unknown" or "stale"); return end
    if not Buy.pending then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    local name = Buy.pending
    Buy.pending, Buy.waiting, Buy.ownQuery = nil, true, true
    local ok
    if name == "SendSearchQuery" then ok = pcall(C_AuctionHouse[name], Buy.row.itemKey, {}, true)
    else ok = pcall(C_AuctionHouse[name], Buy.row.itemKey) end
    Buy.ownQuery = false
    if not ok then Buy.Cancel("failed") end
end

------------------------------------------------------------------------
-- Wiring: other addons' searches end ours (results would be mixed)
------------------------------------------------------------------------
local function InstallHooks()
    if Scan.hooked or not Scan.Supported() then return end
    Scan.hooked = true
    for _, n in ipairs({ "SendBrowseQuery", "SendSearchQuery", "SearchForItemKeys", "SearchForFavorites",
        "SendSellSearchQuery", "RequestMoreBrowseResults", "RequestMoreItemSearchResults" }) do
        if C_AuctionHouse[n] then
            hooksecurefunc(C_AuctionHouse, n, function()
                if Scan.running and not Scan.ownQuery and not Buy.ownQuery then Scan.Stop("interrupted") end
                if Buy.active and not Buy.ownQuery then Buy.Cancel("stale") end
            end)
        end
    end
    if C_AuctionHouse.PlaceBid then
        hooksecurefunc(C_AuctionHouse, "PlaceBid", function()
            if Buy.active and not Buy.ownBid then Buy.Cancel("unknown") end
        end)
    end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function()
    local ok, err = pcall(function() Scan.Tick(); Buy.Tick() end)
    if not ok then Scan.lastError = tostring(err); Scan.Stop("failed") end
end)

for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE", "ITEM_SEARCH_RESULTS_UPDATED" }) do
    if C_AuctionHouse then
        ns.On(e, function(a1, a2)
            if e == "AUCTION_HOUSE_SHOW" then InstallHooks(); ticker:Show() end
            if e == "AUCTION_HOUSE_CLOSED" then ticker:Hide() end
            Scan.OnEvent(e, a1)
            Buy.OnEvent(e, a1, a2)
        end)
    end
end
for _, e in ipairs({ "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM" }) do
    ns.On(e, function(a1, a2)
        if not Buy.active then return end
        -- UI_*_MESSAGE pass (type, message); CHAT_MSG_SYSTEM passes (message)
        if e == "CHAT_MSG_SYSTEM" then Buy.OnEvent(e, a1) else Buy.OnEvent(e, nil, a2) end
    end)
end

Scan.STATE_TEXT = {
    idle = "Open the auction house and click Scan. Material prices come from TSM or Auctionator.",
    browse = "Loading the item list...", filtering = "Checking prices...", search = "Checking listings...", paused = "Paused while you buy - it carries on afterwards.",
    loading = "Loading item data...", norarity = "Pick at least one rarity to scan.",
    monitoring = "Full pass done. Watching for new and changed listings...",
    done = "Full pass done. Click Scan to check again.",
    stopped = "Stopped - partial results.", closed = "Auction house closed - results may be out of date.",
    unsupported = "This auction house interface isn't supported.", timeout = "The server didn't answer - scan again.",
    failed = "The search failed - scan again.", interrupted = "Another addon started a search - partial results.",
    stalled = "The auction list stopped loading. Stop other scanners and try again.",
}
Buy.STATE_TEXT = {
    checking = "Checking the lot is still there...", ready = "Ready - click Buy to confirm.", sent = "Buying...",
    bought = "Bought!", stale = "That lot changed or is gone.", money = "Not enough gold.",
    failed = "The purchase failed.", unknown = "No reply from the server - check your mail.",
    unavailable = "That lot is gone.", cancelled = "Cancelled.",
}

-- 1.0.0 stored the minimum profit in whole gold; it's now gold, silver and copper (in copper)
ns.Listen("LOADED", function()
    local o = ns.opts
    if (o.auctionMinProfit or 0) > 0 then
        if (o.auctionMinProfitCopper or 0) == 0 then o.auctionMinProfitCopper = o.auctionMinProfit * 10000 end
        o.auctionMinProfit = 0
    end
end)
