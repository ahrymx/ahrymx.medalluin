-- The vendor, in the NPC box (npc/window.lua): what it sells and what you
-- sold it, on two tabs of our own, and its repairs and your junk in the
-- foot.
--
--   [Merchant][Buyback]
--   [icon] Mining Pick                              10c
--   [icon] Elemental Flux                    15s  2 [o]   <- an extended cost
--   2g 36s 55c         [Repair 1s 4c] [Guild] [Sell junk] [Goodbye]
--
-- A click buys one (one bundle: a stack of five sells as five); Shift
-- asks how many, up to a stack; an item that costs more than money, or
-- more than the game's high price, asks first. Asking happens in the foot:
--
--   Buy 20 Strong Flux for 4s?          [-] [+] [Buy] [Cancel]
--
-- Selling stays the game's: a bag item's right click, with the vendor
-- open. That works because Blizzard's MerchantFrame is still shown (only
-- parked), and stays untouched: no tab of its set, nothing of it called
-- (npc/window.lua, Taint).
local _, ns = ...

local HIGH = MERCHANT_HIGH_PRICE_COST or 1500000      -- the game's own: 150 gold
local RED = { 1, 0.3, 0.25 }

local tab = "merchant"
local pending                    -- { index, name, count, most, stack, price, extended }

local function Money(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    return format("%dg %ds %dc", copper / 10000, copper / 100 % 100, copper % 100)
end

-- An item the vendor sells, the same from either API.
local function Item(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local t = C_MerchantFrame.GetItemInfo(i)
        if t then
            return { name = t.name, icon = t.texture, price = t.price or 0, stack = t.stackCount or 1,
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

local function Blocks()
    local out = { { "tabs",
        { label = "Merchant", selected = tab == "merchant", click = function()
            tab = "merchant"
            ns.npc.Update("merchant")
        end },
        { label = "Buyback", selected = tab == "buyback", click = function()
            tab, pending = "buyback", nil
            ns.npc.Update("merchant")
        end } } }
    if tab == "buyback" then Buyback(out) else Merchant(out) end
    return out
end

-- -------------------------------------------------------------- junk
-- Your grey items that sell: how many, and for how much.
local function Junk()
    local C = C_Container
    local count, value, slots = 0, 0, {}
    if not C or not C.GetContainerItemInfo then return count, value, slots end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue then
                local price = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(info.itemID)) or 0
                count = count + 1
                value = value + price * (info.stackCount or 1)
                table.insert(slots, { bag, slot })
            end
        end
    end
    return count, value, slots
end

local function SellJunk()
    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
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
            { label = "Cancel", click = function()
                pending = nil
                ns.npc.Update("merchant")
            end },
            { label = "Buy", click = function() Buy(p.index, p.count) end },
            { label = "+", click = By(1), enabled = p.count < p.most },
            { label = "-", click = By(-1), enabled = p.count > 1 } }
    end
    local foot = { left = Money(GetMoney and GetMoney() or 0), close }
    local count, value = Junk()
    table.insert(foot, { label = "Sell junk", click = SellJunk, enabled = count > 0,
        tip = count > 0 and format("Sells your %d grey item%s for %s.", count, count == 1 and "" or "s", Money(value))
            or "No grey items to sell." })
    if CanMerchantRepair and CanMerchantRepair() then
        local cost, can = GetRepairAllCost()
        local broken = can and cost and cost > 0
        if CanGuildBankRepair and CanGuildBankRepair() then
            table.insert(foot, { label = "Guild", click = function() RepairAllItems(true) end, enabled = broken,
                tip = broken and "Repair everything from the guild bank: " .. Money(cost) .. "."
                    or "Nothing to repair." })
        end
        table.insert(foot, { label = "Repair", click = function() RepairAllItems() end,
            enabled = broken and (GetMoney() >= cost),
            tip = broken and "Repair everything: " .. Money(cost) .. "." or "Nothing to repair." })
    end
    return foot
end

local function Update() ns.npc.Update("merchant") end

ns.npc.Page{
    key = "merchant", frame = "MerchantFrame",
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
    end,
}
