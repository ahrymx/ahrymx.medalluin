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
ns.HealthPercent = HealthPercent         -- the overhead's cells (console/overhead.lua) too

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
ns.ROLE_COORDS = ROLE_COORDS        -- media/role-icons, the LFG window's too (social/lfg.lua)

local CHECK_COORDS = {
    ready = { 0, 32 / 128, 0, 1 },
    notready = { 32 / 128, 64 / 128, 0, 1 },
    waiting = { 64 / 128, 96 / 128, 0, 1 },
}
ns.CHECK_COORDS = CHECK_COORDS      -- media/ready-status, the editor's canvas too (options/canvas.lua)

-- The health value as the editor's format has it (editor.lua): the percent,
-- the current health, both, or what is missing. Where the game keeps the
-- numbers secret, the missing health cannot be worked out: the percent.
local function HealthValue(self, cur, max, pct)
    local format = ns.EditFormat and ns.EditFormat(self, "value")
    if format == "current" then
        self.value:SetText(FormatPower(cur))
    elseif format == "both" then
        self.value:SetFormattedText("%s | %.0f%%", FormatPower(cur), pct)
    elseif format == "stacked" then
        self.value:SetFormattedText("%.0f%%\n%s", pct, FormatPower(cur))
    elseif format == "deficit" and not ns.IsSecret(cur) and not ns.IsSecret(max) then
        self.value:SetText(cur < max and "-" .. FormatPower(max - cur) or "")
    else
        self.value:SetFormattedText("%.0f%%", pct)
    end
end

local function UpdateHealth(self)
    local stub = self.stub
    if stub then
        -- offline as a real member is: the health it had, greyed, never dead
        local isOffline = stub.offline
        local isDead = not isOffline and (stub.dead or stub.health == 0)
        if isDead then
            self.health:SetMinMaxValues(0, 1)
            self.health:SetValue(0)
            self.health:SetStatusBarColor(unpack(C.dead))
        else
            self.health:SetMinMaxValues(0, stub.maxHealth)
            self.health:SetValue(stub.health)
            local c = not isOffline and RAID_CLASS_COLORS[stub.class]
            if c then self.health:SetStatusBarColor(Muted(c.r, c.g, c.b)) else
                self.health:SetStatusBarColor(unpack(C.dead)) end
        end
        ns.ShowDead(self, isOffline and "offline" or (isDead and "dead"))
        if self.value then
            if isOffline then
                self.value:SetText(PLAYER_OFFLINE)
            elseif isDead then
                self.value:SetText(DEAD)
            else
                HealthValue(self, stub.health, stub.maxHealth, math.floor(stub.health / stub.maxHealth * 100 + 0.5))
            end
        end
        return
    end
    local unit = self.unit
    local isOffline = not UnitIsConnected(unit)
    local isDead = UnitIsDeadOrGhost(unit)
    ns.ShowDead(self, isOffline and "offline" or (isDead and "dead"))
    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    self.health:SetMinMaxValues(0, max)
    self.health:SetValue(cur)
    self.health:SetStatusBarColor(HealthColor(unit))
    if not self.value then return end
    if isOffline then
        self.value:SetText(PLAYER_OFFLINE)
    elseif isDead then
        self.value:SetText(DEAD)
    else
        HealthValue(self, cur, max, HealthPercent(unit, cur, max))
    end
end

-- The power value as the editor's format has it: current and percent (as
-- it always was), the current alone, or the percent alone. pct may be nil
-- where the game keeps it secret and has no curve to read it through.
local function PowerValue(self, cur, pct)
    local format = ns.EditFormat and ns.EditFormat(self, "powerValue")
    -- no percent (the game keeps the numbers secret): the value, whole
    if format == "current" or pct == nil then
        self.powerValue:SetText(cur)
    elseif format == "percent" then
        self.powerValue:SetFormattedText("%.0f%%", pct)
    else
        self.powerValue:SetFormattedText("%s | %.0f%%", cur, pct)
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
            PowerValue(self, FormatPower(stub.power), math.floor(stub.power / stub.maxPower * 100 + 0.5))
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
        PowerValue(self, cur, PowerPercent(unit, cur, max))
    else
        PowerValue(self, FormatPower(cur), PowerPercent(unit, cur, max))
    end
end

