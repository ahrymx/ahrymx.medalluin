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
local fit                 -- the reach each copy was fitted to, held still while a box is dragged
-- The view: zoom over the fitted scale (ZOOM_MIN to ZOOM_MAX), and the pan, the
-- holder's centre moved from its fitted place in stage units (the
-- screen's size, whatever the zoom). A new frame tab fits again; another
-- piece of the same frame keeps it. last: what the last Draw fitted.
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP, DOUBLE = 0.25, 4, 1.25, 0.3
local view = { zoom = 1, x = 0, y = 0 }
local last
local function Refit() view.zoom, view.x, view.y = 1, 0, 0 end
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

-- The real region's points onto the copy's. The game keeps a text's points
-- secret while its words are (2026-11-12: the power value, then the health
-- value, drawn in the middle of the health): then the points Medalluin's
-- code gave it (ns.Text's record), else those its code first gave it (shot,
-- the editor's, while the piece is not moved), else each point by name with
-- no offset, else the middle of what the text is in.
local function Readable(point, relPoint, x, y)
    return type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(relPoint)
        and (x == nil or Plain(x)) and (y == nil or Plain(y))
end
local function CopyPoints(src, dst, map, p, shot)
    dst:ClearAllPoints()
    local set, named = 0, {}
    for i = 1, (src:GetNumPoints() or 0) do
        local point, rel, relPoint, x, y = src:GetPoint(i)
        if Readable(point, relPoint, x, y) then
            dst:SetPoint(point, map[rel] or p, relPoint or point, x or 0, y or 0)
            set = set + 1
        elseif type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(rel) then
            table.insert(named, { point, rel, not ns.IsSecret(relPoint) and relPoint or point })
        end
    end
    if set > 0 then return end
    -- the points as Medalluin's code gave them (ns.Text keeps them)
    for _, pt in ipairs(src.medalluinPoints or {}) do
        dst:SetPoint(pt[1], map[pt[2]] or p, pt[3], pt[4], pt[5])
        set = set + 1
    end
    if set > 0 then return end
    for _, pt in ipairs(shot and shot.points or {}) do
        if Readable(pt[1], pt[3], pt[4], pt[5]) then
            dst:SetPoint(pt[1], map[pt[2]] or p, pt[3] or pt[1], pt[4] or 0, pt[5] or 0)
            set = set + 1
        end
    end
    if set > 0 then return end
    for _, pt in ipairs(named) do
        dst:SetPoint(pt[1], map[pt[2]] or p, pt[3], 0, 0)
        set = set + 1
    end
    if set == 0 then
        local within = src.GetParent and src:GetParent()
        dst:SetPoint("CENTER", map[within] or p, "CENTER", 0, 0)
    end
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
        -- a piece not moved: its points as its code first gave them
        local shot
        local e = pr[3] and E.Edits(frame, pr[3])
        if pr[3] and not (e and e.h) then shot = E.Shot(b, pr[3])[pr[4] or 1] end
        CopyPoints(src, dst, map, p, shot)
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
            -- a text held by one point grows from it, as wide as its own
            -- words: the real one's width is not read, which the game gives
            -- stale just after the editor moved it (2026-11-12: the name
            -- left behind its box as its anchor changed), and a room the
            -- editor gave leans the way the point does anyway
            if (src:GetNumPoints() or 0) < 2 then dst:SetWidth(0) end
        else
            dst:SetSize(Plain(src:GetWidth()) or 0, Plain(src:GetHeight()) or 0)
        end
        if id then
            dst:SetAlpha(E.Shown(frame, id) and 1 or 0.25)
            if E.PIECES[id].type == "text" then
                dst:Show()
            else
                -- an icon as the real one is, else while chosen or previewed;
                -- a live row's icons are the client's (ns.LiveIcons)
                local stub = E.preview[id] and ns.STUB_ICONS[id]
                if type(stub) == "table" then stub = stub[pr[4]] end
                local live = pr[4] and ns.LiveIcons and ns.LiveIcons(E.PIECES[id].get(b))
                local real = live and live[pr[4]]
                Paint(dst, id, src, stub or real, id == "cc" and stub ~= nil)
                dst:SetShown(stub ~= nil or id == chosen or src:IsShown() or real ~= nil)
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
    p.power:SetAlpha(b.power:GetAlpha())
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

-- ------------------------------------------------------------ dragging
-- A dragged piece takes its anchor from where it is dropped: the nearest
-- of nine dots on what it is on, INSET in from its edges, across and down
-- (outer, centre, inner; top, middle, bottom). Near the dot, it snaps
-- there (the dot lit); else level with another piece's edge or middle, it
-- snaps to that (a guide). Shift: no snapping.
-- (art: /workspace/editor-snap-S3.png)
local SNAP, INSET = 6, 8
local GUIDE = { 0.35, 0.78, 1 }
local dots, guides = {}, {}

local function Rect(r)
    if not r then return nil end
    local l, rt, t, b = Plain(r:GetLeft()), Plain(r:GetRight()), Plain(r:GetTop()), Plain(r:GetBottom())
    if l and rt and t and b then return { l = l, r = rt, t = t, b = b } end
end

-- A text's words: its region, where one point sizes it to them; else
-- where its justify puts them in its span.
local function Words(r)
    local box = Rect(r)
    local w = Plain(r:GetStringWidth())
    if not box or not w or r:GetNumPoints() < 2 then return box end
    local j = r.GetJustifyH and r:GetJustifyH() or "CENTER"
    if j == "LEFT" then box.r = box.l + w
    elseif j == "RIGHT" then box.l = box.r - w
    else
        local mid = (box.l + box.r) / 2
        box.l, box.r = mid - w / 2, mid + w / 2
    end
    return box
end

-- The copy's region a piece is on (editor.lua's OnRegion).
local function OnCopy(p, on)
    if on == "power" then return p.power end
    if on == "name" then return p.pieces.name end
    if on == "frame" then return p end
    return p.health
