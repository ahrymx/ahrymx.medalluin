-- The bags: one window for the backpack, the bags and the reagent bag, in
-- the console's ink and gold. Baganator is the reference, kept simple: no
-- other characters, no filters of one's own.
--
--   [the bags' slots]                              <- the drawer, from Bags
--   [Bags]  [search ...............]  [Groups] [Sort] [x]
--   ------------------------------------------------------
--   one grid of every slot, bag by bag (the reagent bag on its own rows),
--   or the items in fixed groups: New, Equipment, Consumables, Quest items,
--   Trade goods, Other, Junk, and one slot for the free ones
--   [money]                                       [Free 23 / 120] .:
--
-- The corner's dots resize it: dragging them sets how many slots go across,
-- and the height follows what is in the bags. Bags opens a drawer above the
-- window with the equipped bags' slots (Blizzard's own, as on its bag bar:
-- put a bag in, swap one, take one out).
--
-- The slots are Blizzard's own (ContainerFrameItemButtonTemplate), each in
-- a holder frame whose ID is its bag, as Blizzard's bags hold them: using,
-- moving, splitting, selling, tooltips and the new-item glow are the
-- client's, and a click is never ours.
--
-- Opening and closing are Blizzard's too. Its bag frames still open and
-- close (keybinds, the backpack, the bank, a vendor), but under a hidden
-- parent, so they are never seen: this window shows while any of them is
-- open. Nothing of Blizzard's is replaced, so nothing is tainted.
--
-- The search is the client's (C_Container.SetItemSearch): names, types and
-- the rest, and the template dims what does not match. Sort is the client's
-- (C_Container.SortBags).
--
-- Only on clients with Blizzard's combined bags (Forever and retail).
local _, ns = ...

local Container = C_Container
local SLOT, GAP, PAD = 37, 4, 8
local HEAD, RULE, FOOT, TITLE = 38, 32, 24, 16
local COLUMNS_MIN, COLUMNS_MAX = 8, 24
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }

-- The groups, in order, and what goes in each (the first that fits).
local GROUPS = {
    { key = "new", name = "New" },
    { key = "equipment", name = "Equipment" },
    { key = "consumable", name = "Consumables" },
    { key = "quest", name = "Quest items" },
    { key = "trade", name = "Trade goods" },
    { key = "other", name = "Other" },
    { key = "junk", name = "Junk" },
    { key = "free", name = "Free slots" },
}
local CLASS = { [2] = "equipment", [4] = "equipment", [0] = "consumable", [12] = "quest",
    [3] = "trade", [5] = "trade", [7] = "trade", [8] = "trade", [9] = "trade", [19] = "trade" }

local window, body, search, money, free, drawer
local holders, slots, headings = {}, {}, {}
local buttons = {}          -- the header's buttons, repainted together
local dirty = true
local Remember              -- below: the window's place, saved
local blizzard = {}         -- Blizzard's bag frames: kept, never seen

-- --------------------------------------------------------------- the bags
local function ReagentBag()
    return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
end

-- The bags shown, in order: the backpack, the equipped bags, the reagent bag.
local function Bags()
    local out = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do table.insert(out, bag) end
    local reagent = ReagentBag()
    if reagent and Container.GetContainerNumSlots(reagent) > 0 then table.insert(out, reagent) end
    return out
end

local function Holder(bag)
    if not holders[bag] then
        local h = CreateFrame("Frame", "MedalluinBagsBag" .. bag, body)
        h:SetID(bag)
        h:SetAllPoints(body)
        holders[bag] = h
        slots[bag] = {}
    end
    return holders[bag]
end

