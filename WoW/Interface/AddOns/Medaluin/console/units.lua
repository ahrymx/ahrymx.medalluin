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
    if not ns.IsSecret(cur) and not ns.IsSecret(max) then
        return (max and max > 0) and math.floor(cur / max * 100 + 0.5) or 0
    end
    if percentCurve then return UnitHealthPercent(unit, false, percentCurve) end
    return (max and max > 0) and math.floor(cur / max * 100 + 0.5) or 0
end

local function PowerPercent(unit, cur, max)
    if not ns.IsSecret(cur) and not ns.IsSecret(max) then
        return (max and max > 0) and math.floor(cur / max * 100 + 0.5) or 0
    end
    if UnitPowerPercent and percentCurve then
        local pType = UnitPowerType(unit)
        return UnitPowerPercent(unit, pType, false, percentCurve)
    end
    return nil
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

local ROLE_COORDS = {
    TANK = { 0, 32 / 128, 0, 1 },
    HEALER = { 32 / 128, 64 / 128, 0, 1 },
    DAMAGER = { 64 / 128, 96 / 128, 0, 1 },
}

local CHECK_COORDS = {
    ready = { 0, 32 / 128, 0, 1 },
    notready = { 32 / 128, 64 / 128, 0, 1 },
    waiting = { 64 / 128, 96 / 128, 0, 1 },
}

local function UpdateHealth(self)
    local stub = self.stub
    if stub then
        local isDead = stub.dead or (stub.health == 0)
        if isDead then
            self.health:SetMinMaxValues(0, 1)
            self.health:SetValue(0)
            self.health:SetStatusBarColor(unpack(C.dead))
        else
            self.health:SetMinMaxValues(0, stub.maxHealth)
            self.health:SetValue(stub.health)
            local c = RAID_CLASS_COLORS[stub.class]
            if c then self.health:SetStatusBarColor(Muted(c.r, c.g, c.b)) end
        end
        if self.rezIcon then self.rezIcon:SetShown(isDead) end
        if self.value then
            if isDead then
                self.value:SetText(DEAD)
            else
                self.value:SetFormattedText("%.0f%%", math.floor(stub.health / stub.maxHealth * 100 + 0.5))
            end
        end
        return
    end
    local unit = self.unit
    local isDead = UnitIsDeadOrGhost(unit)
    local isIncomingRez = UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit)
    if self.rezIcon then
        self.rezIcon:SetShown(isDead or isIncomingRez)
    end
    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    self.health:SetMinMaxValues(0, max)
    self.health:SetValue(cur)
    self.health:SetStatusBarColor(HealthColor(unit))
    if not self.value then return end
    if not UnitIsConnected(unit) then
        self.value:SetText(PLAYER_OFFLINE)
    elseif isDead then
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

local function UpdateRole(self)
    if not self or not self.roleFrame then return end
    local role
    if self.stub and self.stub.role then
        role = self.stub.role
    elseif UnitGroupRolesAssigned then
        role = UnitGroupRolesAssigned(self.unit)
    end
    if role and ROLE_COORDS[role] then
        self.roleIcon:SetTexCoord(unpack(ROLE_COORDS[role]))
        self.roleFrame:Show()
    else
        self.roleFrame:Hide()
    end
end

local function UpdateAll(self)
    if not UnitExists(self.unit) and not self.stub then return end
    UpdateName(self)
    UpdateHealth(self)
    UpdatePower(self)
    UpdateRole(self)
end

local STUBS = {
    party1 = { name = "Party 1", class = "PRIEST", role = "HEALER", powerType = 0, health = 85, maxHealth = 100,
        power = 80, maxPower = 100 },
    party2 = { name = "Party 2", class = "MAGE", role = "DAMAGER", powerType = 0, health = 92, maxHealth = 100,
        power = 100, maxPower = 100 },
    party3 = { name = "Party 3", class = "WARRIOR", role = "TANK", powerType = 1, health = 78, maxHealth = 100,
        power = 45, maxPower = 100 },
    party4 = { name = "Party 4", class = "ROGUE", role = "DAMAGER", powerType = 3, health = 88, maxHealth = 100,
        power = 70, maxPower = 100 },
}

