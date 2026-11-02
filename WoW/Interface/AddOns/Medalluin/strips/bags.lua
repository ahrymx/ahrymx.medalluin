-- The backpack, in the right strip's medallion: Blizzard's own button, so
-- dropping an item on it works. The bag slots have no place on the strips:
-- the drawer that held them was removed (2026-11-01) because the user is
-- moving bags into a new inventory UI. They stay on BagsBar, which
-- blizzard.lua kills.
--
-- On Forever and retail the backpack belongs to BagsBar, which places it
-- again (when an item is picked up, for one) and re-sets its atlases on
-- whatever its state textures are; both are answered after the fact,
-- below. BagsBar's layout runs from references it took at load, so a hook
-- on it misses most of its calls: what is watched is the button's own
-- SetPoint.
--
-- There it is a plain button (ItemButton), with no checked state: its open
-- mark is its SlotHighlightTexture, which Blizzard shows and hides, so that
-- is what wears ours. And it has no icon there, its whole picture being its
-- normal texture's atlas: it is given the backpack's item icon, by name.
local _, ns = ...

local BACKPACK = "Interface\\Icons\\INV_Misc_Bag_08"

local function Hide(region)
    if region then region:SetAlpha(0) end
end

local function Icon(btn)
    return btn.icon or _G[btn:GetName() .. "IconTexture"]
end

-- A button's state textures as we drew them, put back after Blizzard has
-- been at them.
local function Restyle(btn)
    local m = btn.medalluin
    local normal = btn:GetNormalTexture()
    Hide(normal)
    ns.Mute(normal)
    btn:SetPushedTexture(m.pushed)
    btn:SetHighlightTexture(m.highlight)
    if m.checked then btn:SetCheckedTexture(m.checked) end
    m.restore(m)
end

local function Watch(btn)
    Restyle(btn)
    for _, method in ipairs({ "SetNormalTexture", "SetNormalAtlas", "UpdateTextures" }) do
        if btn[method] then hooksecurefunc(btn, method, Restyle) end
    end
    Hide(_G[btn:GetName() .. "Count"])       -- the stats say how full the bags are
    Hide(btn.FreeSlots)
    ns.Mute(btn.IconBorder)
end

-- The bags window's drawer (inventory/bags.lua) styles the bag slots the same way.
ns.BagIcon, ns.WatchBagButton = Icon, Watch

-- Placed by us, and put back after anyone else.
local placing = false
local function Hold(btn, Place)
    hooksecurefunc(btn, "SetPoint", function()
        if not placing then Place() end
    end)
end

-- The backpack: round, its icon masked to the well.
local function PlaceBackpack()
    local w = ns.stripWell
    placing = true
    ns.OnStrip(MainMenuBarBackpackButton, 1, w.x, w.y, w.size, w.size)
    placing = false
end

local function Backpack()
    local btn = MainMenuBarBackpackButton
    btn:SetParent(ns.strips[1])
    btn:SetFrameLevel(ns.levels.stripWell)
    PlaceBackpack()
    local icon = Icon(btn)
    icon:ClearAllPoints()
    icon:SetAllPoints()
    if not icon:GetTexture() then
        icon:SetTexture(BACKPACK)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if btn.CircleMask then icon:RemoveMaskTexture(btn.CircleMask) end
    if btn.CreateMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture(ns.media .. "strips\\round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    -- a round gold glow says the bag is open: the checked state, or
    -- Blizzard's open mark where there is none
    local open = btn.SetCheckedTexture and ns.RoundGlow(btn, 0.77, 0.65, 0.34, 0.3)
    btn.medalluin = {
        pushed = ns.Blank(btn),
        highlight = ns.RoundGlow(btn, 1, 0.9, 0.6, 0.18),
        checked = open or nil,
        restore = function(m)
            m.pushed:SetColorTexture(0, 0, 0, 0)
            local glows = { [m.highlight] = 0.18 }
            if m.checked then
                glows[m.checked] = 0.3
                Hide(btn.SlotHighlightTexture)
            elseif btn.SlotHighlightTexture then
                glows[btn.SlotHighlightTexture] = 0.3
                btn.SlotHighlightTexture:SetVertexColor(0.77, 0.65, 0.34)
            end
            for t, a in pairs(glows) do
                t:ClearAllPoints()
                t:SetAllPoints()
                t:SetTexture(ns.media .. "strips\\round")
                t:SetBlendMode("ADD")
                t:SetAlpha(a)
            end
        end,
    }
    Watch(btn)
    Hold(btn, PlaceBackpack)
end

ns.On("PLAYER_LOGIN", Backpack)