local function Slot(bag, slot)
    Holder(bag)
    local b = slots[bag][slot]
    if b then return b end
    b = CreateFrame("ItemButton", "MedalluinBagsItem" .. bag .. "_" .. slot, holders[bag],
        "ContainerFrameItemButtonTemplate")
    b:SetID(slot)
    b:SetSize(SLOT, SLOT)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetAllPoints()
    well:SetColorTexture(0, 0, 0, 0.45)
    b.itemLevel = ns.PlainText(b, 10)
    b.itemLevel:SetPoint("TOPLEFT", 2, -2)
    b.spare = ns.PlainText(b, 12)       -- on the free slot: how many there are
    b.spare:SetPoint("CENTER")
    b.spare:SetTextColor(unpack(ns.colors.dim))
    slots[bag][slot] = b
    return b
end

-- What group an item goes in.
local function Group(info, bag, slot)
    if C_NewItems and C_NewItems.IsNewItem(bag, slot) then return "new" end
    if info.quality == 0 then return "junk" end
    local quest = Container.GetContainerItemQuestInfo and Container.GetContainerItemQuestInfo(bag, slot)
    if quest and quest.isQuestItem then return "quest" end
    local class = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(info.itemID))
    return CLASS[class] or "other"
end

local function Level(b, info, bag, slot)
    local class = info and C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(info.itemID))
    if not ns.db.bagsItemLevel or (class ~= 2 and class ~= 4) or not C_Item.GetCurrentItemLevel then
        b.itemLevel:SetText("")
        return
    end
    b.itemLevel:SetText(C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot)) or "")
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality or 1]
    if c then b.itemLevel:SetTextColor(c.r, c.g, c.b) end
end

-- A slot as Blizzard's bags draw it (ContainerFrameMixin:UpdateItems), each
-- step only where the client has it.
local function Fill(b, bag, slot, info)
    local texture = info and info.iconFileID
    if ClearItemButtonOverlay then ClearItemButtonOverlay(b) end
    if b.SetHasItem then b:SetHasItem(texture) end
    if b.SetItemButtonTexture then b:SetItemButtonTexture(texture) end
    if SetItemButtonQuality then SetItemButtonQuality(b, info and info.quality, info and info.hyperlink, false,
        info and info.isBound) end
    if SetItemButtonCount then SetItemButtonCount(b, info and info.stackCount) end
    if SetItemButtonDesaturated then SetItemButtonDesaturated(b, info and info.isLocked) end
    local quest = Container.GetContainerItemQuestInfo and Container.GetContainerItemQuestInfo(bag, slot)
    if b.UpdateQuestItem and quest then b:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive) end
    if b.UpdateNewItem then b:UpdateNewItem(info and info.quality) end
    if b.UpdateJunkItem then b:UpdateJunkItem(info and info.quality, info and info.hasNoValue) end
    if b.UpdateItemContextMatching then b:UpdateItemContextMatching() end
    if b.UpdateCooldown then b:UpdateCooldown(texture) end
    if b.SetReadable then b:SetReadable(info and info.isReadable) end
    if b.SetMatchesSearch then b:SetMatchesSearch(not (info and info.isFiltered)) end
    if b.CheckUpdateTooltip then b:CheckUpdateTooltip(GameTooltip:GetOwner()) end
    Level(b, info, bag, slot)
    b.spare:SetText("")
end

-- ------------------------------------------------------------- the layout
local function Place(b, i, top)
    local col, row = (i - 1) % ns.db.bagsColumns, math.floor((i - 1) / ns.db.bagsColumns)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", body, "TOPLEFT", col * (SLOT + GAP), -(top + row * (SLOT + GAP)))
    b:Show()
end

local function Rows(n)
    return math.ceil(n / ns.db.bagsColumns)
end

local function Heading(i, text, top)
    local h = headings[i]
    if not h then
        h = ns.Text(body, 11)
        h:SetTextColor(unpack(GOLD))
        headings[i] = h
    end
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", body, "TOPLEFT", 1, -top)
    h:SetText(text)
    h:Show()
end

-- Every slot of every bag in order, the reagent bag on rows of its own.
local function Grid(list)
    local top, i = 0, 0
    local reagent = ReagentBag()
    for _, bag in ipairs(Bags()) do
        if bag == reagent and i > 0 then
            top = top + Rows(i) * (SLOT + GAP) + GAP * 2
            i = 0
        end
        for _, s in ipairs(list[bag]) do
            i = i + 1
            Place(s.button, i, top)
        end
    end
    return top + Rows(i) * (SLOT + GAP) - GAP
