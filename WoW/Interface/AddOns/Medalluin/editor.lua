-- The unit-frame editor's model (options/editor.lua is its window, after
-- Cell_UnitFrames'; art/settings/gen_editor.py, draft A): what a frame's
-- pieces are, and each piece placed, sized, set in its font and formatted
-- as the player left it.
--
-- Six frames. The console's: the player and the target (one layout, the
-- two mirrored) and the console's party, kept per profile, as the console
-- shapes them. The group widgets': the party in its widget, the raid, the
-- bosses and the arena, shared by every profile.
--
-- What the player changed is an option per frame (editUnit ... editArena),
-- false until something is: { [piece] = { field = value } }. A piece no
-- field touches is left exactly as its own code laid it, so an untouched
-- frame draws as it always has. The first time the editor touches a piece
-- on a button it remembers how that button had it (a snapshot), which
-- Reset gives back, and which a first move starts from, so nothing jumps.
--
-- Places are mirrored on the console: a piece sits at the frame's outer or
-- inner end, not its left or right, and moves inward, so the left copy and
-- the right one stay each other's mirror. A widget's cells are all the
-- left copy: outer is left.
local _, ns = ...

local E = {}
ns.editor = E

-- ------------------------------------------------------------ formats
-- What a text piece can show: { value, name on the menu, tip }.
E.FORMATS = {
    name = {
        { "full", "Full", "The whole name." },
        { "short", "Initials", "Every word but the last as its initial: \"J. Smith\"." },
    },
    value = {
        { "percent", "Percent", "\"82%\"." },
        { "current", "Current", "\"41.2k\"." },
        { "both", "Current and percent", "\"41.2k | 82%\"." },
        { "deficit", "Missing", "\"-9.1k\", blank at full health. Where the game keeps the numbers secret, the "
            .. "percent." },
    },
    powerValue = {
        { "both", "Current and percent", "\"8.2k | 60%\"." },
        { "current", "Current", "\"8.2k\"." },
        { "percent", "Percent", "\"60%\"." },
    },
}

-- ------------------------------------------------------------ pieces
-- A piece: its id, its name in the list, what it is ("text", "icon", a
-- "row" of icons, or the "cell" itself), and how to find it on a button.
-- A text piece has formats; one hidden by default starts with its Shown off.
local PIECES = {
    cell = { label = "Cell size", type = "cell" },
    name = { label = "Name", type = "text", get = function(b) return b.name end },
    value = { label = "Health value", type = "text", get = function(b) return b.value end },
    powerValue = { label = "Power value", type = "text", get = function(b) return b.powerValue end },
    role = { label = "Role", type = "icon", get = function(b) return b.roleFrame end },
    status = { label = "Ready check", type = "icon", get = function(b) return b.statusWidget end },
    cc = { label = "Crowd control", type = "icon", get = function(b) return b.ccWidget end },
    boss = { label = "Boss debuff", type = "icon", get = function(b) return b.bossDebuff end },
    buffs = { label = "Your buffs", type = "row", get = function(b) return b.buffWidgets end },
    mine = { label = "Your debuffs", type = "row", get = function(b) return b.mineWidgets end },
}
E.PIECES = PIECES

local function Party(which)
    return function()
        local list = {}
        for i = 1, 4 do
            local b = ns.units and ns.units["party" .. i]
            if b and (b.inWidget and true or false) == which then table.insert(list, b) end
        end
        return list
    end
end

-- The cells a widget registered (ns.EditableCell), in the order they came.
local cells = { partyWidget = {}, raid = {}, boss = {}, arena = {} }
local function Cells(id)
    return function() return cells[id] end
end

