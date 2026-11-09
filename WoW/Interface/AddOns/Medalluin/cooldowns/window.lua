-- The Cooldown Manager's settings window (/cdm): the game's own
-- (CooldownViewerSettings, Blizzard_CooldownViewer), dressed in Medalluin's
-- look and standing where the LFG window stands, on the chat box up to the
-- screen's top (social/lfg.lua).
--
--   Cooldown Manager                                       [x]
--      Cooldowns         Buffs         Group buffs     <- its side tabs, open tabs across the top
--   =========================================================
--   [ search spells                                ] | (gear)
--   - ESSENTIAL ----------------------------------------    its categories: our headings
--     (o) (o) (o) (o)                                       its spells: round, a gold rim
--   - UTILITY ------------------------------------------
--     ...
--   - NOT DISPLAYED ------------------------------------
--     (o) Frost Nova                                        a line each: icon and name
--     (o) Blink
--   ---------------------------------------------------------
--   [<-] [ Enhancement       ^ ]                            Revert, the layouts
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
local PAD, HEAD, TABS = 12, 36, 26
local ROW, GAP = 28, 4              -- the search row's and the foot's cells, as the chat's tabs (strips/chat.lua)
local EDGE = 3                      -- the gear's inset from the right: flush inside the window's border
local TOP = -(HEAD + TABS + 18)     -- the search row's top, clear of the tabs' hairlines
local LIST = TOP - ROW - 12         -- the lists' top, under it
local FOOT = 1 + ROW + 12           -- the lists' foot, over the foot row
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local ROUND = ns.media .. "strips\\round"
local GLYPHS = ns.media .. "strips\\"
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

-- Every texture of a frame put away (its art), fonts kept: once, as first
-- met, so ours drawn on it after stay
local function Bare(f)
    if not f or not f.GetRegions then return end
    local d = deco[f] or {}
    deco[f] = d
    if d.bare then return end
    d.bare = true
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
end

-- A box in the windows' face: an ink well, a gold edge, drawn on the frame
-- under its own (hidden) art
-- (its edge four lines, so a see-through well shows the world, not gold);
-- fill: the well's opacity, 0.92 unless given
local function Edge(d, c)
    for _, t in ipairs(d.edges) do t:SetColorTexture(c[1], c[2], c[3], 1) end
end

local function Box(f, fill)
    local d = deco[f] or {}
    deco[f] = d
    if d.box then return d end
    d.box = true
    d.edges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then t:SetHeight(1) else t:SetWidth(1) end
        table.insert(d.edges, t)
    end
    Edge(d, GOLD_D)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    local ink = ns.colors.ink
    well:SetColorTexture(ink[1], ink[2], ink[3], fill or 0.92)
    d.well = well
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
    -- the search row's and the foot row's lines, edge to edge along their
    -- cells (the chat's tab row's hairline)
    for _, at in ipairs({ { "TOP", TOP }, { "BOTTOM", ROW } }) do
        local rule = skin:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(at[1] .. "LEFT", 1, at[2])
        rule:SetPoint(at[1] .. "RIGHT", -1, at[2])
    end
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
-- Its controls' box faces: the edge lit under the mouse
local function Lit(f)
    local d = deco[f]
    if not d or d.lit then return end
    d.lit = true
    f:HookScript("OnEnter", function()
        Edge(d, GOLD)
        if d.glyph then d.glyph:SetVertexColor(1, 1, 1) end
    end)
    f:HookScript("OnLeave", function()
        Edge(d, GOLD_D)
        if d.glyph then
            local on = not f.IsEnabled or f:IsEnabled()
            local c = on and GOLD or DIM
            d.glyph:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        end
    end)
end

-- a button's own states' art (normal, pushed, lit, disabled): put away
local function Plain(b)
    Bare(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
end

-- A divider between two cells: gold, the row's height (the chat's, before
-- its cog)
local function Divider(f, key, point, x, y)
    local fd = deco[f] or {}
    deco[f] = fd
    if not fd[key] and skin then
        fd[key] = skin:CreateTexture(nil, "ARTWORK")
        fd[key]:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        fd[key]:SetSize(1, ROW)
        fd[key]:SetPoint(point, f, point, x, y)
    end
end

