-- What the list pages share (Reputation, Currency, Skills, Statistics):
-- a scrolling list of headers and rows over the page, and the details
-- under it.
--
--   ns.character.List(body) -> list
--     list:Set(rows)   draws them; each row is
--       { header = true, label, collapsed, depth, click(), bright }   a heading: ± at its
--                                                     right; bright, a stronger band
--       { label, depth, icon, value, bar = { min, max, cur, color, text },
--         selected, click(button), enter(row), dim, color, inset }   an entry; inset,
--                                                     how far short of the right its label stops
--     an entry may also have (the quest tracker's):
--       font = { path, size }   its label's, Medalluin's at 12 without
--       pad                     a gap before what follows, past its depth's indent
--       middle()                its middle click (no other entry hears that button)
--       badge = { atlas, file, tint, size }   a mark before its label: the
--                               atlas where the client has it, else the file
--                               (tinted); size square
--       lead = "bullet" | "mid" | "last" | "pass" | "blank", leadWidth
--                               before the label: a dot, a tree's branch (├ └),
--                               its stem going on past a wrapped line (│), or room
--       group                   rows with the same group light together under
--                               the pointer, the row's own glow then off
--     list:Draw()      again, at the same scroll (after the body's height changes)
--     list.fade = true  headings fade out to the right (the quest tracker's,
--                       over the world), where the client has gradients
--     list.ornate = true  headings in a gold metal rim, a margin above and
--                       below each (the professions'): a heading's row is
--                       taller, its band inset, so rows are no longer even
--     list.row          a row's height (22)
--
--   ns.character.Details(foot, ticks, nothing, lines) -> details
--     details:Set{ title, sub, bar, text, lines }   (nil hides the lot; empty says so)
--     ticks = { { label, tip, click(on) } ... }: details.ticks[i]:Set(on, enabled)
--   ns.character.Tick(parent, { label, tip, click(on), at (its tooltip's
--   anchor, as ns.Tip takes) }) -> one such tick, alone
--     nothing: what it says with nothing chosen; lines: how many its text runs to (3)
--
-- The list fills the body; the wheel scrolls it a row at a time, and a thin
-- thumb on its right says where it is when there is more than it shows.
local _, ns = ...

local ROW, INDENT, BAR_W, BAR_H, ICON = 22, 12, 150, 16, 18
local LEAD, STEM, DOT = 12, 1, 4        -- a lead's room, its stem's width, a bullet's size
local MARGIN = 6                        -- an ornate heading's room above and below its band
local METAL_LIT = { 0.98, 0.88, 0.58 }  -- the rim's lit edge
local METAL_DARK = { 0.36, 0.27, 0.10 } -- its shadowed edge
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
    r.glow = r:CreateTexture(nil, "HIGHLIGHT")
    r.glow:SetAllPoints()
    r.glow:SetColorTexture(1, 1, 1, 0.06)
    -- the group's light, the glow's colour, on every row of it
    r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    r.lit:SetAllPoints()
    r.lit:SetColorTexture(1, 1, 1, 0.06)
    r.lit:Hide()
    -- an ornate heading's rim: lit along the top, shadowed along the
    -- bottom, its sides running from one to the other; a shine inside
    r.rim = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = r:CreateTexture(nil, "BORDER")
        r.rim[side] = t
        t:Hide()
    end
    r.shine = r:CreateTexture(nil, "BORDER")
    r.shine:SetHeight(1)
    r.shine:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.badge = r:CreateTexture(nil, "ARTWORK")
    -- a lead: a dot, or a stem down the row and a branch across to the label
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(DOT, DOT)
    r.stem = r:CreateTexture(nil, "ARTWORK")
    r.stem:SetWidth(STEM)
    r.branch = r:CreateTexture(nil, "ARTWORK")
    r.branch:SetHeight(STEM)
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
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    r:SetScript("OnClick", function(self, button)
        local d = self.data
        if not d then return end
        -- the middle button only for an entry that asks for it
        if button == "MiddleButton" then
            if d.middle then d.middle() end
        elseif d.click then
            d.click(button)
        end
    end)
    r:SetScript("OnEnter", function(self)
        list:Light(self.data and self.data.group)
        if self.data and self.data.enter then self.data.enter(self) end
    end)
    r:SetScript("OnLeave", function()
        list:Light(nil)
        GameTooltip:Hide()
    end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) list:Scroll(-delta) end)
    return r
end

-- The mark before a label: the atlas where the client has one, its own
-- colours; else the file, tinted.
local function Badge(t, b)
    local atlas = b.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(b.atlas) and b.atlas
    if atlas then
        t:SetAtlas(atlas)
        t:SetVertexColor(1, 1, 1)
    else
        t:SetTexture(b.file)
        t:SetTexCoord(0, 1, 0, 1)
        local c = b.tint or { 1, 1, 1 }
        t:SetVertexColor(c[1], c[2], c[3])
    end
    t:SetDesaturated(not atlas and b.tint ~= nil)
end
ns.character.Badge = Badge     -- the NPC windows' quest marks too (npc/window.lua)

-- The lead at x, w wide, in the label's colour: a dot, or a stem (the
-- whole row, or down to the middle for the last) and a branch from it.
local function Lead(r, d, x, w, c)
    local kind = d.lead
    local mid = x + math.floor(w / 2) - 2
    r.dot:SetShown(kind == "bullet")
    r.stem:SetShown(kind == "mid" or kind == "last" or kind == "pass")
    r.branch:SetShown(kind == "mid" or kind == "last")
    for _, t in ipairs({ r.dot, r.stem, r.branch }) do t:SetColorTexture(c[1], c[2], c[3], 0.6) end
    r.dot:ClearAllPoints()
    r.dot:SetPoint("CENTER", r, "LEFT", mid, 0)
    r.stem:ClearAllPoints()
    r.stem:SetPoint("TOPLEFT", mid, 0)
    r.stem:SetPoint("BOTTOMLEFT", mid, kind == "last" and r:GetHeight() / 2 or 0)
    r.branch:ClearAllPoints()
    r.branch:SetPoint("LEFT", r, "LEFT", mid, 0)
    r.branch:SetPoint("RIGHT", r, "LEFT", x + w - 2, 0)
end

-- An ornate heading's band, inset by the margin, in its metal rim; any
-- other row's band is the whole row, and no rim.
local function Rim(r, on)
    local inset = on and MARGIN or 0
    for _, t in ipairs({ r.fill, r.mark, r.glow, r.lit }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -inset)
        t:SetPoint("BOTTOMRIGHT", 0, inset)
    end
    for _, t in pairs(r.rim) do t:SetShown(on) end
    r.shine:SetShown(on)
    if not on then return end
    local rim = r.rim
    rim.TOP:ClearAllPoints()
    rim.TOP:SetPoint("TOPLEFT", 0, -inset)
    rim.TOP:SetPoint("TOPRIGHT", 0, -inset)
    rim.TOP:SetHeight(1)
    rim.TOP:SetColorTexture(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 1)
    rim.BOTTOM:ClearAllPoints()
    rim.BOTTOM:SetPoint("BOTTOMLEFT", 0, inset)
    rim.BOTTOM:SetPoint("BOTTOMRIGHT", 0, inset)
    rim.BOTTOM:SetHeight(1)
    rim.BOTTOM:SetColorTexture(METAL_DARK[1], METAL_DARK[2], METAL_DARK[3], 1)
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local t = rim[side]
        t:ClearAllPoints()
        t:SetPoint("TOP" .. side, 0, -inset)
        t:SetPoint("BOTTOM" .. side, 0, inset)
        t:SetWidth(1)
        if t.SetGradient and CreateColor then
            t:SetColorTexture(1, 1, 1, 1)
            t:SetGradient("VERTICAL", CreateColor(METAL_DARK[1], METAL_DARK[2], METAL_DARK[3], 1),
                CreateColor(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 1))
        else
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        end
    end
    r.shine:ClearAllPoints()
    r.shine:SetPoint("TOPLEFT", 1, -(inset + 1))
    r.shine:SetPoint("TOPRIGHT", -1, -(inset + 1))
    r.shine:SetColorTexture(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 0.35)
end

local function Paint(r, d, list)
    r.data = d
    Rim(r, list.ornate and d.header and true or false)
    local depth = d.depth or 0
    local x = 6 + depth * INDENT + (d.pad or 0)
    local font = d.font or { ns.font, 12 }
    if r.font ~= font[1] .. font[2] then
        r.label:SetFont(font[1], font[2], "")
        r.font = font[1] .. font[2]
    end
    r.icon:SetShown(d.icon ~= nil)
    if d.icon then
        r.icon:SetTexture(d.icon)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", x, 0)
        x = x + ICON + 4
    end
    r.badge:SetShown(d.badge ~= nil)
    if d.badge then
        local size = d.badge.size or ICON
        Badge(r.badge, d.badge)
        r.badge:SetSize(size, size)
        r.badge:ClearAllPoints()
        r.badge:SetPoint("LEFT", x, 0)
        x = x + size + 4
    end
    local lead = d.lead and d.leadWidth or LEAD
    Lead(r, d, x, lead, d.dim and ns.colors.dim or d.color or ns.colors.text)
    if d.lead then x = x + lead end
    r.glow:SetShown(d.group == nil)
    r.lit:SetShown(d.group ~= nil and d.group == list.lit)
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", x, 0)
    r.label:SetText(d.label or "")
    if d.header then
        local a = d.bright and 0.55 or depth == 0 and 0.30 or 0.15
        if list.ornate and r.fill.SetGradient and CreateColor then
            r.fill:SetColorTexture(1, 1, 1, 1)
            r.fill:SetGradient("VERTICAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a * 0.5),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a * 1.5))
        elseif list.fade and r.fill.SetGradient and CreateColor then
            r.fill:SetColorTexture(1, 1, 1, 1)
            r.fill:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0))
        else
            r.fill:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a)
        end
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
    r.label:SetPoint("RIGHT", r, "RIGHT", d.inset and -d.inset or d.bar and -(BAR_W + 10) or d.value and -60 or -24, 0)
