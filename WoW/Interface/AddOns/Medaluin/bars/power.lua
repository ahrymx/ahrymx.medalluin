-- The class resource in the action bar's lower row: combo points, holy
-- power, chi, soul shards, arcane charges, essence or runes, or vigor
-- charges while on a dragonriding mount, as one segment each across the row.
-- A class or spec without one (or a druid out of cat form) leaves the row
-- empty when unmounted. The cast bar (bars/cast.lua) covers it while the
-- player casts.
--
-- The current value may be secret (Forever, retail), and Lua cannot compare
-- a secret. So every segment is a status bar spanning one point of the
-- resource, i-1 to i, and is handed the whole value: the bar clamps it, so
-- segment i is full exactly when the value reaches i, without a comparison.
-- The count of segments is the resource's maximum, which is read as a plain
-- number where the client gives one and otherwise taken from Blizzard's
-- usual maximum below.
local _, ns = ...

local P = Enum and Enum.PowerType or {}
-- power type, its usual maximum, its colour, and the spec or form it needs
local POWERS = {
    ROGUE = { P.ComboPoints or 4, 5, { 0.91, 0.78, 0.38 } },
    DRUID = { P.ComboPoints or 4, 5, { 0.91, 0.78, 0.38 }, cat = true },
    PALADIN = { P.HolyPower or 9, 5, { 0.95, 0.85, 0.45 } },
    MONK = { P.Chi or 12, 5, { 0.42, 0.82, 0.64 }, spec = 3 },
    WARLOCK = { P.SoulShards or 7, 5, { 0.62, 0.40, 0.86 } },
    MAGE = { P.ArcaneCharges or 16, 4, { 0.45, 0.62, 1.00 }, spec = 1 },
    EVOKER = { P.Essence or 19, 5, { 0.40, 0.80, 0.76 } },
    DEATHKNIGHT = { P.Runes or 5, 6, { 0.80, 0.22, 0.26 } },
}
local ENERGY = P.Energy or 3
local MAX_SEGMENTS, SEGMENT_GAP = 10, 1
local VIGOR_COLOR = { 0.20, 0.70, 0.95 }
local VIGOR_SPELLS = { 372610, 372608 }   -- Skyward Ascent, Surge Forward

local function Active(p)
    if p.spec and GetSpecialization then
        local spec = GetSpecialization()
        if not ns.IsSecret(spec) and spec ~= p.spec then return false end
    end
    if p.cat then
        local kind = UnitPowerType("player")
        if not ns.IsSecret(kind) and kind ~= ENERGY then return false end
    end
    return true
end

-- The segment count: the client's maximum when it is a plain number, the
-- usual one when it is secret, none when the client has no such resource.
local function Count(p)
    local max = UnitPowerMax("player", p[1])
    if ns.IsSecret(max) then return p[2] end
    return math.min(MAX_SEGMENTS, max or 0)
end

local function VigorCharges()
    for _, id in ipairs(VIGOR_SPELLS) do
        if C_Spell and C_Spell.GetSpellCharges then
            local info = C_Spell.GetSpellCharges(id)
            if type(info) == "table" and info.currentCharges then
                return info.currentCharges, info.maxCharges or 6,
                    info.cooldownStartTime or info.cooldownStart, info.cooldownDuration,
                    info.chargeModRate or 1
            elseif info ~= nil then
                local cur, max, start, dur, rate = C_Spell.GetSpellCharges(id)
                if cur then return cur, max or 6, start, dur, rate or 1 end
            end
        end
        if GetSpellCharges then
            local cur, max, start, dur, rate = GetSpellCharges(id)
            if cur then return cur, max or 6, start, dur, rate or 1 end
        end
    end
end

local function IsSkyriding()
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
        if canGlide or isGliding then return true end
    end
    if IsMounted and IsMounted() and VigorCharges() ~= nil then
        return true
    end
    return false
end

local function VigorState()
    if not IsSkyriding() then return nil end
    local cur, max, start, dur, rate = VigorCharges()
    if not cur then return nil end
    return cur, max or 6, start, dur, rate
end

local function VigorValue(cur, max, start, dur, rate)
    if ns.IsSecret(cur) then return cur end
    if start and start > 0 and dur and dur > 0 and cur < max then
        local now = GetTime()
        local progress = (now - start) / dur * (rate or 1)
        if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
        return cur + progress
    end
    return cur
