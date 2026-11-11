-- The game menu (Escape), in Medalluin's look: Blizzard's own buttons,
-- moved into a frame of ours and dressed, so every click stays the game's
-- (Log Out, Exit Game, Options run Blizzard's own code, untouched). Two
-- ways to stand (gameMenu):
--
--   docked (the default): a panel down the left edge, as the windows stand
--   (mockup C2c, 2026-11-10: /workspace/gamemenu-mock-C2c.png)
--   +--------------------------------+
--   | (portrait)  Ahrymx             |   who you are: name in class colour,
--   |             Level 24 Gnome Mage|   level, race, class; zone, guild;
--   |             Westfall · <Guild> |   the XP bar short of the last level
--   | [=========-----   ]  62% to 25 |
--   | ---* Game menu *--------  6 v  |   a heading: its word centred between
--   | [o][o][o][o][o][o]             |   rules, a note, a chevron folding it
--   | ---* Medalluin *--------  3 v  |   Blizzard's as icon keys (words in
--   | [* Medalluin][Cooldowns][Cast] |   tooltips), ours apart, worded
--   | ---* Friends *-- 3 online  v   |
--   | (Online) (All) (Battle.net)    |   the people: a status dot, the name
--   |  . Thalen 60       Shattrath   |   in class colour, level, where; under
--   | ---* Guild *------ 12 / 87  v  |   the mouse Whisper and Invite
--   | <Guild>  [message of the day]  |
--   | (Officers) (All) (Ranks)       |   which ranks are listed; Ranks:
--   | [Guild Master] [Officer] [..]  |   a chip each, picked ones lit
--   |  . Aldren 60 Officer  Tanaris  |   (the top ranks, until chosen)
--   | ---* This session *-- 1,284g > |   folded until opened: gold, session,
--   |                                |   latency
--   | ---* Leave *------------------ |
--   | [ v Log Out ] [ x Exit Game ]  |
--   | [      Return to Game        ] |
--   +--------------------------------+
--   The people get the room left above Leave, shared, cut with "and n more".
--
--   medallion: a ring of medallions around your character, at the screen's
--   centre: the menu's buttons an arch over it, two chains of dumbbells
--                 (o)====(o)
--          (o)====/          \====(o)          the arch: 160 to 20 degrees,
--       (o)/                        \(o)       a metal bar from each to the next
--                    (you)
--          (v)\                    /(x)        Log Out, Return to Game, Exit
--              \=====( ^ )=====/               Game: 225, 270, 315 degrees
--
--   The world is not dimmed but a little; no band, no title. "ribbon", its
--   old name, is read as it.
--
-- Shortcuts of ours join them, docked only: a slash command each
-- (Medalluin's options, the game's Cooldown Manager and Click Casting), a
-- section of their own; one nothing answers (the game's not loaded, a
-- client without it) is left out. The Medallion ring is for a controller,
-- and those windows want a mouse: it has none of them.
--
-- While it is open the rest of the interface is gone: UIParent's alpha is
-- nothing, and the frames that keep their own alpha (the strips, the minimap
-- in the corner, the tracker, the windows) follow it again until it closes.
-- Ours alone keeps its own; the world stays. A click outside it lands on it,
-- not on the buttons unseen under it.
--
-- Blizzard's GameMenuFrame stays the panel the game shows and hides
-- (Escape, ShowUIPanel), made see-through and let click through; it builds
-- its buttons again each time it shows (InitButtons, from a pool), and each
-- time they are taken into ours, by what they say. Its sections (a button
-- with topPadding starts one) become ours. "game" leaves it as it is.
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local RED = { 0.86, 0.27, 0.22 }
local BLUE = { 0.47, 0.75, 1 }
local DOCK_W, PAD = 360, 18
local MOTD_TOP = 19             -- the message under its box's label
local CHIP = 20                 -- a rank chip's height (the guild's Ranks pill)
local LEAVE, BACK = 32, 38
local MEDAL, BACK_MEDAL = 48, 58           -- a medallion's size; Return to Game's
local REACH = 0.30                          -- the ring's radius, of the screen's height
local ARCH_FROM, ARCH_TO = 160, 20          -- the arch's ends, in degrees, for six
local ARCH_GROW = 7                         -- each end's step out per medallion past six, to 180 and 0
local LEAVE_AT = { logout = 225, exit = 315 }
local BAR_W = 5                             -- a chain bar's thickness
local ROUND = ns.media .. "strips\\round"
local BAR = ns.media .. "gamemenu-bar"
local KEY_TOP, KEY_FOOT = { 0.341, 0.286, 0.165 }, { 0.141, 0.114, 0.055 }   -- a key's well, as the strips'
local KEY_H, WIDE_H, KEY_GAP = 42, 34, 4    -- the menu's icon keys, the shortcuts' worded ones, apart
local PERSON = 26                           -- a friend's or a guild member's row
local HEAD = 24                             -- a heading's room

local menu = {}
ns.gameMenu = menu

-- Blizzard's buttons by their words: our key, the glyph (media/strips)
local function Kinds()
    return {
        { GAMEMENU_OPTIONS, "options", "menu" }, { BLIZZARD_STORE, "shop", "store" },
        { ADDONS, "addons", "misc" }, { HUD_EDIT_MODE_MENU, "edit", "view-grid" },
        { GAMEMENU_SUPPORT, "support", "help" }, { MACROS, "macros", "log" },
        { LOG_OUT, "logout", "chevron-down" }, { EXIT_GAME, "exit", "close" },
        { GAMEMENU_EXTERNALEVENT, "event", "achievement" }, { GAME_MENU_SHOW_REWARDS, "rewards", "store" },
        { GAMEMENU_NEW_BUTTON, "news", "journal" }, { RATINGS_MENU, "ratings", "statistics" },
    }
end

local function Kind(b, close)
    if b == close then return "return" end
    local text = b:GetText()
    for _, k in ipairs(Kinds()) do
        if k[1] and text == k[1] then return k[2], k[3] end
    end
    return "other", "misc"
end
menu.Kind = Kind

-- the shortcuts (docked): a slash command, its words, its glyph, and the
-- game's function opening it where no command answers
-- (and the few words on its key)
local SHORTCUTS = {
    { "/mui", "Medalluin", "achievement", nil, nil, "Medalluin" },
    { "/cdm", "Cooldown Manager", "legacy", nil, nil, "Cooldowns" },
    { "/cc", "Click Casting", "spellbook", nil, "ToggleClickBindingFrame", "Click Cast" },
}

local holder, docked, ring, shade
local shortcuts = {}            -- our buttons for them, by command
local bars = {}                 -- the chains' bars, pooled
local deco = {}                 -- a button's dress, by button (no field of ours on Blizzard's)
local heads = {}                -- the docked panel's headings, pooled
local who = {}                  -- the docked panel's portrait and lines

local function Style()
    local style = ns.db.gameMenu or "docked"
    if style == "ribbon" then return "medallion" end
    return style
end
menu.Style = Style

-- ------------------------------------------------------------- the dress
local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], a * 0.1))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.55)
    end
end

