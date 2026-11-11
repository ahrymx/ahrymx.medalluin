-- The leave-vehicle seat, in the right strip's medallion: while a vehicle can
-- be left (or a flight path cut short), it sits over the backpack's well and
-- the backpack steps aside, as the queue eye takes the portrait's on the left
-- (strips/micro.lua). When it goes, the backpack comes back.
--
-- It is Blizzard's own button (MainMenuBarVehicleLeaveButton), so its rules
-- stay Blizzard's: it shows itself when CanExitVehicle says so and the main
-- bar is up (a vehicle with its own override bar has that bar's leave button
-- instead), its click is VehicleExit or the early landing, its tooltip is
-- Blizzard's. It is not secure, so it shows and hides in combat too. It
-- lives on MainActionBar, which Medalluin takes apart (bars/buttons.lua), so
-- without this it would never be seen; and its Edit Mode system places it
-- again, which is answered after the fact, as the backpack's BagsBar is.
--
-- Blizzard's art is a square crop of a framed button; the well is round, so
-- the seat wears its own (art/strips/gen_strips.py's leave: a crimson disc,
-- a gold door and the arrow out of it), greyed while a landing is on its way.
local _, ns = ...

local ART = ns.media .. "strips\\leave"

local seat
local placing, styling = false, false

-- Over the backpack, in the same well, a level above it (and still below
-- the strip's art, so the ring covers its edge).
local function Place()
    if placing then return end
    placing = true
    local w = ns.stripWell
    seat:SetParent(ns.strips[1])
    seat:SetFrameLevel(ns.levels.stripWell + 1)
    seat:SetScale(1)
    ns.OnStrip(seat, 1, w.x, w.y, w.size, w.size)
    placing = false
end

-- The backpack steps aside while the seat is up: hidden by its alpha, not by
-- Hide, which BagsBar would undo. The seat over it takes the mouse.
local function Swap()
    local pack = MainMenuBarBackpackButton
    if pack then pack:SetAlpha(seat:IsShown() and 0 or 1) end
end

local function Art(t, shade, grey)
    t:ClearAllPoints()
    t:SetAllPoints()
    t:SetTexture(ART)
    t:SetTexCoord(0, 1, 0, 1)                  -- Blizzard's crop is on the XML's textures
    t:SetVertexColor(shade, shade, shade)
    t:SetDesaturated(grey)
end

-- Our states, put back after Blizzard's own (its Update and its click set a
-- square highlight of theirs on every change).
local glow
local function Style()
    if styling then return end
    styling = true
    -- Blizzard's XML gives it a normal and a pushed texture, not a disabled one
    Art(seat:GetNormalTexture(), 1, false)
    Art(seat:GetPushedTexture(), 0.7, false)
    seat:SetDisabledTexture(ART)
    Art(seat:GetDisabledTexture(), 0.8, true)
    seat:SetHighlightTexture(glow)
    glow:ClearAllPoints()
    glow:SetAllPoints()
    glow:SetTexture(ns.media .. "strips\\round")
    glow:SetTexCoord(0, 1, 0, 1)
    glow:SetVertexColor(1, 0.9, 0.6)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.18)
    styling = false
end

-- A possessed unit or a remote control (the Darkmoon Faire's Steam Tonk, a
-- channelled "Using Control Console", 2026-11-11) is no vehicle: the game's
-- way out is the possess bar's cancel, by the chat. The seat is that way out
-- too, and the possess bar goes.
local function Possessed()
    local f = C_ActionBar and C_ActionBar.IsPossessBarVisible or IsPossessBarVisible
    return f and f() and true or false
end

-- Blizzard's shows it only while the main bar is up: a vehicle with a skinned
-- bar (the Darkmoon Faire's) gets the override bar's leave button instead,
-- whose bar Medalluin's bar 1 stands in for, so there was no way out
-- (2026-11-11). Here it shows whenever the vehicle can be left, or the
-- possession cancelled; Blizzard's rule shows it only where this one does.
local function Leave()
    if not seat or seat.isInEditMode then return end
    local want = (CanExitVehicle and CanExitVehicle()) or Possessed()
    if want and not seat:IsShown() then
        seat:Show()
        seat:Enable()
    elseif not want and seat:IsShown() then
        seat:Hide()
    end
end

-- After Blizzard's click, which lands a flight or leaves a vehicle: a
-- possession is cancelled, as the possess bar's cancel does
local function Cancel()
    if (UnitOnTaxi and UnitOnTaxi("player")) or (CanExitVehicle and CanExitVehicle()) then return end
    if Possessed() and CancelPetPossess then CancelPetPossess() end
end

local function Setup()
    if seat then return end
    seat = MainMenuBarVehicleLeaveButton
    if not seat then return end                -- Classic Era: no vehicles
    glow = ns.RoundGlow(seat, 1, 0.9, 0.6, 0.18)
    Place()
    Style()
    hooksecurefunc(seat, "SetPoint", Place)
    hooksecurefunc(seat, "SetScale", Place)
    hooksecurefunc(seat, "SetParent", function(_, parent)
        if parent ~= ns.strips[1] then Place() end
    end)
    for _, method in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture",
        "SetHighlightTexture" }) do
        hooksecurefunc(seat, method, Style)
    end
    -- Blizzard anchors its tooltip to the right, past the screen's edge here
    seat:HookScript("OnEnter", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 4)
        end
    end)
    seat:HookScript("OnShow", Swap)
    seat:HookScript("OnHide", Swap)
    seat:HookScript("OnClick", Cancel)
    if PossessActionBar then ns.OutOfCombat(function() ns.Park(PossessActionBar) end) end
    -- after Blizzard's pass, whichever this client has
    if seat.UpdateShownState then hooksecurefunc(seat, "UpdateShownState", Leave)
    elseif seat.Update then hooksecurefunc(seat, "Update", Leave) end
    if MainMenuBarVehicleLeaveButton_Update then hooksecurefunc("MainMenuBarVehicleLeaveButton_Update", Leave) end
    Leave()
    Swap()
end

-- After strips/bags.lua has placed the backpack (both wait for login).
ns.On("PLAYER_LOGIN", Setup)
for _, event in ipairs({ "UPDATE_POSSESS_BAR", "UPDATE_BONUS_ACTIONBAR", "UNIT_PET", "PET_BAR_UPDATE",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "VEHICLE_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, Leave)
end
