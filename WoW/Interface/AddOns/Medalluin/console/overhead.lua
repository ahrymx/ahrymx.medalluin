-- The overhead console: decks hanging from the screen's top edge, in the
-- console's brown and gold (art/console/gen_overhead.py, variant C).
--   the boss deck:      boss1..boss5
--   the companion deck: pet, focus, target of target
--   the tray:           the stance bar, the pet bar and the totem bar, one centred row of bare icons
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

-- The cells share a deck's floor less its margins, filling it: a deck the
-- one under it has widened (three units under two bosses, a full pet bar
-- under the pet) stretches its cells across. The total is kept even so the
-- row is centred on whole pixels. Never under A.cell from Layout: a deck is
-- at least DeckWidth wide.
local function CellWidth(kind, n, w)
    local floor = w - 2 * A.deck[kind] - 2 * A.margin
    local cw = math.floor((floor - (n - 1) * A.gap) / n)
    if (n * cw + (n - 1) * A.gap) % 2 == 1 then cw = cw - 1 end
    return cw
end
ns.OverheadCellWidth = CellWidth

-- The command row's width: its icons, and a separator before each group
-- but the first (breaks: the indices a separator comes before).
local function RowWidth(n, breaks)
    if n == 0 then return 0 end
    local seps = 0
    for _ in pairs(breaks) do seps = seps + 1 end
    return n * (A.icon + A.iconGap) - A.iconGap + seps * A.iconSep, A.iconSep
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

    -- the gold edge, and the ink well A.cellEdge inside it
    local e = A.cellEdge
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(unpack(A.edge))
    local ink = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", e, -e)
    ink:SetPoint("BOTTOMRIGHT", -e, e)
    ink:SetColorTexture(unpack(C.ink))

    -- the icon column on the left: chip and glyph, then the gold divider
    local c = CHIPS[chip]
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MEDIA .. c.file)
    icon:SetTexCoord(0, c.w / c.tw, 0, c.h / c.th)
    icon:SetSize(c.w, c.h)
    icon:SetPoint("TOPLEFT", e, -e)
    b.chip = icon
    local divider = b:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(A.edge))
    divider:SetWidth(e)
    divider:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    divider:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT")

    -- the window: health, one ink row, power
    local window = CreateFrame("Frame", nil, b)
    window:SetPoint("TOPLEFT", e + c.w + e, -e)
    window:SetPoint("BOTTOMRIGHT", -e, e)
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
    b.watching = true
    b:Hide()
    return b
end

local bossUnits = {}
for i = 1, 5 do
    local b = CreateCell("boss" .. i, "boss", "boss")
    -- your debuffs at the health's right end (Unit Frames > Boss; auras.lua),
    -- four pixels short of its height
    ns.AttachAuras(b, "overhead", A.deck.boss - A.cellTop - A.cellBottom - 2 * A.cellEdge - A.power - 1 - 4)
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
-- command row's icons go with it: a cell that turns up where no unit deck
-- was drawn takes the tray's place, so the icons step down a deck under it
-- (2026-11-05: a target's target over the totems), and back up when the
-- last cell goes. The plates follow on the next frame (CombatPlates): they
-- are textures, free in combat.
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
unitRow:SetAttribute("icons", 0)
unitRow:SetAttribute("unitDeck", A.deck.unit)
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
    -- the command row: under the unit deck while a cell shows, else in its place
    local icons = owner:GetAttribute("icons")
    if icons > 0 then
        local y = owner:GetAttribute("trayBase")
        if n > 0 then y = y + owner:GetAttribute("unitDeck") end
        for i = 1, icons do
            local b = owner:GetFrameRef("icon" .. i)
            if b then b:SetPoint("TOPLEFT", owner, "TOP", owner:GetAttribute("iconX" .. i), -y) end
        end
    end
    if n == 0 then return end
    local cw, gap, floor = owner:GetAttribute("cell"), owner:GetAttribute("gap"), owner:GetAttribute("floor")
    -- floor: the drawn deck's width less its sides, the cells filling it;
    -- 0, no deck was drawn
    if floor > 0 then
        cw = (floor - (n - 1) * gap) / n
        cw = cw - cw % 1
    end
    if (n * cw + (n - 1) * gap) % 2 == 1 then cw = cw - 1 end
    local left, top = -(n * cw + (n - 1) * gap) / 2, -owner:GetAttribute("top")
    for i = 1, n do
        cells[i]:SetWidth(cw)
        cells[i]:SetPoint("TOPLEFT", owner, "TOP", left + (i - 1) * (cw + gap), top)
    end
]=]
-- The watch shows and hides a cell from inside its walk over every watched
-- frame, so the layout a cell asks for runs on the next frame, never inside
-- that walk (2026-11-03: run there, it disconnected the client). Asks within
-- one frame make one layout. A frame of its own: it updates while the
-- overhead, or the whole interface (Alt+Z), is hidden.
local soon = CreateFrame("Frame")
soon:Hide()
soon:SetScript("OnUpdate", function(self)
    self:Hide()
    UpdateOverhead()
end)
ns.overheadSoon = soon
local function LayoutSoon()
    if not laying then soon:Show() end
