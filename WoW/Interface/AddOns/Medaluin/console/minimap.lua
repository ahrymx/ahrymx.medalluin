-- The minimap moves into the ring: reparented to the console, masked round,
-- a touch larger than the hole so its edge tucks under the gold. Zoom is on
-- the mouse wheel. (The combat swap to the CC tracker comes later.)
local _, ns = ...

local console = ns.console

ns.On("PLAYER_LOGIN", function()
    local _, r, top, bottom = unpack(ns.windows.ring)
    local size = 2 * r + 2 * ns.layout.minimapBleed
    local mmCfg = ns.layout.minimap

    Minimap:SetParent(console)
    Minimap:SetFrameStrata(console:GetFrameStrata())
    Minimap:SetFrameLevel(ns.levels.bars)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", console, "TOP", 0, -(top + bottom) / 2)
    Minimap:SetSize(size, mmCfg and mmCfg.square and (bottom - top) or size)
    Minimap:SetScale(1)
    Minimap:SetMaskTexture(mmCfg and mmCfg.square
        and "Interface\\Buttons\\WHITE8X8"
        or "Interface\\CharacterFrame\\TempPortraitAlphaMask")

    if mmCfg and mmCfg.relocate then
        local bezel = CreateFrame("Frame", "MedaluinMinimapBezel", console)
        bezel:SetFrameLevel(ns.levels.art)
        bezel:SetSize(mmCfg.topRightSize, mmCfg.topRightSize)
        bezel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -mmCfg.topRightInset, -mmCfg.topRightInset)
        local bt = bezel:CreateTexture(nil, "ARTWORK")
        bt:SetAllPoints()
        bt:SetTexture(ns.media .. "minimap-light")
        bt:SetTexCoord(0, mmCfg.topRightSize / mmCfg.texWidth, 0, mmCfg.topRightSize / mmCfg.texHeight)
        bezel:Hide()
        ns.minimapBezel = bezel

        local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
        local function UpdateLocation()
            local _, rx, rTop, rBottom = unpack(ns.windows.ring)
            local w = 2 * rx + 2 * ns.layout.minimapBleed
            local h = rBottom - rTop
            local hasTarget = UnitExists and UnitExists("target") and true or false
            local relocated = inCombat or hasTarget or ns.skyriding or false
            Minimap:ClearAllPoints()
            if relocated then
                local trInner = mmCfg.topRightSize - 4
                Minimap:SetPoint("CENTER", bezel, "CENTER", 0, 0)
                Minimap:SetSize(trInner, trInner)
                bezel:Show()
            else
                Minimap:SetPoint("CENTER", console, "TOP", 0, -(rTop + rBottom) / 2)
                Minimap:SetSize(w, h)
                bezel:Hide()
            end
            if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
            if ns.UpdateBar7Visibility then ns.UpdateBar7Visibility(relocated) end
        end
        ns.UpdateMinimapLocation = UpdateLocation
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
