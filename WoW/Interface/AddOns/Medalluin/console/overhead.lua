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
-- Tooltips stand under the overhead, below what is hovered, out of its way
-- (a totem flyout's beside it, right or left as the option says);
-- a detached cell's beside it, towards the screen's middle (window/shell.lua's marks).
local _, ns = ...

local C = ns.colors
local A, PIECES, CHIPS = ns.overheadArt, ns.overheadPieces, ns.overheadChips
local MEDIA = ns.media .. "overhead\\"
local KEY_TOP, KEY_FOOT = { 0.341, 0.286, 0.165 }, { 0.141, 0.114, 0.055 }   -- a key's well, as the strips'
local GOLD_B = { 0.910, 0.788, 0.431 }                                        -- the percentage

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

-- There, as the unit watch has it (SecureStateDriver.lua): it exists, or the
-- game draws it. The layout hid what the watch, every 0.2s, showed again
-- (2026-11-11: the pet's cell flashing in a Darkmoon Faire vehicle, the pet
-- drawn but not existing).
local function Exists(unit)
    if UnitExists(unit) then return true end
    if not UnitIsVisible then return false end
    local ok, vis = pcall(UnitIsVisible, unit)
    return ok and (ns.IsSecret(vis) or vis) and true or false
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
    -- the dark channel the deck's keys sit in (mockup C, 2026-11-10): in by
    -- A.channel from its top, its floor and the floor's corners
    d.channel = plate:CreateTexture(nil, "OVERLAY", nil, slot)
    d.channel:SetColorTexture(0.051, 0.043, 0.027, 0.65)
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
        local h, c = A.deck[kind], A.channel
        self.channel:ClearAllPoints()
        self.channel:SetPoint("TOPLEFT", overhead, "TOP", -(half - h - c), -(y + c))
        self.channel:SetSize(2 * (half - h - c), h - 2 * c)
        self.channel:Show()
        self.kind, self.y, self.half, self.shown = kind, y, half, true
        self.left:Show(); self.right:Show(); self.mid:Show()
    end
    function d:Clear()
        self.shown = false
        self.left:Hide(); self.right:Hide(); self.mid:Hide(); self.channel:Hide()
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

    -- a key (mockup C, 2026-11-10, as the strips' keys): the gold edge, a
    -- brown well A.cellEdge inside it, lighter at its top, and a lit lip
    local e = A.cellEdge
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(unpack(A.edge))
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetPoint("TOPLEFT", e, -e)
    well:SetPoint("BOTTOMRIGHT", -e, e)
    if well.SetGradient and CreateColor then
        well:SetColorTexture(1, 1, 1, 1)
        well:SetGradient("VERTICAL", CreateColor(KEY_FOOT[1], KEY_FOOT[2], KEY_FOOT[3], 1),
            CreateColor(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1))
    else
        well:SetColorTexture((KEY_TOP[1] + KEY_FOOT[1]) / 2, (KEY_TOP[2] + KEY_FOOT[2]) / 2,
            (KEY_TOP[3] + KEY_FOOT[3]) / 2, 1)
    end
    local lip = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    lip:SetColorTexture(1, 0.95, 0.78, 0.22)
    lip:SetPoint("TOPLEFT", e + 1, -e)
    lip:SetPoint("TOPRIGHT", -e - 1, -e)
    lip:SetHeight(1)

    -- the icon column on the left: chip and glyph, on the key
    local c = CHIPS[chip]
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MEDIA .. c.file)
    icon:SetTexCoord(0, c.w / c.tw, 0, c.h / c.th)
    icon:SetSize(c.w, c.h)
    icon:SetPoint("TOPLEFT", e, -e)
    b.chip = icon

    -- the trough, sunk in the key: health, one ink row, power, in the window
    -- a pixel inside it
    local trough = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    trough:SetColorTexture(0.043, 0.035, 0.024, 1)
    trough:SetPoint("TOPLEFT", e + c.w + 2, -e)
    trough:SetPoint("BOTTOMRIGHT", -e, e)
    local window = CreateFrame("Frame", nil, b)
    window:SetPoint("TOPLEFT", e + c.w + 3, -e - 1)
    window:SetPoint("BOTTOMRIGHT", -e - 1, e + 1)
    local health = CreateFrame("StatusBar", nil, window)
    health:SetPoint("TOPLEFT")
    health:SetPoint("BOTTOMRIGHT", 0, A.power + 1)
    health:SetStatusBarTexture(ns.bar)
    -- a gloss over the health, light at its top
    local gloss = health:CreateTexture(nil, "OVERLAY")
    gloss:SetAllPoints(health:GetStatusBarTexture())
    if gloss.SetGradient and CreateColor then
        gloss:SetColorTexture(1, 1, 1, 1)
        gloss:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.18), CreateColor(1, 1, 1, 0.20))
    else
        gloss:SetColorTexture(1, 1, 1, 0)
    end
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
    b.value:SetTextColor(unpack(GOLD_B))
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
    -- the game's unit tooltip (a simulated one says so); the marks place it
    b:SetScript("OnEnter", function(self)
        if self.stub and not UnitExists(self.unit) then
            ns.Tip(self, "ANCHOR_RIGHT", { title = self.stub.name or self.unit, color = C.white,
                { "body", "Simulated", C.grey } })
        elseif UnitFrame_OnEnter then
            UnitFrame_OnEnter(self)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self.stub and not UnitExists(self.unit) then
            GameTooltip_Hide()
        elseif UnitFrame_OnLeave then
            UnitFrame_OnLeave(self)
        end
    end)

    RegisterUnitWatch(b)
    b.watching = true
    b:Hide()
    return b
