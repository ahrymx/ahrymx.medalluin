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
--
-- In combat, where the client has the Cooldown Manager (retail's
-- Blizzard_CooldownViewer), the tab shows its tracked bars instead
-- (BuffBarCooldownViewer, chosen and sized in Edit Mode), as the game keeps
-- new buffs to itself there. The bars are adopted into the tab out of combat;
-- the swap is two visibility state drivers, run by the game's secure manager,
-- so nothing here shows, hides or moves a frame in combat. The tab stays the
-- one the player picked: the bars show only while the Auras tab does.
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
local runsOutIcon = {}          -- icon -> true / false fallback when auraInstanceID is secret
local kept = {}                 -- filter -> last entries, kept when a combat read is refused
local removed = {}              -- auraInstanceID -> true when UNIT_AURA reports removal in combat
local seconds                   -- the client's seconds formatter, for secret times
local zero                      -- a zero duration, to stop a row's timer
local holder, host              -- the lists' frame, and the tracked bars' frame over the same body
local adopted                   -- the Cooldown Manager's bar viewer, while it sits in the host
local placing = false           -- the viewer is being moved here, not by Blizzard
local watched = false
local fighting = false

local function Key(v)
    if ns.IsSecret(v) or v == nil then return nil end
    return v
end

-- ------------------------------------------------------------- reading
-- true if the aura runs out, false if it never does, nil if the client will not say
local function RunsOut(aura)
    local id = aura.auraInstanceID
    local timed
    if Auras.DoesAuraHaveExpirationTime and ns.Present(id) then
        local ok, res = pcall(Auras.DoesAuraHaveExpirationTime, "player", id)
        if ok then timed = res end
    elseif not InCombatLockdown() then
        timed = aura.expirationTime
        if not ns.IsSecret(timed) and timed ~= nil then timed = timed > 0 end
    end
    if ns.IsSecret(timed) or timed == nil then return nil end
    if InCombatLockdown() and not timed then return nil end
    return timed and true or false
end

local function IsDebuffAura(aura)
    local h = aura.isHarmful
    if not ns.IsSecret(h) and h ~= nil then return h and true or false end
    local help = aura.isHelpful
    if not ns.IsSecret(help) and help ~= nil then return not help end
    local id = Key(aura.auraInstanceID)
    if id and Auras.IsAuraFilteredOutByInstanceID then
        local ok, out = pcall(Auras.IsAuraFilteredOutByInstanceID, "player", id, "HARMFUL")
        if ok and not ns.IsSecret(out) and out ~= nil then return not out end
        local ok2, out2 = pcall(Auras.IsAuraFilteredOutByInstanceID, "player", id, "HELPFUL")
        if ok2 and not ns.IsSecret(out2) and out2 ~= nil then return out2 and true or false end
    end
    return false
end

local function FetchByIndex(filter)
    local out, refused = {}, false
    for i = 1, 40 do
        local ok, aura = pcall(Auras.GetAuraDataByIndex, "player", i, filter)
        if not ok then
            refused = true
        elseif ns.IsSecret(aura) or not aura then
            break
        else
            table.insert(out, aura)
        end
    end
    return out, refused
end

local function AddAuras(dst, src, seenId, seenIcon)
    for _, aura in ipairs(src) do
        if not ns.IsSecret(aura) then
            local id = Key(aura.auraInstanceID)
            local icon = Key(aura.icon)
            if id then
                if not seenId[id] then
                    seenId[id] = true
                    table.insert(dst, aura)
                end
            elseif icon then
                if not seenIcon[icon] then
                    seenIcon[icon] = true
                    table.insert(dst, aura)
                end
            else
                table.insert(dst, aura)
            end
        end
    end
end

