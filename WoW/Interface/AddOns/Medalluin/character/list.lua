-- What the list pages share (Reputation, Currency, Skills, Statistics):
-- a scrolling list of headers and rows over the page, and the details
-- under it.
--
--   ns.character.List(body) -> list
--     list:Set(rows)   draws them; each row is
--       { header = true, label, collapsed, depth, click() }   a heading: ± at its right
--       { label, depth, icon, value, bar = { min, max, cur, color, text },
--         selected, click(button), enter(row), dim, color }   an entry
--     list:Draw()      again, at the same scroll (after the body's height changes)
--
--   ns.character.Details(foot, ticks, nothing, lines) -> details
--     details:Set{ title, sub, bar, text, lines }   (nil hides the lot; empty says so)
--     ticks = { { label, tip, click(on) } ... }: details.ticks[i]:Set(on, enabled)
--     nothing: what it says with nothing chosen; lines: how many its text runs to (3)
--
-- The list fills the body; the wheel scrolls it a row at a time, and a thin
-- thumb on its right says where it is when there is more than it shows.
local _, ns = ...

local ROW, INDENT, BAR_W, BAR_H, ICON = 22, 12, 150, 16, 18
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }

local function Well(f, inset)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", inset, -inset)
    well:SetPoint("BOTTOMRIGHT", -inset, inset)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    return edge, well
end

-- A bar in an ink well with a gold edge, its words over it.
local function Bar(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, BAR_H)
    Well(holder, 1)
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(ns.bar)
    holder.bar = bar
    holder.text = ns.Text(bar, 11)
    holder.text:SetPoint("CENTER", 0, 0)
    function holder:Fill(b)
        local lo, hi, cur = b.min or 0, b.max or 1, b.cur or 0
        if hi <= lo then lo, hi, cur = 0, 1, 1 end
        self.bar:SetMinMaxValues(lo, hi)
        self.bar:SetValue(cur)
        local c = b.color or GOLD
        self.bar:SetStatusBarColor(c[1] * ns.mute, c[2] * ns.mute, c[3] * ns.mute)
        self.text:SetText(b.text or "")
    end
    return holder
end
ns.character.Bar = Bar

-- ----------------------------------------------------------------- rows
local function Row(list)
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(ROW)
    r.fill = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.fill:SetAllPoints()
    r.mark = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.label = ns.Text(r, 12)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.value = ns.Text(r, 12)
    r.value:SetPoint("RIGHT", -6, 0)
    r.sign = ns.Text(r, 14)
    r.sign:SetPoint("RIGHT", -6, 0)
    r.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    r.bar = Bar(r, BAR_W)
    r.bar:SetPoint("RIGHT", -4, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
        if self.data and self.data.click then self.data.click(button) end
    end)
    r:SetScript("OnEnter", function(self)
        if self.data and self.data.enter then self.data.enter(self) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) list:Scroll(-delta) end)
    return r
end

local function Paint(r, d)
    r.data = d
    local depth = d.depth or 0
    local x = 6 + depth * INDENT
    r.icon:SetShown(d.icon ~= nil)
    if d.icon then
        r.icon:SetTexture(d.icon)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", x, 0)
        x = x + ICON + 4
    end
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", x, 0)
    r.label:SetText(d.label or "")
    if d.header then
        r.fill:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], depth == 0 and 0.30 or 0.15)
        r.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        r.sign:SetText(d.collapsed and "+" or "-")
    else
        r.fill:SetColorTexture(0, 0, 0, 0)
        r.label:SetTextColor(unpack(d.color or d.dim and ns.colors.dim or ns.colors.text))
        r.sign:SetText("")
    end
    r.mark:SetShown(d.selected and true or false)
    -- a heading with a bar of its own (a reputation's) shows it left of its sign
    r.bar:SetShown(d.bar ~= nil)
    r.bar:ClearAllPoints()
    r.bar:SetPoint("RIGHT", d.header and -20 or -4, 0)
    if d.bar then r.bar:Fill(d.bar) end
    r.value:SetShown(d.bar == nil and d.value ~= nil)
    r.value:SetText(d.value or "")
    r.label:SetPoint("RIGHT", r, "RIGHT", d.bar and -(BAR_W + 10) or d.value and -60 or -24, 0)
end

-- ----------------------------------------------------------------- list
local List = {}

function List:Shown() return math.max(1, math.floor((self.body:GetHeight() or 0) / ROW)) end

function List:Scroll(lines)
    local most = math.max(0, #self.data - self:Shown())
    self.offset = math.max(0, math.min(most, self.offset + lines))
    self:Draw()
end

function List:Draw()
    local shown = self:Shown()
    self.offset = math.max(0, math.min(self.offset, #self.data - shown))
    for i = 1, shown do
        local r = self.rows[i]
        if not r then
            r = Row(self)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
            r:SetPoint("TOPRIGHT", -6, -(i - 1) * ROW)
            self.rows[i] = r
        end
        local d = self.data[self.offset + i]
        r:SetShown(d ~= nil)
        if d then Paint(r, d) end
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    local total = #self.data
    self.empty:SetShown(total == 0)
    self.track:SetShown(total > shown)
    if total > shown then
        local h = shown * ROW
        local size = math.max(12, h * shown / total)
        self.thumb:SetHeight(size)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - size) * self.offset / (total - shown))
    end
end

function List:Set(rows)
    self.data = rows
    self:Draw()
end

function ns.character.List(body, empty)
    local list = CreateFrame("Frame", nil, body)
    list:SetAllPoints()
    for k, v in pairs(List) do list[k] = v end
    list.body, list.rows, list.data, list.offset = body, {}, {}, 0
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta) end)
    list.track = list:CreateTexture(nil, "ARTWORK")
    list.track:SetPoint("TOPRIGHT")
    list.track:SetPoint("BOTTOMRIGHT")
    list.track:SetWidth(3)
    list.track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    list.thumb = list:CreateTexture(nil, "OVERLAY")
    list.thumb:SetWidth(3)
    list.thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    hooksecurefunc(list.track, "SetShown", function(_, on) list.thumb:SetShown(on) end)
    list.empty = ns.Text(list, 13)
    list.empty:SetPoint("CENTER")
    list.empty:SetTextColor(unpack(ns.colors.dim))
    list.empty:SetText(empty or "")
    return list
