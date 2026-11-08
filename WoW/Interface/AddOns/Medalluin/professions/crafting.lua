-- A profession's tab of the professions window (professions/window.lua):
-- its recipes, the chosen one's reagents, and Create.
--
--   [icon] Mining                          Expert at skill 125, level 20
--          [================ 142 / 150 ================]
--   ------------------------------ <> ------------------------------
--   [search........................]
--   - Favourites                                  (right-click stars one)
--     [icon] Rough Sharpening Stone                          [3]
--   - Armor                                                    (a heading)
--     [icon] Copper Chain Vest                               [3]
--     [icon] Runed Copper Belt
--   - Nodes (13)                     (Mining and Herbalism: what it gathers)
--     [icon] Tin Vein                                   Skill 65
--   - At the trainer (2)              (what its trainer teaches, unlearned)
--     [icon] Copper Mace                               Skill 15
--   ---------------------------------------------------------------
--   the chosen recipe: its reagents had / needed, a tree to what it makes
--   [-] 1 [+]   [Create] [Create all]
--   ---------------------------------------------------------------
--   (backpack)     [x] Have materials  [x] Show unknown
--
-- A recipe's colour is its difficulty, as the game's (orange, yellow,
-- green, grey), and its count how many the bags can make. The list is the
-- open profession's: a tab opens its profession (out of combat), and the
-- page waits for it. Search and Have materials are the game's own filters.
--
-- Favourites are Medalluin's, per character (MedalluinCharDB.
-- recipeFavourites, by recipe), listed first and not again in their
-- category. At the trainer closes the list: the profession trainer's
-- services as last read (spells/trainers.lua) not learned yet, those your
-- skill and level allow first; one is read in the details, never made.
-- Have materials leaves it out, as Show unknown unticked does (per
-- character: MedalluinCharDB.recipesUnknownHidden), and the search filters
-- it as the recipes.
--
-- Over it all, the profession's banner: its icon, its name, its next rank
-- as the Overview's card says it, and its skill as a bar across; under it,
-- the window's ornament.
-- Mining's and Herbalism's pages list the nodes they gather (character/
-- nodes.lua), coloured by the chance one gives a skill point; one is read
-- in the details: the skill it needs and where it grows.
-- The details say where a recipe greys (maxTrivialLevel) and what a craft
-- is worth (numSkillUps); the yellow and green marks are not the API's,
-- so only smelting has them, from the Classic-era record (SMELTING): its
-- recipes say where they turn yellow, green and grey, in those colours.
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local Money = function(c) return ns.npc and ns.npc.Money(c) or tostring(c) end
local SLOTS = 5                         -- with Overview, six tabs at most
local SEARCH = 24
local BANNER, BANNER_ICON, HAIR = 42, 36, 14    -- the banner, its icon, the ornament's room under it
local HEAD = BANNER + HAIR + SEARCH             -- the list's top
-- the game's colours, by Enum.TradeskillRelativeDifficulty
local DIFFICULTY = {
    [0] = { 1, 0.5, 0.25 },             -- optimal
    [1] = { 1, 1, 0 },                  -- medium
    [2] = { 0.25, 0.75, 0.25 },         -- easy
    [3] = { 0.5, 0.5, 0.5 },            -- trivial
}

-- the profession is open, its list built
local function Ready(p)
    return p.skillLine and W.Skill() == p.skillLine and not C_TradeSkillUI.IsDataSourceChanging()
end

-- the open last asked for, and when: on its way until it has come, or for
-- WAIT seconds (an open the game drops is asked again after that)
local asked, askedAt, WAIT = nil, 0, 2

local function Count(recipe) return C_TradeSkillUI.GetCraftableCount(recipe) or 0 end

-- ----------------------------------------------------------------- list
local function Favourites()
    MedalluinCharDB = MedalluinCharDB or {}
    if type(MedalluinCharDB.recipeFavourites) ~= "table" then MedalluinCharDB.recipeFavourites = {} end
    return MedalluinCharDB.recipeFavourites
end

