-- The left-edge tray (mockup T1, 2026-11-11): out of sight until the
-- pointer touches the screen's left edge, then a rail slides out there,
-- where the pointer touched it, as tall as its tabs: its top and bottom angled back to the
-- edge, a gold rule between its sections, a glyph each. A tab opens its
-- window on the left, or closes it when it is open: the open one's tab is
-- lit (its glyph gold, a wash, a gold bar on the edge). Its tooltip names
-- the window and says what a click does.
--
--   |\
--   | \
--   |  |  [@]   Character        (open: lit)
--   |  |------
--   |  |  [!]   Quest tracker
--   | /
--   |/
--
-- The tabs (each its own option, tray<Key>): the character window and the
-- quest tracker by default; the group finder, the chat's log, the Cooldown
-- Manager and Click Casting where the client has them. The tracker's tab
-- hides or shows the tracker, remembered (questsHidden, quests/tracker.lua).
--
-- Nothing takes the world's mouse to find the edge: the pointer is read a
-- few times a second. The rail slides out centred where the pointer touched
-- the edge (2026-11-11), anywhere from the strip up to the screen's top,
-- kept on screen; touched again elsewhere, it moves there. It stays while
-- the pointer is on it, and goes a moment after it leaves. Not while the game menu is open (the docked one
-- stands on that edge), nor while something is held on the cursor. No
-- frame of it is secure: the windows' own toggles do the work, in combat
-- too.
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local W, SEC, CH = 42, 46, 16           -- the rail's width, a tab's height, a chamfer's
local GLYPH = 26
local EDGE = 2                          -- how near the edge the pointer must come
local GAP = 6                           -- the rail's least room from the screen's top and the strip
local POLL, LINGER = 0.05, 0.4          -- how often the pointer is read; how long the rail stays after it
local FADE = 8                          -- the slide and fade, per second

local tray = {}
ns.tray = tray

-- ---------------------------------------------------------------- the tabs
local function Shown(f) return f and f:IsShown() or false end
local function Toggle(f)
    if not f then return end
    if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f) end
end

local TABS = {
    { key = "character", setting = "trayCharacter", glyph = "character", name = "Character",
        Available = function() return ns.db.character and CharacterFrame ~= nil and ToggleCharacter ~= nil end,
        IsOpen = function() return Shown(CharacterFrame) end,
        Toggle = function() ToggleCharacter("PaperDollFrame") end },
    { key = "quests", setting = "trayQuests", glyph = "quests", name = "Quest tracker",
        Available = function() return ns.quests ~= nil end,
        IsOpen = function() return not ns.db.questsHidden end,
        Toggle = function() ns.SetOption("questsHidden", not ns.db.questsHidden) end,
        words = { "Shown. Click: hide it.", "Hidden. Click: show it." } },
    { key = "lfg", setting = "trayLFG", glyph = "lfg", name = "Group finder",
        Available = function() return ns.db.lfgWindow and ns.lfg ~= nil and MedalluinToggleLFG ~= nil end,
        IsOpen = function() return ns.lfg.IsShown() end,
        Toggle = function() MedalluinToggleLFG() end },
    { key = "chatlog", setting = "trayChatLog", glyph = "log", name = "Chat log",
        Available = function() return ns.db.chat and ns.ToggleChatLog ~= nil end,
        IsOpen = function() return ns.ChatLogShown() end,
        Toggle = function() ns.ToggleChatLog() end },
    { key = "cdm", setting = "trayCdm", glyph = "side-timeless", name = "Cooldown Manager",
        Available = function()
            return _G.CooldownViewerSettings ~= nil or C_AddOns ~= nil and C_AddOns.DoesAddOnExist ~= nil
                and C_AddOns.DoesAddOnExist("Blizzard_CooldownViewer")
        end,
        IsOpen = function() return Shown(_G.CooldownViewerSettings) end,
        Toggle = function()
            if not _G.CooldownViewerSettings and C_AddOns and C_AddOns.LoadAddOn then
                pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
            end
            Toggle(_G.CooldownViewerSettings)
        end },
    { key = "cc", setting = "trayCc", glyph = "mouse", name = "Click Casting",
        Available = function() return ToggleClickBindingFrame ~= nil end,
        IsOpen = function() return Shown(_G.ClickBindingFrame) end,
        Toggle = function() ToggleClickBindingFrame() end },
}
tray.tabs = TABS

-- ---------------------------------------------------------------- the rail
local rail, driver
local buttons, rules = {}, {}
local used = {}                         -- the tabs on the rail now, in order

