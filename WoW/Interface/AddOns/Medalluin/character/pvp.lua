-- The PvP page (Forever): the season, the rank and its emblem, and the rank
-- points toward the next; the details are the rank's: how far into the
-- season's ranks, this week's rise in the cap, and the next rewards.
--
-- Forever keeps the rank as a renown (C_MajorFactions, faction 2800), and
-- these are the reads and the words Blizzard's own page uses
-- (PVPRankFrame.lua), each word with a plain fallback.
--
-- The page is the window's height: the emblem grows into it, and the lot
-- stands in the middle between two dividers.
local _, ns = ...

local FACTION = 2800
local EMBLEM, EMBLEM_MAX = 96, 192
local FRAME = 32                                -- a divider and its room, above and below
local GOLD = { 0.941, 0.831, 0.533 }
local season, rank, emblem, bar, details, above, below

local function Words(key, fallback) return _G[key] or fallback end

local function RankName(level)
    if not level or level <= 0 then return Words("PVP_RANK_0_NAME", "Civilian") end
    local first = Enum and Enum.PvPRanks and Enum.PvPRanks.Rank_1 or 5
    local key = "PVP_RANK_" .. (first + level - 1) .. "_" .. (UnitFactionGroup("player") == "Alliance" and 1 or 0)
    return GetText and GetText(key, UnitSex("player")) or _G[key] or ("Rank " .. level)
end

local function Total(level) return C_MajorFactions.GetTotalReputationForRenownLevel(FACTION, level) or 0 end

-- the first rank above this one with a reward, and its rewards
local function NextRewards(level, top)
    for r = level + 1, top or level do
        local rewards = C_MajorFactions.GetRenownRewardsForLevel(FACTION, r)
        if rewards and #rewards > 0 then return r, rewards end
    end
end

local function Refresh()
    local info = C_MajorFactions.GetMajorFactionProgressionInfo(FACTION)
    local n = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
    season:SetText(n > 0 and format("Season %d", n) or "")
    if not info then
        rank:SetText(RankName(0))
        bar:Hide()
        details:Set(nil)
        return
    end
    local level = info.renownLevel or 0
    rank:SetText(level > 0 and format("Rank %d: %s", level, RankName(level)) or RankName(0))
    local faction = UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
    emblem:SetAtlas(level > 0 and format("UI-Character-Info-Honor-Icon-%d", level)
        or "UI-Character-Info-Honor-Icon-" .. faction)
    bar:Show()
    bar:Fill({ min = 0, max = info.renownLevelThreshold, cur = info.renownReputationEarned, color = ns.colors.xp,
        text = format("Rank Points: %s / %s", BreakUpLargeNumbers(info.renownReputationEarned or 0),
            BreakUpLargeNumbers(info.renownLevelThreshold or 0)) })

    local top = info.maxLevel or level
    local week = Total(info.currentWeekProgressiveMaxLevel or 0)
    local lastWeek = Total(info.previousWeekProgressiveMaxLevel or 0)
    local mine = Total(level) + (info.renownReputationEarned or 0)
    local lines = {}
    if mine > 0 then
        table.insert(lines, week > 0 and format("Season progress: %s / %s", BreakUpLargeNumbers(mine),
            BreakUpLargeNumbers(week)) or format("Season progress: %s", BreakUpLargeNumbers(mine)))
    end
    if week - lastWeek > 0 then
        table.insert(lines, format("Cap increase this week: %s", BreakUpLargeNumbers(week - lastWeek)))
    end
    local at, rewards = NextRewards(level, top)
    if at then
        table.insert(lines, format("Next rewards at Rank %d:", at))
        for _, r in ipairs(rewards) do
            if r.description then
                table.insert(lines, (r.icon and format("|T%s:14:14|t ", r.icon) or "") .. r.description)
            end
        end
    end
    details:Set({ title = RankName(level), sub = level > 0 and format("Rank %d", level) or nil,
        text = format("Each week the rank points cap rises, up to %s for Rank %d.", BreakUpLargeNumbers(Total(top)),
            top), lines = lines })
end

local page

-- the block's height with an emblem this big
local function Block(size) return 10 + 12 + 6 + 18 + 14 + size + 14 + 14 + 10 end

local function Fit(h)
    local size = math.max(EMBLEM, math.min(EMBLEM_MAX, h - 2 * FRAME - Block(0)))
    emblem:SetSize(size, size)
    local top = math.max(0, math.floor((h - Block(size)) / 2))
    season:ClearAllPoints()
    season:SetPoint("TOP", 0, -(top + 10))
    local room = top >= FRAME
    above:SetShown(room)
    below:SetShown(room)
    above:ClearAllPoints()
    above:SetPoint("TOPLEFT", 60, -(top - FRAME / 2 - 6))
    above:SetPoint("TOPRIGHT", -60, -(top - FRAME / 2 - 6))
    below:ClearAllPoints()
    below:SetPoint("TOPLEFT", 60, -(top + Block(size) + FRAME / 2 - 6))
    below:SetPoint("TOPRIGHT", -60, -(top + Block(size) + FRAME / 2 - 6))
    page.emblemSize = size
end

local function Build(body, foot)
    season = ns.Text(body, 10)
    season:SetTextColor(unpack(ns.colors.dim))
    rank = ns.Text(body, 15)
    rank:SetPoint("TOP", season, "BOTTOM", 0, -6)
    rank:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    emblem = body:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(EMBLEM, EMBLEM)
    emblem:SetPoint("TOP", rank, "BOTTOM", 0, -14)
    bar = ns.character.Bar(body, 220)
    bar:SetPoint("TOP", emblem, "BOTTOM", 0, -14)
    above, below = ns.character.Ornament(body), ns.character.Ornament(body)
    Fit(page.height)
    details = ns.character.Details(foot, nil, "No rank this season.", 8)
    page.footHeight = details.height
    page.season, page.rank, page.emblem, page.bar, page.details = season, rank, emblem, bar, details
end

page = {
    key = "pvp", label = "PvP", tip = "Player vs. Player", frame = "PVPRankFrame", order = 5,
    height = Block(EMBLEM),
    events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_PVP_RANK_CHANGED" },
    Build = Build, Fit = Fit, Refresh = Refresh,
}
ns.CharacterPage(page)
