-- What the quest tracker (quests/tracker.lua) shows: the quests in the log
-- that are tracked, each with its zone heading, level, state, objectives
-- and usable item.
--
-- The game's own quest log is the source. Questie, when it is loaded and
-- ready, is asked too, so the two trackers agree: which quests are tracked
-- (Questie keeps its own set), the items its database knows a quest needs,
-- and its quest log, focus and arrow. Questie's tracker itself is left
-- alone; its own options show it.
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
    modules = { tracker = tracker, utils = utils, data = data }
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

-- What sort of quest: "dungeon" (a dungeon's or a raid's), "group" (for a
-- group, or elite), or nothing. The tag is the game's: C_QuestLog's where
-- the client has it, the global's otherwise.
-- raid, dungeon, heroic, raid 10 and 25
local INSTANCE = { [62] = true, [81] = true, [85] = true, [88] = true, [89] = true }
local function Kind(id, info)
    local tag, elite
    if C_QuestLog.GetQuestTagInfo then
        local t = C_QuestLog.GetQuestTagInfo(id)
        tag, elite = t and t.tagID, t and t.isElite
    elseif GetQuestTagInfo then
        tag = GetQuestTagInfo(id)
    end
    if INSTANCE[tag] then return "dungeon" end
    if tag == 1 or elite or (info.suggestedGroup or 0) > 1 then return "group" end
end

-- The quests that keep(id) takes, in the log's order: { id, index, title,
-- level, zone, state (1 complete, -1 failed, 0), objectives { text, done },
-- item, daily (daily or weekly), kind (Kind's) }.
local function Walk(keep)
    local out, zone = {}, nil
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            zone = info.title
        elseif info and info.questID and not info.isHidden and keep(info.questID) then
            local id = info.questID
            local state = C_QuestLog.IsFailed(id) and -1 or C_QuestLog.IsComplete(id) and 1 or 0
            local objectives = {}
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                if o.text and o.text ~= "" then table.insert(objectives, { text = o.text, done = o.finished }) end
            end
            table.insert(out, { id = id, index = index, title = info.title, level = info.level or 0,
                zone = zone or "Other", state = state, objectives = objectives, item = Item(index, id, state),
                daily = (info.frequency or 0) > 0, kind = Kind(id, info) })
        end
    end
    return out
end

-- The tracked quests (the tracker's).
function Q.Read() return Walk(Tracked) end

-- ---------------------------------------------------------- the whole log
-- The quest log's reward calls read the quest it has selected (Classic's
-- take no quest at all; retail's take the id too): so the quest is selected
-- for them, and the selection put back after.
local function Selected()
    if C_QuestLog.GetSelectedQuest then return C_QuestLog.GetSelectedQuest() end
    return GetQuestLogSelection and GetQuestLogSelection()
end

local function Select(q)
    if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(q.id) end
    if SelectQuestLogEntry then SelectQuestLogEntry(q.index) end
end

local function Restore(was)
    if not was then return end
    if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(was) end
    if SelectQuestLogEntry and not C_QuestLog.GetSelectedQuest then SelectQuestLogEntry(was) end
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

-- What a quest gives: xp, money (copper), items (any to have or to choose).
-- They do not change while the quest is in the log, but for the xp as the
-- player levels, so they are kept until then.
local rewards = {}
local function Rewards(q)
    local r = rewards[q.id]
    if r then return r end
    local was = Selected()
    Select(q)
    local given = Call(GetNumQuestLogRewards, q.id) or 0
    local chosen = Call(GetNumQuestLogChoices, q.id) or 0
    r = { xp = Call(GetQuestLogRewardXP, q.id) or 0, money = Call(GetQuestLogRewardMoney, q.id) or 0,
        items = given + chosen > 0 }
    Restore(was)
    rewards[q.id] = r
    return r
end
ns.On("PLAYER_LEVEL_UP", function() wipe(rewards) end)
local details

-- Every quest in the log, each as Read's, with tracked and rewards.
function Q.All()
    local out = Walk(function() return true end)
    for _, q in ipairs(out) do
        q.tracked = Tracked(q.id)
        q.rewards = Rewards(q)
    end
    return out
end

-- Every quest in the log, each as Read's, with tracked: All's without the
-- rewards, which select each quest in turn (the side panel's Zone tab,
-- strips/zone.lua, reads it on every change).
function Q.Log()
    local out = Walk(function() return true end)
    for _, q in ipairs(out) do q.tracked = Tracked(q.id) end
    return out
end

-- A quest's page: { text, goal (the objectives' summary), given, chosen },
-- each reward item { name, icon, count, quality, link, index, type }. Kept
-- as the rewards are: selecting a quest may tell the log it changed, and
-- the page drawn again must not select it again.
details = {}
function Q.Details(q)
    if details[q.id] then return details[q.id] end
    local was = Selected()
    Select(q)
    local d = { given = {}, chosen = {} }
    if GetQuestLogQuestText then d.text, d.goal = GetQuestLogQuestText(q.index) end
    local kinds = { { "given", GetNumQuestLogRewards, "reward" }, { "chosen", GetNumQuestLogChoices, "choice" } }
    for _, kind in ipairs(kinds) do
        for i = 1, Call(kind[2], q.id) or 0 do
            local name, icon, count, quality
            if kind[3] == "reward" then
                name, icon, count, quality = Call(GetQuestLogRewardInfo, i, q.id)
            else
                name, icon, count, quality = Call(GetQuestLogChoiceInfo, i, q.id)
            end
            if name then
                table.insert(d[kind[1]], { name = name, icon = icon, count = count or 1, quality = quality,
                    link = Call(GetQuestLogItemLink, kind[3], i, q.id), index = i, type = kind[3] })
            end
        end
    end
    Restore(was)
    details[q.id] = d
    return d