-- The player's buffs or debuffs, the longest first as the client sorts them.
local function Fetch(filter)
    local out, seenId, seenIcon = {}, {}, {}
    local refused = false
    if Auras.GetUnitAuras and SORT and DIRECTION then
        local ok, res = pcall(Auras.GetUnitAuras, "player", filter, nil, SORT.ExpirationOnly, DIRECTION.Reverse)
        if ok and not ns.IsSecret(res) and res then
            AddAuras(out, res, seenId, seenIcon)
            if #out > 0 and not InCombatLockdown() then return out, false end
        elseif not ok then
            refused = true
        end
    end
    if #out == 0 or refused or InCombatLockdown() then
        local idx, ref1 = FetchByIndex(filter)
        AddAuras(out, idx, seenId, seenIcon)
        refused = refused or ref1
    end
    if refused then
        local ownFilter = filter .. "|PLAYER"
        if #out == 0 and Auras.GetUnitAuras and SORT and DIRECTION then
            local ok, res = pcall(
                Auras.GetUnitAuras, "player", ownFilter, nil, SORT.ExpirationOnly, DIRECTION.Reverse
            )
            if ok and not ns.IsSecret(res) and res then AddAuras(out, res, seenId, seenIcon) end
        end
        local own = FetchByIndex(ownFilter)
        AddAuras(out, own, seenId, seenIcon)
    end
    return out, refused
end

local function EntryFromAura(aura, debuff, seen, prevById, prevByIcon)
    local key = Key(aura.auraInstanceID)
    local icon = Key(aura.icon)
    local prev = (key and prevById and prevById[key]) or (not key and icon and prevByIcon and prevByIcon[icon]) or nil
    local timed = RunsOut(aura)
    if key then
        if timed == nil then timed = runsOut[key] end
        seen[key] = timed
    elseif icon and timed == nil then
        timed = runsOutIcon[icon]
    end
    if icon and timed ~= nil then runsOutIcon[icon] = timed end
    local ends = aura.expirationTime
    if ns.IsSecret(ends) or ends == 0 then ends = nil end
    local full = aura.duration
    if ns.IsSecret(full) or full == 0 then full = prev and prev.full or nil end
    local added = prev and prev.addedInCombat or (InCombatLockdown() and not prev and true or nil)
    return {
        aura = aura, debuff = debuff, timed = timed, ends = ends,
        prevEnds = ends or (prev and prev.prevEnds),
        duration = prev and prev.duration, full = full,
        addedInCombat = added,
    }
end

-- Each aura as an entry: whether it is a debuff, whether it runs out (as
-- read now, or as last read), and its end time when that can be read.
local function Entries(filter, debuff, seen)
    local prevList = kept[filter] or {}
    local prevById, prevByIcon = {}, {}
    for _, e in ipairs(prevList) do
        local id = Key(e.aura.auraInstanceID)
        local icon = Key(e.aura.icon)
        if id then prevById[id] = e end
        if icon and not prevByIcon[icon] then prevByIcon[icon] = e end
    end
    local list, refused = Fetch(filter)
    local out, present, presentIcon = {}, {}, {}
    for _, aura in ipairs(list) do
        local id = Key(aura.auraInstanceID)
        local icon = Key(aura.icon)
        if not (id and removed[id]) then
            local e = EntryFromAura(aura, debuff, seen, prevById, prevByIcon)
            if id then present[id] = true end
            if icon then presentIcon[icon] = true end
            table.insert(out, e)
        end
    end
    if InCombatLockdown() or refused then
        local now = GetTime()
        local keepAll = refused or #out == 0
        for _, e in ipairs(prevList) do
            local key = Key(e.aura.auraInstanceID)
            local icon = Key(e.aura.icon)
            local exp = e.ends or e.prevEnds
            local alive = not exp or exp > now
            if alive and (keepAll or e.addedInCombat) then
                if key and not present[key] and not removed[key] then
                    local keep = true
                    if not e.addedInCombat and Auras.GetAuraDataByAuraInstanceID then
                        local ok, aura = pcall(Auras.GetAuraDataByAuraInstanceID, "player", key)
                        if ok and not ns.IsSecret(aura) then
                            if not aura then
                                keep = false
                            else
                                e = EntryFromAura(aura, debuff, seen, prevById, prevByIcon)
                            end
                        end
                    end
                    if keep then
                        if seen[key] == nil then seen[key] = e.timed end
                        present[key] = true
                        if icon then presentIcon[icon] = true end
                        table.insert(out, e)
                    end
                elseif not key and icon and not presentIcon[icon] then
                    presentIcon[icon] = true
                    table.insert(out, e)
                end
            end
        end
    end
    kept[filter] = out
    return out
