-- Blizzard's own windows in Medalluin's look: the pieces the Cooldown
-- Manager (cooldowns/window.lua) and Click Casting (spells/clickcast.lua)
-- share. Each dresses a game window that keeps every click, menu and save
-- its own: its art hidden with alpha (or hidden outright where it is art),
-- ours drawn beside it and kept in one side table by frame (deco), never
-- as fields on the game's frames.
--
--   R.Bare(f)                every texture of f put away, once
--   R.Box(f, fill)           an ink well and a gold edge (four lines) on f
--   R.Edge(d, color)         that edge's colour
--   R.Glyph(f, name, size)   a gold strip glyph at f's centre
--   R.Font(fs, size, color)  our font, shadowed
--   R.Lit(f)                 its box's edge (and glyph) lit under the mouse
--   R.Plain(b)               a button's own states' art put away
--   R.Divider(skin, f, key, point, x, y)  a gold divider the cells' height
--   R.Medal(owner, icon, inset)           an icon round in a gold rim
--   R.Chrome(f, title, rules, hairAt)     the frame's art gone, ours under it
--   R.Place(f)               where the LFG window stands, and kept there
--   R.Stand(f, who, shown)   the spot's rules (one window there at a time)
--   R.Dropdown(button)       its menu (the game's shared one) dressed while open
local _, ns = ...

local R = {}
ns.reskin = R

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD = 12
local ROW = 28                      -- the cells' height, as the chat's tabs (strips/chat.lua)
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local ROUND = ns.media .. "strips\\round"
local GLYPHS = ns.media .. "strips\\"

R.PAD, R.ROW, R.GAP, R.EDGE = PAD, ROW, 4, 3
R.GOLD, R.GOLD_D, R.DIM, R.ROUND, R.GLYPHS = GOLD, GOLD_D, DIM, ROUND, GLYPHS

local deco = {}         -- our dress, by the game's frame
R.deco = deco

-- ---------------------------------------------------------------- pieces
function R.Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.5)
    end
end

-- Every texture of a frame put away (its art), fonts kept: once, as first
-- met, so ours drawn on it after stay
function R.Bare(f)
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
function R.Edge(d, c)
    for _, t in ipairs(d.edges) do t:SetColorTexture(c[1], c[2], c[3], 1) end
end

function R.Box(f, fill)
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
    R.Edge(d, GOLD_D)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    local ink = ns.colors.ink
    well:SetColorTexture(ink[1], ink[2], ink[3], fill or 0.92)
    d.well = well
    return d
end

function R.Glyph(f, name, size)
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

function R.Font(fs, size, color)
    if not fs then return end
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- Its controls' box faces: the edge lit under the mouse
function R.Lit(f)
    local d = deco[f]
    if not d or d.lit then return end
    d.lit = true
    f:HookScript("OnEnter", function()
        R.Edge(d, GOLD)
        if d.glyph then d.glyph:SetVertexColor(1, 1, 1) end
    end)
    f:HookScript("OnLeave", function()
        R.Edge(d, GOLD_D)
        if d.glyph then
            local on = not f.IsEnabled or f:IsEnabled()
            local c = on and GOLD or DIM
            d.glyph:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        end
    end)
end

-- a button's own states' art (normal, pushed, lit, disabled): put away
function R.Plain(b)
    R.Bare(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
end

-- A divider between two cells: gold, the row's height (the chat's, before
-- its cog), drawn on our skin beside f
function R.Divider(skin, f, key, point, x, y)
    local fd = deco[f] or {}
    deco[f] = fd
    if not fd[key] and skin then
        fd[key] = skin:CreateTexture(nil, "ARTWORK")
        fd[key]:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        fd[key]:SetSize(1, ROW)
        fd[key]:SetPoint(point, f, point, x, y)
    end
end

-- An icon as a medallion: its square border cut off (once, before the
-- mask: the game refuses tex coords after), masked round (inset from its
-- edge), a thin gold ring round an ink well under it. Returns its dress.
function R.Medal(owner, icon, inset)
    local d = deco[owner] or {}
    deco[owner] = d
    if d.rim then return d end
    inset = inset or 3
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if owner.CreateMaskTexture and icon.AddMaskTexture then
        d.mask = owner:CreateMaskTexture()
        d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
        d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
        icon:AddMaskTexture(d.mask)
    end
    d.rim = owner:CreateTexture(nil, "BACKGROUND", nil, -6)
    d.rim:SetTexture(ROUND)
    d.rim:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    d.rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    d.well = owner:CreateTexture(nil, "BACKGROUND", nil, -5)
    d.well:SetTexture(ROUND)
    d.well:SetPoint("TOPLEFT", icon, "TOPLEFT", 1.5, -1.5)
    d.well:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1.5, 1.5)
    local ink = ns.colors.ink
    d.well:SetVertexColor(ink[1], ink[2], ink[3], 1)
    return d
end

