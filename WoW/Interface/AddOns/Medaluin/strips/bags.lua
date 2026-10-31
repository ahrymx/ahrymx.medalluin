-- The backpack, in the right strip's medallion, and the bag drawer: the
-- arrow beside the medallion slides out a small plate above the strip with
-- the four bag slots (and the key ring and reagent bag, where the client has
-- them). All of them are Blizzard's buttons, so dropping an item or a bag on
-- them works.
--
-- On Forever and retail they belong to BagsBar, which places them again (when
-- an item is picked up, for one) and re-sets its atlases on whatever their
-- state textures are; both are answered after the fact, below.
local _, ns = ...

local L = ns.stripLayout
local SLOT, GAP, PAD = 30, 2, 4
local GOLD_D = { 0.541, 0.439, 0.204 }

local function Hide(region)
    if region then region:SetAlpha(0) end
end

local function Icon(btn)
    return btn.icon or _G[btn:GetName() .. "IconTexture"]
end

-- A button's state textures as we drew them, put back after Blizzard has
-- been at them.
local function Restyle(btn)
    local m = btn.medaluin
    local normal = btn:GetNormalTexture()
    Hide(normal)
    ns.Mute(normal)
    btn:SetPushedTexture(m.pushed)
    btn:SetHighlightTexture(m.highlight)
    if btn.SetCheckedTexture then btn:SetCheckedTexture(m.checked) end
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

-- The backpack: round, its icon masked to the well.
local function PlaceBackpack()
    local w = ns.stripWell
    ns.OnStrip(MainMenuBarBackpackButton, 1, w.x, w.y, w.size, w.size)
end

local function Backpack()
    local btn = MainMenuBarBackpackButton
    btn:SetParent(ns.strips[1])
    btn:SetFrameLevel(ns.levels.stripWell)
    PlaceBackpack()
    local icon = Icon(btn)
    icon:ClearAllPoints()
    icon:SetAllPoints()
    if btn.CircleMask then icon:RemoveMaskTexture(btn.CircleMask) end
    if btn.CreateMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture(ns.media .. "strips\\round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    Hide(btn.SlotHighlightTexture)           -- the round glow says the bag is open
    btn.medaluin = {
        pushed = ns.Blank(btn),
        highlight = ns.RoundGlow(btn, 1, 0.9, 0.6, 0.18),
        checked = ns.RoundGlow(btn, 0.77, 0.65, 0.34, 0.3),
        restore = function(m)
            m.pushed:SetColorTexture(0, 0, 0, 0)
            for t, a in pairs({ [m.highlight] = 0.18, [m.checked] = 0.3 }) do
                t:ClearAllPoints()
                t:SetAllPoints()
                t:SetTexture(ns.media .. "strips\\round")
                t:SetBlendMode("ADD")
                t:SetAlpha(a)
            end
        end,
    }
    Watch(btn)
end

-- A bag slot, styled like the action buttons: square, 1px black edge.
local OVER = { pushed = { 0, 0, 0, 0.35 }, highlight = { 1, 1, 1, 0.15 }, checked = { 0.77, 0.65, 0.34, 0.35 } }

local function Slot(btn, parent)
    btn:SetParent(parent)
    btn:SetFrameLevel(parent:GetFrameLevel() + 1)
    local icon = Icon(btn)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if btn.SquareMask then icon:RemoveMaskTexture(btn.SquareMask) end
    local edge = btn:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0)
    edge:SetAllPoints()
    btn.medaluin = {
        pushed = btn:CreateTexture(), highlight = btn:CreateTexture(), checked = btn:CreateTexture(),
        restore = function(m)
            for key, c in pairs(OVER) do
                local t = m[key]
                t:ClearAllPoints()
                t:SetAllPoints(icon)
                t:SetColorTexture(unpack(c))
                t:SetBlendMode("BLEND")
                t:SetAlpha(1)
            end
            -- marks the bag whose window is open
            local open = btn.SlotHighlightTexture
            if open then
                open:ClearAllPoints()
                open:SetAllPoints(icon)
                open:SetColorTexture(unpack(OVER.checked))
            end
        end,
    }
    Watch(btn)
    -- the drawer is the expand control now: Blizzard's collapse would hide them
    if btn.SetBarExpanded then hooksecurefunc(btn, "SetBarExpanded", btn.Show) end
    btn:Show()