-- A line of the rail's edge, from (x1, y1) to (x2, y2) down from its top
-- left: a 1px texture turned to lie along it.
local function Line(layer, sub, c, a)
    local t = rail:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(c[1], c[2], c[3], a)
    function t.Along(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        t:SetSize(math.sqrt(dx * dx + dy * dy) + 1, 1)
        t:ClearAllPoints()
        t:SetPoint("CENTER", rail, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
        if t.SetRotation then t:SetRotation(-math.atan2(dy, dx)) end
    end
    return t
end

-- The ink: a band down the middle, and the chamfers a row of lines each,
-- each row as wide as the slope has come.
local inkRows = {}
local function Ink(tall)
    local ink = ns.colors.ink
    local n = 0
    local function Row(y, wide)
        n = n + 1
        local t = inkRows[n]
        if not t then
            t = rail:CreateTexture(nil, "BACKGROUND")
            inkRows[n] = t
        end
        t:SetColorTexture(ink[1], ink[2], ink[3], 0.92)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -y)
        t:SetSize(math.max(1, wide), 1)
        t:Show()
    end
    for y = 0, CH - 1 do Row(y, W * (y + 1) / CH) end
    n = n + 1
    local band = inkRows[n] or rail:CreateTexture(nil, "BACKGROUND")
    inkRows[n] = band
    band:SetColorTexture(ink[1], ink[2], ink[3], 0.92)
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", 0, -CH)
    band:SetSize(W, tall - 2 * CH)
    band:Show()
    for y = 0, CH - 1 do Row(tall - 1 - y, W * (y + 1) / CH) end
    for i = n + 1, #inkRows do inkRows[i]:Hide() end
end

local edges
local function Edges(tall)
    if not edges then
        edges = {
            top = Line("BORDER", 1, GOLD, 1), side = Line("BORDER", 1, GOLD, 1), foot = Line("BORDER", 1, GOLD, 1),
            innerTop = Line("BORDER", 0, GOLD_D, 0.55), innerSide = Line("BORDER", 0, GOLD_D, 0.55),
            innerFoot = Line("BORDER", 0, GOLD_D, 0.55),
        }
    end
    edges.top.Along(0, 0, W, CH)
    edges.side.Along(W, CH, W, tall - CH)
    edges.foot.Along(W, tall - CH, 0, tall)
    edges.innerTop.Along(0, 5, W - 4, CH + 3)
    edges.innerSide.Along(W - 4, CH + 3, W - 4, tall - CH - 3)
    edges.innerFoot.Along(W - 4, tall - CH - 3, 0, tall - 5)
end

-- A rule between two tabs, fading out at both ends.
local function Rule(i)
    local r = rules[i]
    if r then return r end
    r = {}
    for side = 1, 2 do
        local t = rail:CreateTexture(nil, "ARTWORK")
        t:SetHeight(1)
        t:SetWidth((W - 10) / 2)
        if t.SetGradient and CreateColor then
            t:SetColorTexture(1, 1, 1, 1)
            local near, far = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.7),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.05)
            if side == 1 then t:SetGradient("HORIZONTAL", far, near) else t:SetGradient("HORIZONTAL", near, far) end
        else
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.4)
        end
        r[side] = t
    end
    rules[i] = r
    return r
end

local function Paint(b)
    local tab, on = b.tab, b.tab and b.tab.IsOpen()
    b.lit = on
    local c = on and GOLD or { 1, 1, 1 }
    b.glyph:SetVertexColor(c[1], c[2], c[3])
    b.glyph:SetAlpha(on and 1 or b:IsMouseOver() and 0.85 or 0.55)
    b.wash:SetShown(on)
    b.bar:SetShown(on)
    if tab and GameTooltip:IsOwned(b) then tray.Tip(b) end
end

function tray.Tip(b)
    local tab = b.tab
    local open = tab.IsOpen()
    local words = tab.words and tab.words[open and 1 or 2] or open and "Open. Click: close it." or "Click: open it."
    ns.Tip(b, "ANCHOR_RIGHT", { title = tab.name, color = GOLD, { "hint", words } })
end

local function Button(i)
    local b = buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, rail)
    b:SetSize(W - 6, SEC - 6)
    b:RegisterForClicks("LeftButtonUp")
    b.wash = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.wash:SetAllPoints()
    b.wash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.10)
    b.bar = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(3)
    b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetSize(GLYPH, GLYPH)
    b.glyph:SetPoint("CENTER", 0, 0)
    b:SetScript("OnClick", function(self)
        self.tab.Toggle()
        Paint(self)
    end)
    b:SetScript("OnEnter", function(self)
        Paint(self)
        tray.Tip(self)
    end)
    b:SetScript("OnLeave", function(self)
        Paint(self)
        GameTooltip:Hide()
    end)
    buttons[i] = b
    return b
