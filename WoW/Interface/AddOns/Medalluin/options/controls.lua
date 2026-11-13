-- The settings window's controls, in the console's ink and gold: a
-- checkbox, a switch, a dropdown and the list it opens, a colour swatch, a
-- slider, a key box and a button. Each option control reads ns.db and
-- writes through ns.SetOption, so the modules hear about the change the
-- way they always have; Refresh(enabled) redraws one from ns.db.
--
-- In a row (row true: the window's sections) a control is one line, its
-- label at the left and its box at the right; a label too long for its
-- room wraps, and the row grows to hold it.
--
-- Nothing here is Blizzard's settings machinery or its dropdown menu: the
-- window's frames are Medalluin's own, so they can taint nothing the game's
-- secure code reads.
local _, ns = ...

local C = {
    gold = { 0.769, 0.647, 0.341 },
    goldDark = { 0.541, 0.439, 0.204 },
    goldBright = { 0.878, 0.722, 0.290 },
    ink = ns.colors.ink,
    panel = { 0.102, 0.094, 0.082 },
    well = { 0.047, 0.047, 0.047 },
    selected = { 0.204, 0.165, 0.086 },
    hover = { 0.271, 0.220, 0.114 },
    red = { 0.471, 0.094, 0.078 },
    redHover = { 0.580, 0.125, 0.098 },
    text = ns.colors.text,
    dim = ns.colors.dim,
}
local MEDIA = ns.media .. "options\\"

local UI = { colors = C }
ns.OptionsUI = UI

local function Fill(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(color[1], color[2], color[3], 1)
    return t
end
UI.Fill = Fill

-- A one-pixel line round a frame, inset.
local function Outline(parent, layer, color, inset, sub)
    local t = {}
    for i = 1, 4 do t[i] = Fill(parent, layer, color, sub) end
    t[1]:SetPoint("TOPLEFT", inset, -inset)
    t[1]:SetPoint("TOPRIGHT", -inset, -inset)
    t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT", inset, inset)
    t[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT", inset, -inset)
    t[3]:SetPoint("BOTTOMLEFT", inset, inset)
    t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT", -inset, -inset)
    t[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[4]:SetWidth(1)
    return t
end
UI.Outline = Outline

-- The suite's frame: a fill, a gold edge (two pixels, or one), a dark line
-- inside it.
function UI.Skin(frame, color, edge)
    edge = edge or 2
    local bg = Fill(frame, "BACKGROUND", color, 1)
    bg:SetAllPoints()
    for i = 0, edge - 1 do Outline(frame, "BORDER", C.gold, i, 1) end
    Outline(frame, "BORDER", C.goldDark, edge, 2)
    return bg
end

-- A heading's face (the console's serif) or the plain one, for reading.
function UI.Serif(parent, size, color)
    local fs = ns.Text(parent, size)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end
function UI.Plain(parent, size, color)
    local fs = ns.PlainText(parent, size)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- The game's tooltip: the title in gold, then the text, wrapped.
function UI.Tip(owner, title, text)
    if not GameTooltip then return end
    ns.Tip(owner, "ANCHOR_RIGHT", { title = title, color = C.goldBright, text and { "body", text } or false })
end
local function Untip() if GameTooltip then GameTooltip:Hide() end end

-- An option's value, and a change to it: ns.db and ns.SetOption, unless the
-- spec reads and writes its own (the unit-frame editor's, whose values sit
-- inside one option per frame: options/editor.lua).
local function Get(spec)
    if spec.get then return spec.get() end
    return ns.db[spec.key]
end
local function Set(spec, value)
    if spec.set then spec.set(value) else ns.SetOption(spec.key, value) end
end
UI.Get, UI.Set = Get, Set

local function Tipped(frame, title, text)
    frame:SetScript("OnEnter", function(self) UI.Tip(self, title, text) end)
    frame:SetScript("OnLeave", Untip)
end

-- a row's label: the room left of its box, wrapped; the row as tall as it
UI.ROW_H = 24
local function Fit(f, label, room)
    label:SetWidth(math.max(20, room))
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    f:SetHeight(math.max(UI.ROW_H, math.ceil(label:GetStringHeight() or 0) + 8))
end

-- ------------------------------------------------------------ button
-- A gold-edged button; red for the window's Close.
function UI.Button(parent, label, width, height, click, tip, red)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local bg = Fill(b, "BACKGROUND", red and C.red or C.selected, 1)
    bg:SetAllPoints()
    Outline(b, "BORDER", C.gold, 0)
    b.text = UI.Serif(b, 12, C.goldBright)
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label)
    local rest, lit = red and C.red or C.selected, red and C.redHover or C.hover
    b:SetScript("OnClick", function() click() end)
    b:SetScript("OnEnter", function(self)
        bg:SetColorTexture(lit[1], lit[2], lit[3], 1)
        if tip then UI.Tip(self, label, tip) end
    end)
    b:SetScript("OnLeave", function()
        bg:SetColorTexture(rest[1], rest[2], rest[3], 1)
        Untip()
    end)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        local c = enabled and C.goldBright or C.dim
        self.text:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.5)
    end
    b.spec = { kind = "button", label = label }
    return b
end

-- ------------------------------------------------------------ checkbox
local CHECK = 16
UI.CHECK_H = 22

function UI.Check(parent, spec, width, row)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, UI.CHECK_H)
    b.spec = spec
    local box = Fill(b, "BACKGROUND", C.goldDark, 1)
    box:SetSize(CHECK, CHECK)
    box:SetPoint(row and "RIGHT" or "LEFT", 0, 0)
    local well = Fill(b, "BACKGROUND", C.well, 2)
    well:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    b.tick = b:CreateTexture(nil, "ARTWORK")
    b.tick:SetTexture(MEDIA .. "check")
    b.tick:SetSize(CHECK + 4, CHECK + 4)
    b.tick:SetPoint("CENTER", box, "CENTER", 1, 1)
    b.label = UI.Plain(b, 12)
    if row then
        b.label:SetPoint("LEFT", 0, 0)
        b.label:SetText(spec.label)
        Fit(b, b.label, width - CHECK - 12)
    else
        b.label:SetPoint("LEFT", box, "RIGHT", 7, 0)
        b.label:SetPoint("RIGHT", 0, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetText(spec.label)
    end
    b:SetScript("OnClick", function() Set(spec, not Get(spec)) end)
    Tipped(b, spec.label, spec.tip)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        self.tick:SetShown(Get(spec) and true or false)
        local c = enabled and C.text or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return b
end

-- ------------------------------------------------------------ switch
-- An on/off pill (a page's master, a module's card): a track gold-edged,
-- filled while on, its knob at the right while on and at the left while
-- off; label (optional) left of it. Its tick is the fill, as a checkbox's.
UI.SWITCH_W, UI.SWITCH_H = 36, 18

function UI.Switch(parent, spec, label)
    local b = CreateFrame("Button", nil, parent)
    b.spec = spec
    local track = CreateFrame("Frame", nil, b)
    track:SetSize(UI.SWITCH_W, UI.SWITCH_H)
    track:SetPoint("RIGHT", 0, 0)
    local well = Fill(track, "BACKGROUND", C.well, 1)
    well:SetAllPoints()
    b.edge = Outline(track, "BORDER", C.goldDark, 0)
    b.tick = Fill(track, "ARTWORK", C.goldDark, 1)
    b.tick:SetPoint("TOPLEFT", 1, -1)
    b.tick:SetPoint("BOTTOMRIGHT", -1, 1)
    b.knob = track:CreateTexture(nil, "OVERLAY")
    b.knob:SetTexture(ns.media .. "strips\\round")
    b.knob:SetSize(UI.SWITCH_H - 6, UI.SWITCH_H - 6)
    b.track = track
    local w = UI.SWITCH_W
    if label then
        b.label = UI.Serif(b, 12, C.gold)
        b.label:SetPoint("RIGHT", track, "LEFT", -8, 0)
        b.label:SetText(label)
        w = w + 8 + math.ceil(b.label:GetStringWidth())
    end
    b:SetSize(w, UI.SWITCH_H + 4)
    b:SetScript("OnClick", function() Set(spec, not Get(spec)) end)
    Tipped(b, spec.label, spec.tip)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        local on = Get(spec) and true or false
        self.tick:SetShown(on)
        self.knob:ClearAllPoints()
        self.knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
        local k = on and C.goldBright or C.dim
        self.knob:SetVertexColor(k[1], k[2], k[3], 1)
        local e = on and C.gold or C.goldDark
        for _, t in ipairs(self.edge) do t:SetColorTexture(e[1], e[2], e[3], 1) end
        self:SetAlpha(enabled and 1 or 0.45)
    end
    return b
end

-- ------------------------------------------------------------ key
-- A key binding: the label, and a box with the key bound to the command.
-- Click the box, then press a key (with any modifiers) to bind it; Esc
-- while it listens leaves the key as it was; a right-click unbinds.
-- Bindings only change out of combat. spec.command is the binding's name
-- (Bindings.xml); keybind.lua does the binding.
function UI.Key(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.CHECK_H)
    f.spec = spec
    f.label = UI.Plain(f, 12)
    f.label:SetPoint("LEFT", 0, 0)
    f.label:SetText(spec.label)
    local box = CreateFrame("Button", nil, f)
    box:SetSize(math.min(140, math.floor(width / 2)), UI.CHECK_H)
    box:SetPoint("RIGHT", 0, 0)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = Fill(box, "BACKGROUND", C.well, 1)
    bg:SetAllPoints()
    Outline(box, "BORDER", C.goldDark, 0)
    box.text = UI.Plain(box, 12)
    box.text:SetPoint("CENTER", 0, 0)
    f.box = box

    local function Shown()
        if box.listening then return "Press a key" end
        local keys = ns.BindingKeys and ns.BindingKeys(spec.command) or {}
        if #keys == 0 then return "Not bound" end
        return ns.KeyText and ns.KeyText(keys[1]) or keys[1]
    end
    local function Listen(on)
        box.listening = on or nil
        box:EnableKeyboard(on and true or false)
        f:Refresh(true)
    end
    box:SetScript("OnClick", function(_, button)
        if InCombatLockdown() then return end
        if button == "RightButton" then
            Listen(false)
            if ns.Rebind then ns.Rebind(spec.command) end
            f:Refresh(true)
            return
        end
        Listen(not box.listening)
    end)
    box:SetScript("OnKeyDown", function(self, key)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        if key == "ESCAPE" then Listen(false) return end
        local chord = ns.KeyChord and ns.KeyChord(key)
        if not chord then return end        -- a modifier alone: keep listening
        if ns.Rebind and not InCombatLockdown() then ns.Rebind(spec.command, chord) end
        Listen(false)
    end)
    box:SetScript("OnHide", function() if box.listening then Listen(false) end end)
    box:SetScript("OnEnter", function(self)
        UI.Tip(self, spec.label, (spec.tip and spec.tip .. "\n\n" or "")
            .. "Click, then press a key. Right-click unbinds it.")
    end)
    box:SetScript("OnLeave", Untip)
    function f:Refresh(enabled)
        box:SetEnabled(enabled)
        box.text:SetText(Shown())
        local c = box.listening and C.goldBright or enabled and C.text or C.dim
        box.text:SetTextColor(c[1], c[2], c[3])
        local l = enabled and C.text or C.dim
        self.label:SetTextColor(l[1], l[2], l[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end

-- ------------------------------------------------------------ the list
-- One list for every dropdown, over everything; a click anywhere off it
-- closes it.
local menu, catcher
local ROW_H = 20
local MENU_ROWS = 16                    -- a list's rows before it flows into another column

local function Menu()
    if menu then return menu end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetAllPoints(UIParent)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() UI.CloseMenu() end)
    catcher:Hide()
    menu = CreateFrame("Frame", "MedalluinOptionsMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    UI.Skin(menu, C.well, 1)
    menu.rows = {}
    menu:Hide()
    return menu
end

local function Row(i)
    local row = menu.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, menu)
    row:SetHeight(ROW_H)
    row.lit = Fill(row, "BACKGROUND", C.hover, 1)
    row.lit:SetAllPoints()
    row.lit:Hide()
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(MEDIA .. "check")
    row.mark:SetSize(14, 14)
    row.mark:SetPoint("LEFT", 4, 0)
    row.text = UI.Plain(row, 12)
    menu.font = menu.font or { row.text:GetFont() }
    row.text:SetPoint("LEFT", 22, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(self)
        self.lit:Show()
        if self.tip then UI.Tip(self, self.label, self.tip) end
    end)
    row:SetScript("OnLeave", function(self)
        self.lit:Hide()
        Untip()
    end)
    row:SetScript("OnClick", function(self)
        local spec, value = menu.spec, self.value
        -- a list of several picks stays open, each click toggling one
        if spec.multi then
            Set(spec, value)
            UI.MarkMenu()
            return
        end
        UI.CloseMenu()
        Set(spec, value)
    end)
    menu.rows[i] = row
    return row
end

function UI.CloseMenu()
    if menu then
        menu:Hide()
        menu.owner = nil
        catcher:Hide()
    end
end

-- a choice's mark: the value chosen, or each of a multi list's (spec.on)
local function Chosen(spec, value)
    if spec.multi then return spec.on(value) and true or false end
    return Get(spec) == value
end

function UI.MarkMenu()
    if not (menu and menu:IsShown()) then return end
    for _, row in ipairs(menu.rows) do
        if row:IsShown() then
            local on = Chosen(menu.spec, row.value)
            row.mark:SetShown(on)
            local c = on and C.goldBright or C.text
            row.text:SetTextColor(c[1], c[2], c[3])
        end
    end
end

-- The list of a dropdown's choices under it; again on the same dropdown
-- closes it. spec: { choices = { { value, label, tip, font } }, key or
-- get/set; multi (several picks: on(value) says which, set(value) toggles
-- one, and the list stays open) }.
function UI.OpenMenu(owner, spec)
    Menu()
    if menu.owner == owner and menu:IsShown() then
        UI.CloseMenu()
        return
    end
    menu.owner, menu.spec = owner, spec
    -- choices that change while the game runs (fonts other addons share)
    if spec.list then spec.choices = spec.list() end
    local width = owner:GetWidth()
    for i, choice in ipairs(spec.choices) do
        local row = Row(i)
        -- a tip may be a function: what the choice does can depend on the profile
        local tip = choice[3]
        if type(tip) == "function" then tip = tip() end
        row.value, row.label, row.tip = choice[1], choice[2], tip
        -- a font's choice drawn in that font
        row.text:SetFont(choice[4] or menu.font[1], menu.font[2], menu.font[3])
        row.text:SetText(choice[2])
        local on = Chosen(spec, choice[1])
        row.mark:SetShown(on)
        local c = on and C.goldBright or C.text
        row.text:SetTextColor(c[1], c[2], c[3])
        width = math.max(width, math.ceil(row.text:GetStringWidth()) + 40)
        row:Show()
    end
    for i = #spec.choices + 1, #menu.rows do menu.rows[i]:Hide() end
    -- a long list flows into columns, each MENU_ROWS deep
    local n = #spec.choices
    local columns = math.max(1, math.ceil(n / MENU_ROWS))
    local deep = math.min(n, MENU_ROWS)
    for i = 1, n do
        local row, col, at = menu.rows[i], math.floor((i - 1) / MENU_ROWS), (i - 1) % MENU_ROWS
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 3 + col * width, -3 - at * ROW_H)
        row:SetWidth(width - 6)
    end
    menu:SetSize(columns * width, deep * ROW_H + 6)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    menu:Show()
end

-- ------------------------------------------------------------ dropdown
UI.CHOICE_H = 40

local function ChoiceLabel(spec)
    local value = Get(spec)
    if spec.list then spec.choices = spec.list() end
    for _, choice in ipairs(spec.choices) do
        if choice[1] == value then return choice[2] end
    end
    return tostring(value)
end

UI.CHOICE_W = 150                       -- a row's dropdown

function UI.Choice(parent, spec, width, row)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.CHOICE_H)
    f.spec = spec
    local b = CreateFrame("Button", nil, f)
    if row then
        local box = math.min(UI.CHOICE_W, math.floor(width * 0.55))
        f.label = UI.Plain(f, 12)
        f.label:SetPoint("LEFT", 0, 0)
        f.label:SetText(spec.label)
        Fit(f, f.label, width - box - 10)
        b:SetPoint("RIGHT", 0, 0)
        b:SetWidth(box)
    else
        f.label = UI.Serif(f, 11, C.goldBright)
        f.label:SetPoint("TOPLEFT", 0, 0)
        f.label:SetText(spec.label)
        b:SetPoint("BOTTOMLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    f.row = row
    b:SetHeight(22)
    local bg = Fill(b, "BACKGROUND", C.well, 1)
    bg:SetAllPoints()
    Outline(b, "BORDER", C.goldDark, 0)
    b.value = UI.Plain(b, 12)
    b.value:SetPoint("LEFT", 8, 0)
    b.value:SetPoint("RIGHT", -24, 0)
    b.value:SetJustifyH("LEFT")
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture(MEDIA .. "arrow")
    b.arrow:SetSize(16, 16)
    b.arrow:SetPoint("RIGHT", -5, 0)
    b:SetScript("OnClick", function(self) UI.OpenMenu(self, spec) end)
    Tipped(b, spec.label, spec.tip)
    f.button = b
    function f:Refresh(enabled)
        b:SetEnabled(enabled)
        b.value:SetText(ChoiceLabel(spec))
        local c = enabled and C.text or C.dim
        b.value:SetTextColor(c[1], c[2], c[3])
        if self.row then self.label:SetTextColor(c[1], c[2], c[3]) end
        self:SetAlpha(enabled and 1 or 0.55)
        if not enabled and menu and menu.owner == b then UI.CloseMenu() end
    end
    return f
end

-- ------------------------------------------------------------ grid
-- One option for many frames, a box each: a column per frame (cols, each
-- { label }), a row per option (rows, each { label, keys, tip }, keys one
-- per column, false where that frame has no such option: a dash). A box
-- whose frame chose its own over the shared one (the row's key in the
-- first column) wears a gold corner.
UI.GRID_COL = 58
function UI.Grid(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f.spec = spec
    local n = #spec.cols
    local left = width - n * UI.GRID_COL
    f.heads, f.cells, f.labels, f.dashes = {}, {}, {}, {}
    for i, col in ipairs(spec.cols) do
        local h = UI.Plain(f, 10, C.goldDark)
        h:SetPoint("TOP", f, "TOPLEFT", left + (i - 0.5) * UI.GRID_COL, -2)
        h:SetWidth(UI.GRID_COL - 2)
        h:SetText(col.label)
        f.heads[i] = h
    end
    local y = -18
    for r, row in ipairs(spec.rows) do
        local label = UI.Plain(f, 12, C.text)
        label:SetPoint("LEFT", f, "TOPLEFT", 0, y - UI.CHECK_H / 2)
        label:SetWidth(left - 8)
        label:SetJustifyH("LEFT")
        label:SetText(row.label)
        f.labels[r] = label
        f.cells[r] = {}
        for i, key in ipairs(row.keys) do
            local x = left + (i - 0.5) * UI.GRID_COL
            if key then
                local cell = UI.Check(f, { kind = "check", key = key,
                    label = row.label .. ": " .. spec.cols[i].label, tip = row.tip }, CHECK, false)
                cell.label:SetText("")
                cell:SetPoint("CENTER", f, "TOPLEFT", x, y - UI.CHECK_H / 2)
                cell.corner = Fill(cell, "OVERLAY", C.gold)
                cell.corner:SetSize(5, 5)
                cell.corner:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 1, 1)
                cell.corner:Hide()
                f.cells[r][i] = cell
            else
                local dash = UI.Plain(f, 12, C.dim)
                dash:SetPoint("CENTER", f, "TOPLEFT", x, y - UI.CHECK_H / 2)
                dash:SetText("-")
                f.dashes[#f.dashes + 1] = dash
            end
        end
        y = y - UI.CHECK_H - 4
    end
    f:SetSize(width, -y)
    function f:Refresh(enabled)
        for _, cells in pairs(self.cells) do
            for _, cell in pairs(cells) do
                cell:Refresh(enabled)
                cell.corner:SetShown(ns.SharedOf(cell.spec.key) ~= nil and ns.OptionOwn(cell.spec.key))
            end
        end
        local c = enabled and C.text or C.dim
        for _, l in ipairs(self.labels) do l:SetTextColor(c[1], c[2], c[3]) end
    end
    return f
end

-- ------------------------------------------------------------ note
-- Words the page reads as it draws (spec.text(), two lines at most): what
-- the game says of the player, such as the dispels they know.
function UI.Note(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 32)
    f.spec = spec
    f.text = UI.Plain(f, 12, C.text)
    f.text:SetPoint("TOPLEFT", 0, -2)
    f.text:SetWidth(width)
    f.text:SetJustifyH("LEFT")
    function f:Refresh()
        self.text:SetText(spec.text())
    end
    return f
end

-- ------------------------------------------------------------ colour
-- A swatch opening the game's colour picker; the option is "ffRRGGBB".
local function Hex(r, g, b)
    return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end
UI.Hex = Hex

-- The picker's own setup call (10.2.5 and Forever's client); writing its
-- fields, the older way, would leave them Medalluin's.
local function Pick(key)
    local picker = ColorPickerFrame
    if not (picker and picker.SetupColorPickerAndShow) then return end
    local before = ns.db[key]
    local r, g, b = ns.HexColor(before)
    local function Changed()
        local nr, ng, nb = picker:GetColorRGB()
        ns.SetOption(key, Hex(nr, ng, nb))
    end
    local function Cancel() ns.SetOption(key, before) end
    picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = Changed, cancelFunc = Cancel })
