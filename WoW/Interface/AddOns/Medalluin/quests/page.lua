-- A quest's page: the quest log's (quests/log.lua) and the tracker's click
-- opens it. A box of its own (window/shell.lua, detached only: dragged,
-- sized, scaled; questPagePlace).
--
--   [questlog]                                                 [x]
--   ---------------------------------------------------------------
--   The Coastal Menace                      (its difficulty's colour)
--   Level 17  ·  Westfall  ·  tracked
--   Objectives
--     • Old Murk-Eye slain                    (v once done, dimmed)
--   Description
--     A murloc of unusual size ...
--   Rewards
--     1,250 xp     35s
--     [icon] Murkeye's Fins                   (its quality's colour)
--     Choose one:
--     [icon] ...
--   ---------------------------------------------------------------
--   [ Untrack | Share | View on map ]  [ Abandon ]
--
-- The words scroll with the wheel when they are more than the page holds.
-- View on map opens the world map at it (quests/source.lua, Q.ShowOnMap).
-- Share only in a group, for a quest that can be shared. Abandon asks once
-- more on its own face (Confirm: abandon), for four seconds. The same quest
-- again closes it; the quest gone from the log closes it.
local _, ns = ...

local Q = ns.questSource
local GOLD = { 0.941, 0.831, 0.533 }
local DIM = { 0.55, 0.52, 0.45 }
local XP = { 0.63, 0.55, 0.9 }
local RED = { 0.86, 0.27, 0.22 }
local ICON, LINE = 28, 16
local CONFIRM = 4
local STEP = 40                         -- a turn of the wheel

local qp = {}
ns.questPage = qp

local W, page, current, armed
local scroll, child, parts, band
local offset = 0

function qp.Current() return W and W.window:IsShown() and current or nil end

local function Find(id)
    for _, q in ipairs(Q.All()) do
        if q.id == id then return q end
    end
end

-- the page's pieces, made as needed and kept: texts, headings, reward rows
local used
local function Take(kind)
    used[kind] = (used[kind] or 0) + 1
    local list = parts[kind]
    local p = list[used[kind]]
    if p then return p end
    if kind == "heading" then
        p = ns.Text(child, 13)
        p:SetTextColor(unpack(GOLD))
    elseif kind == "text" then
        p = ns.PlainText(child, 12)
        p:SetJustifyH("LEFT")
        p:SetSpacing(3)
    else
        p = CreateFrame("Button", nil, child)
        p:SetHeight(ICON)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetSize(ICON - 2, ICON - 2)
        p.icon:SetPoint("LEFT", 1, 0)
        p.edge = p:CreateTexture(nil, "BACKGROUND")
        p.edge:SetSize(ICON, ICON)
        p.edge:SetPoint("LEFT")
        p.name = ns.PlainText(p, 12)
        p.name:SetPoint("LEFT", ICON + 8, 0)
        p.count = ns.PlainText(p, 10)
        p.count:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 0, 1)
        p:SetScript("OnEnter", function(self)
            if not self.item then return end
            ns.window.Outside(self)
            local it = self.item
            if GameTooltip.SetQuestLogItem then
                GameTooltip:SetQuestLogItem(it.type, it.index, current)
            elseif it.link then
                GameTooltip:SetHyperlink(it.link)
            end
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(self)
            if self.item and self.item.link and HandleModifiedItemClick then HandleModifiedItemClick(self.item.link) end
        end)
    end
    list[used[kind]] = p
    return p
end

