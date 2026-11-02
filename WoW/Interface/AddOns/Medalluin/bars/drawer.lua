-- The minimap button drawer, on the action bar's left end (the mirror of
-- the page chevrons): a toggle in the end's box, and, open, one line of the
-- addons' minimap buttons, left beside the plate or up from the frame's
-- top, as the Drawer option says (settings.lua). The console's minimap is
-- too small and too boxed in for buttons to orbit it, so they live here.
--
-- A button is any named Button on the minimap that is not Blizzard's own
-- furniture (mail, tracking and the rest stay on the minimap) and not a map
-- pin, plus every LibDBIcon button. Each is reparented into the drawer and
-- fitted to a cell; when its addon moves it (LibDBIcon re-places a button
-- whenever its settings change), it is put back. Addons that load late, or
-- make their buttons late, are picked up on the next scan: a few seconds
-- after login, after every addon load, when LibDBIcon announces a new icon,
-- and whenever the drawer is opened.
--
-- The toggle is a round button wearing the user's toolkit icon, recoloured
-- to the console's navy and gold, under the plate's round window, which is
-- smaller than the button so the stone covers its gold rim; while
-- the drawer is open its highlight stays lit. It and the drawer's line are
-- drawn by art/bars/gen_bar.py; the buttons keep their own art.
local _, ns = ...

local console = ns.console
local PARTS = ns.media .. "bar\\"
local NAMES = { [1] = "left", [2] = "up" }      -- ns.DRAWER, by value

-- Blizzard's own minimap furniture, by name: it stays on the minimap.
local BLIZZARD = { "^Minimap", "^MiniMap", "^GameTime", "^TimeManager", "^QueueStatus",
    "^GarrisonLandingPage", "^ExpansionLandingPage", "^AddonCompartment", "^HybridMinimap" }

local function Wanted(f)
    local name = f.GetName and f:GetName()
    if type(name) ~= "string" then return false end      -- unnamed: a map pin, or a part
    if name:match("^LibDBIcon10_") then return true end
    if not (f.IsObjectType and f:IsObjectType("Button")) then return false end
    if name:match("Pin") then return false end            -- HandyNotes, GatherMate and the like
    for _, p in ipairs(BLIZZARD) do
        if name:match(p) then return false end
    end
    return true
end

function ns.BuildDrawer(tray)
    local box, c = ns.barDrawer, ns.barDrawerCell
    local level = ns.levels.barPager
    local open, placing = false, false
    local buttons, taken = {}, {}

    -- the toggle, round, centred in the left end's box
    local toggle = CreateFrame("Button", "MedalluinDrawerButton", tray)
    toggle:SetFrameLevel(ns.levels.barToggle)   -- under the plate, which covers its rim
    toggle:SetSize(ns.barDrawerToggle, ns.barDrawerToggle)
    toggle:SetPoint("CENTER", console, "TOP", (box[1] + box[2]) / 2, (box[3] + box[4]) / 2)
    toggle:SetNormalTexture(PARTS .. "toolkit")
    toggle:SetPushedTexture(PARTS .. "toolkit-pushed")
    toggle:SetHighlightTexture(PARTS .. "chevron-highlight", "ADD")
    ns.drawerToggle = toggle

    -- the open line: a well with a gold rim, like the boxes on the plate
    local panel = CreateFrame("Frame", "MedalluinDrawer", tray)
    panel:SetFrameLevel(level)
    panel:Hide()
    for i, colour in ipairs({ { 0.54, 0.42, 0.14, 1 }, { 0.08, 0.08, 0.08, 1 }, ns.colors.ink }) do
        local t = panel:CreateTexture(nil, "BACKGROUND", nil, i)
        t:SetPoint("TOPLEFT", i - 1, 1 - i)
        t:SetPoint("BOTTOMRIGHT", 1 - i, i - 1)
        t:SetColorTexture(unpack(colour))
    end
    ns.drawer = panel

    local function Direction() return NAMES[ns.db.drawer] or "left" end

    -- A button fitted to its cell; i counts out from the toggle. Offsets
    -- are in the button's own scale.
    local function Place(b, i, dir)
        placing = true
        local size = math.max(b:GetWidth() or 0, b:GetHeight() or 0)
        local k = size > 0 and c.button / size or 1
        b:SetScale(k)
        b:ClearAllPoints()
        local along = c.pad + (i - 0.5) * c.cell
        if dir == "left" then
            b:SetPoint("CENTER", panel, "RIGHT", -along / k, 0)
        else
            b:SetPoint("CENTER", panel, "BOTTOM", 0, along / k)
        end
        placing = false
    end

    local function Layout()
        local dir = Direction()
        if open then toggle:LockHighlight() else toggle:UnlockHighlight() end
        local shown = {}
        for _, b in ipairs(buttons) do
            if b:IsShown() then table.insert(shown, b) end
        end
        local n = #shown
        panel:SetShown(open and n > 0)
        if n == 0 then return end
        local long, short = n * c.cell + 2 * c.pad, c.cell + 2 * c.pad
        panel:ClearAllPoints()
        if dir == "left" then
            panel:SetSize(long, short)
            panel:SetPoint("RIGHT", console, "TOP", c.left, (box[3] + box[4]) / 2)
        else
            panel:SetSize(short, long)
            panel:SetPoint("BOTTOM", console, "TOP", (box[1] + box[2]) / 2, c.up)
        end
        for i, b in ipairs(shown) do Place(b, i, dir) end
    end
    ns.drawerLayout = Layout

    local function Take(b)
        -- a secure button cannot change hands in combat; the next scan has it
        if InCombatLockdown() and b.IsProtected and b:IsProtected() then return end
        taken[b] = true
        table.insert(buttons, b)
        b:SetParent(panel)
        b:SetFrameLevel(level + 2)
        -- dragging moves a button round the minimap; there is none here
        if b.RegisterForDrag then b:RegisterForDrag() end
        hooksecurefunc(b, "SetPoint", function()
            if not placing then Layout() end
        end)
        b:HookScript("OnShow", Layout)
        b:HookScript("OnHide", Layout)
    end

    local function Scan()
        local found = false
        for _, f in ipairs({ Minimap:GetChildren() }) do
            if not taken[f] and Wanted(f) then
                Take(f)
                found = true
            end
        end
        if found then
            table.sort(buttons, function(a, b) return a:GetName() < b:GetName() end)
        end
        Layout()
    end
    ns.drawerScan = Scan

    toggle:SetScript("OnClick", function()
        open = not open
        if open then Scan() else Layout() end
    end)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Minimap buttons")
        local n = 0
        for _, b in ipairs(buttons) do
            if b:IsShown() then n = n + 1 end
        end
        GameTooltip:AddLine(n > 0 and (n .. (n == 1 and " button" or " buttons")) or "None yet", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", GameTooltip_Hide)

    ns.OnSetting("drawer", Layout)
    ns.On("ADDON_LOADED", function()
        if C_Timer then C_Timer.After(0, Scan) end
    end)
    if C_Timer then C_Timer.After(3, Scan) end
    local icons = LibStub and LibStub("LibDBIcon-1.0", true)
    if icons and icons.RegisterCallback then
        pcall(icons.RegisterCallback, panel, "LibDBIcon_IconCreated", Scan)
    end
    Scan()
end
