-- The NPC windows: gossip, the quest pages and the vendor, Medalluin's
-- own, in one box standing on the chat box (strips/chat.lua) where the
-- quest tracker's full view stands, as tall as what it shows up to the
-- screen's top. The tracker hides while it is open (quests/tracker.lua),
-- as it does under the character window; the box hides under that too.
--
--   (portrait) The Defias Brotherhood                       [x]  <- the page's
--              Gryan Stoutmantle                                  title, the NPC
--   ---------------------------------------------------------      (or, untitled,
--                                                                   the NPC's name
--                                                                   and its trade)
--   Did Master Shaw shed any light on things?       (the page: text, label
--                                                    pills, rows, item tiles,
--   [Required]                                       tabs; scrolls past the top)
--   [icon] Shaw's Report
--   ---------------------------------------------------------
--   [        Continue        ] [         Cancel         ]
--   [General][Trade]                       <- the chat box under it
--
-- Laid out as a dialogue is, not a list: a readable face for what the NPC
-- says, room between the parts, and wide buttons. The head and foot keep
-- the ink at 60% at the far edge where the page fades to the tracker's
-- tenth, so the name and the buttons stand on something.
--
-- Blizzard's GossipFrame, QuestFrame and MerchantFrame keep every way in
-- and out: the game opens and closes them, Escape too, under a hidden
-- parent (ns.Park), as the character window keeps Blizzard's. The box
-- shows while one of them is shown, on its page; the last to open wins.
--
-- Taint: nothing here writes to Blizzard's frames, calls their functions
-- (MerchantFrame_*, StaticPopup_Show) or sets their tabs. A bag's right
-- click reads MerchantFrame's own state to sell, and a value an addon
-- wrote there would block it (the 0.12 bag-click errors). Everything is
-- asked of the game's API instead, and confirmed in the box's own foot.
--
--   local page = ns.npc.Page{ key, frame (Blizzard's, by name), addon (the
--                             Blizzard addon that brings it, when loaded on
--                             demand), Blocks() ->
--                             blocks, Foot() -> foot, Title() -> title,
--                             under (the NPC's name when not given), Close(),
--                             Shown(), own (a frame of its own, shown in
--                             the box's place instead: the flight map),
--                             veil (Blizzard's frame must stay visible:
--                             parked under ns.veil, not ns.hidden),
--                             price (a shop: its rows a table, under this
--                             heading over their values), column (and
--                             this over their names: "Item", or a
--                             function saying), icon (the
--                             portrait's, where there is no NPC: the
--                             mailbox), Steady() -> blocks (the page as
--                             tall as these, on every tab: the rest scrolls),
--                             keys (true: its rows numbered, and picked
--                             with the keys 1 to 0, - and =), space (Space presses the foot's primary
--                             button, while the Space option is on) }
--   ns.npc.Show(key) (its page to the front), ns.npc.Update(key) (drawn
--   again if in front), ns.npc.box, ns.npc.dock, ns.npc.Room() (the room up to the
--   screen's top)
--
-- A page's blocks, top down:
--   { "text", text, color, pin }         a paragraph, wrapped (pin: the
--                                        page's one that stays put, above
--                                        the tabs: what the NPC says)
--   { "heading", text }                  a label on a dark pill
--   { "fold", label, collapsed, click() } a heading that folds what follows
--                                        (its page leaves those out when
--                                        collapsed): the professions' ornate
--                                        band, + or - at its right, in the
--                                        box's gold, fading as the box does
--   { "row", label, icon, crop, badge, value, color, dim, selected,
--     click(button), enter(row) }        a line that clicks (crop: the icon's
--                                        own square border cut off, as an
--                                        item's or a letter's)
--   { "tiles", { icon, crop, label, count, color, selected, dim,
--     click(button), enter(tile) } ... } items, two a row
--   { "tabs", { label, selected, click } ... }
--                                        one a page: one joined row across
--                                        it (ns.window.Segments), staying put
--                                        under the head, under an ornament
--                                        when the NPC says something, while
--                                        the rest scrolls
--   { "input", key, label, text, lines, numeric, complete(text) -> names,
--     changed(text), enter() }           a labelled box, one line or several
--                                        (lines); a box being typed in keeps
--                                        its text when the page is drawn
--                                        again. complete: names under it,
--                                        Tab or a click takes one
--   { "money", key, label, copper, changed(copper) }
--                                        gold, silver and copper boxes
--   { "slots", { icon, count, click(button), receive(), enter(slot) } ... }
--                                        item wells, six a row: a click, or
--                                        what the cursor holds dropped in
--                                        (the icons cropped, being items)
-- Any block with dock = true stands under the list instead, over a
-- hairline above the foot, and stays put while the list scrolls (a
-- trainer's spell picked, what it does and asks).
-- A shop's rows, as a shop's list reads: shaded every other one, and a
-- hairline between the names and the prices, the column as wide as the
-- widest price; each run of rows (the list's, or a fold's) under its own
-- heading, scrolling with them:
--
--   [   Merchant   |     Sell     |    Buyback    ]
--   Item                                          |   Price
--   [icon] Fishing Pole                           |     23c   <- shaded
--   [icon] Shiny Bauble                           |     50c
-- Its foot: { left = text, { label, click, enabled, tip, primary } ... },
-- the buttons left to right: sharing the width when there is no text, else
-- at the right; the primary one wears the deed's red.
--
-- The keys: while a page with keys is in front, its first twelve rows wear
-- their key ("1." in grey) and the keys 1 to 0, - and = pick them; on a page
-- with space, Space presses the primary button (Accept, Continue, Complete
-- Quest). They are priority override bindings of the box's own, so the
-- action bar buttons on those keys do nothing meanwhile. Bindings cannot
-- change in combat: they are cleared as it begins (PLAYER_REGEN_DISABLED,
-- still allowed), so a fight always has its bars, and set again after.
--
-- Built at login, only with the chat box and the NPC windows option on.
local _, ns = ...

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD, HEAD, FOOT, GAP = 14, 60, 50, 12
local PORTRAIT, BUTTON = 42, 32
local ROW, ICON, TILE, TILE_ICON, TABS, PILL = 30, 20, 48, 40, 26, 22
local CONTROL = 16
local INPUT, LINE, LABEL, NAME, WELL = 26, 16, 72, 22, 40   -- the boxes, a line of one, the label's width
local NAMES = 4                                  -- the names offered under a box, at most
local ZEBRA, RULE = 0.05, 0.6                    -- a shop's shaded rows, its hairlines
local HEADING, HEADING_FONT = 14, 11             -- a shop's column heading, slim, and its words
local FOLD_MARGIN, FOLD_FILL = 4, 0.45           -- a fold's room above and below its band, its gold
local TENTH = 0.1                                -- the far edge of a fade, as the box's ink
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DEED = { 0.42, 0.13, 0.09 }                -- the primary button's fill
-- the head's and foot's own ink over the box's: 5/9 more, the box's fade
-- from solid to a tenth becomes solid to 60% (1 - 0.9 * 4/9 = 0.6)
local BAND_INK = 5 / 9

local pages, order = {}, {}
local box, head, portrait, name, under, close, bar, scroll, child, dock, foot, footText, thumb
local current
local wanted                     -- the page last asked for, preferred once its frame is open
local pools = {}
local drawing                    -- inside Lay: a box's focus moving is not a redraw
local edits = {}                 -- this draw's boxes in order, for Tab
local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
local numbering                  -- this draw's rows are numbered (the page's keys)
local keyed = {}                 -- this draw's numbered rows, in order
local primary                    -- the foot's primary button, for Space
local KEY = 18                   -- a row's key's room
local KEY_GREY = { 0.62, 0.62, 0.62 }

ns.npc = { pages = pages }

-- copper as the game writes it, for every page
function ns.npc.Money(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    return format("%dg %ds %dc", copper / 10000, copper / 100 % 100, copper % 100)
end

function ns.npc.Page(spec)
    pages[spec.key] = spec
    table.insert(order, spec)
    return spec
end

-- ------------------------------------------------------------ the blocks
-- an icon's texture coordinates: cropped past the square border the game
-- draws into an item's icon, or whole
local function Crop(on)
    if on then return 0.08, 0.92, 0.08, 0.92 end
    return 0, 1, 0, 1
end

local function Glow(f)
    local glow = f:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    f.mark = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.mark:SetAllPoints()
    f.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
end

-- c across a texture, at alpha a on the left fading to a tenth of it on
-- the right, as the box's ink does (flat between the two where the client
-- has no gradients)
local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], a * TENTH))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * (1 + TENTH) / 2)
    end
