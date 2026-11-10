-- Click Casting (/cc): the game's own window (ClickBindingFrame,
-- Blizzard_ClickBindingUI) dressed as the Cooldown Manager is, standing in
-- the LFG window's spot (window/reskin.lua) while the spellbook opens on
-- the right strip beside it.
--
--   Click Casting                                          [x]
--   ---------------------------------------------------------
--   [v] Mouseover cast   with Shift v                 | (book) (macros)
--   - DEFAULT ------------------------------------------
--     (o) Target unit frame
--         [Left]
--   - CUSTOM -------------------------------------------
--     (o) Healing Wave
--         [Shift] + [Middle]                      a binding: its click as keycaps
--     (+) Click on a spell or macro to get started    the slot waiting for one
--   ---------------------------------------------------------
--   BINDER  (1) Pick a spell - (2) Click the pad - (3) Save
--     (o) Healing Wave   [ (mouse) Click here with the click you want ]
--   ---------------------------------------------------------
--   [<-] | [ + Add binding ]                        | [ Save ]
--
-- Every click, drop, menu and save is the game's own code; ours is its look,
-- its place, and the binder, whose pad passes its click to the game's own
-- click on the binding's line.
--
-- ns.clickcast.Keys(info) and ns.clickcast.Bound() serve the spellbook too
-- (spells/spellbook.lua): a binding's click as words, and the bindings by
-- spell.
local _, ns = ...

local R = ns.reskin
local deco = R.deco
local PAD, ROW, GAP, EDGE = R.PAD, R.ROW, R.GAP, R.EDGE
local GOLD, GOLD_D, DIM = R.GOLD, R.GOLD_D, R.DIM
local GLYPHS, ROUND = R.GLYPHS, R.ROUND
local HEAD = 36
local TOP = -(HEAD + 18)            -- the top row's top, under the head's hairs
local LIST = TOP - ROW - 12         -- the list's top, under it
local FOOT = 1 + ROW + 12           -- the list's foot, over the foot row
local BINDER = 128                  -- the binder, over the foot
local ICON = 28                     -- a binding's medallion
local TYPE = Enum and Enum.ClickBindingType or { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
local NEW_SLOT = 5                  -- the game's ElementDataTypes.NewSlot

local cc = {}
ns.clickcast = cc

local skin

local function Frame() return _G.ClickBindingFrame end

-- ---------------------------------------------------------------- the keys
-- A binding's click as words: its modifiers (the game's own names for them)
-- and its button, short. { "Shift", "Middle" }, "Shift+Middle"; nil when
-- it has no button (unbound).
local BUTTONS = { LeftButton = "Left", Button1 = "Left", RightButton = "Right", Button2 = "Right",
    MiddleButton = "Middle", Button3 = "Middle" }

local function Mods(m)
    if not m or m == 0 then return "" end
    local f = C_ClickBindings and C_ClickBindings.GetStringFromModifiers or _G.GetStringFromModifiers
    if not f then return "" end
    local ok, s = pcall(f, m)
    return ok and type(s) == "string" and s or ""
end

function cc.Keys(info)
    if type(info) ~= "table" or type(info.button) ~= "string" then return nil end
    local keys = {}
    for word in Mods(info.modifiers):gmatch("[^%-%+%s]+") do
        table.insert(keys, word:sub(1, 1):upper() .. word:sub(2):lower())
    end
    table.insert(keys, BUTTONS[info.button] or (info.button:gsub("^Button(%d+)$", "Mouse %1")))
    return keys, table.concat(keys, "+")
end

-- The profile's spell and pet bindings: by spell ID, and by name (a binding
-- set on another rank of a spell still marks the rank the book shows).
-- Each a list of { text, pet }.
function cc.Bound()
    local ids, names = {}, {}
    local get = C_ClickBindings and C_ClickBindings.GetProfileInfo
    if not get then return ids, names end
    local ok, profile = pcall(get)
    if not ok or type(profile) ~= "table" then return ids, names end
    for _, info in ipairs(profile) do
        local pet = info.type == TYPE.PetAction
        if (info.type == TYPE.Spell or pet) and info.actionID then
            local _, text = cc.Keys(info)
            if text then
                local b = { text = text, pet = pet }
                ids[info.actionID] = ids[info.actionID] or {}
                table.insert(ids[info.actionID], b)
                local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(info.actionID)
                if name then
                    names[name] = names[name] or {}
                    table.insert(names[name], b)
                end
            end
        end
    end
    return ids, names
end

-- In the game's bind mode: its window open
function cc.Binding()
    return _G.InClickBindingMode ~= nil and _G.InClickBindingMode() and true or false
end

-- ---------------------------------------------------------------- the place
local function Place() R.Place(Frame()) end
cc.Place = Place

-- A cell's words: ours, over the game's (its font objects reset a font of
-- ours each time its state changes)
local function Words(b, text, size)
    local d = deco[b]
    if not d.words then
        d.words = ns.Text(b, size or 13)
        d.words:SetPoint("CENTER", 0, 0)
        -- the game's own words emptied, not only hidden: its button states
        -- draw them again (nothing reads them back)
        local fs = b.GetFontString and b:GetFontString()
        if fs then fs:SetAlpha(0) end
        if b.Text then b.Text:SetAlpha(0) end
        if b.SetText then b:SetText("") end
    end
    d.words:SetText(text)
    return d.words
