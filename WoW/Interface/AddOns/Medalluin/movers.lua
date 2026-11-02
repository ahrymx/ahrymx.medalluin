-- Moving and scaling the two consoles: the console at the bottom and the
-- overhead at the top. One saved place per console, per profile (settings.lua:
-- <console>Scale, <console>X, <console>Y), read by console/frame.lua's and
-- console/overhead.lua's placement. Two doors onto it:
--
--   Edit Mode   while Blizzard's Edit Mode is open, each console wears a
--               mover: drag it anywhere; click it for its scale and place.
--               Without a client Edit Mode (Classic Era), /mdlui move.
--   the window  Console > Position: the same values as sliders, and Reset.
--
-- The movers are Medalluin's own frames, shown on Edit Mode's EventRegistry
-- events. They are never registered with Edit Mode: an addon's frame in its
-- system list would taint Blizzard's own bars when it saves a layout.
-- The consoles hold secure buttons, so they move only out of combat; a drag
-- in combat waits for it to end (ns.OutOfCombat, in the placement).
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors

-- How far an offset reaches: past the screen's half-width either way, and up
-- or down by most of its height. In design units (a 1080-high screen).
local REACH_X, REACH_Y = 1000, 1000
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 1.5, 0.05

local CONSOLES = {
    {
        id = "console", name = "Console",
        frame = function() return ns.console end,
        place = function() if ns.PlaceConsole then ns.PlaceConsole() end end,
        -- the bottom console rises from the screen's foot
        minY = -200, maxY = REACH_Y,
    },
    {
        id = "overhead", name = "Overhead",
        frame = function() return ns.overhead end,
        place = function() if ns.PlaceOverhead then ns.PlaceOverhead() end end,
        -- the overhead hangs from the screen's top
        minY = -REACH_Y, maxY = 200,
        shown = function() return ns.db.overhead ~= false end,
    },
}
ns.CONSOLE_MOVERS = CONSOLES

local function Key(c, field) return c.id .. field end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- The page's sliders, and the popup's: one spec each, shared.
local function Specs(c)
    return {
        scale = { kind = "slider", key = Key(c, "Scale"), label = "Scale",
            min = SCALE_MIN, max = SCALE_MAX, step = SCALE_STEP,
            text = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
            tip = "Its size, as a share of the size it is drawn at." },
        x = { kind = "slider", key = Key(c, "X"), label = "Across",
            min = -REACH_X, max = REACH_X, step = 1,
            tip = "Right of where it is drawn, or left below zero." },
        y = { kind = "slider", key = Key(c, "Y"), label = "Up",
            min = c.minY, max = c.maxY, step = 1,
            tip = "Up from where it is drawn, or down below zero." },
    }
end

-- Back to where, and how big, the profile draws it.
local function Reset(c)
    for _, field in ipairs({ "Scale", "X", "Y" }) do
        ns.SetOption(Key(c, field), ns.OptionBase(Key(c, field)))
    end
end
ns.ResetConsolePlace = function(id)
    for _, c in ipairs(CONSOLES) do if c.id == id then Reset(c) end end
end

-- Each console's page group (options/pages.lua).
function ns.ConsolePlaceGroups(Group)
    local groups = {}
    for _, c in ipairs(CONSOLES) do
        local s = Specs(c)
        table.insert(groups, Group(c.name, s.scale, s.x, s.y,
            { kind = "button", label = "Reset " .. c.name:lower(), click = function() Reset(c) end,
                tip = "Back to where the profile draws it, at its own size." }))
    end
    return groups
end

-- A setting moved: place the console it belongs to.
for _, c in ipairs(CONSOLES) do
    for _, field in ipairs({ "Scale", "X", "Y" }) do
        ns.OnSetting(Key(c, field), c.place)
    end
end

-- ------------------------------------------------------------ the movers
-- Edit Mode's look: a blue wash with a brighter edge, the name in its middle;
-- the one last clicked is gold, as Edit Mode marks its selection.
local BLUE, BLUE_EDGE = { 0.20, 0.55, 1.00, 0.30 }, { 0.40, 0.72, 1.00, 0.90 }
local GOLD_FILL, GOLD_EDGE = { 0.88, 0.72, 0.29, 0.25 }, { 0.88, 0.72, 0.29, 1 }

local movers, popup, selected = {}, nil, nil
local showing = false

-- The pointer, in design units from the screen's bottom left.
local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    local k = (ns.layout and ns.layout.designHeight or 1080) / UIParent:GetHeight()
    return x / s * k, y / s * k
end

local function Paint(m)
    local on = m.console == selected
    local fill, edge = on and GOLD_FILL or BLUE, on and GOLD_EDGE or BLUE_EDGE
    m.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
    for _, t in ipairs(m.edges) do t:SetColorTexture(edge[1], edge[2], edge[3], edge[4]) end
end

local function RefreshPopup()
    if not popup or not popup:IsShown() then return end
    for _, ctl in ipairs(popup.controls) do ctl:Refresh(true) end
end

local Popup

