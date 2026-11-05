-- The character window: Medalluin's own, in the console's ink and gold,
-- standing on the left strip over the chat panel's place, from the screen's
-- edge to its top.
--
--   [  @  ][  @  ][  @  ][  @  ][  @  ][  @  ]               [v] [x]
--   ---------------------------------------------------------------
--   the page
--   ---------------------------------------------------------------
--   the page's details                     <- the chevron folds these
--   ---------------------------------------------------------------
--   (medallion)  the page's band           <- the margin
--
-- The portrait's medallion stands up out of the strip into the window's
-- bottom margin: it is drawn over the window while the window is open (the
-- portrait lifted to the window's strata, the medallion's art copied over
-- it), and the margin's rule runs above it, so it covers nothing. A page
-- may put a row of its own in the margin beside the medallion (the
-- Character page's shortcuts); the others have a divider there.
--
-- Blizzard's window keeps every way in: the keys (C, the reputation and
-- currency keys), the portrait's medallion, ToggleCharacter, Escape. It
-- still opens and closes, and still switches its pages, but under a hidden
-- parent, as the bags window keeps Blizzard's bags (inventory/bags.lua):
-- this window shows while it is open, on the page Blizzard last showed.
-- A tab asks Blizzard for its page in turn, so the next key press knows
-- which page is open; in combat it only turns our page, leaving Blizzard's
-- panel code alone.
--
-- The tabs are icons, the glyph art/strips draws for each page (named by
-- the page's key, or glyph), spread across the row, with the page's name
-- in a tooltip (tip, or the label). The chevron and the cross are glyphs
-- of the same set.
--
-- The pages are our own, drawn from the game's API, one per Blizzard page
-- this client has (Forever has six, retail three):
--
--   ns.CharacterPage{ key, label, tip, glyph, frame (Blizzard's page), order, height,
--                     footHeight, flex, bandUsed, events = { ... },
--                     Build(body, foot, band), Fit(height), Refresh(),
--                     OnEvent(event, ...), Shown(), Showing(on) }
--
-- Build draws into body (the page), foot (its details) and, when the page
-- says bandUsed, the margin beside the medallion; Refresh redraws
-- both, at the next frame after the page shows or one of its events comes,
-- and only while the window is open. OnEvent (optional) hears the event
-- itself first, for what only one event changes; Shown (optional) is told
-- each time the page comes into sight: the window opening on it, or its
-- tab, and Showing (optional) each time the window opens or closes on it or
-- its tab is taken or left. height is the least a fixed page needs, and Fit (optional) is told
-- the height it has, which is the screen's; a page with flex is a list,
-- which takes the same (see Layout).
--
-- Built at login, and only when the Character window option is on.
local _, ns = ...

local L, ART = ns.stripLayout, ns.stripArt
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local WIDTH = L.chatLeft + L.chatWidth          -- from the screen's edge to the chat panel's far edge
local PAD, TAB, RULE = 8, 28, 6                 -- the edge, the tab row, the gap round a rule
local GLYPH, CONTROL = 20, 16                   -- a tab's glyph, the chevron's and the cross's
local TOP = PAD + TAB + RULE                    -- the page's top
local MEDALLION = L.chatLeft                    -- the medallion's width: the strip's art left of the chat
local OVER = ART.height - L.stripHeight         -- how far the medallion stands above the strip
local BAND = OVER + 4                           -- the margin, up to its rule
local BOTTOM = BAND + RULE                      -- the page's (or its details') foot
local LIFT = 20                                 -- the portrait's level over the window's

local pages = {}
ns.character = { pages = pages, width = WIDTH - 2 * PAD, band = { left = MEDALLION + PAD, height = BAND } }

function ns.CharacterPage(page)
    table.insert(pages, page)
end

local window, chevron, close, footRule, medal
local current, dirty
local tabs = {}
local listener = CreateFrame("Frame")

-- ------------------------------------------------------------ buttons
-- As the bags window's: a gold edge, an ink well, a white glow under the
-- mouse; one of a set marked when it is in use.
local function Button(parent, width, click, tip, template)
    local b = CreateFrame("Button", nil, parent, template)
    b:SetSize(width, TAB)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    b.mark = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.mark:SetPoint("TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
    b.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    b.mark:Hide()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.12)
    b.label = ns.Text(b, 12)
    b.label:SetPoint("CENTER")
    if click then b:SetScript("OnClick", click) end
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tip(), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
ns.character.Button = Button

-- ---------------------------------------------------------- decoration
-- A divider: a gold rule each side of a diamond, or of a word.
local function Ornament(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(12)
    local mid
    if label then
        mid = ns.Text(f, 11)
        mid:SetText(label)
        mid:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        mid = f:CreateTexture(nil, "ARTWORK")
        mid:SetSize(6, 6)
        mid:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        mid:SetRotation(math.pi / 4)
    end
    mid:SetPoint("CENTER")
    for _, side in ipairs({ -1, 1 }) do
        local rule = f:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(side < 0 and "LEFT" or "RIGHT")
        rule:SetPoint(side < 0 and "RIGHT" or "LEFT", mid, side < 0 and "LEFT" or "RIGHT", side * 8, 0)
    end
    f.mid = mid
    return f
end
ns.character.Ornament = Ornament

-- Gold brackets in a frame's four corners, inset from its edge.
local function Corners(f, inset, size)
    for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 },
        { "BOTTOMRIGHT", -1, 1 } }) do
        local across = f:CreateTexture(nil, "ARTWORK")
        across:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        across:SetSize(size, 1)
        across:SetPoint(c[1], c[2] * inset, c[3] * inset)
        local down = f:CreateTexture(nil, "ARTWORK")
        down:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        down:SetSize(1, size)
        down:SetPoint(c[1], c[2] * inset, c[3] * inset)
    end
