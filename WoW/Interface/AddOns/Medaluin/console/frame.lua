-- The console: one frame the size of the art, centred at the bottom of the
-- screen. Everything drawn in a window sits BELOW the art, so the art's cut
-- edges shape the plain rectangles behind them; text sits above it.
--
--   base       dark backing for each window (an empty window reads as ink)
--   base + 2   unit buttons, XP bars, minimap
--   base + 10  the art (solo or group), and over it the combat tint
--   base + 12  text and mouse-over hit areas
local _, ns = ...

local art = ns.art
local console = CreateFrame("Frame", "MedaluinConsole", UIParent)
console:SetFrameStrata("LOW")
console:SetSize(art.width, art.height)
console:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, art.bottomGap)
ns.console = console

local base = console:GetFrameLevel()
ns.levels = { bars = base + 2, art = base + 10, text = base + 12 }

-- Keep the art the same share of the screen at any resolution or UI scale.
-- The console holds secure buttons, so its scale only changes out of combat.
local function Rescale()
    ns.OutOfCombat(function()
        console:SetScale(UIParent:GetHeight() / ns.layout.designHeight)
    end)
end
Rescale()
ns.On("UI_SCALE_CHANGED", Rescale)
ns.On("DISPLAY_SIZE_CHANGED", Rescale)
ns.On("PLAYER_ENTERING_WORLD", Rescale)

-- Backing: an ink rectangle under every window except the ring (the
-- minimap fills that). Party backings only show with the group art.
local backings = { solo = {}, group = {} }
for name in pairs(ns.windows) do
    if name ~= "ring" then
        for _, side in ipairs({ -1, 1 }) do
            local t = console:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(unpack(ns.colors.ink))
            ns.PlaceOn(t, console, name, side)
            table.insert(name:match("^party") and backings.group or backings.solo, t)
        end
    end
end

local artFrame = CreateFrame("Frame", nil, console)
artFrame:SetAllPoints()
artFrame:SetFrameLevel(ns.levels.art)
local tex = artFrame:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints()
tex:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)

-- The combat colour code: the art's grey surface, never its gold trim, as
-- a white mask strongest at the ring and faintest at the ends (drawn by
-- art/console/export.py), tinted by the player's state. Out of combat it
-- is hidden; in combat it is yellow, and red while the player has threat,
-- which is any threat situation at all: Blizzard's own indicator lights
-- from 1, "higher threat than the tank", up. A threat query on the player
-- alone is not restricted, so it is not secret; should it be, the tint
-- stays yellow rather than guess.
local TINT = { combat = { 1, 0.82, 0 }, threat = { 0.9, 0.12, 0.08 } }
local TINT_ALPHA = 0.45
local tint = artFrame:CreateTexture(nil, "ARTWORK", nil, 1)
tint:SetAllPoints()
tint:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
tint:Hide()
ns.tint = tint

local fighting = false
local function Threatened()
    local s = UnitThreatSituation and UnitThreatSituation("player")
    if ns.IsSecret(s) or s == nil then return false end
    return s >= 1
end
local function UpdateTint()
    tint:SetShown(fighting)
    if fighting then
        local c = Threatened() and TINT.threat or TINT.combat
        tint:SetVertexColor(c[1], c[2], c[3], TINT_ALPHA)
    end
end
ns.On("PLAYER_REGEN_DISABLED", function() fighting = true; UpdateTint() end)
ns.On("PLAYER_REGEN_ENABLED", function() fighting = false; UpdateTint() end)
-- a reload in combat
ns.On("PLAYER_ENTERING_WORLD", function()
    fighting = UnitAffectingCombat("player") and true or false
    UpdateTint()
end)
local threat = CreateFrame("Frame")
ns.RegisterUnitEvent(threat, "UNIT_THREAT_SITUATION_UPDATE", "player")
threat:SetScript("OnEvent", UpdateTint)

-- The group art adds the party row. Textures are not protected, so this
-- can swap in combat too; the party buttons themselves follow their units.
local function UpdateGroup()
    local grouped = IsInGroup()
    local file = ns.media .. (grouped and "console-group" or "console-solo")
    tex:SetTexture(file)
    tint:SetTexture(file .. "-tint")
    for _, t in ipairs(backings.group) do t:SetShown(grouped) end
end
UpdateGroup()
ns.On("GROUP_ROSTER_UPDATE", UpdateGroup)
ns.On("PLAYER_ENTERING_WORLD", UpdateGroup)
