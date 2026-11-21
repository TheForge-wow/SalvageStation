-- Salvage Station: main window (Artisan Network layout), confirm dialog,
-- self-check report, minimap button, slash commands
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

local WIDTH, HEIGHT, SIDE_W = 760, 600, 170
ns.PageBuilders = {}

local NAV = {
    { key = "disenchant", label = "Disenchant", icon = 132854 },
    { key = "stats",      label = "Statistics", icon = "Interface\\Icons\\INV_Misc_Note_05" },
    { key = "auction",    label = "Auction",    icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { key = "ignored",    label = "Ignored",    icon = "Interface\\Icons\\Spell_Holy_DivineProtection" },
    { key = "settings",   label = "Settings",   icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

------------------------------------------------------------------------
-- Window helpers used everywhere
------------------------------------------------------------------------
function ns.IsAnyWindowShown()
    return (ns.main and ns.main:IsShown()) or (ns.compactFrame and ns.compactFrame:IsShown()) or false
end

function ns.CloseWindows(forCombat)
    if ns.main and ns.main:IsShown() then ns.main:Hide() end
    if ns.compactFrame and ns.compactFrame:IsShown() then ns.compactFrame:Hide() end
    if not forCombat then ns.openedBy = nil end
end

-- by: "auto", "vendor", "bags" (closes again with them) or nil; page: open the full window on that page
function ns.OpenWindow(by, page)
    if InCombatLockdown() then ns.Print("Can't open during combat."); return end
    if not ns.main then return end
    local wantCompact = (by == "compact") or (not page and ns.opts.compact)
    if wantCompact and ns.compactFrame then
        if ns.main:IsShown() then ns.main:Hide() end
        ns.compactFrame:Show()
    else
        if ns.compactFrame and ns.compactFrame:IsShown() then ns.compactFrame:Hide() end
        ns.main:ShowPage(page or ns.main.page or "disenchant")
    end
    ns.openedBy = (by == "auto" or by == "vendor" or by == "bags") and by or nil
end

function ns.ToggleWindow()
    if ns.IsAnyWindowShown() then ns.CloseWindows() else ns.OpenWindow() end
end

------------------------------------------------------------------------
-- Main frame
------------------------------------------------------------------------
local function CreateMain()
    local f = CreateFrame("Frame", "SalvageStationFrame", UIParent)
    ns.main = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScale(ns.opts.scale or 1)
    f:Hide()
    W.Fill(f, C.bg)
    W.Border(f, { 0, 0, 0, 1 })
    tinsert(UISpecialFrames, "SalvageStationFrame")
    local pos = ns.opts.pos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER") end

    -- header
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", 1, -1)
    h:SetPoint("TOPRIGHT", -1, -1)
    h:SetHeight(44)
    W.Fill(h, C.header)
    local hl = W.Line(h, true, { 1, 1, 1, 0.06 })
    hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p1, _, p2, x, y = f:GetPoint()
        ns.opts.pos = { p1, p2, x, y }
    end)

    local mark = h:CreateTexture(nil, "ARTWORK")
    mark:SetSize(26, 26)
    mark:SetPoint("LEFT", 13, 0)
    mark:SetTexture(ns.MEDIA .. "Icon")
    local t1 = W.Text(h, 15)
    t1:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    t1:SetText("SALVAGE")
    W.Accentize(t1, "text")
    local t2 = W.Text(h, 15, C.text)
    t2:SetPoint("LEFT", t1, "RIGHT", 5, 0)
    t2:SetText("STATION")
    local ver = W.Text(h, 10, C.faint)
    ver:SetPoint("LEFT", t2, "RIGHT", 10, -1)
    ver:SetText("v" .. ns.VERSION)

    local close = CreateFrame("Button", nil, h)
    close:SetSize(30, 30)
    close:SetPoint("RIGHT", -8, 0)
    close.bg = W.Fill(close, { 1, 1, 1, 0 })
    close.text = W.Text(close, 14, C.dim, "CENTER")
    close.text:SetPoint("CENTER", 0, 1)
    close.text:SetText("x")
    close:SetScript("OnClick", function() ns.CloseWindows() end)
    close:SetScript("OnEnter", function(s) s.bg:SetColorTexture(1, 0.3, 0.35, 0.25); s.text:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function(s) s.bg:SetColorTexture(1, 1, 1, 0); s.text:SetTextColor(unpack(C.dim)) end)

    local compactBtn = W.Button(h, "Compact", 74, 24)
    compactBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
    compactBtn:SetScript("OnClick", function()
        ns.opts.compact = true
        ns.OpenWindow("compact")
    end)
    W.Tip(compactBtn, "Compact bar", "Switch to the small floating bar. It shows the next item and a Disenchant button.")

    f.hStatus = W.Text(h, 11, C.dim, "RIGHT")
    f.hStatus:SetPoint("RIGHT", compactBtn, "LEFT", -14, 0)
    f.hDot = h:CreateTexture(nil, "ARTWORK")
    f.hDot:SetSize(8, 8)
    f.hDot:SetPoint("RIGHT", f.hStatus, "LEFT", -7, 0)

    -- sidebar
    local s = CreateFrame("Frame", nil, f)
    s:SetPoint("TOPLEFT", h, "BOTTOMLEFT")
    s:SetPoint("BOTTOMLEFT", 1, 1)
    s:SetWidth(SIDE_W)
    W.Fill(s, C.side)
    local sl = W.Line(s, false, { 1, 1, 1, 0.05 })
    sl:SetPoint("TOPRIGHT"); sl:SetPoint("BOTTOMRIGHT")

    f.nav = {}
    for i, n in ipairs(NAV) do
        local b = CreateFrame("Button", nil, s)
        b:SetHeight(36)
        b:SetPoint("TOPLEFT", 0, -14 - (i - 1) * 38)
        b:SetPoint("TOPRIGHT", -1, -14 - (i - 1) * 38)
        b.bg = W.Fill(b, { 0, 0, 0, 0 })
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetWidth(2)
        b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 20, 0)
        b.icon:SetTexture(n.key == "disenchant" and ns.DEIcon() or n.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.text = W.Text(b, 12, C.dim)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 12, 0)
        b.text:SetText(n.label)
        b.badge = W.Text(b, 10, C.faint, "RIGHT")
        b.badge:SetPoint("RIGHT", -14, 0)
        b:SetScript("OnClick", function() f:ShowPage(n.key) end)
        b:SetScript("OnEnter", function(self)
            if f.page ~= n.key then
                self.text:SetTextColor(unpack(C.text))
                self.bg:SetColorTexture(1, 1, 1, 0.03)
            end
        end)
        b:SetScript("OnLeave", function() f:UpdateNav() end)
        f.nav[n.key] = b
    end

    f.sidePrice = W.Text(s, 10, C.dim)
    f.sidePrice:SetPoint("BOTTOMLEFT", 20, 36)
    f.sideSkill = W.Text(s, 10, C.dim)
    f.sideSkill:SetPoint("BOTTOMLEFT", 20, 18)

    -- content + pages
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", s, "TOPRIGHT")
    content:SetPoint("BOTTOMRIGHT", -1, 1)
    f.content = content
    f.pages = {}
    for _, n in ipairs(NAV) do
        local build = ns.PageBuilders[n.key]
        if build then
            local pg = build(content, f)
            pg.frame:Hide()
            f.pages[n.key] = pg
        end
    end

    function f:UpdateNav()
        local r, g, bb = ns.Accent()
        for key, b in pairs(self.nav) do
            local on = key == self.page
            b.bar:SetColorTexture(r, g, bb, 1)
            b.bar:SetShown(on)
            b.bg:SetColorTexture(r, g, bb, on and 0.10 or 0)
            b.text:SetTextColor(unpack(on and C.text or C.dim))
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(on and 1 or 0.55)
        end
        local ready = ns.known and ns.ReadyCount() or 0
        self.nav.disenchant.badge:SetText(ready > 0 and ("|cff" .. ns.AccentHex() .. ready .. "|r") or "")
        self.nav.stats.badge:SetText(ns.session and ns.session.count > 0 and ns.session.count or "")
        local rows = ns.AuctionScan and #ns.AuctionScan.rows or 0
        self.nav.auction.badge:SetText(rows > 0 and ("|cff52de7c" .. rows .. "|r") or "")
        self.nav.auction:SetShown(ns.opts.auction)
        self.nav.settings:ClearAllPoints()
        local idx = ns.opts.auction and 5 or 4
        self.nav.settings:SetPoint("TOPLEFT", 0, -14 - (idx - 1) * 38)
        self.nav.settings:SetPoint("TOPRIGHT", -1, -14 - (idx - 1) * 38)
        self.nav.ignored:ClearAllPoints()
        local iidx = ns.opts.auction and 4 or 3
        self.nav.ignored:SetPoint("TOPLEFT", 0, -14 - (iidx - 1) * 38)
        self.nav.ignored:SetPoint("TOPRIGHT", -1, -14 - (iidx - 1) * 38)
        local n = 0
        for _ in pairs(ns.db.ignore) do n = n + 1 end
        self.nav.ignored.badge:SetText(n > 0 and n or "")
    end

    function f:UpdateChrome()
        local ready = ns.known and ns.ReadyCount() or 0
        if not ns.known then
            self.hStatus:SetText("Disenchant not learned")
        elseif ns.busy then
            self.hStatus:SetText("Disenchanting...")
        else
            self.hStatus:SetText(ready .. " ready to disenchant")
        end
        local r, g, b = ns.Accent()
        if ready > 0 then self.hDot:SetColorTexture(r, g, b, 1) else self.hDot:SetColorTexture(unpack(C.faint)) end
        local src = ns.Prices.Source()
        self.sidePrice:SetText("Prices  " .. (src and ("|cff52de7c" .. src .. "|r") or "|cffd0d0d6Vendor only|r"))
        self.sideSkill:SetText("Enchanting  |cffd0d0d6" .. (ns.enchSkill or "-") .. "|r")
        self:UpdateNav()
    end

    function f:ShowPage(key)
        if key == "auction" and not ns.opts.auction then key = "disenchant" end
        if not self.pages[key] then key = "disenchant" end
        self.page = key
        for k, pg in pairs(self.pages) do pg.frame:SetShown(k == key) end
        if not self:IsShown() then self:Show() end
        local pg = self.pages[key]
        if pg.onShow then pg.onShow() end
        self:Refresh()
        ns.UpdateHotkey()
    end

    function f:Refresh()
        if not self:IsShown() then return end
        self:UpdateChrome()
        local pg = self.pages[self.page]
        if pg and pg.refresh then pg.refresh() end
    end

    f:SetScript("OnShow", function() ns:RequestRefresh(0) end)
    f:SetScript("OnHide", function()
        ns.ClearSkipped()
        if ns.confirmFrame and ns.confirmFrame:IsShown() then ns.confirmFrame:Hide() end
        ns.UpdateHotkey()
    end)
    W.OnAccent(function() f:UpdateNav() end)
end

ns.Listen("REFRESH", function()
    if ns.main and ns.main:IsShown() then ns.main:Refresh() end
end)
ns.Listen("BUSY", function()
    if ns.main and ns.main:IsShown() then ns.main:Refresh() end
end)
ns.Listen("STATS", function()
    if ns.main and ns.main:IsShown() then ns.main:UpdateNav(); if ns.main.page == "stats" then ns.main:Refresh() end end
end)
ns.Listen("AUCTION", function()
    if ns.main and ns.main:IsShown() then ns.main:UpdateNav(); if ns.main.page == "auction" then ns.main:Refresh() end end
end)
ns.Listen("SELECTION", function()
    if ns.main and ns.main:IsShown() then ns.main:Refresh() end
end)

------------------------------------------------------------------------
-- Confirm dialog (its Disenchant button is a secure cast button)
------------------------------------------------------------------------
local QCOL = { [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 } }
ns.QCOL = QCOL

local function CreateConfirm()
    local cf = CreateFrame("Frame", "SalvageStationConfirm", UIParent)
    ns.confirmFrame = cf
    cf:SetSize(360, 192)
    cf:SetPoint("CENTER", 0, 140)
    cf:SetFrameStrata("FULLSCREEN_DIALOG")
    cf:SetClampedToScreen(true)
    cf:EnableMouse(true)
    cf:Hide()
    W.Fill(cf, C.bg)
    W.Border(cf, { 0, 0, 0, 1 })
    tinsert(UISpecialFrames, "SalvageStationConfirm")
    local top = cf:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 1, -1); top:SetPoint("TOPRIGHT", -1, -1); top:SetHeight(2)
    W.Accentize(top, "tex")

    local lbl = W.Label(cf, "Confirm disenchant")
    lbl:SetPoint("TOPLEFT", 18, -16)
    cf.icon = W.Icon(cf, 34)
    cf.icon:SetPoint("TOPLEFT", 18, -38)
    cf.name = W.Text(cf, 13)
    cf.name:SetPoint("TOPLEFT", cf.icon, "TOPRIGHT", 12, -1)
    cf.name:SetPoint("RIGHT", -18, 0)
    cf.reason = W.Text(cf, 11, C.dim)
    cf.reason:SetPoint("TOPLEFT", cf.name, "BOTTOMLEFT", 0, -5)
    cf.reason:SetPoint("RIGHT", -18, 0)
    cf.reason:SetWordWrap(true)
    cf.reason:SetJustifyV("TOP")
    cf.reason:SetHeight(42)

    local yes = CreateFrame("Button", "SalvageStationConfirmButton", cf, "SecureActionButtonTemplate")
    yes:SetSize(156, 30)
    yes:SetPoint("BOTTOMLEFT", 18, 16)
    yes.bg = W.Fill(yes, { 1, 1, 1, 1 })
    W.Border(yes)
    yes.text = W.Text(yes, 12, { 1, 1, 1 }, "CENTER")
    yes.text:SetPoint("CENTER")
    yes.text:SetText("Disenchant")
    local function Paint(hover)
        local r, g, b = ns.Accent()
        yes.bg:SetColorTexture(r, g, b, hover and 0.45 or 0.30)
        W.SetBorderColor(yes, r, g, b, 0.9)
    end
    yes:SetScript("OnEnter", function() Paint(true) end)
    yes:SetScript("OnLeave", function() Paint(false) end)
    W.OnAccent(function() Paint(false) end)
    Paint(false)
    ns.MakeCastButton(yes, function() return cf.entry end, true)

    -- "Don't ask again" for this item until you log out
    cf.remember = false
    cf.rememberToggle = W.Toggle(cf, "Don't ask again for this item this session",
        function() return cf.remember end, function(v) cf.remember = v end, 324)
    cf.rememberToggle:SetPoint("BOTTOMLEFT", 18, 56)
    W.Tip(cf.rememberToggle, "Don't ask again",
        "Disenchants more of this item without asking until you log out or /reload. Undo it on the Ignored page or in Settings > Protection.")
    yes:HookScript("PostClick", function()
        if cf.remember and cf.entry then ns.TrustForSession(cf.entry.itemID) end
        if not InCombatLockdown() then cf:Hide() end
    end)

    local no = W.Button(cf, "Cancel", 156, 30)
    no:SetPoint("BOTTOMRIGHT", -18, 16)
    no:SetScript("OnClick", function() cf:Hide() end)
    cf:SetScript("OnHide", function(self) self.entry = nil end)

    function ns.ShowConfirm(e)
        if InCombatLockdown() or not e then return end
        cf.entry = e
        local q = QCOL[e.quality] or { 1, 1, 1 }
        cf.icon.tex:SetTexture(e.icon)
        cf.name:SetText(e.name)
        cf.name:SetTextColor(q[1], q[2], q[3])
        cf.reason:SetText((e.confirm or "") .. "\nDisenchant it anyway?")
        cf.remember = false
        cf.rememberToggle:SetShown(ns.opts.confirmRemember and true or false)
        cf.rememberToggle:Refresh()
        ns.SyncClicks(yes)
        cf:Show()
    end
