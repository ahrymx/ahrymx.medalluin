-- The side panel's Zone tab: the minimap on the left, and the quests of the
-- zone you are in on the right.
--
-- The minimap is the game's own, moved, not a copy: its pings, zoom and pins
-- come along. While the tab is up it lives in a well here (lent by
-- console/minimap.lua's ns.LendMinimap), and its place on the console, or
-- in the corner, stands empty (black) meanwhile. It goes back when another
-- tab is picked or the panel hides.
--
-- Over the list, the zone's name, and the subzone with where in it you
-- stand. Then a row a quest: those the log files under this zone, and on
-- retail those the game marks on this map too. A row is the quest's title,
-- its progress over all its objectives ("13/30", the counts read from
-- them) and a tick once it is complete; an eye before the count while it
-- is tracked. A click opens its objectives under it or closes them;
-- shift-click tracks it or stops; a right click shows it on the world map.
--
-- The column: zoom in, zoom out, the minimap's tracking, the world map; at
-- the foot, every quest here tracked (or, while they all are, none).
local _, ns = ...

local PARTS = ns.media .. "strips\\"
local ROW, LINE, HEAD, GAP = 18, 13, 22, 1
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }

local body, well, hold, list, title, place, empty
local rows, quests, lines = {}, {}, {}
local open = {}                 -- quest ids whose objectives are shown
local first, shown = 0, 0

-- ------------------------------------------------------------- the zone
local function ZoneName()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

local function MapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- The subzone, and where in the zone's map you stand (none in an instance).
local function Place()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local map, at = MapID(), ""
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and y and (x > 0 or y > 0) then at = string.format("%.0f, %.0f", x * 100, y * 100) end
    end
    if sub ~= "" and at ~= "" then return sub .. "  " .. at end
    return sub ~= "" and sub or at
end

-- The log's quests here: its heading is this zone (or the map's name for
-- it), or the game marks it on this map.
local function Here()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return {} end
    local names, marked = { [ZoneName()] = true }, {}
    local map = MapID()
    local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    if info and info.name then names[info.name] = true end
    if map and C_QuestLog.GetQuestsOnMap then
        for _, e in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
            if e.questID then marked[e.questID] = true end
        end
    end
    local out = {}
    for _, q in ipairs(ns.questSource.Log()) do
        if names[q.zone] or marked[q.id] then table.insert(out, q) end
    end
    return out
end

-- ------------------------------------------------------------- progress
-- An objective's count, "3/10" anywhere in its text; one with none counts
-- as one thing, done or not. Its words without the count.
local function Count(o)
    local have, need = o.text:match("(%d+)%s*/%s*(%d+)")
    if have then return tonumber(have), tonumber(need) end
    return o.done and 1 or 0, 1
end

local function Words(o)
    local s = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub(":?%s*%d+%s*/%s*%d+%s*$", "")
    return s
end

local function Progress(q)
    local have, need = 0, 0
    for _, o in ipairs(q.objectives) do
        local a, b = Count(o)
        have, need = have + math.min(a, b), need + b
    end
    return have, need
end

-- ----------------------------------------------------------------- rows
local function Tip(r)
    local q = r.line and r.line.quest
    if not q then return end
    local state = q.state == 1 and "Complete." or q.state == -1 and "Failed." or nil
    ns.Tip(r, ns.side.Beside, { title = q.title,
        { "body", "Level " .. q.level .. (state and ("  \194\183  " .. state) or "") },
        { "body", q.tracked and "Tracked." or "Not tracked." },
        { "hint", "Click: its objectives. Shift-click: track it or not. Right-click: the world map." } })
end

local Refresh