-- Blizzard's look put away (its slices, its words), ours drawn on the
-- button itself, so the game's highlight layer lights it under the mouse.
local function Dress(b)
    local d = deco[b]
    if d then return d end
    d = {}
    deco[b] = d
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    for _, r in ipairs({ b:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
    local words = b.GetFontString and b:GetFontString()
    if words then words:SetAlpha(0) end
    -- a button's box: a gold edge, an ink well, its fill when it leads
    d.edge = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    d.edge:SetAllPoints()
    d.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.well = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.well:SetPoint("TOPLEFT", 1, -1)
    d.well:SetPoint("BOTTOMRIGHT", -1, 1)
    d.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    -- a key's well, lighter at its top, and the lit lip along it
    d.key = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.key:SetPoint("TOPLEFT", 1, -1)
    d.key:SetPoint("BOTTOMRIGHT", -1, 1)
    if d.key.SetGradient and CreateColor then
        d.key:SetColorTexture(1, 1, 1, 1)
        d.key:SetGradient("VERTICAL", CreateColor(KEY_FOOT[1], KEY_FOOT[2], KEY_FOOT[3], 1),
            CreateColor(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1))
    else
        d.key:SetColorTexture((KEY_TOP[1] + KEY_FOOT[1]) / 2, (KEY_TOP[2] + KEY_FOOT[2]) / 2,
            (KEY_TOP[3] + KEY_FOOT[3]) / 2, 1)
    end
    d.lip = b:CreateTexture(nil, "BACKGROUND", nil, 7)
    d.lip:SetPoint("TOPLEFT", 3, -2)
    d.lip:SetPoint("TOPRIGHT", -3, -2)
    d.lip:SetHeight(1)
    d.lip:SetColorTexture(1, 0.95, 0.78, 0.2)
    -- what is new, on a key: a blue dot at its top right
    d.dot = b:CreateTexture(nil, "OVERLAY")
    d.dot:SetTexture(ROUND)
    d.dot:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 1)
    d.dot:SetSize(7, 7)
    d.dot:SetPoint("CENTER", b, "TOPRIGHT", -7, -7)
    d.fill = b:CreateTexture(nil, "BACKGROUND", nil, 6)
    d.fill:SetPoint("TOPLEFT", 1, -1)
    d.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    d.fill:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    d.glow = b:CreateTexture(nil, "HIGHLIGHT")
    d.glow:SetPoint("TOPLEFT", 1, -1)
    d.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    d.glow:SetColorTexture(1, 1, 1, 0.1)
    -- a row's light under the mouse: a gold wash fading right, a gold edge
    d.wash = b:CreateTexture(nil, "HIGHLIGHT")
    d.wash:SetAllPoints()
    Fade(d.wash, GOLD_D, 0.42)
    d.bar = b:CreateTexture(nil, "HIGHLIGHT")
    d.bar:SetPoint("TOPLEFT")
    d.bar:SetPoint("BOTTOMLEFT")
    d.bar:SetWidth(2)
    d.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    -- a medallion: a gold rim, an ink well; under the mouse it lights itself
    -- (the rim bright, the well lifted), with nothing around it
    d.rim = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    d.rim:SetSize(MEDAL, MEDAL)
    d.rim:SetTexture(ROUND)
    d.rim:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.inner = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.inner:SetSize(MEDAL - 4, MEDAL - 4)
    d.inner:SetTexture(ROUND)
    d.inner:SetVertexColor(0.063, 0.059, 0.055, 1)
    d.core = b:CreateTexture(nil, "BACKGROUND", nil, 6)   -- the leading medallion's gold fill
    d.core:SetTexture(ROUND)
    d.core:SetVertexColor(0.306, 0.251, 0.125, 1)
    -- the glyph, the words, a hint at the end
    d.glyph = b:CreateTexture(nil, "ARTWORK")
    d.label = ns.Text(b, 14)
    d.hint = ns.Text(b, 11)
    local function Hot(hot)
        if d.look == "key" or d.look == "wide" then
            local c = hot and b:IsEnabled() and GOLD or GOLD_D
            d.edge:SetColorTexture(c[1], c[2], c[3], 1)
            return
        end
        if d.look ~= "medal" then return end
        local lit = hot and b:IsEnabled()
        local rim = (lit or d.primary) and GOLD or GOLD_D
        d.rim:SetVertexColor(rim[1], rim[2], rim[3], 1)
        local lift = lit and 0.1 or 0
        d.inner:SetVertexColor(0.063 + lift, 0.059 + lift, 0.055 + lift * 0.6, 1)
        d.glyph:SetAlpha((lit or d.primary) and 1 or b:IsEnabled() and 0.9 or 0.35)
        d.label:SetAlpha(lit and 1 or 0.85)
    end
    d.hot = Hot
    -- a key's words are in its tooltip
    b:HookScript("OnEnter", function()
        Hot(true)
        if d.tip and (d.look == "key" or d.look == "wide") then ns.Tip(b, "ANCHOR_RIGHT", d.tip()) end
    end)
    b:HookScript("OnLeave", function()
        Hot(false)
        if d.tip and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
    end)
    return d
end

-- the hint at a row's end: what is new, how many addons run
local function Hint(kind)
    local f = GameMenuFrame
    if kind == "options" and f.NewOptionsFrame and f.NewOptionsFrame:IsShown() then return "new", BLUE end
    if kind == "edit" and f.EditModeNotification and f.EditModeNotification:IsShown() then return "new", BLUE end
    if kind == "event" and f.NewExternalEventFrame and f.NewExternalEventFrame:IsShown() then return "new", BLUE end
    if kind == "addons" and C_AddOns and C_AddOns.GetNumAddOns then
        local n = 0
        for i = 1, C_AddOns.GetNumAddOns() do
            if C_AddOns.IsAddOnLoaded(i) then n = n + 1 end
        end
        return n .. " loaded", DIM
    end
end

-- One button drawn as a look: "row", "button", "primary", "key" (its glyph
-- alone, its words in its tooltip), "wide" (a key with its glyph and few
-- words) or "medal" (size, and primary: the leading one, gold)
local function Look(b, look, kind, glyph, size, primary)
    local d = Dress(b)
    size = size or MEDAL
    d.primary = look == "medal" and primary or false
    local on = b:IsEnabled()
    local keyed = look == "key" or look == "wide"
    local boxed = look == "button" or look == "primary" or keyed
    d.edge:SetShown(boxed)
    d.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.well:SetShown(boxed and not keyed)
    d.key:SetShown(keyed)
    d.lip:SetShown(keyed)
    d.dot:Hide()
    d.fill:SetShown(look == "primary")
    d.glow:SetShown(boxed)
    d.wash:SetShown(look == "row")
    d.bar:SetShown(look == "row")
    local medal = look == "medal"
    d.rim:SetShown(medal)
    d.inner:SetShown(medal)
    d.core:SetShown(medal and d.primary)
    d.glyph:SetShown(glyph ~= nil)
    if glyph then d.glyph:SetTexture(ns.media .. "strips\\" .. glyph) end
    d.glyph:SetAlpha(on and 0.9 or 0.35)
    d.glyph:ClearAllPoints()
    d.label:ClearAllPoints()
    d.hint:ClearAllPoints()
    d.hint:Hide()
    d.label:SetText(look == "wide" and d.short or d.words or b:GetText() or "")
    d.label:SetShown(look ~= "key")
    local c = not on and DIM or (look == "primary" or d.primary) and GOLD or kind == "exit" and RED
        or ns.colors.text
    d.label:SetTextColor(c[1], c[2], c[3])
    local gc = medal and kind == "exit" and RED or ns.colors.white
    d.glyph:SetVertexColor(gc[1], gc[2], gc[3])
    if look == "key" then
        d.glyph:SetSize(28, 28)
        d.glyph:SetPoint("CENTER")
        d.dot:SetShown(Hint(kind) == "new")
    elseif look == "wide" then
        d.glyph:SetSize(20, 20)
        d.glyph:SetPoint("LEFT", 8, 0)
        d.label:SetPoint("LEFT", 32, 0)
        d.label:SetPoint("RIGHT", -4, 0)
        d.label:SetJustifyH("LEFT")
    elseif look == "row" then
        d.glyph:SetSize(20, 20)
        d.glyph:SetPoint("LEFT", 14, 0)
        d.label:SetPoint("LEFT", 46, 0)
        local hint, hc = Hint(kind)
        if hint then
            d.hint:SetText(hint)
            d.hint:SetTextColor(hc[1], hc[2], hc[3])
            d.hint:SetPoint("RIGHT", -10, 0)
            d.hint:Show()
        end
    elseif medal then
        d.rim:ClearAllPoints()
        d.rim:SetSize(size, size)
        d.rim:SetPoint("CENTER", b, "TOP", 0, -size / 2)
        d.inner:ClearAllPoints()
        d.inner:SetSize(size - 4, size - 4)
        d.inner:SetPoint("CENTER", d.rim)
        d.core:ClearAllPoints()
        d.core:SetSize(size - 4, size - 4)
        d.core:SetPoint("CENTER", d.rim)
        d.glyph:SetSize(size / 2, size / 2)
        d.glyph:SetPoint("CENTER", d.rim)
        d.label:SetPoint("TOP", d.rim, "BOTTOM", 0, -5)
        local hint = Hint(kind)
        if hint == "new" then
            d.hint:SetText("new")
            d.hint:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
            d.hint:SetPoint("LEFT", d.rim, "TOPRIGHT", -4, -2)
            d.hint:Show()
        end
    else
        -- a box: the glyph and the words centred together
        d.label:SetPoint("CENTER", glyph and 11 or 0, 0)
        if glyph then
            d.glyph:SetSize(14, 14)
            d.glyph:SetPoint("RIGHT", d.label, "LEFT", -6, 0)
        end
    end
    d.look = look
    d.label:SetAlpha(1)
    if medal then d.hot(b.IsMouseOver and b:IsMouseOver() or false) end
end
menu.Look = Look

-- ------------------------------------------------------------ the frames
local function Hair(parent, alpha)
    return ns.window.Hair(parent, false, alpha)
end

-- Folded sections (docked), by key, kept; "session" is folded until opened
local function Folded(key)
    local f = ns.db.gameMenuFolded
    local v = nil
    if type(f) == "table" then v = f[key] end
    if v == nil then return key == "session" end
    return v
end
local Relayout                  -- the docked panel laid out again, as last read

local function Fold(key)
    if type(ns.db.gameMenuFolded) ~= "table" then ns.db.gameMenuFolded = {} end
    ns.db.gameMenuFolded[key] = not Folded(key)
    if Relayout then Relayout() end
end
menu.Folded, menu.Fold = Folded, Fold

-- a rule fading toward its outer end: in from the left, or out to the right
local function Rule(t, inward)
    local c = GOLD_D
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        local a, b = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 1)
        if inward then t:SetGradient("HORIZONTAL", a, b) else t:SetGradient("HORIZONTAL", b, a) end
    else
        t:SetColorTexture(c[1], c[2], c[3], 0.6)
    end
