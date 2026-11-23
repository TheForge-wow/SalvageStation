-- Salvage Station: core (namespace, client compatibility, settings, events, helpers)
local ADDON, ns = ...
_G.SalvageStation = ns

ns.VERSION = "1.0.2"
ns.MEDIA = "Interface\\AddOns\\SalvageStation\\Media\\"
ns.ADDON = ADDON

local buildVersion = GetBuildInfo and GetBuildInfo() or ""
ns.isForever = type(buildVersion) == "string" and buildVersion:match("^1%.60%.") ~= nil
ns.TOC = select(4, GetBuildInfo()) or 0
-- WoW Forever runs original-era items and disenchant tables
ns.vanillaData = ns.isForever or ns.TOC < 20000

ns.DE_SPELL = 13262
ns.ENCHANTING_SKILLLINE = 333
ns.SALVAGER_AURA = 1283701

local PREFIX = "|cffa178ffSalvage|r Station: "
function ns.Print(msg) print(PREFIX .. tostring(msg)) end

------------------------------------------------------------------------
-- Client API compatibility
------------------------------------------------------------------------
local C_Container, C_Item = C_Container, C_Item
local function call(modern, legacy, ...)
    local fn = modern or legacy
    if fn then return fn(...) end
end

function ns.ItemInfo(item)
    if not item then return end
    return call(C_Item and C_Item.GetItemInfo, GetItemInfo, item)
end
function ns.ItemInfoInstant(item)
    if not item then return end
    return call(C_Item and C_Item.GetItemInfoInstant, GetItemInfoInstant, item)
end
function ns.ItemLevel(link)
    if not link then return 0 end
    local lvl = call(C_Item and C_Item.GetDetailedItemLevelInfo, GetDetailedItemLevelInfo, link)
    if not lvl or lvl == 0 then lvl = select(4, ns.ItemInfo(link)) end
    return lvl or 0
end
function ns.ItemID(ref)
    if type(ref) == "number" then return ref end
    if type(ref) == "string" then return tonumber(ref:match("item:(%d+)")) or tonumber(ref) end