-- The search row and the foot as the chat's tab row: cells edge to edge,
-- flush to the window's sides, a gold divider between them. Up top the
-- search, then the gear on the edge; at the foot Revert (a rounded arrow
-- back), then the layouts (their menu opening upward, the game's own way),
-- the rest of the row free.
local function Controls(f)
    -- the gear, on the edge
    local gear = f.SettingsDropdown
    if gear then
        Plain(gear)
        if gear.Icon then gear.Icon:SetAlpha(0) end
        Box(gear, 0.4)
        Glyph(gear, "menu", 17)
        Lit(gear)
        gear:ClearAllPoints()
        gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -EDGE, TOP)
        gear:SetSize(ROW, ROW)
        Divider(f, "gearRule", "TOPRIGHT", -(EDGE + ROW + GAP), TOP)
    end
    -- the search, the row's width up to the divider; its glass in off the edge
    local search = f.SearchBox
    if search then
        for _, key in ipairs({ "Left", "Right", "Middle", "Mid" }) do
            if search[key] then search[key]:SetAlpha(0) end
        end
        Box(search, 0.4)
        Lit(search)
        search:ClearAllPoints()
        search:SetPoint("TOPLEFT", f, "TOPLEFT", 1, TOP)
        search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(EDGE + ROW + GAP + 1 + GAP), TOP)
        search:SetHeight(ROW)
        if search.SetFont then search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "") end
        if search.SetTextInsets then search:SetTextInsets(28, 24, 0, 0) end
        local glass = search.searchIcon
        if glass then
            glass:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
            glass:ClearAllPoints()
            glass:SetPoint("LEFT", search, "LEFT", 10, 0)
        end
        if search.Instructions then
            Font(search.Instructions, 12, DIM)
            search.Instructions:ClearAllPoints()
            search.Instructions:SetPoint("LEFT", search, "LEFT", 28, 0)
            search.Instructions:SetPoint("RIGHT", search, "RIGHT", -24, 0)
        end
    end
    -- its lists: under the search row, over the foot
    for _, key in ipairs({ "CooldownScroll", "GroupBuffFilter" }) do
        local s = f[key]
        if s then
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, LIST)
            s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, FOOT)
        end
    end
    -- Revert: a cell with a rounded arrow back (the reset glyph, mirrored);
    -- its words in its tooltip
    local undo = f.UndoButton
    if undo then
        Plain(undo)
        for _, key in ipairs({ "Left", "Right", "Middle" }) do
            if undo[key] then undo[key]:SetAlpha(0) end
        end
        local d = Box(undo)
        local fs = undo.GetFontString and undo:GetFontString()
        if not d.glyph then
            d.words = fs and fs:GetText()
            d.glyph = undo:CreateTexture(nil, "OVERLAY")
            d.glyph:SetTexture(GLYPHS .. "side-reset")
            d.glyph:SetTexCoord(1, 0, 0, 1)
            d.glyph:SetSize(16, 16)
            d.glyph:SetPoint("CENTER")
            if undo.SetMotionScriptsWhileDisabled then undo:SetMotionScriptsWhileDisabled(true) end
            undo:HookScript("OnEnter", function(self)
                local words = d.words
                if type(words) ~= "string" or words == "" then words = "Revert changes" end
                ns.Tip(self, ns.window.Outside, { title = words, color = GOLD,
                    { "body", self:IsEnabled() and "Back to this layout as it was last saved."
                        or "Nothing to revert: no changes since this layout was saved." } })
            end)
            undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
            Lit(undo)
            -- the game fits it to its words whenever it sets them (hover, leave,
            -- enabled, disabled): back to the cell, square
            hooksecurefunc(undo, "SetWidth", function(self, w)
                if w ~= ROW then self:SetWidth(ROW) end
            end)
        end
        if fs and fs:GetAlpha() ~= 0 then fs:SetAlpha(0) end
        undo:ClearAllPoints()
        undo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        undo:SetSize(ROW, ROW)
        local on = undo:IsEnabled()
        local c = on and GOLD or DIM
        d.glyph:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        Divider(f, "footRule", "BOTTOMLEFT", 1 + ROW + GAP, 1)
    end
    -- the layouts: past the divider, their menu opening upward
    local layout = f.LayoutDropdown
    if layout then
        Bare(layout)
        if layout.Arrow then layout.Arrow:SetAlpha(0) end
        local d = Box(layout)
        if not d.arrow then
            d.arrow = layout:CreateTexture(nil, "OVERLAY")
            d.arrow:SetTexture(GLYPHS .. "chevron-up")
            d.arrow:SetSize(11, 11)
            d.arrow:SetPoint("RIGHT", -10, 0)
            d.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            Lit(layout)
        end
        Font(layout.Text, 12, ns.colors.text)
        if layout.Text then
            layout.Text:ClearAllPoints()
            layout.Text:SetPoint("LEFT", 10, 0)
            layout.Text:SetPoint("RIGHT", d.arrow, "LEFT", -6, 0)
            if layout.Text.SetJustifyH then layout.Text:SetJustifyH("LEFT") end
        end
        layout:ClearAllPoints()
        layout:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1 + ROW + GAP + 1 + GAP, 1)
        layout:SetSize(210, ROW)
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
    d.rim:SetVertexColor(c[1], c[2], c[3], d.filtered and 0.35 or grey and not lit and 0.6 or 1)
    -- left out by the search: faded in its ring (the game's square shade put away)
    if item.Icon then item.Icon:SetAlpha(d.filtered and 0.3 or 1) end
    if d.row then d.row:SetShown(d.listed and lit or false) end
end

-- A tracked bar as the Auras tab draws its own: a solid gold fill with a
-- sheen on its top half, cream words; grey when the game holds the spell
-- unknown or locked. The game's fill is kept hidden (it shows it again, and
-- tints it orange, as it refreshes the spell): ours stands in its place.
function cdm.Bar(item)
    local bar = item.Bar
    local e = bar and deco[bar]
    if not e then return end
    if bar.FillTexture then bar.FillTexture:SetAlpha(0) end
    local empty = item.IsEmptyCategory and item:IsEmptyCategory()
    local grey = (item.IsKnown and not item:IsKnown()) or (item.IsReorderLocked and item:IsReorderLocked())
    local out = deco[item] and deco[item].filtered
    local c = grey and DIM or GOLD_D
    e.fill:SetColorTexture(c[1], c[2], c[3], out and 0.2 or grey and 0.4 or 0.75)
    e.fill:SetShown(not empty)
    e.sheen:SetShown(not empty)
    local name = bar.Name or item.Name
    Font(name, 12, (grey or out) and DIM or ns.colors.text)
    if name and name.SetDrawLayer then name:SetDrawLayer("OVERLAY", 7) end