end

-- The items in their groups, a heading over each; the free slots as one
-- slot per kind of bag (the bags, the reagent bag) with how many are free.
local function Groups(list)
    local into = {}
    for _, g in ipairs(GROUPS) do into[g.key] = {} end
    local firstFree, spare = {}, {}
    local reagent = ReagentBag()
    for _, bag in ipairs(Bags()) do
        local kind = bag == reagent and "reagent" or "bags"
        for _, s in ipairs(list[bag]) do
            if s.info then
                table.insert(into[Group(s.info, bag, s.slot)], s.button)
            else
                spare[kind] = (spare[kind] or 0) + 1
                if not firstFree[kind] then      -- the rest stay hidden, as Refresh left them
                    firstFree[kind] = s.button
                    table.insert(into.free, s.button)
                end
            end
        end
    end
    for kind, b in pairs(firstFree) do b.spare:SetText(spare[kind]) end
    local top, n = 0, 0
    for _, g in ipairs(GROUPS) do
        local items = into[g.key]
        if #items > 0 then
            n = n + 1
            Heading(n, g.name, top)
            top = top + TITLE
            for i, b in ipairs(items) do Place(b, i, top) end
            top = top + Rows(#items) * (SLOT + GAP) + GAP
        end
    end
    return top - GAP * 2, n
end

local function Money()
    local copper = GetMoney and GetMoney() or 0
    if GetMoneyString then return GetMoneyString(copper, true) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function Free()
    local reagent = ReagentBag()
    local spare, total, rSpare, rTotal = 0, 0, 0, 0
    for _, bag in ipairs(Bags()) do
        local n, f = Container.GetContainerNumSlots(bag), Container.GetContainerNumFreeSlots(bag)
        if bag == reagent then rSpare, rTotal = f, n else spare, total = spare + f, total + n end
    end
    local text = string.format("Free %d / %d", spare, total)
    if rTotal > 0 then text = text .. string.format("   Reagents %d / %d", rSpare, rTotal) end
    return text
end

local function Paint()
    for _, b in ipairs(buttons) do b.label:SetText(b.text()) end
end

local function Refresh()
    if not window then return end
    dirty = false
    -- every slot read, those past a bag's size hidden (a smaller bag swapped in)
    local list = {}
    for bag, row in pairs(slots) do
        for _, b in pairs(row) do b:Hide() end
        list[bag] = {}
    end
    for _, bag in ipairs(Bags()) do
        list[bag] = list[bag] or {}
        for slot = 1, Container.GetContainerNumSlots(bag) do
            local b = Slot(bag, slot)
            local info = Container.GetContainerItemInfo(bag, slot)
            Fill(b, bag, slot, info)
            table.insert(list[bag], { slot = slot, button = b, info = info })
        end
    end
    for _, h in ipairs(headings) do h:Hide() end
    local height
    if ns.db.bagsView == "groups" then height = Groups(list) else height = Grid(list) end
    local width = ns.db.bagsColumns * (SLOT + GAP) - GAP
    body:SetSize(width, math.max(height, SLOT))
    window:SetSize(width + PAD * 2, math.max(height, SLOT) + HEAD + FOOT + PAD)
    money:SetText(Money())
    free:SetText(Free())
    Paint()
end

-- --------------------------------------------------------------- the window
local function Button(spec)
    local b = CreateFrame("Button", nil, window)
    b:SetSize(spec.width, 20)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.12)
    b.label = ns.Text(b, 10)
    b.label:SetPoint("CENTER")
    b.text = spec.text
    b:SetScript("OnClick", spec.click)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(spec.tip(), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(buttons, b)
    return b
end

-- Where the window sits: where it was dragged, or over the side panel.
local function Anchor()
    window:ClearAllPoints()
    local at = ns.db.bagsPoint
    if at then
        -- { point, relativePoint, x, y }; one saved before the corner, { point,
        -- x, y }, reads as SetPoint(point, UIParent, x, y), which is the same place
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    elseif ns.side and ns.side.panel and ns.side.panel:IsShown() then
        window:SetPoint("BOTTOMRIGHT", ns.side.panel, "TOPRIGHT", 0, 36)
    else
        window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 260)
    end