end
function ns.ItemName(id)
    local name = ns.ItemInfo(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID and type(id) == "number" then
        C_Item.RequestLoadItemDataByID(id)
    end
    return name or (ns.MATERIAL_NAMES and ns.MATERIAL_NAMES[id]) or ("Item " .. tostring(id))
end
function ns.ItemIcon(id)
    local _, _, _, _, icon = ns.ItemInfoInstant(id)
    return icon or 134400
end
function ns.ItemQuality(id)
    local _, _, q = ns.ItemInfo(id)
    return q or 1
end
function ns.IsEquippable(link)
    local r = call(C_Item and C_Item.IsEquippableItem, IsEquippableItem, link)
    return r and true or false
end

function ns.NumSlots(bag)
    return call(C_Container and C_Container.GetContainerNumSlots, GetContainerNumSlots, bag) or 0
end
-- returns a small table describing a bag slot, or nil
function ns.SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if not i then return nil end
        return { link = i.hyperlink, count = i.stackCount or 1, itemID = i.itemID, isBound = i.isBound,
                 icon = i.iconFileID, locked = i.isLocked }
    end
    if not GetContainerItemInfo then return nil end
    local tex, count, locked, _, _, _, link, _, _, itemID, isBound = GetContainerItemInfo(bag, slot)
    if not link then return nil end
    return { link = link, count = count or 1, itemID = itemID or ns.ItemID(link), isBound = isBound,
             icon = tex, locked = locked }
end
function ns.SlotLink(bag, slot)
    return call(C_Container and C_Container.GetContainerItemLink, GetContainerItemLink, bag, slot)
end
-- A unique identity for a bag item, so a click can never hit the wrong item
function ns.SlotGUID(bag, slot)
    if C_Item and C_Item.GetItemGUID and C_Item.DoesItemExist and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, guid = pcall(function()
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if loc and C_Item.DoesItemExist(loc) then return C_Item.GetItemGUID(loc) end
        end)
        if ok and guid then return guid end
    end
    local link = ns.SlotLink(bag, slot)
    return link and (bag .. ":" .. slot .. ":" .. tostring(ns.ItemID(link))) or nil
end

ns.BAGS = {}
for bag = 0, (NUM_BAG_SLOTS or 4) do ns.BAGS[#ns.BAGS + 1] = bag end
do
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > (NUM_BAG_SLOTS or 4) then ns.BAGS[#ns.BAGS + 1] = reagent end
end

function ns.SpellName(id)
    return call(C_Spell and C_Spell.GetSpellName, GetSpellInfo, id)
end
function ns.SpellIcon(id)
    return call(C_Spell and C_Spell.GetSpellTexture, GetSpellTexture, id)
end
function ns.KnowsSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end
function ns.KnowsDisenchant() return ns.KnowsSpell(ns.DE_SPELL) end
function ns.DEName() return ns.SpellName(ns.DE_SPELL) or "Disenchant" end
function ns.DEIcon() return ns.SpellIcon(ns.DE_SPELL) or 132854 end

function ns.EnchantingSkill()
    local ok, rank = pcall(function()
        if GetProfessions and GetProfessionInfo then
            local p1, p2 = GetProfessions()
            for _, idx in pairs({ p1, p2 }) do
                local _, _, r, _, _, _, line = GetProfessionInfo(idx)
                if line == ns.ENCHANTING_SKILLLINE then return r end
            end
        end
        if GetNumSkillLines and GetSkillLineInfo then
            local ench = ns.SpellName(7411) or "Enchanting"
            for i = 1, GetNumSkillLines() do
                local name, header, _, r = GetSkillLineInfo(i)
                if not header and name == ench then return r end
            end
        end
    end)
    if ok then return rank end
end

function ns.HasSalvagerBuff()
    if not ns.isForever then return false end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, ns.SALVAGER_AURA)
        return ok and type(aura) == "table"
    end
    if AuraUtil and AuraUtil.FindAuraBySpellID then
        return AuraUtil.FindAuraBySpellID(ns.SALVAGER_AURA, "player", "HELPFUL") ~= nil
    end
    return false
end

------------------------------------------------------------------------
-- Money / number formatting (American style)
------------------------------------------------------------------------
function ns.Money(c, short)
    if type(c) ~= "number" then return "|cff616269-|r" end
    local neg = c < 0
    c = math.floor(math.abs(c) + 0.5)
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out
    if g > 0 then
        local gs = tostring(g):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        out = gs .. "|cffffd700g|r"
        if not short or g < 100 then out = out .. (s > 0 and (" " .. s .. "|cffc7c7cfs|r") or "") end
    elseif s > 0 then
        out = s .. "|cffc7c7cfs|r" .. (cp > 0 and (" " .. cp .. "|cffeda55fc|r") or "")
    else
        out = cp .. "|cffeda55fc|r"
    end
    return (neg and "-" or "") .. out
end

function ns.Num(n)
    if n >= 10 then return tostring(math.floor(n + 0.5)) end
    if n >= 1 then return (string.format("%.1f", n):gsub("%.0$", "")) end
    if n >= 0.1 then return string.format("%.1f", n) end
    return string.format("%.2f", n)
end

-- Bag item tooltip inside our own windows (the general tooltip lines are skipped there)
function ns.TipPanelActive()
    local o = ns.opts
    return o and o.tipPanel and (not o.tipShift or IsShiftKeyDown()) and true or false
end
function ns.SetBagTooltip(tt, bag, slot)
    -- with the panel on, it shows in our windows too; otherwise skip the plain lines here
    ns.ownTip = not ns.TipPanelActive()
    pcall(tt.SetBagItem, tt, bag, slot)
    ns.ownTip = false
end

-- 0.995 -> "99.5", 0.75 -> "75"
function ns.Pct(chance)
    local pct = math.floor((chance or 0) * 1000 + 0.5) / 10
    return (pct % 1 == 0) and tostring(math.floor(pct)) or string.format("%.1f", pct)
end

function ns.IconText(id, size)
    size = size or 14
    return "|T" .. ns.ItemIcon(id) .. ":" .. size .. ":" .. size .. ":0:0:64:64:5:59:5:59|t"
end

------------------------------------------------------------------------
-- Saved settings
------------------------------------------------------------------------
local function NewStats()
    return { count = 0, vendor = 0, ah = 0, unknownAH = 0, items = {}, qualities = {}, materials = {} }
end
ns.NewStats = NewStats

local DEFAULTS = {
    ignore   = {},          -- [itemID] = true   permanently hidden
    noDE     = {},          -- [itemID] = true   the game refused to disenchant it
    samples  = {},          -- learned disenchant results by bucket
    stats    = { total = NewStats() },
    opts = {
        -- general
        autoShow = true, autoHide = true, openWithVendor = false, openWithBags = false,
        includeSoulbound = true, q2 = true, q3 = true, q4 = false,
        minValueOn = false, minValue = 0, reopenAfterCombat = true, compact = false,
        -- safety
        confirmEpic = true, confirmBoERare = true, confirmWorthMore = true, confirmGoldOn = false, confirmGold = 0,
        -- protection
        upgradeGuard = true, ilvlProtect = false, ilvlCap = 0, valueProtect = false, valueGold = 0,
        skipSets = true, hideProtected = false, bagProtect = true,
        -- value
        showValue = true, flagWorthMore = true,
        -- prices
        priceSource = "auto", auctionatorMode = "last", statsBasis = "vendor",
        -- tooltips
        tipMaterials = true, tipChances = true, tipValue = true, tipIgnored = true,
        tipPanel = true, tipPanelStyle = "full", tipVerdict = true, tipShift = false, tipLearnBar = true, tipLearnCount = true,
        ahMinOn = false, ahMin = 1,
        -- hotkey
        hotkey = false,
        -- window / appearance
        accent = "violet", scale = 1, minimap = { hide = false, angle = 210 }, badge = true,
        brokerSession = false,
        -- auction scanner
        auction = true, auctionMinProfit = 0, auctionMinProfitCopper = 0, ahQ2 = true, ahQ3 = true, ahQ4 = true, auctionNext = true, auctionSort = "profit", auctionSortAsc = false, auctionKeepScanning = true, auctionMarkNew = true, confirmRemember = true, auctionWatch = true,
    },
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

------------------------------------------------------------------------
-- Events + internal signals
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers, signals = {}, {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end)

function ns.Listen(name, fn)
    signals[name] = signals[name] or {}
    table.insert(signals[name], fn)
end
function ns.Fire(name, ...)
    for _, fn in ipairs(signals[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

-- Coalesced rescan + redraw
local queued = false
function ns:RequestRefresh(delay)
    if queued then return end
    queued = true
    C_Timer.After(delay or 0.15, function()
        queued = false
        if not ns.db then return end
        ns.Scan()
        ns.Fire("REFRESH")
    end)
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    SalvageStationDB = SalvageStationDB or {}
    -- data from the old (pre-rebuild) layout
    if SalvageStationDB.opts and SalvageStationDB.opts.accent == nil then SalvageStationDB.opts.accent = "violet" end
    Merge(SalvageStationDB, DEFAULTS)
    ns.db = SalvageStationDB
    ns.opts = SalvageStationDB.opts
    -- migrate old protected list
    if type(SalvageStationDB.ignore) == "table" then
        for k, v in pairs(SalvageStationDB.ignore) do
            if type(k) == "string" and tonumber(k) then SalvageStationDB.ignore[tonumber(k)] = v; SalvageStationDB.ignore[k] = nil end
        end
    end
    ns.session = NewStats()
    ns.sessionIgnore = {}
    ns.sessionOK = {}   -- items you said not to ask about again (cleared on logout or /reload)
    ns.skipped = {}
    ns.Fire("LOADED")
end)

ns.On("PLAYER_LOGIN", function()
    ns.Fire("LOGIN")
    C_Timer.After(2, function() ns:RequestRefresh() end)
end)

-- "Don't ask again this session" (confirm dialog)
function ns.TrustForSession(itemID)
    if not itemID then return end
    ns.sessionOK[itemID] = true
    ns.Print("Won't ask again about " .. ns.ItemName(itemID) .. " until you log out. Undo: Ignored page or Settings > Protection.")
    ns:RequestRefresh(0)
end
function ns.UntrustForSession(itemID)
    if itemID then ns.sessionOK[itemID] = nil else wipe(ns.sessionOK) end
    ns:RequestRefresh(0)
end
function ns.TrustedCount()
    local n = 0
    for _ in pairs(ns.sessionOK or {}) do n = n + 1 end
    return n
end
