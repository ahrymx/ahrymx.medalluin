-- A profession's tab of the professions window (professions/window.lua):
-- its recipes, the chosen one's reagents, and Create.
--
--   [search........................]
--   - Armor                                                    (a heading)
--     [icon] Copper Chain Vest                               [3]
--     [icon] Runed Copper Belt
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
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
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
local function Rows(p)
    local rows, heads, order = {}, {}, {}
    for _, id in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            local cat = info.categoryID or 0
            if not heads[cat] then
                local c = C_TradeSkillUI.GetCategoryInfo(cat)
                heads[cat] = { name = c and c.name or "Other", recipes = {} }
                table.insert(order, cat)
            end
            table.insert(heads[cat].recipes, info)
        end
    end
    for _, cat in ipairs(order) do
        local h = heads[cat]
        local folded = p.folded[cat]
        table.insert(rows, { header = true, label = h.name, collapsed = folded, click = function()
            p.folded[cat] = not p.folded[cat] or nil
            p.Refresh()
        end })
        if not folded then
            for _, info in ipairs(h.recipes) do
                local n = Count(info.recipeID)
                table.insert(rows, { label = info.name, icon = info.icon, depth = 1,
                    value = n > 0 and format("[%d]", n) or nil,
                    color = DIFFICULTY[info.relativeDifficulty] or ns.colors.text,
                    selected = info.recipeID == p.chosen,
                    click = function()
                        p.chosen = info.recipeID
                        p.Refresh()
                    end,
                    enter = function(row)
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:SetSpellByID(info.recipeID)
                        GameTooltip:Show()
                    end })
            end
        end
    end
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

local function Details(p)
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
        "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    -- the i-th profession that crafts
    function p.Available()
        local n = 0
        for _, prof in ipairs(W.Learned()) do
            if prof.crafts then
                n = n + 1
                if n == i then
                    if p.skillLine ~= prof.skillLine then p.chosen, p.folded = nil, {} end
                    p.label, p.icon, p.skillLine = prof.name, prof.icon, prof.skillLine
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