local PET_STUBS = {
    partypet2 = { name = "Water Elemental", class = "MAGE", health = 90, maxHealth = 100 },
}

local function AbbreviateName(name)
    if not name or name == "" then return "" end
    local first, rest = name:match("^(%S+)%s+(%S.*)$")
    if first and rest then
        local initial = first:match("([%z\1-\127\194-\244][\128-\191]*)") or first:sub(1, 1)
        return initial .. ". " .. AbbreviateName(rest)
    end
    return name
end

local function PetHealthColor(pet)
    local unit = pet.unit
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        return unpack(C.dead)
    end
    local owner = pet.owner
    if owner then
        local _, class = UnitClass(owner)
        local c = not ns.IsSecret(class) and class and RAID_CLASS_COLORS[class]
        if c then
            return Muted(c.r * 0.85, c.g * 0.85, c.b * 0.85)
        end
    end
    local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 5] or FACTION_BAR_COLORS[5]
    return Muted(c.r, c.g, c.b)
end

local function UpdatePartyPet(pet)
    if not pet then return end
    if ns.db and ns.db.partyPets == false then
        pet.stub = nil
        ns.OutOfCombat(function()
            if UnregisterUnitWatch then UnregisterUnitWatch(pet) end
            if pet:IsShown() then pet:Hide() end
        end)
        return
    end

    local unit = pet.unit
    local sim = ns.db and ns.db.simParty
    if UnitExists(unit) then
        pet.stub = nil
        ns.OutOfCombat(function()
            RegisterUnitWatch(pet)
        end)
        local max = UnitHealthMax(unit)
        local cur = UnitHealth(unit)
        if not ns.IsSecret(max) and max <= 0 then max = 1 end
        pet.health:SetMinMaxValues(0, max)
        pet.health:SetValue(cur)
        pet.health:SetStatusBarColor(PetHealthColor(pet))
        pet.name:SetText(AbbreviateName(ns.Or(UnitName(unit), "Pet")))
        if pet.value then
            if not UnitIsConnected(unit) then
                pet.value:SetText(PLAYER_OFFLINE)
            elseif UnitIsDeadOrGhost(unit) then
                pet.value:SetText(DEAD)
            else
                pet.value:SetFormattedText("%.0f%%", HealthPercent(unit, cur, max))
            end
        end
    elseif sim and PET_STUBS[unit] then
        local stub = PET_STUBS[unit]
        pet.stub = stub
        ns.OutOfCombat(function()
            if UnregisterUnitWatch then UnregisterUnitWatch(pet) end
            if not pet:IsShown() then pet:Show() end
        end)
        pet.health:SetMinMaxValues(0, stub.maxHealth)
        pet.health:SetValue(stub.health)
        local c = RAID_CLASS_COLORS[stub.class]
        if c then pet.health:SetStatusBarColor(Muted(c.r * 0.85, c.g * 0.85, c.b * 0.85)) end
        pet.name:SetText(AbbreviateName(stub.name))
        if pet.value then
            pet.value:SetFormattedText("%.0f%%", math.floor(stub.health / stub.maxHealth * 100 + 0.5))
        end
    else
        pet.stub = nil
        ns.OutOfCombat(function()
            RegisterUnitWatch(pet)
            if pet:IsShown() then pet:Hide() end
        end)
    end
