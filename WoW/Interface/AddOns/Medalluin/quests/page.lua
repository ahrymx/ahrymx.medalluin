-- A quest's page: the quest log's (quests/log.lua) and the tracker's click
-- opens it. A box of its own (window/shell.lua, detached only: dragged,
-- sized, scaled; questPagePlace). (2026-11-12, the user's P3.)
--
--   [! The Coastal Menace                                   ]  [x]   <- the head:
--   ---------------------------------------------------------------     its mark, its
--   Level 17  ·  Westfall  ·  tracked  ·  142 yd                        title in its
--   Objectives                                                          difficulty's colour
--     0/1  Old Murk-Eye slain                                  (b)   <- (b): the line into
--     ===========-------------------------------------------            the chat box
--   Description
--     A murloc of unusual size ...
--   Rewards
--     1,250 xp     35s
--     Choose one:
--     [[icon] Murkeye's Fins     ]  [[icon] Shore Boots       ]    (tiles, two a row,
--   Drag across the words to select them, Ctrl+C to copy             its quality's colour)
--   ---------------------------------------------------------------
--   [ Untrack | Share | (map) | (pin) ]  [ Abandon ]
--
-- Shift-click on the head links the quest in chat; a drag on it moves the
-- window, as one on its ink does. The words (the facts,
-- the objectives with their counts, the description) are edit boxes a key cannot change, as
-- the chat log's (strips/chatlog.lua): the game lets text be selected only
-- in one. While a selection stands, the page is not drawn again (that would
-- drop it); it is, once the selection is left. The bubble at an
-- objective's end puts its line ("0/1 Old Murk-Eye slain") in the chat's
-- input box, as a Shift-click puts a link there, opening the box when none
-- is; it is never sent.
--
-- The words scroll with the wheel when they are more than the page holds.
-- The map glyph (the Zone tab's) opens the world map at it (quests/source.lua,
-- Q.ShowOnMap). The pin sets the waypoint to it or clears it
-- (quests/waypoint.lua): lit blue while it has it, and its distance after
-- the facts. Share only in a group, for a quest that can be shared. Abandon
-- asks once more on its own face (Confirm: abandon), for four seconds. The
-- same quest again closes it; the quest gone from the log closes it.
local _, ns = ...

local Q = ns.questSource
local WP = ns.waypoint
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local XP = { 0.63, 0.55, 0.9 }
local RED = { 0.86, 0.27, 0.22 }
local ICON, LINE = 28, 16
local TILE, GAP = 32, 6                 -- a reward's tile, and between tiles
local SEND = 18                         -- an objective's chat button, and its room on the right
local FAR = 70                          -- the waypoint's distance: its room after the facts
local HINT = 16                         -- the selecting hint's line, over the band
local CONFIRM = 4
local STEP = 40                         -- a turn of the wheel

local qp = {}
ns.questPage = qp

local W, page, current, armed
local scroll, child, parts, band, measure, far
local offset = 0

function qp.Current() return W and W.window:IsShown() and current or nil end

local function Find(id)
    for _, q in ipairs(Q.All()) do
        if q.id == id then return q end
    end
end

-- the page's pieces, made as needed and kept: headings, words (to select),
-- plain texts, objective lines, reward tiles
local used, pending
local function Take(kind)
    used[kind] = (used[kind] or 0) + 1
    local list = parts[kind]
    local p = list[used[kind]]
    if p then return p end
    if kind == "heading" then
        p = ns.Text(child, 13)
        p:SetTextColor(unpack(GOLD))
    elseif kind == "plain" then
        p = ns.PlainText(child, 12)
        p:SetJustifyH("LEFT")
    elseif kind == "text" then
        -- read only: whatever a key changes is put back; a refresh waits
        -- while one is selected (has the focus), and comes as it is left
        p = CreateFrame("EditBox", nil, child)
        p:SetMultiLine(true)
        p:SetAutoFocus(false)
        p:SetMaxLetters(0)
        p:SetScript("OnEscapePressed", p.ClearFocus)
        p:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(self.words or "") end
        end)
        p:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            if pending then
                pending = nil
                qp.Refresh()
            end
        end)
    elseif kind == "send" then
        -- the line into the chat's input box, as a Shift-click puts a link:
        -- the box open already, or opened with it; never sent
        p = CreateFrame("Button", nil, child)
        p:SetSize(SEND, SEND)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p.icon:SetTexture(ns.media .. "strips\\chat")
        p.icon:SetAlpha(0.6)
        p:SetScript("OnEnter", function(self)
            self.icon:SetAlpha(1)
            ns.Tip(self, ns.window.Outside, { title = "Put this line in the chat box", wrap = true,
                { "body", self.line or "" } })
        end)
        p:SetScript("OnLeave", function(self)
            self.icon:SetAlpha(0.6)
            GameTooltip:Hide()
        end)
        p:SetScript("OnClick", function(self)
            local line = self.line
            if not line then return end
            if ChatEdit_InsertLink and ChatEdit_InsertLink(line) then return end
            local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
            if open then open(line) end
        end)
    elseif kind == "bar" then
        p = CreateFrame("Frame", nil, child)
        p:SetHeight(2)
        p.track = p:CreateTexture(nil, "BACKGROUND")
        p.track:SetAllPoints()
        p.track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.25)
        p.fill = p:CreateTexture(nil, "ARTWORK")
        p.fill:SetPoint("TOPLEFT")
        p.fill:SetPoint("BOTTOMLEFT")
        p.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.7)
    else
        p = CreateFrame("Button", nil, child)
        p:SetHeight(TILE)
        p.bg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
        p.bg:SetAllPoints()
        p.bg:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
        p.well = p:CreateTexture(nil, "BACKGROUND", nil, 2)
        p.well:SetPoint("TOPLEFT", 1, -1)
        p.well:SetPoint("BOTTOMRIGHT", -1, 1)
        p.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.9)
        p.edge = p:CreateTexture(nil, "BORDER")
        p.edge:SetSize(ICON, ICON)
        p.edge:SetPoint("LEFT", 2, 0)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetSize(ICON - 2, ICON - 2)
        p.icon:SetPoint("CENTER", p.edge)
        p.name = ns.PlainText(p, 12)
        p.name:SetPoint("LEFT", p.edge, "RIGHT", 8, 0)
        p.name:SetPoint("RIGHT", -4, 0)
        p.name:SetJustifyH("LEFT")
        p.name:SetWordWrap(false)
        p.count = ns.PlainText(p, 10)
        p.count:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 0, 1)
        local glow = p:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
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