end

-- Timeless first (when they are listed), then the latest end first.
local function Later(a, b)
    local at, bt = a.timed == false, b.timed == false
    if at ~= bt then return at end
    if a.ends ~= b.ends then return (a.ends or 0) > (b.ends or 0) end
    local ida = not ns.IsSecret(a.aura.auraInstanceID) and a.aura.auraInstanceID or 0
    local idb = not ns.IsSecret(b.aura.auraInstanceID) and b.aura.auraInstanceID or 0
    return ida < idb
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
    if InCombatLockdown() then
        for k, v in pairs(seen) do runsOut[k] = v end
    else
        runsOut = seen
        wipe(removed)
    end
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
    if r.duration and r.duration.GetRemainingDuration then
        local ok, s = pcall(r.duration.GetRemainingDuration, r.duration)
        if ok then
            if not ns.IsSecret(s) then
                if s ~= nil then return math.max(0, s) end
            else
                local f = Seconds()
                if f then
                    local ok2, text = pcall(f.Format, f, s)
                    if ok2 and ns.Present(text) then return nil, text end
                end
                return nil
            end
        end
    end
    if e.prevEnds then return math.max(0, e.prevEnds - GetTime()) end
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
        r.left:SetText(ns.Or(text, ""))
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
    if Auras.GetAuraApplicationDisplayCount and ns.Present(id) then
        local ok, count = pcall(Auras.GetAuraApplicationDisplayCount, "player", id, 2)
        if ok and ns.Present(count) then return count end
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
                pcall(r.SetTimerDuration, r, zero, INTERPOLATION and INTERPOLATION.Immediate or 0, TIMER.RemainingTime)
            end
        end
        r.duration, r.clientBar = nil, false
        r:SetMinMaxValues(0, 1)
        r:SetValue(0)
        return
    end
    r.duration, r.clientBar = nil, false
    local id = aura.auraInstanceID
    if Auras.GetAuraDuration and ns.Present(id) then
        local ok, dur = pcall(Auras.GetAuraDuration, "player", id)
        if ok and ns.Present(dur) then
            r.duration = dur
            e.duration = dur
        end
    end
    if not r.duration and e.duration then r.duration = e.duration end
    if r.duration and r.SetTimerDuration and TIMER then
        local ok = pcall(
            r.SetTimerDuration, r, r.duration, INTERPOLATION and INTERPOLATION.Immediate or 0, TIMER.RemainingTime
        )
        r.clientBar = ok
    end
    if not r.clientBar then
        if not pcall(r.SetMinMaxValues, r, 0, ns.Or(e.full or aura.duration, 1)) then
            r:SetMinMaxValues(0, 1)
        end
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
    r.label:SetText(ns.Or(aura.name, ""))
    Bar(r, e)
    Tick(r)
    r:Show()
end

-- ------------------------------------------------------------ the lists
-- A list's heading: its title, its count, and the gold line under them.
local function Header(f)
    local title = ns.Text(f, 11)
    title:SetPoint("TOPLEFT", 2, -(HEAD / 2) + 5)
    title:SetTextColor(unpack(GOLD))
    local number = ns.PlainText(f, 10)
    number:SetPoint("TOPRIGHT", -2, -(HEAD / 2) + 5)
    number:SetTextColor(unpack(DIM))
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -(HEAD - 2))
    line:SetPoint("TOPRIGHT", 0, -(HEAD - 2))
    return title, number
