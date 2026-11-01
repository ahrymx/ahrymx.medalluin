-- Retire the Blizzard frames the console replaces.
local _, ns = ...

ns.On("PLAYER_LOGIN", function()
    ns.Kill(PlayerFrame)
    ns.Kill(TargetFrame)        -- ComboFrame is its child and goes with it
    ns.Kill(PartyFrame)         -- newer clients group the party frames here
    for i = 1, 4 do
        ns.Kill(_G["PartyMemberFrame" .. i])
    end
    ns.Kill(CompactPartyFrame)

    if ns.db and ns.db.overhead ~= false then
        if ns.db.topPet ~= false then ns.Kill(PetFrame) end
        if ns.db.topFocus ~= false then ns.Kill(FocusFrame) end
        if ns.db.topToT ~= false then ns.Kill(TargetFrameToT) end
        if ns.db.topBoss ~= false then
            for i = 1, 5 do
                ns.Kill(_G["Boss" .. i .. "TargetFrame"])
            end
        end
        -- parked, not killed: their events give the adopted buttons their icons
        if ns.db.topStances ~= false then
            ns.Park(StanceBar)
            ns.Park(ShapeshiftBarFrame)
        end
        if ns.db.topPetBar ~= false then
            ns.Park(PetActionBar)
            ns.Park(PetActionBarFrame)
        end
    end
    -- The stance and pet bars and the other action bars stay Blizzard's,
    -- placed by Edit Mode; bars/buttons.lua takes action bar 1 when its
    -- option is on, and retires the main bar with it, and bars/cast.lua
    -- retires the player's cast bar. On
    -- Forever and retail the micro menu, bags and XP bars are frames of their
    -- own; strips/ moves the buttons it keeps out of them, just after this on
    -- the same event. Secure frames only move out of combat.
    ns.OutOfCombat(function()
        ns.Kill(MicroButtonAndBagsBar)
        ns.Kill(MicroMenuContainer)
        ns.Kill(BagsBar)
        ns.Kill(StatusTrackingBarManager)   -- the XP and reputation bars
        ns.Kill(MainStatusTrackingBarContainer)
        ns.Kill(SecondaryStatusTrackingBarContainer)
    end)
end)