-- The frames, in the window's order. A piece whose Shown is an option the
-- Unit Frames page has too names it (shows): the editor's Shown is that
-- option, not a second one. A widget's cell has its size from cell.
E.FRAMES = {
    { id = "unit", key = "editUnit", name = "Player · Target", buttons = function()
        return { ns.units.player, ns.units.target }
    end, pieces = { "name", "value", "powerValue", "cc", "boss", "buffs" },
      shows = { cc = "auraCC", boss = "auraBoss", buffs = "auraBuffs" } },
    { id = "party", key = "editParty", name = "Party", buttons = Party(false),
      pieces = { "name", "value", "role", "status", "cc", "boss", "buffs" },
      hidden = { value = true },
      shows = { cc = "auraCC", boss = "auraBoss", buffs = "auraBuffs" } },
    { id = "partyWidget", key = "editPartyWidget", name = "Party widget", buttons = Party(true),
      cell = { 160, 40 },
      pieces = { "cell", "name", "value", "role", "status", "cc", "boss", "buffs" },
      hidden = { value = true },
      shows = { cc = "partyWidgetCC", boss = "partyWidgetBoss", buffs = "partyWidgetBuffs" } },
    { id = "raid", key = "editRaid", name = "Raid", buttons = Cells("raid"), cell = { 112, 36 },
      pieces = { "cell", "name", "value", "cc", "boss" },
      shows = { cc = "raidCC", boss = "raidBoss" } },
    { id = "boss", key = "editBoss", name = "Boss", buttons = Cells("boss"), cell = { 180, 40 },
      pieces = { "cell", "name", "value", "mine" },
      shows = { mine = "bossWidgetMine" } },
    { id = "arena", key = "editArena", name = "Arena", buttons = Cells("arena"), cell = { 160, 40 },
      pieces = { "cell", "name", "value", "cc", "mine" },
      shows = { cc = "arenaCC", mine = "arenaMine" } },
}
local byId = {}
for _, frame in ipairs(E.FRAMES) do byId[frame.id] = frame end
E.byId = byId

-- A widget's cell, given to the editor as one of its frame's.
function ns.EditableCell(b, id)
    if not cells[id] then return end
    b.editFrame = id
    table.insert(cells[id], b)
end

-- The frame a button is drawn as now: the party's by where its layout put it.
function E.FrameOf(b)
    if b.editFrame then return byId[b.editFrame] end
    local unit = b.unit or ""
    if unit == "player" or unit == "target" then return byId.unit end
    if unit:match("^party%d$") then return byId[b.inWidget and "partyWidget" or "party"] end
end

-- Which way a button's outer end is: -1 left, 1 right. The console's copies
-- by their slot; the light console's party row and every widget cell are
-- left copies.
local function Side(b, frame)
    if frame.id == "unit" or frame.id == "party" and not (ns.layout.party and ns.layout.party.detached) then
        local slot = ns.slots[b.unit]
        return slot and slot[2] or -1
    end
    return -1
end
E.Side = Side

-- ------------------------------------------------------------ the option
-- What the player changed on a piece, or nil.
function E.Edits(frame, piece)
    local all = ns.db[frame.key]
    return type(all) == "table" and all[piece] or nil
end

-- A copy, so the saved table of the frame is never changed under a reader.
local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = type(v) == "table" and Copy(v) or v end
    return out
end

-- Write fields onto a piece (nil clears one); a piece with none left goes,
-- and a frame with none left is false again.
function E.Set(frame, piece, fields)
    local all = type(ns.db[frame.key]) == "table" and Copy(ns.db[frame.key]) or {}
    local edits = all[piece] or {}
    for k, v in pairs(fields) do
        if v == E.NIL then edits[k] = nil else edits[k] = v end
    end
    all[piece] = next(edits) and edits or nil
    ns.SetOption(frame.key, next(all) and all or false)
end
E.NIL = {}

function E.ResetPiece(frame, piece)
    local all = type(ns.db[frame.key]) == "table" and Copy(ns.db[frame.key]) or nil
    if not all or not all[piece] then return end
    all[piece] = nil
    ns.SetOption(frame.key, next(all) and all or false)
end

function E.ResetFrame(frame)
    ns.SetOption(frame.key, false)
end

-- ------------------------------------------------------------ anchors
-- A place is { h, v }: h "outer", "center" or "inner", v "top", "middle" or
-- "bottom". As a point on a button whose outer end is side:
local function Point(h, v, side)
    local outer, inner = side == 1 and "RIGHT" or "LEFT", side == 1 and "LEFT" or "RIGHT"
    local x = h == "outer" and outer or h == "inner" and inner or ""
    local y = v == "top" and "TOP" or v == "bottom" and "BOTTOM" or ""
    local p = y .. x
    return p ~= "" and p or "CENTER"
end
E.Point = Point

-- and back
local function Place(point, side)
    local v = point:match("^TOP") and "top" or point:match("^BOTTOM") and "bottom" or "middle"
    local x = point:match("LEFT$") and "LEFT" or point:match("RIGHT$") and "RIGHT" or nil
    local outer = side == 1 and "RIGHT" or "LEFT"
    local h = not x and "center" or x == outer and "outer" or "inner"
    return h, v
end

-- What a piece can hang from: a button's frame, its bars, its name.
E.ON = {
    { "health", "Health bar" }, { "power", "Power bar" }, { "frame", "Frame" }, { "name", "Name" },
}
local function OnRegion(b, on)
    if on == "health" then return b.health end
    if on == "power" then return b.power end
    if on == "name" then return b.name end
    return b
