-- Item slots laid out in a frame, for the bags window (inventory/bags.lua)
-- and the bank's (inventory/bank.lua): each container's slots Blizzard's own
-- buttons (ContainerFrameItemButtonTemplate) in a holder frame whose ID is
-- the container, as Blizzard's bags hold them, so using, moving, splitting,
-- tooltips and the new-item glow are the client's.
--
--   local set = ns.Slots{ prefix (the frames' names), body, Bags() -> the
--                         containers in order, Columns() -> slots across,
--                         View() -> "grid" | "bags" | "groups",
--                         Apart(bag) -> true: a container on rows of its
--                         own in the grid, and free slots of its own kind in
--                         the groups (the reagent bag), Name(bag) }
--   set.Refresh() -> width, height (the body sized to them)
--   set.Make()    every container's slots made, out of combat only
--
-- A slot is never made in combat: a ContainerFrameItemButtonTemplate button
-- created in combat runs its clicks tainted until /reload, and using an
-- item (UseContainerItem) is then forbidden. So the slots are made ahead
-- (Make, at login and as the bags change), and one still missing in combat
-- is left out until it ends.
--
-- The views:
--   grid    every slot in order, a container Apart on rows of its own
--   bags    each container on rows of its own, under its name
--   groups  the items in fixed groups: New, Equipment, Consumables, Quest
--           items, Trade goods, Other, Junk, and one slot per kind for the
--           free ones, with how many there are
local _, ns = ...

local Container = C_Container
local SLOT, GAP, TITLE = 37, 4, 16
local GOLD = { 0.941, 0.831, 0.533 }

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

function ns.Slots(spec)
    local set = { holders = {}, slots = {}, headings = {} }
    local body, holders, slots, headings = spec.body, set.holders, set.slots, set.headings

    local function Holder(bag)
        if not holders[bag] then
            local h = CreateFrame("Frame", spec.prefix .. "Bag" .. bag, body)
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
        b = CreateFrame("ItemButton", spec.prefix .. "Item" .. bag .. "_" .. slot, holders[bag],
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

    -- -------------------------------------------------------- the layout
    local columns
    local function Place(b, i, top)
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", body, "TOPLEFT", col * (SLOT + GAP), -(top + row * (SLOT + GAP)))
        b:Show()
    end

    local function Rows(n) return math.ceil(n / columns) end

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

    local function Apart(bag) return spec.Apart and spec.Apart(bag) or false end

    -- Every slot of every container in order, one Apart on rows of its own.
    local function Grid(list)
        local top, i = 0, 0
        for _, bag in ipairs(spec.Bags()) do
            if Apart(bag) and i > 0 then
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

    -- Each container on rows of its own, its name over it.
    local function ByBag(list)
        local top, n = 0, 0
        for _, bag in ipairs(spec.Bags()) do
            local items = list[bag]
            if #items > 0 then
                n = n + 1
                Heading(n, spec.Name(bag), top)
                top = top + TITLE
                for i, s in ipairs(items) do Place(s.button, i, top) end
                top = top + Rows(#items) * (SLOT + GAP) + GAP
            end
        end
        return top - GAP * 2, n
    end

    -- The items in their groups, a heading over each; the free slots as one
    -- slot per kind of container (the rest, one Apart) with how many are free.
    local function Groups(list)
        local into = {}
        for _, g in ipairs(GROUPS) do into[g.key] = {} end
        local firstFree, spare = {}, {}
        for _, bag in ipairs(spec.Bags()) do
            local kind = Apart(bag) and "apart" or "bags"
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

    function set.Refresh()
        columns = spec.Columns()
        -- every slot read, those past a container's size hidden (a smaller bag swapped in)
        local list = {}
        for bag, row in pairs(slots) do
            for _, b in pairs(row) do b:Hide() end
            list[bag] = {}
        end
        local fight = InCombatLockdown()
        for _, bag in ipairs(spec.Bags()) do
            list[bag] = list[bag] or {}
            for slot = 1, Container.GetContainerNumSlots(bag) do
                local b = slots[bag] and slots[bag][slot] or not fight and Slot(bag, slot)
                if b then
                    local info = Container.GetContainerItemInfo(bag, slot)
                    Fill(b, bag, slot, info)
                    table.insert(list[bag], { slot = slot, button = b, info = info })
                end
            end
        end
        for _, h in ipairs(headings) do h:Hide() end
        local height
        local view = spec.View()
        if view == "groups" then
            height = Groups(list)
        elseif view == "bags" then
            height = ByBag(list)
        else
            height = Grid(list)
        end
        local width = columns * (SLOT + GAP) - GAP
        height = math.max(height, SLOT)
        body:SetSize(width, height)
        return width, height
    end

    function set.Make()
        if InCombatLockdown() then return end
        for _, bag in ipairs(spec.Bags()) do
            for slot = 1, Container.GetContainerNumSlots(bag) do Slot(bag, slot) end
        end
    end

    -- how many slots go across a width
    function set.Fit(width) return math.max(1, math.floor((width + GAP) / (SLOT + GAP))) end

    return set
end

ns.slotSize = { slot = SLOT, gap = GAP }
