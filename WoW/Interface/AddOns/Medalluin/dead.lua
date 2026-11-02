-- A dead friend's frame: the dead colour over the whole button (its power
-- is empty), darkening to its edges inside a thin gold line, and a stack in
-- its middle: the wings (the resurrect icon), how long it has been dead,
-- its name. The player's frame, the console's party, the party widget and
-- the raid cells have it (ns.DeadLook); a dead enemy keeps its grey bar.
-- One colour for all of them (General > Appearance). The time counts from
-- when Medalluin first saw the death, so a reload starts it again.
local _, ns = ...

local EDGE = 6                     -- how far in the edges darken
local LINE = { 0.54, 0.44, 0.20 }  -- the gold line, the console's dark gold

local looks = {}  -- every look, shown or not: a recolour reaches them all
local shown = {}  -- looks on show, for the clock
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

local clock = CreateFrame("Frame")
clock:Hide()
local wait = 0
clock:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.25
    local now = GetTime()
    for o in pairs(shown) do o.timer:SetText(Clock(now - (since[o.key] or now))) end
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
    t:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
    t:SetPoint(from, o, from, from:match("LEFT") and 1 or -1, from:match("TOP") and -1 or 1)
    t:SetPoint(to, o, to, to:match("LEFT") and 1 or -1, to:match("TOP") and -1 or 1)
    if horizontal then t:SetHeight(1) else t:SetWidth(1) end
end

-- The look on button b, hidden until its unit dies.
function ns.DeadLook(b)
    local o = CreateFrame("Frame", nil, b)
    o:SetAllPoints(b)
    o:Hide()
    o.fill = o:CreateTexture(nil, "BACKGROUND")
    o.fill:SetAllPoints()
    Colour(o)
    Shade(o, "TOPLEFT", "TOPRIGHT", "VERTICAL", false)
    Shade(o, "BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true)
    Shade(o, "TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true)
    Shade(o, "TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false)
    Line(o, "TOPLEFT", "TOPRIGHT", true)
    Line(o, "BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line(o, "TOPLEFT", "BOTTOMLEFT", false)
    Line(o, "TOPRIGHT", "BOTTOMRIGHT", false)
    -- the stack, hung from the timer in the middle
    o.timer = ns.Text(o, 9)
    o.timer:SetTextColor(0.82, 0.80, 0.74)
    o.wings = o:CreateTexture(nil, "OVERLAY")
    o.wings:SetTexture(ns.media .. "dead-wings")
    o.wings:SetPoint("BOTTOM", o.timer, "TOP", 0, 0)
    o.name = ns.Text(o, 10)
    o.name:SetPoint("TOP", o.timer, "BOTTOM", 0, 0)
    o.name:SetWordWrap(false)
    b.dead = o
    looks[o] = true
    return o
end

-- The stack's sizes by the button's height: a raid cell, a party window or
-- widget cell, the player's frame.
local SIZES = { { 50, 20, 11, 13 }, { 40, 18, 10, 11 }, { 0, 14, 8, 10 } }

local function Fit(o, b)
    local h = b:GetHeight() or 0
    if ns.IsSecret(h) then h = 0 end
    local icon, timer, name = 14, 8, 10
    for _, s in ipairs(SIZES) do
        if h >= s[1] then icon, timer, name = s[2], s[3], s[4]; break end
    end
    o.wings:SetSize(icon, icon)
    o.timer:SetFont(ns.font, timer, "")
    o.name:SetFont(ns.font, name, "")
    -- the timer a little low, so the stack (icon over, name under) centres
    o.timer:ClearAllPoints()
    o.timer:SetPoint("CENTER", o, "CENTER", 0, math.floor((name + 2 - icon) / 2))
    local w = b:GetWidth() or 0
    if not ns.IsSecret(w) then o.name:SetWidth(math.max(20, w - 8)) end
end

-- Show or hide b's look. Its own texts give way while it shows.
function ns.ShowDead(b, dead)
    local o = b.dead
    if not o then return end
    if not dead then
        if o:IsShown() then
            -- the death is over only if this is still its unit: a raid
            -- cell handed to another member leaves its time to the others
            if Key(b) == o.key then since[o.key] = nil end
            shown[o] = nil
            o:Hide()
        end
        if b.text then b.text:SetAlpha(1) end
        return
    end
    o.key = Key(b)
    since[o.key] = since[o.key] or GetTime()
    o:SetFrameLevel(math.max(b.health:GetFrameLevel(), b.power:GetFrameLevel()) + 1)
    Fit(o, b)
    o.name:SetText(b.name:GetText())
    o.timer:SetText(Clock(GetTime() - since[o.key]))
    o:Show()
    if b.text then b.text:SetAlpha(0) end
    shown[o] = true
    clock:Show()
end

ns.OnSetting("deadColor", function()
    for o in pairs(looks) do Colour(o) end
end)
