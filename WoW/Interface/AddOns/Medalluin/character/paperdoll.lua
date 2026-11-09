-- The Character page: the name and title, the gear down both sides of the
-- player's model, the weapons under it, and in the details a switch
-- between the stats, the titles and the equipment sets
-- (character/stats.lua, titles.lua, sets.lua).
--
--   Name, Title of the Realm
--   Class (Spec)  Level N
--   ------------------- <> --------------------
--   [head]                          [hands]
--   [neck]                          [waist]
--    ...           the model          ...
--   [wrist]                         [trinket]
--   -------- [main] [off] [ranged] [ammo] -------
--   ...the details...
--   (medallion)  [Talents] [Spellbook] [Professions]
--
-- The window is the screen's height, and the page spreads out over what it
-- has (Fit): a divider under the name first, then bigger slots, then room
-- between them, then what is left in three, above the name, round the
-- divider and under the weapons.
--
-- The gear slots are Blizzard's own (CharacterHeadSlot and the rest), taken
-- off its hidden window as the bags window takes the bag slots off the bag
-- bar: equipping, swapping, the tooltips and a right click's use are the
-- client's, and the use is protected, so it must be. Blizzard decides which
-- of the ranged and ammo slots this character has; the weapons row closes
-- up over the ones it hides.
local _, ns = ...

local SLOT, PITCH, GAP = 34, 39, 6             -- the least: a slot, a row, the weapons' gap
local SLOT_MAX, SPREAD = 46, 26                 -- the most: a slot, and room added between rows
local HEAD = 40                                 -- the name and the class line
local DIVIDER = 22                              -- the divider under them, with its room
local BELT = 8                                  -- between the weapons row and its rules
local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local BOTTOM = { "MainHand", "SecondaryHand", "Ranged", "Ammo" }
-- no item level on these: a shirt, a tabard and ammo have none worth reading
local PLAIN = { Shirt = true, Tabard = true, Ammo = true }
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local TURN = 0.012                              -- the model's turn, in radians per pixel dragged
local SWITCH = 22 + 6                           -- the details' switch, and the gap under it
local VIEWS = { { "stats", "Stats", "Your stats." }, { "titles", "Titles", "Wear a title you have earned." },
    { "sets", "Sets", "Your equipment sets." } }

local page
local body, name, line, model, divider, belt
local size, pitch, cols = SLOT, PITCH, HEAD     -- a slot, a row, the columns' top: Fit's
local slots, weapons = {}, {}
local placing = false
local views, view = {}, "stats"                 -- the details' parts, and the one shown

-- ---------------------------------------------------------------- slots
local function Icon(btn)
    return btn.icon or _G[btn:GetName() .. "IconTexture"]
end

local function Quality(slot)
    local q = GetInventoryItemQuality("player", slot)
    if q and q > 1 then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if c then return c.r, c.g, c.b end
    end
    return GOLD_D[1], GOLD_D[2], GOLD_D[3]
end

