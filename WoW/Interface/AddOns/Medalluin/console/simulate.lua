-- The simulation panel: while "Simulate party frames" is on, a small panel
-- on the left of the screen sets the simulated frames' situation, a tab per
-- set of frames (art/widgets/gen_sim_panel.py, draft A):
--
--   Party     Members - n +; a column per member: Health (click cycles
--             100/60/25%), Dead, Offline, Out of range, Pet; Auras;
--             Ready check, Role check
--   Raid      Groups - n +; Hurt, Dead, Offline, Out of range; Auras
--   Enemies   Bosses - n +, Arena - n +; Hurt, Dead; Auras
--   Overhead  Pet, Focus, Target of target; Hurt
--   [End simulation]
--
-- A set's state or aura that is on shows on at least one of its frames
-- (ns.SimHas, core.lua); the party's members are set one by one. It changes
-- only the stubs and ns.sim, and redraws through the frames' own updates; a
-- real unit is never touched. Nothing here is saved: a reload starts from the
-- defaults. The player and target are not simulated. Drag it by any free spot.
local _, ns = ...

local MEMBERS = { "party1", "party2", "party3", "party4" }
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local ROW, PAD, W = 22, 12, 248
local IW = W - PAD * 2      -- a page's width, inside the margin
-- the party grid, right-aligned to the page: a column's width and step, its first column
local CW, COL = 30, 34
local COL0 = IW - (CW + COL * 3)
local STEP = 0.6            -- seconds between members' answers
local HOLD = 3              -- seconds the answers stay up, as for a real check
-- each member's answer to a ready check, in turn
local ANSWERS = { party1 = "ready", party2 = "ready", party3 = "notready", party4 = "ready" }
local HEALTH = { 100, 60, 25 }  -- a member's health, click by click
local TABS = { { "party", "Party" }, { "raid", "Raid" }, { "enemies", "Enemies" }, { "overhead", "Overhead" } }

local panel
local tab = "party"
local pages = {}
local buttons = {}          -- every button, repainted together
ns.simButtons = buttons     -- by id, for the harness
local check                 -- the check under way: { kind, t, order, answered }

-- ------------------------------------------------------------- the checks
-- The simulated members (a real member has no stub, and answers for itself).
local function Simulated()
    local out = {}
    for _, u in ipairs(MEMBERS) do
        local b = ns.units and ns.units[u]
        if b and b.stub then table.insert(out, b) end
    end
    return out
end

local function EndCheck()
    if not check then return end
    for _, b in ipairs(check.members) do ns.SetCheckStatus(b, nil) end
    check = nil
end

local function StartCheck(kind)
    EndCheck()
    check = { kind = kind, t = 0, members = Simulated(), answered = 0 }
    for _, b in ipairs(check.members) do ns.SetCheckStatus(b, "waiting") end
end

