-- The Cooldown Manager's settings window (/cdm): the game's own
-- (CooldownViewerSettings, Blizzard_CooldownViewer), dressed in Medalluin's
-- look and standing where the LFG window stands, on the chat box up to the
-- screen's top (social/lfg.lua).
--
--   Cooldown Manager                                       [x]
--      Cooldowns         Buffs         Group buffs     <- its side tabs, open tabs across the top
--   =========================================================
--   [ search spells          ] (gear) [ Enhancement  v ]
--   - ESSENTIAL ----------------------------------------    its categories: our headings
--     (o) (o) (o) (o)                                       its spells: round, a gold rim
--   - UTILITY ------------------------------------------
--     ...
--   - NOT DISPLAYED ------------------------------------
--     (o) Frost Nova                                        a line each: icon and name
--     (o) Blink
--   ---------------------------------------------------------
--   [                    Revert changes                  ]
--
-- Only its look and its place are ours: every click, drag, menu, alert,
-- layout and save is the game's own code, untouched, so nothing of ours
-- runs where the cooldown viewers keep their secured tables
-- (CooldownViewerSecure.lua). Its parts are hidden with alpha or hidden
-- outright where they are art; ours are drawn beside them, kept in a side
-- table, never as fields on the game's frames.
--
-- It shares the LFG window's place: either opening closes the other. An NPC
-- window or the character window opening closes it; the quest tracker steps
-- aside while it is open.
local _, ns = ...

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD, HEAD, TABS, ROW, BAND = 12, 36, 26, 24, 28
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local ROUND = ns.media .. "strips\\round"
local GLYPHS = ns.media .. "strips\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TAB_WORDS = { spells = "Cooldowns", auras = "Buffs", groupBuffs = "Group buffs" }

local cdm = {}
ns.cooldownWindow = cdm

local deco = {}         -- our dress, by the game's frame
local skin              -- our dress under its content

local function Frame() return _G.CooldownViewerSettings end

-- ---------------------------------------------------------------- pieces
local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.5)
    end
end

-- Every texture of a frame put away (its art), fonts kept
local function Bare(f)
    if not f or not f.GetRegions then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
end

-- A box in the windows' face: an ink well, a gold edge, drawn on the frame
-- under its own (hidden) art
local function Box(f)
    local d = deco[f] or {}
    deco[f] = d
    if d.box then return d end
    d.box = true
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    local ink = ns.colors.ink
    well:SetColorTexture(ink[1], ink[2], ink[3], 0.92)
    d.edge, d.well = edge, well
    return d
end

local function Glyph(f, name, size)
    local d = deco[f] or {}
    deco[f] = d
    if not d.glyph then
        d.glyph = f:CreateTexture(nil, "OVERLAY")
        d.glyph:SetPoint("CENTER")
    end
    d.glyph:SetTexture(GLYPHS .. name)
    d.glyph:SetSize(size, size)
    d.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    return d.glyph
end

local function Font(fs, size, color)
    if not fs then return end
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- --------------------------------------------------------------- the place
-- Where the LFG window stands: its box (built or not shown) when there is
-- one, else the chat box's top to the screen's
local placing = false
local function Place()
    local f = Frame()
    if not f or placing then return end
    placing = true
    f:ClearAllPoints()
    local box = ns.lfg and ns.lfg.box
    if box then
        f:SetPoint("TOPLEFT", box, "TOPLEFT")
        f:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    else
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        if ns.chat and ns.chat.box then
            f:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
        else
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 260)
        end
        f:SetWidth(WIDTH)
    end
    placing = false
end
cdm.Place = Place

