-- Overhead Console: Top-of-screen Cascading Inverted Ziggurat housing:
--   Tier 1 (Boss Deck): Encounter Boss frames (boss1..boss5)
--   Tier 2 (Companion Deck): Player Pet (pet), Focus (focus), Target of Target (targettarget)
--   Tier 3 (Command Deck): Pet Action Bar and Stance / Shapeshift Bar
local _, ns = ...

local C = ns.colors

local function Muted(r, g, b)
    return r * ns.mute, g * ns.mute, b * ns.mute
end

local function HealthColor(unit)
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        return unpack(C.dead)
    end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = not ns.IsSecret(class) and class and RAID_CLASS_COLORS[class]
        if c then return Muted(c.r, c.g, c.b) end
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then
        return unpack(C.dead)
    end
    local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
    return Muted(c.r, c.g, c.b)
end

local overhead = CreateFrame("Frame", "MedaluinOverhead", UIParent)
overhead:SetFrameStrata("LOW")
overhead:SetPoint("TOP", UIParent, "TOP", 0, 0)
ns.overhead = overhead

local base = overhead:GetFrameLevel()
local LEVELS = {
    backing = base + 1,
    bars = base + 2,
    cast = base + 3,
    stone = base + 5,
    buttons = base + 6,
    text = base + 8,
}

local function Rescale()
    ns.OutOfCombat(function()
        local dh = ns.layout and ns.layout.designHeight or 1080
        overhead:SetScale(UIParent:GetHeight() / dh)
    end)
end
Rescale()
ns.On("UI_SCALE_CHANGED", Rescale)
ns.On("DISPLAY_SIZE_CHANGED", Rescale)
ns.On("PLAYER_ENTERING_WORLD", Rescale)

-- ------------------------------------------------------------ Deck builder
local function CreateTierDeck(name, height)
    local deck = CreateFrame("Frame", "MedaluinOverhead_" .. name, overhead)
    deck:SetHeight(height)
    deck.deckHeight = height

    local stone = CreateFrame("Frame", nil, deck)
    stone:SetAllPoints()
    stone:SetFrameLevel(LEVELS.stone)
    deck.stone = stone

    local leftCap = stone:CreateTexture(nil, "ARTWORK")
    leftCap:SetSize(32, height)
    leftCap:SetPoint("TOPLEFT", stone, "TOPLEFT", 0, 0)
    leftCap:SetTexture(ns.media .. "overhead-left")
    leftCap:SetTexCoord(0, 32 / 64, 0, height / 32)
    deck.leftCap = leftCap

    local rightCap = stone:CreateTexture(nil, "ARTWORK")
    rightCap:SetSize(32, height)
    rightCap:SetPoint("TOPRIGHT", stone, "TOPRIGHT", 0, 0)
    rightCap:SetTexture(ns.media .. "overhead-right")
    rightCap:SetTexCoord(32 / 64, 1, 0, height / 32)
    deck.rightCap = rightCap

    local mid = stone:CreateTexture(nil, "ARTWORK")
    mid:SetHeight(height)
    mid:SetPoint("TOPLEFT", leftCap, "TOPRIGHT", 0, 0)
    mid:SetPoint("BOTTOMRIGHT", rightCap, "BOTTOMLEFT", 0, 0)
    mid:SetTexture(ns.media .. "overhead-mid")
    mid:SetTexCoord(0, 1, 0, height / 32)
    deck.mid = mid

    local bg = deck:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 14, 0)
    bg:SetPoint("BOTTOMRIGHT", -14, 0)
    bg:SetColorTexture(unpack(ns.colors.ink))
    deck.bg = bg

    deck.dividers = {}

    function deck:SetDeckWidth(w)
        deck.width = w
        deck.w = w
        deck:SetWidth(w)
        deck.stone:SetWidth(w)
    end

    function deck:ClearDividers()
        for _, d in ipairs(deck.dividers) do d:Hide() end
    end

    function deck:AddDivider(x)
        local d
        for _, existing in ipairs(deck.dividers) do
            if not existing:IsShown() then d = existing; break end
        end
        if not d then
            d = stone:CreateTexture(nil, "OVERLAY")
            d:SetSize(12, height)
            d:SetTexture(ns.media .. "overhead-seam")
            d:SetTexCoord(2 / 16, 14 / 16, 0, height / 32)
            table.insert(deck.dividers, d)
        end
        d:ClearAllPoints()
        d:SetPoint("CENTER", stone, "LEFT", x, 0)
        d:Show()
    end

    return deck