end

local function Diamond(h)
    local t = h:CreateTexture(nil, "ARTWORK")
    t:SetSize(5, 5)
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    if t.SetRotation then t:SetRotation(math.pi / 4) end
    return t
end

-- A heading (mockup C2c, 2026-11-10): its word centred in gold between two
-- rules fading out from it, a diamond at each one's inner end; a note at
-- the right (what is in it, or how many), and a chevron there to fold it.
-- The whole heading is the click; one with no key (Leave) folds nothing.
local function Heading(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Button", nil, docked)
    h:SetHeight(18)
    h:RegisterForClicks("LeftButtonUp")
    h:SetScript("OnClick", function(self) if self.key then Fold(self.key) end end)
    h.word = ns.Text(h, 13)
    h.word:SetPoint("CENTER", -8, 0)
    h.word:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    h.chev = h:CreateTexture(nil, "ARTWORK")
    h.chev:SetSize(14, 14)
    h.chev:SetPoint("RIGHT", 0, 0)
    h.chev:SetTexture(ns.media .. "strips\\chevron-down")
    h.note = ns.Text(h, 11)
    h.note:SetTextColor(DIM[1], DIM[2], DIM[3])
    h.left = h:CreateTexture(nil, "ARTWORK")
    h.left:SetHeight(1)
    h.left:SetPoint("LEFT", 4, 0)
    h.left:SetPoint("RIGHT", h.word, "LEFT", -14, 0)
    Rule(h.left, true)
    h.right = h:CreateTexture(nil, "ARTWORK")
    h.right:SetHeight(1)
    h.right:SetPoint("LEFT", h.word, "RIGHT", 14, 0)
    Rule(h.right, false)
    h.dl = Diamond(h)
    h.dl:SetPoint("CENTER", h.word, "LEFT", -9, 0)
    h.dr = Diamond(h)
    h.dr:SetPoint("CENTER", h.word, "RIGHT", 9, 0)
    heads[i] = h
    return h
end

-- a heading set: its word, note and key (nil: it folds nothing); its rule
-- stops short of the note
local function Head(n, y, word, note, key)
    local h = Heading(n)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", docked, "TOPLEFT", PAD, y)
    h:SetPoint("TOPRIGHT", docked, "TOPRIGHT", -PAD, y)
    h.key = key
    h.word:SetText(word)
    h:EnableMouse(key ~= nil)
    h.chev:SetShown(key ~= nil)
    if key and h.chev.SetRotation then h.chev:SetRotation(Folded(key) and math.pi / 2 or 0) end
    h.note:ClearAllPoints()
    h.note:SetPoint("RIGHT", key and h.chev or h, key and "LEFT" or "RIGHT", key and -4 or 0, 0)
    h.note:SetText(note or "")
    h.note:SetShown(note ~= nil)
    h.right:ClearAllPoints()
    h.right:SetPoint("LEFT", h.word, "RIGHT", 14, 0)
    if note then
        h.right:SetPoint("RIGHT", h.note, "LEFT", -8, 0)
    elseif key then
        h.right:SetPoint("RIGHT", h.chev, "LEFT", -6, 0)
    else
        h.right:SetPoint("RIGHT", -4, 0)
    end
    h:Show()
    return h
end

local function Build()
    holder = CreateFrame("Frame", "MedalluinGameMenu", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetFrameLevel(20)
    holder:SetAllPoints(UIParent)
    holder:Hide()
    if holder.SetIgnoreParentAlpha then holder:SetIgnoreParentAlpha(true) end
    holder:EnableMouse(true)
    -- the world dimmed behind it
    shade = holder:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    -- docked: down the whole left edge, ink, a gold edge on its right
    docked = CreateFrame("Frame", nil, holder)
    docked:SetWidth(DOCK_W)
    docked:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    docked:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    docked:EnableMouse(true)
    local well = docked:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetAllPoints()
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.97)
    local edge = docked:CreateTexture(nil, "BACKGROUND", nil, 2)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    who.ring = ns.window.Ring(docked, 56)
    who.ring:SetPoint("TOPLEFT", PAD + 4, -PAD - 4)
    who.name = ns.PlainText(docked, 20)
    who.name:SetPoint("TOPLEFT", PAD + 74, -PAD - 6)
    who.what = ns.PlainText(docked, 12)
    who.what:SetPoint("TOPLEFT", who.name, "BOTTOMLEFT", 0, -6)
    who.what:SetTextColor(DIM[1], DIM[2], DIM[3])
    who.where = ns.PlainText(docked, 12)
    who.where:SetPoint("TOPLEFT", who.what, "BOTTOMLEFT", 0, -4)
    who.where:SetTextColor(DIM[1], DIM[2], DIM[3])
    -- the XP bar under who you are: ink in a gold edge, the XP purple, the
    -- rested past it blue; its words under it
    local xp = CreateFrame("Frame", nil, docked)
    xp:SetPoint("TOPLEFT", PAD, -(PAD + 76))
    xp:SetPoint("TOPRIGHT", -PAD, -(PAD + 76))
    xp:SetHeight(8)
    local e = xp:CreateTexture(nil, "BACKGROUND", nil, 1)
    e:SetAllPoints()
    e:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local ink = xp:CreateTexture(nil, "BACKGROUND", nil, 2)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(0.043, 0.035, 0.024, 1)
    xp.fill = xp:CreateTexture(nil, "ARTWORK", nil, 2)
    xp.fill:SetPoint("TOPLEFT", 1, -1)
    xp.fill:SetPoint("BOTTOMLEFT", 1, 1)
    xp.fill:SetColorTexture(0.55, 0.30, 0.82, 1)
    xp.rest = xp:CreateTexture(nil, "ARTWORK", nil, 1)
    xp.rest:SetPoint("TOPLEFT", xp.fill, "TOPRIGHT")
    xp.rest:SetPoint("BOTTOMLEFT", xp.fill, "BOTTOMRIGHT")
    xp.rest:SetColorTexture(0.23, 0.37, 0.69, 0.55)
    xp.left = ns.PlainText(xp, 11)
    xp.left:SetPoint("TOPLEFT", xp, "BOTTOMLEFT", 0, -4)
    xp.left:SetTextColor(DIM[1], DIM[2], DIM[3])
    xp.right = ns.PlainText(xp, 11)
    xp.right:SetPoint("TOPRIGHT", xp, "BOTTOMRIGHT", 0, -4)
    xp.right:SetTextColor(0.48, 0.61, 0.88)
    who.xp = xp
    local foot = Hair(docked)
    foot:SetPoint("BOTTOMLEFT", PAD, PAD + BACK + 12)
    foot:SetPoint("BOTTOMRIGHT", -PAD, PAD + BACK + 12)
    -- medallion: a point at the screen's centre the ring stands around; the
    -- chains' bars are its, the medallions over them
    ring = CreateFrame("Frame", nil, holder)
    ring:SetSize(1, 1)
    ring:SetPoint("CENTER", UIParent, "CENTER")
    menu.holder, menu.docked, menu.ring, menu.bars = holder, docked, ring, bars
end

-- who you are, at the docked panel's top
local function Who()
    if SetPortraitTexture then
        SetPortraitTexture(who.ring, "player")
        who.ring:SetTexCoord(0, 1, 0, 1)
    end
    local name = UnitName("player") or ""
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    who.name:SetText(name)
    if c then who.name:SetTextColor(c.r, c.g, c.b) else who.name:SetTextColor(unpack(ns.colors.text)) end
    local race = UnitRace and UnitRace("player") or ""
    local className = UnitClass("player") or ""
    who.what:SetText("Level " .. (UnitLevel("player") or 0) .. "  " .. race .. "  " .. className)
    local guild = GetGuildInfo and GetGuildInfo("player")
    local zone = GetZoneText and GetZoneText() or ""
    who.where:SetText(zone .. (guild and ("  \194\183  <" .. guild .. ">") or ""))
    -- the XP bar, short of the last level
    local xp, level = who.xp, UnitLevel("player") or 0
    local top = GetMaxPlayerLevel and GetMaxPlayerLevel() or 0
    local cur, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
    local on = level < top and max > 0
    xp:SetShown(on)
    if on then
        local w = math.max(1, (xp:GetWidth() or (DOCK_W - 2 * PAD)) - 2)
        local rest = math.min(GetXPExhaustion and GetXPExhaustion() or 0, max - cur)
        xp.fill:SetWidth(math.max(0.01, w * cur / max))
        xp.rest:SetWidth(math.max(0.01, w * rest / max))
        xp.rest:SetShown(rest > 0)
        xp.left:SetText(format("%d%% to %d", math.floor(cur / max * 100), level + 1))
        xp.right:SetText(rest > 0 and format("rested %d%%", math.floor(rest / max * 100)) or "")
    end
    return on
end

-- Blizzard's buttons, read as it lays them: sections (topPadding starts
-- one), and each button's kind
local function Read()
    local f = GameMenuFrame
    local close = f.closeButton
    local sections, leave, back = {}, {}, nil
    local cur
    for _, b in ipairs(f.buttons or {}) do
        local kind, glyph = Kind(b, close)
        if kind == "return" then
            back = b
        elseif kind == "logout" or kind == "exit" then
            table.insert(leave, { b = b, kind = kind, glyph = glyph })
        else
            if not cur or b.topPadding then
                cur = {}
                table.insert(sections, cur)
            end
            table.insert(cur, { b = b, kind = kind, glyph = glyph })
        end
    end
    return sections, leave, back
