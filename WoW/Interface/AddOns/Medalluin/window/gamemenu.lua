-- The game menu (Escape), in Medalluin's look: Blizzard's own buttons,
-- moved into a frame of ours and dressed, so every click stays the game's
-- (Log Out, Exit Game, Options run Blizzard's own code, untouched). Two
-- ways to stand (gameMenu):
--
--   docked (the default): a panel down the left edge, as the windows stand
--   +--------------------------------+
--   | (portrait)  Ahrymx             |   who you are: name in class colour,
--   |             Level 24 Gnome Mage|   level, race, class; zone, guild
--   |             Westfall · <Guild> |
--   | GAME ------------------------- |
--   |  * Options                 new |   a row each: the glyph, the words,
--   |  * Shop                        |   a hint (new, how many addons)
--   | INTERFACE -------------------- |
--   |  * AddOns            42 loaded |
--   |  ...                           |
--   | LEAVE ------------------------ |
--   | [ v Log Out ] [ x Exit Game ]  |
--   |                                |
--   | [      Return to Game        ] |
--   +--------------------------------+
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
local ROW, LEAVE, BACK = 34, 32, 38
local MEDAL, BACK_MEDAL = 48, 58           -- a medallion's size; Return to Game's
local REACH = 0.30                          -- the ring's radius, of the screen's height
local ARCH_FROM, ARCH_TO = 160, 20          -- the arch's ends, in degrees, for six
local ARCH_GROW = 7                         -- each end's step out per medallion past six, to 180 and 0
local LEAVE_AT = { logout = 225, exit = 315 }
local BAR_W = 5                             -- a chain bar's thickness
local ROUND = ns.media .. "strips\\round"
local BAR = ns.media .. "gamemenu-bar"

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
local SHORTCUTS = {
    { "/mui", "Medalluin", "achievement" },
    { "/cdm", "Cooldown Manager", "legacy" },
    { "/cc", "Click Casting", "spellbook", nil, "ToggleClickBindingFrame" },
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
    b:HookScript("OnEnter", function() Hot(true) end)
    b:HookScript("OnLeave", function() Hot(false) end)
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

-- One button drawn as a look: "row", "button", "primary" or "medal" (size,
-- and primary: the leading one, gold)
local function Look(b, look, kind, glyph, size, primary)
    local d = Dress(b)
    size = size or MEDAL
    d.primary = look == "medal" and primary or false
    local on = b:IsEnabled()
    local boxed = look == "button" or look == "primary"
    d.edge:SetShown(boxed)
    d.well:SetShown(boxed)
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
    d.label:SetText(d.words or b:GetText() or "")
    local c = not on and DIM or (look == "primary" or d.primary) and GOLD or kind == "exit" and RED
        or ns.colors.text
    d.label:SetTextColor(c[1], c[2], c[3])
    local gc = medal and kind == "exit" and RED or ns.colors.white
    d.glyph:SetVertexColor(gc[1], gc[2], gc[3])
    if look == "row" then
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

-- a heading: its word in small capitals, dim, a rule fading out to the right
local function Heading(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, docked)
    h:SetHeight(18)
    h.word = ns.Text(h, 12)
    h.word:SetPoint("LEFT", 2, 0)
    h.word:SetTextColor(DIM[1], DIM[2], DIM[3])
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetHeight(1)
    h.rule:SetPoint("LEFT", h.word, "RIGHT", 10, 0)
    h.rule:SetPoint("RIGHT")
    Fade(h.rule, GOLD_D, 1)
    heads[i] = h
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
            Dress(b).words = sc[2]
            b:Show()
            table.insert(out, { b = b, kind = "shortcut", glyph = sc[3], hint = cmd })
        elseif b then
            b:Hide()
        end
    end
    return out
end
menu.Shortcuts = Shortcuts
function menu.Words(b) return deco[b] and deco[b].label:GetText() end

-- a section's word, by what is in it
local function Named(section)
    for _, it in ipairs(section) do
        if it.kind == "options" or it.kind == "shop" then return "Game" end
        if it.kind == "addons" or it.kind == "macros" or it.kind == "support" or it.kind == "edit" then
            return "Interface"
        end
        if it.kind == "event" then return "Event" end
        if it.kind == "shortcut" then return "Shortcuts" end
    end
    return ""
end

local function Take(b, parent)
    b:SetParent(parent)
    b:ClearAllPoints()
end

local function Docked(sections, leave, back)
    Who()
    local y = -(PAD + 92)
    local n = 0
    local w = DOCK_W - 2 * PAD
    for _, section in ipairs(sections) do
        n = n + 1
        local h = Heading(n)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", PAD, y)
        h:SetPoint("TOPRIGHT", -PAD, y)
        h.word:SetText(Named(section))
        h:Show()
        y = y - 24
        for _, it in ipairs(section) do
            Take(it.b, docked)
            it.b:SetPoint("TOPLEFT", PAD - 4, y)
            it.b:SetSize(w + 8, ROW)
            Look(it.b, "row", it.kind, it.glyph)
            if it.hint then
                local d = deco[it.b]
                d.hint:SetText(it.hint)
                d.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
                d.hint:SetPoint("RIGHT", -10, 0)
                d.hint:Show()
            end
            y = y - ROW - 2
        end
        y = y - 10
    end
    if #leave > 0 then
        n = n + 1
        local h = Heading(n)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", PAD, y)
        h:SetPoint("TOPRIGHT", -PAD, y)
        h.word:SetText("Leave")
        h:Show()
        y = y - 24
        local bw = math.floor((w - 10 * (#leave - 1)) / #leave)
        for i, it in ipairs(leave) do
            Take(it.b, docked)
            it.b:SetPoint("TOPLEFT", PAD + (i - 1) * (bw + 10), y)
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
