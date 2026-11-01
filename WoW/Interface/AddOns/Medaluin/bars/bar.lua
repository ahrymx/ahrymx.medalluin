-- The action bar: action bar 1 in a stone plate standing on the console's
-- top edge, pure geometry after the user's sketch: two rows, its sides
-- upright beside the upper row and then a 45-degree skirt on the console's
-- own shoulder line. The upper row holds the 12 slots, a pillar in every
-- gap, the page chevrons and number in its right end and the minimap
-- button drawer's toggle in its left (bars/drawer.lua); the lower row
-- holds the player's cast bar (bars/cast.lua) over the class resource
-- (bars/power.lua). With the Rows option, action bars 2 and 3 stack above
-- the plate, bare.
--
-- The plate and chevrons are Medaluin's own art (art/bars/gen_bar.py; the
-- client's own frame atlas is only a hairline on retail), and the page
-- buttons are Blizzard's frames in Medaluin's chevrons; nothing of
-- Blizzard's ships here. Blizzard's action buttons are laid out for 45px;
-- they are scaled to the plate's 36px windows.
--
-- The plate's foot tucks under the console's top border, so the plate
-- draws below the console's art.
--
--   console base + 1   the slots' backing, so an empty slot is a dark well
--   console base + 2   the class resource, in the lower row, and the drawer's
--                      toggle, in the left end
--   console base + 3   the cast bar, over the class resource
--   console base + 4   the plate, over all three: its pill and its round
--                      window crop what shows through them
--   console base + 5   the action buttons
--   console base + 7   the page chevrons and number, the minimap button
--                      drawer's toggle and its open line (bars/drawer.lua)
--   (console base + 10 is the console's art, over the plate's foot)
--
-- Built at login by bars/buttons.lua, and only when the Action bar option is
-- on (settings.lua): the row count it is built with is the saved one.
local _, ns = ...

local console = ns.console
local base = console:GetFrameLevel()
ns.levels.actionBar = base + 1
ns.levels.barPower = base + 2
ns.levels.barToggle = base + 2
ns.levels.barCast = base + 3
ns.levels.barPlate = base + 4
ns.levels.actionButtons = base + 5
local PAGER = base + 7
ns.levels.barPager = PAGER

-- Blizzard's buttons are laid out at this size.
local BUTTON = 45

-- Anchor one of Blizzard's widgets over a window ({ left, right, top,
-- bottom }, heights above the console's top), scaling it from its own size
-- to the window's. Offsets are in the widget's own scale.
local function Fit(region, w, size)
    local k = (w[2] - w[1]) / size
    region:SetScale(k)
    region:ClearAllPoints()
    region:SetPoint("CENTER", console, "TOP", (w[1] + w[2]) / 2 / k, (w[3] + w[4]) / 2 / k)
    return k
end

function ns.PlaceOnBar(btn, w)
    Fit(btn, w, BUTTON)
    btn:SetSize(BUTTON, BUTTON)
end

local plate
local function Tint(hex) plate:SetVertexColor(ns.HexColor(hex)) end

-- ------------------------------------------------------------- visibility
-- The Show the bar option fades the whole bar (buttons, plate, chevrons,
-- cast bar and class resource are all its children). Only the alpha changes, which is allowed
-- in combat, so a faded bar keeps working: clicks and key bindings stay
-- live. It also comes back while a spell or item is on the cursor, so one
-- can be dropped on it.
local FADE_TIME, FADED = 0.2, 0

local function Fade(tray)
    local V = ns.VISIBILITY
    local inCombat = InCombatLockdown()
    local function Wanted()
        local mode = ns.db.visibility
        if mode == V.ALWAYS or (GetCursorInfo and GetCursorInfo()) then return true end
        -- an open drawer stands outside the tray, and counts as the bar
        local over = tray:IsMouseOver() or (ns.drawer and ns.drawer:IsShown() and ns.drawer:IsMouseOver())
        if mode == V.COMBAT then return inCombat end
        if mode == V.MOUSEOVER then return over end
        return inCombat or over
    end
    local alpha = Wanted() and 1 or FADED
    tray:SetAlpha(alpha)
    local watcher = CreateFrame("Frame", nil, tray)
    watcher:SetScript("OnUpdate", function(_, dt)
        local goal = Wanted() and 1 or FADED
        if alpha == goal then return end
        local step = dt / FADE_TIME
        alpha = goal > alpha and math.min(goal, alpha + step) or math.max(goal, alpha - step)
        tray:SetAlpha(alpha)
    end)
    ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true end)
    ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false end)
    ns.barFade = watcher
end

-- ------------------------------------------------------------ paging
-- Blizzard's own page buttons and number (MainActionBar.ActionBarPageNumber),
-- moved into the boxes on the upper row's right end and dressed in the plate's
-- chevrons: their clicks are still Blizzard's, so paging (and quick keybind
-- mode on them) behaves as in the default UI. The number was kept by
-- MainActionBar's event handler, which goes quiet with the bar, so it is
-- kept here. Nothing on a client without one (Classic Era).
local CHEVRONS = ns.media .. "bar\\"

