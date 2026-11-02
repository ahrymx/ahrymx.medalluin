-- The side panel's Meter tab: Medalluin's own view over the client's combat
-- meter, C_DamageMeter, the one Blizzard's Damage Meter reads. The combat
-- log is closed to addons in combat on Forever and retail, so this is the
-- only source; it also means nothing here counts anything itself.
--
-- One list, or two side by side, each showing its own thing (damage,
-- healing, absorbs ...): a heading (what, which fight, how long), then a bar
-- for each member of the group with their spec icon, name and amount, in
-- the order the client gives them, against the fight's top amount.
--
-- In combat the session's numbers and names are secret. Nothing here does
-- arithmetic on them or tests them: the bars take them as they are (the
-- status bar accepts a secret), AbbreviateLargeNumbers formats them as
-- Blizzard's own meter does, and the font strings show them. The class and
-- spec icon are never secret, so the colour and icon are picked in Lua.
--
-- The column: the fight (current, or overall), per second, one list or two;
-- at the foot, reset. Clicking a heading steps its list through what it can
-- show (right click: back). All of it is on the options page too.
local _, ns = ...

local DM = C_DamageMeter
local T = Enum and Enum.DamageMeterType or {}
local function Type(name, value) return T[name] or value end

-- What each list can show: the client's type for the total, and for the
-- amount per second where there is one. A rate type's amount is shown per
-- second; the bar is the total in both (Blizzard's meter does the same).
local METRIC = {
    damage = { total = Type("DamageDone", 0), rate = Type("Dps", 1), name = "Damage",
        rateName = "Damage per second", rateShort = "DPS" },
    healing = { total = Type("HealingDone", 2), rate = Type("Hps", 3), name = "Healing",
        rateName = "Healing per second", rateShort = "HPS" },
    absorbs = { total = Type("Absorbs", 4), name = "Absorbs" },
    interrupts = { total = Type("Interrupts", 5), name = "Interrupts" },
    dispels = { total = Type("Dispels", 6), name = "Dispels" },
    taken = { total = Type("DamageTaken", 7), name = "Damage taken", short = "Taken" },
    avoidable = { total = Type("AvoidableDamageTaken", 8), name = "Avoidable damage taken",
        short = "Avoidable" },
}
local ORDER = {}
for i, m in ipairs(ns.METER_METRICS) do ORDER[m[1]] = i end

local ROW, GAP, HEAD = 16, 2, 18
local SPLIT = 3                 -- each list stands this far from the panel's middle
local S = ns.METER_SESSION
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local body, lists, rows
local first = 0
local dirty, since, tick = true, 0, 0

local function Metric(list)
    return METRIC[ns.db[list.option]] or METRIC.damage
end

local function Session()
    return ns.db.meterSession == S.OVERALL and S.OVERALL or S.CURRENT
end

-- The type asked for, and whether its amount is per second.
local function Asked(m)
    if ns.db.meterRate and m.rate then return m.rate, true end
    return m.total, false
end

-- AbbreviateLargeNumbers takes a secret (Blizzard's meter hands it one in
-- combat); should a client's not, the font string shows the number whole.
local function Short(v)
    if AbbreviateLargeNumbers then
        local ok, s = pcall(AbbreviateLargeNumbers, v)
        if ok then return s end
    end
    return v
end

local function Clock(seconds)
    if SecondsToClock then return SecondsToClock(seconds) end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- -------------------------------------------------------------- the rows
local function Row(parent)
    local r = CreateFrame("StatusBar", nil, parent)
    r:SetHeight(ROW)
    r:SetStatusBarTexture(WHITE8)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    local fill = r:GetStatusBarTexture()
    local sheen = r:CreateTexture(nil, "ARTWORK", nil, 2)
    sheen:SetColorTexture(1, 1, 1, 0.08)
    sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
    sheen:SetPoint("BOTTOMRIGHT", fill, "RIGHT")
    -- the spec icon in an inked, gold-edged square
    local edge = r:CreateTexture(nil, "OVERLAY", nil, 1)
    edge:SetSize(ROW - 2, ROW - 2)
    edge:SetPoint("LEFT", 1, 0)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    r.icon = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.icon:SetSize(ROW - 4, ROW - 4)
    r.icon:SetPoint("CENTER", edge)
    r.label = ns.Text(r, 10)
    r.label:SetPoint("LEFT", ROW + 3, 0)
    r.label:SetJustifyH("LEFT")
    r.amount = ns.Text(r, 10)
    r.amount:SetPoint("RIGHT", -3, 0)
    r.label:SetPoint("RIGHT", r.amount, "LEFT", -4, 0)
    r.label:SetWordWrap(false)
    return r
end

local function Fill(r, src, rate)
    local c = RAID_CLASS_COLORS and src.classFilename and RAID_CLASS_COLORS[src.classFilename]
    if c then
        r:SetStatusBarColor(c.r * ns.mute, c.g * ns.mute, c.b * ns.mute, 0.85)
    else
        r:SetStatusBarColor(DIM[1] * ns.mute, DIM[2] * ns.mute, DIM[3] * ns.mute, 0.85)
    end
    local spec, class = src.specIconID, src.classFilename
    if spec and spec ~= 0 then
        r.icon:SetTexture(spec)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif class and class ~= "" and GetClassAtlas then
        r.icon:SetAtlas(GetClassAtlas(class))
    else
        r.icon:SetColorTexture(0.071, 0.067, 0.063, 1)
    end
    r:SetValue(src.totalAmount)
    r.label:SetText(src.name)
    r.amount:SetText(Short(rate and src.amountPerSecond or src.totalAmount))
    r:Show()
end

-- ------------------------------------------------------------- the lists
local function Step(list, by)
    local key = ns.db[list.option]
    local i = ((ORDER[key] or 1) - 1 + by) % #ns.METER_METRICS + 1
    ns.SetOption(list.option, ns.METER_METRICS[i][1])
end

local function List(option)
    local list = { option = option, rows = {} }
    local f = CreateFrame("Frame", nil, body)
    list.frame = f
    local head = CreateFrame("Button", nil, f)
    head:SetHeight(HEAD)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    head:SetScript("OnClick", function(_, mouse) Step(list, mouse == "RightButton" and -1 or 1) end)
    head:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(Metric(list).name)
        GameTooltip:AddLine("Click for the next thing to show; right click for the one before.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    list.head = head
    list.title = ns.Text(head, 11)
    list.title:SetPoint("LEFT", 2, 1)
    list.title:SetTextColor(unpack(GOLD))
    list.when = ns.PlainText(head, 10)
    list.when:SetPoint("RIGHT", -2, 1)
    list.when:SetTextColor(unpack(DIM))
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", 0, 2)
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
    local two = ns.db.meterColumns == 2
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

local function When(list)
    local label = Session() == S.OVERALL and "Overall" or "Current"
    local d = DM.GetSessionDurationSeconds and DM.GetSessionDurationSeconds(Session())
    if not ns.IsSecret(d) and d ~= nil and d > 0 then label = label .. "  " .. Clock(d) end
    list.when:SetText(label)
end

local function Title(list)
    local m = Metric(list)
    local _, rate = Asked(m)
    if lists.count == 2 then
        list.title:SetText(rate and m.rateShort or m.short or m.name)
    else
        list.title:SetText(rate and m.rateName or m.name)
    end
end

-- The list's sources, or why there are none.
local function Read(list)
    local ok, reason = true, nil
    if DM.IsDamageMeterAvailable then ok, reason = DM.IsDamageMeterAvailable() end
    if not ok then return nil, reason ~= "" and reason or "The meter is not available here." end
    local kind, rate = Asked(Metric(list))
    local session = DM.GetCombatSessionFromType(Session(), kind)
    local sources = session and session.combatSources or {}
    if #sources == 0 then
        return nil, Session() == S.OVERALL and "Nothing yet." or "No fight yet."
    end
    return session, nil, rate
end

local total = 0
local function Draw(list)
    Title(list)
    When(list)
    local session, why, rate = Read(list)
    list.empty:SetText(why or "")
    list.empty:SetShown(why ~= nil)
    local sources = session and session.combatSources or {}
    total = math.max(total, #sources)
    for i, r in ipairs(list.rows) do
        local src = sources[first + i]
        if src then
            r:SetMinMaxValues(0, session.maxAmount)
            Fill(r, src, rate)
        else
            r:Hide()
        end
    end
end

local function Refresh()
    if not body then return end
    dirty, since = false, 0
    total = 0
    for i = 1, lists.count do Draw(lists[i]) end
    if first > 0 and first > total - rows then
        first = math.max(0, total - rows)
        total = 0
        for i = 1, lists.count do Draw(lists[i]) end
    end
    ns.side.Changed()
end

-- --------------------------------------------------------------- the view
local view = {
    key = "meter", label = "Meter", option = "sideMeter",
    Available = function() return DM ~= nil and DM.GetCombatSessionFromType ~= nil end,
}

function view.Build(f)
    body = f
    rows = math.floor((f:GetHeight() - HEAD - 1 + GAP) / (ROW + GAP))
    lists = { List("meterLeft"), List("meterRight") }
    Layout()
    -- the session's numbers change with every hit: draw at most four times
    -- a second, and only while the tab is shown; the clock once a second
    f:SetScript("OnUpdate", function(_, elapsed)
        since, tick = since + elapsed, tick + elapsed
        if dirty and since >= 0.25 then
            Refresh()
        elseif tick >= 1 then
            for i = 1, lists.count do When(lists[i]) end
        end
        if tick >= 1 then tick = 0 end
    end)
    -- (a reset empties the lists, and the redraw brings the scroll back to the top)
    local function Dirty() dirty = true end
    for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
        "DAMAGE_METER_RESET", "PLAYER_REGEN_ENABLED" }) do ns.On(e, Dirty) end
    for _, key in ipairs({ "meterLeft", "meterRight", "meterSession", "meterRate" }) do
        ns.OnSetting(key, Refresh)
    end
    ns.OnSetting("meterColumns", function()
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
        glyph = function() return Session() == S.OVERALL and "side-overall" or "side-current" end,
        lit = function() return true end,
        click = function() ns.SetOption("meterSession", Session() == S.OVERALL and S.CURRENT or S.OVERALL) end,
        tip = function()
            if Session() == S.OVERALL then
                return "Overall", "Every fight since the last reset. Click for the current fight."
            end
            return "Current fight", "The fight you are in, or the last one. Click for every fight since the last reset."
        end,
    },
    {
        glyph = function() return "side-rate" end,
        lit = function() return ns.db.meterRate end,
        click = function() ns.SetOption("meterRate", not ns.db.meterRate) end,
        tip = function()
            return "Per second", ns.db.meterRate and "Damage and healing per second. Click for totals."
                or "Damage and healing as totals. Click for per second."
        end,
    },
    {
        glyph = function() return ns.db.meterColumns == 2 and "side-two" or "side-one" end,
        lit = function() return ns.db.meterColumns == 2 end,
        click = function() ns.SetOption("meterColumns", ns.db.meterColumns == 2 and 1 or 2) end,
        tip = function()
            return ns.db.meterColumns == 2 and "Two lists" or "One list",
                "Click for " .. (ns.db.meterColumns == 2 and "one list." or "two lists side by side.")
        end,
    },
}
view.foot = {
    glyph = function() return "side-reset" end,
    lit = function() return false end,
    click = function()
        if DM.ResetAllCombatSessions then DM.ResetAllCombatSessions() end
    end,
    tip = function() return "Reset", "Clear every fight from the meter." end,
}

ns.SideView(view)
