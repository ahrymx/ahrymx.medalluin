-- Gossip, in the NPC box (npc/window.lua): what the NPC says, then the
-- quests it has for you and the quests it takes back, each with the
-- tracker's mark (ns.QuestMark), then what you can say to it, each with
-- the game's own gossip icon.
--
--   Who is this shaman who goes before the Court of Lakeshire ...
--   ------------- Quests -------------
--   ? WANTED: Gath'Ilzogg                    <- ready to hand in
--   ! Messenger to Westfall                  <- to take (blue: a daily)
--   ------------- Options -------------
--   [icon] I would like to train.
--                                        [Goodbye]
--
-- The quests and options are numbered, and the keys 1 to 0, - and = pick
-- them (npc/window.lua, the keys).
--
-- Everything is asked of C_GossipInfo; a click picks the quest or option
-- there, and the game answers with the next page (a quest's opens the
-- quest pages, npc/quest.lua).
local _, ns = ...

local G = C_GossipInfo
if not G then return end
local MARK = 16

local function Mark(q, ready, taken)
    return ns.QuestMark and ns.QuestMark({ state = ready and 1 or 0, incomplete = taken and not ready,
        daily = (q.frequency or 0) > 0 }, MARK)
end

local function Blocks()
    local out = { { "text", G.GetText() or "" } }
    local quests = {}
    for _, q in ipairs(G.GetActiveQuests and G.GetActiveQuests() or {}) do
        table.insert(quests, { "row", label = q.title, badge = Mark(q, q.isComplete, true), dim = q.isTrivial,
            click = function() G.SelectActiveQuest(q.questID) end })
    end
    for _, q in ipairs(G.GetAvailableQuests and G.GetAvailableQuests() or {}) do
        table.insert(quests, { "row", label = q.title, badge = Mark(q), dim = q.isTrivial,
            click = function() G.SelectAvailableQuest(q.questID) end })
    end
    if #quests > 0 then
        table.insert(out, { "heading", "Quests" })
        for _, r in ipairs(quests) do table.insert(out, r) end
    end
    local options = G.GetOptions and G.GetOptions() or {}
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    if #options > 0 then
        table.insert(out, { "heading", "Options" })
        for _, o in ipairs(options) do
            table.insert(out, { "row", label = o.name, icon = o.icon,
                click = function() G.SelectOption(o.gossipOptionID or o.orderIndex) end })
        end
    end
    return out
end

local function Close() G.CloseGossip() end

ns.npc.Page{
    key = "gossip", frame = "GossipFrame", keys = true,
    Blocks = Blocks,
    Foot = function() return { { label = "Goodbye", click = Close } } end,
    Close = Close,
    Start = function()
        ns.On("GOSSIP_SHOW", function() ns.npc.Show("gossip") end)
        ns.On("GOSSIP_CLOSED", ns.npc.Sync)
        ns.On("QUEST_LOG_UPDATE", function() ns.npc.Update("gossip") end)
    end,
}