-- a heading, folded by key
local function Heading(p, rows, key, label)
    local folded = p.folded[key]
    table.insert(rows, { header = true, label = label, collapsed = folded, click = function()
        p.folded[key] = not p.folded[key] or nil
        p.Refresh()
    end })
    return not folded
end

local function Recipe(p, info)
    local n = Count(info.recipeID)
    return { label = info.name, icon = info.icon, depth = 1,
        value = n > 0 and format("[%d]", n) or nil,
        color = DIFFICULTY[info.relativeDifficulty] or ns.colors.text,
        selected = info.recipeID == p.chosen,
        click = function(button)
            if button == "RightButton" then
                local favs = Favourites()
                favs[info.recipeID] = not favs[info.recipeID] or nil
            else
                p.chosen, p.trained, p.node = info.recipeID, nil, nil
            end
            p.Refresh()
        end,
        enter = function(row)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(info.recipeID)
            GameTooltip:AddLine(Favourites()[info.recipeID] and "Right-click: take its star off."
                or "Right-click: star it, to list it first.", unpack(ns.colors.dim))
            GameTooltip:Show()
        end }
end

local function Label(e) return e.rank and format("%s (%s)", e.name, e.rank) or e.name end

-- the profession trainer's services not learned, matching the search:
-- { key, entry, now }, those you can learn now first, then by skill
local function Untrained(p, learned)
    local out = {}
    local prof = p.prof
    if not prof then return out end
    local text = p.search and p.search:GetText() or ""
    text = text:lower()
    local level = UnitLevel("player")
    for key, e in pairs(ns.trainers.Trade(prof.name)) do
        if not e.known and not learned[e.name] and (text == "" or e.name:lower():find(text, 1, true)) then
            table.insert(out, { key = key, entry = e,
                now = (e.skill or 0) <= prof.rank and (e.level or 0) <= level })
        end
    end
    table.sort(out, function(a, b)
        if a.now ~= b.now then return a.now end
        if (a.entry.skill or 0) ~= (b.entry.skill or 0) then return (a.entry.skill or 0) < (b.entry.skill or 0) end
        return a.key < b.key
    end)
    return out
end

-- the nodes this profession gathers, matching the search
local function Nodes(p)
    local out = {}
    local text = (p.search and p.search:GetText() or ""):lower()
    for _, prof in ipairs(ns.gatheringNodes) do
        if p.prof and prof.skillID == p.prof.skillLine then
            for _, n in ipairs(prof.nodes) do
                if text == "" or n[1]:lower():find(text, 1, true) then table.insert(out, n) end
            end
        end
    end
    return out
end

local function Rows(p)
    local rows, heads, order, favs, learned = {}, {}, {}, {}, {}
    local starred = Favourites()
    for _, id in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            learned[info.name] = true
            if starred[id] then
                table.insert(favs, info)
            else
                local cat = info.categoryID or 0
                if not heads[cat] then
                    local c = C_TradeSkillUI.GetCategoryInfo(cat)
                    heads[cat] = { name = c and c.name or "Other", recipes = {} }
                    table.insert(order, cat)
                end
                table.insert(heads[cat].recipes, info)
            end
        end
    end
    -- a recipe the filters hide is still learned
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then learned[info.name] = true end
    end
    if #favs > 0 and Heading(p, rows, "favourites", "Favourites") then
        for _, info in ipairs(favs) do table.insert(rows, Recipe(p, info)) end
    end
    for _, cat in ipairs(order) do
        if Heading(p, rows, cat, heads[cat].name) then
            for _, info in ipairs(heads[cat].recipes) do table.insert(rows, Recipe(p, info)) end
        end
    end
    local makeable = C_TradeSkillUI.GetOnlyShowMakeableRecipes()
    local nodes = not makeable and Nodes(p) or {}
    if #nodes > 0 and Heading(p, rows, "nodes", format("Nodes (%d)", #nodes)) then
        for _, n in ipairs(nodes) do
            table.insert(rows, { label = n[1], icon = p.prof.icon, depth = 1, value = format("Skill %d", n[2]),
                color = (ns.GatheringChance(p.prof.rank or 0, n[2])), selected = n[1] == p.node,
                click = function(button)
                    if button == "RightButton" then return end
                    p.chosen, p.trained, p.node = nil, nil, n[1]
                    p.Refresh()
                end })
        end
    end
    p.nodes = nodes
    local unknown = not (MedalluinCharDB and MedalluinCharDB.recipesUnknownHidden)
    local untrained = not makeable and unknown and Untrained(p, learned) or {}
    if #untrained > 0 and Heading(p, rows, "trainer", format("At the trainer (%d)", #untrained)) then
        for _, u in ipairs(untrained) do
            local e = u.entry
            table.insert(rows, { label = Label(e), icon = e.icon, depth = 1,
                value = (e.skill or 0) > 0 and format("Skill %d", e.skill) or nil,
                color = u.now and ns.colors.text or ns.colors.dim,
                selected = u.key == p.trained,
                click = function(button)
                    if button == "RightButton" then return end
                    p.chosen, p.trained, p.node = nil, u.key, nil
                    p.Refresh()
                end })
        end
    end
    p.untrained = untrained
    return rows
