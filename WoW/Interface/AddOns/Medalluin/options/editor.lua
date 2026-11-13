-- The unit-frame editor's window (art/settings/gen_editor.py, U3): the
-- frames as tabs (the console's, then the widgets), the chosen frame's
-- pieces down the left in groups, the canvas in the middle
-- (options/canvas.lua: the frame drawn large, the chosen piece boxed; drag
-- it to move the piece, the arrow keys nudge it), the chosen piece's
-- controls down the right under its tabs (Place, Look, Auras), one to a
-- line, applied as they change. Its footer has
-- the preview (simulate.lua's: a party, a raid, bosses and an arena to edit
-- out of a group) and the canvas's preview chips (editor.lua's E.preview:
-- each dispel type's glow, the aggro glow, the combat tint, crowd control,
-- a boss debuff, your buffs). editor.lua is the model: what the pieces are,
-- and where they go.
--
-- Opened by /mdlui edit, and by the button on each Unit Frames tab.
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors
local E = ns.editor

local W, H = 1000, 620
local PAD, LIST_W, BODY_W, TAB_H, FOOT = 14, 160, 270, 24, 58
local ROW_H, HEAD_H, GAP, CHIP_H = 22, 16, 6, 24
local TAB_Y = PAD + 24                  -- the frame tabs' top, under their group's caption
local TOP = TAB_Y + TAB_H + 10          -- the list's, the canvas's and the body's top
local PIECE_TAB_H = 22                  -- the piece's tabs (Place, Look, Auras)

local window, tabs, list, stage, body, chips
local frame, piece        -- what is chosen: the frame (E.FRAMES) and its piece
local tab = "place"       -- the piece's tab, kept by name from piece to piece
local controls = {}       -- the body's controls, by field
local Refresh

