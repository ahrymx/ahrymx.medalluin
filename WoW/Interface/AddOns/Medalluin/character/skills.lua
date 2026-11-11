-- The Skills page (Forever): the skill lines under their headings (weapon
-- skills, armour, languages, professions), each with its rank as a bar;
-- the details are the chosen skill's rank and what the game says of it.
--
-- From C_SkillInfo, kept as Blizzard's own page keeps them: only the top
-- lines (no parent), and not the class's own heading. A bonus to a rank
-- (gear, a buff) is shown after it in green; defense's comes from
-- UnitDefenseSkill, as Blizzard's does.
--
-- Under them, Gathering: the nodes of each gathering profession known
-- (character/nodes.lua), coloured as the game colours a recipe, by the
-- chance a node gives a skill point; the details say the skill it needs
-- and where it grows.
local _, ns = ...

local CLASS_SKILLS = 7                  -- the category Blizzard leaves out
local PROFESSIONS = 11                  -- the heading the gathering professions are under
local DEFENSE = 95
local BLUE = { 0.25, 0.40, 0.90 }
local list, details
local selected                          -- a skillID, or a node's "profession:name"
local known = {}                        -- a gathering profession's skill line, by skillID
local folded = {}                       -- Gathering's own headings, folded

local Chance = ns.GatheringChance

local Refresh

local function Info(i)
    local s = C_SkillInfo.GetSkillLineInfo(i)
    if not s or not s.name then return end
    if s.parentSkillLineID and s.parentSkillLineID ~= 0 then return end
    if s.skillLineCategoryID == CLASS_SKILLS then return end
    if s.skillID == DEFENSE and UnitDefenseSkill then s.modifier = select(2, UnitDefenseSkill("player")) end
    return s
end

-- A rank's bonus, as last read plainly: in combat it can be a secret (the
-- defense UnitDefenseSkill gives, 2026-11-11), which cannot be tested, so
-- the one read before it stands (none until one is)
local bonus = {}

local function Rank(s)
    local mod = s.modifier
    if ns.IsSecret(mod) then mod = bonus[s.skillID] else bonus[s.skillID] = mod end
    mod = mod or 0
    local text = mod ~= 0 and format("%d |cff40ff40(%+d)|r / %d", s.rank or 0, mod, s.maxRank or 0)
        or format("%d / %d", s.rank or 0, s.maxRank or 0)
    return { min = 0, max = s.maxRank, cur = s.rank, color = BLUE, text = text }
end

-- The nodes of each gathering profession known, under one heading, and a
-- heading each.
local function Gathering(rows)
    local any = false
    for _, prof in ipairs(ns.gatheringNodes) do
        if known[prof.skillID] then any = true end
    end
    if not any then return end
    local function Heading(key, label, depth)
        table.insert(rows, { header = true, label = label, collapsed = folded[key], depth = depth,
            click = function()
                folded[key] = not folded[key]
                Refresh()
            end })
        return not folded[key]
    end
    if not Heading("Gathering", "Gathering", 0) then return end
    for _, prof in ipairs(ns.gatheringNodes) do
        local s = known[prof.skillID]
        if s and Heading(prof.name, prof.name, 1) then
            for _, n in ipairs(prof.nodes) do
                local key = prof.name .. ":" .. n[1]
                table.insert(rows, { label = n[1], depth = 2, value = tostring(n[2]),
                    color = (Chance(s.rank or 0, n[2])), selected = key == selected,
                    click = function()
                        selected = key
                        Refresh()
                    end })
            end
        end
    end
end

local function Rows()
    local rows = {}
    -- the gathering professions seen; while the Professions heading is
    -- folded their lines are not given, and the last seen stand
    local seen, open = {}, false
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local s = Info(i)
        if s then
            local row = { label = s.name }
            if s.isHeader then
                if s.skillLineCategoryID == PROFESSIONS and not s.isCollapsed then open = true end
                row.header, row.collapsed, row.depth = true, s.isCollapsed, 0
                row.click = function()
                    if s.isCollapsed then C_SkillInfo.ExpandSkillHeader(i) else C_SkillInfo.CollapseSkillHeader(i) end
                    Refresh()
                end
            else
                seen[s.skillID] = s
                row.depth = 1
                row.bar = Rank(s)
                row.selected = s.skillID == selected
                row.click = function()
                    selected = s.skillID
                    Refresh()
                end
            end
            table.insert(rows, row)
        end
    end
    for _, prof in ipairs(ns.gatheringNodes) do
        local id = prof.skillID
        if seen[id] or open then known[id] = seen[id] end
    end
    Gathering(rows)
    return rows
end

-- the node chosen: its profession, that profession's line, and the node
local function Node()
    for _, prof in ipairs(ns.gatheringNodes) do
        local s = known[prof.skillID]
        if s then
            for _, n in ipairs(prof.nodes) do
                if prof.name .. ":" .. n[1] == selected then return prof, s, n end
            end
        end
    end
end

local function Chosen()
    if not selected then return end
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local s = Info(i)
        if s and not s.isHeader and s.skillID == selected then return s end
    end
end

Refresh = function()
    list:Set(Rows())
    local prof, line, node = Node()
    if node then
        local _, say = Chance(line.rank or 0, node[2])
        details:Set({ title = node[1], sub = format("Needs %s %d", prof.name, node[2]), bar = Rank(line),
            text = say .. "\nFound in: " .. node[3] })
        return
    end
    local s = Chosen()
    if not s then
        selected = nil
        details:Set(nil)
        return
    end
    details:Set({ title = s.name, bar = Rank(s), text = s.description })
end

local page
local function Build(body, foot)
    list = ns.character.List(body, "No skills yet.")
    -- four lines: a node's zones run long
    details = ns.character.Details(foot, nil, "Choose a skill to see its details.", 4)
    page.footHeight = details.height
    page.list, page.details = list, details
end

page = {
    key = "skills", label = "Skills", frame = "SkillsFrame", order = 4,
    height = 0, flex = true,
    events = { "SKILL_LINES_CHANGED" },
    Build = Build, Refresh = function() Refresh() end,
}
ns.CharacterPage(page)