end
menu.Read = Read

-- What a slash command runs: the chat box's own table of them first (the
-- game's commands it has met), then the handler whose SLASH_ names it; nil
-- when nothing answers it
local function Handler(cmd)
    local hash = _G.hash_SlashCmdList
    if type(hash) == "table" and type(hash[cmd:upper()]) == "function" then return hash[cmd:upper()] end
    if type(SlashCmdList) ~= "table" then return nil end
    cmd = cmd:lower()
    for key, fn in pairs(SlashCmdList) do
        local i = 1
        while true do
            local name = _G["SLASH_" .. key .. i]
            if type(name) ~= "string" then break end
            if name:lower() == cmd then return fn end
            i = i + 1
        end
    end
end
menu.Handler = Handler

-- What a shortcut runs: its command's handler, else the game's function
local function Runs(sc)
    local fn = Handler(sc[1])
    if fn then return function() fn("") end end
    local game = sc[5] and _G[sc[5]]
    if type(game) == "function" then return game end
end

-- Our shortcut buttons (docked), those something answers: the menu closes, then the
-- command runs as if typed. They hold no words of their own (a button's
-- own would show in the game's yellow under the mouse): ours, in the dress.
local function Shortcuts(wanted)
    local out = {}
    for _, sc in ipairs(SHORTCUTS) do
        local cmd = sc[1]
        local b = shortcuts[cmd]
        if wanted and Runs(sc) then
            if not b then
                b = CreateFrame("Button", nil, holder)
                b:RegisterForClicks("LeftButtonUp")
                b:SetScript("OnClick", function()
                    local run = Runs(sc)
                    HideUIPanel(GameMenuFrame)
                    if run then run() end
                end)
                shortcuts[cmd] = b
            end
            local d = Dress(b)
            d.words, d.short, d.cmd = sc[2], sc[6], cmd
            d.tip = function() return { title = sc[2], { "hint", cmd } } end
            b:Show()
            table.insert(out, { b = b, kind = "shortcut", glyph = sc[3], hint = cmd })
        elseif b then
            b:Hide()
        end
    end
    return out
end
menu.Shortcuts = Shortcuts
function menu.Words(b) return deco[b] and (deco[b].words or deco[b].label:GetText()) end
function menu.Command(b) return deco[b] and deco[b].cmd end

local function Take(b, parent)
    b:SetParent(parent)
    b:ClearAllPoints()
end

-- ------------------------------------------------------------ the people
-- Friends and the guild (docked, mockup C2c): a row each, a status dot,
-- the name in its class's colour, the level (and rank), where they are;
-- under the mouse, Whisper and Invite in where's place. A click whispers.
local rows = {}                 -- pooled people rows
local pills = {}                -- the friends' filter, pooled
local cards = {}                -- the session's cards, pooled
local social = {}               -- the guild's name and its message box
local STATUS = { online = { 0.25, 0.75, 0.31 }, afk = { 0.88, 0.69, 0.19 }, dnd = { 0.82, 0.25, 0.19 },
    offline = { 0.45, 0.43, 0.40 } }
local GUILD_GREEN = { 0.25, 1, 0.25 }
local started = GetTime and GetTime() or 0

-- a class's token from its name in the game's words (friends give the words)
local function ClassFile(name)
    if not name then return nil end
    for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for file, words in pairs(list) do
            if words == name then return file end
        end
    end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[name] and name or nil
end

local function Whisper(p)
    HideUIPanel(GameMenuFrame)
    if p.bnet and ChatFrame_SendBNetTell then ChatFrame_SendBNetTell(p.bnet)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(p.name) end
end

local function Invite(p)
    if not p.invite then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(p.invite)
    elseif InviteUnit then InviteUnit(p.invite) end
end

-- a small key on a row: its glyph, a tooltip, the click
local function SmallKey(row, glyph, words, run)
    local k = CreateFrame("Button", nil, row)
    k:SetSize(26, 20)
    k:RegisterForClicks("LeftButtonUp")
    local d = Dress(k)
    Look(k, "key", "other", glyph)
    d.glyph:SetSize(18, 18)
    d.tip = function() return { title = words } end
    k:SetScript("OnClick", function() if row.person then run(row.person) end end)
    k:HookScript("OnLeave", function() if not row:IsMouseOver() then row.Lit(false) end end)
    return k
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, docked)
    r:SetHeight(PERSON)
    r:RegisterForClicks("LeftButtonUp")
    r.wash = r:CreateTexture(nil, "BACKGROUND")
    r.wash:SetAllPoints()
    Fade(r.wash, GOLD_D, 0.3)
    r.wash:Hide()
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetTexture(ROUND)
    r.dot:SetSize(8, 8)
    r.dot:SetPoint("LEFT", 8, 0)
    r.nick = ns.PlainText(r, 13)
    r.nick:SetPoint("LEFT", 22, 0)
    r.lvl = ns.PlainText(r, 11)
    r.lvl:SetPoint("LEFT", r.nick, "RIGHT", 6, 0)
    r.lvl:SetTextColor(DIM[1], DIM[2], DIM[3])
    r.where = ns.PlainText(r, 11)
    r.where:SetPoint("RIGHT", -8, 0)
    r.where:SetPoint("LEFT", r.lvl, "RIGHT", 8, 0)
    r.where:SetJustifyH("RIGHT")
    r.where:SetTextColor(DIM[1], DIM[2], DIM[3])
    r.where:SetWordWrap(false)
    r.invite = SmallKey(r, "character", "Invite", Invite)
    r.invite:SetPoint("RIGHT", -4, 0)
    r.whisper = SmallKey(r, "chat", "Whisper", Whisper)
    r.whisper:SetPoint("RIGHT", r.invite, "LEFT", -3, 0)
    function r.Lit(on)
        r.wash:SetShown(on)
        r.where:SetShown(not on)
        r.whisper:SetShown(on)
        r.invite:SetShown(on and r.person and r.person.invite ~= nil)
    end
    r:SetScript("OnEnter", function() r.Lit(true) end)
    r:SetScript("OnLeave", function()
        if not (r.whisper:IsMouseOver() or r.invite:IsMouseOver()) then r.Lit(false) end
    end)
    r:SetScript("OnClick", function() if r.person and not r.person.more then Whisper(r.person) end end)
    r.Lit(false)
    rows[i] = r
    return r