end
-- and which of them a region is (the text layers lie over their bars)
local function OnOf(b, region)
    if region == b.health or region == b.text then return "health" end
    if region == b.power or (b.powerValue and region == b.powerValue:GetParent()) then return "power" end
    if region == b.name then return "name" end
    if region == b then return "frame" end
end

-- ------------------------------------------------------------ snapshots
-- How a button had a region before the editor touched it.
-- (A size the game keeps secret, a text's while its words are, is not
-- kept: nothing may compare it. A point is kept as the game gives it, its
-- offsets perhaps secret, for Restore to try.)
local function Plain(v)
    if type(v) == "number" and not ns.IsSecret(v) then return v end
end
E.Plain = Plain
local function Shot(r)
    local s = { points = {}, w = Plain(r:GetWidth()), h = Plain(r:GetHeight()) }
    for i = 1, (r:GetNumPoints() or 0) do
        local pt = { r:GetPoint(i) }
        if type(pt[1]) == "string" and not ns.IsSecret(pt[1]) then table.insert(s.points, pt) end
    end
    if r.GetFont then s.font = { r:GetFont() } end
    if r.GetJustifyH then s.justify = r:GetJustifyH() end
    return s
end

local function Regions(b, piece)
    local got = PIECES[piece].get and PIECES[piece].get(b)
    if not got then return nil end
    if PIECES[piece].type == "row" then return got end
    return { got }
end

local function Snap(b, piece)
    b.editShots = b.editShots or {}
    local shot = b.editShots[piece]
    if not shot then
        shot = {}
        for i, r in ipairs(Regions(b, piece) or {}) do shot[i] = Shot(r) end
        b.editShots[piece] = shot
    end
    return shot
end

-- Undo what the editor wrote on a piece but its place: the size, the font,
-- a text's width (its own code never sets one: a text sizes to its words
-- or to its two points).
local function Unwrite(b, piece, shot, done)
    for i, r in ipairs(Regions(b, piece) or {}) do
        local s = shot[i]
        if s then
            if done.place and PIECES[piece].type == "text" then r:SetWidth(0) end
            if done.size then r:SetSize(s.w, s.h) end
            if done.font and s.font and s.font[1] then r:SetFont(s.font[1], s.font[2], s.font[3]) end
        end
    end
end

-- A button's own code laid these pieces again (a party moving between the
-- console and its widget): their places are the button's own now. Its
-- code sets no size or font there, so the editor's go back first, or the
-- next snapshot would take them for the button's.
function E.Relaid(b, ...)
    if not b.editShots then return end
    for i = 1, select("#", ...) do
        local piece = select(i, ...)
        local shot, done = b.editShots[piece], b.editDone and b.editDone[piece]
        if shot and done then Unwrite(b, piece, shot, done) end
        b.editShots[piece] = nil
        if b.editDone then b.editDone[piece] = nil end
    end
end

-- Where a piece is, as the editor states a place, read from how a button
-- had it: the first of its points on a region the editor knows.
function E.Seed(frame, piece)
    local b = frame.buttons()[1]
    if not b then return {} end
    local shot = Snap(b, piece)[1]
    if not shot then return {} end
    local side = Side(b, frame)
    for _, pt in ipairs(shot.points) do
        local on = OnOf(b, pt[2])
        -- a point the game keeps secret cannot be stated as a place
        local readable = not ns.IsSecret(pt[3]) and (pt[4] == nil or Plain(pt[4])) and (pt[5] == nil or Plain(pt[5]))
        if on and readable then
            local h, v = Place(pt[3], side)
            local ph, pv = Place(pt[1], side)
            local seed = { h = h, v = v, on = on, x = -side * (pt[4] or 0), y = pt[5] or 0 }
            if ph ~= h or pv ~= v then seed.ph, seed.pv = ph, pv end
            return seed
        end
    end
    return {}
end

-- A piece's size, as the button has it.
function E.SizeOf(frame, piece)
    local b = frame.buttons()[1]
    local shot = b and Snap(b, piece)[1]
    if not shot then return nil end
    if shot.font then return shot.font[2] end
    return shot.w
end

-- ------------------------------------------------------------ apply
local OUTLINE = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }
E.OUTLINES = { { "none", "None" }, { "thin", "Thin" }, { "thick", "Thick" } }

local function Restore(r, shot, text)
    r:ClearAllPoints()
    -- a point whose offsets the game kept secret will not go back: the
    -- piece stays on the rest until its own code lays it again
    for _, pt in ipairs(shot.points) do pcall(r.SetPoint, r, unpack(pt)) end
    if text then
        r:SetWidth(0)
        if shot.justify then r:SetJustifyH(shot.justify) end
    elseif #shot.points == 0 and shot.w then
        r:SetSize(shot.w, shot.h)
    end
