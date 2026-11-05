-- The Reputation page: the factions under their headings, each with its
-- standing as a bar; the details are the chosen faction's: its standing,
-- how far into it, what the game says of it, and its three ticks (at war,
-- inactive, shown on the experience bar).
--
-- All from C_Reputation, by the list's index, as Blizzard's own page does:
-- moving a faction to inactive moves it in the list, so the choice is kept
-- by faction, not by index. A friendship's standing comes from
-- C_GossipInfo, a renown's from C_MajorFactions (retail).
local _, ns = ...

local R = C_Reputation
local MAX_REACTION = 8
local list, details
local selected                          -- a factionID

local function Label(reaction)
    local key = "FACTION_STANDING_LABEL" .. tostring(reaction)
    return GetText and GetText(key, UnitSex and UnitSex("player")) or _G[key] or ""
end

local function Color(reaction)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    return c and { c.r, c.g, c.b } or ns.colors.rep
end

-- { min, max, cur, color, text } for the row, and the standing in words
local function Standing(f)
    local id = f.factionID
    local friend = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and id
        and C_GossipInfo.GetFriendshipReputation(id)
    if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
        local top = friend.nextThreshold or friend.standing
        return { min = friend.reactionThreshold, max = top, cur = friend.standing, color = Color(5),
            text = friend.reaction }, friend.reaction
    end
    if R.IsMajorFaction and id and R.IsMajorFaction(id) and C_MajorFactions then
        local m = C_MajorFactions.GetMajorFactionData(id)
        if m then
            local words = format("Renown %d", m.renownLevel or 0)
            return { min = 0, max = m.renownLevelThreshold, cur = m.renownReputationEarned,
                color = { 0.0, 0.6, 0.9 }, text = words }, words
        end
    end
    local words = Label(f.reaction)
    if f.reaction == MAX_REACTION then
        return { min = 0, max = 1, cur = 1, color = Color(f.reaction), text = words }, words
    end
    return { min = f.currentReactionThreshold, max = f.nextReactionThreshold, cur = f.currentStanding,
        color = Color(f.reaction), text = words }, words
end

local Refresh

local function Rows()
    local rows = {}
    for i = 1, R.GetNumFactions() do
        local f = R.GetFactionDataByIndex(i)
        if f and f.name then
            local row = { label = f.name }
            if f.isHeader then
                row.header, row.collapsed, row.depth = true, f.isCollapsed, f.isChild and 1 or 0
                row.click = function()
                    if f.isCollapsed then R.ExpandFactionHeader(i) else R.CollapseFactionHeader(i) end
                    Refresh()
                end
                if f.isHeaderWithRep then row.bar = Standing(f) end
            else
                row.depth = f.isChild and 2 or 1
                row.bar = Standing(f)
                row.selected = f.factionID == selected
                row.click = function()
                    selected = f.factionID
                    Refresh()
                end
            end
            table.insert(rows, row)
        end
    end
    return rows
end

-- the chosen faction, and where it is in the list now
local function Chosen()
    if not selected then return end
    for i = 1, R.GetNumFactions() do
        local f = R.GetFactionDataByIndex(i)
        if f and f.factionID == selected then return f, i end
    end
end

local function Watch()
    if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
        StatusTrackingBarManager:UpdateBarsShown()
    end
end

local TICKS = {
    { label = "At war", tip = "At war with this faction: its members attack you on sight, and you them.",
        click = function()
            local _, i = Chosen()
            if i then R.ToggleFactionAtWar(i) end
            Refresh()
        end },
    { label = "Inactive", tip = "Move this faction to the Inactive heading, out of the way.",
        click = function(on)
            local _, i = Chosen()
            if i then R.SetFactionActive(i, not on) end
            Refresh()
        end },
    { label = "Experience bar", tip = "Follow this faction on the reputation bar.",
        click = function(on)
            local _, i = Chosen()
            if i then R.SetWatchedFactionByIndex(on and i or 0) end
            Watch()
            Refresh()
        end },
}

Refresh = function()
    list:Set(Rows())
    local f, i = Chosen()
    if not f then
        selected = nil
        details:Set(nil)
        return
    end
    local bar, words = Standing(f)
    local progress = { min = 0, max = (bar.max or 1) - (bar.min or 0), cur = (bar.cur or 0) - (bar.min or 0),
        color = bar.color }
    progress.text = f.reaction == MAX_REACTION and words
        or format("%s / %s", BreakUpLargeNumbers(progress.cur), BreakUpLargeNumbers(progress.max))
    details:Set({ title = f.name, sub = words, bar = progress, text = f.description })
    details.ticks[1]:Set(f.atWarWith, f.canToggleAtWar and not f.isHeader)
    local active = not R.IsFactionActive or R.IsFactionActive(i)
    details.ticks[2]:Set(not active, f.canSetInactive)
    details.ticks[3]:Set(f.isWatched, true)
end

local page
local function Build(body, foot)
    list = ns.character.List(body, "No reputations yet.")
    details = ns.character.Details(foot, TICKS, "Choose a faction to see its details.")
    page.footHeight = details.height
    page.list, page.details = list, details
end

page = {
    key = "reputation", label = "Reputation", frame = "ReputationFrame", order = 2,
    height = 0, flex = true,
    events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED" },
    Build = Build, Refresh = function() Refresh() end,
}
ns.CharacterPage(page)