end

-- Every other piece on copy p, by its edges and middles (a guide's lines).
local function Others(p, piece)
    local out = {}
    for id, r in pairs(p.pieces) do
        if id ~= piece then
            local list = r.GetObjectType and { r } or (rawget(r, 1) and r) or { r }
            for _, one in ipairs(list) do
                if one.IsShown and one:IsShown() then
                    local box = E.PIECES[id].type == "text" and Words(one) or Rect(one)
                    if box then table.insert(out, box) end
                end
            end
        end
    end
    return out
end

local function Dot(i)
    local d = dots[i]
    if d then return d end
    d = holder:CreateTexture(nil, "OVERLAY")
    d:SetColorTexture(GUIDE[1], GUIDE[2], GUIDE[3], 1)
    dots[i] = d
    return d
end
local function Guide(i)
    local g = guides[i]
    if g then return g end
    g = holder:CreateTexture(nil, "OVERLAY")
    g:SetColorTexture(GUIDE[1], GUIDE[2], GUIDE[3], 0.9)
    guides[i] = g
    return g
end
local function HideGuides()
    for _, d in ipairs(dots) do d:Hide() end
    for _, g in ipairs(guides) do g:Hide() end
end

local THIRDS = { { "left", "center", "right" }, { "top", "middle", "bottom" } }
local DOT_POINT = { left = "LEFT", center = "", right = "RIGHT", top = "TOP", middle = "", bottom = "BOTTOM" }

-- The nine dots on what the piece is on; the anchor's larger, filled when
-- the piece snapped to it.
local function ShowDots(on, ax, ay, lit)
    local k = 0
    for _, v in ipairs(THIRDS[2]) do
        for _, h in ipairs(THIRDS[1]) do
            k = k + 1
            local d = Dot(k)
            local point = DOT_POINT[v] .. DOT_POINT[h]
            if point == "" then point = "CENTER" end
            local x = h == "left" and INSET or h == "right" and -INSET or 0
            local y = v == "top" and -INSET or v == "bottom" and INSET or 0
            local mine = h == ax and v == ay
            local size = mine and (lit and 4 or 3) or 2
            d:SetSize(size, size)
            d:SetAlpha(mine and 1 or 0.7)
            d:ClearAllPoints()
            d:SetPoint("CENTER", on, point, x, y)
            d:Show()
        end
    end
end

-- A guide across the copy at a screen x (vertical) or y, in holder units.
local function ShowGuide(i, vertical, at)
    local g = Guide(i)
    local area = Rect(holder)
    if not area then return end
    g:ClearAllPoints()
    if vertical then
        g:SetSize(0.5, area.t - area.b + 2 * GAP)
        g:SetPoint("CENTER", holder, "BOTTOMLEFT", at - area.l, (area.t - area.b) / 2)
    else
        g:SetSize(area.r - area.l + 40, 0.5)
        g:SetPoint("CENTER", holder, "BOTTOMLEFT", (area.r - area.l) / 2, at - area.b)
    end
    g:Show()
end

-- The nearest of a piece's low, middle and high edges to another piece's
-- edges and middles, within SNAP: how far to move, and the guide's place.
local function Level(lo, hi, others, keyLo, keyHi)
    local best, guide
    for _, q in ipairs(others) do
        for _, a in ipairs({ lo, (lo + hi) / 2, hi }) do
            for _, b in ipairs({ q[keyLo], (q[keyLo] + q[keyHi]) / 2, q[keyHi] }) do
                local d = b - a
                if math.abs(d) <= SNAP and (not best or math.abs(d) < math.abs(best)) then best, guide = d, b end
            end
        end
    end
    return best, guide
end

-- One axis, low to high: which dot the piece is nearest (its low edge to
-- the low dot, INSET in; its middle to the middle; its high edge to the
-- high dot), the offset of its point there from what it is on's, and
-- whether it snapped to that dot.
local function Axis(lo, hi, onLo, onHi, free)
    local mine = { lo, (lo + hi) / 2, hi }
    local theirs = { onLo, (onLo + onHi) / 2, onHi }
    local want = { INSET, 0, -INSET }
    local at, far
    -- a tie: the middle
    for _, i in ipairs({ 2, 1, 3 }) do
        local d = math.abs(mine[i] - theirs[i] - want[i])
        if not far or d < far then at, far = i, d end
    end
    if not free and far <= SNAP then return at, want[at], true end
    return at, mine[at] - theirs[at]
end

-- How far (screen pixels) the pointer goes before a press is a drag: a
-- click on a box writes nothing (2026-11-13: a click on a row Outside put
-- it in, and the refit under it threw it thousands of pixels away).
local SLOP = 3

-- The holder at the view's zoom and pan, the pan held to what the zoom
-- hides: at the fit nothing pans, zoomed in an edge comes to the room's
-- edge and no further. The holder's own 6 down (and the scope's) is in its
-- units.
local function Scale() return last.scale * view.zoom end
local function Clamp()
    local s = Scale()
    local mx = math.max(0, (last.w * s - last.roomW) / 2)
    local my = math.max(0, (last.h * s - last.roomH) / 2)
    view.x = math.max(-mx, math.min(mx, view.x))
    view.y = math.max(-my, math.min(my, view.y))
