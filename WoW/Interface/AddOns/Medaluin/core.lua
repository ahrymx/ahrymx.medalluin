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
function ns.Kill(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:SetParent(ns.hidden)
end

-- Register a unit event if this client knows it; Classic-era clients have
-- renamed several (UNIT_HEALTH_FREQUENT, for one) between builds.
function ns.RegisterUnitEvent(frame, event, unit)
    return pcall(frame.RegisterUnitEvent, frame, event, unit)
end

function ns.Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(ns.colors.text))
    return fs
end
