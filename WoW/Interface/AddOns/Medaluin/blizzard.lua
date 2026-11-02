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
    -- boss frames: the overhead's, the Boss widget's (widgets/enemies.lua), or both
    if ns.db.bossFrames ~= "overhead" or ns.db.overhead ~= false then
        for i = 1, 5 do
            ns.Kill(_G["Boss" .. i .. "TargetFrame"])
        end
    end

    if ns.db and ns.db.overhead ~= false then
        if ns.db.topPet ~= false then ns.Kill(PetFrame) end
        if ns.db.topFocus ~= false then ns.Kill(FocusFrame) end
        if ns.db.topToT ~= false then ns.Kill(TargetFrameToT) end
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

-- Blizzard's buff and debuff rows (top right), hidden unless the Unit Frames
-- page's option asks for them: the console's own auras (the portrait's
-- column, the side panel's Auras tab) show the same. Hidden by the hidden
-- parent, not by Hide(): Edit Mode shows them again whenever it updates
-- (AuraFrameEditModeMixin:UpdateShownState). Not Park: they must come
-- back to UIParent when the option is turned on. Classic Era keeps its
-- weapon enchants in a frame of their own.
local AURA_ROWS = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }
local function BlizzardAuras(show)
    ns.OutOfCombat(function()
        for _, name in ipairs(AURA_ROWS) do
            local frame = _G[name]
            if frame then frame:SetParent(show and UIParent or ns.hidden) end
        end
    end)
end
-- left alone at login when shown: they are where Blizzard put them
ns.On("PLAYER_LOGIN", function()
    if not ns.db.blizzardAuras then BlizzardAuras(false) end
end)
ns.OnSetting("blizzardAuras", BlizzardAuras)
