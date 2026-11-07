-- A profession's tab of the professions window (professions/window.lua):
-- its recipes, the chosen one's reagents, and Create.
--
--   [search........................]
--   - Favourites                                  (right-click stars one)
--     [icon] Rough Sharpening Stone                          [3]
--   - Armor                                                    (a heading)
--     [icon] Copper Chain Vest                               [3]
--     [icon] Runed Copper Belt
--   - At the trainer (2)              (what its trainer teaches, unlearned)
--     [icon] Copper Mace                               Skill 15
--   ---------------------------------------------------------------
--   the chosen recipe: what it makes, its reagents had / needed
--   [x] Have materials
--   ---------------------------------------------------------------
--   (backpack)     [-] 1 [+]   [Create] [Create all]
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
-- Have materials leaves it out, and the search filters it as the recipes.
-- The details say where a recipe greys (maxTrivialLevel) and what a craft
-- is worth (numSkillUps); the yellow and green marks are not the API's.
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
local Money = function(c) return ns.npc and ns.npc.Money(c) or tostring(c) end
local SLOTS = 5                         -- with Overview, six tabs at most
local SEARCH = 24
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
                p.chosen, p.trained = info.recipeID, nil
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
    local untrained = not C_TradeSkillUI.GetOnlyShowMakeableRecipes() and Untrained(p, learned) or {}
    if #untrained > 0 and Heading(p, rows, "trainer", format("At the trainer (%d)", #untrained)) then
        for _, u in ipairs(untrained) do
            local e = u.entry
            table.insert(rows, { label = Label(e), icon = e.icon, depth = 1,
                value = (e.skill or 0) > 0 and format("Skill %d", e.skill) or nil,
                color = u.now and ns.colors.text or ns.colors.dim,
                selected = u.key == p.trained,
                click = function(button)
                    if button == "RightButton" then return end
                    p.chosen, p.trained = nil, u.key
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

local function Reagents(recipe)
    local lines = {}
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipe, false)
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local r = slot.reagents and slot.reagents[1]
        if r and r.itemID and slot.required ~= false then
            local have, need = C_Item.GetItemCount(r.itemID), slot.quantityRequired or 1
            local c = have >= need and "|cff40c040" or "|cffe04040"
            table.insert(lines, format("%s  %s%d / %d|r", ItemName(r.itemID), c, have, need))
        end
    end
    return lines, schematic
end

-- what a craft is worth: where it greys, its points
local function Worth(info)
    if info.canSkillUp == false or info.relativeDifficulty == 3 then return "No more points" end
    if not info.maxTrivialLevel or info.maxTrivialLevel <= 0 then return nil end
    local n = info.numSkillUps or 0
    return n > 0 and format("Grey at %d  ·  %d |4point:points; a craft", info.maxTrivialLevel, n)
        or format("Grey at %d", info.maxTrivialLevel)
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

local function Details(p)
    if p.trained and Untaught(p) then return end
    local info = p.chosen and C_TradeSkillUI.GetRecipeInfo(p.chosen)
    if not info then p.details:Set(nil) return end
    local lines, schematic = Reagents(p.chosen)
    local n = Count(p.chosen)
    local sub = {}
    if schematic and schematic.quantityMax and schematic.quantityMax > 1 then
        table.insert(sub, format("Makes %d", schematic.quantityMax))
    end
    table.insert(sub, n > 0 and format("You can make %d", n) or "Reagents missing")
    local cooldown = C_TradeSkillUI.GetRecipeCooldown(p.chosen)
    if cooldown and cooldown > 0 then table.insert(sub, "Ready in " .. SecondsToTime(cooldown)) end
    local worth = Worth(info)
    if worth then table.insert(sub, worth) end
    p.details:Set({ title = info.name, sub = table.concat(sub, "  ·  "), lines = lines })
end

-- ------------------------------------------------------------- the band
local function Craft(p, all)
    if InCombatLockdown() or not p.chosen then return end
    local n = all and Count(p.chosen) or p.count
    if n < 1 or n > Count(p.chosen) then return end
    C_TradeSkillUI.CraftRecipe(p.chosen, n)
end

local function Band(p, band)
    local function Step(by, label, tip)
        local b = ns.window.Button(band, 24, function()
            p.count = math.max(1, math.min(999, p.count + by))
            p.Refresh()
        end, function() return tip end)
        b:SetHeight(24)
        b.label:SetText(label)
        return b
    end
    local less = Step(-1, "-", "One fewer.")
    less:SetPoint("LEFT", 4, 0)
    p.counter = ns.Text(band, 13)
    p.counter:SetWidth(40)
    p.counter:SetPoint("LEFT", less, "RIGHT", 2, 0)
    p.counter:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local more = Step(1, "+", "One more.")
    p.more = more
    more:SetPoint("LEFT", p.counter, "RIGHT", 2, 0)
    p.create = ns.window.Button(band, 72, function() Craft(p, false) end,
        function() return InCombatLockdown() and "Not in combat." or "Make as many as the count says." end)
    p.create:SetHeight(24)
    p.create.label:SetText("Create")
    p.create:SetPoint("LEFT", more, "RIGHT", 10, 0)
    p.createAll = ns.window.Button(band, 88, function() Craft(p, true) end,
        function() return InCombatLockdown() and "Not in combat." or "Make as many as the bags can." end)
    p.createAll:SetHeight(24)
    p.createAll.label:SetText("Create all")
    p.createAll:SetPoint("LEFT", p.create, "RIGHT", 4, 0)
end

-- ------------------------------------------------------------------ page
local function Refresh(p)
    p.counter:SetText(p.count)
    if not Ready(p) then
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
    p.details.ticks[1]:Set(C_TradeSkillUI.GetOnlyShowMakeableRecipes(), true)
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
                    if p.skillLine ~= prof.skillLine then p.chosen, p.trained, p.folded = nil, nil, {} end
                    p.label, p.icon, p.skillLine, p.prof = prof.name, prof.icon, prof.skillLine, prof
                    return true
                end
            end
        end
        p.skillLine = nil
        return false
    end
    function p.Open()
        if p.skillLine and W.Skill() ~= p.skillLine then C_TradeSkillUI.OpenTradeSkill(p.skillLine) end
    end
    function p.Build(body, foot, band)
        local search = CreateFrame("EditBox", "MedalluinProfessionsSearch" .. i, body, "SearchBoxTemplate")
        search:SetHeight(20)
        search:SetPoint("TOPLEFT", 6, -2)
        search:SetPoint("TOPRIGHT", -2, -2)
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
        holder:SetPoint("TOPLEFT", 0, -SEARCH)
        holder:SetPoint("TOPRIGHT", 0, -SEARCH)
        p.holder = holder
        p.list = ns.character.List(holder, "No recipes.")
        p.details = ns.character.Details(foot, { { label = "Have materials",
            tip = "Only the recipes the bags hold the reagents for.",
            click = function(on)
                C_TradeSkillUI.SetOnlyShowMakeableRecipes(on)
                p.Refresh()
            end } },
            "Choose a recipe to read it.", 4)
        p.footHeight = p.details.height
        Band(p, band)
    end
    function p.Fit(height) p.holder:SetHeight(height - SEARCH) end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end
