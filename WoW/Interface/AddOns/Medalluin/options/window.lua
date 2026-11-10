-- Medalluin's settings window: a sidebar down the left lists the pages
-- under their categories (pages.lua's), with a search over every option
-- above them; the page shown has a header (its title, where it sits, its
-- master's switch) over its options, each group a section of label-left
-- rows, the sections in two columns. Modules, the page it opens on, has a
-- card for each part with a master. The title on the top edge, or the
-- window itself, drags it; where it is left is kept. The footer names the
-- profile being edited and, once an option that waits for one has
-- changed, asks for a reload.
--
-- Built the first time it opens (/mdlui, the minimap button, the button on
-- Options > AddOns > Medalluin); pages.lua says what is on it.
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors

local W, H = 900, 600
local PAD, SIDE_W, TITLE_ROOM, FOOT = 14, 200, 22, 46
local HEAD_H, TAB_H, COL_GAP, SEC_GAP = 54, 24, 22, 14
local ITEM_H, CAT_H, SEARCH_H, LINK_H = 22, 22, 22, 20
local CARD_H, CARD_GAP = 44, 8
local X = PAD + SIDE_W + 14             -- the header's and body's left
local ROUND = ns.media .. "strips\\round"
local GREEN = { 0.42, 0.78, 0.36 }

local pages        -- pages.lua's, built at login
local categories
local window, side, nav, navChild, search, tabStrip, body, scroll, thumb, flash
local finds        -- a search's page: the sections it matched, lent by their own
local colW         -- a section's width
local footProfile, footReload
local built = {}   -- page frames by path ("general", "console/unit")
ns.optionPages = built
local current      -- the path shown
local lastTab = {} -- each tabbed page's tab, by page id
local reloadAt     -- what the reload options were at login
local controls = {}
ns.optionControls = controls
local place = {}   -- each path's category and sidebar item
local index = {}   -- what search looks through
local query        -- what it is looking for, while it shows what it found
local results = {}

-- ------------------------------------------------------------ pages
local function Find(path)
    local id, tab = tostring(path):match("^([^/]+)/?(.*)$")
    for _, page in ipairs(pages) do
        if page.id == id then
            if not page.tabs then return page, nil end
            tab = tab ~= "" and tab or lastTab[id] or page.tabs[1].id
            for _, t in ipairs(page.tabs) do
                if t.id == tab then return page, t end
            end
            return page, page.tabs[1]
        end
    end
end

local function Each(fn)
    for _, page in ipairs(pages) do
        if page.tabs then
            for _, tab in ipairs(page.tabs) do fn(tab, page.id .. "/" .. tab.id, page, tab) end
        else
            fn(page, page.id, page, nil)
        end
    end
end

-- A sidebar item's name, and whether it is a tabbed page listed whole (its
-- tabs a row under its header).
local function Whole(item)
    local page = Find(item)
    return page and page.tabs and not item:find("/") and page
end
local function ItemName(item)
    local page, tab = Find(item)
    if not page then return item end
    return (tab and not Whole(item)) and tab.name or page.name
end

-- Every path's category and item.
local function Places()
    for _, cat in ipairs(categories) do
        for _, item in ipairs(cat.items) do
            local page, tab = Find(item)
            if Whole(item) then
                for _, t in ipairs(page.tabs) do place[item .. "/" .. t.id] = { cat = cat, item = item } end
            elseif page then
                place[tab and (page.id .. "/" .. tab.id) or page.id] = { cat = cat, item = item }
            end
        end
    end
end

-- The options that take effect after a reload, and the profile: what they
-- were at login.
local function ReloadKeys(fn)
    fn("consoleProfile")
    Each(function(content)
        if content.master and content.master.reload then fn(content.master.key) end
        for _, group in ipairs(content.groups) do
            for _, item in ipairs(group.items) do
                if item.reload then fn(item.key) end
            end
        end
    end)
end
local function NeedsReload()
    local needs = false
    ReloadKeys(function(key)
        if ns.db[key] ~= reloadAt[key] then needs = true end
    end)
    return needs
end

-- ------------------------------------------------------------ a page
-- An option's control: in a section's row (row true), or a header's switch
-- (row "switch", label by it).
local function Control(parent, spec, width, row, label)
    local c
    if row == "switch" then
        c = UI.Switch(parent, spec, label)
    elseif spec.kind == "check" then
        c = UI.Check(parent, spec, width, row)
    elseif spec.kind == "choice" then
        c = UI.Choice(parent, spec, width, row)
    elseif spec.kind == "color" then
        c = UI.Color(parent, spec, width, row)
    elseif spec.kind == "slider" then
        c = UI.Slider(parent, spec, width, row)
    elseif spec.kind == "key" then
        c = UI.Key(parent, spec, width)
    else
        c = UI.Button(parent, spec.label, math.min(width, 200), 24, spec.click, spec.tip)
    end
    -- a control drawn greyed while another option is off, or while its
    -- page's own test says no (spec.needs; content.enabled) unless it is
    -- for every profile there (spec.always)
    c.needs, c.always = spec.needs, spec.always
    -- a key control is found by its binding's name
    if spec.key or spec.command then controls[spec.key or spec.command] = c end
    return c
end

-- A page's header, over its body: its title, where it sits ("Console >
-- Action Bars · Kept per profile"), its master's switch, a hairline under.
-- Shown with its page.
local function Header(f, content, path, page, tab)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", window, "TOPLEFT", X, -(PAD + TITLE_ROOM))
    head:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -(PAD + TITLE_ROOM))
    head:SetHeight(HEAD_H)
    local at = place[path]
    local whole = at and Whole(at.item)
    head.title = UI.Serif(head, 20, C.goldBright)
    head.title:SetPoint("TOPLEFT", 0, -2)
    head.title:SetText(at and ItemName(at.item) or (tab and tab.name or page.name))
    local parts = {}
    if at then
        table.insert(parts, at.cat.name)
        table.insert(parts, ItemName(at.item))
        if whole then table.insert(parts, tab.name) end
    end
    local scope = content.scope or at and at.cat.scope
    head.crumb = UI.Plain(head, 12, C.dim)
    head.crumb:SetPoint("TOPLEFT", 0, -30)
    head.crumb:SetText(table.concat(parts, "  >  ") .. (scope and ("   \194\183   " .. scope) or ""))
    if content.master then
        -- a tab's switch names what it turns on: the page's own is Enabled
        local m = Control(head, content.master, nil, "switch", whole and content.master.label or "Enabled")
        m:SetPoint("TOPRIGHT", 0, -6)
        f.master = m
        table.insert(f.controls, m)
    end
    local rule = UI.Fill(head, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    head:Hide()
    f.head = head
end

local function Where(path, title)
    local at = place[path]
    local s = at and (at.cat.name .. " > " .. ItemName(at.item)) or path
    local _, tab = Find(path)
    if at and Whole(at.item) and tab then s = s .. " > " .. tab.name end
    return title and (s .. " > " .. title) or s
end

-- A group as a section: its heading over a hairline, its tip, then an
-- option a row.
local function Section(f, group, width, path)
    local s = CreateFrame("Frame", nil, f)
    s:SetWidth(width)
    s.title = UI.Serif(s, 14, C.goldBright)
    s.title:SetPoint("TOPLEFT", 0, 0)
    s.title:SetText(group.title)
    local rule = UI.Fill(s, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -20)
    rule:SetPoint("TOPRIGHT", 0, -20)
    local y = -28
    if group.tip then
        local tip = UI.Plain(s, 11, C.dim)
        tip:SetPoint("TOPLEFT", 6, y)
        tip:SetWidth(width - 6)
        tip:SetJustifyH("LEFT")
        tip:SetText(group.tip)
        y = y - math.ceil(tip:GetStringHeight()) - 8
    end
    local where = Where(path, group.title)
    table.insert(index, { label = group.title, path = path, section = s, where = Where(path) })
    for _, spec in ipairs(group.items) do
        local c = Control(s, spec, width - 6, true)
        c:SetPoint("TOPLEFT", 6, y)
        table.insert(f.controls, c)
        y = y - c:GetHeight() - 6
        if spec.label then
            table.insert(index, { label = spec.label, path = path, section = s, control = c, where = where })
        end
    end
    s:SetHeight(-y)
    return s
end

-- The page's intro, then its sections in two columns, each in the shorter.
local function Build(content, path, page, tab, width)
    local f = CreateFrame("Frame", nil, scroll)
    f:SetWidth(width)
    f.controls = {}
    f.sections = {}
    f.enabled = content.enabled
    Header(f, content, path, page, tab)
    local y = -4
    if content.intro then
        local intro = UI.Plain(f, 12, C.dim)
        intro:SetPoint("TOPLEFT", 0, y)
        intro:SetWidth(width)
        intro:SetJustifyH("LEFT")
        intro:SetText(content.intro)
        f.intro = intro
        y = y - math.ceil(intro:GetStringHeight()) - 16
    end
    local tops = { y, y }
    for i, group in ipairs(content.groups) do
        local col = tops[2] > tops[1] and 2 or 1
        local s = Section(f, group, colW, path)
        s:SetPoint("TOPLEFT", (col - 1) * (colW + COL_GAP), tops[col])
        s.home, s.x, s.top, s.col = f, (col - 1) * (colW + COL_GAP), -tops[col], col
        tops[col] = tops[col] - s:GetHeight() - SEC_GAP
        f.sections[i] = s
    end
    f:SetHeight(-math.min(tops[1], tops[2]) + 4)
    f:Hide()
    return f
end

-- ------------------------------------------------------------ modules
local Select

-- A part's card on Modules: its medallion, name, tag and line, its master's
-- switch (not the header's: the header's is the option's control); a click
-- off the switch opens its page. An addon's card has no switch, only
-- whether the addon is loaded.
local function CardName(content)
    local name = (content.master.label:gsub(" window$", ""))
    return #name > 22 and content.name or name
end

local function Card(parent, content, path, width, names)
    local m = content.master
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, CARD_H)
    b.path, b.needs, b.content = path, m and m.needs, content
    UI.Fill(b, "BACKGROUND", C.ink, 1):SetAllPoints()
    b.edge = UI.Outline(b, "BORDER", C.goldDark, 0)
    local ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(ROUND)
    ring:SetSize(32, 32)
    ring:SetPoint("LEFT", 8, 0)
    ring:SetVertexColor(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
    local well = b:CreateTexture(nil, "ARTWORK", nil, 2)
    well:SetTexture(ROUND)
    well:SetSize(28, 28)
    well:SetPoint("CENTER", ring, "CENTER", 0, 0)
    well:SetVertexColor(C.well[1], C.well[2], C.well[3], 1)
    b.glyph = b:CreateTexture(nil, "ARTWORK", nil, 3)
    b.glyph:SetTexture(ns.media .. "strips\\" .. (content.glyph or "help"))
    b.glyph:SetSize(18, 18)
    b.glyph:SetPoint("CENTER", ring, "CENTER", 0, 0)
    b.name = UI.Serif(b, 13, C.gold)
    b.name:SetPoint("TOPLEFT", 50, -7)
    b.name:SetText(m and CardName(content) or content.name)
    -- the tag: Forever, what it needs, or the addon's state
    local tag = CreateFrame("Frame", nil, b)
    tag:SetHeight(14)
    tag:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
    UI.Outline(tag, "BORDER", C.goldDark, 0)
    tag.text = UI.Plain(tag, 10, C.gold)
    tag.text:SetPoint("CENTER", 0, 0)
    b.tag = tag
    local function Tag(text)
        tag.text:SetText(text or "")
        tag:SetWidth(math.ceil(tag.text:GetStringWidth()) + 10)
        tag:SetShown(text ~= nil)
    end
    Tag(content.forever and "Forever" or b.needs and ("Needs " .. (names[b.needs] or b.needs)) or nil)
    b.blurb = UI.Plain(b, 11, C.dim)
    b.blurb:SetPoint("BOTTOMLEFT", 50, 7)
    b.blurb:SetPoint("RIGHT", b, "RIGHT", -(UI.SWITCH_W + 18), 0)
    b.blurb:SetJustifyH("LEFT")
    b.blurb:SetWordWrap(false)
    b.blurb:SetText(content.blurb or "")
    if m then
        b.switch = UI.Switch(b, m)
        b.switch:SetPoint("RIGHT", -10, 0)
    end
    b:SetScript("OnClick", function(self) Select(self.path) end)
    b:SetScript("OnEnter", function(self)
        local why = self.off and ("Turn on " .. (names[self.needs] or self.needs) .. " first.")
        UI.Tip(self, self.name:GetText(), why or (m and m.tip) or content.intro)
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    function b:Refresh(enabled)
        local on
        if m then
            self.switch:Refresh(enabled)
            on = enabled and UI.Get(m) and true or false
        else
            on = content.enabled and content.enabled() and true or false
            Tag(on and "Loaded" or "Addon off")
        end
        self.off = m and not enabled
        local e = on and C.gold or C.goldDark
        for _, t in ipairs(self.edge) do t:SetColorTexture(e[1], e[2], e[3], 1) end
        local n = enabled and (on and C.goldBright or C.gold) or C.dim
        self.name:SetTextColor(n[1], n[2], n[3])
        local g = on and C.goldBright or C.dim
        self.glyph:SetVertexColor(g[1], g[2], g[3], 1)
    end
    return b
end

-- Every part with a master, a card each under the sidebar's categories.
local function Modules(content, path, page, width)
    local f = CreateFrame("Frame", nil, scroll)
    f:SetWidth(width)
    f.controls = {}
    f.sections = {}
    f.cards = {}
    Header(f, content, path, page, nil)
    local intro = UI.Plain(f, 12, C.dim)
    intro:SetPoint("TOPLEFT", 0, -4)
    intro:SetWidth(width)
    intro:SetJustifyH("LEFT")
    intro:SetText(content.intro)
    f.intro = intro
    local y = -4 - math.ceil(intro:GetStringHeight()) - 16
    -- the parts, and the names of those another needs
    local names = {}
    local function Parts(cat)
        local out = {}
        local function Add(c, p)
            if c.master and c.master.kind == "check" then
                table.insert(out, { c, p })
                names[c.master.key] = CardName(c)
            elseif c.addon then
                table.insert(out, { c, p })
            end
        end
        for _, item in ipairs(cat.items) do
            local pg, tab = Find(item)
            if Whole(item) then
                for _, t in ipairs(pg.tabs) do Add(t, item .. "/" .. t.id) end
            elseif pg then
                Add(tab or pg, item)
            end
        end
        return out
    end
    local lists = {}
    for i, cat in ipairs(categories) do lists[i] = Parts(cat) end
    local cardW = math.floor((width - CARD_GAP) / 2)
    for i, cat in ipairs(categories) do
        local list = lists[i]
        if #list > 0 then
            local s = CreateFrame("Frame", nil, f)
            s:SetPoint("TOPLEFT", 0, y)
            s:SetWidth(width)
            s.title = UI.Serif(s, 14, C.goldBright)
            s.title:SetPoint("TOPLEFT", 0, 0)
            s.title:SetText(cat.name)
            s.note = UI.Plain(s, 11, C.dim)
            s.note:SetPoint("BOTTOMLEFT", s.title, "BOTTOMRIGHT", 10, 1)
            s.note:SetText(cat.note or cat.scope or "")
            local sy = -24
            for n, part in ipairs(list) do
                local card = Card(s, part[1], part[2], cardW, names)
                local col = (n - 1) % 2
                card:SetPoint("TOPLEFT", col * (cardW + CARD_GAP), sy)
                if col == 1 or n == #list then sy = sy - CARD_H - CARD_GAP end
                table.insert(f.controls, card)
                table.insert(f.cards, card)
            end
            s:SetHeight(-sy)
            s.top = -y
            table.insert(f.sections, s)
            y = y - s:GetHeight() - SEC_GAP
        end
    end
    f:SetHeight(-y + 4)
    f:Hide()
    return f
end

-- ------------------------------------------------------------ scrolling
local function Thumb()
    local range = scroll:GetVerticalScrollRange() or 0
    if range <= 0 then
        thumb:Hide()
        return
    end
    local view = scroll:GetHeight()
    local size = math.max(24, view * view / (view + range))
    thumb:SetHeight(size)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(view - size) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function Scroll(delta)
    local range = scroll:GetVerticalScrollRange() or 0
    local to = math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * 40))
    scroll:SetVerticalScroll(to)
    Thumb()
end

-- ------------------------------------------------------------ the sidebar
local function Folded(name)
    local folded = ns.db.optionsFolded
    return type(folded) == "table" and folded[name] or false
end

local function Fold(name)
    local folded = type(ns.db.optionsFolded) == "table" and ns.db.optionsFolded or {}
    folded[name] = not folded[name] or nil
    ns.db.optionsFolded = next(folded) and folded or false
end

-- The rows down the sidebar: a heading for each category, a row for each
-- item. While a search shows what it found, no item is lit.
local function Nav()
    local y = -2
    for _, h in ipairs(side.heads) do h:Hide() end
    for _, r in ipairs(side.rows) do r:Hide() end
    local item = not query and current and place[current] and place[current].item
    for _, h in ipairs(side.heads) do
        -- the shown page's category stays open
        local here = false
        for _, r in ipairs(h.rows) do here = here or r.path == item end
        h.open = here or not Folded(h.cat.name)
        h.sign:SetText(h.open and "" or "+")
        h:SetPoint("TOPLEFT", 0, y)
        h:SetPoint("TOPRIGHT", 0, y)
        h:Show()
        y = y - CAT_H
        for _, r in ipairs(h.rows) do
            if h.open then
                r:SetPoint("TOPLEFT", 0, y)
                r:SetPoint("TOPRIGHT", 0, y)
                r:Show()
                y = y - ITEM_H
            end
            local on = r.path == item
            r.lit:SetShown(on)
            r.bar:SetShown(on)
            local c = on and C.goldBright or C.gold
            r.text:SetTextColor(c[1], c[2], c[3])
        end
        y = y - 4
    end
    navChild:SetHeight(-y + 4)
    local range = math.max(0, navChild:GetHeight() - nav:GetHeight())
    if nav:GetVerticalScroll() > range then nav:SetVerticalScroll(range) end
end

local function Head(cat)
    local h = CreateFrame("Button", nil, navChild)
    h:SetHeight(CAT_H)
    h.cat = cat
    h.text = UI.Plain(h, 10, C.dim)
    h.text:SetPoint("LEFT", 10, -2)
    h.text:SetText(cat.name:upper())
    h.sign = UI.Plain(h, 12, C.dim)
    h.sign:SetPoint("RIGHT", -8, -2)
    local rule = UI.Fill(h, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", h, "RIGHT", -22, -2)
    h:SetScript("OnClick", function(self)
        Fold(self.cat.name)
        Nav()
    end)
    h.rows = {}
    return h
end

local function Item(path)
    local r = CreateFrame("Button", nil, navChild)
    r:SetHeight(ITEM_H)
    r.path = path
    r.lit = UI.Fill(r, "BACKGROUND", C.selected, 1)
    r.lit:SetAllPoints()
    r.lit:Hide()
    r.bar = UI.Fill(r, "ARTWORK", C.gold)
    r.bar:SetWidth(3)
    r.bar:SetPoint("TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMLEFT", 0, 0)
    r.bar:Hide()
    r.text = UI.Serif(r, 12, C.gold)
    r.text:SetPoint("LEFT", 20, 0)
    r.text:SetText(ItemName(path))
    local content = Whole(path) and Whole(path).tabs[1] or select(2, Find(path)) or Find(path)
    r.master = content.master and content.master.kind == "check" and content.master or nil
    r.addon = content.addon and content or nil
    if r.master or r.addon then
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetTexture(ROUND)
        r.dot:SetSize(7, 7)
        r.dot:SetPoint("RIGHT", -10, 0)
    end
    local function Lit(self, c)
        if not self.lit:IsShown() then self.text:SetTextColor(c[1], c[2], c[3]) end
    end
    r:SetScript("OnEnter", function(self) Lit(self, C.goldBright) end)
    r:SetScript("OnLeave", function(self) Lit(self, C.gold) end)
    r:SetScript("OnClick", function(self) Select(self.path) end)
    return r
end

-- ------------------------------------------------------------ search
local function Flash(c)
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", c, "TOPLEFT", -4, 3)
    flash:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 4, -3)
    flash.left = 1.2
    flash.control = c
    flash:SetAlpha(1)
    flash:Show()
end

-- The sections a search lent its page, back on their own pages.
local function Home()
    for _, s in ipairs(finds.lent) do
        s:SetParent(s.home)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", s.home, "TOPLEFT", s.x, -s.top)
    end
    finds.lent = {}
end

-- The search over: its page gone, the sections home; the box emptied too
-- when something else ends it (a page chosen).
local function EndSearch(clear)
    if not finds.on then return end
    query, results = nil, {}
    finds.on = false
    Home()
    finds:Hide()
    finds.head:Hide()
    if clear and search:GetText() ~= "" then search:SetText("") end
end

local function Choose(e)
    Select(e.path)
    local f = built[current]
    if e.section and f then
        local range = math.max(0, f:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.min(range, e.section.top))
        Thumb()
    end
    if e.control then Flash(e.control) end
end

-- A line over a match: where it is, a click opening it there.
local function Link(n)
    local b = finds.links[n]
    if b then return b end
    b = CreateFrame("Button", nil, finds)
    b:SetHeight(LINK_H)
    b.text = UI.Plain(b, 11, C.dim)
    b.text:SetPoint("LEFT", 0, 0)
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3]) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
    b:SetScript("OnClick", function(self) Choose(self.entry) end)
    finds.links[n] = b
    return b
