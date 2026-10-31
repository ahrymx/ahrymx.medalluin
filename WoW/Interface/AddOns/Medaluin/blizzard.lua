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
end)
