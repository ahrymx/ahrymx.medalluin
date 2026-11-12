-- The console: one frame the size of the art, centred at the bottom of the
-- screen. Everything drawn in a window sits BELOW the art, so the art's cut
-- edges shape the plain rectangles behind them; text sits above it.
--
--   base       the light profile's combat aura, under all of it; then a
--              dark backing for each window (an empty window reads as ink)
--   base + 2   unit buttons, XP bars, minimap
--   base + 10  the art (solo or group), and over it the combat tint
--   base + 12  text and mouse-over hit areas
local _, ns = ...

local art = ns.art
local console = CreateFrame("Frame", "MedalluinConsole", UIParent)
console:SetFrameStrata("LOW")
console:SetSize(art.width, art.height)
console:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, art.bottomGap)
ns.console = console

local base = console:GetFrameLevel()
ns.levels = { bars = base + 2, art = base + 10, text = base + 12 }

-- Keep the art the same share of the screen at any resolution or UI scale,
-- times the player's Scale, moved by their offset (movers.lua). An offset is
-- in design units; SetPoint's are the console's own, so it is divided by the
-- player's scale. The corner strips are the console's children but keep
-- their own size: they undo the player's scale, and are set first, so the
-- chat's SetScale hook (strips/chat.lua) measures them already undone.
-- The console holds secure buttons, so it only moves out of combat.
local function Rescale()
    ns.OutOfCombat(function()
        local k = tonumber(ns.db.consoleScale) or 1
        if k <= 0 then k = 1 end
        for _, strip in pairs(ns.strips or {}) do strip:SetScale(1 / k) end
        console:SetScale(UIParent:GetHeight() / ns.layout.designHeight * k)
        console:ClearAllPoints()
        console:SetPoint("BOTTOM", UIParent, "BOTTOM", (tonumber(ns.db.consoleX) or 0) / k,
            ns.art.bottomGap + (tonumber(ns.db.consoleY) or 0) / k)
    end)
end
ns.PlaceConsole = Rescale
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

-- The light console's combat aura: a glow round each piece in the tint's
-- colour, fading out over ten pixels (art/console/gen_light_console.py).
-- Each glow is full inside its piece and drawn on the console itself, under
-- everything the console holds, so the art covers all but what lies
-- outside. A glow follows its piece: the bay's shape (the minimap's or the
-- grid's), Bar 1 and the wings as they fade, the party row in a group.
local AURA_ALPHA = 0.85
local auras                 -- key -> texture, once the light profile has them
local bayActive = false     -- the bay is the grid's (UpdateGroup)
local hooked = {}

local fighting = false
-- the unit-frame editor's preview of the tint: "combat", "threat" or nil
-- (ns.PreviewTint, editor.lua's chips)
local previewing
local function Threatened()
    if previewing == "threat" then return true end
    local s = UnitThreatSituation and UnitThreatSituation("player")
    if ns.IsSecret(s) or s == nil then return false end
    return s >= 1
end

local UpdateGroup

local function AuraTexture(spec, shift)
    local t = console:CreateTexture(nil, "BACKGROUND", nil, -8)
    local b = spec.box
    t:SetTexture(ns.media .. spec.file)
    t:SetSize(b[2] - b[1], b[3] - b[4])
    t:SetPoint("TOPLEFT", console, "TOP", b[1] + (shift or 0), b[3])
    t:SetTexCoord(0, (b[2] - b[1]) / spec.texWidth, 0, (b[3] - b[4]) / spec.texHeight)
    t:Hide()
    return t
end

-- How much of a piece shows: nothing while it is missing or hidden, else
-- its own alpha (Bar 1 and the wings fade on their own: bars/bar.lua).
local function Shown(frame)
    if not (frame and frame:IsShown()) then return 0 end
    if not hooked[frame] then
        hooked[frame] = true
        hooksecurefunc(frame, "SetAlpha", function() ns.UpdateConsoleAura() end)
    end
    return frame:GetAlpha()
end

function ns.UpdateConsoleAura()
    local spec = ns.art.aura
    if not spec then return end
    if not auras then
        auras = {}
        for _, key in ipairs({ "explore", "combat", "bar1", "hybrid", "wing", "row" }) do
            auras[key] = AuraTexture(spec[key])
        end
        auras.wing2 = AuraTexture(spec.wing, spec.wingShift)
    end
    local wings = ns.barWingPlates or {}
    local show = {
        explore = not bayActive and 1 or 0,
        combat = bayActive and 1 or 0,
        bar1 = ns.barPlate and Shown(ns.actionBar) or 0,
        hybrid = Shown(ns.hybridBar),
        wing = wings[1] and Shown(ns.extraBars) or 0,
        wing2 = wings[2] and Shown(ns.extraBars) or 0,
        row = Shown(ns.partyRowBand),
    }
    local c = Threatened() and TINT.threat or TINT.combat
    for key, t in pairs(auras) do
        local a = (fighting or previewing) and show[key] or 0
        t:SetShown(a > 0)
        if a > 0 then t:SetVertexColor(c[1], c[2], c[3], AURA_ALPHA * a) end
    end
end

local function UpdateTint()
    local on = fighting or previewing ~= nil
    tint:SetShown(on)
    if on then
        local c = Threatened() and TINT.threat or TINT.combat
        tint:SetVertexColor(c[1], c[2], c[3], TINT_ALPHA)
    end
    -- the light profile's art, and its aura with it
    if ns.art.exploreFile and UpdateGroup then UpdateGroup() end
end
function ns.PreviewTint(kind)
    previewing = kind
    UpdateTint()
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
-- In the "light" profile, party frames are detached (a row under the
-- console: party_row.lua), and the console plate swaps between
-- its exploration (minimap bay) and combat/target (2x5 Bar 7 bay) textures;
-- the bay is the grid's while the minimap is in the corner (console/minimap.lua).
UpdateGroup = function()
    if ns.art.exploreFile then
        -- the bay shows what is in it: the minimap's one rule (console/minimap.lua)
        local active
        if ns.MinimapInCorner then
            active = ns.MinimapInCorner()
        else
            local row = ns.PartyRowShown and ns.PartyRowShown()
            active = fighting or (UnitExists and UnitExists("target")) or ns.skyriding or row
        end
        bayActive = active and true or false
        local file = ns.media .. (active and ns.art.combatFile or ns.art.exploreFile)
        tex:SetTexture(file)
        tint:SetTexture(ns.media .. ns.art.tintFile)
        for _, t in ipairs(backings.group) do t:SetShown(false) end
        if ns.ShowPartyRow then ns.ShowPartyRow() end
        ns.UpdateConsoleAura()
        return
    end
    -- the party in its widget leaves the wings empty (widgets/party.lua)
    local grouped = (IsInGroup() or (ns.db and ns.db.simParty))
        and not (ns.PartyWidgetLayout and ns.PartyWidgetLayout())
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
-- built-in "light" profile when MedalluinDB.consoleProfile == "light".
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
    Rescale()
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