end

local function List()
    local list = { rows = {} }
    local f = CreateFrame("Frame", nil, body)
    list.frame = f
    list.title, list.number = Header(f)
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

local function RemoveKept(id)
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = kept[filter]
        if list then
            for i = #list, 1, -1 do
                if Key(list[i].aura.auraInstanceID) == id then table.remove(list, i) end
            end
        end
    end
end

local function UpsertKept(aura, debuff)
    if ns.IsSecret(aura) or not aura then return end
    local id = Key(aura.auraInstanceID)
    if id then removed[id] = nil end
    local filter = debuff and "HARMFUL" or "HELPFUL"
    local list = kept[filter]
    if not list then
        list = {}
        kept[filter] = list
    end
    local icon = Key(aura.icon)
    local prevById, prevByIcon, match = {}, {}, nil
    for i, e in ipairs(list) do
        local eid = Key(e.aura.auraInstanceID)
        local eicon = Key(e.aura.icon)
        if eid then prevById[eid] = e end
        if eicon and not prevByIcon[eicon] then prevByIcon[eicon] = e end
        if not match and ((id and eid == id) or (not id and not eid and icon and eicon == icon)) then
            match = i
        end
    end
    local ne = EntryFromAura(aura, debuff, runsOut, prevById, prevByIcon)
    if match then
        ne.addedInCombat = list[match].addedInCombat
        list[match] = ne
    else
        ne.addedInCombat = InCombatLockdown() or nil
        table.insert(list, ne)
    end
end

local function ScanCombatAuras(retry)
    if not InCombatLockdown() then return end
    local ref = false
    for _, spec in ipairs({ { "HELPFUL", false }, { "HARMFUL", true } }) do
        local list, r = FetchByIndex(spec[1])
        for _, aura in ipairs(list) do UpsertKept(aura, spec[2]) end
        if r then
            ref = true
            local own = FetchByIndex(spec[1] .. "|PLAYER")
            for _, aura in ipairs(own) do UpsertKept(aura, spec[2]) end
        end
    end
    if ref and not retry and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            ScanCombatAuras(true)
            dirty = true
        end)
    end
end

-- ---------------------------------------------------- the tracked bars
local function Viewer() return _G.BuffBarCooldownViewer end

-- The bars are what the tab shows: adopted, and the player fighting.
local function Tracking() return adopted ~= nil and fighting end

-- Edit Mode (or anything else) moving the viewer away: back into the tab
-- once combat allows.
local function Watch(v)
    if watched then return end
    watched = true
    local function Moved()
        if placing or adopted ~= v then return end
        ns.OutOfCombat(function()
            if adopted == v then
                placing = true
                pcall(function()
                    v:SetParent(host)
                    v:ClearAllPoints()
                    v:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(HEAD + 1))
                end)
                placing = false
            end
        end)
    end
    hooksecurefunc(v, "SetParent", function(_, parent) if parent ~= host then Moved() end end)
    hooksecurefunc(v, "SetPoint", Moved)
end

-- Under the tab's own heading; Edit Mode keeps their width, which bars
-- are tracked, and whether the Cooldown Manager is on at all.
local function Adopt(v)
    placing = true
    local ok = pcall(function()
        v:SetParent(host)
        v:ClearAllPoints()
        v:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(HEAD + 1))
    end)
    placing = false
    if not ok then return end
    adopted = v
    Watch(v)
end

-- Back to UIParent and its Edit Mode place.
local function GiveBack()
    local v = adopted
    if not v then return end
    adopted = nil
    placing = true
    pcall(v.SetParent, v, UIParent)
    if v.ApplySystemAnchor then pcall(v.ApplySystemAnchor, v) end
    placing = false
end

