-- What the quest tracker (quests/tracker.lua) shows: the quests in the log
-- that are tracked, each with its zone heading, level, state, objectives
-- and usable item.
--
-- The game's own quest log is the source. Questie, when it is loaded and
-- ready, is asked too, so the two trackers agree: which quests are tracked
-- (Questie keeps its own set), the items its database knows a quest needs,
-- how far each quest's nearest objective is, and its quest log, focus and
-- arrow. Questie's tracker itself is left alone; its own options show it.
--
-- Questie is never needed. Its modules are its internals, not its API, so
-- every call is made through pcall, and a call that fails answers as if
-- Questie were not there.
local _, ns = ...

local Q = {}
ns.questSource = Q

-- A call that may fail: its first two answers, or nothing.
local function Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- Questie's modules, once it is ready; nothing otherwise.
local modules
local function Questie()
    if modules then return modules end
    local Q_ = _G.Questie
    if not (QuestieLoader and Q_ and Q_.API and Q_.API.isReady) then return end
    local function Import(name) return Try(QuestieLoader.ImportModule, QuestieLoader, name) end
    local tracker, utils, data = Import("QuestieTracker"), Import("TrackerUtils"), Import("TrackerData")
    if not (tracker and utils and data) then return end
    modules = { tracker = tracker, utils = utils, data = data, distance = Import("DistanceUtils") }
    return modules
end
Q.Questie = Questie

-- Questie's record of a quest, for its own calls.
local function Record(id)
    local m = Questie()
    return m and Try(m.data.GetQuest, id)
end

-- Questie keeps the tracked set only while its own tracker is on. Off, it
-- no longer hears the quest log's track box (its watch hooks return early),
-- so its set goes stale and the game's watch is the truth.
local function Keeps()
    local Q_ = _G.Questie
    local db = type(Q_) == "table" and type(Q_.db) == "table" and Q_.db
    local profile = db and type(db.profile) == "table" and db.profile
    return profile and profile.trackerEnabled and Questie() or nil
end

local function Tracked(id)
    local m = Keeps()
    if m then
        local on = Try(m.tracker.IsTrackedByQuestie, id)
        if on ~= nil then return on and true or false end
    end
    return C_QuestLog.GetQuestWatchType(id) ~= nil
end

-- The usable item: the game's own for the quest, else Questie's first.
local function Item(index, id, state)
    if GetQuestLogSpecialItemInfo then
        local link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(index)
        local item = link and tonumber(link:match("item:(%d+)"))
        if item and (state ~= 1 or showWhenComplete) then return item end
    end
    local m, record = Questie(), Record(id)
    if m and record then
        local items = Try(m.utils.GetQuestItemIds, record, state)
        if type(items) == "table" and items[1] then return items[1] end
    end
end

-- Questie can say how far each quest is: not when the last read that asked
-- measured none of them
local unmeasured
function Q.CanMeasure()
    local m = Questie()
    return not unmeasured and m and m.distance and m.distance.GetNearestSpawnForQuest and true or false
end

local function Distance(id)
    local m, record = Questie(), Record(id)
    if not (m and m.distance and record) then return end
    local _, _, _, distance = Try(m.distance.GetNearestSpawnForQuest, record)
    return type(distance) == "number" and distance or nil
end

-- The tracked quests, in the log's order: { id, index, title, level, zone,
-- state (1 complete, -1 failed, 0), objectives { text, done }, item, far }.
function Q.Read(measure)
    local out, zone, measured = {}, nil, false
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            zone = info.title
        elseif info and info.questID and not info.isHidden and Tracked(info.questID) then
            local id = info.questID
            local state = C_QuestLog.IsFailed(id) and -1 or C_QuestLog.IsComplete(id) and 1 or 0
            local objectives = {}
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                if o.text and o.text ~= "" then table.insert(objectives, { text = o.text, done = o.finished }) end
            end
            table.insert(out, { id = id, index = index, title = info.title, level = info.level or 0,
                zone = zone or "Other", state = state, objectives = objectives, item = Item(index, id, state),
                far = measure and Distance(id) or nil })
            measured = measured or out[#out].far ~= nil
        end
    end
    if measure then unmeasured = #out > 0 and not measured end
    return out
end

-- -------------------------------------------------------------- actions
-- The quest in the quest log: Questie's way when it is there (it knows the
-- log addons), the game's otherwise; not in combat.
function Q.Show(quest)
    local m, record = Questie(), Record(quest.id)
    if m and record and pcall(m.utils.ShowQuestLog, m.utils, record) then return end
    if InCombatLockdown() then return end
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(quest.id)
    elseif QuestLogFrame then
        C_QuestLog.SetSelectedQuest(quest.id)
        ShowUIPanel(QuestLogFrame)
    end
end

-- Questie's focus on the quest and its arrow to it; false when it cannot
function Q.Focus(quest)
    local m = Questie()
    if not (m and pcall(m.utils.FocusQuest, m.utils, quest.id)) then return false end
    Try(m.utils.SetQuestTomTomTarget, quest.id)
    return true
end

-- No longer tracked: Questie's untrack when Questie keeps the set and tracks
-- it, the game's watch otherwise.
function Q.Untrack(quest)
    local m = Keeps()
    if m and Try(m.tracker.IsTrackedByQuestie, quest.id) then
        Try(m.tracker.UntrackQuestId, m.tracker, quest.id)
    elseif C_QuestLog.GetQuestWatchType(quest.id) ~= nil then
        C_QuestLog.RemoveQuestWatch(quest.id)
    end
end

-- -------------------------------------------------------------- changes
-- fn() whenever what Read returns may have changed: the game's quest
-- events, and Questie's own updates (its tracked set lives in Questie).
function Q.Listen(fn)
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED",
        "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED" }) do
        ns.On(e, fn)
    end
    local Q_ = _G.Questie
    if Q_ and Q_.API and Q_.API.RegisterOnReady then
        Try(Q_.API.RegisterOnReady, function()
            modules, unmeasured = nil, nil
            Try(Q_.API.RegisterForQuestUpdates, function() fn() end)
            local m = Questie()
            if m then Try(hooksecurefunc, m.tracker, "Update", function() fn() end) end
            fn()
        end)
    end
end