end
ns.character.Corners = Corners

-- ------------------------------------------------------------ medallion
-- The portrait (and the queue's eye, when it sits in its place) lifted to
-- the window's strata while the window is open, under a copy of the
-- medallion's art; put back when it closes. The copy fades with the strip.
local function Lifted()
    local list = { CharacterMicroButton }
    local eye = QueueStatusButton or QueueStatusMinimapButton or MiniMapLFGFrame
    if eye and eye:GetParent() == ns.strips[-1] then table.insert(list, eye) end
    return list
end

local function Lift(on)
    local strip = ns.strips[-1]
    for i, f in ipairs(Lifted()) do
        if not (f:IsProtected() and InCombatLockdown()) then
            if on then
                f:SetFrameStrata(window:GetFrameStrata())
                f:SetFrameLevel(window:GetFrameLevel() + LIFT + i - 1)
            else
                f:SetFrameStrata(strip:GetFrameStrata())
                f:SetFrameLevel(ns.levels.stripWell + i - 1)
            end
        end
    end
end

local function Medal()
    medal = CreateFrame("Frame", nil, window)
    medal:SetFrameLevel(window:GetFrameLevel() + LIFT + 2)
    medal:SetIgnoreParentAlpha(true)
    medal:SetSize(MEDALLION, ART.height)
    medal:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, -L.stripHeight)
    local art = medal:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexture(ns.media .. "strip")
    art:SetTexCoord(0, MEDALLION / ART.texWidth, 0, ART.height / ART.texHeight)
    window.medal = medal
end

-- ------------------------------------------------------------- layout
-- How tall the window is: the screen above the strip.
local function Room()
    local strip = ns.strips[-1]
    local scale = strip:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return UIParent:GetHeight() / scale - L.stripHeight
end

-- What a page's details take, rule and all, with them open.
local function Foot(page, details)
    if not (details and page.footHeight and page.footHeight > 0) then return 0 end
    return page.footHeight + 2 * RULE + 1
end