local function Row()
    local r = CreateFrame("Button", nil, list)
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.fold = ns.Text(r, 11)
    r.fold:SetPoint("LEFT", 3, 0)
    r.fold:SetTextColor(unpack(GOLD_D))
    r.count = ns.Text(r, 11)
    r.count:SetPoint("RIGHT", -3, 0)
    r.tick = r:CreateTexture(nil, "ARTWORK")
    r.tick:SetSize(12, 12)
    r.tick:SetPoint("RIGHT", -3, 0)
    r.tick:SetTexture(TICK)
    r.eye = r:CreateTexture(nil, "ARTWORK")
    r.eye:SetSize(14, 14)
    r.eye:SetTexture(PARTS .. "track")
    r.text = ns.Text(r, 11)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, mouse)
        local q = self.line and self.line.quest
        if not q then return end
        if mouse == "RightButton" then
            ns.questSource.ShowOnMap(q)
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            if q.tracked then ns.questSource.Untrack(q) else ns.questSource.Track(q) end
        else
            open[q.id] = not open[q.id] or nil
        end
        Refresh()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    r:SetScript("OnEnter", Tip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.side.PassWheel(r)
    return r
end

-- A quest's row, or one of its objectives under it.
local function Fill(r, line, odd)
    r.line = line
    local q, o = line.quest, line.objective
    r.text:ClearAllPoints()
    if o then
        local a, b = Count(o)
        r:SetHeight(LINE)
        r.stripe:Hide()
        r.fold:SetText("")
        r.eye:Hide()
        r.tick:Hide()
        r.text:SetPoint("LEFT", 20, 0)
        r.text:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r.text:SetText(Words(o))
        r.text:SetTextColor(unpack(DIM))
        r.count:SetText(o.text:match("%d+%s*/%s*%d+") and (a .. "/" .. b) or "")
        r.count:SetTextColor(unpack(DIM))
        r:EnableMouse(false)
    else
        local have, need = Progress(q)
        local done = q.state == 1
        r:SetHeight(ROW)
        r.stripe:SetColorTexture(odd and 0 or 0.102, odd and 0 or 0.078, odd and 0 or 0.039, 0.45)
        r.stripe:Show()
        r.fold:SetText(#q.objectives > 0 and (open[q.id] and "-" or "+") or "")
        r.tick:SetShown(done)
        r.count:SetText(done and "" or need > 0 and (have .. "/" .. need) or "")
        r.count:SetTextColor(unpack(q.state == -1 and { 0.8, 0.3, 0.25 } or GOLD))
        r.eye:SetShown(q.tracked and true or false)
        r.eye:ClearAllPoints()
        r.eye:SetPoint("RIGHT", done and r.tick or r.count, "LEFT", -3, 0)
        r.text:SetPoint("LEFT", 14, 0)
        r.text:SetPoint("RIGHT", q.tracked and r.eye or done and r.tick or r.count, "LEFT", -4, 0)
        r.text:SetText(q.title)
        r.text:SetTextColor(unpack(done and DIM or ns.colors.text))
        r:EnableMouse(true)
    end
    r:Show()
end

local function Lines()
    local out = {}
    for _, q in ipairs(quests) do
        table.insert(out, { quest = q })
        if open[q.id] then
            for _, o in ipairs(q.objectives) do table.insert(out, { quest = q, objective = o }) end
        end
    end
    return out
end

local function Header()
    title:SetText(ZoneName())
    place:SetText(Place())
end

function Refresh()
    if not body then return end
    Header()
    quests = Here()
    lines = Lines()
    if first > 0 and first >= #lines then first = math.max(0, #lines - 1) end
    local y, n, odd = HEAD, 0, false
    local height = list:GetHeight()
    shown = 0
    for i = first + 1, #lines do
        local l = lines[i]
        local h = l.objective and LINE or ROW + GAP
        if y + h - GAP > height then break end
        n = n + 1
        local r = rows[n] or Row()
        rows[n] = r
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        if not l.objective then odd = not odd end
        Fill(r, l, odd)
        y = y + h
        shown = shown + 1
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
        rows[i].line = nil
    end
    empty:SetShown(#lines == 0)
    ns.side.Changed()
end

-- ---------------------------------------------------------- the minimap
-- Lent while the body is on the screen, given back when it is not: the tab
-- picked or another one, the panel shown or hidden.
local function Lend()
    if ns.LendMinimap then ns.LendMinimap(body:IsVisible() and hold or nil) end
end

local function Zoom(by)
    local z = Minimap:GetZoom() + by
    Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, z)))
end

-- The game's tracking types, as a menu of ticks at the pointer: retail's
-- menus, or the older clients' own tracking drop-down.
local function TrackingInfo(i)
    local a, _, c = C_Minimap.GetTrackingInfo(i)
    if type(a) == "table" then return a.name, a.active end
    return a, c
end

local function Tracking()
    if MenuUtil and MenuUtil.CreateContextMenu and C_Minimap and C_Minimap.GetNumTrackingTypes then
        MenuUtil.CreateContextMenu(ns.side.panel, function(_, root)
            root:CreateTitle("Tracking")
            for i = 1, C_Minimap.GetNumTrackingTypes() do
                local name = TrackingInfo(i)
                if name then
                    root:CreateCheckbox(name, function() return select(2, TrackingInfo(i)) and true or false end,
                        function() C_Minimap.SetTracking(i, not select(2, TrackingInfo(i))) end)
                end
            end
        end)
        return true
    end
    if ToggleDropDownMenu and MiniMapTrackingDropDown then
        ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor", 0, 0)
        return true
    end
    return false
