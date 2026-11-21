-- Salvage Station: a panel attached to item tooltips (full or compact)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C
local TP = {}
ns.TipPanel = TP

local MIN_W = { full = 270, compact = 240 }
local PAD = 10
local panels = {}

local SELL = { 1, 0.82, 0.2 }
local GOOD = { 0.32, 0.87, 0.49 }

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------
local function NewBar(parent, w, h)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(w, h)
    W.Fill(b, { 1, 1, 1, 0.07 })
    b.fill = b:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT")
    b.fill:SetPoint("BOTTOMLEFT")
    function b:Apply()
        local frac = self.frac or 0
        self.fill:SetWidth(math.max(1, (self:GetWidth() or 0) * frac))
        self.fill:SetShown(frac > 0)
    end
    function b:Set(frac, r, g, bl)
        self.frac = math.max(0, math.min(1, frac or 0))
        self.fill:SetColorTexture(r, g, bl, 1)
        self:Apply()
    end
    b:SetScript("OnSizeChanged", function(self) self:Apply() end)
    return b
end

local function MatRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(20)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("TOPLEFT", 0, -3)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = W.Text(r, 11)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
    r.pct = W.Text(r, 10, C.dim, "RIGHT")
    r.pct:SetPoint("TOPRIGHT", 0, -4)
    r.pct:SetWidth(38)
    r.bar = NewBar(r, 80, 5)
    r.bar:SetPoint("RIGHT", r.pct, "LEFT", -6, 0)
    r.name:SetPoint("RIGHT", r.bar, "LEFT", -8, 0)
    r.sub = W.Text(r, 9, C.faint)
    r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 21, -16)
    return r
end

local function ValueRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(20)
    r.label = W.Text(r, 11, C.dim)
    r.label:SetPoint("LEFT")
    r.badge = CreateFrame("Frame", nil, r)
    r.badge:SetSize(32, 13)
    W.Border(r.badge, { 0.32, 0.87, 0.49, 0.5 })
    r.badge.text = W.Text(r.badge, 8, { 0.32, 0.87, 0.49 }, "CENTER")
    r.badge.text:SetPoint("CENTER", 0, 0)
    r.badge.text:SetText("BEST")
    r.value = W.Text(r, 11, C.text, "RIGHT")
    r.value:SetPoint("RIGHT")
    r.value:SetWidth(76)
    r.bar = NewBar(r, 80, 7)
    r.bar:SetPoint("LEFT", r, "LEFT", 108, 0)
    r.bar:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
    return r
end

local function Create(tt)
    local p = CreateFrame("Frame", nil, tt)
    p:SetFrameStrata("TOOLTIP")
    p:SetFrameLevel(tt:GetFrameLevel() + 5)
    p:Hide()
    W.Fill(p, { 0.047, 0.047, 0.055, 0.97 })
    W.Border(p, { 0, 0, 0, 1 })

    -- header
    p.head = CreateFrame("Frame", nil, p)
    p.head:SetPoint("TOPLEFT", 1, -1)
    p.head:SetPoint("TOPRIGHT", -1, -1)
    p.head:SetHeight(26)
    W.Fill(p.head, C.header)
    local top = p.head:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(2)
    W.Accentize(top, "tex")
    local hl = W.Line(p.head, true, { 1, 1, 1, 0.06 })
    hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")
    p.mark = W.Icon(p.head, 16)
    p.mark:SetPoint("LEFT", 8, -1)
    p.mark.tex:SetTexture(ns.DEIcon())
    p.t1 = W.Text(p.head, 11)
    p.t1:SetPoint("LEFT", p.mark, "RIGHT", 7, 0)
    p.t1:SetText("SALVAGE")
    W.Accentize(p.t1, "text")
    p.t2 = W.Text(p.head, 11, C.text)
    p.t2:SetPoint("LEFT", p.t1, "RIGHT", 4, 0)
    p.t2:SetText("STATION")
    p.tag = CreateFrame("Frame", nil, p.head)
    p.tag:SetHeight(15)
    p.tag:SetPoint("LEFT", p.t2, "RIGHT", 7, 0)
    p.tag.border = W.Border(p.tag)
    p.tag.text = W.Text(p.tag, 9, C.text, "CENTER")
    p.tag.text:SetPoint("CENTER", 0, 0)
    p.right = W.Text(p.head, 9, C.dim, "RIGHT")
    p.right:SetPoint("RIGHT", -8, -1)

    p.mats = {}
    for i = 1, 4 do p.mats[i] = MatRow(p) end
    p.sep = W.Line(p, true)
    p.vRows = { ValueRow(p), ValueRow(p), ValueRow(p) }
    p.note = W.Text(p, 10, C.dim)
    p.note:SetWordWrap(true)

    p.verdict = CreateFrame("Frame", nil, p)
    p.verdict.bg = W.Fill(p.verdict, { 1, 1, 1, 0.08 })
    W.Border(p.verdict)
    p.verdict.text = W.Text(p.verdict, 11, C.text)
    p.verdict.text:SetPoint("LEFT", 8, 0)
    p.verdict.text:SetWordWrap(true)
    p.verdict.text:SetJustifyV("MIDDLE")

    p.xp = CreateFrame("Frame", nil, p)
    p.xp:SetPoint("BOTTOMLEFT", 1, 1)
    p.xp:SetPoint("BOTTOMRIGHT", -1, 1)
    p.xp:SetHeight(4)
    W.Fill(p.xp, { 1, 1, 1, 0.14 })
    p.xp.fill = p.xp:CreateTexture(nil, "ARTWORK")
    p.xp.fill:SetPoint("TOPLEFT")
    p.xp.fill:SetPoint("BOTTOMLEFT")

    p.foot = W.Text(p, 9, C.faint)
    p.footR = W.Text(p, 9, C.faint, "RIGHT")

    -- other addons add lines after us: keep matching the tooltip's final size
    tt:HookScript("OnSizeChanged", function()
        if not p:IsShown() or p.relayout then return end
        if math.abs((tt:GetWidth() or 0) - p:GetWidth()) > 0.5 and TP.last and TP.last.tt == tt then
            p.relayout = true
            TP.Attach(tt, TP.last.link)
            p.relayout = false
        else
            TP.Place(p, tt)
        end
    end)
    tt:HookScript("OnTooltipCleared", function() p:Hide() end)
    tt:HookScript("OnHide", function() p:Hide() end)
    return p
