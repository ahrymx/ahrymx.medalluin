-- Who gave each quest: the quest's page (quests/page.lua) names them. The
-- game keeps no record of it, so it is noted as the quest is offered (the
-- NPC whose quest text is open) and kept as it is accepted, by the quest's
-- id, in MedalluinDB.questGivers; forgotten as it is handed in. A quest
-- from an item, or accepted before this, has none.
--
--   ns.questGivers.Of(id)   the giver's name, or nil
local _, ns = ...

local G = {}
ns.questGivers = G

local FRESH = 10                -- seconds: an offer older than this is not the one accepted
local offered, at

local function Kept()
    if not MedalluinDB then return {} end
    MedalluinDB.questGivers = type(MedalluinDB.questGivers) == "table" and MedalluinDB.questGivers or {}
    return MedalluinDB.questGivers
end

function G.Of(id)
    return id and Kept()[id] or nil
end

local function Now() return GetTime and GetTime() or 0 end

ns.On("QUEST_DETAIL", function()
    local name = UnitName("questnpc") or UnitName("npc")
    -- (an item's quest offers itself as the player)
    if name and not ns.IsSecret(name) and name ~= UnitName("player") then
        offered, at = name, Now()
    else
        offered = nil
    end
end)

-- the quest's id: the last argument (a client may send its log index first)
ns.On("QUEST_ACCEPTED", function(_, ...)
    local id = select(select("#", ...), ...)
    if type(id) ~= "number" or ns.IsSecret(id) then return end
    if offered and Now() - (at or 0) <= FRESH then Kept()[id] = offered end
    offered = nil
end)

ns.On("QUEST_TURNED_IN", function(_, id)
    if type(id) == "number" and not ns.IsSecret(id) then Kept()[id] = nil end
end)
