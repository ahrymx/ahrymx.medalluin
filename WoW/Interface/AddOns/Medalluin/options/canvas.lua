-- The unit-frame editor's edit mode (art/settings/gen_canvas.py): a window
-- beside the editor, opened by its Edit mode button. Down its left a tree
-- of the frames, the chosen one open on its pieces; the rest is the canvas,
-- the chosen frame drawn large as its buttons have it now, the chosen piece
-- boxed. Drag the box to move the piece, the arrow keys nudge it;
-- the frames on screen follow, as they follow the editor's controls.
--
-- What the canvas draws is a copy, read off a real button after every
-- change (each region's points, size, font and words), so it can never
-- disagree with the frame it shows. A mirrored frame shows a left copy over
-- a right one. A frame with no button laid out now (the party in the
-- layout it is not using) says so instead.
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors
local E = ns.editor

local W, H = 600, 360
local PAD, TREE_W, ROW_H = 12, 170, 19
local MAX_SCALE, GAP = 3, 30

local window, stage, holder, tree
local proxies = {}        -- the copies, in use and spare
local boxes = {}          -- a box per piece per copy, in use and spare
local Draw

-- What a copy says where its button's words are secret or not yet set.
local SAMPLE = {
    unit = { "Player", "Target" }, party = { "Party member" }, partyWidget = { "Party member" },
    raid = { "Raider" }, boss = { "Boss" }, arena = { "Enemy" },
}
local SAMPLE_TEXT = { level = "60", value = "100%", powerValue = "60 | 60%" }

-- ------------------------------------------------------------ a copy
local TEXTS = { name = "text", level = "text", value = "text", powerValue = "powerBox" }

local function Icon(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetFrameLevel(p:GetFrameLevel() + 6)
    f.fill = UI.Fill(f, "ARTWORK", C.well)
    f.fill:SetAllPoints()
    UI.Outline(f, "OVERLAY", C.gold, 0)
    return f
end

local function Proxy(i)
    local p = proxies[i]
    if p then return p end
    p = CreateFrame("Frame", nil, holder)
    p.bg = UI.Fill(p, "BACKGROUND", C.ink)
    p.bg:SetAllPoints()
    UI.Outline(p, "OVERLAY", C.goldDark, -1)
    p.health = CreateFrame("Frame", nil, p)
    p.health.fill = UI.Fill(p.health, "ARTWORK", C.ink)
    p.health.fill:SetAllPoints()
    p.power = CreateFrame("Frame", nil, p)
    p.power.fill = UI.Fill(p.power, "ARTWORK", C.ink)
    p.power.fill:SetAllPoints()
    p.text = CreateFrame("Frame", nil, p)
    p.text:SetFrameLevel(p:GetFrameLevel() + 4)
    p.powerBox = CreateFrame("Frame", nil, p)
    p.powerBox:SetFrameLevel(p:GetFrameLevel() + 4)
    p.pieces = {}
    proxies[i] = p
    return p
end

-- The copy's region for a piece (made the first time), shaped like the
-- real one: a text, an icon, or a row of as many icons.
local function ProxyPiece(p, id, real)
    local kind = E.PIECES[id].type
    local have = p.pieces[id]
    if kind == "text" then
        if not have then
            have = UI.Plain(p[TEXTS[id]], 12, C.text)
            p.pieces[id] = have
        end
    elseif kind == "icon" then
        have = have or Icon(p)
        p.pieces[id] = have
    elseif kind == "row" then
        have = have or {}
        for k = 1, #real do have[k] = have[k] or Icon(p) end
        for k = #real + 1, #have do have[k]:Hide() end
        p.pieces[id] = have
    end
    return have
end

-- A number the game lets Lua read: not secret (a text's size is secret
-- while its words are, and so is any point on it), else nil.
local function Plain(v)
    if type(v) == "number" and not ns.IsSecret(v) then return v end
end

-- The real region's points onto the copy's. A point the game keeps secret
-- (on a text of secret size) cannot be read: the copy hangs where its own
-- other points put it, or in the middle of the copy.
local function CopyPoints(src, dst, map, p)
    dst:ClearAllPoints()
    local set = 0
    for i = 1, (src:GetNumPoints() or 0) do
        local point, rel, relPoint, x, y = src:GetPoint(i)
        if type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(relPoint)
            and (x == nil or Plain(x)) and (y == nil or Plain(y)) then
            dst:SetPoint(point, map[rel] or p, relPoint or point, x or 0, y or 0)
            set = set + 1
        end
    end
    if set == 0 then dst:SetPoint("CENTER", p, "CENTER", 0, 0) end
end

local function Colour(bar, fallback)
    local r, g, b
    if bar and bar.GetStatusBarColor then r, g, b = bar:GetStatusBarColor() end
    if type(r) ~= "number" or ns.IsSecret(r) then return fallback end
    return { r, g, b }
end

-- Copy real button b onto p, as frame has it, the copy's words from slot
-- k's sample where the button's are not plain.
local function Mirror(frame, b, p, k)
    p:SetSize(Plain(b:GetWidth()) or 0, Plain(b:GetHeight()) or 0)
    local map = { [b] = p, [b.health] = p.health, [b.power] = p.power }
    if b.text then map[b.text] = p.text end
    if b.powerValue then map[b.powerValue:GetParent()] = p.powerBox end
    -- the regions the pieces sit on, then the pieces
    local pairs_ = { { b.health, p.health }, { b.power, p.power } }
    for _, id in ipairs(frame.pieces) do
        local spec = E.PIECES[id]
        local real = spec.get and spec.get(b)
        if real then
            local mine = ProxyPiece(p, id, real)
            if spec.type == "row" then
                for i, r in ipairs(real) do
                    map[r] = mine[i]
                    table.insert(pairs_, { r, mine[i], id })
                end
            else
                map[real] = mine
                table.insert(pairs_, { real, mine, id })
            end
        end
    end
    if b.text then table.insert(pairs_, 3, { b.text, p.text }) end
    if b.powerValue then table.insert(pairs_, 3, { b.powerValue:GetParent(), p.powerBox }) end
    for _, pr in ipairs(pairs_) do
        local src, dst = pr[1], pr[2]
        CopyPoints(src, dst, map, p)
        local id = pr[3]
        if id and E.PIECES[id].type == "text" then
            local face, size, flags = src:GetFont()
            if face then dst:SetFont(face, size, flags) end
            local words = src:GetText()
            -- (a secret string may not even be compared: ask first)
            if ns.IsSecret(words) or words == nil or words == "" then
                words = id == "name" and (SAMPLE[frame.id][k] or SAMPLE[frame.id][1]) or SAMPLE_TEXT[id]
            end
            dst:SetText(words)
            if src.GetJustifyH then dst:SetJustifyH(src:GetJustifyH()) end
            -- one line, as the button's: a copy free to wrap measures itself
            -- two lines tall, and anything hung from its edge moves with it
            if src.CanWordWrap then dst:SetWordWrap(src:CanWordWrap() and true or false) end
            dst:SetHeight(Plain(src:GetHeight()) or 0)
            -- a text held by one point is as wide as its own words, or as
            -- the editor set it
            -- (a secret width is the words' own: the copy's sample sizes itself)
            if (src:GetNumPoints() or 0) < 2 then dst:SetWidth(Plain(src:GetWidth()) or 0) end
        else
            dst:SetSize(Plain(src:GetWidth()) or 0, Plain(src:GetHeight()) or 0)
        end
        if id then
            dst:SetAlpha(E.Shown(frame, id) and 1 or 0.25)
            dst:Show()
        end
    end
    -- a row as long as its Max: the rest of its icons wait unseen
    for _, id in ipairs(frame.pieces) do
        local row = E.PIECES[id].type == "row" and p.pieces[id]
        if row then
            local n = ns.RowMax(b, id)
            for j, r in ipairs(row) do if j > n then r:Hide() end end
        end
    end
    local hc = Colour(b.health, { 0.25, 0.5, 0.25 })
    p.health.fill:SetColorTexture(hc[1] * 0.7, hc[2] * 0.7, hc[3] * 0.7, 1)
    local pc = Colour(b.power, { 0, 0.35, 0.75 })
    p.power.fill:SetColorTexture(pc[1], pc[2], pc[3], 1)
    -- the pieces this frame has not (a copy made for another frame)
    for id, mine in pairs(p.pieces) do
        local used = false
        for _, have in ipairs(frame.pieces) do if have == id then used = true end end
        if not used then
            if mine.Hide then mine:Hide() else for _, r in ipairs(mine) do r:Hide() end end
        end
    end
    p.button, p.side = b, E.Side(b, frame)
    p:Show()
end

-- The buttons to copy: a left one and its mirror for a mirrored frame,
-- else the first.
local function Models(frame)
    local all = frame.buttons()
    if not all[1] then return {} end
    local left, right
    for _, b in ipairs(all) do
        local side = E.Side(b, frame)
        if side == -1 and not left then left = b end
        if side == 1 and not right then right = b end
    end
    if left and right then return { left, right } end
    return { all[1] }
end

-- ------------------------------------------------------------ boxes
local function Box(i)
    local o = boxes[i]
    if o then return o end
    o = CreateFrame("Button", nil, holder)
    o.edge = UI.Outline(o, "OVERLAY", C.goldBright, 0)
    o.fill = UI.Fill(o, "BACKGROUND", C.gold)
    o.fill:SetAllPoints()
    o.fill:SetAlpha(0.25)
    o.label = UI.Plain(o, 9, C.goldBright)
    o.label:SetPoint("BOTTOMLEFT", o, "TOPLEFT", 0, 1)
    o:RegisterForClicks("AnyUp")
    o:SetScript("OnMouseDown", function(self)
        local x, y = GetCursorPosition()
        self.from = { x = x, y = y, px = E.ui.PlaceField("x") or 0, py = E.ui.PlaceField("y") or 0,
            scale = self:GetEffectiveScale() }
    end)
    o:SetScript("OnMouseUp", function(self) self.from = nil end)
    o:SetScript("OnUpdate", function(self)
        local from = self.from
        if not from then return end
        local x, y = GetCursorPosition()
        -- the canvas is drawn larger: a pixel of the frame is scale of the screen's
        local dx = math.floor((x - from.x) / from.scale + 0.5)
        local dy = math.floor((y - from.y) / from.scale + 0.5)
        -- inward is away from this copy's outer end
        local nx, ny = from.px - self.side * dx, from.py + dy
        if nx ~= E.ui.PlaceField("x") or ny ~= E.ui.PlaceField("y") then E.ui.SetPlace({ x = nx, y = ny }) end
    end)
    o:SetScript("OnEnter", function(self)
        UI.Tip(self, E.PIECES[self.piece].label, "Drag to move it; the arrow keys nudge the chosen piece.")
    end)
    o:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    boxes[i] = o
    return o
end

-- A row of icons from its leftmost to its rightmost.
local function Ends(regions)
    local first, last = regions[1], regions[#regions]
    local a, b = Plain(first:GetLeft()), Plain(last:GetLeft())
    if a and b and b < a then first, last = last, first end
    return first, last
end

-- ------------------------------------------------------------ the tree
-- The frames, the chosen one open on its pieces.
local function Entries()
    local frame = E.ui.Chosen()
    local list = {}
    for _, f in ipairs(E.FRAMES) do
        table.insert(list, { frame = f })
        if f == frame then
            for _, id in ipairs(f.pieces) do table.insert(list, { frame = f, piece = id }) end
        end
    end
    return list
end

local function TreeRow(i)
    local row = tree.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, tree)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 4, -6 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", -4, -6 - (i - 1) * ROW_H)
    row.lit = UI.Fill(row, "BACKGROUND", C.selected)
    row.lit:SetAllPoints()
    row.text = UI.Serif(row, 12, C.text)
    row.mark = UI.Fill(row, "ARTWORK", C.gold)
    row.mark:SetSize(4, 4)
    row.mark:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function(self)
        local _, piece = E.ui.Chosen()
        E.ui.Choose(self.frame.id, self.piece or piece)
    end)
    tree.rows[i] = row
    return row
end

local function DrawTree()
    local frame, piece = E.ui.Chosen()
    local list = Entries()
    for i, entry in ipairs(list) do
        local row = TreeRow(i)
        row.frame, row.piece = entry.frame, entry.piece
        row.text:ClearAllPoints()
        if entry.piece then
            row.text:SetPoint("LEFT", 22, 0)
            row.text:SetText(E.PIECES[entry.piece].label)
            local on = entry.piece == piece
            local c = on and C.goldBright or C.text
            row.text:SetTextColor(c[1], c[2], c[3])
            row.lit:SetShown(on)
            row.mark:SetShown(E.Edits(entry.frame, entry.piece) ~= nil)
        else
            local open = entry.frame == frame
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetText((open and "- " or "+ ") .. entry.frame.name)
            local c = open and C.goldBright or C.dim
            row.text:SetTextColor(c[1], c[2], c[3])
            row.lit:Hide()
            row.mark:SetShown(type(ns.db[entry.frame.key]) == "table")
        end
        row:Show()
    end
    for i = #list + 1, #tree.rows do tree.rows[i]:Hide() end
end

-- ------------------------------------------------------------ the canvas
-- Why a frame has nothing to draw.
local function Absent(frame)
    local widget = ns.PartyWidgetLayout and ns.PartyWidgetLayout()
    if frame.id == "partyWidget" and not widget then
        return "The party layout is Console: the party widget is not laid out now."
    elseif frame.id == "party" and widget then
        return "The party layout is Widget: the console's party is not laid out now."
    end
    return "Nothing to draw yet: Preview in the editor makes the frames."
end

function Draw()
    if not window or not window:IsShown() then return end
    local frame, piece = E.ui.Chosen()
    DrawTree()
    stage.title:SetText(frame.name .. "  >  " .. E.PIECES[piece].label)
    local models = Models(frame)
    stage.note:SetShown(#models == 0)
    if #models == 0 then stage.note:SetText(Absent(frame)) end
    -- the copies, one over the other, at the largest size that fits: sized
    -- and placed from their buttons before anything is copied
    local width, height = 0, 0
    for _, b in ipairs(models) do
        width = math.max(width, Plain(b:GetWidth()) or 0)
        height = height + GAP + (Plain(b:GetHeight()) or 0)
    end
    for k = 1, #models do Proxy(k) end
    for k = #models + 1, #proxies do proxies[k]:Hide() end
    -- the stage's room, less its title, its hint and a margin
    local roomW, roomH = W - 2 * PAD - TREE_W - 10 - 40, H - 3 * PAD - 20 - 56
    local scale = MAX_SCALE
    if width > 0 then scale = math.min(scale, roomW / width) end
    if height > 0 then scale = math.min(scale, roomH / height) end
    holder:SetScale(scale)
    holder:SetSize(math.max(width, 1), math.max(height, 1))
    local y = 0
    for k = 1, #models do
        local p = proxies[k]
        y = y + GAP
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
        y = y + (Plain(models[k]:GetHeight()) or 0)
    end
    for k, b in ipairs(models) do Mirror(frame, b, proxies[k], k) end
    -- a box round the chosen piece on each copy (the others are chosen in
    -- the tree: their boxes only stood over the frame)
    local n = 0
    local kind = E.PIECES[piece].type
    for k = 1, #models do
        local p = proxies[k]
        local mine = kind ~= "cell" and p.pieces[piece]
        local regions = {}
        for _, r in ipairs(kind == "row" and mine or { mine or nil }) do
            if r:IsShown() then table.insert(regions, r) end
        end
        if regions[1] then
            n = n + 1
            local o = Box(n)
            o.piece, o.side, o.copy = piece, p.side, k
            o:SetFrameLevel(p:GetFrameLevel() + 10)
            o:ClearAllPoints()
            local first, last = Ends(regions)
            o:SetPoint("TOPLEFT", first, "TOPLEFT", -1, 1)
            o:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 1, -1)
            o.label:SetText(k == 1 and E.PIECES[piece].label or "")
            o:Show()
        end
    end
    for i = n + 1, #boxes do boxes[i]:Hide(); boxes[i].from = nil end
end

-- ------------------------------------------------------------ the keys
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local function Key(self, key)
    local frame, piece = E.ui.Chosen()
    local step = ARROWS[key]
    local move = step and E.PIECES[piece].type ~= "cell"
    -- the other keys go on to the game (not in combat: the game forbids it)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not move) end
    if not move then return end
    local b = frame.buttons()[1]
    local side = E.ui.Mirrored() and b and E.Side(b, frame) or -1
    E.ui.SetPlace({ x = (E.ui.PlaceField("x") or 0) - side * step[1], y = (E.ui.PlaceField("y") or 0) + step[2] })
