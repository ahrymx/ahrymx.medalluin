-- The player's timeless buffs (a mount, a form, an aura: anything without
-- an expiry), in a column above the portrait's medallion. Buffs that run
-- out stay in Blizzard's buff frame until the user decides where they go.
--
-- Which buffs are timeless can be secret in combat (Forever and retail:
-- DoesAuraHaveExpirationTime is restricted with the rest of the aura API),
-- so a buff is sorted when it arrives if the client allows, and otherwise
-- at the end of combat, when the whole list is read again. Each is kept by
-- its aura instance, which is never secret for the player's own auras.
--
-- The icons are plain buttons, not secure ones: a right click cancels the
-- buff out of combat, and does nothing in it.
local _, ns = ...

local Auras = C_UnitAuras
local L = ns.stripLayout
local ICON, GAP = 26, 4

local known = {}        -- auraInstanceID -> { icon, count } if timeless, false if timed
local unsorted = false  -- a buff could not be sorted in combat: read them all after it
local buttons = {}

-- true for a timeless buff, false for a timed one, nil if the client will not say
local function Timeless(aura)
    local timed
    if Auras.DoesAuraHaveExpirationTime then
        timed = Auras.DoesAuraHaveExpirationTime("player", aura.auraInstanceID)
    else
        timed = aura.expirationTime
        if not ns.IsSecret(timed) then timed = timed ~= nil and timed > 0 end
    end
    if ns.IsSecret(timed) or timed == nil then return nil end
    return not timed
end

local function Count(aura)
    local n = aura.applications
    if ns.IsSecret(n) or not n or n < 2 then return "" end
    return n
end

local function Add(aura)
    local id = aura.auraInstanceID
    if ns.IsSecret(id) then
        unsorted = true
        return
    end
    local timeless = Timeless(aura)
    if timeless == nil then
        unsorted = true
    elseif timeless then
        known[id] = { icon = aura.icon, count = Count(aura) }
    else
        known[id] = false
    end
end

local function Button(i)
    if buttons[i] then return buttons[i] end
    local btn = CreateFrame("Button", nil, ns.strips[-1])
    btn:SetFrameLevel(ns.levels.stripTop)
    btn:SetSize(ICON, ICON)
    local rim = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    rim:SetAllPoints()
    rim:SetColorTexture(0.54, 0.44, 0.20, 1)
    local ink = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(unpack(ns.colors.ink))
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.count = ns.Text(btn, 10)
    btn.count:SetPoint("BOTTOMRIGHT", -1, 2)
    btn:RegisterForClicks("RightButtonUp")
    btn:SetScript("OnClick", function(self)
        if InCombatLockdown() or not self.id then return end
        if Auras.CancelAuraByInstanceID then Auras.CancelAuraByInstanceID("player", self.id) end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetUnitAuraByAuraInstanceID then
            GameTooltip:SetUnitAuraByAuraInstanceID("player", self.id)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = btn
    return btn
end

-- Up from the medallion's ring, oldest at the bottom.
local function Layout()
    local ids = {}
    for id, buff in pairs(known) do
        if buff then table.insert(ids, id) end
    end
    table.sort(ids)
    local well = ns.stripWell
    local top = well.y - L.ringRadius - GAP
    for i, id in ipairs(ids) do
        local btn, buff = Button(i), known[id]
        btn.id = id
        btn.icon:SetTexture(buff.icon)
        btn.count:SetText(buff.count)
        ns.OnStrip(btn, -1, well.x, top - ICON / 2 - (i - 1) * (ICON + GAP))
        btn:Show()
    end
    for i = #ids + 1, #buttons do
        buttons[i].id = nil
        buttons[i]:Hide()
    end
    ns.buffs = buttons
end

local function Scan()
    wipe(known)
    unsorted = false
    local i = 1
    while true do
        local aura = Auras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        Add(aura)
        i = i + 1
    end
    Layout()
end

local function Changed(info)
    if not info or info.isFullUpdate then return Scan() end
    for _, aura in ipairs(info.addedAuras or {}) do Add(aura) end
    for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
        if known[id] then
            local aura = Auras.GetAuraDataByAuraInstanceID("player", id)
            if aura then known[id].count = Count(aura) end
        end
    end
    for _, id in ipairs(info.removedAuraInstanceIDs or {}) do known[id] = nil end
    Layout()
end

if Auras and Auras.GetAuraDataByIndex then
    local events = CreateFrame("Frame")
    ns.RegisterUnitEvent(events, "UNIT_AURA", "player")
    events:SetScript("OnEvent", function(_, _, _, info) Changed(info) end)
    ns.On("PLAYER_ENTERING_WORLD", Scan)
    ns.On("PLAYER_REGEN_ENABLED", function()
        if unsorted then Scan() end
    end)
end
