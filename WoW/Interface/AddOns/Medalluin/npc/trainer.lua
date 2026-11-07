-- The trainer, in the NPC box (npc/window.lua): what it teaches, the ones
-- you can learn now unless the filter asks for more, and the one picked,
-- with what it asks of you; Train in the foot learns it.
--
--   [Available] [Unavailable] [Known]           <- toggles, kept (trainerFilter)
--   [Fire]                                      <- the game's lines, as pills
--   [icon] Fireball (Rank 2)              1s
--   [icon] Fire Ward                      2s    <- red: not yet; dim: known
--   [Fireball (Rank 2)]
--   Hurls a fiery ball ...
--   Requires level 6                            <- red while it is not met
--   2g 36s 55c                         [Train] [Goodbye]
--
-- A click only picks: Blizzard's selection (SelectTrainerService) is left
-- alone, and nothing of ClassTrainerFrame is written or called; it comes
-- with Blizzard_TrainerUI, loaded on the first TRAINER_SHOW, and is parked
-- as it loads (npc/window.lua, Adopt). Under the veil, not the hidden
-- parent: Blizzard closes the trainer when its frame is not visible.
local _, ns = ...

local RED = { 1, 0.3, 0.25 }
local Money = ns.npc.Money
local TYPES = { { "available", "Available" }, { "unavailable", "Unavailable" }, { "used", "Known" } }

local picked                     -- the service picked, by name: indexes move as you learn

-- the game's services in its order, headers too
local function Services()
    local out = {}
    for i = 1, GetNumTrainerServices and GetNumTrainerServices() or 0 do
        local name, rank, category = GetTrainerServiceInfo(i)
        if name then
            table.insert(out, { index = i, name = name, rank = rank ~= "" and rank or nil, category = category,
                cost = category ~= "header" and GetTrainerServiceCost(i) or 0 })
        end
    end
    return out
end

local function Label(s) return s.rank and format("%s (%s)", s.name, s.rank) or s.name end

-- the picked service, or the first you can learn when it is gone
local function Picked(list)
    for _, s in ipairs(list) do
        if s.category ~= "header" and Label(s) == picked then return s end
    end
    for _, s in ipairs(list) do
        if s.category == "available" then
            picked = Label(s)
            return s
        end
    end
    picked = nil
end

-- the filter as kept: the types shown, Available alone until you choose
local function Kept() return ns.db.trainerFilter or { available = true } end

-- the filter as kept, given to the game (it answers with TRAINER_UPDATE)
local function Filter()
    local keep = Kept()
    for _, t in ipairs(TYPES) do
        -- on/off as a boolean: the game raises "Missing on/off parameter" on 1 and 0
        if SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter(t[1], keep[t[1]] and true or false) end
    end
end

-- what the picked one asks of you, a line each, red when not met
local function Requirements(out, i)
    local level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
    if level and level > 1 then
        table.insert(out, { "text", format("Requires level %d", level),
            UnitLevel("player") < level and RED or ns.colors.dim })
    end
    if GetTrainerServiceSkillReq then
        local skill, rank, met = GetTrainerServiceSkillReq(i)
        if skill and skill ~= "" then
            table.insert(out, { "text", format("Requires %s (%d)", skill, rank or 0), met and ns.colors.dim or RED })
        end
    end
    for j = 1, GetTrainerServiceNumAbilityReq and GetTrainerServiceNumAbilityReq(i) or 0 do
        local ability, met = GetTrainerServiceAbilityReq(i, j)
        if ability then table.insert(out, { "text", "Requires " .. ability, met and ns.colors.dim or RED }) end
    end
end

local function Blocks()
    local out = {}
    local greeting = GetTrainerGreetingText and GetTrainerGreetingText()
    if greeting and greeting ~= "" then table.insert(out, { "text", greeting, ns.colors.dim }) end
    local tabs = { "tabs" }
    for _, t in ipairs(TYPES) do
        table.insert(tabs, { label = t[2], selected = Kept()[t[1]] and true or false, click = function()
            local keep = {}
            for k, v in pairs(Kept()) do keep[k] = v end
            keep[t[1]] = not keep[t[1]] or nil
            ns.db.trainerFilter = keep
            Filter()
            ns.npc.Update("trainer")
        end })
    end
    table.insert(out, tabs)
    local list = Services()
    local current = Picked(list)
    local any = false
    for _, s in ipairs(list) do
        if s.category == "header" then
            table.insert(out, { "heading", s.name })
        else
            any = true
            local i = s.index
            table.insert(out, { "row", label = Label(s), icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i),
                value = s.cost > 0 and Money(s.cost) or nil, selected = s == current,
                color = s.category == "unavailable" and RED or s.category == "used" and ns.colors.dim or nil,
                click = function(button)
                    if button == "RightButton" then return end
                    picked = Label(s)
                    ns.npc.Update("trainer")
                end,
                enter = function(row)
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetTrainerService(i)
                    GameTooltip:Show()
                end })
        end
    end
    if not any then table.insert(out, { "text", "Nothing to learn here right now.", ns.colors.dim }) end
    if current then
        table.insert(out, { "heading", Label(current) })
        local text = GetTrainerServiceDescription and GetTrainerServiceDescription(current.index)
        if text and text ~= "" then table.insert(out, { "text", text }) end
        Requirements(out, current.index)
        if current.cost > 0 then table.insert(out, { "text", "Costs " .. Money(current.cost) }) end
    end
    return out
end

local function Close() CloseTrainer() end

local function Foot()
    local current = Picked(Services())
    local why
    if not current then why = "Choose a skill."
    elseif current.category == "used" then why = "Already known."
    elseif current.category ~= "available" then why = "Not yet available."
    elseif GetMoney() < current.cost then why = "Not enough money." end
    return { left = Money(GetMoney()),
        { label = "Train", primary = true, enabled = not why, tip = why,
            click = function() if current and not why then BuyTrainerService(current.index) end end },
        { label = "Goodbye", click = Close } }
end

local function Update() ns.npc.Update("trainer") end

ns.npc.Page{
    key = "trainer", frame = "ClassTrainerFrame", addon = "Blizzard_TrainerUI", veil = true,
    Blocks = Blocks, Foot = Foot, Close = Close,
    Start = function()
        ns.On("TRAINER_SHOW", function()
            picked = nil
            if ExpandTrainerSkillLine then ExpandTrainerSkillLine(0) end
            Filter()
            ns.npc.Show("trainer")
        end)
        ns.On("TRAINER_CLOSED", ns.npc.Sync)
        for _, e in ipairs({ "TRAINER_UPDATE", "PLAYER_MONEY", "SKILL_LINES_CHANGED" }) do ns.On(e, Update) end
    end,
}