-- The window runs to the screen's top, on every page, so it keeps its
-- height from tab to tab; a fixed page spreads out over it (Fit), a list
-- fills it. On a screen too short for the tallest fixed page (the
-- Character page), that page runs off the top, and a list gives up height
-- to fit.
local function Layout()
    if not current then return end
    local details = ns.db.characterDetails and true or false
    local least = 0
    for _, p in ipairs(pages) do
        if p.available and not p.flex then least = math.max(least, p.height + Foot(p, details)) end
    end
    local foot = Foot(current, details)
    local room = Room()
    local total = math.max(TOP + least + BOTTOM, room)
    if current.flex then total = math.max(TOP + 80 + foot + BOTTOM, math.min(total, room)) end
    local height = total - TOP - foot - BOTTOM
    current.body:SetHeight(height)
    if current.Fit then current.Fit(height) end
    local shown = foot > 0
    current.foot:SetShown(shown)
    footRule:SetShown(shown)
    if shown then
        footRule:ClearAllPoints()
        footRule:SetPoint("TOPLEFT", PAD, -(TOP + height + RULE))
        footRule:SetPoint("TOPRIGHT", -PAD, -(TOP + height + RULE))
        current.foot:SetHeight(current.footHeight)
    end
    window:SetHeight(total)
    chevron.icon:SetTexture(ns.media .. "strips\\" .. (details and "chevron-down" or "chevron-up"))
    dirty = true            -- a list's rows follow its height
end

-- --------------------------------------------------------------- pages
local function Listen()
    listener:UnregisterAllEvents()
    if not (window:IsShown() and current) then return end
    for _, e in ipairs(current.events or {}) do
        if e:match("^UNIT_") then
            ns.RegisterUnitEvent(listener, e, "player")
        else
            pcall(listener.RegisterEvent, listener, e)
        end
    end
end
listener:SetScript("OnEvent", function(_, event, ...)
    if current.OnEvent then current.OnEvent(event, ...) end
    dirty = true
end)

-- tell each page whether the window is open on it
local function Showing()
    for _, p in ipairs(pages) do
        if p.Showing then p.Showing(window:IsShown() and p == current) end
    end
end

local function Select(page)
    if not page.available then return end
    current = page
    for _, p in ipairs(pages) do
        if p.body then
            p.body:SetShown(p == page)
            p.band:SetShown(p == page)
            if p ~= page then p.foot:Hide() end
        end
        if p.tab then
            p.tab.mark:SetShown(p == page)
            p.tab.icon:SetAlpha(p == page and 1 or 0.6)
        end
    end
    Layout()
    Listen()
    if window:IsShown() and page.Shown then page.Shown() end
    Showing()
    dirty = true
end

local function ByFrame(name)
    for _, p in ipairs(pages) do
        if p.frame == name then return p end
    end
end

-- A tab asks Blizzard for its page (the hook on that page's Show selects
-- ours); in combat, or where Blizzard has no such page, it turns ours alone.
local function Open(page)
    if not InCombatLockdown() and ToggleCharacter and _G[page.frame] then
        ToggleCharacter(page.frame, true)
    end
    if current ~= page then Select(page) end
end

-- ---------------------------------------------------------------- build
-- a control's glyph, centred in its button
local function Glyph(b, name)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(CONTROL, CONTROL)
    b.icon:SetPoint("CENTER")
    if name then b.icon:SetTexture(ns.media .. "strips\\" .. name) end
end

