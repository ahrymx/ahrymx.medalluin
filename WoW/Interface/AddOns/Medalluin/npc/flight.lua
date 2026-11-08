-- The flight map, in the NPC box's place (npc/window.lua) but not in its
-- ink: the game's map bare in a thin gold edge, a strip over it with the
-- flight master's name, and the places you can fly to under it.
--
--   Thor                                                  [x]  <- the strip
--   +-------------------------------------------------------+
--   |              the game's map, its nodes and             |
--   |              the routes from here                      |
--   +-------------------------------------------------------+
--   Ironforge                                    You are here  <- dim
--   Menethil Harbor                                       50s
--   Sentinel Hill                                      1g 5s  <- red: beyond
--   [General][Trade]                       <- the chat box      your money
--
-- A node or a row flies there (TakeTaxiNode); hovering one draws its route,
-- as Blizzard's map does. The nodes, routes and the rule for both are
-- Blizzard's (TaxiFrame.lua), drawn on our own buttons and lines.
--
-- Blizzard's TaxiFrame keeps every way in and out: the game shows it on
-- TAXIMAP_OPENED and hides it on TAXIMAP_CLOSED, Escape too, under the
-- hidden parent. Parked, it never runs its OnShow (where it draws) or its
-- OnHide (where it tells the game the map closed): this does both, from
-- the frame's own Show and Hide. Only TaxiFrame: retail's other flight map
-- (FlightMapFrame, a map canvas) stays Blizzard's.
local _, ns = ...

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local STRIP, ROW, PAD, CONTROL, NODE = 28, 26, 10, 16, 16
local SIZE = WIDTH - 2                          -- the map, inside its edge
local SPREAD = 18 * SIZE / 580                  -- Blizzard's least gap, at our size
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local RED = { 1, 0.3, 0.25 }
local BAND = 0.6                                -- the NPC box's head and foot, at their edge
local BODY = 0.94                               -- the list: as dark as a window's body (the spellbook's)
local ICONS = {
    CURRENT = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    REACHABLE = "Interface\\TaxiFrame\\UI-Taxi-Icon-White",
    DISTANT = "Interface\\TaxiFrame\\UI-Taxi-Icon-Nub",
    UNREACHABLE = "Interface\\TaxiFrame\\UI-Taxi-Icon-White",
}
local REFUSED = "Interface\\TaxiFrame\\UI-Taxi-Icon-Red"   -- an unreachable one, hovered

local frame, map, art, title, list, scroll, child, thumb
local nodes, legs, rows = {}, {}, {}
local spots = {}                                -- each node's place, from the map's bottom left
local offset = 0

local function Kind(i) return TaxiNodeGetType(i) end

-- Blizzard's places: the node's position on the map, pushed off any node
-- before it that it would sit on (a distant one never pushes a near one)
local function Place()
    wipe(spots)
    for i = 1, NumTaxiNodes() do
        local kind = Kind(i)
        if kind ~= "NONE" then
            local x, y = TaxiNodePosition(i)
            x, y = x * SIZE, (1 - y) * SIZE
            local at = { x = x, y = y }
            for j = 1, i - 1 do
                local s = spots[j]
                if s and (kind == "DISTANT" or Kind(j) ~= "DISTANT") then
                    local dx, dy = x - s.x, y - s.y
                    local d2 = dx * dx + dy * dy
                    if d2 < SPREAD * SPREAD then
                        local k = d2 > 0 and SPREAD / math.sqrt(d2) or SPREAD
                        at = { x = s.x + dx * k, y = s.y + dy * k }
                    end
                end
            end
            spots[i] = at
        end
    end
end

-- -------------------------------------------------------------- routes
local used = 0
local function Line(a, b)
    if not a or not b then return end
    used = used + 1
    local l = legs[used]
    if not l then
        l = map:CreateLine(nil, "ARTWORK", nil, 2)
        l:SetThickness(2)
        l:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
        legs[used] = l
    end
    l:SetStartPoint("BOTTOMLEFT", art, a.x, a.y)
    l:SetEndPoint("BOTTOMLEFT", art, b.x, b.y)
    l:Show()
end

-- The routes drawn: a reachable node's legs while it is hovered (and the
-- distant nodes they pass), else every flight one hop from here.
local function Routes(hover)
    used = 0
    for i, n in pairs(nodes) do
        if spots[i] and Kind(i) == "DISTANT" then n:Hide() end
    end
    local kind = hover and Kind(hover)
    if kind == "REACHABLE" then
        for leg = 1, GetNumRoutes(hover) do
            local from, to = TaxiGetNodeSlot(hover, leg, true), TaxiGetNodeSlot(hover, leg, false)
            Line(spots[from], spots[to])
            if nodes[to] and Kind(to) == "DISTANT" then nodes[to]:Show() end
        end
    elseif kind ~= "UNREACHABLE" then
        for i = 1, NumTaxiNodes() do
            if Kind(i) == "REACHABLE" and TaxiIsDirectFlight(i) then
                Line(spots[TaxiGetNodeSlot(i, 1, true)], spots[TaxiGetNodeSlot(i, 1, false)])
            end
        end
    end
    for i = used + 1, #legs do legs[i]:Hide() end
