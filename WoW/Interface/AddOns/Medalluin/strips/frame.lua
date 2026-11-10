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

-- The strip's row as joined cells, as a window's tabs (window/shell.lua):
-- from 5 short of the medallion's ring (as a window's flush band) to the
-- strip's top inner corner, the row's full height, its top edge the
-- strip's, each cell boxed in dark gold over the strip's own brown and
-- neighbours sharing an edge.
local GOLD_D = { 0.541, 0.439, 0.204 }
local cells = { from = ns.stripWell.x + L.ringRadius + 5, to = L.length,
    y = art.height - L.stripHeight / 2, height = L.stripHeight }
ns.stripCells = cells

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

-- A cell's box on b (its own textures, under whatever b draws): its four
-- edges, a glow under the mouse.
function ns.StripCell(b)
    local edge = Edges(b)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.08)
    b.cell = { edge = edge, glow = glow }
end

-- Lay the frames out along the side's row, from the medallion outward
-- (inward, toward the console), sharing the row's width.
function ns.StripCells(side, list)
    local n = #list
    if n == 0 then return end
    local total = cells.to - cells.from + (n - 1)       -- the shared edges given back
    local x = cells.from
    for i, f in ipairs(list) do
        local w = math.floor(i * total / n) - math.floor((i - 1) * total / n)
        ns.OnStrip(f, side, x + w / 2, cells.y, w, cells.height)
        x = x + w - 1
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
