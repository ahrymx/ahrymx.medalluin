-- The action bar's lower row shows the class resource (bars/power.lua) or,
-- as chosen on Console > Action Bars, one of the two built here: the swing
-- timer or mana. The cast bar (bars/cast.lua) covers whichever it is while
-- the player casts.
--
-- The swing timer hears PLAYER_SWING, the event Forever's own swing timer
-- (Blizzard_SwingTimer) is built on: each swing's length and its hand, as
-- plain numbers. Retail has no such event, and its combat log is closed to
-- addons, so there the choice is not offered, and a profile holding it
-- shows the class resource. It follows the main hand and the ranged shot;
-- the off hand's swings would start it over between the main hand's.
--
-- Mana may be secret: the bar takes it as it is, and the number at its
-- right is AbbreviateLargeNumbers', which takes a secret too.
local _, ns = ...

local OFF_HAND = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.OffHand or 1
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local SWING_COLOR = ns.colors.xp
local MANA_COLOR = { 0.0, 0.0, 1.0 }    -- Blizzard's, when PowerBarColor is missing

function ns.SwingTimerAvailable() return C_SwingTimer ~= nil end

-- what the row shows: the choice, or the class resource where it cannot be had
function ns.LowRow()
    local v = ns.db.barLowRow
    if v == "mana" or v == "swing" and ns.SwingTimerAvailable() then return v end
    return "resource"
end

local function Short(v)
    if AbbreviateLargeNumbers then
        local ok, s = pcall(AbbreviateLargeNumbers, v)
        if ok then return s end
    end
    return v
end

-- a bar over the row's window, its own ink under it, a number at its right
-- clear of the window's gold edge, as the cast bar's
local function Strip(tray, color)
    local w = ns.barLow
    local bar = CreateFrame("StatusBar", nil, tray)
    bar:SetFrameLevel(ns.levels.barPower)
    bar:SetPoint("TOPLEFT", ns.console, "TOP", w[1], w[3])
    bar:SetPoint("BOTTOMRIGHT", ns.console, "TOP", w[2], w[4])
    bar:SetStatusBarTexture(ns.bar)
    bar:SetStatusBarColor(color[1] * ns.mute, color[2] * ns.mute, color[3] * ns.mute)
    local ink = bar:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(unpack(ns.colors.ink))
    bar.clock = ns.Text(bar, 10)
    bar.clock:SetPoint("RIGHT", -8, 0)
    bar.clock:SetJustifyH("RIGHT")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

-- fills over the swing, the seconds left at its right; empty between swings
local function Swing(tray)
    local bar = Strip(tray, SWING_COLOR)
    local length, ends
    local function Tick()
        local left = ends - GetTime()
        if left <= 0 then
            bar:SetScript("OnUpdate", nil)
            bar:SetValue(0)
            bar.clock:SetText("")
            return
        end
        bar:SetValue(1 - left / length)
        bar.clock:SetFormattedText("%.1f", left)
    end
    bar:SetScript("OnEvent", function(_, _, duration, hand)
        if hand == OFF_HAND then return end
        length, ends = duration, GetTime() + duration
        bar:SetScript("OnUpdate", Tick)
        Tick()
    end)
    -- heard only while shown; a swing under the cast bar still counts
    function bar.Listen(on)
        if on then
            pcall(bar.RegisterEvent, bar, "PLAYER_SWING")
        else
            bar:UnregisterAllEvents()
        end
    end
    return bar
end

local function Mana(tray)
    local c = PowerBarColor and PowerBarColor.MANA
    local bar = Strip(tray, c and { c.r, c.g, c.b } or MANA_COLOR)
    -- a class without mana has an empty row: no bar, no number
    function bar.Update()
        local max = UnitPowerMax("player", MANA)
        if not ns.IsSecret(max) and max <= 0 then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            bar.clock:SetText("")
            return
        end
        local cur = UnitPower("player", MANA)
        bar:SetMinMaxValues(0, max)
        bar:SetValue(cur)
        bar.clock:SetText(Short(cur))
    end
    bar:SetScript("OnEvent", function(_, event, _, kind)
        if event == "UNIT_POWER_FREQUENT" and not ns.IsSecret(kind) and kind ~= "MANA" then return end
        bar.Update()
    end)
    function bar.Listen(on)
        if on then
            ns.RegisterUnitEvent(bar, "UNIT_POWER_FREQUENT", "player")
            ns.RegisterUnitEvent(bar, "UNIT_MAXPOWER", "player")
            pcall(bar.RegisterEvent, bar, "PLAYER_ENTERING_WORLD")
            bar.Update()
        else
            bar:UnregisterAllEvents()
        end
    end
    return bar
end

-- Built with the action bar (bars/bar.lua), after the class resource.
function ns.BuildLowRow(tray)
    local rows = { swing = Swing(tray), mana = Mana(tray) }
    ns.barSwing, ns.barMana = rows.swing, rows.mana
    local function Apply()
        local row = ns.LowRow()
        if ns.barPower then ns.barPower:SetShown(row == "resource") end
        for key, bar in pairs(rows) do
            bar.Listen(row == key)
            bar:SetShown(row == key)
        end
    end
    ns.OnSetting("barLowRow", Apply)
    Apply()
end
