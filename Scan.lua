-- Salvage Station: bag scan, filters, protections and the selected item
local ADDON, ns = ...

ns.list = {}
ns.counts = { filtered = 0, ignored = 0, skipped = 0, soulbound = 0, protected = 0 }

------------------------------------------------------------------------
-- Tooltip helpers
------------------------------------------------------------------------
local scanTip
local function TipLines(bag, slot, link)
    local lines = {}
    if C_TooltipInfo and bag and C_TooltipInfo.GetBagItem then
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        for _, l in ipairs(data and data.lines or {}) do lines[#lines + 1] = l end
        return lines
    end
    if C_TooltipInfo and link and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        for _, l in ipairs(data and data.lines or {}) do lines[#lines + 1] = l end
        return lines
    end
    if not scanTip then scanTip = CreateFrame("GameTooltip", "SalvageStationScanTip", nil, "GameTooltipTemplate") end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    if bag then scanTip:SetBagItem(bag, slot) elseif link then scanTip:SetHyperlink(link) end
    for i = 1, scanTip:NumLines() do
        local L, R = _G["SalvageStationScanTipTextLeft" .. i], _G["SalvageStationScanTipTextRight" .. i]
        local lr, lg, lb = L:GetTextColor()
        local line = { leftText = L:GetText(), leftColor = { r = lr, g = lg, b = lb } }
        if R and R:IsShown() then
            local rr, rg, rb = R:GetTextColor()
            line.rightText, line.rightColor = R:GetText(), { r = rr, g = rg, b = rb }
        end
        lines[#lines + 1] = line
    end
    scanTip:Hide()
    return lines
end

local function IsRed(c) return c and c.r and c.r > 0.9 and c.g < 0.2 and c.b < 0.2 end

-- Can the player use it (no red text such as wrong armor type or level)?
local function Usable(bag, slot)
    local lines = TipLines(bag, slot)
    for i = 2, #lines do
        local l = lines[i]
        if IsRed(l.leftColor) or IsRed(l.rightColor) then return false end
    end
    return true
end

local refuseCache = {}
local REFUSE = { "cannot be disenchanted", "can not be disenchanted", "nicht entzauberbar", "kann nicht entzaubert" }
-- Does the tooltip say it can't be disenchanted? (cached by item ID)
function ns.TooltipRefuses(itemID, bag, slot, link)
    if refuseCache[itemID] ~= nil then return refuseCache[itemID] end
    local exact = {}
    for _, g in ipairs({ "ERR_CANT_BE_DISENCHANTED", "ITEM_DISENCHANT_NOT_DISENCHANTABLE" }) do
        if type(_G[g]) == "string" then exact[_G[g]:lower()] = true end
    end
    local refuses = false
    for _, l in ipairs(TipLines(bag, slot, link)) do
        local t = type(l.leftText) == "string" and l.leftText:lower() or nil
        if t then
            if exact[t] then refuses = true break end
            for _, p in ipairs(REFUSE) do
                if t:find(p, 1, true) then refuses = true break end
            end
            if refuses then break end
        end
    end
    refuseCache[itemID] = refuses
    return refuses
end

------------------------------------------------------------------------
-- Upgrade guard
------------------------------------------------------------------------
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local eqCache
local function EquippedIlvl(slot)
    if eqCache[slot] == nil then eqCache[slot] = ns.ItemLevel(GetInventoryItemLink("player", slot)) end
    return eqCache[slot]
end
local function IsUpgrade(e, equipLoc)
    local slots = SLOTS[equipLoc]
    if not slots then return false end
    local lowest
    for _, s in ipairs(slots) do
        local l = EquippedIlvl(s)
        if not lowest or l < lowest then lowest = l end
    end
    if e.ilvl <= (lowest or 0) then return false end
    return Usable(e.bag, e.slot)
end

-- Lowest equipped item level (for the iLvl protection "Suggest" button)
function ns.LowestEquippedIlvl()
    local low
    for s = 1, 18 do
        if s ~= 4 then
            local l = ns.ItemLevel(GetInventoryItemLink("player", s))
            if l > 0 and (not low or l < low) then low = l end
        end
    end
    return low
end

------------------------------------------------------------------------
-- Scan
------------------------------------------------------------------------
local function IsIgnored(id) return ns.db.ignore[id] or ns.sessionIgnore[id] end
ns.IsIgnored = IsIgnored

local function Evaluate(bag, slot, info, o, counts)
    local link, id = info.link, info.itemID
    local name, _, quality, baseIlvl, _, _, _, _, equipLoc, icon, sellPrice, classID, _, bindType = ns.ItemInfo(link)
    if not name then ns.needInfo = true; return end
    if classID ~= 2 and classID ~= 4 then return end
    if not quality or quality < 2 or quality > 4 then return end
    if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" or equipLoc == "" then return end
    if not ns.IsEquippable(link) then return end
    if ns.Data.IsExcluded(id) or ns.db.noDE[id] then return end
    if ns.TooltipRefuses(id, bag, slot) then ns.db.noDE[id] = true; return end

    if IsIgnored(id) then counts.ignored = counts.ignored + 1; return end
    local guid = ns.SlotGUID(bag, slot)
    if guid and ns.skipped[guid] then counts.skipped = counts.skipped + 1; return end
    if info.isBound and not o.includeSoulbound then counts.soulbound = counts.soulbound + 1; return end
    if not o["q" .. quality] then counts.filtered = counts.filtered + 1; return end
    local search = ns.search
    if search and search ~= "" and not name:lower():find(search:lower(), 1, true) then
        counts.filtered = counts.filtered + 1
        return
    end

    local e = {
        bag = bag, slot = slot, link = link, itemID = id, name = name, icon = icon or info.icon,
        quality = quality, baseIlvl = baseIlvl or 0, ilvl = ns.ItemLevel(link), classID = classID,
        equipLoc = equipLoc, isBound = info.isBound, isBoE = (bindType == 2) and not info.isBound,
        locked = info.locked, guid = guid, count = info.count or 1, vendor = sellPrice or 0,
    }
    if e.ilvl == 0 then e.ilvl = e.baseIlvl end

    -- values
    e.mats = ns.Forecast.Value(e)
    e.use = ns.Forecast.Best(id, e.vendor, e.isBound, e.mats)
    e.ah = e.use.ahGross
    -- what you'd get by selling it the best way (auction after the cut, or vendor)
    e.sellBy = e.use.ah and "ah" or "vendor"
    e.value = e.use.ah or e.vendor

    -- TSM: only list items whose disenchant value is above a price (unknown values stay)
    if o.minValueOn and (o.minValue or 0) > 0 and e.mats and e.mats < o.minValue * 10000 then
        counts.filtered = counts.filtered + 1
        return
    end

    -- protections: listed, but "Disenchant next" won't pick them on its own
    local why
    if o.skipSets and C_Container and C_Container.GetContainerItemEquipmentSetInfo then
        if C_Container.GetContainerItemEquipmentSetInfo(bag, slot) then why = "Gear set" end
    end
    if not why and o.ilvlProtect and (o.ilvlCap or 0) > 0 and e.ilvl >= o.ilvlCap then why = "iLvl " .. o.ilvlCap .. "+" end
    if not why and o.valueProtect and (o.valueGold or 0) > 0 then
        local price = e.ah
        if not price or price >= o.valueGold * 10000 then why = price and "Valuable" or "No price" end
    end
    if not why and o.upgradeGuard and IsUpgrade(e, equipLoc) then why = "Upgrade" end
    e.protected = why
    if why then
        counts.protected = counts.protected + 1
        if o.hideProtected then return end
    end

    e.worthMore = (o.flagWorthMore and e.mats and e.value > e.mats) and true or false


    -- safety confirm reasons
    if o.confirmEpic and quality == 4 then
        e.confirm = "This is an Epic item."
    elseif o.confirmBoERare and quality == 3 and e.isBoE then
        e.confirm = "This is a Rare item that's still Bind on Equip."
    elseif o.confirmGoldOn and (o.confirmGold or 0) > 0 and e.value >= o.confirmGold * 10000 then
        e.confirm = "It's worth " .. ns.Money(e.value) .. "."
    elseif o.confirmWorthMore and e.worthMore then
        e.confirm = (e.sellBy == "ah" and ("It's worth more on the auction house (" .. ns.Money(e.value) .. " after the cut)")
            or ("It's worth more at a vendor (" .. ns.Money(e.value) .. ")")) .. " than its materials (" .. ns.Money(e.mats) .. ")."
    end
    if e.confirm and ns.sessionOK and ns.sessionOK[e.itemID] then e.confirm, e.okSession = nil, true end
    return e
end

function ns.Scan()
    local o = ns.opts
    local list = {}
    local counts = { filtered = 0, ignored = 0, skipped = 0, soulbound = 0, protected = 0 }
    ns.needInfo = false
    eqCache = {}
    ns.enchSkill = ns.EnchantingSkill()
    ns.known = ns.KnowsDisenchant()

    for _, bag in ipairs(ns.BAGS) do
        for slot = 1, ns.NumSlots(bag) do
            local info = ns.SlotInfo(bag, slot)
            if info and info.link and info.itemID then
                local e = Evaluate(bag, slot, info, o, counts)
                if e then list[#list + 1] = e end
            end
        end
    end

    table.sort(list, function(a, b)
        if (a.protected ~= nil) ~= (b.protected ~= nil) then return b.protected ~= nil end
        if a.quality ~= b.quality then return a.quality < b.quality end
        if a.ilvl ~= b.ilvl then return a.ilvl < b.ilvl end
        if a.name ~= b.name then return a.name < b.name end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)

    ns.list, ns.counts = list, counts
    ns.FixSelection()
    return list
end

------------------------------------------------------------------------
-- Selection (TSM: the selected row is what "Disenchant next" uses)
------------------------------------------------------------------------
local function Auto(e) return not e.protected and not e.locked end

function ns.Selected()
    for i, e in ipairs(ns.list) do
        if e.guid == ns.selected then return e, i end
    end
end

function ns.FixSelection()
    local cur = ns.Selected()
    if cur then return end
    ns.selected = nil
    for _, e in ipairs(ns.list) do
        if Auto(e) then ns.selected = e.guid; return end
    end
end

function ns.Select(e)
    ns.selected = e and e.guid or nil
    ns.Fire("SELECTION")
end

-- Step through the list (compact bar arrows)
function ns.Cycle(dir)
    local n = #ns.list
    if n == 0 then return end
    local _, i = ns.Selected()
    i = ((i or 0) - 1 + dir) % n + 1
    ns.Select(ns.list[i])
end

function ns.ReadyCount()
    local n = 0
    for _, e in ipairs(ns.list) do if Auto(e) then n = n + 1 end end
    return n
end

-- Skip until the window closes (Disenchantry)
function ns.Skip(e)
    if not e or not e.guid then return end
    ns.skipped[e.guid] = true
    ns.selected = nil
    ns:RequestRefresh(0)
end
function ns.ClearSkipped()
    if next(ns.skipped) then wipe(ns.skipped); ns:RequestRefresh(0) end
end

-- Hide: session or permanent (TSM)
function ns.Hide(itemID, permanent, link)
    if not itemID then return end
    local name = link or ns.ItemName(itemID)
    if permanent then
        ns.db.ignore[itemID] = true
        ns.Print(name .. " is now ignored permanently. Unignore it on the Ignored page.")
    else
        ns.sessionIgnore[itemID] = true
        ns.Print(name .. " is hidden until you log out. Shift+click the hide icon to ignore it permanently.")
    end
    ns:RequestRefresh(0)
end
function ns.Unhide(itemID)
    ns.db.ignore[itemID] = nil
    ns.sessionIgnore[itemID] = nil
    ns.db.noDE[itemID] = nil
    refuseCache[itemID] = nil
    ns:RequestRefresh(0)
end
