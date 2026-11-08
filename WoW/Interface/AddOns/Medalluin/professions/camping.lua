-- The Overview's Camping section (professions/window.lua builds it under
-- the professions' cards): the camp's buffs, timed, and the camp objects
-- of the professions known, each at the best tier learned.
--
--   [icon] Camp Benefits     [icon] Well Fed          [icon] Boosted Rest
--          42 min                   None                     None
--   [icon] Incense Candle   +   [icon] Lodestone            +
--          Tier 1 of 3 · 2 in bags      Tier 1 of 3
--   [icon] Basic Campfire   +   ...
--
-- A tile's + opens its drawer: the profession's tiers, each with the skill
-- it needs and what it gives; a tier known is clicked to its profession's
-- tab, chosen there, to make. Which tiers are known is read when a
-- profession is open (its recipes, professions/crafting.lua) and kept per
-- character (MedalluinCharDB.camp, by object); until then a tile says
-- what it would take.
--
-- The game says none of the objects; they are kept here, from Forever's
-- record: tier 1 at skill 20 (a trainer, or Camping 101), tiers 2 and 3 at
-- 140 and 300 from blueprints, each upgrade keeping tier 1's buff. The
-- buffs are told by their names: Camp Benefits is every object's buff in
-- one, after a minute sat by the fire (Welcoming Campfire meanwhile).
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local GAP, BUFF_H, TILE_H, ICON, ROW = 6, 36, 40, 28, 40

-- by the profession's skill line, in the cards' order: each line's tiers
-- { object, skill, what it adds }, and the buff tier 1 gives
local LINES = {
    { skill = 171, buff = "Mana every 5 seconds, to you and those near.", tiers = {
        { "Mana Well", 20 }, { "Fermenter", 140, "Makes certain reagents at the camp." },
        { "Alchemy Laboratory", 300, "A workstation some recipes need." } } },
    { skill = 164, buff = "Strength, to you and those near.", tiers = {
        { "Sharpening Wheel", 20 }, { "Anvil", 140, "An anvil at the camp." },
        { "Master Forge", 300, "A workstation some plans need." } } },
    { skill = 333, buff = "Armor and all stats (resistances from level 30), to you and those near.", tiers = {
        { "Enchanted Lute", 20 }, { "Arcane Salvager", 140, "Disenchanting at the camp." },
        { "Arcane Forge", 300, "A workstation some formulas need." } } },
    { skill = 202, buff = "No buff: sells reagents to you and those near.", tiers = {
        { "Reagent Bot", 20 }, { "Repair Bot", 140, "Repairs too." },
        { "Anarchist's Workbench", 300, "A workstation some schematics need." } } },
    { skill = 182, buff = "Intellect, to you and those near.", tiers = {
        { "Incense Candle", 20 }, { "Greenhouse", 140, "Grows herbs from seeds planted." },
        { "Seed Hybridizer", 300, "Multiplies or improves seeds." } } },
    { skill = 165, buff = "Rested experience, up to 5% of a level, once an hour (Boosted Rest).", tiers = {
        { "Camp Tent", 20 }, { "Tanning Rack", 140, "Makes certain reagents at the camp." },
        { "Sewing Machine", 300, "A workstation some patterns need." } } },
    { skill = 186, buff = "Melee attack power, to you and those near.", tiers = {
        { "Lodestone", 20 }, { "Rock Garden", 140, "Grows a common ore node in time." },
        { "Molten Foundry", 300, "A smelting workstation." } } },
    { skill = 393, buff = "2% critical strike, to you and those near.", tiers = {
        { "Camp Chair", 20 }, { "Field Guide", 140, "Its reader tracks beasts." },
        { "Trapper's Workbench", 300, "Holds a trap." } } },
    { skill = 197, buff = "Spirit, to you and those near.", tiers = {
        { "Faction Banner", 20 }, { "Spinning Wheel", 140, "Makes certain reagents at the camp." },
        { "Loom", 300, "A workstation some patterns need." } } },
    { skill = 129, buff = "Stamina, to you and those near.", tiers = {
        { "First Aid Kit", 20 }, { "Toxin Study", 140, "Holds healing potions and anti-venom." },
        { "Plague Doctor's Laboratory", 300, "Holds healing potions and poultices." } } },
    { skill = 356, buff = "8% all stats, to you and those near.", tiers = {
        { "Fish Bowl", 20 }, { "Fishing Rack", 140, "Lures, and uncommon fish for an hour." },
        { "Fishing Hut", 300, "Lures, and rare fish for an hour." } } },
    { skill = 185, label = "Campfire", buff = "Room for the camp's objects.", tiers = {
        { "Basic Campfire", 1, "Room for 3 objects." }, { "Journeyman Campfire", 140, "Room for 5 objects." },
        { "Expert Campfire", 220, "Room for 10 objects." } } },
    { skill = 185, buff = "Stamina from food, by a cooking fire.", tiers = {
        { "Cookie's Feast", 140 }, { "Iron Oven", 300, "A workstation some recipes need." } } },
}
W.campLines = LINES

