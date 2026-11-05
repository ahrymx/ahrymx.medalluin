-- Medalluin's settings window (art/settings/gen_settings.py, draft B): the
-- tree down the left holds the top pages, Console's pages are tabs over the
-- body, and a page's options sit in framed groups, two to a row. The title
-- on the top edge, or the window itself, drags it; where it is left is
-- kept. The footer names the profile being edited and, once an option that
-- waits for one has changed, asks for a reload.
--
-- Built the first time it opens (/mdlui, the minimap button, the button on
-- Options > AddOns > Medalluin); pages.lua says what is on it.
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors

local W, H = 820, 560
local PAD, TREE_W, TITLE_ROOM, FOOT = 14, 170, 22, 46
local TAB_H, ROW_GAP, COL_GAP, INSET = 24, 8, 18, 14

local pages        -- pages.lua's, built at login
local window, tree, tabStrip, body, scroll, thumb
local footProfile, footReload
local built = {}   -- page frames by path ("general", "console/unit")
ns.optionPages = built
local current      -- the path shown
local lastTab = {} -- each tabbed page's tab, by page id
local reloadAt     -- what the reload options were at login
local controls = {}
ns.optionControls = controls

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
            for _, tab in ipairs(page.tabs) do fn(tab, page.id .. "/" .. tab.id) end
        else
            fn(page, page.id)
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
local function Control(parent, spec, width)
    local c
    if spec.kind == "check" then
        c = UI.Check(parent, spec, width)
    elseif spec.kind == "choice" then
        c = UI.Choice(parent, spec, width)
    elseif spec.kind == "color" then
        c = UI.Color(parent, spec, width)
    elseif spec.kind == "slider" then
        c = UI.Slider(parent, spec, width)
    elseif spec.kind == "key" then
        c = UI.Key(parent, spec, width)
    else
        c = UI.Button(parent, spec.label, math.min(width, 160), 24, spec.click, spec.tip)
    end
    -- a control drawn greyed while another option is off, or while its
    -- page's own test says no (spec.needs; content.enabled) unless it is
    -- for every profile there (spec.always)
    c.needs, c.always = spec.needs, spec.always
    -- a key control is found by its binding's name
    if spec.key or spec.command then controls[spec.key or spec.command] = c end
    return c
end

-- Lay a page's content out top down: its line of intro, its master, then
-- each group, two controls a row, a row as tall as its tallest and every
-- control on the row's bottom (so a checkbox sits level with a dropdown's
-- box).
local function Build(content, width)
    local f = CreateFrame("Frame", nil, scroll)
    f:SetWidth(width)
    f.controls = {}
    f.enabled = content.enabled
    local y = -INSET
    if content.intro then
        local intro = UI.Plain(f, 11, C.dim)
        intro:SetPoint("TOPLEFT", INSET, y)
        intro:SetWidth(width - 2 * INSET)
        intro:SetJustifyH("LEFT")
        intro:SetText(content.intro)
        y = y - math.ceil(intro:GetStringHeight()) - 10
    end
    if content.master then
        local m = Control(f, content.master, width - 2 * INSET)
        m:SetPoint("TOPLEFT", INSET, y)
        f.master = m
        table.insert(f.controls, m)
        y = y - m:GetHeight() - 12
    end
    local inner = width - 2 * INSET
    local colW = math.floor((inner - 2 * INSET - COL_GAP) / 2)
    for _, group in ipairs(content.groups) do
        local top = y
        y = top - 26
        if group.tip then
            local tip = UI.Plain(f, 11, C.dim)
            tip:SetPoint("TOPLEFT", 2 * INSET, y)
            tip:SetWidth(inner - 2 * INSET)
            tip:SetJustifyH("LEFT")
            tip:SetText(group.tip)
            y = y - math.ceil(tip:GetStringHeight()) - 8
        end
        local items = group.items
        for i = 1, #items, 2 do
            local row = {}
            local rowH = 0
            for col = 0, 1 do
                local spec = items[i + col]
                if spec then
                    local c = Control(f, spec, colW)
                    row[col + 1] = c
                    rowH = math.max(rowH, c:GetHeight())
                    table.insert(f.controls, c)
                end
            end
            for col, c in pairs(row) do
                c:SetPoint("TOPLEFT", 2 * INSET + (col - 1) * (colW + COL_GAP), y - (rowH - c:GetHeight()))
            end
            y = y - rowH - ROW_GAP
        end
        y = y - 4
        -- the group's frame, its heading set into the top edge: the heading
        -- and the panel-coloured gap behind it on the frame's own frame, as
        -- a child frame draws over its parent's text
        local edge = CreateFrame("Frame", nil, f)
        edge:SetPoint("TOPLEFT", INSET, top - 8)
        edge:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", INSET + inner, y)
        UI.Outline(edge, "BACKGROUND", C.goldDark, 0)
        local title = UI.Serif(edge, 13, C.goldBright)
        title:SetPoint("LEFT", edge, "TOPLEFT", 12, 0)
        title:SetText(group.title)
        local backing = UI.Fill(edge, "BORDER", C.panel)
        backing:SetPoint("TOPLEFT", title, "TOPLEFT", -5, 2)
        backing:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 5, -2)
        edge.title = title
        y = y - 14
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
    thumb:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -4 - (view - size) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function Scroll(delta)
    local range = scroll:GetVerticalScrollRange() or 0
    local to = math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * 40))
    scroll:SetVerticalScroll(to)
    Thumb()
