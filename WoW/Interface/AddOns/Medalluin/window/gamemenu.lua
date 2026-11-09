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
--   ribbon: a band across the middle of the screen, fading out at both ends
--     ------------------ Game Menu ------------------
--       (o)     (o)     (o)     (o)     (o)     (o)     medallions, their words under
--     Options   Shop  AddOns  Edit Mode Support Macros
--     -----------------------------------------------
--     [ Log Out ]   [ Return to Game ]   [ Exit Game ]
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
local MEDAL, STEP = 48, 84                 -- the ribbon's medallions: their size, their pitch
local BAND_H = 132
local ROUND = ns.media .. "strips\\round"

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

local holder, docked, ribbon, shade
local deco = {}                 -- a button's dress, by button (no field of ours on Blizzard's)
local heads = {}                -- the docked panel's headings, pooled
local who = {}                  -- the docked panel's portrait and lines

local function Style() return ns.db.gameMenu or "docked" end
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
    -- a medallion: a gold rim, an ink well, a glow behind it under the mouse
    d.halo = b:CreateTexture(nil, "HIGHLIGHT")
    d.halo:SetSize(MEDAL + 22, MEDAL + 22)
    d.halo:SetTexture(ROUND)
    d.halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    if d.halo.SetBlendMode then d.halo:SetBlendMode("ADD") end
    d.rim = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    d.rim:SetSize(MEDAL, MEDAL)
    d.rim:SetTexture(ROUND)
    d.rim:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.inner = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.inner:SetSize(MEDAL - 4, MEDAL - 4)
    d.inner:SetTexture(ROUND)
    d.inner:SetVertexColor(0.063, 0.059, 0.055, 1)
    -- the glyph, the words, a hint at the end
    d.glyph = b:CreateTexture(nil, "ARTWORK")
    d.label = ns.Text(b, 14)
    d.hint = ns.Text(b, 11)
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

-- One button drawn as a look: "row", "button", "primary" or "medal"
local function Look(b, look, kind, glyph)
    local d = Dress(b)
    local on = b:IsEnabled()
    local boxed = look == "button" or look == "primary"
    d.edge:SetShown(boxed)
    d.well:SetShown(boxed)
    d.fill:SetShown(look == "primary")
    d.glow:SetShown(boxed)
    d.wash:SetShown(look == "row")
    d.bar:SetShown(look == "row")
    local medal = look == "medal"
    d.halo:SetShown(medal)
    d.rim:SetShown(medal)
    d.inner:SetShown(medal)
    d.glyph:SetShown(glyph ~= nil)
    if glyph then d.glyph:SetTexture(ns.media .. "strips\\" .. glyph) end
    d.glyph:SetAlpha(on and 0.9 or 0.35)
    d.glyph:ClearAllPoints()
    d.label:ClearAllPoints()
    d.hint:ClearAllPoints()
    d.hint:Hide()
    d.label:SetText(b:GetText() or "")
    local c = not on and DIM or look == "primary" and GOLD or kind == "exit" and RED or ns.colors.text
    d.label:SetTextColor(c[1], c[2], c[3])
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
        d.halo:ClearAllPoints()
        d.halo:SetPoint("CENTER", b, "TOP", 0, -MEDAL / 2)
        d.rim:ClearAllPoints()
        d.rim:SetPoint("CENTER", b, "TOP", 0, -MEDAL / 2)
        d.inner:ClearAllPoints()
        d.inner:SetPoint("CENTER", d.rim)
        d.glyph:SetSize(24, 24)
        d.glyph:SetPoint("CENTER", d.rim)
        d.label:SetPoint("BOTTOM", 0, 2)
        local hint = Hint(kind)
        if hint == "new" then
            d.hint:SetText("new")
            d.hint:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
            d.hint:SetPoint("TOPRIGHT", 0, 0)
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
    -- ribbon: a band across the middle, fading out at both ends
    ribbon = CreateFrame("Frame", nil, holder)
    ribbon:SetHeight(BAND_H)
    ribbon:SetPoint("LEFT", UIParent, "LEFT", 0, 40)
    ribbon:SetPoint("RIGHT", UIParent, "RIGHT", 0, 40)
    ribbon:EnableMouse(true)
    local ink = ns.colors.ink
    for i = 1, 2 do
        local t = ribbon:CreateTexture(nil, "BACKGROUND")
        t:SetPoint("TOP")
        t:SetPoint("BOTTOM")
        t:SetPoint(i == 1 and "LEFT" or "RIGHT")
        t:SetPoint(i == 1 and "RIGHT" or "LEFT", ribbon, "CENTER")
        if t.SetGradient and CreateColor then
            t:SetColorTexture(1, 1, 1, 1)
            local solid, clear = CreateColor(ink[1], ink[2], ink[3], 0.95), CreateColor(ink[1], ink[2], ink[3], 0)
            t:SetGradient("HORIZONTAL", i == 1 and clear or solid, i == 1 and solid or clear)
        else
            t:SetColorTexture(ink[1], ink[2], ink[3], 0.6)
        end
    end
    for _, at in ipairs({ "TOP", "BOTTOM" }) do
        local h = Hair(ribbon)
        h:SetPoint(at .. "LEFT", 40, 0)
        h:SetPoint(at .. "RIGHT", -40, 0)
    end
    ribbon.title = ns.Text(ribbon, 15)
    ribbon.title:SetPoint("TOP", 0, -12)
    ribbon.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    ribbon.title:SetText(MAINMENU_BUTTON or "Game Menu")
    menu.holder, menu.docked, menu.ribbon = holder, docked, ribbon
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