end

-- a row set to a person, or to "and n more"
local function Person(i, y, p)
    local r = Row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", PAD - 4, y)
    r:SetPoint("TOPRIGHT", -PAD + 4, y)
    r.person = p
    r.Lit(false)
    if p.more then
        r.dot:Hide()
        r.nick:SetText(p.more)
        r.nick:SetTextColor(DIM[1], DIM[2], DIM[3])
        r.lvl:SetText("")
        r.where:SetText("")
        r:EnableMouse(false)
    else
        local c = STATUS[p.status] or STATUS.online
        r.dot:SetVertexColor(c[1], c[2], c[3], 1)
        r.dot:Show()
        r.nick:SetText(p.name)
        local cc = p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
        if p.status == "offline" then r.nick:SetTextColor(DIM[1], DIM[2], DIM[3])
        elseif cc then r.nick:SetTextColor(cc.r, cc.g, cc.b)
        else r.nick:SetTextColor(unpack(ns.colors.text)) end
        r.lvl:SetText((p.level and p.level > 0 and p.level or "") .. (p.rank and ("  " .. p.rank) or ""))
        r.where:SetText(p.where or "")
        r:EnableMouse(true)
    end
    r:Show()
    return r
end

local function Clean(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

-- the friends, by the filter: "online" (in WoW, online), "all", or "bnet"
local function Friends(filter)
    local out, online = {}, 0
    if filter == "bnet" then
        if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return out, 0 end
        for i = 1, BNGetNumFriends() or 0 do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            local g = a and a.gameAccountInfo
            if g and g.isOnline then
                online = online + 1
                local wow = g.clientProgram == (BNET_CLIENT_WOW or "WoW")
                table.insert(out, { name = Clean(wow and g.characterName) or Clean(a.accountName) or "?",
                    class = ClassFile(Clean(g.className)), level = Clean(g.characterLevel),
                    where = Clean(wow and g.areaName) or Clean(g.richPresence) or "",
                    status = a.isAFK and "afk" or a.isDND and "dnd" or "online",
                    bnet = Clean(a.accountName), invite = wow and Clean(g.characterName) or nil })
            end
        end
        return out, online
    end
    if not (C_FriendList and C_FriendList.GetNumFriends) then return out, 0 end
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local f = C_FriendList.GetFriendInfoByIndex(i)
        local name = f and Clean(f.name)
        if name then
            if f.connected then online = online + 1 end
            if f.connected or filter == "all" then
                table.insert(out, { name = name, class = ClassFile(Clean(f.className)), level = Clean(f.level),
                    where = f.connected and Clean(f.area) or "offline",
                    status = not f.connected and "offline" or f.afk and "afk" or f.dnd and "dnd" or "online",
                    invite = f.connected and name or nil })
            end
        end
    end
    -- online first
    table.sort(out, function(a, b)
        if (a.status == "offline") ~= (b.status == "offline") then return b.status == "offline" end
        return a.name < b.name
    end)
    return out, online
end
menu.Friends = Friends

-- the guild's online members, but you; and how many it has
-- Which of the guild are listed (2026-11-11), by ns.db.gameMenuGuild:
-- "officers", its top ranks (the leader, rank 0, the rank under it, and
-- any rank named an officer's); "all"; or "ranks", those picked by name in
-- ns.db.gameMenuGuildRanks (by name: a rank's index moves when ranks are
-- added), the top ranks until any is picked. The rest are counted, not
-- listed.
local function Top(rank, index)
    if type(index) == "number" and index <= 1 then return true end
    return type(rank) == "string" and rank:lower():find("officer", 1, true) ~= nil
end

local function Picked(rank, index)
    local picked = ns.db.gameMenuGuildRanks
    if type(picked) ~= "table" then return Top(rank, index) end
    return picked[rank] == true
end

local function Wanted(mode, rank, index)
    if mode == "all" then return true end
    if mode == "ranks" then return Picked(rank, index) end
    return Top(rank, index)
end

-- the members listed, the roster's size, how many are online, and the
-- guild's ranks ({ index, name }, in order) as the roster names them
local function Guild(mode)
    local out, total, on = {}, GetNumGuildMembers and GetNumGuildMembers() or 0, 0
    local me = UnitName("player")
    local seen, ranks = {}, {}
    for i = 1, total do
        local name, rank, index, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
        name, rank, index = Clean(name), Clean(rank), Clean(index)
        if type(rank) == "string" and not seen[rank] then
            seen[rank] = true
            table.insert(ranks, { index = type(index) == "number" and index or 99, name = rank })
        end
        local short = name and (Ambiguate and Ambiguate(name, "guild") or name:match("^[^-]+"))
        if online then on = on + 1 end
        if short and online and short ~= me and Wanted(mode, rank, index) then
            table.insert(out, { name = short, rank = Clean(rank), level = Clean(level), where = Clean(zone) or "",
                class = Clean(class),
                status = (status == 1 or status == "<AFK>") and "afk" or (status == 2 or status == "<DND>") and "dnd"
                    or "online", invite = name })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    table.sort(ranks, function(a, b) return a.index < b.index end)
    return out, total, on, ranks
end
menu.Guild = Guild

-- A rank chip toggled: the picks begin from what was shown (the top ranks)
local function Pick(rank, ranks)
    local picked = ns.db.gameMenuGuildRanks
    if type(picked) ~= "table" then
        picked = {}
        for _, r in ipairs(ranks) do
            if Top(r.name, r.index) then picked[r.name] = true end
        end
        ns.db.gameMenuGuildRanks = picked
    end
    picked[rank.name] = not picked[rank.name] or nil
end

local function Money(m)
    local g, sv = math.floor(m / 10000), math.floor(m / 100) % 100
    local gs = BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)
    return format("%sg %ds", gs, sv)
end

local function Since()
    local t = math.floor((GetTime and GetTime() or 0) - started)
    local h, m = math.floor(t / 3600), math.floor(t / 60) % 60
    return h > 0 and format("%dh %dm", h, m) or format("%dm", m)
end

local function Latency()
    if not GetNetStats then return "?" end
    local _, _, home = GetNetStats()
    return format("%d ms", home or 0)
end

local function Pill(i)
    local p = pills[i]
    if p then return p end
    p = CreateFrame("Button", nil, docked)
    p:SetSize(96, 20)
    p:RegisterForClicks("LeftButtonUp")
    p.edge = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.edge:SetAllPoints()
    p.fill = p:CreateTexture(nil, "BACKGROUND", nil, 2)
    p.fill:SetPoint("TOPLEFT", 1, -1)
    p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    p.word = ns.Text(p, 11)
    p.word:SetPoint("CENTER")
    p:SetScript("OnClick", function(self)
        self.choose(self)
        if Relayout then Relayout() end
    end)
    pills[i] = p
    return p
end

local function Card(i)
    local c = cards[i]
    if c then return c end
    c = CreateFrame("Frame", nil, docked)
    c:SetHeight(42)
    local e = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    e:SetAllPoints()
    e:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    local ink = c:CreateTexture(nil, "BACKGROUND", nil, 2)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(0.051, 0.043, 0.027, 0.9)
    c.label = ns.Text(c, 10)
    c.label:SetPoint("TOPLEFT", 8, -6)
    c.label:SetTextColor(DIM[1], DIM[2], DIM[3])
    c.value = ns.PlainText(c, 13)
    c.value:SetPoint("BOTTOMLEFT", 8, 6)
    cards[i] = c
    return c
end

local function Social()
    if social.name then return social end
    social.name = ns.PlainText(docked, 15)
    social.name:SetTextColor(GUILD_GREEN[1], GUILD_GREEN[2], GUILD_GREEN[3])
    local box = CreateFrame("Frame", nil, docked)
    box:SetHeight(36)
    local ink = box:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(0.051, 0.043, 0.027, 0.75)
    local bar = box:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(2)
    bar:SetColorTexture(GUILD_GREEN[1], GUILD_GREEN[2], GUILD_GREEN[3], 0.7)
    box.label = ns.Text(box, 9)
    box.label:SetPoint("TOPLEFT", 10, -5)
    box.label:SetTextColor(DIM[1], DIM[2], DIM[3])
    box.label:SetText("Message of the day")
    -- the message wrapped, as many lines as it takes (a guild's message is
    -- at most 128 characters): its width set, so its height is known
    box.text = ns.PlainText(box, 11)
    box.text:SetPoint("TOPLEFT", 10, -MOTD_TOP)
    box.text:SetWidth(DOCK_W - 2 * PAD - 18)
    box.text:SetJustifyH("LEFT")
    box.text:SetJustifyV("TOP")
    box.text:SetWordWrap(true)
    social.motd = box
    return social
end

-- The message of the day's box, fitted to it; its height.
local function Motd(motd)
    local box = Social().motd
    box.text:SetText(motd)
    local tall = MOTD_TOP + math.ceil(box.text:GetStringHeight()) + 6
    box:SetHeight(tall)
    return tall
end

local last                      -- the docked panel's last reading: sections, leave, back
-- The guild's message of the day, as GUILD_MOTD last brought it (at login,
-- and when it changes): GetGuildRosterMOTD from here is a blocked action in
-- game (ADDON_ACTION_BLOCKED, 2026-11-11)
local guildMotd

