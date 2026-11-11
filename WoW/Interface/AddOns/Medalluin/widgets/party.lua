-- The Party widget (Console > General > Party layout > Widget, on either profile):
-- the console's own party buttons, party1..4, taken into a box under a
-- "Party" tab. The console then draws no party: the medallion's solo art,
-- the light console's plate without the row. In a raid the box gives way to
-- the Raid widget. It has no pets: it is for competitive play, where they
-- are not wanted (ns.PartyPets hides them, on the console where they hang).
--
-- The buttons hang in four fixed rows (the holder is sized for them all, out
-- of combat); the skin ends under the last member shown, so a box of three
-- has no empty fourth row. It follows the buttons' showing and hiding, in
-- combat too.
local _, ns = ...

local W = ns.WIDGET
-- a cell is 160x40 until the editor sizes it (ns.CellSize, editor.lua)

local box = ns.WidgetBox("MedalluinPartyWidget", "partyWidgetPoint", { "LEFT", "LEFT", 40, 120 },
    "partyWidgetMoverHover")
ns.partyWidget = box

function ns.PartyWidgetLayout()
    return ns.db and ns.db.partyLayout == "widget" or false
end

local function Step()
    local _, unitH = ns.CellSize("partyWidget")
    return unitH + W.gap
end

local function Conditional()
    if not ns.PartyWidgetLayout() then return "hide" end
    if ns.db.simParty then return "[group:raid] hide; show" end
    -- shown while party1 is there, the test the members' own unit watch
    -- makes: [group:party] held on in combat after the player left a party
    -- of four, the box empty but for the player's cell (2026-11-11)
    return "[group:raid] hide; [@party1,exists] show; hide"
end

local function Show()
    ns.OutOfCombat(function() ns.WidgetVisibility(box, Conditional()) end)
end

-- The skin to the last member shown.
local function Skin()
    if not ns.units.party1.inWidget then return end
    local CELL_W, UNIT_H = ns.CellSize("partyWidget")
    local last
    for i = 1, 4 do
        if ns.units["party" .. i]:IsShown() then last = i end
    end
    -- no party: the box hides; the player's cell alone until it does
    if ns.db.partyWidgetPlayer then last = (last or 0) + 1 end
    if not last then return end
    ns.WidgetSkin(box, { "Party" }, CELL_W, (last - 1) * Step() + UNIT_H)
end

local function LayCell(b, row, CELL_W, UNIT_H, step)
    local x, y = ns.WidgetColumnX(1, CELL_W), ns.WidgetRowY(row, step)
    b:SetParent(box)
    b:SetFrameLevel(box:GetFrameLevel() + 2)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    b:SetSize(CELL_W, UNIT_H)
    b.power:ClearAllPoints()
    b.health:ClearAllPoints()
    b.power:SetHeight(5)
    b.power:SetPoint("BOTTOMLEFT")
    b.power:SetPoint("BOTTOMRIGHT")
    b.health:SetPoint("TOPLEFT")
    b.health:SetPoint("TOPRIGHT")
    b.health:SetHeight(UNIT_H - 5 - 1)
    b.health:SetReverseFill(false)
    b.power:SetReverseFill(false)
    b.roleFrame:ClearAllPoints()
    b.roleFrame:SetPoint("CENTER", b, "LEFT", 10, 2)
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b.health, "LEFT", 22, 0)
    b.name:SetPoint("RIGHT", b.health, "RIGHT", -6, 0)
    b.name:SetJustifyH("LEFT")
    -- the health value where a cell has it (box.lua)
    b.value:ClearAllPoints()
    b.value:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -4, 3)
    -- the level bottom left, under the name, clear of the role icon
    b.levelText:ClearAllPoints()
    b.levelText:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 22, 3)
    -- the crown on the top edge, over the role icon
    b.leaderFrame:ClearAllPoints()
    b.leaderFrame:SetPoint("CENTER", b, "TOPLEFT", 10, 0)

    -- a cell is a left copy, whichever way its console slot faced
    ns.LayBuffs(b, -1)
    b.inWidget = true
    -- what the editor changed goes back on (editor.lua)
    ns.editor.Relaid(b, "name", "level", "role", "leader", "value", "buffs")
    ns.ApplyEdits(b)
end

-- Called by ns.RelayoutUnits (units.lua) while the layout is the widget.
function ns.LayoutPartyWidget()
    local step = Step()
    local withPlayer = ns.db.partyWidgetPlayer and true or false
    local rows = withPlayer and 5 or 4
    local height = rows * step - W.gap
    local CELL_W, UNIT_H = ns.CellSize("partyWidget")
    ns.OutOfCombat(function()
        ns.WidgetHolder(box, ns.WidgetSize(1, CELL_W, height))
        local pb = ns.partyWidgetPlayer
        if pb then
            if withPlayer then
                LayCell(pb, 1, CELL_W, UNIT_H, step)
                pb:Show()
                ns.UpdateUnitButton(pb)
                if ns.UpdateUnitAuras then ns.UpdateUnitAuras(pb) end
            else
                pb:Hide()
                pb.inWidget = nil
            end
        end
        local offset = withPlayer and 1 or 0
        for i = 1, 4 do
            LayCell(ns.units["party" .. i], i + offset, CELL_W, UNIT_H, step)
        end
        Skin()
    end)
    Show()
end

-- Out of the widget: the box hidden and the buttons back on the console,
-- for ns.RelayoutUnits to place. True when they were in it.
function ns.ReleasePartyWidget()
    local b1 = ns.units.party1
    if not b1.inWidget then return false end
    ns.OutOfCombat(function()
        ns.WidgetVisibility(box, "hide")
        local pb = ns.partyWidgetPlayer
        if pb then
            pb:Hide()
            pb.inWidget = nil
        end
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            b:SetParent(ns.console)
            b:SetFrameLevel(ns.levels.bars)
            b.inWidget = nil
        end
    end)
    return true
end

local function Relayout()
    ns.OutOfCombat(function()
        ns.RelayoutUnits()
        if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
        if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
    end)
end

-- the light console's own handler relayouts it (party_row.lua)
ns.OnSetting("partyLayout", function()
    if not (ns.layout.party and ns.layout.party.row) then Relayout() end
end)
ns.OnSetting("partyWidgetPlayer", function()
    if ns.PartyWidgetLayout() then Relayout() end
end)
-- the editor's cell size: the box laid again only when that changed (its
-- pieces follow the editor at once, in combat too)
local laidSize
ns.OnSetting("editPartyWidget", function()
    local w, h = ns.CellSize("partyWidget")
    local size = w .. "x" .. h
    if size == laidSize then return end
    laidSize = size
    if ns.PartyWidgetLayout() then Relayout() end
end)
ns.OnWidgetUpdate(Show)
-- the skin follows the members as they show and hide
for i = 1, 4 do
    local b = ns.units["party" .. i]
    b:HookScript("OnShow", Skin)
    b:HookScript("OnHide", Skin)
end
-- the medallion lays its party out at load; the widget takes it at login
ns.On("PLAYER_LOGIN", function()
    if ns.PartyWidgetLayout() and not ns.units.party1.inWidget then Relayout() end
end)
