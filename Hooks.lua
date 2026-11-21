-- Salvage Station: tooltips, bag clicks, auto-show, combat, data bar
local ADDON, ns = ...

------------------------------------------------------------------------
-- Item tooltips (Disenchantry): materials, chances, disenchant value
------------------------------------------------------------------------
local function ItemFromLink(link)
    local name, _, quality, baseIlvl, _, _, _, _, equipLoc, _, _, classID = ns.ItemInfo(link)
    if not name or (classID ~= 2 and classID ~= 4) or not quality or quality < 2 or quality > 4 then return end
    if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then return end
    return { itemID = ns.ItemID(link), quality = quality, baseIlvl = baseIlvl, classID = classID }
end
ns.ItemFromLink = ItemFromLink

local function AddLines(tt, link)
    if not ns.db or not link or ns.ownTip then return end
    local o = ns.opts
    if o.tipPanel then return end -- the tooltip panel shows all of this
    local id = ns.ItemID(link)
    if o.tipIgnored and id and (ns.db.ignore[id] or ns.sessionIgnore[id]) then
        tt:AddLine("|cff" .. ns.AccentHex() .. "Ignored|r |cff8a8b94by Salvage Station|r")
    end
    if not (o.tipMaterials or o.tipValue) then return end
    local item = ItemFromLink(link)
    if not item or ns.Data.IsExcluded(item.itemID) or ns.db.noDE[item.itemID] then return end
    local res = ns.Forecast.Get(item)
    if not res then return end
    if o.tipMaterials then
        tt:AddLine("|cff" .. ns.AccentHex() .. "Disenchant|r", 1, 1, 1)
        for i = 1, math.min(4, #res) do
            local r = res[i]
            local range = (r.min == r.max) and tostring(r.min) or (r.min .. "-" .. r.max)
            local right = o.tipChances and (ns.Pct(r.chance) .. "%") or ""
            tt:AddDoubleLine("  " .. ns.IconText(r.id, 12) .. " " .. range .. "x " .. ns.ItemName(r.id), right,
                0.85, 0.85, 0.85, 0.6, 0.6, 0.65)
        end
    end
    if o.tipValue then
        local v = ns.Forecast.Value(item)
        if v then tt:AddDoubleLine("  Disenchant value", ns.Money(v), 0.85, 0.85, 0.85, 1, 1, 1) end
    end
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
            local link
            if tt.GetItem then link = select(2, tt:GetItem()) end
            if not link and data and data.id then link = "item:" .. data.id end
            pcall(AddLines, tt, link)
            if ns.TipPanel then pcall(ns.TipPanel.Attach, tt, link) end
        end)
    else
        for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tt then
                tt:HookScript("OnTooltipSetItem", function(self)
                    local _, link = self:GetItem()
                    pcall(AddLines, self, link)
                    if ns.TipPanel then pcall(ns.TipPanel.Attach, self, link) end
                end)
            end
        end
    end
end

------------------------------------------------------------------------
-- Alt+Right-click an item in your bags to ignore / unignore it
------------------------------------------------------------------------
local function HookBagClicks()
    if not HandleModifiedItemClick then return end
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not ns.opts.bagProtect or type(link) ~= "string" then return end
        if not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
        if GetMouseButtonClicked and GetMouseButtonClicked() ~= "RightButton" then return end
        local id = ns.ItemID(link)
        if not id then return end
        if ns.db.ignore[id] then
            ns.Unhide(id)
            ns.Print(link .. " is no longer ignored.")
        else
            ns.Hide(id, true, link)
        end
    end)
end

------------------------------------------------------------------------
-- Auto-show / auto-hide (TSM), vendor + bags (optional)
------------------------------------------------------------------------
local lastReady = 0
ns.Listen("REFRESH", function()
    local ready = ns.known and ns.ReadyCount() or 0
    if InCombatLockdown() then lastReady = ready; return end
    local shown = ns.IsAnyWindowShown and ns.IsAnyWindowShown()
    if ready > 0 and lastReady == 0 and ns.opts.autoShow and not shown and not UnitIsDeadOrGhost("player") then
        ns.OpenWindow("auto")
    elseif ready == 0 and #ns.list == 0 and ns.opts.autoHide and ns.openedBy == "auto" and shown then
        ns.CloseWindows()
    end
    lastReady = ready
end)

ns.On("MERCHANT_SHOW", function()
    if ns.opts.openWithVendor and ns.ReadyCount() > 0 and not ns.IsAnyWindowShown() then ns.OpenWindow("vendor") end
end)
ns.On("MERCHANT_CLOSED", function()
    if ns.openedBy == "vendor" then ns.CloseWindows() end
end)

