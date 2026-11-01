-- The beam: the two thin windows either side of the ring. The left half is
-- experience (with rested shown as a darker run ahead of it), the right half
-- is the watched reputation, mirrored. Both fill from the outer end inward.
-- Hover either half for the numbers.
--
-- With the Experience and Reputation cast options (settings.lua), a half is
-- also a cast bar: the player's casts over experience, under the player's
-- frame, and the target's over reputation, under the target's. A cast bar
-- lies over its half with its own ink, mirrored like it, and is clear while
-- its unit is not casting, so the half shows. The window is 8px high: no
-- room for a spell name or a time, so a cast is the fill and its spark.
local _, ns = ...

local console, C = ns.console, ns.colors

local function Half(side)
    local bar = CreateFrame("StatusBar", nil, console)
    bar:SetFrameLevel(ns.levels.bars + 1)
    bar:SetStatusBarTexture(ns.bar)
    bar:SetReverseFill(side == 1)
    ns.PlaceOn(bar, console, "xp", side)
    -- the hit area sits above the art so the tooltip can be reached
    bar.hit = CreateFrame("Frame", nil, console)
    bar.hit:SetFrameLevel(ns.levels.text)
    bar.hit:SetAllPoints(bar)
    bar.hit:EnableMouse(true)
    bar.hit:SetScript("OnLeave", GameTooltip_Hide)
    return bar
end

local xp, rep = Half(-1), Half(1)
xp:SetStatusBarColor(unpack(C.xp))
rep:SetStatusBarColor(unpack(C.rep))
ns.xpBar, ns.repBar = xp, rep

function ns.RelayoutXP()
    ns.PlaceOn(xp, console, "xp", -1)
    ns.PlaceOn(rep, console, "xp", 1)
    if ns.beamCast then
        ns.PlaceOn(ns.beamCast.player, console, "xp", -1)
        ns.PlaceOn(ns.beamCast.target, console, "xp", 1)
    end
end

local rested = CreateFrame("StatusBar", nil, console)
rested:SetFrameLevel(ns.levels.bars)
rested:SetStatusBarTexture(ns.bar)
rested:SetStatusBarColor(unpack(C.rested))
rested:SetAllPoints(xp)

local function AtMaxLevel()
    local max = GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_PLAYER_LEVEL
    return UnitLevel("player") >= (max or 60)
end

local function UpdateXP()
    if AtMaxLevel() then
        xp:SetValue(0)
        rested:SetValue(0)
        return
    end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    max = max > 0 and max or 1
    xp:SetMinMaxValues(0, max)
    xp:SetValue(cur)
    rested:SetMinMaxValues(0, max)
    rested:SetValue(math.min(max, cur + (GetXPExhaustion() or 0)))
end

-- Retail-shaped clients moved this into C_Reputation; take whichever exists.
local function Watched()
    if GetWatchedFactionInfo then
        local name, standing, min, max, value = GetWatchedFactionInfo()
        if name then return name, standing, value - min, max - min end
    elseif C_Reputation and C_Reputation.GetWatchedFactionData then
        local d = C_Reputation.GetWatchedFactionData()
        if d then
            return d.name, d.reaction, d.currentStanding - d.currentReactionThreshold,
                d.nextReactionThreshold - d.currentReactionThreshold
        end
    end
end

local function UpdateRep()
    local name, _, value, span = Watched()
    rep:SetMinMaxValues(0, (span and span > 0) and span or 1)
    rep:SetValue(name and value or 0)
end

xp.hit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if AtMaxLevel() then
        GameTooltip:SetText(LEVEL .. " " .. UnitLevel("player"))
    else
        local cur, max = UnitXP("player"), UnitXPMax("player")
        GameTooltip:SetText(XP)
        GameTooltip:AddLine(format("%s / %s (%d%%)", BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max),
            max > 0 and math.floor(cur / max * 100) or 0), 1, 1, 1)
        local restedXP = GetXPExhaustion()
        if restedXP then
            GameTooltip:AddLine(format("Rested: %s", BreakUpLargeNumbers(restedXP)), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end)

rep.hit:SetScript("OnEnter", function(self)
    local name, standing, value, span = Watched()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if not name then
        GameTooltip:SetText(REPUTATION)
        GameTooltip:AddLine("No faction watched.", 1, 1, 1)
    else
        GameTooltip:SetText(name)
        local label = _G["FACTION_STANDING_LABEL" .. (standing or 4)] or ""
        GameTooltip:AddLine(format("%s  %s / %s", label,
            BreakUpLargeNumbers(value), BreakUpLargeNumbers(span)), 1, 1, 1)
    end
    GameTooltip:Show()
end)

-- the cast bars, above the halves and below the art
local function CastOver(side, unit, key)
    local bar = CreateFrame("StatusBar", nil, console)
    bar:SetFrameLevel(ns.levels.bars + 2)
    bar:SetStatusBarTexture(ns.bar)
    bar:SetReverseFill(side == 1)
    ns.PlaceOn(bar, console, "xp", side)
    local ink = bar:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(unpack(C.ink))
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(1, 1, 1, 0.8)
    spark:SetSize(2, select(4, ns.Rect("xp", side)))
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), side == 1 and "LEFT" or "RIGHT")
    local driver = ns.CastBar(bar, unit, { spark = spark })
    -- the saved option is only known once the addon has loaded
    ns.On("PLAYER_LOGIN", function() driver:SetEnabled(ns.db[key]) end)
    ns.OnSetting(key, function(on) driver:SetEnabled(on) end)
    return bar
end
ns.beamCast = { player = CastOver(-1, "player", "xpCast"), target = CastOver(1, "target", "repCast") }

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" }) do
    ns.On(e, UpdateXP)
end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_FACTION" }) do
    ns.On(e, UpdateRep)
end
