-- The side panel, on the right strip: the chat panel's mirror (chat.lua),
-- holding Medalluin's own views instead of Blizzard's chat: the Loot log
-- (loot.lua), the Meter (meter.lua) and the Auras (auras.lua).
--
-- Mirrored piece for piece: the same art, size and place on its strip; the
-- button column on the OUTER edge (the right), the scroll bar on the inner
-- edge, the tabs running inward from over the column. The tabs are the
-- chat panel's old ones (ns.TabSlices), in the views' order from the outer end: Loot
-- outermost, then Meter, then Auras.
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
--
-- BACKGROUND strata, like the chat panel. Built at login, and only when the
-- Side panel option is on; its tabs come and go with their own options.
local _, ns = ...

local L = ns.stripLayout
local PARTS = ns.media .. "strips\\"
local COLUMN = L.chatPad + L.chatColumn / 2     -- the column's centre, from the panel's outer edge
local INNER = L.chatPad + L.chatColumn + 5      -- the body's outer edge, the same
local PITCH = 30                                -- column buttons, top down
local BUTTON, WELL = 24, 32                     -- a button, and its 32x32 art centred on it
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

local panel, track, thumb
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
    b.well:SetTexture(PARTS .. (spec.lit() and "side-well-on" or "side-well"))
    b.glyph:SetTexture(PARTS .. spec.glyph())
    if spec.tint then b.glyph:SetVertexColor(spec.tint()) end
end

local function Tip(b)
    local title, line = b.spec.tip()
    ns.Tip(b, "ANCHOR_LEFT", { title = title, line and { "body", line } or false })
end

local function Button(view, spec, y, from)
    local b = CreateFrame("Button", nil, view.column)
    b.spec = spec
    b:SetSize(BUTTON, BUTTON)
    b:SetPoint("CENTER", panel, from, -COLUMN, y)
    b.well = b:CreateTexture(nil, "BACKGROUND")
    b.well:SetSize(WELL, WELL)
    b.well:SetPoint("CENTER")
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetSize(WELL, WELL)
    b.glyph:SetPoint("CENTER")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetSize(WELL, WELL)
    glow:SetPoint("CENTER")
    glow:SetTexture(PARTS .. "side-well-on")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.35)
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

-- ----------------------------------------------------------------- tabs
local function Selected(view, on)
    for _, t in ipairs(view.tab.selected) do t:SetShown(on) end
    view.tab.label:SetTextColor(unpack(on and { 1, 0.82, 0 } or { 0.78, 0.67, 0.31 }))
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

-- The tabs that are on, from the outer end inward; the panel goes when
-- none is.
local function Arrange()
    local prev, pick, first
    for _, v in ipairs(views) do
        if v.available then
            local on = On(v)
            v.tab:SetShown(on)
            if on then
                v.tab:ClearAllPoints()
                if prev then
                    v.tab:SetPoint("BOTTOMRIGHT", prev.tab, "BOTTOMLEFT", -1, 0)
                else
                    v.tab:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -INNER, 0)
                end
                prev, first = v, first or v
                if v.key == ns.db.sideTab then pick = v end
            end
        end
    end
    panel:SetShown(first ~= nil)
    Select(pick or first)
end

local function Tab(view)
    local tab = CreateFrame("Button", nil, panel)
    ns.TabSlices(tab, "tab", "BACKGROUND", 1)
    local glow = ns.TabSlices(tab, "tab", "HIGHLIGHT", 1)
    for _, t in ipairs(glow) do
        t:SetBlendMode("ADD")
        t:SetAlpha(0.35)
    end
    tab.selected = ns.TabSlices(tab, "tab-selected", "BACKGROUND", 2)
    -- the label sits in the tab's shape, below its open top (TAB_TOP)
    tab.label = ns.Text(tab, 11)
    tab.label:SetPoint("CENTER", 0, -4)
    tab.label:SetText(view.label)
    tab:SetSize(math.max(L.tabTex, math.floor(tab.label:GetStringWidth() + 28)), 32)
    tab:SetScript("OnClick", function() Select(view) end)
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
    panel = CreateFrame("Frame", "MedalluinSide", strip)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetSize(L.chatWidth, L.chatHeight)
    panel:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -L.chatLeft, L.stripHeight)
    local tex = panel:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(ns.media .. "chat")
    tex:SetTexCoord(L.chatWidth / L.chatTexWidth, 0, 0, L.chatHeight / L.chatTexHeight)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)

    -- the scroll bar's track, where the chat's is on the other side
    track = panel:CreateTexture(nil, "BORDER")
    track:SetColorTexture(0, 0, 0, 0.35)
    track:SetSize(8, L.chatHeight - 12)
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -6)
    thumb = panel:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    thumb:SetWidth(6)

    ns.side.panel = panel
    for _, v in ipairs(views) do
        v.available = v.Available() and true or false
        if v.available then
            v.body = CreateFrame("Frame", nil, panel)
            v.body:SetPoint("TOPLEFT", panel, "TOPLEFT", L.chatRight, -4)
            v.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -INNER, 4)
            v.body:SetSize(L.chatWidth - L.chatRight - INNER, L.chatHeight - 8)
            v.column = CreateFrame("Frame", nil, panel)
            v.column:SetAllPoints()
            v.paint = {}
            for i, spec in ipairs(v.buttons) do Button(v, spec, -16 - (i - 1) * PITCH, "TOPRIGHT") end
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
