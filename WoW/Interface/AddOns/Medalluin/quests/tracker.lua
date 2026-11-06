-- The quest tracker: the tracked quests, on the left of the screen over the
-- chat panel, as wide as the character window and as tall as the screen
-- leaves it. Nothing behind it: the world shows through, and only its rows
-- and buttons take the mouse.
--
--   ------------ Quests ------------
--   [Sort: Level] [-]
--   - Elwynn Forest
--     [10] The Fargodeep Mine                       [item]
--          Kobold Laborer slain: 4/10
--   + Westfall                                     (folded)
--
-- A zone heading folds (remembered). The sort orders the quests inside
-- each zone, and the zones by their first quest: Level, Zone (the one you
-- are in first) or Distance (the nearest objective, from Questie, offered
-- only while Questie can measure it). [-] folds the whole tracker to its
-- heading. A quest's colour is its difficulty.
--
-- A quest: a click opens it in the quest log, Shift links it, Alt focuses
-- it with Questie's arrow, a right click stops tracking it.
--
-- A quest's usable item is a secure button at the right of its row, in a
-- layer on the strip, and it works in combat. So in combat the rows keep
-- their places: counts and colours change where they stand, a quest added
-- or finished waits for combat's end, and a fold, a sort or a scroll does
-- nothing.
--
-- The data is quests/source.lua's: the game's quest log, and Questie's
-- when it is there. The tracker hides while the character window stands
-- over it. Blizzard's own quest tracker is hidden while this one is on.
local _, ns = ...

local L = ns.stripLayout
local Q = ns.questSource
local GOLD = { 0.941, 0.831, 0.533 }
local GREEN = "|cff40c040"
local WIDTH = L.chatLeft + L.chatWidth   -- the character window's width
local PAD, HEAD, CONTROL = 8, 14, 20
local TOP = PAD + HEAD + 6 + CONTROL + 6 -- the list's top, under the heading and the controls
local ITEM = 20
local SORTS = { level = "Level", zone = "Zone", distance = "Distance" }

local frame, list, layer, sortButton, foldButton
local quests = {}
local drawn                             -- the rows' shape as last laid out
local dirty

-- ---------------------------------------------------------------- order
local function Sort()
    local sort = ns.db.questsSort
    if sort == "distance" and not Q.CanMeasure() then sort = "level" end
    return SORTS[sort] and sort or "level"
end

local function Key(q, sort)
    if sort == "distance" then return q.far or math.huge end
    return q.level
end

-- The zones in order, each with its quests in order.
local function Zones()
    local sort = Sort()
    local byZone, zones = {}, {}
    for _, q in ipairs(quests) do
        if not byZone[q.zone] then
            byZone[q.zone] = { name = q.zone, quests = {} }
            table.insert(zones, byZone[q.zone])
        end
        table.insert(byZone[q.zone].quests, q)
    end
    for _, z in ipairs(zones) do
        table.sort(z.quests, function(a, b)
            local ka, kb = Key(a, sort), Key(b, sort)
            if ka ~= kb then return ka < kb end
            return a.title < b.title
        end)
        z.key = Key(z.quests[1], sort)
    end
    local here = GetRealZoneText and GetRealZoneText()
    table.sort(zones, function(a, b)
        if sort == "zone" then
            if (a.name == here) ~= (b.name == here) then return a.name == here end
        elseif a.key ~= b.key then
            return a.key < b.key
        end
        return a.name < b.name
    end)
    return zones
end

-- ----------------------------------------------------------------- rows
local function Colour(q)
    if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer and GetDifficultyColor then
        local d = C_PlayerInfo.GetContentDifficultyQuestForPlayer(q.id)
        local c = d and GetDifficultyColor(d)
        if c then return { c.r, c.g, c.b } end
    end
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(q.level)
        return { c.r, c.g, c.b }
    end
    return ns.colors.text
end

local function Tip(row, q)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local link = GetQuestLink and GetQuestLink(q.id)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(q.title, GOLD[1], GOLD[2], GOLD[3])
        for _, o in ipairs(q.objectives) do GameTooltip:AddLine(o.text, 1, 1, 1) end
    end
    GameTooltip:AddLine("Click: quest log.  Shift: link.  Right-click: stop tracking.", 0.7, 0.66, 0.55, true)
    if Q.Questie() then GameTooltip:AddLine("Alt-click: focus, with Questie's arrow.", 0.7, 0.66, 0.55, true) end
    GameTooltip:Show()
