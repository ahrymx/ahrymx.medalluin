-- The vendor, in the NPC box (npc/window.lua): what it sells, what you
-- could sell it, and what you sold it, on three tabs of our own, and its
-- repairs and your junk in the foot.
--
--   [Merchant][Sell][Buyback]
--   [icon] Mining Pick                              10c
--   [icon] Elemental Flux                    15s  2 [o]   <- an extended cost
--   2g 36s 55c                [Repair] [Guild] [Sell junk] [Goodbye]
--
-- A click buys one (one bundle: a stack of five sells as five); Shift
-- asks how many, up to a stack; an item that costs more than money, or
-- more than the game's high price, asks first. Asking happens in the foot:
--
--   Buy 20 Strong Flux for 4s?              [-] [+] [Buy] [Cancel]
--
-- Sell lists what in your bags the vendor would buy, the most money first
-- (a stack at its whole price); a click sells it, as the bag's right click
-- would. A bag item's right click still sells too: Blizzard's MerchantFrame
-- is still shown (only parked), and stays untouched: no tab of its set,
-- nothing of it called (npc/window.lua, Taint).
--
-- A locked item (inventory/locks.lua) is on neither Sell nor Sell junk, and
-- its right click in the bags is guarded (inventory/slots.lua).
local _, ns = ...

local HIGH = MERCHANT_HIGH_PRICE_COST or 1500000      -- the game's own: 150 gold
local RED = { 1, 0.3, 0.25 }

local tab = "merchant"
local pending                    -- { index, name, count, most, stack, price, extended }

local Money = ns.npc.Money