-- ------------------------------------------------------------ the fields
-- A field of the chosen piece: what the player set, else where the piece
-- is now (a place read off a button the first time, editor.lua's E.Seed).
local function Edits() return E.Edits(frame, piece) or {} end
-- (read each time: a button laid again by its own code has a new place)
local function Seed() return E.Seed(frame, piece) end
local function PlaceField(field)
    local e = Edits()
    if e.h then return e[field] end
    return Seed()[field]
end
-- A change of place: the first one writes the whole place, so what is not
-- changed stays where it was. A row placed is in its frame again (Outside).
local function SetPlace(fields)
    local write = { out = E.NIL }
    if not Edits().h then
        for k, v in pairs(Seed()) do write[k] = v end
    end
    for k, v in pairs(fields) do write[k] = v end
    E.Set(frame, piece, write)
end
local function SetField(field, value) E.Set(frame, piece, { [field] = value }) end

local function Mirrored() return frame.id == "unit" or frame.id == "party" end

-- What a piece's outline is set to, read off its font when not set.
local function Outline()
    local e = Edits()
    if e.outline then return e.outline end
    local b = frame.buttons()[1]
    local r = b and E.PIECES[piece].get(b)
    local flags = r and r.GetFont and select(3, r:GetFont()) or ""
    flags = tostring(flags or "")
    return flags:match("THICK") and "thick" or flags:match("OUTLINE") and "thin" or "none"
end

-- ------------------------------------------------------------ the controls
-- An offset to the hundredth: one saved earlier from a float read back
-- from the game (-2 as -2.0000002384186) shows as what it is.
local function Pixels(v) return tostring(math.floor(v * 100 + 0.5) / 100) end

local function Specs()
    return {
        shown = { kind = "check", label = "Shown",
            get = function() return E.Shown(frame, piece) end,
            set = function(v)
                local key = frame.shows and frame.shows[piece]
                if key then ns.SetOption(key, v) else SetField("shown", v) end
            end,
            tip = function()
                local key = frame.shows and frame.shows[piece]
                if key then return "The same option as on the Unit Frames page." end
                return "Off, the piece is not drawn, but keeps its place."
            end },
        on = { kind = "choice", label = "On",
            choices = E.ON,
            get = function() return PlaceField("on") or "health" end,
            set = function(v) SetPlace({ on = v }) end,
            tip = "What the piece is placed on. Its anchor (a corner, an edge or the middle of it) is "
                .. "where it is dropped on the canvas." },
        x = { kind = "slider", label = "Inward", min = -150, max = 150,
            get = function() return PlaceField("x") or 0 end,
            set = function(v) SetPlace({ x = v }) end, text = Pixels,
            tip = "Pixels from the anchor, toward the frame's inner end (on the console) or right (a widget)." },
        y = { kind = "slider", label = "Up", min = -60, max = 60,
            get = function() return PlaceField("y") or 0 end,
            set = function(v) SetPlace({ y = v }) end, text = Pixels,
            tip = "Pixels from the anchor, up." },
        size = { kind = "slider", label = "Size", min = 6, max = 48,
            get = function()
                -- (the debuffs matched to the buffs: theirs)
                local own = piece == "mine" and E.Matched(frame) and E.BuffSize(frame) or Edits().size
                return own or math.floor((E.SizeOf(frame, piece) or 12) + 0.5)
            end,
            set = function(v) SetField("size", v) end,
            tip = "A text's font size, an icon's width and height." },
        -- the debuffs', while both rows are outside
        match = { kind = "check", label = "Match buffs size",
            get = function() return Edits().match == true end,
            set = function(v) SetField("match", v or E.NIL) end,
            tip = "The debuffs as large as the buffs, and following them as the buffs' Size changes. Only "
                .. "while both rows are outside the frame; each keeps its own side." },
        outline = { kind = "choice", label = "Outline", choices = E.OUTLINES,
            get = Outline, set = function(v) SetField("outline", v) end,
            tip = "A dark edge round the letters." },
        format = { kind = "choice", label = "Format", choices = {},
            get = function()
                local formats = E.FORMATS[piece]
                return Edits().format or (formats and formats[1][1])
            end,
            set = function(v) SetField("format", v) end,
            tip = "What the text says." },
        len = { kind = "slider", label = "Longest name", min = 0, max = 30,
            get = function() return Edits().len or 0 end,
            set = function(v) SetField("len", v > 0 and v or E.NIL) end,
            text = function(v) return v > 0 and (v .. " letters") or "No limit" end,
            tip = "Letters before a name is cut. A name the game keeps secret is shown whole." },
        grow = { kind = "choice", label = "Grow", choices = {},
            get = function() return Edits().grow or (E.RowOwn(frame, piece)) end,
            set = function(v) SetField("grow", v) end,
            tip = "Which way the icons run from the first." },
        cols = { kind = "slider", label = "Columns", min = 1, max = 10,
            get = function() return Edits().cols or 10 end,
            set = function(v) SetField("cols", v < 10 and v or E.NIL) end,
            text = function(v) return v < 10 and tostring(v) or "One line" end,
            tip = "Icons in a line before the next starts, away from the edge the first hangs on. Growing up "
                .. "or down, icons in a column." },
        out = { kind = "check", label = "Outside",
            get = function() return Edits().out == true end,
            set = function(v) SetField("out", v or E.NIL) end,
            tip = "Beyond the frame's outer end, running toward the screen's edge. With buffs and debuffs both "
                .. "outside, the debuffs' Next to buffs says where they go. A drag puts the row back in the "
                .. "frame." },
        -- a widget's: which side, or toward the nearer edge of the screen
        side = { kind = "choice", label = "Place", choices = {
                { "in", "Inside the frame" }, { "edge", "Toward screen edge" },
                { "left", "Outside, left" }, { "right", "Outside, right" } },
            get = function()
                local out = Edits().out
                return out == true and "edge" or out or "in"
            end,
            set = function(v) SetField("out", v == "edge" or (v ~= "in" and v) or E.NIL) end,
            tip = "Inside the frame, or beyond one of its ends, running away from it: toward the nearer edge of "
                .. "the screen, or left or right. Buffs and debuffs out on the same side: the debuffs' Next to "
                .. "buffs says where they go. A drag puts the row back in the frame." },
        -- the debuffs', while both rows are out on one side
        by = { kind = "choice", label = "Next to buffs", choices = {},
            get = function() return Edits().by or "below" end,
            set = function(v) SetField("by", v ~= "below" and v or E.NIL) end,
            tip = "Where the debuffs go while the buffs are outside on the same side: under them, over them, "
                .. "or beside them." },
        from = { kind = "choice", label = "From", choices = E.FROM,
            get = function()
                local b = frame.buttons()[1]
                local row = b and E.PIECES[piece].get(b)
                return Edits().from or row and row.from or "mine"
            end,
            set = function(v) SetField("from", v) end,
            tip = "Whose auras the row shows: only the ones you cast, or all of them." },
        max = { kind = "slider", label = "Most icons", min = 1, max = 10,
            get = function() return Edits().max or select(2, E.RowOwn(frame, piece)) end,
            set = function(v) SetField("max", v) end,
            tip = "The most auras the row shows at once." },
        ph = { kind = "slider", label = "Height", min = 0, max = 20,
            get = function()
                local b = frame.buttons()[1]
                return ns.PowerHeight(frame.id, b and b.powerDefault or 4)
            end,
            set = function(v) SetField("ph", v) end,
            text = function(v) return v > 0 and tostring(v) or "None" end,
            tip = "The power bar's height; the health bar takes the rest. None: no power bar, the health the "
                .. "whole frame." },
        w = { kind = "slider", label = "Width", min = 60, max = 300,
            get = function() return (ns.CellSize(frame.id)) end,
            set = function(v) SetField("w", v) end,
            tip = "The cell's width. Takes effect out of combat." },
        h = { kind = "slider", label = "Height", min = 18, max = 80,
            get = function() return select(2, ns.CellSize(frame.id)) end,
            set = function(v) SetField("h", v) end,
            tip = "The cell's height, the power bar included. Takes effect out of combat." },
    }
end

-- The piece's tabs, in order: where it goes, how it looks, which auras (a
-- row's). Shown is over them all, never in one. A cell and a bar have one
-- tab each, and no strip.
local TAB_NAMES = { place = "Place", look = "Look", auras = "Auras" }
local function Tabs()
    local kind = E.PIECES[piece].type
    if kind == "cell" then return { { id = "place", fields = { "w", "h" } } } end
    if kind == "bar" then return { { id = "place", fields = { "ph" } } } end
    local place = { "on", "x", "y" }
    local look = { "size" }
    if kind == "text" then
        look[#look + 1] = "outline"
        if E.FORMATS[piece] then look[#look + 1] = "format" end
        if piece == "name" then look[#look + 1] = "len" end
    end
    if kind ~= "row" then
        return { { id = "place", fields = place }, { id = "look", fields = look } }
    end
    local out = Mirrored() and "out" or "side"
    -- the debuffs out with the buffs: a size of the buffs' to take
    local buffs = E.Edits(frame, "buffs")
    if piece == "mine" and Edits().out and buffs and buffs.out then look = { "match", "size" } end
    -- a row outside its frame is placed by that: no place, no way to grow
    if Edits().out then
        place = { out, "cols" }
        -- the debuffs out on the buffs' side: where, beside them
        if piece == "mine" and E.Stacked(frame, frame.buttons()[1]) then place = { out, "by", "cols" } end
    else
        place = { out, "on", "x", "y", "grow", "cols" }
    end
    return { { id = "place", fields = place }, { id = "look", fields = look },
        { id = "auras", fields = { "from", "max" } } }
end

-- The chosen tab of the piece's: the one kept, else its first.
local function Tab()
    local all = Tabs()
    for _, t in ipairs(all) do if t.id == tab then return t, all end end
    return all[1], all
end

-- What is laid, as one string; laid: Lay's last.
local function Laid()
    local t, all = Tab()
    return piece .. ":" .. t.id .. "/" .. #all .. ":" .. table.concat(t.fields, ",")
end
local laid

-- The piece's tabs across the body, in the settings window's look: the
-- chosen one lit, its foot open onto what it holds.
local function Strip(y)
    local strip = body.tabStrip
    local t, all = Tab()
    for _, b in ipairs(strip.tabs) do b:Hide() end
    strip:SetShown(#all > 1)
    if #all < 2 then return y end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
    strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
    local x = 0
    for i, one in ipairs(all) do
        local b = strip.tabs[i]
        b.id = one.id
        b.text:SetText(TAB_NAMES[one.id])
        b:SetWidth(math.ceil(b.text:GetStringWidth()) + 24)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, 0)
        local on = one == t
        local bg = on and C.selected or C.ink
        b.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
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
    return y - PIECE_TAB_H - 10
end

-- Shown, the tabs, and the chosen tab's controls, one to a line. Should a
-- tab ever hold more than the column (none does: the harness measures
-- every one), its lines close up rather than run into the footer.
local function Lay()
    laid = Laid()
    local t = Tab()
    window.tab = t.id
    local function Down(gap)
        for _, c in pairs(controls) do c:Hide() end
        local y = -30
        if E.PIECES[piece].type ~= "cell" and E.PIECES[piece].type ~= "bar" then
            local c = controls.shown
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
            c:Show()
            y = y - c:GetHeight() - gap
        end
        y = Strip(y)
        for _, field in ipairs(t.fields) do
            local c = controls[field]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
            c:Show()
            y = y - c:GetHeight() - gap
        end
        controls.reset:Show()
        return -(y + gap)
    end
    -- (the body's height from the window's sizes: read off the body, it is
    -- 0 until the game first lays it out)
    if Down(GAP) > H - (TOP + 4) - FOOT then Down(2) end
end

-- ------------------------------------------------------------ choosing
local function Choose(id, which)
    frame = E.byId[id] or E.FRAMES[1]
    local ok = false
    for _, p in ipairs(frame.pieces) do if p == which then ok = true end end
    piece = ok and which or frame.pieces[1]
    controls.x.spec.label = Mirrored() and "Inward" or "Right"
    controls.x.label:SetText(controls.x.spec.label)
    controls.format.spec.choices = E.FORMATS[piece] or {}
    controls.grow.spec.choices = Mirrored()
        and { { "inner", "Inward" }, { "outer", "Outward" }, { "up", "Up" }, { "down", "Down" } }
        or { { "inner", "Right" }, { "outer", "Left" }, { "up", "Up" }, { "down", "Down" } }
    controls.by.spec.choices = Mirrored()
        and { { "below", "Below" }, { "above", "Above" }, { "outer", "Outward" }, { "inner", "Inward" } }
        or { { "below", "Below" }, { "above", "Above" }, { "left", "Left" }, { "right", "Right" } }
    Lay()
    Refresh()
    if E.onChoose then E.onChoose() end
end

-- What the frame is, whose it is, and where it can be seen.
local NOTES = {
    unit = "The player and the target: one layout, mirrored.",
    party = "The console's party; the left and right wings mirrored.",
    partyWidget = "The party, while Console > General > Party layout is Widget.",
    raid = "The Raid widget, and in a battleground too.",
    boss = "The Boss widget, while Console > General > Boss frames shows it.",
    arena = "The Arena widget's enemy frames.",
}
local function Scope()
    local profile = ns.db.consoleProfile
    for _, p in ipairs(ns.PROFILE_NAMES) do if p[1] == profile then profile = p[2] end end
    local whose = ns.PER_PROFILE[frame.key] and ("Per profile: " .. profile .. ".")
        or "Shared by every profile."
    local shown = false
    for _, b in ipairs(frame.buttons()) do if b:IsVisible() then shown = true end end
    -- the party is one or the other: the preview cannot show the one its
    -- layout does not use
    local why = " Not on screen now: Preview shows it."
    local widget = ns.PartyWidgetLayout and ns.PartyWidgetLayout()
    if frame.id == "partyWidget" and not widget then why = " Not on screen now: the party layout is Console."
    elseif frame.id == "party" and widget then why = " Not on screen now: the party layout is Widget." end
    return NOTES[frame.id] .. " " .. whose .. (shown and "" or why)
end

-- ------------------------------------------------------------ the list
-- The pieces in groups, each under its heading, in the frame's order.
local GROUPS = {
    { name = "Frame", types = { cell = true, bar = true } },
    { name = "Texts", types = { text = true } },
    { name = "Icons", types = { icon = true } },
    { name = "Auras", types = { row = true } },
}

-- The list's i-th line, made the first time it is wanted: a piece (its
-- name, lit when chosen, a mark when changed) or a group's heading.
local function List(i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row.lit = UI.Fill(row, "BACKGROUND", C.selected, 1)
    row.lit:SetAllPoints()
    row.text = UI.Serif(row, 13, C.text)
    row.text:SetPoint("LEFT", 10, 0)
    row.head = UI.Plain(row, 10, C.goldDark)
    row.head:SetPoint("BOTTOMLEFT", 8, 1)
    -- a mark on a piece the player changed
    row.mark = UI.Fill(row, "ARTWORK", C.gold)
    row.mark:SetSize(4, 4)
    row.mark:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function(self) if self.piece then Choose(frame.id, self.piece) end end)
    list.rows[i] = row
    return row
end

-- ------------------------------------------------------------ refresh
function Refresh()
    if not window or not window:IsShown() then return end
    -- a row taken outside, or brought in, has other controls
    if laid ~= Laid() then Lay() end
    for _, b in ipairs(tabs) do
        local on = b.frame == frame
        local bg, text = on and C.selected or C.ink, on and C.goldBright or C.dim
        b.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
        b.text:SetTextColor(text[1], text[2], text[3])
    end
    -- the pieces under their group's heading; a group the frame has none
    -- of, no heading
    local i, y = 0, -6
    for _, group in ipairs(GROUPS) do
        local ids = {}
        for _, id in ipairs(frame.pieces) do
            if group.types[E.PIECES[id].type] then ids[#ids + 1] = id end
        end
        if #ids > 0 then
            i = i + 1
            local head = List(i)
            head.piece = nil
            head.heading = group.name
            head:EnableMouse(false)
            head:SetHeight(HEAD_H)
            head.lit:Hide()
            head.mark:Hide()
            head.text:Hide()
            head.head:SetText(group.name:upper())
            head.head:Show()
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 4, y)
            head:SetPoint("TOPRIGHT", -4, y)
            head:Show()
            y = y - HEAD_H - 4
            for _, id in ipairs(ids) do
                i = i + 1
                local row = List(i)
                row.piece = id
                row.heading = nil
                row:EnableMouse(true)
                row:SetHeight(ROW_H)
                row.head:Hide()
                row.text:SetText(E.PIECES[id].label)
                row.text:Show()
                row.lit:SetShown(id == piece)
                local edited = E.Edits(frame, id) ~= nil
                local c = id == piece and C.goldBright or edited and C.text or C.dim
                row.text:SetTextColor(c[1], c[2], c[3])
                row.mark:SetShown(edited)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 4, y)
                row:SetPoint("TOPRIGHT", -4, y)
                row:Show()
                y = y - ROW_H - 2
            end
        end
    end
    for k = i + 1, #list.rows do list.rows[k]:Hide() end
    body.title:SetText(E.PIECES[piece].label)
    -- (the canvas sets it as it draws, too: the room it leaves)
    stage.scope:SetText(Scope())
    for field, c in pairs(controls) do
        if c:IsShown() and c.Refresh then
            -- a hidden piece's other fields stay set, but wait
            local kind = E.PIECES[piece].type
            local enabled = field == "shown" or field == "reset" or kind == "cell" or kind == "bar"
                or controls.shown.spec.get() ~= false
            if field == "reset" then enabled = E.Edits(frame, piece) ~= nil end
            -- the debuffs' size, while it is the buffs'
            if field == "size" and piece == "mine" and E.Matched(frame) then enabled = false end
            c:Refresh(enabled)
        end
    end
    window.preview:SetText(ns.db.simParty and "Preview: on" or "Preview")
    for _, b in ipairs(chips) do
        local on = E.preview[b.id] and true or false
        local bg, text = on and C.selected or C.ink, on and C.goldBright or C.dim
        b.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
        b.text:SetTextColor(text[1], text[2], text[3])
        for _, t in ipairs(b.edge) do t:SetShown(on) end
        if b.swatch then
            local key = b.id == "threat" and "threatColor" or ("dispelColor" .. b.id)
            b.swatch:SetColorTexture(ns.HexColor(ns.db[key]))
        end
    end
end

-- ------------------------------------------------------------ the keys
-- The arrow keys nudge the chosen piece; the other keys go on to the game
-- (not in combat: the game forbids passing them on, so a fight hands them
-- all back).
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local function Key(self, key)
    local step = ARROWS[key]
    local kind = E.PIECES[piece].type
    -- (a row outside its frame is placed by that)
    local move = step and kind ~= "cell" and kind ~= "bar" and not Edits().out
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not move) end
    if not move then return end
    local b = frame.buttons()[1]
    local side = Mirrored() and b and E.Side(b, frame) or -1
    SetPlace({ x = (PlaceField("x") or 0) - side * step[1], y = (PlaceField("y") or 0) + step[2] })
end

local function Keys(on)
    if not window then return end
    window:EnableKeyboard(on)
    if on and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end
ns.On("PLAYER_REGEN_DISABLED", function() Keys(false) end)
ns.On("PLAYER_REGEN_ENABLED", function() if window and window:IsShown() then Keys(true) end end)

-- ------------------------------------------------------------ the chips
-- The canvas's previews (E.PREVIEWS), a chip each, across the footer: a
-- dispel type's and the aggro's with their colour's swatch.
local function Chips(from, to)
    chips = {}
    local n = #E.PREVIEWS
    local w = math.floor((to - from - (n - 1) * 4) / n)
    -- (what the rounding leaves, either side alike)
    from = from + math.floor((to - from - n * w - (n - 1) * 4) / 2)
    for i, p in ipairs(E.PREVIEWS) do
        local b = CreateFrame("Button", nil, window)
        b:SetSize(w, CHIP_H)
        b:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", from + (i - 1) * (w + 4), 10)
        b.bg = UI.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        UI.Outline(b, "BORDER", C.goldDark, 0)
        b.edge = UI.Outline(b, "OVERLAY", C.goldBright, 0)
        b.id = p[1]
        b.text = UI.Serif(b, 11, C.dim)
        if p.dispel or p[1] == "threat" then
            b.swatch = UI.Fill(b, "ARTWORK", C.gold)
            b.swatch:SetSize(6, 6)
            b.swatch:SetPoint("LEFT", 4, 0)
            b.text:SetPoint("LEFT", b.swatch, "RIGHT", 3, 0)
            b.text:SetPoint("RIGHT", -2, 0)
        else
            b.text:SetPoint("CENTER", 0, 0)
        end
        b.text:SetText(p[2])
        b:SetScript("OnClick", function(self)
            E.TogglePreview(self.id)
            Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            UI.Tip(self, p[2], p.dispel and ("A " .. p[2] .. " debuff's glow on the canvas, in its colour (Unit "
                .. "Frames > General > Glows). One type at a time.")
                or p[1] == "threat" and "The aggro glow on the canvas, and the console's tint red."
                or p[1] == "combat" and "The console's combat tint, on screen."
                or "Shown on the canvas, as in play.")
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        chips[i] = b
    end
end

-- ------------------------------------------------------------ the window
local function Remember()
    local point, _, relative, x, y = window:GetPoint()
    ns.SetOption("editorPoint", { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) })
end

local function Grip(f)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() window:StartMoving() end)
    f:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        if window.SetUserPlaced then window:SetUserPlaced(false) end
        Remember()
    end)
