-- The right strip's row and the medallions' gauges (2026-11-10, mockup A
-- of /workspace/rings-mockups.png; were Bags | Durability | clock keys):
-- durability is a ring round the portrait, the bags a ring round the
-- backpack (ns.Ring), their numbers in the medallions' tooltips (ours, in
-- place of Blizzard's, after it has written its own). The row holds
-- shortcut keys, Medalluin's and the game's, then the clock nearest the
-- console, wider, opening Blizzard's time manager.
local _, ns = ...

local GOLD_B = { 0.91, 0.788, 0.431 }
local SIZE = 13

local GetSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots

local strip = ns.strips[1]

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

local bags = ns.Ring(1)

local function UpdateBags()
    local used, total = BagCount()
    local frac = total > 0 and used / total or 0
    bags:Set(frac, 1 - frac)
end

MainMenuBarBackpackButton:HookScript("OnEnter", function(self)
    local used, total = BagCount()
    ns.Tip(self, "ANCHOR_TOP", { title = BACKPACK_TOOLTIP or "Backpack",
        { "bar", used, total, format("%d / %d slots used (%d%%)", used, total,
            total > 0 and math.floor(used / total * 100 + 0.5) or 0) } })
end)

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

local durability = ns.Ring(-1)

local function UpdateDurability()
    local low = Lowest()
    durability:Set(low, low)
end

CharacterMicroButton:HookScript("OnEnter", function(self)
    local low, slot = Lowest()
    ns.Tip(self, "ANCHOR_TOP", { title = CHARACTER_BUTTON or "Character Info",
        { "row", DURABILITY or "Durability", format("%d%%", math.floor(low * 100)) },
        slot and { "item", GetInventoryItemTexture and GetInventoryItemTexture("player", slot),
            GetInventoryItemLink("player", slot) or "", format("%d%%", math.floor(low * 100)) } or false })
end)

-- -------------------------------------------------------------- shortcuts
-- A slash command (run through the menu's handler table), its words, its
-- glyph, and the game's function opening it where no command answers.
local SHORTCUTS = {
    { "/mui", "Medalluin", "achievement" },
    { "/cdm", "Cooldown Manager", "legacy" },
    { "/cc", "Click Casting", "spellbook", function() return ToggleClickBindingFrame end },
    { "/macro", "Macros", "log" },
    { nil, "Edit Mode", "view-grid", function()
        local f = EditModeManagerFrame
        return f and ShowUIPanel and function() ShowUIPanel(f) end
    end },
    { nil, FRIENDS or "Friends", "social", function()
        return ToggleFriendsFrame and function() ToggleFriendsFrame(1) end
    end },
    { nil, GUILD or "Guild", "guild", function() return ToggleGuildFrame end },
}

local function Runs(sc)
    local menu = ns.gameMenu
    local fn = sc[1] and menu and menu.Handler and menu.Handler(sc[1])
    if fn then return function() fn("") end end
    local game = sc[4] and sc[4]()
    if type(game) == "function" then return game end
end

local keys = {}

local function Key(sc)
    local b = CreateFrame("Button", nil, strip)
    b:SetFrameLevel(ns.levels.stripTop)
    b:RegisterForClicks("LeftButtonUp")
    ns.StripCell(b)
    b.tex = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.tex:SetTexture(ns.media .. "strips\\" .. sc[3])
    b.tex:SetPoint("CENTER")
    b.tex:SetSize(ns.stripLayout.glyphTex - 6, ns.stripLayout.glyphTex - 6)
    b.glow = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.glow:SetTexture(ns.media .. "strips\\" .. sc[3])
    b.glow:SetBlendMode("ADD")
    b.glow:SetAlpha(0.45)
    b.glow:SetAllPoints(b.tex)
    b.glow:Hide()
    b.shortcut = sc
    b:SetScript("OnClick", function()
        local run = Runs(sc)
        if run then run() end
    end)
    b:SetScript("OnEnter", function(self)
        self.glow:Show()
        ns.Tip(self, "ANCHOR_TOP", { title = sc[2], sc[1] and { "body", sc[1] } or nil })
    end)
    b:SetScript("OnLeave", function(self)
        self.glow:Hide()
        GameTooltip_Hide()
    end)
    return b
end

for _, sc in ipairs(SHORTCUTS) do table.insert(keys, Key(sc)) end

-- ------------------------------------------------------------------ clock
local function Now()
    if GameTime_GetTime then return GameTime_GetTime(false) end
    return date("%H:%M")
end

local clock = CreateFrame("Button", nil, strip)
clock:SetFrameLevel(ns.levels.stripTop)
ns.StripCell(clock)
clock.share = 1.8
clock.text = ns.Text(clock, SIZE)
clock.text:SetPoint("CENTER")
clock.text:SetTextColor(unpack(GOLD_B))
clock:SetScript("OnClick", function()
    if not TimeManager_Toggle and LoadAddOn then pcall(LoadAddOn, "Blizzard_TimeManager") end
    if TimeManager_Toggle then TimeManager_Toggle() end
end)
clock:SetScript("OnEnter", function(self)
    local spec = { title = TIMEMANAGER_TITLE or "Clock" }
    if GameTime_GetLocalTime and GameTime_GetGameTime then
        spec[1] = { "row", TIMEMANAGER_TOOLTIP_LOCALTIME or "Local time", GameTime_GetLocalTime(true) }
        spec[2] = { "row", TIMEMANAGER_TOOLTIP_REALMTIME or "Realm time", GameTime_GetGameTime(true) }
    end
    ns.Tip(self, "ANCHOR_TOP", spec)
end)
clock:SetScript("OnLeave", GameTooltip_Hide)

local elapsed = 1
clock:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    clock.text:SetText(Now())
end)

-- The row: the keys something answers, from the medallion outward, the
-- clock last. Other addons' commands are known by the time the world is
-- entered, so it is laid out again then.
local function Arrange()
    local row = {}
    for _, b in ipairs(keys) do
        local on = Runs(b.shortcut) ~= nil
        b:SetShown(on)
        if on then table.insert(row, b) end
    end
    table.insert(row, clock)
    ns.StripCells(1, row)
end
ns.stripShortcuts = { keys = keys, clock = clock, Arrange = Arrange }

Arrange()
ns.On("PLAYER_ENTERING_WORLD", Arrange)
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE" }) do ns.On(e, UpdateBags) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY" }) do
    ns.On(e, UpdateDurability)
end
UpdateBags()
UpdateDurability()
clock.text:SetText(Now())
