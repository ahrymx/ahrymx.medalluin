-- Fading the console and the overhead.
--
--   the console    Console > General > Visibility and Opacity: while it is
--                  idle (nothing ticked there is so) it fades to its faded
--                  opacity, and back to its opacity when something is
--   the overhead   Console > Overhead > Opacity: it shows whenever it holds
--                  anything (console/overhead.lua), so it only fades in as it
--                  appears and out as it empties
--
-- Only the alpha changes, which is allowed in combat, so a faded console
-- keeps working: its buttons still click and its keys still press, as a faded
-- action bar's do (bars/bar.lua). The corner strips and the corner minimap
-- are the console's children but not its body, so they keep their own alpha.
local _, ns = ...

local console, overhead = ns.console, ns.overhead

local function Num(key, lo, hi)
    local v = tonumber(ns.db[key])
    if v == nil then v = tonumber(ns.OptionBase(key)) or lo end
    return math.max(lo, math.min(hi, v))
end

-- A frame's alpha eased toward a goal: a fade takes `time` seconds however
-- far it goes, and `done` runs when it gets there. The driver is its own
-- frame, so it runs while the faded frame is hidden too.
function ns.Fader(frame)
    local o = { alpha = frame:GetAlpha() or 1 }
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    local function Arrive()
        driver:Hide()
        local done = o.done
        o.done = nil
        if done then done() end
    end
    function o:Set(a)
        self.alpha = a
        frame:SetAlpha(a)
    end
    function o:Go(goal, time, done)
        self.goal, self.done = goal, done
        local dist = math.abs(goal - self.alpha)
        if not time or time <= 0 or dist == 0 then
            self:Set(goal)
            Arrive()
            return
        end
        self.rate = dist / time
        driver:Show()
    end
    function o:Moving() return driver:IsShown() end
    driver:SetScript("OnUpdate", function(_, dt)
        local a, g = o.alpha, o.goal
        local step = dt * o.rate
        a = g > a and math.min(g, a + step) or math.max(g, a - step)
        o:Set(a)
        if a == g then Arrive() end
    end)
    o.driver = driver
    return o
end

-- ------------------------------------------------------------ the console
local fader = ns.Fader(console)
ns.consoleFader = fader
local inCombat = false

-- Hurt: health below its most. A secret value cannot be compared, so it
-- says nothing either way; in combat, where values go secret, In combat
-- answers instead.
local function Hurt()
    local h, most = UnitHealth("player"), UnitHealthMax("player")
    if ns.IsSecret(h) or ns.IsSecret(most) or not h or not most or most <= 0 then return false end
    return h < most
end

-- The pointer over the console or anything that hangs off it.
local function Over()
    for _, f in ipairs({ console, ns.actionBar, ns.extraBars, ns.partyRowBand }) do
        if f and f:IsVisible() and f:IsMouseOver() then return true end
    end
    return ns.drawer and ns.drawer:IsShown() and ns.drawer:IsMouseOver() or false
end

-- Whether the console shows at its full opacity now. Binding keys, a spell
-- or item on the cursor, Edit Mode's movers and the party preview always
-- want it whole: they are about what is on it.
function ns.ConsoleWanted()
    local db = ns.db
    if not db.consoleFade then return true end
    if ns.keybinding or (GetCursorInfo and GetCursorInfo()) or db.simParty
        or (ns.ConsoleMoversShown and ns.ConsoleMoversShown()) then
        return true
    end
    return (db.consoleShowCombat and inCombat)
        or (db.consoleShowTarget and UnitExists("target"))
        or (db.consoleShowHurt and Hurt())
        or (db.consoleShowGroup and IsInGroup())
        or (db.consoleShowMouse and Over())
        or false
end

local wanted
-- now: a setting changed, so go there at once rather than fade
local function Update(now)
    local want = ns.ConsoleWanted()
    local goal = want and Num("consoleAlpha", 0, 1) or Num("consoleFadedAlpha", 0, 1)
    if not now and want == wanted and goal == fader.goal then return end
    wanted = want
    fader:Go(goal, (not now) and Num(want and "consoleFadeIn" or "consoleFadeOut", 0, 10) or 0)
end
ns.UpdateConsoleFade = Update

-- The pointer has no event, so the console looks ten times a second.
local watch = CreateFrame("Frame", nil, UIParent)
local since = 0
watch:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    Update()
end)
ns.consoleFadeWatch = watch

ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; Update() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; Update() end)
ns.On("PLAYER_TARGET_CHANGED", function() Update() end)
ns.On("GROUP_ROSTER_UPDATE", function() Update() end)
ns.On("PLAYER_ENTERING_WORLD", function()
    inCombat = UnitAffectingCombat("player") and true or false
    Update(true)
end)
for _, key in ipairs({ "consoleFade", "consoleShowCombat", "consoleShowTarget", "consoleShowHurt",
    "consoleShowGroup", "consoleShowMouse", "consoleAlpha", "consoleFadedAlpha", "simParty" }) do
    ns.OnSetting(key, function() Update(true) end)
end

-- The strips keep their own alpha (the minimap in the corner sets its own:
-- console/minimap.lua).
ns.On("PLAYER_LOGIN", function()
    for _, strip in pairs(ns.strips or {}) do
        if strip.SetIgnoreParentAlpha then strip:SetIgnoreParentAlpha(true) end
    end
    Update(true)
end)

-- ------------------------------------------------------------ the overhead
local top = ns.Fader(overhead)
ns.overheadFader = top

-- As it appears: from nothing, or from wherever a fade out had got to.
function ns.OverheadFadeIn()
    local goal = Num("overheadAlpha", 0, 1)
    if not top:Moving() and top.alpha == goal then return end
    top:Go(goal, Num("overheadFadeIn", 0, 10))
end
-- As it empties: what it showed stays while it fades, then done() clears it.
-- False when there is no fade to make, and the overhead should go at once.
function ns.OverheadFadeOut(done)
    local time = Num("overheadFadeOut", 0, 10)
    if time <= 0 then return false end
    top:Go(0, time, done)
    return true
end
-- Shown at once: before it ever appears, and when it is turned off
function ns.OverheadSettle(shown)
    top:Go(shown and Num("overheadAlpha", 0, 1) or 0, 0)
end
ns.OnSetting("overheadAlpha", function()
    if overhead:IsShown() and not (top:Moving() and top.goal == 0) then top:Go(Num("overheadAlpha", 0, 1), 0) end
end)
