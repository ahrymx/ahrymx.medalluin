-- Drop: the quest log's window for abandoning quests (quests/log.lua's
-- Drop). A box of its own (window/shell.lua, detached only: dragged, sized,
-- scaled; questDropPlace), every quest in the log by zone, each with a tick.
--
--   [quests]                                                   [x]
--   ---------------------------------------------------------------
--   Tick the quests to abandon.
--   [ All | None ]  [ Grey | Failed ]
--   [-] Westfall                                            2 / 4
--       [ ] [18] The Defias Brotherhood
--       [v] [16] Patrolling Westfall                    (washed red)
--   ---------------------------------------------------------------
--   [ Cancel ]  [ Abandon 2 quests ]
--
-- A zone's tick picks all its quests, or none when all are picked; it shows
-- all, some or none. Grey picks the quests too low to give experience,
-- Failed the failed ones. Abandon asks once more on its own face (Confirm:
-- abandon 2), for four seconds or until the picks change; the second click
-- abandons them all, one after the other, and the window closes.
local _, ns = ...

local Q = ns.questSource
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local RED = { 0.86, 0.27, 0.22 }
local ROW, ZONE, TICK, PICKS = 20, 24, 14, 24
local CONFIRM = 4                       -- seconds the confirm stands

local drop = {}
ns.questDrop = drop

local W, page
local picked = {}                       -- [id] = true
local quests, lines = {}, {}
local first, shown = 0, 0
local armed                             -- the confirm's token, while it stands
local body, intro, picks, list, rows, empty, band

-- ------------------------------------------------------------------ picks
local function Count()
    local n = 0
    for _, q in ipairs(quests) do if picked[q.id] then n = n + 1 end end
    return n
end

local function Grey(q)
    if q.rewards and q.rewards.xp == 0 then return true end
    local level = UnitLevel and UnitLevel("player") or 0
    return GetQuestGreenRange and q.level > 0 and level - q.level > GetQuestGreenRange() or false
end

local function Disarm() armed = nil end

local function Changed()
    Disarm()
    drop.Refresh()
end

local function Pick(fn)
    wipe(picked)
    for _, q in ipairs(quests) do
        if fn(q) then picked[q.id] = true end
    end
    Changed()
end

-- --------------------------------------------------------------- the rows
local function Tick(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(TICK, TICK)
    ns.window.Face(t)
    t.check = ns.PlainText(t, 11)
    t.check:SetPoint("CENTER", 0, 0)
    t.check:SetTextColor(unpack(GOLD))
    t.check:SetText("\226\156\148")
    t.part = t:CreateTexture(nil, "ARTWORK")
    t.part:SetPoint("LEFT", 3, 0)
    t.part:SetPoint("RIGHT", -3, 0)
    t.part:SetHeight(2)
    t.part:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    function t.Set(state)
        t.check:SetShown(state == "all")
        t.part:SetShown(state == "some")
        t.state = state
    end
    return t
end

local function Wheel(delta) drop.Scroll(-delta * 3) end

local function Row()
    local r = CreateFrame("Button", nil, list)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    r.wash = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.wash:SetAllPoints()
    r.wash:SetColorTexture(0.6, 0.16, 0.12, 0.28)
    r.band = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.band:SetPoint("TOPLEFT", 0, -2)
    r.band:SetPoint("BOTTOMRIGHT", 0, 2)
    if r.band.SetGradient and CreateColor then
        r.band:SetColorTexture(1, 1, 1, 1)
        r.band:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45),
            CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.045))
    else
        r.band:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.25)
    end
    r.tick = Tick(r)
    r.label = ns.PlainText(r, 11)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.label:SetPoint("RIGHT", -60, 0)
    r.zone = ns.Text(r, 13)
    r.zone:SetPoint("LEFT", TICK + 12, 0)
    r.zone:SetTextColor(unpack(GOLD))
    r.count = ns.Text(r, 11)
    r.count:SetPoint("RIGHT", -6, 0)
    r.count:SetTextColor(unpack(DIM))
    r:SetScript("OnClick", function(self)
        local d = self.data
        if d.zone then
            local all = self.tick.state == "all"
            for _, q in ipairs(d.zone.quests) do picked[q.id] = not all or nil end
        else
            picked[d.quest.id] = not picked[d.quest.id] or nil
        end
        Changed()
    end)
    return r
end

