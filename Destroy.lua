-- Salvage Station: the disenchant flow, secure buttons and statistics recording.
-- Flow follows TSM Destroying (wait for cast + loot before the next item);
-- loot confirmation via chat follows Disenchantry. See NOTICE.txt.
local ADDON, ns = ...

ns.busy = false

------------------------------------------------------------------------
-- Statistics data
------------------------------------------------------------------------
local function EachStats(fn)
    fn(ns.session)
    fn(ns.db.stats.total)
end

local function StatsAddItem(p)
    EachStats(function(d)
        d.count = d.count + 1
        d.vendor = d.vendor + (p.vendor or 0)
        if p.ah then d.ah = d.ah + p.ah else d.unknownAH = d.unknownAH + 1 end
        if p.link then d.items[p.link] = (d.items[p.link] or 0) + 1 end
        if p.quality then d.qualities[p.quality] = (d.qualities[p.quality] or 0) + 1 end
        local v = math.max(p.vendor or 0, p.ah or 0)
        if v > (d.maxValue or -1) then d.maxValue = v; d.maxLink = p.link end
    end)
end

local function StatsAddMaterial(id, qty)
    EachStats(function(d) d.materials[id] = (d.materials[id] or 0) + qty end)
end

function ns.ResetSession()
    ns.session = ns.NewStats()
    ns.Fire("STATS")
end
function ns.ResetAllStats()
    ns.db.stats.total = ns.NewStats()
    ns.session = ns.NewStats()
    ns.Fire("STATS")
end

------------------------------------------------------------------------
-- Busy state
------------------------------------------------------------------------
local token = 0
local function EndBusy()
    ns.busy = false
    ns.pending = nil
    ns.Fire("BUSY")
    ns:RequestRefresh(0.05)
end
ns.EndBusy = EndBusy

local function BeginCast(e)
    token = token + 1
    local my = token
    ns.busy = true
    ns.pending = {
        itemID = e.itemID, link = e.link, quality = e.quality, baseIlvl = e.baseIlvl, classID = e.classID,
        vendor = e.vendor, ah = e.ah, name = e.name, t = GetTime(),
    }
    ns.Fire("BUSY")
    -- never stay stuck
    C_Timer.After(10, function()
        if ns.busy and token == my then EndBusy() end
    end)
end

local function IsDE(spellID)
    if spellID == ns.DE_SPELL then return true end
    local n = spellID and ns.SpellName(spellID)
    return n ~= nil and n == ns.DEName()
end

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    local p = ns.pending
    if unit ~= "player" or not p or not IsDE(spellID) or p.succeeded then return end
    p.succeeded = true
    p.boosted = ns.HasSalvagerBuff()
    StatsAddItem(p)
    ns.Fire("STATS")
end)

local function CastStopped(unit, _, spellID)
    if unit == "player" and ns.pending and not ns.pending.succeeded and IsDE(spellID) then EndBusy() end
end
ns.On("UNIT_SPELLCAST_FAILED", CastStopped)
ns.On("UNIT_SPELLCAST_INTERRUPTED", CastStopped)
ns.On("UNIT_SPELLCAST_FAILED_QUIET", CastStopped)

local function ReadLoot()
    local p = ns.pending
    if not p or not p.succeeded or p.loot then return end
    local n = GetNumLootItems and GetNumLootItems() or 0
    if n == 0 then return end
    local got = {}
    for i = 1, n do
        local link = GetLootSlotLink(i)
        local id = ns.ItemID(link)
        local qty = select(3, GetLootSlotInfo(i))
        -- a partial snapshot must never be learned; retry on the next loot event
        if not id or not qty or qty <= 0 then return end
        got[id] = (got[id] or 0) + qty
    end
    p.loot = got
    p.remaining = {}
    for id, q in pairs(got) do p.remaining[id] = q end
    ns.Forecast.Record(p, got, p.boosted)
end
ns.On("LOOT_READY", ReadLoot)
ns.On("LOOT_OPENED", ReadLoot)

