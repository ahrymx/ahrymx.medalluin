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
-- minimap fills that). The player and target frames wear a glassy vial
-- backing so an empty bar reads as a depleted vial; party backings only
-- show with the group art.
local backings = { solo = {}, group = {}, byName = {} }
local vialU, vialV = art.vialWidth / art.vialTexWidth, art.vialHeight / art.vialTexHeight
for name in pairs(ns.windows) do
    if name ~= "ring" then
        for _, side in ipairs({ -1, 1 }) do
            local t = console:CreateTexture(nil, "BACKGROUND")
            if name == "unit" then
                t:SetTexture(ns.media .. "vial")
                t:SetTexCoord(side == 1 and vialU or 0, side == 1 and 0 or vialU, 0, vialV)
            else
                t:SetColorTexture(unpack(ns.colors.ink))
            end
            ns.PlaceOn(t, console, name, side)
            table.insert(name:match("^party") and backings.group or backings.solo, t)
            table.insert(backings.byName, { tex = t, name = name, side = side })
        end
    end
end

local artFrame = CreateFrame("Frame", nil, console)
artFrame:SetAllPoints()
artFrame:SetFrameLevel(ns.levels.art)
local tex = artFrame:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints()
tex:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
ns.consoleTex = tex

-- The combat colour code: glowing lava veins through the art's grey stone
-- surface (never its gold trim), as a white mask drawn by art/console/export.py,
-- tinted by the player's state. Drawn with additive blending so the magma
-- veins shine over the dark rock. Out of combat it is hidden; in combat it
-- is yellow, and red while the player has threat, which is any threat
-- situation at all: Blizzard's own indicator lights from 1, "higher threat
-- than the tank", up. A threat query on the player alone is not restricted,
-- so it is not secret; should it be, the tint stays yellow rather than guess.
local TINT = { combat = { 1, 0.82, 0 }, threat = { 0.9, 0.12, 0.08 } }
local TINT_ALPHA = 0.85
local tint = artFrame:CreateTexture(nil, "ARTWORK", nil, 1)
tint:SetAllPoints()
tint:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
tint:SetBlendMode("ADD")
tint:Hide()
ns.tint = tint

local fighting = false
local function Threatened()
    local s = UnitThreatSituation and UnitThreatSituation("player")
    if ns.IsSecret(s) or s == nil then return false end
    return s >= 1
end

local UpdateGroup

local function UpdateTint()
    tint:SetShown(fighting)
    if fighting then
        local c = Threatened() and TINT.threat or TINT.combat
        tint:SetVertexColor(c[1], c[2], c[3], TINT_ALPHA)
    end
    if ns.art.exploreFile and UpdateGroup then UpdateGroup() end
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
-- In the "light" profile, party frames are detached (a vertical stack, or a
-- row under the console: party_row.lua), and the console plate swaps between
-- its exploration (minimap bay) and combat/target (2x5 Bar 7 bay) textures;
-- skyriding and a shown party row count as active (console/minimap.lua).
UpdateGroup = function()
    if ns.art.exploreFile then
        local row = ns.PartyRowShown and ns.PartyRowShown()
        local active = fighting or (UnitExists and UnitExists("target")) or ns.skyriding or row
        local file = ns.media .. (active and ns.art.combatFile or ns.art.exploreFile)
        tex:SetTexture(file)
        tint:SetTexture(ns.media .. ns.art.tintFile)
        for _, t in ipairs(backings.group) do t:SetShown(false) end
        if ns.ShowPartyRow then ns.ShowPartyRow() end
        return
    end
    local grouped = IsInGroup() or (ns.db and ns.db.simParty)
    local file = ns.media .. (grouped and "console-group" or "console-solo")
    tex:SetTexture(file)
    tint:SetTexture(file .. "-tint")
    for _, t in ipairs(backings.group) do t:SetShown(grouped and true or false) end
end
ns.UpdateConsoleArt = UpdateGroup
UpdateGroup()
ns.On("GROUP_ROSTER_UPDATE", UpdateGroup)
ns.On("PLAYER_TARGET_CHANGED", function()
    if ns.art.exploreFile then UpdateGroup() end
end)
ns.On("PLAYER_ENTERING_WORLD", UpdateGroup)
ns.On("ADDON_LOADED", UpdateGroup)
ns.OnSetting("simParty", UpdateGroup)

-- Switch the console, unit windows, XP/Rep slots and action bar tables to the
-- built-in "light" profile when MedaluinDB.consoleProfile == "light".
function ns.ApplyLightProfile()
    local p = ns.lightProfile
    if not p then return end
    ns.art = p.art
    ns.windows = p.windows
    ns.layout = p.layout
    ns.barArt = p.barArt
    ns.barFrame = p.barFrame
    ns.barLow = p.barLow
    ns.barPager = p.barPager
    ns.barDrawer = p.barDrawer
    ns.barDrawerToggle = p.barDrawerToggle
    ns.barDrawerCell = p.barDrawerCell
    ns.barWindows = p.barWindows
    ns.bar7 = p.bar7

    art = ns.art
    console:SetSize(art.width, art.height)
    console:ClearAllPoints()
    console:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, art.bottomGap)
    tex:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
    tint:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)

    for _, entry in ipairs(backings.byName) do
        if ns.windows[entry.name] then
            ns.PlaceOn(entry.tex, console, entry.name, entry.side)
            entry.tex:Show()
        else
            entry.tex:Hide()
        end
    end
    UpdateGroup()
    if ns.RelayoutUnits then ns.RelayoutUnits() end
    if ns.RelayoutXP then ns.RelayoutXP() end
end