end

-- The rail laid out for the tabs whose options are on and whose windows
-- this client has; none, and it never shows.
function tray.Layout()
    if not rail then return end
    wipe(used)
    for _, tab in ipairs(TABS) do
        if ns.db[tab.setting] and tab.Available() then table.insert(used, tab) end
    end
    local tall = 2 * CH - 8 + #used * SEC
    rail:SetSize(W, tall)
    Ink(tall)
    Edges(tall)
    for i, tab in ipairs(used) do
        local b = Button(i)
        b.tab = tab
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, -(CH - 4 + (i - 1) * SEC + 3))
        b.glyph:SetTexture(ns.media .. "strips\\" .. tab.glyph)
        Paint(b)
        b:Show()
    end
    for i = #used + 1, #buttons do buttons[i]:Hide() end
    for i = 1, math.max(#rules, #used - 1) do
        local r = Rule(i)
        local on = i < #used
        for side = 1, 2 do
            local t = r[side]
            t:ClearAllPoints()
            t:SetPoint(side == 1 and "RIGHT" or "LEFT", rail, "TOPLEFT", (W - 4) / 2, -(CH - 4 + i * SEC))
            t:SetShown(on)
        end
    end
    tray.used = used
end

-- ------------------------------------------------------------ the reveal
local out, wanted, since, last = 0, false, 0, 0   -- slid out (0..1), wanted, time since wanted went, poll

local function Blocked()
    return (GameMenuFrame and GameMenuFrame:IsShown()) or (GetCursorInfo and GetCursorInfo() ~= nil) or false
end

-- Whether the pointer asks for the rail: at the edge, beside it, or on it.
local at                                -- the rail's middle, up from the screen's bottom

-- The rail's middle for the pointer at y: there, kept clear of the screen's
-- top and of the left strip (its medallion and the chat under it).
local function Clamp(y)
    local half = rail:GetHeight() / 2
    local strip = ns.strips and ns.strips[-1]
    local floor = math.max(0, strip and strip:GetTop() or 0) + GAP + half
    local ceiling = UIParent:GetHeight() - GAP - half
    return math.max(floor, math.min(ceiling, y))
end

-- Whether the pointer asks for the rail: on it, or at the edge (which
-- brings it to the pointer, where it is not already).
local function Asked()
    if #used == 0 or Blocked() then return false end
    if rail:IsShown() and rail:IsMouseOver() then return true end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    if x > EDGE then return false end
    local half = rail:GetHeight() / 2
    if not (at and out > 0 and y >= at - half and y <= at + half) then at = Clamp(y) end
    return true
end

local function Place()
    rail:ClearAllPoints()
    rail:SetPoint("LEFT", UIParent, "BOTTOMLEFT", out >= 1 and 0 or -W * (1 - out), at or UIParent:GetHeight() / 2)
    rail:SetAlpha(out)
    rail:SetShown(out > 0)
end

local function Tick(_, elapsed)
    last = last + elapsed
    if last >= POLL then
        local was = at
        local asked = Asked()
        if at ~= was then Place() end
        if asked then
            wanted, since = true, 0
        elseif wanted then
            since = since + last
            if since >= LINGER then wanted = false end
        end
        last = 0
        -- the lit tabs follow their windows (Escape, a key)
        if rail:IsShown() then
            for i = 1, #used do
                local b = buttons[i]
                if b.lit ~= b.tab.IsOpen() then Paint(b) end
            end
        end
    end
    local want = wanted and 1 or 0
    if out ~= want then
        local step = elapsed * FADE
        out = want > out and math.min(want, out + step) or math.max(want, out - step)
        Place()
        if out == 0 then GameTooltip:Hide() end
    end
end

local function Start()
    if not ns.db.tray then return end
    rail = CreateFrame("Frame", "MedalluinTray", UIParent)
    rail:SetFrameStrata("HIGH")
    rail:SetClampedToScreen(false)
    rail:EnableMouse(true)
    rail:Hide()
    driver = CreateFrame("Frame", nil, UIParent)
    driver:SetScript("OnUpdate", Tick)
    tray.rail, tray.driver = rail, driver
    tray.Layout()
    Place()
    for _, tab in ipairs(TABS) do ns.OnSetting(tab.setting, tray.Layout) end
    for _, key in ipairs({ "character", "lfgWindow", "chat" }) do ns.OnSetting(key, tray.Layout) end
end

-- at login, after the windows (this file loads after theirs)
ns.On("PLAYER_LOGIN", Start)