-- ---------------------------------------------------------------- the frame
local function Chrome(f)
    -- the game's frame art: gone
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer" }) do
        if f[key] then f[key]:Hide() end
    end
    for _, key in ipairs({ "Background", "Bg", "TopTileStreaks" }) do
        if f[key] then f[key]:SetAlpha(0) end
    end
    if f.Inset then
        f.Inset:SetAlpha(0)
        f.Inset:EnableMouse(false)
    end
    -- ours under its content
    skin = CreateFrame("Frame", nil, f)
    skin:SetAllPoints()
    skin:SetFrameLevel(f:GetFrameLevel())       -- under its content, over its own art
    local dress = ns.window.Dress(skin, 0)
    if dress.rule then dress.rule:Hide() end
    skin.title = ns.Text(skin, 16)
    skin.title:SetPoint("TOPLEFT", PAD + 2, -12)
    skin.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    skin.title:SetText("Cooldown Manager")
    -- under the tabs, a hair and a fainter one, as the LFG window's
    local hair = ns.window.Hair(skin)
    hair:SetPoint("TOPLEFT", PAD, -(HEAD + TABS + 4))
    hair:SetPoint("TOPRIGHT", -PAD, -(HEAD + TABS + 4))
    local faint = ns.window.Hair(skin, false, 0.5)
    faint:SetPoint("TOPLEFT", PAD + 30, -(HEAD + TABS + 7))
    faint:SetPoint("TOPRIGHT", -PAD - 30, -(HEAD + TABS + 7))
    -- the foot band's rule
    local rule = skin:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", PAD, PAD + BAND + 7)
    rule:SetPoint("BOTTOMRIGHT", -PAD, PAD + BAND + 7)
    -- the close button: its click the game's, our glyph
    local close = f.CloseButton
    if close then
        Bare(close)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local t = close[get] and close[get](close)
            if t then t:SetAlpha(0) end
        end
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -PAD, -6)
        close:SetSize(26, 26)
        local g = Glyph(close, "close", 16)
        close:HookScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
        close:HookScript("OnLeave", function() g:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
    end
end

-- ----------------------------------------------------------------- the tabs
-- Its side tabs across the top as open tabs: their art hidden, our words, a
-- gold underline and a glow rising from it on the one in use
local function Tabs(f)
    local tabs = f.TabButtons or {}
    local n = #tabs
    if n == 0 then return end
    local each = (WIDTH - 2 * PAD) / n
    for i, tab in ipairs(tabs) do
        for _, key in ipairs({ "Background", "Icon", "SelectedTexture", "TabGlow", "HighlightTexture" }) do
            if tab[key] then tab[key]:SetAlpha(0) end
        end
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * each, -HEAD)
        tab:SetSize(each, TABS)
        local d = deco[tab] or {}
        deco[tab] = d
        if not d.words then
            d.words = ns.Text(tab, 13)
            d.words:SetPoint("CENTER", 0, 1)
            d.line = tab:CreateTexture(nil, "ARTWORK")
            d.line:SetHeight(2)
            d.line:SetPoint("BOTTOMLEFT", 10, 0)
            d.line:SetPoint("BOTTOMRIGHT", -10, 0)
            d.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            d.glow = tab:CreateTexture(nil, "BACKGROUND")
            d.glow:SetPoint("BOTTOMLEFT", 10, 2)
            d.glow:SetPoint("TOPRIGHT", -10, 0)
            if d.glow.SetGradient and CreateColor then
                d.glow:SetColorTexture(1, 1, 1, 1)
                d.glow:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.18),
                    CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
            else
                d.glow:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
            end
            tab:HookScript("OnEnter", function() d.hot = true; cdm.Tabs() end)
            tab:HookScript("OnLeave", function() d.hot = false; cdm.Tabs() end)
        end
        d.words:SetText(TAB_WORDS[tab.displayMode] or tab.tooltipText or "")
    end
end

-- which tab is in use, as the game set it
function cdm.Tabs()
    local f = Frame()
    if not f then return end
    for _, tab in ipairs(f.TabButtons or {}) do
        local d = deco[tab]
        if d then
            local on = tab.displayMode == f.displayMode
            local c = (on or d.hot) and GOLD or ns.colors.text
            d.words:SetTextColor(c[1], c[2], c[3])
            d.line:SetShown(on)
            d.glow:SetShown(on)
        end
    end
end

