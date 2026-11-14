-- The side panel's Auras tab: the player's buffs and debuffs, each with the
-- time it has left, the longest first, in two lists side by side (Buffs |
-- Debuffs).
--
-- A row: the icon (edged in the debuff's dispel colour, or gold for a buff)
-- with its stack count, the name, a bar of the time left against the full
-- duration (gold for a buff, red for a debuff), and the time left (a
-- debuff's red in its last seconds).
--
-- In combat the client refuses this addon every aura read (measured
-- 2026-11-13), so each list is Blizzard's aura container
-- (CustomAuraContainerTemplate, Blizzard_AuraContainer): the client reads
-- the auras, sorts them, and fills the rows this file draws once, through
-- the row's own setters (its icon, name, count, bar, time, dispel edge).
-- Nothing here touches a row after it is made, or reads one: its every
-- state is secret to this addon, whether it is shown included.
--   * the order is the client's: by when the aura runs out, the latest
--     first, and the auras that never run out above them all;
--   * the auras that never run out are left out by default (the column
--     above the portrait, buffs.lua, shows them); the infinity button lists
--     them, at the top;
--   * a right click on a buff cancels it, where the client allows; the
--     tooltip is the client's.
--
-- Each list scrolls: its container sits on a canvas of this addon's in a
-- scroll frame, both lists by the same rows. How many rows a list holds is
-- counted from the auras out of combat, where they can be read; in combat
-- the last count stands and the wheel goes as far as a list can hold.
local _, ns = ...

local LIVE = "CustomAuraContainerTemplate"
local ROW, GAP, HEAD = 16, 2, 18
local SPLIT = 3                 -- each list stands this far from the panel's middle
local MAX = 40                  -- the most rows a list holds
local URGENT = 10               -- a debuff's time turns red under this many seconds
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
local RED = { 1, 0.502, 0.439 }
local BUFF_BAR = { 0.541, 0.439, 0.204 }
local DEBUFF_BAR = { 0.541, 0.227, 0.188 }
local DISPEL = {
    Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Poison = { 0, 0.6, 0 }, Disease = { 0.6, 0.4, 0 },
    None = { 0.753, 0.188, 0.188 },
}
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

-- The two lists, buffs then debuffs: the filter, the heading, the empty line.
local LISTS = {
    { key = "buffs", filter = "HELPFUL", title = "Buffs", empty = "No buffs." },
    { key = "debuffs", filter = "HARMFUL", title = "Debuffs", empty = "No debuffs.", debuff = true },
}

local body, lists, rows
local first, total = 0, 0
local dirty, since = true, 0

-- ------------------------------------------------------------- the rows
local function Color(c) return CreateColor and CreateColor(c[1], c[2], c[3], 1) end

-- A debuff's time: red under URGENT seconds, the text's colour from there.
local urgent
local function Urgent()
    if urgent == nil then
        urgent = false
        local Curve, Step = C_CurveUtil and C_CurveUtil.CreateColorCurve, Enum and Enum.LuaCurveType
        if Curve and Step then
            local ok, curve = pcall(Curve)
            if ok and curve and pcall(function()
                curve:SetType(Step.Step)
                curve:AddPoint(0, Color(RED))
                curve:AddPoint(URGENT, Color(ns.colors.text))
            end) then
                urgent = curve
            end
        end
    end
    return urgent or nil
end

-- A row, as the client asks for one: a bar the row's width, the icon in a
-- square at its left edged gold (a buff) or in the dispel colour (a debuff),
-- the stacks on it, the name, the time on the right. Each part handed to
-- the row's setter; one the client lacks leaves only that part out.
local function InitRow(list)
    local debuff = list.debuff
    return function(btn)
        btn:SetSize(list.width, ROW)
        local bar = CreateFrame("StatusBar", nil, btn)
        bar:SetAllPoints()
        bar:SetStatusBarTexture(WHITE8)
        local c = debuff and DEBUFF_BAR or BUFF_BAR
        bar:SetStatusBarColor(c[1], c[2], c[3], 0.75)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.35)
        local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        sheen:SetColorTexture(1, 1, 1, 0.07)
        sheen:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "RIGHT")
        local edge = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        edge:SetSize(ROW, ROW)
        edge:SetPoint("LEFT")
        local icon = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        icon:SetSize(ROW - 2, ROW - 2)
        icon:SetPoint("CENTER", edge)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local count = ns.PlainText(bar, 9)
        count:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
        count:SetTextColor(1, 1, 1)
        local left = ns.PlainText(bar, 10)
        left:SetPoint("RIGHT", -3, 0)
        left:SetTextColor(unpack(ns.colors.text))
        local label = ns.Text(bar, 10)
        label:SetPoint("LEFT", ROW + 5, 0)
        label:SetPoint("RIGHT", bar, "RIGHT", -46, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        pcall(btn.SetIcon, btn, icon)
        pcall(btn.SetApplicationCount, btn, count)
        pcall(btn.SetSpellName, btn, label)
        local TIMER = Enum and Enum.StatusBarTimerDirection
        pcall(btn.SetDurationBar, btn, bar, { direction = TIMER and TIMER.RemainingTime })
        local PROPERTY = Enum and Enum.DurationTextBindingProperty
        local curve = debuff and PROPERTY and Urgent()
        pcall(btn.SetDurationText, btn, left,
            curve and { textColor = { curve = curve, property = PROPERTY.RemainingDuration } } or nil)
        local STYLE = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
        if debuff then
            edge:SetColorTexture(1, 1, 1, 1)
            local colours = {}
            for k, v in pairs(DISPEL) do colours[k] = Color(v) end
            pcall(btn.AddDispelTypeTexture, btn, edge, { style = STYLE and STYLE.PreserveAsset,
                showWhenHarmful = true, showWithoutDispelType = true, customDispelColorMap = colours })
        else
            edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            pcall(btn.SetCancelAuraButtons, btn, "RightButtonUp")
        end
        pcall(btn.SetTooltipAnchorPoint, btn, "ANCHOR_LEFT")
    end
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

-- The never-run-out auras: left out unless listed (any longest duration
-- leaves out the auras with none).
local function Timeless()
    return not ns.db.aurasTimeless and { maxDuration = math.huge } or nil
end

-- A list: the heading, and under it a scroll frame over a canvas holding the
-- container (hung from the canvas, which is this addon's: nothing of this
-- addon may hang from the container). false where the client has none.
local function List(spec, i)
    local list = { key = spec.key, filter = spec.filter, debuff = spec.debuff, count = 0 }
    local w = body:GetWidth() / 2 - SPLIT
    list.width = w
    local f = CreateFrame("Frame", nil, body)
    f:SetWidth(w)
    if i == 1 then
        f:SetPoint("TOPLEFT", body, "TOPLEFT")
        f:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT")
    else
        f:SetPoint("TOPRIGHT", body, "TOPRIGHT")
        f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
    end
    list.frame = f
    list.title, list.number = Header(f)
    list.title:SetText(spec.title)
    list.empty = ns.Text(f, 10)
    list.empty:SetPoint("TOPLEFT", 4, -(HEAD + 6))
    list.empty:SetPoint("RIGHT", -4, 0)
    list.empty:SetJustifyH("LEFT")
    list.empty:SetTextColor(unpack(DIM))
    list.empty:SetText(spec.empty)
    list.empty:Hide()
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 0, -(HEAD + 1))
    scroll:SetPoint("BOTTOMRIGHT")
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetSize(w, MAX * (ROW + GAP))
    scroll:SetScrollChild(canvas)
    ns.side.PassWheel(scroll)
    list.scroll = scroll
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, canvas, LIVE)
    if not ok or not c then return false end
    c:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    local Axis, Way = AnchorUtil and AnchorUtil.FlowLayoutAxis, AnchorUtil and AnchorUtil.FlowDirection
    if Axis and Way then
        c:SetFlowLayoutAxis(Axis.Vertical)
        c:SetFlowLayoutGrowthDirection(Way.Right, Way.Down)
    end
    c:SetFlowLayoutAnchorPoint("TOPLEFT")
    c:SetFlowLayoutMaximumLineSize(MAX * (ROW + GAP))
    local Sort, Direction = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
    local made = pcall(c.AddAuraGroup, c, spec.key, spec.filter, {
        maxFrameCount = MAX,
        initializeFrame = InitRow(list),
        candidateFilters = Timeless(),
        sortMethod = Sort and Sort.ExpirationOnly,
        sortDirection = Direction and Direction.Reverse,
        layout = { elementSpacing = GAP, lineSpacing = 0, elementWidth = w, elementHeight = ROW },
    })
    if not made then return false end
    c:SetUnit("player")
    list.live = c
    return list
