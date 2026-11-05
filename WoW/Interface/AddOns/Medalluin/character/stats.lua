-- The Character page's details: the stats, as the reference draws them.
--
--     Crit      Haste    [ 322 ]    Mastery    Vers       <- the ribbon
--     39%       25%        ilvl     14%        12%
--   Agility        2,505          Parry               3%
--   Stamina       38,553          Leech               9%
--   ...                           ...
--   [arcane] 0  [fire] 0  [frost] 0  [nature] 0  [shadow] 0   <- Forever
--
-- The ribbon has four of the stats that matter most on the client around
-- the item level: retail's secondary stats, or Forever's hit, crit, haste
-- and armour. Under it, two columns of the rest, read by the functions
-- Blizzard's own pane calls; a row whose function this client lacks (or
-- that raises) is left out, and its column closes up. Forever adds the
-- five resistances.
--
-- Crit, hit and haste are the best of melee, ranged and spell, as one
-- number serves every class.
local _, ns = ...

local ROW, RIBBON, BADGE, GAP = 15, 38, 46, 6
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local SCHOOLS = { "Arcane", "Fire", "Frost", "Nature", "Shadow" }
local SCHOOL_CLASS = { Arcane = 6, Fire = 2, Frost = 4, Nature = 3, Shadow = 5 }   -- Enum.Damageclass

local function Best(...)
    local best
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" and (not best or v > best) then best = v end
    end
    return best
end

local function Percent(v) return format("%.0f%%", v) end
local function Whole(v)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(math.floor(v + 0.5)) end
    return tostring(math.floor(v + 0.5))
end

local function SpellSchools(fn)
    if not fn then return end
    local best
    for school = 2, 7 do best = Best(best, fn(school)) end
    return best
end

local function Rating(cr)
    if not (cr and GetCombatRatingBonus) then return 0 end
    return GetCombatRatingBonus(cr) or 0
end

local function Crit()
    return Best(GetCritChance and GetCritChance(), GetRangedCritChance and GetRangedCritChance(),
        SpellSchools(GetSpellCritChance))
end

local function Haste()
    return Best(GetHaste and GetHaste(), GetMeleeHaste and GetMeleeHaste(), GetRangedHaste and GetRangedHaste(),
        UnitSpellHaste and UnitSpellHaste("player"))
end

local function Hit()
    local melee = (GetHitModifier and GetHitModifier() or 0) + Rating(CR_HIT_MELEE)
    local spell = (GetSpellHitModifier and GetSpellHitModifier() or 0) + Rating(CR_HIT_SPELL)
    return Best(melee, spell)
end

local function Armor() return select(2, UnitArmor("player")) end
local function Stat(i) return function() return select(2, UnitStat("player", i)) end end

local function PrimaryName()
    local best, at = -1, 1
    for _, i in ipairs({ 1, 2, 4 }) do
        local v = select(2, UnitStat("player", i))
        if v > best then best, at = v, i end
    end
    return _G["SPELL_STAT" .. at .. "_NAME"] or ({ "Strength", "Agility", "", "Intellect" })[at], at
end

local function Speed()
    local _, run = GetUnitSpeed("player")
    return run / (BASE_MOVEMENT_SPEED or 7) * 100
end

local function Power() return UnitPowerMax("player") end
local function PowerName()
    local _, token = UnitPowerType("player")
    return token and _G[token] or "Power"
end

-- { label, value (a function), format }; a label may be a function too
local FOREVER = {
    ribbon = {
        { "Hit", Hit, Percent }, { "Crit", Crit, Percent },
        { "Haste", Haste, Percent }, { "Armor", Armor, Whole },
    },
    left = {
        { "Health", function() return UnitHealthMax("player") end, Whole },
        { PowerName, Power, Whole },
        { "Strength", Stat(1), Whole }, { "Agility", Stat(2), Whole }, { "Stamina", Stat(3), Whole },
        { "Intellect", Stat(4), Whole }, { "Spirit", Stat(5), Whole },
    },
    right = {
        { "Attack Power", function()
            local base, pos, neg = UnitAttackPower("player")
            return base + pos + neg
        end, Whole },
        { "Spell Power", function() return SpellSchools(GetSpellBonusDamage) end, Whole },
        { "Healing", function() return GetSpellBonusHealing() end, Whole },
        { "Defense", function()
            local base, mod = UnitDefenseSkill("player")
            return base + mod
        end, Whole },
        { "Dodge", function() return GetDodgeChance() end, Percent },
        { "Parry", function() return GetParryChance() end, Percent },
        { "Block", function() return GetBlockChance() end, Percent },
    },
    resist = true,
}

