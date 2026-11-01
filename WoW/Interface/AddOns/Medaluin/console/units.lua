-- Unit buttons: one secure button per slot, each a single rectangle (power
-- and health share it, flush against each other), placed in its window. The left
-- copy fills from the left edge, the right copy mirrors it.
local _, ns = ...

local console, L, C = ns.console, ns.layout, ns.colors

local function Muted(r, g, b)
    return r * ns.mute, g * ns.mute, b * ns.mute
end

local function HealthColor(unit)
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        return unpack(C.dead)
    end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        -- a restricted unit's class is secret, and a secret cannot be a key
        local c = not ns.IsSecret(class) and class and RAID_CLASS_COLORS[class]
        if c then return Muted(c.r, c.g, c.b) end
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then
        return unpack(C.dead)
    end
    local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
    return Muted(c.r, c.g, c.b)
end

-- Health may be secret in combat (Forever, retail): the bar takes the
-- numbers as they come, and the percentage comes from UnitHealthPercent
-- through a 0-100 curve, so no Lua arithmetic ever touches a secret.
-- (Blizzard's own ScaleTo100 curve, where it is loaded.)
local percentCurve
if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve then
    percentCurve = CurveConstants and CurveConstants.ScaleTo100
    if not percentCurve then
        percentCurve = C_CurveUtil.CreateCurve()
        percentCurve:SetType(Enum.LuaCurveType.Linear)
        percentCurve:AddPoint(0, 0)
        percentCurve:AddPoint(1, 100)
    end
end

local function HealthPercent(unit, cur, max)
    if percentCurve then return UnitHealthPercent(unit, false, percentCurve) end
    return max > 0 and math.floor(cur / max * 100 + 0.5) or 0
end

local function PowerPercent(unit, cur, max)
    if UnitPowerPercent and percentCurve then return UnitPowerPercent(unit, false, percentCurve) end
    if ns.IsSecret(cur) or ns.IsSecret(max) then return nil end
    return max > 0 and math.floor(cur / max * 100 + 0.5) or 0
end

local function FormatPower(cur)
    if ns.IsSecret(cur) then return cur end
    if cur >= 1e6 then
        return (cur % 1e6 == 0) and string.format("%.0fm", cur / 1e6) or string.format("%.1fm", cur / 1e6)
    elseif cur >= 1e4 then
        return string.format("%.0fk", cur / 1e3)
    elseif cur >= 1e3 then
        return (cur % 1000 == 0) and string.format("%.0fk", cur / 1e3) or string.format("%.1fk", cur / 1e3)
    else
        return string.format("%d", math.floor(cur + 0.5))
    end
end

local function UpdateHealth(self)
    local stub = self.stub
    if stub then
        self.health:SetMinMaxValues(0, stub.maxHealth)
        self.health:SetValue(stub.health)
        local c = RAID_CLASS_COLORS[stub.class]
        if c then self.health:SetStatusBarColor(Muted(c.r, c.g, c.b)) end
        if self.value then
            self.value:SetFormattedText("%.0f%%", math.floor(stub.health / stub.maxHealth * 100 + 0.5))
        end
        return
    end
    local unit = self.unit
    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    self.health:SetMinMaxValues(0, max)
    self.health:SetValue(cur)
    self.health:SetStatusBarColor(HealthColor(unit))
    if not self.value then return end
    if not UnitIsConnected(unit) then
        self.value:SetText(PLAYER_OFFLINE)
    elseif UnitIsDeadOrGhost(unit) then
        self.value:SetText(DEAD)
    else
        self.value:SetFormattedText("%.0f%%", HealthPercent(unit, cur, max))
    end
end

local function UpdatePower(self)
    local stub = self.stub
    if stub then
        self.power:SetShown(true)
        self.power:SetMinMaxValues(0, stub.maxPower)
        self.power:SetValue(stub.power)
        local c = PowerBarColor[stub.powerType] or PowerBarColor.MANA
        if c then self.power:SetStatusBarColor(Muted(c.r, c.g, c.b)) end
        if self.powerValue then
            self.powerValue:SetFormattedText("%s | %d%%", FormatPower(stub.power),
                math.floor(stub.power / stub.maxPower * 100 + 0.5))
        end
        return
    end
    local unit = self.unit
    local max = UnitPowerMax(unit)
    -- a unit with no power of this type shows no bar; a secret max is shown
    self.power:SetShown(ns.IsSecret(max) or max > 0)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    self.power:SetMinMaxValues(0, max)
    local cur = UnitPower(unit)
    self.power:SetValue(cur)
    local c = PowerBarColor[UnitPowerType(unit)] or PowerBarColor.MANA
    self.power:SetStatusBarColor(Muted(c.r, c.g, c.b))
    if not self.powerValue then return end
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) or not self.power:IsShown() then
        self.powerValue:SetText("")
        return
    end
    if ns.IsSecret(cur) or ns.IsSecret(max) then
        local pct = PowerPercent(unit, cur, max)
        if pct then
            self.powerValue:SetFormattedText("%s | %.0f%%", cur, pct)
        else
            self.powerValue:SetText(cur)
        end
    else
        self.powerValue:SetFormattedText("%s | %d%%", FormatPower(cur), PowerPercent(unit, cur, max))
    end