end

-- Where it is now, kept for the next opening and the next session.
Remember = function()
    local point, _, relative, x, y = window:GetPoint()
    ns.db.bagsPoint = { point, relative, x, y }
end

-- The new items are seen once the bags close, as Blizzard's bags do it.
local function Seen()
    if not C_NewItems then return end
    for _, bag in ipairs(Bags()) do
        for slot = 1, Container.GetContainerNumSlots(bag) do
            if C_NewItems.IsNewItem(bag, slot) then C_NewItems.RemoveNewItem(bag, slot) end
        end
    end
end

-- ------------------------------------------------------------- the drawer
-- The equipped bags' slots, left to right as the bags are numbered, then
-- the reagent bag and the key ring. Blizzard's own buttons, off its bag bar
-- (which blizzard.lua kills), styled as the old strip drawer styled them.
local DRAWER_SLOT, DRAWER_PAD = 30, 6
local OVER = { pushed = { 0, 0, 0, 0.35 }, highlight = { 1, 1, 1, 0.15 }, checked = { 0.77, 0.65, 0.34, 0.35 } }
local bagSlots = {}
local placing = false

local function StyleBagSlot(btn)
    local icon = ns.BagIcon(btn)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if btn.SquareMask then icon:RemoveMaskTexture(btn.SquareMask) end
    local edge = btn:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0)
    edge:SetAllPoints()
    btn.medalluin = {
        pushed = btn:CreateTexture(), highlight = btn:CreateTexture(),
        checked = btn.SetCheckedTexture and btn:CreateTexture() or nil,
        restore = function(m)
            for key, c in pairs(OVER) do
                local t = m[key]
                if t then
                    t:ClearAllPoints()
                    t:SetAllPoints(icon)
                    t:SetColorTexture(unpack(c))
                    t:SetBlendMode("BLEND")
                    t:SetAlpha(1)
                end
            end
            local open = btn.SlotHighlightTexture       -- marks the bag whose window is open
            if open then
                open:ClearAllPoints()
                open:SetAllPoints(icon)
                open:SetColorTexture(unpack(OVER.checked))
            end
        end,
    }
    ns.WatchBagButton(btn)
end

-- The key ring keeps its own tall art, which Forever sizes for its own
-- 33x45 button: fitted to ours, and again whenever Blizzard re-sets it.
local function FitRing(ring)
    local function Fit()
        for _, t in ipairs({ ring:GetNormalTexture(), ring:GetPushedTexture(), ring:GetHighlightTexture() }) do
            if t then
                t:ClearAllPoints()
                t:SetAllPoints(ring)
            end
        end
    end
    Fit()
    if ring.UpdateTextures then hooksecurefunc(ring, "UpdateTextures", Fit) end
end

local function PlaceBagSlots()
    placing = true
    local x = DRAWER_PAD
    for _, b in ipairs(bagSlots) do
        local w = b == KeyRingButton and DRAWER_SLOT / 2 or DRAWER_SLOT
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", drawer.inner, "TOPLEFT", x, -DRAWER_PAD)
        b:SetSize(w, DRAWER_SLOT)
        x = x + w + GAP
    end
    placing = false
    drawer.full = x - GAP + DRAWER_PAD
    drawer.inner:SetSize(drawer.full, DRAWER_SLOT + 2 * DRAWER_PAD)
end

-- It opens out of the window's top-left corner and grows to the right.
local GROW = 0.15           -- seconds

