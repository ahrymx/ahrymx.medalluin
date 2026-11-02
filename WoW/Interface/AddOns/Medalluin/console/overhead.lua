-- The overhead console: decks hanging from the screen's top edge, in the
-- console's navy and gold (art/console/gen_overhead.py, variant C).
--   the boss deck:      boss1..boss5
--   the companion deck: pet, focus, target of target
--   the tray:           the stance bar and the pet bar, one centred row of bare icons
-- Each deck is an inverted trapezoid; a lower one is narrower than the floor
-- above it, so the stack reads as an upside-down ziggurat. When a lower deck
-- is too wide for that, the decks above grow, and their cells stretch to fill. Every unit is one
-- cell: a gold edge, an icon column on its left that says who it is, then
-- health over a thin power strip. The geometry and the art come from the
-- generated console/overhead_art.lua; the sums below are the generator's.
local _, ns = ...

local C = ns.colors
local A, PIECES, CHIPS = ns.overheadArt, ns.overheadPieces, ns.overheadChips
local MEDIA = ns.media .. "overhead\\"

local function Muted(r, g, b)
    return r * ns.mute, g * ns.mute, b * ns.mute
end

local function HealthColor(unit)
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        return unpack(C.dead)
    end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = not ns.IsSecret(class) and class and RAID_CLASS_COLORS[class]
        if c then return Muted(c.r, c.g, c.b) end
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then
        return unpack(C.dead)
    end
    local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
    return Muted(c.r, c.g, c.b)
end

local overhead = CreateFrame("Frame", "MedalluinOverhead", UIParent)
overhead:SetFrameStrata("LOW")
overhead:SetPoint("TOP", UIParent, "TOP", 0, 0)
-- A frame with one anchor and no size has no rectangle, and nothing anchored
-- to it can be placed; Layout sizes it to what it holds.
overhead:SetSize(1, 1)
ns.overhead = overhead

local base = overhead:GetFrameLevel()
-- The plate is the backing, under the cells and the tray's icons; the cells'
-- text over everything.
local LEVELS = {
    plate = base + 1,
    cells = base + 2,
    buttons = base + 6,
    text = base + 8,
}

-- As the console's (console/frame.lua): its share of the screen, times the
-- player's Scale, moved by their offset in design units (movers.lua).
local function Rescale()
    ns.OutOfCombat(function()
        local dh = ns.layout and ns.layout.designHeight or 1080
        local k = tonumber(ns.db.overheadScale) or 1
        if k <= 0 then k = 1 end
        overhead:SetScale(UIParent:GetHeight() / dh * k)
        overhead:ClearAllPoints()
        overhead:SetPoint("TOP", UIParent, "TOP", (tonumber(ns.db.overheadX) or 0) / k,
            (tonumber(ns.db.overheadY) or 0) / k)
    end)
end
ns.PlaceOverhead = Rescale
Rescale()
ns.On("UI_SCALE_CHANGED", Rescale)
ns.On("DISPLAY_SIZE_CHANGED", Rescale)
ns.On("PLAYER_ENTERING_WORLD", Rescale)

-- ------------------------------------------------------------ the plate
local plate = CreateFrame("Frame", nil, overhead)
plate:SetAllPoints()
plate:SetFrameLevel(LEVELS.plate)

-- One art piece: the art sits at the top-left of its power-of-two texture.
local function Piece(tex, name, mirrored)
    local p = PIECES[name]
    tex:SetTexture(MEDIA .. name)
    local u, v = p.w / p.tw, p.h / p.th
    if mirrored then tex:SetTexCoord(u, 0, 0, v) else tex:SetTexCoord(0, u, 0, v) end
    tex:SetSize(p.w, p.h)
end

