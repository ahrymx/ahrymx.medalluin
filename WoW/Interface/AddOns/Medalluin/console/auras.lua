-- Aura management on unit frames:
--   1. Border / taint glow for debuffs the player can dispel (green for Poison,
--      purple for Curse, blue for Magic, orange for Disease, red for Bleed;
--      each type's on and colour are options), else for the unit's aggro.
--   2. Crowd Control (CC): large centered icon with radial timer sweep and
--      countdown numbers.
--   3. Player-applied buffs: compact row on the outer corner of the health bar
--      (the side health decreases toward).
--   4. Boss debuffs: a large icon in the centre of the health, in the slot
--      crowd control uses (crowd control wins it).
--   5. Your debuffs on an enemy (the widgets' boss and arena cells, the
--      overhead's bosses): a row of small icons in the health's top right.
--
-- The console's frames answer to Unit Frames > Party; a widget's cell is
-- given its pieces and its tab's options by ns.AttachAuras (the raid's
-- switch to the Battleground tab's inside one).
local _, ns = ...

local Auras = C_UnitAuras
local LossOfControl = C_LossOfControl

-- The dispel types, in the order a frame with several shows them. Each has
-- an option (dispel<Type>) and a colour (dispelColor<Type>, settings.lua).
local DISPEL_PRIORITY = { "Magic", "Curse", "Poison", "Disease", "Bleed" }
ns.DISPEL_TYPES = DISPEL_PRIORITY

-- What dispels what: the class, the spell's name, the types, its ids.
-- Retail and Forever share some ids under other names (527 is Purify on
-- retail, Dispel Magic on Forever), so an id counts only under its own
-- name; a spell whose id is not here is found by its name in the
-- spellbook, the class's only (two classes have a Purify).
local DISPEL_SPELLS = {
    { "SHAMAN", "Cure Poison", { "Poison" }, 526 },
    { "SHAMAN", "Cure Disease", { "Disease" }, 2870 },
    { "SHAMAN", "Cleanse Spirit", { "Curse" }, 51886 },
    { "SHAMAN", "Purify Spirit", { "Magic", "Curse" }, 77130 },
    { "DRUID", "Remove Curse", { "Curse" }, 2782 },
    { "DRUID", "Cure Poison", { "Poison" }, 8946 },
    { "DRUID", "Abolish Poison", { "Poison" }, 2893 },
    { "DRUID", "Remove Corruption", { "Curse", "Poison" }, 2782 },
    { "DRUID", "Nature's Cure", { "Magic", "Curse", "Poison" }, 88423 },
    { "PRIEST", "Dispel Magic", { "Magic" }, 527, 988 },
    { "PRIEST", "Cure Disease", { "Disease" }, 528 },
    { "PRIEST", "Abolish Disease", { "Disease" }, 552 },
    { "PRIEST", "Purify", { "Magic", "Disease" }, 527 },
    { "PRIEST", "Purify Disease", { "Disease" }, 213634 },
    { "PALADIN", "Purify", { "Poison", "Disease" }, 1152 },
    { "PALADIN", "Cleanse", { "Magic", "Poison", "Disease" }, 4987 },
    { "PALADIN", "Cleanse Toxins", { "Poison", "Disease" }, 213644 },
    { "MAGE", "Remove Lesser Curse", { "Curse" }, 475 },
    { "MAGE", "Remove Curse", { "Curse" }, 475 },
    { "MONK", "Detox", { "Magic", "Poison", "Disease" }, 115450 },
    { "MONK", "Detox", { "Poison", "Disease" }, 218164 },
    { "EVOKER", "Naturalize", { "Magic", "Poison" }, 360823 },
    { "EVOKER", "Expunge", { "Poison" }, 365585 },
    { "EVOKER", "Cauterizing Flame", { "Bleed", "Poison", "Curse", "Disease" }, 374251 },
    -- the felhunter's and the imp's, on the pet's bar
    { "WARLOCK", "Devour Magic", { "Magic" }, 19505, 19731, 19734, 19736, 27276, 27277, pet = true },
    { "WARLOCK", "Singe Magic", { "Magic" }, 89808, 132411, pet = true },
}

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function Known(id, pet)
    if pet then return IsSpellKnown and IsSpellKnown(id, true) or false end
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

-- A spell in the spellbook by its name (the client answers only for one
-- the player has).
local function InBook(name)
    local ok, info = pcall(C_Spell and C_Spell.GetSpellInfo or GetSpellInfo, name)
    return ok and info ~= nil
end

local playerDispels = {}    -- type -> true
local dispelSpells = {}     -- the names of the spells that grant them

local function UpdatePlayerDispels()
    wipe(playerDispels)
    wipe(dispelSpells)
    local _, class = UnitClass("player")
    for _, s in ipairs(DISPEL_SPELLS) do
        if s[1] == class then
            local have = false
            for k = 4, #s do
                if Known(s[k], s.pet) and SpellName(s[k]) == s[2] then have = true end
            end
            if not have and not s.pet then have = InBook(s[2]) end
            if have then
                for _, t in ipairs(s[3]) do playerDispels[t] = true end
                local listed = false
                for _, n in ipairs(dispelSpells) do if n == s[2] then listed = true end end
                if not listed then table.insert(dispelSpells, s[2]) end
            end
        end
    end
end

-- What the player dispels: the types (in DISPEL_PRIORITY's order) and the
-- spells that do it (the Unit Frames page says so).
function ns.PlayerDispels()
    local types = {}
    for _, t in ipairs(DISPEL_PRIORITY) do if playerDispels[t] then table.insert(types, t) end end
    return types, dispelSpells
end

-- A type's colour, as the player set it.
local function DispelColor(t) return ns.HexColor(ns.db["dispelColor" .. t]) end
-- A type glows when the player dispels it and has it on.
local function Glows(t) return playerDispels[t] and ns.db["dispel" .. t] ~= false end

-- Common CC spell IDs across Classic and modern expansions
local CC_SPELLS = {
    [118] = true, [28271] = true, [28272] = true, [61305] = true, [61721] = true,
    [3355] = true, [2094] = true, [6770] = true, [20066] = true, [115078] = true,
    [51514] = true, [360806] = true, [99] = true, [31661] = true, [203340] = true,
    [853] = true, [408] = true, [1833] = true, [5211] = true, [107570] = true,
    [119381] = true, [108194] = true, [19577] = true, [305483] = true,
    [5782] = true, [5246] = true, [8122] = true, [6789] = true, [64044] = true,
    [33786] = true, [710] = true, [15487] = true, [47476] = true,
    [339] = true, [122] = true, [113724] = true,
}

local function IsCCAura(aura)
    if not aura or ns.IsSecret(aura.isHarmful) or not aura.isHarmful then return false end
    local id = aura.spellId
    if id and not ns.IsSecret(id) and CC_SPELLS[id] then return true end
    local name = aura.name
    if name and not ns.IsSecret(name) and (name:find("Polymorph") or name:find("Freezing Trap") or name:find("Fear")
        or name:find("Hammer of Justice") or name:find("Stun") or name:find("Cyclone")
        or name:find("Blind") or name:find("Sap") or name:find("Paralysis")
        or name:find("Sleep") or name:find("Silence") or name:find("Horror")
        or name:find("Incapacitate") or name:find("Hex")) then
        return true
    end
    return false
end

-- Timer text OnUpdate with throttling
local function OnTimerUpdate(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < 0.1 then return end
    self.throttle = 0
    if self.stubText then
        self.timer:SetText(self.stubText)
        return
    end
    if not self.expires then
        self.timer:SetText("")
        return
    end
    local rem = self.expires - GetTime()
    if rem <= 0 then
        self.timer:SetText("")
    elseif rem >= 10 then
        self.timer:SetFormattedText("%d", math.floor(rem + 0.5))
    elseif rem >= 3 then
        self.timer:SetFormattedText("%d", math.ceil(rem))
    else
        self.timer:SetFormattedText("%.1f", rem)
    end
end

-- A glow round a frame's edges, behind the stone console art, pulsing: a
-- debuff the player dispels, in its type's colour, or the unit's aggro.
-- The canvas's copies draw theirs with it too (options/canvas.lua).
local function CreateDispelGlow(btn, side, window)
    local f = CreateFrame("Frame", nil, btn)
    f:SetAllPoints(btn)
    f:SetFrameStrata(btn:GetFrameStrata())
    f:SetFrameLevel(ns.levels.art - 1)
    local t = 3
    local top = f:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    top:SetHeight(t)
    top:SetBlendMode("ADD")

    local btm = f:CreateTexture(nil, "OVERLAY")
    btm:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    btm:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    btm:SetHeight(t)
    btm:SetBlendMode("ADD")

    local left = f:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -t)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, t)
    left:SetWidth(t)
    left:SetBlendMode("ADD")

    local right = f:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -t)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, t)
    right:SetWidth(t)
    right:SetBlendMode("ADD")

    local edges = { top, btm, left, right }

    -- 45-degree diagonal cut on the inner end of the window, built for the
    -- windows that have one in the medallion's art and shown only while the
    -- layout says the window is cut (ns.ShapeDispelGlows)
    f.window = window
    if window == "party1" or window == "unit" then
        local h = btn:GetHeight()
        if f.CreateLine then
            local line = f:CreateLine(nil, "OVERLAY")
            if side == -1 then
                line:SetStartPoint("TOPRIGHT", f, -h, 0)
                line:SetEndPoint("BOTTOMRIGHT", f, 0, 0)
            else
                line:SetStartPoint("TOPLEFT", f, h, 0)
                line:SetEndPoint("BOTTOMLEFT", f, 0, 0)
            end
            line:SetThickness(t)
            line:SetBlendMode("ADD")
            table.insert(edges, line)
            f.cut = line
        else
            local diag = f:CreateTexture(nil, "OVERLAY")
            local len = math.ceil(math.sqrt(h * h + h * h))
            diag:SetSize(len, t)
            if side == -1 then
                diag:SetPoint("CENTER", f, "TOPRIGHT", -h / 2, -h / 2)
                if diag.SetRotation then diag:SetRotation(-math.pi / 4) end
            else
                diag:SetPoint("CENTER", f, "TOPLEFT", h / 2, -h / 2)
                if diag.SetRotation then diag:SetRotation(math.pi / 4) end
            end
            diag:SetBlendMode("ADD")
            table.insert(edges, diag)
            f.cut = diag
        end
    end

    for _, e in ipairs(edges) do e:SetColorTexture(1, 1, 1, 1) end

    function f:SetGlowColor(r, g, b, a)
        for _, e in ipairs(edges) do e:SetVertexColor(r, g, b, a or 0.85) end
    end

    f:SetScript("OnUpdate", function(self, elapsed)
        self.pulse = (self.pulse or 0) + elapsed * 3
        local alpha = 0.65 + 0.35 * math.abs(math.sin(self.pulse))
        self:SetAlpha(alpha)
    end)
    f:Hide()
    return f
