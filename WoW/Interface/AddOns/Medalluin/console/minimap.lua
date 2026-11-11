-- The minimap moves into the ring: reparented to the console, masked round,
-- a touch larger than the hole so its edge tucks under the gold. Zoom is on
-- the mouse wheel. (The combat swap to the CC tracker comes later.)
local _, ns = ...

local console = ns.console
-- the hover label's look: the window trim on a brown well, both see-through
local GOLD_D = { 0.541, 0.439, 0.204 }
local AREA_BROWN = { 0.165, 0.125, 0.071 }      -- #2a2012
local AREA_ALPHA = 0.8
local AREA_SIZE, AREA_PAD, AREA_INSET = 10, 3, 4
local AREA_FADE_IN, AREA_FADE_OUT = 0.5, 1      -- seconds it takes to come and to go

-- ------------------------------------------------------------ where it goes
-- The light profile's minimap sits in the console's bay, or in the screen's
-- top-right corner while the 2x5 grid takes the bay (console/bar7.lua). One
-- rule decides, and the console's art follows it (console/frame.lua):
--
--   1. a party row under the console takes the bay's foot, so in a group
--      the minimap is in the corner, always (party_row.lua)
--   2. a pin, from the minimap key, holds it where the key put it (for
--      this session). The place chosen for the game's load (Console >
--      Minimap: When the game loads) is a pin too, held only until the
--      automatic moves change their answer
--   3. otherwise, with Move automatically on, it goes to the corner on each
--      trigger ticked on Console > Minimap: combat, a target, skyriding
local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
local pin                                   -- nil, "corner" or "console"
local lent                                  -- the side panel's Zone tab's well, while it has the map
local held                                  -- the load's pin: rule 3's answer when it was set

function ns.MinimapMoves()
    local mm = ns.layout and ns.layout.minimap
    return mm and mm.relocate and true or false
end

-- rule 3 alone
local function Auto()
    if not ns.db.minimapAuto then return false end
    local target = UnitExists and UnitExists("target")
    return (inCombat and ns.db.minimapAutoCombat or target and ns.db.minimapAutoTarget
        or ns.skyriding and ns.db.minimapAutoSkyriding) and true or false
end

function ns.MinimapInCorner()
    if not ns.MinimapMoves() then return false end
    if ns.PartyRowShown and ns.PartyRowShown() then return true end
    if pin then return pin == "corner" end
    return Auto()
end

function ns.MinimapPinned() return pin end

-- The key (Bindings.xml): the minimap back where the game loads it, when it
-- is not there; there, pinned in its other place. Where the game loads it is
-- the place chosen for the load, held as the load holds it (until rule 3
-- changes its answer), or, "As it moves", where rule 3 puts it (no pin).
function ns.ToggleMinimap()
    if not ns.MinimapMoves() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Medalluin: only the Central Console profile's minimap moves.", 1, 0.82, 0)
        end
        return
    end
    if lent then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Medalluin: the minimap is in the side panel's Zone tab.", 1, 0.82, 0)
        end
        return
    end
    local here = ns.MinimapInCorner() and "corner" or "console"
    local other = here == "corner" and "console" or "corner"
    local start = ns.db.minimapStart
    if start ~= "corner" and start ~= "console" then
        start = nil
    end
    local home = start or (Auto() and "corner" or "console")
    if here ~= home then
        -- back as the load left it: the load's pin, or none
        pin, held = start, nil
        if start then held = Auto() end
    else
        pin, held = other, nil
    end
    if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
end
-- the binding's code runs outside the addon, so it calls a global
function MedalluinToggleMinimap() ns.ToggleMinimap() end
BINDING_HEADER_MEDALLUIN = "Medalluin"
BINDING_NAME_MEDALLUIN_MINIMAP = "Minimap: console or corner"

