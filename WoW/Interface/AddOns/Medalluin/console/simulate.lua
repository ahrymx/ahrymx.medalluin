-- The simulation panel: while "Simulate party frames" is on, a small panel
-- on the left of the screen changes the simulated situation.
--
--   Bosses    - n +           how many simulated boss cells (0 to 5)
--   Dead      1 2 3 4         a lit member is dead
--   In range  1 2 3 4         a lit member is in range (needs the range fade)
--   [Ready check] [Role check]  the members answer one by one, then it clears
--   [End simulation]
--
-- It changes only the stubs (ns.partyStubs, ns.sim) and redraws through the
-- frames' own updates; a real group member is never touched. Nothing here is
-- saved: a reload starts from the stubs' defaults. Drag it by any free spot.
local _, ns = ...

local MEMBERS = { "party1", "party2", "party3", "party4" }
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local ROW, PAD, W = 22, 8, 196
local STEP = 0.6            -- seconds between members' answers
local HOLD = 3              -- seconds the answers stay up, as for a real check
-- each member's answer to a ready check, in turn
local ANSWERS = { party1 = "ready", party2 = "ready", party3 = "notready", party4 = "ready" }

local panel
local buttons = {}          -- every button, repainted together
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

-- After a click: the frames from the stubs.
local function Redraw()
    ns.UpdatePartyFrames()
    ns.UpdateOverhead()
    if ns.UpdateWidgets then ns.UpdateWidgets() end
end

local function Tip(b)
    if not b.tip then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(b.tip(), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

-- A plain button in the console's colours: an inked well with a gold edge,
-- filled gold while lit.
local function Button(x, y, w, spec)
    local b = CreateFrame("Button", nil, panel)
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
    b.lit, b.enabled, b.text, b.tip = spec.lit, spec.enabled, spec.text, spec.tip
    b:SetScript("OnClick", function(self)
        spec.click()
        Redraw()
        Paint()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(buttons, b)
    return b
end

local function Label(y, text)
    local fs = ns.Text(panel, 10)
    fs:SetPoint("TOPLEFT", PAD, y - 3)
    fs:SetText(text)
    fs:SetTextColor(unpack(ns.colors.dim))
    return fs
end

local function Name(u)
    local stub = ns.partyStubs[u]
    return stub and stub.name or u
end

-- A row of four member toggles after a label.
local function Members(y, label, lit, flip, tip, enabled)
    Label(y, label)
    for i, u in ipairs(MEMBERS) do
        Button(84 + (i - 1) * 26, y, 22, {
            label = tostring(i),
            lit = function() return lit(ns.partyStubs[u]) end,
            enabled = enabled,
            click = function() flip(ns.partyStubs[u]) end,
            tip = function() return tip(Name(u), lit(ns.partyStubs[u])) end,
        })
    end
end

local function Build()
    panel = CreateFrame("Frame", "MedalluinSimPanel", UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetSize(W, PAD * 2 + 16 + ROW * 5 + 4)
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

    local y = -(PAD + 16 + 4)
    Label(y, "Bosses")
    local function Bosses(by) ns.sim.bosses = math.max(0, math.min(5, ns.sim.bosses + by)) end
    Button(84, y, 22, { label = "-", click = function() Bosses(-1) end,
        enabled = function() return ns.sim.bosses > 0 end, tip = function() return "One boss fewer." end })
    Button(110, y, 48, { text = function() return tostring(ns.sim.bosses) end,
        click = function() ns.sim.bosses = ns.sim.bosses == 0 and 5 or 0 end,
        tip = function() return "Simulated bosses over the screen. Click for none, or all five." end })
    Button(162, y, 22, { label = "+", click = function() Bosses(1) end,
        enabled = function() return ns.sim.bosses < 5 end, tip = function() return "One boss more." end })

    y = y - ROW
    Members(y, "Dead", function(s) return s.dead == true end,
        function(s) s.dead = not s.dead end,
        function(name, dead)
            return name .. (dead and " is dead. Click to bring them back." or " is alive. Click to kill them.")
        end)

    y = y - ROW
    Members(y, "In range", function(s) return s.inRange ~= false end,
        function(s) s.inRange = s.inRange == false end,
        function(name, near) return name .. (near and " is in range. Click to move them away."
            or " is out of range. Click to bring them near.") end,
        function() return ns.PartyOption("partyRange") ~= 0 end)

    y = y - ROW
    Button(PAD, y, (W - PAD * 2 - 4) / 2, { label = "Ready check",
        lit = function() return check ~= nil and check.kind == "ready" end,
        click = function() StartCheck("ready") end,
        tip = function() return "The members answer in turn: ready, ready, not ready, ready." end })
    Button(PAD + (W - PAD * 2 - 4) / 2 + 4, y, (W - PAD * 2 - 4) / 2, { label = "Role check",
        lit = function() return check ~= nil and check.kind == "role" end,
        click = function() StartCheck("role") end,
        tip = function() return "The members confirm their roles in turn." end })

    y = y - ROW
    Button(PAD, y, W - PAD * 2, { label = "End simulation",
        click = function() ns.SetOption("simParty", false) end,
        tip = function() return "Turn off Simulate party frames." end })

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
for _, key in ipairs({ "partyRange", "partyWidgetRange", "partyLayout" }) do
    ns.OnSetting(key, function() if panel then Paint() end end)
end
-- a real fight clears a check, as a real check is cleared
ns.On("PLAYER_REGEN_DISABLED", function()
    EndCheck()
    if panel then Paint() end
end)