end

-- How many rows a list shows: its auras, read here out of combat (the
-- container's frames answer nothing, not even whether they are shown: a
-- secret, measured 2026-11-14), less the timeless where they are left out;
-- nil in combat, where the client refuses the read.
local function Count(list)
    if InCombatLockdown() or not ns.ListAuras then return nil end
    local all = ns.db.aurasTimeless
    local ok, n = pcall(function()
        local got = 0
        for _, a in ipairs(ns.ListAuras("player", list.filter)) do
            if all or a.duration ~= 0 then got = got + 1 end
        end
        return got
    end)
    if not ok or ns.IsSecret(n) then return nil end
    return math.min(n, MAX)
end

-- Both lists scrolled to the same row.
local function Place()
    for _, list in ipairs(lists) do list.scroll:SetVerticalScroll(first * (ROW + GAP)) end
end

-- The counts read again where they can be; the scroll kept in what they hold.
local function Refresh()
    if not lists then return end
    dirty, since = false, 0
    local fighting = InCombatLockdown()
    total = 0
    for _, list in ipairs(lists) do
        local n = Count(list)
        if n then list.count = n end
        list.number:SetText(list.count)
        list.empty:SetShown(not fighting and list.count == 0)
        total = math.max(total, list.count)
    end
    if not fighting then first = math.max(0, math.min(first, total - rows)) end
    Place()
    ns.side.Changed()
