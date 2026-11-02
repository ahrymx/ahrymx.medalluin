-- The light profile's party row (Console > Unit Layout > Party layout: Console): one
-- band hanging under the console, cut into four fixed slots, one per member.
-- A member with a pet gives up part of its slot to the pet, on the slot's
-- centre-ward side, so the slots never move and only that frame narrows.
-- The geometry and the band's art come from art/console/gen_light_console.py.
--
-- A pet comes and goes in combat, and a secure button cannot be moved from
-- Lua then. So a member's width is a state the game's own conditional drives
-- ([@partypetN,exists]), and the header's snippet moves the button from the
-- secure update, in combat too (ns.DriveState, core.lua).
local _, ns = ...

local console = ns.console
local SEAM = { 0.541, 0.439, 0.204 }    -- the art's dark gold, between a frame and its pet

local header, band, backings

local function Box(region, box)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", console, "TOP", box[1], box[3])
    region:SetPoint("BOTTOMRIGHT", console, "TOP", box[2], box[4])
end

local function Row()
    local party = ns.layout and ns.layout.party
    return party and party.row
end

-- The option: the row's places, whether or not there is a group to show.
function ns.PartyRowLayout()
    return Row() and ns.db and ns.db.partyLayout ~= "widget" and true or false
end

-- The row is up: its layout, and a group (or the preview) in it. The minimap
-- then keeps to the corner and the centre grid stays out (minimap.lua).
function ns.PartyRowShown()
    return ns.PartyRowLayout() and (IsInGroup() or ns.db.simParty) and true or false
end

-- The snippet for member i: the frame alone in its slot, or beside its pet.
local SNIPPET = [=[
    if self:GetAttribute("%s") then return end
    local b = self:GetFrameRef("party%d")
    b:ClearAllPoints()
    if newstate == "pet" then
        b:SetPoint("TOPLEFT", self, "TOP", %d, %d)
        b:SetPoint("BOTTOMRIGHT", self, "TOP", %d, %d)
    else
        b:SetPoint("TOPLEFT", self, "TOP", %d, %d)
        b:SetPoint("BOTTOMRIGHT", self, "TOP", %d, %d)
    end
]=]

local function Build(row)
    band = CreateFrame("Frame", nil, console)
    band:SetFrameLevel(ns.levels.art)
    band:SetPoint("TOP", console, "TOP", 0, row.top)
    band:SetSize(row.width, row.height)
    local t = band:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(ns.media .. row.file)
    t:SetTexCoord(0, row.width / row.texWidth, 0, row.height / row.texHeight)

    -- ink under a whole slot, frame and pet: the margin between them is empty
    backings = {}
    for i, f in ipairs(row.frames) do
        local p = row.pets[i]
        local bg = console:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(unpack(ns.colors.ink))
        Box(bg, { math.min(f[1], p[1]), math.max(f[2], p[2]), f[3], f[4] })
        backings[i] = bg
    end
    ns.partyRowBand, ns.partyRowBackings = band, backings

    header = CreateFrame("Frame", "MedalluinPartyRow", console, "SecureHandlerStateTemplate")
    header:SetAllPoints(console)
    for i = 1, 4 do
        local alone, beside = row.frames[i], row.framesPet[i]
        header:SetFrameRef("party" .. i, ns.units["party" .. i])
        header:SetAttribute("_onstate-pet" .. i, SNIPPET:format(ns.HOLD, i,
            beside[1], beside[3], beside[2], beside[4], alone[1], alone[3], alone[2], alone[4]))

        -- the seam goes with the pet: a texture of its frame
        local pet = ns.units["party" .. i].pet
        local seam = pet:CreateTexture(nil, "ARTWORK")
        seam:SetColorTexture(SEAM[1], SEAM[2], SEAM[3])
        seam:SetPoint("TOPLEFT", console, "TOP", row.seams[i], alone[3])
        seam:SetPoint("BOTTOMRIGHT", console, "TOP", row.seams[i] + 1, alone[4])
        pet.rowSeam = seam
    end
end

-- Member i's pet: none while pets are off, always one while the preview
-- shows a simulated pet, else whatever the game says.
local function Conditional(i)
    if ns.db.partyPets == false then return nil end
    if ns.db.simParty and ns.partyPetStubs and ns.partyPetStubs["partypet" .. i] then return "pet" end
    return ("[@partypet%d,exists] pet; none"):format(i)
end

local function Drive()
    if not (header and ns.PartyRowLayout()) then return end
    ns.OutOfCombat(function()
        for i = 1, 4 do ns.DriveState(header, "pet" .. i, Conditional(i)) end
    end)
end

function ns.ShowPartyRow()
    if not band then return end
    local shown = ns.PartyRowShown()
    band:SetShown(shown)
    for _, bg in ipairs(backings) do bg:SetShown(shown) end
end

-- Called from ns.RelayoutUnits (units.lua): the row's places, or, with the
-- party in its widget, the pets let go of the row's boxes.
function ns.LayoutPartyRow()
    local row = Row()
    if not row then return end
    if not header then Build(row) end
    local on = ns.PartyRowLayout()
    ns.OutOfCombat(function()
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            if on then
                -- alone; the snippet narrows it when the pet is there
                Box(b, row.frames[i])
                ns.LayoutPet(b.pet, row.pets[i])
            else
                UnregisterStateDriver(header, "pet" .. i)
                ns.LayoutPet(b.pet)
            end
            b.pet.rowSeam:SetShown(on)
        end
    end)
    Drive()
    ns.ShowPartyRow()
end

ns.OnSetting("partyPets", Drive)
ns.OnSetting("simParty", function()
    Drive()
    if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
end)
ns.OnSetting("partyLayout", function()
    if not Row() then return end
    ns.OutOfCombat(function()
        ns.RelayoutUnits()
        if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
        if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
    end)
end)
ns.On("GROUP_ROSTER_UPDATE", function()
    ns.ShowPartyRow()
    if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
end)