end

-- Left to right, as Blizzard orders them: the key ring (in its own tall
-- art), the reagent bag, bags 3 to 0; the backpack follows, in the medallion.
local slots = {}

local function PlaceSlots()
    local d, x = ns.bagDrawer, PAD
    for _, b in ipairs(slots) do
        local w = b == KeyRingButton and SLOT / 2 or SLOT
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", d, "TOPLEFT", x, -PAD)
        b:SetSize(w, SLOT)
        x = x + w + GAP
    end
    d:SetSize(x - GAP + PAD, SLOT + 2 * PAD)
end

-- The drawer: a navy plate with a gold edge, resting on the strip beside
-- the medallion. Closed at login.
local function Drawer()
    local strip = ns.strips[1]
    local d = CreateFrame("Frame", "MedaluinBagDrawer", strip)
    d:SetFrameLevel(ns.levels.stripTop)
    ns.bagDrawer = d
    if KeyRingButton then
        local ring = KeyRingButton
        ring:SetParent(d)
        ring:SetFrameLevel(d:GetFrameLevel() + 1)
        -- Forever sizes the ring's art for its own 33x45 button; fit it to ours
        local function Fit()
            for _, t in ipairs({ ring:GetNormalTexture(), ring:GetPushedTexture(), ring:GetHighlightTexture() }) do
                if t then
                    t:ClearAllPoints()
                    t:SetAllPoints(ring)
                end
            end
        end
        Fit()
        if ring.UpdateTextures then hooksecurefunc(ring, "UpdateTextures", Fit) end
        table.insert(slots, ring)
    end
    for _, name in ipairs({ "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot",
        "CharacterBag1Slot", "CharacterBag0Slot" }) do
        local b = _G[name]
        if b then
            Slot(b, d)
            table.insert(slots, b)
        end
    end
    PlaceSlots()
    -- its right edge stops just short of the medallion, its foot rests on the strip
    d:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -(L.arrowX - 4), L.stripHeight - 1)

    local fill = d:CreateTexture(nil, "BACKGROUND", nil, 0)
    fill:SetColorTexture(0.188, 0.208, 0.267)       -- the navy gradient's middle
    fill:SetAllPoints()
    -- a 1px gold edge: { first corner, second corner, horizontal }
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = d:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(GOLD_D))
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    d:Hide()

    local arrow = CreateFrame("Button", nil, strip)
    arrow:SetFrameLevel(ns.levels.stripTop)
    ns.OnStrip(arrow, 1, L.arrowX, ns.stripArt.height - L.arrowY, 16, 16)
    local tex = arrow:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ns.media .. "strips\\arrow")
    tex:SetAllPoints()
    local glow = arrow:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(ns.media .. "strips\\arrow")
    glow:SetAllPoints()
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.5)
    local function Point()
        -- points left (out) while closed, right (back) while open
        local u0, u1 = 0, 1
        if d:IsShown() then u0, u1 = 1, 0 end
        tex:SetTexCoord(u0, u1, 0, 1)
        glow:SetTexCoord(u0, u1, 0, 1)
    end
    arrow:SetScript("OnClick", function()
        d:SetShown(not d:IsShown())
        Point()
    end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(BAGSLOTTEXT or "Bags")
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    Point()
end

ns.On("PLAYER_LOGIN", function()
    Backpack()
    Drawer()
    -- Blizzard's bag bar places its buttons again (an item picked up, an
    -- Edit Mode change); put them back where the strip has them.
    for _, bar in ipairs({ BagsBar, MicroButtonAndBagsBar }) do
        if bar and bar.Layout then
            hooksecurefunc(bar, "Layout", function()
                PlaceBackpack()
                PlaceSlots()
            end)
        end
    end
end)