local function Select(c)
    selected = c
    for _, m in pairs(movers) do Paint(m) end
    Popup(c)
end

local function Mover(c)
    local m = CreateFrame("Button", "MedalluinMover_" .. c.id, UIParent)
    m.console = c
    m:SetFrameStrata("DIALOG")
    m:SetAllPoints(c.frame())
    m:RegisterForClicks("LeftButtonUp")
    m.fill = m:CreateTexture(nil, "BACKGROUND")
    m.fill:SetAllPoints()
    m.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = m:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
        m.edges[i] = t
    end
    m.label = UI.Serif(m, 14, C.text)
    m.label:SetPoint("CENTER")
    m.label:SetText("Medalluin " .. c.name:lower())
    Paint(m)

    -- A press that moves the pointer a few units is a drag; one that does
    -- not is a click, and selects. A drag places the console as it goes and
    -- saves where it is let go.
    m:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local x, y = Cursor()
        self.from = { x, y, tonumber(ns.db[Key(c, "X")]) or 0, tonumber(ns.db[Key(c, "Y")]) or 0 }
        self.dragged = false
    end)
    m:SetScript("OnUpdate", function(self)
        local from = self.from
        if not from then return end
        local x, y = Cursor()
        local dx, dy = x - from[1], y - from[2]
        if not self.dragged and math.abs(dx) + math.abs(dy) < 4 then return end
        self.dragged = true
        self.at = { Clamp(math.floor(from[3] + dx + 0.5), -REACH_X, REACH_X),
            Clamp(math.floor(from[4] + dy + 0.5), c.minY, c.maxY) }
        -- straight onto the saved table's layer, so the console's placement reads
        -- it; ns.SetOption tells everyone else once, on release
        ns.db[Key(c, "X")], ns.db[Key(c, "Y")] = self.at[1], self.at[2]
        c.place()
    end)
    m:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.from then return end
        local dragged, at = self.dragged, self.at
        self.from, self.at, self.dragged = nil, nil, false
        if dragged and at then
            ns.SetOption(Key(c, "X"), at[1])
            ns.SetOption(Key(c, "Y"), at[2])
        end
        Select(c)
    end)
    m:Hide()
    return m
end

-- The popup: the selected console's scale and place, beside Edit Mode's.
function Popup(c)
    if not popup then
        popup = CreateFrame("Frame", "MedalluinMoverPopup", UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetSize(260, 228)
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        popup:SetClampedToScreen(true)
        UI.Skin(popup, C.panel)
        popup.title = UI.Serif(popup, 14, C.goldBright)
        popup.title:SetPoint("TOP", 0, -12)
        popup.close = UI.Button(popup, "Close", 80, 22, function()
            popup:Hide()
            selected = nil
            for _, m in pairs(movers) do Paint(m) end
        end)
        popup.close:SetPoint("BOTTOMRIGHT", -12, 12)
        popup.reset = UI.Button(popup, "Reset", 80, 22, function()
            if popup.console then Reset(popup.console) end
        end, "Back to where the profile draws it, at its own size.")
        popup.reset:SetPoint("BOTTOMLEFT", 12, 12)
        popup.byConsole = {}
    end
    popup.console = c
    popup.title:SetText("Medalluin " .. c.name:lower())
    -- each console's sliders are built once, and shown while it is selected
    for id, set in pairs(popup.byConsole) do
        for _, ctl in ipairs(set) do ctl:SetShown(id == c.id) end
    end
    if not popup.byConsole[c.id] then
        local s, set = Specs(c), {}
        local y = -40
        for _, field in ipairs({ "scale", "x", "y" }) do
            local ctl = UI.Slider(popup, s[field], 236)
            ctl:SetPoint("TOPLEFT", 12, y)
            y = y - UI.SLIDER_H - 8
            table.insert(set, ctl)
        end
        popup.byConsole[c.id] = set
    end
    popup.controls = popup.byConsole[c.id]
    popup:Show()
    RefreshPopup()
end

local function ShowMovers(on)
    showing = on and true or false
    for _, c in ipairs(CONSOLES) do
        local frame = c.frame()
        if frame then
            movers[c.id] = movers[c.id] or Mover(c)
            movers[c.id]:SetShown(showing and (not c.shown or c.shown()) and true or false)
        end
    end
    if not showing then
        if popup then popup:Hide() end
        selected = nil
        for _, m in pairs(movers) do m.from = nil; Paint(m) end
    end
end
ns.ShowConsoleMovers = ShowMovers
function ns.ConsoleMoversShown() return showing end
ns.consoleMovers = movers

ns.OnAnySetting(function(key)
    RefreshPopup()
    -- the overhead turned off or on while its mover is out
    if key == "overhead" and showing then ShowMovers(true) end
end)

-- Edit Mode's own events; a client without them has /mdlui move.
if EventRegistry and EventRegistry.RegisterCallback then
    local owner = {}
    EventRegistry:RegisterCallback("EditMode.Enter", function() ShowMovers(true) end, owner)
    EventRegistry:RegisterCallback("EditMode.Exit", function() ShowMovers(false) end, owner)
end
