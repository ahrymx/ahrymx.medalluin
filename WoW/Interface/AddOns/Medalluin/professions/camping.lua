-- The Overview's Camping section (professions/window.lua builds it under
-- the professions' cards): the camp's buffs, timed, and the camp objects
-- of the professions known, each at the best tier learned.
--
--   [buff] 42 min  [buff] None  [buff] None  :  (obj)  (obj)  (obj)  (obj)
--                                            : 1/3     20     20      1
--   +-------------------------------------------------------------------+
--   | (icon) Basic Campfire (tier 1)                           Learn it |
--   |        Room for 3 objects.                                        |
--
-- One strip: the camp's three buffs, timed (their names in their
-- tooltips), and an icon per object line, at its best tier known, its
-- corner saying the tier ("1/3") or the skill its first tier needs (dim
-- and grey until known); more than a row's worth go on under the first.
-- An icon opens its drawer under the strip: the profession's tiers, each
-- with the skill it needs and what it gives; a tier known is clicked to its
-- profession's tab, chosen there, to make. Which tiers are known is read when a
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
local ICON, ROW = 28, 40                -- a drawer row's icon, and the row
local BUFF_W, BUFF, OBJ, OBJ_W, STRIP = 96, 24, 28, 42, 40     -- a buff's room and icon; an object's; a row
local FROM = 3 * BUFF_W + 16            -- the objects' left: past the buffs and their hair

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
    for i, spec in ipairs(SLOTS) do
        local s = CreateFrame("Frame", nil, c)
        s.spec = spec
        s:SetSize(BUFF_W, STRIP)
        s:SetPoint("TOPLEFT", (i - 1) * BUFF_W, 0)
        s:EnableMouse(true)
        s.edge = s:CreateTexture(nil, "BACKGROUND")
        s.icon = Icon(s, BUFF)
        s.icon:SetPoint("LEFT", 4, 0)
        s.edge:SetPoint("TOPLEFT", s.icon, -1, 1)
        s.edge:SetPoint("BOTTOMRIGHT", s.icon, 1, -1)
        s.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        s.time = ns.Text(s, 11)
        s.time:SetPoint("LEFT", s.icon, "RIGHT", 6, 0)
        s.time:SetWidth(BUFF_W - BUFF - 16)
        s.time:SetJustifyH("LEFT")
        s:SetScript("OnEnter", function(self)
            W.Beside(self)
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

    c.split = ns.window.Hair(c, true)
    c.split:SetPoint("TOPLEFT", FROM - 8, -4)
    c.split:SetHeight(STRIP - 8)

    -- the drawer: one, under the strip
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

    -- an object: its ring, its corner, a gold underline while its drawer is open
    function c.Tile(i)
        local t = c.tiles[i]
        if t then return t end
        t = CreateFrame("Button", nil, c)
        t:SetSize(OBJ_W, STRIP)
        t.icon = ns.window.Ring(t, OBJ)
        t.icon:SetPoint("CENTER", 0, 2)
        t.mark = t:CreateTexture(nil, "ARTWORK", nil, 4)
        t.mark:SetPoint("BOTTOMLEFT", 5, 0)
        t.mark:SetPoint("BOTTOMRIGHT", -5, 0)
        t.mark:SetHeight(2)
        t.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local glow = t:CreateTexture(nil, "HIGHLIGHT")
        glow:SetPoint("TOPLEFT", 3, 0)
        glow:SetPoint("BOTTOMRIGHT", -3, 0)
        glow:SetColorTexture(1, 1, 1, 0.06)
        -- the corner: on an ink pill in a gold edge, over the ring's foot
        t.corner = ns.Text(t, 10)
        t.corner:SetPoint("BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", 4, -4)
        t.corner:SetDrawLayer("OVERLAY", 2)
        t.pill = t:CreateTexture(nil, "OVERLAY", nil, 1)
        t.pill:SetPoint("TOPLEFT", t.corner, -2, 1)
        t.pill:SetPoint("BOTTOMRIGHT", t.corner, 2, -1)
        t.pill:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
        t.rim = t:CreateTexture(nil, "OVERLAY")
        t.rim:SetPoint("TOPLEFT", t.pill, -1, 1)
        t.rim:SetPoint("BOTTOMRIGHT", t.pill, 1, -1)
        t.rim:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetScript("OnClick", function(self)
            c.open = c.open ~= self.line and self.line or nil
            -- the drawer takes room: the Overview lays out again
            if c.Changed then c.Changed() else c.Refresh(c.learned) end
        end)
        t:SetScript("OnEnter", function(self)
            W.Beside(self)
            GameTooltip:SetText(self.name, unpack(self.known and GOLD or ns.colors.dim))
            GameTooltip:AddLine(self.sub, unpack(self.subColor))
            GameTooltip:AddLine(c.open == self.line and "Click: close its tiers." or "Click: its tiers.",
                unpack(ns.colors.dim))
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        -- the objects, a row's worth across, the rest under the first
        local across = math.max(1, math.floor((width - FROM) / OBJ_W))
        local opened
        for i, e in ipairs(lines) do
            local t = c.Tile(i)
            local line, prof = e.line, e.prof
            local best = Best(line)
            local tier = line.tiers[best or 1]
            t.line, t.prof, t.known = line, prof, best ~= nil
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", FROM + ((i - 1) % across) * OBJ_W, -math.floor((i - 1) / across) * STRIP)
            t.icon:SetTexture(TierIcon(tier, prof))
            t.icon:SetDesaturated(best == nil)
            t.name = tier[1]
            if best then
                local n = Count(Known()[tier[1]].item)
                local bags = n > 0 and format("  ·  %d in bags", n) or ""
                t.sub, t.subColor = format("Tier %d of %d", best, #line.tiers) .. bags, ns.colors.text
                t.corner:SetText(format("%d/%d", best, #line.tiers))
                t.corner:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                t.sub, t.subColor = State(tier, prof.rank or 0, 1)
                t.corner:SetText(tier[2])
                t.corner:SetTextColor(unpack(ns.colors.dim))
            end
            t.mark:SetShown(c.open == line)
            t:Show()
            if c.open == line then opened = t end
        end
        local rows = math.max(1, math.ceil(#lines / across))
        local height = rows * STRIP
        for i = #lines + 1, #c.tiles do c.tiles[i]:Hide() end
        -- the drawer under its tile, or shut when its line has gone
        drawer:SetShown(opened ~= nil)
        if opened then
            local line, prof = opened.line, opened.prof
            drawer:ClearAllPoints()
            drawer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(height + 2))
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
            height = height + 2 + #line.tiers * ROW + 2
        else
            c.open = nil
        end
        c:SetHeight(height)
        return height
    end
    return c
end

