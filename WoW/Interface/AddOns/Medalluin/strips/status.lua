-- The stats on the right strip: Bags | Durability | clock, a cell each of
-- the strip's row (ns.StripCells), sharing it evenly. Each one is a
-- button: Bags opens the bags, Durability the character pane, the clock
-- Blizzard's time manager.
local _, ns = ...

local C = ns.colors
local SIZE = 15
local WARN = { 0.90, 0.35, 0.28 }

local GetSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots

local strip = ns.strips[1]
local stats = {}

local function Stat(onClick, onEnter)
    local b = CreateFrame("Button", nil, strip)
    b:SetFrameLevel(ns.levels.stripTop)
    ns.StripCell(b)
    b.text = ns.Text(b, SIZE)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) ns.Tip(self, "ANCHOR_TOP", onEnter()) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(stats, b)
    return b
end

local function Set(b, text, warn)
    b.text:SetText(text)
    b.text:SetTextColor(unpack(warn and WARN or C.text))
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
    return { title = BAGSLOTTEXT or "Bags", { "bar", used, total, format("%d / %d slots used", used, total) } }
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
    return { title = DURABILITY or "Durability", slot
        and { "item", GetInventoryItemTexture and GetInventoryItemTexture("player", slot),
            GetInventoryItemLink("player", slot) or "", format("%d%%", math.floor(low * 100)) }
        or { "body", "Nothing is damaged." } }
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
    local spec = { title = TIMEMANAGER_TITLE or "Clock" }
    if GameTime_GetLocalTime and GameTime_GetGameTime then
        spec[1] = { "row", TIMEMANAGER_TOOLTIP_LOCALTIME or "Local time", GameTime_GetLocalTime(true) }
        spec[2] = { "row", TIMEMANAGER_TOOLTIP_REALMTIME or "Realm time", GameTime_GetGameTime(true) }
    end
    return spec
end)

local elapsed = 1
clock:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    Set(clock, Now())
end)

-- x is measured from the screen edge, so the clock (the last stat) sits
-- nearest the console
ns.StripCells(1, stats)

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE" }) do ns.On(e, UpdateBags) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY" }) do
    ns.On(e, UpdateDurability)
end
Set(clock, Now())
