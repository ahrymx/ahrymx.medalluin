-- The corner strips: one along each bottom corner of the screen, the right
-- one the left one's mirror. Each ends in a medallion at the outer corner:
-- the character portrait on the left, the backpack on the right. What sits
-- in a medallion's well is drawn BELOW the art; what sits on the strip (the
-- glyph buttons, the stats) is drawn above it.
--
--   console base + 1   the strip frames
--   console base + 2   the medallion buttons (portrait, backpack)
--   console base + 6   the strip art
--   console base + 8   glyph buttons, stats, the bag drawer
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
    local f = CreateFrame("Frame", side < 0 and "MedaluinStripLeft" or "MedaluinStripRight", console)
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