end

-- -------------------------------------------------------------- actions
-- The quest's page: Medalluin's own (quests/page.lua) while its quest log
-- is on; else the quest log, Questie's way when it is there (it knows the
-- log addons), the game's otherwise; not in combat.
function Q.Show(quest)
    if ns.questPage and ns.questLog and ns.questLog.On() then
        ns.questPage.Open(quest.id)
        return
    end
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

-- ------------------------------------------------------------- the map
-- A zone's map, by its name (the log's heading for the quest): every map
-- under the world the player is in, a zone's first. Kept once read from
-- the whole world; read again while only a continent's (or less) is known.
local maps, whole
local function MapByName(name)
    if not (name and C_Map and C_Map.GetMapChildrenInfo) then return end
    if not whole then
        local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            or C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID()
        if not here then return end
        local top = here
        local T = Enum and Enum.UIMapType
        if MapUtil and MapUtil.GetMapParentInfo and T then
            local world = MapUtil.GetMapParentInfo(here, T.Cosmic, true)
                or MapUtil.GetMapParentInfo(here, T.World, true)
            local info = world or MapUtil.GetMapParentInfo(here, T.Continent, true)
            if info and info.mapID then top = info.mapID end
            whole = world ~= nil
        end
        maps = {}
        local zone = T and T.Zone
        for _, m in ipairs(C_Map.GetMapChildrenInfo(top, nil, true) or {}) do
            local had = maps[m.name]
            if m.name and (not had or (m.mapType == zone and had.mapType ~= zone)) then maps[m.name] = m end
        end
    end
    return maps[name] and maps[name].mapID
end

-- The quest's map: the game's own for it (retail), else its zone's.
function Q.MapOf(quest)
    local id = GetQuestUiMapID and Try(GetQuestUiMapID, quest.id)
    if id and id > 0 then return id end
    return MapByName(quest.zone)
end

-- Questie's places for the quest: its objectives not yet done, or, ready
-- to hand in, who takes it; nil when it knows none.
local function Places(quest)
    local m, record = Questie(), Record(quest.id)
    if not (m and record) then return end
    if quest.state == 1 then
        if record.Finisher and m.utils.ShowFinisherOnMap then return m, record end
        return
    end
    local list = {}
    for _, set in ipairs({ record.Objectives or {}, record.SpecialObjectives or {} }) do
        for _, o in pairs(set) do
            if type(o) == "table" and not o.Completed and type(o.spawnList) == "table" and next(o.spawnList) then
                table.insert(list, o)
            end
        end
    end
    if #list > 0 then return m, nil, list end