end

-- A spell's alert marker (CooldownViewerVisualAlertTarget: the alerts set on
-- it, a black strip on its icon's foot): an ink tag with a gold edge across
-- the medallion's foot, its alert glyphs the game's; on a Not displayed
-- line, at the line's end
local function Badge(item)
    local o = item.AlertTypesOverlay
    if not o then return end
    local e = deco[o]
    if not e then
        e = {}
        deco[o] = e
        e.edge = o:CreateTexture(nil, "BACKGROUND", nil, -1)
        e.edge:SetPoint("TOPLEFT", -1, 1)
        e.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        e.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    end
    -- its glyphs are atlases (common-icon-sound, -visual) the client may not
    -- have, drawing nothing: only those it has count. None to draw but
    -- alerts set: no tag (its frame kept: its OnHide lets the alerts go),
    -- a gold pip on the medallion instead
    local set, drawn = 0, 0
    for _, g in ipairs(o.visibleIcons or {}) do
        set = set + 1
        local atlas = g.GetAtlas and g:GetAtlas()
        local info = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if info then drawn = drawn + 1 end
        g:SetAlpha(info and 1 or 0)
    end
    local glyphs = drawn > 0
    if o.BG then
        local ink = ns.colors.ink
        o.BG:SetColorTexture(ink[1], ink[2], ink[3], glyphs and 0.95 or 0)
    end
    e.edge:SetShown(glyphs)
    if not e.pip and item.Icon then
        e.pip = o:CreateTexture(nil, "OVERLAY")
        e.pip:SetTexture(ROUND)
        e.pip:SetSize(8, 8)
        e.pip:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    end
    if e.pip then
        e.pip:ClearAllPoints()
        e.pip:SetPoint("CENTER", item.Icon, "BOTTOMRIGHT", -5, 5)
        e.pip:SetShown(set > 0 and not glyphs)
    end
    o:ClearAllPoints()
    local d = deco[item]
    if d and d.listed then
        o:SetPoint("RIGHT", item, "RIGHT", -6, 0)
    elseif item.Icon then
        o:SetPoint("CENTER", item.Icon, "BOTTOM", 0, 0)
    end