end

-- ------------------------------------------------------------- details
local function ItemName(id)
    return C_Item.GetItemNameByID(id) or format("Item %d", id)
end

-- a name and its two counts, green when the first covers the second
local function Counted(name, have, need, enough)
    return format("%s  %s%d / %d|r", name, enough and "|cff40c040" or "|cffe04040", have, need)
end

local function Reagents(recipe)
    local lines = {}
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipe, false)
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local r = slot.reagents and slot.reagents[1]
        if r and r.itemID and slot.required ~= false then
            local have, need = C_Item.GetItemCount(r.itemID), slot.quantityRequired or 1
            table.insert(lines, Counted(ItemName(r.itemID), have, need, have >= need))
        end
    end
    return lines, schematic
end

-- The reagents as a tree: each had / needed, down the left, joined by a
-- stem to what they make, so many a craft / as many crafts as the bags
-- allow. The font has no box-drawing letters, so the stem is drawn.
--   Copper Bar  30 / 1  |
--   Tin Bar  10 / 1     └ Bronze Bar  2 / 10
-- TREE_ROWS rows of TREE_ROW fit; more reagents than that share them.
local TREE_TOP, TREE_ROW, TREE_ROWS = 43, 15, 5
local function Tree(foot)
    local t = CreateFrame("Frame", nil, foot)
    t:SetPoint("TOPLEFT", 4, -TREE_TOP)
    t:SetSize(1, TREE_ROWS * TREE_ROW)
    t.lines = {}
    t.stem = t:CreateTexture(nil, "ARTWORK")
    t.stem:SetWidth(1)
    t.arm = t:CreateTexture(nil, "ARTWORK")
    t.arm:SetSize(7, 1)
    for _, line in ipairs({ t.stem, t.arm }) do line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1) end
    t.product = ns.PlainText(t, 12)
    t:Hide()
    return t
end

local function Grow(t, reagents, product)
    local n = #reagents
    local row = math.min(TREE_ROW, TREE_ROWS * TREE_ROW / math.max(n, 1))
    local wide = 0
    for i, text in ipairs(reagents) do
        local fs = t.lines[i] or ns.PlainText(t, 12)
        t.lines[i] = fs
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", t, "TOPLEFT", 0, -(i - 0.5) * row)
        fs:SetText(text)
        fs:Show()
        wide = math.max(wide, fs:GetStringWidth())
    end
    for i = n + 1, #t.lines do t.lines[i]:Hide() end
    -- the stem from the first row's middle to the last's, the arm off it
    local x, bottom = wide + 10, (n - 0.5) * row
    t.stem:ClearAllPoints()
    t.stem:SetPoint("TOPLEFT", x, -row / 2)
    t.stem:SetHeight(math.max(1, bottom - row / 2 + 1))
    t.arm:ClearAllPoints()
    t.arm:SetPoint("TOPLEFT", x, -bottom)
    t.product:ClearAllPoints()
    t.product:SetPoint("LEFT", t, "TOPLEFT", x + 11, -bottom)
    t.product:SetText(product)
    t:Show()
end