-- The name, as the editor's format has it: whole or with initials, and cut
-- to the longest it may be. A secret name still displays, as it is.
local function UpdateName(self)
    local name = self.stub and self.stub.name or ns.Or(UnitName(self.unit), "")
    local format, len = nil, nil
    if ns.EditFormat then format, len = ns.EditFormat(self, "name") end
    if not ns.IsSecret(name) then
        if format == "short" then name = ns.AbbreviateName(name) end
        if ns.CutName then name = ns.CutName(name, len) end
    end
    self.name:SetText(name)
    if self.dead and self.dead:IsShown() then self.dead.name:SetText(name) end
end

-- The level: "??" for a boss (or a unit too far above to tell), "+" on an
-- elite; an enemy's in the colour of how hard it is, anyone else's dim. A
-- simulated unit shows its stub's, else the player's. A secret level still
-- displays, as it is, in the plain colour.
local ELITE = { elite = "+", rareelite = "+" }
local function UpdateLevel(self)
    local fs = self.levelText
    if not fs then return end
    local stub = self.stub
    local level = stub and (stub.level or UnitLevel("player")) or UnitLevel(self.unit)
    if ns.IsSecret(level) then
        fs:SetText(level)
        fs:SetTextColor(unpack(C.dim))
        return
    end
    if type(level) ~= "number" or level == 0 then
        fs:SetText("")
        return
    end
    if level < 0 then
        fs:SetText("??")
        fs:SetTextColor(1, 0.1, 0.1)
        return
    end
    local class = not stub and UnitClassification and UnitClassification(self.unit)
    fs:SetText(level .. (not ns.IsSecret(class) and ELITE[class] or ""))
    local hostile = not stub and UnitCanAttack("player", self.unit)
    local Difficulty = GetCreatureDifficultyColor or GetQuestDifficultyColor
    if hostile and not ns.IsSecret(hostile) and Difficulty then
        local c = Difficulty(level)
        fs:SetTextColor(c.r, c.g, c.b)
    else
        fs:SetTextColor(unpack(C.dim))
    end
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

-- The group's leader wears a crown; a simulated member by its stub's word.
-- The editor's Shown is the crown's alpha, so the two never cross.
local function UpdateLeader(self)
    local f = self.leaderFrame
    if not f then return end
    local on
    if self.stub then
        on = self.stub.leader
    elseif UnitIsGroupLeader then
        on = UnitIsGroupLeader(self.unit)
    end
    f:SetShown(not ns.IsSecret(on) and on and true or false)
end
ns.UpdateLeader = UpdateLeader

-- A button's crown (hidden until its unit leads), over the frame's level.
function ns.LeaderIcon(b, size, level)
    local f = CreateFrame("Frame", nil, b)
    f:SetSize(size, size)
    f:SetFrameLevel(level)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    f.icon = t
    f:Hide()
    b.leaderFrame = f
    return f
end

