-- The quest pages, in the NPC box (npc/window.lua): the game's QuestFrame
-- in Medalluin's look, page by page as the game sends them.
--
--   greeting  what the NPC says, its quests to take and to hand in
--   detail    the quest: its title, text, objectives and rewards;
--             [Accept] [Decline]
--   progress  what it asks for, and whether you have it; [Continue] [Cancel]
--   reward    the rewards, a choice among some (a click picks it, marked);
--             [Complete Quest], once a choice is picked if there is one
--
--   Solomon's Law
--   Turn in 10 Shadowhide Pendants to me, and you shall be rewarded.
--   ------------- Required -------------
--   [icon 10] Shadowhide Pendant
--                                      [Cancel] [Continue]
--
-- The words, items and rewards are the game's (GetQuestText and the rest);
-- the buttons answer it (AcceptQuest, CompleteQuest, GetQuestReward).
local _, ns = ...

local MARK = 16

local page                       -- "greeting", "detail", "progress" or "reward"
local choice                     -- the reward picked, on the reward page

local function Money(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    return format("%dg %ds %dc", copper / 10000, copper / 100 % 100, copper % 100)
end

local function Tip(kind, i)
    return function(tile)
        GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
        GameTooltip:SetQuestItem(kind, i)
        GameTooltip:Show()
    end
end

-- the items of a kind ("required", "choice", "reward") as tiles
local function Items(kind, n, pick)
    local tiles = { "tiles" }
    for i = 1, n do
        local itemName, texture, count, quality, isUsable = GetQuestItemInfo(kind, i)
        local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        table.insert(tiles, { icon = texture, label = itemName, count = count,
            color = isUsable == false and { 1, 0.3, 0.25 } or c and { c.r, c.g, c.b },
            selected = pick and choice == i, enter = Tip(kind, i),
            click = pick and function()
                choice = i
                ns.npc.Update("quest")
            end or nil })
    end
    return tiles
end

-- what the quest gives: a choice among some, the items, money and experience
local function Rewards(out, pick)
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    local items = GetNumQuestRewards and GetNumQuestRewards() or 0
    local money = GetRewardMoney and GetRewardMoney() or 0
    local xp = GetRewardXP and GetRewardXP() or 0
    if choices + items == 0 and money == 0 and xp == 0 then return end
    table.insert(out, { "heading", "Rewards" })
    if choices > 1 then
        table.insert(out, { "text", pick and "Choose one:" or "You will choose one of:", ns.colors.dim })
    end
    if choices > 0 then table.insert(out, Items("choice", choices, pick and choices > 1)) end
    if items > 0 then
        if choices > 0 then table.insert(out, { "text", "You will also receive:", ns.colors.dim }) end
        table.insert(out, Items("reward", items))
    end
    local given = {}
    if money > 0 then table.insert(given, Money(money)) end
    if xp > 0 then table.insert(given, format("%d experience", xp)) end
    if #given > 0 then table.insert(out, { "text", table.concat(given, "    ") }) end
end

-- the greeting's quests, by index, with the tracker's marks
local function Greeting(out)
    local quests = {}
    for i = 1, GetNumActiveQuests and GetNumActiveQuests() or 0 do
        local done = false
        if GetActiveQuestID and C_QuestLog and C_QuestLog.IsComplete then
            done = C_QuestLog.IsComplete(GetActiveQuestID(i))
        end
        table.insert(quests, { "row", label = GetActiveTitle(i),
            badge = ns.QuestMark and ns.QuestMark({ state = done and 1 or 0, incomplete = not done }, MARK),
            click = function() SelectActiveQuest(i) end })
    end
    for i = 1, GetNumAvailableQuests and GetNumAvailableQuests() or 0 do
        local trivial, frequency = false, 0
        if GetAvailableQuestInfo then trivial, frequency = GetAvailableQuestInfo(i) end
        table.insert(quests, { "row", label = GetAvailableTitle(i), dim = trivial,
            badge = ns.QuestMark and ns.QuestMark({ daily = (frequency or 0) > 0 }, MARK),
            click = function() SelectAvailableQuest(i) end })
    end
    if #quests > 0 then
        table.insert(out, { "heading", "Quests" })
        for _, r in ipairs(quests) do table.insert(out, r) end
    end
end

local function Blocks()
    local out = {}
    if page == "greeting" then
        table.insert(out, { "text", GetGreetingText() or "" })
        Greeting(out)
    elseif page == "detail" then
        table.insert(out, { "title", GetTitleText() or "" })
        table.insert(out, { "text", GetQuestText() or "" })
        local objectives = GetObjectiveText and GetObjectiveText() or ""
        if objectives ~= "" then
            table.insert(out, { "heading", "Objectives" })
            table.insert(out, { "text", objectives })
        end
        Rewards(out)
    elseif page == "progress" then
        table.insert(out, { "title", GetTitleText() or "" })
        table.insert(out, { "text", GetProgressText() or "" })
        local n = GetNumQuestItems and GetNumQuestItems() or 0
        local money = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
        if n > 0 or money > 0 then
            table.insert(out, { "heading", "Required" })
            if n > 0 then table.insert(out, Items("required", n)) end
            if money > 0 then table.insert(out, { "text", Money(money) }) end
        end
    elseif page == "reward" then
        table.insert(out, { "title", GetTitleText() or "" })
        table.insert(out, { "text", GetRewardText() or "" })
        Rewards(out, true)
    end
    return out
end

local function Close() CloseQuest() end

local function Foot()
    if page == "detail" then
        -- a quest the game took already (shared, or a zone's) is only acknowledged
        local auto = QuestGetAutoAccept and QuestGetAutoAccept()
        return {
            { label = auto and "Okay" or "Accept", click = function()
                if auto then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
            end },
            not auto and { label = "Decline", click = DeclineQuest } or nil,
        }
    elseif page == "progress" then
        local ready = IsQuestCompletable()
        return {
            { label = "Continue", click = CompleteQuest, enabled = ready and true or false,
                tip = not ready and "You do not have everything it asks for yet." or nil },
            { label = "Cancel", click = Close },
        }
    elseif page == "reward" then
        local choices = GetNumQuestChoices() or 0
        local need = choices > 1 and not choice
        return {
            { label = "Complete Quest", enabled = not need,
                tip = need and "Choose a reward first." or nil,
                click = function() GetQuestReward(choices > 1 and choice or choices) end },
        }
    end
    return { { label = "Goodbye", click = Close } }
end

local function To(which)
    return function()
        page, choice = which, nil
        ns.npc.Show("quest")
    end
end

ns.npc.Page{
    key = "quest", frame = "QuestFrame",
    Blocks = Blocks, Foot = Foot, Close = Close,
    Start = function()
        ns.On("QUEST_GREETING", To("greeting"))
        ns.On("QUEST_DETAIL", To("detail"))
        ns.On("QUEST_PROGRESS", To("progress"))
        ns.On("QUEST_COMPLETE", To("reward"))
        ns.On("QUEST_FINISHED", ns.npc.Sync)
        ns.On("QUEST_ITEM_UPDATE", function() ns.npc.Update("quest") end)
    end,
}