end

-- What a search found, on the right: the pages whose names match, then each
-- section with a match (its own, lent: its options work there) under a
-- line saying where it is, in two columns.
local function Found()
    Home()
    local seen, sections, named = {}, {}, {}
    for _, e in ipairs(results) do
        if not e.section then
            table.insert(named, e)
        elseif not seen[e.section] then
            seen[e.section] = true
            table.insert(sections, e)
        end
    end
    for _, b in ipairs(finds.links) do b:Hide() end
    local n = 0
    local function Line(e, text, x, y, w)
        n = n + 1
        local b = Link(n)
        b.entry = e
        b.text:SetText(text)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, y)
        b:SetWidth(w)
        b:Show()
    end
    local width = finds:GetWidth()
    local y = -4
    for _, e in ipairs(named) do
        Line(e, "Open " .. e.label .. "   (" .. e.where .. ")", 0, y, width)
        y = y - LINK_H
    end
    if #named > 0 then y = y - 10 end
    local tops = { y, y }
    for _, e in ipairs(sections) do
        local s = e.section
        local col = tops[2] > tops[1] and 2 or 1
        local x = (col - 1) * (colW + COL_GAP)
        Line(e, Where(e.path) .. "  >", x, tops[col], colW)
        s:SetParent(finds)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", finds, "TOPLEFT", x, tops[col] - LINK_H - 2)
        table.insert(finds.lent, s)
        tops[col] = tops[col] - LINK_H - 2 - s:GetHeight() - SEC_GAP
    end
    finds.none:SetShown(#results == 0)
    finds.head.crumb:SetText(#results == 0 and ("Nothing matches \"" .. query .. "\".")
        or (#sections .. (#sections == 1 and " section" or " sections") .. " and "
            .. #named .. (#named == 1 and " page" or " pages") .. " match \"" .. query .. "\""))
    finds:SetHeight(-math.min(tops[1], tops[2]) + 4)
end

local function Search(text)
    text = tostring(text or ""):lower():match("^%s*(.-)%s*$")
    if #text < 2 then
        -- back to the page it was on
        if finds.on then
            EndSearch()
            Select(current)
        end
        return
    end
    query = text
    results = {}
    for _, e in ipairs(index) do
        if e.label:lower():find(query, 1, true) then table.insert(results, e) end
    end
    if not finds.on then
        finds.on = true
        for _, f in pairs(built) do
            f:Hide()
            f.head:Hide()
        end
        for _, t in ipairs(tabStrip.tabs) do t:Hide() end
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", window, "TOPLEFT", X, -(PAD + TITLE_ROOM + HEAD_H + 12))
        body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, FOOT + 4)
        finds:Show()
        finds.head:Show()
        scroll:SetScrollChild(finds)
        flash:Hide()
        UI.CloseMenu()
    end
    Found()
    scroll:SetVerticalScroll(0)
    Thumb()
    Nav()
end

local function SearchBox()
    local box = CreateFrame("EditBox", nil, side)
    box:SetHeight(SEARCH_H)
    box:SetPoint("TOPLEFT", 8, -8)
    box:SetPoint("TOPRIGHT", -8, -8)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    box:SetTextInsets(8, 8, 0, 0)
    box:SetMaxLetters(40)
    UI.Fill(box, "BACKGROUND", C.well, 1):SetAllPoints()
    box.edge = UI.Outline(box, "BORDER", C.goldDark, 0)
    box.hint = UI.Plain(box, 12, C.dim)
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText("Search options")
    box:SetScript("OnTextChanged", function(self)
        self.hint:SetShown((self:GetText() or "") == "")
        Search(self:GetText())
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        Search("")
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local first = finds.links[1]
        if first and first:IsShown() then Choose(first.entry) end
    end)
    box:SetScript("OnEditFocusGained", function(self)
        for _, t in ipairs(self.edge) do t:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1) end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        for _, t in ipairs(self.edge) do t:SetColorTexture(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1) end
    end)
    return box
end

-- ------------------------------------------------------------ redraw
local function Refresh()
    if not window then return end
    -- a master greys only with what it needs; all else with it too
    local function Has(c) return not c.needs or ns.db[c.needs] and true or false end
    for _, f in pairs(built) do
        local on = (not f.master or ns.db[f.master.spec.key] and Has(f.master))
            and (not f.enabled or f.enabled()) and true or false
        for _, c in ipairs(f.controls) do
            c:Refresh((c == f.master or c.always or on) and Has(c))
        end
    end
    -- the sidebar's dots: a part on, or off
    for _, r in ipairs(side.rows) do
        if r.dot then
            local on
            if r.master then
                on = ns.db[r.master.key] and Has(r.master)
            else
                on = r.addon.enabled and r.addon.enabled()
            end
            local c = on and GREEN or C.dim
            r.dot:SetVertexColor(c[1], c[2], c[3], 1)
            r.dot.on = on and true or false
        end
    end
    local name = ns.db.consoleProfile
    for _, p in ipairs(ns.PROFILE_NAMES) do
        if p[1] == name then name = p[2] end
    end
    footProfile:SetText("Profile: " .. name)
    footReload:SetShown(NeedsReload())
end
ns.RefreshOptions = Refresh

function Select(path)
    local page, tab = Find(path)
    if not page then return end
    EndSearch(true)
    if tab then lastTab[page.id] = tab.id end
    current = tab and (page.id .. "/" .. tab.id) or page.id
    local at = place[current]
    -- a tabbed page listed whole: its tabs under its header, the body under them
    for _, t in ipairs(tabStrip.tabs) do t:Hide() end
    local top = PAD + TITLE_ROOM + HEAD_H + 12
    if tab and at and Whole(at.item) then
        local x = 0
        for i, t in ipairs(page.tabs) do
            local b = tabStrip.tabs[i]
            b.page, b.tab = page, t
            b.text:SetText(t.name)
            b:SetWidth(math.ceil(b.text:GetStringWidth()) + 24)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", tabStrip, "BOTTOMLEFT", x, 0)
            local on = t == tab
            b.bg:SetColorTexture(unpack(on and { C.selected[1], C.selected[2], C.selected[3], 1 }
                or { C.ink[1], C.ink[2], C.ink[3], 1 }))
            for _, line in ipairs(b.edge) do
                local c = on and C.gold or C.goldDark
                line:SetColorTexture(c[1], c[2], c[3], 1)
            end
            b.edge[2]:SetShown(not on)
            local c = on and C.goldBright or C.dim
            b.text:SetTextColor(c[1], c[2], c[3])
            b:Show()
            x = x + b:GetWidth() + 4
        end
        top = top + TAB_H + 10
    end
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", window, "TOPLEFT", X, -top)
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, FOOT + 4)
    for p, f in pairs(built) do
        f:SetShown(p == current)
        f.head:SetShown(p == current)
    end
    scroll:SetScrollChild(built[current])
    scroll:SetVerticalScroll(0)
    flash:Hide()
    UI.CloseMenu()
    Nav()
    Refresh()
    Thumb()
