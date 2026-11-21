-- Salvage Station: Statistics page (session / all time, profit vs vendor or market)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

ns.PageBuilders.stats = function(content, main)
    local o = ns.opts
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    local scope, view = "session", "materials"

    local lbl = W.Label(p, "Statistics")
    lbl:SetPoint("TOPLEFT", 16, -22)
    local seg = W.Segmented(p, { { value = "session", label = "This session" }, { value = "total", label = "All time" } },
        function() return scope end, function(v) scope = v; main:Refresh() end, 100)
    seg:SetPoint("TOPLEFT", 100, -16)
    local basisLbl = W.Text(p, 11, C.dim, "RIGHT")
    local basis = W.Segmented(p, { { value = "vendor", label = "Vendor" }, { value = "ah", label = "Market" } },
        function() return o.statsBasis end, function(v) o.statsBasis = v; main:Refresh() end, 70)
    basis:SetPoint("TOPRIGHT", -16, -16)
    basisLbl:SetPoint("RIGHT", basis, "LEFT", -8, 0)
    basisLbl:SetText("Compare with")
    W.Tip(basis, "Compare with", "Profit compares your materials' market value with what the items would have sold for at a vendor or on the auction house.")

    -- summary cards
    local cards = {}
    local CARD_W = (588 - 32 - 24) / 4
    for i, def in ipairs({ "Disenchanted", "Items were worth", "Materials worth", "Profit" }) do
        local c = W.Panel(p)
        c:SetSize(CARD_W, 62)
        c:SetPoint("TOPLEFT", 16 + (i - 1) * (CARD_W + 8), -54)
        c.lbl = W.Label(c, def)
        c.lbl:SetPoint("TOPLEFT", 10, -10)
        c.val = W.Text(c, 16, C.text)
        c.val:SetPoint("BOTTOMLEFT", 10, 12)
        cards[i] = c
    end

    local info = W.Text(p, 11, C.dim)
    info:SetPoint("TOPLEFT", 16, -126)
    info:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    info:SetWordWrap(true)
    info:SetHeight(30)
    info:SetJustifyV("TOP")

    -- materials table
    local hdr = CreateFrame("Frame", nil, p)
    hdr:SetPoint("TOPLEFT", 16, -196)
    hdr:SetPoint("TOPRIGHT", -16, -196)
    local viewSeg = W.Segmented(p, { { value = "materials", label = "Materials" }, { value = "knowledge", label = "Knowledge" } },
        function() return view end, function(v) view = v; main:Refresh() end, 100)
    viewSeg:SetPoint("TOPLEFT", 16, -164)
    W.Tip(viewSeg, "Knowledge", "How much Salvage Station has learned from your own disenchants, for each kind of item.")
    hdr:SetHeight(16)
    local a = W.Label(hdr, "Materials received"); a:SetPoint("LEFT", 12, 0)
    local d = W.Label(hdr, "Total"); d:SetPoint("RIGHT", -14, 0)
    local cU = W.Label(hdr, "Each"); cU:SetPoint("RIGHT", -120, 0)
    local b = W.Label(hdr, "Count"); b:SetPoint("RIGHT", -220, 0)
    local kSum = W.Text(hdr, 10, C.dim, "RIGHT"); kSum:SetPoint("RIGHT", -14, 0)
    local function HeaderFor(v)
        a:SetText(v == "knowledge" and "KNOWLEDGE" or "MATERIALS RECEIVED")
        d:SetShown(v ~= "knowledge"); cU:SetShown(v ~= "knowledge"); b:SetShown(v ~= "knowledge")
        kSum:SetShown(v == "knowledge")
    end
    local line = W.Line(hdr, true)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")

    local function CreateRow(list)
        local r = W.RowBase(list)
        r.icon = W.Icon(r, 18)
        r.icon:SetPoint("LEFT", 12, 0)
        r.name = W.Text(r, 12)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -270, 0)
        r.count = W.Text(r, 12, C.text, "RIGHT"); r.count:SetPoint("RIGHT", -220, 0)
        r.unit = W.Text(r, 11, C.dim, "RIGHT"); r.unit:SetPoint("RIGHT", -120, 0)
        r.total = W.Text(r, 11, C.text, "RIGHT"); r.total:SetPoint("RIGHT", -10, 0)
        r.kb = CreateFrame("Frame", nil, r)
        r.kb:SetHeight(7)
        r.kb:SetPoint("LEFT", r, "LEFT", 220, 0)
        r.kb:SetPoint("RIGHT", r, "RIGHT", -90, 0)
        W.Fill(r.kb, { 1, 1, 1, 0.07 })
        r.kb.fill = r.kb:CreateTexture(nil, "ARTWORK")
        r.kb.fill:SetPoint("TOPLEFT"); r.kb.fill:SetPoint("BOTTOMLEFT")
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            local it = self.item
            if not it then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if it.kind == "knowledge" then
                GameTooltip:AddLine(it.name, 1, 1, 1)
                GameTooltip:AddLine(it.n .. " disenchants recorded", 0.8, 0.8, 0.8)
                for _, m in ipairs(it.mats) do
                    GameTooltip:AddDoubleLine("  " .. ns.IconText(m.id, 12) .. " " .. ns.ItemName(m.id), ns.Pct(m.chance) .. "%", 0.85, 0.85, 0.85, 0.6, 0.6, 0.65)
                end
                if not it.learned then GameTooltip:AddLine((ns.Forecast.LEARN_MIN - it.n) .. " more to switch to your own results", 0.63, 0.47, 1) end
            else
                GameTooltip:SetItemByID(it.id)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        return r
    end
    local function UpdateRow(r, m)
        if m.kind == "knowledge" then
            local q = ns.QCOL[m.quality] or { 1, 1, 1 }
            r.icon:Hide()
            r.name:ClearAllPoints(); r.name:SetPoint("LEFT", 12, 0); r.name:SetPoint("RIGHT", r, "LEFT", 212, 0)
            r.name:SetText(m.name); r.name:SetTextColor(q[1], q[2], q[3])
            r.count:SetText(""); r.unit:SetText("")
            r.total:SetText(m.learned and "|cff52de7cLearned|r" or (m.n .. "/" .. ns.Forecast.LEARN_MIN))
            r.kb:Show()
            local frac = math.min(1, m.n / ns.Forecast.LEARN_MIN)
            r.kb.fill:SetWidth(math.max(1, (r.kb:GetWidth() or 0) * frac))
            r.kb.fill:SetShown(frac > 0)
            if m.learned then r.kb.fill:SetColorTexture(0.32, 0.87, 0.49, 1)
            else local ar, ag, ab = ns.Accent(); r.kb.fill:SetColorTexture(ar, ag, ab, 1) end
            return
        end
        r.icon:Show()
        r.kb:Hide()
        r.name:ClearAllPoints(); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetPoint("RIGHT", -270, 0)
        local q = ns.QCOL[ns.ItemQuality(m.id)] or { 1, 1, 1 }
        r.icon.tex:SetTexture(ns.ItemIcon(m.id))
        r.name:SetText(ns.ItemName(m.id))
        r.name:SetTextColor(q[1], q[2], q[3])
        r.count:SetText(m.qty)
        r.unit:SetText(m.price and ns.Money(m.price, true) or "|cff616269?|r")
        r.total:SetText(m.price and ns.Money(m.price * m.qty, true) or "|cff616269?|r")
    end
    local list = W.List(p, 24, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
    list:SetPoint("BOTTOMRIGHT", -16, 58)

    local note = W.Text(p, 10, C.faint)
    note:SetPoint("BOTTOMLEFT", 16, 24)
    note:SetText("Prices are estimates. Fees aren't included.")

    local reset = W.Button(p, "Reset session", 120, 28)
    reset:SetPoint("BOTTOMRIGHT", -16, 16)
    reset:SetScript("OnClick", function() ns.ResetSession() end)
    local resetAll = W.Button(p, "Reset all time", 120, 28)
    resetAll:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    W.Tip(resetAll, "Reset all time", "Clears every statistic. Click twice to confirm.")
    resetAll:SetScript("OnClick", function(self)
        if self.armed then
            self.armed = nil; self:SetLabel("Reset all time"); ns.ResetAllStats()
        else
            self.armed = true; self:SetLabel("Click to confirm")
            C_Timer.After(3, function() self.armed = nil; self:SetLabel("Reset all time") end)
        end
    end)

    local page = { frame = p }
    function page.refresh()
        seg:Refresh(); basis:Refresh()
        local s = (scope == "session") and ns.session or ns.db.stats.total
        local mats, matValue, missing = {}, 0, 0
        for id, qty in pairs(s.materials) do
            local price = ns.Prices.Market(id)
            mats[#mats + 1] = { id = id, qty = qty, price = price }
            if price then matValue = matValue + price * qty else missing = missing + 1 end
        end
        table.sort(mats, function(x, y)
            local vx, vy = (x.price or 0) * x.qty, (y.price or 0) * y.qty
            if vx ~= vy then return vx > vy end
            return x.qty > y.qty
        end)
        viewSeg:Refresh()
        HeaderFor(view)
        if view == "knowledge" then
            local rows, done = {}, 0
            for key, sm in pairs(ns.db.samples) do
                if (sm.n or 0) > 0 then
                    local name, q = ns.Forecast.BucketName(key)
                    local learned = sm.n >= ns.Forecast.LEARN_MIN
                    if learned then done = done + 1 end
                    local ms = {}
                    for id, rr in pairs(sm.items or {}) do ms[#ms + 1] = { id = id, chance = rr.hits / sm.n } end
                    table.sort(ms, function(x, y) return x.chance > y.chance end)
                    rows[#rows + 1] = { kind = "knowledge", name = name, quality = q or 2, n = sm.n, learned = learned, mats = ms }
                end
            end
            table.sort(rows, function(x, y)
                if x.learned ~= y.learned then return x.learned end
                if x.n ~= y.n then return x.n > y.n end
                return x.name < y.name
            end)
            kSum:SetText(done .. " of " .. #rows .. " kinds learned")
            list:SetData(rows, "Nothing learned yet.\nEvery disenchant teaches Salvage Station about that kind of item.")
        else
            list:SetData(mats, "No materials received yet.\nThey're counted as they reach your bags.")
        end

        local itemsValue = (o.statsBasis == "ah") and s.ah or s.vendor
        cards[1].val:SetText(s.count)
        cards[2].val:SetText(ns.Money(itemsValue, true))
        cards[3].val:SetText(ns.Money(matValue, true))
        local profit = matValue - itemsValue
        cards[4].lbl:SetText(profit >= 0 and "PROFIT" or "LOSS")
        cards[4].val:SetText(ns.Money(profit, true))
        if profit >= 0 then cards[4].val:SetTextColor(unpack(C.online)) else cards[4].val:SetTextColor(unpack(C.warn)) end

        local bits = {}
        local qn = { [2] = "|cff1eff00Uncommon|r", [3] = "|cff0070ddRare|r", [4] = "|cffa335eeEpic|r" }
        local qs = {}
        for q = 2, 4 do if (s.qualities[q] or 0) > 0 then qs[#qs + 1] = qn[q] .. " " .. s.qualities[q] end end
        if #qs > 0 then bits[#bits + 1] = table.concat(qs, "   ") end
        if s.maxLink then bits[#bits + 1] = "Most valuable: " .. s.maxLink end
        local warn = {}
        if missing > 0 then warn[#warn + 1] = missing .. " material price" .. (missing == 1 and "" or "s") .. " unknown" end
        if o.statsBasis == "ah" and (s.unknownAH or 0) > 0 then warn[#warn + 1] = s.unknownAH .. " item price" .. (s.unknownAH == 1 and "" or "s") .. " unknown" end
        if #warn > 0 then bits[#bits + 1] = "|cffffba45Incomplete: " .. table.concat(warn, ", ") .. "|r" end
        info:SetText(table.concat(bits, "     "))
    end
    return page
end