end

-- Whether a text was held between a left point and a right one: its words
-- then had that much room, not as much as they need.
local function Bounded(shot)
    local left, right
    for _, pt in ipairs(shot.points) do
        if pt[1]:match("LEFT$") then left = true elseif pt[1]:match("RIGHT$") then right = true end
    end
    return left and right
end

-- How a row's own code spaced it: the screen way it runs (1 right, -1
-- left) and the gap between its icons.
local function OwnRun(shot)
    local s1, s2 = shot[1].points[1], shot[2] and shot[2].points[1]
    local dir, gap = 1, 2
    if s1 and s2 and Plain(s1[4] or 0) and Plain(s2[4] or 0) then
        local d = (s2[4] or 0) - (s1[4] or 0)
        dir = d < 0 and -1 or 1
        gap = math.abs(d) - (shot[1].w or 0)
    end
    return dir, gap
end

-- One region placed at the edits' place on button b.
local function Put(b, r, e, side, dx)
    local on = OnRegion(b, e.on or "health")
    local p = Point(e.h or "center", e.v or "middle", side)
    local self = e.ph and Point(e.ph, e.pv, side) or p
    r:ClearAllPoints()
    r:SetPoint(self, on, p, -side * (e.x or 0) + (dx or 0), e.y or 0)
    return p, on
end

-- A row: the first icon at the place (else it stays at its own), the rest
-- after it the way the row grows, a new line every cols icons, the new
-- line away from the edge the first hangs on. The rest hang from the
-- first, so a move of it moves them all.
local function Row(b, regions, shot, e, side)
    local own, gap = OwnRun(shot)
    if e.h then Put(b, regions[1], e, side) end
    local dx, dy = own, 0
    if e.grow == "up" then dx, dy = 0, 1
    elseif e.grow == "down" then dx, dy = 0, -1
    elseif e.grow == "outer" then dx = side
    elseif e.grow == "inner" then dx = -side end
    local point = regions[1]:GetPoint(1)
    if type(point) ~= "string" or ns.IsSecret(point) then point = "CENTER" end
    local wx, wy = 0, point:find("BOTTOM") and 1 or -1
    if dx == 0 then wx, wy = point:find("RIGHT") and -1 or 1, 0 end
    local cols = e.cols or #regions
    local step = (e.size or shot[1].w or 0) + gap
    for i = 2, #regions do
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        local r = regions[i]
        r:ClearAllPoints()
        r:SetPoint("CENTER", regions[1], "CENTER", (dx * col + wx * line) * step, (dy * col + wy * line) * step)
    end
end

-- A row's own way (as the editor names it) and length, as the frame's
-- first button has them: what its Grow and Max show untouched.
function E.RowOwn(frame, piece)
    local b = frame.buttons()[1]
    local list = b and PIECES[piece].get(b)
    if not list or not list[1] then return "inner", 1 end
    local dir = OwnRun(Snap(b, piece))
    return dir == Side(b, frame) and "outer" or "inner", list.default or #list
end