end
-- The grid behind the copies: a line every MINOR of the frame's pixels, a
-- brighter one every MAJOR, from the first copy's top left (its pixel 0),
-- so it moves and grows with the view. Lines closer than SPARSE stage
-- units are left out (the minor ones first), and none crosses the edge.
local MINOR, MAJOR, SPARSE, INSIDE = 10, 50, 5, 3
local GRID_MINOR, GRID_MAJOR = { 1, 1, 1, 0.035 }, { 0.541, 0.439, 0.204, 0.22 }
local grid = { v = {}, h = {} }
local function GridLine(list, i)
    local t = list[i]
    if not t then
        t = stage:CreateTexture(nil, "BACKGROUND", nil, 3)
        list[i] = t
    end
    return t
end
-- The lines down (vertical) or across from origin o, a stage unit apart
-- by step, within the stage's span.
local function Lines(list, vertical, o, step, span, other)
    local n = 0
    local mod = MAJOR / MINOR
    local sparse = step < SPARSE
    if step * mod >= SPARSE then
        local k = math.ceil((INSIDE - o) / step)
        while true do
            local at = o + k * step
            if at > span - INSIDE then break end
            local major = k % mod == 0
            if major or not sparse then
                n = n + 1
                local t = GridLine(list, n)
                local c = major and GRID_MAJOR or GRID_MINOR
                t:SetColorTexture(c[1], c[2], c[3], c[4])
                t:ClearAllPoints()
                if vertical then
                    t:SetPoint("TOPLEFT", stage, "TOPLEFT", at, -INSIDE)
                    t:SetSize(1, other - 2 * INSIDE)
                else
                    t:SetPoint("TOPLEFT", stage, "TOPLEFT", INSIDE, -at)
                    t:SetSize(other - 2 * INSIDE, 1)
                end
                t:Show()
            end
            k = k + 1
        end
    end
    for i = n + 1, #list do list[i]:Hide() end
    return n