end

local tier1 = CreateTierDeck("Tier1", 28)
local tier2 = CreateTierDeck("Tier2", 26)
local tier3 = CreateTierDeck("Tier3", 30)

ns.overheadTier1 = tier1
ns.overheadTier2 = tier2
ns.overheadTier3 = tier3

-- ------------------------------------------------------------ Unit Frame creation
local function CreateOverheadUnit(parent, unit, isBoss)
    local b = CreateFrame("Button", "MedaluinUnit_" .. unit, parent, "SecureUnitButtonTemplate")
    b.unit = unit
    b:SetFrameLevel(LEVELS.bars)
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")

    local powerH = 4

    local bar = CreateFrame("StatusBar", nil, b)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2 + powerH)
    bar:SetStatusBarTexture(ns.bar)
    b.health = bar

    local power = CreateFrame("StatusBar", nil, b)
    power:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -1)
    power:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    power:SetStatusBarTexture(ns.bar)
    b.power = power

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(unpack(ns.colors.ink))
    b.bg = bg

    local text = CreateFrame("Frame", nil, b)
    text:SetAllPoints(b)
    text:SetFrameLevel(LEVELS.text)

    b.name = ns.Text(text, 10)
    b.name:SetPoint("LEFT", text, "LEFT", 6, isBoss and 2 or 1)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    b.value = ns.Text(text, 10)
    b.value:SetPoint("RIGHT", text, "RIGHT", -6, isBoss and 2 or 1)
    b.value:SetJustifyH("RIGHT")
    b.value:SetTextColor(unpack(C.dim))

    -- Integrated cast bar
    local cast = CreateFrame("StatusBar", nil, b)
    cast:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    cast:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    cast:SetStatusBarTexture(ns.bar)
    cast:SetStatusBarColor(0.85, 0.65, 0.15, 0.85)
    cast:SetFrameLevel(LEVELS.cast)
    cast:Hide()
    b.cast = cast

    local castText = ns.Text(text, 9)
    castText:SetPoint("CENTER", b, "CENTER", 0, 0)
    castText:SetTextColor(1, 0.9, 0.4)
    b.castText = castText

    RegisterUnitWatch(b)
    b:Hide()
    return b
end

local bossUnits = {}
for i = 1, 5 do
    bossUnits[i] = CreateOverheadUnit(tier1, "boss" .. i, true)
end

local petUnit = CreateOverheadUnit(tier2, "pet", false)
local focusUnit = CreateOverheadUnit(tier2, "focus", false)
local totUnit = CreateOverheadUnit(tier2, "targettarget", false)

ns.overheadUnits = {
    pet = petUnit,
    focus = focusUnit,
    targettarget = totUnit,
    boss1 = bossUnits[1],
    boss2 = bossUnits[2],
    boss3 = bossUnits[3],
    boss4 = bossUnits[4],
    boss5 = bossUnits[5],
}