-- An item the vendor sells, the same from either API. One the client has
-- not cached yet comes without its name (and link): the game's "retrieving"
-- words stand in until GET_ITEM_INFO_RECEIVED draws it again.
local WAIT = RETRIEVING_ITEM_INFO or "Retrieving item information"
local function Item(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local t = C_MerchantFrame.GetItemInfo(i)
        if t then
            return { name = t.name or WAIT, icon = t.texture, price = t.price or 0, stack = t.stackCount or 1,
                available = t.numAvailable, usable = t.isUsable, extended = t.hasExtendedCost }
        end
    end
    local name, icon, price, stack, available, usable, extended = GetMerchantItemInfo(i)
    if not name then return end
    return { name = name, icon = icon, price = price or 0, stack = stack or 1, available = available,
        usable = usable, extended = extended }
end

-- the item's quality colour, from its link
local function Quality(link)
    local info = link and (C_Item and C_Item.GetItemInfo or GetItemInfo)
    local quality = info and select(3, info(link))
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return c and { c.r, c.g, c.b }
end

-- what it costs: money, and each currency or item, with its icon
local function Cost(i, item)
    local parts = {}
    if item.price > 0 then table.insert(parts, Money(item.price)) end
    if item.extended and GetMerchantItemCostInfo then
        for j = 1, GetMerchantItemCostInfo(i) or 0 do
            local icon, value = GetMerchantItemCostItem(i, j)
            if icon and value then table.insert(parts, format("%d |T%s:14:14|t", value, icon)) end
        end
    end
    return table.concat(parts, " ")
end

local function Buy(i, count)
    BuyMerchantItem(i, count)
    pending = nil
    ns.npc.Update("merchant")
end

-- ask first: n of it, from the foot
local function Ask(i, item, count)
    local most = GetMerchantItemMaxStack and GetMerchantItemMaxStack(i) or item.stack
    pending = { index = i, name = item.name, count = math.max(1, math.min(count, most)), most = most,
        stack = item.stack, price = item.price, extended = item.extended }
    ns.npc.Update("merchant")
end

local function Click(i, item, link)
    return function(button)
        if button == "RightButton" then return end
        if IsModifiedClick("CHATLINK") and link and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
            ChatEdit_InsertLink(link)
        elseif IsModifiedClick("DRESSUP") and link and DressUpItemLink then
            DressUpItemLink(link)
        elseif IsShiftKeyDown() then
            Ask(i, item, GetMerchantItemMaxStack and GetMerchantItemMaxStack(i) or item.stack)
        elseif item.extended or item.price >= HIGH then
            Ask(i, item, item.stack)
        else
            Buy(i, item.stack)
        end
    end
end

local function Merchant(out)
    local n = GetMerchantNumItems() or 0
    for i = 1, n do
        local item = Item(i)
        if item then
            local link = GetMerchantItemLink and GetMerchantItemLink(i)
            local label = item.name
            if item.stack > 1 then label = format("%s  x%d", label, item.stack) end
            if item.available and item.available >= 0 then label = format("%s  (%d)", label, item.available) end
            table.insert(out, { "row", label = label, icon = item.icon, value = Cost(i, item),
                color = item.usable == false and RED or Quality(link),
                click = Click(i, item, link),
                enter = function(row)
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetMerchantItem(i)
                    GameTooltip:Show()
                end })
        end
    end
    if n == 0 then table.insert(out, { "text", "Nothing for sale.", ns.colors.dim }) end
end

local function Buyback(out)
    local n = GetNumBuybackItems and GetNumBuybackItems() or 0
    for i = 1, n do
        local name, icon, price, quantity, _, usable = GetBuybackItemInfo(i)
        if name then
            local label = (quantity or 1) > 1 and format("%s  x%d", name, quantity) or name
            table.insert(out, { "row", label = label, icon = icon, value = Money(price or 0),
                color = usable == false and RED or Quality(GetBuybackItemLink and GetBuybackItemLink(i)),
                click = function(button) if button ~= "RightButton" then BuybackItem(i) end end,
                enter = function(row)
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetBuybackItem(i)
                    GameTooltip:Show()
                end })
        end
    end
    if n == 0 then table.insert(out, { "text", "Nothing sold here yet.", ns.colors.dim }) end
end

-- ------------------------------------------------------------ to sell
-- Everything in your bags the vendor buys and you have not locked: { bag,
-- slot, info, name, value (the whole stack's) }, in the bags' order. With
-- `locked`, the locked ones alone.
local function Sellable(locked)
    local C, out = C_Container, {}
    if not C or not C.GetContainerItemInfo then return out end
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local item = C.GetContainerItemInfo(bag, slot)
            if item and not item.hasNoValue and ns.locks.Is(item.itemID) == (locked or false) then
                local name, _, _, _, _, _, _, _, _, _, price = info(item.itemID)
                if price and price > 0 then
                    table.insert(out, { bag = bag, slot = slot, info = item, name = item.itemName or name or WAIT,
                        value = price * (item.stackCount or 1) })
                end
            end
        end
    end
    return out
end

-- one sold, as a right click in the bags would; never in combat, and never
-- once the vendor has gone (the same call would then use the item)
local function Sell(s)
    if InCombatLockdown() or not (MerchantFrame and MerchantFrame:IsShown()) then return end
    C_Container.UseContainerItem(s.bag, s.slot)
end

local function SellList(out)
    local list = Sellable()
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    for _, s in ipairs(list) do
        local n, link = s.info.stackCount or 1, s.info.hyperlink
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[s.info.quality or 1]
        table.insert(out, { "row", label = n > 1 and format("%s  x%d", s.name, n) or s.name, icon = s.info.iconFileID,
            value = Money(s.value), color = c and { c.r, c.g, c.b },
            click = function(button)
                if button == "RightButton" then return end
                if IsModifiedClick("CHATLINK") and link and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
                    ChatEdit_InsertLink(link)
                elseif IsModifiedClick("DRESSUP") and link and DressUpItemLink then
                    DressUpItemLink(link)
                else
                    Sell(s)
                end
            end,
            enter = function(row)
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(s.bag, s.slot)
                GameTooltip:Show()
            end })
    end
    if #list == 0 then table.insert(out, { "text", "Nothing in your bags to sell.", ns.colors.dim }) end
end

local function Blocks()
    local function To(key)
        return function()
            tab = key
            if key ~= "merchant" then pending = nil end
            ns.npc.Update("merchant")
        end
    end
    local out = { { "tabs",
        { label = "Merchant", selected = tab == "merchant", click = To("merchant") },
        { label = "Sell", selected = tab == "sell", click = To("sell") },
        { label = "Buyback", selected = tab == "buyback", click = To("buyback") } } }
    if tab == "buyback" then Buyback(out) elseif tab == "sell" then SellList(out) else Merchant(out) end
    return out
end

-- -------------------------------------------------------------- junk
-- Your grey items that sell: how many, and for how much.
local function Junk(locked)
    local count, value, slots = 0, 0, {}
    for _, s in ipairs(Sellable(locked)) do
        if s.info.quality == 0 then
            count = count + 1
            value = value + s.value
            table.insert(slots, { s.bag, s.slot })
        end
    end
    return count, value, slots
end

local function SellJunk()
    -- the game's own sells every grey, so not while one is locked
    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems and Junk(true) == 0 then
        C_MerchantFrame.SellAllJunkItems()
        return
    end
    -- a client without it: each, as a right click would, and never in combat
    if InCombatLockdown() then return end
    local _, _, slots = Junk()
    for _, s in ipairs(slots) do C_Container.UseContainerItem(s[1], s[2]) end
end

-- ------------------------------------------------------------ the foot
local function Foot()
    local close = { label = "Goodbye", click = function() CloseMerchant() end }
    if pending then
        local p = pending
        local cost = p.price > 0 and Money(math.ceil(p.price * p.count / p.stack)) or ""
        local ask = format("Buy %d %s%s?", p.count, p.name, cost ~= "" and " for " .. cost or "")
        if p.extended then ask = format("Buy %d %s (it costs more than money)?", p.count, p.name) end
        local function By(d)
            return function()
                p.count = math.max(1, math.min(p.most, p.count + d))
                ns.npc.Update("merchant")
            end
        end
        return { left = ask,
            { label = "-", click = By(-1), enabled = p.count > 1 },
            { label = "+", click = By(1), enabled = p.count < p.most },
            { label = "Buy", primary = true, click = function() Buy(p.index, p.count) end },
            { label = "Cancel", click = function()
                pending = nil
                ns.npc.Update("merchant")
            end } }
    end
    local foot = { left = Money(GetMoney and GetMoney() or 0) }
    if CanMerchantRepair and CanMerchantRepair() then
        local cost, can = GetRepairAllCost()
        local broken = can and cost and cost > 0
        if CanGuildBankRepair and CanGuildBankRepair() then
            table.insert(foot, { label = "Guild", click = function() RepairAllItems(true) end, enabled = broken,
                tip = broken and "Repair everything from the guild bank: " .. Money(cost) .. "."
                    or "Nothing to repair." })
        end
        table.insert(foot, 1, { label = "Repair", click = function() RepairAllItems() end,
            enabled = broken and (GetMoney() >= cost),
            tip = broken and "Repair everything: " .. Money(cost) .. "." or "Nothing to repair." })
    end
    local count, value = Junk()
    table.insert(foot, { label = "Sell junk", click = SellJunk, enabled = count > 0,
        tip = count > 0 and format("Sells your %d grey item%s for %s.", count, count == 1 and "" or "s", Money(value))
            or "No grey items to sell." })
    table.insert(foot, close)
    return foot
end

local function Update() ns.npc.Update("merchant") end

ns.npc.Page{
    key = "merchant", frame = "MerchantFrame", price = "Price",
    Blocks = Blocks, Foot = Foot, Close = function() CloseMerchant() end,
    Start = function()
        ns.On("MERCHANT_SHOW", function()
            tab, pending = "merchant", nil
            ns.npc.Show("merchant")
        end)
        ns.On("MERCHANT_CLOSED", function()
            pending = nil
            ns.npc.Sync()
        end)
        for _, e in ipairs({ "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "UPDATE_INVENTORY_DURABILITY",
            "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
            ns.On(e, Update)
        end
        ns.locks.Watch(function() if MerchantFrame and MerchantFrame:IsShown() then Update() end end)
    end,
}