end

local function UpdateName(self)
    if self.stub then
        self.name:SetText(self.stub.name)
        return
    end
    -- a secret name still displays
    self.name:SetText(ns.Or(UnitName(self.unit), ""))
end

local function UpdateAll(self)
    if not UnitExists(self.unit) and not self.stub then return end
    UpdateName(self)
    UpdateHealth(self)
    UpdatePower(self)
end

local STUBS = {
    party1 = { name = "Party 1", class = "PRIEST", powerType = 0, health = 85, maxHealth = 100,
        power = 80, maxPower = 100 },
    party2 = { name = "Party 2", class = "MAGE", powerType = 0, health = 92, maxHealth = 100,
        power = 100, maxPower = 100 },
    party3 = { name = "Party 3", class = "WARRIOR", powerType = 1, health = 78, maxHealth = 100,
        power = 45, maxPower = 100 },
    party4 = { name = "Party 4", class = "ROGUE", powerType = 3, health = 88, maxHealth = 100,
        power = 70, maxPower = 100 },
}

local function UpdatePartyUnit(b)
    local unit = b.unit
    local sim = ns.db and ns.db.simParty
    if UnitExists(unit) then
        b.stub = nil
        ns.OutOfCombat(function()
            RegisterUnitWatch(b)
        end)
        UpdateAll(b)
    elseif sim then
        b.stub = STUBS[unit]
        ns.OutOfCombat(function()
            if UnregisterUnitWatch then UnregisterUnitWatch(b) end
            if not b:IsShown() then b:Show() end
        end)
        UpdateAll(b)
    else
        b.stub = nil
        ns.OutOfCombat(function()
            RegisterUnitWatch(b)
            if b:IsShown() then b:Hide() end
        end)
    end
end

local function UpdateState(self)
    UpdateHealth(self)
    UpdatePower(self)
end

local unitEvents = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_HEALTH_FREQUENT = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateState,
    UNIT_FACTION = UpdateHealth,
    UNIT_FLAGS = UpdateState,
    UNIT_POWER_FREQUENT = UpdatePower,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_NAME_UPDATE = UpdateName,
}

local function Bar(parent, side)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.bar)
    bar:SetReverseFill(side == 1)
    return bar
end