end

local function Shade(b)
    local d = deco[b]
    if not d or not d.words then return end
    local on = not b.IsEnabled or b:IsEnabled()
    local c = d.marked and GOLD or on and ns.colors.text or DIM
    d.words:SetTextColor(c[1], c[2], c[3])
end

-- ---------------------------------------------------------------- the rows
-- The top row as the Cooldown Manager's search row: a cell holding the
-- mouseover tick and its key, then the two windows it opens beside it on
-- the edge (the spellbook, the macros), the one open marked.
local function Portrait(p, glyph, x)
    R.Bare(p)
    for _, k in ipairs({ "Portrait", "Frame", "UnselectedFrame", "Highlight" }) do
        if p[k] then p[k]:SetAlpha(0) end
    end
    local d = R.Box(p, 0.4)
    R.Glyph(p, glyph, 16)
    R.Lit(p)
    if not d.mark then
        d.mark = p:CreateTexture(nil, "BACKGROUND", nil, -6)
        d.mark:SetPoint("TOPLEFT", 1, -1)
        d.mark:SetPoint("BOTTOMRIGHT", -1, 1)
        d.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
        d.mark:Hide()
        if p.SetSelectedState then
            hooksecurefunc(p, "SetSelectedState", function(_, on)
                d.mark:SetShown(on and true or false)
                local c = on and GOLD or GOLD_D
                d.glyph:SetVertexColor(c[1], c[2], c[3])
            end)
        end
    end
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", Frame(), "TOPRIGHT", x, TOP)
    p:SetSize(ROW, ROW)
end

