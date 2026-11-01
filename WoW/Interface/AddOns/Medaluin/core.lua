-- Medaluin core: namespace, media, palette, events and the hidden parent.
local _, ns = ...

ns.media = "Interface\\AddOns\\Medaluin\\media\\"
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
}
-- Blizzard's class and reaction colours are brighter than the art; mute them.
ns.mute = 0.8

-- One event frame for the whole addon: ns.On("EVENT", fn).
local handlers, events = {}, CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)
function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
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
function ns.Park(frame)
    if not frame then return end
    frame:SetParent(ns.hidden)
    if killed[frame] then return end
    killed[frame] = true
    hooksecurefunc(frame, "SetParent", function(self, parent)
        if parent ~= ns.hidden then
            ns.OutOfCombat(function() self:SetParent(ns.hidden) end)
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
-- for this session only.
ns.sim = { bosses = 2 }

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

function ns.Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(ns.colors.text))
    return fs
end