end
for i, b in ipairs(unitCells) do
    unitRow:SetFrameRef("cell" .. i, b)
    SecureHandlerWrapScript(b, "OnShow", unitRow, UNIT_ROW)
    SecureHandlerWrapScript(b, "OnHide", unitRow, UNIT_ROW)
    b:HookScript("OnShow", LayoutSoon)
    b:HookScript("OnHide", LayoutSoon)
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
--
-- The watch is registered or let go only when that CHANGES (2026-11-03: the
-- pet's return disconnected the client). Re-registering on every layout
-- rewrote the watch manager's list of frames, and a layout run from a cell's
-- OnShow ran inside the manager's walk over that very list.
local function SetWatched(b, on)
    if b.watching == on then return end
    b.watching = on
    if on then RegisterUnitWatch(b) else UnregisterUnitWatch(b) end
end
local function Watch(b, stub)
    b.stub = stub
    SetWatched(b, not stub)
end

local function Retire(b)
    b.stub = nil
    SetWatched(b, false)
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
-- Blizzard's stance, pet and totem buttons, adopted as bare icons. Their
-- bars are parked, not killed (blizzard.lua): the bars' own events still
-- give the buttons their icons and show the ones that are in use.
local stanceButtons, petButtons = {}, {}
local totems = {}           -- the totem bar's adopted buttons, as a set

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

local function Adopt(btn, list, keepParent)
    if not keepParent then btn:SetParent(overhead) end
    btn:SetFrameStrata(overhead:GetFrameStrata())
    btn:SetFrameLevel(LEVELS.buttons)
    Bare(btn)
    FadeAutoCastCorners(btn)
    -- a button Blizzard shows or hides changes the row: lay it out again
    btn:HookScript("OnShow", function() if not laying then UpdateOverhead() end end)
    btn:HookScript("OnHide", function() if not laying then UpdateOverhead() end end)
    table.insert(list, btn)
end

-- Forever's totem bar (MultiCastActionBarFrame, Wrath's): the summon spell,
-- the current page's action per element, the recall spell. Its pages move,
-- not their buttons, so a page Blizzard hides still takes its four with it.
-- Its flyouts (an element's totems, the summons) and the arrow that opens
-- them hang above a button on Blizzard's bar; the tray hangs from the
-- screen's top, so here they open below it instead.
local function Flip(tex)
    local ulx, uly, _, lly, urx = tex:GetTexCoord()
    if ulx then tex:SetTexCoord(ulx, urx, lly, uly) end
end

local function FlyoutDown(flyout)
    local parent = flyout.parent
    if not (flyout:IsShown() and totems[parent]) then return end
    flyout:ClearAllPoints()
    flyout:SetPoint("TOP", parent, "BOTTOM", 0, 0)
    local prev
    for _, b in ipairs(flyout.buttons or {}) do
        if b:IsShown() then
            -- a spell's icon cut past its own square border, as the bar's are;
            -- the empty slot's art (spellId 0, a piece of the totem bar) left whole
            if b.icon and b.spellId and b.spellId ~= 0 then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            b:ClearAllPoints()
            if prev then b:SetPoint("TOP", prev, "BOTTOM", 0, -2) else b:SetPoint("TOP", flyout, "TOP", 0, -4) end
            prev = b
        end
    end
    -- the cap and the close arrow at the foot now, both turned over
    local close = MultiCastFlyoutFrameCloseButton
    if close then
        close:ClearAllPoints()
        close:SetPoint("BOTTOM", flyout, "BOTTOM", 0, 0)
        if close.normalTexture then Flip(close.normalTexture) end
    end
    if flyout.top and flyout.middle then
        flyout.top:ClearAllPoints()
        flyout.top:SetPoint("BOTTOM", flyout, "BOTTOM", 0, 10)
        Flip(flyout.top)
        flyout.middle:ClearAllPoints()
        flyout.middle:SetPoint("TOP", flyout, "TOP", 0, 0)
        flyout.middle:SetPoint("BOTTOM", flyout.top, "TOP", 0, 0)
        Flip(flyout.middle)
    end
end

local function ArrowDown(arrow, _, parent)
    if not (totems[parent] and arrow:IsShown()) then return end
    arrow:ClearAllPoints()
    arrow:SetPoint("TOP", parent, "BOTTOM", 0, 0)
    if arrow.normalTexture then Flip(arrow.normalTexture) end
end

local function AdoptTotems()
    local bar = MultiCastActionBarFrame
    if not bar then return end
    local perPage = NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4
    for p = 1, NUM_MULTI_CAST_PAGES or 3 do
        local page = _G["MultiCastActionPage" .. p]
        if page then
            page:SetParent(overhead)
            page:SetFrameStrata(overhead:GetFrameStrata())
            for i = 1, perPage do
                local btn = _G["MultiCastActionButton" .. ((p - 1) * perPage + i)]
                if btn then
                    Adopt(btn, {}, true)
                    totems[btn] = true
                    -- the element's coloured ring: the gold edge says it here
                    if btn.overlayTex then btn.overlayTex:SetAlpha(0) end
                end
            end
        end
    end
    for _, btn in ipairs({ MultiCastSummonSpellButton, MultiCastRecallSpellButton }) do
        Adopt(btn, {})
        totems[btn] = true
        -- the totem bar's ring round a summon or recall (always drawn, never
        -- touched by Blizzard's code): the gold edge stands for it, as the
        -- elements' overlayTex
        local ring = _G[btn:GetName() .. "Highlight"]
        if ring then ring:SetAlpha(0) end
    end
    local flyout = MultiCastFlyoutFrame
    if flyout then
        flyout:SetParent(overhead)
        flyout:SetFrameStrata(overhead:GetFrameStrata())
        flyout:SetFrameLevel(LEVELS.buttons + 4)
    end
    if MultiCastFlyoutFrame_ToggleFlyout then hooksecurefunc("MultiCastFlyoutFrame_ToggleFlyout", FlyoutDown) end
    if MultiCastFlyoutFrameOpenButton_Show then
        hooksecurefunc("MultiCastFlyoutFrameOpenButton_Show", ArrowDown)
    end
    -- the recall's update anchors it beside the last slot on Blizzard's bar;
    -- a page change shows other buttons: either way the row is laid again
    if MultiCastRecallSpellButton_Update then
        hooksecurefunc("MultiCastRecallSpellButton_Update", function() if not laying then UpdateOverhead() end end)
    end
    if ChangeMultiCastActionPage then hooksecurefunc("ChangeMultiCastActionPage", UpdateOverhead) end
end

-- The totem bar's row: the summon, the current page's elements, the recall,
-- as Blizzard's bar has them. None while the bar has no element (not a
-- shaman, or none learned yet).
local function TotemRow()
    local list, bar = {}, MultiCastActionBarFrame
    if not (bar and next(totems)) then return list end
    if not bar:IsShown() then return list end
    if MultiCastSummonSpellButton:IsShown() then table.insert(list, MultiCastSummonSpellButton) end
    local perPage = NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4
    local first = ((bar.currentPage or 1) - 1) * perPage
    for i = 1, perPage do
        local btn = _G["MultiCastActionButton" .. (first + i)]
        if btn and btn:IsShown() then table.insert(list, btn) end
    end
    if MultiCastRecallSpellButton:IsShown() then table.insert(list, MultiCastRecallSpellButton) end
    return list
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
    if ns.db and ns.db.topTotems ~= false then AdoptTotems() end
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