-- A deck slot, top down. A lower slot draws on a higher sublevel, because its
-- pieces repaint where it meets the deck above. The plate's gradient is fixed
-- to the screen, so a piece is chosen by the deck's kind AND the y it hangs at.
local function DeckSlot(slot)
    local d = { slot = slot }
    d.left = plate:CreateTexture(nil, "ARTWORK", nil, slot)
    d.right = plate:CreateTexture(nil, "ARTWORK", nil, slot)
    d.mid = plate:CreateTexture(nil, "ARTWORK", nil, slot)
    function d:Place(kind, y, half)
        local name = kind .. "-" .. y
        local wing = PIECES[name .. "-wing"]
        Piece(self.left, name .. "-wing", false)
        Piece(self.right, name .. "-wing", true)
        Piece(self.mid, name .. "-mid", false)
        self.left:ClearAllPoints()
        self.left:SetPoint("TOPLEFT", overhead, "TOP", -half + wing.dx, -(y + wing.dy))
        self.right:ClearAllPoints()
        self.right:SetPoint("TOPRIGHT", overhead, "TOP", half - wing.dx, -(y + wing.dy))
        self.mid:ClearAllPoints()
        self.mid:SetPoint("TOPLEFT", self.left, "TOPRIGHT")
        self.mid:SetPoint("BOTTOMRIGHT", self.right, "BOTTOMLEFT")
        self.kind, self.y, self.half, self.shown = kind, y, half, true
        self.left:Show(); self.right:Show(); self.mid:Show()
    end
    function d:Clear()
        self.shown = false
        self.left:Hide(); self.right:Hide(); self.mid:Hide()
    end
    d:Clear()
    return d
end
local decks = { DeckSlot(1), DeckSlot(2), DeckSlot(3) }
ns.overheadDecks = decks

-- A deck's top width for n cells: the cells fit its floor, which is two
-- heights narrower than its top, plus a margin each side.
local function DeckWidth(kind, n)
    return n * A.cell[kind] + (n - 1) * A.gap + 2 * A.deck[kind] + 2 * A.margin
end

-- The cells share a deck's floor less its margins, each at most A.cell wide:
-- a deck the one under it has widened (a full pet bar under the pet) centres
-- its cells rather than stretching them. The total is kept even so the row is
-- centred on whole pixels. Never under A.cell from Layout: a deck is at least
-- DeckWidth wide.
local function CellWidth(kind, n, w)
    local floor = w - 2 * A.deck[kind] - 2 * A.margin
    local cw = math.min(A.cell[kind], math.floor((floor - (n - 1) * A.gap) / n))
    if (n * cw + (n - 1) * A.gap) % 2 == 1 then cw = cw - 1 end
    return cw
end
ns.OverheadCellWidth = CellWidth

-- The command row's width: stances, the separator, the pet bar.
local function RowWidth(n, stances)
    if n == 0 then return 0 end
    local sep = (stances > 0 and stances < n) and A.iconSep or 0
    return n * (A.icon + A.iconGap) - A.iconGap + sep, sep
end

-- ------------------------------------------------------------ the cells
local UpdateUnitStatus
-- true while Layout runs: the shows and hides it makes are not news to it
local laying = false
local UpdateOverhead

local function CreateCell(unit, kind, chip)
    local b = CreateFrame("Button", "MedalluinUnit_" .. unit, overhead, "SecureUnitButtonTemplate")
    b.unit, b.kind = unit, kind
    b:SetFrameLevel(LEVELS.cells)
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    b:SetSize(A.cell[kind], A.deck[kind] - A.cellTop - A.cellBottom)

    -- the gold edge, and the ink well one pixel inside it
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(unpack(A.edge))
    local ink = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(unpack(C.ink))

    -- the icon column on the left: chip and glyph, then the gold divider
    local c = CHIPS[chip]
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MEDIA .. c.file)
    icon:SetTexCoord(0, c.w / c.tw, 0, c.h / c.th)
    icon:SetSize(c.w, c.h)
    icon:SetPoint("TOPLEFT", 1, -1)
    b.chip = icon
    local divider = b:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(A.edge))
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    divider:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT")

    -- the window: health, one ink row, power
    local window = CreateFrame("Frame", nil, b)
    window:SetPoint("TOPLEFT", 1 + c.w + 1, -1)
    window:SetPoint("BOTTOMRIGHT", -1, 1)
    local health = CreateFrame("StatusBar", nil, window)
    health:SetPoint("TOPLEFT")
    health:SetPoint("BOTTOMRIGHT", 0, A.power + 1)
    health:SetStatusBarTexture(ns.bar)
    b.health = health
    local power = CreateFrame("StatusBar", nil, window)
    power:SetPoint("BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT")
    power:SetHeight(A.power)
    power:SetStatusBarTexture(ns.bar)
    b.power = power

    local text = CreateFrame("Frame", nil, b)
    text:SetAllPoints(health)
    text:SetFrameLevel(LEVELS.text)
    b.value = ns.Text(text, 10)
    b.value:SetPoint("RIGHT", text, "RIGHT", -4, 0)
    b.value:SetJustifyH("RIGHT")
    b.value:SetTextColor(unpack(C.dim))
    b.name = ns.Text(text, 10)
    b.name:SetPoint("LEFT", text, "LEFT", 4, 0)
    b.name:SetPoint("RIGHT", b.value, "LEFT", -4, 0)   -- a long name stops short of the value
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    -- Each button hears its own unit: RegisterUnitEvent keeps one unit per
    -- event per frame, so a shared watcher only ever heard the last one.
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_NAME_UPDATE" }) do
        ns.RegisterUnitEvent(b, event, unit)
    end
    b:SetScript("OnEvent", function(self) UpdateUnitStatus(self) end)

    RegisterUnitWatch(b)
    b:Hide()
    return b