end

-- ------------------------------------------------------------ redraw
local function Refresh()
    if not window then return end
    for _, f in pairs(built) do
        -- a master greys only with what it needs; all else with it too
        local function Has(c) return not c.needs or ns.db[c.needs] and true or false end
        local on = (not f.master or ns.db[f.master.spec.key] and Has(f.master))
            and (not f.enabled or f.enabled()) and true or false
        for _, c in ipairs(f.controls) do
            c:Refresh((c == f.master or c.always or on) and Has(c))
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

local function Select(path)
    local page, tab = Find(path)
    if not page then return end
    if tab then lastTab[page.id] = tab.id end
    current = tab and (page.id .. "/" .. tab.id) or page.id
    for _, row in ipairs(tree.rows) do
        row.lit:SetShown(row.page == page)
        local c = row.page == page and C.goldBright or C.gold
        row.text:SetTextColor(c[1], c[2], c[3])
    end
    -- the tabs, for a page that has them; the body under them
    for _, t in ipairs(tabStrip.tabs) do t:Hide() end
    body:ClearAllPoints()
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, FOOT)
    if tab then
        local x = 8
        for i, t in ipairs(page.tabs) do
            local b = tabStrip.tabs[i]
            b.page, b.tab = page, t
            b.text:SetText(t.name)
            b:SetWidth(math.ceil(b.text:GetStringWidth()) + 24)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", tabStrip, "BOTTOMLEFT", x, 0)
            local on = t == tab
            b.bg:SetColorTexture(unpack(on and { C.panel[1], C.panel[2], C.panel[3], 1 }
                or { C.ink[1], C.ink[2], C.ink[3], 1 }))
            for _, line in ipairs(b.edge) do
                local c = on and C.gold or C.goldDark
                line:SetColorTexture(c[1], c[2], c[3], 1)
            end
            b.edge[2]:SetShown(not on)   -- the open tab runs into the body
            local c = on and C.goldBright or C.dim
            b.text:SetTextColor(c[1], c[2], c[3])
            b:SetFrameLevel(body:GetFrameLevel() + (on and 3 or 1))
            b:Show()
            x = x + b:GetWidth() + 4
        end
        body:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + TREE_W + 12, -(PAD + TITLE_ROOM + TAB_H - 2))
    else
        body:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + TREE_W + 12, -(PAD + TITLE_ROOM))
    end
    for p, f in pairs(built) do f:SetShown(p == current) end
    scroll:SetScrollChild(built[current])
    scroll:SetVerticalScroll(0)
    UI.CloseMenu()
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

local function TreeRows()
    tree.rows = {}
    for i, page in ipairs(pages) do
        local row = CreateFrame("Button", nil, tree)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 4, -6 - (i - 1) * 26)
        row:SetPoint("TOPRIGHT", -4, -6 - (i - 1) * 26)
        row.page = page
        row.lit = UI.Fill(row, "BACKGROUND", C.selected, 1)
        row.lit:SetAllPoints()
        row.lit:Hide()
        row.text = UI.Serif(row, 14, C.gold)
        row.text:SetPoint("LEFT", 10, 0)
        row.text:SetText(page.name)
        row:SetScript("OnClick", function() Select(page.id) end)
        tree.rows[i] = row
    end
end

local function TabStrip()
    tabStrip = CreateFrame("Frame", nil, window)
    tabStrip:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + TREE_W + 12, -(PAD + TITLE_ROOM))
    tabStrip:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -(PAD + TITLE_ROOM))
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

    tree = CreateFrame("Frame", nil, window)
    tree:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_ROOM))
    tree:SetPoint("BOTTOMLEFT", PAD, FOOT)
    tree:SetWidth(TREE_W)
    UI.Skin(tree, C.ink)
    TreeRows()
    TabStrip()

    body = CreateFrame("Frame", nil, window)
    UI.Skin(body, C.panel)
    scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", 3, -3)
    scroll:SetPoint("BOTTOMRIGHT", -12, 3)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    thumb = UI.Fill(body, "ARTWORK", C.goldDark)
    thumb:SetWidth(4)
    thumb:Hide()
    Footer()
    -- its parts, by name (the harness reads them)
    window.tree, window.tabs, window.scroll, window.thumb = tree, tabStrip.tabs, scroll, thumb
    window.footProfile, window.footReload = footProfile, footReload

    local width = W - 2 * PAD - TREE_W - 12 - 15
    Each(function(content, path) built[path] = Build(content, width) end)
    Select(current or "general")
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

ns.OnAnySetting(function() Refresh() end)

ns.On("PLAYER_LOGIN", function()
    pages = ns.OptionPages()
    reloadAt = {}
    ReloadKeys(function(key) reloadAt[key] = ns.db[key] end)
end)