end

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
    INCOMING_RESURRECT_CHANGED = UpdateHealth,
    PLAYER_ROLES_ASSIGNED = UpdateRole,
    ROLE_CHANGED_INFORM = UpdateRole,
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

        -- Resurrect icon above the name
        local rez = text:CreateTexture(nil, "OVERLAY")
        rez:SetSize(20, 20)
        rez:SetPoint("BOTTOM", b.name, "TOP", 0, 2)
        rez:SetTexture(ns.media .. "rez-icon")
        rez:Hide()
        b.rezIcon = rez

        -- Role icon at bottom outer edge (overlapping power and console surface)
        local rf = CreateFrame("Frame", nil, b)
        rf:SetSize(16, 16)
        rf:SetFrameLevel(ns.levels.art + 2)
        if side == -1 then
            rf:SetPoint("CENTER", b, "BOTTOMLEFT", 8, 0)
        else
            rf:SetPoint("CENTER", b, "BOTTOMRIGHT", -8, 0)
        end
        local ri = rf:CreateTexture(nil, "ARTWORK")
        ri:SetAllPoints()
        ri:SetTexture(ns.media .. "role-icons")
        b.roleFrame = rf
        b.roleIcon = ri
        rf:Hide()

        -- Ready check & role check status widget in the middle of the frame
        local sw = CreateFrame("Frame", nil, b)
        sw:SetSize(22, 22)
        sw:SetPoint("CENTER", b.health, "CENTER", 0, 0)
        sw:SetFrameLevel(ns.levels.text + 3)
        local si = sw:CreateTexture(nil, "ARTWORK")
        si:SetAllPoints()
        si:SetTexture(ns.media .. "ready-status")
        sw.icon = si
        sw:Hide()
        b.statusWidget = sw
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

local petEvents = {
    UNIT_HEALTH = true,
    UNIT_HEALTH_FREQUENT = true,
    UNIT_MAXHEALTH = true,
    UNIT_NAME_UPDATE = true,
    UNIT_CONNECTION = true,
    UNIT_FLAGS = true,
    UNIT_FACTION = true,
}

local function SpawnPet(parentBtn, unit, side)
    local pet = CreateFrame("Button", "MedaluinUnit_" .. unit, console, "SecureUnitButtonTemplate")
    pet.unit = unit
    pet.owner = parentBtn.unit
    pet:SetFrameLevel(ns.levels.bars)
    pet:SetHeight(18)
    pet:SetPoint("TOPLEFT", parentBtn, "BOTTOMLEFT", 0, -8)
    pet:SetPoint("TOPRIGHT", parentBtn, "BOTTOMRIGHT", 0, -8)

    pet:SetAttribute("unit", unit)
    pet:SetAttribute("*type1", "target")
    pet:SetAttribute("*type2", "togglemenu")
    pet:RegisterForClicks("AnyUp")

    -- Health bar status bar inset inside the trapezoid (rectangular bar underneath)
    local bar = CreateFrame("StatusBar", nil, pet)
    bar:SetPoint("TOPLEFT", pet, "TOPLEFT", 12, -3)
    bar:SetPoint("BOTTOMRIGHT", pet, "BOTTOMRIGHT", -12, 3)
    bar:SetStatusBarTexture(ns.bar)
    bar:SetReverseFill(side == 1)
    pet.health = bar

    -- Ink backing behind health bar
    local bg = pet:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(unpack(ns.colors.ink))
    pet.bg = bg

    -- Melded stone trapezoid surface with pill cutout layered ON TOP of the rectangular bar to round its edges
    local frameOverlay = CreateFrame("Frame", nil, pet)
    frameOverlay:SetAllPoints(pet)
    frameOverlay:SetFrameLevel(bar:GetFrameLevel() + 1)
    local bracket = frameOverlay:CreateTexture(nil, "ARTWORK")
    bracket:SetAllPoints()
    bracket:SetTexture(ns.media .. "pet-bracket")
    bracket:SetTexCoord(0, 129 / 256, 0, 18 / 32)
    pet.bracket = bracket

    -- Text overlay
    local text = CreateFrame("Frame", nil, pet)
    text:SetAllPoints(bar)
    text:SetFrameLevel(frameOverlay:GetFrameLevel() + 1)

    local outer = side == 1 and "RIGHT" or "LEFT"
    local inner = side == 1 and "LEFT" or "RIGHT"

    pet.value = ns.Text(text, 9)
    pet.value:SetPoint(inner, text, inner, side * 6, 0)
    pet.value:SetJustifyH(inner)
    pet.value:SetWordWrap(false)
    pet.value:SetTextColor(unpack(C.dim))

    pet.name = ns.Text(text, 9)
    pet.name:SetPoint(outer, text, outer, -side * 6, 0)
    pet.name:SetPoint(inner, pet.value, outer, side * 6, 0)
    pet.name:SetJustifyH(outer)
    pet.name:SetWordWrap(false)
    pet.name:SetTextColor(unpack(C.text))

    pet:SetScript("OnEnter", function(self)
        if self.stub and not UnitExists(self.unit) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.stub.name, 1, 1, 1)
            GameTooltip:AddLine("Simulated party pet", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        elseif UnitFrame_OnEnter then
            UnitFrame_OnEnter(self)
        end
    end)
    pet:SetScript("OnLeave", function(self)
        if self.stub and not UnitExists(self.unit) then
            GameTooltip_Hide()
        elseif UnitFrame_OnLeave then
            UnitFrame_OnLeave(self)
        end
    end)

    for event in pairs(petEvents) do
        ns.RegisterUnitEvent(pet, event, unit)
    end
    pet:SetScript("OnEvent", function(self)
        UpdatePartyPet(self)
    end)
    pet:SetScript("OnShow", function(self)
        UpdatePartyPet(self)
    end)

    RegisterUnitWatch(pet)
    pet:Hide()
    return pet
