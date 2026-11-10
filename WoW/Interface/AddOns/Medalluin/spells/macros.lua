-- The spellbook's Macros page (spells/spellbook.lua): the game's own macro
-- window (MacroFrame, Blizzard_MacroUI, loaded as the page first shows)
-- inside the page, dressed as Click Casting is (spells/clickcast.lua).
--
--   [ General  4 / 120 ][ Ahrymx  2 / 18 ]
--   +-----------------------------------------------------------+
--   | [ic] Heal                                               + |
--   |      /cast [@mouseover,help] Flash Heal                   |
--   +-----------------------------------------------------------+
--   | [ic] Focus                                              - |   opened
--   |-----------------------------------------------------------|
--   |   /focus                                                  |
--   |   /cast [@focus] Polymorph                       [Delete] |
--   +-----------------------------------------------------------+
--   ...
--   [ic] Focus (pencil)                    [+ New][Save][Cancel]
--   +-----------------------------------------------------------+
--   | /focus                                                    |
--   | /cast [@focus] Polymorph                                  |
--   +-----------------------------------------------------------+
--   Casts Polymorph                                    32 / 255
--
-- A switch between the account's macros and the character's, a card for
-- each macro of the set (folded, its name and first line; opened, the
-- whole text, MedalluinCharDB.macroOpen by name), and the editor under
-- them. A left click on a card opens or closes it and puts it in the
-- editor; the right runs it (a secure button over its head, as the book's
-- rows cast); the left dragged puts it on a bar. Click Casting open,
-- either button binds it. New and the pencil show the game's name and
-- icon picker (MacroPopupFrame) floating left of the book, over it if
-- dragged there.
--
-- Every save, delete, new and icon pick is the game's own code: ours calls
-- the game's buttons, which stay, hidden. Its art is put away, ours drawn
-- beside it (window/reskin.lua), nothing written on the game's frames.
-- The game's ways in (/macro, the game menu) open the book on this page.
local _, ns = ...

local R = ns.reskin
local GOLD, GOLD_D = R.GOLD, R.GOLD_D
local PLAIN = "Fonts\\ARIALN.TTF"       -- the macros' own words
local SWITCH = 26                       -- the switch's height
local HEAD, LINE = 40, 13               -- a card folded; a line of its text
local SPACE = 6                         -- between the cards
local ICON = 30
local EDITOR = 232                      -- the editor, under the list
local BAR = 34                          -- the editor's header
local GUTTER = 10                       -- the scroll bar, left of the list
local STEP = HEAD * 1.5                 -- a turn of the wheel
local LETTERS = 255
local TYPE = Enum and Enum.ClickBindingType or { Macro = 2 }

local M = {}
ns.macros = M

local W = ns.spellbook
local page, body, switch, list, scroller, editor, layer
local cards = {}
M.cards = cards
local adopted, placing, shown = false, false, false
local edited = false                    -- the editor's text typed into since it was loaded

local function Binding()
    return ns.db.spellbookClickCast and ns.clickcast ~= nil and ns.clickcast.Binding()
end

