-- The unit-frame editor's window (art/settings/gen_editor.py, U3): the
-- frames as tabs, the chosen frame's pieces down the left, the canvas in
-- the middle (options/canvas.lua: the frame drawn large, the chosen piece
-- boxed; drag it to move the piece, the arrow keys nudge it), the chosen
-- piece's controls down the right, applied as they change. Its footer has
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
local PAD, LIST_W, BODY_W, TAB_H, FOOT = 14, 160, 250, 24, 46
local ROW_H, GAP, CHIP_H = 22, 8, 24

local window, tabs, list, stage, body, chips
local frame, piece        -- what is chosen: the frame (E.FRAMES) and its piece
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
-- changed stays where it was.
local function SetPlace(fields)
    local write = {}
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
            tip = "What the piece is placed on: the anchor is a point of it." },
        x = { kind = "slider", label = "Inward", min = -150, max = 150,
            get = function() return PlaceField("x") or 0 end,
            set = function(v) SetPlace({ x = v }) end,
            tip = "Pixels from the anchor, toward the frame's inner end (on the console) or right (a widget)." },
        y = { kind = "slider", label = "Up", min = -60, max = 60,
            get = function() return PlaceField("y") or 0 end,
            set = function(v) SetPlace({ y = v }) end,
            tip = "Pixels from the anchor, up." },
        size = { kind = "slider", label = "Size", min = 6, max = 48,
            get = function() return Edits().size or math.floor((E.SizeOf(frame, piece) or 12) + 0.5) end,
            set = function(v) SetField("size", v) end,
            tip = "A text's font size, an icon's width and height." },
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

-- A new anchor keeps the piece as far into what it is on as it was: an
-- inset from the inner end becomes one from the outer, not one past it
-- (2026-11-12: the health value thrown off the frame). Centred, no offset.
local function Reanchor(h, v)
    local x, y = PlaceField("x") or 0, PlaceField("y") or 0
    local oh, ov = PlaceField("h"), PlaceField("v")
    local deepX = oh == "inner" and -x or oh == "outer" and x or math.abs(x)
    local deepY = ov == "top" and -y or ov == "bottom" and y or math.abs(y)
    return { h = h, v = v, ph = E.NIL, pv = E.NIL,
        -- (+ 0: no -0 saved)
        x = (h == "inner" and -deepX or h == "outer" and deepX or 0) + 0,
        y = (v == "top" and -deepY or v == "bottom" and deepY or 0) + 0 }
end

-- The anchor: nine points, as the piece sits on what it is placed on.
local GRID = { { "top", "middle", "bottom" }, { "outer", "center", "inner" } }
local function Grid(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(90, 58)
    f.label = UI.Serif(f, 11, C.goldBright)
    f.label:SetPoint("TOPLEFT", 0, 0)
    f.label:SetText("Anchor")
    f.cells = {}
    for r, v in ipairs(GRID[1]) do
        for c, h in ipairs(GRID[2]) do
            local b = CreateFrame("Button", nil, f)
            b:SetSize(20, 12)
            b:SetPoint("TOPLEFT", (c - 1) * 24, -16 - (r - 1) * 14)
            b.bg = UI.Fill(b, "BACKGROUND", C.well, 1)
            b.bg:SetAllPoints()
            UI.Outline(b, "BORDER", C.goldDark, 0)
            b.h, b.v = h, v
            b:SetScript("OnClick", function(self) SetPlace(Reanchor(self.h, self.v)) end)
            table.insert(f.cells, b)
        end
    end
    function f:Refresh(enabled)
        local h, v = PlaceField("h"), PlaceField("v")
        for _, b in ipairs(self.cells) do
            local on = b.h == h and b.v == v
            local col = on and C.goldBright or C.well
            b.bg:SetColorTexture(col[1], col[2], col[3], 1)
            b:SetEnabled(enabled)
        end
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end

-- Which controls a piece has, row by row (the anchor and what it is on
-- share one).
local function Rows()
    local kind = E.PIECES[piece].type
    if kind == "cell" then return { { "w", "h" } } end
    if kind == "bar" then return { { "ph" } } end
    local rows = { { "shown" }, { "anchor", "on" }, { "x", "y" } }
    if kind == "text" then
        table.insert(rows, { "size", "outline" })
        if E.FORMATS[piece] then table.insert(rows, piece == "name" and { "format", "len" } or { "format" }) end
    elseif kind == "row" then
        table.insert(rows, { "size", "max" })
        table.insert(rows, { "grow", "cols" })
    else
        table.insert(rows, { "size" })
    end
    return rows
end

local function Lay()
    for _, c in pairs(controls) do c:Hide() end
    local y = -(math.ceil(body.scope:GetStringHeight()) + 40)
    for _, row in ipairs(Rows()) do
        if row[1] == "anchor" then
            local a, on = controls.anchor, controls.on
            a:ClearAllPoints()
            a:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
            on:ClearAllPoints()
            on:SetPoint("TOPLEFT", body, "TOPLEFT", 100, y)
            on:SetWidth(BODY_W - 100)
            a:Show()
            on:Show()
            y = y - math.max(a:GetHeight(), on:GetHeight()) - GAP
        else
            -- one to a row
            for _, field in ipairs(row) do
                local c = controls[field]
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
                if c.SetWidth then c:SetWidth(BODY_W) end
                c:Show()
                y = y - c:GetHeight() - GAP
            end
        end
    end
    controls.reset:ClearAllPoints()
    controls.reset:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y - 4)
    controls.reset:Show()
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