end

ns.units = {}
ns.partyPets = {}
for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    ns.units[unit] = Spawn(unit)
end

for i = 1, 4 do
    local partyUnit = "party" .. i
    local petUnit = "partypet" .. i
    local parentBtn = ns.units[partyUnit]
    local _, side = unpack(ns.slots[partyUnit])
    local pet = SpawnPet(parentBtn, petUnit, side)
    parentBtn.pet = pet
    ns.partyPets[petUnit] = pet
end

-- Range check logic: party frames fade when members are out of distance
local function IsUnitInRange(unit, dist)
    if not dist or dist == 0 then return true end
    if unit == "player" then return true end
    local b = ns.units and ns.units[unit]
    if b and b.stub then return b.stub.inRange ~= false end
    if not UnitExists(unit) or not UnitIsConnected(unit) then return false end

    if dist == 10 then
        if CheckInteractDistance then
            return CheckInteractDistance(unit, 3) or CheckInteractDistance(unit, 2)
        end
    elseif dist == 20 or dist == 30 then
        if CheckInteractDistance then
            return CheckInteractDistance(unit, 1) or CheckInteractDistance(unit, 4)
        end
    end

    if UnitInRange then
        local inRange, checkedRange = UnitInRange(unit)
        if checkedRange then return inRange end
    end

    if UnitIsVisible then
        return UnitIsVisible(unit)
    end
    return true
end

local function UpdatePartyRange()
    local dist = ns.db and ns.db.partyRange
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and pb:IsShown() then
            local inRange = (dist == 0) or IsUnitInRange(u, dist)
            local targetAlpha = inRange and 1.0 or 0.45
            if pb:GetAlpha() ~= targetAlpha then
                pb:SetAlpha(targetAlpha)
            end
            if pb.pet and pb.pet:IsShown() then
                if pb.pet:GetAlpha() ~= targetAlpha then
                    pb.pet:SetAlpha(targetAlpha)
                end
            end
        end
    end
end
ns.UpdatePartyRange = UpdatePartyRange

