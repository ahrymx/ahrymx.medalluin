-- The group finder's and Who's data, read from the game and acted on, for
-- the LFG / Who window (social/lfg.lua). Shaped on Blizzard's own Forever
-- group finder (Blizzard_GroupFinder_VanillaStyle, loaded on demand: the
-- window loads it at login):
--
--   listing   C_LFGList.CreateListing{ activityIDs, newPlayerFriendly,
--             generalPlaystyle, voiceMode } (UpdateListing: the same but
--             the playstyle, which a listing keeps); a playstyle is
--             required. The note is not in it: the game reads it from
--             Blizzard's own box (LFGListingComment, a secure reference
--             whose SetText addons cannot call), which the window hosts.
--   roles     solo: C_LFGListRoles; in a group: the role you are
--             assigned (UnitSetRole). Only a solo player or the group's
--             leader lists.
--   search    Search(category, 0, 0, nil, false, nil, activityIDs), one at a
--             time; a result of one is a player, of more a group. It is
--             restricted: the game runs it only straight from a click or
--             a key, and refuses it otherwise (ADDON_ACTION_BLOCKED, the
--             call quietly dropped). A pick in a dropdown does not count:
--             the game refused one on 2026-11-09, and again on 2026-11-12
--             (searching from a pick's click was tried that day). Picks
--             changed, a search refused, or one asked for while one was
--             out, the list is stale (D.stale) and waits for a click
--             (Browse's Search). A click runs
--             one restricted call: List me's posts, and Browse waits for
--             Search (2026-11-12: the search after it was refused).
--             A result the game keeps secret (every field but its
--             partyGUID, the modern client in an instance or a fight) is
--             not read: counted in D.hidden, and the list says so.
--   who       SendWho(text, origin, { classIDs, raceIDs, uiMapIDs }),
--             SortWho(mode, ascending); the server answers 50 at most.
--
-- Retail's Group Finder is another thing (premade groups, protected
-- calls) and stays the game's: D.Has() is false there, and only Who is
-- ours. Every call is asked for before it is made. /mdlui lfgdump prints
-- what this client has, and one result as it comes.
local ADDON, ns = ...

local D = { results = {}, searching = false, hidden = 0,
    who = { list = {}, total = 0, pending = false, query = "" } }
ns.lfgData = D

local listeners = {}
function D.Listen(fn) table.insert(listeners, fn) end
local function Changed()
    for _, fn in ipairs(listeners) do fn() end
end
D.Changed = Changed

local function L() return C_LFGList end

-- Forever's tool: C_LFGList without retail's Group Finder
function D.Has()
    local api = L()
    return api and api.GetAvailableCategories and api.Search and api.CreateListing and not PVEFrame
        and not GroupFinderFrame and true or false
end

-- Blizzard's own window, loaded on demand: its frames, its note box and
-- its helpers (LFGUtil_GetFilteredActivities)
D.ADDON = "Blizzard_GroupFinder_VanillaStyle"
function D.Load()
    if not D.Has() then return false end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(D.ADDON)
    if not loaded and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, D.ADDON) end
    return _G.LFGParentFrame ~= nil
end

-- --------------------------------------------------------- playstyles, voice
local PS = Enum and Enum.LFGEntryGeneralPlaystyle or {}
D.PLAYSTYLES = {
    { value = PS.Learning or 1, name = "Learning", color = { 0.47, 0.75, 1 } },
    { value = PS.FunRelaxed or 2, name = "Relaxed", color = { 0.43, 0.78, 0.35 } },
    { value = PS.FunSerious or 3, name = "Competitive", color = { 1, 0.67, 0.24 } },
    { value = PS.Expert or 4, name = "Carry offered", color = { 0.78, 0.55, 1 } },
}
local function Playstyle(v)
    for _, p in ipairs(D.PLAYSTYLES) do if p.value == v then return p end end
