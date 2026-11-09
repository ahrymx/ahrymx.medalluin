-- The side panel, on the right strip: the chat panel's mirror (chat.lua),
-- holding Medalluin's own views instead of Blizzard's chat: the Loot log
-- (loot.lua), the Meter (meter.lua) and the Auras (auras.lua).
--
-- In a box as the chat's is (ns.window.Dress, its ink solid at the
-- screen's edge here), standing on the strip:
--
--   |  the view's list         [o]    <- the body; the button column on
--   |                          [o]       the OUTER edge (the right), the
--   |                          [o]       scroll bar on the inner edge
--   ---------------------------------
--   [  *  |  =  |  #  ] |     (bag)   <- the margin: the tabs edge to edge,
--                                        up to a break divider before the bag
--
-- The tabs run inward from the break divider in the views' order: Loot
-- outermost, then Meter, then Auras, sharing the row edge to edge. They and
-- the column's buttons wear the windows' box (ns.window.Face), a view's
-- button marked while it is lit.
--
-- A view hands the panel its tab label, the option that switches it, its
-- column buttons (top down, and one at the foot), and draws itself into a
-- body frame between the column and the scroll bar. The panel draws the
-- buttons, the tabs and the scroll bar, and passes the mouse wheel on.
--
--   ns.SideView{ key, label, option, Available(), Build(body), Refresh(),
--                Scroll(lines), Thumb() -> first, shown, total,
--                buttons = { spec... }, foot = spec, Shown(shown) }
--   spec = { glyph(), lit(), tint() (optional), click(mouse), tip() -> title, line }
--        or a ladder: { steps, color(i) -> r, g, b, lit(i), click(i, mouse),
--                       tip(i) -> title, line }: a stack of swatches, one
--                       per step, top down, picked directly; a lit one in
--                       its colour, the rest faint. It takes a button's
--                       room and more (steps * SWATCH); last in the list.
--
-- BACKGROUND strata, like the chat panel. Built at login, and only when the
-- Side panel option is on; its tabs come and go with their own options.
local _, ns = ...

local L = ns.stripLayout
local PARTS = ns.media .. "strips\\"
local COLUMN = L.chatPad + L.chatColumn / 2     -- the column's centre, from the panel's outer edge
local INNER = L.chatPad + L.chatColumn + 5      -- the body's outer edge, the same
local PITCH = 30                                -- column buttons, top down
local BUTTON, GLYPH = 24, 28                    -- a button's box, and its glyph's 32x32 art in it
local SWATCH = 14                               -- a ladder's step: its pitch (the box 1 less, edges shared)
local PAD, RULE, TABS = 8, 6, 28                -- as the chat box's (chat.lua)
local GOLD_D = { 0.541, 0.439, 0.204 }

local views = {}
ns.side = { views = views }

function ns.SideView(view)
    table.insert(views, view)
end

-- Plain text, where the panel's own face reads badly (money's "g", links).
function ns.PlainText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(ns.colors.text))
    return fs
end

local panel, area, row, track, thumb
local current

local function On(view)
    return view.available and ns.db[view.option] and true or false
end

-- ------------------------------------------------------------ scroll bar
-- On the inner edge, where the chat's own scroll bar is on its side. The
-- thumb only when there is more than the body shows.
local function Thumb()
    if not current then
        thumb:Hide()
        return
    end
    local first, shown, total = current.Thumb()
    if total <= shown or shown <= 0 then
        thumb:Hide()
        return
    end
    local h = track:GetHeight()
    local th = math.max(12, h * shown / total)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -(h - th) * math.min(1, first / (total - shown)))
    thumb:Show()
end

local function Wheel(delta)
    if current then
        current.Scroll(-delta)
        Thumb()
    end
end

-- ------------------------------------------------------- column buttons
local function Paint(b)
    local spec = b.spec
    if b.step then
        local on = spec.lit(b.step) and true or false
        local r, g, bl = spec.color(b.step)
        b.fill:SetColorTexture(r, g, bl, on and 0.9 or 0.18)
        b.mark:SetShown(on)
        return
    end
    b.mark:SetShown(spec.lit() and true or false)
    b.glyph:SetTexture(PARTS .. spec.glyph())
    if spec.tint then b.glyph:SetVertexColor(spec.tint()) end
end

-- a tooltip outside the panel, at its left (it stands on the right strip)
function ns.side.Beside(owner) ns.window.Beside(panel, owner, 1) end

local function Tip(b)
    local title, line = b.spec.tip(b.step)
    ns.Tip(b, ns.side.Beside, { title = title, line and { "body", line } or false })
end

local function Button(view, spec, y, from)
    local b = CreateFrame("Button", nil, view.column)
    b.spec = spec
    b:SetSize(BUTTON, BUTTON)
    b:SetPoint("CENTER", area, from, -COLUMN, y)
    ns.window.Face(b)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetSize(GLYPH, GLYPH)
    b.glyph:SetPoint("CENTER")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, mouse)
        self.spec.click(mouse)
        ns.side.Changed()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(view.paint, b)
    Paint(b)
    return b
end