-- ------------------------------------------------------- search and choices
local function Controls(f)
    local top = -(HEAD + TABS + 16)
    -- the layout dropdown, at the search row's right
    local layout = f.LayoutDropdown
    local right = 0
    if layout then
        Bare(layout)
        if layout.Arrow then layout.Arrow:SetAlpha(0) end
        local d = Box(layout)
        if not d.arrow then
            d.arrow = layout:CreateTexture(nil, "OVERLAY")
            d.arrow:SetTexture(GLYPHS .. "chevron-down")
            d.arrow:SetSize(12, 12)
            d.arrow:SetPoint("RIGHT", -6, 0)
            d.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        end
        Font(layout.Text, 12, ns.colors.text)
        layout:ClearAllPoints()
        layout:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, top)
        layout:SetSize(180, 22)
        right = 180 + 6
    end
    -- the gear: its menu the game's, our glyph
    local gear = f.SettingsDropdown
    if gear then
        Bare(gear)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local t = gear[get] and gear[get](gear)
            if t then t:SetAlpha(0) end
        end
        if gear.Icon then gear.Icon:SetAlpha(0) end
        gear:ClearAllPoints()
        gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - right, top)
        gear:SetSize(22, 22)
        Glyph(gear, "menu", 16)
        right = right + 22 + 6
    end
    -- the search box: its art hidden, our well
    local search = f.SearchBox
    if search then
        for _, key in ipairs({ "Left", "Right", "Middle", "Mid" }) do
            if search[key] then search[key]:SetAlpha(0) end
        end
        Box(search)
        search:ClearAllPoints()
        search:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - right, top)
        search:SetHeight(22)
        if search.SetFont then search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "") end
        if search.Instructions then Font(search.Instructions, 11, DIM) end
        if search.searchIcon then search.searchIcon:SetVertexColor(DIM[1], DIM[2], DIM[3]) end
    end
    -- its lists: under the search row, over the foot band
    local list = top - ROW - 8
    for _, key in ipairs({ "CooldownScroll", "GroupBuffFilter" }) do
        local s = f[key]
        if s then
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, list)
            s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, PAD + BAND + 14)
        end
    end
    -- Revert: the foot band, a box with gold words
    local undo = f.UndoButton
    if undo then
        Bare(undo)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local t = undo[get] and undo[get](undo)
            if t then t:SetAlpha(0) end
        end
        for _, key in ipairs({ "Left", "Right", "Middle" }) do
            if undo[key] then undo[key]:SetAlpha(0) end
        end
        local d = Box(undo)
        if not d.glow then
            d.glow = undo:CreateTexture(nil, "HIGHLIGHT")
            d.glow:SetPoint("TOPLEFT", 1, -1)
            d.glow:SetPoint("BOTTOMRIGHT", -1, 1)
            d.glow:SetColorTexture(1, 1, 1, 0.08)
        end
        undo:ClearAllPoints()
        undo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
        undo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
        undo:SetHeight(BAND)
        local fs = undo.GetFontString and undo:GetFontString()
        Font(fs, 13)
        if fs then
            local on = undo:IsEnabled()
            local c = on and GOLD or DIM
            fs:SetTextColor(c[1], c[2], c[3])
        end
    end
end

-- -------------------------------------------------------- headings, spells
-- A category's heading: its three slices hidden; the word in gold small
-- capitals, a fold sign before it, a gold rule fading out to the right
local function Heading(cat)
    local h = cat.Header
    if not h then return end
    for _, key in ipairs({ "Left", "Right", "Middle", "HighlightLeft", "HighlightRight", "HighlightMiddle" }) do
        if h[key] then h[key]:SetAlpha(0) end
    end
    local d = deco[h] or {}
    deco[h] = d
    if not d.fold then
        d.fold = ns.Text(h, 13)
        d.fold:SetPoint("LEFT", 2, 0)
        d.fold:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        d.rule = h:CreateTexture(nil, "ARTWORK")
        d.rule:SetHeight(1)
        d.rule:SetPoint("RIGHT", h, "RIGHT", 0, 0)
        Fade(d.rule, GOLD_D, 1)
    end
    if h.Name then
        Font(h.Name, 12, GOLD)
        h.Name:ClearAllPoints()
        h.Name:SetPoint("LEFT", 16, 0)
        d.rule:SetPoint("LEFT", h.Name, "RIGHT", 10, 0)
    end
    local collapsed = cat.IsCollapsed and cat:IsCollapsed()
    d.fold:SetText(collapsed and "+" or "\226\136\146")
end

