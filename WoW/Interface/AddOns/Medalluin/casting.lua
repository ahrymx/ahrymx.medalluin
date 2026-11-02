-- One unit's casts, driving a status bar: the player's in the action bar's
-- lower row (bars/cast.lua), and, as options, the player's over the beam's
-- experience half and the target's over its reputation half (console/xp.lua).
-- Gold fill (draining for a channel); a failed or interrupted cast turns red
-- and fades. Idle, the bar is fully transparent, so what lies under it shows.
--
-- The player's own cast times are plain numbers on every client, so the bar
-- is driven from them. Forever and retail can flag a cast as secret (and a
-- target's often is); such a cast runs on the status bar's own timer
-- (SetTimerDuration), with no time shown, since Lua cannot do sums on it.
local _, ns = ...

local C = ns.colors
local FILL, FAIL = { 0.85, 0.70, 0.36 }, { 0.72, 0.20, 0.16 }
local FADE = 0.6

-- Classic-era builds have used both spellings; the old one is the player's only.
local Casting = UnitCastingInfo or function(unit) if unit == "player" then return CastingInfo() end end
local Channel = UnitChannelInfo or function(unit) if unit == "player" then return ChannelInfo() end end

local DurationOf = { cast = UnitCastingDuration, channel = UnitChannelDuration }
local Timer = Enum and Enum.StatusBarTimerDirection

local function Same(a, b)
    if ns.IsSecret(a) or ns.IsSecret(b) then return true end
    return a == b
end

local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }

-- ns.CastBar(bar, unit, parts): parts.spark, parts.name and parts.clock are
-- optional. Returns a driver with :SetEnabled(on); switched off, the bar is
-- hidden, and switched on, it picks up a cast already under way.
function ns.CastBar(bar, unit, parts)
    local spark, name, clock = parts.spark, parts.name, parts.clock
    local enabled = true
    bar:SetMinMaxValues(0, 1)
    bar:SetAlpha(0)

    -- state: "cast", "channel", "timer" (a secret cast), "fade" or nil
    local state, castID, start, finish, fadeAt
    local channelling

    local function Idle()
        state = nil
        bar:SetAlpha(0)
    end

    local function Show(kind, label, s, f, id)
        castID, channelling = id, kind == "channel"
        if ns.IsSecret(s) or ns.IsSecret(f) then
            local duration = DurationOf[kind] and DurationOf[kind](unit)
            if not (duration and bar.SetTimerDuration and Timer) then return end
            bar:SetTimerDuration(duration, 0, channelling and Timer.RemainingTime or Timer.ElapsedTime)
            state = "timer"
            if clock then clock:SetText("") end
        else
            state, start, finish = kind, s / 1000, f / 1000
        end
        bar:SetStatusBarColor(unpack(FILL))
        if name then
            name:SetText(label)
            name:SetTextColor(unpack(C.text))
        end
        if spark then spark:Show() end
        bar:SetAlpha(1)
    end

    local function Fade(failed)
        if failed then
            bar:SetStatusBarColor(unpack(FAIL))
            bar:SetValue(1)
            if name then name:SetText(failed) end
            if clock then clock:SetText("") end
        end
        if spark then spark:Hide() end
        state, fadeAt = "fade", GetTime()
    end

    local function Begin()
        if not enabled then return end
        -- a cast's name can be secret too: test it for nil, never for truth
        local label, _, _, s, f, _, id = Casting(unit)
        if ns.Present(label) then return Show("cast", label, s, f, id) end
        label, _, _, s, f = Channel(unit)
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
        if clock then clock:SetFormattedText("%.1f", math.max(0, finish - now)) end
    end)

    for _, e in ipairs(EVENTS) do ns.RegisterUnitEvent(bar, e, unit) end
    -- switched off, nothing starts (Begin), so nothing is left to stop
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
    -- a new target: its cast, if it is casting, or nothing
    if unit == "target" then
        ns.On("PLAYER_TARGET_CHANGED", function()
            Idle()
            Begin()
        end)
    end
    Begin()

    return {
        SetEnabled = function(_, on)
            enabled = on and true or false
            Idle()
            bar:SetShown(enabled)
            Begin()
        end,
    }
end