end

------------------------------------------------------------------------
-- What the panel needs to know about an item
------------------------------------------------------------------------
local SOULBOUND = { ITEM_SOULBOUND, ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND }
-- Is the item in this tooltip soulbound? (looks at the first few tooltip lines)
local function TooltipBound(tt)
    local name = tt.GetName and tt:GetName()
    if not name then return false end
    for i = 2, 5 do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t then
            for _, b in ipairs(SOULBOUND) do if b and t == b then return true end end
        end
    end
    return false
end

local function Info(link, tt)
    local item = ns.ItemFromLink(link)
    if not item or ns.Data.IsExcluded(item.itemID) or ns.db.noDE[item.itemID] then return end
    local res, src, n = ns.Forecast.Get(item)
    local vendor = ns.Prices.Vendor(item.itemID)
    local de = ns.Forecast.Value(item)
    local bindType = select(14, ns.ItemInfo(link))
    local bound = bindType == 1 or TooltipBound(tt)

    -- status tag
    local tag, tagColor
    if ns.db.ignore[item.itemID] or ns.sessionIgnore[item.itemID] then
        tag, tagColor = "Ignored", C.faint
    else
        for _, e in ipairs(ns.list) do
            if e.itemID == item.itemID and e.protected then tag, tagColor = e.protected, { 1, 0.73, 0.27 }; break end
        end
    end
    local inBags = false
    for _, e in ipairs(ns.list) do if e.itemID == item.itemID then inBags = true; break end end
    return { item = item, res = res, src = src, n = n, vendor = vendor, de = de,
             use = ns.Forecast.Best(item.itemID, vendor, bound, de),
             tag = tag, tagColor = tagColor, inBags = inBags }
end

local function SrcShort(src, n)
    if src == "learned" then return "|cff52de7cYOUR RESULTS · " .. n .. "|r" end
    if src == "forever" then return "Forever estimate" end
    if src == "table" then return "Estimate" end
    return "No data yet"
