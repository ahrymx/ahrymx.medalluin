-- A quest's page: the quest log's (quests/log.lua) and the tracker's click
-- opens it. A box of its own (window/shell.lua, detached only: dragged,
-- sized, scaled; questPagePlace). (2026-11-12, the user's P3.)
--
--   [! The Coastal Menace                                   ]  [x]   <- the head:
--   ===============================================================     its mark, its
--   Level | Zone     | Given by     | Chain  | Status  | Waypoint       title in its
--    17   | Westfall | Gryan Stoutm.| 2 of 4 | Tracked | 142 yd         difficulty's colour
--   ===============================================================  <- the facts' tiles
--   Objectives
--     0/1  Old Murk-Eye slain                                  (b)   <- (b): the line into
--     ===========-------------------------------------------            the chat box
--   Description
--     A murloc of unusual size ...
--   Rewards
--     1,250 xp     35s
--     Choose one:
--     [[icon] Murkeye's Fins     ]  [[icon] Shore Boots       ]    (tiles, two a row,
--   Chain · The Defias                                                 its quality's colour)
--    (✔)  Furlbrow's Deed                               12        <- its chain, when in
--     |                                                                one: a step a row,
--    (2)  The Coastal Menace                            17           this one gold
--     |
--    (3)  Red Linen Goods                               18
--   Drag across the words to select them, Ctrl+C to copy
--   ---------------------------------------------------------------
--   [ Untrack | Share | (map) | (pin) ]  [ Abandon ]
--
-- The facts stand in tiles across the window under the head (edge to
-- edge, ns.window.Strip): its level, its zone, who gave it (as recorded,
-- quests/givers.lua; a dash for one accepted before), its step in its
-- chain ("1 of 1" in none; no tile on a client that cannot say; the
-- game's quest line, else QuestieDB's, quests/chains.lua), its
-- state (ready, failed, tracked or not), and the waypoint's distance while
-- it has it. A quest in a chain has the chain under its rewards: its name,
-- then its quests in order on a rail, each with its step (a tick once
-- done), its title and its level, this one gold, one in the log lit; a
-- long one shortened round this one. A click on a step opens it in
-- Questie (its Journey's search) when Questie is there, else the step's
-- own page when it is in the log.
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
local TILES = 44                        -- the facts' strip
local AROUND = 6                        -- a chain's quests spelt out, at most
local STEPH, DOT = 22, 16               -- a chain's step: its row, and its numbered box
local HINT = 16                         -- the selecting hint's line, over the band
local CONFIRM = 4
local STEP = 40                         -- a turn of the wheel

local qp = {}
ns.questPage = qp

local W, page, current, armed
local scroll, child, parts, band, measure, facts
local tiles, wayTile = {}, nil
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
    elseif kind == "step" then
        -- a chain's step: its box on the rail, its title, its level
        p = CreateFrame("Button", nil, child)
        p:SetHeight(STEPH)
        p.rail = p:CreateTexture(nil, "BACKGROUND")
        p.rail:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.7)
        p.rail:SetWidth(1)
        p.rail:SetHeight(STEPH)
        p.rail:SetPoint("TOP", p, "TOPLEFT", 10 + DOT / 2, -STEPH / 2)
        p.edge = p:CreateTexture(nil, "BORDER")
        p.edge:SetSize(DOT, DOT)
        p.edge:SetPoint("LEFT", 10, 0)
        p.well = p:CreateTexture(nil, "ARTWORK")
        p.well:SetPoint("TOPLEFT", p.edge, 1, -1)
        p.well:SetPoint("BOTTOMRIGHT", p.edge, -1, 1)
        p.num = ns.PlainText(p, 10)
        p.num:SetPoint("CENTER", p.edge, 0, 0)
        p.lvl = ns.PlainText(p, 11)
        p.lvl:SetPoint("RIGHT", -6, 0)
        p.lvl:SetJustifyH("RIGHT")
        p.lvl:SetTextColor(unpack(DIM))
        p.name = ns.PlainText(p, 12)
        p.name:SetPoint("LEFT", p.edge, "RIGHT", 8, 0)
        p.name:SetPoint("RIGHT", -44, 0)
        p.name:SetJustifyH("LEFT")
        p.name:SetWordWrap(false)
        p.glow = p:CreateTexture(nil, "HIGHLIGHT")
        p.glow:SetAllPoints()
        p.glow:SetColorTexture(1, 1, 1, 0.06)
        p:SetScript("OnEnter", function(self)
            if not self.id then return end
            local spec = { title = self.title, wrap = true, { "body", self.where, DIM } }
            if self.go then table.insert(spec, { "hint", self.go }) end
            ns.Tip(self, ns.window.Outside, spec)
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(self)
            local id = self.id
            if not (id and self.go) then return end
            if Q.CanShowInQuestie() and Q.ShowInQuestie(id) then return end
            if Find(id) then qp.Open(id) end
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

-- ------------------------------------------------------------ the facts
-- The quest's chain (C_QuestLine, on its map, or the player's): its name,
-- its quests in order and where this one stands. False when the game
-- knows it is in none (or alone in one), nil when it cannot say (no
-- quest lines, or no map to ask on). When the game has no line for it,
-- QuestieDB's chain if it is installed (quests/chains.lua; no name).
local function GameChain(id)
    local L = C_QuestLine
    if not (L and L.GetQuestLineInfo and L.GetQuestLineQuests) then return nil end
    local map = GetQuestUiMapID and GetQuestUiMapID(id)
    if (not map or map == 0) and C_Map and C_Map.GetBestMapForUnit then map = C_Map.GetBestMapForUnit("player") end
    if not map or map == 0 or ns.IsSecret(map) then return nil end
    local info = L.GetQuestLineInfo(id, map)
    local line = info and info.questLineID
    if not line or ns.IsSecret(line) then return false end
    local ids, at = L.GetQuestLineQuests(line) or {}, nil
    for i, q in ipairs(ids) do
        if q == id then at = i end
    end
    if not at or #ids < 2 then return false end
    return { name = info.questLineName, ids = ids, at = at }
end

function qp.Chain(id)
    local chain = GameChain(id)
    if chain then return chain end
    local other = ns.questChains and ns.questChains.Of(id)
    if other ~= nil then return other end
    return chain
end

-- a tile: its label over its value, a hairline at its left
local function Tile(i)
    local t = tiles[i]
    if t then return t end
    t = CreateFrame("Frame", nil, facts)
    t:SetHeight(TILES - 2)
    t.label = ns.PlainText(t, 9)
    t.label:SetPoint("TOP", 0, -7)
    t.label:SetTextColor(unpack(DIM))
    t.value = ns.PlainText(t, 12)
    t.value:SetPoint("TOPLEFT", 6, -21)
    t.value:SetPoint("TOPRIGHT", -6, -21)
    t.value:SetWordWrap(false)
    t.rule = t:CreateTexture(nil, "BORDER")
    t.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    t.rule:SetWidth(1)
    t.rule:SetPoint("TOPLEFT", 0, -6)
    t.rule:SetPoint("BOTTOMLEFT", 0, 6)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        if self.tip then ns.Tip(self, ns.window.Outside, { title = self.tip, wrap = true }) end
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[i] = t
    return t
end

-- The tiles across the strip: each as wide as its words, the last to the
-- end; all narrowed alike when they come to more than the strip
local function Facts(q)
    local list = { { "Level", tostring(q.level or "") }, { "Zone", q.zone or "" } }
    local giver = ns.questGivers and ns.questGivers.Of(q.id)
    table.insert(list, giver and { "Given by", giver }
        or { "Given by", "\226\128\148", DIM, "Accepted before Medalluin recorded who gave it." })
    local chain = qp.Chain(q.id)
    if chain ~= nil then
        table.insert(list, { "Chain", chain and format("%d of %d", chain.at, #chain.ids) or "1 of 1" })
    end
    if q.state == 1 then table.insert(list, { "Status", "Ready to hand in", GOLD })
    elseif q.state == -1 then table.insert(list, { "Status", "Failed", RED })
    else table.insert(list, { "Status", q.tracked and "Tracked" or "Not tracked", q.tracked and GOLD or DIM }) end
    if WP.Is(q.id) then table.insert(list, { "Waypoint", WP.Distance(q.id), WP.COLOR, nil, true }) end
    local room = (facts:GetWidth() or 0) - 2
    if room < 2 then room = (W.window:GetWidth() or 0) - 2 end
    local widths, sum = {}, 0
    wayTile = nil
    for i, f in ipairs(list) do
        local t = Tile(i)
        t.label:SetText(f[1])
        t.value:SetText(f[2])
        t.value:SetTextColor(unpack(f[3] or ns.colors.text))
        t.tip = f[4]
        if f[5] then wayTile = t end
        widths[i] = math.ceil(math.max(t.label:GetStringWidth() or 0, t.value:GetStringWidth() or 0)) + 24
        sum = sum + widths[i]
    end
    local k = sum > room and room / sum or 1
    local x = 1
    for i = 1, #list do
        local t = tiles[i]
        local w = math.floor(widths[i] * k)
        if i == #list then w = math.max(w, room + 1 - x) end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", x, -1)
        t:SetWidth(w)
        t.rule:SetShown(i > 1)
        t:Show()
        x = x + w
    end
    for i = #list + 1, #tiles do tiles[i]:Hide() end
end
qp.Facts = Facts

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
    -- the chain, when it is one: a step a row, round this one when long
    local chain = qp.Chain(q.id)
    if chain then
        local n = #chain.ids
        local from, to = 1, n
        if n > AROUND then
            from = math.max(1, chain.at - 2)
            to = math.min(n, from + AROUND - 1)
            from = math.max(1, to - AROUND + 1)
        end
        local name = chain.name
        Heading((name and name ~= "" and not ns.IsSecret(name)) and ("Chain \194\183 " .. name) or "Chain")
        local function More(k, words)
            Plain(format(words, k), DIM, 10 + DOT + 8, 11)
            y = y + LINE
        end
        if from > 1 then More(from - 1, "\226\128\166 %d before") end
        local questie = Q.CanShowInQuestie()
        for i = from, to do
            local id = chain.ids[i]
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
            if (not title or ns.IsSecret(title)) and ns.questChains then title = ns.questChains.Title(id) end
            if not title or ns.IsSecret(title) then
                if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(id) end
                title = "\226\128\166"
            end
            local this = i == chain.at
            local done = not this and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
            local held = not this and Find(id) ~= nil
            local level = ns.questChains and ns.questChains.Level(id)
            local r = Take("step")
            r.id, r.title = id, title
            r.where = format("Step %d of %d", i, n) .. (level and (", level " .. level) or "")
                .. (this and ": this quest" or done and ": done" or held and ": in your quest log" or "")
            r.go = questie and "Click: open it in Questie." or (held and "Click: open its page.") or nil
            r:SetWidth(width)
            r.name:SetText(title)
            r.name:SetTextColor(unpack(this and GOLD or done and DIM or ns.colors.text))
            r.num:SetText(done and "\226\156\148" or tostring(i))
            r.num:SetTextColor(unpack(this and ns.colors.ink or done and DIM or GOLD))
            local edge = (this or held and not done) and GOLD or GOLD_D
            r.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
            local well = this and GOLD or ns.colors.ink
            r.well:SetColorTexture(well[1], well[2], well[3], 1)
            r.lvl:SetText(level and tostring(level) or "")
            r.rail:SetShown(i < to)
            r.glow:SetAlpha(r.go and 1 or 0)
            Put(r, 0, STEPH)
        end
        if to < n then More(n - to, "\226\128\166 %d more") end
        y = y + 4
    end
    for kind, list in pairs(parts) do
        for i = (used[kind] or 0) + 1, #list do
            list[i]:Hide()
            if kind == "item" or kind == "step" then list[i].item, list[i].id = nil, nil end
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
    Facts(q)
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
            parts = { heading = {}, text = {}, plain = {}, bar = {}, send = {}, item = {}, step = {} }
            facts = ns.window.Strip(b, TILES, 0)
            scroll = CreateFrame("ScrollFrame", nil, b)
            scroll:SetPoint("TOPLEFT", 0, -(TILES + 8))
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
            qp.band, qp.child, qp.scroll, qp.facts = band, child, scroll, facts
            -- the waypoint: the band's pin and the facts' tile; the distance kept up
            WP.OnChange(function() qp.Refresh() end)
            WP.OnTick(function()
                local q = qp.quest
                if wayTile and wayTile:IsShown() and q and W.window:IsShown() then
                    wayTile.value:SetText(WP.Distance(q.id))
                end
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

-- a chain's quest's title come in: drawn again
ns.On("QUEST_DATA_LOAD_RESULT", function()
    if qp.Current() then qp.Refresh() end
end)
