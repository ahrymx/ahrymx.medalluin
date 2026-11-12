-- The unit-frame editor's canvas (art/settings/gen_editor.py's U3): the
-- middle of the editor's window (options/editor.lua), the chosen frame drawn
-- large as its buttons have it now, the chosen piece boxed and nothing else.
-- Drag the box to move the piece, the arrow keys nudge it (the editor's
-- window has the keys); the frames on screen follow, as they follow the
-- editor's controls.
--
-- What the canvas draws is a copy, read off a real button after every
-- change (each region's points, size, font and words), so it can never
-- disagree with the frame it shows. An icon shows on the copy as the real
-- one does, or while it is the chosen piece, or while the footer's preview
-- chips show it (E.preview: a dispel type's glow, the aggro glow, crowd
-- control, a boss debuff, your buffs), drawn by the frame's own glow
-- (ns.EdgeGlow) with the preview's icons (ns.STUB_ICONS). A mirrored frame
-- shows a left copy over a right one. A frame with no button laid out now
-- (the party in the layout it is not using) says so instead.
local _, ns = ...

local UI = ns.OptionsUI
local C = UI.colors
local E = ns.editor

local MAX_SCALE, GAP = 3, 30
local CC_TIME = 8           -- the previewed crowd control's sweep, looping

local stage, holder
local settling            -- a second drawing waits for the next frame
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

-- An icon on the copy: no edge of its own (the box is the only one), the
-- real icon's texture or the preview's, a sweep and a timer for a preview.
local function Icon(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetFrameLevel(p:GetFrameLevel() + 6)
    f.fill = UI.Fill(f, "BACKGROUND", C.ink)
    f.fill:SetAllPoints()
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.tex)
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
    f.timer = UI.Plain(f.cd, 11, { 1, 0.9, 0.2 })
    f.timer:SetPoint("CENTER", 0, 0)
    return f
end

-- The player's role, by their spec (or talents, on Forever), else as the
-- group has it, else damage: the role a copy shows while no group gives it.
local function PlayerRole()
    if GetSpecialization and GetSpecializationRole then
        local i = GetSpecialization()
        local role = i and GetSpecializationRole(i)
        if role then return role end
    end
    if GetTalentGroupRole and GetActiveTalentGroup then
        local ok, role = pcall(GetTalentGroupRole, GetActiveTalentGroup())
        if ok and ns.ROLE_COORDS[role] then return role end
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if ns.ROLE_COORDS[role] then return role end
    return "DAMAGER"
end

-- A real icon's texture: its .icon, else its first.
local function RealTexture(real)
    if not real then return nil end
    if real.icon then return real.icon end
    for _, r in ipairs({ real:GetRegions() }) do
        if r.SetTexCoord then return r end
    end
end

-- What an icon on the copy shows: the preview's texture (a sweep with it
-- for crowd control), else its real one's, cut as the real one is (a sheet
-- such as the role icons'). While its button shows none, the role is the
-- player's own and the ready check is ready: a sheet uncut is every icon.
local CROP = { 0.08, 0.92, 0.08, 0.92 }
local function Paint(f, id, real, stub, sweep)
    local t, coords = stub, CROP
    if not t then
        local r = RealTexture(real)
        local idle = not (real and real:IsShown())
        if id == "role" and idle then
            t, coords = ns.media .. "role-icons", ns.ROLE_COORDS[PlayerRole()]
        elseif id == "status" and idle then
            t, coords = ns.media .. "ready-status", ns.CHECK_COORDS.ready
        elseif r then
            t = r:GetTexture()
            if ns.IsSecret(t) then t = nil end
            -- its corners (eight numbers: the game's), or its edges (four)
            local c = { r:GetTexCoord() }
            if #c >= 8 then
                coords = { c[1], c[7], c[2], c[8] }
            elseif #c == 4 then
                coords = c
            else
                coords = { 0, 1, 0, 1 }
            end
        end
    end
    f.tex:SetTexture(t)
    f.tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    f.tex:SetShown(t ~= nil)
    if sweep then
        if not f.sweepAt then
            f.sweepAt = GetTime()
            f.cd:SetCooldown(f.sweepAt, CC_TIME)
        end
        f.cd:Show()
        f.timer:Show()
    else
        f.sweepAt = nil
        f.cd:Hide()
        f.timer:Hide()
    end
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

-- The player's class colour, for a copy whose button has none.
local function ClassColour()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return { 0.25, 0.5, 0.25 }
end

-- Copy real button b onto p, as frame has it, the copy's words from slot
-- k's sample where the button's are not plain.
local function Mirror(frame, b, p, k)
    local _, chosen = E.ui.Chosen()
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
                    table.insert(pairs_, { r, mine[i], id, i })
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
            if E.PIECES[id].type == "text" then
                dst:Show()
            else
                -- an icon as the real one is, else while chosen or previewed
                local stub = E.preview[id] and ns.STUB_ICONS[id]
                if type(stub) == "table" then stub = stub[pr[4]] end
                Paint(dst, id, src, stub, id == "cc" and stub ~= nil)
                dst:SetShown(stub ~= nil or id == chosen or src:IsShown())
            end
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
    -- a button with no unit yet (no group, no preview) was never coloured:
    -- its bars are the game's white, so the copy takes the player's class
    local live = b.stub or (b.unit and UnitExists(b.unit))
    local hc = live and Colour(b.health, nil)
    if not hc or (hc[1] > 0.99 and hc[2] > 0.99 and hc[3] > 0.99) then hc = ClassColour() end
    p.health.fill:SetColorTexture(hc[1] * 0.7, hc[2] * 0.7, hc[3] * 0.7, 1)
    local pc = live and Colour(b.power, nil)
    if not pc or (pc[1] > 0.99 and pc[2] > 0.99 and pc[3] > 0.99) then pc = { 0, 0.35, 0.75 } end
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

-- The previewed glow on a copy: a dispel type's colour, else the aggro's.
local function Glow(p)
    local key
    for _, t in ipairs(ns.DISPEL_TYPES) do if E.preview[t] then key = "dispelColor" .. t end end
    if not key and E.preview.threat then key = "threatColor" end
    if not key then
        if p.glow then p.glow:Hide() end
        return
    end
    if not p.glow then
        p.glow = ns.EdgeGlow(p, p.side)
        p.glow:SetFrameLevel(p:GetFrameLevel() + 8)
    end
    p.glow:SetGlowColor(ns.HexColor(ns.db[key]))
    p.glow:Show()
end

function Draw()
    if not stage or not stage:IsVisible() then return end
    local frame, piece = E.ui.Chosen()
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
    local roomW, roomH = (stage:GetWidth() or 0) - 40, (stage:GetHeight() or 0) - 76
    local scale = MAX_SCALE
    if width > 0 then scale = math.min(scale, roomW / width) end
    if height > 0 then scale = math.min(scale, roomH / height) end
    scale = math.max(scale, 0.1)
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
    for k, b in ipairs(models) do
        Mirror(frame, b, proxies[k], k)
        Glow(proxies[k])
    end
    -- a box round the chosen piece on each copy, and on nothing else
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
            local words = kind == "text" and Plain(first:GetStringWidth())
            if words then
                -- a text: round its words. Held by one point, the words
                -- grow from it (a width the editor gave leans the same
                -- way), so the box hangs from that point; held by two,
                -- they sit in the span where its justify puts them.
                local tall = Plain(first:GetStringHeight()) or Plain(first:GetHeight()) or 0
                local point, rel, relPoint, px, py
                if first:GetNumPoints() == 1 then point, rel, relPoint, px, py = first:GetPoint(1) end
                if type(point) == "string" and not ns.IsSecret(point) and Plain(px) and Plain(py) then
                    local dx = point:find("LEFT") and -1 or point:find("RIGHT") and 1 or 0
                    local dy = point:find("TOP") and 1 or point:find("BOTTOM") and -1 or 0
                    o:SetPoint(point, rel, relPoint, px + dx, py + dy)
                else
                    local j = first.GetJustifyH and first:GetJustifyH() or "CENTER"
                    local at = j == "LEFT" and "LEFT" or j == "RIGHT" and "RIGHT" or "CENTER"
                    o:SetPoint(at, first, at, at == "LEFT" and -1 or at == "RIGHT" and 1 or 0, 0)
                end
                o:SetSize(words + 2, tall + 2)
            else
                o:SetPoint("TOPLEFT", first, "TOPLEFT", -1, 1)
                o:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 1, -1)
            end
            o.label:SetText(k == 1 and E.PIECES[piece].label or "")
            o:Show()
        end
    end
    for i = n + 1, #boxes do boxes[i]:Hide(); boxes[i].from = nil end
    stage.preview:SetText(E.PreviewText())
    -- once more next frame: words just set are measured only once the game
    -- has laid them out, so a text's box first drawn from them is off until
    -- then (2026-11-12: the name's box centred until it was dragged)
    if not settling and C_Timer and C_Timer.After then
        settling = true
        C_Timer.After(0, function()
            Draw()
            settling = false
        end)
    end
end

-- The previewed crowd control's sweep, again as it runs out, its seconds on it.
local function Tick(self, elapsed)
    self.wait = (self.wait or 0) - elapsed
    if self.wait > 0 then return end
    self.wait = 0.1
    local now = GetTime()
    for _, p in ipairs(proxies) do
        local f = p.pieces.cc
        if f and f.sweepAt and p:IsShown() then
            local left = CC_TIME - (now - f.sweepAt)
            if left <= 0 then
                f.sweepAt = now
                f.cd:SetCooldown(now, CC_TIME)
                left = CC_TIME
            end
            f.timer:SetText(math.ceil(left))
        end
    end
end

-- ------------------------------------------------------------ the stage
-- ns.EditorStage(parent): the canvas, made in the editor's window, which
-- places it. Drawn again as it shows.
function ns.EditorStage(parent)
    if stage then return stage end
    stage = CreateFrame("Frame", nil, parent)
    UI.Skin(stage, C.well)
    -- nothing drawn on the canvas reaches past it
    stage:SetClipsChildren(true)
    stage.title = UI.Serif(stage, 12, C.goldBright)
    stage.title:SetPoint("TOPLEFT", 10, -8)
    stage.preview = UI.Plain(stage, 10, C.goldDark)
    stage.preview:SetPoint("BOTTOMLEFT", 10, 24)
    stage.hint = UI.Plain(stage, 10, C.dim)
    stage.hint:SetPoint("BOTTOMLEFT", 10, 8)
    stage.hint:SetText("Drag the box  ·  arrows nudge  ·  the frames on screen follow")
    stage.note = UI.Plain(stage, 12, C.dim)
    stage.note:SetPoint("CENTER", 0, 0)
    stage.note:SetPoint("LEFT", 20, 0)
    stage.note:SetPoint("RIGHT", -20, 0)
    holder = CreateFrame("Frame", nil, stage)
    holder:SetPoint("CENTER", stage, "CENTER", 0, -6)
    stage:SetScript("OnShow", function() Draw() end)
    stage:SetScript("OnSizeChanged", function() Draw() end)
    stage:SetScript("OnUpdate", Tick)
    stage:SetScript("OnHide", function() for _, o in ipairs(boxes) do o.from = nil end end)
    -- its parts, by name (the harness reads them)
    stage.holder, stage.proxies, stage.boxes = holder, proxies, boxes
    return stage
end

-- Whatever the editor or the game changes, the canvas draws again: a new
-- choice, a preview chip, a frame's pieces laid again, an option.
E.onChoose = function() Draw() end
E.onApply = function() Draw() end
E.onPreview = function() Draw() end
ns.OnAnySetting(function() Draw() end)
