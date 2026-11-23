-- Salvage Station: Settings page, split into tabs across the top (like Lifeline).
-- Every option has its own switch.
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

local TABS = {
    { key = "general",    label = "General" },
    { key = "protection", label = "Protection" },
    { key = "tooltips",   label = "Tooltips" },
    { key = "prices",     label = "Prices" },
    { key = "window",     label = "Window" },
}
local BAR_H = 34
local LX, RX, COLW = 8, 290, 262

ns.PageBuilders.settings = function(content, main)
    local o = ns.opts
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()

    local controls, refreshers = {}, {}
    local function Track(c) controls[#controls + 1] = c; return c end

    -- tab bar --------------------------------------------------------------
    local bar = CreateFrame("Frame", nil, p)
    bar:SetPoint("TOPLEFT", 16, -14)
    bar:SetPoint("TOPRIGHT", -16, -14)
    bar:SetHeight(26)
    local barLine = W.Line(bar, true)
    barLine:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
    barLine:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)

    local pages, buttons, current = {}, {}, "general"
    local function Select(key)
        current = key
        for k, pg in pairs(pages) do pg:SetShown(k == key) end
        for _, b in ipairs(buttons) do b:SetActive(b.key == key) end
    end
    local x = 0
    for _, t in ipairs(TABS) do
        local w = math.max(96, 26 + #t.label * 7)
        local b = W.Button(bar, t.label, w, 24)
        b:SetPoint("LEFT", x, 0)
        b.key = t.key
        b:SetScript("OnClick", function() Select(t.key) end)
        buttons[#buttons + 1] = b
        x = x + w + 6

        local pg = CreateFrame("Frame", nil, p)
        pg:SetPoint("TOPLEFT", 16, -14 - BAR_H - 8)
        pg:SetPoint("BOTTOMRIGHT", -16, 40)
        pg:Hide()
        pages[t.key] = pg
    end

    -- helpers --------------------------------------------------------------
    local function Section(pg, xx, y, text, width)
        local t = W.Label(pg, text)
        t:SetPoint("TOPLEFT", xx, y)
        local line = W.Line(pg, true)
        line:SetPoint("TOPLEFT", xx, y - 14)
        line:SetWidth(width or COLW)
    end
    local function Desc(pg, xx, y, text, h, width)
        local t = W.Text(pg, 11, C.dim)
        t:SetPoint("TOPLEFT", xx, y)
        t:SetWidth(width or COLW)
        t:SetWordWrap(true)
        t:SetJustifyV("TOP")
        t:SetHeight(h or 28)
        if text then t:SetText(text) end
        return t
    end
    local function Opt(pg, xx, y, label, key, onSet, tip)
        local t = Track(W.Toggle(pg, label, function() return o[key] end, function(v)
            o[key] = v
            if onSet then onSet(v) end
        end))
        t:SetPoint("TOPLEFT", xx, y)
        if tip then W.Tip(t, label, tip) end
        return t
    end
    local function OptBox(pg, xx, y, label, key, boxKey, suffix, tip)
        local t = Opt(pg, xx, y, label, key, nil, tip)
        local box = W.EditBox(pg, 52, 22, "-")
        box:SetNumeric(true)
        box:SetMaxLetters(5)
        box:SetPoint("LEFT", t, "RIGHT", 2, 0)
        box.onChange = function(v) o[boxKey] = tonumber(v) or 0; ns:RequestRefresh() end
        local suf = W.Text(pg, 12, C.dim)
        suf:SetPoint("LEFT", box, "RIGHT", 6, 0)
        suf:SetText(suffix or "")
        refreshers[#refreshers + 1] = function() box:SetText((o[boxKey] or 0) > 0 and tostring(o[boxKey]) or "") end
        return t, box, suf
    end
    local function Seg(pg, xx, y, label, labelW, opts, key, segW, onSet)
        local l = W.Text(pg, 12)
        l:SetPoint("TOPLEFT", xx, y - 6)
        l:SetText(label)
        local sg = Track(W.Segmented(pg, opts, function() return o[key] end, function(v)
            o[key] = v
            if onSet then onSet(v) end
        end, segW))
        sg:SetPoint("TOPLEFT", xx + labelW, y)
        return sg
    end
    local function Confirming(pg, label, w, fn, tip)
        local b = W.Button(pg, label, w, 26)
        W.Tip(b, label, tip .. " Click twice to confirm.")
        b:SetScript("OnClick", function(self)
            if self.armed then
                self.armed = nil; self:SetLabel(label); fn()
            else
                self.armed = true; self:SetLabel("Click to confirm")
                C_Timer.After(3, function() self.armed = nil; self:SetLabel(label) end)
            end
        end)
        return b
    end

    -- GENERAL --------------------------------------------------------------
    do
        local pg, y = pages.general, -8
        Section(pg, LX, y, "When to show"); y = y - 26
        Opt(pg, LX, y, "Show automatically", "autoShow", nil,
            "Opens Salvage Station when something you can disenchant shows up in your bags."); y = y - 28
        Opt(pg, LX, y, "Close automatically when done", "autoHide", nil,
            "Closes it again once there's nothing left (only if it opened by itself)."); y = y - 28
        Opt(pg, LX, y, "Open at vendors", "openWithVendor"); y = y - 28
        Opt(pg, LX, y, "Open with your bags", "openWithBags"); y = y - 28
        Track(W.Toggle(pg, "Reopen after combat", function() return o.reopenAfterCombat end,
            function(v) o.reopenAfterCombat = v end)):SetPoint("TOPLEFT", LX, y); y = y - 28
        Opt(pg, LX, y, "Use the compact bar", "compact", nil, "Opens the small floating bar instead of the full window."); y = y - 40

        Section(pg, LX, y, "What to list"); y = y - 26
        Opt(pg, LX, y, "Include soulbound items", "includeSoulbound", nil,
            "List items that are already soulbound, like quest rewards."); y = y - 28
        OptBox(pg, LX, y, "Only if DE value over", "minValueOn", "minValue", "g",
            "Only lists items whose materials are worth more than this. Items without prices stay listed.")

        local ry = -8
        Section(pg, RX, ry, "Hotkey"); ry = ry - 26
        local cap = W.Button(pg, "", 170, 26)
        cap:SetPoint("TOPLEFT", RX, ry)
        local clear = W.Button(pg, "Clear", 70, 26)
        clear:SetPoint("LEFT", cap, "RIGHT", 6, 0)
        local listening = false
        local function Stop()
            listening = false
            cap:EnableKeyboard(false)
            cap:SetActive(false)
            cap:SetLabel(o.hotkey and o.hotkey ~= "" and o.hotkey or "Click to set a key")
        end
        cap:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            listening = true
            cap:SetLabel("Press a key (Esc cancels)")
            cap:SetActive(true)
            cap:EnableKeyboard(true)
            cap:SetPropagateKeyboardInput(false)
            local tok = {}
            cap.tok = tok
            C_Timer.After(10, function() if listening and cap.tok == tok then Stop() end end)
        end)
        cap:SetScript("OnKeyDown", function(_, key)
            if not listening then return end
            if InCombatLockdown() or key == "ESCAPE" then Stop(); return end
            if key:match("SHIFT$") or key:match("CTRL$") or key:match("ALT$") then return end
            o.hotkey = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
            Stop()
            ns.UpdateHotkey()
        end)
        cap:SetScript("OnHide", Stop)
        clear:SetScript("OnClick", function() o.hotkey = false; Stop(); ns.UpdateHotkey() end)
        refreshers[#refreshers + 1] = function() if not listening then Stop() end end
        ry = ry - 34
        Desc(pg, RX, ry, "Disenchants the next item while Salvage Station is open. It only takes over the key while the window is open.", 44)
    end

    -- PROTECTION -----------------------------------------------------------
    do
        local pg, y = pages.protection, -8
        Section(pg, LX, y, "Safety"); y = y - 24
        Desc(pg, LX, y, "Ask before disenchanting these.", 16); y = y - 22
        Opt(pg, LX, y, "Confirm Epics", "confirmEpic"); y = y - 28
        Opt(pg, LX, y, "Confirm Rare BoE items", "confirmBoERare"); y = y - 28
        Opt(pg, LX, y, "Confirm if worth more sold", "confirmWorthMore", nil,
            "Asks first when an item sells for more than its materials are worth. Needs TSM or Auctionator."); y = y - 28
        OptBox(pg, LX, y, "Confirm if worth over", "confirmGoldOn", "confirmGold", "g"); y = y - 28
        Opt(pg, LX, y, "Offer \"Don't ask again\"", "confirmRemember", nil,
            "Adds a switch to the confirm box to stop asking about that item until you log out or /reload."); y = y - 30
        local trustText = W.Text(pg, 11, C.dim)
        trustText:SetPoint("TOPLEFT", LX, y - 6)
        local askAgain = W.Button(pg, "Ask again", 90, 24)
        askAgain:SetPoint("TOPLEFT", LX + 172, y)
        askAgain:SetScript("OnClick", function() ns.UntrustForSession(); main:Refresh() end)
        W.Tip(askAgain, "Ask again", "Asks before disenchanting every item again, as normal.")
        refreshers[#refreshers + 1] = function()
            local n = ns.TrustedCount()
            trustText:SetText(n > 0 and ("Not asking about |cffffffff" .. n .. "|r item" .. (n == 1 and "" or "s")) or "Asking about every item")
            askAgain:SetEnabled(n > 0)
        end

        local ry = -8
        Section(pg, RX, ry, "Protection"); ry = ry - 24
        Desc(pg, RX, ry, "Protected items stay in the list, but Disenchant Next skips them unless you select one.", 30); ry = ry - 36
        Opt(pg, RX, ry, "Upgrade guard", "upgradeGuard", nil,
            "Protects items with a higher item level than what you wear in that slot, if you can use them."); ry = ry - 28
        local _, ilvlBox, ilvlSuf = OptBox(pg, RX, ry, "Protect iLvl", "ilvlProtect", "ilvlCap", "+",
            "Protects items at or above this item level.")
        local suggest = W.Button(pg, "Suggest", 64, 22)
        suggest:SetPoint("LEFT", ilvlSuf, "RIGHT", 8, 0)
        W.Tip(suggest, "Suggest", "Fills in your lowest equipped item level. Anything below it can't be an upgrade.")
        suggest:SetScript("OnClick", function()
            local low = ns.LowestEquippedIlvl()
            if low then o.ilvlCap = low; o.ilvlProtect = true; ilvlBox:SetText(tostring(low)); ns:RequestRefresh(0) end
            for _, c in ipairs(controls) do c:Refresh() end
        end)
        ry = ry - 28
        OptBox(pg, RX, ry, "Protect if worth over", "valueProtect", "valueGold", "g",
            "Protects items whose market value is at least this much. Items with no price are protected too. Needs TSM or Auctionator."); ry = ry - 28
        Opt(pg, RX, ry, "Protect gear-set items", "skipSets"); ry = ry - 28
        Opt(pg, RX, ry, "Hide protected items", "hideProtected", nil, "Leaves protected items out of the list completely."); ry = ry - 40

        Section(pg, RX, ry, "Ignoring"); ry = ry - 26
        Opt(pg, RX, ry, "Alt+Right-click in bags to ignore", "bagProtect")
    end

    -- TOOLTIPS -------------------------------------------------------------
    do
        local pg, y = pages.tooltips, -8
        Section(pg, LX, y, "Tooltip panel"); y = y - 26
        Opt(pg, LX, y, "Salvage Station panel", "tipPanel", nil,
            "Adds a Salvage Station panel under item tooltips: possible materials, and whether to disenchant, vendor or auction."); y = y - 32
        Seg(pg, LX + 40, y, "Style", 62, { { value = "full", label = "Full" }, { value = "compact", label = "Compact" } },
            "tipPanelStyle", 80); y = y - 32
        Opt(pg, LX + 40, y, "Show the verdict", "tipVerdict", nil,
            "Says whether to disenchant, vendor or auction, and by how much."); y = y - 28
        Opt(pg, LX + 40, y, "Show the learning bar", "tipLearnBar", nil,
            "A thin bar along the bottom of the panel that fills as Salvage Station learns from your disenchants of that kind of item."); y = y - 28
        Opt(pg, LX + 40, y, "Show the learning count", "tipLearnCount", nil,
            "Shows \"Learning n/10\" in the bottom corner of the panel."); y = y - 28
        Opt(pg, LX + 40, y, "Only while holding Shift", "tipShift")

        local ry = -8
        Section(pg, RX, ry, "Plain lines"); ry = ry - 24
        Desc(pg, RX, ry, "With the panel off, these lines are added to tooltips instead.", 30); ry = ry - 36
        Opt(pg, RX, ry, "Possible materials", "tipMaterials"); ry = ry - 28
        Opt(pg, RX, ry, "Drop chances", "tipChances"); ry = ry - 28
        Opt(pg, RX, ry, "Disenchant value", "tipValue"); ry = ry - 28
        Opt(pg, RX, ry, "Ignored items", "tipIgnored")
    end

    -- PRICES ---------------------------------------------------------------
    local priceInfo
    do
        local pg, y = pages.prices, -8
        Section(pg, LX, y, "Price source", COLW * 2 + (RX - LX - COLW)); y = y - 28
        Seg(pg, LX, y, "Source", 96, { { value = "auto", label = "Auto" }, { value = "tsm", label = "TSM" },
            { value = "auctionator", label = "Auctionator" } }, "priceSource", 96,
            function() ns.Prices.ClearCache(); ns:RequestRefresh(0) end); y = y - 32
        Seg(pg, LX, y, "Auctionator", 96, { { value = "last", label = "Last seen" }, { value = "average", label = "Average" } },
            "auctionatorMode", 144, function() ns.Prices.ClearCache(); ns:RequestRefresh(0) end); y = y - 32
        priceInfo = Desc(pg, LX, y, nil, 30, 400); y = y - 44

        Section(pg, LX, y, "Values"); y = y - 26
        Opt(pg, LX, y, "Show values in the list", "showValue"); y = y - 28
        Opt(pg, LX, y, "Flag items worth more sold", "flagWorthMore"); y = y - 28
        OptBox(pg, LX, y, "Min. auction gain", "ahMinOn", "ahMin", "g",
            "Only suggest the auction house when it beats vendoring by at least this much (after the 5% cut)."); y = y - 26
        Desc(pg, LX, y, "Auction prices have the 5% auction house cut taken off.", 16)

        local ry = -8 - 26 - 32 - 32 - 44
        Section(pg, RX, ry, "Auction house"); ry = ry - 26
        Opt(pg, RX, ry, "Auction scanner", "auction", function() main:UpdateNav() end,
            "Adds the Auction page and a Salvage button on the auction house to find gear worth more disenchanted than its price."); ry = ry - 26
        Desc(pg, RX, ry, "Finds gear on the auction house worth more disenchanted than its buyout.", 30); ry = ry - 38
        Opt(pg, RX, ry, "Select the next item after buying", "auctionNext", nil,
            "After a purchase, the next item in the list is checked and selected, ready for you to click Buy."); ry = ry - 28
        Opt(pg, RX, ry, "Keep scanning while you buy", "auctionKeepScanning", nil,
            "Buying only pauses the scan. It carries on from where it was once you buy or cancel.")
        ry = ry - 28
        Opt(pg, RX, ry, "Keep watching after a full pass", "auctionWatch", nil,
            "After checking the whole auction house once, keep looking for new and changed listings. Off: stop after one full pass.")
        ry = ry - 28
        Opt(pg, RX, ry, "Mark new finds", "auctionMarkNew", nil,
            "Puts a green NEW tag on deals that turn up while the scanner keeps watching.")
    end

    -- WINDOW ---------------------------------------------------------------
    local swatches, barInfo = {}, nil
    do
        local pg, y = pages.window, -8
        Section(pg, LX, y, "Appearance"); y = y - 26
        local sw = W.Text(pg, 12)
        sw:SetPoint("TOPLEFT", LX, y - 4)
        sw:SetText("Accent")
        for i, a in ipairs(ns.ACCENTS) do
            local b = CreateFrame("Button", nil, pg)
            b:SetSize(22, 22)
            b:SetPoint("TOPLEFT", LX + 62 + (i - 1) * 28, y)
            W.Fill(b, { a.c[1], a.c[2], a.c[3], 1 }, "BACKGROUND", 3)
            W.Border(b)
            b.key = a.key
            b:SetScript("OnClick", function()
                o.accent = a.key
                W.RefreshAccent()
                ns.Fire("REFRESH")
            end)
            swatches[#swatches + 1] = b
        end
        y = y - 34
        Seg(pg, LX, y, "Scale", 62, { { value = 0.9, label = "90%" }, { value = 1, label = "100%" },
            { value = 1.1, label = "110%" }, { value = 1.25, label = "125%" } }, "scale", 48, function(v)
            main:SetScale(v)
            if ns.compactFrame then ns.compactFrame:SetScale(v) end
        end); y = y - 44

        Section(pg, LX, y, "Data"); y = y - 28
        local bLearn = Confirming(pg, "Reset learned results", 160, function()
            wipe(ns.db.samples); ns:RequestRefresh(0); ns.Print("Learned results cleared.")
        end, "Forgets what your own disenchants have taught it and goes back to the tables.")
        bLearn:SetPoint("TOPLEFT", LX, y)
        local bCheck = W.Button(pg, "Self-check", 96, 26)
        bCheck:SetPoint("LEFT", bLearn, "RIGHT", 6, 0)
        W.Tip(bCheck, "Self-check", "Opens a report you can copy into a bug report.")
        bCheck:SetScript("OnClick", function() ns.ShowReport() end)

        local ry = -8
        Section(pg, RX, ry, "Minimap and data bar"); ry = ry - 26
        Track(W.Toggle(pg, "Minimap button", function() return not o.minimap.hide end, function(v)
            o.minimap.hide = not v
            ns.UpdateMinimap()
        end)):SetPoint("TOPLEFT", RX, ry); ry = ry - 28
        Opt(pg, RX, ry, "Minimap count badge", "badge", function() ns.UpdateMinimap() end); ry = ry - 28
        Opt(pg, RX, ry, "Session count on the data bar", "brokerSession", function() ns.UpdateBroker() end); ry = ry - 30
        barInfo = Desc(pg, RX, ry, nil, 30)
    end

    local foot = W.Text(p, 10, C.faint)
    foot:SetPoint("BOTTOMLEFT", 24, 16)
    foot:SetText("Salvage Station v" .. ns.VERSION .. "   ·   /salvage help for commands")

    local page = { frame = p }
    function page.onShow() Select(current) end
    function page.refresh()
        for _, c in ipairs(controls) do c:Refresh() end
        for _, fn in ipairs(refreshers) do fn() end
        for _, b in ipairs(swatches) do
            if b.key == (o.accent or "violet") then W.SetBorderColor(b, 1, 1, 1, 0.9) else W.SetBorderColor(b, unpack(C.border)) end
        end
        local src = ns.Prices.Source()
        priceInfo:SetText(src and ("Using |cff52de7c" .. src .. "|r prices. TSM is used first when both are installed.")
            or "No TSM or Auctionator found - only vendor prices are shown.")
        barInfo:SetText("Data bar: " .. ns.BrokerStatus())
        for _, b in ipairs(buttons) do b:SetActive(b.key == current) end
    end
    Select(current)
    return page
end