end
function D.PlaystyleName(v)
    if not v or v == 0 then return nil end
    local ok, s = pcall(function() return GetGeneralPlaystyleString and GetGeneralPlaystyleString(v) end)
    if ok and type(s) == "string" and s ~= "" then return s end
    local p = Playstyle(v)
    return p and p.name or nil
end
function D.PlaystyleColour(v)
    local p = Playstyle(v)
    return p and p.color or ns.colors.dim
end

local VM = Enum and Enum.LFGEntryVoiceMode or {}
D.VOICES = {
    { value = VM.None or 0, name = VOICE_CHAT_MODE_NONE or "None" },
    { value = VM.Legacy or 1, name = VOICE_CHAT_MODE_LEGACY or "In-game voice" },
    { value = VM.Discord or 2, name = VOICE_CHAT_MODE_DISCORD or "Discord" },
    { value = VM.Custom or 3, name = VOICE_CHAT_MODE_CUSTOM or "Other" },
}
function D.VoiceName(v)
    for _, x in ipairs(D.VOICES) do if x.value == v then return x.name end end
end

-- ------------------------------------------------------------ activities
local function CategoryName(id)
    local api = L()
    if api.GetLfgCategoryInfo then
        local info = api.GetLfgCategoryInfo(id)
        if type(info) == "table" then return info.name end
    end
end

function D.Categories()
    if not D.Has() then return {} end
    local out = {}
    for _, id in ipairs(L().GetAvailableCategories() or {}) do
        table.insert(out, { id = id, name = CategoryName(id) or ("Category " .. id) })
    end
    return out
end

-- "All level ranges": Blizzard's own switch, a CVar its filter reads
local CVAR = "disableSuggestedLevelActivityFilter"
function D.ShowAllLevels() return GetCVarBool and GetCVarBool(CVAR) and true or false end
function D.SetShowAllLevels(on)
    if SetCVar then SetCVar(CVAR, on and "1" or "0") end
    Changed()
end

local activities = {}           -- by id, read once
function D.Activity(id)
    if activities[id] then return activities[id] end
    local t = L().GetActivityInfoTable and L().GetActivityInfoTable(id)
    local a = { id = id, name = "Activity " .. id, min = 0, max = 0, size = 5, order = 0 }
    if type(t) == "table" then
        a.name = t.fullName or t.shortName or a.name
        a.min = t.minLevelSuggestion or t.minLevel or 0
        a.max = t.maxLevelSuggestion or 0
        a.size = t.maxNumPlayers and t.maxNumPlayers > 0 and t.maxNumPlayers or 5
        a.order = t.orderIndex or 0
        a.cat = t.categoryID
        a.groupID = t.groupFinderActivityGroupID
        if a.groupID and a.groupID > 0 and L().GetActivityGroupInfo then
            a.group, a.groupOrder = L().GetActivityGroupInfo(a.groupID)
        end
    end
    if a.max < a.min then a.max = a.min end
    activities[id] = a
    return a
end

-- the level filter where Blizzard's helper is not there: within the
-- suggested range, give or take
local function Suits(a)
    local level = UnitLevel and UnitLevel("player") or 0
    if a.min <= 0 then return true end
    return level >= a.min - 5 and level <= a.max + 5
end

-- A category's activities: Blizzard's filtered list (the level ranges
-- that suit you, or all of them with All level ranges), by level.
function D.Activities(cat)
    if not D.Has() or not cat then return {} end
    local api = L()
    local ids
    if LFGUtil_GetFilteredActivities then
        local ok, list = pcall(LFGUtil_GetFilteredActivities, cat)
        if ok and type(list) == "table" then ids = list end
    end
    local filter = not ids and not D.ShowAllLevels()
    ids = ids or (api.GetAvailableActivities and api.GetAvailableActivities(cat)) or {}
    local out = {}
    for _, id in ipairs(ids) do
        local a = D.Activity(id)
        if not filter or Suits(a) then table.insert(out, a) end
    end
    table.sort(out, function(a, b)
        if (a.groupOrder or 0) ~= (b.groupOrder or 0) then return (a.groupOrder or 0) < (b.groupOrder or 0) end
        if a.min ~= b.min then return a.min > b.min end
        return a.name < b.name
    end)
    return out