-- Which command icons show, in order: stances in use, the pet bar's, the
-- totem bar's; a separator comes before each group but the first.
local function CommandRow()
    -- real buttons only, simulating or not: an invented stance or pet slot is
    -- an empty, invisible button that still takes its place in the row
    local row, breaks = {}, {}
    local function Group(list)
        if #list == 0 then return end
        if #row > 0 then breaks[#row + 1] = true end
        for _, btn in ipairs(list) do table.insert(row, btn) end
    end
    local stances, pets = {}, {}
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i, btn in ipairs(stanceButtons) do
        if i <= forms then table.insert(stances, btn) else btn:Hide() end
    end
    local hasPetBar = PetHasActionBar and PetHasActionBar()
    for _, btn in ipairs(petButtons) do
        if hasPetBar and btn:IsShown() then table.insert(pets, btn) else btn:Hide() end
    end
    Group(stances)
    Group(pets)
    Group(TotemRow())
    return row, #stances, breaks
end

-- The decks the last layout drew, by kind: their widths (nil, not drawn).
local drawn = {}

local function Widen(stack)
    for i = #stack - 1, 1, -1 do
        stack[i].w = math.max(stack[i].w, stack[i + 1].w + 2 * A.deck[stack[i].kind] + 2 * A.ledge)
    end