end
local function Grid()
    local w, h = stage:GetWidth() or 0, stage:GetHeight() or 0
    local p = proxies[1]
    local k = stage:GetEffectiveScale()
    local ox, oy
    if p and p:IsShown() and p:GetLeft() and stage:GetLeft() then
        local q = p:GetEffectiveScale() / k
        ox, oy = p:GetLeft() * q - stage:GetLeft(), stage:GetTop() - p:GetTop() * q
    end
    if not ox then
        for _, t in ipairs(grid.v) do t:Hide() end
        for _, t in ipairs(grid.h) do t:Hide() end
        grid.across, grid.down = 0, 0
        return
    end
    local step = MINOR * Scale()
    grid.across = Lines(grid.v, true, ox, step, w, h)
    grid.down = Lines(grid.h, false, oy, step, h, w)
end

local function Lay()
    if not last then return end
    Clamp()
    local s = Scale()
    holder:SetScale(s)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", stage, "CENTER", view.x / s, view.y / s - 6 - last.down)
    Grid()
end

-- Whether a box is being dragged (a press that has moved).
local function Dragging()
    for _, o in ipairs(boxes) do if o.from and o.from.moved then return true end end
    return false
end

-- The pointer, in stage units from the stage's middle.
local function FromMiddle()
    local x, y = GetCursorPosition()
    local k = stage:GetEffectiveScale()
    local l, r, t, b = stage:GetLeft(), stage:GetRight(), stage:GetTop(), stage:GetBottom()
    if not (l and r and t and b) then return 0, 0 end
    return x / k - (l + r) / 2, y / k - (t + b) / 2
end

-- The wheel: a step in or out, about the point under the pointer, which
-- stays under it. Not while a box is dragged (its drag measures at the
-- scale it was pressed at).
local function Wheel(_, delta)
    if not last or Dragging() then return end
    local cx, cy = FromMiddle()
    local s = Scale()
    -- the drawing's point under the pointer, from the holder's middle
    local dx, dy = (cx - view.x) / s, (cy - (view.y - (6 + last.down) * s)) / s
    view.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, view.zoom * ZOOM_STEP ^ delta))
    local s2 = Scale()
    view.x, view.y = cx - dx * s2, cy - dy * s2 + (6 + last.down) * s2
    Draw()
end

-- A press on the canvas (not a box): a second within DOUBLE of the first,
-- where it was, fits again; else a pan, once it has moved SLOP.
local function Press(self, button)
    if button and button ~= "LeftButton" then return end
    local x, y = GetCursorPosition()
    local was = self.pressed
    if was and GetTime() - was.t < DOUBLE and math.abs(x - was.x) < SLOP and math.abs(y - was.y) < SLOP then
        self.pressed, self.pan = nil, nil
        Refit()
        Draw()
        return
    end
    self.pressed = { t = GetTime(), x = x, y = y }
    self.pan = { x = x, y = y, vx = view.x, vy = view.y }
end
local function Panning(self)
    local pan = self.pan
    if not pan or not last then return end
    local x, y = GetCursorPosition()
    if not pan.moved then
        if math.abs(x - pan.x) < SLOP and math.abs(y - pan.y) < SLOP then return end
        pan.moved = true
    end
    local k = self:GetEffectiveScale()
    view.x, view.y = pan.vx + (x - pan.x) / k, pan.vy + (y - pan.y) / k
    Lay()
end