end

-- ---------------------------------------------------------------- search
D.category = nil
D.stale = false                 -- the list is not of what is asked for: a search waits for a click
local askedAt                   -- when we last called Search (a refusal comes straight after)
-- the picks changed and may not search: the list waits for Browse's Search
function D.Stale()
    D.stale = true
    Changed()
end
function D.Search(cat, ids)
    if not D.Has() or not cat then return end
    if D.searching then
        -- its answer will be of something else: sent by the next click, not
        -- from the answer's event (the game would refuse it there)
        D.stale = true
        Changed()
        return
    end
    D.category = cat
    if not ids or #ids == 0 then
        ids = {}
        for _, a in ipairs(D.Activities(cat)) do table.insert(ids, a.id) end
    end
    D.searching, D.stale = true, false
    askedAt = GetTime()
    if not pcall(L().Search, cat, 0, 0, nil, false, nil, ids) then D.searching, D.stale = false, true end
    Changed()
end

local S = ns.IsSecret
local ROLE = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DAMAGER" }
-- (a role the game keeps secret is not one)
local function Roles(t)
    if type(t) ~= "table" then return {} end
    local function On(v) return not S(v) and v and true or nil end
    return { TANK = On(t.tank), HEALER = On(t.healer), DAMAGER = On(t.dps) or On(t.damager) }
end

local function Person(p)
    if type(p) ~= "table" or S(p.name) or S(p.classFilename) or S(p.assignedRole) or S(p.isLeader)
        or S(p.lfgRoles) or S(p.level) or S(p.className) then return nil end
    return { name = p.name, level = p.level, class = p.classFilename, className = p.className,
        role = ROLE[p.assignedRole or ""], roles = Roles(p.lfgRoles), leader = p.isLeader }
end

-- The fields Read tests or compares: one secret, the result is not read.
local FIELDS = { "isDelisted", "numMembers", "age", "hasSelf", "activityIDs", "name", "comment",
    "generalPlaystyle", "voiceMode", "newPlayerFriendly", "leaderName", "activityID" }
local function Hidden(info)
    for _, k in ipairs(FIELDS) do if S(info[k]) then return true end end
    return false
end

local function Read(id)
    local api = L()
    local info = api.GetSearchResultInfo(id)
    if type(info) ~= "table" then return nil end
    if Hidden(info) then
        D.hidden = D.hidden + 1
        return nil
    end
    if info.isDelisted then return nil end
    local ids = info.activityIDs or (info.activityID and { info.activityID }) or {}
    local names = {}
    local lo, hi, size = nil, nil, 0
    for _, x in ipairs(ids) do
        local a = D.Activity(x)
        table.insert(names, a.name)
        lo = lo and math.min(lo, a.min) or a.min
        hi = hi and math.max(hi, a.max) or a.max
        size = math.max(size, a.size)
    end
    local r = { id = id, activityIDs = ids, name = #names > 0 and table.concat(names, ", ") or (info.name or "?"),
        min = lo or 0, max = hi or 0, size = size > 0 and size or 5, members = {},
        comment = info.comment or "", age = info.age or 0, self = info.hasSelf and true or false,
        count = info.numMembers or 1, playstyle = info.generalPlaystyle, voice = info.voiceMode,
        newPlayers = info.newPlayerFriendly and true or false }
    r.solo = r.count <= 1
    r.leader = Person(api.GetSearchResultLeaderInfo and api.GetSearchResultLeaderInfo(id))
        or { name = info.leaderName, roles = {} }
    r.leader.name = r.leader.name or info.leaderName or "?"
    if api.GetSearchResultPlayerInfo then
        for i = 1, r.count do
            local p = Person(api.GetSearchResultPlayerInfo(id, i))
            if p then table.insert(r.members, p) end
        end
    end
    r.needs = {}
    local n = api.GetSearchResultMemberCounts and api.GetSearchResultMemberCounts(id)
    if type(n) == "table" then
        for role in pairs(ROLE) do
            local left = n[role .. "_REMAINING"]
            if left and not S(left) then r.needs[role] = left > 0 or nil end
        end
    end
    return r