-- The bars in a button's room h: the power bar power high (the editor's
-- Power bar > Height, ns.PowerHeight, when set), a seam, the health the rest.
-- A power bar of 0 is none: the health takes its room and the seam. Called
-- by the frames' own layouts; with no arguments, again as they last were
-- (the editor's, as an edit changes).
function ns.LayPower(b, power, seam, h)
    if power then b.powerDefault, b.powerSeam, b.powerRoom = power, seam, h end
    local frame = ns.editor and ns.editor.FrameOf(b)
    local ph = frame and ns.PowerHeight(frame.id, b.powerDefault) or b.powerDefault
    local room = b.powerRoom or b:GetHeight()
    b.power:SetHeight(math.max(ph, 0.001))
    b.power:SetAlpha(ph > 0 and 1 or 0)
    b.health:SetHeight(room - ph - (ph > 0 and b.powerSeam or 0))
end

local function UpdateAll(self)
    if not UnitExists(self.unit) and not self.stub then return end
    UpdateName(self)
    UpdateLevel(self)
    UpdateLeader(self)
    UpdateHealth(self)
    UpdatePower(self)
    UpdateRole(self)
end
-- the group widgets' cells draw the same way (widgets/)
ns.UpdateUnitButton = UpdateAll

local STUBS = {
    party1 = { name = "Party 1", class = "PRIEST", role = "HEALER", powerType = 0, health = 85, maxHealth = 100,
        power = 80, maxPower = 100, leader = true },
    party2 = { name = "Party 2", class = "MAGE", role = "DAMAGER", powerType = 0, health = 92, maxHealth = 100,
        power = 100, maxPower = 100 },
    party3 = { name = "Party 3", class = "WARRIOR", role = "TANK", powerType = 1, health = 78, maxHealth = 100,
        power = 45, maxPower = 100 },
    party4 = { name = "Party 4", class = "ROGUE", role = "DAMAGER", powerType = 3, health = 88, maxHealth = 100,
        power = 70, maxPower = 100 },
}

STUBS.party2.pet = true
ns.partyStubs = STUBS     -- the simulation panel (simulate.lua) sets each member's health and state

-- a member's simulated pet, shown while its stub has .pet
local PET_STUBS = {
    partypet1 = { name = "Shadowfiend", class = "PRIEST", health = 80, maxHealth = 100 },
    partypet2 = { name = "Water Elemental", class = "MAGE", health = 90, maxHealth = 100 },
    partypet3 = { name = "Spirit Wolf", class = "SHAMAN", health = 70, maxHealth = 100 },
    partypet4 = { name = "Imp", class = "WARLOCK", health = 100, maxHealth = 100 },
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
ns.AbbreviateName = AbbreviateName

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

-- A button's unit watch, registered or let go only when that changes:
-- registering again rewrites the watch manager's list of frames, and from a
-- frame's OnShow that runs inside the manager's walk over that very list (as
-- the overhead's: overhead.lua)
local function Watched(f, on)
    if f.watching == on then return end
    f.watching = on
    if on then RegisterUnitWatch(f) elseif UnregisterUnitWatch then UnregisterUnitWatch(f) end
end

local function UpdatePartyPet(pet)
    if not pet then return end
    if ns.db and not ns.PartyPets() then
        pet.stub = nil
        ns.OutOfCombat(function()
            Watched(pet, false)
            if pet:IsShown() then pet:Hide() end
        end)
        return
    end

    local unit = pet.unit
    local sim = ns.db and ns.db.simParty
    if UnitExists(unit) then
        pet.stub = nil
        ns.OutOfCombat(function()
            Watched(pet, true)
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
    elseif sim and PET_STUBS[unit] and pet.ownerButton.stub and pet.ownerButton.stub.pet then
        local stub = PET_STUBS[unit]
        pet.stub = stub
        ns.OutOfCombat(function()
            Watched(pet, false)
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
            Watched(pet, true)
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
            Watched(b, true)
        end)
        UpdateAll(b)
    elseif sim and tonumber(unit:match("%d$")) <= ns.sim.party.count then
        b.stub = STUBS[unit]
        ns.OutOfCombat(function()
            Watched(b, false)
            if not b:IsShown() then b:Show() end
        end)
        UpdateAll(b)
    else
        b.stub = nil
        ns.OutOfCombat(function()
            Watched(b, true)
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
    UNIT_CONNECTION = UpdateAll,
    UNIT_FACTION = UpdateHealth,
    UNIT_FLAGS = UpdateState,
    UNIT_POWER_FREQUENT = UpdatePower,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_NAME_UPDATE = UpdateAll,     -- a joiner's name, class and all, as the game learns them
    UNIT_LEVEL = UpdateLevel,
    UNIT_CLASSIFICATION_CHANGED = UpdateLevel,
    PLAYER_ROLES_ASSIGNED = UpdateRole,
    ROLE_CHANGED_INFORM = UpdateRole,
}
ns.unitEvents = unitEvents

local function Bar(parent, side)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.bar)
    bar:SetReverseFill(side == 1)
    return bar
end

-- the party's health value from its window's inner end, short of the cut
local PARTY_VALUE_INSET = 24
-- the party's level from its window's outer end, past the role icon
local PARTY_LEVEL_INSET = 20

-- A party member's level on its power bar's outer end, inset from it.
local function PartyLevel(b, side, inset)
    local outer = side == 1 and "RIGHT" or "LEFT"
    b.levelText:ClearAllPoints()
    b.levelText:SetPoint(outer, b.power, outer, -side * inset, 0)
end

-- The crown on the top edge's outer end, inset from it: over the role
-- icon on the bottom one.
local function PartyLeader(b, side, inset)
    local outer = side == 1 and "RIGHT" or "LEFT"
    b.leaderFrame:ClearAllPoints()
    b.leaderFrame:SetPoint("CENTER", b, "TOP" .. outer, -side * inset, 0)
end

local function Spawn(unit, forWidget)
    local window, side = unpack(ns.slots[unit])
    local isParty = forWidget or window ~= "unit"
    local style = isParty and L.party or L.unit

    local name = forWidget and "MedalluinPartyWidgetPlayer" or ("MedalluinUnit_" .. unit)
    local b = CreateFrame("Button", name, console, "SecureUnitButtonTemplate")
    b.unit = unit
    b:SetFrameLevel(ns.levels.bars)
    if not forWidget then ns.PlaceOn(b, console, window, side) end
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnEnter", function(self)
        if self.stub and not UnitExists(self.unit) then
            ns.Tip(self, "ANCHOR_RIGHT", { title = self.stub.name, color = ns.colors.white,
                { "body", "Simulated party member", ns.colors.grey } })
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
    ns.LayPower(b, style.power, style.seam, h)
    b.power:SetPoint("LEFT")
    b.power:SetPoint("RIGHT")
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
    b.text = text
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

        -- the level on the power bar's outer end, clear of its value
        b.levelText = ns.Text(text, style.powerSize)
        b.levelText:SetPoint(outer, b.power, outer, -side * style.textInset, 0)

        -- the crown on the top edge's outer end
        ns.LeaderIcon(b, 16, ns.levels.text + 2)
        b.leaderFrame:SetPoint("CENTER", b, "TOP" .. outer, -side * 14, 0)
    else
        b.name:SetPoint(inner, text, inner, side * style.textInset, 0)
        b.name:SetJustifyH(outer)

        -- The health value, faded until the editor shows it (editor.lua):
        -- the party's windows are short, and the name fills them
        b.value = ns.Text(text, style.nameSize - 2)
        b.value:SetTextColor(unpack(C.dim))
        b.value:SetPoint(inner, text, inner, side * PARTY_VALUE_INSET, 0)
        b.value:SetWordWrap(false)
        b.value:SetAlpha(0)

        -- the level on the power bar, its outer end being the role icon's
        b.levelText = ns.Text(text, style.nameSize - 3)
        PartyLevel(b, side, PARTY_LEVEL_INSET)

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

        -- the crown over it, on the top edge
        ns.LeaderIcon(b, 14, ns.levels.art + 2)
        PartyLeader(b, side, 8)

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
    b.levelText:SetWordWrap(false)
    -- a friend's frame shows its death (dead.lua); the target may be an enemy
    if unit ~= "target" then ns.DeadLook(b) end

    for event in pairs(unitEvents) do
        ns.RegisterUnitEvent(b, event, unit)
    end
    b:SetScript("OnEvent", function(self, event)
        if forWidget and not self.inWidget then return end
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

    if forWidget then
        b:RegisterEvent("PLAYER_ENTERING_WORLD")
        b:RegisterEvent("GROUP_ROSTER_UPDATE")
        b:Hide()
    elseif unit == "player" then
        b:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        -- target and party buttons show only while their unit exists
        b.watching = true
        RegisterUnitWatch(b)
        b:RegisterEvent(unit == "target" and "PLAYER_TARGET_CHANGED" or "GROUP_ROSTER_UPDATE")
        -- a member the game comes to know, or who comes back in reach: the
        -- whole button again (UpdatePartyUnit)
        if unit ~= "target" then
            for _, e in ipairs({ "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "UNIT_OTHER_PARTY_CHANGED" }) do
                pcall(b.RegisterEvent, b, e)
            end
            ns.RegisterUnitEvent(b, "UNIT_PHASE", unit)
        end
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

-- A pet's frame has two shapes. With no box it hangs under its owner in a
-- stone bracket (the medallion's party wings, and the light console's row:
-- party_row.lua). With a box it fills that box: no bracket, the bar edge
-- to edge, its name over its value. The box is from rel's relPoint (the
-- party widget's cell, widgets/party.lua). Hung, it drops from its owner's
-- foot to the art's edge, to weld there: the medallion's 8 unless drop says.
-- Out of combat only: it is secure.
function ns.LayoutPet(pet, box, rel, relPoint, drop)
    local side = pet.side
    local outer = side == 1 and "RIGHT" or "LEFT"
    local inner = side == 1 and "LEFT" or "RIGHT"
    pet:ClearAllPoints()
    pet.health:ClearAllPoints()
    pet.name:ClearAllPoints()
    pet.value:ClearAllPoints()
    if box then
        pet:SetPoint("TOPLEFT", rel or console, relPoint or "TOP", box[1], box[3])
        pet:SetPoint("BOTTOMRIGHT", rel or console, relPoint or "TOP", box[2], box[4])
        pet.health:SetAllPoints(pet)
        pet.bracket:Hide()
        pet.name:SetPoint("TOPLEFT", pet.text, "TOPLEFT", 2, -3)
        pet.name:SetPoint("TOPRIGHT", pet.text, "TOPRIGHT", -2, -3)
        pet.name:SetJustifyH("CENTER")
        pet.value:SetPoint("BOTTOM", pet.text, "BOTTOM", 0, 3)
        pet.value:SetJustifyH("CENTER")
        return
    end
    pet:SetHeight(18)
    pet:SetPoint("TOPLEFT", pet.ownerButton, "BOTTOMLEFT", 0, -(drop or 8))
    pet:SetPoint("TOPRIGHT", pet.ownerButton, "BOTTOMRIGHT", 0, -(drop or 8))
    pet.health:SetPoint("TOPLEFT", pet, "TOPLEFT", 12, -3)
    pet.health:SetPoint("BOTTOMRIGHT", pet, "BOTTOMRIGHT", -12, 3)
    pet.bracket:Show()
    pet.value:SetPoint(inner, pet.text, inner, side * 6, 0)
    pet.value:SetJustifyH(inner)
    pet.name:SetPoint(outer, pet.text, outer, -side * 6, 0)
    pet.name:SetPoint(inner, pet.value, outer, side * 6, 0)
    pet.name:SetJustifyH(outer)
end

local function SpawnPet(parentBtn, unit, side)
    local pet = CreateFrame("Button", "MedalluinUnit_" .. unit, console, "SecureUnitButtonTemplate")
    pet.unit = unit
    pet.owner = parentBtn.unit
    pet.ownerButton = parentBtn
    pet.side = side
    pet:SetFrameLevel(ns.levels.bars)

    pet:SetAttribute("unit", unit)
    pet:SetAttribute("*type1", "target")
    pet:SetAttribute("*type2", "togglemenu")
    pet:RegisterForClicks("AnyUp")

    -- Health bar status bar inset inside the trapezoid (rectangular bar underneath)
    local bar = CreateFrame("StatusBar", nil, pet)
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
    pet.text = text

    pet.value = ns.Text(text, 9)
    pet.value:SetWordWrap(false)
    pet.value:SetTextColor(unpack(C.dim))

    pet.name = ns.Text(text, 9)
    pet.name:SetWordWrap(false)
    pet.name:SetTextColor(unpack(C.text))
    ns.LayoutPet(pet)

    pet:SetScript("OnEnter", function(self)
        if self.stub and not UnitExists(self.unit) then
            ns.Tip(self, "ANCHOR_RIGHT", { title = self.stub.name, color = ns.colors.white,
                { "body", "Simulated party pet", ns.colors.grey } })
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

    pet.watching = true
    RegisterUnitWatch(pet)
    pet:Hide()
    return pet
end

ns.units = {}
ns.partyPets = {}
for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    ns.units[unit] = Spawn(unit)
end
ns.partyWidgetPlayer = Spawn("player", true)

for i = 1, 4 do
    local partyUnit = "party" .. i
    local petUnit = "partypet" .. i
    local parentBtn = ns.units[partyUnit]
    local _, side = unpack(ns.slots[partyUnit])
    local pet = SpawnPet(parentBtn, petUnit, side)
    parentBtn.pet = pet
    ns.partyPets[petUnit] = pet
end

-- A party button back in its console window, as Spawn made it: after the
-- party widget had it (widgets/party.lua).
local function ConsoleParty(b)
    local window, side = unpack(ns.slots[b.unit])
    local style = L.party
    ns.PlaceOn(b, console, window, side)
    local h = b:GetHeight()
    b.power:ClearAllPoints()
    b.health:ClearAllPoints()
    ns.LayPower(b, style.power, style.seam, h)
    b.power:SetPoint("LEFT")
    b.power:SetPoint("RIGHT")
    b.power:SetPoint("BOTTOM")
    b.health:SetPoint("LEFT")
    b.health:SetPoint("RIGHT")
    b.health:SetPoint("TOP")
    b.health:SetReverseFill(side == 1)
    b.power:SetReverseFill(side == 1)
    local outer = side == 1 and "RIGHT" or "LEFT"
    local inner = side == 1 and "LEFT" or "RIGHT"
    b.name:ClearAllPoints()
    b.name:SetPoint(outer, b.text, outer, -side * style.textInset, 0)
    b.name:SetPoint(inner, b.text, inner, side * style.textInset, 0)
    b.name:SetJustifyH(outer)
    b.roleFrame:ClearAllPoints()
    if side == -1 then
        b.roleFrame:SetPoint("CENTER", b, "BOTTOMLEFT", 8, 0)
    else
        b.roleFrame:SetPoint("CENTER", b, "BOTTOMRIGHT", -8, 0)
    end
    b.value:ClearAllPoints()
    b.value:SetPoint(inner, b.text, inner, side * PARTY_VALUE_INSET, 0)
    PartyLevel(b, side, PARTY_LEVEL_INSET)
    PartyLeader(b, side, 8)
    if b.pet then b.pet.health:SetReverseFill(side == 1) end
    if ns.LayBuffs then ns.LayBuffs(b, side) end
    -- what the editor changed goes back on (editor.lua)
    if ns.editor then
        ns.editor.Relaid(b, "name", "level", "role", "leader", "value", "buffs")
        ns.ApplyEdits(b)
    end
end

-- The way a party button faces on the console, -1 left or 1 right: its
-- slot's, or in the light profile's row (party_row.lua) its half's, so the
-- row mirrors across the centre as the console's windows do.
function ns.PartySide(unit)
    local party = ns.layout.party
    local row = party and party.detached and party.row
    if row then
        local f = row.frames[tonumber(unit:match("%d$"))]
        return f[1] + f[2] < 0 and -1 or 1
    end
    return ns.slots[unit][2]
end

function ns.RelayoutUnits()
    L = ns.layout
    local uStyle, pStyle = L.unit, L.party
    for _, unit in ipairs({ "player", "target" }) do
        local b = ns.units[unit]
        local _, side = unpack(ns.slots[unit])
        ns.PlaceOn(b, console, "unit", side)
        local h = b:GetHeight()
        b.power:ClearAllPoints()
        b.health:ClearAllPoints()
        ns.LayPower(b, uStyle.power, uStyle.seam, h)
        b.power:SetPoint("LEFT")
        b.power:SetPoint("RIGHT")
        b.health:SetPoint("LEFT")
        b.health:SetPoint("RIGHT")
        local healthEdge = uStyle.healthOnTop and "TOP" or "BOTTOM"
        local powerEdge = uStyle.healthOnTop and "BOTTOM" or "TOP"
        b.health:SetPoint(healthEdge)
        b.power:SetPoint(powerEdge)
    end
    -- the party widget places the party buttons itself (widgets/party.lua);
    -- out of it, they come back to the console
    local widget = ns.PartyWidgetLayout and ns.PartyWidgetLayout()
    if widget then
        -- the row's band goes (party_row.lua)
        if ns.LayoutPartyRow then ns.LayoutPartyRow() end
        ns.LayoutPartyWidget()
    elseif ns.ReleasePartyWidget and ns.ReleasePartyWidget() and not pStyle.detached then
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            ConsoleParty(b)
            ns.LayoutPet(b.pet)
        end
    end
    if pStyle.detached and not widget then
        -- the horizontal row (party_row.lua), which places the buttons itself
        local h = pStyle.row.frames[1][3] - pStyle.row.frames[1][4]
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local side = ns.PartySide(b.unit)
            local outer = side == 1 and "RIGHT" or "LEFT"
            local inner = side == 1 and "LEFT" or "RIGHT"
            b.power:ClearAllPoints()
            b.health:ClearAllPoints()
            ns.LayPower(b, pStyle.power, pStyle.seam, h)
            b.power:SetPoint("LEFT")
            b.power:SetPoint("RIGHT")
            b.power:SetPoint("BOTTOM")
            b.health:SetPoint("LEFT")
            b.health:SetPoint("RIGHT")
            b.health:SetPoint("TOP")
            b.health:SetReverseFill(side == 1)
            b.power:SetReverseFill(side == 1)
            if not b.detachedBg then
                local bg = b:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(unpack(C.ink))
                b.detachedBg = bg
            end
            if b.roleFrame then
                b.roleFrame:ClearAllPoints()
                b.roleFrame:SetPoint("CENTER", b, outer, -side * 10, 2)
            end
            b.name:ClearAllPoints()
            b.name:SetPoint(outer, b.health, outer, -side * 22, 0)
            b.name:SetPoint(inner, b.health, inner, side * 6, 0)
            b.name:SetJustifyH(outer)
            b.value:ClearAllPoints()
            b.value:SetPoint(inner, b.health, inner, side * 6, 0)
            -- under the name's outer end, the role icon outside both
            PartyLevel(b, side, 22)
            PartyLeader(b, side, 10)
            if b.pet then
                -- hung under its owner by the row (ns.LayoutPet), facing as it does
                b.pet.side = side
                b.pet.health:SetReverseFill(side == 1)
            end
            if ns.LayBuffs then ns.LayBuffs(b, side) end
            if ns.editor then
                ns.editor.Relaid(b, "name", "level", "role", "leader", "value", "buffs")
                ns.ApplyEdits(b)
            end
        end
        if ns.LayoutPartyRow then ns.LayoutPartyRow() end
    end
    if ns.ShapeDispelGlows then ns.ShapeDispelGlows() end
end

-- Range check logic: party frames fade when members are out of distance.
-- The answer may be a secret: the modern client keeps UnitInRange's (and
-- may keep the others') from addons, and it is then passed on untested,
-- for RangeFade to apply (it was taken as "in range", so nothing faded).
local function IsUnitInRange(unit, dist)
    if not dist or dist == 0 then return true end
    if unit == "player" then return true end
    local b = ns.units and ns.units[unit]
    if b and b.stub then return b.stub.inRange ~= false and not b.stub.offline end
    if not UnitExists(unit) or not UnitIsConnected(unit) then return false end

    if dist == 10 then
        if CheckInteractDistance then
            local ok, r = pcall(CheckInteractDistance, unit, 3)
            if ok and ns.IsSecret(r) then return r end
            if ok and r then return true end
            ok, r = pcall(CheckInteractDistance, unit, 2)
            if ok and ns.IsSecret(r) then return r end
            if ok and r then return true end
            return false
        end
    elseif dist == 20 or dist == 30 then
        if CheckInteractDistance then
            local ok, r = pcall(CheckInteractDistance, unit, 1)
            if ok and ns.IsSecret(r) then return r end
            if ok and r then return true end
            ok, r = pcall(CheckInteractDistance, unit, 4)
            if ok and ns.IsSecret(r) then return r end
            if ok and r then return true end
            return false
        end
    end

    if UnitInRange then
        local ok, inRange, checkedRange = pcall(UnitInRange, unit)
        if ok then
            -- (a secret: its own word, the check unknown, as Blizzard's
            -- compact frames have it when they cannot tell)
            if ns.IsSecret(inRange) then return inRange end
            if ns.IsSecret(checkedRange) or checkedRange then return inRange and true or false end
        end
    end

    if UnitIsVisible then
        local ok, vis = pcall(UnitIsVisible, unit)
        if ok then
            if ns.IsSecret(vis) then return vis end
            return vis and true or false
        end
    end
    return true
end

ns.UnitInRange = IsUnitInRange

-- A frame faded by its unit's range: near, a secret or not. A secret is
-- the client's to apply (SetAlphaFromBoolean takes it untested); a client
-- without that shows the frame whole.
local FADED = 0.45
function ns.RangeFade(f, near)
    if ns.IsSecret(near) then
        if f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(near, 1, FADED) else f:SetAlpha(1) end
    else
        f:SetAlpha(near and 1 or FADED)
    end
end

local function UpdatePartyRange()
    local dist = ns.db and ns.PartyOption("partyRange")
    for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
        local pb = ns.units[u]
        if pb and pb:IsShown() then
            local inRange = (dist == 0) or IsUnitInRange(u, dist)
            ns.RangeFade(pb, inRange)
            if pb.pet and pb.pet:IsShown() then ns.RangeFade(pb.pet, inRange) end
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
    if ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        UpdateAll(ns.partyWidgetPlayer)
    end
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
ns.UpdatePartyFrames = UpdatePartyFrames
ns.On("GROUP_ROSTER_UPDATE", UpdatePartyFrames)
-- A member who joins is shown before the game knows them (no name, class
-- or health yet), and what follows does not always reach the button as an
-- event of its own: the party looked at again as the roster settles
-- (2026-11-11: in combat, a joiner's frame in the Party widget stayed empty
-- till the fight ended). The last change's looks only.
local settling = 0
ns.On("GROUP_ROSTER_UPDATE", function()
    if not (C_Timer and C_Timer.After) then return end
    settling = settling + 1
    local mine = settling
    for _, t in ipairs({ 0.5, 1.5, 3 }) do
        C_Timer.After(t, function() if mine == settling then UpdatePartyFrames() end end)
    end
end)
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
-- the Party widget's own (settings.lua: ns.PartyOption), and the layout
-- choosing between them (the widget has no pets: ns.PartyPets)
ns.OnSetting("partyWidgetRange", UpdatePartyRange)
ns.OnSetting("partyLayout", function()
    UpdatePartyFrames()
    UpdatePartyRange()
end)

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

local function PartyCheckButtons()
    local out = { ns.units.party1, ns.units.party2, ns.units.party3, ns.units.party4 }
    if ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
        table.insert(out, ns.partyWidgetPlayer)
    end
    return out
end

local checkHideTime = nil
local checkTimerFrame = CreateFrame("Frame")
checkTimerFrame:SetScript("OnUpdate", function(_, elapsed)
    if checkHideTime then
        checkHideTime = checkHideTime - elapsed
        if checkHideTime <= 0 then
            checkHideTime = nil
            for _, pb in ipairs(PartyCheckButtons()) do
                SetCheckStatus(pb, nil)
            end
        end
    end
end)

local function OnReadyCheck()
    checkHideTime = nil
    for _, pb in ipairs(PartyCheckButtons()) do
        local u = pb.unit
        if UnitExists(u) or pb.stub then
            local status = GetReadyCheckStatus and GetReadyCheckStatus(u) or "waiting"
            SetCheckStatus(pb, status)
        end
    end
end

local function OnReadyCheckConfirm(unit, isReady)
    local pb = unit == "player" and (ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget and ns.partyWidgetPlayer)
        or ns.units[unit]
    if pb then
        SetCheckStatus(pb, isReady and "ready" or "notready")
    end
end

local function OnReadyCheckFinished()
    for _, pb in ipairs(PartyCheckButtons()) do
        if pb.isChecking then
            local status = GetReadyCheckStatus and GetReadyCheckStatus(pb.unit)
            if status then SetCheckStatus(pb, status) end
        end
    end
    checkHideTime = 3.0
end

local function OnRolePollBegin()
    checkHideTime = nil
    for _, pb in ipairs(PartyCheckButtons()) do
        if UnitExists(pb.unit) or pb.stub then
            SetCheckStatus(pb, "waiting")
        end
    end
end

local function OnRolePollUpdate()
    for _, pb in ipairs(PartyCheckButtons()) do
        if pb.isChecking then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(pb.unit)
            if role and role ~= "NONE" then
                SetCheckStatus(pb, "ready")
            end
        end
    end
end

local function ClearCheckStatus()
    checkHideTime = nil
    for _, pb in ipairs(PartyCheckButtons()) do
        if pb.isChecking then
            SetCheckStatus(pb, nil)
        end
    end
end

ns.On("READY_CHECK", OnReadyCheck)
ns.On("READY_CHECK_CONFIRM", OnReadyCheckConfirm)
ns.On("READY_CHECK_FINISHED", OnReadyCheckFinished)

-- a new leader: every console button's crown (the widget cells': box.lua)
for _, e in ipairs({ "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE" }) do
    ns.On(e, function()
        for _, b in pairs(ns.units) do UpdateLeader(b) end
        if ns.partyWidgetPlayer and ns.partyWidgetPlayer.inWidget then
            UpdateLeader(ns.partyWidgetPlayer)
        end
    end)
end
ns.On("ROLE_POLL_BEGIN", OnRolePollBegin)
ns.On("ROLE_POLL_UPDATE", OnRolePollUpdate)
ns.On("PLAYER_REGEN_DISABLED", ClearCheckStatus)
