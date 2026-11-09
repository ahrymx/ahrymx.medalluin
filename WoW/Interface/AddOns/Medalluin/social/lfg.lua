-- The LFG / Who window: Medalluin's own, in one box standing on the chat box
-- (strips/chat.lua) where the quest tracker's full view stands, up to the
-- screen's top, as the NPC windows' box does (npc/window.lua). The tracker
-- hides while it is open; it hides under the character window and the
-- bank, and an NPC window opening closes it.
--
--   Looking for group                                      [x]
--   [   Browse   |   List me   |    Who    ]       <- the pages
--   ---------------------------------------------------------
--   Browse   [Dungeons v] [All activities (4) v]      (category, activities)
--            [search          ]        Need: (T)(H)(D)
--            - Groups (2)
--              Ash White  Lvl 26          (T)(H)(D)(D)  4/5   3m
--              Stormwind Stockades        (the activity, its difficulty)
--              Competitive  "the note"    (the playstyle, its colour)
--              (a click opens a group: its members, [Send message])
--            - Players (3)
--              Ilrana  Lvl 22                  Roles: (H)(D)   5m
--   List me  [Tank|Healer|Damage] [New players]
--            [Dungeons|Quests|PvP|Custom]
--            [Playstyle (required) v]            [ ] All level ranges
--            [-] Dungeons . 2 of 4               (the activity group, ticks all)
--                [v] Blackfathom Deeps     24-32
--            Note  (the game's own box: the game reads the note from it)
--            Voice chat [None v]
--            Listed 4m ago . Relaxed
--   Who      [query box]
--            [Class v] [Race v] [Zone v] [Sort: Name v]
--            [My zone|My level +-3|My guild] [Clear]
--            38 people found
--            Arlenne                         Westfall   [Invite]
--            Level 24  Gnome  Mage           <Silver Hand>
--   ---------------------------------------------------------
--   [ Refresh ] [ Send message | Invite ] [ Delist ]   (each page its own)
--   [General][Trade]                       <- the chat box under it
--
-- LFG is Forever's group finder (social/lfgdata.lua); on retail the game's
-- Group Finder stays and only Who is here. Blizzard's frames keep every
-- way in: the LFG frame (LFGParentFrame, its addon loaded at login) is
-- parked under a hidden parent (ns.Park) and followed, so the micro
-- button, its key and the game open and close ours; the Friends window's
-- Who tab (and /who's long answers) opens the Who page instead.
--
-- The note is Blizzard's own box (LFGListingComment): the game reads a
-- listing's note from it alone, and no addon may set its words. It stands
-- in List me, moved there, for the player to type in.
local _, ns = ...

local L = ns.stripLayout
local D = ns.lfgData
local WIDTH = L.chatLeft + L.chatWidth
local PAD, HEAD, TABS, BAND, CONTROL = 12, 36, 26, 28, 16
local INNER = WIDTH - 2 * PAD                   -- a page's width
local GUTTER = 10
local RESULT, MEMBER, ACTIONS = 56, 17, 32      -- a result's row, a member's line under it, its buttons
local PERSON = 34                               -- a Who row
local ROW, FOLD, PICK = 20, 24, 22              -- an activity's row, a fold, a dropdown
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local RED = { 0.86, 0.27, 0.22 }
local UNPICKED = { 0.8, 0.77, 0.69 }
local GREEN = { 0.43, 0.78, 0.35 }
local ROLES = { "TANK", "HEALER", "DAMAGER" }
local FIELD = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
local ROLE_WORD = { tank = "Tank", healer = "Healer", dps = "Damage" }
local COORDS = ns.ROLE_COORDS or { TANK = { 0, 0.25, 0, 1 }, HEALER = { 0.25, 0.5, 0, 1 },
    DAMAGER = { 0.5, 0.75, 0, 1 } }
local ART = ns.media .. "role-icons"
local ROUND = ns.media .. "strips\\round"
local SLOT, SLOTS = 18, 5                       -- a result's role slots: their pitch, how many
local MEDAL = 34                                -- List me's role medallions
local NOTE = 255                                -- a listing's note, at most
local TICK, SOME = "\226\156\148", "\226\128\147"

local lfg = {}
ns.lfg = lfg

local box, title, close, tabs, band
local current
local wanted = false
local covers = {}
local dirty = true
local syncing = false

-- ------------------------------------------------------------------ helpers
local function Glyph(b, name, size)
    b.icon = b.icon or b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(size or CONTROL, size or CONTROL)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(ns.media .. "strips\\" .. name)
end

local function Tip(owner, spec) ns.Tip(owner, ns.window.Outside, spec) end

local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], a * 0.1))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.55)
    end
end

local function Diff(level)
    local c = level and level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    if c then return { c.r, c.g, c.b } end
    return ns.colors.text
end

local function ClassColour(file)
    local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c then return { c.r, c.g, c.b } end
    return ns.colors.text
end

local function Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local function Age(s)
    s = math.max(0, math.floor(s or 0))
    if s < 60 then return "now" end
    if s < 3600 then return math.floor(s / 60) .. "m" end
    return math.floor(s / 3600) .. "h"
end
lfg.Age = Age

local function Range(min, max)
    if not min or min <= 0 then return "" end
    return min == max and tostring(min) or (min .. SOME .. max)
end

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- A role in the unit frames' art (media/role-icons): "on", in its
-- colours; "ghost", a role a group still wants (grey, faint); "off", not
-- wanted (grey); "empty", an open place no role is asked for (a dot).
local function RoleIcon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.art = f:CreateTexture(nil, "ARTWORK")
    f.art:SetAllPoints()
    f.art:SetTexture(ART)
    f.dot = f:CreateTexture(nil, "ARTWORK")
    f.dot:SetSize(6, 6)
    f.dot:SetPoint("CENTER")
    f.dot:SetTexture(ROUND)
    f.dot:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    function f:Set(role, state)
        self.role, self.state = role, state
        self.dot:SetShown(state == "empty")
        self.art:SetShown(state ~= "empty")
        if state == "empty" then return end
        self.art:SetTexCoord(unpack(COORDS[role] or COORDS.DAMAGER))
        if self.art.SetDesaturated then self.art:SetDesaturated(state ~= "on") end
        self.art:SetAlpha(state == "on" and 1 or state == "ghost" and 0.35 or 0.45)
    end
    return f
end

-- A role's medallion (List me): the role's art in a gold rim
-- (ns.window.Ring); chosen, the rim bright and a glow behind it; not, the
-- rim dark and the art grey; a role the class cannot take, faint.
local function Medallion(parent, role)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(MEDAL, MEDAL)
    b.halo = b:CreateTexture(nil, "BACKGROUND")
    b.halo:SetSize(MEDAL + 18, MEDAL + 18)
    b.halo:SetPoint("CENTER")
    b.halo:SetTexture(ROUND)
    b.halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.22)
    if b.halo.SetBlendMode then b.halo:SetBlendMode("ADD") end
    b.art = ns.window.Ring(b, MEDAL - 10)
    b.art:SetPoint("CENTER")
    b.art:SetTexture(ART)
    b.art:SetTexCoord(unpack(COORDS[role]))
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetSize(MEDAL, MEDAL)
    glow:SetPoint("CENTER")
    glow:SetTexture(ROUND)
    glow:SetVertexColor(1, 1, 1, 0.08)
    b.role = role
    function b:Set(on, can)
        self.on, self.can = on and true or false, can ~= false
        local rim = on and GOLD or GOLD_D
        self.art.rim:SetColorTexture(rim[1], rim[2], rim[3], 1)
        self.halo:SetShown(on and true or false)
        if self.art.SetDesaturated then self.art:SetDesaturated(not on) end
        self.art:SetAlpha(not self.can and 0.25 or on and 1 or 0.55)
    end
    return b
end