-- One member answers every STEP seconds; HOLD seconds after the last, all clear.
local function Advance(elapsed)
    if not check then return end
    check.t = check.t + elapsed
    local due = math.min(#check.members, math.floor(check.t / STEP))
    while check.answered < due do
        check.answered = check.answered + 1
        local b = check.members[check.answered]
        ns.SetCheckStatus(b, check.kind == "ready" and ANSWERS[b.unit] or "ready")
    end
    if check.t >= #check.members * STEP + HOLD then EndCheck() end
end

-- -------------------------------------------------------------- the panel
local function Paint()
    for _, b in ipairs(buttons) do
        local lit = b.lit and b.lit() or false
        b.on:SetShown(lit)
        b.label:SetTextColor(unpack(lit and GOLD or ns.colors.text))
        local enabled = not b.enabled or b.enabled()
        b:SetEnabled(enabled)
        b:SetAlpha(enabled and 1 or 0.4)
        if b.text then b.label:SetText(b.text()) end
    end
end

-- After a click: the frames from the stubs and the sets.
local function Redraw()
    ns.UpdatePartyFrames()
    ns.UpdateOverhead()
    if ns.UpdateWidgets then ns.UpdateWidgets() end
    if ns.UpdateAllAuras then ns.UpdateAllAuras() end
end

local function Tip(b)
    if not b.tip then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(b.tip(), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

-- A plain button in the console's colours: an inked well with a gold edge,
-- filled gold while lit.
local function Button(parent, x, y, w, spec)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, ROW - 4)
    b:SetPoint("TOPLEFT", x, y)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    b.on = b:CreateTexture(nil, "BORDER")
    b.on:SetPoint("TOPLEFT", 1, -1)
    b.on:SetPoint("BOTTOMRIGHT", -1, 1)
    b.on:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.12)
    b.label = ns.Text(b, 10)
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(spec.label or "")
    b.id, b.lit, b.enabled, b.text, b.tip = spec.id, spec.lit, spec.enabled, spec.text, spec.tip
    b:SetScript("OnClick", function(self)
        spec.click()
        Redraw()
        Paint()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(buttons, b)
    if spec.id then buttons[spec.id] = b end
    return b
end

local function Label(parent, y, text)
    local fs = ns.Text(parent, 10)
    fs:SetPoint("TOPLEFT", 0, y - 3)
    fs:SetText(text)
    fs:SetTextColor(unpack(ns.colors.dim))
    return fs
end

-- A count: label, -, the number (a click for none or all), +.
local function Count(page, y, id, label, min, max, get, set, what)
    Label(page, y, label)
    local function By(n) set(math.max(min, math.min(max, get() + n))) end
    Button(page, COL0, y, 22, { id = id .. ".less", label = "-", click = function() By(-1) end,
        enabled = function() return get() > min end, tip = function() return "One " .. what .. " fewer." end })
    Button(page, COL0 + 26, y, IW - COL0 - 52, { id = id, text = function() return tostring(get()) end,
        click = function() set(get() == min and max or min) end,
        tip = function() return "How many " .. what .. "s. Click for " .. min .. ", or " .. max .. "." end })
    Button(page, IW - 22, y, 22, { id = id .. ".more", label = "+", click = function() By(1) end,
        enabled = function() return get() < max end, tip = function() return "One " .. what .. " more." end })
    return y - ROW
end

-- On/off toggles, two to a row across the page: { key, label, tip, enabled }
-- read from and written to the table t.
local function Toggles(page, y, idp, t, list)
    local half = (IW - 4) / 2
    for k, spec in ipairs(list) do
        local key = spec[1]
        Button(page, (k - 1) % 2 * (half + 4), y - math.floor((k - 1) / 2) * ROW, half, {
            id = idp .. "." .. key, label = spec[2], enabled = spec[4],
            lit = function() return t()[key] == true end,
            click = function() t()[key] = not t()[key] end,
            tip = function() return spec[3] end })
    end
    return y - math.ceil(#list / 2) * ROW
end

-- A set's auras, a button each across the page.
local AURAS = {
    glow = { "Dispel", "A debuff you can dispel: the frame's border glows." },
    cc = { "CC", "Crowd control, in the frame's centre." },
    boss = { "Boss", "A boss's debuff, in the frame's centre." },
    buffs = { "Buffs", "Your heals over time on the frame." },
    mine = { "Your debuffs", "Your damage over time on the enemy." },
}
local function Auras(page, y, set, keys)
    Label(page, y, "Auras")
    y = y - 18
    local w = (IW - (#keys - 1) * 3) / #keys
    for k, key in ipairs(keys) do
        local a = AURAS[key]
        Button(page, (k - 1) * (w + 3), y, w, { id = set .. ".aura." .. key, label = a[1],
            lit = function() return ns.sim[set].auras[key] == true end,
            click = function() ns.sim[set].auras[key] = not ns.sim[set].auras[key] end,
            tip = function() return a[2] .. " On at least one frame while lit." end })
    end
    return y - ROW
end

-- ------------------------------------------------------------- the pages
local function Here(i) return function() return i <= ns.sim.party.count end end

local function PartyPage(page)
    local p = ns.sim.party
    local y = Count(page, 0, "party.count", "Members", 1, 4, function() return p.count end,
        function(n) p.count = n end, "member")
    for i, u in ipairs(MEMBERS) do
        local head = ns.Text(page, 10)
        head:SetPoint("TOP", page, "TOPLEFT", COL0 + (i - 1) * COL + CW / 2, y - 3)
        local c = RAID_CLASS_COLORS[ns.partyStubs[u].class]
        head:SetText("P" .. i)
        if c then head:SetTextColor(c.r, c.g, c.b) end
    end
    y = y - 16
    -- a row of the grid: one button per member
    local function Row(key, label, lit, click, tip, enabled)
        Label(page, y, label)
        for i, u in ipairs(MEMBERS) do
            local here = Here(i)
            Button(page, COL0 + (i - 1) * COL, y, CW, {
                id = "party." .. key .. "." .. i,
                lit = lit and function() return lit(ns.partyStubs[u]) end,
                text = key == "health" and function() return tostring(ns.partyStubs[u].health) end or nil,
                enabled = function() return here() and (not enabled or enabled()) end,
                click = function() click(ns.partyStubs[u]) end,
                tip = function() return tip(ns.partyStubs[u].name, ns.partyStubs[u]) end })
        end
        y = y - ROW
    end
    Row("health", "Health", nil, function(s)
        local next = HEALTH[1]
        for k, h in ipairs(HEALTH) do
            if h == s.health then next = HEALTH[k % #HEALTH + 1] end
        end
        s.health = next
    end, function(name, s) return name .. " is at " .. s.health .. "%. Click for "
        .. (s.health == 100 and 60 or s.health == 60 and 25 or 100) .. "%." end)
    Row("dead", "Dead", function(s) return s.dead == true end, function(s) s.dead = not s.dead end,
        function(name, s) return name .. (s.dead and " is dead. Click to bring them back." or
            " is alive. Click to kill them.") end)
    Row("offline", "Offline", function(s) return s.offline == true end, function(s) s.offline = not s.offline end,
        function(name, s) return name .. (s.offline and " is offline. Click to bring them back." or
            " is online. Click to disconnect them.") end)
    Row("away", "Out of range", function(s) return s.inRange == false end,
        function(s) s.inRange = s.inRange == false end,
        function(name, s) return name .. (s.inRange == false and " is out of range. Click to bring them near."
            or " is in range. Click to move them away.") end,
        function() return ns.PartyOption("partyRange") ~= 0 end)
    Row("pet", "Pet", function(s) return s.pet == true end, function(s) s.pet = not s.pet end,
        function(name, s) return name .. (s.pet and " has a pet. Click to dismiss it." or
            " has no pet. Click to summon one.") end,
        function() return ns.PartyOption("partyPets") ~= false end)
    y = Auras(page, y - 4, "party", { "glow", "cc", "boss", "buffs" })
    local half = (IW - 4) / 2
    Button(page, 0, y - 4, half, { id = "party.ready", label = "Ready check",
        lit = function() return check ~= nil and check.kind == "ready" end,
        click = function() StartCheck("ready") end,
        tip = function() return "The members answer in turn: ready, ready, not ready, ready." end })
    Button(page, half + 4, y - 4, half, { id = "party.role", label = "Role check",
        lit = function() return check ~= nil and check.kind == "role" end,
        click = function() StartCheck("role") end,
        tip = function() return "The members confirm their roles in turn." end })
    return y - 4 - ROW
end

local function RaidPage(page)
    local r = ns.sim.raid
    local y = Count(page, 0, "raid.groups", "Groups", 1, 8, function() return r.groups end,
        function(n) r.groups = n end, "group")
    y = Toggles(page, y - 4, "raid", function() return r end, {
        { "hurt", "Hurt", "Members below full health." },
        { "dead", "Dead", "At least one member is dead." },
        { "offline", "Offline", "At least one member is offline." },
        { "away", "Out of range", "At least one member is out of range.",
            function() return ns.RaidRange() ~= 0 end },
    })
    return Auras(page, y - 4, "raid", { "glow", "cc", "boss" })
end

local function EnemiesPage(page)
    local e = ns.sim.enemies
    local y = Count(page, 0, "enemies.bosses", "Bosses", 0, 5, function() return e.bosses end,
        function(n) e.bosses = n end, "boss")
    y = Count(page, y, "enemies.arena", "Arena", 0, 5, function() return e.arena end,
        function(n) e.arena = n end, "arena enemy")
    y = Toggles(page, y - 4, "enemies", function() return e end, {
        { "hurt", "Hurt", "Bosses and arena enemies below full health." },
        { "dead", "Dead", "At least one boss and arena enemy is dead." },
    })
    return Auras(page, y - 4, "enemies", { "cc", "mine" })
end

local function OverheadPage(page)
    local o = ns.sim.overhead
    return Toggles(page, 0, "overhead", function() return o end, {
        { "pet", "Pet", "Your pet's frame, over the console." },
        { "focus", "Focus", "Your focus's frame." },
        { "targettarget", "Target of target", "Your target's target's frame." },
        { "hurt", "Hurt", "These frames below full health." },
    })
end

local BUILD = { party = PartyPage, raid = RaidPage, enemies = EnemiesPage, overhead = OverheadPage }
local TOP = PAD + 16 + 4 + ROW + 6     -- the title and the tabs
local foot

-- The tab shown, and the panel to its height.
local function Show(id)
    tab = id
    for k, page in pairs(pages) do page:SetShown(k == id) end
    local h = pages[id].height
    foot:ClearAllPoints()
    foot:SetPoint("TOPLEFT", PAD, -(TOP + h + 6))
    panel:SetHeight(TOP + h + 6 + ROW + PAD - 4)
end

local function Build()
    panel = CreateFrame("Frame", "MedalluinSimPanel", UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetWidth(W)
    panel:SetPoint("LEFT", UIParent, "LEFT", 16, 120)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local edge = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.92)
    local title = ns.Text(panel, 11)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Simulated frames")
    title:SetTextColor(unpack(GOLD))

    local tw = (IW - 2 * (#TABS - 1)) / #TABS
    for k, t in ipairs(TABS) do
        Button(panel, PAD + (k - 1) * (tw + 2), -(PAD + 16 + 4), tw, { id = "tab." .. t[1], label = t[2],
            lit = function() return tab == t[1] end, click = function() Show(t[1]) end,
            tip = function() return "The simulated " .. t[2]:lower() .. " frames." end })
    end
    for _, t in ipairs(TABS) do
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", PAD, -TOP)
        page:SetSize(IW, 1)
        page.height = -BUILD[t[1]](page)
        pages[t[1]] = page
    end

    foot = Button(panel, PAD, 0, IW, { id = "end", label = "End simulation",
        click = function() ns.SetOption("simParty", false) end,
        tip = function() return "Turn off Simulate party frames." end })
    Show(tab)

    panel:SetScript("OnUpdate", function(_, elapsed)
        if check then
            Advance(elapsed)
            if not check then Paint() end
        end
    end)
end

local function Shown()
    local on = ns.db and ns.db.simParty
    if on and not panel then Build() end
    if not panel then return end
    if not on then EndCheck() end
    panel:SetShown(on and true or false)
    Paint()
end

ns.On("PLAYER_LOGIN", Shown)
ns.OnSetting("simParty", Shown)
for _, key in ipairs({ "partyRange", "partyWidgetRange", "partyLayout", "partyPets", "partyWidgetPets",
    "raidRange", "bgRange" }) do
    ns.OnSetting(key, function() if panel then Paint() end end)
end
-- a real fight clears a check, as a real check is cleared
ns.On("PLAYER_REGEN_DISABLED", function()
    EndCheck()
    if panel then Paint() end
end)