local function Top(f)
    -- the windows it opens beside it: the macros on the edge, the book in
    -- from it (sharing an edge), a gap before them
    local left = -EDGE                  -- the cells' left edge, from the window's right
    if f.MacrosPortrait then
        Portrait(f.MacrosPortrait, "log", left)
        left = left - ROW + 1
    end
    if f.PlayerSpellsPortrait then
        Portrait(f.PlayerSpellsPortrait, "spellbook", left)
        left = left - ROW + 1
    end
    left = left - 1
    -- the cell: the tick and its key, up to the gap
    local d = deco[f] or {}
    deco[f] = d
    if not d.cell then
        d.cell = CreateFrame("Frame", nil, skin)
        R.Box(d.cell, 0.4)
    end
    d.cell:ClearAllPoints()
    d.cell:SetPoint("TOPLEFT", f, "TOPLEFT", 1, TOP)
    d.cell:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", left - GAP, TOP - ROW)
    local check = f.EnableMouseoverCastCheckbox
    if type(check) == "table" then
        R.Plain(check)
        R.Box(check, 1)
        for _, get in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
            local t = check[get] and check[get](check)
            if t then
                t:SetDesaturated(true)
                t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", -3, 3)
                t:SetPoint("BOTTOMRIGHT", 3, -3)
            end
        end
        R.Lit(check)
        check:ClearAllPoints()
        check:SetPoint("LEFT", d.cell, "LEFT", 10, 0)
        check:SetSize(14, 14)
        if check.Label then
            R.Font(check.Label, 14, ns.colors.text)
            check.Label:ClearAllPoints()
            check.Label:SetPoint("LEFT", check, "RIGHT", 8, 0)
        end
    end
    -- its key: shown while mouseover cast is on (the game's), after a
    -- faint parting
    local key = f.MouseoverCastKeyDropdown
    if key then
        R.Bare(key)
        for _, k in ipairs({ "Background", "Arrow" }) do
            if key[k] then key[k]:SetAlpha(0) end
        end
        if key.Label then key.Label:SetAlpha(0) end
        local e = deco[key]
        if not e.with then
            e.part = key:CreateTexture(nil, "ARTWORK")
            e.part:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.55)
            e.part:SetSize(1, ROW - 12)
            e.part:SetPoint("LEFT", -8, 0)
            e.with = ns.Text(key, 12)
            e.with:SetPoint("LEFT", 0, 0)
            e.with:SetTextColor(DIM[1], DIM[2], DIM[3])
            e.with:SetText("with")
            e.arrow = key:CreateTexture(nil, "OVERLAY")
            e.arrow:SetTexture(GLYPHS .. "chevron-down")
            e.arrow:SetSize(10, 10)
            e.arrow:SetPoint("RIGHT", -6, 0)
            e.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            key:HookScript("OnEnter", function() e.arrow:SetVertexColor(1, 1, 1) end)
            key:HookScript("OnLeave", function() e.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
        end
        if key.Text then
            R.Font(key.Text, 13, ns.colors.text)
            key.Text:ClearAllPoints()
            key.Text:SetPoint("LEFT", e.with, "RIGHT", 8, 0)
            key.Text:SetPoint("RIGHT", e.arrow, "LEFT", -4, 0)
            if key.Text.SetJustifyH then key.Text:SetJustifyH("LEFT") end
        end
        key:ClearAllPoints()
        key:SetPoint("LEFT", d.cell, "LEFT", 168, 0)
        key:SetSize(120, ROW)
        R.Dropdown(key)
    end
    -- the tutorial's button: away (its page still opens the first time)
    if f.TutorialButton then
        f.TutorialButton:SetAlpha(0)
        f.TutorialButton:EnableMouse(false)
    end
end

-- The foot as the Cooldown Manager's: Reset (a rounded arrow back), a gap,
-- Add binding; at the edge Save, marked while
-- there are changes to save.
local function Cell(b, width)
    R.Plain(b)
    for _, k in ipairs({ "Left", "Right", "Middle" }) do
        if b[k] then b[k]:SetAlpha(0) end
    end
    local d = R.Box(b, 0.4)
    if not d.cell then
        d.cell = true
        R.Lit(b)
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
        b:HookScript("OnEnable", function() Shade(b) end)
        b:HookScript("OnDisable", function() Shade(b) end)
        -- the game fitting a button to its words: back to the cell
        hooksecurefunc(b, "SetWidth", function(self, w)
            if w ~= width then self:SetWidth(width) end
        end)
    end
    b:SetSize(width, ROW)
    return d
end

function cc.Pending()
    local f = Frame()
    local save = f and f.SaveButton
    local d = save and deco[save]
    if not d or not d.mark then return end
    d.marked = f.pendingChanges and true or false
    d.mark:SetShown(d.marked)
    Shade(save)
end

local function Foot(f)
    local reset = f.ResetButton
    if reset then
        local d = Cell(reset, ROW)
        if not d.glyph then
            d.glyph = reset:CreateTexture(nil, "OVERLAY")
            d.glyph:SetTexture(GLYPHS .. "side-reset")
            d.glyph:SetTexCoord(1, 0, 0, 1)
            d.glyph:SetSize(16, 16)
            d.glyph:SetPoint("CENTER")
            d.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            local fs = reset.GetFontString and reset:GetFontString()
            if fs then fs:SetAlpha(0) end
            reset:HookScript("OnEnter", function(self)
                ns.Tip(self, ns.window.Outside, { title = "Reset to default", color = GOLD,
                    { "body", "Back to the game's own bindings: your custom ones are kept, unbound." } })
            end)
            reset:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        reset:ClearAllPoints()
        reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    end
    local add = f.AddBindingButton
    if type(add) == "table" then
        Cell(add, 130)
        Words(add, "+  Add binding")
        Shade(add)
        add:ClearAllPoints()
        add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1 + ROW + GAP, 1)
    end
    local save = f.SaveButton
    if save then
        local d = Cell(save, 90)
        Words(save, "Save")
        if not d.mark then
            d.mark = save:CreateTexture(nil, "BACKGROUND", nil, -6)
            d.mark:SetPoint("TOPLEFT", 1, -1)
            d.mark:SetPoint("BOTTOMRIGHT", -1, 1)
            d.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
            d.mark:Hide()
        end
        save:ClearAllPoints()
        save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -EDGE, 1)
        cc.Pending()
    end
    -- what a binding taken from another left unbound: over the foot
    if f.UnboundText then
        R.Font(f.UnboundText, 13)
        f.UnboundText:ClearAllPoints()
        f.UnboundText:SetPoint("BOTTOM", f, "BOTTOM", 0, FOOT - 4)
    end
end

-- -------------------------------------------------------------- the list
-- Its headings as ours: gold small capitals, a rule fading right
local function Heading(h)
    local d = deco[h] or {}
    deco[h] = d
    if not d.rule then
        if h.Init then hooksecurefunc(h, "Init", function() Heading(h) end) end
        d.rule = h:CreateTexture(nil, "ARTWORK")
        d.rule:SetHeight(1)
        d.rule:SetPoint("RIGHT", h, "RIGHT", -4, 0)
        R.Fade(d.rule, GOLD_D, 1)
    end
    if h.Name then
        R.Font(h.Name, 13, GOLD)
        h.Name:ClearAllPoints()
        h.Name:SetPoint("LEFT", 4, 0)
        if h.Name.SetWidth then h.Name:SetWidth(0) end
        d.rule:SetPoint("LEFT", h.Name, "RIGHT", 10, 0)
    end
end

-- a keycap: its word in a small gold-edged box
local function Cap(line, d, i)
    local k = d.caps[i]
    if not k then
        k = CreateFrame("Frame", nil, line)
        k:SetHeight(18)
        R.Box(k, 0.95)
        k.word = ns.Text(k, 12)
        k.word:SetPoint("CENTER", 0, 0)
        k.plus = ns.Text(line, 12)
        k.plus:SetText("+")
        k.plus:SetTextColor(DIM[1], DIM[2], DIM[3])
        d.caps[i] = k
    end
    return k
end