local function HookBags()
    local function changed()
        C_Timer.After(0, function()
            if not ns.opts.openWithBags or not IsBagOpen or InCombatLockdown() then return end
            if IsBagOpen(0) then
                if ns.ReadyCount() > 0 and not ns.IsAnyWindowShown() then ns.OpenWindow("bags") end
            elseif ns.openedBy == "bags" then
                ns.CloseWindows()
            end
        end)
    end
    for _, fn in ipairs({ "ToggleAllBags", "OpenAllBags", "CloseAllBags", "ToggleBackpack", "OpenBackpack", "CloseBackpack" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, changed) end
    end
end

------------------------------------------------------------------------
-- Combat: secure buttons can't change in combat, so close and reopen
------------------------------------------------------------------------
ns.On("PLAYER_REGEN_DISABLED", function()
    if ns.confirmFrame and ns.confirmFrame:IsShown() then ns.confirmFrame:Hide() end
    if ns.IsAnyWindowShown and ns.IsAnyWindowShown() then
        ns.reopen = ns.compactFrame and ns.compactFrame:IsShown() and "compact" or "main"
        ns.CloseWindows(true)
    end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    if ns.reopen and ns.opts.reopenAfterCombat then ns.OpenWindow(ns.reopen == "compact" and "compact" or nil) end
    ns.reopen = nil
    ns:RequestRefresh()
end)

------------------------------------------------------------------------
-- Rescans
------------------------------------------------------------------------
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "SPELLS_CHANGED",
    "PLAYER_LEVEL_UP", "EQUIPMENT_SETS_CHANGED" }) do
    ns.On(e, function() if not ns.busy then ns:RequestRefresh() end end)
end
ns.On("GET_ITEM_INFO_RECEIVED", function() if ns.needInfo then ns:RequestRefresh(0.3) end end)

------------------------------------------------------------------------
-- Data bar (LibDataBroker): EllesmereUI, ElvUI, Titan Panel, ChocolateBar...
-- Retries because some UI suites load their data bar part late.
------------------------------------------------------------------------
local brokerErr
local function OnBrokerTooltip(tt)
    if not tt or not tt.AddLine then return end
    tt:AddLine("|cff" .. ns.AccentHex() .. "Salvage|r Station")
    if not ns.known then
        tt:AddLine("You don't know Disenchant on this character.", 0.55, 0.57, 0.63)
    else
        tt:AddDoubleLine("Ready to disenchant", ns.ReadyCount(), 0.8, 0.8, 0.8, 1, 1, 1)
        local sel = ns.Selected()
        if sel then tt:AddDoubleLine("Next up", sel.link or sel.name, 0.8, 0.8, 0.8) end
    end
    local s = ns.session
    if s and s.count > 0 then
        tt:AddLine(" ")
        tt:AddLine("This session: " .. s.count .. " disenchanted", 1, 1, 1)
        local ids = {}
        for id in pairs(s.materials) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b) return s.materials[a] > s.materials[b] end)
        for i = 1, math.min(5, #ids) do
            tt:AddDoubleLine("  " .. ns.IconText(ids[i], 12) .. " " .. ns.ItemName(ids[i]), s.materials[ids[i]], 0.9, 0.9, 0.9, 0.4, 0.9, 0.55)
        end
    end
    tt:AddLine(" ")
    tt:AddLine("Left-click: open / close", 0.55, 0.57, 0.63)
    tt:AddLine("Shift+Left-click: statistics", 0.55, 0.57, 0.63)
    tt:AddLine("Right-click: settings", 0.55, 0.57, 0.63)
end

function ns.UpdateBroker()
    local b = ns.broker
    if not b then return end
    b.icon = ns.DEIcon()
    if not ns.known then b.text = "|cff8a8b94No Disenchant|r"; return end
    local n = ns.ReadyCount()
    local t = (n > 0) and ("|cff" .. ns.AccentHex() .. n .. "|r to disenchant") or "|cff8a8b94Nothing to DE|r"
    if ns.opts.brokerSession and ns.session then t = t .. "  ·  " .. ns.session.count .. " done" end
    b.text = t
end

local function TryBroker()
    if ns.broker or not ns.db then return end
    local ok, err = pcall(function()
        local LS = _G.LibStub
        local LDB = LS and LS("LibDataBroker-1.1", true)
        if not LDB then return end
        ns.broker = LDB:NewDataObject("Salvage Station", {
            type = "data source", label = "Salvage", text = "Salvage Station", icon = ns.DEIcon(),
            OnClick = function(_, button)
                if button == "RightButton" then ns.OpenWindow(nil, "settings")
                elseif IsShiftKeyDown() then ns.OpenWindow(nil, "stats")
                else ns.ToggleWindow() end
            end,
            OnTooltipShow = function(tt) pcall(OnBrokerTooltip, tt) end,
        })
        ns.UpdateBroker()
    end)
    if not ok then brokerErr = tostring(err) end
end
function ns.BrokerStatus()
    if ns.broker then return "connected" end
    if brokerErr then return "error: " .. brokerErr end
    local LS = _G.LibStub
    if LS and LS("LibDataBroker-1.1", true) then return "library found, not registered yet" end
    return "no data bar addon found"
end
ns.On("ADDON_LOADED", function() if ns.db then TryBroker() end end)
ns.Listen("REFRESH", ns.UpdateBroker)
ns.Listen("STATS", ns.UpdateBroker)

ns.Listen("LOGIN", function()
    HookTooltips()
    HookBagClicks()
    HookBags()
    TryBroker()
    C_Timer.After(1, TryBroker)
    C_Timer.After(10, TryBroker)
    C_Timer.After(30, TryBroker)
end)