local function Tabs()
    local shown = {}
    for _, p in ipairs(pages) do
        if p.available then table.insert(shown, p) end
    end
    -- the row less the chevron and the cross, shared out; the tabs overlap
    -- a pixel, sharing their edges
    local room = WIDTH - 2 * PAD - 2 * (TAB + 4)
    local w = math.floor((room + #shown - 1) / #shown)
    local prev
    for _, p in ipairs(shown) do
        local b = Button(window, w, function() Open(p) end, function() return p.tip or p.label end)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(GLYPH, GLYPH)
        b.icon:SetPoint("CENTER")
        b.icon:SetTexture(ns.media .. "strips\\" .. (p.glyph or p.key))
        if prev then b:SetPoint("LEFT", prev, "RIGHT", -1, 0) else b:SetPoint("TOPLEFT", PAD, -PAD) end
        p.tab, prev = b, b
        table.insert(tabs, b)
    end
end

local function Build()
    local strip = ns.strips[-1]
    window = CreateFrame("Frame", "MedalluinCharacter", strip)
    -- the strip's scale, so it stands on the strip as the chat panel does,
    -- but not the console's fading
    window:SetIgnoreParentAlpha(true)
    window:SetFrameStrata("MEDIUM")
    window:EnableMouse(true)
    window:SetWidth(WIDTH)
    window:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, L.stripHeight)
    window:Hide()
    local edge = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local bg = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)
    local rule = window:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rule:SetPoint("TOPLEFT", PAD, -(PAD + TAB + RULE / 2))
    rule:SetPoint("TOPRIGHT", -PAD, -(PAD + TAB + RULE / 2))
    rule:SetHeight(1)
    footRule = window:CreateTexture(nil, "ARTWORK")
    footRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    footRule:SetHeight(1)
    -- the margin's edge, over the medallion
    local bandRule = window:CreateTexture(nil, "ARTWORK")
    bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    bandRule:SetHeight(1)
    bandRule:SetPoint("BOTTOMLEFT", PAD, BAND)
    bandRule:SetPoint("BOTTOMRIGHT", -PAD, BAND)
    window.bandRule = bandRule
    Corners(window, 3, 12)
    Medal()

    close = Button(window, TAB, function() HideUIPanel(CharacterFrame) end,
        function() return "Close the character window." end)
    Glyph(close, "close")
    close:SetPoint("TOPRIGHT", -PAD, -PAD)
    chevron = Button(window, TAB, function() ns.SetOption("characterDetails", not ns.db.characterDetails) end,
        function() return ns.db.characterDetails and "Hide the details." or "Show the details." end)
    Glyph(chevron)
    chevron:SetPoint("RIGHT", close, "LEFT", -4, 0)
    window.close, window.chevron = close, chevron

    table.sort(pages, function(a, b) return a.order < b.order end)
    for _, p in ipairs(pages) do
        p.available = _G[p.frame] ~= nil
        if p.available then
            p.body = CreateFrame("Frame", nil, window)
            p.body:SetPoint("TOPLEFT", PAD, -TOP)
            p.body:SetPoint("TOPRIGHT", -PAD, -TOP)
            p.foot = CreateFrame("Frame", nil, window)
            p.foot:SetPoint("BOTTOMLEFT", PAD, BOTTOM)
            p.foot:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
            p.band = CreateFrame("Frame", nil, window)
            p.band:SetPoint("BOTTOMLEFT", MEDALLION + PAD, 0)
            p.band:SetPoint("BOTTOMRIGHT", -PAD, 0)
            p.band:SetHeight(BAND)
            p.body:Hide()
            p.foot:Hide()
            p.band:Hide()
            p.Build(p.body, p.foot, p.band)
            if not p.bandUsed then
                local o = Ornament(p.band)
                o:SetPoint("LEFT", 0, 0)
                o:SetPoint("RIGHT", 0, 0)
            end
        end
    end
    Tabs()

    window:SetScript("OnShow", function()
        Lift(true)
        Layout()
        Listen()
        Showing()
        if current and current.Shown then current.Shown() end
        dirty = true
    end)
    window:SetScript("OnHide", function()
        Lift(false)
        Listen()
        Showing()
    end)
    -- a change is drawn once, at the next frame, and only while it is open
    window:SetScript("OnUpdate", function()
        medal:SetAlpha(strip:GetEffectiveAlpha())
        if dirty and current then
            dirty = false
            current.Refresh()
        end
    end)
    ns.OnSetting("characterDetails", Layout)
    -- the screen's height is the window's
    for _, e in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        ns.On(e, function() if window:IsShown() then Layout() end end)
    end
end

-- ----------------------------------------------- Blizzard's character window
local function Sync()
    local open = CharacterFrame:IsShown()
    if open ~= window:IsShown() then window:SetShown(open) end
end

local function Start()
    if not ns.db.character or not CharacterFrame or not C_Reputation then return end
    Build()
    ns.Park(CharacterFrame)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        hooksecurefunc(CharacterFrame, method, Sync)
    end
    -- Blizzard's page switches (its keys, ToggleCharacter) turn ours
    for _, p in ipairs(pages) do
        local f = p.available and _G[p.frame]
        if f then
            hooksecurefunc(f, "Show", function() Select(p) end)
            if f:IsShown() and not current then Select(p) end
        end
    end
    if not current then Select(ByFrame("PaperDollFrame") or pages[1]) end
    ns.character.window, ns.character.Select, ns.character.listener = window, Select, listener
    Sync()
end

ns.On("PLAYER_LOGIN", Start)