end

-- The keys are the canvas's only out of combat: a fight hands them all back
-- (in it the game would not let them be passed on).
local function Keys(on)
    if not window then return end
    window:EnableKeyboard(on)
    if on and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end
ns.On("PLAYER_REGEN_DISABLED", function() Keys(false) end)
ns.On("PLAYER_REGEN_ENABLED", function() if window and window:IsShown() then Keys(true) end end)

-- ------------------------------------------------------------ the window
local function Remember()
    local point, _, relative, x, y = window:GetPoint()
    ns.SetOption("editCanvasPoint", { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) })
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
    window = CreateFrame("Frame", "MedalluinEditCanvas", UIParent)
    ns.editCanvas = window
    window:SetSize(W, H)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    Grip(window)
    UI.Skin(window, C.panel)
    window:Hide()
    window:SetScript("OnShow", function()
        Keys(true)
        Draw()
        E.ui.Refresh()
    end)
    window:SetScript("OnHide", function()
        Keys(false)
        for _, o in ipairs(boxes) do o.from = nil end
        E.ui.Refresh()
    end)
    window:SetScript("OnKeyDown", Key)

    local title = CreateFrame("Frame", nil, window)
    title:SetHeight(28)
    title:SetPoint("CENTER", window, "TOP", 0, 0)
    title:SetFrameLevel(window:GetFrameLevel() + 5)
    UI.Skin(title, C.ink)
    local text = UI.Serif(title, 15, C.goldBright)
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Edit mode")
    title:SetWidth(math.ceil(text:GetStringWidth()) + 44)
    Grip(title)

    local x = CreateFrame("Button", nil, window)
    x:SetSize(20, 20)
    x:SetPoint("TOPRIGHT", -8, -6)
    x.text = UI.Serif(x, 14, C.gold)
    x.text:SetPoint("CENTER", 0, 1)
    x.text:SetText("x")
    x:SetScript("OnClick", function() window:Hide() end)

    tree = CreateFrame("Frame", nil, window)
    tree:SetPoint("TOPLEFT", PAD, -(PAD + 20))
    tree:SetPoint("BOTTOMLEFT", PAD, PAD)
    tree:SetWidth(TREE_W)
    UI.Skin(tree, C.ink)
    tree.rows = {}

    stage = CreateFrame("Frame", nil, window)
    stage:SetPoint("TOPLEFT", tree, "TOPRIGHT", 10, 0)
    stage:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    UI.Skin(stage, C.well)
    -- nothing drawn on the canvas reaches past it
    stage:SetClipsChildren(true)
    stage.title = UI.Serif(stage, 12, C.goldBright)
    stage.title:SetPoint("TOPLEFT", 10, -8)
    stage.hint = UI.Plain(stage, 10, C.dim)
    stage.hint:SetPoint("BOTTOMRIGHT", -10, 8)
    stage.hint:SetText("Drag a box  ·  arrows nudge  ·  the frames on screen follow")
    stage.note = UI.Plain(stage, 12, C.dim)
    stage.note:SetPoint("CENTER", 0, 0)
    stage.note:SetPoint("LEFT", 20, 0)
    stage.note:SetPoint("RIGHT", -20, 0)
    holder = CreateFrame("Frame", nil, stage)
    holder:SetPoint("CENTER", stage, "CENTER", 0, -6)

    -- its parts, by name (the harness reads them)
    window.tree, window.stage, window.holder, window.proxies, window.boxes = tree, stage, holder, proxies, boxes
end

-- ns.ShowEditCanvas(on): the canvas, beside the editor the first time.
function ns.ShowEditCanvas(on)
    if not on then
        if window then window:Hide() end
        return
    end
    Window()
    window:ClearAllPoints()
    local at = ns.db.editCanvasPoint
    local editor = E.ui.Window()
    if at then
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    elseif editor then
        window:SetPoint("TOPLEFT", editor, "TOPRIGHT", 8, 0)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    window:Show()
    window:Raise()
end

-- Whatever the editor or the game changes, the canvas draws again: a new
-- choice, a frame's pieces laid again, an option.
E.onChoose = function() Draw() end
E.onApply = function() Draw() end
ns.OnAnySetting(function() Draw() end)
