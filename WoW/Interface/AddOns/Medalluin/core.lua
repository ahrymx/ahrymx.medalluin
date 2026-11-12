-- Medalluin core: namespace, media, palette, events and the hidden parent.
local _, ns = ...

ns.media = "Interface\\AddOns\\Medalluin\\media\\"
ns.font = ns.media .. "fonts\\MarcellusSC-Regular.ttf"
ns.bar = ns.media .. "bar"

-- Sampled from the H mockup so code-drawn fills sit in the art's palette.
ns.colors = {
    ink = { 0.071, 0.067, 0.063 },      -- #121110, an empty window
    text = { 0.949, 0.918, 0.824 },     -- #f2ead2
    dim = { 0.70, 0.66, 0.55 },
    xp = { 0.847, 0.722, 0.416 },       -- #d8b86a
    rested = { 0.541, 0.439, 0.204 },   -- #8a7034
    rep = { 0.643, 0.545, 0.310 },      -- #a48b4f
    dead = { 0.35, 0.35, 0.35 },
    white = { 1, 1, 1 },
    grey = { 0.7, 0.7, 0.7 },
}
-- Blizzard's class and reaction colours are brighter than the art; mute them.
ns.mute = 0.8

-- One event frame for the whole addon: ns.On("EVENT", fn).
local handlers, events = {}, CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)
-- An event this client does not have (Forever lacks ROLE_POLL_UPDATE and
-- QUEUE_STATUS_UPDATE) is skipped: RegisterEvent raises, and the raise would
-- end the calling file's main chunk, losing everything after it.
function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(events.RegisterEvent, events, event) then return end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
end

-- Work that touches protected frames waits for combat to end.
local queued = {}
function ns.OutOfCombat(fn)
    if InCombatLockdown() then
        table.insert(queued, fn)
    else
        fn()
    end
end
ns.On("PLAYER_REGEN_ENABLED", function()
    for i = 1, #queued do queued[i]() end
    wipe(queued)
end)

-- A state driver whose states reach the frame only from the game's secure
-- update, never from Medalluin's own code. RegisterStateDriver applies the
-- conditional's state at once, inside the caller, and an addon's execution
-- is tainted: a snippet run then, setting "actionpage" on Blizzard's action
-- buttons, runs their OnAttributeChanged tainted, and what that writes on
-- the button taints every click after it ("Medalluin has been blocked",
-- UseAction; BugSack, 2026-11-01). So the frame holds while the driver is
-- registered (its snippet sees ns.HOLD and returns), and its state is left
-- at "hold", which no conditional gives: SecureStateDriverManager's next
-- update (within 0.2 s) sets the real state, securely, and the snippet runs
-- then. No conditional is the state nil, set the same way.
ns.HOLD = "medalluin-hold"
function ns.DriveState(frame, state, conditional)
    frame:SetAttribute(ns.HOLD, true)
    RegisterStateDriver(frame, state, conditional or "nil")
    frame:SetAttribute("state-" .. state, "hold")
    frame:SetAttribute(ns.HOLD, nil)
end

-- Blizzard frames are parented here and unregistered, never just hidden,
-- so their own code cannot show them again and taint stays contained.
ns.hidden = CreateFrame("Frame")
ns.hidden:Hide()
-- Some come back: retail-family clients reparent MainActionBar to UIParent
-- when a vehicle or pet battle lets go of it. Such a frame goes back to the
-- hidden parent as soon as combat allows.
local killed = {}
-- Park is Kill without the unregistering: the frame is out of sight, but its
-- own events still run. The stance and pet bars are parked, because their
-- events are what give the buttons the overhead adopts their icons.
-- Parked under the veil (under) instead, a frame stays visible to its own
-- code: Blizzard_TrainerUI shows its frame and closes the trainer at once
-- when it is not IsVisible, which a frame under the hidden parent never is.
-- The veil is shown but see-through, and shrunk to a speck, so nothing on
-- it draws or takes a click.
ns.veil = CreateFrame("Frame", nil, UIParent)
ns.veil:SetAlpha(0)
ns.veil:SetScale(0.01)
function ns.Park(frame, under)
    if not frame then return end
    under = under or ns.hidden
    frame:SetParent(under)
    if killed[frame] then return end
    killed[frame] = true
    hooksecurefunc(frame, "SetParent", function(self, parent)
        if parent ~= under then
            ns.OutOfCombat(function() self:SetParent(under) end)
        end
    end)