end
ns.EdgeGlow = CreateDispelGlow

-- CC Centerpiece widget
local function CreateCCWidget(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    f:SetFrameLevel(ns.levels.text + 2)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(unpack(ns.colors.ink))

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetSwipeColor(0, 0, 0, 0.75)
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetDrawSwipe(true)
    if f.cooldown.SetHideCountdownNumbers then
        f.cooldown:SetHideCountdownNumbers(true)
    end

    f.timer = ns.Text(f.cooldown, size <= 26 and 11 or 13)
    f.timer:SetPoint("CENTER", f.cooldown, "CENTER", 0, 0)
    f.timer:SetTextColor(1, 0.9, 0.2)

    f:SetScript("OnUpdate", OnTimerUpdate)
    f:Hide()
    return f
end

-- An aura's tooltip, the first way the client has: by its instance as a
-- buff or a debuff (with the filter it was found by: an aura looked up
-- with the wrong one is no aura, and the tooltip stays empty), by its
-- instance alone, else by its index (the older clients). Each may refuse
-- an aura the game keeps secret; the next is tried.
local function AuraTip(self)
    local unit, id, filter = self.unit, self.auraInstanceID, self.filter
    local harmful = filter and filter:find("HARMFUL") and true or false
    local typed = harmful and GameTooltip.SetUnitDebuffByAuraInstanceID or GameTooltip.SetUnitBuffByAuraInstanceID
    for _, try in ipairs({
        { typed, unit, id, filter },
        { GameTooltip.SetUnitAuraByAuraInstanceID, unit, id, filter },
        { self.auraIndex and GameTooltip.SetUnitAura, unit, self.auraIndex, filter },
    }) do
        if try[1] and try[3] and pcall(try[1], GameTooltip, try[2], try[3], try[4]) and GameTooltip:NumLines() > 0 then
            return true
        end
    end
    return false
end

local function AttachTooltip(btn)
    btn:SetScript("OnEnter", function(self)
        if not self.auraInstanceID and not self.auraIndex and not self.tooltipTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipTitle then
            GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
            if self.tooltipDesc then
                GameTooltip:AddLine(self.tooltipDesc, 0.7, 0.7, 0.7, true)
            end
        elseif not (self.unit and AuraTip(self)) then
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

-- Which aura a widget shows, for its tooltip: unit, instance, the filter
-- and index it was read by (nil for a widget filled another way).
local function Holds(btn, unit, aura, filter, index)
    btn.unit, btn.auraInstanceID, btn.filter, btn.auraIndex = unit, aura and aura.auraInstanceID, filter, index
    btn.tooltipTitle, btn.tooltipDesc = nil, nil
end

-- The rows: buffs at the health's outer corner (where health decreases toward),
-- debuffs at its inner one.
-- A row's icons: as many as the editor's Max may ask for, of which the
-- row shows its default (buttons.default) until it does (ns.RowMax).
local POOL = 10

local ICON, GAP = 15, 2

-- The row from its outer corner inward. Again when the party's side changes
-- (the light row mirrors where the console's slots did not: ns.PartySide).
local function LayBuffs(health, buttons, side)
    local point = (buttons.isParty and "TOP" or "BOTTOM") .. (side == -1 and "LEFT" or "RIGHT")
    local offsetY = buttons.isParty and -2 or 2
    for i, btn in ipairs(buttons) do
        local step = (i - 1) * (ICON + GAP)
        btn:ClearAllPoints()
        btn:SetPoint(point, health, point, side == -1 and (2 + step) or (-2 - step), offsetY)
    end
end

-- A frame's debuffs, level with its buffs at the other (inner) end, running
-- outward. Only the rows laid by side (a console unit's, the Party
-- widget's): the widgets' own stay where they were made.
local function LayDebuffs(health, buttons, side)
    local point = (buttons.isParty and "TOP" or "BOTTOM") .. (side == -1 and "RIGHT" or "LEFT")
    local offsetY = buttons.isParty and -2 or 2
    for i, btn in ipairs(buttons) do
        local step = (i - 1) * (ICON + GAP)
        btn:ClearAllPoints()
        btn:SetPoint(point, health, point, side == -1 and (-2 - step) or (2 + step), offsetY)
    end
end

function ns.LayBuffs(b, side)
    if b.buffWidgets then LayBuffs(b.health, b.buffWidgets, side) end
    if b.mineWidgets and b.mineWidgets.bySide then LayDebuffs(b.health, b.mineWidgets, side) end
end

-- An icon of a row: an inked square, the aura's icon, its spiral, its stacks.
local function RowIcon(health, size)
    local btn = CreateFrame("Button", nil, health)
    btn:SetSize(size, size)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(unpack(ns.colors.ink))
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetDrawSwipe(true)
    if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end
    btn.count = ns.Text(btn, 9)
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.count:SetTextColor(1, 1, 1)
    AttachTooltip(btn)
    btn:Hide()
    return btn
end

local function CreateBuffWidgets(health, side, isParty)
    local buttons = { default = isParty and 3 or 4, isParty = isParty, from = "mine" }

    for _ = 1, POOL do
        local btn = RowIcon(health, ICON)
        btn:SetFrameLevel(ns.levels.text + 1)
        table.insert(buttons, btn)
    end
    LayBuffs(health, buttons, side)
    return buttons
end

-- Boss debuff centerpiece widget: shares the center threat slot with CC (Priority B)
local function CreateBossDebuffWidget(health, size)
    local btn = CreateFrame("Button", nil, health)
    btn:SetSize(size, size)
    btn:SetPoint("CENTER", health, "CENTER", 0, 0)
    btn:SetFrameLevel(ns.levels.text + 2)

    local rim = btn:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0.90, 0.15, 0.15, 1)

    local ink = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(unpack(ns.colors.ink))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1.5, -1.5)
    btn.icon:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetSwipeColor(0, 0, 0, 0.75)
    btn.cooldown:SetDrawEdge(true)
    btn.cooldown:SetDrawSwipe(true)
    if btn.cooldown.SetHideCountdownNumbers then
        btn.cooldown:SetHideCountdownNumbers(true)
    end

    btn.timer = ns.Text(btn.cooldown, size <= 26 and 11 or 13)
    btn.timer:SetPoint("CENTER", btn.cooldown, "CENTER", 0, 0)
    btn.timer:SetTextColor(1, 0.9, 0.2)

    btn.count = ns.Text(btn, 10)
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.count:SetTextColor(1, 1, 1)

    btn:SetScript("OnUpdate", OnTimerUpdate)
    AttachTooltip(btn)
    btn:Hide()
    return btn
end

-- The preview's auras, by unit: a debuff to dispel, crowd control, your
-- buffs, a boss debuff, and how many of your debuffs (an enemy).
-- The simulated auras: each the simulation panel has on falls on at least
-- one frame of its set (ns.SimHas, core.lua). A unit's set, its place in it
-- and how many the set shows:
local function SimPlace(unit)
    local kind, i = (unit or ""):match("^(%a+)(%d+)$")
    i = tonumber(i)
    if kind == "party" then return "party", i, ns.sim.party.count end
    if kind == "raidpreview" then return "raid", i, ns.sim.raid.groups * 5 end
    if kind == "boss" then return "enemies", i, ns.sim.enemies.bosses end
    if kind == "arena" then return "enemies", i, ns.sim.enemies.arena end
end

local MINE = { 3, 1, 2 }    -- how many of your debuffs, enemy by enemy
-- A simulated frame's debuff to dispel: the types the player glows for,
-- frame by frame; every type in turn when none does, to see the colours.
local function SimDispel(i)
    local types = {}
    for _, t in ipairs(DISPEL_PRIORITY) do if Glows(t) then table.insert(types, t) end end
    if not types[1] then types = DISPEL_PRIORITY end
    return types[(i - 1) % #types + 1]
end
local function StubAuras(unit)
    local set, i, n = SimPlace(unit)
    if not set then return {} end
    local function has(key) return ns.SimHas(set, key, i, n) end
    return { glow = has("glow") and SimDispel(i), cc = has("cc"), buffs = has("buffs"), boss = has("boss"),
        mine = has("mine") and MINE[(i - 1) % 3 + 1] }
end
local MINE_ICONS = { "Spell_Shadow_ShadowWordPain", "Spell_Holy_SearingLight", "Spell_Shadow_AbominationExplosion" }
-- The preview's icons, for the editor's canvas too (options/canvas.lua).
ns.STUB_ICONS = {
    cc = "Interface\\Icons\\Spell_Nature_Polymorph",
    boss = "Interface\\Icons\\Ability_Creature_Cursed_01",
    buffs = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Nature_ResistNature",
        "Interface\\Icons\\Spell_Holy_Renew" },
    mine = {},
}
for k, icon in ipairs(MINE_ICONS) do ns.STUB_ICONS.mine[k] = "Interface\\Icons\\" .. icon end

-- Whether a frame shows one kind of aura: the option its tab gives it. The
-- console's party buttons answer to the Party widget's own while they are in
-- it (ns.PartyKey); the player's and target's to the console's.
local CONSOLE_KEYS = { glow = "auraGlow", threat = "auraThreat", cc = "auraCC", buffs = "auraBuffs", boss = "auraBoss",
    mine = "auraDebuffs" }
local function Shows(b, kind)
    local keys = b.auraKeys or CONSOLE_KEYS
    if type(keys) == "function" then keys = keys() end
    local key = keys[kind]
    if key and not b.auraKeys and b.unit:match("^party%d$") then key = ns.PartyKey(key) end
    return key and ns.db[key] ~= false or false
end

-- Applies stub simulation auras when simParty is true
local function ApplyStubAuras(b)
    local want = StubAuras(b.unit)
    -- Dispel glow stub
    if b.dispelGlow then
        if want.glow and Shows(b, "glow") then
            b.dispelGlow:SetGlowColor(DispelColor(want.glow))
            b.dispelGlow:Show()
        else
            b.dispelGlow:Hide()
        end
    end

    -- CC Centerpiece stub (sheeped)
    local cc = false
    if b.ccWidget then
        if want.cc and Shows(b, "cc") then
            b.ccWidget.icon:SetTexture("Interface\\Icons\\Spell_Nature_Polymorph")
            b.ccWidget.stubText = "4"
            b.ccWidget.expires = nil
            b.ccWidget.timer:SetText("4")
            b.ccWidget:Show()
            cc = true
        else
            b.ccWidget:Hide()
        end
    end

    -- Player buffs stub (personal HoTs)
    if b.buffWidgets then
        for _, btn in ipairs(b.buffWidgets) do btn:Hide() end
        if want.buffs and Shows(b, "buffs") then
            local max = ns.RowMax(b, "buffs")
            local b1 = max >= 1 and b.buffWidgets[1]
            if b1 then
                b1.icon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
                b1.count:SetText("")
                b1.tooltipTitle = "Rejuvenation"
                b1.tooltipDesc = "Heals 1,420 over 15 sec."
                b1:Show()
            end
            local b2 = max >= 2 and b.buffWidgets[2]
            if b2 then
                b2.icon:SetTexture("Interface\\Icons\\Spell_Nature_ResistNature")
                b2.count:SetText("3")
                b2.tooltipTitle = "Lifebloom (3)"
                b2.tooltipDesc = "Heals 3,150 over 15 sec. When it expires, blooms for direct healing."
                b2:Show()
            end
        end
    end

    -- Boss debuff stub (a critical boss aura, shown in the centerpiece)
    if b.bossDebuff then
        if want.boss and Shows(b, "boss") and not cc then
            b.bossDebuff.icon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_01")
            b.bossDebuff.stubText = "8"
            b.bossDebuff.expires = nil
            b.bossDebuff.timer:SetText("8")
            b.bossDebuff.count:SetText("2")
            b.bossDebuff.tooltipTitle = "Cursed Agony"
            b.bossDebuff.tooltipDesc = "Critical encounter mechanic. Inflicts heavy shadow damage every 2 sec."
            b.bossDebuff:Show()
        else
            b.bossDebuff:Hide()
        end
    end

    -- Debuffs stub (an enemy with your damage over time on it, a member hurt)
    if b.mineWidgets then
        local n = want.mine and Shows(b, "mine") and math.min(want.mine, ns.RowMax(b, "mine")) or 0
        for k, btn in ipairs(b.mineWidgets) do
            if k <= n then
                btn.icon:SetTexture("Interface\\Icons\\" .. MINE_ICONS[k])
                btn.count:SetText("")
                btn.tooltipTitle = "Debuff " .. k
                btn.tooltipDesc = "Simulated"
            end
            btn:SetShown(k <= n)
        end
        if b.mineLaid then b.mineLaid(n) end
    end
end

local function IsTimeless(unit, aura)
    if not aura then return false end
    if Auras and Auras.DoesAuraHaveExpirationTime and not ns.IsSecret(aura.auraInstanceID) then
        local ok, timed = pcall(Auras.DoesAuraHaveExpirationTime, unit, aura.auraInstanceID)
        if ok and not ns.IsSecret(timed) and timed ~= nil then
            return not timed
        end
    end
    local exp = aura.expirationTime
    local dur = aura.duration
    if not ns.IsSecret(exp) and not ns.IsSecret(dur) then
        if (exp == nil or exp == 0) and (dur == nil or dur == 0) then
            return true
        end
    end
    return false
end

-- One aura by index, or nil past the last. The client can refuse the read
-- outright: an aura it holds secret is an error to addon code, not a secret
-- value (C_UnitAuras' RequiresUnitAuraAccess). It does so inside a secure
-- call such as TargetUnit (a key bound to Target self), whose
-- PLAYER_TARGET_CHANGED reaches this before the call returns. A refused read
-- ends its list as if the list had, and is marked: the frame scans again once
-- the call is over (UpdateUnitAuras).
local refused = false
local function Read(unit, i, filter)
    local ok, aura = pcall(Auras.GetAuraDataByIndex, unit, i, filter)
    if ok then return aura end
    refused = true
    return nil
end

-- A cooldown's spiral from its aura's duration object, for times that are
-- secret: SetCooldown takes no secret from an addon, the object it may.
-- Cleared, and left so where the client has neither call (or no aura).
local function Spiral(cd, unit, id)
    cd:Clear()
    local ok, dur = pcall(Auras and Auras.GetAuraDuration, unit, id)
    if ok then pcall(cd.SetCooldownFromDurationObject, cd, dur) end
end

-- Live aura scanning for active units
local function ScanUnitAuras(b)
    local unit = b.unit
    local isAlly = unit == "player" or (UnitIsFriend and UnitIsFriend("player", unit))

    -- 1. Dispel Glow
    local bestDispel = nil
    if isAlly and b.dispelGlow and Shows(b, "glow") and Auras and Auras.GetAuraDataByIndex then
        local i = 1
        while true do
            local aura = Read(unit, i, "HARMFUL")
            if not aura then break end
            local d = aura.dispelName
            if d and not ns.IsSecret(d) and Glows(d) then
                if not bestDispel then
                    bestDispel = d
                else
                    for _, p in ipairs(DISPEL_PRIORITY) do
                        if p == d then bestDispel = d; break
                        elseif p == bestDispel then break end
                    end
                end
            end
            i = i + 1
        end
    end
    if b.dispelGlow then
        if bestDispel then
            b.dispelGlow:SetGlowColor(DispelColor(bestDispel))
            b.dispelGlow:Show()
        else
            b.dispelGlow:Hide()
        end
    end

    -- 2. Crowd Control (CC)
    local ccAura, ccIndex = nil, nil
    if b.ccWidget and Shows(b, "cc") then
        if unit == "player" and LossOfControl and LossOfControl.GetActiveLossOfControlDataCount then
            local count = LossOfControl.GetActiveLossOfControlDataCount()
            if count and count > 0 then
                local loc = LossOfControl.GetActiveLossOfControlData(1)
                if loc and loc.iconTexture then
                    -- its times are secret in combat: no sum of them then
                    -- (the spiral comes from its aura's duration instead)
                    local start, duration = loc.startTime, loc.duration
                    local open = not ns.IsSecret(start) and not ns.IsSecret(duration)
                    ccAura = {
                        icon = loc.iconTexture,
                        duration = duration,
                        expirationTime = open and start and duration and (start + duration) or nil,
                        auraInstanceID = loc.auraInstanceID,
                    }
                end
            end
        end
        if not ccAura and Auras and Auras.GetAuraDataByIndex then
            local i = 1
            while true do
                local aura = Read(unit, i, "HARMFUL")
                if not aura then break end
                if IsCCAura(aura) then
                    ccAura, ccIndex = aura, i
                    break
                end
                i = i + 1
            end
        end
    end
    if b.ccWidget then
        if ccAura then
            b.ccWidget.icon:SetTexture(ccAura.icon)
            -- (the loss of control's: by its instance, when it has one)
            Holds(b.ccWidget, unit, ccAura, "HARMFUL", ccIndex)
            b.ccWidget.stubText = nil
            if ccAura.duration and ccAura.expirationTime and not ns.IsSecret(ccAura.duration)
                and ccAura.duration > 0 then
                b.ccWidget.cooldown:SetCooldown(ccAura.expirationTime - ccAura.duration, ccAura.duration)
                b.ccWidget.expires = ccAura.expirationTime
            else
                b.ccWidget.expires = nil
                b.ccWidget.timer:SetText("")
                Spiral(b.ccWidget.cooldown, unit, ccAura.auraInstanceID)
            end
            b.ccWidget:Show()
        else
            b.ccWidget:Hide()
        end
    end

    -- 3. Buffs: yours, or all (the row's From)
    if b.buffWidgets then
        for _, btn in ipairs(b.buffWidgets) do btn:Hide() end
        if Shows(b, "buffs") and Auras and Auras.GetAuraDataByIndex then
            local idx = 1
            local btnIdx = 1
            local max = ns.RowMax(b, "buffs")
            local filter = ns.RowFrom(b, "buffs") == "all" and "HELPFUL" or "HELPFUL|PLAYER"
            while btnIdx <= max do
                local aura = Read(unit, idx, filter)
                if not aura then break end
                -- Do not show timeless buffs on the player frame
                if not (unit == "player" and IsTimeless(unit, aura)) then
                    local btn = b.buffWidgets[btnIdx]
                    Holds(btn, unit, aura, filter, idx)
                    btn.icon:SetTexture(aura.icon)
                    local n = aura.applications
                    btn.count:SetText((n and not ns.IsSecret(n) and n > 1) and tostring(n) or "")
                    if aura.duration and aura.expirationTime and not ns.IsSecret(aura.duration)
                        and aura.duration > 0 then
                        btn.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                    end
                    btn:Show()
                    btnIdx = btnIdx + 1
                end
                idx = idx + 1
            end
        end
    end

    -- 4. Boss Debuffs (shares the center threat slot with CC; P0 is CC, P1 is Boss Debuff)
    local bossAura, bossIndex = nil, nil
    if b.bossDebuff and Shows(b, "boss") and not ccAura and Auras and Auras.GetAuraDataByIndex then
        local i = 1
        while true do
            local aura = Read(unit, i, "HARMFUL")
            if not aura then break end
            if not ns.IsSecret(aura.isBossAura) and aura.isBossAura then
                bossAura, bossIndex = aura, i
                break
            end
            i = i + 1
        end
    end
    if b.bossDebuff then
        if bossAura and not ccAura then
            Holds(b.bossDebuff, unit, bossAura, "HARMFUL", bossIndex)
            b.bossDebuff.icon:SetTexture(bossAura.icon)
            b.bossDebuff.stubText = nil
            local n = bossAura.applications
            b.bossDebuff.count:SetText((n and not ns.IsSecret(n) and n > 1) and tostring(n) or "")
            if bossAura.duration and bossAura.expirationTime and not ns.IsSecret(bossAura.duration)
                and bossAura.duration > 0 then
                b.bossDebuff.cooldown:SetCooldown(bossAura.expirationTime - bossAura.duration, bossAura.duration)
                b.bossDebuff.expires = bossAura.expirationTime
            else
                b.bossDebuff.expires = nil
                b.bossDebuff.timer:SetText("")
            end
            b.bossDebuff:Show()
        else
            b.bossDebuff:Hide()
        end
    end

    -- 5. Debuffs: yours (on an enemy), or all (the row's From)
    if b.mineWidgets then
        local n = 0
        if Shows(b, "mine") and Auras and Auras.GetAuraDataByIndex then
            local max = ns.RowMax(b, "mine")
            local filter = ns.RowFrom(b, "mine") == "all" and "HARMFUL" or "HARMFUL|PLAYER"
            while n < max do
                local aura = Read(unit, n + 1, filter)
                if not aura then break end
                n = n + 1
                local btn = b.mineWidgets[n]
                Holds(btn, unit, aura, filter, n)
                btn.icon:SetTexture(aura.icon)
                local stacks = aura.applications
                btn.count:SetText((stacks and not ns.IsSecret(stacks) and stacks > 1) and tostring(stacks) or "")
                if aura.duration and aura.expirationTime and not ns.IsSecret(aura.duration)
                    and aura.duration > 0 then
                    btn.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                end
            end
        end
        for k, btn in ipairs(b.mineWidgets) do btn:SetShown(k <= n) end
        if b.mineLaid then b.mineLaid(n) end
    end
end

-- The aggro glow: the unit is tanking something (a threat situation of 2
-- or more), and the border is not the dispel glow's. Not in the preview
-- (the editor's canvas shows it); hidden where the game keeps it secret.
local function UpdateThreat(b)
    local g = b.threatGlow
    if not g then return end
    local show = false
    if Shows(b, "threat") and UnitExists(b.unit) and not (b.dispelGlow and b.dispelGlow:IsShown()) then
        local s = UnitThreatSituation and UnitThreatSituation(b.unit)
        show = s ~= nil and not ns.IsSecret(s) and s >= 2
    end
    if show then g:SetGlowColor(ns.HexColor(ns.db.threatColor)) end
    g:SetShown(show)
end

-- Every aura piece a frame has, hidden.
local function HideAuras(b)
    if b.dispelGlow then b.dispelGlow:Hide() end
    if b.threatGlow then b.threatGlow:Hide() end
    if b.ccWidget then b.ccWidget:Hide() end
    if b.bossDebuff then b.bossDebuff:Hide() end
    for _, btn in ipairs(b.buffWidgets or {}) do btn:Hide() end
    for _, btn in ipairs(b.mineWidgets or {}) do btn:Hide() end
    if b.mineLaid then b.mineLaid(0) end
end

local UpdateUnitAuras
-- retry: the scan again after a refused read, which is not tried a third time
-- (the next aura event scans anyway)
function UpdateUnitAuras(b, retry)
    if not b then return end
    local unit = b.unit
    if not unit or (not UnitExists(unit) and not b.stub) then
        HideAuras(b)
        return
    end

    -- Ready checks and role checks hide buffs and debuffs while active
    if b.isChecking or (b.statusWidget and b.statusWidget:IsShown()) then
        HideAuras(b)
        return
    end

    if b.stub and not UnitExists(unit) then
        ApplyStubAuras(b)
    else
        refused = false
        ScanUnitAuras(b)
        if refused and not retry and C_Timer and C_Timer.After then
            C_Timer.After(0, function() UpdateUnitAuras(b, true) end)
        end
    end
    UpdateThreat(b)
end
ns.UpdateUnitAuras = UpdateUnitAuras

-- The widgets' cells and the overhead's bosses that carry auras (ns.AttachAuras).
local carriers = {}

local function UpdateAllAuras()
    UpdatePlayerDispels()
    for _, b in pairs(ns.units or {}) do
        UpdateUnitAuras(b)
    end
    if ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        UpdateUnitAuras(ns.partyWidgetPlayer)
    end
    for b in pairs(carriers) do UpdateUnitAuras(b) end
end
ns.UpdateAllAuras = UpdateAllAuras   -- the simulation panel's aura toggles (simulate.lua)

-- Debuffs: three icons (the editor's Max more), from point inward along
-- the health's edge (right to left from a right corner). from: whose, as
-- the row has it untouched (ns.RowFrom).
local function CreateMineWidgets(health, size, point, y, from)
    local buttons = { default = 3, from = from or "mine" }
    local dir = point:find("LEFT") and 1 or -1
    for i = 1, POOL do
        local btn = RowIcon(health, size)
        btn:SetPoint(point, health, point, dir * (2 + (i - 1) * (size + 2)), y)
        buttons[i] = btn
    end
    return buttons
end

-- A console unit's (or the Party widget's player's) debuffs: every one on
-- it, at the inner end level with its buffs (LayDebuffs).
local function CreateUnitDebuffs(health, side, isParty)
    local buttons = CreateMineWidgets(health, ICON, "CENTER", 0, "all")
    buttons.default, buttons.isParty, buttons.bySide = isParty and 3 or 4, isParty, true
    for _, btn in ipairs(buttons) do btn:SetFrameLevel(ns.levels.text + 1) end
    LayDebuffs(health, buttons, side)
    return buttons
end

-- Initialize widgets on each unit frame
for unit, b in pairs(ns.units or {}) do
    local window, side = unpack(ns.slots[unit])
    local isParty = window ~= "unit"

    b.dispelGlow = CreateDispelGlow(b, side, window)
    b.threatGlow = CreateDispelGlow(b, side, window)
    b.ccWidget = CreateCCWidget(b.health, isParty and 24 or 32)
    b.buffWidgets = CreateBuffWidgets(b.health, side, isParty)
    b.mineWidgets = CreateUnitDebuffs(b.health, side, isParty)
    b.bossDebuff = CreateBossDebuffWidget(b.health, isParty and 24 or 32)
end
if ns.partyWidgetPlayer then
    local b = ns.partyWidgetPlayer
    b.auraKeys = { glow = "partyWidgetGlow", threat = "partyWidgetThreat", cc = "partyWidgetCC",
        buffs = "partyWidgetBuffs", boss = "partyWidgetBoss", mine = "partyWidgetDebuffs" }
    b.dispelGlow = CreateDispelGlow(b, -1)
    b.threatGlow = CreateDispelGlow(b, -1)
    b.ccWidget = CreateCCWidget(b.health, 24)
    b.buffWidgets = CreateBuffWidgets(b.health, -1, true)
    b.mineWidgets = CreateUnitDebuffs(b.health, -1, true)
    b.bossDebuff = CreateBossDebuffWidget(b.health, 24)
    b:HookScript("OnHide", HideAuras)
end

-- In a battleground, the raid's cells answer to the Battleground tab.
local RAID_KEYS = { glow = "raidGlow", threat = "raidThreat", cc = "raidCC", boss = "raidBoss", mine = "raidDebuffs" }
local BG_KEYS = { glow = "bgGlow", threat = "bgThreat", cc = "bgCC", mine = "bgDebuffs" }
function ns.InBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end
local function RaidKeys() return ns.InBattleground() and BG_KEYS or RAID_KEYS end
ns.RaidAuraKeys = RaidKeys

-- A widget's cell, or an overhead boss, given its aura pieces and the
-- options that rule them (Unit Frames' tabs), by kind:
--   "raid": the dispel glow on the border; crowd control or a boss debuff
--           in the middle of the health (the draft's A, gen_cell_auras.py);
--           every debuff on it in the health's bottom right
--   "boss", "arena": your debuffs in the health's top right; on arena,
--           crowd control in the middle
--   "overhead": the overhead's boss, too short for a row over its name: your
--           debuffs (size square) at the health's right end, its value
--           stepping left of them
function ns.AttachAuras(b, kind, size)
    local level = b:GetFrameLevel()
    local function Over(f, by) f:SetFrameLevel(level + by) end
    if kind == "raid" then
        b.auraKeys = RaidKeys
        b.dispelGlow = CreateDispelGlow(b, 1)
        Over(b.dispelGlow, 3)
        b.threatGlow = CreateDispelGlow(b, 1)
        Over(b.threatGlow, 3)
        b.ccWidget = CreateCCWidget(b.health, 20)
        Over(b.ccWidget, 4)
        b.bossDebuff = CreateBossDebuffWidget(b.health, 20)
        Over(b.bossDebuff, 4)
        b.mineWidgets = CreateMineWidgets(b.health, 12, "BOTTOMRIGHT", 2, "all")
    elseif kind == "arena" then
        b.auraKeys = { cc = "arenaCC", mine = "arenaMine" }
        b.ccWidget = CreateCCWidget(b.health, 20)
        Over(b.ccWidget, 4)
    elseif kind == "boss" then
        b.auraKeys = { mine = "bossWidgetMine" }
    else
        b.auraKeys = { mine = "bossMine" }
    end
    if kind == "boss" or kind == "arena" then
        b.mineWidgets = CreateMineWidgets(b.health, 14, "TOPRIGHT", -2)
    elseif kind == "overhead" then
        b.mineWidgets = CreateMineWidgets(b.health, size, "RIGHT", 0)
        local value = b.value
        b.mineLaid = function(n)
            value:ClearAllPoints()
            if n > 0 then
                value:SetPoint("RIGHT", b.mineWidgets[n], "LEFT", -3, 0)
            else
                value:SetPoint("RIGHT", value:GetParent(), "RIGHT", -4, 0)
            end
        end
    end
    for _, btn in ipairs(b.mineWidgets or {}) do Over(btn, 4) end
    -- a cell gone takes its auras with it; shown, its owner draws them again
    b:HookScript("OnHide", HideAuras)
    carriers[b] = true
end

-- The glow's cut follows the layout's. A cut is built shown, which is the
-- medallion's; the light profile swaps its layout in after this file has run,
-- and ns.RelayoutUnits (called by ns.ApplyLightProfile) reshapes the glows.
function ns.ShapeDispelGlows()
    local cuts = ns.layout.cuts or {}
    for _, b in pairs(ns.units or {}) do
        -- a party button in the widget is a plain rectangle (widgets/party.lua)
        for _, g in ipairs({ b.dispelGlow, b.threatGlow }) do
            if g.cut then g.cut:SetShown(cuts[g.window] and not b.inWidget and true or false) end
        end
    end
end

local events = CreateFrame("Frame")
for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    ns.RegisterUnitEvent(events, "UNIT_AURA", unit)
end
events:SetScript("OnEvent", function(_, _, unit)
    if ns.units and ns.units[unit] then
        UpdateUnitAuras(ns.units[unit])
    end
    if unit == "player" and ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        UpdateUnitAuras(ns.partyWidgetPlayer)
    end
end)

-- A unit's aggro, wherever its frames are.
local threat = CreateFrame("Frame")
threat:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
threat:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
threat:SetScript("OnEvent", function(_, _, unit)
    if not unit then return end
    if ns.units and ns.units[unit] then UpdateThreat(ns.units[unit]) end
    if unit == "player" and ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        UpdateThreat(ns.partyWidgetPlayer)
    end
    for b in pairs(carriers) do if b.unit == unit then UpdateThreat(b) end end
end)

local loc = CreateFrame("Frame")
loc:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
loc:RegisterEvent("LOSS_OF_CONTROL_ADDED")
loc:SetScript("OnEvent", function()
    if ns.units and ns.units.player then
        UpdateUnitAuras(ns.units.player)
    end
    if ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        UpdateUnitAuras(ns.partyWidgetPlayer)
    end
end)

UpdatePlayerDispels()
ns.On("PLAYER_SPECIALIZATION_CHANGED", UpdateAllAuras)
ns.On("SPELLS_CHANGED", UpdateAllAuras)
ns.On("GROUP_ROSTER_UPDATE", UpdateAllAuras)
ns.On("PLAYER_TARGET_CHANGED", function()
    if ns.units and ns.units.target then
        UpdateUnitAuras(ns.units.target)
    end
end)
ns.On("PLAYER_ENTERING_WORLD", UpdateAllAuras)
ns.On("ADDON_LOADED", UpdateAllAuras)

ns.OnSetting("auraGlow", UpdateAllAuras)
ns.OnSetting("auraCC", UpdateAllAuras)
ns.OnSetting("auraBuffs", UpdateAllAuras)
ns.OnSetting("auraBoss", UpdateAllAuras)
ns.OnSetting("auraThreat", UpdateAllAuras)
ns.OnSetting("threatColor", UpdateAllAuras)
for _, t in ipairs(DISPEL_PRIORITY) do
    ns.OnSetting("dispel" .. t, UpdateAllAuras)
    ns.OnSetting("dispelColor" .. t, UpdateAllAuras)
end
for _, key in ipairs({ "raidGlow", "raidCC", "raidBoss", "bgGlow", "bgCC", "bossMine", "bossWidgetMine", "arenaCC",
    "arenaMine", "partyWidgetGlow", "partyWidgetCC", "partyWidgetBuffs", "partyWidgetBoss", "partyLayout",
    "partyWidgetThreat", "raidThreat", "bgThreat", "auraDebuffs", "partyWidgetDebuffs", "raidDebuffs",
    "bgDebuffs" }) do
    ns.OnSetting(key, UpdateAllAuras)
end
ns.OnSetting("simParty", UpdateAllAuras)
