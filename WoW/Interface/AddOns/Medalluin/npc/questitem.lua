-- A quest item, in the NPC box (npc/window.lua): an item that begins a
-- quest, got just now, opens the box on it.
--
--   (icon) Sealed Letter to Ag'tor
--   This item begins a quest. Read it to accept it or not.
--   [icon] Sealed Letter to Ag'tor
--   [     Read the quest     ] [         Later          ]
--
-- The game lets no addon use an item by itself: Read the quest (or Space)
-- is a secure button over the foot's, and the game answers with the
-- quest's page (npc/quest.lua). Later puts it away; the next waiting, if
-- any, comes up. Items carried at login, or once put away, do not ask
-- again this session.
--
-- The box shows a page while its frame is shown: the holder stands in for
-- the Blizzard frame the other pages have, shown while an item waits.
local _, ns = ...

local Container = C_Container
if not ns.npc then return end

local holder = CreateFrame("Frame", "MedalluinQuestItem", UIParent)
holder:Hide()
-- Escape puts it away, as it closes the game's windows
if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinQuestItem") end

local queue = {}                 -- the items waiting, first in front: { id, bag, slot }
local seen = {}                  -- itemIDs asked about, or carried at login
local quiet                      -- until then (GetTime), what the bags show is carried, not got:
                                 -- the first seconds in the world, as the bags fill and the
                                 -- items' quest info comes in
local QUIET = 5
local layer, use                 -- the secure button over Read the quest, on its own layer

-- The quest item in bag, slot: its itemID, if it begins a quest not taken
-- or done; by the game's quest info, else by its tooltip's line.
local function Starts(bag, slot)
    local id = Container.GetContainerItemID and Container.GetContainerItemID(bag, slot)
    if not id then return nil end
    local quest = Container.GetContainerItemQuestInfo and Container.GetContainerItemQuestInfo(bag, slot)
    if quest and quest.questID then
        if quest.isActive then return nil end
        local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        if done and done(quest.questID) then return nil end
        return id
    end
    local tip = ITEM_STARTS_QUEST and C_TooltipInfo and C_TooltipInfo.GetBagItem
        and C_TooltipInfo.GetBagItem(bag, slot)
    for _, line in ipairs(tip and tip.lines or {}) do
        if line.leftText == ITEM_STARTS_QUEST then return id end
    end
    return nil
end

local function Bags()
    local last = NUM_BAG_SLOTS or 4
    local list = {}
    for bag = 0, last do list[#list + 1] = bag end
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > last then list[#list + 1] = reagent end
    return list
end

-- Every quest item carried, by itemID: its first bag and slot.
local function Carried()
    local out = {}
    for _, bag in ipairs(Bags()) do
        for slot = 1, (Container.GetContainerNumSlots and Container.GetContainerNumSlots(bag) or 0) do
            local id = Starts(bag, slot)
            if id and not out[id] then out[id] = { id = id, bag = bag, slot = slot } end
        end
    end
    return out
end

local function Name(item)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item.id)
    if not name and GetItemInfo then name = GetItemInfo(item.id) end
    return name or "Quest item"
end

local function Icon(item)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)
    if not icon and GetItemIcon then icon = GetItemIcon(item.id) end
    return icon
end

-- The front of the queue shown, or the holder hidden: the box follows.
local function Front()
    local item = queue[1]
    local page = ns.npc.pages.questItem
    if item and ns.db.npcQuestItems ~= false then
        page.icon = Icon(item)
        -- (secure: out of combat; in it, the button waits, PLAYER_REGEN_ENABLED)
        if use and not InCombatLockdown() then use:SetAttribute("item", "item:" .. item.id) end
        if holder:IsShown() then ns.npc.Update("questItem") else holder:Show() end
        ns.npc.Show("questItem")
    else
        holder:Hide()
    end
end

-- The front item done with: used, or put away.
local function Next()
    table.remove(queue, 1)
    Front()
end