ns.On("PLAYER_LOGIN", function()
    local _, r, top, bottom = unpack(ns.windows.ring)
    local size = 2 * r + 2 * ns.layout.minimapBleed
    local mmCfg = ns.layout.minimap

    -- The minimap draws true only when it is square: on a wider frame the
    -- ground stretches to fill it while the icons keep a square's spacing, so
    -- they drift off what they mark. So it stays square, as wide as the
    -- longer side of where it shows, and its mask keeps that place's shape:
    -- the bay's (art/console/gen_light_console.py) is a band across the
    -- middle. A parent that clips its children does not crop it: the client
    -- draws the minimap past its parent's edges.
    --
    -- The mask hides only the ground, though, and the pins addons hang on
    -- the minimap are frames of their own, drawn over the whole square. The
    -- parent that cannot crop the ground does crop them (measured in game,
    -- in and out of combat): the minimap sits in a frame of the shown shape,
    -- clipping, so nothing on it shows past the gold. A pin floated to the
    -- edge of a round map past the band is cut off with it.
    local round = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local square = "Interface\\Buttons\\WHITE8X8"
    local clip = CreateFrame("Frame", "MedalluinMinimapClip", console)
    clip:SetFrameLevel(math.max(0, ns.levels.bars - 1))
    clip:SetClipsChildren(true)
    clip:SetPoint("CENTER", Minimap, "CENTER")
    Minimap:SetParent(clip)
    Minimap:SetFrameStrata(console:GetFrameStrata())
    Minimap:SetFrameLevel(ns.levels.bars)
    Minimap:SetScale(1)
    -- the square's side and the mask for w x h shown (or always square)
    local function Shape(w, h, always)
        local side = math.max(w, h)
        if always then return side, square end
        if not (mmCfg and mmCfg.square) then return side, round end
        if w ~= h and mmCfg.bayMask then return side, ns.media .. mmCfg.bayMask end
        return side, square
    end
    -- w x h shown, from a square as big as the longer side; what the mask
    -- hides takes no clicks, pings or the wheel either
    local function Fit(w, h, always)
        local side, mask = Shape(w, h, always)
        Minimap:SetSize(side, side)
        clip:SetSize(w, h)
        Minimap:SetHitRectInsets((side - w) / 2, (side - w) / 2, (side - h) / 2, (side - h) / 2)
        Minimap:SetMaskTexture(mask)
    end

    -- While the side panel's Zone tab has the map (strips/zone.lua), its
    -- place here stands empty: black, in the shape the map shows there.
    -- (Something else is to fill it later.)
    local hole = CreateFrame("Frame", "MedalluinMinimapEmpty", console)
    hole:SetFrameLevel(clip:GetFrameLevel())
    hole:SetClipsChildren(true)
    local dark = hole:CreateTexture(nil, "BACKGROUND")
    dark:SetPoint("CENTER")
    dark:SetColorTexture(0, 0, 0, 1)
    local darkMask
    if hole.CreateMaskTexture and dark.AddMaskTexture then
        darkMask = hole:CreateMaskTexture()
        darkMask:SetAllPoints(dark)
        dark:AddMaskTexture(darkMask)
    end
    hole:Hide()
    ns.minimapEmpty = hole
    -- The client rings the quest, bonus-objective and dig-site areas at a
    -- round minimap's edge, where the area runs off the map: on the square
    -- map that ring sits inside the square, a hatched circle round the
    -- player. The areas themselves still show. (Clients without them: Era.)
    if mmCfg and mmCfg.square then
        for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
            for _, what in ipairs({ "Scalar", "Alpha" }) do
                local set = Minimap["Set" .. kind .. "BlobRing" .. what]
                if set then set(Minimap, 0) end
            end
        end
    end

    local area                              -- the area's name over the hovered map, below

    -- The map at its place, w x h shown, centred on (to, rel, x, y); or,
    -- while it is lent, the empty place there and the map in the well,
    -- square and as big as the well, on the well's strata and above it.
    local function Place(to, rel, x, y, w, h)
        Minimap:ClearAllPoints()
        if not lent then
            hole:Hide()
            clip:SetParent(console)
            clip:SetFrameStrata(console:GetFrameStrata())
            clip:SetFrameLevel(math.max(0, ns.levels.bars - 1))
            Minimap:SetFrameStrata(console:GetFrameStrata())
            Minimap:SetFrameLevel(ns.levels.bars)
            Minimap:SetPoint("CENTER", to, rel, x, y)
            Fit(w, h)
            return
        end
        local side, mask = Shape(w, h)
        hole:ClearAllPoints()
        hole:SetPoint("CENTER", to, rel, x, y)
        hole:SetSize(w, h)
        dark:SetSize(side, side)
        if darkMask then darkMask:SetTexture(mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
        hole:Show()
        clip:SetParent(lent)
        clip:SetFrameStrata(lent:GetFrameStrata())
        clip:SetFrameLevel(lent:GetFrameLevel() + 1)
        Minimap:SetFrameStrata(lent:GetFrameStrata())
        Minimap:SetFrameLevel(lent:GetFrameLevel() + 2)
        Minimap:SetPoint("CENTER", lent, "CENTER")
        local s = math.min(lent:GetWidth(), lent:GetHeight())
        Fit(s, s, true)
        if area then area:Hide() end
    end
    -- the profiles whose map stays in the ring; the moving one's is below
    local function Locate()
        Place(console, "TOP", 0, -(top + bottom) / 2, size, mmCfg and mmCfg.square and (bottom - top) or size)
    end
    Locate()
    if mmCfg and mmCfg.relocate then
        local bezel = CreateFrame("Frame", "MedalluinMinimapBezel", console)
        bezel:SetFrameLevel(ns.levels.art)
        local bt = bezel:CreateTexture(nil, "ARTWORK")
        bt:SetAllPoints()
        bt:SetTexture(ns.media .. "minimap-light")
        bt:SetTexCoord(0, mmCfg.topRightSize / mmCfg.texWidth, 0, mmCfg.topRightSize / mmCfg.texHeight)
        bezel:Hide()
        ns.minimapBezel = bezel
        -- in the corner they are not the console's body, and keep their own
        -- alpha while it fades (console/fade.lua)
        if bezel.SetIgnoreParentAlpha then bezel:SetIgnoreParentAlpha(true) end

        -- The grip: a widget's tab on the corner's top edge, with the area's
        -- name on it (the console's hover label stays in the bay). A drag
        -- moves the corner, as its mover does (Console > Minimap: In the
        -- corner); nothing in it is protected, so in combat too. It shows
        -- with the corner, and with Movers only on mouseover only while the
        -- pointer is over the minimap or it.
        local grip = ns.WidgetTab(bezel, bezel:GetFrameLevel())
        grip:SetPoint("BOTTOM", bezel, "TOP", 0, -ns.WIDGET_TAB_OVER)
        local drag = ns.ConsoleDragger("minimap")
        grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then drag.Start() end end)
        grip:SetScript("OnUpdate", drag.Update)
        grip:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then drag.Stop() end end)
        grip:SetScript("OnEnter", function(self)
            ns.Tip(self, "ANCHOR_TOP", { title = self.label:GetText(), color = ns.colors.white,
                { "hint", "Drag to move." } })
        end)
        grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ns.minimapGrip = grip
        ns.WatchMover({ hover = "minimapMoverHover", tabs = { grip }, Hovered = function()
            return drag.from ~= nil or bezel:IsMouseOver() or grip:IsMouseOver()
        end })
        -- the area's name, no wider than the corner
        local function Name()
            grip.label:SetText(GetMinimapZoneText())
            ns.WidgetTabWidth(grip, bezel:GetWidth())
        end
        for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
            ns.On(e, Name)
        end

        -- The corner, at the player's size and place (Console > Minimap, or
        -- its Edit Mode mover): in design units, whatever the console's own
        -- scale, as the corner strips are. The minimap is the console's child,
        -- so its size in the corner undoes the console's scale.
        local function Corner()
            local k = tonumber(ns.db.consoleScale) or 1
            if k <= 0 then k = 1 end
            local s = tonumber(ns.db.minimapScale) or 1
            bezel:SetScale(1 / k)
            bezel:SetSize(mmCfg.topRightSize * s, mmCfg.topRightSize * s)
            bezel:ClearAllPoints()
            bezel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -mmCfg.topRightInset + (tonumber(ns.db.minimapX) or 0),
                -mmCfg.topRightInset + (tonumber(ns.db.minimapY) or 0))
            return (mmCfg.topRightSize - 4) * s / k
        end

        local function UpdateLocation()
            -- the load's place is let go once rule 3 says something new
            if held ~= nil and Auto() ~= held then pin, held = nil, nil end
            local _, rx, rTop, rBottom = unpack(ns.windows.ring)
            local w = 2 * rx + 2 * ns.layout.minimapBleed
            local h = rBottom - rTop
            local corner = ns.MinimapInCorner()
            local inner = Corner()
            if Minimap.SetIgnoreParentAlpha then Minimap:SetIgnoreParentAlpha(corner and not lent) end
            if hole.SetIgnoreParentAlpha then hole:SetIgnoreParentAlpha(corner) end
            if corner then
                Place(bezel, "CENTER", 0, 0, inner, inner)
                -- the corner is the map's alone: while the side panel has
                -- it, the corner goes too (its grip with it), nothing left
                -- empty there
                if lent then hole:Hide() end
                bezel:SetShown(not lent)
                Name()
                if area then area:Hide() end
            else
                Place(console, "TOP", 0, -(rTop + rBottom) / 2, w, h)
                bezel:Hide()
            end
            if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
            if ns.UpdateBar7Visibility then ns.UpdateBar7Visibility(corner) end
        end
        ns.UpdateMinimapLocation = UpdateLocation
        ns.PlaceMinimap = UpdateLocation
        Locate = UpdateLocation
        for _, key in ipairs({ "minimapAuto", "minimapAutoCombat", "minimapAutoTarget", "minimapAutoSkyriding",
            "minimapScale", "minimapX", "minimapY", "consoleScale" }) do
            ns.OnSetting(key, UpdateLocation)
        end
        ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; UpdateLocation() end)
        ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; UpdateLocation() end)
        ns.On("PLAYER_TARGET_CHANGED", UpdateLocation)
        -- skyriding brings the grid out too: it flies on page 11
        -- (bars/paging.lua), and its skills must be seen to be placed. The
        -- game's own conditional decides, as it does the grid's page, so
        -- the two cannot disagree; a state driver runs in combat too.
        local flight = CreateFrame("Frame")
        flight:SetScript("OnAttributeChanged", function(_, name, value)
            if name ~= "state-skyriding" then return end
            ns.skyriding = value == "on"
            UpdateLocation()
        end)
        RegisterStateDriver(flight, "skyriding", "[bonusbar:5] on; off")
        ns.skyridingWatch = flight
        ns.On("PLAYER_ENTERING_WORLD", function()
            inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
            UpdateLocation()
        end)
        local start = ns.db.minimapStart
        if start == "corner" or start == "console" then pin, held = start, Auto() end
        UpdateLocation()
    end

    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self:GetZoom() + (delta > 0 and 1 or -1)
        self:SetZoom(math.max(0, math.min(self:GetZoomLevels() - 1, zoom)))
    end)

    -- The area, at the top's middle of the shown map while the pointer is
    -- over it, fading out once it has shown for as long as Console > Minimap
    -- says (or never): the zone text the cluster had, gone with it below.
    -- Not in the corner, whose grip wears the name.
    -- The minimap's child, so it keeps the map's alpha in the corner, but
    -- placed on the clip, whose top is the one shown. A pin is a frame of
    -- its own and takes the pointer from the map, so it hides when the
    -- pointer leaves the shown shape, not the map.
    area = CreateFrame("Frame", "MedalluinMinimapArea", Minimap)
    area:SetFrameLevel(ns.levels.text)
    area:SetPoint("TOP", clip, "TOP", 0, -AREA_INSET)
    area:Hide()
    local well = area:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(AREA_BROWN[1], AREA_BROWN[2], AREA_BROWN[3], AREA_ALPHA)
    -- the trim in four lines: under a well that is not opaque, one gold
    -- square would show through
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local line = area:CreateTexture(nil, "BORDER")
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] == 1 then line:SetWidth(1) else line:SetHeight(1) end
        line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], AREA_ALPHA)
    end
    local label = ns.Text(area, AREA_SIZE)
    label:SetPoint("LEFT", AREA_PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    local function ShowArea()
        label:SetText(GetMinimapZoneText())
        -- no wider than the shown map; a longer name ends in an ellipsis
        local most = clip:GetWidth() - 2 * (AREA_INSET + AREA_PAD)
        label:SetWidth(math.min(label:GetStringWidth() + 1, most))
        area:SetSize(label:GetWidth() + 2 * AREA_PAD, label:GetStringHeight() + 2 * AREA_PAD)
    end
    -- One visit shows it once. A pin takes the pointer and gives it back,
    -- and the map's OnEnter comes again, which must not start it over: so
    -- it stays shown, at no alpha once its time is up, until the pointer
    -- leaves the shown shape, and fades in and out on the way. Back on the
    -- map while it fades out is a new visit. Its time counts while the
    -- pointer is on the shape, from naught each time it is off it, so it
    -- is naught again whenever it has hidden.
    local shownFor = 0
    Minimap:HookScript("OnEnter", function()
        if area:IsShown() or lent or ns.MinimapInCorner() then return end
        ShowArea()
        area:SetAlpha(0)
        area:Show()
    end)
    area:SetScript("OnUpdate", function(self, elapsed)
        local hold = tonumber(ns.db.minimapAreaTime) or 0
        local over = clip:IsMouseOver()
        shownFor = over and shownFor + elapsed or 0
        local a = self:GetAlpha()
        if over and (hold <= 0 or shownFor < hold) then
            a = math.min(1, a + elapsed / AREA_FADE_IN)
        else
            a = math.max(0, a - elapsed / AREA_FADE_OUT)
        end
        self:SetAlpha(a)
        if a == 0 and not over then self:Hide() end
    end)
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
        ns.On(e, ShowArea)
    end

    -- The round border, zoom buttons, zone text and the rest of the cluster
    -- belong to the default frame. Mail and tracking are children of the
    -- minimap itself and come along until they get their corner pips.
    for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
        "MinimapZoneTextButton", "MiniMapWorldMapButton", "MinimapToggleButton",
        "MinimapNorthTag", "MinimapCompassTexture", "GameTimeFrame", "TimeManagerClockButton",
        -- Forever and retail hang their ring art (and the landing-page
        -- button) on the minimap itself, and the zoom buttons by key
        "MinimapBackdrop", "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
        local f = _G[name]
        if type(f) ~= "table" then f = rawget(Minimap, name) end
        if type(f) == "table" then
            if f.UnregisterAllEvents then f:UnregisterAllEvents() end
            f:SetParent(ns.hidden)
        end
    end
    ns.Kill(MinimapCluster)

    -- The side panel's Zone tab takes the map into its well (a frame), and
    -- gives it back (nil). The well clips the pins, as the clip here does.
    function ns.LendMinimap(to)
        if to == lent then return end
        lent = to
        Locate()
    end
end)