local function Quality(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return ns.colors.text
end

-- ---------------------------------------------------------------- drawing
local function Draw(q)
    used = {}
    local width = math.max(100, child:GetWidth())
    local y = 0
    local function Put(p, x, gap)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", x, -y)
        p:Show()
        y = y + (gap or 0)
    end
    local function Text(s, color, x, size)
        local t = Take("text")
        t:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "")
        t:SetWidth(width - x)
        t:SetText(s)
        t:SetTextColor(unpack(color or ns.colors.text))
        Put(t, x)
        y = y + math.ceil(t:GetStringHeight() or LINE) + 4
        return t
    end
    local function Heading(s)
        y = y + 6
        local h = Take("heading")
        h:SetText(s)
        Put(h, 0, 20)
    end
    local c = ns.QuestColour and ns.QuestColour(q) or ns.colors.text
    local title = Take("heading")
    title:SetText(q.title)
    title:SetTextColor(c[1], c[2], c[3])
    Put(title, 0, 20)
    title:SetTextColor(c[1], c[2], c[3])
    local facts = { "Level " .. q.level, q.zone }
    if q.state == 1 then table.insert(facts, "ready to hand in")
    elseif q.state == -1 then table.insert(facts, "failed") end
    table.insert(facts, q.tracked and "tracked" or "not tracked")
    Text(table.concat(facts, "  \194\183  "), DIM, 0, 11)
    local d = Q.Details(q)
    Heading("Objectives")
    if #q.objectives == 0 then
        Text(d.goal ~= "" and d.goal or "Nothing more to do: hand it in.", ns.colors.text, 10)
    end
    for _, o in ipairs(q.objectives) do
        Text((o.done and "\226\156\148 " or "\226\128\162 ") .. o.text, o.done and DIM or ns.colors.text, 10)
    end
    if d.text and d.text ~= "" then
        Heading("Description")
        Text(d.text, ns.colors.text, 10)
    end
    local rw = q.rewards or {}
    local has = (rw.xp or 0) > 0 or (rw.money or 0) > 0 or #d.given > 0 or #d.chosen > 0
    if has then
        Heading("Rewards")
        local bits = {}
        if (rw.xp or 0) > 0 then
            table.insert(bits, string.format("|cff%02x%02x%02x%s xp|r", XP[1] * 255, XP[2] * 255, XP[3] * 255,
                ns.questLog.Number(rw.xp)))
        end
        local coin = ns.questLog.Money(rw.money)
        if coin then
            table.insert(bits, string.format("|cff%02x%02x%02x%s|r", GOLD[1] * 255, GOLD[2] * 255, GOLD[3] * 255, coin))
        end
        if #bits > 0 then Text(table.concat(bits, "     "), ns.colors.text, 10) end
        for _, set in ipairs({ { d.given, #d.chosen > 0 and #d.given > 0 and "You get:" or nil },
            { d.chosen, #d.chosen > 1 and "Choose one:" or nil } }) do
            if #set[1] > 0 then
                if set[2] then Text(set[2], DIM, 10, 11) end
                for _, it in ipairs(set[1]) do
                    local r = Take("item")
                    r.item = it
                    r:SetWidth(width - 10)
                    r.icon:SetTexture(it.icon)
                    local qc = Quality(it.quality)
                    r.edge:SetColorTexture(qc[1], qc[2], qc[3], 1)
                    r.name:SetText(it.name)
                    r.name:SetTextColor(qc[1], qc[2], qc[3])
                    r.count:SetText((it.count or 1) > 1 and it.count or "")
                    Put(r, 10, ICON + 6)
                end
            end
        end
    end
    for kind, list in pairs(parts) do
        for i = (used[kind] or 0) + 1, #list do
            list[i]:Hide()
            if kind == "item" then list[i].item = nil end
        end
    end
    child:SetHeight(math.max(1, y))
    return y
end

local function Scroll(to)
    local range = math.max(0, child:GetHeight() - scroll:GetHeight())
    offset = math.max(0, math.min(range, to))
    child:ClearAllPoints()
    child:SetPoint("TOPLEFT", 0, offset)
    child:SetPoint("TOPRIGHT", 0, offset)
end

function qp.Refresh()
    if not page or not W.window:IsShown() or not current then return end
    local q = Find(current)
    if not q then
        qp.Close()
        return
    end
    page.label = q.title
    Draw(q)
    Scroll(offset)
    band:Set("track", { selected = false })
    band.byKey.track.label:SetText(q.tracked and "Untrack" or "Track")
    band:Set("share", { enabled = Q.CanShare(q) })
    band:Set("map", { enabled = Q.CanMap(q) })
    band:Set("abandon", { color = RED, selected = armed ~= nil })
    band.byKey.abandon.label:SetText(armed and "Confirm: abandon" or "Abandon")
    qp.quest = q
end

local function Abandon()
    if not qp.quest then return end
    if not armed then
        local token = {}
        armed = token
        if C_Timer and C_Timer.After then
            C_Timer.After(CONFIRM, function()
                if armed == token then
                    armed = nil
                    qp.Refresh()
                end
            end)
        end
        qp.Refresh()
        return
    end
    armed = nil
    Q.Abandon({ qp.quest.id })
    qp.Close()
    if ns.questLog then ns.questLog.Refresh() end
end

-- ------------------------------------------------------------- the window
local function Window()
    if W then return W end
    W = ns.Window{
        name = "MedalluinQuestPage", side = 1, place = "questPagePlace", detachedOnly = true,
        closeTip = "Close the quest's page.",
        Close = function() qp.Close() end,
        Lifted = function() return {} end,
    }
    page = { key = "quest", label = "Quest", glyph = "questlog", order = 1, flex = true, bandUsed = true,
        height = 160,
        Available = function() return true end,
        Build = function(b, _, margin)
            parts = { heading = {}, text = {}, item = {} }
            scroll = CreateFrame("ScrollFrame", nil, b)
            scroll:SetAllPoints()
            child = CreateFrame("Frame", nil, scroll)
            child:SetPoint("TOPLEFT")
            child:SetPoint("TOPRIGHT")
            child:SetHeight(1)
            scroll:SetScrollChild(child)
            scroll:EnableMouseWheel(true)
            scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(offset - delta * STEP) end)
            scroll:SetScript("OnSizeChanged", function(self, w)
                if w and w > 0 then child:SetWidth(w) end
                qp.Refresh()
            end)
            band = ns.window.Segments(margin, { height = 28, items = {
                { key = "track", label = "Track", group = "do", click = function()
                    local q = qp.quest
                    if not q then return end
                    if q.tracked then Q.Untrack(q) else Q.Track(q) end
                    qp.Refresh()
                    if ns.questLog then ns.questLog.Refresh() end
                end, tip = function()
                    return qp.quest and qp.quest.tracked and "Stop tracking it." or "Track it."
                end },
                { key = "share", label = "Share", group = "do", click = function()
                    if qp.quest and Q.CanShare(qp.quest) then Q.Share(qp.quest) end
                end, tip = function()
                    return qp.quest and Q.CanShare(qp.quest) and "Offer it to your group."
                        or "Only in a group, and only a quest that can be shared."
                end },
                { key = "map", label = "View on map", group = "do", click = function()
                    if qp.quest then Q.ShowOnMap(qp.quest) end
                end, tip = function()
                    return qp.quest and Q.CanMap(qp.quest) and "Open the world map at it."
                        or "Neither the game nor Questie knows where it is."
                end },
                { key = "abandon", label = "Abandon", group = "abandon", color = RED, click = Abandon,
                    tip = function()
                        return armed and "Click again to abandon it." or "Abandon it. It asks once more first."
                    end },
            } })
            band:SetPoint("LEFT", 4, 0)
            band:SetPoint("RIGHT", -4, 0)
            qp.band, qp.child, qp.scroll = band, child, scroll
        end,
        Refresh = function() qp.Refresh() end,
    }
    W.Page(page)
    W.Build()
    qp.window = W
    return W
end

function qp.Open(id)
    local w = Window()
    if current ~= id then
        offset = 0
        armed = nil
    end
    current = id
    if not w.Current() then w.Select(page) end
    w.SetShown(true)
    qp.Refresh()
    if ns.questLog then ns.questLog.Refresh() end
end

-- the same quest again closes it
function qp.Toggle(id)
    if qp.Current() == id then qp.Close() else qp.Open(id) end
end

function qp.Close()
    armed = nil
    if W then W.SetShown(false) end
    current = nil
    if ns.questLog and ns.questLog.IsShown() then ns.questLog.Refresh() end
end