local function Caps(line, d)
    local info = d.data and d.data.bindingInfo
    local keys = d.data and d.data.elementType ~= NEW_SLOT and cc.Keys(info)
    local x = 0
    for i = 1, math.max(#(keys or {}), #d.caps) do
        local key = keys and keys[i]
        if key then
            local k = Cap(line, d, i)
            k.word:SetText(key)
            local w = (k.word:GetStringWidth() or 0) + 12
            k:SetWidth(w)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", line.Name, "BOTTOMLEFT", x, -4)
            local c = d.hot and GOLD or GOLD_D
            R.Edge(deco[k], c)
            local t = d.hot and GOLD or ns.colors.text
            k.word:SetTextColor(t[1], t[2], t[3])
            k:Show()
            x = x + w
            k.plus:SetShown(keys[i + 1] ~= nil)
            if keys[i + 1] then
                k.plus:ClearAllPoints()
                k.plus:SetPoint("LEFT", k, "RIGHT", 3, 0)
                x = x + 14
            end
        elseif d.caps[i] then
            d.caps[i]:Hide()
            d.caps[i].plus:Hide()
        end
    end
    -- the game's words where there are no keys: unbound (red), the slot's
    -- prompt (green)
    if line.BindingText then line.BindingText:SetAlpha(keys and 0 or 1) end
end

-- A binding: its icon a medallion of ours (the game's own texture, which it
-- sets again and again, an atlas on the waiting slot, left unmasked and
-- hidden), its name, its click as keycaps; the slot waiting for a spell a
-- gold dashed box with a + in its ring.
local function Line(line)
    local d = deco[line] or {}
    deco[line] = d
    if not d.icon then
        d.caps = {}
        for _, k in ipairs({ "Background", "FrameHighlight", "NewOutline", "EmptySlotIconHighlight" }) do
            if line[k] then line[k]:SetAlpha(0) end
        end
        d.row = line:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.row:SetAllPoints()
        d.row:SetColorTexture(1, 1, 1, 0.05)
        d.row:Hide()
        d.slot = CreateFrame("Frame", nil, line)
        d.slot:SetAllPoints()
        d.slot:SetFrameLevel(line:GetFrameLevel())
        R.Box(d.slot, 0)
        d.slot.wash = d.slot:CreateTexture(nil, "BACKGROUND", nil, -6)
        d.slot.wash:SetPoint("TOPLEFT", 1, -1)
        d.slot.wash:SetPoint("BOTTOMRIGHT", -1, 1)
        d.slot.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14)
        d.icon = line:CreateTexture(nil, "ARTWORK")
        d.icon:SetSize(ICON, ICON)
        d.icon:SetPoint("LEFT", line, "LEFT", 4, 0)
        R.Medal(line, d.icon, 2.5)
        d.plus = ns.Text(line, 16)
        d.plus:SetPoint("CENTER", d.icon, "CENTER", 0, 1)
        d.plus:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        d.plus:SetText("+")
        if line.IconHighlight then
            -- the game's glow as it waits for a spell: round, over our ring
            line.IconHighlight:ClearAllPoints()
            line.IconHighlight:SetPoint("TOPLEFT", d.icon, "TOPLEFT", -6, 6)
            line.IconHighlight:SetPoint("BOTTOMRIGHT", d.icon, "BOTTOMRIGHT", 6, -6)
        end
        local del = line.DeleteButton
        if del then
            R.Plain(del)
            if del.Icon then del.Icon:SetAlpha(0) end
            local g = R.Glyph(del, "close", 10)
            g:SetVertexColor(DIM[1], DIM[2], DIM[3])
            del:HookScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
            del:HookScript("OnLeave", function() g:SetVertexColor(DIM[1], DIM[2], DIM[3]) end)
            del:ClearAllPoints()
            del:SetPoint("RIGHT", line, "RIGHT", -6, 0)
            del:SetSize(20, 20)
        end
        -- edit: into the binder (left of the game's delete)
        local edit = CreateFrame("Button", nil, line)
        d.edit = edit
        edit:SetSize(20, 20)
        edit:SetPoint("RIGHT", line, "RIGHT", -30, 0)
        local eg = R.Glyph(edit, "edit", 11)
        eg:SetVertexColor(DIM[1], DIM[2], DIM[3])
        edit:SetScript("OnEnter", function(self)
            eg:SetVertexColor(1, 1, 1)
            ns.Tip(self, ns.window.Outside, { title = "Edit", color = GOLD,
                { "body", "Into the binder: click its pad with the new click." } })
        end)
        edit:SetScript("OnLeave", function()
            eg:SetVertexColor(DIM[1], DIM[2], DIM[3])
            GameTooltip:Hide()
            cc.Line(line)
        end)
        edit:SetScript("OnClick", function()
            cc.Load(line.GetElementData and line:GetElementData(), line)
        end)
        edit:Hide()
        line:HookScript("OnEnter", function()
            d.hot = true
            cc.Line(line)
        end)
        line:HookScript("OnLeave", function()
            d.hot = false
            cc.Line(line)
        end)
        if line.Init then hooksecurefunc(line, "Init", function() cc.Line(line) end) end
    end
    d.data = line.GetElementData and line:GetElementData() or nil
    local new = d.data and d.data.elementType == NEW_SLOT
    local icon = line.Icon
    local atlas = icon and icon.GetAtlas and icon:GetAtlas()
    if icon then icon:SetAlpha(0) end
    local empty = new and not (d.data and d.data.bindingInfo)
    if icon and not atlas and not empty then
        d.icon:SetTexture(icon:GetTexture())
        d.icon:SetDesaturated(icon.IsDesaturated and icon:IsDesaturated() or false)
        d.icon:Show()
    else
        d.icon:Hide()
    end
    d.plus:SetShown(empty)
    d.slot:SetShown(new and true or false)
    -- the binding in the binder: lit as under the mouse
    local held = d.data ~= nil and d.data == cc.target
    d.row:SetShown((d.hot or held) and not new or false)
    local over = d.edit.IsMouseOver and d.edit:IsMouseOver()
    d.edit:SetShown(((d.hot or over) and not new and d.data and d.data.bindingInfo) and true or false)
    local rim = (d.hot or held) and GOLD or GOLD_D
    deco[line].rim:SetVertexColor(rim[1], rim[2], rim[3], 1)
    if line.Name then
        R.Font(line.Name, 14, ns.colors.text)
        line.Name:ClearAllPoints()
        line.Name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, 2)
        line.Name:SetPoint("RIGHT", line, "RIGHT", -30, 0)
    end
    if line.BindingText then
        R.Font(line.BindingText, 13)
        line.BindingText:ClearAllPoints()
        line.BindingText:SetPoint("TOPLEFT", line.Name, "BOTTOMLEFT", 0, -5)
        line.BindingText:SetPoint("RIGHT", line, "RIGHT", -30, 0)
    end
    if empty and line.Name then
        -- the waiting slot: its prompt alone, level with the +
        line.Name:SetText("")
        line.BindingText:ClearAllPoints()
        line.BindingText:SetPoint("LEFT", d.icon, "RIGHT", 10, 0)
    end
    Caps(line, d)