-- A ladder: its swatches stacked down from y (the top of the room a
-- button there would have), sharing their edges.
local function Ladder(view, spec, y, from)
    for i = 1, spec.steps do
        local b = CreateFrame("Button", nil, view.column)
        b.spec, b.step = spec, i
        b:SetSize(BUTTON, SWATCH + 1)
        b:SetPoint("TOP", area, from, -COLUMN, y - (i - 1) * SWATCH)
        ns.window.Face(b)
        b.fill = b:CreateTexture(nil, "ARTWORK")
        b.fill:SetPoint("TOPLEFT", 3, -3)
        b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, mouse)
            self.spec.click(self.step, mouse)
            ns.side.Changed()
            if GameTooltip:IsOwned(self) then Tip(self) end
        end)
        b:SetScript("OnEnter", Tip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(view.paint, b)
        Paint(b)
    end
end

-- ----------------------------------------------------------------- tabs
local function Selected(view, on)
    view.tab.mark:SetShown(on)
    view.tab.glyph:SetAlpha(on and 1 or 0.6)
end

local function Select(view)
    current = view
    if view then ns.db.sideTab = view.key end
    for _, v in ipairs(views) do
        if v.available then
            local shown = v == view
            v.body:SetShown(shown)
            v.column:SetShown(shown)
            Selected(v, shown)
            if v.Shown then v.Shown(shown) end
        end
    end
    if view then view.Refresh() end
    ns.side.Changed()
end

-- The tabs that are on, from the outer end inward, sharing the row edge to
-- edge; the panel goes when none is.
local function Arrange()
    local shown, pick = {}, nil
    for _, v in ipairs(views) do
        if v.available then
            local on = On(v)
            v.tab:SetShown(on)
            if on then
                table.insert(shown, v)
                if v.key == ns.db.sideTab then pick = v end
            end
        end
    end
    local n, full, prev = #shown, row:GetWidth(), nil
    for i, v in ipairs(shown) do
        local x0 = math.floor((i - 1) * (full - 1) / n)
        local x1 = math.floor(i * (full - 1) / n) + 1
        v.tab:SetWidth(x1 - x0)
        v.tab:ClearAllPoints()
        if prev then
            v.tab:SetPoint("RIGHT", prev.tab, "LEFT", 1, 0)
        else
            v.tab:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        end
        prev = v
    end
    panel:SetShown(n > 0)
    Select(pick or shown[1])
end

local function Tab(view)
    local tab = CreateFrame("Button", nil, row)
    tab:SetHeight(row:GetHeight())
    ns.window.Face(tab)
    tab.glyph = tab:CreateTexture(nil, "ARTWORK")
    tab.glyph:SetSize(GLYPH, GLYPH)
    tab.glyph:SetPoint("CENTER")
    tab.glyph:SetTexture(PARTS .. "side-" .. view.key)
    tab:SetScript("OnClick", function() Select(view) end)
    tab:SetScript("OnEnter", function(self)
        ns.Tip(self, ns.side.Beside, { title = view.label })
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    view.tab = tab
end

-- ---------------------------------------------------------------- views
-- After a view's data or options change: its buttons and the scroll bar.
function ns.side.Changed()
    if not panel then return end
    for _, v in ipairs(views) do
        for _, b in ipairs(v.paint or {}) do Paint(b) end
    end
    Thumb()
end

-- A row that takes the mouse passes the wheel on to the panel, so the list
-- scrolls wherever the pointer is over it.
function ns.side.PassWheel(frame)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
end

function ns.side.IsCurrent(view)
    return panel ~= nil and current == view and panel:IsShown()
end

local function Build()
    local strip = ns.strips[1]
    local width = L.chatLeft + L.chatWidth
    local margin = ns.window.band               -- the windows' margin, as the chat's
    local foot = margin + RULE                  -- the body's foot, over the margin's rule
    local tall = L.chatHeight + TABS - PAD      -- the chat's messages and tab row: the same box
    panel = CreateFrame("Frame", "MedalluinSide", strip)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetWidth(width)
    panel:SetHeight(foot + tall + PAD)
    panel:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, L.stripHeight)
    local breakAt = ns.stripWell.x + L.ringRadius + 5
    local dress = ns.window.Dress(panel, margin, true)
    dress.rule:SetPoint("BOTTOMLEFT", 0, margin)
    dress.rule:SetPoint("BOTTOMRIGHT", 0, margin)
    -- the body's room, the old panel's: the column at its right
    area = CreateFrame("Frame", nil, panel)
    area:SetPoint("BOTTOMRIGHT", -PAD, foot)
    area:SetSize(width - 2 * PAD, tall)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    -- the tabs' row, edge to edge under the margin's rule up to a break
    -- divider before the backpack's medallion
    row = CreateFrame("Frame", nil, panel)
    row:SetPoint("BOTTOMRIGHT", -breakAt, 0)
    row:SetSize(width - breakAt, margin + 1)

    -- the scroll bar's track, where the chat's is on the other side
    track = area:CreateTexture(nil, "BORDER")
    track:SetColorTexture(0, 0, 0, 0.35)
    track:SetSize(8, tall - 12)
    track:SetPoint("TOPLEFT", area, "TOPLEFT", 3, -6)
    thumb = area:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    thumb:SetWidth(6)

    ns.side.panel, ns.side.area, ns.side.row, ns.side.dress = panel, area, row, dress
    for _, v in ipairs(views) do
        v.available = v.Available() and true or false
        if v.available then
            v.body = CreateFrame("Frame", nil, area)
            v.body:SetPoint("TOPLEFT", area, "TOPLEFT", L.chatRight, -4)
            v.body:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -INNER, 4)
            v.body:SetSize(width - 2 * PAD - L.chatRight - INNER, tall - 8)
            v.column = CreateFrame("Frame", nil, area)
            v.column:SetAllPoints()
            v.paint = {}
            for i, spec in ipairs(v.buttons) do
                local y = -16 - (i - 1) * PITCH
                if spec.steps then Ladder(v, spec, y + BUTTON / 2, "TOPRIGHT")
                else Button(v, spec, y, "TOPRIGHT") end
            end
            if v.foot then Button(v, v.foot, 16, "BOTTOMRIGHT") end
            Tab(v)
            v.Build(v.body)
            ns.OnSetting(v.option, Arrange)
        end
    end
    Arrange()
end

ns.On("PLAYER_LOGIN", function()
    if ns.db.side then Build() end
end)
