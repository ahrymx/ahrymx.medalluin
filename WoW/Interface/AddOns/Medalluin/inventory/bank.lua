-- The bank: Medalluin's own (the shell is window/shell.lua), on the left
-- strip where the character window stands, or detached, a box of its own
-- (bankPlace). Forever only: its bank is the game's tabs (C_Bank), the
-- first the bank itself and the rest bag slots a bag goes in.
--
--   [  Bank  ][ Warband ]                                [v] [^] [x]
--   ---------------------------------------------------------------
--   the bank's slots, as the bags window lays them (inventory/slots.lua):
--   a grid, each bag under its name, or the items in groups; it scrolls
--   ---------------------------------------------------------------
--   [bag][bag][lock][lock]...                 <- the details: the bag slots
--   Next bag slot: 10s                [Purchase]
--   ---------------------------------------------------------------
--   (medallion) [search......] [Bags|Grid|Groups] [Deposit] [Sort]
--
-- A page per kind of bank the game lets you see (Bank, and Warband where
-- there is one). The slots are Blizzard's own, so a click moves an item
-- to the bags, and a bag's right click into the bank, as the game's do.
-- A bag slot takes a bag dropped on it and gives it back to a click, as
-- Blizzard's do: the bank's bag slots are a container of their own
-- (Enum.BagIndex.Characterbanktab), a bag in it an item. Purchase is
-- Blizzard's own button, pressed by a secure one over ours: the game
-- refuses PurchaseBankTab to addons, and asks to be sure in its own popup.
--
-- Blizzard's BankFrame keeps every way in and out (the banker, Escape,
-- walking away) under a hidden parent; this window shows while it is open.
-- Docked, it gives way to the character window, and the quest tracker and
-- the NPC box hide under it as they do under that window; detached, it
-- covers nothing.
local _, ns = ...

local Container = C_Container
local GOLD = { 0.941, 0.831, 0.533 }
local GUTTER, STEP = 10, 41 * 2         -- the scroll bar's room, a wheel's step (two rows)
local BAG, BAR = 30, 24                 -- a bag slot, the purchase line
local LOCK = "Interface\\Buttons\\LockButton-Locked-Up"
local EMPTY = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local VIEWS = {
    { key = "bags", name = "Bags", width = 40, tip = "Each bag on rows of its own, under its name." },
    { key = "grid", name = "Grid", width = 36, tip = "Every slot in one grid, bag by bag." },
    { key = "groups", name = "Groups", width = 50, tip = "The items in groups: new, equipment and the rest." },
}

local function Money(c) return ns.npc and ns.npc.Money(c) or tostring(c) end

local cover                             -- shown while the bank stands docked on the strip
local layer, buy                        -- the secure Purchase, on the strip (w.Layer)

local W = ns.Window{
    name = "MedalluinBank", side = -1, detailsKey = "bankDetails", place = "bankPlace",
    closeTip = "Close the bank.",
    Close = function() if C_Bank and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame() end end,
    -- the portrait, and the queue's eye when it sits in its place
    Lifted = function()
        local list = { CharacterMicroButton }
        local eye = QueueStatusButton or QueueStatusMinimapButton or MiniMapLFGFrame
        if eye and eye:GetParent() == ns.strips[-1] then table.insert(list, eye) end
        return list
    end,
    Placed = function() if ns.bank and ns.bank.Sync then ns.bank.Sync() end end,
}
ns.bank = { W = W }

-- ------------------------------------------------------------- the data
-- A kind of bank's containers, in order, and their names.
local function Tabs(kind)
    local out, names = {}, {}
    for i, t in ipairs(C_Bank.FetchPurchasedBankTabData(kind) or {}) do
        table.insert(out, t.ID)
        local name = t.name ~= "" and t.name or Container.GetBagName and Container.GetBagName(t.ID)
        names[t.ID] = name and name ~= "" and name or (i == 1 and "Bank" or format("Bank bag %d", i - 1))
    end
    return out, names
end

-- ------------------------------------------------------------ bag slots
-- A bag slot, as Blizzard's bank numbers it: the first tab is the bank, so
-- the first bag slot is the second
local function Where(p, i)
    local index = p.kind == Enum.BankType.Account and Enum.BagIndex.Accountbanktab or Enum.BagIndex.Characterbanktab
    return index, i + 1
end

local function BagTip(b)
    ns.window.Outside(b, "ANCHOR_TOP")
    if b.bought and b.worn then
        GameTooltip:SetBagItem(Where(b.page, b.index))
    elseif b.bought then
        GameTooltip:SetText("An empty bag slot. Drop a bag here.")
    else
        GameTooltip:SetText("Not bought yet: Purchase buys the next.")
    end
    GameTooltip:Show()
end

