-- Salvage Station: compact bar (idea from Disenchantry, Artisan Network look)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

function ns.CreateCompact()
    local o = ns.opts
    local f = CreateFrame("Frame", "SalvageStationCompact", UIParent)
    ns.compactFrame = f
    f:SetSize(420, 168)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScale(o.scale or 1)
    f:Hide()
    W.Fill(f, C.bg)
    W.Border(f, { 0, 0, 0, 1 })
    local cp = o.compactPos
    if cp then f:SetPoint(cp[1], UIParent, cp[2], cp[3], cp[4]) else f:SetPoint("CENTER", 0, -220) end
    f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p1, _, p2, x, y = self:GetPoint()
        o.compactPos = { p1, p2, x, y }
    end)

    -- top strip
    local top = CreateFrame("Frame", nil, f)
    top:SetPoint("TOPLEFT", 1, -1); top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(28)
    W.Fill(top, C.header)
    local tl = W.Line(top, true, { 1, 1, 1, 0.06 })
    tl:SetPoint("BOTTOMLEFT"); tl:SetPoint("BOTTOMRIGHT")
    local t1 = W.Text(top, 11)
    t1:SetPoint("LEFT", 10, 0)
    t1:SetText("SALVAGE")
    W.Accentize(t1, "text")
    local t2 = W.Text(top, 11, C.text)
    t2:SetPoint("LEFT", t1, "RIGHT", 4, 0)
    t2:SetText("STATION")

    local close = CreateFrame("Button", nil, top)
    close:SetSize(24, 24)
    close:SetPoint("RIGHT", -4, 0)
    close.text = W.Text(close, 13, C.dim, "CENTER")
    close.text:SetPoint("CENTER", 0, 1)
    close.text:SetText("x")
    close:SetScript("OnClick", function() ns.CloseWindows() end)
    close:SetScript("OnEnter", function(s) s.text:SetTextColor(1, 0.42, 0.42) end)
    close:SetScript("OnLeave", function(s) s.text:SetTextColor(unpack(C.dim)) end)
    local full = W.Button(top, "Full", 46, 20)
    full:SetPoint("RIGHT", close, "LEFT", -4, 0)
    full:SetScript("OnClick", function() o.compact = false; ns.OpenWindow() end)
    W.Tip(full, "Full window", "Switch back to the full Salvage Station window.")
    local stats = W.Button(top, "Stats", 52, 20)
    stats:SetPoint("RIGHT", full, "LEFT", -4, 0)
    stats:SetScript("OnClick", function() ns.OpenWindow(nil, "stats") end)

    -- item
    local prev = W.Button(f, "<", 24, 36)
    prev:SetPoint("TOPLEFT", 10, -40)
    prev:SetScript("OnClick", function() ns.Cycle(-1) end)
    W.Tip(prev, "Previous item")
    local nxt = W.Button(f, ">", 24, 36)
    nxt:SetPoint("TOPRIGHT", -10, -40)
    nxt:SetScript("OnClick", function() ns.Cycle(1) end)
    W.Tip(nxt, "Next item")

    local icon = W.Icon(f, 36)
    icon:SetPoint("TOPLEFT", 44, -40)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        local e = ns.Selected()
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        ns.SetBagTooltip(GameTooltip, e.bag, e.slot)
        ns.AddEntryTooltip(GameTooltip, e)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local name = W.Text(f, 13)
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    name:SetPoint("RIGHT", nxt, "LEFT", -8, 0)
    local sub = W.Text(f, 11, C.dim)
    sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    sub:SetPoint("RIGHT", nxt, "LEFT", -8, 0)

    -- results strip
    local strip = {}
    for i = 1, 3 do
        local s = CreateFrame("Frame", nil, f)
        s:SetSize(126, 16)
        s:SetPoint("TOPLEFT", 14 + (i - 1) * 132, -86)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(14, 14)
        s.icon:SetPoint("LEFT")
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.text = W.Text(s, 10, C.text)
        s.text:SetPoint("LEFT", s.icon, "RIGHT", 4, 0)
        s.text:SetPoint("RIGHT")
        strip[i] = s
    end

    -- buttons
    local cast = CreateFrame("Button", "SalvageStationCompactCast", f, "SecureActionButtonTemplate")
    cast:SetSize(190, 34)
    cast:SetPoint("BOTTOMRIGHT", -10, 12)
    cast.bg = W.Fill(cast, { 1, 1, 1, 1 })
    W.Border(cast)
    cast.ic = cast:CreateTexture(nil, "ARTWORK")
    cast.ic:SetSize(18, 18)
    cast.ic:SetPoint("LEFT", 12, 0)
    cast.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.ic:SetTexture(ns.DEIcon())
    cast.label = W.Text(cast, 13, { 1, 1, 1 })
    cast.label:SetPoint("LEFT", cast.ic, "RIGHT", 10, 0)
    function cast:Paint(hover)
        local r, g, b = ns.Accent()
        if ns.known and ns.Selected() and not ns.busy then
            self.bg:SetColorTexture(r, g, b, hover and 0.45 or 0.30)
            W.SetBorderColor(self, r, g, b, 0.9)
            self.label:SetTextColor(1, 1, 1)
        else
            self.bg:SetColorTexture(1, 1, 1, 0.04)
            W.SetBorderColor(self, unpack(C.border))
            self.label:SetTextColor(unpack(C.faint))
        end
    end
    W.OnAccent(function() cast:Paint(false) end)
    ns.MakeCastButton(cast, function() return ns.Selected() end, false)
    cast:SetScript("OnEnter", function(self) self:Paint(true) end)
    cast:SetScript("OnLeave", function(self) self:Paint(false) end)

    local skip = W.Button(f, "Skip", 80, 34)
    skip:SetPoint("RIGHT", cast, "LEFT", -6, 0)
    skip:SetScript("OnClick", function() ns.Skip(ns.Selected()) end)
    W.Tip(skip, "Skip", "Skip this item until the bar is closed.")
    local hide = W.Button(f, "Hide", 80, 34)
    hide:SetPoint("RIGHT", skip, "LEFT", -6, 0)
    hide:SetScript("OnClick", function()
        local e = ns.Selected()
        if e then ns.Hide(e.itemID, IsShiftKeyDown(), e.link) end
    end)
    W.Tip(hide, "Hide", "Hide this item until you log out. Hold Shift to ignore it permanently.")

    local function Update()
        if not f:IsShown() then return end
        local e = ns.Selected()
        local c = ns.counts
        if e then
            local q = ns.QCOL[e.quality] or { 1, 1, 1 }
            icon.tex:SetTexture(e.icon)
            name:SetText(e.name)
            name:SetTextColor(q[1], q[2], q[3])
            local bits = { ns.ReadyCount() .. " ready" }
            if e.protected then bits[#bits + 1] = "|cffffba45" .. e.protected .. "|r" end
            if c.protected > 0 then bits[#bits + 1] = c.protected .. " protected" end
            if e.mats and o.showValue then bits[#bits + 1] = "DE " .. ns.Money(e.mats, true) end
            sub:SetText(table.concat(bits, "  ·  "))
            local res = ns.Forecast.Get(e)
            for i, s in ipairs(strip) do
                local r = res and res[i]
                if r then
                    s.icon:SetTexture(ns.ItemIcon(r.id))
                    s.text:SetText(ns.Pct(r.chance) .. "% x" .. ns.Num(r.exp))
                    s:Show()
                else
                    s:Hide()
                end
            end
        else
            icon.tex:SetTexture(ns.DEIcon())
            name:SetText(ns.known and "Nothing to disenchant" or "Disenchant not learned")
            name:SetTextColor(unpack(C.dim))
            sub:SetText(c.protected > 0 and (c.protected .. " protected item" .. (c.protected == 1 and "" or "s") .. " - use the arrows to pick one") or "")
            for _, s in ipairs(strip) do s:Hide() end
        end
        cast.label:SetText(ns.busy and "Disenchanting..." or "Disenchant")
        cast:Paint(cast:IsMouseOver())
        skip:SetEnabled(e ~= nil and not ns.busy)
        hide:SetEnabled(e ~= nil)
        prev:SetEnabled(#ns.list > 1)
        nxt:SetEnabled(#ns.list > 1)
        if not InCombatLockdown() then ns.SyncClicks(cast) end
    end
    f.Update = Update
    ns.Listen("REFRESH", Update)
    ns.Listen("BUSY", Update)
    ns.Listen("SELECTION", Update)
    f:SetScript("OnShow", function() ns:RequestRefresh(0); ns.UpdateHotkey() end)
    f:SetScript("OnHide", function()
        ns.ClearSkipped()
        if ns.confirmFrame and ns.confirmFrame:IsShown() then ns.confirmFrame:Hide() end
        ns.UpdateHotkey()
    end)
end