end
D.Read = Read

local function Results()
    D.searching, D.hidden = false, 0
    local first, ids = L().GetSearchResults()
    if type(first) == "table" then ids = first end
    local out = {}
    for _, id in ipairs(ids or {}) do
        local r = Read(id)
        if r then table.insert(out, r) end
    end
    -- yours first, then the newest
    table.sort(out, function(a, b)
        if a.self ~= b.self then return a.self end
        if a.age ~= b.age then return a.age < b.age end
        return a.id < b.id
    end)
    D.results = out
    D.searchedAt = GetTime()
    Changed()
end
D.Results = Results

-- ----------------------------------------------------------------- roles
local function Grouped() return IsInGroup and IsInGroup() or false end

-- solo, or the group's leader: who may list
function D.CanEdit()
    if not Grouped() then return true end
    return UnitIsGroupLeader and UnitIsGroupLeader("player") and true or false
end

function D.CanInvite()
    if not Grouped() then return true end
    return UnitIsGroupLeader and UnitIsGroupLeader("player")
        or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        or false
end

-- The roles the class can take: C_LFGList.GetAvailableRoles (three
-- answers, or a table); none said, all three.
function D.Available()
    local api = L()
    local all = { tank = true, healer = true, dps = true }
    if not (api and api.GetAvailableRoles) then return all end
    local ok, t, h, d = pcall(api.GetAvailableRoles)
    if not ok then return all end
    if type(t) == "table" then return { tank = t.tank ~= false, healer = t.healer ~= false, dps = t.dps ~= false } end
    if t == nil and h == nil and d == nil then return all end
    return { tank = t and true or false, healer = h and true or false, dps = d and true or false }
end

-- Solo, the roles are ours, as Blizzard's own check buttons hold them:
-- seeded once from the game's saved ones, sent with each click
-- (SetRoles), and the game's word taken back as it answers
-- (LFG_LIST_ROLE_UPDATE: GetRoles), never read straight after a send. In
-- a group, the role you are assigned: the one clicked shows at once,
-- until the game says (PLAYER_ROLES_ASSIGNED).
local function Clean(r)
    if type(r) ~= "table" then r = {} end
    return { tank = r.tank and true or false, healer = r.healer and true or false, dps = r.dps and true or false }
end

local function Solo()
    if not D.roles then
        local api = C_LFGListRoles
        local r = api and api.GetSavedRoles and api.GetSavedRoles()
        if type(r) ~= "table" and api and api.GetRoles then r = api.GetRoles() end
        if type(r) ~= "table" then r = ns.db and ns.db.lfgRoles end
        D.roles = Clean(r)
    end
    return D.roles
end

local function Send()
    local r = Clean(Solo())
    if ns.db then ns.db.lfgRoles = r end
    if C_LFGListRoles and C_LFGListRoles.SetRoles then
        D.sentAt = GetTime()
        pcall(C_LFGListRoles.SetRoles, r)
    end
end