local function Docked(sections, leave, back)
    last = { sections, leave, back }
    local hasXP = Who()
    local w = DOCK_W - 2 * PAD
    local y = -(PAD + (hasXP and 110 or 84))
    local n = 0
    -- Blizzard's buttons, and our shortcuts, apart
    local items, ours = {}, {}
    for _, section in ipairs(sections) do
        for _, it in ipairs(section) do table.insert(it.kind == "shortcut" and ours or items, it) end
    end
    local function Keys(list, look, per, tall)
        local rowsOf = math.ceil(#list / per)
        local kw = (w - (per - 1) * KEY_GAP) / per
        for i, it in ipairs(list) do
            local col, line = (i - 1) % per, math.floor((i - 1) / per)
            Take(it.b, docked)
            it.b:SetPoint("TOPLEFT", PAD + col * (kw + KEY_GAP), y - line * (tall + KEY_GAP))
            it.b:SetSize(kw, tall)
            local d = Dress(it.b)
            if not d.tip then
                local kind = it.kind
                d.tip = function()
                    local hint = Hint(kind)
                    return { title = d.label:GetText() or "", hint and { "hint", hint } or false }
                end
            end
            Look(it.b, look, it.kind, it.glyph)
        end
        return rowsOf * (tall + KEY_GAP) - KEY_GAP
    end
    local function Hide(list) for _, it in ipairs(list) do it.b:Hide() end end
    -- the game's menu
    n = n + 1
    Head(n, y, "Game menu", tostring(#items), "menu")
    y = y - HEAD
    if Folded("menu") then Hide(items) else
        for _, it in ipairs(items) do it.b:Show() end
        y = y - Keys(items, "key", 6, KEY_H) - 14
    end
    -- Medalluin's shortcuts
    if #ours > 0 then
        n = n + 1
        Head(n, y, "Medalluin", tostring(#ours), "shortcuts")
        y = y - HEAD
        if Folded("shortcuts") then Hide(ours) else
            for _, it in ipairs(ours) do it.b:Show() end
            y = y - Keys(ours, "wide", 3, WIDE_H) - 14
        end
    end

    -- the foot: Leave, then Return to Game
    local leaveTop = PAD + BACK + 24 + LEAVE + 8 + HEAD     -- from the bottom
    local tall = docked:GetHeight() or 0
    if tall <= 0 then tall = UIParent:GetHeight() or 768 end
    local floor = -(tall - leaveTop)                       -- the people stop here
    -- what the rest needs: the session and the guild's head
    local filter = ns.db.gameMenuFriends or "online"
    if filter == "bnet" and not BNGetNumFriends then filter = "online" end
    local friends, online = Friends(filter)
    local inGuild = (not IsInGuild or IsInGuild()) and GetGuildInfo and GetGuildInfo("player")
    local guildMode = ns.db.gameMenuGuild or "officers"
    local members, total, guildOn, ranks = {}, 0, 0, {}
    if inGuild then members, total, guildOn, ranks = Guild(guildMode) end
    local chipRows = guildMode == "ranks" and math.ceil(#ranks / 3) or 0
    local motd = inGuild and guildMotd or nil
    if motd == "" then motd = nil end
    local sessionTall = HEAD + (Folded("session") and 0 or 50)
    local friendsFixed = HEAD + (Folded("friends") and 0 or 28)
    local motdTall = motd and Motd(motd) or 0
    local guildFixed = inGuild and HEAD + (Folded("guild") and 0
        or (22 + (motd and motdTall + 6 or 0) + 28 + chipRows * (CHIP + 4))) or 0
    local room = math.floor((y - floor - sessionTall - friendsFixed - guildFixed - 14 * 3) / PERSON)
    local wantF = Folded("friends") and 0 or #friends
    local wantG = (inGuild and not Folded("guild")) and #members or 0
    local giveF, giveG = wantF, wantG
    if wantF + wantG > room then
        local half = math.floor(room / 2)
        giveF = math.min(wantF, math.max(half, room - wantG))
        giveG = math.max(0, math.min(wantG, room - giveF))
    end
    local used = 0
    local function People(list, give)
        local shown = #list > give and math.max(0, give - 1) or #list
        for i = 1, shown do
            used = used + 1
            Person(used, y, list[i])
            y = y - PERSON
        end
        if #list > shown and give > 0 then
            used = used + 1
            Person(used, y, { more = format("and %d more", #list - shown) })
            y = y - PERSON
        end
    end

    -- the filter pills (friends', the guild's) and the rank chips: pooled,
    -- the next one at x, y, wide by high
    local np = 0
    local function Choice(x, wide, high, word, on, choose)
        np = np + 1
        local p = Pill(np)
        p:SetSize(wide, high)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", x, y)
        local e = on and GOLD or GOLD_D
        p.edge:SetColorTexture(e[1], e[2], e[3], 1)
        p.fill:SetColorTexture(on and 0.23 or 0.051, on and 0.18 or 0.043, on and 0.08 or 0.027, 1)
        p.word:SetText(word)
        p.word:SetTextColor(unpack(on and ns.colors.text or DIM))
        p.choose = choose
        p:Show()
        return p
    end
    local function Pills(kinds, current, save)
        for i, k in ipairs(kinds) do
            local p = Choice(PAD + (i - 1) * 102, 96, 20, k[2], current == k[1], function(self) save(self.filter) end)
            p.filter, p.rank = k[1], nil
        end
        y = y - 28
    end

    -- friends
    n = n + 1
    Head(n, y, "Friends", format("%d online", online), "friends")
    y = y - HEAD
    if not Folded("friends") then
        local kinds = { { "online", "Online" }, { "all", "All" } }
        if BNGetNumFriends then table.insert(kinds, { "bnet", "Battle.net" }) end
        Pills(kinds, filter, function(f) ns.db.gameMenuFriends = f end)
        People(friends, giveF)
        y = y - 14
    end

    -- the guild
    local soc = Social()
    soc.name:Hide()
    soc.motd:Hide()
    if inGuild then
        n = n + 1
        Head(n, y, "Guild", format("%d / %d", guildOn, total), "guild")
        y = y - HEAD
        if not Folded("guild") then
            soc.name:ClearAllPoints()
            soc.name:SetPoint("TOPLEFT", PAD, y)
            soc.name:SetText("<" .. inGuild .. ">")
            soc.name:Show()
            y = y - 22
            if motd then
                soc.motd:ClearAllPoints()
                soc.motd:SetPoint("TOPLEFT", PAD, y)
                soc.motd:SetPoint("TOPRIGHT", -PAD, y)
                soc.motd:Show()
                y = y - motdTall - 6
            end
            Pills({ { "officers", "Officers" }, { "all", "All" }, { "ranks", "Ranks" } }, guildMode,
                function(f) ns.db.gameMenuGuild = f end)
            -- picking ranks: a chip each, three to a row, lit when listed
            if guildMode == "ranks" then
                local chip = math.floor((DOCK_W - 2 * PAD - 2 * 6) / 3)
                for i, r in ipairs(ranks) do
                    local col = (i - 1) % 3
                    local p = Choice(PAD + col * (chip + 6), chip, CHIP, r.name, Picked(r.name, r.index),
                        function() Pick(r, ranks) end)
                    p.filter = nil
                    p.rank = r.name
                    if col == 2 or i == #ranks then y = y - CHIP - 4 end
                end
            end
            People(members, giveG)
            y = y - 14
        end
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    for i = np + 1, #pills do pills[i]:Hide() end

    -- this session
    n = n + 1
    local money = GetMoney and GetMoney() or 0
    Head(n, y, "This session", Folded("session") and (Money(money) .. "  \194\183  " .. Since()) or nil, "session")
    y = y - HEAD
    local nc = 0
    if not Folded("session") then
        local list = { { "Gold", Money(money), GOLD }, { "Session", Since() }, { "Latency", Latency() } }
        local cw = (w - 2 * 8) / 3
        for i, it in ipairs(list) do
            local c = Card(i)
            nc = i
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", PAD + (i - 1) * (cw + 8), y)
            c:SetWidth(cw)
            c.label:SetText(it[1])
            c.value:SetText(it[2])
            c.value:SetTextColor(unpack(it[3] or ns.colors.text))
            c:Show()
        end
        y = y - 50
    end
    for i = nc + 1, #cards do cards[i]:Hide() end

    -- Leave, at the foot
    if #leave > 0 then
        n = n + 1
        local h = Head(n, 0, "Leave")
        h:ClearAllPoints()
        h:SetPoint("BOTTOMLEFT", docked, "BOTTOMLEFT", PAD, PAD + BACK + 24 + LEAVE + 8)
        h:SetPoint("BOTTOMRIGHT", docked, "BOTTOMRIGHT", -PAD, PAD + BACK + 24 + LEAVE + 8)
        local bw = math.floor((w - 10 * (#leave - 1)) / #leave)
        for i, it in ipairs(leave) do
            Take(it.b, docked)
            it.b:SetPoint("BOTTOMLEFT", PAD + (i - 1) * (bw + 10), PAD + BACK + 24)
            it.b:SetSize(bw, LEAVE)
            Look(it.b, "button", it.kind, it.glyph)
        end
    end
    for i = n + 1, #heads do heads[i]:Hide() end
    if back then
        Take(back, docked)
        back:SetPoint("BOTTOMLEFT", PAD, PAD)
        back:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        back:SetHeight(BACK)
        Look(back, "primary", "return")
    end
    -- the world to its right, dimmed a little, fading
    shade:ClearAllPoints()
    shade:SetPoint("TOPLEFT", docked, "TOPRIGHT")
    shade:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    Fade(shade, { 0, 0, 0 }, 0.5)
end

Relayout = function()
    if last and holder and holder:IsShown() and Style() == "docked" then Docked(last[1], last[2], last[3]) end
end
menu.Relayout = Relayout

-- a chain's bar from one medallion's centre to the next's: stretched to the
-- distance, turned to the angle between them
local function Bar(n, x1, y1, x2, y2)
    local t = bars[n]
    if not t then
        t = ring:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(BAR)
        bars[n] = t
    end
    local dx, dy = x2 - x1, y2 - y1
    t:SetSize(math.sqrt(dx * dx + dy * dy), BAR_W * 2)      -- the art's bar is its middle half
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", (x1 + x2) / 2, (y1 + y2) / 2)
    if t.SetRotation then t:SetRotation(math.atan2(dy, dx)) end
    t:Show()
    return t
end

-- a medallion's centre on the ring, at a angle (degrees, counter-clockwise from the right)
local function At(r, deg)
    local a = math.rad(deg)
    return r * math.cos(a), r * math.sin(a)
end

local function Place(b, x, y, size)
    b:SetSize(math.max(size + 40, 96), size + 24)
    b:SetPoint("TOP", ring, "CENTER", x, y + size / 2)
end

local function Medallion(sections, leave, back)
    local r = REACH * (UIParent:GetHeight() or 768)
    local items = {}
    for _, section in ipairs(sections) do
        for _, it in ipairs(section) do table.insert(items, it) end
    end
    local n, used = #items, 0
    local grow = math.min(math.max(n - 6, 0) * ARCH_GROW, 180 - ARCH_FROM)
    local from, to = ARCH_FROM + grow, ARCH_TO - grow
    -- the arch, evenly from end to end; a chain bar from each to the next
    local px, py
    for i, it in ipairs(items) do
        local deg = n > 1 and from + (to - from) * (i - 1) / (n - 1) or 90
        local x, y = At(r, deg)
        Take(it.b, ring)
        Place(it.b, x, y, MEDAL)
        Look(it.b, "medal", it.kind, it.glyph)
        if px then
            used = used + 1
            Bar(used, px, py, x, y)
        end
        px, py = x, y
    end
    -- below: Log Out, Return to Game, Exit Game, chained the same
    local low = {}
    for _, it in ipairs(leave) do
        if it.kind == "logout" then table.insert(low, 1, it) end
    end
    if back then table.insert(low, { b = back, kind = "return", glyph = "chevron-up", primary = true }) end
    for _, it in ipairs(leave) do
        if it.kind ~= "logout" then table.insert(low, it) end
    end
    px, py = nil, nil
    for _, it in ipairs(low) do
        local deg = it.primary and 270 or LEAVE_AT[it.kind] or 270
        local x, y = At(r, deg)
        local size = it.primary and BACK_MEDAL or MEDAL
        Take(it.b, ring)
        Place(it.b, x, y, size)
        Look(it.b, "medal", it.kind, it.glyph, size, it.primary)
        if px then
            used = used + 1
            Bar(used, px, py, x, y)
        end
        px, py = x, y
    end
    for i = used + 1, #bars do bars[i]:Hide() end
    shade:ClearAllPoints()
    shade:SetAllPoints(UIParent)
    shade:SetColorTexture(0, 0, 0, 0.2)
end

-- Taken in: after each InitButtons (as it shows, as the store's state
-- changes), Blizzard's buttons are moved into ours and dressed.
local function Arrange()
    if not holder then return end
    local sections, leave, back = Read()
    local style = Style()
    local extra = Shortcuts(style == "docked")
    if #extra > 0 then table.insert(sections, extra) end
    docked:SetShown(style == "docked")
    ring:SetShown(style == "medallion")
    if style == "medallion" then Medallion(sections, leave, back) else Docked(sections, leave, back) end
end
menu.Arrange = Arrange

-- The rest of the interface put away while the menu is open, and back after
local cleared
local function Clear()
    if cleared then return end
    cleared = { alpha = UIParent:GetAlpha(), loose = {} }
    -- a frame whose answers are secret (another addon's, a restricted one)
    -- is left as it is: a secret cannot be tested
    local function Loose(f)
        if f == holder or not f.IsIgnoringParentAlpha then return false end
        local forbidden = f.IsForbidden and f:IsForbidden()
        if ns.IsSecret(forbidden) or forbidden then return false end
        local ignores = f:IsIgnoringParentAlpha()
        return not ns.IsSecret(ignores) and ignores == true
    end
    if EnumerateFrames and holder.IsIgnoringParentAlpha then
        local f = EnumerateFrames()
        while f do
            local ok, loose = pcall(Loose, f)
            if ok and loose then
                f:SetIgnoreParentAlpha(false)
                table.insert(cleared.loose, f)
            end
            f = EnumerateFrames(f)
        end
    end
    UIParent:SetAlpha(0)
    -- the minimap draws its blips and pins (the quest marks, the arrow) past
    -- any alpha: it is hidden, and shown again after
    local mm = _G.Minimap
    if mm and mm:IsShown() and not (mm.IsProtected and mm:IsProtected() and InCombatLockdown()) then
        mm:Hide()
        cleared.minimap = mm
    end
end
local function Restore()
    if not cleared then return end
    for _, f in ipairs(cleared.loose) do f:SetIgnoreParentAlpha(true) end
    UIParent:SetAlpha(cleared.alpha or 1)
    if cleared.minimap then cleared.minimap:Show() end
    cleared = nil
end
menu.Clear, menu.Restore = Clear, Restore

local adopted = false
local function Adopt()
    local f = _G.GameMenuFrame
    if adopted or not f or not f.InitButtons then return end
    adopted = true
    Build()
    -- Blizzard's frame: still the panel the game shows and hides, but unseen
    -- and clicked through; its buttons stand in ours
    f:SetAlpha(0)
    f:EnableMouse(false)
    hooksecurefunc(f, "InitButtons", Arrange)
    f:HookScript("OnShow", function()
        Clear()
        holder:Show()
        -- the friends and the guild asked for again; their answers lay it out anew
        if Style() == "docked" then
            if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends() end
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
            elseif GuildRoster then GuildRoster() end
        end
    end)
    f:HookScript("OnHide", function()
        holder:Hide()
        Restore()
    end)
    if f:IsShown() then
        Arrange()
        Clear()
        holder:Show()
    end
end
menu.Adopt = Adopt

local function Start()
    local style = Style()
    if style ~= "docked" and style ~= "medallion" then return end
    Adopt()
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_GameMenu" then Adopt() end end)
    end
end

ns.On("PLAYER_LOGIN", Start)
-- while it is open: the people and the session as they change
for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "PLAYER_MONEY" }) do
    ns.On(e, function() Relayout() end)
end
ns.On("GUILD_MOTD", function(_, message)
    guildMotd = Clean(message)
    Relayout()
end)