-- The bags read again: the new quest items queued, the gone ones dropped.
-- Before the world is entered, or in the quiet after, what they show is
-- only remembered.
local function Scan()
    if not Container then return end
    local carried = Carried()
    if not quiet or GetTime() < quiet then
        for id in pairs(carried) do seen[id] = true end
        return
    end
    local front = queue[1]
    for i = #queue, 1, -1 do
        local now = carried[queue[i].id]
        if now then queue[i] = now else table.remove(queue, i) end
    end
    for id, item in pairs(carried) do
        if not seen[id] then
            seen[id] = true
            if ns.db.npcQuestItems ~= false then table.insert(queue, item) end
        end
    end
    if queue[1] ~= front or (queue[1] and not holder:IsShown()) then Front() end
end

-- ------------------------------------------------------------ the button
-- Over the foot's Read the quest, out of combat, by numbers from a layer
-- of its own: never anchored to the box (a protected frame would make the
-- box one, which could then not close in combat). Hidden in combat.
local function Secure()
    if layer or InCombatLockdown() or not ns.strips then return end
    layer = CreateFrame("Frame", "MedalluinQuestItemLayer", ns.strips[-1])
    layer:SetFrameStrata("DIALOG")
    layer:SetAllPoints(ns.strips[-1])
    layer:Hide()
    use = CreateFrame("Button", "MedalluinQuestItemUse", layer, "SecureActionButtonTemplate")
    use:RegisterForClicks("AnyUp", "AnyDown")
    use:SetAttribute("type", "item")
    use:SetScript("PostClick", Next)
    use:SetScript("OnEnter", function()
        local face = ns.npc.Primary()
        local on = face and face:GetScript("OnEnter")
        if on then on(face) end
    end)
    use:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = use:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.12)
end

-- After each draw or showing of the box (both end in ns.npc.Keys, which
-- the pages' events reach through ns.npc.Sync): the button set over the
-- foot's again while this page is in front; else the layer hidden, its
-- combat driver off.
local function Follow()
    if not use or InCombatLockdown() then return end
    local item = queue[1]
    local face = item and ns.npc.Front() == "questItem" and ns.npc.Primary()
    local on = face and ns.window.Over(use, face) or false
    if on then
        use:SetAttribute("item", "item:" .. item.id)
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end
hooksecurefunc(ns.npc, "Keys", function() Follow() end)

-- ------------------------------------------------------------ the page
ns.npc.Page{
    key = "questItem", frame = "MedalluinQuestItem", space = true, spaceClick = "MedalluinQuestItemUse",
    Title = function() return queue[1] and Name(queue[1]) or "" end,
    Blocks = function()
        local item = queue[1]
        if not item then return {} end
        local out = {
            { "text", "This item begins a quest. Read it to accept it or not.", pin = true },
            { "tiles", { icon = Icon(item), crop = true, label = Name(item), enter = function(tile)
                ns.window.Outside(tile)
                GameTooltip:SetBagItem(item.bag, item.slot)
                GameTooltip:Show()
            end } },
        }
        if #queue > 1 then
            table.insert(out, { "text", #queue == 2 and "One more quest item after this one."
                or (#queue - 1) .. " more quest items after this one." })
        end
        return out
    end,
    Foot = function()
        local fight = InCombatLockdown()
        return { left = fight and "After combat" or nil,
            { label = "Read the quest", primary = true, enabled = not fight,
                tip = "Uses the item: the quest's page opens, to accept it or not." },
            { label = "Later", click = Next,
                tip = "Puts it away. It does not ask again until you log in again." } }
    end,
    Close = Next,
    Start = function()
        Secure()
        -- hidden by Escape (or anything not ours) with an item in front: put away
        holder:SetScript("OnHide", function() if queue[1] then Next() end end)
        ns.On("PLAYER_ENTERING_WORLD", function()
            if not quiet then quiet = GetTime() + QUIET end
            Scan()
        end)
        ns.On("BAG_UPDATE_DELAYED", Scan)
        -- the button waits out a fight; the page says so meanwhile
        ns.On("PLAYER_REGEN_DISABLED", function() ns.npc.Update("questItem") end)
        ns.On("PLAYER_REGEN_ENABLED", function()
            Secure()
            if queue[1] then Front() end
        end)
        ns.OnSetting("npcQuestItems", function()
            if ns.db.npcQuestItems == false then wipe(queue) end
            Front()
        end)
        Scan()
    end,
}
