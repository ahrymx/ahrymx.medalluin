-- The Party widget (Console > Unit Layout > Party layout > Widget, on either profile):
-- the console's own party buttons, party1..4, taken into a box under a
-- "Party" tab, with each member's pet in a strip under it. The console then
-- draws no party: the medallion's solo art, the light console's plate
-- without the row. In a raid the box gives way to the Raid widget.
local _, ns = ...

local W = ns.WIDGET
-- a cell is 160x40 until the editor sizes it (ns.CellSize, editor.lua)
local PET_H, PET_GAP = 16, 2

local box = ns.WidgetBox("MedalluinPartyWidget", "partyWidgetPoint", { "LEFT", "LEFT", 40, 120 })
ns.partyWidget = box

function ns.PartyWidgetLayout()
    return ns.db and ns.db.partyLayout == "widget" or false
end

local function Step()
    local _, unitH = ns.CellSize("partyWidget")
    return unitH + (ns.db.partyWidgetPets ~= false and PET_GAP + PET_H or 0) + W.gap
end

local function Conditional()
    if not ns.PartyWidgetLayout() then return "hide" end
    if ns.db.simParty then return "[group:raid] hide; show" end
    return "[group:raid] hide; [group:party] show; hide"
end

local function Show()
    ns.OutOfCombat(function() ns.WidgetVisibility(box, Conditional()) end)
end

-- Called by ns.RelayoutUnits (units.lua) while the layout is the widget.
function ns.LayoutPartyWidget()
    local step = Step()
    local height = 4 * step - W.gap
    local CELL_W, UNIT_H = ns.CellSize("partyWidget")
    ns.OutOfCombat(function()
        ns.WidgetHolder(box, ns.WidgetSize(1, CELL_W, height))
        ns.WidgetSkin(box, { "Party" }, CELL_W, height)
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local x, y = ns.WidgetColumnX(1, CELL_W), ns.WidgetRowY(i, step)
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

            -- the pet's strip: its name left, its value right
            local pet = b.pet
            pet:SetParent(box)
            pet:SetFrameLevel(box:GetFrameLevel() + 2)
            local top = y - UNIT_H - PET_GAP
            ns.LayoutPet(pet, { x, x + CELL_W, top, top - PET_H }, box, "TOPLEFT")
            pet.health:SetReverseFill(false)
            pet.name:ClearAllPoints()
            pet.name:SetPoint("LEFT", pet.text, "LEFT", 4, 0)
            pet.name:SetPoint("RIGHT", pet.value, "LEFT", -4, 0)
            pet.name:SetJustifyH("LEFT")
            pet.value:ClearAllPoints()
            pet.value:SetPoint("RIGHT", pet.text, "RIGHT", -4, 0)
            b.inWidget = true
            -- what the editor changed goes back on (editor.lua)
            ns.editor.Relaid(b, "name", "role", "value")
            ns.ApplyEdits(b)
        end
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
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            b:SetParent(ns.console)
            b.pet:SetParent(ns.console)
            b:SetFrameLevel(ns.levels.bars)
            b.pet:SetFrameLevel(ns.levels.bars)
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
ns.OnSetting("partyWidgetPets", function()
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
-- the medallion lays its party out at load; the widget takes it at login
ns.On("PLAYER_LOGIN", function()
    if ns.PartyWidgetLayout() and not ns.units.party1.inWidget then Relayout() end
end)