D.pending = nil                 -- in a group: the role asked for, until the game assigns it
function D.Roles()
    if Grouped() then
        local r = D.pending or (UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")) or "NONE"
        return { tank = r == "TANK", healer = r == "HEALER", dps = r == "DAMAGER", group = true }
    end
    return Clean(Solo())
end

-- solo: any of the three the class can take; in a group: the one you are assigned
function D.SetRole(field, on)
    if on and not D.Available()[field] then return false end
    if Grouped() then
        local role = field == "tank" and "TANK" or field == "healer" and "HEALER" or "DAMAGER"
        D.pending = on and role or "NONE"
        if UnitSetRole then UnitSetRole("player", D.pending) end
    else
        Solo()[field] = on and true or false
        Send()
    end
    Changed()
    return true
end

local function Answered()
    local api = C_LFGListRoles
    if api and api.GetRoles then
        local r = api.GetRoles()
        if type(r) == "table" then D.roles = Clean(r) end
    end
    Changed()
end
D.Answered = Answered

-- -------------------------------------------------------------- listing
function D.Entry()
    local api = L()
    if not D.Has() then return nil end
    if api.HasActiveEntryInfo and not api.HasActiveEntryInfo() then return nil end
    local info = api.GetActiveEntryInfo and api.GetActiveEntryInfo()
    if type(info) ~= "table" then return nil end
    local e = { activityIDs = info.activityIDs or (info.activityID and { info.activityID }) or {},
        comment = info.comment or "", age = info.duration, playstyle = info.generalPlaystyle,
        voice = info.voiceMode, newPlayers = info.newPlayerFriendly and true or false, applicants = 0 }
    if api.GetApplicants then e.applicants = #(api.GetApplicants() or {}) end
    return e
end

-- Why a listing cannot go up as asked, or nil: { ids, playstyle, voice, newPlayers }
function D.Problem(p)
    if not D.Has() then return "The game's group finder is not here." end
    if not D.CanEdit() then return "Only your group's leader can list it." end
    if #p.ids == 0 then return "Tick what you are after." end
    if not D.Entry() and not p.playstyle then return "Pick a playstyle." end
    local r = D.Roles()
    if not r.group and not (r.tank or r.healer or r.dps) then return "Pick a role or more." end
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    for _, id in ipairs(p.ids) do
        local a = D.Activity(id)
        if members > a.size then return "Your group is too big for " .. a.name .. "." end
    end
    return nil
end

function D.Post(p)
    local problem = D.Problem(p)
    if problem then return false, problem end
    local api = L()
    local data = { activityIDs = p.ids, newPlayerFriendly = p.newPlayers and true or false, voiceMode = p.voice or 0 }
    local ok
    if D.Entry() and api.UpdateListing then
        ok = pcall(api.UpdateListing, data)
    else
        data.generalPlaystyle = p.playstyle
        ok = pcall(api.CreateListing, data)
    end
    -- a solo player's roles, kept as Blizzard keeps them after a listing
    if not Grouped() then Send() end
    D.expired = nil
    Changed()
    if not ok then return false, "The game refused the listing." end
    return true
end

function D.Delist()
    local api = L()
    if api and api.RemoveListing then api.RemoveListing() end
    Changed()
end

-- ----------------------------------------------------------------- who
D.WHO_MAX = MAX_WHOS_FROM_SERVER or 50
D.SORTS = {
    { value = "name", name = "Name" }, { value = "level", name = "Level" }, { value = "class", name = "Class" },
}

-- the menus' lists: classes, races, the zones of your continent
function D.Classes()
    local out, ids = {}, nil
    if C_SpecializationInfo and C_SpecializationInfo.GetAllClassIDs then ids = C_SpecializationInfo.GetAllClassIDs() end
    if not ids then
        ids = {}
        for i = 1, (GetNumClasses and GetNumClasses() or 0) do table.insert(ids, i) end
    end
    for _, id in ipairs(ids) do
        local name, file = GetClassInfo(id)
        if name then table.insert(out, { value = id, name = name, file = file }) end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function D.Races()
    local out = {}
    local list = C_FriendList and C_FriendList.GetWhoRaceFilters and C_FriendList.GetWhoRaceFilters() or {}
    for _, r in ipairs(list) do
        local id = r.raceID or r.id
        if id then table.insert(out, { value = id, name = r.name or ("Race " .. id) }) end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function D.HereMap() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil end

function D.Zones()
    local out = {}
    if not (C_Map and C_Map.GetMapChildrenInfo) then return out end
    local here = D.HereMap() or (C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID())
    if not here then return out end
    local top = here
    if MapUtil and MapUtil.GetMapParentInfo and Enum and Enum.UIMapType then
        local info = MapUtil.GetMapParentInfo(here, Enum.UIMapType.Continent, true)
        if info and info.mapID then top = info.mapID end
    end
    for _, m in ipairs(C_Map.GetMapChildrenInfo(top, Enum and Enum.UIMapType and Enum.UIMapType.Zone) or {}) do
        if not C_Map.IsMapValidForNavBarDropdown or C_Map.IsMapValidForNavBarDropdown(m.mapID) then
            table.insert(out, { value = m.mapID, name = m.name })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- filters: { classes = { [id] = true }, races = {...}, zones = {...} }
local function Keys(t)
    local out = {}
    for k in pairs(t or {}) do table.insert(out, k) end
    table.sort(out)
    return out
end

local ours = false                  -- the query in flight is ours: its answers to the window
function D.Who(text, filters)
    local F = C_FriendList
    if not (F and F.SendWho) then return end
    filters = filters or {}
    D.who.query = text or ""
    D.who.filters = filters
    D.who.pending = true
    ours = true
    if F.SetWhoToUi then F.SetWhoToUi(true) end
    local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social
    local sent = { classIDs = Keys(filters.classes), raceIDs = Keys(filters.races), uiMapIDs = Keys(filters.zones) }
    if not (origin and pcall(F.SendWho, D.who.query, origin, sent)) then F.SendWho(D.who.query) end
    Changed()
end

function D.SortWho(mode, ascending)
    if C_FriendList and C_FriendList.SortWho then C_FriendList.SortWho(mode, ascending ~= false) end
end

local function WhoResults()
    local F = C_FriendList
    local list = {}
    local n, total = F.GetNumWhoResults()
    for i = 1, n or 0 do
        local info = F.GetWhoInfo(i)
        if info then
            table.insert(list, { name = info.fullName, level = info.level or 0, class = info.classStr or "",
                classFile = info.filename, race = info.raceStr or "", guild = info.fullGuildName or "",
                zone = info.area or "" })
        end
    end
    D.who.list, D.who.total, D.who.pending = list, total or #list, false
    if ours and F.SetWhoToUi then F.SetWhoToUi(false) end
    ours = false
    Changed()
end
D.WhoResults = WhoResults

-- ------------------------------------------------------------- the deeds
function D.Message(name)
    if not name then return end
    if ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(name)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(name) end
end
D.Whisper = D.Message

function D.Invite(name)
    if not name then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then InviteUnit(name) end
end

function D.Friend(name)
    if name and C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(name) end
end

-- ------------------------------------------------------------- the events
ns.On("LFG_LIST_SEARCH_RESULTS_RECEIVED", function() if D.Has() then Results() end end)
ns.On("LFG_LIST_SEARCH_RESULT_UPDATED", function()
    if not D.Has() or D.searching then return end
    Results()
end)
-- our search refused (it was not straight from a click): no answer will
-- come, so not searching; the list waits for Browse's Search
ns.On("ADDON_ACTION_BLOCKED", function(_, addon)
    if addon == ADDON and D.searching and askedAt == GetTime() then
        D.searching, D.stale = false, true
        Changed()
    end
end)
ns.On("LFG_LIST_SEARCH_FAILED", function()
    D.searching = false
    Changed()
end)
D.expired = nil
ns.On("LFG_LIST_ENTRY_EXPIRED_TIMEOUT", function()
    D.expired = "Your listing ran out of time."
    Changed()
end)
ns.On("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS", function()
    D.expired = "Your group grew too big for its listing."
    Changed()
end)
for _, e in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "LFG_LIST_APPLICANT_LIST_UPDATED", "LFG_LIST_AVAILABILITY_UPDATE",
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do
    ns.On(e, Changed)
end
-- the game's roles: taken back as it answers, once our last click has
-- had its own answer (a second click a moment after the first must not be
-- undone by the first's)
ns.On("LFG_LIST_ROLE_UPDATE", function()
    local wait = (D.sentAt or -10) + 1 - GetTime()
    if wait > 0 and C_Timer and C_Timer.After then C_Timer.After(wait, Answered) else Answered() end
end)
ns.On("PLAYER_ROLES_ASSIGNED", function()
    D.pending = nil
    Changed()
end)
ns.On("WHO_LIST_UPDATE", function() if C_FriendList and C_FriendList.GetNumWhoResults then WhoResults() end end)

-- /mdlui lfgdump: what this client's tool has, and one result as it comes
local Fields
function Fields(t)
    local keys = {}
    for k, v in pairs(type(t) == "table" and t or {}) do
        if type(v) == "table" then v = "{" .. Fields(v) .. "}" end
        table.insert(keys, k .. "=" .. tostring(v))
    end
    table.sort(keys)
    return table.concat(keys, " ")
end

function D.Dump()
    local say = function(s) print("|cfff0d488Medalluin LFG|r " .. s) end
    local api = L()
    if not api then
        say("no C_LFGList")
        return
    end
    local names = {}
    for k, v in pairs(api) do if type(v) == "function" then table.insert(names, k) end end
    table.sort(names)
    say("tool=" .. tostring(D.Has()) .. " loaded=" .. tostring(_G.LFGParentFrame ~= nil) .. " note box="
        .. tostring(_G.LFGListingComment ~= nil) .. " filter helper=" .. tostring(LFGUtil_GetFilteredActivities ~= nil))
    say("C_LFGList: " .. table.concat(names, ", "))
    say("roles: " .. Fields(D.Roles()) .. " can list=" .. tostring(D.CanEdit()))
    if api.GetAvailableRoles then
        local function Words(ok, ...)
            local out = { tostring(ok) }
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                table.insert(out, type(v) == "table" and ("{" .. Fields(v) .. "}") or tostring(v))
            end
            return out
        end
        local out = Words(pcall(api.GetAvailableRoles))
        say("available roles: " .. table.concat(out, ", ") .. " -> " .. Fields(D.Available()))
    end
    if C_LFGListRoles then
        local saved = C_LFGListRoles.GetSavedRoles and C_LFGListRoles.GetSavedRoles()
        local now = C_LFGListRoles.GetRoles and C_LFGListRoles.GetRoles()
        say("game roles: saved {" .. Fields(saved) .. "} now {" .. Fields(now) .. "}")
    end
    for _, c in ipairs(D.Categories()) do
        say("category " .. c.id .. " " .. c.name .. ": " .. #D.Activities(c.id) .. " activities")
    end
    local e = D.Entry()
    if e then say("listed: " .. Fields(e)) end
    local id
    if api.GetSearchResults then
        local first, second = api.GetSearchResults()
        id = type(first) == "table" and first[1] or type(second) == "table" and second[1] or nil
    end
    if id then
        say("result " .. id .. ": " .. Fields(api.GetSearchResultInfo(id)))
        if api.GetSearchResultLeaderInfo then say("leader: " .. Fields(api.GetSearchResultLeaderInfo(id))) end
        if api.GetSearchResultPlayerInfo then say("player 1: " .. Fields(api.GetSearchResultPlayerInfo(id, 1))) end
        if api.GetSearchResultMemberCounts then say("counts: " .. Fields(api.GetSearchResultMemberCounts(id))) end
    else
        say("no search results yet: search in the window first")
    end
end