local function ItemLevel(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return end
    if C_Item and C_Item.GetCurrentItemLevel and ItemLocation and ItemLocation.CreateFromEquipmentSlot then
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        if loc and loc:IsValid() then return C_Item.GetCurrentItemLevel(loc) end
    end
    if GetDetailedItemLevelInfo then return (GetDetailedItemLevelInfo(link)) end
end

-- the edge in the item's quality, its level under it
local function Paint(btn)
    local slot = btn:GetID()
    btn.edge:SetColorTexture(Quality(slot))
    local level = not PLAIN[btn.slotName] and ItemLevel(slot)
    btn.level:SetText(level and level > 0 and tostring(level) or "")
end

-- Blizzard's slot art (its frame, its quality ring) gives way to an edge
-- like the bag slots'; put back whenever Blizzard re-sets it.
local function Restyle(btn)
    ns.Mute(btn:GetNormalTexture())
    ns.Mute(btn.IconBorder)
end

local function Style(btn, slotName)
    btn.slotName = slotName
    local icon = Icon(btn)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.edge = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    btn.edge:SetAllPoints()
    btn.level = ns.Text(btn, 11)
    btn.level:SetPoint("BOTTOM", 0, 2)
    Restyle(btn)
    for _, method in ipairs({ "SetNormalTexture", "SetNormalAtlas" }) do
        if btn[method] then hooksecurefunc(btn, method, Restyle) end
    end
end

-- The columns, and the weapons row closed up and centred under the model.
-- the weapons row's top: under the columns' last slot
local function WeaponsTop()
    return cols + (#LEFT - 1) * pitch + size + (PITCH - SLOT) + GAP
end

local function Place()
    placing = true
    local width = ns.character.width
    for _, btn in ipairs(slots) do
        local col = btn.side
        btn:ClearAllPoints()
        btn:SetSize(size, size)
        btn:SetPoint(col < 0 and "TOPLEFT" or "TOPRIGHT", body, col < 0 and "TOPLEFT" or "TOPRIGHT",
            0, -(cols + (btn.row - 1) * pitch))
    end
    local shown = {}
    for _, btn in ipairs(weapons) do
        if btn:IsShown() then table.insert(shown, btn) end
    end
    local across = #shown * size + math.max(0, #shown - 1) * GAP
    local x = (width - across) / 2
    local y = WeaponsTop()
    for _, btn in ipairs(shown) do
        btn:ClearAllPoints()
        btn:SetSize(size, size)
        btn:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
        x = x + size + GAP
    end
    -- a gold rule out from each side of the row, to the columns
    if belt then
        local mid = -(y + size / 2)
        local reach = (width - across) / 2 - BELT - (size + GAP)
        for i, rule in ipairs(belt) do
            rule:ClearAllPoints()
            rule:SetWidth(math.max(0, reach))
            rule:SetShown(reach > 0)
            if i == 1 then
                rule:SetPoint("TOPLEFT", body, "TOPLEFT", size + GAP, mid)
            else
                rule:SetPoint("TOPRIGHT", body, "TOPRIGHT", -(size + GAP), mid)
            end
        end
    end
    placing = false
end

local function Take(slotName, side, row)
    local btn = _G["Character" .. slotName .. "Slot"]
    if not btn then return end
    btn:SetParent(body)
    btn:SetFrameLevel(body:GetFrameLevel() + 2)
    Style(btn, slotName)
    btn.side, btn.row = side, row
    if side then table.insert(slots, btn) else table.insert(weapons, btn) end
    hooksecurefunc(btn, "SetPoint", function()
        if not placing then Place() end
    end)
    return btn
end

-- ---------------------------------------------------------------- model
-- The player, turned by dragging across it.
local function Frame()
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", body, "TOPLEFT", size + GAP, -cols)
    model:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", -(size + GAP), -(cols + (#LEFT - 1) * pitch + size))
end

local function Model()
    model = CreateFrame("PlayerModel", nil, body)
    local well = model:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.05)
    Frame()
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self.from = GetCursorPosition() end
    end)
    model:SetScript("OnMouseUp", function(self) self.from = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.from then return end
        local x = GetCursorPosition()
        self:SetFacing((self:GetFacing() or 0) + (x - self.from) * TURN)
        self.from = x
    end)
end

-- ------------------------------------------------------------------ fit
-- The page has h, at least page.height: the divider first, then bigger
-- slots (nine of them stand in a column with the weapons), then room
-- between the rows (seven gaps), then the rest in three: above the name,
-- round the divider, under the weapons.
local function Fit(h)
    local extra = math.max(0, h - page.height)
    local shown = extra >= DIVIDER
    local room = shown and DIVIDER or 0
    extra = extra - room
    size = math.min(SLOT_MAX, SLOT + math.floor(extra / 9))
    extra = extra - 9 * (size - SLOT)
    local spare = math.min(SPREAD, math.floor(extra / 7))
    extra = extra - 7 * spare
    pitch = size + (PITCH - SLOT) + spare
    local top = math.floor(extra / 3)
    room = room + top
    cols = top + HEAD + room
    name:ClearAllPoints()
    name:SetPoint("TOP", 0, -(top + 2))
    divider:SetShown(shown)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", body, "TOPLEFT", 40, -(top + HEAD + (room - 12) / 2))
    divider:SetPoint("TOPRIGHT", body, "TOPRIGHT", -40, -(top + HEAD + (room - 12) / 2))
    Frame()
    Place()
    page.fit = { size = size, pitch = pitch, top = top, cols = cols, divider = shown }