-- A heading: its word in small capitals, gold, a count dim after it, and
-- a rule fading out to the right; s:Right(frame) stops the rule short of
-- something standing at its end (a tick, a count).
local function Section(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetHeight(18)
    s.word = ns.Text(s, 12)
    s.word:SetPoint("LEFT", 2, 0)
    s.word:SetTextColor(unpack(GOLD))
    s.count = ns.Text(s, 11)
    s.count:SetPoint("LEFT", s.word, "RIGHT", 6, 0)
    s.count:SetTextColor(unpack(DIM))
    s.rule = s:CreateTexture(nil, "ARTWORK")
    s.rule:SetHeight(1)
    s.rule:SetPoint("LEFT", s.count, "RIGHT", 10, 0)
    s.rule:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    Fade(s.rule, GOLD_D, 1)
    function s:Set(word, count)
        self.word:SetText(word)
        self.count:SetText(count and ("\194\183  " .. count) or "")
    end
    function s:Right(f) self.rule:SetPoint("RIGHT", f, "LEFT", -10, 0) end
    return s
end

-- An edit box in the windows' face, its words plain
local function Input(parent, name, height)
    local well = CreateFrame("Frame", nil, parent)
    well:SetHeight(height)
    ns.window.Face(well)
    local e = CreateFrame("EditBox", name, well)
    e:SetPoint("TOPLEFT", 6, 0)
    e:SetPoint("BOTTOMRIGHT", -6, 0)
    e:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    e:SetTextColor(unpack(ns.colors.text))
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    well.edit = e
    return well
end

-- A tick box: true, false or "some"
local function Tick(parent, size)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    ns.window.Face(f)
    f.mark = ns.PlainText(f, size - 3)
    f.mark:SetPoint("CENTER", 0, 0)
    f.mark:SetTextColor(unpack(GOLD))
    function f:Set(state)
        self.state = state
        self.mark:SetText(state == true and TICK or state == "some" and SOME or "")
    end
    return f
end

-- A dropdown: its words, and the options window's list under it (one list
-- for every dropdown, options/controls.lua); multi: several picks, the
-- list staying open.
--   Picker(parent, width, { text() -> words, choices() -> { { value, name,
--          tip } }, get, set(value), multi, on(value), tip })
local function Picker(parent, width, spec)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, PICK)
    local _, edge = ns.window.Face(b)
    b.edge = edge
    b.text = ns.PlainText(b, 12)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -22, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture(ns.media .. "options\\arrow")
    b.arrow:SetSize(14, 14)
    b.arrow:SetPoint("RIGHT", -4, 0)
    b.spec = spec
    b:SetScript("OnClick", function(self)
        local UI = ns.OptionsUI
        if not UI or self.off then return end
        local choices = {}
        for _, c in ipairs(spec.choices()) do table.insert(choices, { c.value, c.name, c.tip }) end
        UI.OpenMenu(self, { choices = choices, get = spec.get, multi = spec.multi, on = spec.on, set = function(v)
            spec.set(v)
            lfg.Refresh()
        end })
    end)
    b:SetScript("OnEnter", function(self)
        local tip = spec.tip and spec.tip()
        if tip then Tip(self, { title = tip, color = ns.colors.white, wrap = true }) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Update(warn, off)
        self.off = off
        self.text:SetText(spec.text())
        local c = off and DIM or warn and RED or ns.colors.text
        self.text:SetTextColor(c[1], c[2], c[3])
        if warn then self.edge:SetColorTexture(RED[1], RED[2], RED[3], 1)
        else self.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1) end
        self.arrow:SetAlpha(off and 0.3 or 1)
    end
    return b
end

