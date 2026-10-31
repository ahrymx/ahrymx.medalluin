-- The minimap moves into the ring: reparented to the console, masked round,
-- a touch larger than the hole so its edge tucks under the gold. Zoom is on
-- the mouse wheel. (The combat swap to the CC tracker comes later.)
local _, ns = ...

local console = ns.console

ns.On("PLAYER_LOGIN", function()
    local _, r, top, bottom = unpack(ns.windows.ring)
    local size = 2 * r + 2 * ns.layout.minimapBleed

    Minimap:SetParent(console)
    Minimap:SetFrameStrata(console:GetFrameStrata())
    Minimap:SetFrameLevel(ns.levels.bars)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", console, "TOP", 0, -(top + bottom) / 2)
    Minimap:SetSize(size, size)
    Minimap:SetScale(1)
    Minimap:SetMaskTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")

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
        "MinimapNorthTag", "MinimapCompassTexture", "GameTimeFrame", "TimeManagerClockButton" }) do
        local f = _G[name]
        if f then
            if f.UnregisterAllEvents then f:UnregisterAllEvents() end
            f:SetParent(ns.hidden)
        end
    end
    ns.Kill(MinimapCluster)
end)