-- a section's word, by what is in it
local function Named(section)
    for _, it in ipairs(section) do
        if it.kind == "options" or it.kind == "shop" then return "Game" end
        if it.kind == "addons" or it.kind == "macros" or it.kind == "support" or it.kind == "edit" then
            return "Interface"
        end
        if it.kind == "event" then return "Event" end
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

local function Ribbon(sections, leave, back)
    local items = {}
    for _, section in ipairs(sections) do
        for _, it in ipairs(section) do table.insert(items, it) end
    end
    local first = -(#items - 1) * STEP / 2
    for i, it in ipairs(items) do
        Take(it.b, ribbon)
        it.b:SetSize(STEP - 4, MEDAL + 26)
        it.b:SetPoint("TOP", ribbon, "TOP", first + (i - 1) * STEP, -34)
        Look(it.b, "medal", it.kind, it.glyph)
    end
    if back then
        Take(back, ribbon)
        back:SetSize(220, BACK)
        back:SetPoint("TOP", ribbon, "BOTTOM", 0, -22)
        Look(back, "primary", "return")
    end
    for i, it in ipairs(leave) do
        Take(it.b, ribbon)
        it.b:SetSize(130, LEAVE)
        if back then
            it.b:SetPoint(i == 1 and "RIGHT" or "LEFT", back, i == 1 and "LEFT" or "RIGHT", i == 1 and -12 or 12, 0)
        else
            it.b:SetPoint("TOP", ribbon, "BOTTOM", (i - 1.5) * 150, -22)
        end
        Look(it.b, "button", it.kind, it.glyph)
    end
    shade:ClearAllPoints()
    shade:SetAllPoints(UIParent)
    shade:SetColorTexture(0, 0, 0, 0.35)
end

-- Taken in: after each InitButtons (as it shows, as the store's state
-- changes), Blizzard's buttons are moved into ours and dressed.
local function Arrange()
    if not holder then return end
    local sections, leave, back = Read()
    local style = Style()
    docked:SetShown(style == "docked")
    ribbon:SetShown(style == "ribbon")
    if style == "ribbon" then Ribbon(sections, leave, back) else Docked(sections, leave, back) end
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
    if style ~= "docked" and style ~= "ribbon" then return end
    Adopt()
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_GameMenu" then Adopt() end end)
    end
end

ns.On("PLAYER_LOGIN", Start)