-- A spell: its icon masked round, a gold rim under it; under the mouse the
-- rim lights (the game's square highlight hidden)
local function Rim(item, d)
    local lit = d.hot or (item.IsBeingDragged and item:IsBeingDragged())
    local grey = item.Icon and item.Icon.IsDesaturated and item.Icon:IsDesaturated()
    local c = lit and GOLD or GOLD_D
    d.rim:SetVertexColor(c[1], c[2], c[3], grey and not lit and 0.55 or 1)
    if d.row then d.row:SetShown(d.listed and lit or false) end
end

local function Spell(item)
    local icon = item.Icon
    if not icon then return end
    local d = deco[item]
    if not d then
        d = {}
        deco[item] = d
        if item.CreateMaskTexture and icon.AddMaskTexture then
            d.mask = item:CreateMaskTexture()
            d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
            d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
            icon:AddMaskTexture(d.mask)
        end
        d.rim = item:CreateTexture(nil, "BACKGROUND", nil, -6)
        d.rim:SetTexture(ROUND)
        d.rim:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        d.rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        if item.HookScript then
            item:HookScript("OnEnter", function() d.hot = true; Rim(item, d) end)
            item:HookScript("OnLeave", function() d.hot = false; Rim(item, d) end)
        end
    end
    if item.Highlight then item.Highlight:SetAlpha(0) end
    -- a tracked bar: our gold bar, our words
    local bar = item.Bar
    if bar then
        if bar.SetStatusBarTexture then bar:SetStatusBarTexture(WHITE) end
        if bar.SetStatusBarColor then bar:SetStatusBarColor(GOLD_D[1], GOLD_D[2], GOLD_D[3]) end
        local name = bar.Name or item.Name
        Font(name, 11, ns.colors.text)
    end
    Rim(item, d)
end

-- ------------------------------------------------ Not displayed: a list
-- The spells and buffs left off the bars, a line each: a small round icon
-- and its name. The game's grid lays them out first; we only stand them in
-- a column after it (the game finds a drop's target by where each item
-- stands, so dragging in and out still works). The game hands its category
-- frames from one section to another, so a frame no longer Not displayed
-- gets its grid's items back before the grid runs (its Init).
local LIST_W, LINE, LINE_GAP, LINE_ICON = 314, 22, 2, 18

local function Hidden(cat)
    local E = Enum and Enum.CooldownViewerCategory
    local o = cat.GetCategoryObject and cat:GetCategoryObject()
    local id = o and o.GetCategory and o:GetCategory()
    return E ~= nil and id ~= nil and (id == E.HiddenActive or id == E.HiddenPassive)
end

local function Unlist(item)
    local d = deco[item]
    if not d or not d.listed then return end
    d.listed = false
    item:SetSize(d.w, d.h)
    item.Icon:ClearAllPoints()
    item.Icon:SetSize(d.iw, d.ih)
    item.Icon:SetAllPoints()
    d.name:Hide()
    Rim(item, d)
end

local function Line(item)
    Spell(item)
    local d = deco[item]
    if not d then return end
    if not d.name then
        d.name = ns.Text(item, 12)
        d.name:SetPoint("LEFT", item.Icon, "RIGHT", 8, 0)
        d.name:SetPoint("RIGHT", item, "RIGHT", -4, 0)
        d.name:SetJustifyH("LEFT")
        d.name:SetWordWrap(false)
        d.row = item:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.row:SetAllPoints()
        d.row:SetColorTexture(1, 1, 1, 0.05)
    end
    if not d.listed then
        d.listed = true
        d.w, d.h = item:GetWidth(), item:GetHeight()
        d.iw, d.ih = item.Icon:GetWidth(), item.Icon:GetHeight()
        item:SetSize(LIST_W, LINE)
        item.Icon:ClearAllPoints()
        item.Icon:SetPoint("LEFT", item, "LEFT", 2, 0)
        item.Icon:SetSize(LINE_ICON, LINE_ICON)
        d.name:Show()
    end
    local empty = item.IsEmptyCategory and item:IsEmptyCategory()
    local ok, text = false, nil
    if not empty and item.GetNameText then ok, text = pcall(item.GetNameText, item) end
    d.name:SetText(ok and type(text) == "string" and text or "")
    local known = not item.IsKnown or item:IsKnown()
    local c = known and ns.colors.text or DIM
    d.name:SetTextColor(c[1], c[2], c[3])
    Rim(item, d)
end

local listing = false
local function List(cat)
    local d = deco[cat] or {}
    deco[cat] = d
    d.items = d.items or {}
    if not Hidden(cat) then
        for item in pairs(d.items) do Unlist(item) end
        return
    end
    local items = {}
    if cat.itemPool and cat.itemPool.EnumerateActive then
        for item in cat.itemPool:EnumerateActive() do table.insert(items, item) end
    end
    table.sort(items, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
    local box = cat.Container
    for i, item in ipairs(items) do
        d.items[item] = true
        Line(item)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(i - 1) * (LINE + LINE_GAP))
    end
    box:SetSize(LIST_W, math.max(1, #items * (LINE + LINE_GAP) - LINE_GAP))
    -- the section's own size, to fit the column (as the game's fold does)
    if not listing and cat.Layout then
        listing = true
        pcall(cat.Layout, cat)
        listing = false
    end
end
cdm.List = List

-- ----------------------------------------- only the list scrolls
-- The sections over Not displayed stand still in a block of ours under the
-- search row, Not displayed's heading under them; only its list is left in
-- the game's scroll frame, which starts under that heading, so the scroll
-- bar runs beside the list alone. The drop marker (its child, clipped by
-- it) is lifted onto the window, to show over the still sections too. A
-- section frame the game hands on is given back to the scroll's content as
-- it is reused (its Init), its heading with it. No Not displayed (Group
-- buffs) or the still sections too tall to leave the list room: the game's
-- own scroll, all of it.
local ROOM = 120            -- the list's least height, under the still sections
local block                 -- ours: the still sections
local pinned = {}           -- the section whose heading is in the block

-- The scroll back on its own place on the window, hanging on nothing of
-- the sections: first, before any of them is anchored again (else a
-- section, the scroll's content, the scroll and the heading it hangs from
-- would anchor in a circle, which the game refuses)
local function Loose(f)
    local scroll = f and f.CooldownScroll
    if not scroll then return end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -(HEAD + TABS + 16) - ROW - 8)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, PAD + BAND + 14)