local function Drag(self)
    local from = self.from
    local x, y = GetCursorPosition()
    if not from.moved then
        if math.abs(x - from.x) < SLOP and math.abs(y - from.y) < SLOP then return end
        from.moved = true
    end
    -- the canvas is drawn larger: a pixel of the frame is scale of the screen's
    local dx, dy = (x - from.x) / from.scale, (y - from.y) / from.scale
    local box = from.rect
    local on = OnCopy(from.p, E.ui.PlaceField("on") or "health")
    local area = Rect(on)
    if not (box and area) then
        -- nothing to measure: a plain move, as before
        local nx = from.px - self.side * math.floor(dx + 0.5)
        local ny = from.py + math.floor(dy + 0.5)
        if nx ~= E.ui.PlaceField("x") or ny ~= E.ui.PlaceField("y") then E.ui.SetPlace({ x = nx, y = ny }) end
        return
    end
    local l, r, t, b = box.l + dx, box.r + dx, box.t + dy, box.b + dy
    local free = IsShiftKeyDown and IsShiftKeyDown()
    -- across, left to right; down, top to bottom (screen y grows up, so negated)
    local ax, ox, dotX = Axis(l, r, area.l, area.r, free)
    local ay, oy, dotY = Axis(-t, -b, -area.t, -area.b, free)
    local gx, gy
    if not free and not dotX then
        local d
        d, gx = Level(l, r, from.others, "l", "r")
        if d then ox = ox + d end
    end
    if not free and not dotY then
        local d
        d, gy = Level(b, t, from.others, "b", "t")
        if d then oy = oy - d end
    end
    local h = THIRDS[1][ax]
    local v = THIRDS[2][ay]
    ShowDots(on, h, v, dotX and dotY)
    for _, g in ipairs(guides) do g:Hide() end
    if gx then ShowGuide(1, true, gx) end
    if gy then ShowGuide(2, false, gy) end
    -- as the editor states a place: outer and inner by this copy's side;
    -- x inward (away from its outer end), y up
    local side = self.side
    local place = {
        h = h == "center" and "center" or (h == "left") == (side == -1) and "outer" or "inner",
        v = v,
        x = math.floor(-side * ox + 0.5) + 0,
        y = math.floor(-oy + 0.5) + 0,
        ph = E.NIL, pv = E.NIL,
    }
    local now = { E.ui.PlaceField("h"), E.ui.PlaceField("v"), E.ui.PlaceField("x"), E.ui.PlaceField("y") }
    if now[1] ~= place.h or now[2] ~= place.v or now[3] ~= place.x or now[4] ~= place.y then
        E.ui.SetPlace(place)
    end
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
        -- a bar is sized, not moved: its height is the editor's
        if E.PIECES[self.piece].type == "bar" then return end
        local x, y = GetCursorPosition()
        local p = proxies[self.copy]
        local mine = p.pieces[self.piece]
        -- what moves to the anchor: a row's first icon, else what is boxed
        local rect
        if E.PIECES[self.piece].type == "row" then
            rect = Rect(mine[1])
        else
            rect = Rect(self)
            if rect then rect.l, rect.r, rect.t, rect.b = rect.l + 1, rect.r - 1, rect.t - 1, rect.b + 1 end
        end
        self.from = { x = x, y = y, px = E.ui.PlaceField("x") or 0, py = E.ui.PlaceField("y") or 0,
            scale = self:GetEffectiveScale(), p = p, rect = rect, others = Others(p, self.piece) }
    end)
    o:SetScript("OnMouseUp", function(self)
        local moved = self.from and self.from.moved
        self.from = nil
        HideGuides()
        -- the fit held still while it was dragged: fitted again to where it is
        if moved then Draw() end
    end)
    o:SetScript("OnUpdate", function(self)
        if self.from then Drag(self) end
    end)
    o:SetScript("OnEnter", function(self)
        local bar = E.PIECES[self.piece].type == "bar"
        UI.Tip(self, E.PIECES[self.piece].label, bar and "Its height is the editor's, on the right."
            or "Drag to move it: it hangs from the nearest corner, edge or middle, and snaps to the dots "
            .. "and to other pieces (Shift: no snapping). The arrow keys nudge it.")
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

-- How far copy p's shown pieces reach past it, from its top left: left
-- (0 or less), right (its width or more), top (0 or more), bottom (its
-- height below 0, or further). A piece the game will not measure counts
-- as inside.
local function Reach(p)
    local box = Rect(p)
    local w, h = Plain(p:GetWidth()) or 0, Plain(p:GetHeight()) or 0
    local out = { l = 0, r = w, t = 0, b = -h }
    if not box then return out end
    for id, r in pairs(p.pieces) do
        local text = E.PIECES[id].type == "text"
        for _, one in ipairs(r.GetObjectType and { r } or r) do
            local at = one:IsShown() and (text and Words(one) or Rect(one))
            if at then
                out.l = math.min(out.l, at.l - box.l)
                out.r = math.max(out.r, at.r - box.l)
                out.t = math.max(out.t, at.t - box.t)
                out.b = math.min(out.b, at.b - box.t)
            end
        end
    end
    return out
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
    if view.frame ~= frame.id then
        Refit()
        view.frame = frame.id
    end
    stage.title:SetText(frame.name .. "  >  " .. E.PIECES[piece].label)
    -- what the frame is and whose, under it (the editor's words)
    stage.scope:SetWidth(math.max(20, (stage:GetWidth() or 0) - 20))
    stage.scope:SetText(E.ui.Scope and E.ui.Scope() or "")
    local top = (stage.scope:GetText() or "") ~= "" and math.ceil(stage.scope:GetStringHeight() or 0) + 4 or 0
    local models = Models(frame)
    stage.note:SetShown(#models == 0)
    if #models == 0 then stage.note:SetText(Absent(frame)) end
    -- the copies, one over the other, at the largest size that fits all
    -- of each: its button and whatever hangs past it (a row Outside, an
    -- icon over its edge), measured once copied
    for k = 1, #models do Proxy(k) end
    for k = #models + 1, #proxies do proxies[k]:Hide() end
    -- (while a box is dragged, the fit it started on: one refitted under
    -- the pointer moves what the drag measures against, and it runs away)
    local held = false
    for _, o in ipairs(boxes) do if o.from and o.from.moved then held = true end end
    local reach = {}
    for k, b in ipairs(models) do
        local p = proxies[k]
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
        Mirror(frame, b, p, k)
        Glow(p)
        reach[k] = Reach(p)
    end
    if held and fit and #fit == #models then reach = fit end
    fit = reach
    local left, right, height = 0, 0, 0
    for k = 1, #models do
        left, right = math.min(left, reach[k].l), math.max(right, reach[k].r)
        height = height + GAP + reach[k].t - reach[k].b
    end
    local width = right - left
    -- the stage's room, less its title and scope, its hint and a margin
    local roomW, roomH = (stage:GetWidth() or 0) - 40, (stage:GetHeight() or 0) - 76 - top
    local scale = MAX_SCALE
    if width > 0 then scale = math.min(scale, roomW / width) end
    if height > 0 then scale = math.min(scale, roomH / height) end
    scale = math.max(scale, 0.1)
    -- (down: the drawing's middle below the stage's by half the scope, in
    -- the holder's units as its 6 is, so a zoom about a point keeps it)
    last = { scale = scale, w = width, h = height, roomW = roomW, roomH = roomH, down = top / 2 / scale }
    Lay()
    holder:SetSize(math.max(width, 1), math.max(height, 1))
    local y = 0
    for k = 1, #models do
        local p = proxies[k]
        y = y + GAP + reach[k].t
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", holder, "TOPLEFT", -left, -y)
        y = y - reach[k].b
    end
    -- (the grid starts at the first copy, now in its place)
    if last then Grid() end
    -- a box round the chosen piece on each copy, and on nothing else
    local n = 0
    local kind = E.PIECES[piece].type
    for k = 1, #models do
        local p = proxies[k]
        -- the power bar is the copy's own
        local mine = kind == "bar" and p.power or kind ~= "cell" and p.pieces[piece]
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
    Panning(self)
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
    stage.scope = UI.Plain(stage, 10, C.dim)
    stage.scope:SetPoint("TOPLEFT", 10, -24)
    stage.scope:SetJustifyH("LEFT")
    stage.preview = UI.Plain(stage, 10, C.goldDark)
    stage.preview:SetPoint("BOTTOMLEFT", 10, 24)
    stage.hint = UI.Plain(stage, 10, C.dim)
    stage.hint:SetPoint("BOTTOMLEFT", 10, 8)
    stage.hint:SetText("Drag the box  ·  arrows nudge  ·  wheel zooms  ·  drag the canvas to pan  ·  double-click fits")
    stage.note = UI.Plain(stage, 12, C.dim)
    stage.note:SetPoint("CENTER", 0, 0)
    stage.note:SetPoint("LEFT", 20, 0)
    stage.note:SetPoint("RIGHT", -20, 0)
    holder = CreateFrame("Frame", nil, stage)
    holder:SetPoint("CENTER", stage, "CENTER", 0, -6)
    -- the wheel zooms at the pointer, a drag off the box pans, a double
    -- click fits (and the canvas no longer moves the window)
    stage:EnableMouse(true)
    stage:EnableMouseWheel(true)
    stage:SetScript("OnMouseWheel", Wheel)
    stage:SetScript("OnMouseDown", Press)
    stage:SetScript("OnMouseUp", function(self) self.pan = nil end)
    stage:SetScript("OnShow", function() Draw() end)
    stage:SetScript("OnSizeChanged", function() Draw() end)
    stage:SetScript("OnUpdate", Tick)
    stage:SetScript("OnHide", function(self)
        for _, o in ipairs(boxes) do o.from = nil end
        self.pan = nil
    end)
    -- its parts, by name (the harness reads them)
    stage.holder, stage.proxies, stage.boxes, stage.dots, stage.guides = holder, proxies, boxes, dots, guides
    stage.view, stage.grid = view, grid
    return stage
end

-- Whatever the editor or the game changes, the canvas draws again: a new
-- choice, a preview chip, a frame's pieces laid again, an option.
E.onChoose = function() Draw() end
E.onApply = function() Draw() end
E.onPreview = function() Draw() end
ns.OnAnySetting(function() Draw() end)