local function BagSlot(p, i)
    local b = CreateFrame("Button", nil, p.foot)
    b:SetSize(BAG, BAG)
    b:SetPoint("TOPLEFT", (i - 1) * (BAG + 6), -2)
    ns.window.Face(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.page, b.index = p, i
    b:RegisterForDrag("LeftButton")
    -- the bag there comes up, or the cursor's goes in (they swap), as the
    -- game's own bag slots do it, for a click, a drag and a drop alike
    local function Take(self)
        if self.bought then C_Container.PickupContainerItem(Where(p, i)) end
    end
    b:SetScript("OnClick", Take)
    b:SetScript("OnDragStart", Take)
    b:SetScript("OnReceiveDrag", Take)
    b:SetScript("OnEnter", BagTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- the bag slots, as the game numbers them (the first tab is the bank), and
-- the next one's price
local function Slots(p)
    local bags = C_Bank.ShouldUsePlayerBagsInBank and C_Bank.ShouldUsePlayerBagsInBank()
    local bought = C_Bank.FetchPurchasedBankTabData(p.kind) or {}
    local n = bags and math.max(0, (C_Bank.FetchMaxNumBankTabs(p.kind) or 1) - 1) or 0
    for i = 1, math.max(n, #p.bags) do
        local b = p.bags[i]
        if i <= n then
            b = b or BagSlot(p, i)
            p.bags[i] = b
            b.bought = bought[i + 1] ~= nil
            local at = ItemLocation:CreateFromBagAndSlot(Where(p, i))
            b.worn = b.bought and C_Item.DoesItemExist(at) and C_Item.GetItemIcon(at) or nil
            b.icon:SetTexture(b.worn or (b.bought and EMPTY or LOCK))
            b.icon:SetDesaturated(not b.bought)
            b.icon:SetAlpha(b.bought and 1 or 0.5)
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    -- the warband's first tab is bought elsewhere, as Blizzard's hides it
    local unbegun = #bought == 0 and p.kind == Enum.BankType.Account
    local upcoming = not unbegun and C_Bank.FetchNextPurchasableBankTabData(p.kind) or nil
    p.price:SetText(unbegun and "The warband bank is not begun yet."
        or upcoming and "Next bag slot: " .. Money(upcoming.tabCost) or "Every bag slot is bought.")
    p.purchase:SetShown(upcoming ~= nil)
    p.next = upcoming
    p.purchase:SetAlpha(upcoming and upcoming.canAfford ~= false and 1 or 0.4)
end

-- ------------------------------------------------------- the secure buy
-- Out of combat only: the secure button over the shown page's Purchase,
-- pressing Blizzard's (whose bank tab is the game's: the button only
-- where that is this page's); the layer hidden in combat.
local function Follow()
    if not layer or InCombatLockdown() then return end
    local p = W.Current()             -- (its Purchase is visible only while the window is open)
    local panel = BankFrame.BankPanel
    local target = panel and panel.PurchaseButton
    local on = p and p.purchase and p.purchase:IsVisible() and target ~= nil and panel.GetActiveBankType ~= nil
        and panel:GetActiveBankType() == p.kind or false
    if on and not buy then
        buy = CreateFrame("Button", "MedalluinBankPurchase", layer, "SecureActionButtonTemplate")
        buy:RegisterForClicks("AnyUp", "AnyDown")
        buy:SetAttribute("type", "click")
        buy:SetScript("OnEnter", function(self) if self.face then self.face:GetScript("OnEnter")(self.face) end end)
        buy:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local glow = buy:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.12)
    end
    if buy then
        buy:SetAttribute("clickbutton", on and target or nil)
        buy.face = on and p.purchase or nil
        buy:SetShown(on and W.Over(buy, p.purchase) or false)
    end
    if on then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- -------------------------------------------------------------- the page
local function Columns(p)
    return p.set.Fit(W.window:GetWidth() - 2 * ns.window.pad - GUTTER)
end

local function Refresh(p)
    p.set.Refresh()
    p.scroller.To(p.scroller.target)
    Slots(p)
    for _, b in ipairs(p.views) do b.mark:SetShown(ns.db.bankView == b.key) end
    p.deposit:SetShown(C_Bank.DoesBankTypeSupportAutoDeposit and C_Bank.DoesBankTypeSupportAutoDeposit(p.kind)
        and true or false)
    Follow()
end

local function Band(p, band)
    local function Button(width, label, click, tip)
        local b = ns.window.Button(band, width, click, tip)
        b:SetHeight(22)
        b.label:SetText(label)
        return b
    end
    local sort = Button(42, "Sort", function()
        if Container.SortBankBags then Container.SortBankBags() end
    end, function() return "Sort the bank, as the game sorts it." end)
    sort:SetPoint("RIGHT", 0, 0)
    p.deposit = Button(60, "Deposit", function()
        if C_Bank.AutoDepositItemsIntoBank then C_Bank.AutoDepositItemsIntoBank(p.kind) end
    end, function() return "Put what the bank takes in on its own into it, as the game's button does." end)
    p.deposit:SetPoint("RIGHT", sort, "LEFT", -4, 0)
    -- the views, joined edge to edge, right to left
    p.views = {}
    local prev = p.deposit
    for i = #VIEWS, 1, -1 do
        local v = VIEWS[i]
        local b = Button(v.width, v.name, function() ns.SetOption("bankView", v.key) end,
            function() return v.tip end)
        b.key = v.key
        b:SetPoint("RIGHT", prev, "LEFT", prev == p.deposit and -8 or 1, 0)
        table.insert(p.views, b)
        prev = b
    end
    local search = CreateFrame("EditBox", "MedalluinBankSearch" .. p.key, band, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("LEFT", 6, 0)
    search:SetPoint("RIGHT", prev, "LEFT", -8, 0)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(self)
        if Container.SetItemSearch then Container.SetItemSearch(self:GetText()) end
    end)
    p.search = search
end

local KINDS = {
    { key = "bank", label = "Bank", tip = "The bank.", icon = "Interface\\Icons\\INV_Box_02",
        kind = function() return Enum.BankType.Character end, order = 1 },
    { key = "warband", label = "Warband", tip = "The warband's bank, shared by your characters.",
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", order = 2,
        kind = function() return Enum.BankType.Account end },
}

for _, k in ipairs(KINDS) do
    local p = { key = k.key, label = k.label, tip = k.tip, icon = k.icon, order = k.order, frame = "BankFrame" }
    p.flex, p.height, p.bandUsed = true, 0, true
    p.footHeight = BAG + 8 + BAR
    p.bags = {}
    p.events = { "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
        "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE", "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED",
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" }
    function p.Available()
        p.kind = Enum and Enum.BankType and k.kind()
        return p.kind ~= nil and C_Bank ~= nil and (k.key == "bank" or C_Bank.CanViewBank(p.kind)) and true or false
    end
    function p.Build(body, foot, band)
        p.foot = foot
        p.scroller = ns.window.Scroller(body, GUTTER)
        body:EnableMouseWheel(true)
        body:SetScript("OnMouseWheel", function(_, delta) p.scroller.To(p.scroller.target - delta * STEP) end)
        p.set = ns.Slots{ prefix = "MedalluinBank" .. (k.key == "bank" and "" or "Warband"),
            body = p.scroller.child,
            Bags = function() return (Tabs(p.kind)) end,
            Name = function(bag) return select(2, Tabs(p.kind))[bag] end,
            Columns = function() return Columns(p) end, View = function() return ns.db.bankView end }
        p.price = ns.Text(foot, 12)
        p.price:SetPoint("BOTTOMLEFT", 2, 4)
        p.price:SetTextColor(unpack(GOLD))
        -- the face only: the secure button over it (Follow) presses the game's
        p.purchase = ns.window.Button(foot, 92, nil, function()
            if p.next and p.next.canAfford == false then return "Not enough money." end
            if InCombatLockdown() then return "Not in combat." end
            if not (buy and buy:IsShown()) then return "Not here: the game's bank stands on its other tab." end
            return "Buy the next bag slot, for " .. (p.next and Money(p.next.tabCost) or "-")
                .. ". The game asks to be sure."
        end)
        p.purchase:SetHeight(22)
        p.purchase:SetPoint("BOTTOMRIGHT", 0, 2)
        p.purchase.label:SetText("Purchase")
        Band(p, band)
    end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end

-- ----------------------------------------------------- Blizzard's frame
-- Shown while BankFrame is, unless it stands docked where the character
-- window is open; the cover tells the tracker and the NPC box.
local function Sync()
    if not W.window then return end
    local open = BankFrame and BankFrame:IsShown() or false
    local character = ns.character and ns.character.window
    local docked = not W.Detached()
    local on = open and not (docked and character and character:IsShown())
    if on and not W.window:IsShown() then
        W.Retab()
        local p = W.Current()
        if not (p and p.available) then W.Select(W.pages[1]) end
    end
    W.SetShown(on)
    cover:SetShown(on and docked)
    Follow()
end
ns.bank.Sync = Sync

local function Start()
    if not ns.db.bank or not BankFrame or not C_Bank or not C_Bank.FetchPurchasedBankTabData or not Enum.BankType then
        return
    end
    -- the cover first: Build places the window, and the place syncs
    cover = CreateFrame("Frame", "MedalluinBankCover", UIParent)
    cover:Hide()
    ns.bank.cover = cover
    W.Build()
    layer = W.Layer("MedalluinBankLayer")
    ns.bank.layer = layer
    ns.On("PLAYER_REGEN_ENABLED", Follow)
    ns.Park(BankFrame)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(BankFrame, method, Sync) end
    local character = ns.character and ns.character.window
    if character then
        character:HookScript("OnShow", Sync)
        character:HookScript("OnHide", Sync)
    end
    if ns.quests and ns.quests.Cover then ns.quests.Cover(cover) end
    if ns.npc and ns.npc.Sync then
        cover:HookScript("OnShow", ns.npc.Sync)
        cover:HookScript("OnHide", ns.npc.Sync)
    end
    ns.OnSetting("bankView", function() if W.window:IsShown() and W.Current() then W.Current().Refresh() end end)
    Sync()
end

-- after the tracker and the NPC box (their covers), at login
ns.On("PLAYER_LOGIN", Start)