-- the buffs, by name: the camp's (with the steps before it), food's, the tent's
local CAMP, WELCOME, NEAR = "Camp Benefits", "Welcoming Campfire", "Campfire Nearby"
local SLOTS = {
    { name = CAMP, icon = "Interface\\Icons\\Spell_Fire_Fire" },
    { name = "Well Fed", icon = "Interface\\Icons\\INV_Misc_Food_14" },
    { name = "Boosted Rest", icon = "Interface\\Icons\\Spell_Nature_Sleep" },
}

local function Known()
    MedalluinCharDB = MedalluinCharDB or {}
    if type(MedalluinCharDB.camp) ~= "table" then MedalluinCharDB.camp = {} end
    return MedalluinCharDB.camp
end

-- A profession open: which of its objects it knows, from its learned
-- recipes (name -> recipeID); a recipe is an object's when its name holds
-- the object's (Basic Campfire Kit).
function W.CampLearned(skill, learned)
    local known = Known()
    for _, line in ipairs(LINES) do
        if line.skill == skill then
            for _, t in ipairs(line.tiers) do
                local id
                for name, recipe in pairs(learned) do
                    if name:find(t[1], 1, true) then id = recipe break end
                end
                if id then
                    local schematic = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(id, false)
                    local info = C_TradeSkillUI.GetRecipeInfo(id)
                    known[t[1]] = { recipe = id, item = schematic and schematic.outputItemID,
                        icon = info and info.icon }
                else
                    known[t[1]] = nil
                end
            end
        end
    end
end

local function Count(item)
    return item and C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item) or 0
end

-- ------------------------------------------------------------- buffs
local function Clock(left)
    if left >= 3600 then return format("%dh %dm", left / 3600, left % 3600 / 60) end
    if left >= 60 then return format("%d min", math.ceil(left / 60)) end
    return format("%d sec", left)
end

-- the player's buffs by name: name -> aura
local function Auras()
    local out = {}
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return out end
    for i = 1, 255 do
        local ok, aura = pcall(get, "player", i, "HELPFUL")
        if not ok or not aura then break end
        local name = aura.name
        if name and not ns.IsSecret(name) then out[name] = aura end
    end
    return out
end

-- one slot: its aura's time left, or what the camp is waiting for
local function Slot(s, auras)
    local aura = auras[s.spec.name]
    local text, color = "None", ns.colors.dim
    if aura then
        local ends = aura.expirationTime
        if ends and not ns.IsSecret(ends) and ends > 0 then
            text = Clock(math.max(0, ends - GetTime()))
        else
            text = "Active"
        end
        color = ns.colors.text
    elseif s.spec.name == CAMP and auras[WELCOME] then
        text, color = "Settling in by the fire", GOLD
    elseif s.spec.name == CAMP and auras[NEAR] then
        text, color = "Sit by the fire a minute", GOLD
    end
    s.aura = aura
    s.icon:SetTexture(aura and aura.icon or s.spec.icon)
    s.icon:SetDesaturated(aura == nil)
    s.time:SetText(text)
    s.time:SetTextColor(unpack(color))
end

-- ------------------------------------------------------------ objects
-- a line's best tier known (its index), or nil
local function Best(line)
    local known = Known()
    for i = #line.tiers, 1, -1 do
        if known[line.tiers[i][1]] then return i end
    end
end