-- whether one of the words is selected (has the focus)
local function Selecting()
    for _, t in ipairs(parts and parts.text or {}) do
        if t:IsShown() and t:HasFocus() then return true end
    end
    return false
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
    -- words to select: as tall as a hidden string of the same font and width
    local function Text(s, color, x, size, room)
        local t = Take("text")
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local w = width - x - (room or 0)
        t:SetFont(font, size or 12, "")
        t:SetWidth(w)
        measure:SetFont(font, size or 12, "")
        measure:SetWidth(w)
        measure:SetText(s)
        local h = math.ceil(measure:GetStringHeight() or LINE)
        t:SetHeight(h + 2)
        t.words = s
        t:SetText(s)
        t:SetTextColor(unpack(color or ns.colors.text))
        Put(t, x)
        y = y + h + 6
        return t, h
    end
    local function Plain(s, color, x, size)
        local t = Take("plain")
        t:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "")
        t:SetText(s)
        t:SetTextColor(unpack(color or ns.colors.text))
        Put(t, x)
        return t
    end
    local function Heading(s)
        y = y + 6
        local h = Take("heading")
        h:SetText(s)
        Put(h, 0, 20)
    end
    -- the facts, and the waypoint's distance after them
    local facts = { "Level " .. q.level, q.zone }
    if q.state == 1 then table.insert(facts, "ready to hand in")
    elseif q.state == -1 then table.insert(facts, "failed") end
    table.insert(facts, q.tracked and "tracked" or "not tracked")
    local line = table.concat(facts, "  \194\183  ")
    local top = y
    Text(line, DIM, 0, 11, FAR)
    far:ClearAllPoints()
    far:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    measure:SetWidth(0)
    measure:SetText(line)
    far:SetPoint("TOPLEFT", child, "TOPLEFT", (measure:GetStringWidth() or 0) + 4, -top)
    far:SetShown(WP.Is(q.id))
    far:SetText(WP.Is(q.id) and ("\194\183  " .. WP.Distance(q.id)) or "")
    local d = Q.Details(q)
    Heading("Objectives")
    if #q.objectives == 0 then
        Text(d.goal ~= "" and d.goal or "Nothing more to do: hand it in.", ns.colors.text, 10)
    end
    -- each: its count first, then its words, all of it to select (one
    -- colour: a colour code would be copied too); a thin bar of it under
    for _, o in ipairs(q.objectives) do
        local counted = o.text:match("%d+%s*/%s*%d+")
        local have, need = Q.Count(o)
        local words = counted and (have .. "/" .. need .. "  " .. Q.Words(o)) or o.text
        local at = y
        local _, h = Text((o.done and "\226\156\148 " or "") .. words, o.done and DIM or ns.colors.text, 10, 12,
            SEND + 4)
        local send = Take("send")
        send.line = counted and (have .. "/" .. need .. " " .. Q.Words(o)) or o.text
        send:ClearAllPoints()
        send:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(at - 1))
        send:Show()
        if counted then
            local bar = Take("bar")
            bar:SetWidth(width - 10)
            bar.fill:SetWidth(math.max(0.01, (width - 10) * math.min(1, have / math.max(1, need))))
            bar.fill:SetShown(have > 0)
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -(at + h + 3))
            bar:Show()
            y = y + 2
        end
    end
    if d.text and d.text ~= "" then
        Heading("Description")
        Text(d.text, ns.colors.text, 10)
    end
    local rw = q.rewards or {}
    local has = (rw.xp or 0) > 0 or (rw.money or 0) > 0 or #d.given > 0 or #d.chosen > 0
    if has then
        Heading("Rewards")
        local x, any = 10, false
        if (rw.xp or 0) > 0 then
            local t = Plain(ns.questLog.Number(rw.xp) .. " xp", XP, x, 12)
            x = x + math.ceil(t:GetStringWidth() or 0) + 20
            any = true
        end
        local coin = ns.questLog.Money(rw.money)
        if coin then
            Plain(coin, GOLD, x, 12)
            any = true
        end
        if any then y = y + LINE + 6 end
        -- each set of items: two columns of tiles
        local half = math.floor((width - 10 - GAP) / 2)
        for _, set in ipairs({ { d.given, #d.chosen > 0 and #d.given > 0 and "You get:" or nil },
            { d.chosen, #d.chosen > 1 and "Choose one:" or nil } }) do
            if #set[1] > 0 then
                if set[2] then
                    Plain(set[2], DIM, 10, 11)
                    y = y + LINE + 2
                end
                for i, it in ipairs(set[1]) do
                    local r = Take("item")
                    r.item = it
                    r:SetWidth(half)
                    r.icon:SetTexture(it.icon)
                    local qc = Quality(it.quality)
                    r.edge:SetColorTexture(qc[1], qc[2], qc[3], 1)
                    r.name:SetText(it.name)
                    r.name:SetTextColor(qc[1], qc[2], qc[3])
                    r.count:SetText((it.count or 1) > 1 and it.count or "")
                    local right = i % 2 == 0
                    Put(r, right and (10 + half + GAP) or 10, 0)
                    if right or i == #set[1] then y = y + TILE + GAP end
                end
                y = y + 4
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
    qp.quest = q
    W.Head()
    -- (a selection stands: drawn once it is left)
    if Selecting() then pending = true else Draw(q) end
    Scroll(offset)
    band:Set("track", { selected = false })
    band.byKey.track.label:SetText(q.tracked and "Untrack" or "Track")
    band:Set("share", { enabled = Q.CanShare(q) })
    band:Set("map", { enabled = Q.CanMap(q) })
    band:Set("waypoint", { shown = WP.Has(), lit = WP.Is(q.id) and { wash = WP.WASH, color = WP.COLOR } or nil })
    band:Set("abandon", { color = RED, selected = armed ~= nil })
    band.byKey.abandon.label:SetText(armed and "Confirm: abandon" or "Abandon")
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
        -- the head: its mark and title; Shift links it
        head = {
            Text = function()
                local q = qp.quest
                if not q then return "" end
                return q.title, ns.QuestColour and ns.QuestColour(q) or nil
            end,
            Badge = function()
                local q = qp.quest
                return q and ns.QuestMark and ns.QuestMark(q, 16) or nil
            end,
            Click = function()
                local q = qp.quest
                if q and IsModifiedClick("CHATLINK") and GetQuestLink and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(GetQuestLink(q.id))
                end
            end,
            tip = function() return "Shift-click: link it in chat. Drag: move the window." end,
        },
        Available = function() return true end,
        Build = function(b, _, margin)
            parts = { heading = {}, text = {}, plain = {}, bar = {}, send = {}, item = {} }
            scroll = CreateFrame("ScrollFrame", nil, b)
            scroll:SetPoint("TOPLEFT")
            scroll:SetPoint("BOTTOMRIGHT", 0, HINT)
            local hint = ns.PlainText(b, 10)
            hint:SetPoint("BOTTOMLEFT", 0, 2)
            hint:SetTextColor(unpack(DIM))
            hint:SetText("Drag across the words to select them, Ctrl+C to copy.")
            child = CreateFrame("Frame", nil, scroll)
            child:SetPoint("TOPLEFT")
            child:SetPoint("TOPRIGHT")
            child:SetHeight(1)
            scroll:SetScrollChild(child)
            -- the words' heights, from a hidden string of the same font and width
            measure = child:CreateFontString(nil, "ARTWORK")
            measure:SetJustifyH("LEFT")
            measure:SetWordWrap(true)
            measure:SetNonSpaceWrap(true)
            measure:Hide()
            far = ns.PlainText(child, 11)
            far:SetTextColor(unpack(WP.COLOR))
            far:Hide()
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
                { key = "map", label = "View on map", icon = "side-zone", group = "do", click = function()
                    if qp.quest then Q.ShowOnMap(qp.quest) end
                end, tip = function()
                    return qp.quest and Q.CanMap(qp.quest) and "Open the world map at it."
                        or "Neither the game nor Questie knows where it is."
                end },
                { key = "waypoint", label = "Waypoint", icon = "waypoint", group = "do", click = function()
                    if qp.quest then WP.Toggle(qp.quest) end
                end, tip = function()
                    return qp.quest and WP.Is(qp.quest.id) and "Clear the waypoint." or "Set the waypoint to it."
                end },
                { key = "abandon", label = "Abandon", group = "abandon", color = RED, click = Abandon,
                    tip = function()
                        return armed and "Click again to abandon it." or "Abandon it. It asks once more first."
                    end },
            } })
            band:SetPoint("LEFT", 4, 0)
            band:SetPoint("RIGHT", -4, 0)
            qp.band, qp.child, qp.scroll = band, child, scroll
            -- the waypoint: the band's pin and the facts' distance; the distance kept up
            WP.OnChange(function() qp.Refresh() end)
            WP.OnTick(function()
                local q = qp.quest
                if far:IsShown() and q and W.window:IsShown() then far:SetText("\194\183  " .. WP.Distance(q.id)) end
            end)
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