end

-- -------------------------------------------------------------- hover
local function Fly(i)
    if Kind(i) == "REACHABLE" then TakeTaxiNode(i) end
end

local function Enter(i, owner)
    local kind = Kind(i)
    ns.window.Outside(owner)
    GameTooltip:AddLine(TaxiNodeName(i), nil, nil, nil, true)
    if kind == "REACHABLE" then
        GameTooltip:AddLine(ns.npc.Money(TaxiNodeCost(i)), 1, 1, 1)
    elseif kind == "CURRENT" then
        GameTooltip:AddLine(TAXINODEYOUAREHERE or "You are here.", 1, 1, 1, true)
    end
    GameTooltip:Show()
    local n = nodes[i]
    if n then
        n.lit:Show()
        if kind == "UNREACHABLE" then n.icon:SetTexture(REFUSED) end
    end
    Routes(i)
end

local function Leave(i)
    GameTooltip:Hide()
    local n = nodes[i]
    if n then
        n.lit:Hide()
        if ICONS[Kind(i)] then n.icon:SetTexture(ICONS[Kind(i)]) end
    end
    Routes()
end

local function Node(i)
    local n = CreateFrame("Button", nil, map)
    n:SetSize(NODE, NODE)
    n.icon = n:CreateTexture(nil, "ARTWORK")
    n.icon:SetAllPoints()
    n.glow = n:CreateTexture(nil, "HIGHLIGHT")
    n.glow:SetAllPoints()
    n.glow:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight")
    n.glow:SetBlendMode("ADD")
    -- lit while its row is hovered
    n.lit = n:CreateTexture(nil, "OVERLAY")
    n.lit:SetPoint("CENTER")
    n.lit:SetSize(NODE * 2, NODE * 2)
    n.lit:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight")
    n.lit:SetBlendMode("ADD")
    n.lit:Hide()
    n:SetScript("OnEnter", function(self) Enter(i, self) end)
    n:SetScript("OnLeave", function() Leave(i) end)
    n:SetScript("OnClick", function() Fly(i) end)
    nodes[i] = n
    return n
end

-- -------------------------------------------------------------- the list
-- Where you can fly, by name, after where you are.
local function Destinations()
    local out, here = {}, nil
    for i = 1, NumTaxiNodes() do
        local kind = Kind(i)
        if kind == "REACHABLE" then
            table.insert(out, { index = i, name = TaxiNodeName(i), cost = TaxiNodeCost(i) or 0 })
        elseif kind == "CURRENT" then
            here = { index = i, name = TaxiNodeName(i), here = true }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    if here then table.insert(out, 1, here) end
    return out
end

local function Row()
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    r.label = ns.Text(r, 14)
    r.label:SetPoint("LEFT", 6, 0)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.value = ns.Text(r, 13)
    r.value:SetPoint("RIGHT", -6, 0)
    r.label:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
    r:SetScript("OnEnter", function(self) Enter(self.data.index, self) end)
    r:SetScript("OnLeave", function(self) Leave(self.data.index) end)
    r:SetScript("OnClick", function(self) Fly(self.data.index) end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) ns.npc.flight.Scroll(-delta) end)
    return r
end

local function Colour(t, c) t:SetTextColor(c[1], c[2], c[3]) end

local function Thumb()
    local range = scroll:GetVerticalScrollRange() or 0
    thumb:SetShown(range > 0)
    if range > 0 then
        local h = scroll:GetHeight()
        local size = math.max(12, h * h / (h + range))
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", PAD - 3, -(h - size) * offset / range)
    end
end

