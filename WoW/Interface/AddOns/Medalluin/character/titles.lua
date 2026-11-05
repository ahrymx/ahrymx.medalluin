-- The Character page's titles (one of its details, beside the stats and the
-- sets): "No title", then every title this character has earned, A to Z;
-- the one worn is marked, and a click wears another.
--
-- As Blizzard's own pane reads them (PaperDollFrame.lua, GetKnownTitles):
-- by mask ID from 1 to GetNumTitles, the known ones with a player's name
-- in them; SetCurrentTitle(-1) wears none.
local _, ns = ...

local NONE = -1
local list
local titles = { available = GetNumTitles ~= nil }
ns.character.titles = titles

local function Known()
    local out = {}
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) then
            local name, playerTitle = GetTitleName(i)
            if name and playerTitle then
                table.insert(out, { id = i, name = name:match("^%s*(.-)%s*$") })
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    table.insert(out, 1, { id = NONE, name = PLAYER_TITLE_NONE or "No title" })
    return out
end

function titles.Refresh()
    local worn = GetCurrentTitle()
    if not (worn and worn > 0 and worn <= GetNumTitles() and IsTitleKnown(worn)) then worn = NONE end
    local rows = {}
    for _, t in ipairs(Known()) do
        table.insert(rows, { label = t.name, depth = 0, selected = t.id == worn, dim = t.id == NONE,
            click = function()
                SetCurrentTitle(t.id)
                titles.Refresh()
            end })
    end
    list:Set(rows)
end

function titles.Build(frame)
    list = ns.character.List(frame, "No titles yet.")
    titles.list = list
end