end
cc.Line = Line

local function Element(frame)
    if not frame then return end
    if frame.BindingText then Line(frame) elseif frame.Name then Heading(frame) end
end

local function List(f)
    if f.ScrollBoxBackground then f.ScrollBoxBackground:SetAlpha(0) end
    local box = f.ScrollBox
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, LIST)
        box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 16, FOOT + BINDER + 16)
        if box.ForEachFrame then box:ForEachFrame(Element) end
    end
    local bar = f.ScrollBar
    if bar and box then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
    end
end

-- ------------------------------------------------------------- the binder
-- Over the foot: what to do next, and a pad that takes the click. A binding
-- loads into it (a spell clicked in the book, the slot filled, a line's
-- edit glyph); a click on the pad is the click on that binding's line, the
-- game's own (its modifiers read as it reads them, a clash unbound, the
-- list sorted, Save marked).
--
--   BINDER ---------------------------------------------------
--   (1) Pick a spell - (2) Click the pad - (3) Save
--   (o) Healing Wave   [ (mouse) Click here with the click you want    ]
--       Rank 4         [         hold Shift, Ctrl or Alt as you click  ]
--   Or click its line in the list.
local STEPS = { "Pick a spell", "Click the pad", "Save" }
local HELP = { "Click a spell in the spellbook: the ones that glow can be bound.",
    "Click the pad here with the mouse button and keys you want.", "Save." }
local GREEN = { 0.45, 0.85, 0.40 }
local binder
local loaded            -- the target's click when it loaded, and its look

local function Alive(f, data)
    local dp = f and f.dataProvider
    if not data or not dp or not dp.ForEach then return false end
    local found = false
    dp:ForEach(function(e) if e == data then found = true end end)
    return found
end