-- The rows, and the frame fitted: the map whole, the list in the room left
-- up to the screen's top.
local function List()
    local places = Destinations()
    local money = GetMoney()
    for i = 1, math.max(#rows, #places) do
        local d, r = places[i], rows[i]
        if d and not r then
            r = Row()
            rows[i] = r
        end
        if r then
            r:SetShown(d ~= nil)
            if d then
                r.data = d
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
                r:SetPoint("RIGHT", child, "RIGHT")
                r.label:SetText(d.name)
                r.value:SetText(d.here and (TAXINODEYOUAREHERE or "You are here.") or ns.npc.Money(d.cost))
                local c = d.here and ns.colors.dim or money < d.cost and RED or ns.colors.text
                Colour(r.label, c)
                Colour(r.value, c)
            end
        end
    end
    child:SetHeight(math.max(1, #places * ROW))
    local want = #places * ROW + 2 * PAD
    local room = ns.npc.Room() - STRIP - SIZE - 2
    local h = math.max(0, math.min(want, room))
    list:SetHeight(h)
    list:SetShown(h > 0)
    frame:SetHeight(STRIP + SIZE + 2 + h)
    offset = math.min(offset, scroll:GetVerticalScrollRange() or 0)
    scroll:SetVerticalScroll(offset)
    Thumb()
end

-- ------------------------------------------------------------- the map
-- Everything Blizzard's OnShow does, on ours: the art, the nodes, the
-- one-hop routes, and the list; no route from here at all closes it, with
-- the game's own words.
local function Draw()
    if not frame then return end
    title:SetText(UnitName("npc") or FLIGHT_MAP or "Flight map")
    art:SetTexCoord(0, 1, 0, 1)
    SetTaxiMap(art)
    Place()
    local count, hops = NumTaxiNodes(), 0
    for i = 1, math.max(count, #nodes) do
        local n, at = nodes[i], i <= count and spots[i]
        if at then
            n = n or Node(i)
            local kind = Kind(i)
            n:ClearAllPoints()
            n:SetPoint("CENTER", art, "BOTTOMLEFT", math.floor(at.x + 0.5), math.floor(at.y + 0.5))
            n.icon:SetTexture(ICONS[kind])
            n.glow:SetAlpha(kind == "REACHABLE" and 1 or 0)
            n.lit:Hide()
            n:Show()                            -- a distant one: Routes hides it
            if kind == "DISTANT" or kind == "REACHABLE" and TaxiIsDirectFlight(i) then hops = hops + 1 end
        elseif n then
            n:Hide()
        end
    end
    Routes()
    offset = 0
    List()
    if hops == 0 then
        if UIErrorsFrame and ERR_TAXINOPATHS then UIErrorsFrame:AddMessage(ERR_TAXINOPATHS, 1, 0.1, 0.1, 1) end
        CloseTaxiMap()
    end
end

local function Build()
    frame = CreateFrame("Frame", "MedalluinFlight", ns.strips[-1])
    ns.window.Mark(frame, -1)                    -- its tooltips beside it
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(ns.chat.box:GetFrameLevel() + 1)
    frame:SetWidth(WIDTH)
    frame:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
    frame:EnableMouse(true)

    local strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(STRIP)
    local ink = strip:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], BAND)
    title = ns.Text(strip, 15)
    title:SetPoint("LEFT", PAD, 0)
    title:SetPoint("RIGHT", -(PAD + CONTROL + 12), 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    Colour(title, GOLD)
    local close = ns.window.Button(strip, CONTROL + 8, function() CloseTaxiMap() end,
        function() return "Close." end)
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetSize(CONTROL, CONTROL)
    close.icon:SetPoint("CENTER")
    close.icon:SetTexture(ns.media .. "strips\\close")
    close:SetHeight(CONTROL + 8)
    close:SetPoint("RIGHT", -4, 0)

    -- the map in its edge: a gold fill one pixel wider than the art on it
    map = CreateFrame("Frame", nil, frame)
    map:SetPoint("TOPLEFT", 0, -STRIP)
    map:SetSize(WIDTH, SIZE + 2)
    local edge = map:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    art = map:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", 1, -1)
    art:SetSize(SIZE, SIZE)

    list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", map, "BOTTOMLEFT")
    list:SetPoint("TOPRIGHT", map, "BOTTOMRIGHT")
    local back = list:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], BODY)
    scroll = CreateFrame("ScrollFrame", nil, list)
    scroll:SetPoint("TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - 2 * PAD, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ns.npc.flight.Scroll(-delta) end)
    thumb = list:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    thumb:Hide()
    frame:Hide()
    return frame
end

ns.npc.flight = {}
function ns.npc.flight.Scroll(lines)
    local range = scroll:GetVerticalScrollRange() or 0
    offset = math.max(0, math.min(range, offset + lines * ROW))
    scroll:SetVerticalScroll(offset)
    Thumb()
end

local page
page = ns.npc.Page{
    key = "flight", frame = "TaxiFrame",
    Close = function() CloseTaxiMap() end,
    Start = function()
        page.own = Build()
        ns.npc.flight.frame = frame
        -- Blizzard's OnShow and OnHide, which a parked frame never runs
        hooksecurefunc(TaxiFrame, "Show", function()
            Draw()
            ns.npc.Show("flight")
        end)
        hooksecurefunc(TaxiFrame, "Hide", function() CloseTaxiMap() end)
        ns.On("TAXIMAP_CLOSED", ns.npc.Sync)
        ns.On("PLAYER_MONEY", function() if frame:IsShown() then List() end end)
    end,
}