ns.On("LOOT_CLOSED", function()
    local p = ns.pending
    if not p or not p.loot then return end
    p.lootClosed = true
    C_Timer.After(1.5, function() if ns.pending == p then EndBusy() end end)
end)

ns.On("BAG_UPDATE_DELAYED", function()
    local p = ns.pending
    if p and p.lootClosed then EndBusy() end
end)

-- Materials only count once they really reach your bags
local function LootPattern(template)
    return "^" .. template:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)") .. "$"
end
ns.On("CHAT_MSG_LOOT", function(msg)
    local p = ns.pending
    if not p or not p.remaining or type(msg) ~= "string" then return end
    local link, qty
    if LOOT_ITEM_SELF_MULTIPLE then link, qty = msg:match(LootPattern(LOOT_ITEM_SELF_MULTIPLE)) end
    if not link and LOOT_ITEM_SELF then link = msg:match(LootPattern(LOOT_ITEM_SELF)); qty = 1 end
    local id = ns.ItemID(link)
    local left = id and p.remaining[id]
    if not left or left <= 0 then return end
    qty = math.min(tonumber(qty) or 1, left)
    p.remaining[id] = left - qty
    StatsAddMaterial(id, qty)
    ns.Fire("STATS")
end)

ns.On("UI_ERROR_MESSAGE", function(a1, a2)
    local msg = type(a2) == "string" and a2 or a1
    local p = ns.pending
    if not p or type(msg) ~= "string" then return end
    for _, g in ipairs({ "SPELL_FAILED_CANT_BE_DISENCHANTED", "ERR_CANT_BE_DISENCHANTED" }) do
        if _G[g] and msg == _G[g] then
            ns.db.noDE[p.itemID] = true
            ns.Print((p.link or p.name or "That item") .. " can't be disenchanted - it won't be listed again.")
            EndBusy()
            return
        end
    end
end)

------------------------------------------------------------------------
-- Secure cast buttons (TSM: set the macro in PreClick)
------------------------------------------------------------------------
local function Disarm(btn)
    if InCombatLockdown() then return end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("macrotext", nil)
end

local function Arm(btn, e)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/cast " .. ns.DEName() .. "\n/use " .. e.bag .. " " .. e.slot)
end

function ns.SyncClicks(btn)
    if InCombatLockdown() then return end
    local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    btn:RegisterForClicks(down and "LeftButtonDown" or "LeftButtonUp")
end

-- getEntry() returns the item this button should disenchant.
-- isConfirm = true for the button inside the confirm dialog.
function ns.MakeCastButton(btn, getEntry, isConfirm)
    ns.SyncClicks(btn)
    btn:SetScript("PreClick", function(self)
        Disarm(self)
        self.askConfirm = nil
        if InCombatLockdown() then return end
        local e = getEntry()
        if not e or not ns.known or not e.bag then return end
        if ns.busy then return end
        if UnitCastingInfo and (UnitCastingInfo("player") or UnitChannelInfo("player")) then return end
        if ns.SlotGUID(e.bag, e.slot) ~= e.guid then ns:RequestRefresh(0); return end
        if e.confirm and not isConfirm then self.askConfirm = e; return end
        Arm(self, e)
        BeginCast(e)
    end)
    btn:SetScript("PostClick", function(self)
        local ask = self.askConfirm
        self.askConfirm = nil
        if not InCombatLockdown() then Disarm(self) end
        if ask and ns.ShowConfirm then ns.ShowConfirm(ask) end
    end)
end

------------------------------------------------------------------------
-- Hotkey (Disenchantry): override binding while a window is open
------------------------------------------------------------------------
local owner = CreateFrame("Frame")
function ns.UpdateHotkey()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    local key = ns.opts and ns.opts.hotkey
    if not key or key == "" then return end
    local target
    if ns.compactFrame and ns.compactFrame:IsShown() then target = "SalvageStationCompactCast"
    elseif ns.main and ns.main:IsShown() and ns.main.page == "disenchant" then target = "SalvageStationNextButton" end
    if target then SetOverrideBindingClick(owner, true, key, target, "LeftButton") end
end
ns.On("PLAYER_REGEN_ENABLED", function() ns.UpdateHotkey() end)