end

local function Unpin(cat)
    if not pinned[cat] then return end
    pinned[cat] = nil
    local h, box = cat.Header, cat.Container
    h:SetParent(cat)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", cat, "TOPLEFT")
    h:SetPoint("TOPRIGHT", cat, "TOPRIGHT")
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 13, -15)
    end
end

local function Home(cat)
    if next(pinned) then Loose(Frame()) end
    Unpin(cat)
    local content = Frame().CooldownScroll.Content
    if cat:GetParent() ~= content then cat:SetParent(content) end
end

local function Stand(f)
    local scroll = f.CooldownScroll
    local content = scroll and scroll.Content
    if not content or not f.categoryPool then return end
    Loose(f)
    -- the sections in the game's order
    local byObj, order = {}, {}
    for cat in f.categoryPool:EnumerateActive() do
        if cat.GetCategoryObject then byObj[cat:GetCategoryObject()] = cat end
    end
    for _, obj in ipairs(f.currentCategories or {}) do
        if byObj[obj] then table.insert(order, byObj[obj]) end
    end
    local list = order[#order]
    if not (list and Hidden(list)) or f.displayMode == "groupBuffs" then list = nil end
    for cat in pairs(pinned) do
        if cat ~= list then Unpin(cat) end
    end
    if not block then
        block = CreateFrame("Frame", nil, f)
        block:SetSize(1, 1)
    end
    local function Restore()
        -- the game's own: every section in its scroll, chained as it set them
        local prev
        for _, cat in ipairs(order) do
            Home(cat)
            cat:ClearAllPoints()
            if prev then
                cat:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18)
            else
                cat:SetPoint("TOPLEFT", content, "TOPLEFT")
            end
            prev = cat
        end
    end
    if not list then
        Restore()
        return
    end
    -- the still sections, stacked in the block where the scroll began
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -(HEAD + TABS + 16) - ROW - 8)
    local prev
    for _, cat in ipairs(order) do
        if cat ~= list then
            Unpin(cat)
            cat:SetParent(block)
            cat:ClearAllPoints()
            if prev then
                cat:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18)
            else
                cat:SetPoint("TOPLEFT", block, "TOPLEFT")
            end
            prev = cat
        end
    end
    -- Not displayed's heading under them, its list alone in the scroll
    local h = list.Header
    pinned[list] = true
    h:SetParent(block)
    h:ClearAllPoints()
    if prev then
        h:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18)
    else
        h:SetPoint("TOPLEFT", block, "TOPLEFT")
    end
    h:SetWidth(list:GetWidth() > 0 and list:GetWidth() or LIST_W + 30)
    if list:GetParent() ~= content then list:SetParent(content) end
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", content, "TOPLEFT")
    if list.Container then
        list.Container:ClearAllPoints()
        list.Container:SetPoint("TOPLEFT", list, "TOPLEFT", 13, -2)
    end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, PAD + BAND + 14)
    -- too tall to leave the list its room: the game's scroll after all
    local hb, fb = h:GetBottom(), f:GetBottom()
    if hb and fb and hb - (fb + PAD + BAND + 14) < ROOM then
        Loose(f)
        Unpin(list)
        Restore()
        return
    end
    -- the drop marker over the still sections too
    local marker = f.ReorderMarker or content.ReorderMarker
    if marker and marker:GetParent() ~= f then
        marker:SetParent(f)
        marker:SetFrameLevel(f:GetFrameLevel() + 40)
    end
