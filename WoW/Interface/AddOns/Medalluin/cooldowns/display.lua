-- The Cooldown Manager's display: the game's own viewers (Blizzard_CooldownViewer),
-- their spells drawn as Medalluin's medallions and standing in rows over the
-- console.
--
--                 (b) (b) (b)                  BuffIconCooldownViewer: the tracked buffs
--          (E)  (E)  (E)  (E)   (u) (u) (u)    Essential, the biggest; Utility at its right
--        +-----------------------------+
--        |         the console         |
--
-- The viewers still track everything themselves (cooldowns, charges, auras,
-- totems, alerts, their secret values in combat): only their look and their
-- place are ours. Each spell's icon is masked round in a gold rim, its
-- cooldown swept round, its counts in our font; their square overlay and
-- the out-of-range shadow are put away (out of range, a red tint over the
-- round icon). The tracked bars stay in the Auras tab (strips/auras.lua).
--
-- They are placed out of combat only; Edit Mode moving one is undone once
-- combat allows, as the Auras tab keeps its bars. In combat nothing here
-- moves, shows or hides a frame: a new spell's icon is only dressed.
local _, ns = ...

local GOLD_D = { 0.541, 0.439, 0.204 }
local ROUND = ns.media .. "strips\\round"
local GAP = 14                  -- between the console and the rows, and between rows
-- each viewer: the size its spells are drawn at
local SIZES = { essential = 44, utility = 32, buffs = 30 }

local display = {}
ns.cooldownDisplay = display

local deco = {}                 -- our dress, by the game's frame
local viewers = {}              -- ours, by key: the game's viewer frames
local placing = false

local function Viewer(key)
    return key == "essential" and _G.EssentialCooldownViewer or key == "utility" and _G.UtilityCooldownViewer
        or key == "buffs" and _G.BuffIconCooldownViewer or nil
end

local function Items(v)
    if v.GetItemFrames then
        local ok, frames = pcall(v.GetItemFrames, v)
        if ok and type(frames) == "table" then return frames end
    end
    local out = {}
    if v.itemFramePool and v.itemFramePool.EnumerateActive then
        for item in v.itemFramePool:EnumerateActive() do table.insert(out, item) end
    end
    return out
end

-- ---------------------------------------------------------------- the dress
local function Font(fs, size)
    if not fs or not fs.SetFont then return end
    fs:SetFont(ns.font, size, "OUTLINE")
end

-- A spell's frame as a medallion: its masks swapped for a round one, its
-- overlay hidden, a gold rim under it, a round sweep
local function Dress(item)
    local icon = item and item.Icon
    if not icon or deco[item] then return end
    local d = {}
    deco[item] = d
    if icon.GetNumMaskTextures and icon.RemoveMaskTexture then
        for i = (icon:GetNumMaskTextures() or 0), 1, -1 do
            local m = icon:GetMaskTexture(i)
            if m then icon:RemoveMaskTexture(m) end
        end
    end
    -- the icon's own square border cut off, so the round mask shows its face
    -- (with the game's masks off: tex coords are refused on a masked texture)
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if item.CreateMaskTexture and icon.AddMaskTexture then
        d.mask = item:CreateMaskTexture()
        d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
        icon:AddMaskTexture(d.mask)
    end
    -- the square overlay (its frame art): put away; the icon and the shadow kept
    for _, r in ipairs({ item:GetRegions() }) do
        if r ~= icon and r ~= item.OutOfRange and r.GetObjectType and r:GetObjectType() == "Texture" then
            r:SetAlpha(0)
        end
    end
    d.rim = item:CreateTexture(nil, "BACKGROUND", nil, -6)
    d.rim:SetTexture(ROUND)
    d.rim:SetAllPoints(icon)
    d.rim:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    -- out of range: a red tint over the round icon, not the square shadow
    local oor = item.OutOfRange
    if oor then
        oor:SetTexture(ROUND)
        oor:ClearAllPoints()
        oor:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        oor:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
        oor:SetVertexColor(0.8, 0.1, 0.08, 0.45)
    end
    local cd = item.Cooldown
    if cd then
        if cd.SetSwipeTexture then cd:SetSwipeTexture(ROUND) end
        if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.7) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
        for _, r in ipairs({ cd:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then Font(r, 14) end
        end
    end
    if item.ChargeCount then Font(item.ChargeCount.Current, 13) end
    if item.Applications then Font(item.Applications.Applications, 13) end
    -- the GCD's square flash: put away
    if item.CooldownFlash then item.CooldownFlash:SetAlpha(0) end
end
display.Dress = Dress

local function DressAll(v)
    for _, item in ipairs(Items(v)) do Dress(item) end
end

-- ---------------------------------------------------------------- the place
-- A viewer's scale, for its spells to stand at our size (Edit Mode's own
-- icon size inside it kept as the base)
local function Fit(v, key)
    local items = Items(v)
    local item = items[1]
    if not item then return end
    local w = (item:GetWidth() or 0) * (item:GetScale() or 1)
    if w and w > 0 then v:SetScale(SIZES[key] / w) end
end

-- Over the console: Essential at its top's middle, the buffs over it,
-- Utility at its right
local function Place()
    if placing then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.OutOfCombat(Place)
        return
    end
    placing = true
    local console = ns.console
    local e, u, b = viewers.essential, viewers.utility, viewers.buffs
    pcall(function()
        if e then
            Fit(e, "essential")
            e:ClearAllPoints()
            e:SetPoint("BOTTOM", console, "TOP", 0, GAP / e:GetScale())
        end
        if u then
            Fit(u, "utility")
            u:ClearAllPoints()
            if e then
                u:SetPoint("LEFT", e, "RIGHT", GAP / u:GetScale(), 0)
            else
                u:SetPoint("BOTTOM", console, "TOP", 0, GAP / u:GetScale())
            end
        end
        if b then
            Fit(b, "buffs")
            b:ClearAllPoints()
            if e then
                b:SetPoint("BOTTOM", e, "TOP", 0, GAP / b:GetScale())
            else
                b:SetPoint("BOTTOM", console, "TOP", 0, (GAP + SIZES.essential + GAP) / b:GetScale())
            end
        end
    end)
    placing = false
end
display.Place = Place

-- ------------------------------------------------------------- the takeover
local function Adopt(key)
    local v = Viewer(key)
    if not v or viewers[key] then return end
    viewers[key] = v
    DressAll(v)
    if v.OnAcquireItemFrame then
        hooksecurefunc(v, "OnAcquireItemFrame", function(_, item) Dress(item) end)
    end
    if v.RefreshLayout then
        hooksecurefunc(v, "RefreshLayout", function()
            DressAll(v)
            ns.OutOfCombat(Place)
        end)
    end
    -- Edit Mode (or the game) moving it: back over the console once combat allows
    hooksecurefunc(v, "SetPoint", function()
        if not placing then ns.OutOfCombat(Place) end
    end)
end

local function AdoptAll()
    for _, key in ipairs({ "essential", "utility", "buffs" }) do Adopt(key) end
    if next(viewers) then ns.OutOfCombat(Place) end
end
display.Adopt = AdoptAll
display.viewers = viewers

local function Start()
    if not (ns.db.cdmWindow and ns.db.cdmDisplay) then return end
    AdoptAll()
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_CooldownViewer" then AdoptAll() end
    end)
end

ns.On("PLAYER_LOGIN", Start)
