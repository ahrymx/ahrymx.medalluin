-- The side panel's Auras tab: the player's buffs and debuffs, each with the
-- time it has left, the longest first. Two lists side by side (Buffs |
-- Debuffs), or one list of both.
--
-- A row: the icon (edged in the debuff's dispel colour, or gold for a buff)
-- with its stack count, the name, a bar of the time left against the full
-- duration (gold for a buff, red for a debuff), and the time left.
--
-- In combat the times can be secret (Forever and retail restrict the aura
-- API there). Nothing here does arithmetic on them or tests them:
--   * the order is the client's own: GetUnitAuras sorted by expiration,
--     reversed, which holds in combat. Out of combat, when every time can
--     be read, the lists are sorted here as well, so the order never rests
--     on where the client puts an aura that never runs out;
--   * the bar is the client's: SetTimerDuration with the aura's duration
--     object runs it down by itself;
--   * the time text is the duration object's remaining time, formatted
--     here when it can be read and by the client's seconds formatter when
--     it cannot.
-- One list of both cannot be merged by time while the times are secret, so
-- there it is the debuffs, then the buffs, each in its own order.
--
-- Auras that never run out are left out by default (the column above the
-- portrait, buffs.lua, shows them); the infinity button lists them, at the
-- top. Whether an aura runs out can itself be secret in combat, so what was
-- learnt out of combat is kept for each aura instance.
--
-- A right click on a buff cancels it out of combat, as over the portrait.
local _, ns = ...

local Auras = C_UnitAuras
local SORT = Enum and Enum.UnitAuraSortRule
local DIRECTION = Enum and Enum.UnitAuraSortDirection
local TIMER = Enum and Enum.StatusBarTimerDirection
local INTERPOLATION = Enum and Enum.StatusBarInterpolation

local ROW, GAP, HEAD = 16, 2, 18
local SPLIT = 3                 -- each list stands this far from the panel's middle
local URGENT = 10               -- a debuff's time turns red under this many seconds
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
local RED = { 1, 0.502, 0.439 }
local BUFF_BAR = { 0.541, 0.439, 0.204 }
local DEBUFF_BAR = { 0.541, 0.227, 0.188 }
local DISPEL = {
    Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Poison = { 0, 0.6, 0 }, Disease = { 0.6, 0.4, 0 },
}
local NONE = { 0.753, 0.188, 0.188 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local body, lists, rows
local first, total = 0, 0
local dirty, since, tick = true, 0, 0
local runsOut = {}              -- auraInstanceID -> true / false, as last read
local seconds                   -- the client's seconds formatter, for secret times
local zero                      -- a zero duration, to stop a row's timer

-- ------------------------------------------------------------- reading
-- true if the aura runs out, false if it never does, nil if the client will not say
local function RunsOut(aura)
    local id = aura.auraInstanceID
    local timed
    if Auras.DoesAuraHaveExpirationTime and not ns.IsSecret(id) then
        timed = Auras.DoesAuraHaveExpirationTime("player", id)
    else
        timed = aura.expirationTime
        if not ns.IsSecret(timed) and timed ~= nil then timed = timed > 0 end
    end
    if ns.IsSecret(timed) or timed == nil then return nil end
    return timed and true or false
end

-- The player's buffs or debuffs, the longest first as the client sorts them.
local function Fetch(filter)
    if Auras.GetUnitAuras and SORT and DIRECTION then
        return Auras.GetUnitAuras("player", filter, nil, SORT.ExpirationOnly, DIRECTION.Reverse) or {}
    end
    local out, i = {}, 1
    while true do
        local aura = Auras.GetAuraDataByIndex("player", i, filter)
        if not aura then break end
        out[i] = aura
        i = i + 1
    end
    return out
end

-- Each aura as an entry: whether it is a debuff, whether it runs out (as
-- read now, or as last read), and its end time when that can be read.
local function Entries(filter, debuff, seen)
    local out = {}
    for _, aura in ipairs(Fetch(filter)) do
        local id = aura.auraInstanceID
        local timed = RunsOut(aura)
        if not ns.IsSecret(id) then
            if timed == nil then timed = runsOut[id] end
            seen[id] = timed
        end
        local ends = aura.expirationTime
        if ns.IsSecret(ends) then ends = nil end
        table.insert(out, { aura = aura, debuff = debuff, timed = timed, ends = ends })
    end
    return out
end

-- Timeless first (when they are listed), then the latest end first.
local function Later(a, b)
    local at, bt = a.timed == false, b.timed == false
    if at ~= bt then return at end
    if a.ends ~= b.ends then return (a.ends or 0) > (b.ends or 0) end
    return (a.aura.auraInstanceID or 0) < (b.aura.auraInstanceID or 0)
end

-- Leave out the timeless ones unless they are wanted; sort when every time
-- can be read, otherwise keep the client's order with the timeless on top
-- (in the order Later gives them, so they hold still as combat starts).
local function Arrange(entries)
    local keep, readable = {}, true
    for _, e in ipairs(entries) do
        if e.timed ~= false or ns.db.aurasTimeless then
            table.insert(keep, e)
            if e.timed ~= false and e.ends == nil then readable = false end
        end
    end
    if readable then
        table.sort(keep, Later)
        return keep
    end
    local top, rest = {}, {}
    for _, e in ipairs(keep) do table.insert(e.timed == false and top or rest, e) end
    table.sort(top, Later)
    for _, e in ipairs(rest) do table.insert(top, e) end
    return top
end

local function Collect()
    local seen = {}
    local buffs = Entries("HELPFUL", false, seen)
    local debuffs = Entries("HARMFUL", true, seen)
    runsOut = seen
    if ns.db.aurasColumns == 2 then
        return { Arrange(buffs), Arrange(debuffs) }
    end
    local both = {}
    for _, e in ipairs(debuffs) do table.insert(both, e) end
    for _, e in ipairs(buffs) do table.insert(both, e) end
    return { Arrange(both) }
end

-- --------------------------------------------------------------- times
local function Clock(s)
    s = math.ceil(s)
    if s >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
    elseif s >= 60 then
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end
    return s .. "s"
end

local function Seconds()
    if seconds == nil then
        seconds = false
        if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
            local ok, f = pcall(C_StringUtil.CreateSecondsFormatter)
            if ok and f then seconds = f end
        end
    end
    return seconds or nil
end

-- The time left, as a number when it can be read, else as the client's text.
local function Left(r)
    local e = r.entry
    if e.ends then return math.max(0, e.ends - GetTime()) end
    if not r.duration then return nil end
    local s = r.duration:GetRemainingDuration()
    if not ns.IsSecret(s) then return math.max(0, s) end
    local f = Seconds()
    if f then
        local ok, text = pcall(f.Format, f, s)
        if ok then return nil, text end
    end
    return nil
end

local function Tick(r)
    if r.entry.timed == false then
        r.left:SetText("")
        return
    end
    local s, text = Left(r)
    if s then
        r.left:SetText(Clock(s))
        r.left:SetTextColor(unpack(r.entry.debuff and s < URGENT and RED or ns.colors.text))
        if not r.clientBar then r:SetValue(s) end
    else
        r.left:SetText(text or "")
        r.left:SetTextColor(unpack(ns.colors.text))
    end
end

-- ------------------------------------------------------------- the rows
local function Tip(r)
    if not r.entry then return end
    GameTooltip:SetOwner(r, "ANCHOR_LEFT")
    if GameTooltip.SetUnitAuraByAuraInstanceID then
        GameTooltip:SetUnitAuraByAuraInstanceID("player", r.entry.aura.auraInstanceID)
    end
    GameTooltip:Show()
end

local function Row(parent)
    local r = CreateFrame("StatusBar", nil, parent)
    r:SetHeight(ROW)
    r:SetStatusBarTexture(WHITE8)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    local fill = r:GetStatusBarTexture()
    local sheen = r:CreateTexture(nil, "ARTWORK", nil, 2)
    sheen:SetColorTexture(1, 1, 1, 0.07)
    sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
    sheen:SetPoint("BOTTOMRIGHT", fill, "RIGHT")
    -- the icon in a square edged in gold, or in the debuff's dispel colour
    r.edge = r:CreateTexture(nil, "OVERLAY", nil, 1)
    r.edge:SetSize(ROW, ROW)
    r.edge:SetPoint("LEFT")
    r.icon = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.icon:SetSize(ROW - 2, ROW - 2)
    r.icon:SetPoint("CENTER", r.edge)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = ns.PlainText(r, 9)
    r.count:SetPoint("BOTTOMRIGHT", r.edge, "BOTTOMRIGHT", 0, 0)
    r.count:SetTextColor(1, 1, 1)
    r.left = ns.PlainText(r, 10)
    r.left:SetPoint("RIGHT", -3, 0)
    r.label = ns.Text(r, 10)
    r.label:SetPoint("LEFT", ROW + 5, 0)
    r.label:SetPoint("RIGHT", r, "RIGHT", -46, 0)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", Tip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self, mouse)
        local e = self.entry
        if mouse ~= "RightButton" or not e or e.debuff or InCombatLockdown() then return end
        if Auras.CancelAuraByInstanceID then Auras.CancelAuraByInstanceID("player", e.aura.auraInstanceID) end
    end)
    ns.side.PassWheel(r)
    return r
end

local function Count(aura)
    local id = aura.auraInstanceID
    if Auras.GetAuraApplicationDisplayCount and not ns.IsSecret(id) then
        return Auras.GetAuraApplicationDisplayCount("player", id, 2)
    end
    local n = aura.applications
    if ns.IsSecret(n) then return n end
    if not n or n < 2 then return "" end
    return n
end

-- The bar: the client's own timer where it has one; otherwise the full
-- duration as the range, and the time left set on each tick. A timeless
-- aura has none: a row that ran a timer before is handed a zero duration
-- (a status bar has no way to drop its timer), so it stops.
local function Bar(r, e)
    local aura = e.aura
    if e.timed == false then
        if r.clientBar then
            zero = zero or C_DurationUtil and C_DurationUtil.CreateDuration and C_DurationUtil.CreateDuration()
            if zero then
                r:SetTimerDuration(zero, INTERPOLATION and INTERPOLATION.Immediate or 0, TIMER.RemainingTime)
            end
        end
        r.duration, r.clientBar = nil, false
        r:SetMinMaxValues(0, 1)
        r:SetValue(0)
        return
    end
    r.duration, r.clientBar = nil, false
    local id = aura.auraInstanceID
    if Auras.GetAuraDuration and not ns.IsSecret(id) then r.duration = Auras.GetAuraDuration("player", id) end
    if r.duration and r.SetTimerDuration and TIMER then
        r:SetTimerDuration(r.duration, INTERPOLATION and INTERPOLATION.Immediate or 0, TIMER.RemainingTime)
        r.clientBar = true
    else
        r:SetMinMaxValues(0, ns.Or(aura.duration, 1))
    end
end

local function Fill(r, e)
    r.entry = e
    local aura = e.aura
    local c = GOLD_D
    if e.debuff then
        local kind = aura.dispelName
        c = not ns.IsSecret(kind) and DISPEL[kind] or NONE
    end
    r.edge:SetColorTexture(c[1], c[2], c[3], 1)
    local bar = e.debuff and DEBUFF_BAR or BUFF_BAR
    r:SetStatusBarColor(bar[1], bar[2], bar[3], 0.75)
    r.icon:SetTexture(aura.icon)
    r.count:SetText(Count(aura))
    r.label:SetText(aura.name)
    Bar(r, e)
    Tick(r)
    r:Show()
end

-- ------------------------------------------------------------ the lists
local function List()
    local list = { rows = {} }
    local f = CreateFrame("Frame", nil, body)
    list.frame = f
    list.title = ns.Text(f, 11)
    list.title:SetPoint("TOPLEFT", 2, -(HEAD / 2) + 5)
    list.title:SetTextColor(unpack(GOLD))
    list.number = ns.PlainText(f, 10)
    list.number:SetPoint("TOPRIGHT", -2, -(HEAD / 2) + 5)
    list.number:SetTextColor(unpack(DIM))
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -(HEAD - 2))
    line:SetPoint("TOPRIGHT", 0, -(HEAD - 2))
    list.empty = ns.Text(f, 10)
    list.empty:SetPoint("TOPLEFT", 4, -(HEAD + 6))
    list.empty:SetPoint("RIGHT", -4, 0)
    list.empty:SetJustifyH("LEFT")
    list.empty:SetTextColor(unpack(DIM))
    for i = 1, rows do
        local r = Row(f)
        r:SetPoint("TOPLEFT", 0, -(HEAD + 1) - (i - 1) * (ROW + GAP))
        r:SetPoint("TOPRIGHT", 0, -(HEAD + 1) - (i - 1) * (ROW + GAP))
        list.rows[i] = r
    end
    return list
