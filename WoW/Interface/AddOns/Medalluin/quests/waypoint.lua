-- The waypoint: the one quest the game points you to (its super-tracked
-- quest: the marker in the world and on the map), shared by the quest
-- tracker, the quest log and the Zone tab (strips/zone.lua). Ctrl-click on
-- a quest in any of them sets it there; on the quest that has it, clears it.
-- The game keeps one, so setting it here moves it from wherever it was,
-- and the game's own map moves it too.
--
-- The quest that has it is washed in blue in each, its distance in blue
-- after its title ("142 yd"): the game's navigation distance while it
-- points at the quest, else how far the quest's area is (nothing when the
-- game knows no place for it, "far" off this continent).
--
--   W.Quest()           its quest's id, or nil
--   W.Is(id)            whether the quest has it
--   W.Toggle(quest)     set to it, or cleared when it has it
--   W.Distance(id)      the text of its distance ("142 yd", "far", or "")
--   W.Tag(id)           the same in its colour, after two spaces (or "")
--   W.OnChange(fn)      fn() when it moves or clears
--   W.OnTick(fn)        fn() twice a second while there is one: the distance
--   W.WASH, W.COLOR     the wash ({ r, g, b, a }) and the text's colour
--
-- Retail's and Forever's (C_SuperTrack). A client without it has none:
-- Toggle does nothing, Quest is nil.
local _, ns = ...

local W = {
    WASH = { 0.35, 0.67, 1.00, 0.20 },
    COLOR = { 0.59, 0.78, 1.00 },
}
ns.waypoint = W

local HEX = "|cff96c8ff"
local TICK = 0.5
local changed, ticked = {}, {}

local function Has() return C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and true or false end
W.Has = Has

function W.Quest()
    if not Has() then return nil end
    local id = C_SuperTrack.GetSuperTrackedQuestID()
    if not id or ns.IsSecret(id) or id == 0 then return nil end
    return id
end

function W.Is(id)
    return id ~= nil and W.Quest() == id
end

function W.Toggle(quest)
    if not Has() then return end
    C_SuperTrack.SetSuperTrackedQuestID(W.Is(quest.id) and 0 or quest.id)
end

-- yards, or "far" (another continent), or nil (no place known)
local function Yards(id)
    local N = C_Navigation
    if W.Is(id) and N and N.GetDistance and C_SuperTrack.IsSuperTrackingQuest
        and C_SuperTrack.IsSuperTrackingQuest() then
        local d = N.GetDistance()
        if d and not ns.IsSecret(d) and d > 0 then return d end
    end
    local sq = C_QuestLog and C_QuestLog.GetDistanceSqToQuest
    if not sq then return nil end
    local d2, near = sq(id)
    if not d2 or ns.IsSecret(d2) or ns.IsSecret(near) then return nil end
    if not near then return "far" end
    return math.sqrt(d2)
end

function W.Distance(id)
    local d = Yards(id)
    if d == "far" then return "far" end
    if not d then return "" end
    if d >= 10000 then return string.format("%.0fk yd", d / 1000) end
    return string.format("%d yd", d)
end

function W.Tag(id)
    local s = W.Distance(id)
    return s ~= "" and ("  " .. HEX .. s .. "|r") or ""
end

function W.OnChange(fn) table.insert(changed, fn) end
function W.OnTick(fn) table.insert(ticked, fn) end

local clock = CreateFrame("Frame")
clock:Hide()
W.clock = clock                  -- (the harness's way in)
local wait = 0
clock:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = TICK
    for _, fn in ipairs(ticked) do fn() end
end)

local function Changed()
    clock:SetShown(W.Quest() ~= nil)
    for _, fn in ipairs(changed) do fn() end
end

ns.On("SUPER_TRACKING_CHANGED", Changed)
ns.On("PLAYER_ENTERING_WORLD", Changed)