end

-- ------------------------------------------------------------ the window
local function Remember()
    local point, _, relative, x, y = window:GetPoint()
    ns.db.optionsPoint = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

local function Grip(frame)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() window:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        if window.SetUserPlaced then window:SetUserPlaced(false) end
        Remember()
    end)
end

local function Sidebar()
    side = CreateFrame("Frame", nil, window)
    side:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_ROOM))
    side:SetPoint("BOTTOMLEFT", PAD, FOOT + 4)
    side:SetWidth(SIDE_W)
    UI.Skin(side, C.ink, 1)
    search = SearchBox()
    nav = CreateFrame("ScrollFrame", nil, side)
    nav:SetPoint("TOPLEFT", 3, -(8 + SEARCH_H + 8))
    nav:SetPoint("BOTTOMRIGHT", -3, 4)
    navChild = CreateFrame("Frame", nil, nav)
    navChild:SetWidth(SIDE_W - 6)
    navChild:SetHeight(1)
    nav:SetScrollChild(navChild)
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, navChild:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    side.heads, side.rows = {}, {}
    for _, cat in ipairs(categories) do
        local h = Head(cat)
        for _, item in ipairs(cat.items) do
            if Find(item) then
                local r = Item(item)
                table.insert(h.rows, r)
                table.insert(side.rows, r)
            end
        end
        table.insert(side.heads, h)
    end
    -- the pages' names are found too
    for _, cat in ipairs(categories) do
        for _, item in ipairs(cat.items) do
            if Find(item) then table.insert(index, { label = ItemName(item), path = item, where = cat.name }) end
        end
    end