end
-- learning progress shown in the footer
local function Learning(src, n)
    if src == "learned" or src == "none" then return nil end
    return "Learning " .. (n or 0) .. "/" .. ns.Forecast.LEARN_MIN
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
local function Layout(p, d, style)
    local o = ns.opts
    local r, g, b = ns.Accent()
    local y = -26 - 8

    -- header
    if d.tag then
        p.tag.text:SetText(d.tag)
        p.tag.text:SetTextColor(unpack(d.tagColor))
        W.SetBorderColor(p.tag, d.tagColor[1], d.tagColor[2], d.tagColor[3], 0.5)
        p.tag:SetWidth(p.tag.text:GetStringWidth() + 12)
        p.tag:Show()
    else
        p.tag:Hide()
    end
    local width = p:GetWidth()
    if style == "compact" then
        local ready = d.inBags and not d.tag and ns.known
        p.right:SetText(ready and "|cff52de7cReady|r" or SrcShort(d.src, d.n))
    else
        p.right:SetText(SrcShort(d.src, d.n))
    end
    -- don't let the source run into the tag on narrow tooltips
    p.right:SetShown(not d.tag or width >= 300)
    local barW = math.floor(math.max(36, math.min(80, (width - 2 * PAD) * 0.22)))

    -- materials (green once learned, with what the estimate said)
    local learned = d.src == "learned"
    local est = {}
    if learned and style == "full" then
        local t = ns.Data.Table(d.item.itemID, d.item.quality, d.item.baseIlvl, d.item.classID)
        for _, e in ipairs(t or {}) do est[e[1]] = e[2] end
    end
    local GREEN = { 0.32, 0.87, 0.49 }
    local nm = 0
    for i, row in ipairs(p.mats) do
        local m = d.res and d.res[i]
        if m then
            nm = nm + 1
            local q = ns.QCOL[ns.ItemQuality(m.id)] or { 1, 1, 1 }
            local range = (m.min == m.max) and (m.min .. "x ") or (m.min .. "-" .. m.max .. "x ")
            row.icon:SetTexture(ns.ItemIcon(m.id))
            row.name:SetText(range .. ns.ItemName(m.id))
            row.name:SetTextColor(q[1], q[2], q[3])
            row.pct:SetText(ns.Pct(m.chance) .. "%")
            row.bar:SetWidth(style == "compact" and math.min(60, barW) or barW)
            if learned then row.bar:Set(m.chance, GREEN[1], GREEN[2], GREEN[3]) else row.bar:Set(m.chance, r, g, b) end
            local e = est[m.id]
            local showEst = e and math.abs(e - m.chance) >= 0.005
            row.sub:SetText(showEst and ("estimate was " .. ns.Pct(e) .. "%") or "")
            row.sub:SetShown(showEst and true or false)
            local h = showEst and 30 or 20
            row:SetHeight(h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, y)
            row:SetPoint("RIGHT", -PAD, 0)
            row:Show()
            y = y - h
        else
            row:Hide()
        end
    end
    if nm == 0 then
        p.note:ClearAllPoints()
        p.note:SetPoint("TOPLEFT", PAD, y - 2)
        p.note:SetPoint("RIGHT", -PAD, 0)
        p.note:SetText("No data for this item yet. It learns as you disenchant.")
        p.note:Show()
        y = y - 30
    else
        p.note:Hide()
    end

    -- values (full only): Disenchant, Vendor, Auction
    local u = d.use
    local BLUE = { 0.44, 0.69, 1 }
    p.sep:SetShown(style == "full")
    for _, row in ipairs(p.vRows) do row:Hide() end
    if style == "full" then
        y = y - 4
        p.sep:ClearAllPoints()
        p.sep:SetPoint("TOPLEFT", PAD, y)
        p.sep:SetPoint("TOPRIGHT", -PAD, y)
        y = y - 6
        local maxV = math.max(u.de or 0, u.vendor or 0, u.ah or u.ahNet or 0, 1)
        local ahText = u.ah and ns.Money(u.ah, true)
            or (u.ahWhy == "soulbound" and "|cff8a8b94Soulbound|r")
            or (u.ahWhy == "small" and ("|cff8a8b94" .. ns.Money(u.ahNet, true) .. "|r"))
            or "|cff8a8b94no price|r"
        local defs = {
            { "de", "Disenchant", u.de, u.de and ns.Money(u.de, true) or "|cff8a8b94no prices|r", { r, g, b } },
            { "vendor", "Vendor", u.vendor, ns.Money(u.vendor, true), SELL },
            { "ah", "Auction", u.ah or u.ahNet, ahText, BLUE },
        }
        for i, def in ipairs(defs) do
            local row = p.vRows[i]
            local best = u.best == def[1] and u.second ~= nil
            row.label:SetText(def[2])
            row.label:SetTextColor(unpack(best and C.text or C.dim))
            row.badge:ClearAllPoints()
            row.badge:SetPoint("LEFT", row, "LEFT", row.label:GetStringWidth() + 6, 0)
            row.badge:SetShown(best)
            row.value:SetText(def[4])
            row.bar:Set((def[3] or 0) / maxV, def[5][1], def[5][2], def[5][3])
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, y)
            row:SetPoint("RIGHT", -PAD, 0)
            row:Show()
            y = y - 20
        end
    end

    -- verdict
    if o.tipVerdict and u.gain then
        local col = (u.best == "de") and GOOD or (u.best == "ah" and BLUE or SELL)
        p.verdict.text:SetText(ns.Forecast.USE_VERB[u.best] .. ": |cffffffff+" .. ns.Money(u.gain, true) ..
            "|r more than " .. ns.Forecast.USE_LABEL[u.second])
        p.verdict.text:SetTextColor(col[1], col[2], col[3])
        p.verdict.bg:SetColorTexture(col[1], col[2], col[3], 0.08)
        W.SetBorderColor(p.verdict, col[1], col[2], col[3], 0.4)
        y = y - 4
        p.verdict:ClearAllPoints()
        p.verdict:SetPoint("TOPLEFT", PAD, y)
        p.verdict:SetPoint("RIGHT", -PAD, 0)
        -- wrap onto a second line instead of cutting the text off
        p.verdict.text:SetWidth(width - 2 * PAD - 16)
        local vh = math.max(24, math.ceil(p.verdict.text:GetStringHeight()) + 10)
        p.verdict:SetHeight(vh)
        p.verdict:Show()
        y = y - vh
    else
        p.verdict:Hide()
    end

    -- footer (full only)
    local learning = o.tipLearnCount and Learning(d.src, d.n) or nil
    if style == "full" and (d.tag or o.bagProtect or u.ahGross or learning) then
        y = y - 6
        p.foot:ClearAllPoints()
        p.foot:SetPoint("TOPLEFT", PAD, y)
        local left = {}
        if d.tag then left[#left + 1] = d.tag == "Ignored" and "Ignored" or ("Protected: " .. d.tag) end
        if #left == 0 and u.ahGross then left[1] = "Auction " .. ns.Money(u.ahGross, true) .. " minus 5% cut" end
        p.foot:SetText(table.concat(left, "  ·  "))
        p.footR:ClearAllPoints()
        p.footR:SetPoint("TOPRIGHT", -PAD, y)
        p.footR:SetText(learning and ("|cffcbb8ff" .. learning .. "|r")
            or (o.bagProtect and (d.tag == "Ignored" and "Alt+Right-click to unignore" or "Alt+Right-click to ignore") or ""))
        -- the hint only shows when it fits next to the left text
        if p.foot:GetStringWidth() + p.footR:GetStringWidth() + 16 > width - 2 * PAD then
            if learning then p.foot:SetText(d.tag or "") else p.footR:SetText("") end
        end
        p.foot:Show(); p.footR:Show()
        y = y - 12
    else
        p.foot:Hide(); p.footR:Hide()
    end
    -- learning bar along the bottom edge (accent while learning, green once learned)
    local frac = learned and 1 or math.min(1, (d.n or 0) / ns.Forecast.LEARN_MIN)
    p.xp.fill:SetWidth(math.max(1, (width - 2) * frac))
    p.xp.fill:SetShown(frac > 0)
    if learned then p.xp.fill:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 1)
    else p.xp.fill:SetColorTexture(r, g, b, 1) end
    p.xp:SetShown(o.tipLearnBar and d.src ~= "none")
    return -y + 11
