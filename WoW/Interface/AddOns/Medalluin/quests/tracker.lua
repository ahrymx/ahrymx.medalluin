-- The quest tracker: the tracked quests, on the left of the screen. Two
-- views (questsView):
--
--   full     in the chat box (strips/chat.lua), above the chat's tabs, up
--            to the screen's top: the box reaches up for it, and comes
--            back down to the chat when the tracker goes minimal. With the
--            chat panel off it stands on the strip in a frame of its own,
--            the same (ns.window.Dress), the medallion's margin at its
--            foot and the timeless buffs in it.
--   minimal  a box of its own: dragged by its heading, sized by the grip
--            in its corner, scaled with Ctrl and the wheel over its heading
--            (questsPlace). Nothing behind it but a shade that comes up
--            while the pointer is over it.
--
-- Only its rows and buttons take the mouse: the world takes the rest. The
-- full view is in the BACKGROUND strata, as the chat box is: the strip
-- and its medallion draw over it, the chat and its tabs too.
--
--   ------------ Quests ------------           <- a click folds it all
--   - Westfall  3                              (your zone, brighter)
--     [12] Testing the Wells          [item]  140 yd
--          0/1 Jansen Stead Water Sample
--   + Elwynn Forest  2                         (folded)
--   [cog][log]             [sort][fold][view]  <- the list's footer, no rule
--   --------------------------------           (the minimal view's grip)
--   [General][Trade]                       <- full view: the chat box
--   the chat's messages                       under it (strips/chat.lua)
--   --------------------------------
--   (medallion)  [buff][buff]
--
-- The footer's buttons are glyphs: the cog opens the Quests settings, the
-- book the quest log (Blizzard's, on its own key); the sort cycles, the
-- chevron folds or opens every zone, the last switches the view.
--
-- A zone heading folds (remembered), and counts its quests. The sort orders
-- the quests inside each zone, and the zones by their first quest: Level,
-- Zone (the one you are in first) or Distance (the nearest objective, from
-- Questie, offered only while Questie can measure it). With Questie, each
-- quest says how far its nearest objective is. A quest's colour is its
-- difficulty.
--
-- A quest: a click opens it in the quest log, Shift links it, Alt focuses
-- it with Questie's arrow, a right click stops tracking it.
--
-- A quest's usable item is a secure button in a column short of the
-- distance, in a layer on the strip, and it works in combat. So in combat
-- the rows keep their places: counts and colours change where they stand, a
-- quest added or finished waits for combat's end, and a fold, a sort, a
-- scroll, the view, a drag, the grip and the scale do nothing.
--
-- The data is quests/source.lua's: the game's quest log, and Questie's
-- when it is there. The tracker hides while the character window stands
-- over it. Blizzard's own quest tracker is hidden while this one is on.
local _, ns = ...

local L = ns.stripLayout
local Q = ns.questSource
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local GREEN = "|cff40c040"
local DIM = "|cff8c8473"
local WIDTH = L.chatLeft + L.chatWidth   -- the character window's width
local PAD, HEAD, CONTROL, GLYPH = 8, 14, 22, 16
local TOP = PAD + HEAD + 6              -- the list's top, under the heading
local FOOT = 4 + CONTROL                -- the footer: a gap under the list, and its buttons
local GRIP = 14                         -- the grip's size
local ITEM = 20
local VALUE = 60                        -- a row's value column, the distance (character/list.lua)
local COLUMN = ITEM + 8                 -- the items' column, short of it
local SHADE, FADE = 0.6, 6              -- the shade's darkest, and how fast it comes and goes (per second)
local RULE = 6                          -- the gap each side of a rule
local HEIGHT, LEAST = 400, { 320, 160 } -- the minimal view's first height, and its least size
local SCALES = { 0.6, 1.5, 0.05 }       -- its scale: least, most, a step of the wheel
local SORTS = { level = "Level", zone = "Zone", distance = "Distance" }

local frame, list, layer, sortButton, foldAll, viewButton, head, grip, footer, ink, measure, shade
local dress, chatRule
local wide = WIDTH                      -- the width the rows have now
local quests = {}
local drawn                             -- the rows' shape as last laid out
local dirty

-- ---------------------------------------------------------------- order
local function Full() return ns.db.questsView ~= "minimal" end

-- an objective's room on its row: the frame less the body's margin, the
-- row's inset, its label's indent at depth 2 and its right margin
-- (character/list.lua)
local function Line() return wide - PAD - 6 - (6 + 2 * 12) - 24 end

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

-- A long objective as the lines it takes, a row each, broken between words
-- (a word longer than a line keeps its own, cut).
local function Wrap(text)
    local room = Line()
    measure:SetText(text)
    if measure:GetStringWidth() <= room then return { text } end
    local lines, line = {}, nil
    for word in text:gmatch("%S+") do
        local try = line and (line .. " " .. word) or word
        measure:SetText(try)
        if line and measure:GetStringWidth() > room then
            table.insert(lines, line)
            line = word
        else
            line = try
        end
    end
    table.insert(lines, line)
    return lines
end

-- how far, in yards
local function Yards(far)
    if far >= 1000 then return format("%.1fk yd", far / 1000) end
    return format("%d yd", far)
end

local Refresh

-- a footer button: the windows' button, square, its glyph centred
local function Control(click, tip)
    local b = ns.window.Button(footer, CONTROL, click, tip)
    b:SetHeight(CONTROL)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(GLYPH, GLYPH)
    b.icon:SetPoint("CENTER")
    return b
end

local function Glyph(b, name)
    b.icon:SetTexture(ns.media .. "strips\\" .. name)
    b.glyph = name
end

local function Rows()
    local rows = {}
    if ns.db.questsMinimised then return rows end
    local folded = ns.db.questsFolded or {}
    local here = GetRealZoneText and GetRealZoneText()
    for _, z in ipairs(Zones()) do
        table.insert(rows, { header = true, label = z.name .. "  " .. DIM .. #z.quests .. "|r",
            collapsed = folded[z.name], bright = z.name == here, click = function()
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
                    color = Colour(q), quest = q, item = q.item, value = q.far and Yards(q.far) or "",
                    inset = VALUE + COLUMN,
                    click = function(button) Click(q, button) end,
                    enter = function(row) Tip(row, q) end })
                for _, o in ipairs(q.objectives) do
                    for _, line in ipairs(Wrap(o.text)) do
                        table.insert(rows, { label = line, depth = 2, dim = o.done })
                    end
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

-- Out of combat only: a button in the items' column of each shown quest
-- with an item, the rest away.
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
                b:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -(PAD + 6 + VALUE + (COLUMN - ITEM) / 2),
                    -(TOP + (i - 1) * row + (row - ITEM) / 2))
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
-- any zone open, of the ones there are
local function AnyOpen()
    local folded = ns.db.questsFolded or {}
    for _, z in ipairs(Zones()) do
        if not folded[z.name] then return true end
    end
    return false
end

function Refresh()
    dirty = false
    if not frame then return end
    -- Questie asked how far every quest is, whenever it is there (asked
    -- again, though it failed last time)
    quests = Q.Read(Q.Questie() ~= nil)
    local rows = Rows()
    local shape = Shape(rows)
    if InCombatLockdown() and shape ~= drawn then
        dirty = true                     -- waits for combat's end
        return
    end
    local minimised = ns.db.questsMinimised
    list:Set(rows)
    list.body:SetShown(not minimised)  -- not even "No quests"
    footer:SetShown(not minimised)
    grip:SetShown(not Full() and not minimised)
    -- the minimal view's shade: the box, or its heading while it is folded
    shade:SetHeight(minimised and TOP or frame:GetHeight() or TOP)
    Glyph(foldAll, AnyOpen() and "chevron-up" or "chevron-down")
    Glyph(viewButton, Full() and "view-minimal" or "view-full")
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

-- ----------------------------------------------------------------- views
-- The view's place, size, scale and strata; the footer's place. Out of
-- combat only: the items' secure layer stands on the frame.
local function Layout()
    if InCombatLockdown() then
        ns.OutOfCombat(Layout)
        return
    end
    local full = Full()
    local at = ns.db.questsPlace or {}
    local scale = full and 1 or at.scale or 1
    frame:ClearAllPoints()
    frame:SetScale(scale)
    layer:SetScale(scale)
    local strata = full and "BACKGROUND" or "LOW"
    frame:SetFrameStrata(strata)
    layer:SetFrameStrata(strata)
    layer:SetFrameLevel(frame:GetFrameLevel() + 10)
    -- the chat box (strips/chat.lua, built before us at login), when the
    -- chat panel is on: the full view stands in it, above its tabs
    local chat = ns.chat
    if full then
        wide = WIDTH
        frame:SetWidth(wide)
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        if chat then
            frame:SetPoint("BOTTOMLEFT", chat.box, "BOTTOMLEFT", 0, chat.top)
        else
            frame:SetPoint("BOTTOMLEFT", ns.strips[-1], "BOTTOMLEFT", 0, L.stripHeight)
        end
    else
        wide = at.w or WIDTH
        frame:SetSize(wide, at.h or HEIGHT)
        if at.point then
            frame:SetPoint(at.point, UIParent, at.relative, at.x, at.y)
        else
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        end
    end
    if chat then chat.Reach(full) end
    -- The full view's foot: in the chat box, a rule over the chat's tabs;
    -- without one, a frame of its own with the medallion's margin, and the
    -- timeless buffs in it. The minimal view's footer is at its foot.
    dress:SetShown(full and not chat)
    chatRule:SetShown(full and chat and true or false)
    local lift = PAD
    if full and chat then
        lift = RULE + 1 + RULE
    elseif full then
        lift = ns.window.band + RULE
    end
    if not chat then
        ns.BuffRow(full and { x = L.chatLeft + PAD, y = ns.stripArt.height - L.stripHeight - ns.window.band / 2 }
            or nil)
    end
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", PAD, lift)
    footer:SetPoint("BOTTOMRIGHT", -(full and PAD or PAD + GRIP), lift)     -- clear of the grip
    list.body:SetPoint("BOTTOMRIGHT", -PAD, lift + FOOT)
    Refresh()
end

-- Where the minimal view is, kept: its anchor as the game left it after a
-- drag or the grip, its size and its scale.
local function Keep(changes)
    local point, _, relative, x, y = frame:GetPoint()
    local at = ns.db.questsPlace or {}
    local keep = { point = point, relative = relative, x = x, y = y, w = at.w, h = at.h, scale = at.scale }
    for k, v in pairs(changes or {}) do keep[k] = v end
    ns.SetOption("questsPlace", keep)
end

local function Rescale(delta)
    local at = ns.db.questsPlace or {}
    local old = at.scale or 1
    local new = math.max(SCALES[1], math.min(SCALES[2], old + delta * SCALES[3]))
    new = math.floor(new / SCALES[3] + 0.5) * SCALES[3]
    if math.abs(new - old) < 0.001 then return end
    -- the anchor stays where it is on the screen: its offsets are in the
    -- frame's own units, which the scale changes
    local point, _, relative, x, y = frame:GetPoint()
    Keep({ point = point, relative = relative, x = (x or 0) * old / new, y = (y or 0) * old / new, scale = new })
end

-- ------------------------------------------------------------------ build
local function Build()
    local strip = ns.strips[-1]
    frame = CreateFrame("Frame", "MedalluinQuests", strip)
    frame:SetIgnoreParentAlpha(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(LEAST[1], LEAST[2]) end
    frame:SetClampedToScreen(true)
    -- over the chat box, when the full view stands in it
    if ns.chat then frame:SetFrameLevel(ns.chat.box:GetFrameLevel() + 2) end
    local tint = ns.colors.ink

    -- the full view's frame when there is no chat box to stand in
    -- (window/shell.lua), and the rule over the chat's tabs when there is
    dress = ns.window.Dress(frame)
    ink = dress.ink
    chatRule = frame:CreateTexture(nil, "ARTWORK")
    chatRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    chatRule:SetHeight(1)
    chatRule:SetPoint("BOTTOMLEFT", PAD, RULE)
    chatRule:SetPoint("BOTTOMRIGHT", -PAD, RULE)

    -- the minimal view's shade: a frame of its own, so its size is what the
    -- pointer is over
    shade = CreateFrame("Frame", nil, frame)
    shade:SetPoint("TOPLEFT")
    shade:SetPoint("TOPRIGHT")
    shade:SetHeight(TOP)
    shade:SetFrameLevel(frame:GetFrameLevel())
    shade:SetAlpha(0)
    shade.fill = shade:CreateTexture(nil, "BACKGROUND")
    shade.fill:SetAllPoints()
    if shade.fill.SetGradient and CreateColor then
        shade.fill:SetColorTexture(1, 1, 1, 1)
        shade.fill:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], SHADE),
            CreateColor(tint[1], tint[2], tint[3], 0))
    else
        shade.fill:SetColorTexture(tint[1], tint[2], tint[3], SHADE / 2)
    end

    -- the heading: a click folds the tracker to it; in the minimal view a
    -- drag moves the box and Ctrl with the wheel scales it
    head = CreateFrame("Button", nil, frame)
    head:SetPoint("TOPLEFT", PAD, -(PAD - 2))
    head:SetPoint("TOPRIGHT", -PAD, -(PAD - 2))
    head:SetHeight(HEAD + 4)
    head:RegisterForClicks("LeftButtonUp")
    head:RegisterForDrag("LeftButton")
    local ornament = ns.window.Ornament(head, "Quests")
    ornament:SetPoint("LEFT")
    ornament:SetPoint("RIGHT")
    ornament.mid:SetFont(ns.font, HEAD, "")
    head:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        ns.db.questsMinimised = not ns.db.questsMinimised
        Refresh()
    end)
    head:SetScript("OnDragStart", function()
        if Full() or InCombatLockdown() then return end
        frame:StartMoving()
    end)
    head:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if not Full() then Keep() end
    end)
    head:EnableMouseWheel(true)
    head:SetScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            if not Full() and not InCombatLockdown() then Rescale(delta) end
        else
            list:Scroll(-delta)
        end
    end)
    head:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_RIGHT", { title = "Quests", color = GOLD,
            { "body", ns.db.questsMinimised and "Click: show the quests."
                or "Click: fold the tracker to this heading." },
            not Full() and { "body", "Drag: move it.  Ctrl-wheel: its size.  The corner's grip: its shape." } or false,
            { "hint", "Not in combat." } })
    end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- the footer, under the list it works on: the settings and the quest
    -- log at its left; the sort, every zone folded or opened and the other
    -- view at its right
    footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(CONTROL)
    local gear = Control(function() ns.OpenOptions("quests") end,
        function() return "Medalluin's quest settings." end)
    Glyph(gear, "menu")
    gear:SetPoint("LEFT")
    local book = Control(function() if ToggleQuestLog then ToggleQuestLog() end end, function()
        local key = GetBindingKey and GetBindingKey("TOGGLEQUESTLOG")
        return "The quest log" .. (key and (" (" .. key .. ")") or "") .. "."
    end)
    Glyph(book, "questlog")
    book:SetPoint("LEFT", gear, "RIGHT", 4, 0)
    viewButton = Control(function()
        if InCombatLockdown() then return end
        ns.SetOption("questsView", Full() and "minimal" or "full")
    end, function()
        return Full() and "Minimal: a box of its own, to move and size."
            or "Full: the character window's place, with the chat at its foot."
    end)
    viewButton:SetPoint("RIGHT")
    foldAll = Control(function()
        if InCombatLockdown() then return end
        local f = false
        if AnyOpen() then
            f = {}
            for _, z in ipairs(Zones()) do f[z.name] = true end
        end
        ns.db.questsFolded = f
        Refresh()
    end, function() return AnyOpen() and "Fold every zone." or "Open every zone." end)
    foldAll:SetPoint("RIGHT", viewButton, "LEFT", -4, 0)
    sortButton = Control(function()
        if InCombatLockdown() then return end
        local order = { "level", "zone", "distance" }
        local at = 1
        for i, k in ipairs(order) do if k == Sort() then at = i end end
        local after = order[at % #order + 1]
        if after == "distance" and not Q.CanMeasure() then after = order[1] end
        ns.db.questsSort = after
        Refresh()
    end, function()
        return "Sorted by " .. SORTS[Sort()]:lower() .. ". Click: by level, by zone (yours first)"
            .. (Q.CanMeasure() and ", or by the nearest objective." or ". Questie adds by distance.")
    end)
    Glyph(sortButton, "sort")
    sortButton:SetPoint("RIGHT", foldAll, "LEFT", -4, 0)

    -- the minimal view's grip, in its corner
    grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP, GRIP)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    for _, part in ipairs({ { 14, 2 }, { 2, 14 } }) do
        local t = grip:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        t:SetSize(part[1], part[2])
        t:SetPoint("BOTTOMRIGHT")
    end
    grip:SetScript("OnMouseDown", function()
        if Full() or InCombatLockdown() then return end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if not Full() then Keep({ w = frame:GetWidth(), h = frame:GetHeight() }) end
    end)

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 0, -TOP)
    body:SetPoint("BOTTOMRIGHT", -PAD, PAD + FOOT)
    list = ns.character.List(body, "No quests tracked.")
    list.fade = true
    -- the rows' font, unseen, to measure an objective's lines
    measure = ns.Text(frame, 12)
    measure:SetPoint("TOPLEFT")
    measure:SetWordWrap(false)
    measure:SetAlpha(0)
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
    ns.quests = { frame = frame, list = list, layer = layer, sort = sortButton, foldAll = foldAll,
        view = viewButton, head = head, grip = grip, footer = footer, ink = ink, shade = shade, top = TOP,
        dress = dress, chatRule = chatRule, gear = gear, book = book,
        Refresh = Refresh, Layout = Layout }

    -- one refresh a frame, however many events; a change held in combat
    -- stays dirty until the first frame after it (and a tracker hidden in
    -- combat sends its items away then, through OnHide)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if dirty and not InCombatLockdown() then Refresh() end
        -- the minimal view's shade eases toward the pointer's answer
        local want, now = not Full() and shade:IsMouseOver() and 1 or 0, shade:GetAlpha()
        if now ~= want then
            local step = (elapsed or 0) * FADE
            shade:SetAlpha(want > now and math.min(want, now + step) or math.max(want, now - step))
        end
    end)
    Q.Listen(function()
        dirty = true
        if InCombatLockdown() then Refresh() end    -- counts change in place
    end)
    ns.OnSetting("questsSort", Dirty)
    ns.OnSetting("questsView", Layout)
    ns.OnSetting("questsPlace", Layout)
    -- how far each quest is changes as you move: measured again every few
    -- seconds while Questie is there
    C_Timer.NewTicker(5, function() if Q.Questie() then Dirty() end end)

    -- under the character window
    local character = ns.character.window
    if character then
        character:HookScript("OnShow", function() frame:Hide() end)
        character:HookScript("OnHide", function() frame:Show() end)
    end
    frame:HookScript("OnShow", Dirty)
    frame:HookScript("OnHide", function() ns.OutOfCombat(Place) end)
    Layout()
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