end

-- ----------------------------------------------------------------- head
local function ClassLine()
    local className = UnitClass("player")
    local spec
    if GetSpecialization and GetSpecializationInfo then
        local i = GetSpecialization()
        spec = i and select(2, GetSpecializationInfo(i))
    end
    local who = spec and format("%s (%s)", className, spec) or className
    return format("%s  Level %d", who or "", UnitLevel("player") or 0)
end

local function Refresh()
    name:SetText(UnitPVPName("player") or UnitName("player"))
    line:SetText(ClassLine())
    for _, btn in ipairs(slots) do Paint(btn) end
    for _, btn in ipairs(weapons) do Paint(btn) end
    Place()
    ns.character[view].Refresh()
end

-- ------------------------------------------------------------- details
-- Stats, Titles, Sets across the top; each part has the same room, the
-- stats' (the tallest), so the window keeps its height between them. A
-- client without titles or sets has no button for them.
local function Mark(key)
    view = key
    for k, v in pairs(views) do
        v.frame:SetShown(k == key)
        v.button.mark:SetShown(k == key)
    end
end

local function Show(key)
    Mark(key)
    ns.character[key].Refresh()
end

local function Details(foot)
    local stats = ns.character.stats
    local keys = {}
    for _, v in ipairs(VIEWS) do
        local part = ns.character[v[1]]
        if v[1] == "stats" or part.available then table.insert(keys, v) end
    end
    local w, gap = 80, 4
    local x = (ns.character.width - #keys * w - (#keys - 1) * gap) / 2
    local height
    for _, v in ipairs(keys) do
        local key = v[1]
        local frame = CreateFrame("Frame", nil, foot)
        frame:SetPoint("TOPLEFT", 0, -SWITCH)
        local button = ns.character.Button(foot, w, function() Show(key) end, function() return v[3] end)
        button.label:SetText(v[2])
        button:SetPoint("TOPLEFT", x, 0)
        x = x + w + gap
        views[key] = { frame = frame, button = button }
        if key == "stats" then
            -- the stats draw first: their height is everyone's
            stats.Build(frame)
            height = stats.height
        else
            ns.character[key].Build(frame, height)
        end
        frame:SetSize(ns.character.width, height)
    end
    page.footHeight = SWITCH + height
    page.views = views
    Mark(view)
end

-- ------------------------------------------------------------ shortcuts
-- Talents, Spellbook and Professions, in the window's margin beside the
-- medallion. Each clicks Blizzard's own micro button through a secure
-- button, so the book or the talents open as the micro menu opens them,
-- with no addon's hand on them.
--
-- Neither a secure button nor a frame holding one may be shown or hidden
-- in combat, so the row is not the window's (the window opens and closes
-- in combat): it stands on the strip over the margin and follows the window
-- out of combat; in combat a state driver hides it, and when combat ends
-- it follows the window again.
local SHORTCUTS = {
    { "Talents", "Open your talents.", "talents", { "TalentMicroButton", "PlayerSpellsMicroButton" } },
    { "Spellbook", "Open your spellbook.", "spellbook", { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
    { "Professions", "Open your professions.", "profession", { "ProfessionMicroButton" } },
}
local row
local open = false                              -- the window open on this page

-- the micro button a shortcut clicks: the first this client shows, or has
local function Target(names)
    local had
    for _, n in ipairs(names) do
        local b = _G[n]
        if b then
            if b:IsShown() then return b end
            had = had or b
        end
    end
    return had
end

local function Follow()
    if InCombatLockdown() then return end
    if open then
        RegisterStateDriver(row, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(row, "visibility")
        row:Hide()
    end
end

local function Shortcuts(band)
    local strip = ns.strips[-1]
    local window = band:GetParent()
    local B = ns.character.band
    row = CreateFrame("Frame", "MedalluinCharacterShortcuts", strip)
    row:SetFrameStrata("MEDIUM")
    row:SetFrameLevel(window:GetFrameLevel() + 10)
    row:SetIgnoreParentAlpha(true)
    row:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", B.left, ns.stripLayout.stripHeight)
    row:SetSize(ns.character.width + 8 - B.left, B.height)
    row:Hide()
    local list = {}
    for _, s in ipairs(SHORTCUTS) do
        local target = Target(s[4])
        if target then table.insert(list, { s, target }) end
    end
    local gap = 6
    local w = (row:GetWidth() - (#list - 1) * gap) / math.max(1, #list)
    row.buttons = {}
    for i, e in ipairs(list) do
        local s, target = e[1], e[2]
        local b = ns.character.Button(row, w, nil, function() return s[2] end, "SecureActionButtonTemplate")
        b:SetHeight(24)
        b:SetPoint("LEFT", (i - 1) * (w + gap), -1)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "click")
        b:SetAttribute("clickbutton", target)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetTexture(ns.media .. "strips\\" .. s[3])
        b.label:SetText(s[1])
        b.label:ClearAllPoints()
        b.label:SetPoint("CENTER", 10, 0)
        b.icon:SetPoint("RIGHT", b.label, "LEFT", -5, 0)
        b.target = target
        row.buttons[i] = b
    end
    ns.On("PLAYER_REGEN_ENABLED", Follow)
    page.shortcuts = row
end

local function Build(frame, foot, band)
    body = frame
    -- Blizzard's slot hover opens the equipment flyout (Alt) with the
    -- settings its parent holds: the slots' parent is this page now, so it
    -- holds a copy of Blizzard's, the flyout shown over this window (theirs
    -- is only read; the 0.20 flyoutSettings error)
    local theirs = PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings
    if type(theirs) == "table" then
        local mine = {}
        for k, v in pairs(theirs) do mine[k] = v end
        mine.parent = body
        body.flyoutSettings = mine
    end
    name = ns.Text(body, 18)
    name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    line = ns.Text(body, 12)
    line:SetPoint("TOP", name, "BOTTOM", 0, -4)
    line:SetTextColor(unpack(ns.colors.dim))
    divider = ns.character.Ornament(body)
    belt = {}
    for i = 1, 2 do
        belt[i] = body:CreateTexture(nil, "ARTWORK")
        belt[i]:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        belt[i]:SetHeight(1)
    end
    for i, s in ipairs(LEFT) do Take(s, -1, i) end
    for i, s in ipairs(RIGHT) do Take(s, 1, i) end
    for _, s in ipairs(BOTTOM) do
        local btn = Take(s)
        -- Blizzard shows and hides the ranged and ammo slots by the character
        if btn then
            hooksecurefunc(btn, "Show", Place)
            hooksecurefunc(btn, "Hide", Place)
        end
    end
    Model()
    Fit(page.height)
    ns.character.slots = { columns = slots, weapons = weapons, model = model }
    Details(foot)
    Shortcuts(band)
end

page = {
    key = "character", label = "Character", frame = "PaperDollFrame", order = 1,
    height = HEAD + #LEFT * PITCH + GAP + SLOT, bandUsed = true,
    events = { "PLAYER_EQUIPMENT_CHANGED", "UNIT_MODEL_CHANGED", "UNIT_NAME_UPDATE", "PLAYER_LEVEL_UP",
        "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
        "UNIT_ATTACK_SPEED", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED",
        "PLAYER_AVG_ITEM_LEVEL_UPDATE", "KNOWN_TITLES_UPDATE", "SKILL_LINES_CHANGED",
        "EQUIPMENT_SETS_CHANGED" },
    Build = Build, Fit = Fit, Refresh = Refresh,
    Shown = function() model:SetUnit("player") end,
    Showing = function(on)
        open = on
        Follow()
    end,
    OnEvent = function(event)
        if event == "UNIT_MODEL_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then model:SetUnit("player") end
    end,
}
ns.CharacterPage(page)
