-- A dead or offline friend's frame: a textured bar over the whole button
-- (its power is empty), darkening to its edges inside a thin border line,
-- and a two-row stack in its middle:
--   Dead:     [Icon] [Time]  over  [Name]   (dead-wings, dead-bar)
--   Offline:     [Icon]      over  [Name]   (disconnected, offline-bar)
-- The player's frame, the console's party, the party widget and the raid
-- cells have it (ns.DeadLook); a dead enemy keeps its grey bar. One base
-- colour for all of them (General). The time counts from when
-- Medalluin first saw the death, so a reload starts it again.
local _, ns = ...

local EDGE = 6                                -- how far in the edges darken
local ROW_GAP, COL_GAP = 2, 4                 -- between the two rows, and between icon and timer
local TEX_W, TEX_H = 512, 128                 -- dead-bar.tga and offline-bar.tga
local LINES = {
    dead = { 0.54, 0.44, 0.20 },              -- the console's dark gold
    offline = { 0.46, 0.52, 0.60 },           -- cool silver-steel
}
local NAMES = {
    dead = ns.colors.text,
    offline = { 0.80, 0.84, 0.90 },
}

local looks = {}  -- every look, shown or not: a recolour reaches them all
local shown = {}  -- dead looks on show, for the clock
local since = {}  -- when each death was first seen, by unit (see Key)

-- A unit's death, kept across the buttons that show it: by GUID, or by its
-- unit where the game keeps the GUID secret; a simulated one by its stub.
local function Key(b)
    if b.stub then return b.stub end
    local guid = UnitGUID and UnitGUID(b.unit)
    if guid ~= nil and not ns.IsSecret(guid) then return guid end
    return b.unit
end

local function Clock(s)
    s = math.max(0, math.floor(s))
    if s >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
    end
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-- Place the icon on the top row: centred alone while offline, or shifted left
-- of the centre while dead so [Icon] [Time] sit centred together.
local function PlaceIcon(o)
    local y = math.floor(((o.nameSize or 10) + ROW_GAP) / 2)
    local x = 0
    if o.state == "dead" then
        local tw = o.timer:GetStringWidth() or 0
        if ns.IsSecret(tw) then tw = 24 end
        x = -math.floor((tw + COL_GAP) / 2)
    end
    o.wings:ClearAllPoints()
    o.wings:SetPoint("CENTER", o, "CENTER", x, y)
end

local clock = CreateFrame("Frame")
clock:Hide()
local wait = 0
clock:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.25
    local now = GetTime()
    for o in pairs(shown) do
        o.timer:SetText(Clock(now - (since[o.key] or now)))
        PlaceIcon(o)
    end
    if not next(shown) then self:Hide() end
end)
ns.deadClock = clock

local function Colour(o)
    local r, g, b = ns.HexColor(ns.db and ns.db.deadColor)
    o.fill:SetColorTexture(r, g, b, 1)
end

-- One edge's shade, dark at the edge and clear inward; a flat shade where
-- the client has no colour gradients.
local function Shade(o, from, to, orient, darkFirst)
    local t = o:CreateTexture(nil, "BORDER")
    t:SetPoint(from)
    t:SetPoint(to)
    if orient == "HORIZONTAL" then t:SetWidth(EDGE) else t:SetHeight(EDGE) end
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        local dark, clear = CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0)
        t:SetGradient(orient, darkFirst and dark or clear, darkFirst and clear or dark)
    else
        t:SetColorTexture(0, 0, 0, 0.2)
    end
end

local function Line(o, from, to, horizontal)
    local t = o:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(LINES.dead[1], LINES.dead[2], LINES.dead[3], 1)
    t:SetPoint(from, o, from, from:match("LEFT") and 1 or -1, from:match("TOP") and -1 or 1)
    t:SetPoint(to, o, to, to:match("LEFT") and 1 or -1, to:match("TOP") and -1 or 1)
    if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    return t
end