end
cdm.Stand = Stand

-- ------------------------------------------------------------- the dressing
-- After the game lays its categories out (as it shows, a tab changes, a
-- spell moves): each heading and spell dressed, new ones as first met
local function Dress()
    local f = Frame()
    if not f or not ns.db.cdmWindow then return end
    local pool = f.categoryPool
    if pool and pool.EnumerateActive then
        for cat in pool:EnumerateActive() do
            Heading(cat)
            if cat.itemPool and cat.itemPool.EnumerateActive then
                for item in cat.itemPool:EnumerateActive() do Spell(item) end
            end
            local d = deco[cat] or {}
            deco[cat] = d
            if not d.hooked and cat.SetCollapsed then
                d.hooked = true
                -- folded: its heading's sign; the list's room measured again
                hooksecurefunc(cat, "SetCollapsed", function()
                    Heading(cat)
                    Stand(Frame())
                end)
                -- given to another section: its grid back before the grid runs
                if cat.Init then
                    hooksecurefunc(cat, "Init", function()
                        Home(cat)
                        List(cat)
                    end)
                end
                if cat.Container and cat.Container.Layout then
                    hooksecurefunc(cat.Container, "Layout", function() List(cat) end)
                end
            end
            List(cat)
        end
    end
    Controls(f)
    Stand(f)
    cdm.Tabs()
end
cdm.Dress = Dress

-- ------------------------------------------------------------- the takeover
local adopted = false
local function Adopt()
    local f = Frame()
    if adopted or not f then return end
    adopted = true
    Chrome(f)
    Tabs(f)
    Controls(f)
    Place()
    -- its own place, whenever the panel manager or the game moves it: ours
    hooksecurefunc(f, "SetPoint", function()
        if not placing then ns.OutOfCombat(Place) end
    end)
    for _, method in ipairs({ "RefreshLayout", "SetDisplayMode", "UpdateSaveButtonStates" }) do
        if f[method] then hooksecurefunc(f, method, Dress) end
    end
    f:HookScript("OnShow", function()
        Place()
        Dress()
        if ns.chat then ns.chat.Hold(true, "cdm") end
        -- the LFG window shares the place: closed
        if ns.lfg and ns.lfg.IsShown and ns.lfg.IsShown() then ns.lfg.Close() end
    end)
    f:HookScript("OnHide", function()
        if ns.chat then ns.chat.Hold(false, "cdm") end
    end)
    if ns.quests and ns.quests.Cover then ns.quests.Cover(f) end
    -- the LFG window and an NPC window opening close it: the last opened wins
    local function CloseOurs()
        if f:IsShown() then
            if HideUIPanel then HideUIPanel(f) else f:Hide() end
        end
    end
    if ns.lfg and ns.lfg.box then ns.lfg.box:HookScript("OnShow", CloseOurs) end
    if ns.npc and ns.npc.box then ns.npc.box:HookScript("OnShow", CloseOurs) end
    if ns.character and ns.character.window then ns.character.window:HookScript("OnShow", CloseOurs) end
    if f:IsShown() then
        Place()
        Dress()
    end
    cdm.frame = f
end
cdm.Adopt = Adopt

local function Start()
    if not ns.db.cdmWindow then return end
    if Frame() then Adopt() end
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name)
            if name == "Blizzard_CooldownViewer" then Adopt() end
        end)
    end
end

ns.On("PLAYER_LOGIN", Start)