local rangeChecker = CreateFrame("Frame")
local rangeElapsed = 0
rangeChecker:SetScript("OnUpdate", function(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 0.2 then return end
    rangeElapsed = 0
    UpdatePartyRange()
end)

local function UpdatePartyFrames()
    for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do
        local b = ns.units[unit]
        if b then
            UpdatePartyUnit(b)
            if b.pet then UpdatePartyPet(b.pet) end
        end
    end
    UpdatePartyRange()
end
UpdatePartyFrames()
ns.On("GROUP_ROSTER_UPDATE", UpdatePartyFrames)
ns.On("PLAYER_ENTERING_WORLD", UpdatePartyFrames)
ns.On("ADDON_LOADED", UpdatePartyFrames)
ns.On("PLAYER_ROLES_ASSIGNED", UpdatePartyFrames)
ns.On("ROLE_CHANGED_INFORM", UpdatePartyFrames)
ns.On("UNIT_PET", function(unit)
    if unit and unit:match("^party%d$") then
        local b = ns.units[unit]
        if b and b.pet then UpdatePartyPet(b.pet) end
    end
end)
ns.OnSetting("simParty", UpdatePartyFrames)
ns.OnSetting("partyPets", UpdatePartyFrames)
ns.OnSetting("partyRange", UpdatePartyRange)

-- Ready check & role check: hides buffs/debuffs and shows status in the middle
local function SetCheckStatus(b, status)
    if not b or not b.statusWidget then return end
    if not status then
        b.isChecking = false
        b.statusWidget:Hide()
        if ns.UpdateUnitAuras then ns.UpdateUnitAuras(b) end
        return
    end
    b.isChecking = true
    local coords = CHECK_COORDS[status] or CHECK_COORDS.waiting
    b.statusWidget.icon:SetTexCoord(unpack(coords))
    b.statusWidget:Show()
    if ns.UpdateUnitAuras then ns.UpdateUnitAuras(b) end
end
ns.SetCheckStatus = SetCheckStatus

local checkHideTime = nil
local checkTimerFrame = CreateFrame("Frame")
checkTimerFrame:SetScript("OnUpdate", function(_, elapsed)
    if checkHideTime then
        checkHideTime = checkHideTime - elapsed
        if checkHideTime <= 0 then
            checkHideTime = nil
            for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
                local pb = ns.units[u]
                if pb then SetCheckStatus(pb, nil) end
            end
        end
    end
end)

local function OnReadyCheck()
    checkHideTime = nil
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and (UnitExists(u) or pb.stub) then
            local status = GetReadyCheckStatus and GetReadyCheckStatus(u) or "waiting"
            SetCheckStatus(pb, status)
        end
    end
end

local function OnReadyCheckConfirm(unit, isReady)
    local pb = ns.units[unit]
    if pb then
        SetCheckStatus(pb, isReady and "ready" or "notready")
    end
end

local function OnReadyCheckFinished()
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and pb.isChecking then
            local status = GetReadyCheckStatus and GetReadyCheckStatus(u)
            if status then SetCheckStatus(pb, status) end
        end
    end
    checkHideTime = 3.0
end

local function OnRolePollBegin()
    checkHideTime = nil
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and (UnitExists(u) or pb.stub) then
            SetCheckStatus(pb, "waiting")
        end
    end
end

local function OnRolePollUpdate()
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and pb.isChecking then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(u)
            if role and role ~= "NONE" then
                SetCheckStatus(pb, "ready")
            end
        end
    end
end

local function ClearCheckStatus()
    checkHideTime = nil
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and pb.isChecking then
            SetCheckStatus(pb, nil)
        end
    end
end

ns.On("READY_CHECK", OnReadyCheck)
ns.On("READY_CHECK_CONFIRM", OnReadyCheckConfirm)
ns.On("READY_CHECK_FINISHED", OnReadyCheckFinished)
ns.On("ROLE_POLL_BEGIN", OnRolePollBegin)
ns.On("ROLE_POLL_UPDATE", OnRolePollUpdate)
ns.On("PLAYER_REGEN_DISABLED", ClearCheckStatus)