-- ----------------------------------------------------------------- lists
-- A list of rows of several kinds, each kind pooled; scrolled a row at a
-- time with the wheel, its bar in the gutter at the left.
--   local l = List(parent, { Make(kind) -> row, Fill(row, item, n),
--                            Height(item), Kind(item) })
--   l:Set(items), l:Draw(), l:Scroll(by), l.frame, l.empty
local function List(parent, spec)
    local l = { items = {}, pools = {}, first = 0, shown = 0 }
    local f = CreateFrame("Frame", nil, parent)
    l.frame = f
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) l:Scroll(-delta * 3) end)
    f:SetScript("OnSizeChanged", function() l:Draw() end)
    local bar = f:CreateTexture(nil, "BORDER")
    bar:SetColorTexture(0, 0, 0, 0.35)
    bar:SetWidth(4)
    bar:SetPoint("TOPLEFT", 1, 0)
    bar:SetPoint("BOTTOMLEFT", 1, 0)
    local thumb = f:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    thumb:SetWidth(4)
    l.empty = ns.Text(f, 12)
    l.empty:SetPoint("TOPLEFT", GUTTER + 4, -8)
    l.empty:SetPoint("RIGHT", -8, 0)
    l.empty:SetJustifyH("LEFT")
    l.empty:SetTextColor(unpack(DIM))

    local function Take(kind, used)
        local pool = l.pools[kind] or {}
        l.pools[kind] = pool
        used[kind] = (used[kind] or 0) + 1
        local r = pool[used[kind]]
        if not r then
            r = spec.Make(kind, f)
            r:EnableMouseWheel(true)
            r:SetScript("OnMouseWheel", function(_, delta) l:Scroll(-delta * 3) end)
            pool[used[kind]] = r
        end
        return r
    end

    function l:Set(items)
        self.items = items
        if self.first > 0 and self.first >= #items then self.first = math.max(0, #items - 1) end
        self:Draw()
    end

    function l:Draw()
        local height = f:GetHeight() or 0
        local used, y, n = {}, 0, 0
        self.shown = 0
        for i = self.first + 1, #self.items do
            local item = self.items[i]
            local h = spec.Height(item)
            if y + h > height and self.shown > 0 then break end
            local kind = spec.Kind(item)
            if kind == "head" then n = 0 else n = n + 1 end
            local r = Take(kind, used)
            r.item = item
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", GUTTER, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r:SetHeight(h)
            spec.Fill(r, item, n)
            r:Show()
            y = y + h
            self.shown = self.shown + 1
        end
        for kind, pool in pairs(self.pools) do
            for i = (used[kind] or 0) + 1, #pool do pool[i]:Hide() end
        end
        local total = #self.items
        if total <= self.shown or self.shown == 0 then
            thumb:Hide()
        else
            local th = math.max(14, height * self.shown / total)
            thumb:SetHeight(th)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", bar, "TOP", 0, -(height - th) * math.min(1, self.first / (total - self.shown)))
            thumb:Show()
        end
    end

    function l:Scroll(by)
        self.first = math.max(0, math.min(self.first + by, #self.items - self.shown))
        self:Draw()
    end

    return l
end

-- a row's ground: hover; the picked one's gold wash, fading right, and
-- its edge; a hair under the others, parting them
local function Ground(r)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.05)
    r.mark = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.mark:SetAllPoints()
    Fade(r.mark, GOLD_D, 0.42)
    r.edge = r:CreateTexture(nil, "BORDER")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(2)
    r.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    r.sep = ns.window.Hair(r, false, 0.35)
    r.sep:SetPoint("BOTTOMLEFT", 20, 0)
    r.sep:SetPoint("BOTTOMRIGHT", -20, 0)
end

local function Picked(r, on, parted)
    r.mark:SetShown(on)
    r.edge:SetShown(on)
    r.sep:SetShown(parted ~= false and not on)
end

-- ================================================================ Browse
local browse = { folded = {}, activities = {} }  -- the sections folded; the activity filter, by category
local browseSel                                  -- the picked result's id
local need = {}                                  -- the role filter: results wanting any of these

local function Category()
    local cats = D.Categories()
    for _, c in ipairs(cats) do
        if c.id == ns.db.lfgCategory then return c.id, cats end
    end
    return cats[1] and cats[1].id, cats
end
lfg.Category = Category

local function Filtered(cat)
    browse.activities[cat] = browse.activities[cat] or {}
    return browse.activities[cat]
end

local function Search()
    local cat = Category()
    local ids = {}
    for id in pairs(Filtered(cat)) do table.insert(ids, id) end
    table.sort(ids)
    D.Search(cat, ids)
end
lfg.Search = Search

local function Words(r, words)
    if not words then return true end
    local hay = (r.name .. " " .. (r.leader.name or "") .. " " .. r.comment):lower()
    for w in words:gmatch("%S+") do
        if not hay:find(w, 1, true) then return false end
    end
    return true
end

-- a group needing a role, or a player offering one
local function Wants(r)
    local any = false
    for _, role in ipairs(ROLES) do
        if need[role] then
            any = true
            if r.solo and r.leader.roles[role] or not r.solo and r.needs[role] then return true end
        end
    end
    return not any
end

function browse.Lines()
    local words = browse.search:GetText() or ""
    words = words:match("%S") and words:lower() or nil
    local groups, players = {}, {}
    for _, r in ipairs(D.results) do
        if Words(r, words) and Wants(r) then table.insert(r.solo and players or groups, r) end
    end
    local out = {}
    for _, s in ipairs({ { "groups", "Groups", groups }, { "players", "Players", players } }) do
        if #s[3] > 0 then
            table.insert(out, { head = s[1], label = s[2], n = #s[3] })
            if not browse.folded[s[1]] then
                for _, r in ipairs(s[3]) do table.insert(out, { result = r }) end
            end
        end
    end
    return out, words, #groups + #players
end

local function Selected()
    for _, r in ipairs(D.results) do
        if r.id == browseSel then return r end
    end
end
lfg.Selected = Selected

-- a section's head in the list (Groups, Players): a fold sign, its word,
-- its count, the rule fading off
local function SectionRow(r)
    r.sign = ns.Text(r, 13)
    r.sign:SetPoint("LEFT", 4, 0)
    r.sign:SetTextColor(unpack(GOLD))
    r.word = ns.Text(r, 12)
    r.word:SetPoint("LEFT", 18, 0)
    r.word:SetTextColor(unpack(GOLD))
    r.count = ns.Text(r, 11)
    r.count:SetPoint("LEFT", r.word, "RIGHT", 6, 0)
    r.count:SetTextColor(unpack(DIM))
    r.rule = r:CreateTexture(nil, "ARTWORK")
    r.rule:SetHeight(1)
    r.rule:SetPoint("LEFT", r.count, "RIGHT", 10, 0)
    r.rule:SetPoint("RIGHT", -4, 0)
    Fade(r.rule, GOLD_D, 1)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.04)
    r:SetScript("OnClick", function(self)
        local k = self.item.head
        browse.folded[k] = not browse.folded[k] or nil
        lfg.Refresh()
    end)
end

local function Member(r, i)
    local m = r.people[i]
    if m then return m end
    m = CreateFrame("Frame", nil, r)
    m:SetHeight(MEMBER)
    m.icon = RoleIcon(m, 13)
    m.icon:SetPoint("LEFT", 0, 0)
    m.name = ns.PlainText(m, 11)
    m.name:SetPoint("LEFT", 20, 0)
    m.what = ns.PlainText(m, 11)
    m.what:SetPoint("LEFT", 190, 0)
    m.what:SetTextColor(unpack(DIM))
    r.people[i] = m
    return m
end

-- A result: on the left its leader (class colour, level), the activity
-- (its difficulty's colour), the playstyle (its dot and colour) and the
-- note; on the right, a column of its own: the role slots, and under them
-- the size and how long ago.
local function ResultRow(kind, parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if kind == "head" then
        SectionRow(r)
        return r
    end
    Ground(r)
    r.name = ns.PlainText(r, 13)
    r.name:SetPoint("TOPLEFT", 10, -5)
    r.lvl = ns.PlainText(r, 11)
    r.lvl:SetPoint("LEFT", r.name, "RIGHT", 7, 0)
    r.lvl:SetTextColor(unpack(DIM))
    r.new = ns.Text(r, 10)
    r.new:SetPoint("LEFT", r.lvl, "RIGHT", 8, 0)
    r.new:SetTextColor(unpack(GREEN))
    r.new:SetText("new players welcome")
    r.act = ns.PlainText(r, 11)
    r.act:SetPoint("TOPLEFT", 10, -22)
    r.act:SetPoint("RIGHT", -(SLOTS * SLOT + 14), 0)
    r.act:SetJustifyH("LEFT")
    r.act:SetWordWrap(false)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetTexture(ROUND)
    r.dot:SetPoint("TOPLEFT", 11, -43)
    r.style = ns.PlainText(r, 11)
    r.style:SetPoint("TOPLEFT", 22, -40)
    r.style:SetPoint("RIGHT", -8, 0)
    r.style:SetJustifyH("LEFT")
    r.style:SetWordWrap(false)
    r.slots = {}
    for i = 1, SLOTS do
        local d = RoleIcon(r, 16)
        d:SetPoint("TOPRIGHT", -(8 + (SLOTS - i) * SLOT), -6)
        r.slots[i] = d
    end
    r.meta = ns.PlainText(r, 11)
    r.meta:SetPoint("TOPRIGHT", -8, -25)
    r.meta:SetTextColor(unpack(DIM))
    r.people = {}
    r.actions = ns.window.Segments(r, { height = 22, size = 11, fit = true, items = {
        { key = "message", label = "Send message", group = "m", click = function()
            if r.item then D.Message(r.item.result.leader.name) end
        end, tip = function() return "Whisper the group's leader." end },
    } })
    r.actions:SetPoint("BOTTOMLEFT", 28, 6)
    r:SetScript("OnClick", function(self, mouse)
        local res = self.item.result
        if mouse == "RightButton" then
            D.Message(res.leader.name)
            return
        end
        browseSel = browseSel ~= res.id and res.id or nil
        lfg.Refresh()
    end)
    r:SetScript("OnEnter", function(self)
        local res = self.item.result
        local ps = D.PlaystyleName(res.playstyle)
        Tip(self, { title = res.leader.name, color = ClassColour(res.leader.class), wrap = true,
            { "row", res.solo and "Looking for" or "Doing", res.name, true },
            { "row", "Levels", Range(res.min, res.max), true },
            ps and { "row", "Playstyle", ps, true } or false,
            res.voice and res.voice ~= 0 and D.VoiceName(res.voice) and { "row", "Voice", D.VoiceName(res.voice), true }
                or false,
            res.newPlayers and { "body", "New players welcome.", GREEN } or false,
            res.comment ~= "" and { "body", "\"" .. res.comment .. "\"" } or false,
            { "hint", (res.solo and "Click: pick." or "Click: its members.") .. " Right click: whisper." } })
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- The slots, left to right: a group's members by role (tanks, healers,
-- damage), then the roles it still wants (ghosts), then its open places
-- (dots), up to its size; a raid, past five: each role once, there or
-- wanted. A player: the roles offered, at the right.
local function Slots(res)
    local out = {}
    if res.solo then
        for _, role in ipairs(ROLES) do if res.leader.roles[role] then table.insert(out, { role, "on" }) end end
        return out
    end
    local have = {}
    for _, m in ipairs(res.members) do
        local role = m.role or "DAMAGER"
        have[role] = (have[role] or 0) + 1
    end
    if res.size > SLOTS then
        for _, role in ipairs(ROLES) do
            if have[role] then table.insert(out, { role, "on" })
            elseif res.needs[role] then table.insert(out, { role, "ghost" }) end
        end
        return out
    end
    for _, role in ipairs(ROLES) do
        for _ = 1, have[role] or 0 do table.insert(out, { role, "on" }) end
    end
    for _, role in ipairs(ROLES) do
        if res.needs[role] and #out < res.size then table.insert(out, { role, "ghost" }) end
    end
    while #out < math.min(res.size, SLOTS) do table.insert(out, { "DAMAGER", "empty" }) end
    return out
end
lfg.Slots = Slots

local function FillResult(r, item)
    if item.head then
        r.sign:SetText(browse.folded[item.head] and "+" or "\226\136\146")
        r.word:SetText(item.label)
        r.count:SetText("\194\183  " .. item.n)
        return
    end
    local res = item.result
    local open = browseSel == res.id
    Picked(r, open)
    r.name:SetText(res.leader.name .. (res.self and "  (you)" or ""))
    r.name:SetTextColor(unpack(ClassColour(res.leader.class)))
    r.lvl:SetText(res.leader.level and tostring(res.leader.level) or "")
    r.new:SetShown(res.newPlayers)
    local c = Diff(res.max)
    r.act:SetText(res.name)
    r.act:SetTextColor(c[1], c[2], c[3])
    local ps = D.PlaystyleName(res.playstyle)
    local pc = D.PlaystyleColour(res.playstyle)
    r.dot:SetShown(ps ~= nil)
    r.dot:SetVertexColor(pc[1], pc[2], pc[3], 1)
    local style = ps and (Hex(pc) .. ps .. "|r") or ""
    if res.comment ~= "" then style = style .. (ps and "   " or "") .. Hex(DIM) .. "\"" .. res.comment .. "\"|r" end
    r.style:ClearAllPoints()
    r.style:SetPoint("TOPLEFT", ps and 22 or 10, -40)
    r.style:SetPoint("RIGHT", -8, 0)
    r.style:SetText(style)
    -- the right column: the slots, right-aligned; the size and the age
    local slots = Slots(res)
    for i, d in ipairs(r.slots) do
        local slot = slots[i - (SLOTS - #slots)]
        d:SetShown(slot ~= nil)
        if slot then d:Set(slot[1], slot[2]) end
    end
    local age = Age(res.age + (GetTime() - (D.searchedAt or GetTime())))
    r.meta:SetText(res.solo and age or (res.count .. "/" .. res.size .. "  \194\183  " .. age))
    local members = open and not res.solo
    for i, m in ipairs(r.people) do m:SetShown(members and i <= #res.members) end
    if members then
        for i, who in ipairs(res.members) do
            local m = Member(r, i)
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", 28, -(RESULT + (i - 1) * MEMBER))
            m:SetPoint("RIGHT", -8, 0)
            m.icon:Set(who.role or "DAMAGER", "on")
            m.name:SetText((who.name or "?") .. (who.leader and "  (leader)" or ""))
            m.name:SetTextColor(unpack(ClassColour(who.class)))
            m.what:SetText(((who.level and who.level .. "  ") or "") .. (who.className or ""))
            m:Show()
        end
    end
    r.actions:SetShown(members)
end

function browse.Build(page)
    browse.cat = Picker(page, 150, {
        text = function()
            local cat, cats = Category()
            for _, c in ipairs(cats) do if c.id == cat then return c.name end end
            return "No categories"
        end,
        choices = function()
            local out = {}
            for _, c in ipairs(D.Categories()) do table.insert(out, { value = c.id, name = c.name }) end
            return out
        end,
        get = function() return (Category()) end,
        set = function(v)
            ns.db.lfgCategory = v
            browseSel = nil
            browse.list.first = 0
            Search()
        end,
        tip = function() return "What the groups and players are listed for." end,
    })
    browse.cat:SetPoint("TOPLEFT", 0, 0)
    browse.acts = Picker(page, INNER - 156, {
        text = function()
            local n = Count(Filtered(Category()))
            return n == 0 and ("All activities  (" .. #D.Activities(Category()) .. ")") or (n .. " picked")
        end,
        choices = function()
            local out = {}
            for _, a in ipairs(D.Activities(Category())) do
                table.insert(out, { value = a.id, name = a.name .. "  " .. Range(a.min, a.max) })
            end
            return out
        end,
        multi = true,
        on = function(v) return Filtered(Category())[v] end,
        set = function(v)
            local f = Filtered(Category())
            f[v] = not f[v] or nil
            browseSel = nil
            Search()
        end,
        tip = function() return "Only these activities: none picked, every one that suits your level." end,
    })
    browse.acts:SetPoint("TOPRIGHT", 0, 0)
    local filter = CreateFrame("Frame", nil, page)
    filter:SetHeight(22)
    filter:SetPoint("TOPLEFT", 0, -30)
    filter:SetPoint("TOPRIGHT", 0, -30)
    browse.discs = {}
    for i, role in ipairs(ROLES) do
        local b = CreateFrame("Button", nil, filter)
        b:SetSize(22, 22)
        b:SetPoint("RIGHT", -((3 - i) * 26 + 2), 0)
        b.icon = RoleIcon(b, 20)
        b.icon:SetPoint("CENTER")
        b.icon:Set(role, "off")
        b:SetScript("OnClick", function()
            need[role] = not need[role] or nil
            lfg.Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            local word = role == "TANK" and "tank" or role == "HEALER" and "healer" or "damage dealer"
            Tip(self, { title = "Groups that need a " .. word .. ", players who offer it",
                { "hint", "None lit: everyone." } })
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.role = role
        browse.discs[i] = b
    end
    local needs = ns.Text(filter, 11)
    needs:SetText("Need")
    needs:SetTextColor(unpack(DIM))
    needs:SetPoint("RIGHT", browse.discs[1], "LEFT", -8, 0)
    browse.search = CreateFrame("EditBox", "MedalluinLFGSearch", filter, "SearchBoxTemplate")
    browse.search:SetHeight(20)
    browse.search:SetPoint("LEFT", 6, 0)
    browse.search:SetPoint("RIGHT", needs, "LEFT", -14, 0)
    browse.search:SetAutoFocus(false)
    browse.search:HookScript("OnTextChanged", function()
        browse.list.first = 0
        lfg.Refresh()
    end)
    browse.list = List(page, {
        Make = ResultRow, Fill = FillResult, Kind = function(item) return item.head and "head" or "result" end,
        Height = function(item)
            if item.head then return FOLD end
            local res = item.result
            if browseSel ~= res.id or res.solo then return RESULT end
            return RESULT + #res.members * MEMBER + ACTIONS
        end,
    })
    browse.list.frame:SetPoint("TOPLEFT", 0, -60)
    browse.list.frame:SetPoint("BOTTOMRIGHT")
end

function browse.Refresh()
    browse.cat:Update()
    browse.acts:Update()
    for _, b in ipairs(browse.discs) do b.icon:Set(b.role, need[b.role] and "on" or "off") end
    if browseSel and not Selected() then browseSel = nil end
    local lines, words, n = browse.Lines()
    browse.list:Set(lines)
    browse.list.empty:SetShown(#lines == 0)
    browse.list.empty:SetText(D.searching and "Searching\226\128\166"
        or #D.results == 0 and "Nobody is listed here. Refresh, or list yourself (List me)."
        or n == 0 and (words and "Nobody listed has those words." or "Nobody listed needs those roles.") or "")
end

function browse.Band()
    local sel = Selected()
    local player = sel and sel.solo and not sel.self
    return {
        { key = "refresh", label = D.searching and "Searching\226\128\166" or "Refresh", group = "a",
            enabled = not D.searching, click = Search, tip = function() return "Ask for the listings again." end },
        { key = "message", label = "Send message", group = "b", enabled = sel ~= nil and not sel.self,
            click = function()
                local s = Selected()
                if s then D.Message(s.leader.name) end
            end,
            tip = function()
                return sel and ("Whisper " .. sel.leader.name .. ".") or "Pick someone in the list first."
            end },
        { key = "invite", label = "Invite", group = "b", enabled = player and D.CanInvite() or false, click = function()
            local s = Selected()
            if s and s.solo then D.Invite(s.leader.name) end
        end, tip = function()
            if not player then return "Pick a player (not a group) first." end
            return D.CanInvite() and ("Invite " .. sel.leader.name .. " to your group.")
                or "Only your group's leader can invite."
        end },
        { key = "delist", label = "Delist", group = "c", color = RED, shown = D.Entry() ~= nil,
            click = function() D.Delist() end, tip = function() return "Take your listing down." end },
    }
end

-- =============================================================== List me
local listme = { error = nil }
local prefilled = false

local function ListCategory()
    local cats = D.Categories()
    for _, c in ipairs(cats) do
        if c.id == ns.db.lfgListCategory then return c.id, cats end
    end
    return cats[1] and cats[1].id, cats
end

-- the picks within the category in hand: a listing is for one category
local function Listed()
    local picked = {}
    local t = ns.db.lfgListed or {}
    for _, a in ipairs(D.Activities(ListCategory())) do
        if t[a.id] then table.insert(picked, a.id) end
    end
    return picked
end
lfg.Listed = Listed

local function Asked()
    return { ids = Listed(), playstyle = ns.db.lfgPlaystyle or nil, voice = ns.db.lfgVoice or 0,
        newPlayers = ns.db.lfgNewPlayers and true or false }
end

-- listed already: the window says what the listing says
local function Prefill()
    local e = D.Entry()
    if not e then
        prefilled = false
        return
    end
    if prefilled then return end
    prefilled = true
    local t = {}
    for _, id in ipairs(e.activityIDs) do t[id] = true end
    ns.db.lfgListed = t
    local first = e.activityIDs[1] and D.Activity(e.activityIDs[1])
    if first and first.cat then ns.db.lfgListCategory = first.cat end
    if e.playstyle and e.playstyle ~= 0 then ns.db.lfgPlaystyle = e.playstyle end
    ns.db.lfgVoice = e.voice or 0
    ns.db.lfgNewPlayers = e.newPlayers
end

local function Pick(ids, on)
    local t = ns.db.lfgListed or {}
    for _, id in ipairs(ids) do t[id] = on or nil end
    ns.db.lfgListed = t
    listme.error = nil
    lfg.Refresh()
end

local function ActivityRow(kind, parent)
    local r = CreateFrame("Button", nil, parent)
    if kind == "head" then
        r.fill = r:CreateTexture(nil, "BACKGROUND")
        r.fill:SetPoint("TOPLEFT", 0, -1)
        r.fill:SetPoint("BOTTOMRIGHT", 0, 1)
        r.fill:SetColorTexture(1, 1, 1, 0.035)
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.04)
        r.tick = Tick(r, 14)
        r.tick:SetPoint("LEFT", 8, 0)
        r.word = ns.Text(r, 12)
        r.word:SetPoint("LEFT", 30, 0)
        r.word:SetTextColor(unpack(GOLD))
        r.count = ns.Text(r, 11)
        r.count:SetPoint("LEFT", r.word, "RIGHT", 6, 0)
        r.count:SetTextColor(unpack(DIM))
        local function All()
            local item = r.item
            Pick(item.ids, item.state ~= true)
        end
        r:SetScript("OnClick", All)
        r.tick:SetScript("OnClick", All)
        return r
    end
    Ground(r)
    r.tick = Tick(r, 14)
    r.tick:SetPoint("LEFT", 24, 0)
    r.name = ns.PlainText(r, 12)
    r.name:SetPoint("LEFT", 46, 0)
    r.range = ns.PlainText(r, 11)
    r.range:SetPoint("RIGHT", -6, 0)
    local function One()
        local a = r.item.activity
        Pick({ a.id }, not (ns.db.lfgListed or {})[a.id])
    end
    r:SetScript("OnClick", One)
    r.tick:SetScript("OnClick", One)
    return r
end

local function FillActivity(r, item)
    if item.head then
        r.tick:Set(item.state)
        r.word:SetText(item.head)
        r.count:SetText("\194\183  " .. item.picked .. " of " .. #item.ids)
        return
    end
    -- the name plain, picked or not; the level range in its difficulty's colour
    local a = item.activity
    local on = (ns.db.lfgListed or {})[a.id] and true or false
    Picked(r, on, false)
    r.edge:Hide()
    r.tick:Set(on)
    local t = on and ns.colors.text or UNPICKED
    r.name:SetText(a.name)
    r.name:SetTextColor(t[1], t[2], t[3])
    local c = Diff(a.max)
    r.range:SetText(Range(a.min, a.max))
    r.range:SetTextColor(c[1], c[2], c[3])
end

-- Blizzard's note box, in List me: the game reads the note from it alone
local hosted
local function HostNote()
    local c = _G.LFGListingComment
    if not c or not listme.note then return false end
    if c:GetParent() ~= listme.note then
        c:SetParent(listme.note)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 6, -6)
        c:SetPoint("BOTTOMRIGHT", -24, 6)
        c:SetFrameLevel(listme.note:GetFrameLevel() + 2)
        c:Show()
        if c.EditBox and c.EditBox.SetWidth then c.EditBox:SetWidth(INNER - 36) end
    end
    if hosted ~= c then
        hosted = c
        local e = c.EditBox
        if e and e.HookScript then
            e:HookScript("OnTextChanged", function(self)
                local ok, text = pcall(self.GetText, self)
                listme.count:SetText((ok and #(text or "") or 0) .. " / " .. NOTE)
            end)
        end
    end
    return true
end
lfg.HostNote = HostNote

-- a tick and its words, one button: New players, All levels
local function Toggle(parent, words, tip, click)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    b.tick = Tick(b, 14)
    b.tick:SetPoint("LEFT", 0, 0)
    b.tick:EnableMouse(false)
    b.word = ns.Text(b, 11)
    b.word:SetPoint("LEFT", 20, 0)
    b.word:SetText(words)
    b:SetWidth(24 + math.ceil(b.word:GetStringWidth() or 0))
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", function(self) Tip(self, { title = tip(), color = ns.colors.white, wrap = true }) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function listme.Build(page)
    -- the roles: three medallions, the words of those chosen beside them
    listme.medals = {}
    for i, role in ipairs(ROLES) do
        local m = Medallion(page, role)
        m:SetPoint("TOPLEFT", (i - 1) * (MEDAL + 10), 0)
        local field = FIELD[role]
        m:SetScript("OnClick", function()
            D.SetRole(field, not D.Roles()[field])
            listme.error = nil
            lfg.Refresh()
        end)
        m:SetScript("OnEnter", function(self)
            local word = ROLE_WORD[field]
            local text
            if not self.can then text = "Your class cannot take this role."
            elseif D.Roles().group then text = "Your role in your group: click to take it."
            else text = self.on and "You list as this: click to stop." or "Click to list yourself as this too." end
            Tip(self, { title = word, color = GOLD, wrap = true, { "body", text } })
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        listme.medals[i] = m
    end
    listme.chosen = ns.Text(page, 12)
    listme.chosen:SetPoint("TOPLEFT", 3 * (MEDAL + 10) + 4, -6)
    listme.as = ns.Text(page, 10)
    listme.as:SetPoint("TOPLEFT", listme.chosen, "BOTTOMLEFT", 0, -3)
    listme.as:SetTextColor(unpack(DIM))
    listme.new = Toggle(page, "New players welcome",
        function() return "Groups and players new to the game are welcome to join you." end,
        function()
            ns.db.lfgNewPlayers = not ns.db.lfgNewPlayers
            lfg.Refresh()
        end)
    listme.new.word:SetTextColor(unpack(GREEN))
    listme.new:SetPoint("TOPRIGHT", 0, -8)
    -- what for: the category, the playstyle
    listme.wants = Section(page)
    listme.wants:SetPoint("TOPLEFT", 0, -44)
    listme.wants:SetPoint("TOPRIGHT", 0, -44)
    listme.wants:Set("Looking for")
    listme.cat = Picker(page, 170, {
        text = function()
            local cat, cats = ListCategory()
            for _, c in ipairs(cats) do if c.id == cat then return c.name end end
            return "No categories"
        end,
        choices = function()
            local out = {}
            for _, c in ipairs(D.Categories()) do table.insert(out, { value = c.id, name = c.name }) end
            return out
        end,
        get = function() return (ListCategory()) end,
        set = function(v)
            ns.db.lfgListCategory = v
            listme.list.first = 0
            listme.error = nil
        end,
        tip = function() return "A listing is for one category." end,
    })
    listme.cat:SetPoint("TOPLEFT", 0, -66)
    listme.style = Picker(page, INNER - 178, {
        text = function()
            local e = D.Entry()
            local v = e and e.playstyle or ns.db.lfgPlaystyle
            return D.PlaystyleName(v) or "Playstyle (required)"
        end,
        choices = function()
            local out = {}
            for _, p in ipairs(D.PLAYSTYLES) do
                table.insert(out, { value = p.value, name = D.PlaystyleName(p.value) })
            end
            return out
        end,
        get = function() return ns.db.lfgPlaystyle end,
        set = function(v)
            ns.db.lfgPlaystyle = v
            listme.error = nil
        end,
        tip = function()
            return D.Entry() and "A listing keeps its playstyle: delist to change it."
                or "How you mean to play: the game asks for one."
        end,
    })
    listme.style:SetPoint("TOPRIGHT", 0, -66)
    listme.styleDot = listme.style:CreateTexture(nil, "ARTWORK")
    listme.styleDot:SetSize(6, 6)
    listme.styleDot:SetTexture(ROUND)
    listme.styleDot:SetPoint("RIGHT", -26, 0)
    -- the activities, All levels at the heading's end
    listme.acts = Section(page)
    listme.acts:SetPoint("TOPLEFT", 0, -98)
    listme.acts:SetPoint("TOPRIGHT", 0, -98)
    listme.all = Toggle(page, "All levels",
        function() return "Every activity, not only those that suit your level." end,
        function()
            D.SetShowAllLevels(not D.ShowAllLevels())
            lfg.Refresh()
        end)
    listme.all:SetPoint("RIGHT", listme.acts, "RIGHT", 0, 0)
    listme.acts:Right(listme.all)
    listme.list = List(page, {
        Make = ActivityRow, Fill = FillActivity,
        Kind = function(item) return item.head and "head" or "act" end,
        Height = function(item) return item.head and FOLD or ROW end,
    })
    listme.list.frame:SetPoint("TOPLEFT", 0, -120)
    listme.list.frame:SetPoint("BOTTOMRIGHT", 0, 150)
    -- the note: Blizzard's own box, its count at the heading's end
    listme.notes = Section(page)
    listme.notes:SetPoint("BOTTOMLEFT", 0, 126)
    listme.notes:SetPoint("BOTTOMRIGHT", 0, 126)
    listme.notes:Set("Note")
    listme.count = ns.PlainText(page, 10)
    listme.count:SetPoint("RIGHT", listme.notes, "RIGHT", 0, 0)
    listme.count:SetTextColor(unpack(DIM))
    listme.count:SetText("0 / " .. NOTE)
    listme.notes:Right(listme.count)
    listme.note = CreateFrame("Frame", nil, page)
    listme.note:SetPoint("BOTTOMLEFT", 0, 58)
    listme.note:SetPoint("BOTTOMRIGHT", 0, 58)
    listme.note:SetHeight(62)
    ns.window.Face(listme.note)
    listme.missing = ns.Text(listme.note, 11)
    listme.missing:SetPoint("TOPLEFT", 8, -8)
    listme.missing:SetPoint("RIGHT", -8, 0)
    listme.missing:SetJustifyH("LEFT")
    listme.missing:SetTextColor(unpack(DIM))
    listme.missing:SetText("The game's note box is not loaded: the listing goes up without a note.")
    local voice = ns.Text(page, 12)
    voice:SetText("Voice")
    voice:SetTextColor(unpack(GOLD))
    voice:SetPoint("BOTTOMLEFT", 4, 30)
    listme.voice = Picker(page, 170, {
        text = function() return D.VoiceName(ns.db.lfgVoice or 0) or "None" end,
        choices = function()
            local out = {}
            for _, v in ipairs(D.VOICES) do table.insert(out, { value = v.value, name = v.name }) end
            return out
        end,
        get = function() return ns.db.lfgVoice or 0 end,
        set = function(v) ns.db.lfgVoice = v end,
        tip = function() return "Where your group talks." end,
    })
    listme.voice:SetPoint("BOTTOMLEFT", 56, 26)
    listme.status = ns.Text(page, 11)
    listme.status:SetPoint("BOTTOMLEFT", 4, 4)
    listme.status:SetPoint("RIGHT", -4, 0)
    listme.status:SetJustifyH("LEFT")
end

function listme.Lines()
    local out, heads = {}, {}
    local cat, cats = ListCategory()
    local name = ""
    for _, c in ipairs(cats) do if c.id == cat then name = c.name end end
    local picked = ns.db.lfgListed or {}
    for _, a in ipairs(D.Activities(cat)) do
        local key = a.group or name
        local h = heads[key]
        if not h then
            h = { head = key, ids = {}, picked = 0 }
            heads[key] = h
            table.insert(out, h)
        end
        table.insert(h.ids, a.id)
        if picked[a.id] then h.picked = h.picked + 1 end
        table.insert(out, { activity = a, under = h })
    end
    for _, h in pairs(heads) do
        if h.picked == 0 then h.state = false else h.state = h.picked == #h.ids or "some" end
    end
    return out
end

function listme.Refresh()
    Prefill()
    local r, can = D.Roles(), D.Available()
    local words = {}
    for i, role in ipairs(ROLES) do
        local field = FIELD[role]
        listme.medals[i]:Set(r[field], can[field])
        if r[field] then table.insert(words, ROLE_WORD[field]) end
    end
    listme.chosen:SetText(#words > 0 and table.concat(words, "  \194\183  ") or "No role yet")
    listme.chosen:SetTextColor(unpack(#words > 0 and GOLD or RED))
    listme.as:SetText(r.group and "your role in the group" or "you list as")
    listme.new.tick:Set(ns.db.lfgNewPlayers and true or false)
    local e = D.Entry()
    listme.cat:Update(nil, e ~= nil)
    listme.style:Update(not e and not ns.db.lfgPlaystyle, e ~= nil)
    local v = e and e.playstyle or ns.db.lfgPlaystyle
    local pc = D.PlaystyleColour(v)
    listme.styleDot:SetShown(D.PlaystyleName(v) ~= nil)
    listme.styleDot:SetVertexColor(pc[1], pc[2], pc[3], 1)
    listme.voice:Update()
    listme.all.tick:Set(D.ShowAllLevels())
    listme.acts:Set("Activities", #Listed() .. " of " .. #D.Activities(ListCategory()))
    local lines = listme.Lines()
    listme.list:Set(lines)
    listme.list.empty:SetShown(#lines == 0)
    listme.list.empty:SetText("Nothing here suits your level: tick All levels to see it all.")
    listme.missing:SetShown(not HostNote())
    local problem = D.Problem(Asked())
    local text, color
    if listme.error then
        text, color = listme.error, RED
    elseif D.expired and not e then
        text, color = D.expired .. (problem and ("  " .. problem) or ""), RED
    elseif e then
        local ago = e.age and Age(e.age)
        local bits = { ago == "now" and "Listed just now" or ago and ("Listed " .. ago .. " ago") or "Listed" }
        local ps = D.PlaystyleName(e.playstyle)
        if ps then table.insert(bits, ps) end
        if e.applicants > 0 then table.insert(bits, e.applicants .. " asked to join you") end
        text, color = table.concat(bits, "  \194\183  "), GREEN
        if problem then text = text .. "  \194\183  " .. problem end
    else
        text, color = problem and ("Not listed.  " .. problem) or "Ready to list.", problem and DIM or GREEN
    end
    listme.status:SetText(text)
    listme.status:SetTextColor(unpack(color))
end

function listme.Band()
    local e = D.Entry()
    local problem = D.Problem(Asked())
    return {
        { key = "post", label = e and "Update" or "List me", group = "a", enabled = problem == nil, click = function()
            local ok, why = D.Post(Asked())
            listme.error = not ok and why or nil
            lfg.Refresh()
        end, tip = function()
            return problem or (e and "List the new picks." or "List yourself, so groups and players can find you.")
        end },
        { key = "delist", label = "Delist", group = "b", color = e and RED or nil, enabled = e ~= nil and D.CanEdit(),
            click = function() D.Delist() end, tip = function() return "Take your listing down." end },
    }
end

-- ==================================================================== Who
local who = { filters = { classes = {}, races = {}, zones = {} } }
local whoSel

local function Me(name)
    local mine = UnitName and UnitName("player")
    return mine and name and (name == mine or name:match("^([^-]+)") == mine) or false
end

local function WhoRow(_, parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Ground(r)
    r.name = ns.PlainText(r, 13)
    r.name:SetPoint("TOPLEFT", 10, -3)
    r.what = ns.PlainText(r, 11)
    r.what:SetPoint("TOPLEFT", 10, -19)
    r.zone = ns.PlainText(r, 11)
    r.zone:SetPoint("TOPRIGHT", -62, -4)
    r.zone:SetWidth(150)
    r.zone:SetJustifyH("RIGHT")
    r.zone:SetWordWrap(false)
    r.guild = ns.PlainText(r, 11)
    r.guild:SetPoint("TOPRIGHT", -62, -18)
    r.guild:SetWidth(150)
    r.guild:SetJustifyH("RIGHT")
    r.guild:SetWordWrap(false)
    r.guild:SetTextColor(unpack(DIM))
    r.invite = ns.window.Button(r, 52, function() if r.item then D.Invite(r.item.name) end end,
        function() return r.item and ("Invite " .. r.item.name .. ".") or "" end)
    r.invite.label:SetText("Invite")
    r.invite:SetHeight(20)
    r.invite:SetPoint("RIGHT", -4, 0)
    r:SetScript("OnClick", function(self, mouse)
        local p = self.item
        if mouse == "RightButton" then
            D.Invite(p.name)
            return
        end
        if IsShiftKeyDown() then
            D.Message(p.name)
            return
        end
        whoSel = whoSel ~= p.name and p.name or nil
        lfg.Refresh()
    end)
    r:SetScript("OnEnter", function(self)
        local p = self.item
        Tip(self, { title = p.name, color = ClassColour(p.classFile),
            { "body", "Level " .. p.level .. " " .. p.race .. " " .. p.class },
            p.guild ~= "" and { "body", "<" .. p.guild .. ">" } or false, { "body", p.zone },
            { "hint", "Click: pick. Shift click: whisper. Right click: invite." } })
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function FillWho(r, p)
    Picked(r, whoSel == p.name)
    local cc = ClassColour(p.classFile)
    r.name:SetText(p.name)
    r.name:SetTextColor(cc[1], cc[2], cc[3])
    r.what:SetText(Hex(Diff(p.level)) .. "Level " .. p.level .. "|r  " .. Hex(ns.colors.text) .. p.race .. "|r  "
        .. Hex(cc) .. p.class .. "|r")
    r.zone:SetText(p.zone)
    r.guild:SetText(p.guild ~= "" and ("<" .. p.guild .. ">") or "")
    r.invite:SetShown(not Me(p.name))
end

local function Ask(text)
    who.query.edit:SetText(text or "")
    who.query.edit:ClearFocus()
    who.query.hint:SetShown((text or "") == "")
    whoSel = nil
    who.list.first = 0
    D.Who(text or "", who.filters)
end
lfg.Ask = Ask

local function Quick(kind)
    if kind == "zone" then return "z-\"" .. (GetZoneText and GetZoneText() or "") .. "\"" end
    if kind == "level" then
        local l = UnitLevel("player") or 1
        return math.max(1, l - 3) .. "-" .. (l + 3)
    end
    local g = GetGuildInfo and GetGuildInfo("player")
    return g and ("g-\"" .. g .. "\"") or ""
end
lfg.Quick = Quick

-- a filter's dropdown: several picks, the query asked again as they change
local function Filter(key, label, list)
    return Picker(who.page, math.floor((INNER - 18) / 4), {
        text = function()
            local n = Count(who.filters[key])
            return n == 0 and label or (label .. " (" .. n .. ")")
        end,
        choices = list, multi = true,
        on = function(v) return who.filters[key][v] end,
        set = function(v)
            who.filters[key][v] = not who.filters[key][v] or nil
            Ask(who.query.edit:GetText() or "")
        end,
        tip = function() return "Only these. None picked: any." end,
    })
end

function who.Build(page)
    who.page = page
    who.query = Input(page, "MedalluinWhoQuery", 24)
    who.query:SetPoint("TOPLEFT", 0, 0)
    who.query:SetPoint("TOPRIGHT", 0, 0)
    who.query.edit:SetScript("OnEnterPressed", function(self) Ask(self:GetText() or "") end)
    who.query.hint = ns.Text(who.query, 11)
    who.query.hint:SetPoint("LEFT", 8, 0)
    who.query.hint:SetText("A name, a guild, a zone, 20-30 ... then Enter")
    who.query.hint:SetTextColor(unpack(DIM))
    who.query.edit:HookScript("OnEditFocusGained", function() who.query.hint:Hide() end)
    who.query.edit:HookScript("OnEditFocusLost", function(self) who.query.hint:SetShown(self:GetText() == "") end)
    who.class = Filter("classes", "Class", function()
        local out = {}
        for _, c in ipairs(D.Classes()) do table.insert(out, { value = c.value, name = c.name }) end
        return out
    end)
    who.race = Filter("races", "Race", D.Races)
    who.zone = Filter("zones", "Zone", D.Zones)
    who.sort = Picker(page, math.floor((INNER - 18) / 4), {
        text = function()
            for _, s in ipairs(D.SORTS) do
                if s.value == (ns.db.lfgWhoSort or "name") then return "By " .. s.name:lower() end
            end
            return "By name"
        end,
        choices = function() return D.SORTS end,
        get = function() return ns.db.lfgWhoSort or "name" end,
        set = function(v)
            ns.db.lfgWhoSort = v
            D.SortWho(v, true)
        end,
        tip = function() return "The order the list comes in." end,
    })
    who.class:SetPoint("TOPLEFT", 0, -32)
    who.race:SetPoint("LEFT", who.class, "RIGHT", 6, 0)
    who.zone:SetPoint("LEFT", who.race, "RIGHT", 6, 0)
    who.sort:SetPoint("LEFT", who.zone, "RIGHT", 6, 0)
    local function Quickly(key, label, tip)
        return { key = key, label = label, group = "q", click = function() Ask(Quick(key)) end,
            tip = function() return tip end }
    end
    who.quick = ns.window.Segments(page, { height = 22, size = 11, soft = true, items = {
        Quickly("zone", "My zone", "Everyone in your zone."),
        Quickly("level", "My level \194\177" .. "3", "Everyone within three levels of yours."),
        Quickly("guild", "My guild", "Your guild's members online."),
        { key = "clear", label = "Clear", group = "x", color = RED, click = function()
            who.query.edit:SetText("")
            who.query.hint:Show()
            who.filters = { classes = {}, races = {}, zones = {} }
            whoSel = nil
            D.who.list, D.who.total, D.who.query = {}, 0, ""
            lfg.Refresh()
        end, tip = function() return "Empty the box, the filters and the list." end },
    } })
    who.quick:SetPoint("TOPLEFT", 0, -62)
    who.quick:SetPoint("TOPRIGHT", 0, -62)
    who.heading = Section(page)
    who.heading:SetPoint("TOPLEFT", 0, -94)
    who.heading:SetPoint("TOPRIGHT", 0, -94)
    local hint = ns.Text(page, 10)
    hint:SetPoint("RIGHT", who.heading, "RIGHT", 0, 0)
    hint:SetText("shift: whisper  \194\183  right: invite")
    hint:SetTextColor(unpack(DIM))
    who.heading:Right(hint)
    who.found = who.heading.word
    who.list = List(page, { Make = WhoRow, Fill = FillWho, Kind = function() return "who" end,
        Height = function() return PERSON end })
    who.list.frame:SetPoint("TOPLEFT", 0, -118)
    who.list.frame:SetPoint("BOTTOMRIGHT")
end

function who.Refresh()
    local w = D.who
    local guild = GetGuildInfo and GetGuildInfo("player")
    who.quick:Set("guild", { enabled = guild ~= nil })
    who.quick:Set("clear", { color = RED })
    for _, k in ipairs({ "zone", "level", "guild" }) do
        if k ~= "guild" or guild then who.quick:Set(k, { selected = w.query ~= "" and w.query == Quick(k) }) end
    end
    for _, p in ipairs({ who.class, who.race, who.zone, who.sort }) do p:Update() end
    local picked = false
    for _, p in ipairs(w.list) do if p.name == whoSel then picked = true end end
    if not picked then whoSel = nil end
    local text, shown = "Who is online", nil
    if w.pending then
        text = "Asking\226\128\166"
    elseif #w.list > 0 or w.query ~= "" then
        text = w.total .. " found"
        if w.total > #w.list then shown = #w.list .. " shown" end
    end
    who.heading:Set(text, shown)
    who.list:Set(w.list)
    who.list.empty:SetShown(#w.list == 0 and not w.pending)
    who.list.empty:SetText(w.query == "" and Count(who.filters.classes) + Count(who.filters.races)
        + Count(who.filters.zones) == 0 and "Ask who is online: type in the box, or pick one above."
        or "Nobody online matches.")
end

function who.Band()
    local on = whoSel ~= nil
    return {
        { key = "whisper", label = "Whisper", group = "a", enabled = on, click = function() D.Message(whoSel) end,
            tip = function() return on and "Whisper " .. whoSel .. "." or "Pick someone in the list first." end },
        { key = "invite", label = "Invite", group = "a", enabled = on and not Me(whoSel), click = function()
            D.Invite(whoSel)
        end, tip = function() return on and "Invite " .. whoSel .. " to your group." or "Pick someone first." end },
        { key = "friend", label = "Add friend", group = "a", enabled = on and not Me(whoSel), click = function()
            D.Friend(whoSel)
        end, tip = function() return on and "Add " .. whoSel .. " to your friends." or "Pick someone first." end },
    }
end

-- =========================================================== the box
local PAGES = {
    browse = { label = "Browse", title = "Looking for group", page = browse, lfg = true },
    list = { label = "List me", title = "Looking for group", page = listme, lfg = true },
    who = { label = "Who", title = "Who", page = who },
}
local ORDER = { "browse", "list", "who" }

local function Available(key) return not PAGES[key].lfg or D.Has() end

function lfg.Refresh()
    if not box or not box:IsShown() then return end
    dirty = false
    local p = PAGES[current]
    title:SetText(p.title)
    for _, k in ipairs(ORDER) do tabs:Set(k, { selected = k == current, shown = Available(k) }) end
    for k, v in pairs(PAGES) do v.frame:SetShown(k == current) end
    p.page.Refresh()
    band:Fill(p.page.Band())
end

local function Select(key)
    if not Available(key) then key = "who" end
    if current ~= key then browseSel = nil end
    current = key
    ns.db.lfgPage = key
end

local function Covered()
    for _, f in ipairs(covers) do
        if f:IsShown() then return true end
    end
    local bank = ns.bank and ns.bank.cover          -- the bank, docked on the strip (built when it opens)
    return bank and bank:IsShown() or false
end

local function Theirs() return _G.LFGParentFrame end

local function Sync()
    if not box then return end
    local on = wanted and not Covered()
    syncing = true
    box:SetShown(on)
    syncing = false
    if ns.chat then ns.chat.Hold(on, "lfg") end
    if on then lfg.Refresh() end
end

function lfg.IsShown() return box and box:IsShown() or false end
function lfg.Current() return lfg.IsShown() and current or nil end

function lfg.Open(key)
    if not box then return end
    Select(key or ns.db.lfgPage or "browse")
    local first = not wanted
    wanted = true
    Sync()
    if current == "browse" and first and #D.results == 0 and not D.searching then Search() end
end

local closing = false
function lfg.Close()
    if not box or closing then return end
    closing = true
    wanted = false
    Sync()
    local f = Theirs()
    if f and f:IsShown() then
        if HideUIPanel then HideUIPanel(f) else f:Hide() end
    end
    closing = false
end

function lfg.Toggle(key)
    if lfg.IsShown() and (not key or key == current) then lfg.Close() else lfg.Open(key) end
end

-- the binding's
function MedalluinToggleLFG() lfg.Toggle() end
BINDING_NAME_MEDALLUIN_LFG = "Looking for group / Who"

local function Build()
    local strip = ns.strips[-1]
    box = CreateFrame("Frame", "MedalluinLFG", strip)
    ns.window.Mark(box, -1)
    box:SetFrameStrata("BACKGROUND")
    box:SetWidth(WIDTH)
    box:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    if ns.chat then
        box:SetFrameLevel(ns.chat.box:GetFrameLevel() + 2)
        box:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
    else
        box:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, L.stripHeight)
    end
    box:EnableMouse(true)
    box:Hide()
    local dress = ns.window.Dress(box, 0)
    dress.rule:Hide()
    title = ns.Text(box, 16)
    title:SetPoint("TOPLEFT", PAD + 2, -12)
    title:SetTextColor(unpack(GOLD))
    close = ns.window.Button(box, CONTROL + 10, function() lfg.Close() end, function() return "Close." end)
    Glyph(close, "close")
    close:SetHeight(CONTROL + 10)
    close:SetPoint("TOPRIGHT", -PAD, -6)
    local items = {}
    for _, k in ipairs(ORDER) do
        table.insert(items, { key = k, label = PAGES[k].label, group = "p", click = function()
            Select(k)
            lfg.Refresh()
            if k == "browse" and #D.results == 0 and not D.searching then Search() end
        end, tip = function()
            return k == "browse" and "The groups and players listed." or k == "list"
                and "List yourself, for groups and players to find." or "Who is online."
        end })
    end
    tabs = ns.window.Segments(box, { height = TABS, items = items, soft = "open", size = 13 })
    tabs:SetPoint("TOPLEFT", PAD, -HEAD)
    tabs:SetPoint("TOPRIGHT", -PAD, -HEAD)
    -- under the open tabs, a hair and a fainter one, as the windows' (window/shell.lua)
    local hair = ns.window.Hair(box)
    hair:SetPoint("TOPLEFT", PAD, -(HEAD + TABS + 4))
    hair:SetPoint("TOPRIGHT", -PAD, -(HEAD + TABS + 4))
    local faint = ns.window.Hair(box, false, 0.5)
    faint:SetPoint("TOPLEFT", PAD + 30, -(HEAD + TABS + 7))
    faint:SetPoint("TOPRIGHT", -PAD - 30, -(HEAD + TABS + 7))
    band = ns.window.Segments(box, { height = BAND })
    band:SetPoint("BOTTOMLEFT", PAD, PAD)
    band:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local bandRule = box:CreateTexture(nil, "ARTWORK")
    bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    bandRule:SetHeight(1)
    bandRule:SetPoint("BOTTOMLEFT", PAD, PAD + BAND + 7)
    bandRule:SetPoint("BOTTOMRIGHT", -PAD, PAD + BAND + 7)
    for _, k in ipairs(ORDER) do
        local f = CreateFrame("Frame", nil, box)
        f:SetPoint("TOPLEFT", PAD, -(HEAD + TABS + 16))
        f:SetPoint("BOTTOMRIGHT", -PAD, PAD + BAND + 14)
        f:Hide()
        PAGES[k].frame = f
        if Available(k) then PAGES[k].page.Build(f) end
    end
    box:SetScript("OnHide", function()
        if browse.search then browse.search:ClearFocus() end
        if ns.OptionsUI and ns.OptionsUI.CloseMenu then ns.OptionsUI.CloseMenu() end
        if syncing then return end
        -- Escape, or a parent gone: closed for good
        wanted = false
        if ns.chat then ns.chat.Hold(false, "lfg") end
        local f = Theirs()
        if f and f:IsShown() and not closing then
            closing = true
            if HideUIPanel then HideUIPanel(f) else f:Hide() end
            closing = false
        end
    end)
    box:SetScript("OnUpdate", function() if dirty then lfg.Refresh() end end)
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinLFG") end
    D.Listen(function() dirty = true end)
    Select(ns.db.lfgPage or "browse")
    lfg.box, lfg.tabs, lfg.band, lfg.title = box, tabs, band, title
    lfg.browse, lfg.listme, lfg.who = browse, listme, who
end

-- ------------------------------------------------------------ the takeover
local adopted = false
local theirsShown = false               -- Blizzard's LFG frame, as last followed
-- Only its opening and closing count: the game's panel manager shows it
-- again as other panels come and go (/who's Friends window), and that
-- must not turn ours from Who to Browse.
local function Follow()
    local f = Theirs()
    if not f then return end
    local shown = f:IsShown() and true or false
    if shown == theirsShown then return end
    theirsShown = shown                 -- kept as we close it too
    if closing then return end
    if shown then
        if not (lfg.IsShown() and current ~= "who") then
            lfg.Open(ns.db.lfgPage ~= "who" and ns.db.lfgPage or "browse")
        end
    elseif lfg.IsShown() and current ~= "who" then
        lfg.Close()
    end
end

local function Adopt()
    local f = Theirs()
    if adopted or not f or not D.Has() then return end
    adopted = true
    ns.Park(f)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(f, method, Follow) end
    if f:IsShown() then Follow() end
    -- its own Who tab: ours
    local whoList = _G.LFGWhoListFrame
    if whoList then hooksecurefunc(whoList, "Show", function() lfg.Open("who") end) end
end
lfg.Adopt = Adopt

-- the Friends window's Who tab: ours instead, the Friends window closed
local function TakeWho()
    local w = _G.WhoFrame
    if not w then return end
    hooksecurefunc(w, "Show", function()
        if FriendsFrame and FriendsFrame:IsShown() then
            if HideUIPanel then HideUIPanel(FriendsFrame) else FriendsFrame:Hide() end
        end
        lfg.Open("who")
    end)
end

local function Cover(f)
    if not f then return end
    table.insert(covers, f)
    f:HookScript("OnShow", Sync)
    f:HookScript("OnHide", Sync)
end

local function Start()
    if not ns.db.lfgWindow then return end
    D.Load()
    Build()
    Cover(ns.character and ns.character.window)
    -- an NPC window opening closes it: the last opened wins
    if ns.npc and ns.npc.box then ns.npc.box:HookScript("OnShow", function() lfg.Close() end) end
    if ns.quests and ns.quests.Cover then ns.quests.Cover(box) end
    Adopt()
    if not adopted and D.Has() then
        -- loaded later after all: adopted as it loads
        ns.On("ADDON_LOADED", function() Adopt() end)
    end
    TakeWho()
end

ns.On("PLAYER_LOGIN", Start)
