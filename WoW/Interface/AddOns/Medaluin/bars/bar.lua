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

local plate, hybridPlate
local wingPlates = {}
local function Tint(hex)
    local r, g, b = ns.HexColor(hex)
    plate:SetVertexColor(r, g, b)
    if hybridPlate then hybridPlate:SetVertexColor(r, g, b) end
    for _, w in ipairs(wingPlates) do w:SetVertexColor(r, g, b) end
end

-- ------------------------------------------------------------- visibility
-- The Bar 1 visibility and Extra bar(s) visibility options fade Bar 1 and
-- Bars 2/3 independently. Only the alpha changes, which is allowed in combat,
-- so a faded bar keeps working: clicks and key bindings stay live. It also
-- comes back while a spell or item is on the cursor, so one can be dropped on it.
local FADE_TIME, FADED = 0.2, 0

local function MakeFade(frame, settingKey, isOver)
    local V = ns.VISIBILITY
    local inCombat = InCombatLockdown()
    local function Wanted()
        local mode = ns.db[settingKey] or V.ALWAYS
        if mode == V.ALWAYS or (GetCursorInfo and GetCursorInfo()) then return true end
        local over = isOver()
        if mode == V.COMBAT then return inCombat end
        if mode == V.MOUSEOVER then return over end
        return inCombat or over
    end
    local alpha = Wanted() and 1 or FADED
    frame:SetAlpha(alpha)
    local watcher = CreateFrame("Frame", nil, frame)
    watcher:SetScript("OnUpdate", function(_, dt)
        local goal = Wanted() and 1 or FADED
        if alpha == goal then return end
        local step = dt / FADE_TIME
        alpha = goal > alpha and math.min(goal, alpha + step) or math.max(goal, alpha - step)
        frame:SetAlpha(alpha)
    end)
    ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true end)
    ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false end)
    return watcher
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