end

-- Every quest here tracked
local function AllTracked()
    if #quests == 0 then return false end
    for _, q in ipairs(quests) do
        if not q.tracked then return false end
    end
    return true
end

-- ------------------------------------------------------------- the view
local view = {
    key = "zone", label = "Zone", option = "sideZone",
    Available = function() return Minimap ~= nil and ns.questSource ~= nil end,
}
ns.side.zone = view

function view.Build(f)
    body = f
    local side = f:GetHeight()
    -- the map's well, as tall as the body, in the windows' gold edge; the
    -- map goes in the frame inside it, which clips its pins
    well = CreateFrame("Frame", nil, f)
    well:SetPoint("TOPLEFT")
    well:SetSize(side, side)
    ns.window.Face(well)
    hold = CreateFrame("Frame", "MedalluinZoneMap", well)
    hold:SetPoint("TOPLEFT", 1, -1)
    hold:SetPoint("BOTTOMRIGHT", -1, 1)
    hold:SetSize(side - 2, side - 2)
    hold:SetClipsChildren(true)
    -- the list, beside it
    list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", well, "TOPRIGHT", 8, 0)
    list:SetPoint("BOTTOMRIGHT")
    list:SetSize(f:GetWidth() - side - 8, side)
    title = ns.Text(list, 13)
    title:SetPoint("TOPLEFT", 2, -3)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(unpack(GOLD))
    place = ns.Text(list, 10)
    place:SetPoint("TOPRIGHT", -2, -5)
    place:SetJustifyH("RIGHT")
    place:SetWordWrap(false)
    place:SetTextColor(unpack(DIM))
    title:SetPoint("RIGHT", place, "LEFT", -6, 0)
    empty = ns.Text(list, 10)
    empty:SetPoint("TOPLEFT", 4, -HEAD - 4)
    empty:SetTextColor(unpack(DIM))
    empty:SetText("No quests in this zone.")
    f:HookScript("OnShow", Lend)
    f:HookScript("OnHide", Lend)
    -- where you stand, twice a second while the tab is up
    local wait = 0
    f:HookScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.5
        place:SetText(Place())
    end)
    local function Update()
        if ns.side.IsCurrent(view) then Refresh() end
    end
    ns.questSource.Listen(Update)
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
        ns.On(e, Update)
    end
end

view.Refresh = function() Refresh() end

function view.Shown()
    Lend()
end

function view.Scroll(by)
    first = math.max(0, math.min(first + by, #lines - shown))
    Refresh()
end

function view.Thumb()
    return first, shown, #lines
end

view.buttons = {
    {
        glyph = function() return "side-zoom-in" end,
        lit = function() return false end,
        click = function() Zoom(1) end,
        tip = function() return "Zoom in", "The mouse wheel on the map zooms too." end,
    },
    {
        glyph = function() return "side-zoom-out" end,
        lit = function() return false end,
        click = function() Zoom(-1) end,
        tip = function() return "Zoom out", "The mouse wheel on the map zooms too." end,
    },
    {
        glyph = function() return "side-tracking" end,
        lit = function() return false end,
        click = function()
            if not Tracking() and UIErrorsFrame then
                UIErrorsFrame:AddMessage("Medalluin: this client has no tracking menu.", 1, 0.82, 0)
            end
        end,
        tip = function() return "Tracking", "What the minimap shows: herbs, ores, vendors and the like." end,
    },
    {
        glyph = function() return "side-worldmap" end,
        lit = function() return false end,
        click = function() if ToggleWorldMap then ToggleWorldMap() end end,
        tip = function() return "World map", "Open or close the world map." end,
    },
}
view.foot = {
    glyph = function() return "side-trackall" end,
    lit = AllTracked,
    click = function()
        if AllTracked() then
            for _, q in ipairs(quests) do ns.questSource.Untrack(q) end
        else
            for _, q in ipairs(quests) do
                if not q.tracked and not ns.questSource.Track(q) then break end
            end
        end
        Refresh()
    end,
    tip = function()
        if AllTracked() then return "Untrack this zone", "Stop tracking every quest in this zone." end
        return "Track this zone", "Track every quest in this zone, as many as the game allows."
    end,
}

ns.SideView(view)