end

local bossUnits = {}
for i = 1, 5 do
    local b = CreateCell("boss" .. i, "boss", "boss")
    -- your debuffs at the health's right end (Unit Frames > Boss; auras.lua),
    -- two pixels short of its height
    ns.AttachAuras(b, "overhead", A.deck.boss - A.cellTop - A.cellBottom - 2 * A.cellEdge - 2 - A.power - 1 - 2)
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
-- each cell's switch on the Overhead page, and its name in the detach
-- settings (console/overhead.lua's detached cells)
for i, b in ipairs(unitCells) do
    b.detachOrder = i
    b.switch = ({ "topPet", "topFocus", "topToT" })[i]
    b.detach = ({ "Pet", "Focus", "ToT" })[i]
end
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
-- the cells on the row, not detached (Layout keeps cell1.. to this count)
unitRow:SetAttribute("cells", 3)
ns.overheadUnitRow = unitRow
-- Restricted code has no math library; everything is worked out before a
-- cell is touched, and each keeps its point until the new one is set.
local UNIT_ROW = [=[
    if not PlayerInCombat() then return end
    local cells, n = newtable(), 0
    for i = 1, owner:GetAttribute("cells") do
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
    if not Exists(unit) then return end

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
        -- through the curve when health is secret (it read 100% in combat
        -- before, 2026-11-11): a secret percentage formats as any other
        b.value:SetFormattedText("%.0f%%", ns.HealthPercent(unit, cur, max))
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
    if not bar:IsShown() then
        -- Blizzard updates (and hides) the summon and recall only while its
        -- bar shows, so on a class with no totem bar they keep the shown
        -- state they were made with: hidden by their bar there, not here
        -- (2026-11-14: a warlock's two empty squares at the screen's corner)
        for _, btn in ipairs({ MultiCastSummonSpellButton, MultiCastRecallSpellButton }) do
            if btn and totems[btn] then btn:Hide() end
        end
        return list
    end
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
    if not Exists(b.unit) and stub then
        Watch(b, stub)
    else
        Watch(b, nil)
        if not Exists(b.unit) then
            b:Hide()
            return false
        end
    end
    UpdateUnitStatus(b)
    return true
end

-- Which command icons show, in order: stances in use, the pet bar's, the
-- totem bar's; a separator comes before each group but the first.
local function CommandRow(petAway)
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
    -- a button hidden here while there was no pet bar comes back with one
    -- (2026-11-11: a shaman possessing the Steam Tonk, its controls gone);
    -- one Blizzard hides (an empty slot) stays out
    local hasPetBar = PetHasActionBar and PetHasActionBar()
    for _, btn in ipairs(petButtons) do
        if hasPetBar and btn.medalluinAway then
            btn.medalluinAway = nil
            btn:Show()
        end
        if hasPetBar and btn:IsShown() then
            table.insert(pets, btn)
        else
            if not hasPetBar and btn:IsShown() then btn.medalluinAway = true end
            btn:Hide()
        end
    end
    Group(stances)
    if not petAway then Group(pets) end
    Group(TotemRow())
    return row, #stances, breaks, pets
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
        if b:IsShown() and not ns.OverheadOff(b) then n = n + 1 end
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

-- ------------------------------------------------------------ detached cells
-- A unit cell alt+dragged off the overhead stands on its own (mockup D3,
-- 2026-11-11: the bare key with a shadow), where it was left; alt+dragged
-- back onto the overhead's unit deck it rejoins the row in its place. The
-- pet takes its bar with it, docked under it on a strip of its own, held on
-- by two brackets. Kept per profile (detach<Unit>, detach<Unit>X/Y).
--
-- A detached cell hangs from a holder of its own on UIParent, not from the
-- overhead, which fades and hides when it is empty. The cells are secure:
-- they change hands only out of combat, and a drag is refused in combat. In
-- combat the unit watch still shows and hides each where it stands, and the
-- dock, a child of the pet's cell, goes with it. The row's combat snippet
-- (unitRow) walks only the cells still on it.
local DOCK_PAD, BRACKET = 4, 7
local holders = {}
local dragging              -- the cell being dragged, nil when none

-- Off the row: detached, or on its way off
function ns.OverheadOff(b)
    if not b.detach then return false end
    return dragging == b or (ns.db and ns.db["detach" .. b.detach]) and true or false
end

local function Alpha()
    local v = tonumber(ns.db and ns.db.overheadAlpha) or 1
    return math.max(0, math.min(1, v))
end

local function Holder(b)
    local h = holders[b]
    if h then return h end
    h = CreateFrame("Frame", "MedalluinDetached" .. b.detach, UIParent)
    h:SetFrameStrata(overhead:GetFrameStrata())
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    h:Hide()
    ns.window.Mark(h, 1)        -- its tooltips beside it, towards the middle
    holders[b] = h
    return h
end

-- the shadow a detached key casts, outside its edge
for _, b in ipairs(unitCells) do
    b.shadow = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.shadow:SetColorTexture(0, 0, 0, 0.5)
    b.shadow:SetPoint("TOPLEFT", -3, 3)
    b.shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    b.shadow:Hide()
end

-- The pet's dock: a key under its cell, the bar's icons in its dark
-- channel, two gold brackets from the cell's foot. A child of the cell, so
-- the unit watch hides it with the pet, in combat too.
local dock = CreateFrame("Frame", nil, petUnit)
dock:SetPoint("TOP", petUnit, "BOTTOM", 0, -BRACKET)
dock:Hide()
do
    local shadow = dock:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetColorTexture(0, 0, 0, 0.5)
    shadow:SetPoint("TOPLEFT", -3, 3)
    shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    local e = A.cellEdge
    local edge = dock:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(unpack(A.edge))
    local well = dock:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetPoint("TOPLEFT", e, -e)
    well:SetPoint("BOTTOMRIGHT", -e, e)
    if well.SetGradient and CreateColor then
        well:SetColorTexture(1, 1, 1, 1)
        well:SetGradient("VERTICAL", CreateColor(KEY_FOOT[1], KEY_FOOT[2], KEY_FOOT[3], 1),
            CreateColor(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1))
    else
        well:SetColorTexture(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1)
    end
    local channel = dock:CreateTexture(nil, "BACKGROUND", nil, 2)
    channel:SetColorTexture(0.051, 0.043, 0.027, 0.65)
    channel:SetPoint("TOPLEFT", e, -e)
    channel:SetPoint("BOTTOMRIGHT", -e, e)
    dock.brackets = {}
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        local br = dock:CreateTexture(nil, "BACKGROUND", nil, 3)
        br:SetColorTexture(unpack(A.edge))
        br:SetSize(8, BRACKET + 2)
        br:SetPoint("BOTTOM" .. side, dock, "TOP" .. side, (i == 1 and 14 or -14), -1)
        local rivet = dock:CreateTexture(nil, "ARTWORK")
        rivet:SetColorTexture(GOLD_B[1], GOLD_B[2], GOLD_B[3], 1)
        rivet:SetSize(2, 2)
        rivet:SetPoint("CENTER", br)
        dock.brackets[i] = br
    end
end
ns.overheadDock = dock

-- A cell back on the overhead, and the pet's buttons back in the tray.
local function Unmount(b)
    if b:GetParent() ~= overhead then
        b:SetParent(overhead)
        b:SetFrameLevel(LEVELS.cells)
    end
    b.shadow:Hide()
    Holder(b):Hide()
end

-- Where a holder stands: where it was left, else under the overhead's
-- centre, a row apart for each, in the holder's own units.
local function Place(b, h, w)
    local x, y = ns.db["detach" .. b.detach .. "X"], ns.db["detach" .. b.detach .. "Y"]
    if not (tonumber(x) and tonumber(y)) then
        local k = h:GetScale()
        local order = b.detachOrder - 1
        x = (UIParent:GetWidth() or 1024) / k / 2 - w / 2
        y = (UIParent:GetHeight() or 768) / k - 160 - order * 60
    end
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function Mount(b, w)
    local h = Holder(b)
    h:SetScale(overhead:GetScale())
    h:SetAlpha(Alpha())
    h:SetSize(w, b:GetHeight())
    if dragging ~= b then Place(b, h, w) end
    if b:GetParent() ~= h then b:SetParent(h) end
    b:SetFrameLevel(h:GetFrameLevel() + 1)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", h, "TOPLEFT")
    b:SetWidth(w)
    b.shadow:Show()
    h:Show()
end

-- The pet's bar in the dock, centred under a cell at least as wide as it;
-- nil: the pet's buttons back to the overhead, for the tray.
local function Dock(pets)
    local n = pets and #pets or 0
    local docked = {}
    for i = 1, n do docked[pets[i]] = true end
    for _, btn in ipairs(petButtons) do
        if btn:GetParent() == dock and not docked[btn] then
            btn:SetParent(overhead)
            btn:SetFrameLevel(LEVELS.buttons)
        end
    end
    if n == 0 then
        dock:Hide()
        return A.cell.unit
    end
    local step = A.icon + A.iconGap
    local bw = n * step - A.iconGap
    dock:SetSize(bw + 2 * DOCK_PAD, A.icon + 2 * DOCK_PAD)
    for i, btn in ipairs(pets) do
        if btn:GetParent() ~= dock then btn:SetParent(dock) end
        btn:SetFrameLevel(dock:GetFrameLevel() + 2)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dock, "TOPLEFT", DOCK_PAD + (i - 1) * step, -DOCK_PAD)
        btn:Show()
    end
    dock:Show()
    return math.max(A.cell.unit, bw + 2 * DOCK_PAD)
end

-- The drop zone: the overhead's unit deck, or where one would hang; lit
-- while a dragged cell is over it.
local zone = CreateFrame("Frame", nil, UIParent)
zone:SetFrameStrata("HIGH")
zone:Hide()
do
    local fill = zone:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.769, 0.647, 0.341, 0.28)
    zone.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = zone:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(GOLD_B[1], GOLD_B[2], GOLD_B[3], 1)
        t:SetPoint(pts[1])
        t:SetPoint(pts[2])
        if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
        zone.edges[i] = t
    end
end
ns.overheadZone = zone
local zoneAt = { y = 0, w = 0 }

local function OverZone()
    local x, y = GetCursorPosition()
    local s = zone:GetEffectiveScale()
    x, y = x / s, y / s
    local l, r, t, b = zone:GetLeft(), zone:GetRight(), zone:GetTop(), zone:GetBottom()
    if not (l and r and t and b) then return false end
    return x >= l - 12 and x <= r + 12 and y <= t + 12 and y >= b - 12
end

local function ShowZone()
    zone:SetScale(overhead:GetScale())
    zone:ClearAllPoints()
    zone:SetPoint("TOP", overhead, "TOP", 0, -zoneAt.y)
    zone:SetSize(zoneAt.w, A.deck.unit)
    zone:Show()
end

-- what Layout tells it: the detached on their holders, the pet's dock, and
-- where the unit deck hangs: under the boss deck if there is one, as wide as
-- it is drawn (nil: none, a cell's)
function ns.OverheadDetached(pets, underBosses, unitW)
    for _, b in ipairs(unitCells) do
        if b == dragging then
            -- under the pointer: left where it is until the drop; the pet's
            -- bar into the dock, which it carries
            if b == petUnit then Dock(pets) end
        elseif ns.OverheadOff(b) and ns.db[b.switch] ~= false then
            Mount(b, b == petUnit and Dock(pets) or A.cell.unit)
        else
            if b == petUnit then Dock(nil) end
            Unmount(b)
        end
    end
    zoneAt.y = underBosses and A.deck.boss or 0
    zoneAt.w = unitW or DeckWidth("unit", 1)
end

-- The drag moves the cell itself, from wherever it hangs, and it changes
-- hands (onto its holder, or back onto the overhead) only once it is let go:
-- handed over under the pointer, the game stopped telling it the drag was
-- over, and it stuck to the pointer until a reload (2026-11-11). The drop is
-- the cell's OnDragStop, or else the button found let go by the watcher.
local watcher = CreateFrame("Frame")
watcher:Hide()
ns.overheadDragWatch = watcher

local function Drop(b)
    if dragging ~= b then return end
    b:StopMovingOrSizing()
    if b.SetUserPlaced then b:SetUserPlaced(false) end     -- not the game's to remember
    dragging = nil
    watcher:Hide()
    local back = OverZone()
    zone:Hide()
    local key = "detach" .. b.detach
    if not back then
        -- the cell's own units are its holder's: both the overhead's scale
        ns.db[key .. "X"], ns.db[key .. "Y"] = b:GetLeft(), b:GetTop()
    end
    if (ns.db[key] and true or false) == not back then
        UpdateOverhead()
    else
        ns.SetOption(key, not back)
    end
end

watcher:SetScript("OnUpdate", function()
    local b = dragging
    if not b then watcher:Hide() return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        Drop(b)
        return
    end
    zone:SetAlpha(OverZone() and 1 or 0.35)
end)

local function Lift(b)
    if dragging or InCombatLockdown() or not IsAltKeyDown() then return end
    dragging = b
    b:StartMoving()
    -- the row closes up behind it (Layout leaves the dragged cell alone)
    UpdateOverhead()
    ShowZone()
    zone:SetAlpha(0.35)
    watcher:Show()
end

for _, b in ipairs(unitCells) do
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    -- an Alt release is the drop, not a click on the unit
    b:SetAttribute("alt-type1", "none")
    b:SetScript("OnDragStart", Lift)
    b:SetScript("OnDragStop", Drop)
end
-- a fight starting mid-drag: let go where it is, while that is still allowed
ns.On("PLAYER_REGEN_DISABLED", function() if dragging then Drop(dragging) end end)
ns.On("UI_SCALE_CHANGED", function() if UpdateOverhead then UpdateOverhead() end end)
ns.OnSetting("overheadAlpha", function()
    for _, h in pairs(holders) do h:SetAlpha(Alpha()) end
end)
for _, b in ipairs(unitCells) do
    ns.OnSetting("detach" .. b.detach, function() UpdateOverhead() end)
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
    local units, attached = {}, 0
    for _, b in ipairs(unitCells) do
        local on = Present(b, b.switch)
        if not ns.OverheadOff(b) then
            if on then table.insert(units, b) end
            if ns.db[b.switch] ~= false then
                attached = attached + 1
                unitRow:SetFrameRef("cell" .. attached, b)
            end
        end
    end
    unitRow:SetAttribute("cells", attached)

    -- the command row first: it is the bottom deck, and decks grow from it
    local petAway = ns.OverheadOff(petUnit) and ns.db.topPet ~= false
    local row, stances, breaks, pets = CommandRow(petAway)
    local rowW, sep = RowWidth(#row, breaks)

    -- the decks, top down; bottom up, a deck grows when the one under it
    -- would not be a ledge narrower than its floor
    local stack = {}
    if #bosses > 0 then table.insert(stack, { kind = "boss", cells = bosses, w = DeckWidth("boss", #bosses) }) end
    if #units > 0 then table.insert(stack, { kind = "unit", cells = units, w = DeckWidth("unit", #units) }) end
    if #row > 0 then table.insert(stack, { kind = "tray", w = rowW + 2 * A.deck.tray + 2 * A.margin }) end
    Widen(stack)
    -- the detached on their holders, the pet's bar in its dock; before an
    -- emptied overhead fades, so they do not fade with it
    local unitW
    for _, d in ipairs(stack) do if d.kind == "unit" then unitW = d.w end end
    ns.OverheadDetached(petAway and pets or nil, #bosses > 0, unitW)

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
-- its tooltips under it (window/shell.lua loads after this file); a totem
-- flyout's beside the button hovered, on the side its option says, since
-- under the overhead they would cover the flyout opening below it
ns.On("PLAYER_LOGIN", function()
    ns.window.Mark(overhead, "down")
    if MultiCastFlyoutFrame then
        ns.window.Mark(MultiCastFlyoutFrame, function() return ns.db.overheadFlyoutTips == "left" and 1 or -1 end)
    end
end)
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
