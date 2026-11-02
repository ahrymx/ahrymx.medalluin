-- The stats on the right strip: Bags | Durability | clock, spread evenly
-- between the drawer arrow and the strip's inner end, with gold dividers.
-- Each one is a button: Bags opens the bags, Durability the character
-- pane, the clock Blizzard's time manager.
local _, ns = ...

local L, C = ns.stripLayout, ns.colors
local SIZE = 15
local WARN = { 0.90, 0.35, 0.28 }

local GetSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots

local strip = ns.strips[1]
local stats, dividers = {}, {}

local function Stat(onClick, onEnter)
    local b = CreateFrame("Button", nil, strip)
    b:SetFrameLevel(ns.levels.stripTop)
    b.text = ns.Text(b, SIZE)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        onEnter()
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(stats, b)
    return b
end

-- Lay the stats out by their current widths: equal gaps, a divider centred
-- in each gap between two stats. x is measured from the screen edge, so the
-- clock (the last stat) sits nearest the console.
local function Layout()
    local widths, sum = {}, 0
    for i, b in ipairs(stats) do
        widths[i] = math.ceil(b.text:GetStringWidth())
        sum = sum + widths[i]
    end
    local gap = (L.statsTo - L.statsFrom - sum) / #stats
    local x = L.statsFrom + gap / 2
    for i, b in ipairs(stats) do
        local w = widths[i]
        ns.OnStrip(b, 1, x + w / 2, ns.stripRow, w + 8, L.stripHeight - 6)
        x = x + w + gap
        if dividers[i] then
            ns.OnStrip(dividers[i], 1, x - gap / 2, ns.stripRow, 1, L.stripHeight - 13)
        end
    end
end

local function Set(b, text, warn)
    local before = b.text:GetText()
    b.text:SetText(text)
    b.text:SetTextColor(unpack(warn and WARN or C.text))
    if text ~= before then Layout() end
end

-- ------------------------------------------------------------------- bags
local function BagCount()
    local used, total = 0, 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n = GetSlots(bag) or 0
        local free, kind = GetFree(bag)
        -- quivers, ammo pouches and soul bags hold one thing; leave them out
        if n > 0 and (kind == nil or kind == 0) then
            total = total + n
            used = used + n - (free or 0)
        end
    end
    return used, total
end

local bags = Stat(function()
    if ToggleAllBags then ToggleAllBags() else OpenAllBags() end
end, function()
    local used, total = BagCount()
    GameTooltip:SetText(BAGSLOTTEXT or "Bags")
    GameTooltip:AddLine(format("%d / %d slots used", used, total), 1, 1, 1)
end)

local function UpdateBags()
    local used, total = BagCount()
    local pct = total > 0 and math.floor(used / total * 100 + 0.5) or 0
    Set(bags, format("Bags %d%%", pct), pct >= 90)
end

-- ------------------------------------------------------------- durability
local function Lowest()
    local low, slot = 1, nil
    for i = 1, 18 do
        local cur, max = GetInventoryItemDurability(i)
        if cur and max and max > 0 and cur / max < low then
            low, slot = cur / max, i
        end
    end
    return low, slot
end

local durability = Stat(function()
    ToggleCharacter("PaperDollFrame")
end, function()
    local low, slot = Lowest()
    GameTooltip:SetText(DURABILITY or "Durability")
    if slot then
        GameTooltip:AddLine(format("%s  %d%%", GetInventoryItemLink("player", slot) or "",
            math.floor(low * 100)), 1, 1, 1)
    else
        GameTooltip:AddLine("Nothing is damaged.", 1, 1, 1)
    end
end)

local function UpdateDurability()
    local low = Lowest()
    local pct = math.floor(low * 100)
    Set(durability, format("Durability %d%%", pct), pct <= 25)
end

-- ------------------------------------------------------------------ clock
local function Now()
    if GameTime_GetTime then return GameTime_GetTime(false) end
    return date("%H:%M")
end

local clock = Stat(function()
    if not TimeManager_Toggle and LoadAddOn then pcall(LoadAddOn, "Blizzard_TimeManager") end
    if TimeManager_Toggle then TimeManager_Toggle() end
end, function()
    GameTooltip:SetText(TIMEMANAGER_TITLE or "Clock")
    if GameTime_GetLocalTime and GameTime_GetGameTime then
        GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME or "Local time", GameTime_GetLocalTime(true),
            1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME or "Realm time", GameTime_GetGameTime(true),
            1, 1, 1, 1, 1, 1)
    end
end)

local elapsed = 1
clock:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    Set(clock, Now())
end)

-- --------------------------------------------------------------- dividers
-- on their own frame: the strip itself sits under its art
local over = CreateFrame("Frame", nil, strip)
over:SetAllPoints()
over:SetFrameLevel(ns.levels.stripTop)
for i = 1, #stats - 1 do
    local t = over:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.541, 0.439, 0.204)          -- the art's dark gold
    dividers[i] = t
end

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE" }) do ns.On(e, UpdateBags) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY" }) do
    ns.On(e, UpdateDurability)
end
Set(clock, Now())