end
cdm.Badge = Badge

-- The search leaving a spell out: the game lays a black square over its
-- icon or its bar; ours fades it instead, in its ring
function cdm.Filter(item)
    local d = deco[item]
    if not d then return end
    local out = false
    for _, key in ipairs({ "FilterOverlay", "BarFilterOverlay" }) do
        local o = item[key]
        if o then
            o:SetAlpha(0)
            if o:IsShown() then out = true end
        end
    end
    d.filtered = out
    Rim(item, d)
    if item.Bar then cdm.Bar(item) end
end

local function Spell(item)
    local icon = item.Icon
    if not icon then return end
    local d = deco[item]
    if not d then
        d = {}
        deco[item] = d
        -- the icon's own square border cut off, so the round mask shows its
        -- face (once, before the mask: the game refuses tex coords after)
        if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        if item.CreateMaskTexture and icon.AddMaskTexture then
            d.mask = item:CreateMaskTexture()
            d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 3, -3)
            d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
            icon:AddMaskTexture(d.mask)
        end
        -- a thin gold ring round an ink well, the icon set in it: a slot with
        -- no icon reads as an empty socket
        d.rim = item:CreateTexture(nil, "BACKGROUND", nil, -6)
        d.rim:SetTexture(ROUND)
        d.rim:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        d.rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        d.well = item:CreateTexture(nil, "BACKGROUND", nil, -5)
        d.well:SetTexture(ROUND)
        d.well:SetPoint("TOPLEFT", icon, "TOPLEFT", 1.5, -1.5)
        d.well:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1.5, 1.5)
        local ink = ns.colors.ink
        d.well:SetVertexColor(ink[1], ink[2], ink[3], 1)
        -- the search's verdict on it, after the game's
        if item.ApplyFilter then
            hooksecurefunc(item, "ApplyFilter", function() cdm.Filter(item) end)
        end
        if item.HookScript then
            item:HookScript("OnEnter", function() d.hot = true; Rim(item, d) end)
            item:HookScript("OnLeave", function() d.hot = false; Rim(item, d) end)
        end
        -- its alert marker, made as alerts are set on it
        if item.RefreshAlertTypeOverlay then
            hooksecurefunc(item, "RefreshAlertTypeOverlay", function() Badge(item) end)
        end
    end
    if item.Highlight then item.Highlight:SetAlpha(0) end
    -- a tracked bar: our well, a gold fill, our words
    local bar = item.Bar
    if bar then
        local e = deco[bar]
        if not e then
            e = {}
            deco[bar] = e
            -- the game sets its bars in LOW, under the window and its dress:
            -- lifted to their row's strata, just over it
            if bar.SetFrameStrata and item.GetFrameStrata then
                bar:SetFrameStrata(item:GetFrameStrata())
                bar:SetFrameLevel(item:GetFrameLevel() + 1)
            end
            -- the game's bar art (its frame, wider and taller than the bar, and
            -- its fill): put away
            for _, r in ipairs({ bar:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
            end
            e.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
            e.edge:SetPoint("TOPLEFT", -1, 1)
            e.edge:SetPoint("BOTTOMRIGHT", 1, -1)
            e.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            e.well = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
            e.well:SetAllPoints()
            local ink = ns.colors.ink
            e.well:SetColorTexture(ink[1], ink[2], ink[3], 0.95)
            e.fill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
            e.fill:SetAllPoints()
            e.sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
            e.sheen:SetColorTexture(1, 1, 1, 0.07)
            e.sheen:SetPoint("TOPLEFT")
            e.sheen:SetPoint("BOTTOMRIGHT", bar, "RIGHT")
            -- the game tints its fill orange as it refreshes the spell: ours after it
            for _, method in ipairs({ "RefreshData", "RefreshIconState" }) do
                if item[method] then hooksecurefunc(item, method, function() cdm.Bar(item) end) end
            end
        end
        cdm.Bar(item)
    end
    Badge(item)
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
    Badge(item)
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
    Badge(item)
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
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, LIST)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, FOOT)
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
    block:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, LIST)
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
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 18, FOOT)
    -- too tall to leave the list its room: the game's scroll after all
    local hb, fb = h:GetBottom(), f:GetBottom()
    if hb and fb and hb - (fb + FOOT) < ROOM then
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