local function Plain(fs, size, color)
    fs:SetFont(PLAIN, size, "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- the opened cards, by their macros' names
local function Opened(name)
    local t = MedalluinCharDB and MedalluinCharDB.macroOpen
    return type(t) == "table" and t[name] == true
end

local function Toggle(name)
    if not name then return end
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.macroOpen = type(MedalluinCharDB.macroOpen) == "table" and MedalluinCharDB.macroOpen or {}
    MedalluinCharDB.macroOpen[name] = not Opened(name) or nil
end

-- The set shown: its tab (1 the account's, 2 the character's), how many
-- macros it holds, and the index before its first
local function Set()
    local f = MacroFrame
    local tab = PanelTemplates_GetSelectedTab(f) or 1
    local account, character = GetNumMacros()
    return tab, (tab == 1 and account or character) or 0, f.macroBase or 0
end

-- one of the game's buttons pressed, as its click would (while enabled)
local function Press(b)
    if not (b and b:IsEnabled()) then return end
    local click = b:GetScript("OnClick")
    if click then click(b, "LeftButton") end
end

-- a macro into the editor, as the game's own grid selects one
local function Select(i)
    local f = MacroFrame
    if not i or f:GetSelectedIndex() == i then return end
    f:SaveMacro()
    f:SelectMacro(i, true)
    if MacroPopupFrame then MacroPopupFrame:Hide() end
    MacroFrameText:ClearFocus()
end

-- Click Casting open: the macro into its waiting slot (a slot made first)
local function Bind(index)
    local f = _G.ClickBindingFrame
    if not (f and f.AddNewAction and index) then return end
    if f.HasNewSlot and not f:HasNewSlot() then
        local add = f.AddBindingButton
        local click = type(add) == "table" and add.GetScript and add:GetScript("OnClick")
        if click then click(add, "LeftButton") end
        if not f:HasNewSlot() then return end
    end
    f:AddNewAction(TYPE.Macro, index)
end

-- the first line that is not a #show
local function First(text)
    for line in (text or ""):gmatch("[^\n]+") do
        if not line:match("^%s*#") then return line end
    end
    return ""
end

local function Spell(index)
    local id = GetMacroSpell and GetMacroSpell(index)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local Refresh                           -- below: the page drawn again

-- A card's click: Click Casting open, either button binds it; else the
-- left opens or closes it and puts it in the editor. The right runs it:
-- the secure button's, the client's.
local function Click(c, button)
    if not c.i then return end
    if Binding() then
        Bind(c.index)
    elseif button == "LeftButton" then
        Toggle(c.name)
        Select(c.i)
        Refresh()
    end
end

local function Tooltip(owner, c)
    if not c.name then return end
    local spell = Spell(c.index)
    ns.Tip(owner, ns.window.Outside, { title = c.name, color = GOLD,
        spell and { "body", "Casts " .. spell, ns.colors.dim } or false,
        Binding() and { "body", "Click to bind it.", GOLD } or false,
        not Binding() and { "body", Opened(c.name) and "Left-click to fold it." or "Left-click to show and edit it." }
            or false,
        not Binding() and { "body", "Right-click to run it." } or false,
        { "hint", "Drag it to an action bar." } })
end

-- ------------------------------------------------------------------ cards
-- A macro's card, pooled: a dark box with a brown edge (gold while it is
-- in the editor, a gold bar at its left), its head a strip fading right.
local function Card(n)
    local c = CreateFrame("Button", nil, scroller.child)
    c:SetFrameLevel(scroller.child:GetFrameLevel() + 1)
    local ink = ns.colors.ink
    c.fill = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.fill:SetAllPoints()
    c.fill:SetColorTexture(ink[1], ink[2], ink[3], 0.9)
    c.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = c:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        c.edges[i] = t
    end
    c.band = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.band:SetPoint("TOPLEFT", 1, -1)
    c.band:SetPoint("TOPRIGHT", -1, -1)
    c.band:SetHeight(HEAD - 1)
    R.Fade(c.band, GOLD_D, 0.45)
    c.bar = c:CreateTexture(nil, "ARTWORK")
    c.bar:SetPoint("TOPLEFT", 1, -1)
    c.bar:SetPoint("BOTTOMLEFT", 1, 1)
    c.bar:SetWidth(3)
    c.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("TOPLEFT", 10, -5)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.ring = c:CreateTexture(nil, "BACKGROUND", nil, 5)
    c.ring:SetPoint("TOPLEFT", c.icon, -1, 1)
    c.ring:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    c.ring:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.label = ns.Text(c, 12)
    c.label:SetPoint("TOPLEFT", ICON + 18, -6)
    c.label:SetPoint("RIGHT", -30, 0)
    c.label:SetJustifyH("LEFT")
    c.label:SetWordWrap(false)
    c.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.first = ns.Text(c, 10)
    Plain(c.first, 11, ns.colors.dim)
    c.first:SetPoint("TOPLEFT", ICON + 18, -22)
    c.first:SetPoint("RIGHT", -30, 0)
    c.first:SetJustifyH("LEFT")
    c.first:SetWordWrap(false)
    c.sign = ns.Text(c, 14)
    c.sign:SetPoint("TOPRIGHT", -12, -12)
    c.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- opened: a rule under the head, the whole text, Delete at the foot
    c.rule = c:CreateTexture(nil, "ARTWORK")
    c.rule:SetHeight(1)
    c.rule:SetPoint("TOPLEFT", 1, -HEAD)
    c.rule:SetPoint("TOPRIGHT", -1, -HEAD)
    c.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.text = ns.Text(c, 11)
    Plain(c.text, 12, ns.colors.text)
    c.text:SetPoint("TOPLEFT", 14, -(HEAD + 7))
    c.text:SetJustifyH("LEFT")
    c.text:SetJustifyV("TOP")
    c.text:SetWordWrap(true)
    c.delete = CreateFrame("Button", nil, c)
    c.delete:SetSize(64, 20)
    c.delete:SetPoint("BOTTOMRIGHT", -8, 6)
    c.delete:SetFrameLevel(c:GetFrameLevel() + 2)
    R.Box(c.delete, 0.4)
    R.Lit(c.delete)
    c.delete.label = ns.Text(c.delete, 11)
    c.delete.label:SetPoint("CENTER")
    c.delete.label:SetText("Delete")
    -- the game's own confirm, which deletes the macro in the editor
    c.delete:SetScript("OnClick", function()
        Select(c.i)
        Press(MacroDeleteButton)
    end)
    c.delete:SetScript("OnEnter", function(self)
        ns.Tip(self, ns.window.Outside, { title = "Delete " .. (c.name or ""), color = GOLD,
            { "body", "Asks first." } })
    end)
    c.delete:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- what the secure button covers: the head within the edges
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetPoint("TOPLEFT", 1, -1)
    c.hit:SetPoint("TOPRIGHT", -1, -1)
    c.hit:SetHeight(HEAD - 1)
    c.glow = c:CreateTexture(nil, "HIGHLIGHT")
    c.glow:SetAllPoints(c.hit)
    c.glow:SetColorTexture(1, 1, 1, 0.06)
    -- in combat (the secure layer away), or cut by the scroll's edge: the
    -- left opens it, the right runs nothing
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnClick", function(self, button) Click(self, button) end)
    c:SetScript("OnDragStart", function(self)
        if self.index and not InCombatLockdown() then PickupMacro(self.index) end
    end)
    c:SetScript("OnEnter", function(self) Tooltip(self, self) end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cards[n] = c
    return c
end

-- -------------------------------------------------------- the secure layer
-- One secure button over each card's head wholly in view: the right button
-- runs its macro (type2, so the left runs nothing). Out of combat only;
-- a state driver hides the layer in combat.
local function Secure(n)
    local b = layer.buttons[n]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.card and self.card.index and not InCombatLockdown() then PickupMacro(self.card.index) end
    end)
    b:SetScript("PostClick", function(self, button, down)
        if down and Binding() then return end
        if self.card then Click(self.card, button) end
    end)
    b:SetScript("OnEnter", function(self) if self.card then Tooltip(self, self.card) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    layer.buttons[n] = b
    return b
end

local function Arm(b, c)
    local run = c and c.index and not Binding()
    b:SetAttribute("type", nil)
    b:SetAttribute("type2", run and "macro" or nil)
    b:SetAttribute("macro", run and c.index or nil)
end

local function Follow()
    if not layer or InCombatLockdown() then return end
    local top = scroller.offset or 0
    local bottom = top + (scroller.scroll:GetHeight() or 0)
    local n = 0
    for _, c in ipairs(shown and cards or {}) do
        if c:IsShown() and c.i and c.y >= top - 0.5 and c.y + HEAD <= bottom + 0.5 then
            n = n + 1
            local b = Secure(n)
            b.card = c
            Arm(b, c)
            if Binding() then
                b:RegisterForClicks("AnyUp", "AnyDown")
            else
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
            end
            b:SetShown(W.Over(b, c.hit))
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.card = nil
        Arm(b, nil)
        b:Hide()
    end
    if shown then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ----------------------------------------------------------------- drawing
local function Switch()
    local tab = Set()
    local account, character = GetNumMacros()
    local consts = Constants and Constants.MacroConsts or {}
    local free = not (MacroPopupFrame and MacroPopupFrame:IsShown())
    switch:Fill({
        { key = 1, label = format("General   %d / %d", account or 0, consts.MAX_ACCOUNT_MACROS or 120),
            selected = tab == 1, enabled = free or tab == 1,
            click = function() M.Tab(1) end, tip = function() return "The macros every character shares." end },
        { key = 2, label = format("%s   %d / %d", UnitName("player") or "Character", character or 0,
            consts.MAX_CHARACTER_MACROS or 18), selected = tab == 2, enabled = free or tab == 2,
            click = function() M.Tab(2) end, tip = function() return "This character's own macros." end },
    })
end

local function Cards()
    local f = MacroFrame
    local _, count, base = Set()
    local selected = f:GetSelectedIndex()
    local width = W.width - GUTTER
    local y = 0
    for i = 1, count do
        local c = cards[i] or Card(i)
        local name, icon, text = GetMacroInfo(base + i)
        text = text or ""
        c.i, c.index, c.name = i, base + i, name
        c.icon:SetTexture(icon)
        c.label:SetText(name or "")
        c.first:SetText(First(text))
        local open = name ~= nil and Opened(name)
        c.sign:SetText(open and "-" or "+")
        c.first:SetShown(not open)
        c.rule:SetShown(open)
        c.text:SetShown(open)
        c.delete:SetShown(open)
        local h = HEAD
        if open then
            c.text:SetWidth(width - 28)
            c.text:SetText(text)
            local lines = select(2, text:gsub("\n", "")) + 1
            h = HEAD + 7 + math.max(lines * LINE, c.text:GetStringHeight() or 0) + 8 + 20 + 6
        end
        local on = i == selected
        local edge = on and GOLD or GOLD_D
        for _, t in ipairs(c.edges) do t:SetColorTexture(edge[1], edge[2], edge[3], 1) end
        c.bar:SetShown(on)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetSize(width, h)
        c.y, c.h = y, h
        c:Show()
        y = y + h + SPACE
    end
    for i = count + 1, #cards do
        cards[i].i, cards[i].index, cards[i].name = nil, nil, nil
        cards[i]:Hide()
    end
    scroller.child:SetSize(width, math.max(1, y - SPACE))
end

-- The editor's header and foot: the macro in it, what the game's buttons
-- allow, Save marked while there is typing to save
local function Paint()
    local f = MacroFrame
    if not (editor and f and adopted) then return end
    local _, count, base = Set()
    local selected = f:GetSelectedIndex()
    local index = selected and base + selected
    local name, icon
    if index then name, icon = GetMacroInfo(index) end
    editor.icon:SetTexture(icon)
    editor.icon:SetShown(name ~= nil)
    editor.ring:SetShown(name ~= nil)
    editor.name:SetText(name or "")
    editor.pencil:SetShown(name ~= nil)
    editor.pencil:SetAlpha(MacroEditButton:IsEnabled() and 1 or 0.4)
    editor.empty:SetShown(count == 0)
    local can = name ~= nil
    editor.buttons:Set("new", { enabled = MacroNewButton:IsEnabled() })
    editor.buttons:Set("save", { enabled = can, selected = can and edited })
    editor.buttons:Set("cancel", { enabled = can and edited })
    local spell = index and Spell(index)
    editor.casts:SetText(spell and "Casts " .. spell or "")
    editor.count:SetText(can and format("%d / %d", MacroFrameText:GetNumLetters(), LETTERS) or "")
end

function Refresh()
    if not (adopted and scroller and MacroFrame:IsShown()) then return end
    Switch()
    Cards()
    scroller.To(scroller.target)
    Paint()
    Follow()
end
M.Refresh = Refresh

-- ---------------------------------------------------------------- editor
local function Editor(parent)
    local e = CreateFrame("Frame", nil, parent)
    e:SetPoint("BOTTOMLEFT")
    e:SetPoint("BOTTOMRIGHT")
    e:SetHeight(EDITOR)
    -- its header: the macro's icon and name, the pencil, New Save Cancel
    e.head = CreateFrame("Frame", nil, e)
    e.head:SetPoint("TOPLEFT")
    e.head:SetPoint("TOPRIGHT")
    e.head:SetHeight(BAR)
    R.Box(e.head, 0.9)
    local band = e.head:CreateTexture(nil, "BACKGROUND", nil, -6)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("BOTTOMRIGHT", -1, 1)
    R.Fade(band, GOLD_D, 0.55)
    e.icon = e.head:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(24, 24)
    e.icon:SetPoint("LEFT", 8, 0)
    e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    e.ring = e.head:CreateTexture(nil, "BORDER")
    e.ring:SetPoint("TOPLEFT", e.icon, -1, 1)
    e.ring:SetPoint("BOTTOMRIGHT", e.icon, 1, -1)
    e.ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    e.name = ns.Text(e.head, 13)
    e.name:SetPoint("LEFT", e.icon, "RIGHT", 10, 0)
    e.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    e.name:SetWordWrap(false)
    e.pencil = CreateFrame("Button", nil, e.head)
    e.pencil:SetSize(22, 22)
    e.pencil:SetPoint("LEFT", e.name, "RIGHT", 6, 0)
    R.Glyph(e.pencil, "edit", 12)
    e.pencil:SetScript("OnClick", function() Press(MacroEditButton) end)
    e.pencil:SetScript("OnEnter", function(self)
        ns.Tip(self, ns.window.Outside, { title = "Change its name and icon", color = GOLD })
    end)
    e.pencil:SetScript("OnLeave", function() GameTooltip:Hide() end)
    e.buttons = ns.window.Segments(e.head, { height = BAR - 8, fit = true, size = 12, items = {
        { key = "new", label = "+  New", click = function() Press(MacroNewButton) end,
            tip = function() return "A new macro in this set: its name and icon first." end },
        { key = "save", label = "Save", click = function() Press(MacroSaveButton) end,
            tip = function() return "Save the text." end },
        { key = "cancel", label = "Cancel", click = function()
            if not edited then return end
            Press(MacroCancelButton)
            -- the text back as it was saved
            local i = MacroFrame:GetSelectedIndex()
            if i then MacroFrame:SelectMacro(i) end
        end, tip = function() return "Put the text back as it was saved." end },
    } })
    e.buttons:SetPoint("RIGHT", -4, 0)
    -- the text, in a well the game's own edit box is laid in
    e.well = CreateFrame("Frame", nil, e)
    e.well:SetPoint("TOPLEFT", e.head, "BOTTOMLEFT", 0, -6)
    e.well:SetPoint("BOTTOMRIGHT", 0, 20)
    R.Box(e.well, 0.95)
    e.empty = ns.Text(e.well, 12)
    e.empty:SetPoint("CENTER")
    e.empty:SetTextColor(unpack(ns.colors.dim))
    e.empty:SetText("No macros yet: + New to make one.")
    e.casts = ns.Text(e, 11)
    e.casts:SetPoint("BOTTOMLEFT", 4, 3)
    e.casts:SetTextColor(unpack(ns.colors.dim))
    e.count = ns.Text(e, 11)
    e.count:SetPoint("BOTTOMRIGHT", -4, 3)
    e.count:SetTextColor(unpack(ns.colors.dim))
    return e
end

-- ---------------------------------------------------------------- adopting
local function Place()
    local f = MacroFrame
    placing = true
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", body, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
    placing = false
end

-- The game's frame bare: its art, its title and words away; its grid,
-- tabs and buttons hidden but working (ours call them), the ones its
-- details show again faded out instead
local function Strip(f)
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton" }) do
        if f[key] then f[key]:Hide() end
    end
    for _, key in ipairs({ "Background", "Bg", "TopTileStreaks", "Inset" }) do
        if f[key] then
            f[key]:SetAlpha(0)
            if f[key].EnableMouse then f[key]:EnableMouse(false) end
        end
    end
    for _, r in ipairs({ f:GetRegions() }) do r:SetAlpha(0) end
    for _, part in ipairs({ f.MacroSelector, MacroFrameTab1, MacroFrameTab2, MacroSaveButton, MacroCancelButton,
        MacroDeleteButton, MacroNewButton, MacroExitButton, MacroFrameTextBackground }) do
        part:Hide()
    end
    for _, part in ipairs({ f.SelectedMacroButton, MacroEditButton }) do
        part:SetAlpha(0)
        part:EnableMouse(false)
    end
    f:EnableMouse(false)
    -- its text box in our well
    local scroll = MacroFrameScrollFrame
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", editor.well, "TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", editor.well, "BOTTOMRIGHT", -26, 8)
    MacroFrameText:SetWidth(W.width - 40)
    Plain(MacroFrameText, 13, ns.colors.text)
    MacroFrameTextButton:ClearAllPoints()
    MacroFrameTextButton:SetAllPoints(scroll)
end

-- The name and icon picker: our box and a title strip it is dragged by,
-- floating left of the book, over it (DIALOG) if dragged there
local function Spot(p)
    p:ClearAllPoints()
    local wt, lt = W.window:GetTop(), list:GetTop()
    -- TOPLEFT: the game reads that point back to size its panel
    p:SetPoint("TOPLEFT", W.window, "TOPLEFT", -(p:GetWidth() + 8), (wt and lt) and lt - wt or 0)
end

local function Popup()
    local p = MacroPopupFrame
    if not p then return end
    R.Bare(p)
    if p.BorderBox then R.Bare(p.BorderBox) end
    R.Box(p, 0.97)
    local top = CreateFrame("Frame", nil, p)
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(28)
    top:SetFrameLevel(p:GetFrameLevel() + 5)
    local band = top:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    R.Fade(band, GOLD_D, 0.55)
    local title = ns.Text(top, 13)
    title:SetPoint("LEFT", 10, 0)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() p:StartMoving() end)
    top:SetScript("OnDragStop", function()
        p:StopMovingOrSizing()
        if p.SetUserPlaced then p:SetUserPlaced(false) end
        -- held by its top left, the point the game reads back
        local x, y = p:GetLeft(), p:GetTop()
        if x and y then
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
    end)
    local cross = CreateFrame("Button", nil, top)
    cross:SetSize(22, 22)
    cross:SetPoint("RIGHT", -4, 0)
    local g = R.Glyph(cross, "close", 11)
    cross:SetScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
    cross:SetScript("OnLeave", function() g:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
    local box = p.BorderBox or {}
    cross:SetScript("OnClick", function() Press(box.CancelButton) end)
    for _, b in ipairs({ box.OkayButton, box.CancelButton }) do
        R.Plain(b)
        for _, k in ipairs({ "Left", "Right", "Middle" }) do
            if b[k] then b[k]:SetAlpha(0) end
        end
        R.Box(b, 0.4)
        R.Lit(b)
        R.Font(b.GetFontString and b:GetFontString(), 12, ns.colors.text)
    end
    p:HookScript("OnShow", function(self)
        self:SetFrameStrata("DIALOG")
        Spot(self)
        local new = IconSelectorPopupFrameModes and IconSelectorPopupFrameModes.New or "new"
        title:SetText(self.mode == new and "New macro" or "Change name and icon")
        Refresh()
    end)
    p:HookScript("OnHide", function() Refresh() end)
end

-- The game's own ways in (/macro, the game menu): its window put back, the
-- book opened on this page
local function Take()
    C_Timer.After(0, function()
        HideUIPanel(MacroFrame)
        Place()
        M.Open()
    end)
end

local function Adopt()
    local f = MacroFrame
    if adopted or not f or not body then return end
    adopted = true
    f:SetParent(body)
    f:SetToplevel(false)
    f:SetFrameLevel(editor:GetFrameLevel() + 4)
    Place()
    hooksecurefunc(f, "SetPoint", function() if not placing then Place() end end)
    Strip(f)
    Popup()
    -- each change of the game's: drawn again
    for _, method in ipairs({ "Update", "SelectMacro", "UpdateButtons" }) do
        hooksecurefunc(f, method, function() Refresh() end)
    end
    -- a macro loaded: nothing typed yet
    hooksecurefunc(f, "SelectMacro", function() edited = false Paint() end)
    hooksecurefunc(f, "ChangeTab", function() edited = false end)
    MacroFrameText:HookScript("OnTextChanged", function(_, user)
        if user then edited = true end
        Paint()
    end)
    -- the game opens on the account's set: back to the one last shown
    f:HookScript("OnShow", function(self)
        local tab = MedalluinCharDB and MedalluinCharDB.macroTab
        if tab == 2 and PanelTemplates_GetSelectedTab(self) ~= 2 then self:ChangeTab(2) end
        Refresh()
    end)
    if MacroFrame_Show then hooksecurefunc("MacroFrame_Show", Take) end
end

local function Load()
    if not body then return false end
    if not MacroFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_MacroUI") end
    if MacroFrame then Adopt() end
    return adopted
end

-- ------------------------------------------------------------------ the page
-- The switch at the top, the cards under it, the editor at the foot
function M.Build(p, b)
    page, body = p, b
    switch = ns.window.Segments(b, { height = SWITCH, items = {} })
    switch:SetPoint("TOPLEFT")
    switch:SetPoint("TOPRIGHT")
    list = CreateFrame("Frame", nil, b)
    list:SetPoint("TOPLEFT", 0, -(SWITCH + 8))
    list:SetPoint("BOTTOMRIGHT", 0, EDITOR + 10)
    scroller = ns.window.Scroller(list, GUTTER)
    scroller.Moved = function() Follow() end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) scroller.To(scroller.target - delta * STEP) end)
    editor = Editor(b)
    layer = W.Layer("MedalluinSpellbookMacros")
    M.switch, M.list, M.scroller, M.editor, M.layer = switch, list, scroller, editor, layer
    ns.On("PLAYER_REGEN_ENABLED", Follow)
    if MacroFrame then Adopt() end