end

local bossUnits = {}
for i = 1, 5 do
    local b = CreateCell("boss" .. i, "boss", "boss")
    -- your debuffs at the health's right end (Unit Frames > Boss; auras.lua),
    -- four pixels short of its height
    ns.AttachAuras(b, "overhead", A.deck.boss - A.cellTop - A.cellBottom - 2 - A.power - 1 - 4)
    ns.RegisterUnitEvent(b, "UNIT_AURA", b.unit)
    -- the unit watch shows it in combat, with no word to the layout
    b:HookScript("OnShow", ns.UpdateUnitAuras)
    b:SetScript("OnEvent", function(self, event)
        if event == "UNIT_AURA" then ns.UpdateUnitAuras(self) else UpdateUnitStatus(self) end
    end)
    bossUnits[i] = b
end
local petUnit = CreateCell("pet", "unit", "pet")
local focusUnit = CreateCell("focus", "unit", "focus")
local totUnit = CreateCell("targettarget", "unit", "targettarget")

-- The unit row, as its cells come and go. Out of combat a cell the unit
-- watch shows or hides lays the overhead out again. In combat the layout
-- waits for it to end (UpdateOverhead), but the watch does not: a target's
-- target that turns up mid-fight showed where it last stood, over the pet
-- standing there now. So in combat the row lays itself out, securely: the
-- cells shown, centred on the deck the last layout drew, each at most its
-- drawn width, narrower when more show than that deck was drawn for. The
-- plates stay as they were until combat ends.
local unitCells = { petUnit, focusUnit, totUnit }
-- The header is the cells' anchor in combat: a restricted snippet may only
-- anchor to a protected frame, and the overhead is not one (2026-11-02: the
-- cells were anchored to it, refused, and vanished). It sits on the
-- overhead's top centre, where Layout anchors them.
local unitRow = CreateFrame("Frame", nil, overhead, "SecureHandlerBaseTemplate")
unitRow:SetSize(1, 1)
unitRow:SetPoint("TOP", overhead, "TOP")
unitRow:SetAttribute("cell", A.cell.unit)
unitRow:SetAttribute("gap", A.gap)
unitRow:SetAttribute("floor", 0)
unitRow:SetAttribute("top", A.cellTop)
ns.overheadUnitRow = unitRow
-- Restricted code has no math library; everything is worked out before a
-- cell is touched, and each keeps its point until the new one is set.
local UNIT_ROW = [=[
    if not PlayerInCombat() then return end
    local cells, n = newtable(), 0
    for i = 1, 3 do
        local c = owner:GetFrameRef("cell" .. i)
        if c and c:IsShown() then
            n = n + 1
            cells[n] = c
        end
    end
    if n == 0 then return end
    local cw, gap, floor = owner:GetAttribute("cell"), owner:GetAttribute("gap"), owner:GetAttribute("floor")
    -- floor: the drawn deck's width less its sides; 0, no deck was drawn
    if floor > 0 then
        local fit = (floor - (n - 1) * gap) / n
        fit = fit - fit % 1
        if fit < cw then cw = fit end
    end
    if (n * cw + (n - 1) * gap) % 2 == 1 then cw = cw - 1 end
    local left, top = -(n * cw + (n - 1) * gap) / 2, -owner:GetAttribute("top")
    for i = 1, n do
        cells[i]:SetWidth(cw)
        cells[i]:SetPoint("TOPLEFT", owner, "TOP", left + (i - 1) * (cw + gap), top)
    end
]=]
for i, b in ipairs(unitCells) do
    unitRow:SetFrameRef("cell" .. i, b)
    SecureHandlerWrapScript(b, "OnShow", unitRow, UNIT_ROW)
    SecureHandlerWrapScript(b, "OnHide", unitRow, UNIT_ROW)
    b:HookScript("OnShow", function() if not laying then UpdateOverhead() end end)
    b:HookScript("OnHide", function() if not laying then UpdateOverhead() end end)