local function Plain(s) return s and (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- A binding's name, icon (a texture or an atlas) and what it is
local function Describe(data, line)
    local info = data.bindingInfo
    local id = info.actionID
    local name, icon, atlas, sub
    if info.type == TYPE.Spell or info.type == TYPE.PetAction then
        name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
        if (not sub or sub == "") and info.type == TYPE.PetAction then sub = "Pet" end
    elseif info.type == TYPE.Macro then
        if _G.GetMacroInfo then name, icon = _G.GetMacroInfo(id) end
        sub = "Macro"
    elseif info.type == TYPE.Interaction then
        sub = "Default"
    end
    if not name and line then
        name = Plain(line.Name and line.Name:GetText())
        local ic = line.Icon
        atlas = ic and ic.GetAtlas and ic:GetAtlas()
        icon = not atlas and ic and ic:GetTexture() or nil
    end
    return name or "", icon, atlas, sub or ""
end

-- Where the binder is: 1 nothing loaded, 2 waiting for its click, 3 a new
-- click set and not yet saved
function cc.Step()
    local t = cc.target
    if not (t and t.bindingInfo) then return 1 end
    return cc.set and 3 or 2
end

local function Dashes(pad, lit)
    local d = deco[pad]
    local w, h = pad:GetWidth() or 0, pad:GetHeight() or 0
    local n = 0
    local function Dash(x, y, dw, dh)
        n = n + 1
        local t = d.dashes[n]
        if not t then
            t = pad:CreateTexture(nil, "BORDER")
            d.dashes[n] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", pad, "TOPLEFT", x, -y)
        t:SetSize(dw, dh)
        t:Show()
    end
    for x = 0, w - 3, 6 do
        Dash(x, 0, 3, 1)
        Dash(x, h - 1, 3, 1)
    end
    for y = 0, h - 3, 6 do
        Dash(0, y, 1, 3)
        Dash(w - 1, y, 1, 3)
    end
    for i = n + 1, #d.dashes do d.dashes[i]:Hide() end
    local c = lit and GOLD or GOLD_D
    for i = 1, n do d.dashes[i]:SetColorTexture(c[1], c[2], c[3], 1) end
end

local shown           -- the step last painted
local function Paint()
    local b = binder
    local f = Frame()
    if not b or not f then return end
    local step = cc.Step()
    -- the spellbook's halo follows the step (spells/spellbook.lua)
    if step ~= shown then
        shown = step
        if cc.Stepped then cc.Stepped(step) end
    end
    local t = cc.target
    local idle = step == 1
    for _, fs in ipairs(b.help) do fs:SetShown(idle) end
    for i, s in ipairs(b.steps) do
        s.ring:SetShown(not idle)
        s.well:SetShown(not idle)
        s.num:SetShown(not idle)
        s.word:SetShown(not idle)
        if s.dash then s.dash:SetShown(not idle) end
        local c = i == step and GOLD or i < step and ns.colors.text or DIM
        s.ring:SetVertexColor((i == step and GOLD or GOLD_D)[1], (i == step and GOLD or GOLD_D)[2],
            (i == step and GOLD or GOLD_D)[3], 1)
        s.num:SetTextColor(c[1], c[2], c[3])
        s.word:SetTextColor(c[1], c[2], c[3])
    end
    b.spell:SetShown(not idle)
    b.pad:SetShown(not idle)
    b.pad:EnableMouse(not idle)
    b.cancel:SetShown(not idle)
    if idle then
        b.hint:SetText("")
        return
    end
    b.name:SetText(loaded.name)
    b.sub:SetText(loaded.sub)
    if loaded.atlas then
        b.icon:SetAtlas(loaded.atlas)
    else
        b.icon:SetTexture(loaded.icon)
    end
    -- the pad: its click once set (keycaps), else what to do
    local hot = b.pad.hot
    local keys = step == 3 and cc.Keys(t.bindingInfo)
    local word = hot and { 1, 1, 1 } or GOLD
    b.line1:SetTextColor(word[1], word[2], word[3])
    b.line1:SetText(keys and "" or "Click here with the click you want")
    b.line2:SetText(keys and "Click again to change it" or "hold Shift, Ctrl or Alt as you click")
    local x = 0
    local pd = deco[b.pad]
    for i = 1, math.max(#(keys or {}), #pd.caps) do
        local key = keys and keys[i]
        if key then
            local k = Cap(b.pad, pd, i)
            k.word:SetText(key)
            local w = (k.word:GetStringWidth() or 0) + 12
            k:SetWidth(w)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", b.pad, "TOPLEFT", 38 + x, -5)
            R.Edge(deco[k], GOLD)
            k.word:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            k:Show()
            x = x + w
            k.plus:SetShown(keys[i + 1] ~= nil)
            if keys[i + 1] then
                k.plus:ClearAllPoints()
                k.plus:SetPoint("LEFT", k, "RIGHT", 3, 0)
                x = x + 14
            end
        elseif pd.caps[i] then
            pd.caps[i]:Hide()
            pd.caps[i].plus:Hide()
        end
    end
    Dashes(b.pad, hot)
    if step == 3 then
        b.hint:SetText("Save to keep it.")
        b.hint:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    else
        b.hint:SetText("Or click its line in the list.")
        b.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
    end
end

-- The binder again, as the game changes its list: the target gone (deleted,
-- the list read afresh), its click changed (here or on its line), saved
function cc.Binder()
    local f = Frame()
    local t = cc.target
    if t and not (Alive(f, t) and t.bindingInfo) then t = nil end
    if t and loaded then
        local info = t.bindingInfo
        if info.button ~= loaded.button or (info.modifiers or 0) ~= loaded.modifiers then cc.set = true end
    end
    -- set, then saved (or the changes dropped): done
    if t and cc.set and not (f and f.pendingChanges) then t = nil end
    if not t then
        cc.set, loaded = false, nil
    end
    local was = cc.target
    cc.target = t
    Paint()
    if was ~= t and f and f.ScrollBox and f.ScrollBox.ForEachFrame then f.ScrollBox:ForEachFrame(Element) end
end

-- A binding into the binder: the slot filled, a spell clicked in the book,
-- a line's edit glyph
function cc.Load(data, line)
    local f = Frame()
    if not (data and data.bindingInfo and Alive(f, data)) then return end
    if not line and f.ScrollBox and f.ScrollBox.FindFrame then line = f.ScrollBox:FindFrame(data) end
    local name, icon, atlas, sub = Describe(data, line)
    loaded = { button = data.bindingInfo.button, modifiers = data.bindingInfo.modifiers or 0,
        name = name, icon = icon, atlas = atlas, sub = sub }
    cc.set = false
    cc.target = data
    Paint()
    if f.ScrollBox and f.ScrollBox.ForEachFrame then f.ScrollBox:ForEachFrame(Element) end
end

-- The binding loaded whose spell is one of ids (or of that name): the
-- spellbook's click on a spell already bound
function cc.Find(ids, name)
    local f = Frame()
    local dp = f and f.dataProvider
    if not dp or not dp.ForEach then return nil end
    local found
    dp:ForEach(function(e)
        local info = e.bindingInfo
        if found or not info or not (info.type == TYPE.Spell or info.type == TYPE.PetAction) then return end
        local n = name and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(info.actionID)
        if ids[info.actionID] or (n and n == name) then found = e end
    end)
    return found
end

-- The pad's click: the click on the target's line
local function Press(_, button)
    local f = Frame()
    local t = cc.target
    if not (f and t and Alive(f, t)) then return end
    local box = f.ScrollBox
    -- (elementData, alignment, offset, noInterpolation); a client without
    -- offset reads the 0 as noInterpolation, truthy all the same
    if box.ScrollToElementData then box:ScrollToElementData(t, nil, 0, true) end
    local line = box.FindFrame and box:FindFrame(t)
    local click = line and line:GetScript("OnClick")
    if click then click(line, button) end
    cc.Binder()
end

local function Binder(f)
    if binder then return binder end
    local b = CreateFrame("Frame", nil, f)
    binder = b
    cc.binder = b
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOT)
    b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOT)
    b:SetHeight(BINDER)
    -- its rule over it, the window's width
    b.rule = b:CreateTexture(nil, "ARTWORK")
    b.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    b.rule:SetHeight(1)
    b.rule:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, FOOT + BINDER + 8)
    b.rule:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -1, FOOT + BINDER + 8)
    b.title = ns.Text(b, 13)
    R.Font(b.title, 13, GOLD)
    b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.title:SetText("Binder")
    b.fade = b:CreateTexture(nil, "ARTWORK")
    b.fade:SetHeight(1)
    b.fade:SetPoint("LEFT", b.title, "RIGHT", 10, 0)
    b.fade:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    R.Fade(b.fade, GOLD_D, 1)
    -- nothing loaded: what to do
    b.help = {}
    local intro = ns.Text(b, 13)
    intro:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -24)
    intro:SetText("Bind a spell to a click on unit frames:")
    table.insert(b.help, intro)
    for i, s in ipairs(HELP) do
        local fs = ns.Text(b, 12)
        fs:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -26 - i * 18)
        fs:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(i .. ".  " .. s)
        fs:SetTextColor(DIM[1], DIM[2], DIM[3])
        table.insert(b.help, fs)
    end
    local drag = ns.Text(b, 12)
    drag:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -26 - 4 * 18 - 4)
    drag:SetText("Or drag a spell or macro into the list.")
    drag:SetTextColor(DIM[1], DIM[2], DIM[3])
    table.insert(b.help, drag)
    -- the steps: ringed numerals, their words, dashes between
    b.steps = {}
    local prev
    for i, s in ipairs(STEPS) do
        local st = {}
        st.ring = b:CreateTexture(nil, "ARTWORK")
        st.ring:SetTexture(ROUND)
        st.ring:SetSize(18, 18)
        if prev then
            st.dash = b:CreateTexture(nil, "ARTWORK")
            st.dash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            st.dash:SetSize(8, 1)
            st.dash:SetPoint("LEFT", prev.word, "RIGHT", 6, 0)
            st.ring:SetPoint("LEFT", st.dash, "RIGHT", 6, 0)
        else
            st.ring:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -24)
        end
        st.well = b:CreateTexture(nil, "ARTWORK", nil, 1)
        st.well:SetTexture(ROUND)
        st.well:SetPoint("TOPLEFT", st.ring, "TOPLEFT", 1.5, -1.5)
        st.well:SetPoint("BOTTOMRIGHT", st.ring, "BOTTOMRIGHT", -1.5, 1.5)
        st.well:SetVertexColor(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
        st.num = ns.Text(b, 11)
        st.num:SetPoint("CENTER", st.ring, "CENTER", 0, 0)
        st.num:SetText(tostring(i))
        st.word = ns.Text(b, 13)
        st.word:SetPoint("LEFT", st.ring, "RIGHT", 6, 0)
        st.word:SetText(s)
        b.steps[i] = st
        prev = st
    end
    -- the binding loaded: its medallion, name and what it is
    b.spell = CreateFrame("Frame", nil, b)
    b.spell:SetSize(32, 32)
    b.spell:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -52)
    b.icon = b.spell:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    R.Medal(b.spell, b.icon, 2.5)
    deco[b.spell].rim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    b.name = ns.Text(b.spell, 14)
    b.name:SetPoint("TOPLEFT", b.spell, "TOPRIGHT", 8, -1)
    b.name:SetWidth(84)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = ns.Text(b.spell, 12)
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
    b.sub:SetWidth(84)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b.sub:SetTextColor(DIM[1], DIM[2], DIM[3])
    -- the pad
    local pad = CreateFrame("Button", nil, b)
    b.pad = pad
    pad:SetPoint("TOPLEFT", b, "TOPLEFT", 134, -48)
    pad:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -48)
    pad:SetHeight(42)
    pad:RegisterForClicks("AnyUp")
    local pd = deco[pad] or {}
    deco[pad] = pd
    pd.dashes, pd.caps = {}, {}
    pd.wash = pad:CreateTexture(nil, "BACKGROUND")
    pd.wash:SetAllPoints()
    pd.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14)
    pd.glyph = pad:CreateTexture(nil, "ARTWORK")
    pd.glyph:SetTexture(GLYPHS .. "mouse")
    pd.glyph:SetSize(18, 18)
    pd.glyph:SetPoint("LEFT", pad, "LEFT", 11, 0)
    pd.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    b.line1 = ns.Text(pad, 13)
    b.line1:SetPoint("TOPLEFT", pad, "TOPLEFT", 38, -7)
    b.line2 = ns.Text(pad, 12)
    b.line2:SetPoint("TOPLEFT", pad, "TOPLEFT", 38, -24)
    b.line2:SetTextColor(DIM[1], DIM[2], DIM[3])
    pad:SetScript("OnClick", Press)
    pad:SetScript("OnEnter", function(self)
        self.hot = true
        Paint()
    end)
    pad:SetScript("OnLeave", function(self)
        self.hot = false
        Paint()
    end)
    pad:SetScript("OnSizeChanged", function() Paint() end)
    -- under it: the next thing to know, and the binding dropped
    b.hint = ns.Text(b, 12)
    b.hint:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 8)
    local cancel = CreateFrame("Button", nil, b)
    b.cancel = cancel
    cancel:SetSize(20, 20)
    cancel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 4)
    local g = R.Glyph(cancel, "close", 10)
    g:SetVertexColor(DIM[1], DIM[2], DIM[3])
    cancel:SetScript("OnEnter", function(self)
        g:SetVertexColor(1, 1, 1)
        ns.Tip(self, ns.window.Outside, { title = "Put it down", color = GOLD,
            { "body", "Leaves the binder empty; the list keeps what you set." } })
    end)
    cancel:SetScript("OnLeave", function()
        g:SetVertexColor(DIM[1], DIM[2], DIM[3])
        GameTooltip:Hide()
    end)
    cancel:SetScript("OnClick", function()
        local was = cc.target
        cc.target, cc.set, loaded = nil, false, nil
        Paint()
        local fr = Frame()
        if was and fr and fr.ScrollBox and fr.ScrollBox.ForEachFrame then fr.ScrollBox:ForEachFrame(Element) end
    end)
    Paint()
    return b