end

-- -------------------------------------------------------------- details
local TICK = 16
local TITLE, SUB, LINE = 18, 14, 15      -- the details' title, its sub-line, a line of its text

local function Tick(foot, spec)
    local b = CreateFrame("Button", nil, foot)
    b:SetHeight(TICK)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(TICK, TICK)
    b.box:SetPoint("LEFT")
    Well(b.box, 1)
    b.check = b.box:CreateTexture(nil, "ARTWORK")
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.label = ns.Text(b, 12)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 5, 0)
    b.label:SetText(spec.label)
    b:SetWidth(TICK + 5 + b.label:GetStringWidth() + 4)
    b:SetScript("OnClick", function(self)
        if self.enabled then spec.click(not self.on) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(spec.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Set(on, enabled)
        self.on, self.enabled = on and true or false, enabled ~= false
        self.check:SetShown(self.on)
        self.label:SetTextColor(unpack(self.enabled and ns.colors.text or ns.colors.dim))
        self:SetAlpha(self.enabled and 1 or 0.5)
    end
    return b
end

function ns.character.Details(foot, ticks, nothing, lines)
    local d = { ticks = {} }
    lines = lines or 3
    d.title = ns.Text(foot, 15)
    d.title:SetPoint("TOP", 0, -2)
    d.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    d.sub = ns.Text(foot, 12)
    d.sub:SetPoint("TOP", d.title, "BOTTOM", 0, -3)
    d.sub:SetTextColor(unpack(ns.colors.dim))
    d.bar = Bar(foot, 220)
    d.bar:SetPoint("TOP", d.sub, "BOTTOM", 0, -5)
    d.text = ns.PlainText(foot, 12)
    d.text:SetPoint("TOPLEFT", 4, -(TITLE + 3 + SUB + 5 + BAR_H + 6))
    d.text:SetPoint("TOPRIGHT", -4, -(TITLE + 3 + SUB + 5 + BAR_H + 6))
    d.text:SetJustifyH("LEFT")
    d.text:SetJustifyV("TOP")
    d.text:SetHeight(lines * LINE)           -- more trail off
    d.nothing = ns.Text(foot, 13)
    d.nothing:SetPoint("CENTER")
    d.nothing:SetTextColor(unpack(ns.colors.dim))
    d.nothing:SetText(nothing or "")
    local prev
    for i, spec in ipairs(ticks or {}) do
        local b = Tick(foot, spec)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 16, 0) else b:SetPoint("BOTTOMLEFT", 4, 2) end
        d.ticks[i], prev = b, b
    end
    d.height = TITLE + 3 + SUB + 5 + BAR_H + 6 + lines * LINE + ((ticks and #ticks > 0) and (6 + TICK + 2) or 0)
    local parts = { d.title, d.sub, d.bar, d.text }
    function d:Set(info)
        for _, p in ipairs(parts) do p:SetShown(info ~= nil) end
        for _, b in ipairs(self.ticks) do b:SetShown(info ~= nil) end
        self.nothing:SetShown(info == nil)
        if not info then return end
        self.title:SetText(info.title or "")
        self.sub:SetText(info.sub or "")
        self.bar:SetShown(info.bar ~= nil)
        if info.bar then self.bar:Fill(info.bar) end
        local text = info.text or ""
        if info.lines then
            text = (text ~= "" and text .. "\n\n" or "") .. table.concat(info.lines, "\n")
        end
        self.text:SetText(text)
    end
    return d
end