end

local function Clicks(f)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnClick", function(self, button)
        if self.data.click then self.data.click(button) end
    end)
    f:SetScript("OnEnter", function(self)
        if self.data.enter then self.data.enter(self) end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) ns.npc.Scroll(-delta) end)
end

-- -------------------------------------------------------- the boxes
local function Label(f)
    local t = ns.Text(f, 13)
    t:SetPoint("LEFT", 2, 0)
    t:SetWidth(LABEL - 8)
    t:SetJustifyH("LEFT")
    t:SetTextColor(ns.colors.dim[1], ns.colors.dim[2], ns.colors.dim[3])
    return t
end

-- a box's well: a gold edge, ink inside
local function Well(f)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.5)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.85)
end

-- an edit box, the game's, dressed as ours: on a well of its own unless
-- it stands in one (bare)
local function Edit(f, bare)
    local e = CreateFrame("EditBox", nil, f)
    e:SetAutoFocus(false)
    e:SetFont(ns.font, 14, "")
    e:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    e:SetTextInsets(6, 6, 0, 0)
    if not bare then Well(e) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnTabPressed", function(self) ns.npc.Tab(self) end)
    return e
end

-- the copper three boxes hold
local function Coins(f)
    local function n(i) return tonumber(f.boxes[i]:GetText()) or 0 end
    return n(1) * 10000 + n(2) * 100 + n(3)
end

