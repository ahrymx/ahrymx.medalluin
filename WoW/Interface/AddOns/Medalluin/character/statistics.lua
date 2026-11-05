-- The Statistics page (Forever): the game's statistics under their
-- categories (character, combat, kills, deaths and the rest), each with its
-- number; the details are the chosen one's name, number and category.
--
-- The achievement system's own calls, as Blizzard's page makes them: the
-- categories from GetStatisticsCategoryList and their parents from
-- GetCategoryInfo (-1 is the top), each one's statistics from
-- GetStatistic. A category folds here only (the game keeps no such state);
-- a statistic the game says to skip is left out, and a nought reads "--".
local _, ns = ...

local list, details
local selected                          -- a statistic's ID
local folded = {}                       -- categoryID -> true
local names = {}                        -- statID -> { name, value, category }

local Refresh

local function Value(quantity)
    if quantity == nil or quantity == "" or quantity == 0 or quantity == "0" then return "--" end
    return tostring(quantity)
end

local function Stats(rows, cat, catName, depth)
    for i = 1, GetCategoryNumAchievements(cat) do
        local quantity, skip, id = GetStatistic(cat, i)
        if not skip and id then
            local name = select(2, GetAchievementInfo(id))
            if name then
                local value = Value(quantity)
                names[id] = { name, value, catName }
                table.insert(rows, { label = name, value = value, depth = depth, selected = id == selected,
                    click = function()
                        selected = id
                        Refresh()
                    end })
            end
        end
    end
end

local function Category(rows, cat, children, depth)
    local name = GetCategoryInfo(cat)
    table.insert(rows, { header = true, label = name, depth = math.min(depth, 1), collapsed = folded[cat],
        click = function()
            folded[cat] = not folded[cat] or nil
            Refresh()
        end })
    if folded[cat] then return end
    Stats(rows, cat, name, depth + 1)
    for _, child in ipairs(children[cat] or {}) do Category(rows, child, children, depth + 1) end
end

local function Rows()
    local rows, roots, children = {}, {}, {}
    wipe(names)
    for _, cat in ipairs(GetStatisticsCategoryList() or {}) do
        local _, parent = GetCategoryInfo(cat)
        if parent == -1 or parent == nil then
            table.insert(roots, cat)
        else
            children[parent] = children[parent] or {}
            table.insert(children[parent], cat)
        end
    end
    for _, cat in ipairs(roots) do Category(rows, cat, children, 0) end
    return rows
end

Refresh = function()
    list:Set(Rows())
    local s = selected and names[selected]
    if not s then
        selected = nil
        details:Set(nil)
        return
    end
    details:Set({ title = s[1], sub = s[3], text = s[2] })
end

local page
local function Build(body, foot)
    list = ns.character.List(body, "No statistics yet.")
    details = ns.character.Details(foot, nil, "Choose a statistic to see it here.")
    page.footHeight = details.height
    page.list, page.details = list, details
end

page = {
    key = "statistics", label = "Stats", tip = "Statistics", frame = "StatisticsFrame", order = 6,
    height = 0, flex = true,
    events = { "CRITERIA_UPDATE" },
    Build = Build, Refresh = function() Refresh() end,
}
ns.CharacterPage(page)