end

ns.overheadUnits = {
    pet = petUnit,
    focus = focusUnit,
    targettarget = totUnit,
    boss1 = bossUnits[1],
    boss2 = bossUnits[2],
    boss3 = bossUnits[3],
    boss4 = bossUnits[4],
    boss5 = bossUnits[5],
}

-- A watched button is shown and hidden by its unit's existence, every frame:
-- a simulated (stubbed) unit does not exist, so the watch must let go of it,
-- and a switched-off frame must not come back with its unit.
local function Watch(b, stub)
    b.stub = stub
    if stub then
        UnregisterUnitWatch(b)
    else
        RegisterUnitWatch(b)
    end
end

local function Retire(b)
    b.stub = nil
    UnregisterUnitWatch(b)
    b:Hide()
end

function UpdateUnitStatus(b)
    if not b then return end
    local stub = b.stub
    if stub then
        local health = stub.dead and 0 or stub.health or 100
        b.health:SetMinMaxValues(0, stub.maxHealth or 100)
        b.health:SetValue(health)
        local c = RAID_CLASS_COLORS[stub.class] or FACTION_BAR_COLORS[2]
        if c then b.health:SetStatusBarColor(Muted(c.r, c.g, c.b)) end
        b.name:SetText(stub.name or b.unit)
        if stub.dead then
            b.value:SetText(DEAD)
        else
            b.value:SetFormattedText("%.0f%%", math.floor(health / (stub.maxHealth or 100) * 100 + 0.5))
        end
        b.power:SetMinMaxValues(0, 100)
        b.power:SetValue(stub.power or 80)
        b.power:SetStatusBarColor(0.2, 0.5, 0.85)
        return
    end

    local unit = b.unit
    if not UnitExists(unit) then return end

    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if not ns.IsSecret(max) and max <= 0 then max = 1 end
    b.health:SetMinMaxValues(0, max)
    b.health:SetValue(cur)
    b.health:SetStatusBarColor(HealthColor(unit))

    b.name:SetText(ns.Or(UnitName(unit), unit))
    if not UnitIsConnected(unit) then
        b.value:SetText(PLAYER_OFFLINE)
    elseif UnitIsDeadOrGhost(unit) then
        b.value:SetText(DEAD)
    else
        local pct = (not ns.IsSecret(cur) and not ns.IsSecret(max) and max > 0)
            and math.floor(cur / max * 100 + 0.5) or 100
        b.value:SetFormattedText("%d%%", pct)
    end

    local pMax = UnitPowerMax(unit)
    local pCur = UnitPower(unit)
    if not ns.IsSecret(pMax) and pMax <= 0 then pMax = 1 end
    b.power:SetMinMaxValues(0, pMax)
    b.power:SetValue(pCur)
    local c = PowerBarColor[UnitPowerType(unit)] or PowerBarColor.MANA
    b.power:SetStatusBarColor(Muted(c.r, c.g, c.b))
end

-- ------------------------------------------------------------ the command row
-- Blizzard's stance and pet buttons, adopted as bare icons. Their bars are
-- parked, not killed (blizzard.lua): the bars' own events still give the
-- buttons their icons and show the ones that are in use.
local stanceButtons, petButtons = {}, {}

-- Each icon edged in gold, as the unit cells are (variant A, chosen
-- 2026-11-01 from art/console/render/overhead-frames.png): a 1px black edge
-- inside the button, around the icon, and a 1px gold one outside it, light
-- at the top and dark at the foot, as the art's gold gradient runs.
local GOLD_TOP, GOLD_FOOT = { 0.941, 0.831, 0.533 }, { 0.659, 0.510, 0.227 }   -- #f0d488, #a8823a

