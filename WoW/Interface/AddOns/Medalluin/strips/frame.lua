-- The corner strips: one along each bottom corner of the screen, the right
-- one the left one's mirror. Each ends in a medallion at the outer corner:
-- the character portrait on the left, the backpack on the right. What sits
-- in a medallion's well is drawn BELOW the art; what sits on the strip (the
-- glyph buttons, the stats) is drawn above it.
--
--   console base + 1   the strip frames
--   console base + 2   the medallion buttons (portrait, backpack)
--   console base + 6   the strip art
--   console base + 8   glyph buttons, stats
local _, ns = ...

local art, L = ns.stripArt, ns.stripLayout
local console = ns.console
local base = console:GetFrameLevel()
ns.levels.strip = base + 1
ns.levels.stripWell = base + 2
ns.levels.stripArt = base + 6
ns.levels.stripTop = base + 8

-- Children of the console so they share its scale; anchored to the screen's
-- corners, not to the console.
ns.strips = {}
for _, side in ipairs({ -1, 1 }) do
    local f = CreateFrame("Frame", side < 0 and "MedalluinStripLeft" or "MedalluinStripRight", console)
    f:SetSize(art.width, art.height)
    f:SetPoint(side < 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", UIParent)
    f:SetFrameLevel(ns.levels.strip)
    f.side = side

    local artFrame = CreateFrame("Frame", nil, f)
    artFrame:SetAllPoints()
    artFrame:SetFrameLevel(ns.levels.stripArt)
    local tex = artFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(ns.media .. "strip")
    f.art = artFrame
    local u, v = art.width / art.texWidth, art.height / art.texHeight
    if side < 0 then tex:SetTexCoord(0, u, 0, v) else tex:SetTexCoord(u, 0, 0, v) end

    ns.strips[side] = f
end

-- Place a region on a strip by its centre: x from the screen edge (the outer
-- end), y from the art's top.
function ns.OnStrip(region, side, x, y, w, h)
    local strip = ns.strips[side]
    region:ClearAllPoints()
    region:SetPoint("CENTER", strip, side < 0 and "TOPLEFT" or "TOPRIGHT", -side * x, -y)
    if w then region:SetSize(w, h) end
end

-- The medallion's well, and the strip's middle row (where glyphs and stats sit).
local well = ns.stripWindows.well
ns.stripWell = { x = (well[1] + well[2]) / 2, y = (well[3] + well[4]) / 2, size = well[2] - well[1] }
ns.stripRow = art.height - L.stripHeight / 2 + L.glyphDrop

-- The strip's row as keys (2026-11-10, mockup B of /workspace/strips-mockups.png;
-- were joined boxed cells): a dark channel sunk in the strip from 2 short
-- of `from` (5 short of the medallion's ring, as a window's flush band) to
-- 2 short of the strip's top inner corner, KEY.channel tall; in it, raised
-- keys KEY.gap apart, KEY.inset inside the channel, each a brown well
-- lighter at its top, a dark gold edge (gold under the mouse) and a lit
-- lip along its top.
local GOLD_D = { 0.541, 0.439, 0.204 }
local GOLD = { 0.769, 0.647, 0.341 }
local KEY = { channel = 26, inset = 3, gap = 3, top = { 0.341, 0.286, 0.165 }, bottom = { 0.141, 0.114, 0.055 } }
local cells = { from = ns.stripWell.x + L.ringRadius + 5, to = L.length,
    y = art.height - L.stripHeight / 2, height = L.stripHeight }
ns.stripCells = cells

for _, side in ipairs({ -1, 1 }) do
    local strip = ns.strips[side]
    local channel = strip.art:CreateTexture(nil, "OVERLAY")
    channel:SetColorTexture(0.051, 0.043, 0.027, 0.65)
    ns.OnStrip(channel, side, (cells.from + cells.to) / 2 - 2, cells.y, cells.to - cells.from, KEY.channel)
    strip.channel = channel
end

local function Edges(b)
    local out = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" } }) do
        local t = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        t[e[3]](t, 1)
        table.insert(out, t)
    end
    return out
end

local function Lit(b, on)
    local c = on and GOLD or GOLD_D
    for _, t in ipairs(b.cell.edge) do t:SetColorTexture(c[1], c[2], c[3], 1) end
end

-- A key on b (its own textures, under whatever b draws): its well, edges
-- and lip, a glow and a gold edge under the mouse.
function ns.StripCell(b)
    local fill = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    local t, f = KEY.top, KEY.bottom
    if fill.SetGradient and CreateColor then
        fill:SetColorTexture(1, 1, 1, 1)
        fill:SetGradient("VERTICAL", CreateColor(f[1], f[2], f[3], 1), CreateColor(t[1], t[2], t[3], 1))
    else
        fill:SetColorTexture((t[1] + f[1]) / 2, (t[2] + f[2]) / 2, (t[3] + f[3]) / 2, 1)
    end
    local edge = Edges(b)
    local lip = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    lip:SetColorTexture(1, 0.95, 0.78, 0.22)
    lip:SetPoint("TOPLEFT", 3, -2)
    lip:SetPoint("TOPRIGHT", -3, -2)
    lip:SetHeight(1)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.08)
    b.cell = { fill = fill, edge = edge, lip = lip, glow = glow }
    b:HookScript("OnEnter", function(self) Lit(self, true) end)
    b:HookScript("OnLeave", function(self) Lit(self, false) end)
end

-- Lay the keys out along the side's channel, from the medallion outward
-- (inward, toward the console), sharing its width less their gaps; a key
-- with a share (default 1) takes that many parts of it.
function ns.StripCells(side, list)
    local n = #list
    if n == 0 then return end
    local x = cells.from - 2 + KEY.inset                 -- the channel's start, inset
    local total = cells.to - cells.from - 2 * KEY.inset - (n - 1) * KEY.gap
    local h = KEY.channel - 2 * KEY.inset
    local parts, upto = 0, 0
    for _, f in ipairs(list) do parts = parts + (f.share or 1) end
    for _, f in ipairs(list) do
        local before = upto
        upto = upto + (f.share or 1)
        local w = math.floor(upto * total / parts) - math.floor(before * total / parts)
        ns.OnStrip(f, side, x + w / 2, cells.y, w, h)
        x = x + w + KEY.gap
    end
end

-- A round hover glow for a medallion button.
function ns.RoundGlow(btn, r, g, b, a)
    local t = btn:CreateTexture()
    t:SetTexture(ns.media .. "strips\\round")
    t:SetVertexColor(r, g, b)
    t:SetAlpha(a)
    t:SetBlendMode("ADD")
    t:SetAllPoints()
    return t
end

-- An empty texture, for the button states a medallion does not draw.
function ns.Blank(btn)
    local t = btn:CreateTexture()
    t:SetColorTexture(0, 0, 0, 0)
    return t
end