end

-- ----------------------------------------------------------------- list
local List = {}

function List:Shown() return math.max(1, math.floor((self.body:GetHeight() or 0) / self.row)) end

-- the rows of a group lit together (nil: none)
function List:Light(group)
    self.lit = group
    for _, r in ipairs(self.rows) do
        r.lit:SetShown(group ~= nil and r.data ~= nil and r.data.group == group)
    end
end

-- a row's height: an ornate heading's takes its margins
function List:Height(d)
    return self.ornate and d.header and self.row + 2 * MARGIN or self.row
end

-- the furthest the list scrolls: the first row from which the rest fit
function List:Most()
    if not self.ornate then return math.max(0, #self.data - self:Shown()) end
    local room, y = self.body:GetHeight() or 0, 0
    for k = #self.data, 1, -1 do
        y = y + self:Height(self.data[k])
        if y > room then return k end
    end
    return 0
end

function List:Scroll(lines)
    local most = self:Most()
    self.offset = math.max(0, math.min(most, self.offset + lines))
    self:Draw()
end

-- An ornate list's rows, each as tall as it is, down to the body's foot
-- (one at least).
function List:DrawOrnate()
    self.offset = math.max(0, math.min(self.offset, self:Most()))
    local room, y, n = self.body:GetHeight() or 0, 0, 0
    for k = self.offset + 1, #self.data do
        local d = self.data[k]
        local h = self:Height(d)
        if n > 0 and y + h > room then break end
        n = n + 1
        local r = self.rows[n]
        if not r then
            r = Row(self)
            self.rows[n] = r
        end
        r:SetHeight(h)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", -6, -y)
        r:Show()
        Paint(r, d, self)
        y = y + h
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    local total, most = #self.data, self:Most()
    self.empty:SetShown(total == 0)
    self.track:SetShown(most > 0)
    if most > 0 then
        local h = room
        local size = math.max(12, h * n / total)
        self.thumb:SetHeight(size)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - size) * self.offset / most)
    end