end

------------------------------------------------------------------------
-- Attach to a tooltip
------------------------------------------------------------------------
function TP.Attach(tt, link)
    local o = ns.opts
    local p = panels[tt]
    if p then p:Hide() end
    if not o.tipPanel or ns.ownTip or not link then return end
    if o.tipShift and not IsShiftKeyDown() then return end
    local d = Info(link, tt)
    if not d then return end
    p = p or Create(tt)
    panels[tt] = p
    TP.last = { tt = tt, link = link }

    local style = o.tipPanelStyle == "compact" and "compact" or "full"
    p.minW = 160
    p:SetWidth(math.max(tt:GetWidth() or 0, p.minW))
    p:SetHeight(Layout(p, d, style))
    TP.Place(p, tt)
    p:Show()
end

-- Match the tooltip's width; sit below it, or above it if there's no room
function TP.Place(p, tt)
    p:SetWidth(math.max(tt:GetWidth() or 0, p.minW or 0))
    p:ClearAllPoints()
    local bottom = tt:GetBottom()
    if bottom and (bottom - p:GetHeight() - 4) < 0 then
        p:SetPoint("BOTTOMLEFT", tt, "TOPLEFT", 0, 2)
    else
        p:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -2)
    end
end

-- Holding / releasing Shift updates the panel when "only with Shift" is on
ns.On("MODIFIER_STATE_CHANGED", function(key)
    if not ns.opts or not ns.opts.tipShift or not TP.last then return end
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    local tt = TP.last.tt
    if tt and tt:IsShown() then TP.Attach(tt, TP.last.link) end
end)

-- Accent changes
W.OnAccent(function()
    for tt, p in pairs(panels) do
        if p:IsShown() and TP.last and TP.last.tt == tt then TP.Attach(tt, TP.last.link) end
    end
end)
