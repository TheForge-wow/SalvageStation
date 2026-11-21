-- Salvage Station: Ignored page (permanent, this session, and items the game refused)
local ADDON, ns = ...
local W, C = ns.W, ns.W.C

ns.PageBuilders.ignored = function(content, main)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()

    local lbl = W.Label(p, "Ignored items")
    lbl:SetPoint("TOPLEFT", 16, -22)
    local sub = W.Text(p, 11, C.dim)
    sub:SetPoint("TOPLEFT", 16, -38)
    sub:SetText("Click an item to show it again. Alt+Right-click an item in your bags to ignore it.")

    local KIND = {
        perm = "|cffffba45Permanent|r",
        session = "|cff8a8b94Until you log out|r",
        auto = "|cffff6b6bCan't be disenchanted|r",
        trusted = "|cff52de7cNot asking this session|r",
    }

    local function CreateRow(list)
        local r = W.RowBase(list)
        r.icon = W.Icon(r, 18)
        r.icon:SetPoint("LEFT", 12, 0)
        r.name = W.Text(r, 12)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -200, 0)
        r.kind = W.Text(r, 11, C.dim, "RIGHT")
        r.kind:SetPoint("RIGHT", -40, 0)
        r.x = W.Text(r, 12, C.faint, "CENTER")
        r.x:SetPoint("RIGHT", -14, 0)
        r.x:SetText("x")
        r:SetScript("OnClick", function(self)
            if not self.item then return end
            if self.item.kind == "trusted" then
                ns.UntrustForSession(self.item.id)
                ns.Print("Will ask again before disenchanting " .. ns.ItemName(self.item.id) .. ".")
                return
            end
            ns.Unhide(self.item.id)
            ns.Print(ns.ItemName(self.item.id) .. " will be listed again.")
        end)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            self.x:SetTextColor(1, 0.42, 0.42)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.item.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.item.kind == "trusted" and "Click to be asked again before disenchanting it"
                or "Click to show it again", 0.55, 0.57, 0.63)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); self.x:SetTextColor(unpack(C.faint)); GameTooltip:Hide() end)
        return r
    end
    local function UpdateRow(r, it)
        local _, _, q, _, _, _, _, _, _, icon = ns.ItemInfo(it.id)
        local col = ns.QCOL[q or 1] or { 1, 1, 1 }
        r.icon.tex:SetTexture(icon or ns.ItemIcon(it.id))
        r.name:SetText(ns.ItemName(it.id))
        r.name:SetTextColor(col[1], col[2], col[3])
        r.kind:SetText(KIND[it.kind])
    end
    local list = W.List(p, 26, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", 16, -62)
    list:SetPoint("BOTTOMRIGHT", -16, 58)

    local function Confirming(label, w, fn, tip)
        local b = W.Button(p, label, w, 28)
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
    local clearAll = Confirming("Show all again", 130, function()
        wipe(ns.db.ignore); wipe(ns.sessionIgnore); wipe(ns.db.noDE); wipe(ns.sessionOK)
        ns:RequestRefresh(0)
    end, "Clears the whole list, including ones the game refused and items you're not being asked about.")
    clearAll:SetPoint("BOTTOMRIGHT", -16, 16)

    local page = { frame = p }
    function page.refresh()
        local items = {}
        for id in pairs(ns.db.ignore) do items[#items + 1] = { id = id, kind = "perm" } end
        for id in pairs(ns.sessionIgnore) do if not ns.db.ignore[id] then items[#items + 1] = { id = id, kind = "session" } end end
        for id in pairs(ns.db.noDE) do items[#items + 1] = { id = id, kind = "auto" } end
        for id in pairs(ns.sessionOK) do items[#items + 1] = { id = id, kind = "trusted" } end
        local order = { perm = 1, session = 2, auto = 3, trusted = 4 }
        table.sort(items, function(a, b)
            if a.kind ~= b.kind then return order[a.kind] < order[b.kind] end
            return ns.ItemName(a.id) < ns.ItemName(b.id)
        end)
        list:SetData(items, "Nothing is ignored.")
    end
    return page
end
