-- The player's cast bar, in the action bar's lower row (a pill: the plate
-- above crops its square ends), over the class resource (bars/power.lua):
-- spell name left, time left right, its own ink covering the resource
-- while it is up. The casts themselves are casting.lua's.
--
-- Built with the action bar (bars/bar.lua), which retires Blizzard's player
-- cast bar; with the Action bar option off, Blizzard's stays.
local _, ns = ...

function ns.BuildCast(tray)
    local w = ns.barLow
    local bar = CreateFrame("StatusBar", nil, tray)
    bar:SetFrameLevel(ns.levels.barCast)
    bar:SetPoint("TOPLEFT", ns.console, "TOP", w[1], w[3])
    bar:SetPoint("BOTTOMRIGHT", ns.console, "TOP", w[2], w[4])
    bar:SetStatusBarTexture(ns.bar)
    local ink = bar:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(unpack(ns.colors.ink))
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
    ns.CastBar(bar, "player", { spark = spark, name = name, clock = clock })

    -- Blizzard's player cast bar: PlayerCastingBarFrame on the Edit Mode
    -- clients, CastingBarFrame before them
    ns.OutOfCombat(function()
        ns.Kill(PlayerCastingBarFrame)
        ns.Kill(CastingBarFrame)
    end)
end
