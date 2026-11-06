-- Blizzard's PlayerSpellsFrame (Blizzard_PlayerSpells, loaded on demand):
-- Forever's spellbook and talents, a tab each, shown one at a time. Each of
-- Medalluin's windows takes one tab (ns.PlayerSpellsTab), and shows while the
-- frame is open on it.
--
-- The frame keeps every way in: the keys, the micro buttons, Escape. While
-- the tab up is one of ours it opens and closes under a hidden parent; on
-- any other (the specialisations', or one whose window is off) it is back
-- under UIParent, Blizzard's to show. Which tab is up is the frame's own
-- record, not which page is showing: N shows the frame before it turns the
-- tab, and a page left marked shown would open the wrong window.
local _, ns = ...

local windows = {}                      -- PlayerSpellsUtil.FrameTabs key -> window
local PAGES = { SpellBook = "SpellBookFrame", ClassTalents = "TalentsFrame" }
local adopted, waiting

-- the key of the tab up, if it is one of ours
local function Tab()
    local f = PlayerSpellsFrame
    for key in pairs(windows) do
        if f.IsFrameTabActive and PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs then
            if f:IsFrameTabActive(PlayerSpellsUtil.FrameTabs[key]) then return key end
        else
            local page = f[PAGES[key]]
            if page and page:IsShown() then return key end
        end
    end
end

-- reparented at once unless the frame is protected and it is combat; then
-- at combat's end, to wherever the tab up says by then
local function Hold()
    local f = PlayerSpellsFrame
    local parent = Tab() and ns.hidden or UIParent
    if f:GetParent() == parent then return end
    if f:IsProtected() then
        ns.OutOfCombat(function() f:SetParent(Tab() and ns.hidden or UIParent) end)
    else
        f:SetParent(parent)
    end
end

-- One window on the right strip: ours opening closes the professions'
-- frame (out of combat; in combat the later one stands over the other).
local function Show()
    local f, tab = PlayerSpellsFrame, Tab()
    for key, w in pairs(windows) do w.SetShown(f:IsShown() and tab == key) end
    if tab and f:IsShown() and ns.professions and ns.professions.window and ProfessionsFrame
        and ProfessionsFrame:IsShown() and not InCombatLockdown() then
        HideUIPanel(ProfessionsFrame)
    end
end

-- Closing is at once; opening waits for the frame's end, by when Blizzard's
-- toggle has turned its tab (N on a frame last left on the book would
-- otherwise open the book for that moment).
local function Sync()
    Hold()
    local f, tab = PlayerSpellsFrame, Tab()
    for key, w in pairs(windows) do
        if not (f:IsShown() and tab == key) then w.SetShown(false) end
    end
    if not (f:IsShown() and tab) or waiting then return end
    waiting = true
    C_Timer.After(0, function()
        waiting = false
        Hold()
        Show()
    end)
end

local function Adopt()
    local f = PlayerSpellsFrame
    if not f or adopted or not next(windows) then return end
    adopted = true
    for _, frame in ipairs({ f, f.SpellBookFrame, f.TalentsFrame }) do
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            hooksecurefunc(frame, method, Sync)
        end
    end
    Sync()
end

-- Blizzard's panel manager minimises the frame as it shows whenever another
-- panel counts as open (our parked character or professions frames do), and
-- a minimised frame turns to the book: N opened the book, and only a second
-- N, turning the tab on a frame already shown, maximised it to the talents.
-- Asked for a tab and left on another, turn it as that second N does.
local function Asked(tab)
    local f = PlayerSpellsFrame
    if not tab or not f or not f:IsShown() or f:IsFrameTabActive(tab) then return end
    if InCombatLockdown() and f:IsProtected() then return end
    f:TrySetTab(tab)
end

-- Hooked before the first press: that press loads Blizzard_PlayerSpells
-- inside the very call that would need the hook.
local hooked
local function Hook()
    if hooked or not PlayerSpellsUtil or not PlayerSpellsUtil.TogglePlayerSpellsFrame then return end
    hooked = true
    hooksecurefunc(PlayerSpellsUtil, "TogglePlayerSpellsFrame", Asked)
    hooksecurefunc(PlayerSpellsUtil, "OpenToClassTalentsTab", function()
        Asked(PlayerSpellsUtil.FrameTabs.ClassTalents)
    end)
end

-- A window takes a tab (a PlayerSpellsUtil.FrameTabs key); called at login,
-- after the window is built.
function ns.PlayerSpellsTab(key, w)
    windows[key] = w
    Hook()
    if adopted then
        Sync()
    elseif C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        Adopt()
    end
end

ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_PlayerSpells" then Adopt() end end)