-- Returns the bar, its slots as rows of 12 from the bottom up, and the extra bars frame.
function ns.BuildBar(rows)
    local art, frame, windows = ns.barArt, ns.barFrame, ns.barWindows[rows]
    hybridPlate = nil
    wingPlates = {}

    -- A child of the console, so it takes the console's scale with it.
    -- Action Bar 1's tray spans its own plate (and open drawer for mouseover).
    local tray = CreateFrame("Frame", "MedaluinActionBar", console)
    tray:SetPoint("BOTTOMLEFT", console, "TOP", frame[1], art.bottom)
    tray:SetPoint("TOPRIGHT", console, "TOP", frame[2], frame[3])
    tray:SetFrameLevel(ns.levels.actionBar)
    ns.actionBar = tray

    -- behind the plate: the background layer ("layer2bg") covers the entire plate footprint
    local backing = tray:CreateTexture(nil, "BACKGROUND")
    backing:SetSize(art.width, art.height)
    backing:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
    backing:SetTexture(ns.media .. (art.bgFile or "actionbar-bg"))
    backing:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
    ns.barBacking = backing

    -- the plate stands over the bars and the toggle, so its own frame
    local stone = CreateFrame("Frame", nil, tray)
    stone:SetAllPoints()
    stone:SetFrameLevel(ns.levels.barPlate)
    plate = stone:CreateTexture(nil, "ARTWORK", nil, 1)
    plate:SetSize(art.width, art.height)
    plate:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
    plate:SetTexture(ns.media .. (art.file or "actionbar"))
    plate:SetTexCoord(0, art.width / art.texWidth, 0, art.height / art.texHeight)
    ns.barPlate = plate

    -- In the light profile, the trapezoid hybrid castbar/power row stands on
    -- its own frame so it remains anchored atop the console when Bar 1 fades out.
    local lowParent = tray
    if art.hybridFile then
        local hybrid = CreateFrame("Frame", "MedaluinHybridBar", console)
        hybrid:SetPoint("BOTTOMLEFT", console, "TOP", frame[1], art.bottom)
        hybrid:SetPoint("TOPRIGHT", console, "TOP", frame[2], art.bottom + art.hybridHeight)
        hybrid:SetFrameLevel(ns.levels.actionBar)
        ns.hybridBar = hybrid

        local hBg = hybrid:CreateTexture(nil, "BACKGROUND")
        hBg:SetSize(art.width, art.hybridHeight)
        hBg:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
        hBg:SetTexture(ns.media .. (art.hybridBgFile or "hybrid-light-bg"))
        hBg:SetTexCoord(0, art.width / art.texWidth, 0, art.hybridHeight / art.hybridTexHeight)

        local hStone = CreateFrame("Frame", nil, hybrid)
        hStone:SetAllPoints()
        hStone:SetFrameLevel(ns.levels.barPlate)
        hybridPlate = hStone:CreateTexture(nil, "ARTWORK", nil, 0)
        hybridPlate:SetSize(art.width, art.hybridHeight)
        hybridPlate:SetPoint("BOTTOM", console, "TOP", 0, art.bottom)
        hybridPlate:SetTexture(ns.media .. art.hybridFile)
        hybridPlate:SetTexCoord(0, art.width / art.texWidth, 0, art.hybridHeight / art.hybridTexHeight)
        lowParent = hybrid
    end

    -- Extra bars (Action Bars 2 and 3) live on their own frame managed by extraVisibility.
    local extra = CreateFrame("Frame", "MedaluinExtraBars", console)
    extra:SetFrameLevel(ns.levels.actionBar)
    local row3
    if rows >= 2 then
        local r2 = windows[2]
        extra:SetPoint("BOTTOMLEFT", console, "TOP", r2[1][1], r2[1][4])
        extra:SetPoint("TOPRIGHT", console, "TOP", r2[#r2][2], r2[#r2][3])
        if rows >= 3 then
            local r3 = windows[3]
            row3 = CreateFrame("Frame", nil, extra)
            row3:SetPoint("BOTTOMLEFT", console, "TOP", r3[1][1], r3[1][4])
            row3:SetPoint("TOPRIGHT", console, "TOP", r3[#r3][2], r3[#r3][3])
        end
    else
        extra:SetPoint("BOTTOMLEFT", console, "TOP", frame[1], frame[3])
        extra:SetPoint("TOPRIGHT", console, "TOP", frame[2], frame[3] + 1)
    end
    if art.wingFile and art.wingBoxes and rows >= 2 then
        local wingStone = CreateFrame("Frame", nil, extra)
        wingStone:SetAllPoints()
        wingStone:SetFrameLevel(ns.levels.art + 1)
        for r = 2, rows do
            local wb = art.wingBoxes[r - 1]
            if wb then
                local wt = wingStone:CreateTexture(nil, "ARTWORK")
                wt:SetSize(art.wingWidth, art.wingHeight)
                wt:SetPoint("TOPLEFT", console, "TOP", wb[1], wb[3])
                wt:SetTexture(ns.media .. art.wingFile)
                wt:SetTexCoord(0, art.wingWidth / art.wingTexWidth, 0, art.wingHeight / art.wingTexHeight)
                table.insert(wingPlates, wt)
            end
        end
    end
    ns.extraBars = extra

    ns.pager = Pager(tray)
    if ns.BuildPower then ns.BuildPower(lowParent) end
    if ns.BuildCast then ns.BuildCast(lowParent) end
    if ns.BuildDrawer then ns.BuildDrawer(tray) end
    Tint(ns.db.artColor)
    ns.OnSetting("artColor", Tint)
    ns.barFade = MakeFade(tray, "visibility", function()
        return tray:IsMouseOver() or (ns.drawer and ns.drawer:IsShown() and ns.drawer:IsMouseOver())
    end)
    ns.extraBarFade = MakeFade(extra, "extraVisibility", function()
        if extra:IsMouseOver() or (row3 and row3:IsMouseOver()) then return true end
        for _, btn in ipairs(ns.extraButtons or {}) do
            if btn:IsMouseOver() then return true end
        end
        return false
    end)
    return tray, windows, extra
end