local function Spawn(unit)
    local window, side = unpack(ns.slots[unit])
    local isParty = window ~= "unit"
    local style = isParty and L.party or L.unit

    local b = CreateFrame("Button", "MedaluinUnit_" .. unit, console, "SecureUnitButtonTemplate")
    b.unit = unit
    b:SetFrameLevel(ns.levels.bars)
    ns.PlaceOn(b, console, window, side)
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnEnter", function(self)
        if self.stub and not UnitExists(self.unit) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.stub.name, 1, 1, 1)
            GameTooltip:AddLine("Simulated party member", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        elseif UnitFrame_OnEnter then
            UnitFrame_OnEnter(self)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self.stub and not UnitExists(self.unit) then
            GameTooltip_Hide()
        elseif UnitFrame_OnLeave then
            UnitFrame_OnLeave(self)
        end
    end)

    -- Player and target: power and health. Party flips it across the beam.
    local h = b:GetHeight()
    b.power, b.health = Bar(b, side), Bar(b, side)
    b.power:SetHeight(style.power)
    b.power:SetPoint("LEFT")
    b.power:SetPoint("RIGHT")
    b.health:SetHeight(h - style.power - style.seam)
    b.health:SetPoint("LEFT")
    b.health:SetPoint("RIGHT")
    local healthEdge, powerEdge = "TOP", "BOTTOM"
    if not isParty then healthEdge, powerEdge = "BOTTOM", "TOP" end
    b.health:SetPoint(healthEdge)
    b.power:SetPoint(powerEdge)

    -- Text sits above the art; the name keeps to the outer end, the value
    -- to the inner end, short of the window's 45-degree cut.
    local text = CreateFrame("Frame", nil, b)
    text:SetAllPoints(b.health)
    text:SetFrameLevel(ns.levels.text)
    local outer = side == 1 and "RIGHT" or "LEFT"
    local inner = side == 1 and "LEFT" or "RIGHT"
    b.name = ns.Text(text, style.nameSize)
    b.name:SetPoint(outer, text, outer, -side * style.textInset, 0)
    if not isParty then
        b.value = ns.Text(text, style.valueSize)
        b.value:SetTextColor(unpack(C.dim))
        b.value:SetPoint(inner, text, inner, side * style.valueInset, 0)
        b.name:SetPoint(inner, b.value, outer, side * 6, 0)
        b.name:SetJustifyH(outer)

        local ptext = CreateFrame("Frame", nil, b.power)
        ptext:SetAllPoints(b.power)
        ptext:SetFrameLevel(ns.levels.text)
        b.powerValue = ns.Text(ptext, style.powerSize)
        b.powerValue:SetTextColor(unpack(C.dim))
        b.powerValue:SetPoint("CENTER", ptext, "CENTER", 0, 0)
        b.powerValue:SetJustifyH("CENTER")
        b.powerValue:SetWordWrap(false)
    else
        b.name:SetPoint(inner, text, inner, side * style.textInset, 0)
        b.name:SetJustifyH(outer)
    end
    b.name:SetWordWrap(false)

    for event in pairs(unitEvents) do
        ns.RegisterUnitEvent(b, event, unit)
    end
    b:SetScript("OnEvent", function(self, event)
        local fn = unitEvents[event]
        if fn then
            fn(self)
        elseif self.unit:match("^party") then
            UpdatePartyUnit(self)
        else
            UpdateAll(self)
        end
    end)
    b:SetScript("OnShow", UpdateAll)

    if unit == "player" then
        b:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        -- target and party buttons show only while their unit exists
        RegisterUnitWatch(b)
        b:RegisterEvent(unit == "target" and "PLAYER_TARGET_CHANGED" or "GROUP_ROSTER_UPDATE")
    end
    return b
end

ns.units = {}
for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    ns.units[unit] = Spawn(unit)
end

local function UpdatePartyFrames()
    for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do
        local b = ns.units[unit]
        if b then UpdatePartyUnit(b) end
    end
end
UpdatePartyFrames()
ns.On("GROUP_ROSTER_UPDATE", UpdatePartyFrames)
ns.On("PLAYER_ENTERING_WORLD", UpdatePartyFrames)
ns.On("ADDON_LOADED", UpdatePartyFrames)
ns.OnSetting("simParty", UpdatePartyFrames)
