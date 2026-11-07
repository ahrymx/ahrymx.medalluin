-- The NPC windows: gossip, the quest pages and the vendor, Medalluin's
-- own, in one box standing on the chat box (strips/chat.lua) where the
-- quest tracker's full view stands, as tall as what it shows up to the
-- screen's top. The tracker hides while it is open (quests/tracker.lua),
-- as it does under the character window; the box hides under that too.
--
--   Karen Taylor                                        [x]  <- the NPC
--   ---------------------------------------------------------
--   the page: text, headings, rows, item tiles, tabs           (scrolls
--                                                               past the top)
--   ---------------------------------------------------------
--   2g 36s 55c                      [Repair] [Sell junk] [Goodbye]
--   [General][Trade]                       <- the chat box under it
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
--                             blocks, Foot() -> foot, Close(), Shown() }
--   ns.npc.Show(key) (its page to the front), ns.npc.Update(key) (drawn
--   again if in front), ns.npc.box
--
-- A page's blocks, top down:
--   { "title", text }                    gold, larger
--   { "text", text, color }              a paragraph, wrapped
--   { "heading", text }                  a gold word between rules
--   { "row", label, icon, badge, value, color, dim, selected, click(button),
--     enter(row) }                       a line that clicks
--   { "tiles", { icon, label, count, color, selected, dim, click(button),
--     enter(tile) } ... }                items, two a row
--   { "tabs", { label, selected, click } ... }
-- Its foot: { left = text, { label, click, enabled, tip } ... } (the
-- buttons from the right).
--
-- Built at login, only with the chat box and the NPC windows option on.
local _, ns = ...

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD, HEAD, FOOT, GAP = 8, 26, 28, 6
local ROW, ICON, TILE, TILE_ICON, TABS = 22, 18, 40, 34, 22
local CONTROL = 16
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }

local pages, order = {}, {}
local box, head, name, close, scroll, child, foot, footText, thumb
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
    title = function()
        local t = ns.Text(child, 16)
        t:SetJustifyH("LEFT")
        t:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        return t
    end,
    text = function()
        local t = ns.Text(child, 13)
        t:SetJustifyH("LEFT")
        t:SetSpacing(2)
        return t
    end,
    heading = function() return ns.window.Ornament(child, "") end,
    row = function()
        local r = CreateFrame("Button", nil, child)
        r:SetHeight(ROW)
        Glow(r)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ICON, ICON)
        r.badge = r:CreateTexture(nil, "ARTWORK")
        r.label = ns.Text(r, 13)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        r.value = ns.Text(r, 12)
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
        t.count = ns.Text(t, 11)
        t.count:SetPoint("BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", -1, 1)
        t.label = ns.Text(t, 12)
        t.label:SetJustifyH("LEFT")
        t.label:SetPoint("LEFT", t.icon, "RIGHT", 6, 0)
        t.label:SetPoint("RIGHT", -4, 0)
        Clicks(t)
        return t
    end,
    tab = function()
        local b = CreateFrame("Button", nil, child)
        b:SetHeight(TABS)
        ns.window.Face(b)
        b.label = ns.Text(b, 12)
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
        if i > 1 then y = y + (kind == "row" and blocks[i - 1][1] == "row" and 0 or GAP) end
        if kind == "title" or kind == "text" then
            local t = Take(kind, used)
            t:SetWidth(width)
            t:SetPoint("TOPLEFT", 0, -y)
            t:SetText(b[2] or "")
            if kind == "text" then Colour(t, b[3] or ns.colors.text) end
            y = y + t:GetStringHeight()
        elseif kind == "heading" then
            local h = Take("heading", used)
            h:SetPoint("TOPLEFT", 0, -y)
            h:SetWidth(width)
            h.mid:SetText(b[2])
            y = y + h:GetHeight()
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

-- the foot's buttons, from the right
local buttons = {}
local function Foot(spec)
    spec = spec or {}
    footText:SetText(spec.left or "")
    local right = -PAD
    for i = 1, math.max(#buttons, #spec) do
        local d = spec[i]
        local b = buttons[i]
        if d and not b then
            b = ns.window.Button(foot, 60, function(self) if self.data.click then self.data.click() end end,
                function() return "" end)
            b:SetHeight(FOOT - 6)
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
                b:SetWidth(math.max(60, b.label:GetStringWidth() + 20))
                b:SetEnabled(d.enabled ~= false)
                Colour(b.label, d.enabled ~= false and ns.colors.text or ns.colors.dim)
                b:ClearAllPoints()
                b:SetPoint("RIGHT", foot, "RIGHT", right, 0)
                right = right - b:GetWidth() - 4
            end
        end
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
    name:SetText(UnitName("npc") or "")
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
    head = CreateFrame("Frame", nil, box)
    head:SetPoint("TOPLEFT", PAD, -PAD)
    head:SetPoint("TOPRIGHT", -PAD, -PAD)
    head:SetHeight(HEAD - PAD)
    name = ns.Text(head, 14)
    name:SetPoint("LEFT", 4, 0)
    name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    close = ns.window.Button(head, HEAD - PAD, function()
        if current and current.Close then current.Close() end
    end, function() return "Close." end)
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetSize(CONTROL, CONTROL)
    close.icon:SetPoint("CENTER")
    close.icon:SetTexture(ns.media .. "strips\\close")
    close:SetHeight(HEAD - PAD)
    close:SetPoint("RIGHT")
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    rule:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -2)

    foot = CreateFrame("Frame", nil, box)
    foot:SetPoint("BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT)
    footText = ns.Text(foot, 12)
    footText:SetPoint("LEFT", PAD + 4, 0)
    local footRule = foot:CreateTexture(nil, "ARTWORK")
    footRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    footRule:SetHeight(1)
    footRule:SetPoint("TOPLEFT", PAD, 0)
    footRule:SetPoint("TOPRIGHT", -PAD, 0)

    scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", PAD, -(HEAD + PAD / 2))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOT + PAD / 2)
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