end

local function Click(q, button)
    if button == "RightButton" then
        Q.Untrack(q)
    elseif IsModifiedClick("CHATLINK") and GetQuestLink then
        ChatEdit_InsertLink(GetQuestLink(q.id))
    elseif IsAltKeyDown() and Q.Focus(q) then
        return
    else
        Q.Show(q)
    end
end

local Refresh

local function Rows()
    local rows = {}
    if ns.db.questsMinimised then return rows end
    local folded = ns.db.questsFolded or {}
    for _, z in ipairs(Zones()) do
        table.insert(rows, { header = true, label = z.name, collapsed = folded[z.name], click = function()
            if InCombatLockdown() then return end
            local f = ns.db.questsFolded or {}
            f[z.name] = not f[z.name] or nil
            ns.db.questsFolded = f
            Refresh()
        end })
        if not folded[z.name] then
            for _, q in ipairs(z.quests) do
                local state = q.state == 1 and (" " .. GREEN .. "(Complete)|r")
                    or q.state == -1 and " |cffe04040(Failed)|r" or ""
                table.insert(rows, { label = format("[%d] %s", q.level, q.title) .. state, depth = 1,
                    color = Colour(q), quest = q, item = q.item,
                    click = function(button) Click(q, button) end,
                    enter = function(row) Tip(row, q) end })
                for _, o in ipairs(q.objectives) do
                    table.insert(rows, { label = o.text, depth = 2, dim = o.done })
                end
            end
        end
    end
    return rows
end

-- What decides where everything stands: a heading, a quest and its item,
-- an objective, in order, and the scroll.
local function Shape(rows)
    local parts = { list.offset }
    for _, d in ipairs(rows) do
        table.insert(parts, d.header and ("h" .. d.label .. (d.collapsed and "+" or ""))
            or d.quest and ("q" .. d.quest.id .. ":" .. tostring(d.item)) or "o")
    end
    return table.concat(parts, "|")
end

-- ----------------------------------------------------------- the items
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "MedalluinQuestItem" .. i, layer, "SecureActionButtonTemplate")
    b:SetSize(ITEM, ITEM)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0.541, 0.439, 0.204, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = ns.Text(b, 10)
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    layer.buttons[i] = b
    return b
end

-- The count and cooldown: not secure, so in combat too.
local function Paint(b)
    local n = C_Item.GetItemCount(b.item)
    b.count:SetText(n > 1 and n or "")
    b.icon:SetDesaturated(n == 0)
    local start, duration, enable = 0, 0, 0
    if C_Container and C_Container.GetItemCooldown then
        start, duration, enable = C_Container.GetItemCooldown(b.item)
    end
    if enable == 1 and duration > 0 then b.cooldown:SetCooldown(start, duration) else b.cooldown:Clear() end
end

-- Out of combat only: a button at the right of each shown quest with an
-- item, the rest away.
local function Place()
    local n = 0
    local row = list.rows[1] and list.rows[1]:GetHeight() or 22
    if frame:IsShown() then
        for i, r in ipairs(list.rows) do
            if r:IsShown() and r.data and r.data.item then
                n = n + 1
                local b = Secure(n)
                b.item = r.data.item
                b:SetAttribute("item", "item:" .. b.item)
                b.icon:SetTexture(C_Item.GetItemIconByID(b.item))
                b:ClearAllPoints()
                b:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -6, -(TOP + (i - 1) * row + (row - ITEM) / 2))
                b:Show()
                Paint(b)
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.item = nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
end

-- --------------------------------------------------------------- refresh
function Refresh()
    dirty = false
    if not frame then return end
    quests = Q.Read(ns.db.questsSort == "distance")     -- asked again, though it failed last time
    local rows = Rows()
    local shape = Shape(rows)
    if InCombatLockdown() and shape ~= drawn then
        dirty = true                     -- waits for combat's end
        return
    end
    list:Set(rows)
    list.body:SetShown(not ns.db.questsMinimised)      -- not even "No quests"
    sortButton.label:SetText("Sort: " .. SORTS[Sort()])
    foldButton.label:SetText(ns.db.questsMinimised and "+" or "-")
    if InCombatLockdown() then
        for _, b in ipairs(layer.buttons) do
            if b:IsShown() and b.item then Paint(b) end
        end
        return
    end
    drawn = Shape(rows)
    Place()
end

local function Dirty() dirty = true end