-- ------------------------------------------------------------ refresh
function Refresh()
    if not window or not window:IsShown() then return end
    for _, b in ipairs(tabs) do
        local on = b.frame == frame
        local bg, text = on and C.selected or C.ink, on and C.goldBright or C.dim
        b.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
        b.text:SetTextColor(text[1], text[2], text[3])
    end
    for i, row in ipairs(list.rows) do
        local id = frame.pieces[i]
        row:SetShown(id ~= nil)
        if id then
            row.piece = id
            row.text:SetText(E.PIECES[id].label)
            row.lit:SetShown(id == piece)
            local edited = E.Edits(frame, id) ~= nil
            local c = id == piece and C.goldBright or edited and C.text or C.dim
            row.text:SetTextColor(c[1], c[2], c[3])
            row.mark:SetShown(edited)
        end
    end
    body.title:SetText(E.PIECES[piece].label)
    body.scope:SetText(Scope())
    for field, c in pairs(controls) do
        if c:IsShown() and c.Refresh then
            -- a hidden piece's other fields stay set, but wait
            local kind = E.PIECES[piece].type
            local enabled = field == "shown" or field == "reset" or kind == "cell" or kind == "bar"
                or controls.shown.spec.get() ~= false
            if field == "reset" then enabled = E.Edits(frame, piece) ~= nil end
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
    local move = step and kind ~= "cell" and kind ~= "bar"
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

    -- the frames, as tabs
    tabs = {}
    local left = PAD
    for i, f in ipairs(E.FRAMES) do
        local b = CreateFrame("Button", nil, window)
        b:SetHeight(TAB_H)
        b.bg = UI.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        UI.Outline(b, "BORDER", C.goldDark, 0)
        b.text = UI.Serif(b, 12, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(f.name)
        b:SetWidth(math.ceil(b.text:GetStringWidth()) + 24)
        b:SetPoint("TOPLEFT", window, "TOPLEFT", left, -(PAD + 14))
        left = left + b:GetWidth() + 4
        b.frame = f
        b:SetScript("OnClick", function(self) Choose(self.frame.id, piece) end)
        tabs[i] = b
    end
    local rule = UI.Fill(window, "ARTWORK", C.gold)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", PAD, -(PAD + 14 + TAB_H))
    rule:SetPoint("TOPRIGHT", -PAD, -(PAD + 14 + TAB_H))

    -- the frame's pieces
    list = CreateFrame("Frame", nil, window)
    list:SetPoint("TOPLEFT", PAD, -(PAD + 14 + TAB_H + 10))
    list:SetPoint("BOTTOMLEFT", PAD, FOOT)
    list:SetWidth(LIST_W)
    UI.Skin(list, C.ink)
    list.rows = {}
    local most = 0
    for _, f in ipairs(E.FRAMES) do most = math.max(most, #f.pieces) end
    for i = 1, most do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 4, -6 - (i - 1) * (ROW_H + 2))
        row:SetPoint("TOPRIGHT", -4, -6 - (i - 1) * (ROW_H + 2))
        row.lit = UI.Fill(row, "BACKGROUND", C.selected, 1)
        row.lit:SetAllPoints()
        row.text = UI.Serif(row, 13, C.text)
        row.text:SetPoint("LEFT", 10, 0)
        -- a mark on a piece the player changed
        row.mark = UI.Fill(row, "ARTWORK", C.gold)
        row.mark:SetSize(4, 4)
        row.mark:SetPoint("RIGHT", -8, 0)
        row:SetScript("OnClick", function(self) Choose(frame.id, self.piece) end)
        list.rows[i] = row
    end

    -- the chosen piece's controls, down the right
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD - 4, -(PAD + 14 + TAB_H + 14))
    body:SetPoint("BOTTOMRIGHT", -PAD - 4, FOOT)
    body:SetWidth(BODY_W)
    body.title = UI.Serif(body, 16, C.goldBright)
    body.title:SetPoint("TOPLEFT", 0, -2)
    body.scope = UI.Plain(body, 11, C.dim)
    body.scope:SetPoint("TOPLEFT", 0, -24)
    body.scope:SetWidth(BODY_W)
    body.scope:SetJustifyH("LEFT")

    -- the canvas, between
    stage = ns.EditorStage(window)
    stage:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    stage:SetSize(W - 2 * PAD - LIST_W - 10 - 14 - BODY_W - 4, H - (PAD + 14 + TAB_H + 10) - FOOT)
    local specs = Specs()
    for field, spec in pairs(specs) do
        if type(spec.tip) == "function" then
            local fn = spec.tip
            spec.tip = nil
            spec.tipFn = fn
        end
        local c
        if spec.kind == "check" then
            c = UI.Check(body, spec, 200)
        elseif spec.kind == "choice" then
            c = UI.Choice(body, spec, 200)
        else
            c = UI.Slider(body, spec, 200)
        end
        controls[field] = c
    end
    controls.anchor = Grid(body)
    controls.reset = UI.Button(body, "Reset piece", 110, 22, function() E.ResetPiece(frame, piece) end,
        "This piece back to how its frame draws it.")

    -- the footer
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
    Chips(PAD + 100 + 12, W - PAD - 96 - 8 - 100 - 12)

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
-- the party's, as its layout has it.
function ns.OpenEditor(id)
    Window()
    TipShown()
    id = id or (ns.PartyWidgetLayout and ns.PartyWidgetLayout() and "partyWidget" or "party")
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
    Refresh = function() Refresh() end,
}
