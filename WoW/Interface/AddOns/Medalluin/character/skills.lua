-- The Skills page (Forever): the skill lines under their headings (weapon
-- skills, armour, languages, professions), each with its rank as a bar;
-- the details are the chosen skill's rank and what the game says of it.
--
-- From C_SkillInfo, kept as Blizzard's own page keeps them: only the top
-- lines (no parent), and not the class's own heading. A bonus to a rank
-- (gear, a buff) is shown after it in green; defense's comes from
-- UnitDefenseSkill, as Blizzard's does.
local _, ns = ...

local CLASS_SKILLS = 7                  -- the category Blizzard leaves out
local DEFENSE = 95
local BLUE = { 0.25, 0.40, 0.90 }
local list, details
local selected                          -- a skillID

local Refresh

local function Info(i)
    local s = C_SkillInfo.GetSkillLineInfo(i)
    if not s or not s.name then return end
    if s.parentSkillLineID and s.parentSkillLineID ~= 0 then return end
    if s.skillLineCategoryID == CLASS_SKILLS then return end
    if s.skillID == DEFENSE and UnitDefenseSkill then s.modifier = select(2, UnitDefenseSkill("player")) end
    return s
end

local function Rank(s)
    local mod = s.modifier or 0
    local text = mod ~= 0 and format("%d |cff40ff40(%+d)|r / %d", s.rank or 0, mod, s.maxRank or 0)
        or format("%d / %d", s.rank or 0, s.maxRank or 0)
    return { min = 0, max = s.maxRank, cur = s.rank, color = BLUE, text = text }
end

local function Rows()
    local rows = {}
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local s = Info(i)
        if s then
            local row = { label = s.name }
            if s.isHeader then
                row.header, row.collapsed, row.depth = true, s.isCollapsed, 0
                row.click = function()
                    if s.isCollapsed then C_SkillInfo.ExpandSkillHeader(i) else C_SkillInfo.CollapseSkillHeader(i) end
                    Refresh()
                end
            else
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
    return rows
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
    details = ns.character.Details(foot, nil, "Choose a skill to see its details.")
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