end

-- ------------------------------------------------------------- the dressing
local function Dress()
    local f = Frame()
    if not f or not ns.db.ccWindow then return end
    Top(f)
    List(f)
    Foot(f)
    Binder(f)
    cc.Binder()
end
cc.Dress = Dress

local adopted = false
local function Adopt()
    local f = Frame()
    if adopted or not f then return end
    adopted = true
    skin = R.Chrome(f, "Click Casting", { { "TOP", TOP }, { "BOTTOM", ROW } }, HEAD + 4)
    cc.frame = f
    cc.skin = skin
    Dress()
    -- each binding as the list gives it out (and as the game fills it again)
    local box = f.ScrollBox
    if box and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        ScrollUtil.AddAcquiredFrameCallback(box, function(_, frame) Element(frame) end, cc, true)
    end
    -- what there is to save, and the binder, as the game changes its list
    local function Changed()
        cc.Pending()
        cc.Binder()
    end
    for _, method in ipairs({ "AddNewAction", "Refresh", "ResetToDefaultProfile", "SetHasNewSlot",
        "CleanDataProvider", "ClearUnboundText", "SetUnboundText" }) do
        if f[method] then hooksecurefunc(f, method, Changed) end
    end
    -- the slot filled (a spell clicked in the book, one dropped on it): into
    -- the binder
    if f.FillNewSlot then
        hooksecurefunc(f, "FillNewSlot", function(self)
            cc.Pending()
            if self.GetLastElement then cc.Load(self:GetLastElement()) end
        end)
    end
    f:HookScript("OnHide", function()
        cc.target, cc.set = nil, false
        cc.Binder()
    end)
    if f.UpdateMouseoverCastUI then hooksecurefunc(f, "UpdateMouseoverCastUI", Place) end
    Place()
    R.Hold(f, Place)
    R.Stand(f, "cc", function()
        Place()
        Dress()
    end)
end
cc.Adopt = Adopt

local function Start()
    if not ns.db.ccWindow then return end
    if Frame() then Adopt() end
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name)
            if name == "Blizzard_ClickBindingUI" then Adopt() end
        end)
    end
end

ns.On("PLAYER_LOGIN", Start)
