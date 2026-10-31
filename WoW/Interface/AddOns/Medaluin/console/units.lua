-- Unit buttons: one secure button per slot, each a single rectangle (power
-- and health share it, split by a seam), placed in its window. The left
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
        local c = class and RAID_CLASS_COLORS[class]
        if c then return Muted(c.r, c.g, c.b) end
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then
        return unpack(C.dead)
    end
    local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
    return Muted(c.r, c.g, c.b)
end

local function UpdateHealth(self)
    local unit = self.unit
    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    self.health:SetMinMaxValues(0, max > 0 and max or 1)
    self.health:SetValue(cur)
    self.health:SetStatusBarColor(HealthColor(unit))
    if not self.value then return end
    if not UnitIsConnected(unit) then
        self.value:SetText(PLAYER_OFFLINE)
    elseif UnitIsDeadOrGhost(unit) then
        self.value:SetText(DEAD)
    else
        self.value:SetFormattedText("%d%%", max > 0 and math.floor(cur / max * 100 + 0.5) or 0)
    end
end

local function UpdatePower(self)
    local unit = self.unit
    local max = UnitPowerMax(unit)
    self.power:SetShown(max > 0)
    self.power:SetMinMaxValues(0, max > 0 and max or 1)
    self.power:SetValue(UnitPower(unit))
    local c = PowerBarColor[UnitPowerType(unit)] or PowerBarColor.MANA
    self.power:SetStatusBarColor(Muted(c.r, c.g, c.b))
end

local function UpdateName(self)
    self.name:SetText(UnitName(self.unit) or "")
end

local function UpdateAll(self)
    if not UnitExists(self.unit) then return end
    UpdateName(self)
    UpdateHealth(self)
    UpdatePower(self)
end

local unitEvents = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_HEALTH_FREQUENT = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateHealth,
    UNIT_FACTION = UpdateHealth,
    UNIT_FLAGS = UpdateHealth,
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
    if UnitFrame_OnEnter then
        b:SetScript("OnEnter", UnitFrame_OnEnter)
        b:SetScript("OnLeave", UnitFrame_OnLeave)
    end

    -- Player and target: power, seam, health. Party flips it across the beam.
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
        if fn then fn(self) else UpdateAll(self) end
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