local function Drawer()
    drawer = CreateFrame("Frame", "MedalluinBagsDrawer", window)
    drawer:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, 2)
    drawer:SetHeight(DRAWER_SLOT + 2 * DRAWER_PAD)
    drawer:SetClipsChildren(true)
    drawer:EnableMouse(true)
    drawer.inner = CreateFrame("Frame", nil, drawer)
    drawer.inner:SetPoint("TOPLEFT")
    local edge = drawer:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local bg = drawer:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)
    for _, name in ipairs({ "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
        "CharacterReagentBag0Slot", "KeyRingButton" }) do
        local b = _G[name]
        if b then
            b:SetParent(drawer.inner)
            b:SetFrameLevel(drawer:GetFrameLevel() + 2)
            if b == KeyRingButton then FitRing(b) else StyleBagSlot(b) end
            -- Blizzard's collapsed bag bar would hide them
            if b.SetBarExpanded then hooksecurefunc(b, "SetBarExpanded", b.Show) end
            b:Show()
            table.insert(bagSlots, b)
        end
    end
    PlaceBagSlots()
    for _, b in ipairs(bagSlots) do
        hooksecurefunc(b, "SetPoint", function()
            if not placing then PlaceBagSlots() end
        end)
    end
    drawer:SetScript("OnShow", function(self)
        self.t = 0
        self:SetWidth(1)
    end)
    drawer:SetScript("OnUpdate", function(self, elapsed)
        if self.t >= GROW then return end
        self.t = math.min(GROW, self.t + elapsed)
        self:SetWidth(math.max(1, self.full * self.t / GROW))
    end)
    drawer:Hide()
end