local function Frame(btn)
    local gold = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
    gold:SetPoint("TOPLEFT", -1, 1)
    gold:SetPoint("BOTTOMRIGHT", 1, -1)
    if gold.SetGradient and CreateColor then
        gold:SetColorTexture(1, 1, 1, 1)
        gold:SetGradient("VERTICAL", CreateColor(GOLD_FOOT[1], GOLD_FOOT[2], GOLD_FOOT[3], 1),
            CreateColor(GOLD_TOP[1], GOLD_TOP[2], GOLD_TOP[3], 1))
    else
        gold:SetColorTexture((GOLD_TOP[1] + GOLD_FOOT[1]) / 2, (GOLD_TOP[2] + GOLD_FOOT[2]) / 2,
            (GOLD_TOP[3] + GOLD_FOOT[3]) / 2, 1)
    end
    local black = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
    black:SetAllPoints()
    black:SetColorTexture(0, 0, 0, 1)
    btn.medalluinFrame = gold
end

local function Bare(btn)
    btn:SetSize(A.icon, A.icon)
    if ns.StyleButton then ns.StyleButton(btn) end
    Frame(btn)
    -- StyleButton's text is sized for the 36px action bar
    if btn.medalluinTimer then btn.medalluinTimer:SetFont(ns.font, 10, "OUTLINE") end
    if btn.medalluinHotkey then btn.medalluinHotkey:SetFont(ns.font, 8, "OUTLINE") end
    local count = btn.Count or _G[btn:GetName() .. "Count"]
    if count then count:SetFont(ns.font, 9, "OUTLINE") end
end

-- A pet ability that can autocast wears Blizzard's yellow corner brackets
-- (AutoCastOverlay.Corners, shown by PetActionBar for autoCastAllowed). They
-- are faded out; the rest of the overlay, the moving shine that says autocast
-- is ON, is left alone. Alpha, not Hide: Blizzard shows and hides the overlay
-- but never sets the corners' alpha, and a texture's alpha is free in combat.
-- Found by key, else by atlas; if neither is there, nothing is touched.
local function FadeAutoCastCorners(btn)
    local overlay = btn.AutoCastOverlay
    if not overlay then return end
    local corners = overlay.Corners
    if not corners and overlay.GetRegions then
        for _, r in ipairs({ overlay:GetRegions() }) do
            local atlas = r.GetAtlas and r:GetAtlas()
            if type(atlas) == "string" and atlas:find("Corners") then corners = r; break end
        end
    end
    if corners then corners:SetAlpha(0) end
end

local function Adopt(btn, list)
    btn:SetParent(overhead)
    btn:SetFrameStrata(overhead:GetFrameStrata())
    btn:SetFrameLevel(LEVELS.buttons)
    Bare(btn)
    FadeAutoCastCorners(btn)
    -- a button Blizzard shows or hides changes the row: lay it out again
    btn:HookScript("OnShow", function() if not laying then UpdateOverhead() end end)
    btn:HookScript("OnHide", function() if not laying then UpdateOverhead() end end)
    table.insert(list, btn)
end

local function AdoptCommandButtons()
    if ns.db and ns.db.overhead == false then return end
    if ns.db and ns.db.topStances ~= false then
        for i = 1, 10 do
            local btn = _G["StanceButton" .. i]
            if btn then Adopt(btn, stanceButtons) end
        end
    end
    if ns.db and ns.db.topPetBar ~= false then
        for i = 1, 10 do
            local btn = _G["PetActionButton" .. i]
            if btn then Adopt(btn, petButtons) end
        end
    end
end