local function Page()
    return C_ActionBar and C_ActionBar.GetActionBarPage and C_ActionBar.GetActionBarPage()
        or GetActionBarPage and GetActionBarPage()
end

-- Anchor a region over a box ({ left, right, top, bottom }), inset by a
-- pixel for the box's rim.
local function InBox(region, w)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", console, "TOP", w[1] + 1, w[3] - 1)
    region:SetPoint("BOTTOMRIGHT", console, "TOP", w[2] - 1, w[4] + 1)
end

local function Chevron(btn, w, name)
    if not btn then return end
    InBox(btn, w)
    btn:SetNormalTexture(CHEVRONS .. "chevron-" .. name)
    btn:SetPushedTexture(CHEVRONS .. "chevron-" .. name .. "-pushed")
    btn:SetDisabledTexture(CHEVRONS .. "chevron-" .. name)
    btn:SetHighlightTexture(CHEVRONS .. "chevron-highlight", "ADD")
    local disabled = btn:GetDisabledTexture()
    if disabled and disabled.SetDesaturated then disabled:SetDesaturated(true) end
end

local function Pager(tray)
    local pager = MainActionBar and MainActionBar.ActionBarPageNumber
    if not pager then return end
    local function Show()
        local page = Page()
        if pager.Text and page then pager.Text:SetText(page) end
    end
    ns.OutOfCombat(function()
        local boxes = ns.barPager
        pager:SetParent(tray)
        pager:SetScale(1)       -- MainActionBar shrinks it with the bar's icon size
        pager:SetFrameLevel(PAGER)
        InBox(pager, { boxes.up[1], boxes.number[2], boxes.up[3], boxes.down[4] })
        Chevron(pager.UpButton, boxes.up, "up")
        Chevron(pager.DownButton, boxes.down, "down")
        if pager.Text then
            pager.Text:ClearAllPoints()
            pager.Text:SetPoint("CENTER", console, "TOP", (boxes.number[1] + boxes.number[2]) / 2,
                (boxes.number[3] + boxes.number[4]) / 2)
        end
        pager:Show()
        Show()
    end)
    ns.On("ACTIONBAR_PAGE_CHANGED", Show)
    ns.On("UPDATE_BONUS_ACTIONBAR", Show)
    return pager
end

-- Returns the bar, and its slots as rows of 12 from the bottom up.
function ns.BuildBar(rows)
    local art, frame, windows = ns.barArt, ns.barFrame, ns.barWindows[rows]
    local top = math.max(frame[3], windows[#windows][1][3])

    -- A child of the console, so it takes the console's scale with it. It
    -- spans the plate and the stacked rows, which is what a mouseover reads.
    local tray = CreateFrame("Frame", "MedaluinActionBar", console)
    tray:SetPoint("BOTTOMLEFT", console, "TOP", frame[1], art.bottom)
    tray:SetPoint("TOPRIGHT", console, "TOP", frame[2], top)
    tray:SetFrameLevel(ns.levels.actionBar)
    ns.actionBar = tray

    -- behind the plate: the background layer ("layer2bg") covers the entire plate footprint
    local backing = tray:CreateTexture(nil, "BACKGROUND")
    backing:SetSize(art.width, art.height)
    backing:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
    backing:SetTexture(ns.media .. "actionbar-bg")
    backing:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
    ns.barBacking = backing

    -- if multiple rows are active, upper rows stand above the plate and get their own backing bands
    if rows > 1 then
        for r = 2, rows do
            local rSlots = windows[r]
            local rBacking = tray:CreateTexture(nil, "BACKGROUND")
            rBacking:SetPoint("TOPLEFT", console, "TOP", rSlots[1][1], rSlots[1][3])
            rBacking:SetPoint("BOTTOMRIGHT", console, "TOP", rSlots[#rSlots][2], rSlots[#rSlots][4])
            rBacking:SetColorTexture(unpack(ns.colors.ink))
        end
    end

    -- the plate stands over the bars and the toggle, so its own frame
    local stone = CreateFrame("Frame", nil, tray)
    stone:SetAllPoints()
    stone:SetFrameLevel(ns.levels.barPlate)
    plate = stone:CreateTexture(nil, "ARTWORK")
    plate:SetSize(art.width, art.height)
    plate:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
    plate:SetTexture(ns.media .. "actionbar")
    plate:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
    ns.barPlate = plate

    ns.pager = Pager(tray)
    if ns.BuildPower then ns.BuildPower(tray) end
    if ns.BuildCast then ns.BuildCast(tray) end
    if ns.BuildDrawer then ns.BuildDrawer(tray) end
    Tint(ns.db.artColor)
    ns.OnSetting("artColor", Tint)
    Fade(tray)
    return tray, windows
end