end

function ns.BuildPower(tray)
    local w = ns.barLow
    local strip = CreateFrame("Frame", nil, tray)
    strip:SetFrameLevel(ns.levels.barPower)
    strip:SetPoint("TOPLEFT", ns.console, "TOP", w[1], w[3])
    strip:SetPoint("BOTTOMRIGHT", ns.console, "TOP", w[2], w[4])
    local ink = strip:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(unpack(ns.colors.ink))
    ns.barPower = strip

    local _, class = UnitClass("player")
    local p = POWERS[class]
    local segments = {}
    strip.segments = segments

    local c = p and p[3] or VIGOR_COLOR
    for i = 1, MAX_SEGMENTS do
        local bar = CreateFrame("StatusBar", nil, strip)
        bar:SetStatusBarTexture(ns.bar)
        bar:SetStatusBarColor(c[1], c[2], c[3])
        bar:SetMinMaxValues(i - 1, i)
        local back = bar:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(c[1] * 0.22, c[2] * 0.22, c[3] * 0.22)
        bar.back = back
        segments[i] = bar
    end

    local currentColor
    local function ApplyColor(color)
        if currentColor == color or not color then return end
        currentColor = color
        local r, g, b = color[1], color[2], color[3]
        for _, bar in ipairs(segments) do
            bar:SetStatusBarColor(r, g, b)
            bar.back:SetColorTexture(r * 0.22, g * 0.22, b * 0.22)
        end
    end

    local shown
    local function Layout(n)
        shown = n
        local width = (w[2] - w[1] - (n - 1) * SEGMENT_GAP) / math.max(n, 1)
        for i, bar in ipairs(segments) do
            bar:ClearAllPoints()
            if i <= n then
                bar:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * (width + SEGMENT_GAP), 0)
                bar:SetSize(width, w[3] - w[4])
            end
            bar:SetShown(i <= n)
        end
    end

    local function OnUpdate()
        local cur, max, start, dur, rate = VigorState()
        if cur ~= nil and not ns.IsSecret(cur) and start and start > 0 and dur and dur > 0 and cur < max then
            local val = VigorValue(cur, max, start, dur, rate)
            for i = 1, shown or 0 do segments[i]:SetValue(val) end
        else
            strip:SetScript("OnUpdate", nil)
        end
    end

    local function Value()
        if not shown or shown == 0 then
            strip:SetScript("OnUpdate", nil)
            return
        end
        local vCur, vMax, vStart, vDur, vRate = VigorState()
        if vCur ~= nil then
            local v = VigorValue(vCur, vMax, vStart, vDur, vRate)
            for i = 1, shown do segments[i]:SetValue(v) end
            if not ns.IsSecret(vCur) and vStart and vStart > 0 and vDur and vDur > 0 and vCur < vMax then
                strip:SetScript("OnUpdate", OnUpdate)
            else
                strip:SetScript("OnUpdate", nil)
            end
        else
            strip:SetScript("OnUpdate", nil)
            if p then
                local v = UnitPower("player", p[1])
                for i = 1, shown do segments[i]:SetValue(v) end
            end
        end
    end

    local function Refresh()
        local vCur, vMax = VigorState()
        local n, color
        if vCur ~= nil then
            n = ns.IsSecret(vMax) and 6 or math.min(MAX_SEGMENTS, vMax or 6)
            color = VIGOR_COLOR
        elseif p and Active(p) then
            n = Count(p)
            color = p[3]
        else
            n = 0
        end
        ApplyColor(color)
        if n ~= shown then Layout(n) end
        Value()
    end
    strip.Refresh = Refresh

    strip:SetScript("OnEvent", function(_, event)
        if event == "UNIT_POWER_FREQUENT" or event == "RUNE_POWER_UPDATE" then
            Value()
        else
            Refresh()
        end
    end)
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        ns.RegisterUnitEvent(strip, e, "player")
    end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "RUNE_POWER_UPDATE", "SPELL_UPDATE_CHARGES", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_CAN_GLIDE_CHANGED" }) do
        pcall(strip.RegisterEvent, strip, e)
    end
    Refresh()
end