-- Smelting's yellow and green, by recipe name: the skill each turns at
local SMELTING = {
    ["Smelt Copper"] = { 25, 47 }, ["Smelt Tin"] = { 65, 70 }, ["Smelt Bronze"] = { 65, 90 },
    ["Smelt Silver"] = { 115, 122 }, ["Smelt Iron"] = { 130, 145 }, ["Smelt Gold"] = { 170, 177 },
    ["Smelt Steel"] = { 165, 165 }, ["Smelt Mithril"] = { 175, 202 }, ["Smelt Truesilver"] = { 235, 242 },
    ["Smelt Dark Iron"] = { 300, 305 }, ["Smelt Thorium"] = { 250, 270 },
}

-- what a craft is worth: where it greys (or turns yellow, green and grey),
-- its points
local function Worth(info)
    if info.canSkillUp == false or info.relativeDifficulty == 3 then return "No more points" end
    if not info.maxTrivialLevel or info.maxTrivialLevel <= 0 then return nil end
    local marks = SMELTING[info.name]
    local at = marks and format("|cffffff00%d|r/|cff40c040%d|r/|cff808080%d|r", marks[1], marks[2],
        info.maxTrivialLevel) or format("Grey at %d", info.maxTrivialLevel)
    local n = info.numSkillUps or 0
    return n > 0 and format("%s  ·  %d |4point:points; a craft", at, n) or at
end

-- a service at the trainer: what it asks, and its price
local function Untaught(p)
    for _, u in ipairs(p.untrained or {}) do
        if u.key == p.trained then
            local e, sub = u.entry, { "At the trainer" }
            if (e.skill or 0) > 0 then table.insert(sub, format("Skill %d", e.skill)) end
            if (e.level or 0) > 1 then table.insert(sub, format("Level %d", e.level)) end
            if (e.cost or 0) > 0 then table.insert(sub, Money(e.cost)) end
            p.details:Set({ title = Label(e), sub = table.concat(sub, "  ·  "),
                text = u.now and "You can learn it now, at its trainer." or "Not yet: it needs more skill or level." })
            return true
        end
    end
    p.trained = nil
end

-- a node: the skill it needs, the chance it gives, where it grows
local function Gathered(p)
    for _, n in ipairs(p.nodes or {}) do
        if n[1] == p.node then
            local _, say = ns.GatheringChance(p.prof.rank or 0, n[2])
            p.details:Set({ title = n[1], sub = format("Needs %s %d", p.prof.name, n[2]),
                text = say .. "\nFound in: " .. n[3] })
            return true
        end
    end
    p.node = nil
end

local function Details(p)
    p.tree:Hide()
    if p.trained and Untaught(p) then return end
    if p.node and Gathered(p) then return end
    local info = p.chosen and C_TradeSkillUI.GetRecipeInfo(p.chosen)
    if not info then p.details:Set(nil) return end
    local reagents, schematic = Reagents(p.chosen)
    local n = Count(p.chosen)
    local sub = {}
    local cooldown = C_TradeSkillUI.GetRecipeCooldown(p.chosen)
    if cooldown and cooldown > 0 then table.insert(sub, "Ready in " .. SecondsToTime(cooldown)) end
    local worth = Worth(info)
    if worth then table.insert(sub, worth) end
    p.details:Set({ title = info.name, sub = table.concat(sub, "  ·  ") })
    local made = schematic and schematic.outputItemID
    Grow(p.tree, reagents, Counted(made and ItemName(made) or info.name,
        math.max(1, schematic and schematic.quantityMax or 1), n, n > 0))
end

-- ------------------------------------------------------------- the band
local function Craft(p, all)
    if InCombatLockdown() or not p.chosen then return end
    local n = all and Count(p.chosen) or p.count
    if n < 1 or n > Count(p.chosen) then return end
    C_TradeSkillUI.CraftRecipe(p.chosen, n)
end