local RETAIL = {
    ribbon = {
        { "Crit", Crit, Percent }, { "Haste", Haste, Percent },
        { "Mastery", function() return GetMasteryEffect() end, Percent },
        { "Vers", function()
            return Rating(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        end, Percent },
    },
    left = {
        { PrimaryName, function() return select(2, UnitStat("player", select(2, PrimaryName()))) end, Whole },
        { "Stamina", Stat(3), Whole },
        { "Armor", Armor, Whole },
        { "Dodge", function() return GetDodgeChance() end, Percent },
    },
    right = {
        { "Parry", function() return GetParryChance() end, Percent },
        { "Leech", function() return GetLifesteal() end, Percent },
        { "Avoidance", function() return GetAvoidance() end, Percent },
        { "Movement Speed", Speed, Percent },
    },
}

local layout, ribbon, badge, columns, resist
local stats = { height = 0 }
ns.character.stats = stats

-- a value, or nothing when this client cannot give it; a secret one (the
-- player's health and power on the clients that hide them) shortened by
-- the one formatter that takes it, or shown as it is
local function Read(entry)
    local ok, v = pcall(entry[2])
    if not ok then return end
    if ns.IsSecret(v) then
        local fine, text = pcall(AbbreviateLargeNumbers, v)
        return fine and text or v
    end
    if type(v) ~= "number" then return end
    local ok2, text = pcall(entry[3], v)
    if ok2 then return text end
end

local function Label(entry)
    local l = entry[1]
    return type(l) == "function" and l() or l
end

-- ------------------------------------------------------------- the ribbon
local function Cell(foot, i)
    local c = CreateFrame("Frame", nil, foot)
    c.label = ns.Text(c, 9)
    c.label:SetPoint("TOP", 0, -5)
    c.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.value = ns.Text(c, 13)
    c.value:SetPoint("BOTTOM", 0, 5)
    c.index = i
    return c
end

local function Ribbon(foot)
    local frame = CreateFrame("Frame", nil, foot)
    frame:SetPoint("TOPLEFT")
    frame:SetPoint("TOPRIGHT")
    frame:SetHeight(RIBBON)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    -- the badge in the middle, standing out of the ribbon at both edges
    badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(BADGE, RIBBON + 6)
    badge:SetPoint("CENTER")
    local bEdge = badge:CreateTexture(nil, "BACKGROUND", nil, 1)
    bEdge:SetAllPoints()
    bEdge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local bWell = badge:CreateTexture(nil, "BACKGROUND", nil, 2)
    bWell:SetPoint("TOPLEFT", 1, -1)
    bWell:SetPoint("BOTTOMRIGHT", -1, 1)
    bWell:SetColorTexture(0.24, 0.16, 0.08, 1)
    badge.value = ns.Text(badge, 15)
    badge.value:SetPoint("CENTER", 0, 4)
    badge.value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    badge.label = ns.Text(badge, 8)
    badge.label:SetPoint("BOTTOM", 0, 5)
    badge.label:SetText("ilvl")
    badge.label:SetTextColor(unpack(ns.colors.dim))
    -- two cells each side, each a quarter of what the badge leaves
    local cells = {}
    local width = ns.character.width
    local cell = (width - BADGE) / 4
    for i = 1, 4 do
        local c = Cell(frame, i)
        c:SetSize(cell, RIBBON)
        local x = (i - 1) * cell + (i > 2 and BADGE or 0)
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        cells[i] = c
    end
    return frame, cells
end

-- -------------------------------------------------------------- columns
local function Rows(foot, entries, side)
    local list = {}
    for i = 1, #entries do
        local r = CreateFrame("Frame", nil, foot)
        r:SetHeight(ROW)
        local half = ns.character.width / 2
        r:SetWidth(half - 8)
        r.side = side
        r.label = ns.Text(r, 10)
        r.label:SetPoint("LEFT", 4, 0)
        r.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        r.value = ns.Text(r, 10)
        r.value:SetPoint("RIGHT", -4, 0)
        list[i] = r
    end
    return list
end

local function Resist(foot)
    local frame = CreateFrame("Frame", nil, foot)
    frame:SetHeight(16)
    frame:SetPoint("BOTTOMLEFT")
    frame:SetPoint("BOTTOMRIGHT")
    frame.cells = {}
    local each = ns.character.width / #SCHOOLS
    for i, school in ipairs(SCHOOLS) do
        local c = CreateFrame("Frame", nil, frame)
        c:SetSize(each, 16)
        c:SetPoint("LEFT", (i - 1) * each, 0)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(14, 14)
        c.icon:SetPoint("RIGHT", c, "CENTER", -1, 0)
        c.icon:SetAtlas("UI-Character-Info-Resistance-" .. school)
        c.value = ns.Text(c, 10)
        c.value:SetPoint("LEFT", c, "CENTER", 2, 0)
        c.school = school
        frame.cells[i] = c
    end
    return frame
end

function stats.Build(foot)
    layout = SkillsFrame and FOREVER or RETAIL
    local cells
    ribbon, cells = Ribbon(foot)
    ribbon.cells = cells
    columns = { left = Rows(foot, layout.left, -1), right = Rows(foot, layout.right, 1) }
    local rows = math.max(#layout.left, #layout.right)
    stats.height = RIBBON + 3 + GAP + rows * ROW
    -- a gold rule down between the two columns
    local split = foot:CreateTexture(nil, "ARTWORK")
    split:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    split:SetSize(1, rows * ROW - 4)
    split:SetPoint("TOP", foot, "TOP", 0, -(RIBBON + 3 + GAP + 2))
    stats.split = split
    if layout.resist then
        resist = Resist(foot)
        stats.height = stats.height + GAP + 16
    end
    stats.ribbon, stats.badge, stats.columns, stats.resist = ribbon, badge, columns, resist
    stats.forever = layout == FOREVER
end

-- One column: the rows that read, top down; the rest hidden.
local function Fill(rows, entries, side)
    local y = RIBBON + 3 + GAP
    for i, entry in ipairs(entries) do
        local r = rows[i]
        local text = Read(entry)
        r:SetShown(text ~= nil)
        if text then
            r.label:SetText(Label(entry))
            r.value:SetText(text)
            r:ClearAllPoints()
            r:SetPoint(side < 0 and "TOPLEFT" or "TOPRIGHT", r:GetParent(), side < 0 and "TOPLEFT" or "TOPRIGHT",
                0, -y)
            y = y + ROW
        end
    end
end

function stats.Refresh()
    for i, entry in ipairs(layout.ribbon) do
        local c = ribbon.cells[i]
        c.label:SetText(Label(entry))
        c.value:SetText(Read(entry) or "--")
    end
    local avg, equipped
    if GetAverageItemLevel then avg, equipped = GetAverageItemLevel() end
    local level = equipped or avg
    badge.value:SetText(level and tostring(math.floor(level)) or "--")
    Fill(columns.left, layout.left, -1)
    Fill(columns.right, layout.right, 1)
    if resist then
        for _, c in ipairs(resist.cells) do
            -- base, real, effective, bonus: the effective one, as Blizzard's pane shows
            local ok, _, _, total = pcall(UnitResistance, "player", SCHOOL_CLASS[c.school])
            c.value:SetText(ok and type(total) == "number" and Whole(total) or "--")
        end
    end
end