end
function ns.Kill(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    ns.Park(frame)
end

-- Register a unit event if this client knows it; Classic-era clients have
-- renamed several (UNIT_HEALTH_FREQUENT, for one) between builds.
function ns.RegisterUnitEvent(frame, event, unit)
    return pcall(frame.RegisterUnitEvent, frame, event, unit)
end

-- ---------------------------------------------------------------- clients
-- One addon for Forever (1.60, a Mainline-family client: Edit Mode bars,
-- MicroMenu, duration objects, secret values) and retail (12.x), with the
-- older Classic-era names kept as fallbacks. Code asks for an API or frame
-- by name and never branches on a version number.

-- Secret values (combat-restricted numbers) can be shown by status bars and
-- font strings, but any arithmetic or comparison on one raises an error.
-- The simulated frames' situation, set by the simulation panel (simulate.lua);
-- for this session only. A set's state or aura that is on shows on at least
-- one of its frames (ns.SimHas); the party's members are set one by one, on
-- their stubs (console/units.lua).
ns.sim = {
    party = { count = 4, auras = { glow = true, cc = true, buffs = true, boss = true, mine = true } },
    raid = { groups = 2, hurt = true, auras = { glow = true, cc = true, boss = true, mine = true } },
    enemies = { bosses = 2, arena = 3, hurt = true, auras = { cc = true, mine = true } },
    overhead = { pet = true, focus = true, targettarget = true, hurt = true },
}

-- Where in a set a state or aura first falls, so that two of them fall on
-- different frames while there are frames enough.
-- (CC and the boss debuff share the centre: they meet only in a set of one.)
local FIRST = { away = 2, dead = 3, offline = 4, glow = 1, cc = 2, buffs = 3, boss = 4, mine = 1 }

-- Whether frame i of the n a set shows has state (or aura) key: the first
-- it falls on, and every eighth after it in a big set.
function ns.SimHas(set, key, i, n)
    local s = ns.sim[set]
    local on = s[key]
    if on == nil and s.auras then on = s.auras[key] end
    if not on or n < 1 or i > n then return false end
    local function First(k) return (FIRST[k] - 1) % n + 1 end
    local first = First(key)
    -- the boss debuff steps past CC's frame, the centre they share
    if key == "boss" and n > 1 and first == First("cc") then first = first % n + 1 end
    return i == first or i > first and (i - first) % 8 == 0
end

-- A set's states on frame i of n's stub: its health (whole unless the set
-- is hurt), dead, offline, out of range.
function ns.SimApply(stub, set, i, n)
    stub.hurtHealth = stub.hurtHealth or stub.health
    stub.health = ns.sim[set].hurt and stub.hurtHealth or stub.maxHealth
    stub.dead = ns.SimHas(set, "dead", i, n) or nil
    stub.offline = ns.SimHas(set, "offline", i, n) or nil
    stub.inRange = not ns.SimHas(set, "away", i, n)
end

function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- v, or fallback when v is nil. A secret is never nil, and is passed on
-- untested: "v or fallback" would test it.
function ns.Or(v, fallback)
    if ns.IsSecret(v) then return v end
    if v == nil then return fallback end
    return v
end

-- Whether v is there at all, without testing a secret.
function ns.Present(v)
    return ns.IsSecret(v) or v ~= nil
end

-- The action-bar API moved into C_ActionBar; the old globals only exist
-- while the client's deprecation fallbacks are switched on.
local AB = C_ActionBar or {}
ns.HasAction = AB.HasAction or HasAction
ns.IsUsableAction = AB.IsUsableAction or IsUsableAction
ns.IsActionInRange = AB.IsActionInRange or IsActionInRange
function ns.ActionCooldown(action)
    if AB.GetActionCooldown then
        local info = AB.GetActionCooldown(action)
        if info then return info.startTime, info.duration, info.isEnabled end
        return
    end
    return GetActionCooldown(action)
end

-- Hide a Blizzard texture for good. Blizzard sets alpha (SetAlpha) on its
-- button art as states change; it does not touch the vertex colour's
-- alpha, so that is what silences it.
function ns.Mute(region)
    if region and region.SetVertexColor then region:SetVertexColor(1, 1, 1, 0) end
end

-- The fonts a reader may choose for text they read at length (the quest
-- tracker's): Medalluin's own, the four every client ships, then those
-- other addons register with LibSharedMedia, asked each time (they load
-- after us). Each { key, name, path }; a key is kept in the settings.
local FONTS = {
    { "marcellus", "Marcellus SC", ns.font },
    { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "arialn", "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
local function Shared()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ns.Fonts()
    local out = {}
    for _, f in ipairs(FONTS) do table.insert(out, f) end
    local lsm = Shared()
    if lsm then
        local mine = {}
        for _, f in ipairs(FONTS) do mine[f[3]:lower()] = true end
        for _, name in ipairs(lsm:List("font") or {}) do
            local path = lsm:Fetch("font", name, true)
            if path and not mine[path:lower()] then
                mine[path:lower()] = true
                table.insert(out, { "lsm:" .. name, name, path })
            end
        end
    end
    return out
end

-- A font key's file: Medalluin's own for a key no longer there (a shared
-- font whose addon is gone).
function ns.FontPath(key)
    for _, f in ipairs(FONTS) do
        if f[1] == key then return f[3] end
    end
    local name, lsm = type(key) == "string" and key:match("^lsm:(.+)$"), Shared()
    return name and lsm and lsm:Fetch("font", name, true) or ns.font
end

-- A text's points as Medalluin's code gave them (fs.medalluinPoints:
-- { point, relativeTo, relativePoint, x, y } each). The game keeps a text's
-- points secret while its words are (a health value, in a group), so the
-- unit-frame editor's canvas reads them here (options/canvas.lua).
local function Remember(fs)
    hooksecurefunc(fs, "ClearAllPoints", function(self) self.medalluinPoints = nil end)
    hooksecurefunc(fs, "SetPoint", function(self, point, rel, relPoint, x, y)
        -- (the short forms: point, x, y; point, rel, x, y)
        if type(rel) ~= "table" then rel, relPoint, x, y = self:GetParent(), point, rel, relPoint end
        if type(relPoint) ~= "string" then relPoint, x, y = point, relPoint, x end
        local list = self.medalluinPoints or {}
        for i = #list, 1, -1 do if list[i][1] == point then table.remove(list, i) end end
        table.insert(list, { point, rel, relPoint, x or 0, y or 0 })
        self.medalluinPoints = list
    end)
    hooksecurefunc(fs, "SetAllPoints", function(self, rel)
        rel = rel or self:GetParent()
        self.medalluinPoints = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
    end)
end

function ns.Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(ns.colors.text))
    Remember(fs)
    return fs
end

-- ---------------------------------------------------------- tooltips
-- Medalluin's own tooltips, the ones no game data is behind: one spec,
-- written into GameTooltip as plain lines, and handed to mdlui_Tooltips
-- (mdlui/Medalluin.lua), which draws it as a panel instead.
--   spec = { title, color = {r, g, b} (the title's), wrap (the title's),
--     { "body", text, color },          -- a line, wrapped; white unless coloured
--     { "row", label, value, inline },  -- two columns, or "label: value"
--     { "bar", value, max, text, color },  -- the text here; a bar in the panel
--     { "item", icon, text, right },    -- "text  right"; an icon row in the panel
--     { "hint", text },                 -- dim; the panel's footer
--     { "warn", text } }                -- red
-- A part may be false, for one left out.
local WHITE, HINT, WARN = ns.colors.white, ns.colors.dim, { 1, 0.3, 0.25 }
local live = {}

local function Line(text, c, wrap)
    c = c or WHITE
    GameTooltip:AddLine(text, c[1], c[2], c[3], wrap)
end

local fill = {
    body = function(p) Line(p[2], p[3], true) end,
    row = function(p)
        if p[4] then Line(p[2] .. ": " .. p[3]) else GameTooltip:AddDoubleLine(p[2], p[3], 1, 1, 1, 1, 1, 1) end
    end,
    bar = function(p) Line(p[4]) end,
    item = function(p) Line(p[4] and format("%s  %s", p[3], p[4]) or p[3]) end,
    hint = function(p) Line(p[2], HINT) end,
    warn = function(p) Line(p[2], WARN, true) end,
}

-- anchor: SetOwner's, or a function that owns and places it (w.Beside)
function ns.Tip(owner, anchor, spec)
    if type(anchor) == "function" then anchor(owner) else GameTooltip:SetOwner(owner, anchor) end
    local c = spec.color
    GameTooltip:SetText(spec.title, c and c[1], c and c[2], c and c[3], c and 1, spec.wrap)
    for _, p in ipairs(spec) do
        if p then fill[p[1]](p) end
    end
    spec.owner = owner
    live[GameTooltip] = spec
    GameTooltip:Show()
end

-- a SetOwner or ClearLines from anyone else ends it
if GameTooltip then
    GameTooltip:HookScript("OnTooltipCleared", function(self) live[self] = nil end)
end

-- The spec GameTooltip shows, while its owner is still the one it was
-- written for: the companion's only way in.
function Medalluin_TooltipSpec(tooltip)
    local spec = live[tooltip]
    if spec and tooltip:GetOwner() == spec.owner then return spec end
end