end

-- --------------------------------------------------------------- the view
local view = {
    key = "auras", label = "Auras", option = "sideAuras",
    -- (where the client can make an aura container: one made to find out,
    -- once, as the panel is built)
    Available = function()
        local ok, c = pcall(CreateFrame, "AuraContainer", nil, nil, LIVE)
        if ok and c then c:Hide() end
        return ok and c ~= nil
    end,
}

function view.Build(f)
    body = f
    rows = math.floor((f:GetHeight() - HEAD - 1 + GAP) / (ROW + GAP))
    local made = {}
    for i, spec in ipairs(LISTS) do
        local list = List(spec, i)
        if not list then return end
        made[i] = list
    end
    lists = made
    -- the counts change in bursts: read them at most four times a second,
    -- and only while the tab is shown
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if dirty and since >= 0.25 then Refresh() end
    end)
    local events = CreateFrame("Frame")
    ns.RegisterUnitEvent(events, "UNIT_AURA", "player")
    events:SetScript("OnEvent", function() dirty = true end)
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        ns.On(e, function() dirty = true end)
    end
    ns.OnSetting("aurasTimeless", function()
        for _, list in ipairs(lists) do
            pcall(list.live.SetAuraGroupCandidateFilters, list.live, list.key, Timeless())
        end
        Refresh()
    end)
    Refresh()
end

view.Refresh = Refresh

-- In combat the count is the last one read, so the wheel may go on as far
-- as a list can hold.
function view.Scroll(by)
    if not lists then return end
    local most = InCombatLockdown() and math.max(total, MAX) or total
    first = math.max(0, math.min(first + by, most - rows))
    Place()
end

function view.Thumb()
    return first, rows or 0, math.max(total, first + (rows or 0))
end

view.buttons = {
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
