-- What the art cannot say about itself: how each window splits into bars and
-- where its text goes. Window rectangles live in windows.lua (generated).
-- Units are art pixels; the console is scaled so the art keeps its 1080p
-- proportion of the screen (pixel-exact at 1080p).
local _, ns = ...

ns.layout = {
    designHeight = 1080,

    -- Player and target: power on top, health below.
    unit = { power = 12, seam = 0, nameSize = 16, valueSize = 13, powerSize = 10,
             -- the window's inner end is cut at 45 degrees; keep text on
             -- the part of the health bar that stays visible
             textInset = 10, valueInset = 50 },

    -- Party: mirrored across the beam, so health on top and power below.
    party = { power = 9, seam = 0, nameSize = 12, textInset = 8 },

    -- The minimap is a little larger than the ring's hole so its edge
    -- tucks under the gold.
    minimapBleed = 2,
}

-- Slots, as (window, side): side -1 is the left copy, 1 the right. party1
-- and party2 take the inner pair so a small group stays near the centre.
ns.slots = {
    player = { "unit", -1 },
    target = { "unit", 1 },
    party1 = { "party1", -1 },
    party2 = { "party1", 1 },
    party3 = { "party2", -1 },
    party4 = { "party2", 1 },
}

-- A window on one side as (x from the centre line, y from the top, w, h).
function ns.Rect(name, side)
    local w = ns.windows[name]
    local inner, outer, top, bottom = w[1], w[2], w[3], w[4]
    local x = side == 1 and inner or -outer
    return x, top, outer - inner, bottom - top
end

-- Art pixels a window's contents reach under the art above and below the
-- hole. The console is scaled by a non-integer factor, so the art's hole and
-- a frame of exactly its size round to different screen rows: at 1.35 the
-- beam sat one row below its hole and the world showed through between the
-- unit frames and the experience/reputation halves. Everything placed on a
-- bled window is below the art (ns.levels), so the art clips the overhang.
-- Only vertical: a horizontal overhang would hide the first and last of the
-- fill.
ns.windowBleed = { xp = 1 }

-- Anchor a region over a window of the console.
function ns.PlaceOn(region, console, name, side)
    local x, y, w, h = ns.Rect(name, side)
    local bleed = ns.windowBleed[name] or 0
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", console, "TOP", x, -(y - bleed))
    region:SetSize(w, h + 2 * bleed)
end