end

-- One list across the body, or two halves with SPLIT either side of the middle.
local function Layout()
    local two = ns.db.aurasColumns == 2
    local w = body:GetWidth()
    local a, b = lists[1].frame, lists[2].frame
    a:ClearAllPoints()
    a:SetPoint("TOPLEFT", body, "TOPLEFT")
    a:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT")
    a:SetWidth(two and (w / 2 - SPLIT) or w)
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", body, "TOPRIGHT")
    b:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
    b:SetWidth(w / 2 - SPLIT)
    b:SetShown(two)
    lists.count = two and 2 or 1
end

local TITLES = { [1] = { "Buffs and debuffs" }, [2] = { "Buffs", "Debuffs" } }
local EMPTY = { [1] = { "No buffs or debuffs." }, [2] = { "No buffs.", "No debuffs." } }

local function Draw(list, i, entries)
    list.title:SetText(TITLES[lists.count][i])
    list.number:SetText(#entries)
    list.empty:SetText(EMPTY[lists.count][i])
    list.empty:SetShown(#entries == 0)
    for j, r in ipairs(list.rows) do
        local e = entries[first + j]
        if e then
            Fill(r, e)
        else
            r.entry = nil
            r:Hide()
        end
    end
end

local function Refresh()
    if not body then return end
    dirty, since = false, 0
    local all = Collect()
    total = 0
    for _, entries in ipairs(all) do total = math.max(total, #entries) end
    first = math.max(0, math.min(first, total - rows))
    for i = 1, lists.count do Draw(lists[i], i, all[i]) end
    ns.side.Changed()
end

-- --------------------------------------------------------------- the view
local view = {
    key = "auras", label = "Auras", option = "sideAuras",
    Available = function() return Auras ~= nil and Auras.GetAuraDataByIndex ~= nil end,
}

function view.Build(f)
    body = f
    rows = math.floor((f:GetHeight() - HEAD - 1 + GAP) / (ROW + GAP))
    lists = { List(), List() }
    Layout()
    -- the auras change in bursts: read them at most four times a second,
    -- and only while the tab is shown; the times five times a second
    f:SetScript("OnUpdate", function(_, elapsed)
        since, tick = since + elapsed, tick + elapsed
        if dirty and since >= 0.25 then
            Refresh()
            tick = 0
        elseif tick >= 0.2 then
            tick = 0
            for i = 1, lists.count do
                for _, r in ipairs(lists[i].rows) do
                    if r.entry then Tick(r) end
                end
            end
        end
    end)
    local events = CreateFrame("Frame")
    ns.RegisterUnitEvent(events, "UNIT_AURA", "player")
    events:SetScript("OnEvent", function() dirty = true end)
    -- out of combat the times can be read again: sort by them
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        ns.On(e, function() dirty = true end)
    end
    ns.OnSetting("aurasTimeless", Refresh)
    ns.OnSetting("aurasColumns", function()
        Layout()
        Refresh()
    end)
end

view.Refresh = Refresh

function view.Scroll(by)
    first = math.max(0, math.min(first + by, total - rows))
    Refresh()
end

function view.Thumb()
    return first, rows, total
end

view.buttons = {
    {
        glyph = function() return ns.db.aurasColumns == 2 and "side-two" or "side-one" end,
        lit = function() return ns.db.aurasColumns == 2 end,
        click = function() ns.SetOption("aurasColumns", ns.db.aurasColumns == 2 and 1 or 2) end,
        tip = function()
            if ns.db.aurasColumns == 2 then
                return "Buffs | Debuffs", "Click for one list of both."
            end
            return "One list", "Click for buffs and debuffs side by side."
        end,
    },
    {
        glyph = function() return "side-timeless" end,
        lit = function() return ns.db.aurasTimeless end,
        click = function() ns.SetOption("aurasTimeless", not ns.db.aurasTimeless) end,
        tip = function()
            local what = "Forms, aspects, mounts and the like "
            return "Never run out", ns.db.aurasTimeless
                and what .. "are listed at the top. Click to leave them over the portrait only."
                or what .. "are over the portrait only. Click to list them here too."
        end,
    },
}

ns.SideView(view)