-- The craft buttons along the foot's bottom, under the details; the band
-- holds Have materials.
local function Band(p, foot, band)
    p.have = ns.character.Tick(band, { label = "Have materials",
        tip = "Only the recipes the bags hold the reagents for.",
        click = function(on)
            C_TradeSkillUI.SetOnlyShowMakeableRecipes(on)
            p.Refresh()
        end })
    p.have:SetPoint("LEFT", 4, 0)
    p.unknown = ns.character.Tick(band, { label = "Show unknown",
        tip = "The recipes its trainer teaches that you have not learned, at the list's end.",
        click = function(on)
            MedalluinCharDB = MedalluinCharDB or {}
            MedalluinCharDB.recipesUnknownHidden = not on or nil
            p.Refresh()
        end })
    p.unknown:SetPoint("LEFT", p.have, "RIGHT", 12, 0)
    local function Step(by, label, tip)
        local b = ns.window.Button(foot, 24, function()
            p.count = math.max(1, math.min(999, p.count + by))
            p.Refresh()
        end, function() return tip end)
        b:SetHeight(24)
        b.label:SetText(label)
        return b
    end
    local less = Step(-1, "-", "One fewer.")
    less:SetPoint("BOTTOMLEFT", 4, 2)
    p.counter = ns.Text(foot, 13)
    p.counter:SetWidth(40)
    p.counter:SetPoint("LEFT", less, "RIGHT", 2, 0)
    p.counter:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local more = Step(1, "+", "One more.")
    p.more = more
    more:SetPoint("LEFT", p.counter, "RIGHT", 2, 0)
    p.create = ns.window.Button(foot, 72, function() Craft(p, false) end,
        function() return InCombatLockdown() and "Not in combat." or "Make as many as the count says." end)
    p.create:SetHeight(24)
    p.create.label:SetText("Create")
    p.create:SetPoint("LEFT", more, "RIGHT", 10, 0)
    p.createAll = ns.window.Button(foot, 88, function() Craft(p, true) end,
        function() return InCombatLockdown() and "Not in combat." or "Make as many as the bags can." end)
    p.createAll:SetHeight(24)
    p.createAll.label:SetText("Create all")
    p.createAll:SetPoint("LEFT", p.create, "RIGHT", 4, 0)
end

-- ------------------------------------------------------------------ page
-- the profession's banner: name, next rank, skill
local function Banner(p)
    local b, prof = p.banner, p.prof
    if not prof then return end
    b.icon:SetTexture(prof.icon)
    b.name:SetText(prof.name)
    local text = prof.modifier and prof.modifier > 0
        and format("%d (+%d) / %d", prof.rank, prof.modifier, prof.max) or format("%d / %d", prof.rank, prof.max)
    b.bar:Fill({ min = 0, max = prof.max, cur = prof.rank, text = text })
    local line, color = W.RankLine(prof)
    b.rank:SetShown(line and true or false)
    if line then
        b.rank:SetText(line)
        b.rank:SetTextColor(unpack(color))
    end
end

local function Refresh(p)
    Banner(p)
    p.counter:SetText(p.count)
    if asked and W.Skill() == asked then asked = nil end      -- it came
    if not Ready(p) then
        -- chosen while another profession was opening: open it now
        if W.window:IsShown() and W.Current() == p then p.Open() end
        p.list.empty:SetText(InCombatLockdown() and "Opens out of combat." or "Opening…")
        p.list:Set({})
        p.details:Set(nil)
        p.create:SetAlpha(0.4)
        p.createAll:SetAlpha(0.4)
        return
    end
    p.list.empty:SetText("No recipes.")
    p.list:Set(Rows(p))
    Details(p)
    local makeable = C_TradeSkillUI.GetOnlyShowMakeableRecipes()
    p.have:Set(makeable, true)
    -- Have materials leaves the unknown out whatever this says
    p.unknown:Set(not (MedalluinCharDB and MedalluinCharDB.recipesUnknownHidden), not makeable)
    local can = not InCombatLockdown() and p.chosen and Count(p.chosen) > 0
    p.create:SetAlpha(can and p.count <= Count(p.chosen) and 1 or 0.4)
    p.createAll:SetAlpha(can and 1 or 0.4)
end