end

-- In combat: the plates only, for the cells the watch shows now. The cells
-- and icons are secure, and unitRow has placed them; the boss deck and the
-- tray keep their widths, and a unit deck keeps the one it was drawn at,
-- which is the floor unitRow fits its cells to.
local function CombatPlates()
    if not overhead:IsShown() then return end
    local n = 0
    for _, b in ipairs(unitCells) do
        if b:IsShown() then n = n + 1 end
    end
    local stack = {}
    if drawn.boss then table.insert(stack, { kind = "boss", w = drawn.boss }) end
    if n > 0 then table.insert(stack, { kind = "unit", w = drawn.unit or DeckWidth("unit", n) }) end
    if drawn.tray then table.insert(stack, { kind = "tray", w = drawn.tray }) end
    Widen(stack)
    local y = 0
    for slot = 1, #decks do
        local d = stack[slot]
        if d then
            decks[slot]:Place(d.kind, y, d.w / 2)
            y = y + A.deck[d.kind]
        else
            decks[slot]:Clear()
        end
    end
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
    local row, stances, breaks = CommandRow()
    local rowW, sep = RowWidth(#row, breaks)

    -- the decks, top down; bottom up, a deck grows when the one under it
    -- would not be a ledge narrower than its floor
    local stack = {}
    if #bosses > 0 then table.insert(stack, { kind = "boss", cells = bosses, w = DeckWidth("boss", #bosses) }) end
    if #units > 0 then table.insert(stack, { kind = "unit", cells = units, w = DeckWidth("unit", #units) }) end
    if #row > 0 then table.insert(stack, { kind = "tray", w = rowW + 2 * A.deck.tray + 2 * A.margin }) end
    Widen(stack)

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
    drawn = {}
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
                -- the tray's top with no unit deck over it, for unitRow
                local trayBase = y + A.trayTop - (drawn.unit and A.deck.unit or 0)
                unitRow:SetAttribute("trayBase", trayBase)
                for i, btn in ipairs(row) do
                    if breaks[i] then x = x + sep end
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", overhead, "TOP", x, -(y + A.trayTop))
                    btn:Show()
                    unitRow:SetFrameRef("icon" .. i, btn)
                    unitRow:SetAttribute("iconX" .. i, x)
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
            drawn[d.kind] = d.w
        else
            decks[slot]:Clear()
        end
    end
    unitRow:SetAttribute("icons", drawn.tray and #row or 0)
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
--
-- A runaway guard (2026-11-03: the pet's return after landing, with the pet
-- frame and the pet bar both on, disconnected the client every time). A loop
-- that freezes the client within one frame is on the stack, so it shows as
-- the layout asked for again from inside itself; Layout's own shows and hides
-- never ask (laying), so one level is all a real change needs. Deeper asks
-- are dropped, and the first of the session is reported with its stack.
local pending = false
local depth, reported = 0, false
local MAX_DEPTH = 2
local function Runaway()
    if depth < MAX_DEPTH then return false end
    if not reported then
        reported = true
        local report = geterrorhandler and geterrorhandler() or print
        report("Medalluin: the overhead's layout asked for itself " .. MAX_DEPTH
            .. " deep and was stopped; please send this report.\n" .. (debugstack and debugstack(2) or ""))
    end
    return true
end
-- An error in the layout goes to the game's handler with its stack, and the
-- depth comes back down whatever happens.
local function Guarded(fn)
    depth = depth + 1
    local ok = xpcall(fn or Layout, geterrorhandler and geterrorhandler() or function(e) print("Lua error", e) end)
    depth = depth - 1
    if not ok then laying = false end
end
function UpdateOverhead()
    if Runaway() then return end
    if pending and not InCombatLockdown() then return end
    if InCombatLockdown() then
        Guarded(CombatPlates)
        if pending then return end
        pending = true
        ns.OutOfCombat(function()
            pending = false
            Guarded()
        end)
        return
    end
    Guarded()
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
ns.On("UPDATE_MULTI_CAST_ACTIONBAR", UpdateOverhead)

ns.OnSetting("overhead", UpdateOverhead)
ns.OnSetting("bossFrames", UpdateOverhead)
ns.OnSetting("topPet", UpdateOverhead)
ns.OnSetting("topFocus", UpdateOverhead)
ns.OnSetting("topToT", UpdateOverhead)
ns.OnSetting("topPetBar", UpdateOverhead)
ns.OnSetting("topStances", UpdateOverhead)
ns.OnSetting("topTotems", UpdateOverhead)
ns.OnSetting("simParty", UpdateOverhead)