-- ---------------------------------------------------------------- the frame
-- The game's frame art gone, ours (the windows' Dress) under its content:
-- the title in gold, a hair and a fainter one under the head at hairAt,
-- gold rules edge to edge at rules ({ "TOP" | "BOTTOM", y }: the cell
-- rows' lines, the chat's tab row's hairline), our close glyph on its
-- close button (its click the game's). Returns the skin.
function R.Chrome(f, title, rules, hairAt)
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
    local skin = CreateFrame("Frame", nil, f)
    skin:SetAllPoints()
    skin:SetFrameLevel(f:GetFrameLevel())       -- under its content, over its own art
    local dress = ns.window.Dress(skin, 0)
    if dress.rule then dress.rule:Hide() end
    skin.title = ns.Text(skin, 16)
    skin.title:SetPoint("TOPLEFT", PAD + 2, -12)
    skin.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    skin.title:SetText(title)
    local hair = ns.window.Hair(skin)
    hair:SetPoint("TOPLEFT", PAD, -hairAt)
    hair:SetPoint("TOPRIGHT", -PAD, -hairAt)
    local faint = ns.window.Hair(skin, false, 0.5)
    faint:SetPoint("TOPLEFT", PAD + 30, -(hairAt + 3))
    faint:SetPoint("TOPRIGHT", -PAD - 30, -(hairAt + 3))
    for _, at in ipairs(rules or {}) do
        local rule = skin:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(at[1] .. "LEFT", 1, at[2])
        rule:SetPoint(at[1] .. "RIGHT", -1, at[2])
    end
    local close = f.CloseButton
    if close then
        R.Bare(close)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local t = close[get] and close[get](close)
            if t then t:SetAlpha(0) end
        end
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -PAD, -6)
        close:SetSize(26, 26)
        local g = R.Glyph(close, "close", 16)
        close:HookScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
        close:HookScript("OnLeave", function() g:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
    end
    return skin
end

-- --------------------------------------------------------------- the place
-- Where the LFG window stands: its box (built or not shown) when there is
-- one, else the chat box's top to the screen's
local placing = false
function R.Place(f)
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

-- its own place, whenever the panel manager or the game moves it: ours
function R.Hold(f, place)
    place = place or function() R.Place(f) end
    hooksecurefunc(f, "SetPoint", function()
        if not placing then ns.OutOfCombat(place) end
    end)
end

-- ---------------------------------------------------------------- the spot
-- The LFG window's place holds one window at a time: each of ours there
-- closes the others as it opens (the LFG window too), and the LFG window,
-- an NPC window or the character window opening closes it. While it is
-- open the chat holds still and the quest tracker steps aside; its
-- tooltips stand beside it. shown: run first as it shows (its place, its
-- dress).
local spot = {}

local function Close(f)
    if f:IsShown() then
        if HideUIPanel then HideUIPanel(f) else f:Hide() end
    end
end

function R.Stand(f, who, shown)
    table.insert(spot, f)
    f:HookScript("OnShow", function()
        if shown then shown() end
        if ns.chat then ns.chat.Hold(true, who) end
        -- the LFG window and the others share the place: closed
        if ns.lfg and ns.lfg.IsShown and ns.lfg.IsShown() then ns.lfg.Close() end
        for _, other in ipairs(spot) do
            if other ~= f then Close(other) end
        end
    end)
    f:HookScript("OnHide", function()
        if ns.chat then ns.chat.Hold(false, who) end
    end)
    if ns.quests and ns.quests.Cover then ns.quests.Cover(f) end
    -- its tooltips beside it, as the LFG window's: the game's own (its
    -- SetOwner, placed again by the shell) and ours
    if ns.window.Mark then ns.window.Mark(f, -1) end
    -- the LFG window and an NPC window opening close it: the last opened wins
    local function CloseOurs() Close(f) end
    if ns.lfg and ns.lfg.box then ns.lfg.box:HookScript("OnShow", CloseOurs) end
    if ns.npc and ns.npc.box then ns.npc.box:HookScript("OnShow", CloseOurs) end
    if ns.character and ns.character.window then ns.character.window:HookScript("OnShow", CloseOurs) end
end

-- ------------------------------------------------------------------ menus
-- A dropdown's menu (the game's shared menus, Blizzard_Menu): an ink panel
-- with a gold edge over their art, their radio and check marks, dividers
-- and hover glow in gold, while ours is open. Their frames and parts are
-- the game's, pooled and lent to every other menu after: each change is
-- noted and undone as ours closes, ours hidden. Fonts and text colours are
-- left (the game sizes each line to its words as it opens; a class colour
-- or a green New Layout is the game's meaning).
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

function R.Menu(menu)
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
R.Undo = Undo

function R.Dropdown(button)
    if not button or deco[button] and deco[button].menu then return end
    local d = deco[button] or {}
    deco[button] = d
    d.menu = true
    if button.OnMenuOpened then hooksecurefunc(button, "OnMenuOpened", function(_, menu) R.Menu(menu) end) end
    if button.OnMenuClosed then hooksecurefunc(button, "OnMenuClosed", Undo) end
end