-- a name offered under a box taken into it
local function Pick(e, who)
    e:SetText(who)
    e:SetCursorPosition(#who)
    if e.data.changed then e.data.changed(who) end
    ns.npc.Refresh()
end

local function Field(parent, multi)
    local f = CreateFrame("Frame", nil, parent)
    f.label = Label(f)
    f.label:ClearAllPoints()
    f.label:SetPoint("TOPLEFT", 2, -(INPUT - 14) / 2)
    local e
    if multi then
        -- a box of several lines is as tall as its text, whatever it is
        -- given: the well stands for it at the height asked, and a click
        -- anywhere in it types
        f.well = CreateFrame("Frame", nil, f)
        f.well:SetPoint("TOPLEFT", LABEL, 0)
        f.well:SetPoint("RIGHT")
        Well(f.well)
        f.well:EnableMouse(true)
        f.well:SetScript("OnMouseDown", function() e:SetFocus() end)
        e = Edit(f.well, true)
        e:SetPoint("TOPLEFT")
        e:SetPoint("TOPRIGHT")
        e:SetMultiLine(true)
        e:SetTextInsets(6, 6, 5, 5)
    else
        e = Edit(f)
        e:SetPoint("TOPLEFT", LABEL, 0)
        e:SetPoint("RIGHT")
        e:SetScript("OnEnterPressed", function(self)
            if self.data.enter then self.data.enter() else self:ClearFocus() end
        end)
    end
    e:SetScript("OnTextChanged", function(self, user)
        if user and self.data.changed then self.data.changed(self:GetText()) end
    end)
    -- the names offered show for the box being typed in
    e:SetScript("OnEditFocusGained", function() if not drawing then ns.npc.Refresh() end end)
    f.edit = e
    f.names = {}
    return f
end

function ns.npc.Tab(e)
    local first = e.offered and e.offered[1]
    if first then return Pick(e, first) end
    for i, other in ipairs(edits) do
        if other == e then
            local next = edits[i % #edits + 1]
            if next ~= e then next:SetFocus() end
            return
        end
    end
end

-- a box's text, set only when it differs: what is typed reaches the page
-- (changed) before it draws again, so a box being typed in is left alone,
-- its cursor where it was
local function Fill(e, text)
    if e:GetText() ~= text then e:SetText(text) end
end

local make = {
    -- what the NPC says, in a face made for reading (the game's own)
    text = function(parent)
        local t = ns.Text(parent, 14)
        t:SetFont(ns.FontPath("friz"), 14, "")
        t:SetJustifyH("LEFT")
        t:SetSpacing(4)
        return t
    end,
    heading = function(parent)
        local h = CreateFrame("Frame", nil, parent)
        h:SetHeight(PILL)
        local fill = h:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.8)
        local edge = h:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT")
        edge:SetPoint("BOTTOMLEFT")
        edge:SetWidth(2)
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        h.mid = ns.Text(h, 13)
        h.mid:SetPoint("LEFT", 10, 0)
        h.mid:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        return h
    end,
    row = function(parent)
        local r = CreateFrame("Button", nil, parent)
        r:SetHeight(ROW)
        Glow(r)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ICON, ICON)
        r.badge = r:CreateTexture(nil, "ARTWORK")
        r.key = ns.Text(r, 13)
        r.key:SetPoint("LEFT", 4, 0)
        r.key:SetTextColor(KEY_GREY[1], KEY_GREY[2], KEY_GREY[3])
        r.key:SetAlpha(0.7)
        r.label = ns.Text(r, 14)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        r.value = ns.Text(r, 13)
        r.value:SetPoint("RIGHT", -6, 0)
        -- a shop's: every other row shaded, and the price column's rule
        r.zebra = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.zebra:SetAllPoints()
        r.zebra:SetColorTexture(1, 1, 1, ZEBRA)
        r.rule = r:CreateTexture(nil, "BORDER")
        r.rule:SetWidth(1)
        r.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], RULE)
        Clicks(r)
        return r
    end,
    -- a fold: the professions' ornate heading (character/list.lua), its band
    -- inset by a margin in a rim lit along the top and shadowed along the
    -- bottom, a shine inside; in the box's gold at its hairlines' strength,
    -- fading to a tenth at the far edge as the box does
    fold = function(parent)
        local f = CreateFrame("Button", nil, parent)
        f:SetHeight(ROW + 2 * FOLD_MARGIN)
        local function Band(t, inset)
            t:SetPoint("TOPLEFT", inset, -(FOLD_MARGIN + inset))
            t:SetPoint("BOTTOMRIGHT", -inset, FOLD_MARGIN + inset)
        end
        local fill = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        Band(fill, 0)
        Fade(fill, GOLD_D, FOLD_FILL)
        local glow = f:CreateTexture(nil, "HIGHLIGHT")
        Band(glow, 1)
        glow:SetColorTexture(1, 1, 1, 0.08)
        local function Edge(point, y, c, a)
            local t = f:CreateTexture(nil, "BORDER")
            t:SetPoint(point .. "LEFT", 0, y)
            t:SetPoint(point .. "RIGHT", 0, y)
            t:SetHeight(1)
            Fade(t, c, a)
            return t
        end
        Edge("TOP", -FOLD_MARGIN, GOLD, RULE)
        Edge("BOTTOM", FOLD_MARGIN, GOLD_D, RULE)
        local shine = Edge("TOP", -(FOLD_MARGIN + 1), GOLD, RULE * 0.35)
        shine:SetPoint("TOPLEFT", 1, -(FOLD_MARGIN + 1))
        shine:SetPoint("TOPRIGHT", -1, -(FOLD_MARGIN + 1))
        -- the sides run from the shadow up to the light; the far one faded
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetPoint("TOP" .. side, 0, -FOLD_MARGIN)
            t:SetPoint("BOTTOM" .. side, 0, FOLD_MARGIN)
            t:SetWidth(1)
            local a = side == "LEFT" and RULE or RULE * TENTH
            if t.SetGradient and CreateColor then
                t:SetColorTexture(1, 1, 1, 1)
                t:SetGradient("VERTICAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a),
                    CreateColor(GOLD[1], GOLD[2], GOLD[3], a))
            else
                t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a)
            end
        end
        f.label = ns.Text(f, 14)
        f.label:SetPoint("LEFT", 8, 0)
        f.label:SetPoint("RIGHT", -28, 0)
        f.label:SetJustifyH("LEFT")
        f.label:SetWordWrap(false)
        f.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        f.sign = ns.Text(f, 14)
        f.sign:SetPoint("RIGHT", -8, 0)
        f.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        Clicks(f)
        return f
    end,
    -- a shop's column heading, over a run of its rows: what they are at the
    -- left, Price at the right of the column's rule
    columns = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetHeight(HEADING)
        f.left = ns.Text(f, HEADING_FONT)
        f.left:SetPoint("LEFT", 4, 0)
        f.left:SetTextColor(ns.colors.dim[1], ns.colors.dim[2], ns.colors.dim[3])
        f.right = ns.Text(f, HEADING_FONT)
        f.right:SetPoint("RIGHT", -6, 0)
        f.right:SetTextColor(ns.colors.dim[1], ns.colors.dim[2], ns.colors.dim[3])
        f.rule = f:CreateTexture(nil, "BORDER")
        f.rule:SetWidth(1)
        f.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], RULE)
        return f
    end,
    tile = function(parent)
        local t = CreateFrame("Button", nil, parent)
        t:SetHeight(TILE)
        local edge = t:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.5)
        local well = t:CreateTexture(nil, "BACKGROUND", nil, 1)
        well:SetPoint("TOPLEFT", 1, -1)
        well:SetPoint("BOTTOMRIGHT", -1, 1)
        well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.85)
        Glow(t)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(TILE_ICON, TILE_ICON)
        t.icon:SetPoint("LEFT", 3, 0)
        t.count = ns.Text(t, 12)
        t.count:SetPoint("BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", -1, 1)
        t.label = ns.Text(t, 13)
        t.label:SetJustifyH("LEFT")
        t.label:SetPoint("LEFT", t.icon, "RIGHT", 8, 0)
        t.label:SetPoint("RIGHT", -4, 0)
        Clicks(t)
        return t
    end,
    field = function(parent) return Field(parent, false) end,
    area = function(parent) return Field(parent, true) end,
    coins = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetHeight(INPUT)
        f.label = Label(f)
        f.boxes = {}
        local x = LABEL
        for i, c in ipairs({ { "g", 0.941, 0.831, 0.533, 64 }, { "s", 0.78, 0.78, 0.8, 36 },
            { "c", 0.78, 0.5, 0.3, 36 } }) do
            local e = Edit(f)
            e:SetNumeric(true)
            e:SetMaxLetters(i == 1 and 6 or 2)
            e:SetSize(c[5], INPUT)
            e:SetPoint("LEFT", x, 0)
            e:SetScript("OnTextChanged", function(self, user)
                if user and f.data.changed then f.data.changed(Coins(f)) end
            end)
            local t = ns.Text(f, 13)
            t:SetText(c[1])
            t:SetTextColor(c[2], c[3], c[4])
            t:SetPoint("LEFT", e, "RIGHT", 4, 0)
            x = x + c[5] + 18
            f.boxes[i] = e
        end
        return f
    end,
    well = function(parent)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(WELL, WELL)
        local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.5)
        local well = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        well:SetPoint("TOPLEFT", 1, -1)
        well:SetPoint("BOTTOMRIGHT", -1, 1)
        well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.85)
        Glow(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(Crop(true))
        b.count = ns.Text(b, 12)
        b.count:SetPoint("BOTTOMRIGHT", -3, 3)
        Clicks(b)
        -- what the cursor holds goes in: dropped, or clicked in
        b:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and GetCursorInfo() and self.data.receive then
                self.data.receive()
            elseif self.data.click then
                self.data.click(button)
            end
        end)
        b:SetScript("OnReceiveDrag", function(self) if self.data.receive then self.data.receive() end end)
        return b
    end,
}

