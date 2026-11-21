-- Salvage Station: Disenchant page (TSM Destroying layout)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

local ROW_H = 26
local HIDE_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local QNAME = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }

local function Tags(e)
    local t = {}
    if e.protected then t[#t + 1] = "|cffffba45" .. e.protected .. "|r" end
    if e.warn then t[#t + 1] = "|cffff6b6b" .. e.warn .. "|r" end
    if e.worthMore then t[#t + 1] = (e.sellBy == "ah") and "|cff6fb0ffAH|r" or "|cffffd133Vendor|r" end
    if e.confirm and not e.protected then t[#t + 1] = "|cff8a8b94confirm|r" end
    return table.concat(t, "  ")
end

-- Hover text for an entry (shared with the compact bar)
function ns.AddEntryTooltip(tt, e)
    tt:AddLine(" ")
    local panel = ns.TipPanelActive()
    local res, src, n = ns.Forecast.Get(e)
    if res and not panel then
        tt:AddLine("|cff" .. ns.AccentHex() .. "Possible results|r")
        for _, r in ipairs(res) do tt:AddLine("  " .. ns.Forecast.LineText(r)) end
        tt:AddLine("  " .. ns.Forecast.SourceText(src, n))
    end
    if ns.opts.showValue and not panel then
        tt:AddDoubleLine("Vendor value", ns.Money(e.vendor), 0.8, 0.8, 0.8, 1, 1, 1)
        if e.use and e.use.ah then tt:AddDoubleLine("Auction value (after 5% cut)", ns.Money(e.use.ah), 0.8, 0.8, 0.8, 1, 1, 1) end
        if e.mats then tt:AddDoubleLine("Disenchant value", ns.Money(e.mats), 0.8, 0.8, 0.8, 1, 1, 1) end
        if e.use and e.use.best ~= "de" and e.use.gain then
            tt:AddLine(ns.Forecast.USE_VERB[e.use.best] .. ": +" .. ns.Money(e.use.gain, true) .. " more than " .. ns.Forecast.USE_LABEL[e.use.second], unpack(C.gold))
        end
    end
    if e.protected then tt:AddLine("Protected (" .. e.protected .. "): Disenchant Next skips it unless you select it", 1, 0.73, 0.27, true) end
    if e.warn then tt:AddLine("Your Enchanting skill may be too low (" .. e.warn .. ")", unpack(C.warn)) end
    if e.confirm then tt:AddLine("Asks to confirm: " .. e.confirm, C.gold[1], C.gold[2], C.gold[3], true) end
end

ns.PageBuilders.disenchant = function(content, main)
    local o = ns.opts
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()

    -- search + quality --------------------------------------------------
    local search = W.EditBox(p, 220, 28, "Search items...", true)
    search:SetPoint("TOPLEFT", 16, -16)
    search.onChange = function(t) ns.search = t; ns:RequestRefresh(0.1) end

    local chips = {}
    local last
    for _, q in ipairs({ 4, 3, 2 }) do
        local c = W.Button(p, QNAME[q], 76, 24)
        if last then c:SetPoint("RIGHT", last, "LEFT", -6, 0) else c:SetPoint("TOPRIGHT", -16, -18) end
        c.color = ns.QCOL[q]
        c.idleColor = C.dim
        c:SetScript("OnClick", function(self)
            o["q" .. q] = not o["q" .. q]
            self:SetActive(o["q" .. q])
            ns:RequestRefresh(0)
        end)
        W.Tip(c, "Show " .. QNAME[q] .. " items", "Click to include or leave out this quality.")
        chips[q] = c
        last = c
    end

    -- selected item -----------------------------------------------------
    local sel = W.Panel(p)
    sel:SetPoint("TOPLEFT", 16, -54)
    sel:SetPoint("TOPRIGHT", -16, -54)
    sel:SetHeight(50)
    sel.icon = W.Icon(sel, 34)
    sel.icon:SetPoint("LEFT", 8, 0)
    sel.icon:EnableMouse(true)
    sel.icon:SetScript("OnEnter", function(self)
        local e = ns.Selected()
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        ns.SetBagTooltip(GameTooltip, e.bag, e.slot)
        GameTooltip:Show()
    end)
    sel.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sel.name = W.Text(sel, 13)
    sel.name:SetPoint("TOPLEFT", sel.icon, "TOPRIGHT", 10, -2)
    sel.name:SetPoint("RIGHT", -150, 0)
    sel.sub = W.Text(sel, 11, C.dim)
    sel.sub:SetPoint("BOTTOMLEFT", sel.icon, "BOTTOMRIGHT", 10, 2)
    sel.sub:SetPoint("RIGHT", -150, 0)
    sel.tag = W.Text(sel, 11, C.dim, "RIGHT")
    sel.tag:SetPoint("TOPRIGHT", -12, -10)
    sel.val = W.Text(sel, 11, C.text, "RIGHT")
    sel.val:SetPoint("BOTTOMRIGHT", -12, 10)

    -- possible results --------------------------------------------------
    local res = W.Panel(p)
    res:SetPoint("TOPLEFT", sel, "BOTTOMLEFT", 0, -8)
    res:SetPoint("TOPRIGHT", sel, "BOTTOMRIGHT", 0, -8)
    res:SetHeight(88)
    local resLbl = W.Label(res, "Possible results")
    resLbl:SetPoint("TOPLEFT", 12, -9)
    res.src = W.Text(res, 10, C.faint, "RIGHT")
    res.src:SetPoint("TOPRIGHT", -12, -9)
    res.lines = {}
    for i = 1, 4 do
        local l = CreateFrame("Frame", nil, res)
        l:SetHeight(15)
        l:SetPoint("TOPLEFT", 12, -24 - (i - 1) * 15)
        l:SetPoint("RIGHT", -12, 0)
        l.icon = l:CreateTexture(nil, "ARTWORK")
        l.icon:SetSize(12, 12)
        l.icon:SetPoint("LEFT")
        l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        l.text = W.Text(l, 11, C.text)
        l.text:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
        l.right = W.Text(l, 10, C.dim, "RIGHT")
        l.right:SetPoint("RIGHT")
        l:EnableMouse(true)
        l:SetScript("OnEnter", function(self)
            if not self.id then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.id)
            GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() GameTooltip:Hide() end)
        res.lines[i] = l
    end

    -- list header -------------------------------------------------------
    local hdr = CreateFrame("Frame", nil, p)
    hdr:SetPoint("TOPLEFT", res, "BOTTOMLEFT", 0, -10)
    hdr:SetPoint("TOPRIGHT", res, "BOTTOMRIGHT", 0, -10)
    hdr:SetHeight(16)
    local h1 = W.Label(hdr, "Item"); h1:SetPoint("LEFT", 12, 0)
    local h3 = W.Label(hdr, "Value"); h3:SetPoint("RIGHT", -34, 0)
    local h2 = W.Label(hdr, "iLvl"); h2:SetPoint("RIGHT", -112, 0)
    local hl = W.Line(hdr, true)
    hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")

    -- list --------------------------------------------------------------
    local function CreateRow(list)
        local r = W.RowBase(list)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.q = r:CreateTexture(nil, "ARTWORK")
        r.q:SetSize(2, ROW_H - 8)
        r.q:SetPoint("LEFT", 4, 0)
        r.icon = W.Icon(r, 18)
        r.icon:SetPoint("LEFT", 12, 0)
        r.name = W.Text(r, 12)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -190, 0)
        r.tags = W.Text(r, 10, C.dim, "RIGHT")
        r.tags:SetPoint("RIGHT", -150, 0)
        r.ilvl = W.Text(r, 11, C.dim, "RIGHT")
        r.ilvl:SetPoint("RIGHT", -112, 0)
        r.value = W.Text(r, 11, C.text, "RIGHT")
        r.value:SetPoint("RIGHT", -34, 0)
        r.hide = CreateFrame("Button", nil, r)
        r.hide:SetSize(14, 14)
        r.hide:SetPoint("RIGHT", -10, 0)
        r.hide.tex = r.hide:CreateTexture(nil, "ARTWORK")
        r.hide.tex:SetAllPoints()
        r.hide.tex:SetTexture(HIDE_TEX)
        r.hide.tex:SetDesaturated(true)
        r.hide.tex:SetAlpha(0.45)
        r.hide:SetScript("OnEnter", function(self)
            r.hl:Show()
            self.tex:SetDesaturated(false); self.tex:SetAlpha(1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Hide this item", 1, 1, 1)
            GameTooltip:AddLine("Click to hide it until you log out. Hold Shift to ignore it permanently.", 0.7, 0.7, 0.75, true)
            GameTooltip:Show()
        end)
        r.hide:SetScript("OnLeave", function(self)
            if not r:IsMouseOver() then r.hl:Hide() end
            self.tex:SetDesaturated(true); self.tex:SetAlpha(0.45)
            GameTooltip:Hide()
        end)
        r.hide:SetScript("OnClick", function()
            if r.item then ns.Hide(r.item.itemID, IsShiftKeyDown(), r.item.link) end
        end)
        r:SetScript("OnClick", function(self, button)
            if not self.item then return end
            if button == "RightButton" then ns.Hide(self.item.itemID, IsShiftKeyDown(), self.item.link); return end
            if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                ChatEdit_InsertLink(self.item.link); return
            end
            ns.Select(self.item)
        end)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            local e = self.item
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            ns.SetBagTooltip(GameTooltip, e.bag, e.slot)
            ns.AddEntryTooltip(GameTooltip, e)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: select  ·  Right-click: hide (Shift = permanently)", 0.55, 0.57, 0.63)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        return r
    end
    local function UpdateRow(r, e)
        local q = ns.QCOL[e.quality] or { 1, 1, 1 }
        r.q:SetColorTexture(q[1], q[2], q[3], 0.9)
        r.icon.tex:SetTexture(e.icon)
        r.icon.tex:SetDesaturated(e.locked and true or false)
        r.name:SetText(e.name .. ((e.count or 1) > 1 and (" |cff8a8b94x" .. e.count .. "|r") or ""))
        r.name:SetTextColor(q[1], q[2], q[3])
        r.name:SetAlpha(e.protected and 0.6 or 1)
        r.tags:SetText(Tags(e))
        r.ilvl:SetText(e.ilvl or "")
        r.value:SetText(o.showValue and ns.Money(e.mats or e.value, true) or "")
        r:SetSelected(e.guid == ns.selected)
    end
    local list = W.List(p, ROW_H, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
    list:SetPoint("BOTTOMRIGHT", -16, 62)

    -- bottom bar --------------------------------------------------------
    local status = W.Text(p, 11, C.dim)
    status:SetPoint("BOTTOMLEFT", 16, 24)
    status:SetPoint("RIGHT", p, "RIGHT", -330, 0)
    status:SetWordWrap(true)
    status:SetHeight(30)
    status:SetJustifyV("MIDDLE")

    local nb = CreateFrame("Button", "SalvageStationNextButton", p, "SecureActionButtonTemplate")
    nb:SetSize(220, 36)
    nb:SetPoint("BOTTOMRIGHT", -16, 14)
    nb.bg = W.Fill(nb, { 1, 1, 1, 1 })
    W.Border(nb)
    nb.ic = nb:CreateTexture(nil, "ARTWORK")
    nb.ic:SetSize(18, 18)
    nb.ic:SetPoint("LEFT", 14, 0)
    nb.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    nb.ic:SetTexture(ns.DEIcon())
    nb.label = W.Text(nb, 13, { 1, 1, 1 }, "LEFT")
    nb.label:SetPoint("LEFT", nb.ic, "RIGHT", 10, 0)
    nb.label:SetPoint("RIGHT", -10, 0)
    function nb:Paint(hover)
        local r, g, b = ns.Accent()
        local on = ns.known and ns.Selected() and not ns.busy
        if on then
            self.bg:SetColorTexture(r, g, b, hover and 0.45 or 0.30)
            W.SetBorderColor(self, r, g, b, 0.9)
            self.label:SetTextColor(1, 1, 1)
            self.ic:SetDesaturated(false)
        else
            self.bg:SetColorTexture(1, 1, 1, 0.04)
            W.SetBorderColor(self, unpack(C.border))
            self.label:SetTextColor(unpack(C.faint))
            self.ic:SetDesaturated(true)
        end
    end
    W.OnAccent(function() nb:Paint(false) end)
    ns.MakeCastButton(nb, function() return ns.Selected() end, false)
    -- no item tooltip on the button: it covered the list and the button itself
    nb:SetScript("OnEnter", function(self) self:Paint(true) end)
    nb:SetScript("OnLeave", function(self) self:Paint(false) end)

    local skip = W.Button(p, "Skip", 90, 36)
    skip:SetPoint("RIGHT", nb, "LEFT", -8, 0)
    skip:SetScript("OnClick", function() ns.Skip(ns.Selected()) end)
    W.Tip(skip, "Skip", "Skip this item until the window is closed.")

    -- refresh -----------------------------------------------------------
    local page = { frame = p }
    local lastSel
    function page.refresh()
        for q, c in pairs(chips) do c:SetActive(o["q" .. q]) end
        local empty
        if not ns.known then empty = "You don't know Disenchant on this character."
        else
            empty = "Nothing in your bags to disenchant."
            local c = ns.counts
            local hidden = c.filtered + c.ignored + c.skipped + c.soulbound
            if hidden > 0 then empty = empty .. "\n|cff616269(" .. hidden .. " hidden by filters, ignore or skip)|r" end
        end
        list:SetData(ns.list, empty)
        local e, idx = ns.Selected()
        if e and e.guid ~= lastSel then list:ScrollTo(idx) end
        lastSel = e and e.guid

        -- selected panel + results
        if e then
            local q = ns.QCOL[e.quality] or { 1, 1, 1 }
            sel.icon.tex:SetTexture(e.icon)
            sel.name:SetText(e.name)
            sel.name:SetTextColor(q[1], q[2], q[3])
            local typ = (e.classID == 2) and "Weapon" or "Armor"
            local slotName = _G[e.equipLoc] or ""
            sel.sub:SetText("iLvl " .. e.ilvl .. "  ·  " .. (slotName ~= "" and slotName or typ) ..
                (e.isBoE and "  ·  |cffffd27aBoE|r" or (e.isBound and "  ·  Soulbound" or "")))
            sel.tag:SetText(Tags(e))
            sel.val:SetText(o.showValue and ("|cff8a8b94Vendor|r " .. ns.Money(e.vendor) ..
                (e.mats and ("   |cff8a8b94DE|r " .. ns.Money(e.mats)) or "")) or "")
            local rs, src, n = ns.Forecast.Get(e)
            res.src:SetText(ns.Forecast.SourceText(src, n))
            for i, l in ipairs(res.lines) do
                local r = rs and rs[i]
                if r then
                    l.id = r.id
                    l.icon:SetTexture(ns.ItemIcon(r.id))
                    l.text:SetText(ns.Forecast.LineText(r))
                    local pr = ns.Prices.Market(r.id)
                    l.right:SetText(pr and o.showValue and (ns.Money(pr, true) .. " each") or "")
                    l:Show()
                else
                    l.id = nil
                    l:Hide()
                end
            end
            if not rs then
                res.lines[1].text:SetText("|cff8a8b94No data for this item yet - it learns as you disenchant.|r")
                res.lines[1].icon:SetTexture(nil)
                res.lines[1].right:SetText("")
                res.lines[1]:Show()
            end
        else
            sel.icon.tex:SetTexture(ns.DEIcon())
            sel.name:SetText(ns.known and (#ns.list > 0 and "Select an item" or "Nothing to disenchant") or "Disenchant not learned")
            sel.name:SetTextColor(unpack(C.dim))
            sel.sub:SetText(#ns.list > 0 and "Everything left is protected - click a row to pick it." or "")
            sel.tag:SetText("")
            sel.val:SetText("")
            res.src:SetText("")
            for _, l in ipairs(res.lines) do l.id = nil; l:Hide() end
        end

        -- status
        local c, bits = ns.counts, {}
        bits[#bits + 1] = ns.ReadyCount() .. " ready"
        if c.protected > 0 then bits[#bits + 1] = "|cffffba45" .. c.protected .. " protected|r" end
        if c.skipped > 0 then bits[#bits + 1] = c.skipped .. " skipped" end
        if c.ignored > 0 then bits[#bits + 1] = c.ignored .. " ignored" end
        if c.filtered > 0 then bits[#bits + 1] = c.filtered .. " filtered" end
        if c.soulbound > 0 then bits[#bits + 1] = c.soulbound .. " soulbound" end
        status:SetText(table.concat(bits, "  |cff62636c·|r  "))

        -- button
        if not ns.known then nb.label:SetText("Disenchant not learned")
        elseif ns.busy then nb.label:SetText("Disenchanting...")
        elseif not e then nb.label:SetText("Nothing to disenchant")
        else nb.label:SetText("Disenchant Next") end
        nb:Paint(nb:IsMouseOver())
        skip:SetEnabled(e ~= nil and not ns.busy)
        if not InCombatLockdown() then ns.SyncClicks(nb) end
    end
    return page
end