end

function UI.Color(parent, spec, width, row)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, UI.CHECK_H)
    b.spec = spec
    local edge = Fill(b, "BACKGROUND", C.gold, 1)
    edge:SetSize(CHECK, CHECK)
    edge:SetPoint(row and "RIGHT" or "LEFT", 0, 0)
    b.swatch = Fill(b, "ARTWORK", { 1, 1, 1 })
    b.swatch:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    b.swatch:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    b.label = UI.Plain(b, 12)
    if row then
        b.label:SetPoint("LEFT", 0, 0)
        b.label:SetText(spec.label)
        Fit(b, b.label, width - CHECK - 12)
    else
        b.label:SetPoint("LEFT", edge, "RIGHT", 7, 0)
        b.label:SetText(spec.label)
    end
    b:SetScript("OnClick", function() Pick(spec.key) end)
    Tipped(b, spec.label, spec.tip)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        local r, g, bl = ns.HexColor(ns.db[spec.key])
        self.swatch:SetColorTexture(r, g, bl, 1)
        local c = enabled and C.text or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return b
end

-- ------------------------------------------------------------ slider
-- A number between spec.min and spec.max, by spec.step: the label and the
-- value over a track, a thumb to drag along it, and a step either way at
-- its ends. spec.text, when there is one, says the value ("No limit").
UI.SLIDER_H = 40