end

------------------------------------------------------------------------
-- Self-check (Disenchantry): copyable report
------------------------------------------------------------------------
function ns.Report()
    local L = {}
    local function add(k, v) L[#L + 1] = k .. ": " .. tostring(v) end
    local version, build = GetBuildInfo()
    add("Salvage Station", ns.VERSION)
    add("Client", tostring(version) .. " (" .. tostring(build) .. ") toc " .. ns.TOC)
    add("WoW Forever", ns.isForever and "yes" or "no")
    add("Disenchant known", ns.KnowsDisenchant() and "yes" or "no")
    add("Enchanting skill", ns.enchSkill or "?")
    add("Bags scanned", #ns.BAGS)
    add("Listed / ready", #ns.list .. " / " .. ns.ReadyCount())
    local c = ns.counts
    add("Hidden", string.format("filters %d, ignored %d, skipped %d, soulbound %d, protected %d",
        c.filtered, c.ignored, c.skipped, c.soulbound, c.protected))
    add("Prices", ns.Prices.Status() .. " -> using " .. tostring(ns.Prices.Source() or "vendor only"))
    add("Data bar", ns.BrokerStatus())
    add("Auction house API", ns.AuctionScan.Supported() and "supported" or "not available")
    add("Auction scan", tostring(ns.AuctionScan.state) .. (ns.AuctionScan.lastError and (" err=" .. ns.AuctionScan.lastError) or ""))
    add("Hotkey", ns.opts.hotkey or "none")
    add("Click on key down", (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and "yes" or "no")
    add("Busy", ns.busy and "yes" or "no")
    local n = 0
    for _ in pairs(ns.db.samples) do n = n + 1 end
    add("Learned buckets", n)
    add("Salvager buff", ns.HasSalvagerBuff() and "active" or "no")
    return L
end

local copyFrame
function ns.ShowReport()
    if not copyFrame then
        copyFrame = CreateFrame("Frame", "SalvageStationReport", UIParent)
        copyFrame:SetSize(520, 340)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        copyFrame:EnableMouse(true)
        copyFrame:SetMovable(true)
        copyFrame:RegisterForDrag("LeftButton")
        copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
        copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
        W.Fill(copyFrame, C.bg)
        W.Border(copyFrame, { 0, 0, 0, 1 })
        tinsert(UISpecialFrames, "SalvageStationReport")
        local t = W.Label(copyFrame, "Self-check report")
        t:SetPoint("TOPLEFT", 16, -14)
        local hint = W.Text(copyFrame, 11, C.dim)
        hint:SetPoint("TOPLEFT", 16, -30)
        hint:SetText("Ctrl+A to select, Ctrl+C to copy, then paste it into your bug report.")
        local x = W.Button(copyFrame, "Close", 70, 22)
        x:SetPoint("TOPRIGHT", -12, -10)
        x:SetScript("OnClick", function() copyFrame:Hide() end)
        local sf = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -52)
        sf:SetPoint("BOTTOMRIGHT", -34, 14)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFont(STANDARD_TEXT_FONT, 11, "")
        eb:SetTextColor(0.9, 0.9, 0.92)
        eb:SetWidth(460)
        eb:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
        sf:SetScrollChild(eb)
        copyFrame.eb = eb
    end
    copyFrame.eb:SetText(table.concat(ns.Report(), "\n"))
    copyFrame:Show()
    copyFrame.eb:SetFocus()
    copyFrame.eb:HighlightText()
end

------------------------------------------------------------------------
-- Minimap button (with ready-count badge)
------------------------------------------------------------------------
local function CreateMinimapButton()
    local b = CreateFrame("Button", "SalvageStationMinimapButton", Minimap)
    ns.minimapButton = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    icon:SetTexture(ns.MEDIA .. "Minimap")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local badge = CreateFrame("Frame", nil, b)
    badge:SetSize(18, 14)
    badge:SetPoint("BOTTOMRIGHT", 2, 0)
    badge:SetFrameLevel(b:GetFrameLevel() + 2)
    local bbg = W.Fill(badge, { 0, 0, 0, 1 })
    W.Border(badge)
    badge.text = W.Text(badge, 9, { 1, 1, 1 }, "CENTER")
    badge.text:SetPoint("CENTER")
    local function PaintBadge()
        local r, g, bl = ns.Accent()
        bbg:SetColorTexture(r * 0.45, g * 0.45, bl * 0.45, 1)
        W.SetBorderColor(badge, r, g, bl, 1)
    end
    W.OnAccent(PaintBadge)
    PaintBadge()
    badge:Hide()

    local function Place()
        local a = math.rad(ns.opts.minimap.angle or 210)
        local r = (Minimap:GetWidth() / 2) + 5
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    Place()
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            ns.opts.minimap.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.OpenWindow(nil, "settings")
        elseif IsShiftKeyDown() then ns.OpenWindow(nil, "stats")
        else ns.ToggleWindow() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff" .. ns.AccentHex() .. "Salvage|r Station")
        if ns.known then GameTooltip:AddLine(ns.ReadyCount() .. " ready to disenchant", 1, 1, 1) end
        GameTooltip:AddLine("Click: open  ·  Shift+click: statistics  ·  Right-click: settings", unpack(C.dim))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function ns.UpdateMinimap()
        b:SetShown(not ns.opts.minimap.hide)
        local n = ns.known and ns.ReadyCount() or 0
        if ns.opts.badge and n > 0 then
            badge.text:SetText(n > 99 and "99+" or n)
            badge:Show()
        else
            badge:Hide()
        end
    end
    ns.UpdateMinimap()
end
ns.Listen("REFRESH", function() if ns.UpdateMinimap then ns.UpdateMinimap() end end)

------------------------------------------------------------------------
-- "Learned!" message when a kind of item reaches its 10th disenchant
------------------------------------------------------------------------
local toast
ns.Listen("LEARNED", function(key)
    local name = ns.Forecast.BucketName(key)
    ns.Print("|cff52de7cLearned!|r " .. name .. " now uses your own results.")
    if not toast then
        toast = CreateFrame("Frame", nil, UIParent)
        toast:SetSize(380, 40)
        toast:SetPoint("TOP", 0, -160)
        toast:SetFrameStrata("FULLSCREEN_DIALOG")
        W.Fill(toast, C.bg)
        W.Border(toast, { 0.32, 0.87, 0.49, 0.6 })
        toast.icon = W.Icon(toast, 22)
        toast.icon:SetPoint("LEFT", 10, 0)
        toast.icon.tex:SetTexture(ns.DEIcon())
        toast.text = W.Text(toast, 12, C.text)
        toast.text:SetPoint("LEFT", toast.icon, "RIGHT", 10, 0)
        toast.text:SetPoint("RIGHT", -10, 0)
        toast:Hide()
    end
    toast.text:SetText("|cff52de7cLearned!|r " .. name .. " now uses your results.")
    toast:SetAlpha(1)
    toast:Show()
    local my = {}
    toast.token = my
    C_Timer.After(5, function()
        if toast.token ~= my then return end
        if UIFrameFadeOut then UIFrameFadeOut(toast, 0.6, 1, 0) end
        C_Timer.After(0.7, function() if toast.token == my then toast:Hide() end end)
    end)
    ns.Fire("STATS")
end)

------------------------------------------------------------------------
-- Startup, slash commands, key bindings
------------------------------------------------------------------------
ns.Listen("LOGIN", function()
    CreateMain()
    CreateConfirm()
    if ns.CreateCompact then ns.CreateCompact() end
    CreateMinimapButton()
end)

BINDING_HEADER_SALVAGESTATION = "Salvage Station"
BINDING_NAME_SALVAGESTATION_TOGGLE = "Open / close"
_G["BINDING_NAME_CLICK SalvageStationNextButton:LeftButton"] = "Disenchant next (window open)"
_G["BINDING_NAME_CLICK SalvageStationCompactCast:LeftButton"] = "Disenchant next (compact bar open)"
function SalvageStation_Toggle() ns.ToggleWindow() end

SLASH_SALVAGESTATION1 = "/salvage"
SLASH_SALVAGESTATION2 = "/sst"
SlashCmdList.SALVAGESTATION = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        ns.ToggleWindow()
    elseif msg == "compact" then
        ns.opts.compact = true
        ns.OpenWindow("compact")
    elseif msg == "full" then
        ns.opts.compact = false
        ns.OpenWindow()
    elseif msg == "stats" then
        ns.OpenWindow(nil, "stats")
    elseif msg == "settings" or msg == "options" then
        ns.OpenWindow(nil, "settings")
    elseif msg == "auction" or msg == "ah" then
        ns.OpenWindow(nil, "auction")
    elseif msg == "check" then
        for _, line in ipairs(ns.Report()) do print("  " .. line) end
        ns.Print("Type /salvage copy to open a copyable report.")
    elseif msg == "copy" then
        ns.ShowReport()
    elseif msg == "refresh" then
        ns:RequestRefresh(0)
        ns.Print("Bags rescanned.")
    elseif msg == "reset" then
        ns.opts.pos = nil
        if ns.main then ns.main:ClearAllPoints(); ns.main:SetPoint("CENTER") end
        ns.opts.compactPos = nil
        if ns.compactFrame then ns.compactFrame:ClearAllPoints(); ns.compactFrame:SetPoint("CENTER", 0, -220) end
        ns.Print("Window positions reset.")
    elseif msg == "minimap" then
        ns.opts.minimap.hide = not ns.opts.minimap.hide
        ns.UpdateMinimap()
    else
        ns.Print("commands:")
        print("  /salvage - open or close")
        print("  /salvage compact | full - switch between the compact bar and the full window")
        print("  /salvage stats | settings | auction - open a page")
        print("  /salvage refresh - rescan your bags")
        print("  /salvage check - self-check  ·  /salvage copy - copyable report")
        print("  /salvage minimap - show or hide the minimap button")
        print("  /salvage reset - reset window positions")
        print("  Alt+Right-click an item in your bags to ignore it")
    end
end