-- ------------------------------------------------------------------ build
local function Build()
    local strip = ns.strips[-1]
    frame = CreateFrame("Frame", "MedalluinQuests", strip)
    frame:SetIgnoreParentAlpha(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false)
    frame:SetWidth(WIDTH)
    local above = L.stripHeight + (_G.MedalluinChat and L.chatHeight or 0)
    frame:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, above)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)

    local head = ns.window.Ornament(frame, "Quests")
    head:SetPoint("TOPLEFT", PAD, -PAD)
    head:SetPoint("TOPRIGHT", -PAD, -PAD)
    head.mid:SetFont(ns.font, HEAD, "")

    sortButton = ns.window.Button(frame, 110, function()
        if InCombatLockdown() then return end
        local order = { "level", "zone", "distance" }
        local at = 1
        for i, k in ipairs(order) do if k == Sort() then at = i end end
        local after = order[at % #order + 1]
        if after == "distance" and not Q.CanMeasure() then after = order[1] end
        ns.db.questsSort = after
        Refresh()
    end, function()
        return "Sort the quests by level, by zone (yours first)"
            .. (Q.CanMeasure() and ", or by the nearest objective." or ". Questie adds by distance.")
    end)
    sortButton:SetHeight(CONTROL)
    sortButton:SetPoint("TOPLEFT", PAD, -(PAD + HEAD + 6))
    foldButton = ns.window.Button(frame, CONTROL, function()
        if InCombatLockdown() then return end
        ns.db.questsMinimised = not ns.db.questsMinimised
        Refresh()
    end, function() return ns.db.questsMinimised and "Show the quests." or "Fold the tracker to its heading." end)
    foldButton:SetHeight(CONTROL)
    foldButton:SetPoint("LEFT", sortButton, "RIGHT", 4, 0)

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 0, -TOP)
    body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    list = ns.character.List(body, "No quests tracked.")
    -- the wheel scrolls over the rows only (the empty space keeps the
    -- camera's), and not in combat (the items stand where the rows were)
    list:EnableMouseWheel(false)
    local scroll = list.Scroll
    function list:Scroll(lines)
        if InCombatLockdown() then return end
        scroll(self, lines)
        Refresh()
    end

    layer = CreateFrame("Frame", "MedalluinQuestItems", strip)
    layer:SetFrameStrata("LOW")
    layer:SetFrameLevel(frame:GetFrameLevel() + 10)
    layer:SetIgnoreParentAlpha(true)
    layer:SetAllPoints(frame)
    layer.buttons = {}
    ns.quests = { frame = frame, list = list, layer = layer, sort = sortButton, fold = foldButton,
        Refresh = Refresh }

    -- one refresh a frame, however many events; a change held in combat
    -- stays dirty until the first frame after it (and a tracker hidden in
    -- combat sends its items away then, through OnHide)
    frame:SetScript("OnUpdate", function() if dirty and not InCombatLockdown() then Refresh() end end)
    Q.Listen(function()
        dirty = true
        if InCombatLockdown() then Refresh() end    -- counts change in place
    end)
    ns.OnSetting("questsSort", Dirty)
    -- Distance changes as you move: measured again every few seconds
    C_Timer.NewTicker(5, function() if ns.db.questsSort == "distance" then Dirty() end end)

    -- under the character window
    local character = ns.character.window
    if character then
        character:HookScript("OnShow", function() frame:Hide() end)
        character:HookScript("OnHide", function() frame:Show() end)
    end
    frame:HookScript("OnShow", Dirty)
    frame:HookScript("OnHide", function() ns.OutOfCombat(Place) end)
    Refresh()
end

-- Blizzard's tracker, hidden: and again each time it shows itself (its own
-- updates, Questie letting it go). Hidden, never reparented, as Questie
-- hides it on Forever: a protected one waits for combat's end.
local function HideBlizzard()
    local f = ObjectiveTrackerFrame or QuestWatchFrame or WatchFrame
    if not f then return end
    local function Away()
        if not f:IsShown() then return end
        if InCombatLockdown() and f:IsProtected() then
            ns.OutOfCombat(Away)
            return
        end
        f:Hide()
    end
    f:HookScript("OnShow", Away)
    Away()
end

local function Start()
    if not ns.db.quests or not (C_QuestLog and C_QuestLog.GetInfo) or not ns.strips[-1] then return end
    Build()
    HideBlizzard()
end

ns.On("PLAYER_LOGIN", Start)