end

local function Window()
    if window then return end
    window = CreateFrame("Frame", "MedalluinEditor", UIParent)
    window:SetSize(W, H)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    Grip(window)
    local at = ns.db.editorPoint
    if at then
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
    UI.Skin(window, C.panel)
    window:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinEditor") end
    window:SetScript("OnShow", function()
        Keys(true)
        Refresh()
    end)
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        Keys(false)
        E.ClearPreview()
    end)
    window:SetScript("OnKeyDown", Key)

    local title = CreateFrame("Frame", nil, window)
    title:SetHeight(28)
    title:SetPoint("CENTER", window, "TOP", 0, 0)
    title:SetFrameLevel(window:GetFrameLevel() + 5)
    UI.Skin(title, C.ink)
    local text = UI.Serif(title, 15, C.goldBright)
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Unit Frame Editor")
    title:SetWidth(math.ceil(text:GetStringWidth()) + 44)
    Grip(title)

    local x = CreateFrame("Button", nil, window)
    x:SetSize(20, 20)
    x:SetPoint("TOPRIGHT", -8, -6)
    x.text = UI.Serif(x, 14, C.gold)
    x.text:SetPoint("CENTER", 0, 1)
    x.text:SetText("x")
    x:SetScript("OnClick", function() window:Hide() end)

    -- the frames, as tabs: the console's (per profile), then the widgets
    -- (shared), each group under its caption
    tabs = {}
    window.captions = {}
    local left, group = PAD, nil
    for i, f in ipairs(E.FRAMES) do
        local console = ns.PER_PROFILE[f.key] and true or false
        if console ~= group then
            if group ~= nil then left = left + 10 end
            group = console
            local cap = UI.Plain(window, 9, C.goldDark)
            cap:SetPoint("BOTTOMLEFT", window, "TOPLEFT", left + 2, -(TAB_Y - 2))
            cap:SetText(console and "CONSOLE" or "WIDGETS")
            window.captions[#window.captions + 1] = cap
            cap.first = f
        end
        local b = CreateFrame("Button", nil, window)
        b:SetHeight(TAB_H)
        b.bg = UI.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        UI.Outline(b, "BORDER", C.goldDark, 0)
        b.text = UI.Serif(b, 12, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(f.name)
        b:SetWidth(math.ceil(b.text:GetStringWidth()) + 24)
        b:SetPoint("TOPLEFT", window, "TOPLEFT", left, -TAB_Y)
        left = left + b:GetWidth() + 4
        b.frame = f
        b:SetScript("OnClick", function(self) Choose(self.frame.id, piece) end)
        tabs[i] = b
    end
    local rule = UI.Fill(window, "ARTWORK", C.gold)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", PAD, -(TAB_Y + TAB_H))
    rule:SetPoint("TOPRIGHT", -PAD, -(TAB_Y + TAB_H))

    -- the frame's pieces, in groups (Refresh lays them)
    list = CreateFrame("Frame", nil, window)
    list:SetPoint("TOPLEFT", PAD, -TOP)
    list:SetPoint("BOTTOMLEFT", PAD, FOOT)
    list:SetWidth(LIST_W)
    UI.Skin(list, C.ink)
    list.rows = {}

    -- the chosen piece's controls, down the right: its name and Reset
    -- piece, Shown, its tabs, the chosen tab's controls
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD - 4, -(TOP + 4))
    body:SetPoint("BOTTOMRIGHT", -PAD - 4, FOOT)
    body:SetWidth(BODY_W)
    body.title = UI.Serif(body, 16, C.goldBright)
    body.title:SetPoint("TOPLEFT", 0, -2)
    local strip = CreateFrame("Frame", nil, body)
    strip:SetHeight(PIECE_TAB_H)
    strip.tabs = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, strip)
        b:SetHeight(PIECE_TAB_H)
        b.bg = UI.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        b.edge = UI.Outline(b, "BORDER", C.goldDark, 0)
        b.text = UI.Serif(b, 12, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b:SetScript("OnClick", function(self)
            tab = self.id
            Lay()
            Refresh()
        end)
        b:Hide()
        strip.tabs[i] = b
    end
    strip.rule = UI.Fill(strip, "ARTWORK", C.gold)
    strip.rule:SetHeight(1)
    strip.rule:SetPoint("BOTTOMLEFT", 0, 0)
    strip.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    body.tabStrip = strip

    -- the canvas, between
    stage = ns.EditorStage(window)
    stage:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    stage:SetSize(W - 2 * PAD - LIST_W - 10 - 14 - BODY_W - 4, H - TOP - FOOT)
    local specs = Specs()
    for field, spec in pairs(specs) do
        if type(spec.tip) == "function" then
            local fn = spec.tip
            spec.tip = nil
            spec.tipFn = fn
        end
        -- one line each, the label at the left (the settings window's rows)
        local c
        if spec.kind == "check" then
            c = UI.Check(body, spec, BODY_W, true)
        elseif spec.kind == "choice" then
            c = UI.Choice(body, spec, BODY_W, true)
        else
            c = UI.Slider(body, spec, BODY_W, true)
        end
        controls[field] = c
    end
    controls.reset = UI.Button(body, "Reset piece", 110, 22, function() E.ResetPiece(frame, piece) end,
        "This piece back to how its frame draws it.")
    -- level with the piece's name: under the controls, a long list ran it
    -- into the footer (2026-11-13: the buffs')
    controls.reset:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)

    -- the footer: Preview | the canvas's chips, under their caption |
    -- Reset frame, Close
    local foot = UI.Fill(window, "ARTWORK", C.goldDark)
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", PAD, FOOT - 8)
    foot:SetPoint("BOTTOMRIGHT", -PAD, FOOT - 8)
    window.preview = UI.Button(window, "Preview", 100, 24, function() ns.SetOption("simParty", not ns.db.simParty) end,
        "Simulated party, raid, bosses and arena enemies to edit out of a group; their panel sets what "
        .. "they show.")
    window.preview:SetPoint("BOTTOMLEFT", PAD, 10)
    window.preview.SetText = function(self, t) self.text:SetText(t) end
    local close = UI.Button(window, "Close", 96, 24, function() window:Hide() end, nil, true)
    close:SetPoint("BOTTOMRIGHT", -PAD, 10)
    local reset = UI.Button(window, "Reset frame", 100, 24, function() E.ResetFrame(frame) end,
        "Every piece of this frame back to how it draws it.")
    reset:SetPoint("RIGHT", close, "LEFT", -8, 0)
    window.reset = reset
    local from, to = PAD + 100 + 18, W - PAD - 96 - 8 - 100 - 18
    window.dividers = {}
    for i, x in ipairs({ from - 9, to + 9 }) do
        local d = UI.Fill(window, "ARTWORK", C.goldDark)
        d:SetSize(1, 20)
        d:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", x, 12)
        window.dividers[i] = d
    end
    Chips(from, to)
    window.chipsCaption = UI.Plain(window, 9, C.goldDark)
    window.chipsCaption:SetPoint("BOTTOMLEFT", chips[1], "TOPLEFT", 2, 4)
    window.chipsCaption:SetText("SHOW ON THE CANVAS")

    -- its parts, by name (the harness reads them)
    window.tabs, window.list, window.body, window.controls = tabs, list, body, controls
    window.stage, window.chips = stage, chips
    Choose(E.FRAMES[1].id)
end

-- The Shown tip says which option it is; set as the pointer comes.
local function TipShown()
    local c = controls.shown
    if not c then return end
    c:SetScript("OnEnter", function(self) UI.Tip(self, "Shown", c.spec.tipFn()) end)
end

-- ------------------------------------------------------------ open
-- ns.OpenEditor(id): the window, on that frame ("party", "raid", ...), or
-- its first tab (player and target).
function ns.OpenEditor(id)
    Window()
    TipShown()
    id = id or E.FRAMES[1].id
    Choose(id, piece)
    window:Show()
    window:Raise()
end

-- The window's frames, made without showing it (the harness's way in).
function ns.BuildEditor()
    Window()
    TipShown()
end

ns.OnAnySetting(function()
    if not window or not window:IsShown() then return end
    Refresh()
end)

-- What the canvas shares: the choice, and the place a drag or a key writes.
E.ui = {
    Choose = function(id, which) Choose(id, which) end,
    Chosen = function() return frame, piece end,
    PlaceField = PlaceField,
    SetPlace = SetPlace,
    Mirrored = function() return Mirrored() end,
    Window = function() return window end,
    -- what the frame is and whose, over the canvas
    Scope = function() return frame and Scope() or "" end,
    Refresh = function() Refresh() end,
}