for i = 1, SLOTS do
    local p = { key = "craft" .. i, order = i, label = "", frame = "ProfessionsFrame" }
    p.folded, p.count = {}, 1
    p.flex, p.height, p.bandUsed = true, 0, true
    p.events = { "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_SHOW",
        "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "TRAINER_UPDATE", "PLAYER_LEVEL_UP" }
    -- the i-th profession that crafts
    function p.Available()
        local n = 0
        for _, prof in ipairs(W.Learned()) do
            if prof.crafts then
                n = n + 1
                if n == i then
                    if p.skillLine ~= prof.skillLine then p.chosen, p.trained, p.node, p.folded = nil, nil, nil, {} end
                    p.label, p.icon, p.skillLine, p.prof = prof.name, prof.icon, prof.skillLine, prof
                    p.row = not prof.primary and 2 or nil       -- the secondaries' tabs: a row of their own
                    return true
                end
            end
        end
        p.skillLine = nil
        return false
    end
    -- One open at a time. While one is on its way the game says no
    -- profession is open; opening this one again then is taken as closing
    -- it, and Blizzard's frame, standing on its crafting page, closes with
    -- it. A tab chosen meanwhile opens when the first has come (Refresh).
    function p.Open()
        if not p.skillLine or InCombatLockdown() or C_TradeSkillUI.IsDataSourceChanging() then return end
        local skill = W.Skill()
        if skill == p.skillLine then return end
        if asked and asked ~= skill and GetTime() - askedAt < WAIT then return end
        asked, askedAt = p.skillLine, GetTime()
        C_TradeSkillUI.OpenTradeSkill(p.skillLine)
    end
    function p.Build(body, foot, band)
        local banner = CreateFrame("Frame", nil, body)
        banner:SetHeight(BANNER)
        banner:SetPoint("TOPLEFT")
        banner:SetPoint("TOPRIGHT")
        banner.icon = banner:CreateTexture(nil, "ARTWORK")
        banner.icon:SetSize(BANNER_ICON, BANNER_ICON)
        banner.icon:SetPoint("LEFT", 2, 0)
        banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        banner.name = ns.Text(banner, 14)
        banner.name:SetPoint("TOPLEFT", banner.icon, "TOPRIGHT", 8, -1)
        banner.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        banner.rank = ns.Text(banner, 12)
        banner.rank:SetPoint("TOPRIGHT", -2, -4)
        banner.bar = ns.character.Bar(banner, 100)
        banner.bar:SetPoint("BOTTOMLEFT", banner.icon, "BOTTOMRIGHT", 8, 1)
        banner.bar:SetPoint("RIGHT", -2, 0)
        p.banner = banner
        local hair = ns.window.Ornament(body)
        hair:SetPoint("TOPLEFT", 0, -(BANNER + 1))
        hair:SetPoint("TOPRIGHT", 0, -(BANNER + 1))
        p.hair = hair
        local search = CreateFrame("EditBox", "MedalluinProfessionsSearch" .. i, body, "SearchBoxTemplate")
        search:SetHeight(20)
        search:SetPoint("TOPLEFT", 6, -(BANNER + HAIR + 2))
        search:SetPoint("TOPRIGHT", -2, -(BANNER + HAIR + 2))
        search:SetAutoFocus(false)
        search:HookScript("OnTextChanged", function(self)
            local text = self:GetText()
            if Ready(p) then
                C_TradeSkillUI.SetRecipeItemNameFilter(text ~= "" and text or nil)
                p.Refresh()
            end
        end)
        p.search = search
        local holder = CreateFrame("Frame", nil, body)
        holder:SetPoint("TOPLEFT", 0, -HEAD)
        holder:SetPoint("TOPRIGHT", 0, -HEAD)
        p.holder = holder
        p.list = ns.character.List(holder, "No recipes.")
        p.list.ornate = true
        p.details = ns.character.Details(foot, nil, "Choose a recipe to read it.", 4)
        p.tree = Tree(foot)
        -- the details, the tree's rows, and the craft buttons' row
        p.footHeight = math.max(p.details.height, TREE_TOP + TREE_ROWS * TREE_ROW) + 6 + 24 + 2
        Band(p, foot, band)
    end
    function p.Fit(height) p.holder:SetHeight(height - HEAD) end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end