end

-- Whether the map can show it.
function Q.CanMap(quest)
    return Places(quest) ~= nil or Q.MapOf(quest) ~= nil
end

-- The world map at the quest: Questie's way when it knows the places (the
-- nearest's zone, its icons flashing), else the quest's map (retail pings
-- the quest on it). True when the map was opened.
function Q.ShowOnMap(quest)
    local m, finisher, list = Places(quest)
    local u = m and m.utils
    if finisher and pcall(u.ShowFinisherOnMap, u, finisher) then return true end
    if list then
        local ok
        if u.ShowQuestObjectivesOnMap then
            ok = pcall(u.ShowQuestObjectivesOnMap, u, list)
        else
            ok = pcall(u.ShowObjectiveOnMap, u, list[1])
        end
        if ok then return true end
    end
    local id = Q.MapOf(quest)
    if not (id and WorldMapFrame) then return false end
    if OpenWorldMap then
        OpenWorldMap(id)
    else
        if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
        WorldMapFrame:SetMapID(id)
    end
    if WorldMapFrame.PingQuestID then Try(WorldMapFrame.PingQuestID, WorldMapFrame, quest.id) end
    return true
end

-- How many quests the game lets be watched at once (none known: no limit).
function Q.WatchLimit()
    if C_QuestLog.GetMaxNumQuestsCanWatch then return C_QuestLog.GetMaxNumQuestsCanWatch() end
    return MAX_WATCHABLE_QUESTS
end

-- How many the game watches now.
local function Watched()
    if C_QuestLog.GetNumQuestWatches then return C_QuestLog.GetNumQuestWatches() end
    if GetNumQuestWatches then return GetNumQuestWatches() end
    local n = 0
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then n = n + 1 end
    end
    return n
end

-- Tracked by the game's watch, which Questie hears too while it keeps its
-- own set (its watch hooks); false when the game's limit is reached.
function Q.Track(quest)
    if Tracked(quest.id) then return true end
    local limit = Q.WatchLimit()
    if limit and Watched() >= limit then return false end
    if C_QuestLog.AddQuestWatch then
        C_QuestLog.AddQuestWatch(quest.id)
    elseif AddQuestWatch then
        AddQuestWatch(quest.index)
    end
    return true
end

Q.Tracked = Tracked

-- The quests abandoned, one by one: each selected, marked and dropped. The
-- log's indices move as quests go, so each is found again by its id.
local function Index(id)
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID == id then return index end
    end
end

function Q.Abandon(ids)
    for _, id in ipairs(ids) do
        local index = Index(id)
        if index then
            if C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
                C_QuestLog.SetSelectedQuest(id)
                C_QuestLog.SetAbandonQuest()
                C_QuestLog.AbandonQuest()
            elseif SetAbandonQuest and AbandonQuest then
                if SelectQuestLogEntry then SelectQuestLogEntry(index) end
                if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id) end
                SetAbandonQuest()
                AbandonQuest()
            end
            rewards[id] = nil
            details[id] = nil
        end
    end
end

-- Whether a quest can be shared now, and its sharing.
function Q.CanShare(quest)
    if not (IsInGroup and IsInGroup()) then return false end
    if C_QuestLog.IsPushableQuest then return C_QuestLog.IsPushableQuest(quest.id) and true or false end
    if GetQuestLogPushable then
        local was = Selected()
        Select(quest)
        local can = GetQuestLogPushable()
        Restore(was)
        return can and true or false
    end
    return false
end

function Q.Share(quest)
    local was = Selected()
    Select(quest)
    if QuestLogPushQuest then QuestLogPushQuest() end
    Restore(was)
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
            modules = nil
            Try(Q_.API.RegisterForQuestUpdates, function() fn() end)
            local m = Questie()
            if m then Try(hooksecurefunc, m.tracker, "Update", function() fn() end) end
            fn()
        end)
    end
end