-- The title: Bags, which opens and closes the drawer.
local function Title()
    local b = CreateFrame("Button", nil, window)
    b:SetPoint("TOPLEFT", PAD - 2, -PAD + 2)
    b:SetHeight(20)
    b.label = ns.Text(b, 13)
    b.label:SetPoint("LEFT", 2, 0)
    b.label:SetText("Bags")
    b.label:SetTextColor(unpack(GOLD))
    b:SetWidth(b.label:GetStringWidth() + 4)
    b:SetScript("OnClick", function()
        if not drawer then Drawer() end
        drawer:SetShown(not drawer:IsShown())
    end)
    b:SetScript("OnEnter", function(self)
        self.label:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(drawer and drawer:IsShown() and "Hide your bags' slots."
            or "Show your bags' slots: put a bag in, swap one or take one out.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.label:SetTextColor(unpack(GOLD))
        GameTooltip:Hide()
    end)
    window.title = b
    return b
end

-- ---------------------------------------------------------- the corner
-- Six dots in a stair, the corner's mark: dragging them sets the columns.
local function Columns(width)
    local n = math.floor((width - 2 * PAD + GAP) / (SLOT + GAP) + 0.5)
    return math.max(COLUMNS_MIN, math.min(COLUMNS_MAX, n))
end

local function Grip()
    local g = CreateFrame("Button", "MedalluinBagsGrip", window)
    g:SetSize(12, 12)
    g:SetPoint("BOTTOMRIGHT", -3, 3)
    g.dots = {}
    for row = 0, 2 do
        for col = 0, 2 - row do         -- three dots on the bottom, one at the top
            local d = g:CreateTexture(nil, "OVERLAY")
            d:SetSize(2, 2)
            d:SetPoint("BOTTOMRIGHT", -col * 4, row * 4)
            d:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            table.insert(g.dots, d)
        end
    end
    local function Tint(c)
        for _, d in ipairs(g.dots) do d:SetColorTexture(c[1], c[2], c[3], 1) end
    end
    g:SetScript("OnEnter", function() Tint(GOLD) end)
    g:SetScript("OnLeave", function(self) if not self.held then Tint(GOLD_D) end end)
    -- held: the window pinned by its top-left, the columns following the pointer
    g:SetScript("OnMouseDown", function(self)
        local left, top = window:GetLeft(), window:GetTop()
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        self.held = true
    end)
    g:SetScript("OnMouseUp", function(self)
        self.held = false
        Remember()
        if not self:IsMouseOver() then Tint(GOLD_D) end
    end)
    g:SetScript("OnUpdate", function(self)
        if not self.held then return end
        local x = GetCursorPosition() / window:GetEffectiveScale()
        local n = Columns(x - window:GetLeft())
        if n ~= ns.db.bagsColumns then ns.SetOption("bagsColumns", n) end
    end)
    window.grip = g
end

local function Build()
    window = CreateFrame("Frame", "MedalluinBags", UIParent)
    window:SetFrameStrata("MEDIUM")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Remember()
    end)
    window:Hide()
    local edge = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local bg = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)

    local title = Title()
    local rule = window:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rule:SetPoint("TOPLEFT", PAD, -RULE)
    rule:SetPoint("TOPRIGHT", -PAD, -RULE)
    rule:SetHeight(1)
    window.rule = rule

    local close = Button({ width = 20, text = function() return "x" end, click = function() CloseAllBags() end,
        tip = function() return "Close the bags." end })
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    local sort = Button({ width = 42, text = function() return "Sort" end,
        click = function() if Container.SortBags then Container.SortBags() end end,
        tip = function() return "Sort the bags, as the game sorts them." end })
    sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
    local view = Button({ width = 54, text = function() return ns.db.bagsView == "groups" and "Grid" or "Groups" end,
        click = function() ns.SetOption("bagsView", ns.db.bagsView == "groups" and "grid" or "groups") end,
        tip = function()
            return ns.db.bagsView == "groups" and "Show every slot, bag by bag."
                or "Show the items in groups: new, equipment, consumables and the rest."
        end })
    view:SetPoint("RIGHT", sort, "LEFT", -4, 0)

    search = CreateFrame("EditBox", "MedalluinBagsSearch", window, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("LEFT", title, "RIGHT", 12, 0)
    search:SetPoint("RIGHT", view, "LEFT", -8, 0)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(self)
        if Container.SetItemSearch then Container.SetItemSearch(self:GetText()) end
    end)

    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", PAD, -HEAD)

    money = ns.PlainText(window, 11)
    money:SetPoint("BOTTOMLEFT", PAD, PAD - 2)
    free = ns.PlainText(window, 11)
    free:SetPoint("BOTTOMRIGHT", -PAD - 8, PAD - 2)     -- clear of the corner's dots
    Grip()
    free:SetTextColor(unpack(ns.colors.dim))

    window:SetScript("OnShow", function()
        Anchor()
        Refresh()
    end)
    window:SetScript("OnHide", function()
        Seen()
        if drawer then drawer:Hide() end
    end)
    -- a change is drawn once, at the next frame, and only while the bags are open
    window:SetScript("OnUpdate", function(self)
        if dirty and self:IsShown() then Refresh() end
    end)
    Anchor()
end

-- ---------------------------------------------------- Blizzard's bag frames
local function Open()
    for _, f in ipairs(blizzard) do
        if f:IsShown() then return true end
    end
    return false
end

local function Sync()
    local open = Open()
    if open ~= window:IsShown() then window:SetShown(open) end
end

-- Under a hidden parent, put back if Blizzard moves it (it does, for full
-- screen panels); each opening and closing told to the window.
local function Keep(f)
    ns.Park(f)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if f[method] then hooksecurefunc(f, method, Sync) end
    end
    table.insert(blizzard, f)
end

local function Start()
    if not ns.db.bags or not Container or not Container.GetContainerItemInfo or not ContainerFrameCombinedBags then
        return
    end
    Build()
    Keep(ContainerFrameCombinedBags)
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f then Keep(f) end
    end
    ns.bags = { window = window, blizzard = blizzard }
    local function Dirty() dirty = true end
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
        "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED", "UNIT_QUEST_LOG_CHANGED",
        "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED" }) do
        ns.On(e, Dirty)
    end
    for _, key in ipairs({ "bagsView", "bagsColumns", "bagsItemLevel" }) do ns.OnSetting(key, Refresh) end
    Sync()
end

ns.On("PLAYER_LOGIN", Start)
