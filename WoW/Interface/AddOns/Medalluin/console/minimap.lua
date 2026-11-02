-- The minimap moves into the ring: reparented to the console, masked round,
-- a touch larger than the hole so its edge tucks under the gold. Zoom is on
-- the mouse wheel. (The combat swap to the CC tracker comes later.)
local _, ns = ...

local console = ns.console

-- ------------------------------------------------------------ where it goes
-- The light profile's minimap sits in the console's bay, or in the screen's
-- top-right corner while the 2x5 grid takes the bay (console/bar7.lua). One
-- rule decides, and the console's art follows it (console/frame.lua):
--
--   1. a party row under the console takes the bay's foot, so in a group
--      the minimap is in the corner, always (party_row.lua)
--   2. a pin, from the minimap key, holds it where the key put it until the
--      key is pressed again (for this session)
--   3. otherwise, with Move automatically on, it goes to the corner on each
--      trigger ticked on Console > Minimap: combat, a target, skyriding
local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
local pin                                   -- nil, "corner" or "console"

function ns.MinimapMoves()
    local mm = ns.layout and ns.layout.minimap
    return mm and mm.relocate and true or false
end

function ns.MinimapInCorner()
    if not ns.MinimapMoves() then return false end
    if ns.PartyRowShown and ns.PartyRowShown() then return true end
    if pin then return pin == "corner" end
    if not ns.db.minimapAuto then return false end
    local target = UnitExists and UnitExists("target")
    return (inCombat and ns.db.minimapAutoCombat or target and ns.db.minimapAutoTarget
        or ns.skyriding and ns.db.minimapAutoSkyriding) and true or false
end

function ns.MinimapPinned() return pin end

-- The key (Bindings.xml): the first press pins the minimap in the other
-- place, the next lets the rule decide again.
function ns.ToggleMinimap()
    if not ns.MinimapMoves() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Medalluin: only the Central Console profile's minimap moves.", 1, 0.82, 0)
        end
        return
    end
    if pin then
        pin = nil
    else
        pin = ns.MinimapInCorner() and "console" or "corner"
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
    local round = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local square = "Interface\\Buttons\\WHITE8X8"
    Minimap:SetParent(console)
    Minimap:SetFrameStrata(console:GetFrameStrata())
    Minimap:SetFrameLevel(ns.levels.bars)
    Minimap:SetScale(1)
    -- w x h shown, from a square as big as the longer side; what the mask
    -- hides takes no clicks, pings or the wheel either
    local function Fit(w, h)
        local side = math.max(w, h)
        Minimap:SetSize(side, side)
        Minimap:SetHitRectInsets((side - w) / 2, (side - w) / 2, (side - h) / 2, (side - h) / 2)
        if not (mmCfg and mmCfg.square) then
            Minimap:SetMaskTexture(round)
        elseif w ~= h and mmCfg.bayMask then
            Minimap:SetMaskTexture(ns.media .. mmCfg.bayMask)
        else
            Minimap:SetMaskTexture(square)
        end
    end
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", console, "TOP", 0, -(top + bottom) / 2)
    Fit(size, mmCfg and mmCfg.square and (bottom - top) or size)
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
            local _, rx, rTop, rBottom = unpack(ns.windows.ring)
            local w = 2 * rx + 2 * ns.layout.minimapBleed
            local h = rBottom - rTop
            local corner = ns.MinimapInCorner()
            local inner = Corner()
            if Minimap.SetIgnoreParentAlpha then Minimap:SetIgnoreParentAlpha(corner) end
            Minimap:ClearAllPoints()
            if corner then
                Minimap:SetPoint("CENTER", bezel, "CENTER", 0, 0)
                Fit(inner, inner)
                bezel:Show()
            else
                Minimap:SetPoint("CENTER", console, "TOP", 0, -(rTop + rBottom) / 2)
                Fit(w, h)
                bezel:Hide()
            end
            if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
            if ns.UpdateBar7Visibility then ns.UpdateBar7Visibility(corner) end
        end
        ns.UpdateMinimapLocation = UpdateLocation
        ns.PlaceMinimap = UpdateLocation
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
        UpdateLocation()
    end

    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self:GetZoom() + (delta > 0 and 1 or -1)
        self:SetZoom(math.max(0, math.min(self:GetZoomLevels() - 1, zoom)))
    end)

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
end)