local function Fill(r, l)
    if l.zone then
        r:SetHeight(ZONE)
        r.band:Show()
        r.wash:Hide()
        r.zone:Show()
        r.count:Show()
        r.label:Hide()
        local n = 0
        for _, q in ipairs(l.zone.quests) do if picked[q.id] then n = n + 1 end end
        r.tick:ClearAllPoints()
        r.tick:SetPoint("LEFT", 6, 0)
        r.tick.Set(n == #l.zone.quests and "all" or n > 0 and "some" or "none")
        r.zone:SetText(l.zone.name)
        r.count:SetText(n .. " / " .. #l.zone.quests)
    else
        local q = l.quest
        r:SetHeight(ROW)
        r.band:Hide()
        r.zone:Hide()
        r.count:Hide()
        r.label:Show()
        local on = picked[q.id] and true or false
        r.wash:SetShown(on)
        r.tick:ClearAllPoints()
        r.tick:SetPoint("LEFT", 18, 0)
        r.tick.Set(on and "all" or "none")
        local c = ns.QuestColour and ns.QuestColour(q) or ns.colors.text
        local hex = string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
        r.label:ClearAllPoints()
        r.label:SetPoint("LEFT", 18 + TICK + 8, 0)
        r.label:SetPoint("RIGHT", -6, 0)
        r.label:SetText(hex .. "[" .. q.level .. "]|r  " .. q.title .. (q.state == -1 and "  (failed)" or ""))
        r.label:SetTextColor(unpack(on and ns.colors.text or c))
    end
    r:Show()
end

-- ---------------------------------------------------------------- drawing
function drop.Refresh()
    if not page or not body or not W.window:IsShown() then return end
    quests = Q.All()
    local present = {}
    for _, q in ipairs(quests) do present[q.id] = true end
    for id in pairs(picked) do if not present[id] then picked[id] = nil end end
    lines = {}
    for _, z in ipairs(ns.questLog.Zones(quests)) do
        table.insert(lines, { zone = z })
        for _, q in ipairs(z.quests) do table.insert(lines, { quest = q }) end
    end
    if first > 0 and first >= #lines then first = math.max(0, #lines - 1) end
    local height = list:GetHeight()
    local y, used = 0, 0
    shown = 0
    for i = first + 1, #lines do
        local l = lines[i]
        local h = l.zone and ZONE or ROW
        if y + h > height then break end
        used = used + 1
        local r = rows[used] or Row()
        rows[used] = r
        r.data = l
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        Fill(r, l)
        y = y + h + 2
        shown = shown + 1
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    empty:SetShown(#lines == 0)
    local n = Count()
    band:Set("abandon", { enabled = n > 0, color = RED, selected = armed ~= nil })
    band.byKey.abandon.label:SetText(armed and ("Confirm: abandon " .. n)
        or n == 1 and "Abandon 1 quest" or ("Abandon " .. n .. " quests"))
end

function drop.Scroll(by)
    first = math.max(0, math.min(first + by, #lines - shown))
    drop.Refresh()
end

local function Abandon()
    local n = Count()
    if n == 0 then return end
    if not armed then
        local token = {}
        armed = token
        if C_Timer and C_Timer.After then
            C_Timer.After(CONFIRM, function()
                if armed == token then
                    Disarm()
                    drop.Refresh()
                end
            end)
        end
        drop.Refresh()
        return
    end
    local ids = {}
    for _, q in ipairs(quests) do if picked[q.id] then table.insert(ids, q.id) end end
    Disarm()
    Q.Abandon(ids)
    wipe(picked)
    drop.Close()
    if ns.questLog then ns.questLog.Refresh() end
end
drop.Abandon = Abandon

-- ------------------------------------------------------------- the window
local function Window()
    if W then return W end
    W = ns.Window{
        name = "MedalluinQuestDrop", side = 1, place = "questDropPlace", detachedOnly = true,
        closeTip = "Close, abandoning nothing.",
        Close = function() drop.Close() end,
        Lifted = function() return {} end,
    }
    page = { key = "drop", label = "Drop quests", glyph = "quests", order = 1, flex = true, bandUsed = true,
        height = 160,
        Available = function() return true end,
        Build = function(b, _, margin)
            body = b
            intro = ns.Text(b, 11)
            intro:SetPoint("TOPLEFT", 4, -2)
            intro:SetTextColor(unpack(DIM))
            intro:SetText("Tick the quests to abandon.")
            picks = ns.window.Segments(b, { height = PICKS, items = {
                { key = "all", label = "All", group = "set", click = function() Pick(function() return true end) end,
                    tip = function() return "Every quest." end },
                { key = "none", label = "None", group = "set", click = function() Pick(function() return false end) end,
                    tip = function() return "No quest." end },
                { key = "grey", label = "Grey", group = "kind", click = function() Pick(Grey) end,
                    tip = function() return "The quests too low to give experience." end },
                { key = "failed", label = "Failed", group = "kind",
                    click = function() Pick(function(q) return q.state == -1 end) end,
                    tip = function() return "The quests you have failed." end },
            } })
            picks:SetPoint("TOPLEFT", 0, -20)
            picks:SetPoint("TOPRIGHT", 0, -20)
            list = CreateFrame("Frame", nil, b)
            list:SetPoint("TOPLEFT", 0, -(20 + PICKS + 8))
            list:SetPoint("BOTTOMRIGHT")
            list:EnableMouseWheel(true)
            list:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
            list:SetScript("OnSizeChanged", function() drop.Refresh() end)
            empty = ns.Text(list, 11)
            empty:SetPoint("TOPLEFT", 4, -4)
            empty:SetTextColor(unpack(DIM))
            empty:SetText("Your quest log is empty.")
            rows = {}
            band = ns.window.Segments(margin, { height = margin:GetHeight() > 0 and margin:GetHeight() - 8 or 28,
                items = {
                    { key = "cancel", label = "Cancel", group = "cancel", click = function() drop.Close() end,
                        tip = function() return "Close, abandoning nothing." end },
                    { key = "abandon", label = "Abandon", group = "abandon", color = RED, click = Abandon,
                        tip = function()
                            return armed and "Click again to abandon them. Their items stay in your bags."
                                or "Abandon the ticked quests. It asks once more first."
                        end },
                } })
            band:SetPoint("LEFT", 4, 0)
            band:SetPoint("RIGHT", -4, 0)
            drop.picks, drop.band, drop.list, drop.rows = picks, band, list, rows
        end,
        Refresh = function() drop.Refresh() end,
    }
    W.Page(page)
    W.Build()
    drop.window = W
    return W
end

function drop.Open()
    local w = Window()
    if not w.Current() then w.Select(page) end
    w.SetShown(true)
    drop.Refresh()
end

function drop.Close()
    Disarm()
    if W then W.SetShown(false) end
end

function drop.Toggle()
    if W and W.window:IsShown() then drop.Close() else drop.Open() end
end

drop.picked = picked
