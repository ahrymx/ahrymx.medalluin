-- Items kept from the vendor and from destroying: Alt+click one in the bags
-- or the bank (inventory/slots.lua) and every one of that item (by itemID,
-- so it follows the item from bag to bag) is locked on this character,
-- marked with a padlock in its slot's bottom left corner. Alt+click again
-- unlocks it.
--
-- Locked items are
--   destroyed: never. The game asks first (DELETE_ITEM_CONFIRM, synchronous)
--              and its question closes when the cursor is empty, so the
--              item is put back (ClearCursor) and nothing is deleted.
--   sold:      not by us: the Sell tab and Sell junk leave them out
--              (npc/merchant.lua). A sale we cannot stop without tainting
--              the bags' click (a right click, a drop on the vendor) is
--              bought straight back (ns.locks.Rescue).
--
--   ns.locks.Is(itemID), ns.locks.Toggle(itemID), ns.locks.Watch(fn)
local _, ns = ...

local locks = {}
ns.locks = locks
local watchers = {}

function locks.Is(id)
    local store = MedalluinCharDB and MedalluinCharDB.lockedItems
    return id and store and store[id] or false
end

function locks.Toggle(id)
    if not id then return end
    MedalluinCharDB = MedalluinCharDB or {}
    local store = MedalluinCharDB.lockedItems or {}
    MedalluinCharDB.lockedItems = store
    store[id] = not store[id] or nil
    for _, fn in ipairs(watchers) do fn(id) end
end

function locks.Watch(fn) table.insert(watchers, fn) end

local function Say(text)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.3, 0.25, 1) end
end
locks.Say = Say

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end
locks.ItemID = ItemID

-- ------------------------------------------------------------ destroying
ns.On("DELETE_ITEM_CONFIRM", function(_, name)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not locks.Is(id) then return end
    ClearCursor()
    Say(format("%s is locked. Alt+click it in your bags to unlock it.", name or "That item"))
end)

-- --------------------------------------------------------------- selling
-- What the vendor had bought back from us, by link, the last time we looked.
local seen

local function Sold()
    local list = {}
    for i = 1, GetNumBuybackItems and GetNumBuybackItems() or 0 do
        list[i] = GetBuybackItemLink and GetBuybackItemLink(i) or false
    end
    return list
end

-- At the vendor's opening: what is already there was sold before, locked or
-- not, and is never bought back. Seen(false) at its closing: nothing more.
function locks.Seen(open)
    if open == false then seen = nil else seen = Sold() end
end

-- After a sale: anything new on the buyback list that is locked comes back
-- (the newest first, so the indices below it stay put). What is bought back
-- stays seen until the client's list loses it (BuybackItem is the server's
-- to do), so a second look before then never buys it twice.
function locks.Rescue()
    if not seen then return end
    local list, before = Sold(), {}
    for _, link in ipairs(seen) do before[link] = (before[link] or 0) + 1 end
    local fresh = {}
    for i, link in ipairs(list) do
        if link and (before[link] or 0) > 0 then
            before[link] = before[link] - 1
        else
            table.insert(fresh, i)
        end
    end
    for k = #fresh, 1, -1 do
        local i = fresh[k]
        local link = list[i]
        if locks.Is(ItemID(link)) then
            local name = GetBuybackItemInfo(i)
            BuybackItem(i)
            Say(format("%s is locked: bought back.", name or "The item"))
        end
    end
    seen = list
end