end

local function TabStrip()
    tabStrip = CreateFrame("Frame", nil, window)
    tabStrip:SetPoint("TOPLEFT", window, "TOPLEFT", X, -(PAD + TITLE_ROOM + HEAD_H + 8))
    tabStrip:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -(PAD + TITLE_ROOM + HEAD_H + 8))
    tabStrip:SetHeight(TAB_H)
    tabStrip.tabs = {}
    local most = 0
    for _, page in ipairs(pages) do most = math.max(most, page.tabs and #page.tabs or 0) end
    for i = 1, most do
        local b = CreateFrame("Button", nil, tabStrip)
        b:SetHeight(TAB_H)
        b.bg = UI.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        b.edge = UI.Outline(b, "BORDER", C.goldDark, 0)
        b.text = UI.Serif(b, 12, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b:SetScript("OnClick", function(self) Select(self.page.id .. "/" .. self.tab.id) end)
        b:Hide()
        tabStrip.tabs[i] = b
    end
end

local function Footer()
    local rule = UI.Fill(window, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", PAD, FOOT - 8)
    rule:SetPoint("BOTTOMRIGHT", -PAD, FOOT - 8)
    footProfile = UI.Serif(window, 12, C.dim)
    footProfile:SetPoint("BOTTOMLEFT", PAD + 4, 16)
    local close = UI.Button(window, "Close", 96, 24, function() window:Hide() end, nil, true)
    close:SetPoint("BOTTOMRIGHT", -PAD, 10)
    local reload = UI.Button(window, "Reload UI", 104, 24, ReloadUI,
        "Reload the interface so a changed option takes effect.")
    reload:SetPoint("RIGHT", close, "LEFT", -8, 0)
    footReload = UI.Plain(window, 12, C.goldBright)
    footReload:SetPoint("RIGHT", reload, "LEFT", -12, 0)
    footReload:SetText("Some changes take effect after a reload.")
    footReload:Hide()
end

local function Window()
    if window then return end
    window = CreateFrame("Frame", "MedalluinOptions", UIParent)
    window:SetSize(W, H)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    Grip(window)
    local at = ns.db.optionsPoint
    if at then
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    UI.Skin(window, C.panel)
    window:Hide()
    -- Esc closes it, as it closes the game's own windows
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinOptions") end
    window:SetScript("OnHide", function() UI.CloseMenu() end)
    window:SetScript("OnShow", function() Refresh() end)

    -- the title, set into the top edge: a grip too
    local title = CreateFrame("Frame", nil, window)
    title:SetHeight(28)
    title:SetPoint("CENTER", window, "TOP", 0, 0)
    title:SetFrameLevel(window:GetFrameLevel() + 5)
    UI.Skin(title, C.ink)
    local text = UI.Serif(title, 15, C.goldBright)
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Medalluin")
    title:SetWidth(math.ceil(text:GetStringWidth()) + 44)
    Grip(title)
    window.title, window.titleBox = text, title

    local x = CreateFrame("Button", nil, window)
    x:SetSize(20, 20)
    x:SetPoint("TOPRIGHT", -8, -6)
    x.text = UI.Serif(x, 14, C.gold)
    x.text:SetPoint("CENTER", 0, 1)
    x.text:SetText("x")
    x:SetScript("OnClick", function() window:Hide() end)
    x:SetScript("OnEnter", function(self) self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3]) end)
    x:SetScript("OnLeave", function(self) self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
    window.closeX = x

    Places()
    Sidebar()
    TabStrip()

    body = CreateFrame("Frame", nil, window)
    scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -12, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    thumb = UI.Fill(body, "ARTWORK", C.goldDark)
    thumb:SetWidth(4)
    thumb:Hide()
    -- a search's match, outlined a moment
    flash = CreateFrame("Frame", nil, body)
    flash:SetFrameLevel(body:GetFrameLevel() + 20)
    UI.Outline(flash, "OVERLAY", C.goldBright, 0)
    flash:Hide()
    flash:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left <= 0 then self:Hide() else self:SetAlpha(self.left / 1.2) end
    end)
    Footer()
    -- its parts, by name (the harness reads them)
    window.tree, window.tabs, window.scroll, window.thumb = side, tabStrip.tabs, scroll, thumb
    window.search, window.nav, window.flash = search, nav, flash
    window.footProfile, window.footReload = footProfile, footReload

    local width = W - 2 * PAD - SIDE_W - 14 - 12
    colW = math.floor((width - COL_GAP) / 2)
    -- a search's page, its header saying what it found
    finds = CreateFrame("Frame", nil, scroll)
    finds:SetWidth(width)
    finds:SetHeight(1)
    finds.lent, finds.links = {}, {}
    finds.head = CreateFrame("Frame", nil, window)
    finds.head:SetPoint("TOPLEFT", window, "TOPLEFT", X, -(PAD + TITLE_ROOM))
    finds.head:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -(PAD + TITLE_ROOM))
    finds.head:SetHeight(HEAD_H)
    finds.head.title = UI.Serif(finds.head, 20, C.goldBright)
    finds.head.title:SetPoint("TOPLEFT", 0, -2)
    finds.head.title:SetText("Search")
    finds.head.crumb = UI.Plain(finds.head, 12, C.dim)
    finds.head.crumb:SetPoint("TOPLEFT", 0, -30)
    local rule = UI.Fill(finds.head, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    finds.none = UI.Plain(finds, 12, C.dim)
    finds.none:SetPoint("TOPLEFT", 0, -4)
    finds.none:SetText("No option, section or page has those letters in its name.")
    finds:Hide()
    finds.head:Hide()
    window.finds = finds
    Each(function(content, path, page, tab)
        built[path] = content.modules and Modules(content, path, page, width) or Build(content, path, page, tab, width)
    end)
    Select(current or "modules")
end

-- ------------------------------------------------------------ open
-- ns.OpenOptions(path): the window, on that page ("console/unit"), or on
-- the page it was last on.
function ns.OpenOptions(path)
    if not pages then return end
    Window()
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
    if path then Select(path) end
    window:Show()
    window:Raise()
end

function ns.CloseOptions()
    if window then window:Hide() end
end

-- The page shown, while the window is.
function ns.OptionsShown()
    return window and window:IsShown() and current or nil
end

-- The window's frames, made without showing it (the harness's way in).
function ns.BuildOptions()
    Window()
end

-- What a search finds, and choosing its nth line on the right (the
-- harness's way in).
function ns.SearchOptions(text, choose)
    Window()
    search:SetText(text or "")
    Search(text)
    local found = results
    local link = choose and finds.links[choose]
    if link and link:IsShown() then Choose(link.entry) end
    return found
end

ns.OnAnySetting(function() Refresh() end)

ns.On("PLAYER_LOGIN", function()
    pages = ns.OptionPages()
    categories = ns.OptionCategories()
    reloadAt = {}
    ReloadKeys(function(key) reloadAt[key] = ns.db[key] end)
end)
