-- Items kept from the vendor and from destroying: Alt+click one in the bags
-- or the bank (inventory/slots.lua) and every one of that item (by itemID,
-- so it follows the item from bag to bag) is locked on this character,
-- marked with a padlock in its slot's bottom left corner and a "Locked" line
-- in its tooltip. Alt+click again unlocks it.
--
-- Locked items are
--   destroyed: never. The game asks first (DELETE_ITEM_CONFIRM, synchronous)
--              and its question closes when the cursor is empty, so the
--              item is put back (ClearCursor) and nothing is deleted.
--   sold:      never. The Sell tab and Sell junk leave them out
--              (npc/merchant.lua), and while a vendor is open a guard over
--              a locked slot takes its clicks (inventory/slots.lua), so the
--              bags' right click never reaches the sale.
--
--   ns.locks.Is(itemID), ns.locks.Toggle(itemID), ns.locks.Watch(fn),
--   ns.locks.vendor (a vendor is open)
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
    for _, fn in ipairs(watchers) do fn() end
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

-- ---------------------------------------------------------------- the vendor
local function Notify() for _, fn in ipairs(watchers) do fn() end end
ns.On("MERCHANT_SHOW", function()
    locks.vendor = true
    Notify()
end)
ns.On("MERCHANT_CLOSED", function()
    locks.vendor = false
    Notify()
end)

-- ---------------------------------------------------------------- the tooltip
-- "Locked" under any locked item's tooltip. mdlui_Tooltips knows the line by
-- this text and moves it onto the item's binding line.
Medalluin_LockedLine = "Locked"
local function Line(tooltip, id)
    if not ns.IsSecret(id) and locks.Is(id) then tooltip:AddLine(Medalluin_LockedLine, 0.45, 0.75, 1) end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        Line(tooltip, data and data.id)
    end)
end