-- ------------------------------------------------------------ layout
-- Bosses show up to the simulation panel's count (simulate.lua; two at first),
-- in the Enemies set's state; the pet, focus and target of target each while
-- the panel's Overhead tab has them, hurt with it.
local OVERHEAD_STUBS = {
    boss1 = { name = "High Warlord Naj'entus", health = 85, maxHealth = 100, power = 100, class = "WARRIOR", boss = 1 },
    boss2 = { name = "Supremus", health = 92, maxHealth = 100, power = 50, class = "WARRIOR", boss = 2 },
    boss3 = { name = "Teron Gorefiend", health = 64, maxHealth = 100, power = 100, class = "WARLOCK", boss = 3 },
    boss4 = { name = "Gurtogg Bloodboil", health = 100, maxHealth = 100, power = 30, class = "WARRIOR", boss = 4 },
    boss5 = { name = "Reliquary of Souls", health = 41, maxHealth = 100, power = 70, class = "PRIEST", boss = 5 },
    pet = { name = "Shadowfiend", health = 75, maxHealth = 100, power = 80, class = "PRIEST" },
    focus = { name = "Lady Sacrolash", health = 60, maxHealth = 100, power = 100, class = "MAGE" },
    targettarget = { name = "Main Tank", health = 88, maxHealth = 100, power = 40, class = "WARRIOR" },
}

ns.bossStubs = { OVERHEAD_STUBS.boss1, OVERHEAD_STUBS.boss2, OVERHEAD_STUBS.boss3, OVERHEAD_STUBS.boss4,
    OVERHEAD_STUBS.boss5 }      -- the Boss widget's preview (widgets/enemies.lua)

-- Which cells show: a real unit, or a stub while simulating.
local function Present(b, key)
    if ns.db and ns.db[key] == false then
        Retire(b)
        return false
    end
    local sim = ns.db and ns.db.simParty
    local stub = sim and OVERHEAD_STUBS[b.unit]
    if stub and stub.boss then
        local n = ns.sim.enemies.bosses
        if stub.boss > n then stub = nil else ns.SimApply(stub, "enemies", stub.boss, n) end
    elseif stub then
        if ns.sim.overhead[b.unit] then ns.SimApply(stub, "overhead", 1, 1) else stub = nil end
    end
    if not UnitExists(b.unit) and stub then
        Watch(b, stub)
    else
        Watch(b, nil)
        if not UnitExists(b.unit) then
            b:Hide()
            return false
        end
    end
    UpdateUnitStatus(b)
    return true
end

-- Which command icons show, in order: stances in use, then the pet bar's.
local function CommandRow()
    -- real buttons only, simulating or not: an invented stance or pet slot is
    -- an empty, invisible button that still takes its place in the row
    local row, stances = {}, 0
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i, btn in ipairs(stanceButtons) do
        if i <= forms then table.insert(row, btn); stances = stances + 1 else btn:Hide() end
    end
    local pets = PetHasActionBar and PetHasActionBar()
    for _, btn in ipairs(petButtons) do
        if pets and btn:IsShown() then table.insert(row, btn) else btn:Hide() end
    end
    return row, stances
end