-- the n-th of a kind this draw on parent (the scroll's child, the dock),
-- made the first time: each has its own
local function Take(kind, used, parent)
    pools[parent] = pools[parent] or {}
    local pool = pools[parent]
    pool[kind] = pool[kind] or {}
    used[kind] = (used[kind] or 0) + 1
    local f = pool[kind][used[kind]]
    if not f then
        f = make[kind](parent)
        pool[kind][used[kind]] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
end

local function Colour(t, c) t:SetTextColor(c[1], c[2], c[3]) end

-- Lays the blocks out down parent (the scroll child, or the dock); how
-- tall they came to. With col (a shop's price column, its width) the rows
-- are a table.
local function Lay(blocks, width, col, parent)
    local used, y, n = {}, 0, 0                -- n: the rows so far, for the shading
    drawing = true
    for i, b in ipairs(blocks) do
        local kind = b[1]
        -- rows and folds run together (a fold's margin is its room); a pill
        -- sits closer to what it labels
        if i > 1 then
            local last = blocks[i - 1][1]
            local boxes = (kind == "input" or kind == "money") and (last == "input" or last == "money")
            local flush = (kind == "row" or kind == "fold" or kind == "columns")
                and (last == "row" or last == "fold" or last == "columns")
            y = y + (flush and 0 or (last == "heading" or boxes) and GAP / 2 or GAP)
        end
        if kind == "text" then
            local t = Take(kind, used, parent)
            t:SetWidth(width)
            t:SetPoint("TOPLEFT", 0, -y)
            t:SetText(b[2] or "")
            Colour(t, b[3] or ns.colors.text)
            y = y + t:GetStringHeight()
        elseif kind == "heading" then
            local h = Take("heading", used, parent)
            if i > 1 then y = y + GAP / 2 end    -- and further from what went before
            h:SetPoint("TOPLEFT", 0, -y)
            h.mid:SetText(b[2])
            h:SetWidth(h.mid:GetStringWidth() + 24)
            y = y + PILL
        elseif kind == "fold" then
            local f = Take("fold", used, parent)
            f.data = b
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetWidth(width)
            f.label:SetText(b.label or "")
            f.sign:SetText(b.collapsed and "+" or "-")
            n = 0                               -- each group's shading starts afresh
            y = y + ROW + 2 * FOLD_MARGIN
        elseif kind == "columns" then
            local f = Take("columns", used, parent)
            f.data = b
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetWidth(width)
            f.left:SetText(b.left or "")
            f.right:SetText(b.right or "")
            f.rule:ClearAllPoints()
            f.rule:SetPoint("TOPLEFT", width - col, 0)
            f.rule:SetPoint("BOTTOMLEFT", width - col, 0)
            y = y + HEADING
        elseif kind == "row" then
            local r = Take("row", used, parent)
            r.data = b
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetWidth(width)
            local x = 4
            local key = numbering and KEYS[#keyed + 1]
            r.key:SetText(key and key .. "." or "")
            if key then
                table.insert(keyed, b)
                x = x + KEY
            end
            r.icon:SetShown(b.icon ~= nil)
            if b.icon then
                r.icon:SetTexture(b.icon)
                r.icon:SetTexCoord(Crop(b.crop))
                r.icon:SetPoint("LEFT", x, 0)
                x = x + ICON + 4
            end
            r.badge:SetShown(b.badge ~= nil)
            if b.badge then
                ns.character.Badge(r.badge, b.badge)
                r.badge:SetSize(b.badge.size, b.badge.size)
                r.badge:SetPoint("LEFT", x, 0)
                x = x + b.badge.size + 4
            end
            r.label:SetPoint("LEFT", x, 0)
            r.label:SetText(b.label or "")
            Colour(r.label, b.color or b.dim and ns.colors.dim or ns.colors.text)
            r.value:SetText(b.value or "")
            r.label:SetPoint("RIGHT", r, "RIGHT", col and -(col + 8) or b.value and -(r.value:GetStringWidth() + 14)
                or -6, 0)
            r.mark:SetShown(b.selected and true or false)
            n = n + 1
            r.zebra:SetShown(col ~= nil and n % 2 == 1)
            r.rule:SetShown(col ~= nil)
            if col then
                r.rule:ClearAllPoints()
                r.rule:SetPoint("TOPLEFT", width - col, 0)
                r.rule:SetPoint("BOTTOMLEFT", width - col, 0)
            end
            y = y + ROW
        elseif kind == "tiles" then
            local half = (width - GAP) / 2
            -- b[1] is the block's kind: the tiles are what follows it
            for j = 1, #b - 1 do
                local d = b[j + 1]
                local t = Take("tile", used, parent)
                t.data = d
                local across, down = (j - 1) % 2, math.floor((j - 1) / 2)
                t:SetPoint("TOPLEFT", across * (half + GAP), -(y + down * (TILE + GAP)))
                t:SetWidth(half)
                t.icon:SetTexture(d.icon)
                t.icon:SetTexCoord(Crop(d.crop))
                t.icon:SetDesaturated(d.dim and true or false)
                t.count:SetText(d.count and d.count > 1 and d.count or "")
                t.label:SetText(d.label or "")
                Colour(t.label, d.color or d.dim and ns.colors.dim or ns.colors.text)
                t.mark:SetShown(d.selected and true or false)
            end
            y = y + math.ceil((#b - 1) / 2) * (TILE + GAP) - GAP
        elseif kind == "input" then
            local multi = (b.lines or 1) > 1
            local f = Take(multi and "area" or "field", used, parent)
            f.data, f.edit.data = b, b
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetWidth(width)
            f.label:SetText(b.label or "")
            local e = f.edit
            e:SetNumeric(b.numeric and true or false)
            local tall = multi and b.lines * LINE + 10 or INPUT
            if multi then f.well:SetHeight(tall) else e:SetHeight(tall) end
            Fill(e, b.text or "")
            table.insert(edits, e)
            -- the names that complete it, while it is typed in
            local names = {}
            local text = e:GetText() or ""
            if b.complete and e:HasFocus() and text ~= "" then
                for _, who in ipairs(b.complete(text)) do
                    if who ~= text and #names < NAMES then table.insert(names, who) end
                end
            end
            e.offered = names
            local x = LABEL
            for j = 1, math.max(#names, #f.names) do
                local t = f.names[j]
                if names[j] and not t then
                    t = CreateFrame("Button", nil, f)
                    t:SetHeight(NAME)
                    Glow(t)
                    t.mark:Hide()
                    t.label = ns.Text(t, 13)
                    t.label:SetPoint("CENTER")
                    t:SetScript("OnClick", function(self) Pick(e, self.name) end)
                    f.names[j] = t
                end
                if t then
                    t:SetShown(names[j] ~= nil)
                    if names[j] then
                        t.name = names[j]
                        t.label:SetText(names[j])
                        Colour(t.label, j == 1 and GOLD or ns.colors.text)
                        t:SetWidth(t.label:GetStringWidth() + 16)
                        t:ClearAllPoints()
                        t:SetPoint("TOPLEFT", x, -(tall + 2))
                        x = x + t:GetWidth() + 4
                    end
                end
            end
            if #names > 0 then tall = tall + 2 + NAME end
            f:SetHeight(tall)
            y = y + tall
        elseif kind == "money" then
            local f = Take("coins", used, parent)
            f.data = b
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetWidth(width)
            f.label:SetText(b.label or "")
            local c = b.copper or 0
            local parts = { math.floor(c / 10000), math.floor(c / 100) % 100, c % 100 }
            -- set only when they hold another sum (as Fill): a nought shows as
            -- nothing, and "05" typed stays as typed
            local same = Coins(f) == c
            for j, e in ipairs(f.boxes) do
                e.data = b
                if not same then e:SetText(parts[j] > 0 and tostring(parts[j]) or "") end
                table.insert(edits, e)
            end
            y = y + INPUT
        elseif kind == "slots" then
            for j = 1, #b - 1 do
                local d = b[j + 1]
                local w = Take("well", used, parent)
                w.data = d
                w:SetPoint("TOPLEFT", ((j - 1) % 6) * (WELL + 6), -(y + math.floor((j - 1) / 6) * (WELL + 6)))
                w.icon:SetShown(d.icon ~= nil)
                w.icon:SetTexture(d.icon)
                w.count:SetText(d.count and d.count > 1 and d.count or "")
            end
            y = y + math.ceil((#b - 1) / 6) * (WELL + 6) - 6
        end
    end
    drawing = false
    for kind, list in pairs(pools[parent] or {}) do
        for i = (used[kind] or 0) + 1, #list do list[i]:Hide() end
    end
    return y
end

-- What stays put under the head while the page scrolls: what the NPC
-- says, an ornament, and the tabs, one joined row across the page
-- (ns.window.Segments). The room it takes, its gap below included (none
-- with neither).
local function Pin(say, b)
    bar:SetShown(say ~= nil or b ~= nil)
    local y = 0
    bar.say:SetShown(say ~= nil)
    if say then
        bar.say:SetText(say[2] or "")
        Colour(bar.say, say[3] or ns.colors.text)
        y = y + bar.say:GetStringHeight() + GAP
    end
    -- what the NPC says parted from the tabs
    bar.ornament:SetShown(say ~= nil and b ~= nil)
    if say and b then
        bar.ornament:ClearAllPoints()
        bar.ornament:SetPoint("TOPLEFT", 0, -y)
        bar.ornament:SetPoint("TOPRIGHT", 0, -y)
        y = y + bar.ornament:GetHeight() + GAP
    end
    bar.tabs:SetShown(b ~= nil)
    if b then
        local items = {}
        for j = 2, #b do
            local d = b[j]
            table.insert(items, { key = j, label = d.label, selected = d.selected, click = d.click })
        end
        bar.tabs:ClearAllPoints()
        bar.tabs:SetPoint("TOPLEFT", 0, -y)
        bar.tabs:SetPoint("TOPRIGHT", 0, -y)
        bar.tabs:Fill(items)
        y = y + TABS + GAP
    end
    bar:SetHeight(math.max(1, y))
    return y
end

-- a shop's price column: as wide as its widest price, and its heading;
-- none with no rows to head
local function Column(blocks, price)
    bar.head:SetText(price)
    local most, any = bar.head:GetStringWidth(), false
    for _, b in ipairs(blocks) do
        if b[1] == "row" then
            any = true
            bar.measure:SetText(b.value or "")
            most = math.max(most, bar.measure:GetStringWidth())
        end
    end
    if any then return math.floor(most + 20 + 0.5) end
end

-- the foot's buttons, left to right: the width shared out when nothing
-- is written beside them, else each as wide as its word, at the right
local buttons = {}
local function Foot(spec)
    spec = spec or {}
    primary = nil
    for _, d in ipairs(spec) do
        if d.primary then primary = d end
    end
    footText:SetText(spec.left or "")
    local n = #spec
    local share = not spec.left and n > 0 and (WIDTH - 2 * PAD - (n - 1) * 6) / n
    for i = 1, math.max(#buttons, n) do
        local d = spec[i]
        local b = buttons[i]
        if d and not b then
            b = ns.window.Button(foot, 60, function(self) if self.data.click then self.data.click() end end,
                function() return "" end)
            b:SetHeight(BUTTON)
            b.label:SetFont(ns.font, 14, "")
            b.deed = b:CreateTexture(nil, "BACKGROUND", nil, 3)
            b.deed:SetPoint("TOPLEFT", 1, -1)
            b.deed:SetPoint("BOTTOMRIGHT", -1, 1)
            b.deed:SetColorTexture(DEED[1], DEED[2], DEED[3], 0.9)
            b:SetScript("OnEnter", function(self)
                if self.data.tip then
                    ns.Tip(self, ns.window.OutsideTop,
                        { title = self.data.label, color = GOLD, { "body", self.data.tip } })
                end
            end)
            buttons[i] = b
        end
        if b then
            b:SetShown(d ~= nil)
            if d then
                b.data = d
                b.label:SetText(d.label)
                b:SetWidth(share or math.max(#d.label > 1 and 76 or BUTTON, b.label:GetStringWidth() + 24))
                b:SetEnabled(d.enabled ~= false)
                b.deed:SetShown(d.primary and d.enabled ~= false or false)
                Colour(b.label, d.enabled ~= false and ns.colors.text or ns.colors.dim)
            end
        end
    end
    -- placed once the widths are known: from the left when shared, else
    -- the last against the right edge
    local x = share and PAD or WIDTH - PAD
    if not share then
        for i = 1, n do x = x - buttons[i]:GetWidth() - (i > 1 and 6 or 0) end
    end
    -- the words stop short of the first button, on two lines if they must
    footText:SetPoint("RIGHT", foot, "LEFT", x - 8, 0)
    for i = 1, n do
        local b = buttons[i]
        b:ClearAllPoints()
        b:SetPoint("LEFT", foot, "LEFT", x, 0)
        x = x + b:GetWidth() + 6
    end
end

-- ------------------------------------------------------------ the box
-- the room up to the screen's top, in the box's units
local function Room()
    local top = UIParent:GetTop() and UIParent:GetTop() * UIParent:GetEffectiveScale()
    local at = ns.chat.box:GetTop() and ns.chat.box:GetTop() * ns.chat.box:GetEffectiveScale()
    if not top or not at then return 600 end
    return (top - at) / box:GetEffectiveScale()
end
ns.npc.Room = Room

local offset = 0
local function Thumb()
    local range = scroll:GetVerticalScrollRange() or 0
    thumb:SetShown(range > 0)
    if range > 0 then
        local h = scroll:GetHeight()
        local size = math.max(12, h * h / (h + range))
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", PAD - 2, -(h - size) * offset / range)
    end
end

function ns.npc.Scroll(lines)
    local range = scroll:GetVerticalScrollRange() or 0
    offset = math.max(0, math.min(range, offset + lines * ROW))
    scroll:SetVerticalScroll(offset)
    Thumb()
end

-- The NPC's trade, the line under its name in its tooltip ("Fishing
-- Supplier"); none when that line is its level.
local function Trade()
    local G = C_TooltipInfo
    local ok, info = pcall(function() return G and G.GetUnit and G.GetUnit("npc") end)
    local line = ok and info and info.lines and info.lines[2]
    local text = line and line.leftText
    if not text or ns.IsSecret(text) or text == "" then return end
    if text:find(LEVEL or "Level", 1, true) then return end
    return text
end

-- The page drawn again, and the box fitted to it.
function ns.npc.Refresh()
    if not box or not current or current.own then return end
    local npc = UnitName("npc") or ""
    local title = current.Title and current.Title()
    name:SetText(title or npc)
    -- under a title, the NPC's name, unless it is the title (the mailbox's)
    under:SetText(title and (npc ~= title and npc or "") or Trade() or "")
    if portrait and current.icon then
        portrait:SetTexture(current.icon)
    elseif portrait and SetPortraitTexture then
        SetPortraitTexture(portrait, "npc")
    end
    local width = WIDTH - 2 * PAD - 6
    child:SetWidth(width)
    -- the blocks drawn: what stays put over the list, the list, and what
    -- stays put under it; the room each took (the dock's with its hairline)
    local function Draw(blocks)
        local body, docked, tabs, say = {}, {}, nil, nil
        for _, b in ipairs(blocks) do
            if b[1] == "tabs" then tabs = b
            elseif b.pin then say = b
            elseif b.dock then table.insert(docked, b)
            else table.insert(body, b) end
        end
        wipe(edits)
        wipe(keyed)
        local col = current.price and Column(body, current.price)
        -- a shop's heading over each run of its rows
        if col then
            local left = current.column
            if type(left) == "function" then left = left() end
            local headed = {}
            for i, b in ipairs(body) do
                if b[1] == "row" and (i == 1 or body[i - 1][1] ~= "row") then
                    table.insert(headed, { "columns", left = left, right = current.price })
                end
                table.insert(headed, b)
            end
            body = headed
        end
        local top = Pin(say, tabs)
        local h = Lay(body, width, col, child)
        local low = Lay(docked, width, nil, dock.body)
        return top, h, #docked > 0 and low + GAP + 1 or 0
    end
    numbering = current.keys or false
    -- a page as tall on every tab: its steady blocks drawn first, to be
    -- measured, then drawn over
    local steady = current.Steady and HEAD + PAD + (function(t, b, d) return t + b + d end)(Draw(current.Steady()))
        + PAD + FOOT
    local top, h, low = Draw(current.Blocks())
    scroll:SetPoint("TOPLEFT", PAD, -(HEAD + PAD + top))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOT + PAD + low)
    child:SetHeight(math.max(1, h))
    dock:SetShown(low > 0)
    dock:SetHeight(math.max(1, low))
    Foot(current.Foot and current.Foot())
    local want = steady or HEAD + PAD + top + h + low + PAD + FOOT
    box:SetHeight(math.min(want, Room()))
    offset = math.min(offset, scroll:GetVerticalScrollRange() or 0)
    scroll:SetVerticalScroll(offset)
    Thumb()
    ns.npc.Keys()
end

-- ------------------------------------------------------------ the keys
-- What the keys are bound to now: the rows' keys, Space, or nothing; set
-- again only when that changes, and never in combat.
local keyer, bound
function ns.npc.Keys()
    if not keyer or InCombatLockdown() then return end
    local shown = box:IsShown() and current
    local rows = shown and #keyed > 0
    local space = shown and current.space and ns.db.npcSpace and primary ~= nil
    local want = (rows and "rows" or "") .. (space and " space" or "")
    if want == bound then return end
    ClearOverrideBindings(keyer)
    if rows then
        for _, key in ipairs(KEYS) do SetOverrideBindingClick(keyer, true, key, keyer:GetName(), key) end
    end
    if space then SetOverrideBindingClick(keyer, true, "SPACE", keyer:GetName(), "SPACE") end
    bound = want
end

-- a key pressed: its row picked, or the primary button pressed, while bound
local function Press(_, key)
    if not bound then return end
    if key == "SPACE" then
        if not bound:find("space") then return end
        if primary and primary.enabled ~= false and primary.click then primary.click() end
        return
    end
    for i, k in ipairs(KEYS) do
        if k == key then
            local row = keyed[i]
            if row and row.click then row.click("LeftButton") end
            return
        end
    end
end

local function Keyer()
    keyer = CreateFrame("Button", "MedalluinNPCKeys", box)
    keyer:RegisterForClicks("AnyUp")
    keyer:SetScript("OnClick", Press)
    ns.On("PLAYER_REGEN_DISABLED", function()
        ClearOverrideBindings(keyer)
        bound = nil
    end)
    ns.On("PLAYER_REGEN_ENABLED", ns.npc.Keys)
    ns.OnSetting("npcSpace", ns.npc.Keys)
end

-- A page to the front: the one its event opened.
function ns.npc.Show(key)
    local p = pages[key]
    if not p or not box then return end
    if current ~= p then offset = 0 end
    current, wanted = p, p
    if p.Shown then p.Shown() end
    ns.npc.Sync()
end

function ns.npc.Update(key)
    if box and current and current.key == key and box:IsShown() then ns.npc.Refresh() end
end

local function Open(p)
    local f = _G[p.frame]
    return f and f:IsShown()
end

-- Shown while one of Blizzard's is, and the character window is not over
-- the chat; on the page in front, or another still open.
function ns.npc.Sync()
    if not box then return end
    -- the page last asked for, as soon as its frame is: the game may show
    -- it only after our handler for its event has run
    if wanted and Open(wanted) then current = wanted end
    if current and not Open(current) then current = nil end
    if not current then
        for _, p in ipairs(order) do
            if Open(p) then current = p break end
        end
    end
    local character = ns.character and ns.character.window
    local bank = ns.bank and ns.bank.cover          -- the bank, docked on the strip
    local on = current ~= nil and not (character and character:IsShown()) and not (bank and bank:IsShown())
    local own = on and current.own
    box:SetShown(on and not own)
    for _, p in ipairs(order) do
        if p.own then p.own:SetShown(p.own == own) end
    end
    ns.chat.Hold(on)
    if on then ns.npc.Refresh() end
    ns.npc.Keys()                   -- a page of its own (the flight map) leaves the box hidden
end

local function Build()
    local strip = ns.strips[-1]
    box = CreateFrame("Frame", "MedalluinNPC", strip)
    ns.window.Mark(box, -1)                      -- its tooltips beside it
    box:SetFrameStrata("BACKGROUND")
    box:SetFrameLevel(ns.chat.box:GetFrameLevel() + 1)
    box:SetWidth(WIDTH)
    box:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
    box:EnableMouse(true)
    local dress = ns.window.Dress(box, 0)
    dress.rule:Hide()
    -- the head's and foot's band of ink, over the box's (BAND_INK)
    local function Band(f)
        local ink = f:CreateTexture(nil, "BACKGROUND")
        ink:SetPoint("TOPLEFT", 1, 0)
        ink:SetPoint("BOTTOMRIGHT", -1, 0)
        ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], BAND_INK)
        return ink
    end
    head = CreateFrame("Frame", nil, box)
    head:SetPoint("TOPLEFT", 0, -1)
    head:SetPoint("TOPRIGHT", 0, -1)
    head:SetHeight(HEAD)
    head.ink = Band(head)
    portrait = head:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(PORTRAIT, PORTRAIT)
    portrait:SetPoint("LEFT", PAD, 0)
    local ring = head:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER", portrait)
    ring:SetSize(PORTRAIT + 4, PORTRAIT + 4)
    ring:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    ring:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    ring:SetDrawLayer("ARTWORK", -1)
    name = ns.Text(head, 20)
    name:SetPoint("BOTTOMLEFT", portrait, "RIGHT", 12, 1)
    name:SetPoint("RIGHT", -(PAD + CONTROL + 18), 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    under = ns.Text(head, 13)
    under:SetPoint("TOPLEFT", portrait, "RIGHT", 12, -3)
    under:SetTextColor(ns.colors.dim[1], ns.colors.dim[2], ns.colors.dim[3])
    close = ns.window.Button(head, CONTROL + 8, function()
        if current and current.Close then current.Close() end
    end, function() return "Close." end)
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetSize(CONTROL, CONTROL)
    close.icon:SetPoint("CENTER")
    close.icon:SetTexture(ns.media .. "strips\\close")
    close:SetHeight(CONTROL + 8)
    close:SetPoint("RIGHT", -PAD, 0)
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", PAD, 0)
    rule:SetPoint("BOTTOMRIGHT", -PAD, 0)

    foot = CreateFrame("Frame", nil, box)
    foot:SetPoint("BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT)
    foot.ink = Band(foot)
    footText = ns.Text(foot, 13)
    footText:SetPoint("LEFT", PAD + 2, 0)
    footText:SetJustifyH("LEFT")
    footText:SetMaxLines(2)
    local footRule = foot:CreateTexture(nil, "ARTWORK")
    footRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    footRule:SetHeight(1)
    footRule:SetPoint("TOPLEFT", PAD, 0)
    footRule:SetPoint("TOPRIGHT", -PAD, 0)

    bar = CreateFrame("Frame", nil, box)
    bar:SetPoint("TOPLEFT", PAD, -(HEAD + PAD))
    bar:SetPoint("TOPRIGHT", -PAD, -(HEAD + PAD))
    bar:SetHeight(TABS)
    bar.say = ns.Text(bar, 14)
    bar.say:SetFont(ns.FontPath("friz"), 14, "")
    bar.say:SetJustifyH("LEFT")
    bar.say:SetSpacing(4)
    bar.say:SetPoint("TOPLEFT")
    bar.say:SetWidth(WIDTH - 2 * PAD - 6)
    bar.ornament = ns.window.Ornament(bar)
    bar.ornament:Hide()
    bar.tabs = ns.window.Segments(bar, { height = TABS, size = 13 })
    bar.tabs:Hide()
    bar.head = ns.Text(bar, HEADING_FONT)           -- a column heading, measured
    bar.head:Hide()
    bar.measure = ns.Text(bar, 13)
    bar.measure:Hide()
    bar:Hide()
    ns.npc.bar = bar
    scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", PAD, -(HEAD + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOT + PAD)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - 2 * PAD, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ns.npc.Scroll(-delta) end)
    -- what stays put under the list (a page's docked blocks): from the
    -- scroll's foot down, over a hairline
    dock = CreateFrame("Frame", nil, box)
    dock:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, 0)
    dock:SetPoint("TOPRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    dock:SetHeight(1)
    dock.rule = dock:CreateTexture(nil, "ARTWORK")
    dock.rule:SetHeight(1)
    dock.rule:SetPoint("TOPLEFT", 0, -GAP / 2)
    dock.rule:SetPoint("TOPRIGHT", 0, -GAP / 2)
    dock.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], RULE)
    dock.body = CreateFrame("Frame", nil, dock)
    dock.body:SetPoint("TOPLEFT", 0, -(GAP + 1))
    dock.body:SetSize(WIDTH - 2 * PAD - 6, 1)
    dock:Hide()
    ns.npc.dock = dock
    thumb = box:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    thumb:Hide()
    box:Hide()
    ns.npc.box = box
    Keyer()
end

-- Blizzard's frame parked and followed
local function Adopt(p)
    local f = _G[p.frame]
    if not f or p.adopted then return end
    p.adopted = true
    ns.Park(f, p.veil and ns.veil)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        hooksecurefunc(f, method, ns.npc.Sync)
    end
end

local function Start()
    if not ns.db.npcWindows or not ns.chat then return end
    Build()
    for _, p in ipairs(order) do
        if _G[p.frame] then
            Adopt(p)
            if p.Start then p.Start() end
        elseif p.addon then
            -- loaded on demand (the trainer's on its first TRAINER_SHOW):
            -- adopted as it loads, before the game shows it
            ns.On("ADDON_LOADED", function(_, loaded) if loaded == p.addon then Adopt(p) end end)
            if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(p.addon) then Adopt(p) end
            if p.Start then p.Start() end
        end
    end
    local character = ns.character and ns.character.window
    if character then
        character:HookScript("OnShow", ns.npc.Sync)
        character:HookScript("OnHide", ns.npc.Sync)
    end
    if ns.quests and ns.quests.Cover then
        ns.quests.Cover(box)
        for _, p in ipairs(order) do
            if p.own then ns.quests.Cover(p.own) end
        end
    end
end

-- the pages (npc/gossip.lua and the rest, loaded after this file) have
-- registered by the time the game logs in
ns.On("PLAYER_LOGIN", Start)
