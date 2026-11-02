-- The light profile's party row (Console > General > Party layout: Console): one
-- band hanging under the console, cut into four fixed slots, one per member.
-- A member's pet hangs under its frame in the default console's stone
-- bracket (ns.LayoutPet), so a pet never moves its owner and the slots are
-- the frames' boxes, in combat too.
-- The geometry and the band's art come from art/console/gen_light_console.py.
local _, ns = ...

local console = ns.console

local band, backings

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

local function Build(row)
    band = CreateFrame("Frame", nil, console)
    band:SetFrameLevel(ns.levels.art)
    band:SetPoint("TOP", console, "TOP", 0, row.top)
    band:SetSize(row.width, row.height)
    local t = band:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(ns.media .. row.file)
    t:SetTexCoord(0, row.width / row.texWidth, 0, row.height / row.texHeight)

    -- ink under each slot
    backings = {}
    for i, f in ipairs(row.frames) do
        local bg = console:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(unpack(ns.colors.ink))
        Box(bg, f)
        backings[i] = bg
    end
    ns.partyRowBand, ns.partyRowBackings = band, backings
end

function ns.ShowPartyRow()
    if not band then return end
    local shown = ns.PartyRowShown()
    band:SetShown(shown)
    for _, bg in ipairs(backings) do bg:SetShown(shown) end
end

-- Called from ns.RelayoutUnits (units.lua): the row's places. With the
-- party in its widget, the widget places the buttons and their pets.
function ns.LayoutPartyRow()
    local row = Row()
    if not row then return end
    if not band then Build(row) end
    if ns.PartyRowLayout() then
        ns.OutOfCombat(function()
            for i = 1, 4 do
                local b, f = ns.units["party" .. i], row.frames[i]
                Box(b, f)
                -- the bracket welds to the band's foot, under the frame's
                ns.LayoutPet(b.pet, nil, nil, nil, f[4] - (row.top - row.height))
            end
        end)
    end
    ns.ShowPartyRow()
end

ns.OnSetting("simParty", function()
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
