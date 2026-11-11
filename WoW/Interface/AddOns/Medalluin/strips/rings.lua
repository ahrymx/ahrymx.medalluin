-- The gauges round the medallions (2026-11-10, mockup A of
-- /workspace/rings-mockups.png): an arc on a medallion's border, from 7
-- o'clock clockwise round to 5 (mirrored on the right), on a dark track
-- all the way round; green, amber or red by how well things stand. The
-- numbers are in the medallion's tooltip (strips/status.lua). The arcs are
-- frames of one atlas (art/strips/gen_strips.py, rings), drawn on the
-- strip's art frame, over the gold ring and under the strip's keys.
local _, ns = ...

local STEPS, COLS, ROWS = 32, 8, 4               -- the atlas: frame k spans k/STEPS of the arc
local BOX = 64                                   -- the arc's box, art px, centred on the well
local GREEN, AMBER, RED = { 0.373, 0.749, 0.29 }, { 0.851, 0.627, 0.188 }, { 0.847, 0.267, 0.18 }

local function Colour(v)
    return v > 0.5 and GREEN or v > 0.2 and AMBER or RED
end

-- Frame k of the atlas, flipped for the right strip.
local function Frame(tex, k, side)
    local l, t = ((k - 1) % COLS) / COLS, math.floor((k - 1) / COLS) / ROWS
    local r, b = l + 1 / COLS, t + 1 / ROWS
    if side < 0 then tex:SetTexCoord(l, r, t, b) else tex:SetTexCoord(r, l, t, b) end
end

local function Set(ring, frac, v)
    frac = math.max(0, math.min(1, frac))
    local k = math.floor(frac * STEPS + 0.5)
    local c = Colour(v)
    ring.k, ring.color = k, c
    if k > 0 then Frame(ring.arc, k, ring.side) end
    ring.arc:SetShown(k > 0)
    ring.arc:SetVertexColor(c[1], c[2], c[3])
end

-- A gauge round side's medallion. ring:Set(frac, v): frac how much of the
-- arc, v how well (its colour).
function ns.Ring(side)
    local strip = ns.strips[side]
    local w = ns.stripWell
    local ring = { side = side, Set = Set }
    local track = strip.art:CreateTexture(nil, "OVERLAY", nil, 1)
    track:SetTexture(ns.media .. "strips\\ring-track")
    if side > 0 then track:SetTexCoord(1, 0, 0, 1) end
    ns.OnStrip(track, side, w.x, w.y, BOX, BOX)
    local arc = strip.art:CreateTexture(nil, "OVERLAY", nil, 2)
    arc:SetTexture(ns.media .. "strips\\ring-arc")
    ns.OnStrip(arc, side, w.x, w.y, BOX, BOX)
    ring.track, ring.arc = track, arc
    return ring
end