-- ------------------------------------------------------------ Unit Update Logic
local function UpdateUnitStatus(b)
    if not b then return end
    local stub = b.stub
    if stub then
        b.health:SetMinMaxValues(0, stub.maxHealth or 100)
        b.health:SetValue(stub.health or 100)
        local c = RAID_CLASS_COLORS[stub.class] or FACTION_BAR_COLORS[2]
        if c then b.health:SetStatusBarColor(Muted(c.r, c.g, c.b)) end
        b.name:SetText(stub.name or b.unit)
        b.value:SetFormattedText("%.0f%%", math.floor((stub.health or 100) / (stub.maxHealth or 100) * 100 + 0.5))
        b.power:SetMinMaxValues(0, 100)
        b.power:SetValue(stub.power or 80)
        b.power:SetStatusBarColor(0.2, 0.5, 0.85)
        return
    end

    local unit = b.unit
    if not UnitExists(unit) then return end

    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    b.health:SetMinMaxValues(0, max)
    b.health:SetValue(cur)
    b.health:SetStatusBarColor(HealthColor(unit))

    b.name:SetText(ns.Or(UnitName(unit), unit))
    if not UnitIsConnected(unit) then
        b.value:SetText(PLAYER_OFFLINE)
    elseif UnitIsDeadOrGhost(unit) then
        b.value:SetText(DEAD)
    else
        local pct = (not ns.IsSecret(cur) and not ns.IsSecret(max) and max > 0)
            and math.floor(cur / max * 100 + 0.5) or 100
        b.value:SetFormattedText("%d%%", pct)
    end

    local pMax = UnitPowerMax(unit)
    local pCur = UnitPower(unit)
    if not ns.IsSecret(pMax) and pMax <= 0 then pMax = 1 end
    b.power:SetMinMaxValues(0, pMax)
    b.power:SetValue(pCur)
    local c = PowerBarColor[UnitPowerType(unit)] or PowerBarColor.MANA
    b.power:SetStatusBarColor(Muted(c.r, c.g, c.b))
end

-- ------------------------------------------------------------ Stances & Pet Action Bar
local stanceButtons = {}
local petActionButtons = {}

local function AdoptCommandButtons()
    if ns.db and ns.db.overhead == false then return end

    -- Stances
    if ns.db and ns.db.topStances ~= false then
        for i = 1, 10 do
            local btn = _G["StanceButton" .. i]
            if btn then
                btn:SetParent(tier3)
                btn:SetFrameStrata(tier3:GetFrameStrata())
                btn:SetFrameLevel(LEVELS.buttons)
                btn:SetSize(22, 22)
                if ns.StyleButton and ns.db.bareIcons then ns.StyleButton(btn) end
                table.insert(stanceButtons, btn)
            end
        end
    end

    -- Pet Action Bar
    if ns.db and ns.db.topPetBar ~= false then
        for i = 1, 10 do
            local btn = _G["PetActionButton" .. i]
            if btn then
                btn:SetParent(tier3)
                btn:SetFrameStrata(tier3:GetFrameStrata())
                btn:SetFrameLevel(LEVELS.buttons)
                btn:SetSize(22, 22)
                if ns.StyleButton and ns.db.bareIcons then ns.StyleButton(btn) end
                table.insert(petActionButtons, btn)
            end
        end
    end
end

-- ------------------------------------------------------------ Dynamic Layout Reflow
local OVERHEAD_STUBS = {
    boss1 = { name = "High Warlord Naj'entus", health = 85, maxHealth = 100, power = 100, class = "WARRIOR" },
    boss2 = { name = "Supremus", health = 92, maxHealth = 100, power = 50, class = "WARRIOR" },
    pet = { name = "Shadowfiend", health = 75, maxHealth = 100, power = 80, class = "PRIEST" },
    focus = { name = "Lady Sacrolash", health = 60, maxHealth = 100, power = 100, class = "MAGE" },
    targettarget = { name = "Main Tank", health = 88, maxHealth = 100, power = 40, class = "WARRIOR" },
}