-- --------------------------------------------------------------- dragging
-- The spell under the cursor as it is dragged (CooldownViewerDraggedItem,
-- one frame the game makes on the first drag): a medallion, its rim red
-- where it cannot be dropped. The drop marker: a gold line the length of
-- the spell it falls beside (upright between icons, flat under a bar or a
-- Not displayed line, at the line's top or foot as it will land), red
-- where it cannot go. Their moves and choices stay the game's.
local RED = { 0.86, 0.27, 0.22 }
local dragged

local function Dragged(frame)
    local icon = frame and frame.Icon
    if not icon or deco[frame] then return end
    local d = {}
    deco[frame] = d
    dragged = frame
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if frame.CreateMaskTexture and icon.AddMaskTexture then
        d.mask = frame:CreateMaskTexture()
        d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
        icon:AddMaskTexture(d.mask)
    end
    d.rim = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    d.rim:SetTexture(ROUND)
    d.rim:SetAllPoints(icon)
    d.rim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
end

local function Legal(ok)
    local d = dragged and deco[dragged]
    if d then
        local c = ok and GOLD or RED
        d.rim:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

local function Marker(f)
    local m = f.ReorderMarker or (f.CooldownScroll and f.CooldownScroll.Content.ReorderMarker)
    if not m or deco[m] then return end
    local e = { dir = "v" }
    deco[m] = e
    if m.Texture then m.Texture:SetAlpha(0) end
    e.line = m:CreateTexture(nil, "OVERLAY")
    e.line:SetPoint("CENTER")
    e.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local function Target()
        local t = f.GetReorderTargetItem and f:GetReorderTargetItem()
        return t, t and deco[t] and deco[t].listed
    end
    local function Shape()
        local t, listed = Target()
        if e.dir == "h" or listed then
            e.line:SetSize(t and t:GetWidth() or 300, 2)
        else
            e.line:SetSize(2, t and t:GetHeight() or 38)
        end
    end
    if m.SetHorizontal then hooksecurefunc(m, "SetHorizontal", function() e.dir = "h"; Shape() end) end
    if m.SetVertical then hooksecurefunc(m, "SetVertical", function() e.dir = "v"; Shape() end) end
    if m.SetIsLegalTarget then
        hooksecurefunc(m, "SetIsLegalTarget", function(_, ok)
            local c = ok and GOLD or RED
            e.line:SetColorTexture(c[1], c[2], c[3], 1)
        end)
    end
    -- on a Not displayed line: at its top (before it) or its foot (after),
    -- where the game set it at its left or its right
    local moving = false
    hooksecurefunc(m, "SetPoint", function()
        if moving then return end
        local t, listed = Target()
        if not listed then return end
        local _, _, rp = m:GetPoint(1)
        local before = rp == "LEFT"
        moving = true
        m:ClearAllPoints()
        m:SetPoint("CENTER", t, before and "TOP" or "BOTTOM", 0, before and 1 or -1)
        moving = false
        Shape()
    end)
end

-- ------------------------------------------------------------------ menus
-- The layout and gear menus (the game's shared menus, Blizzard_Menu): an
-- ink panel with a gold edge over their art, their radio and check marks,
-- dividers and hover glow in gold, while ours is open. Their frames and
-- parts are the game's, pooled and lent to every other menu after: each
-- change is noted and undone as ours closes, ours hidden. Fonts and text
-- colours are left (the game sizes each line to its words as it opens; a
-- class colour or a green New Layout is the game's meaning).
local worn = {}                 -- the changes on the open menu, to undo
local panels = {}               -- ours, by the game's menu frame

local function Wear(r, how)
    if how == "hide" then
        table.insert(worn, { r, "alpha", r:GetAlpha() })
        r:SetAlpha(0)
    else
        local vr, vg, vb, va = r:GetVertexColor()
        table.insert(worn, { r, "tint", vr, vg, vb, va, r.IsDesaturated and r:IsDesaturated() })
        if r.SetDesaturated then r:SetDesaturated(true) end
        r:SetVertexColor(how[1], how[2], how[3], how[4] or 1)
    end
end

local function Undo()
    for i = #worn, 1, -1 do
        local w = worn[i]
        local r = w[1]
        if w[2] == "alpha" then
            r:SetAlpha(w[3] or 1)
        else
            r:SetVertexColor(w[3] or 1, w[4] or 1, w[5] or 1, w[6] or 1)
            if r.SetDesaturated then r:SetDesaturated(w[7] and true or false) end
        end
    end
    wipe(worn)
    for _, p in pairs(panels) do p:Hide() end
end

-- a part's look by its art: the marks gold, the glow faint gold, the rule
-- dark gold; anything else (an icon of the game's meaning) left
local function Part(r)
    if not (r.GetObjectType and r:GetObjectType() == "Texture") then return end
    local atlas = r.GetAtlas and r:GetAtlas()
    local file = r.GetTexture and r:GetTexture()
    atlas = type(atlas) == "string" and atlas:lower() or ""
    file = type(file) == "string" and file:lower() or ""
    if atlas:find("tick") or atlas:find("radial") or atlas:find("checkmark") then
        Wear(r, GOLD)
    elseif atlas:find("highlight") or file:find("highlight") then
        Wear(r, { GOLD[1], GOLD[2], GOLD[3], 0.35 })
    elseif file:find("divider") then
        Wear(r, GOLD_D)
    end
end

local function Menu(menu)
    if not menu or not menu.GetRegions then return end
    Undo()
    -- its background (the style's art on the menu itself): under our panel
    for _, r in ipairs({ menu:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then Wear(r, "hide") end
    end
    local p = panels[menu]
    if not p then
        p = CreateFrame("Frame", nil, menu)
        p:SetPoint("TOPLEFT", -2, 2)
        p:SetPoint("BOTTOMRIGHT", 2, 5)
        p:SetFrameLevel(menu:GetFrameLevel())
        local edge = p:CreateTexture(nil, "BACKGROUND", nil, -8)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local well = p:CreateTexture(nil, "BACKGROUND", nil, -7)
        well:SetPoint("TOPLEFT", 1, -1)
        well:SetPoint("BOTTOMRIGHT", -1, 1)
        local ink = ns.colors.ink
        well:SetColorTexture(ink[1], ink[2], ink[3], 0.97)
        panels[menu] = p
    end
    p:Show()
    -- its lines: their marks, rules and glow
    local function Walk(f, depth)
        for _, r in ipairs({ f:GetRegions() }) do Part(r) end
        if f.GetHighlightTexture then
            local h = f:GetHighlightTexture()
            if h then Part(h) end
        end
        if depth < 4 then
            for _, c in ipairs({ f:GetChildren() }) do
                if c ~= p then Walk(c, depth + 1) end
            end
        end
    end
    for _, c in ipairs({ menu:GetChildren() }) do
        if c ~= p then Walk(c, 1) end
    end
end
cdm.Menu = Menu

local function Dropdown(button)
    if not button or deco[button] and deco[button].menu then return end
    local d = deco[button] or {}
    deco[button] = d
    d.menu = true
    if button.OnMenuOpened then hooksecurefunc(button, "OnMenuOpened", function(_, menu) Menu(menu) end) end
    if button.OnMenuClosed then hooksecurefunc(button, "OnMenuClosed", Undo) end
end

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
    Marker(f)
    Dropdown(f.LayoutDropdown)
    Dropdown(f.SettingsDropdown)
    -- the dragged spell's frame, as the game makes it (its mixin's method,
    -- copied into the frame then): ours dressed as it first shows
    local mixin = _G.CooldownViewerDraggedItemBaseMixin
    if mixin and mixin.SetToCursor then
        hooksecurefunc(mixin, "SetToCursor", function(frame) Dragged(frame) end)
    end
    if _G.CooldownViewerDraggedItem_SetIsLegalTarget then
        hooksecurefunc("CooldownViewerDraggedItem_SetIsLegalTarget", Legal)
    end
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
    -- its tooltips beside it, as the LFG window's: the spells' own (the game's
    -- SetOwner, placed again by the shell) and ours
    if ns.window.Mark then ns.window.Mark(f, -1) end
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