-- How many icons a row of button b shows: its frame's Max, else its own.
function ns.RowMax(b, piece)
    local list = PIECES[piece].get(b)
    if not list then return 0 end
    local frame = E.FrameOf(b)
    local e = frame and E.Edits(frame, piece)
    return math.min(#list, e and e.max or list.default or #list)
end

-- Every piece of button b, as its frame's edits have it.
local function ApplyButton(frame, b)
    local side = Side(b, frame)
    b.editDone = b.editDone or {}
    for _, piece in ipairs(frame.pieces) do
        local spec = PIECES[piece]
        local regions = spec.type ~= "cell" and Regions(b, piece)
        if regions and regions[1] then
            local shot = Snap(b, piece)
            local e = E.Edits(frame, piece) or {}
            local done = b.editDone[piece] or {}
            -- the place
            if spec.type == "row" and (e.h or e.grow or e.cols) then
                Row(b, regions, shot, e, side)
                done.place = true
            elseif e.h then
                local p, on = Put(b, regions[1], e, side)
                if spec.type == "text" then
                    -- one point now: a text held between two keeps the
                    -- room it had (or what it hangs from has, less the
                    -- move), leaning the way it sits; one that sized to
                    -- its words still does
                    local r = regions[1]
                    if Bounded(shot[1]) then
                        local room = shot[1].w or 0
                        if room <= 0 then room = (on:GetWidth() or 0) - math.abs(e.x or 0) - 4 end
                        r:SetWidth(math.max(20, room))
                        r:SetJustifyH(p:match("LEFT") and "LEFT" or p:match("RIGHT") and "RIGHT" or "CENTER")
                    else
                        r:SetWidth(0)
                    end
                end
                done.place = true
            elseif done.place then
                for i, r in ipairs(regions) do Restore(r, shot[i], spec.type == "text") end
                done.place = nil
            end
            -- the size: an icon's square, a text's font
            if spec.type == "text" then
                local r, font = regions[1], shot[1].font
                if font and font[1] and (e.size or e.outline) then
                    r:SetFont(font[1], e.size or font[2], e.outline and OUTLINE[e.outline] or font[3])
                    done.font = true
                elseif done.font and font and font[1] then
                    r:SetFont(font[1], font[2], font[3])
                    done.font = nil
                end
            elseif e.size then
                for _, r in ipairs(regions) do r:SetSize(e.size, e.size) end
                done.size = true
            elseif done.size then
                for i, r in ipairs(regions) do r:SetSize(shot[i].w, shot[i].h) end
                done.size = nil
            end
            -- shown: an option's piece shows by its option (auras.lua);
            -- the rest are faded out, which their own code cannot undo
            if not (frame.shows and frame.shows[piece]) then
                local shown = e.shown
                if shown == nil then shown = not (frame.hidden and frame.hidden[piece]) end
                for _, r in ipairs(regions) do r:SetAlpha(shown and 1 or 0) end
            end
            b.editDone[piece] = next(done) and done or nil
        end
    end
end

-- A frame's buttons (all of them, or one) as its edits have them.
function E.Apply(frame, only)
    if not ns.db then return end
    for _, b in ipairs(only and { only } or frame.buttons()) do ApplyButton(frame, b) end
    if E.onApply then E.onApply(frame) end
end

-- One button, as the frame it is drawn as now: after its own code laid it.
function ns.ApplyEdits(b)
    local frame = E.FrameOf(b)
    if frame then E.Apply(frame, b) end
end

function E.ApplyAll()
    for _, frame in ipairs(E.FRAMES) do E.Apply(frame) end
end

-- ------------------------------------------------------------ text
-- A text piece's format on button b, and the longest a name may be.
function ns.EditFormat(b, piece)
    local frame = E.FrameOf(b)
    local e = frame and E.Edits(frame, piece)
    return e and e.format, e and e.len
end

-- A name cut to len letters (UTF-8), unless the game keeps it secret.
function ns.CutName(name, len)
    if not len or len <= 0 or ns.IsSecret(name) or type(name) ~= "string" then return name end
    local out, n = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > len then return table.concat(out) end
        out[n] = ch
    end
    return name
end

-- ------------------------------------------------------------ cells
-- A widget's cell size: the player's, or its own.
function ns.CellSize(id)
    local frame = byId[id]
    local e = E.Edits(frame, "cell")
    return e and e.w or frame.cell[1], e and e.h or frame.cell[2]
end

-- Whether a piece is drawn: an aura's by its option (the Unit Frames
-- page's), the rest by the frame's edits, else as the frame has it.
function E.Shown(frame, piece)
    local key = frame.shows and frame.shows[piece]
    if key then return ns.db[key] and true or false end
    local e = E.Edits(frame, piece)
    if e and e.shown ~= nil then return e.shown end
    return not (frame.hidden and frame.hidden[piece])
end

-- A frame's words and auras drawn again, so a new format or a row's new
-- Max shows at once rather than at the unit's next event.
local function Retext(frame)
    for _, b in ipairs(frame.buttons()) do
        if b.unit and (b.stub or UnitExists(b.unit)) then
            if b.editFrame then
                if ns.UpdateWidgetCell then ns.UpdateWidgetCell(b) end
            elseif ns.unitEvents then
                ns.unitEvents.UNIT_NAME_UPDATE(b)
                ns.unitEvents.UNIT_HEALTH(b)
                ns.unitEvents.UNIT_POWER_UPDATE(b)
                if ns.UpdateUnitAuras then ns.UpdateUnitAuras(b) end
            end
        end
    end
end

-- The widgets hear about their own frame's option; every frame's pieces
-- follow theirs.
for _, frame in ipairs(E.FRAMES) do
    ns.OnSetting(frame.key, function()
        E.Apply(frame)
        Retext(frame)
    end)
end
ns.OnSetting("partyLayout", function() E.ApplyAll() end)
ns.On("PLAYER_LOGIN", function() E.ApplyAll() end)