-- what a tier's row and tile say: its state's words and colour
local function State(t, rank, i)
    local k = Known()[t[1]]
    if k then
        local n = Count(k.item)
        return n > 0 and format("Known  ·  %d in bags", n) or "Known", ns.colors.text, true
    end
    if rank >= t[2] then
        return i == 1 and t[2] <= 20 and "Learn it: a trainer, or Camping 101" or "Learn it: a blueprint", GOLD
    end
    return format("Needs skill %d", t[2]), ns.colors.dim
end

-- a known tier, chosen on its profession's tab
local function Make(skill, t)
    local k = Known()[t[1]]
    if not k then return end
    for _, p in ipairs(W.pages) do
        if p.available and p.skillLine == skill and p.Open then
            p.chosen, p.trained, p.node = k.recipe, nil, nil
            W.Open(p)
            return
        end
    end
end

local function Icon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

local function TierIcon(t, prof)
    local k = Known()[t[1]]
    local icon = k and (k.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(k.item) or k.icon)
    return icon or prof.icon
end

-- --------------------------------------------------------------- build
function W.Camp(body)
    local c = CreateFrame("Frame", nil, body)
    c.slots, c.tiles = {}, {}
    local width = ns.window.width
    local third = (width - 2 * GAP) / 3
    for i, spec in ipairs(SLOTS) do
        local s = CreateFrame("Frame", nil, c)
        s.spec = spec
        s:SetSize(third, BUFF_H)
        s:SetPoint("TOPLEFT", (i - 1) * (third + GAP), 0)
        s:EnableMouse(true)
        s.icon = Icon(s, ICON)
        s.icon:SetPoint("LEFT", 2, 0)
        s.name = ns.Text(s, 12)
        s.name:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 6, -1)
        s.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        s.name:SetText(spec.name)
        s.time = ns.Text(s, 11)
        s.time:SetPoint("BOTTOMLEFT", s.icon, "BOTTOMRIGHT", 6, 1)
        s:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.aura and self.aura.auraInstanceID and GameTooltip.SetUnitBuffByAuraInstanceID then
                GameTooltip:SetUnitBuffByAuraInstanceID("player", self.aura.auraInstanceID, "HELPFUL")
            else
                GameTooltip:SetText(spec.name)
                GameTooltip:AddLine(spec.name == CAMP and "Sit a minute by a campfire: every object's buff, "
                    .. "for an hour." or "Not on you.", 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.slots[i] = s
    end

    -- the drawer: one, under the tile that opened it, over what follows
    local drawer = CreateFrame("Frame", nil, c)
    drawer:SetFrameLevel(c:GetFrameLevel() + 10)
    drawer:SetWidth(width)
    drawer:EnableMouse(true)
    drawer:Hide()
    local edge = drawer:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = drawer:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    drawer.rows = {}
    for i = 1, 3 do
        local r = CreateFrame("Button", nil, drawer)
        r:SetHeight(ROW)
        r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ROW)
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        r.icon = Icon(r, ICON)
        r.icon:SetPoint("LEFT", 6, 0)
        r.name = ns.Text(r, 12)
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
        r.state = ns.Text(r, 11)
        r.state:SetPoint("TOPRIGHT", -6, -3)
        r.what = ns.Text(r, 11)
        r.what:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1)
        r.what:SetPoint("RIGHT", -6, 0)
        r.what:SetJustifyH("LEFT")
        r.what:SetWordWrap(false)
        r.what:SetTextColor(unpack(ns.colors.dim))
        r:SetScript("OnClick", function(self) if self.tier then Make(self.skill, self.tier) end end)
        drawer.rows[i] = r
    end
    c.drawer = drawer

    function c.Tile(i)
        local t = c.tiles[i]
        if t then return t end
        local half = (width - GAP) / 2
        t = CreateFrame("Button", nil, c)
        t:SetSize(half, TILE_H)
        ns.window.Face(t)
        t.icon = Icon(t, ICON)
        t.icon:SetPoint("LEFT", 6, 0)
        t.name = ns.Text(t, 12)
        t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 6, -1)
        t.name:SetPoint("RIGHT", -18, 0)
        t.name:SetJustifyH("LEFT")
        t.name:SetWordWrap(false)
        t.sub = ns.Text(t, 11)
        t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 6, 1)
        t.sub:SetPoint("RIGHT", -18, 0)
        t.sub:SetJustifyH("LEFT")
        t.sub:SetWordWrap(false)
        t.sign = ns.Text(t, 14)
        t.sign:SetPoint("RIGHT", -6, 0)
        t.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        t:SetScript("OnClick", function(self)
            c.open = c.open ~= self.line and self.line or nil
            c.Refresh(c.learned)
        end)
        c.tiles[i] = t
        return t
    end

    -- the buffs only: each second while the Overview shows
    function c.Tick()
        local auras = Auras()
        for _, s in ipairs(c.slots) do Slot(s, auras) end
    end

    -- learned: W.Learned(); the section's height
    function c.Refresh(learned)
        c.learned = learned
        c.Tick()
        local lines = {}
        for _, prof in ipairs(learned) do
            for _, line in ipairs(LINES) do
                if prof.skillLine and line.skill == prof.skillLine then
                    table.insert(lines, { line = line, prof = prof })
                end
            end
        end
        local half = (width - GAP) / 2
        local opened
        for i, e in ipairs(lines) do
            local t = c.Tile(i)
            local line, prof = e.line, e.prof
            local best = Best(line)
            local tier = line.tiers[best or 1]
            t.line, t.prof = line, prof
            t:ClearAllPoints()
            local row = math.floor((i - 1) / 2)
            t:SetPoint("TOPLEFT", ((i - 1) % 2) * (half + GAP), -(BUFF_H + GAP + row * (TILE_H + GAP)))
            t.icon:SetTexture(TierIcon(tier, prof))
            t.icon:SetDesaturated(best == nil)
            t.name:SetText(tier[1])
            t.name:SetTextColor(unpack(best and GOLD or ns.colors.dim))
            if best then
                local n = Count(Known()[tier[1]].item)
                local bags = n > 0 and format("  ·  %d in bags", n) or ""
                t.sub:SetText(format("Tier %d of %d", best, #line.tiers) .. bags)
                t.sub:SetTextColor(unpack(ns.colors.text))
            else
                local words, color = State(tier, prof.rank or 0, 1)
                t.sub:SetText(words)
                t.sub:SetTextColor(unpack(color))
            end
            t.sign:SetText(c.open == line and "-" or "+")
            t.mark:SetShown(c.open == line)
            t:Show()
            if c.open == line then opened = t end
        end
        for i = #lines + 1, #c.tiles do c.tiles[i]:Hide() end
        -- the drawer under its tile, or shut when its line has gone
        drawer:SetShown(opened ~= nil)
        if opened then
            local line, prof = opened.line, opened.prof
            drawer:ClearAllPoints()
            drawer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, select(5, opened:GetPoint()) - TILE_H - 2)
            for i, r in ipairs(drawer.rows) do
                local t = line.tiers[i]
                r:SetShown(t ~= nil)
                if t then
                    local words, color, known = State(t, prof.rank or 0, i)
                    r.skill, r.tier = line.skill, known and t or nil
                    r.icon:SetTexture(TierIcon(t, prof))
                    r.icon:SetDesaturated(not known)
                    r.name:SetText(format("%s  (tier %d)", t[1], i))
                    r.name:SetTextColor(unpack(known and GOLD or ns.colors.dim))
                    r.state:SetText(words)
                    r.state:SetTextColor(unpack(color))
                    -- an upgrade keeps tier 1's buff (not a campfire's room)
                    local keeps = t[3] and i > 1 and line.tiers[1][2] > 1
                    r.what:SetText(keeps and (t[3] .. " Keeps tier 1's buff.") or t[3] or line.buff)
                end
            end
            drawer:SetHeight(#line.tiers * ROW + 2)
        else
            c.open = nil
        end
        local rows = math.ceil(#lines / 2)
        local height = BUFF_H + (rows > 0 and GAP + rows * (TILE_H + GAP) - GAP or 0)
        c:SetHeight(height)
        return height
    end
    return c
end

-- the most the section takes: the buffs and a tile for every line two
-- professions and the three secondaries can have (Cooking has two)
W.CAMP_MOST = BUFF_H + GAP + 4 * (TILE_H + GAP) - GAP