end

-- the set switched: the game's own tab pressed (which saves the text first)
function M.Tab(n)
    local tab = _G["MacroFrameTab" .. n]
    if not tab or PanelTemplates_GetSelectedTab(MacroFrame) == n then return end
    if MacroPopupFrame and MacroPopupFrame:IsShown() then return end
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.macroTab = n
    local click = tab:GetScript("OnClick")
    if click then click(tab, "LeftButton") end
end

-- the window open on the page, or not
function M.Showing(on)
    shown = on and true or false
    if on then
        if Load() then
            Place()
            if not MacroFrame:IsShown() then MacroFrame:Show() end
            Refresh()
        end
    elseif adopted and MacroFrame:IsShown() then
        MacroFrame:Hide()
    end
    Follow()
end

-- the book opened on this page (out of combat: the book's frame is the
-- game's, protected)
function M.Open()
    if not page then return end
    W.Select(page)
    if W.window:IsShown() then return end
    ns.OutOfCombat(function()
        if W.window:IsShown() then return end
        if PlayerSpellsUtil and PlayerSpellsUtil.OpenToSpellBookTab then
            PlayerSpellsUtil.OpenToSpellBookTab()
        elseif PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
            PlayerSpellsUtil.TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.SpellBook)
        end
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then Adopt() end
end)
