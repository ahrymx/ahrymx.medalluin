-- The player's cast bar, in the action bar's lower row (a pill: the plate
-- above crops its square ends), over the class
-- resource (bars/power.lua): gold fill from the left (draining for a
-- channel), spell name left, time left right. A failed or interrupted cast
-- turns red and fades. Idle, it is fully transparent, so the class resource
-- shows; while it is up, its own ink covers the resource.
--
-- The player's own cast times are plain numbers on every client, so the bar
-- is driven from them. Forever and retail can flag a spell's cast as secret;
-- such a cast runs on the status bar's own timer (SetTimerDuration), with no
-- time shown, since Lua cannot do sums on it.
--
-- Built with the action bar (bars/bar.lua), which retires Blizzard's player
-- cast bar; with the Action bar option off, Blizzard's stays.
local _, ns = ...

local C = ns.colors
local FILL, FAIL = { 0.85, 0.70, 0.36 }, { 0.72, 0.20, 0.16 }
local FADE = 0.6

-- Classic-era builds have used both spellings.
local Casting = UnitCastingInfo or function() return CastingInfo() end
local Channel = UnitChannelInfo or function() return ChannelInfo() end

local DurationOf = { cast = UnitCastingDuration, channel = UnitChannelDuration }
local Timer = Enum and Enum.StatusBarTimerDirection

local function Same(a, b)
    if ns.IsSecret(a) or ns.IsSecret(b) then return true end
    return a == b
end

function ns.BuildCast(tray)
    local w = ns.barLow
    local bar = CreateFrame("StatusBar", nil, tray)
    bar:SetFrameLevel(ns.levels.barCast)
    bar:SetPoint("TOPLEFT", ns.console, "TOP", w[1], w[3])
    bar:SetPoint("BOTTOMRIGHT", ns.console, "TOP", w[2], w[4])
    bar:SetStatusBarTexture(ns.bar)
    bar:SetMinMaxValues(0, 1)
    bar:SetAlpha(0)
    local ink = bar:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(unpack(C.ink))
    ns.barCast = bar

    -- the spark rides the fill's leading edge, wherever the value came from
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(1, 1, 1, 0.8)
    spark:SetSize(2, w[3] - w[4])
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")

    local name, clock = ns.Text(bar, 10), ns.Text(bar, 10)
    -- clear of the pill's rounded ends
    name:SetPoint("LEFT", 8, 0)
    clock:SetPoint("RIGHT", -8, 0)
    clock:SetJustifyH("RIGHT")
    bar.name, bar.clock = name, clock

    -- state: "cast", "channel", "timer" (a secret cast), "fade" or nil
    local state, castID, start, finish, fadeAt
    local channelling

    local function Show(kind, label, s, f, id)
        castID, channelling = id, kind == "channel"
        if ns.IsSecret(s) or ns.IsSecret(f) then
            local duration = DurationOf[kind] and DurationOf[kind]("player")
            if not (duration and bar.SetTimerDuration and Timer) then return end
            bar:SetTimerDuration(duration, 0, channelling and Timer.RemainingTime or Timer.ElapsedTime)
            state = "timer"
            clock:SetText("")
        else
            state, start, finish = kind, s / 1000, f / 1000
        end
        bar:SetStatusBarColor(unpack(FILL))
        name:SetText(label)
        name:SetTextColor(unpack(C.text))
        spark:Show()
        bar:SetAlpha(1)
    end

    local function Fade(failed)
        if failed then
            bar:SetStatusBarColor(unpack(FAIL))
            bar:SetValue(1)
            name:SetText(failed)
            clock:SetText("")
        end
        spark:Hide()
        state, fadeAt = "fade", GetTime()
    end

    local function Begin()
        -- a cast's name can be secret too: test it for nil, never for truth
        local label, _, _, s, f, _, id = Casting("player")
        if ns.Present(label) then return Show("cast", label, s, f, id) end
        label, _, _, s, f = Channel("player")
        if ns.Present(label) then return Show("channel", label, s, f) end
    end

    bar:SetScript("OnUpdate", function()
        local now = GetTime()
        if state == "fade" then
            local a = 1 - (now - fadeAt) / FADE
            bar:SetAlpha(math.max(0, a))
            if a <= 0 then state = nil end
            return
        elseif not state or state == "timer" then
            return
        end
        local span = finish - start
        local v = span > 0 and (now - start) / span or 1
        if state == "channel" then v = 1 - v end
        v = math.min(1, math.max(0, v))
        bar:SetValue(v)
        clock:SetFormattedText("%.1f", math.max(0, finish - now))
    end)

    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        ns.RegisterUnitEvent(bar, e, "player")
    end
    bar:SetScript("OnEvent", function(_, event, _, id)
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            Begin()
        elseif event == "UNIT_SPELLCAST_STOP" then
            if (state == "cast" or state == "timer" and not channelling) and Same(id, castID) then
                bar:SetValue(1)
                Fade()
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if state == "channel" or state == "timer" and channelling then Fade() end
        elseif Same(id, castID) and (state == "cast" or state == "timer" or state == "fade") then
            -- FAILED or INTERRUPTED, before or after the STOP that ends it
            Fade(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        end
    end)
    ns.On("PLAYER_ENTERING_WORLD", Begin)
    Begin()

    -- Blizzard's player cast bar: PlayerCastingBarFrame on the Edit Mode
    -- clients, CastingBarFrame before them
    ns.OutOfCombat(function()
        ns.Kill(PlayerCastingBarFrame)
        ns.Kill(CastingBarFrame)
    end)
end