UI.SLIDER_W, UI.VALUE_W = 140, 44      -- a row's slider (its buttons and track), and its value

function UI.Slider(parent, spec, width, row)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.SLIDER_H)
    f.spec = spec
    f.row = row
    local room = row and math.min(UI.SLIDER_W, math.floor(width * 0.45)) or width
    if row then
        f.label = UI.Plain(f, 12)
        f.label:SetPoint("LEFT", 0, 0)
        f.label:SetText(spec.label)
        Fit(f, f.label, width - room - UI.VALUE_W - 12)
        f.value = UI.Plain(f, 11)
        f.value:SetPoint("RIGHT", f, "RIGHT", -(room + 6), 0)
        f.value:SetWidth(UI.VALUE_W)
        f.value:SetJustifyH("RIGHT")
    else
        f.label = UI.Serif(f, 11, C.goldBright)
        f.label:SetPoint("TOPLEFT", 0, 0)
        f.label:SetText(spec.label)
        f.value = UI.Plain(f, 11)
        f.value:SetPoint("TOPRIGHT", 0, 0)
    end
    local step = spec.step or 1
    local function Clamp(v)
        v = math.floor(v / step + 0.5) * step
        return math.max(spec.min, math.min(spec.max, v))
    end
    local function Nudge(by)
        Set(spec, Clamp((Get(spec) or spec.min) + by))
    end
    f.less = UI.Button(f, "-", 18, 18, function() Nudge(-step) end)
    f.more = UI.Button(f, "+", 18, 18, function() Nudge(step) end)
    if row then
        f.less:SetPoint("RIGHT", f, "RIGHT", -(room - 18), 0)
        f.more:SetPoint("RIGHT", 0, 0)
    else
        f.less:SetPoint("BOTTOMLEFT", 0, 0)
        f.more:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    local track = CreateFrame("Button", nil, f)
    track:SetPoint("BOTTOMLEFT", f.less, "BOTTOMRIGHT", 6, 0)
    track:SetPoint("BOTTOMRIGHT", f.more, "BOTTOMLEFT", -6, 0)
    track:SetHeight(18)
    local rail = Fill(track, "BACKGROUND", C.well, 1)
    rail:SetPoint("LEFT", 0, 0)
    rail:SetPoint("RIGHT", 0, 0)
    rail:SetHeight(5)
    Outline(track, "BORDER", C.goldDark, 0)
    f.thumb = Fill(track, "ARTWORK", C.gold)
    f.thumb:SetSize(8, 14)
    f.track = track
    -- where the pointer is on the track, as a value
    local function AtCursor()
        local x = GetCursorPosition() / track:GetEffectiveScale()
        local left, w = track:GetLeft() or 0, track:GetWidth()
        if w <= 0 then return Get(spec) end
        return Clamp(spec.min + (x - left) / w * (spec.max - spec.min))
    end
    track:SetScript("OnMouseDown", function(self)
        self.dragging = true
        Set(spec, AtCursor())
    end)
    track:SetScript("OnMouseUp", function(self) self.dragging = nil end)
    track:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local v = AtCursor()
        if v ~= Get(spec) then Set(spec, v) end
    end)
    Tipped(track, spec.label, spec.tip)
    function f:Refresh(enabled)
        local v = Get(spec) or spec.min
        self.value:SetText(spec.text and spec.text(v) or tostring(v))
        local at = (v - spec.min) / (spec.max - spec.min)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("CENTER", track, "LEFT", math.max(0, math.min(1, at)) * track:GetWidth(), 0)
        track:EnableMouse(enabled)
        self.less:Refresh(enabled)
        self.more:Refresh(enabled)
        local c = enabled and C.text or C.dim
        self.value:SetTextColor(c[1], c[2], c[3])
        if self.row then self.label:SetTextColor(c[1], c[2], c[3]) end
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end
