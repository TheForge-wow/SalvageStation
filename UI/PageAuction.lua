-- Salvage Station: Auction page (find and buy gear worth more disenchanted)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

ns.PageBuilders.auction = function(content, main)
    local o = ns.opts
    local Scan, Buy = ns.AuctionScan, ns.AuctionBuy
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()

    local scanBtn = W.Button(p, "Scan", 110, 28)
    scanBtn:SetPoint("TOPLEFT", 16, -16)
    scanBtn:SetScript("OnClick", function()
        if Scan.paused then
            -- "Resume scan": let go of the lot being bought and carry on
            if Buy.active then Buy.Cancel("cancelled") else Scan.Resume() end
        elseif Scan.running then Scan.Stop("stopped") else Scan.Start() end
    end)

    local minLbl = W.Text(p, 12, C.dim)
    minLbl:SetPoint("LEFT", scanBtn, "RIGHT", 16, 0)
    minLbl:SetText("Minimum profit")
    local minBox = W.MoneyBox(p, function() return o.auctionMinProfitCopper or 0 end,
        function(v) o.auctionMinProfitCopper = v end)
    minBox:SetPoint("LEFT", minLbl, "RIGHT", 8, 0)
    local gl = W.Text(p, 12, C.dim)
    gl:SetPoint("LEFT", minBox, "RIGHT", 8, 0)
    gl:SetText("per lot")
    W.Tip(minBox, "Minimum profit", "Only list auctions that make at least this much. Fill in any mix of gold, silver and copper.")

    -- rarities to scan for
    local QNAME = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }
    local chips, last = {}, nil
    local scanFor = W.Text(p, 12, C.dim)
    scanFor:SetPoint("TOPLEFT", 16, -56)
    scanFor:SetText("Scan for")
    for _, q in ipairs({ 2, 3, 4 }) do
        local c = W.Button(p, QNAME[q], 80, 24)
        if last then c:SetPoint("LEFT", last, "RIGHT", 6, 0) else c:SetPoint("LEFT", scanFor, "RIGHT", 12, 0) end
        c.color = ns.QCOL[q]
        c.idleColor = C.dim
        c:SetScript("OnClick", function(self)
            o["ahQ" .. q] = not o["ahQ" .. q]
            self:SetActive(o["ahQ" .. q])
            if Scan.running then Scan.Stop("stopped"); Scan.Start() end
        end)
        W.Tip(c, "Scan " .. QNAME[q] .. " gear", "Click to include or leave out this rarity. A running scan starts over.")
        chips[q] = c
        last = c
    end

    local state = W.Text(p, 11, C.dim)
    state:SetPoint("TOPLEFT", 16, -84)
    state:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    local counts = W.Text(p, 10, C.faint)
    counts:SetPoint("TOPLEFT", 16, -100)
    counts:SetPoint("RIGHT", p, "RIGHT", -16, 0)

    local hdr = CreateFrame("Frame", nil, p)
    hdr:SetPoint("TOPLEFT", 16, -122)
    hdr:SetPoint("TOPRIGHT", -16, -122)
    hdr:SetHeight(16)
    -- clickable column headers, like the auction house
    local heads = {}
    local DEFAULT_ASC = { name = true, buyout = true }   -- rarity starts Epic first
    local function Head(label, key, point, x)
        local b = CreateFrame("Button", nil, hdr)
        b:SetHeight(16)
        b.text = W.Text(b, 10, C.faint, point == "LEFT" and "LEFT" or "RIGHT")
        b.text:SetPoint(point, 0, 0)
        b:SetPoint(point, x, 0)
        b.label, b.key = label:upper(), key
        b:SetScript("OnClick", function()
            if o.auctionSort == key then o.auctionSortAsc = not o.auctionSortAsc
            else o.auctionSort, o.auctionSortAsc = key, DEFAULT_ASC[key] or false end
            Scan.Sort()
        end)
        b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self) self:Paint() end)
        function b:Paint()
            local on = o.auctionSort == self.key
            local arrow = on and (o.auctionSortAsc and " |TInterface\\Buttons\\Arrow-Up-Up:10:10:0:-2|t" or " |TInterface\\Buttons\\Arrow-Down-Up:10:10:0:2|t") or ""
            self.text:SetText(self.label .. arrow)
            if on then self.text:SetTextColor(ns.Accent()) else self.text:SetTextColor(unpack(C.faint)) end
            self:SetWidth(self.text:GetStringWidth() + 4)
        end
        heads[#heads + 1] = b
        return b
    end
    Head("Item", "name", "LEFT", 12)
    Head("Rarity", "quality", "LEFT", 72)
    Head("%", "percent", "RIGHT", -12)
    Head("Profit", "profit", "RIGHT", -46)
    Head("Disenchant", "value", "RIGHT", -140)
    Head("Buyout", "buyout", "RIGHT", -240)
    W.OnAccent(function() for _, b in ipairs(heads) do b:Paint() end end)
    local hl = W.Line(hdr, true)
    hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")

    local function CreateRow(list)
        local r = W.RowBase(list)
        r.icon = W.Icon(r, 18)
        r.icon:SetPoint("LEFT", 12, 0)
        r.name = W.Text(r, 12)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -320, 0)
        r.buyout = W.Text(r, 11, C.text, "RIGHT"); r.buyout:SetPoint("RIGHT", -240, 0)
        r.value = W.Text(r, 11, C.dim, "RIGHT"); r.value:SetPoint("RIGHT", -140, 0)
        r.profit = W.Text(r, 11, C.online, "RIGHT"); r.profit:SetPoint("RIGHT", -46, 0)
        r.pct = W.Text(r, 11, C.dim, "RIGHT"); r.pct:SetPoint("RIGHT", -10, 0)
        r:SetScript("OnClick", function(self)
            if self.item and not Buy.active then Buy.Prepare(self.item, true) end
        end)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.item.link)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to check this lot and buy it", 0.55, 0.57, 0.63)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        return r
    end
    local function UpdateRow(r, row)
        local q = ns.QCOL[row.quality] or { 1, 1, 1 }
        r.icon.tex:SetTexture(row.icon)
        local fresh = o.auctionMarkNew and row.foundAt and (Scan.round or 0) > 1 and GetTime() - row.foundAt < 30
        r.name:SetText((fresh and "|cff52de7cNEW|r  " or "") .. row.name .. ((row.quantity or 1) > 1 and (" |cff8a8b94x" .. row.quantity .. "|r") or ""))
        r.name:SetTextColor(q[1], q[2], q[3])
        r.buyout:SetText(ns.Money(row.buyout, true))
        r.value:SetText(ns.Money(row.value, true))
        r.profit:SetText(ns.Money(row.profit, true))
        r.pct:SetText(string.format("%d%%", math.floor(row.percent + 0.5)))
        r:SetSelected(Buy.active and Buy.row and Buy.row.auctionID == row.auctionID)
    end
    local list = W.List(p, 26, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
    list:SetPoint("BOTTOMRIGHT", -16, 70)

    -- buy bar
    local bar = W.Panel(p)
    bar:SetPoint("BOTTOMLEFT", 16, 14)
    bar:SetPoint("BOTTOMRIGHT", -16, 14)
    bar:SetHeight(46)
    bar.text = W.Text(bar, 11, C.dim)
    bar.text:SetPoint("LEFT", 12, 0)
    bar.text:SetPoint("RIGHT", -260, 0)
    bar.text:SetWordWrap(true)
    local buy = W.Button(bar, "Buy", 130, 30)
    buy:SetPoint("RIGHT", -8, 0)
    buy.color = { 0.32, 0.87, 0.49 }
    buy:SetScript("OnClick", function() Buy.Confirm() end)
    local cancel = W.Button(bar, "Skip", 100, 30)
    cancel:SetPoint("RIGHT", buy, "LEFT", -6, 0)
    cancel:SetScript("OnClick", function() Buy.Cancel("cancelled") end)
    W.Tip(cancel, "Skip", "Don't buy this one. The scan carries on if it was running.")

    local page = { frame = p }
    function page.onShow()
        minBox:Fill()
    end
    function page.refresh()
        for q, c in pairs(chips) do c:SetActive(o["ahQ" .. q]) end
        for _, b in ipairs(heads) do b:Paint() end
        if Scan.paused and Scan.running then
            scanBtn:SetLabel("Resume scan")
            scanBtn:SetActive(true)
            scanBtn:SetEnabled(true)
        else
            scanBtn:SetLabel(Scan.running and "Stop" or "Scan")
            scanBtn:SetActive(false)
            scanBtn:SetEnabled(Scan.open and not Buy.active and true or false)
        end
        local st = Scan.state
        if not Scan.open and not Scan.running then st = (#Scan.rows > 0) and "closed" or "idle" end
        if Scan.paused then st = "paused" end
        local stText = Scan.STATE_TEXT[st] or st
        if st == "browse" and Scan.browsing then
            stText = "Loading the item list: " .. QNAME[Scan.browsing] .. " gear..."
        end
        if (st == "search" or st == "loading") and Scan.keys and #Scan.keys > 0 then
            local cur = Scan.current and C_AuctionHouse.GetItemKeyInfo and C_AuctionHouse.GetItemKeyInfo(Scan.current)
            stText = string.format("Checking listings %d of %d%s", math.min(Scan.index or 0, #Scan.keys), #Scan.keys,
                cur and cur.itemName and ("  ·  " .. cur.itemName) or "")
        end
        state:SetText(stText)
        local passText = (Scan.round or 0) > 1
            and string.format("pass %d (%d unchanged skipped)", Scan.round, Scan.unchanged or 0)
            or string.format("pass %d", Scan.round or 0)
        counts:SetText(string.format("%d weapons & armor  ·  %d could be deals  ·  %d worth buying  ·  %d no price  ·  %s",
            Scan.total or 0, Scan.keys and #Scan.keys or 0, #Scan.rows, Scan.skipped or 0, passText))
        list:SetData(Scan.rows, Scan.open and (Scan.running and "Nothing found yet..." or "Click Scan to look for gear worth more disenchanted than its price.")
            or "Open the auction house to scan it.")
        if Buy.nextIndex then list:ScrollTo(Buy.nextIndex); Buy.nextIndex = nil end
        if Buy.active and Buy.row then
            local prev = Buy.previous and ("|cff52de7c" .. (Buy.STATE_TEXT[Buy.previous] or "") .. "|r Next: ") or ""
            bar.text:SetText(prev .. (Buy.STATE_TEXT[Buy.state] or Buy.state) .. "\n" .. (Buy.row.link or "") .. "  " .. ns.Money(Buy.row.buyout))
            buy:SetLabel("Buy " .. ns.Money(Buy.row.buyout, true))
            buy:SetEnabled(Buy.state == "ready")
            buy:SetActive(Buy.state == "ready")
            cancel:Show()
        else
            bar.text:SetText(Buy.STATE_TEXT[Buy.state] and Buy.state ~= "idle" and Buy.STATE_TEXT[Buy.state]
                or "Click a row to check that lot, then click Buy. Nothing is bought without your click.")
            buy:SetLabel("Buy")
            buy:SetEnabled(false)
            buy:SetActive(false)
            cancel:Hide()
        end
    end
    return page
end

-- A button on the auction house window that opens this page
ns.On("AUCTION_HOUSE_SHOW", function()
    if not ns.opts.auction or not AuctionHouseFrame then return end
    if not ns.ahButton then
        local b = ns.W.Button(AuctionHouseFrame, "Salvage", 80, 22)
        b:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -60, -1)
        b:SetFrameStrata("HIGH")
        b:SetScript("OnClick", function() ns.OpenWindow(nil, "auction") end)
        ns.W.Tip(b, "Salvage Station", "Find gear worth more disenchanted than its price.")
        ns.ahButton = b
    end
    ns.ahButton:Show()
end)