end

function List:Draw()
    if self.ornate then return self:DrawOrnate() end
    local shown = self:Shown()
    self.offset = math.max(0, math.min(self.offset, #self.data - shown))
    for i = 1, shown do
        local r = self.rows[i]
        if not r then
            r = Row(self)
            self.rows[i] = r
        end
        r:SetHeight(self.row)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * self.row)
        r:SetPoint("TOPRIGHT", -6, -(i - 1) * self.row)
        local d = self.data[self.offset + i]
        r:SetShown(d ~= nil)
        if d then Paint(r, d, self) end
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    local total = #self.data
    self.empty:SetShown(total == 0)
    self.track:SetShown(total > shown)
    if total > shown then
        local h = shown * self.row
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
    list.body, list.rows, list.data, list.offset, list.row = body, {}, {}, 0, ROW
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
        ns.Tip(self, spec.at or "ANCHOR_TOP", { title = spec.tip, color = ns.colors.white, wrap = true })
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

ns.character.Tick = Tick

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
    -- the line said when nothing is chosen: as wide as the foot, wrapping
    -- (one with only its centre placed runs past the window's edges)
    d.nothing = ns.Text(foot, 13)
    d.nothing:SetPoint("LEFT", 8, 0)
    d.nothing:SetPoint("RIGHT", -8, 0)
    d.nothing:SetJustifyH("CENTER")
    d.nothing:SetWordWrap(true)
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