-- Out of combat only: adopt the viewer (or give it back) and set the two
-- drivers that swap the lists for the bars while combat lasts.
local function Drive()
    if not host then return end
    ns.OutOfCombat(function()
        local v = Viewer()
        if ns.db.aurasTrackedBars and v then
            if adopted ~= v then Adopt(v) end
        else
            GiveBack()
        end
        if adopted then
            RegisterStateDriver(host, "visibility", "[combat] show; hide")
            RegisterStateDriver(holder, "visibility", "[combat] hide; show")
        else
            UnregisterStateDriver(host, "visibility")
            UnregisterStateDriver(holder, "visibility")
            host:Hide()
            holder:Show()
        end
        ns.side.Changed()
    end)
end

-- --------------------------------------------------------------- the view
local view = {
    key = "auras", label = "Auras", option = "sideAuras",
    Available = function() return Auras ~= nil and Auras.GetAuraDataByIndex ~= nil end,
}

function view.Build(f)
    -- the lists in a frame of their own, the tracked bars' over the same body
    holder = CreateFrame("Frame", nil, f)
    holder:SetAllPoints(f)
    holder:SetSize(f:GetWidth(), f:GetHeight())
    body = holder
    rows = math.floor((f:GetHeight() - HEAD - 1 + GAP) / (ROW + GAP))
    lists = { List(), List() }
    Layout()
    host = CreateFrame("Frame", "MedalluinAurasTrackedBars", f)
    host:SetAllPoints(f)
    host:SetSize(f:GetWidth(), f:GetHeight())
    host:Hide()
    local title = Header(host)
    title:SetText("Tracked bars")
    fighting = InCombatLockdown() and true or false
    -- the auras change in bursts: read them at most four times a second,
    -- and only while the tab is shown; the times five times a second.
    -- Not while the tracked bars stand in for the lists.
    f:SetScript("OnUpdate", function(_, elapsed)
        if Tracking() then return end
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
    events:SetScript("OnEvent", function(_, _, _, info)
        dirty = true
        if info and not ns.IsSecret(info) then
            local rem = not ns.IsSecret(info.removedAuraInstanceIDs) and info.removedAuraInstanceIDs
            for _, id in ipairs(rem or {}) do
                local k = Key(id)
                if k then
                    removed[k] = true
                    RemoveKept(k)
                end
            end
            local add = not ns.IsSecret(info.addedAuras) and info.addedAuras
            for _, aura in ipairs(add or {}) do
                if not ns.IsSecret(aura) then UpsertKept(aura, IsDebuffAura(aura)) end
            end
            local upd = not ns.IsSecret(info.updatedAuraInstanceIDs) and info.updatedAuraInstanceIDs
            for _, id in ipairs(upd or {}) do
                local k = Key(id)
                if k and Auras.GetAuraDataByAuraInstanceID then
                    local ok, aura = pcall(Auras.GetAuraDataByAuraInstanceID, "player", k)
                    if ok and not ns.IsSecret(aura) and aura then
                        UpsertKept(aura, IsDebuffAura(aura))
                    end
                end
            end
        end
        ScanCombatAuras(false)
    end)
    -- out of combat the times can be read again: sort by them
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        ns.On(e, function() dirty = true end)
    end
    ns.OnSetting("aurasTimeless", Refresh)
    ns.OnSetting("aurasColumns", function()
        Layout()
        Refresh()
    end)
    -- the tracked bars: when the Cooldown Manager loads, and when their option changes
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_CooldownViewer" then Drive() end
    end)
    ns.On("PLAYER_REGEN_DISABLED", function()
        fighting = true
        ns.side.Changed()
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        fighting = false
        ns.side.Changed()
    end)
    ns.OnSetting("aurasTrackedBars", Drive)
    Drive()
end

view.Refresh = Refresh

function view.Scroll(by)
    if Tracking() then return end
    first = math.max(0, math.min(first + by, total - rows))
    Refresh()
end

-- No thumb while the tracked bars are shown: they are not scrolled.
function view.Thumb()
    if Tracking() then return 0, 0, 0 end
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