local finishing = false     -- the pass after a fade out, that clears and hides
local function Layout()
    if ns.db and ns.db.overhead == false then
        overhead:Hide()
        return
    end
    laying = true

    -- bosses here, or in the Boss widget only (widgets/enemies.lua)
    local bosses = {}
    local onTop = ns.db.bossFrames ~= "vertical"
    for i = 1, 5 do
        if not onTop then
            Retire(bossUnits[i])
        elseif Present(bossUnits[i], "bossFrames") then
            table.insert(bosses, bossUnits[i])
        end
    end
    local units = {}
    if Present(petUnit, "topPet") then table.insert(units, petUnit) end
    if Present(focusUnit, "topFocus") then table.insert(units, focusUnit) end
    if Present(totUnit, "topToT") then table.insert(units, totUnit) end

    -- the command row first: it is the bottom deck, and decks grow from it
    local row, stances = CommandRow()
    local rowW, sep = RowWidth(#row, stances)

    -- the decks, top down; bottom up, a deck grows when the one under it
    -- would not be a ledge narrower than its floor
    local stack = {}
    if #bosses > 0 then table.insert(stack, { kind = "boss", cells = bosses, w = DeckWidth("boss", #bosses) }) end
    if #units > 0 then table.insert(stack, { kind = "unit", cells = units, w = DeckWidth("unit", #units) }) end
    if #row > 0 then table.insert(stack, { kind = "tray", w = rowW + 2 * A.deck.tray + 2 * A.margin }) end
    for i = #stack - 1, 1, -1 do
        stack[i].w = math.max(stack[i].w, stack[i + 1].w + 2 * A.deck[stack[i].kind] + 2 * A.ledge)
    end

    -- emptied: the plate stays as it was while it fades out (console/fade.lua),
    -- then this runs again to clear it and hide
    local show = #stack > 0 or #row > 0
    local wasShown = overhead:IsShown()
    if not show and wasShown and not finishing and ns.OverheadFadeOut
        and ns.OverheadFadeOut(function()
            finishing = true
            UpdateOverhead()
            finishing = false
        end) then
        laying = false
        return
    end

    local y, widest = 0, 0
    -- where the unit row's cells go in combat (unitRow): no deck, at its top
    local rowFloor, rowTop = 0, nil
    for slot = 1, #decks do
        local d = stack[slot]
        if d and d.kind ~= "boss" and not rowTop then
            rowTop = y + A.cellTop
            if d.kind == "unit" then rowFloor = d.w - 2 * A.deck.unit - 2 * A.margin end
        end
        if d then
            decks[slot]:Place(d.kind, y, d.w / 2)
            if d.kind == "tray" then
                -- the icons inside the tray, centred
                local x, step = -rowW / 2, A.icon + A.iconGap
                for i, btn in ipairs(row) do
                    if i == stances + 1 then x = x + sep end
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", overhead, "TOP", x, -(y + A.trayTop))
                    btn:Show()
                    x = x + step
                end
            else
                local n = #d.cells
                local cw = CellWidth(d.kind, n, d.w)
                local left = -(n * cw + (n - 1) * A.gap) / 2
                for i, b in ipairs(d.cells) do
                    b:SetWidth(cw)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", overhead, "TOP", left + (i - 1) * (cw + A.gap), -(y + A.cellTop))
                    b:Show()
                end
            end
            y = y + A.deck[d.kind]
            widest = math.max(widest, d.w)
        else
            decks[slot]:Clear()
        end
    end
    unitRow:SetAttribute("floor", rowFloor)
    unitRow:SetAttribute("top", rowTop or y + A.cellTop)
    -- bosses past the count, hidden but still watched
    for i = #bosses + 1, 5 do bossUnits[i]:Hide() end
    ns.overheadRow, ns.overheadRowStances = row, stances

    overhead:SetSize(math.max(widest, 1), math.max(y, 1))
    overhead:SetShown(show)
    -- appearing fades in from nothing; a fade out cut short turns back
    if show and ns.OverheadFadeIn then
        if not wasShown then ns.OverheadSettle(false) end
        ns.OverheadFadeIn()
    end
    laying = false
end

-- The cells and icons are secure buttons, so they are laid out out of combat
-- only; in combat a unit watch still shows and hides each cell where it stands.
local pending = false
function UpdateOverhead()
    if pending then return end
    if InCombatLockdown() then
        pending = true
        ns.OutOfCombat(function()
            pending = false
            Layout()
        end)
        return
    end
    Layout()
end
ns.UpdateOverhead = UpdateOverhead

-- ------------------------------------------------------------ events
ns.On("PLAYER_LOGIN", AdoptCommandButtons)
ns.On("PLAYER_LOGIN", UpdateOverhead)
ns.On("PLAYER_ENTERING_WORLD", UpdateOverhead)
ns.On("GROUP_ROSTER_UPDATE", UpdateOverhead)
ns.On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", UpdateOverhead)
ns.On("UNIT_TARGET", function(_, u)
    if u == "target" or u == "player" then UpdateOverhead() end
end)
ns.On("PLAYER_TARGET_CHANGED", UpdateOverhead)
ns.On("PLAYER_FOCUS_CHANGED", UpdateOverhead)
ns.On("UNIT_PET", function(_, u)
    if u == "player" then UpdateOverhead() end
end)
ns.On("UPDATE_SHAPESHIFT_FORMS", UpdateOverhead)
ns.On("PET_BAR_UPDATE", UpdateOverhead)

ns.OnSetting("overhead", UpdateOverhead)
ns.OnSetting("bossFrames", UpdateOverhead)
ns.OnSetting("topPet", UpdateOverhead)
ns.OnSetting("topFocus", UpdateOverhead)
ns.OnSetting("topToT", UpdateOverhead)
ns.OnSetting("topPetBar", UpdateOverhead)
ns.OnSetting("topStances", UpdateOverhead)
ns.OnSetting("simParty", UpdateOverhead)
