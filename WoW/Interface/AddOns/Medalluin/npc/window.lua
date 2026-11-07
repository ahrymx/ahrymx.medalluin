-- The NPC windows: gossip, the quest pages and the vendor, Medalluin's
-- own, in one box standing on the chat box (strips/chat.lua) where the
-- quest tracker's full view stands, as tall as what it shows up to the
-- screen's top. The tracker hides while it is open (quests/tracker.lua),
-- as it does under the character window; the box hides under that too.
--
--   (portrait) The Defias Brotherhood                       [x]  <- the page's
--              Gryan Stoutmantle                                  title, the NPC
--   ---------------------------------------------------------
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
--   local page = ns.npc.Page{ key, frame (Blizzard's, by name), Blocks() ->
--                             blocks, Foot() -> foot, Title() -> title,
--                             under (the NPC's name when not given), Close(),
--                             Shown() }
--   ns.npc.Show(key) (its page to the front), ns.npc.Update(key) (drawn
--   again if in front), ns.npc.box
--
-- A page's blocks, top down:
--   { "text", text, color }              a paragraph, wrapped
--   { "heading", text }                  a label on a dark pill
--   { "row", label, icon, badge, value, color, dim, selected, click(button),
--     enter(row) }                       a line that clicks
--   { "tiles", { icon, label, count, color, selected, dim, click(button),
--     enter(tile) } ... }                items, two a row
--   { "tabs", { label, selected, click } ... }
-- Its foot: { left = text, { label, click, enabled, tip, primary } ... },
-- the buttons left to right: sharing the width when there is no text, else
-- at the right; the primary one wears the deed's red.
--
-- Built at login, only with the chat box and the NPC windows option on.
local _, ns = ...

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD, HEAD, FOOT, GAP = 14, 60, 50, 12
local PORTRAIT, BUTTON = 42, 32
local ROW, ICON, TILE, TILE_ICON, TABS, PILL = 30, 20, 48, 40, 26, 22
local CONTROL = 16
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DEED = { 0.42, 0.13, 0.09 }                -- the primary button's fill
-- the head's and foot's own ink over the box's: 5/9 more, the box's fade
-- from solid to a tenth becomes solid to 60% (1 - 0.9 * 4/9 = 0.6)
local BAND_INK = 5 / 9

local pages, order = {}, {}
local box, head, portrait, name, under, close, scroll, child, foot, footText, thumb
local current
local pools = {}

ns.npc = { pages = pages }

function ns.npc.Page(spec)
    pages[spec.key] = spec
    table.insert(order, spec)
    return spec
end

-- ------------------------------------------------------------ the blocks
local function Glow(f)
    local glow = f:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    f.mark = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.mark:SetAllPoints()
    f.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
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

local make = {
    -- what the NPC says, in a face made for reading (the game's own)
    text = function()
        local t = ns.Text(child, 14)
        t:SetFont(ns.FontPath("friz"), 14, "")
        t:SetJustifyH("LEFT")
        t:SetSpacing(4)
        return t
    end,
    heading = function()
        local h = CreateFrame("Frame", nil, child)
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
    row = function()
        local r = CreateFrame("Button", nil, child)
        r:SetHeight(ROW)
        Glow(r)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ICON, ICON)
        r.badge = r:CreateTexture(nil, "ARTWORK")
        r.label = ns.Text(r, 14)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        r.value = ns.Text(r, 13)
        r.value:SetPoint("RIGHT", -6, 0)
        Clicks(r)
        return r
    end,
    tile = function()
        local t = CreateFrame("Button", nil, child)
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
    tab = function()
        local b = CreateFrame("Button", nil, child)
        b:SetHeight(TABS)
        ns.window.Face(b)
        b.label = ns.Text(b, 13)
        b.label:SetPoint("CENTER")
        b:SetScript("OnClick", function(self) self.data.click() end)
        return b
    end,
}

-- the n-th of a kind this draw, made the first time
local function Take(kind, used)
    pools[kind] = pools[kind] or {}
    used[kind] = (used[kind] or 0) + 1
    local f = pools[kind][used[kind]]
    if not f then
        f = make[kind]()
        pools[kind][used[kind]] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
end

local function Colour(t, c) t:SetTextColor(c[1], c[2], c[3]) end

-- Lays the blocks out down the scroll child; how tall they came to.
local function Lay(blocks, width)
    local used, y = {}, 0
    for i, b in ipairs(blocks) do
        local kind = b[1]
        -- rows run together; a pill sits closer to what it labels
        if i > 1 then
            local last = blocks[i - 1][1]
            y = y + ((kind == "row" and last == "row") and 0 or last == "heading" and GAP / 2 or GAP)
        end
        if kind == "text" then
            local t = Take(kind, used)
            t:SetWidth(width)
            t:SetPoint("TOPLEFT", 0, -y)
            t:SetText(b[2] or "")
            Colour(t, b[3] or ns.colors.text)
            y = y + t:GetStringHeight()
        elseif kind == "heading" then
            local h = Take("heading", used)
            if i > 1 then y = y + GAP / 2 end    -- and further from what went before
            h:SetPoint("TOPLEFT", 0, -y)
            h.mid:SetText(b[2])
            h:SetWidth(h.mid:GetStringWidth() + 24)
            y = y + PILL
        elseif kind == "row" then
            local r = Take("row", used)
            r.data = b
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetWidth(width)
            local x = 4
            r.icon:SetShown(b.icon ~= nil)
            if b.icon then
                r.icon:SetTexture(b.icon)
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
            r.label:SetPoint("RIGHT", r, "RIGHT", b.value and -(r.value:GetStringWidth() + 14) or -6, 0)
            r.mark:SetShown(b.selected and true or false)
            y = y + ROW
        elseif kind == "tiles" then
            local half = (width - GAP) / 2
            -- b[1] is the block's kind: the tiles are what follows it
            for j = 1, #b - 1 do
                local d = b[j + 1]
                local t = Take("tile", used)
                t.data = d
                local col, row = (j - 1) % 2, math.floor((j - 1) / 2)
                t:SetPoint("TOPLEFT", col * (half + GAP), -(y + row * (TILE + GAP)))
                t:SetWidth(half)
                t.icon:SetTexture(d.icon)
                t.icon:SetDesaturated(d.dim and true or false)
                t.count:SetText(d.count and d.count > 1 and d.count or "")
                t.label:SetText(d.label or "")
                Colour(t.label, d.color or d.dim and ns.colors.dim or ns.colors.text)
                t.mark:SetShown(d.selected and true or false)
            end
            y = y + math.ceil((#b - 1) / 2) * (TILE + GAP) - GAP
        elseif kind == "tabs" then
            local x = 0
            for j = 2, #b do
                local d = b[j]
                local t = Take("tab", used)
                t.data = d
                t.label:SetText(d.label)
                Colour(t.label, d.selected and GOLD or ns.colors.dim)
                t.mark:SetShown(d.selected and true or false)
                t:SetWidth(t.label:GetStringWidth() + 20)
                t:SetPoint("TOPLEFT", x, -y)
                x = x + t:GetWidth() + 4
            end
            y = y + TABS
        end
    end
    for kind, list in pairs(pools) do
        for i = (used[kind] or 0) + 1, #list do list[i]:Hide() end
    end
    return y
end

-- the foot's buttons, left to right: the width shared out when nothing
-- is written beside them, else each as wide as its word, at the right
local buttons = {}
local function Foot(spec)
    spec = spec or {}
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
                    ns.Tip(self, "ANCHOR_TOP", { title = self.data.label, color = GOLD, { "body", self.data.tip } })
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

-- The page drawn again, and the box fitted to it.
function ns.npc.Refresh()
    if not box or not current then return end
    local npc = UnitName("npc") or ""
    local title = current.Title and current.Title()
    name:SetText(title or npc)
    under:SetText(title and npc or "")
    if portrait and SetPortraitTexture then SetPortraitTexture(portrait, "npc") end
    local width = WIDTH - 2 * PAD - 6
    child:SetWidth(width)
    local h = Lay(current.Blocks(), width)
    child:SetHeight(math.max(1, h))
    Foot(current.Foot and current.Foot())
    local want = HEAD + PAD + h + PAD + FOOT
    box:SetHeight(math.min(want, Room()))
    offset = math.min(offset, scroll:GetVerticalScrollRange() or 0)
    scroll:SetVerticalScroll(offset)
    Thumb()
end

-- A page to the front: the one its event opened.
function ns.npc.Show(key)
    local p = pages[key]
    if not p or not box then return end
    if current ~= p then offset = 0 end
    current = p
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
    if current and not Open(current) then current = nil end
    if not current then
        for _, p in ipairs(order) do
            if Open(p) then current = p break end
        end
    end
    local character = ns.character and ns.character.window
    local on = current ~= nil and not (character and character:IsShown())
    box:SetShown(on)
    ns.chat.Hold(on)
    if on then ns.npc.Refresh() end
end

local function Build()
    local strip = ns.strips[-1]
    box = CreateFrame("Frame", "MedalluinNPC", strip)
    box:SetFrameStrata("BACKGROUND")
    box:SetFrameLevel(ns.chat.box:GetFrameLevel() + 1)
    box:SetWidth(WIDTH)
    box:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
    box:EnableMouse(true)
    local dress = ns.window.Dress(box, 0)
    dress.rule:Hide()
    for point, lines in pairs(dress.corners) do
        if point:find("^BOTTOM") then for _, t in ipairs(lines) do t:Hide() end end
    end
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

    scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", PAD, -(HEAD + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOT + PAD)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - 2 * PAD, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ns.npc.Scroll(-delta) end)
    thumb = box:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    thumb:Hide()
    box:Hide()
    ns.npc.box = box
end

local function Start()
    if not ns.db.npcWindows or not ns.chat then return end
    Build()
    for _, p in ipairs(order) do
        local f = _G[p.frame]
        if f then
            ns.Park(f)
            for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
                hooksecurefunc(f, method, ns.npc.Sync)
            end
            if p.Start then p.Start() end
        end
    end
    local character = ns.character and ns.character.window
    if character then
        character:HookScript("OnShow", ns.npc.Sync)
        character:HookScript("OnHide", ns.npc.Sync)
    end
    if ns.quests and ns.quests.Cover then ns.quests.Cover(box) end
end

-- the pages (npc/gossip.lua and the rest, loaded after this file) have
-- registered by the time the game logs in
ns.On("PLAYER_LOGIN", Start)