-- The look on button b, hidden until its unit dies or disconnects.
function ns.DeadLook(b)
    local o = CreateFrame("Frame", nil, b)
    o:SetAllPoints(b)
    o:Hide()
    o.fill = o:CreateTexture(nil, "BACKGROUND", nil, 0)
    o.fill:SetAllPoints()
    Colour(o)
    o.tex = o:CreateTexture(nil, "BACKGROUND", nil, 1)
    o.tex:SetAllPoints()
    o.tex:SetTexture(ns.media .. "dead-bar")
    Shade(o, "TOPLEFT", "TOPRIGHT", "VERTICAL", false)
    Shade(o, "BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true)
    Shade(o, "TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true)
    Shade(o, "TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false)
    o.lines = {
        Line(o, "TOPLEFT", "TOPRIGHT", true),
        Line(o, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        Line(o, "TOPLEFT", "BOTTOMLEFT", false),
        Line(o, "TOPRIGHT", "BOTTOMRIGHT", false),
    }
    -- two-row stack: [Icon] (or [Icon] [Time]) on top, [Name] under it
    o.wings = o:CreateTexture(nil, "OVERLAY")
    o.wings:SetTexture(ns.media .. "dead-wings")
    o.timer = ns.Text(o, 9)
    o.timer:SetTextColor(0.88, 0.85, 0.78)
    o.timer:SetPoint("LEFT", o.wings, "RIGHT", COL_GAP, 0)
    o.name = ns.Text(o, 10)
    o.name:SetWordWrap(false)
    b.dead = o
    looks[o] = true
    return o
end

-- The stack's sizes by the button's height: a raid cell, a party window or
-- widget cell, the player's frame.
local SIZES = { { 50, 20, 11, 13 }, { 40, 18, 10, 11 }, { 0, 16, 9, 10 } }

local function Fit(o, b)
    local h = b:GetHeight() or 0
    if ns.IsSecret(h) then h = 0 end
    local icon, timer, name = 16, 9, 10
    for _, s in ipairs(SIZES) do
        if h >= s[1] then icon, timer, name = s[2], s[3], s[4]; break end
    end
    o.nameSize = name
    o.wings:SetSize(icon, icon)
    o.timer:SetFont(ns.font, timer, "")
    o.name:SetFont(ns.font, name, "")
    o.name:ClearAllPoints()
    o.name:SetPoint("CENTER", o, "CENTER", 0, -math.floor((icon + ROW_GAP) / 2))
    PlaceIcon(o)
    local w = b:GetWidth() or 0
    if ns.IsSecret(w) then w = 0 end
    if w > 0 then o.name:SetWidth(math.max(20, w - 8)) end
    local tw = w > 0 and w or 128
    local th = h > 0 and h or 40
    o.tex:SetTexCoord(0, math.min(1, tw / TEX_W), 0, math.min(1, th / TEX_H))
end

-- Show or hide b's look ("dead"/true, "offline", or false/nil). Its own
-- texts give way while it shows.
function ns.ShowDead(b, state)
    local o = b.dead
    if not o then return end
    if state == true then state = "dead" end
    if state ~= "dead" and state ~= "offline" then state = nil end
    local was = o.state
    if not state then
        if o:IsShown() then
            -- the death is over only if this is still its unit: a raid
            -- cell handed to another member leaves its time to the others
            if Key(b) == o.key then since[o.key] = nil end
            shown[o] = nil
            o.state = nil
            o:Hide()
            if not next(shown) then clock:Hide() end
        end
        if b.text then b.text:SetAlpha(1) end
        if b.powerValue then b.powerValue:SetAlpha(1) end
        if was and ns.UpdateUnitAuras then ns.UpdateUnitAuras(b) end
        return
    end
    o.state = state
    local line = LINES[state]
    for _, t in ipairs(o.lines) do t:SetColorTexture(line[1], line[2], line[3], 1) end
    o.name:SetTextColor(unpack(NAMES[state]))
    if state == "dead" then
        o.key = Key(b)
        since[o.key] = since[o.key] or GetTime()
        o.tex:SetTexture(ns.media .. "dead-bar")
        o.wings:SetTexture(ns.media .. "dead-wings")
        o.timer:SetText(Clock(GetTime() - since[o.key]))
        o.timer:Show()
        shown[o] = true
        clock:Show()
    else
        shown[o] = nil
        if not next(shown) then clock:Hide() end
        o.tex:SetTexture(ns.media .. "offline-bar")
        o.wings:SetTexture(ns.media .. "disconnected")
        o.timer:Hide()
    end
    o:SetFrameLevel(math.max(b.health:GetFrameLevel(), b.power:GetFrameLevel()) + 1)
    Fit(o, b)
    o.name:SetText(b.name:GetText())
    o:Show()
    if b.text then b.text:SetAlpha(0) end
    if b.powerValue then b.powerValue:SetAlpha(0) end
    if was ~= state and ns.UpdateUnitAuras then ns.UpdateUnitAuras(b) end
end

ns.OnSetting("deadColor", function()
    for o in pairs(looks) do Colour(o) end
end)