local function UpdateOverhead()
    if ns.db and ns.db.overhead == false then
        overhead:Hide()
        return
    end

    local sim = ns.db and ns.db.simParty
    local slope = 14

    -- 1. Evaluate Tier 1 (Boss Deck)
    local activeBosses = {}
    if ns.db and ns.db.topBoss ~= false then
        for i = 1, 5 do
            local b = bossUnits[i]
            local exists = UnitExists("boss" .. i)
            if not exists and sim and OVERHEAD_STUBS["boss" .. i] then
                b.stub = OVERHEAD_STUBS["boss" .. i]
                exists = true
            else
                b.stub = nil
            end
            if exists then
                table.insert(activeBosses, b)
                UpdateUnitStatus(b)
            end
        end
    end

    local t1Shown = #activeBosses > 0
    local w1 = 0
    if t1Shown then
        local count = #activeBosses
        if count == 1 then w1 = 380
        elseif count == 2 then w1 = 520
        elseif count == 3 then w1 = 620
        else w1 = 700 end

        tier1:SetDeckWidth(w1)
        tier1:ClearDividers()

        local usableW = w1 - slope * 2
        local colW = usableW / count
        for idx, b in ipairs(activeBosses) do
            b:ClearAllPoints()
            local startX = slope + (idx - 1) * colW
            b:SetPoint("TOPLEFT", tier1, "TOPLEFT", startX, 0)
            b:SetSize(colW, tier1.deckHeight)
            b:Show()
            if idx > 1 then
                tier1:AddDivider(startX)
            end
        end
        for i = count + 1, 5 do bossUnits[i]:Hide() end

        tier1:ClearAllPoints()
        tier1:SetPoint("TOP", overhead, "TOP", 0, 0)
        tier1:Show()
    else
        tier1:Hide()
        for i = 1, 5 do bossUnits[i]:Hide() end
    end

    -- 2. Evaluate Tier 2 (Companion Deck: pet, focus, tot)
    local activeUnits = {}
    local function CheckUnit(b, key)
        if ns.db and ns.db[key] == false then
            b.stub = nil
            b:Hide()
            return
        end
        local exists = UnitExists(b.unit)
        if not exists and sim and OVERHEAD_STUBS[b.unit] then
            b.stub = OVERHEAD_STUBS[b.unit]
            exists = true
        else
            b.stub = nil
        end
        if exists then
            table.insert(activeUnits, b)
            UpdateUnitStatus(b)
        else
            b:Hide()
        end
    end

    CheckUnit(petUnit, "topPet")
    CheckUnit(focusUnit, "topFocus")
    CheckUnit(totUnit, "topToT")

    local t2Shown = #activeUnits > 0
    local w2 = 0
    if t2Shown then
        local count = #activeUnits
        if count == 1 then w2 = 220
        elseif count == 2 then w2 = 360
        else w2 = 480 end

        -- Inset narrower than Tier 1 if Tier 1 is shown
        if t1Shown and w2 >= (w1 - slope * 2) then
            w2 = math.max(180, w1 - slope * 2 - 20)
        end

        tier2:SetDeckWidth(w2)
        tier2:ClearDividers()

        local usableW = w2 - slope * 2
        local colW = usableW / count
        for idx, b in ipairs(activeUnits) do
            b:ClearAllPoints()
            local startX = slope + (idx - 1) * colW
            b:SetPoint("TOPLEFT", tier2, "TOPLEFT", startX, 0)
            b:SetSize(colW, tier2.deckHeight)
            b:Show()
            if idx > 1 then
                tier2:AddDivider(startX)
            end
        end

        tier2:ClearAllPoints()
        if t1Shown then
            tier2:SetPoint("TOP", tier1, "BOTTOM", 0, 0)
        else
            tier2:SetPoint("TOP", overhead, "TOP", 0, 0)
        end
        tier2:Show()
    else
        tier2:Hide()
    end

    -- 3. Evaluate Tier 3 (Command Deck: stances & pet action buttons)
    local activeButtons = {}
    if ns.db and ns.db.topStances ~= false then
        for _, btn in ipairs(stanceButtons) do
            if btn:IsShown() or sim then
                table.insert(activeButtons, btn)
            end
        end
    end
    if ns.db and ns.db.topPetBar ~= false then
        for _, btn in ipairs(petActionButtons) do
            if btn:IsShown() or (sim and #activeButtons < 8) then
                table.insert(activeButtons, btn)
            end
        end
    end

    local t3Shown = #activeButtons > 0
    if t3Shown then
        local btnSize = 22
        local gap = 3
        local btnTotal = #activeButtons * btnSize + (#activeButtons - 1) * gap
        local w3 = btnTotal + slope * 2 + 16

        -- Inset narrower than upper tier
        local parentW = t2Shown and w2 or (t1Shown and w1 or 0)
        if parentW > 0 and w3 >= (parentW - slope * 2) then
            w3 = math.max(140, parentW - slope * 2 - 10)
        end

        tier3:SetDeckWidth(w3)
        tier3:ClearDividers()

        local startX = (w3 - btnTotal) / 2
        for idx, btn in ipairs(activeButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", tier3, "LEFT", startX + (idx - 1) * (btnSize + gap), 0)
            btn:Show()
        end

        tier3:ClearAllPoints()
        if t2Shown then
            tier3:SetPoint("TOP", tier2, "BOTTOM", 0, 0)
        elseif t1Shown then
            tier3:SetPoint("TOP", tier1, "BOTTOM", 0, 0)
        else
            tier3:SetPoint("TOP", overhead, "TOP", 0, 0)
        end
        tier3:Show()
    else
        tier3:Hide()
    end

    -- Container visibility
    if t1Shown or t2Shown or t3Shown then
        overhead:Show()
    else
        overhead:Hide()
    end
end
ns.UpdateOverhead = UpdateOverhead

-- ------------------------------------------------------------ Events & Watchers
ns.On("PLAYER_LOGIN", AdoptCommandButtons)
ns.On("PLAYER_LOGIN", UpdateOverhead)
ns.On("PLAYER_ENTERING_WORLD", UpdateOverhead)
ns.On("GROUP_ROSTER_UPDATE", UpdateOverhead)
ns.On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", UpdateOverhead)
ns.On("UNIT_TARGET", function(u)
    if u == "target" or u == "player" then UpdateOverhead() end
end)
ns.On("PLAYER_TARGET_CHANGED", UpdateOverhead)
ns.On("PLAYER_FOCUS_CHANGED", UpdateOverhead)
ns.On("UNIT_PET", function(u)
    if u == "player" then UpdateOverhead() end
end)
ns.On("UPDATE_SHAPESHIFT_FORMS", UpdateOverhead)
ns.On("UPDATE_SHAPESHIFT_FORM", UpdateOverhead)
ns.On("PET_BAR_UPDATE", UpdateOverhead)

local unitWatcher = CreateFrame("Frame")
for _, u in ipairs({ "pet", "focus", "targettarget", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
    ns.RegisterUnitEvent(unitWatcher, "UNIT_HEALTH", u)
    ns.RegisterUnitEvent(unitWatcher, "UNIT_MAXHEALTH", u)
    ns.RegisterUnitEvent(unitWatcher, "UNIT_POWER_UPDATE", u)
    ns.RegisterUnitEvent(unitWatcher, "UNIT_NAME_UPDATE", u)
end
unitWatcher:SetScript("OnEvent", function(_, _, u)
    local b = ns.overheadUnits[u]
    if b then UpdateUnitStatus(b) end
end)

ns.OnSetting("overhead", UpdateOverhead)
ns.OnSetting("topBoss", UpdateOverhead)
ns.OnSetting("topPet", UpdateOverhead)
ns.OnSetting("topFocus", UpdateOverhead)
ns.OnSetting("topToT", UpdateOverhead)
ns.OnSetting("topPetBar", UpdateOverhead)
ns.OnSetting("topStances", UpdateOverhead)
ns.OnSetting("simParty", UpdateOverhead)
