-- Aura management on unit frames:
--   1. Border / taint glow for debuffs the player can dispel (green for Poison,
--      purple for Curse, blue for Magic, orange for Disease, red for Bleed).
--   2. Crowd Control (CC): large centered icon with radial timer sweep and
--      countdown numbers.
--   3. Player-applied buffs: compact row on the outer corner of the health bar
--      (the side health decreases toward).
--   4. Boss debuffs: a large icon in the centre of the health, in the slot
--      crowd control uses (crowd control wins it).
--   5. Your debuffs on an enemy (the widgets' boss and arena cells, the
--      overhead's bosses): a row of small icons in the health's top right.
--
-- The console's frames answer to Unit Frames > Party; a widget's cell is
-- given its pieces and its tab's options by ns.AttachAuras (the raid's
-- switch to the Battleground tab's inside one).
local _, ns = ...

local Auras = C_UnitAuras
local LossOfControl = C_LossOfControl

local DISPEL_COLORS = {
    Magic = { 0.20, 0.60, 1.00 },
    Curse = { 0.70, 0.00, 1.00 },
    Poison = { 0.00, 0.82, 0.12 },
    Disease = { 0.82, 0.38, 0.00 },
    Bleed = { 0.80, 0.06, 0.06 },
}
local DISPEL_PRIORITY = { "Magic", "Curse", "Poison", "Disease", "Bleed" }

local playerDispels = {}

local function UpdatePlayerDispels()
    wipe(playerDispels)
    local _, class = UnitClass("player")
    local spec = GetSpecialization and GetSpecialization() or 0
    if class == "MAGE" then
        playerDispels.Curse = true
    elseif class == "DRUID" then
        playerDispels.Curse = true
        playerDispels.Poison = true
        if spec == 4 then playerDispels.Magic = true end -- Restoration
    elseif class == "PRIEST" then
        playerDispels.Magic = true
        playerDispels.Disease = true
    elseif class == "PALADIN" then
        playerDispels.Poison = true
        playerDispels.Disease = true
        if spec == 1 then playerDispels.Magic = true end -- Holy
    elseif class == "SHAMAN" then
        playerDispels.Curse = true
        if spec == 3 then -- Restoration
            playerDispels.Magic = true
            playerDispels.Poison = true
        end
    elseif class == "MONK" then
        playerDispels.Poison = true
        playerDispels.Disease = true
        if spec == 2 then playerDispels.Magic = true end -- Mistweaver
    elseif class == "EVOKER" then
        playerDispels.Poison = true
        if spec == 2 then -- Preservation
            playerDispels.Magic = true
            playerDispels.Curse = true
        end
    end
end

-- Common CC spell IDs across Classic and modern expansions
local CC_SPELLS = {
    [118] = true, [28271] = true, [28272] = true, [61305] = true, [61721] = true,
    [3355] = true, [2094] = true, [6770] = true, [20066] = true, [115078] = true,
    [51514] = true, [360806] = true, [99] = true, [31661] = true, [203340] = true,
    [853] = true, [408] = true, [1833] = true, [5211] = true, [107570] = true,
    [119381] = true, [108194] = true, [19577] = true, [305483] = true,
    [5782] = true, [5246] = true, [8122] = true, [6789] = true, [64044] = true,
    [33786] = true, [710] = true, [15487] = true, [47476] = true,
    [339] = true, [122] = true, [113724] = true,
}

local function IsCCAura(aura)
    if not aura or ns.IsSecret(aura.isHarmful) or not aura.isHarmful then return false end
    local id = aura.spellId
    if id and not ns.IsSecret(id) and CC_SPELLS[id] then return true end
    local name = aura.name
    if name and not ns.IsSecret(name) and (name:find("Polymorph") or name:find("Freezing Trap") or name:find("Fear")
        or name:find("Hammer of Justice") or name:find("Stun") or name:find("Cyclone")
        or name:find("Blind") or name:find("Sap") or name:find("Paralysis")
        or name:find("Sleep") or name:find("Silence") or name:find("Horror")
        or name:find("Incapacitate") or name:find("Hex")) then
        return true
    end
    return false
end

-- Timer text OnUpdate with throttling
local function OnTimerUpdate(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < 0.1 then return end
    self.throttle = 0
    if self.stubText then
        self.timer:SetText(self.stubText)
        return
    end
    if not self.expires then
        self.timer:SetText("")
        return
    end
    local rem = self.expires - GetTime()
    if rem <= 0 then
        self.timer:SetText("")
    elseif rem >= 10 then
        self.timer:SetFormattedText("%d", math.floor(rem + 0.5))
    elseif rem >= 3 then
        self.timer:SetFormattedText("%d", math.ceil(rem))
    else
        self.timer:SetFormattedText("%.1f", rem)
    end
end

-- Border glow behind the stone console art for dispellable debuffs
local function CreateDispelGlow(btn, side, window)
    local f = CreateFrame("Frame", nil, btn)
    f:SetAllPoints(btn)
    f:SetFrameStrata(btn:GetFrameStrata())
    f:SetFrameLevel(ns.levels.art - 1)
    local t = 3
    local top = f:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    top:SetHeight(t)
    top:SetBlendMode("ADD")

    local btm = f:CreateTexture(nil, "OVERLAY")
    btm:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    btm:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    btm:SetHeight(t)
    btm:SetBlendMode("ADD")

    local left = f:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -t)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, t)
    left:SetWidth(t)
    left:SetBlendMode("ADD")

    local right = f:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -t)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, t)
    right:SetWidth(t)
    right:SetBlendMode("ADD")

    local edges = { top, btm, left, right }

    -- 45-degree diagonal cut on the inner end of the window, built for the
    -- windows that have one in the medallion's art and shown only while the
    -- layout says the window is cut (ns.ShapeDispelGlows)
    f.window = window
    if window == "party1" or window == "unit" then
        local h = btn:GetHeight()
        if f.CreateLine then
            local line = f:CreateLine(nil, "OVERLAY")
            if side == -1 then
                line:SetStartPoint("TOPRIGHT", f, -h, 0)
                line:SetEndPoint("BOTTOMRIGHT", f, 0, 0)
            else
                line:SetStartPoint("TOPLEFT", f, h, 0)
                line:SetEndPoint("BOTTOMLEFT", f, 0, 0)
            end
            line:SetThickness(t)
            line:SetBlendMode("ADD")
            table.insert(edges, line)
            f.cut = line
        else
            local diag = f:CreateTexture(nil, "OVERLAY")
            local len = math.ceil(math.sqrt(h * h + h * h))
            diag:SetSize(len, t)
            if side == -1 then
                diag:SetPoint("CENTER", f, "TOPRIGHT", -h / 2, -h / 2)
                if diag.SetRotation then diag:SetRotation(-math.pi / 4) end
            else
                diag:SetPoint("CENTER", f, "TOPLEFT", h / 2, -h / 2)
                if diag.SetRotation then diag:SetRotation(math.pi / 4) end
            end
            diag:SetBlendMode("ADD")
            table.insert(edges, diag)
            f.cut = diag
        end
    end

    for _, e in ipairs(edges) do e:SetColorTexture(1, 1, 1, 1) end

    function f:SetGlowColor(r, g, b, a)
        for _, e in ipairs(edges) do e:SetVertexColor(r, g, b, a or 0.85) end
    end

    f:SetScript("OnUpdate", function(self, elapsed)
        self.pulse = (self.pulse or 0) + elapsed * 3
        local alpha = 0.65 + 0.35 * math.abs(math.sin(self.pulse))
        self:SetAlpha(alpha)
    end)
    f:Hide()
    return f
end

-- CC Centerpiece widget
local function CreateCCWidget(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    f:SetFrameLevel(ns.levels.text + 2)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(unpack(ns.colors.ink))

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetSwipeColor(0, 0, 0, 0.75)
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetDrawSwipe(true)
    if f.cooldown.SetHideCountdownNumbers then
        f.cooldown:SetHideCountdownNumbers(true)
    end

    f.timer = ns.Text(f.cooldown, size <= 26 and 11 or 13)
    f.timer:SetPoint("CENTER", f.cooldown, "CENTER", 0, 0)
    f.timer:SetTextColor(1, 0.9, 0.2)

    f:SetScript("OnUpdate", OnTimerUpdate)
    f:Hide()
    return f
end

local function AttachTooltip(btn, isBuff)
    btn:SetScript("OnEnter", function(self)
        if not self.auraInstanceID and not self.tooltipTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipTitle then
            GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
            if self.tooltipDesc then
                GameTooltip:AddLine(self.tooltipDesc, 0.7, 0.7, 0.7, true)
            end
        elseif self.unit and self.auraInstanceID and GameTooltip.SetUnitAuraByAuraInstanceID then
            GameTooltip:SetUnitAuraByAuraInstanceID(self.unit, self.auraInstanceID)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

-- Player buffs container: outer corner of health (where health decreases toward)
-- A row's icons: as many as the editor's Max may ask for, of which the
-- row shows its default (buttons.default) until it does (ns.RowMax).
local POOL = 10

local function CreateBuffWidgets(health, side, isParty)
    local buttons = { default = isParty and 3 or 4 }
    local iconSize = 15
    local gap = 2
    local vert = isParty and "TOP" or "BOTTOM"
    local horiz = side == -1 and "LEFT" or "RIGHT"
    local point = vert .. horiz
    local offsetY = isParty and -2 or 2

    for i = 1, POOL do
        local btn = CreateFrame("Button", nil, health)
        btn:SetSize(iconSize, iconSize)
        btn:SetFrameLevel(ns.levels.text + 1)
        local step = (i - 1) * (iconSize + gap)
        local offsetX = side == -1 and (2 + step) or (-2 - step)
        btn:SetPoint(point, health, point, offsetX, offsetY)

        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(unpack(ns.colors.ink))

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 1, -1)
        btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints(btn.icon)
        btn.cooldown:SetSwipeColor(0, 0, 0, 0.6)
        btn.cooldown:SetDrawEdge(false)
        btn.cooldown:SetDrawSwipe(true)
        if btn.cooldown.SetHideCountdownNumbers then
            btn.cooldown:SetHideCountdownNumbers(true)
        end

        btn.count = ns.Text(btn, 9)
        btn.count:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.count:SetTextColor(1, 1, 1)

        AttachTooltip(btn, true)
        btn:Hide()
        table.insert(buttons, btn)
    end
    return buttons
end

-- Boss debuff centerpiece widget: shares the center threat slot with CC (Priority B)
local function CreateBossDebuffWidget(health, size)
    local btn = CreateFrame("Button", nil, health)
    btn:SetSize(size, size)
    btn:SetPoint("CENTER", health, "CENTER", 0, 0)
    btn:SetFrameLevel(ns.levels.text + 2)

    local rim = btn:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0.90, 0.15, 0.15, 1)

    local ink = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(unpack(ns.colors.ink))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1.5, -1.5)
    btn.icon:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetSwipeColor(0, 0, 0, 0.75)
    btn.cooldown:SetDrawEdge(true)
    btn.cooldown:SetDrawSwipe(true)
    if btn.cooldown.SetHideCountdownNumbers then
        btn.cooldown:SetHideCountdownNumbers(true)
    end

    btn.timer = ns.Text(btn.cooldown, size <= 26 and 11 or 13)
    btn.timer:SetPoint("CENTER", btn.cooldown, "CENTER", 0, 0)
    btn.timer:SetTextColor(1, 0.9, 0.2)

    btn.count = ns.Text(btn, 10)
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.count:SetTextColor(1, 1, 1)

    btn:SetScript("OnUpdate", OnTimerUpdate)
    AttachTooltip(btn, false)
    btn:Hide()
    return btn
end

-- The preview's auras, by unit: a debuff to dispel, crowd control, your
-- buffs, a boss debuff, and how many of your debuffs (an enemy).
local STUB_AURAS = {
    party1 = { glow = "Curse" }, party2 = { cc = true }, party3 = { buffs = true }, party4 = { boss = true },
    raidpreview1 = { glow = "Curse" }, raidpreview2 = { cc = true }, raidpreview4 = { boss = true },
    boss1 = { mine = 3 }, boss2 = { mine = 1 }, boss3 = { mine = 2 },
    arena1 = { mine = 3 }, arena2 = { cc = true, mine = 1 }, arena3 = { mine = 2 },
}
local MINE_ICONS = { "Spell_Shadow_ShadowWordPain", "Spell_Holy_SearingLight", "Spell_Shadow_AbominationExplosion" }

-- Whether a frame shows one kind of aura: the option its tab gives it. The
-- console's party buttons answer to the Party widget's own while they are in
-- it (ns.PartyKey); the player's and target's to the console's.
local CONSOLE_KEYS = { glow = "auraGlow", cc = "auraCC", buffs = "auraBuffs", boss = "auraBoss" }
local function Shows(b, kind)
    local keys = b.auraKeys or CONSOLE_KEYS
    if type(keys) == "function" then keys = keys() end
    local key = keys[kind]
    if key and not b.auraKeys and b.unit:match("^party%d$") then key = ns.PartyKey(key) end
    return key and ns.db[key] ~= false or false
end

-- Applies stub simulation auras when simParty is true
local function ApplyStubAuras(b)
    local want = STUB_AURAS[b.unit] or {}
    -- Dispel glow stub (a Curse)
    if b.dispelGlow then
        if want.glow and Shows(b, "glow") then
            b.dispelGlow:SetGlowColor(unpack(DISPEL_COLORS[want.glow]))
            b.dispelGlow:Show()
        else
            b.dispelGlow:Hide()
        end
    end

    -- CC Centerpiece stub (sheeped)
    local cc = false
    if b.ccWidget then
        if want.cc and Shows(b, "cc") then
            b.ccWidget.icon:SetTexture("Interface\\Icons\\Spell_Nature_Polymorph")
            b.ccWidget.stubText = "4"
            b.ccWidget.expires = nil
            b.ccWidget.timer:SetText("4")
            b.ccWidget:Show()
            cc = true
        else
            b.ccWidget:Hide()
        end
    end

    -- Player buffs stub (personal HoTs)
    if b.buffWidgets then
        for _, btn in ipairs(b.buffWidgets) do btn:Hide() end
        if want.buffs and Shows(b, "buffs") then
            local max = ns.RowMax(b, "buffs")
            local b1 = max >= 1 and b.buffWidgets[1]
            if b1 then
                b1.icon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
                b1.count:SetText("")
                b1.tooltipTitle = "Rejuvenation"
                b1.tooltipDesc = "Heals 1,420 over 15 sec."
                b1:Show()
            end
            local b2 = max >= 2 and b.buffWidgets[2]
            if b2 then
                b2.icon:SetTexture("Interface\\Icons\\Spell_Nature_ResistNature")
                b2.count:SetText("3")
                b2.tooltipTitle = "Lifebloom (3)"
                b2.tooltipDesc = "Heals 3,150 over 15 sec. When it expires, blooms for direct healing."
                b2:Show()
            end
        end
    end

    -- Boss debuff stub (a critical boss aura, shown in the centerpiece)
    if b.bossDebuff then
        if want.boss and Shows(b, "boss") and not cc then
            b.bossDebuff.icon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_01")
            b.bossDebuff.stubText = "8"
            b.bossDebuff.expires = nil
            b.bossDebuff.timer:SetText("8")
            b.bossDebuff.count:SetText("2")
            b.bossDebuff.tooltipTitle = "Cursed Agony"
            b.bossDebuff.tooltipDesc = "Critical encounter mechanic. Inflicts heavy shadow damage every 2 sec."
            b.bossDebuff:Show()
        else
            b.bossDebuff:Hide()
        end
    end

    -- Your debuffs stub (an enemy with your damage over time on it)
    if b.mineWidgets then
        local n = want.mine and Shows(b, "mine") and math.min(want.mine, ns.RowMax(b, "mine")) or 0
        for k, btn in ipairs(b.mineWidgets) do
            if k <= n then
                btn.icon:SetTexture("Interface\\Icons\\" .. MINE_ICONS[k])
                btn.tooltipTitle = "Your debuff " .. k
                btn.tooltipDesc = "Simulated"
            end
            btn:SetShown(k <= n)
        end
        if b.mineLaid then b.mineLaid(n) end
    end
end

local function IsTimeless(unit, aura)
    if not aura then return false end
    if Auras and Auras.DoesAuraHaveExpirationTime then
        local timed = Auras.DoesAuraHaveExpirationTime(unit, aura.auraInstanceID)
        if not ns.IsSecret(timed) and timed ~= nil then
            return not timed
        end
    end
    local exp = aura.expirationTime
    local dur = aura.duration
    if not ns.IsSecret(exp) and not ns.IsSecret(dur) then
        if (exp == nil or exp == 0) and (dur == nil or dur == 0) then
            return true
        end
    end
    return false
end

-- Live aura scanning for active units
local function ScanUnitAuras(b)
    local unit = b.unit
    local isAlly = unit == "player" or (UnitIsFriend and UnitIsFriend("player", unit))

    -- 1. Dispel Glow
    local bestDispel = nil
    if isAlly and b.dispelGlow and Shows(b, "glow") and Auras and Auras.GetAuraDataByIndex then
        local i = 1
        while true do
            local aura = Auras.GetAuraDataByIndex(unit, i, "HARMFUL")
            if not aura then break end
            local d = aura.dispelName
            if d and playerDispels[d] then
                if not bestDispel then
                    bestDispel = d
                else
                    for _, p in ipairs(DISPEL_PRIORITY) do
                        if p == d then bestDispel = d; break
                        elseif p == bestDispel then break end
                    end
                end
            end
            i = i + 1
        end
    end
    if b.dispelGlow then
        if bestDispel and DISPEL_COLORS[bestDispel] then
            b.dispelGlow:SetGlowColor(unpack(DISPEL_COLORS[bestDispel]))
            b.dispelGlow:Show()
        else
            b.dispelGlow:Hide()
        end
    end

    -- 2. Crowd Control (CC)
    local ccAura = nil
    if b.ccWidget and Shows(b, "cc") then
        if unit == "player" and LossOfControl and LossOfControl.GetActiveLossOfControlDataCount then
            local count = LossOfControl.GetActiveLossOfControlDataCount()
            if count and count > 0 then
                local loc = LossOfControl.GetActiveLossOfControlData(1)
                if loc and loc.iconTexture then
                    ccAura = {
                        icon = loc.iconTexture,
                        duration = loc.duration,
                        expirationTime = loc.startTime and loc.duration and (loc.startTime + loc.duration),
                    }
                end
            end
        end
        if not ccAura and Auras and Auras.GetAuraDataByIndex then
            local i = 1
            while true do
                local aura = Auras.GetAuraDataByIndex(unit, i, "HARMFUL")
                if not aura then break end
                if IsCCAura(aura) then
                    ccAura = aura
                    break
                end
                i = i + 1
            end
        end
    end
    if b.ccWidget then
        if ccAura then
            b.ccWidget.icon:SetTexture(ccAura.icon)
            b.ccWidget.stubText = nil
            if ccAura.duration and ccAura.expirationTime and not ns.IsSecret(ccAura.duration)
                and ccAura.duration > 0 then
                b.ccWidget.cooldown:SetCooldown(ccAura.expirationTime - ccAura.duration, ccAura.duration)
                b.ccWidget.expires = ccAura.expirationTime
            else
                b.ccWidget.expires = nil
                b.ccWidget.timer:SetText("")
            end
            b.ccWidget:Show()
        else
            b.ccWidget:Hide()
        end
    end

    -- 3. Player-Applied Buffs
    if b.buffWidgets then
        for _, btn in ipairs(b.buffWidgets) do btn:Hide() end
        if Shows(b, "buffs") and Auras and Auras.GetAuraDataByIndex then
            local idx = 1
            local btnIdx = 1
            local max = ns.RowMax(b, "buffs")
            while btnIdx <= max do
                local aura = Auras.GetAuraDataByIndex(unit, idx, "HELPFUL|PLAYER")
                if not aura then break end
                -- Do not show timeless buffs on the player frame
                if not (unit == "player" and IsTimeless(unit, aura)) then
                    local btn = b.buffWidgets[btnIdx]
                    btn.unit = unit
                    btn.auraInstanceID = aura.auraInstanceID
                    btn.tooltipTitle = nil
                    btn.tooltipDesc = nil
                    btn.icon:SetTexture(aura.icon)
                    local n = aura.applications
                    btn.count:SetText((n and not ns.IsSecret(n) and n > 1) and tostring(n) or "")
                    if aura.duration and aura.expirationTime and not ns.IsSecret(aura.duration)
                        and aura.duration > 0 then
                        btn.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                    end
                    btn:Show()
                    btnIdx = btnIdx + 1
                end
                idx = idx + 1
            end
        end
    end

    -- 4. Boss Debuffs (shares the center threat slot with CC; P0 is CC, P1 is Boss Debuff)
    local bossAura = nil
    if b.bossDebuff and Shows(b, "boss") and not ccAura and Auras and Auras.GetAuraDataByIndex then
        local i = 1
        while true do
            local aura = Auras.GetAuraDataByIndex(unit, i, "HARMFUL")
            if not aura then break end
            if not ns.IsSecret(aura.isBossAura) and aura.isBossAura then
                bossAura = aura
                break
            end
            i = i + 1
        end
    end
    if b.bossDebuff then
        if bossAura and not ccAura then
            b.bossDebuff.unit = unit
            b.bossDebuff.auraInstanceID = bossAura.auraInstanceID
            b.bossDebuff.tooltipTitle = nil
            b.bossDebuff.tooltipDesc = nil
            b.bossDebuff.icon:SetTexture(bossAura.icon)
            b.bossDebuff.stubText = nil
            local n = bossAura.applications
            b.bossDebuff.count:SetText((n and not ns.IsSecret(n) and n > 1) and tostring(n) or "")
            if bossAura.duration and bossAura.expirationTime and not ns.IsSecret(bossAura.duration)
                and bossAura.duration > 0 then
                b.bossDebuff.cooldown:SetCooldown(bossAura.expirationTime - bossAura.duration, bossAura.duration)
                b.bossDebuff.expires = bossAura.expirationTime
            else
                b.bossDebuff.expires = nil
                b.bossDebuff.timer:SetText("")
            end
            b.bossDebuff:Show()
        else
            b.bossDebuff:Hide()
        end
    end

    -- 5. Your debuffs on an enemy
    if b.mineWidgets then
        local n = 0
        if Shows(b, "mine") and Auras and Auras.GetAuraDataByIndex then
            local max = ns.RowMax(b, "mine")
            while n < max do
                local aura = Auras.GetAuraDataByIndex(unit, n + 1, "HARMFUL|PLAYER")
                if not aura then break end
                n = n + 1
                local btn = b.mineWidgets[n]
                btn.unit = unit
                btn.auraInstanceID = aura.auraInstanceID
                btn.tooltipTitle = nil
                btn.tooltipDesc = nil
                btn.icon:SetTexture(aura.icon)
                if aura.duration and aura.expirationTime and not ns.IsSecret(aura.duration)
                    and aura.duration > 0 then
                    btn.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                end
            end
        end
        for k, btn in ipairs(b.mineWidgets) do btn:SetShown(k <= n) end
        if b.mineLaid then b.mineLaid(n) end
    end
end

-- Every aura piece a frame has, hidden.
local function HideAuras(b)
    if b.dispelGlow then b.dispelGlow:Hide() end
    if b.ccWidget then b.ccWidget:Hide() end
    if b.bossDebuff then b.bossDebuff:Hide() end
    for _, btn in ipairs(b.buffWidgets or {}) do btn:Hide() end
    for _, btn in ipairs(b.mineWidgets or {}) do btn:Hide() end
    if b.mineLaid then b.mineLaid(0) end
end

local function UpdateUnitAuras(b)
    if not b then return end
    local unit = b.unit
    if not unit or (not UnitExists(unit) and not b.stub) then
        HideAuras(b)
        return
    end

    -- Ready checks and role checks hide buffs and debuffs while active
    if b.isChecking or (b.statusWidget and b.statusWidget:IsShown()) then
        HideAuras(b)
        return
    end

    if b.stub and not UnitExists(unit) then
        ApplyStubAuras(b)
    else
        ScanUnitAuras(b)
    end
end
ns.UpdateUnitAuras = UpdateUnitAuras

-- The widgets' cells and the overhead's bosses that carry auras (ns.AttachAuras).
local carriers = {}

local function UpdateAllAuras()
    UpdatePlayerDispels()
    for _, b in pairs(ns.units or {}) do
        UpdateUnitAuras(b)
    end
    for b in pairs(carriers) do UpdateUnitAuras(b) end
end

-- Initialize widgets on each unit frame
for unit, b in pairs(ns.units or {}) do
    local window, side = unpack(ns.slots[unit])
    local isParty = window ~= "unit"

    b.dispelGlow = CreateDispelGlow(b, side, window)
    b.ccWidget = CreateCCWidget(b.health, isParty and 24 or 32)
    b.buffWidgets = CreateBuffWidgets(b.health, side, isParty)
    b.bossDebuff = CreateBossDebuffWidget(b.health, isParty and 24 or 32)
end

-- Your debuffs: three icons (the editor's Max more), right to left from
-- the health's top right.
local function CreateMineWidgets(health, size, point, y)
    local buttons = { default = 3 }
    for i = 1, POOL do
        local btn = CreateFrame("Button", nil, health)
        btn:SetSize(size, size)
        btn:SetPoint(point, health, point, -2 - (i - 1) * (size + 2), y)
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(unpack(ns.colors.ink))
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 1, -1)
        btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints(btn.icon)
        btn.cooldown:SetSwipeColor(0, 0, 0, 0.6)
        btn.cooldown:SetDrawEdge(false)
        btn.cooldown:SetDrawSwipe(true)
        if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end
        AttachTooltip(btn, false)
        btn:Hide()
        buttons[i] = btn
    end
    return buttons
end

-- In a battleground, the raid's cells answer to the Battleground tab.
local RAID_KEYS = { glow = "raidGlow", cc = "raidCC", boss = "raidBoss" }
local BG_KEYS = { glow = "bgGlow", cc = "bgCC" }
function ns.InBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end
local function RaidKeys() return ns.InBattleground() and BG_KEYS or RAID_KEYS end
ns.RaidAuraKeys = RaidKeys

-- A widget's cell, or an overhead boss, given its aura pieces and the
-- options that rule them (Unit Frames' tabs), by kind:
--   "raid": the dispel glow on the border; crowd control or a boss debuff
--           in the middle of the health (the draft's A, gen_cell_auras.py)
--   "boss", "arena": your debuffs in the health's top right; on arena,
--           crowd control in the middle
--   "overhead": the overhead's boss, too short for a row over its name: your
--           debuffs (size square) at the health's right end, its value
--           stepping left of them
function ns.AttachAuras(b, kind, size)
    local level = b:GetFrameLevel()
    local function Over(f, by) f:SetFrameLevel(level + by) end
    if kind == "raid" then
        b.auraKeys = RaidKeys
        b.dispelGlow = CreateDispelGlow(b, 1)
        Over(b.dispelGlow, 3)
        b.ccWidget = CreateCCWidget(b.health, 20)
        Over(b.ccWidget, 4)
        b.bossDebuff = CreateBossDebuffWidget(b.health, 20)
        Over(b.bossDebuff, 4)
    elseif kind == "arena" then
        b.auraKeys = { cc = "arenaCC", mine = "arenaMine" }
        b.ccWidget = CreateCCWidget(b.health, 20)
        Over(b.ccWidget, 4)
    elseif kind == "boss" then
        b.auraKeys = { mine = "bossWidgetMine" }
    else
        b.auraKeys = { mine = "bossMine" }
    end
    if kind == "boss" or kind == "arena" then
        b.mineWidgets = CreateMineWidgets(b.health, 14, "TOPRIGHT", -2)
    elseif kind == "overhead" then
        b.mineWidgets = CreateMineWidgets(b.health, size, "RIGHT", 0)
        local value = b.value
        b.mineLaid = function(n)
            value:ClearAllPoints()
            if n > 0 then
                value:SetPoint("RIGHT", b.mineWidgets[n], "LEFT", -3, 0)
            else
                value:SetPoint("RIGHT", value:GetParent(), "RIGHT", -4, 0)
            end
        end
    end
    for _, btn in ipairs(b.mineWidgets or {}) do Over(btn, 4) end
    -- a cell gone takes its auras with it; shown, its owner draws them again
    b:HookScript("OnHide", HideAuras)
    carriers[b] = true
end

-- The glow's cut follows the layout's. A cut is built shown, which is the
-- medallion's; the light profile swaps its layout in after this file has run,
-- and ns.RelayoutUnits (called by ns.ApplyLightProfile) reshapes the glows.
function ns.ShapeDispelGlows()
    local cuts = ns.layout.cuts or {}
    for _, b in pairs(ns.units or {}) do
        local g = b.dispelGlow
        -- a party button in the widget is a plain rectangle (widgets/party.lua)
        if g and g.cut then g.cut:SetShown(cuts[g.window] and not b.inWidget and true or false) end
    end
end

local events = CreateFrame("Frame")
for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    ns.RegisterUnitEvent(events, "UNIT_AURA", unit)
end
events:SetScript("OnEvent", function(_, _, unit)
    if ns.units and ns.units[unit] then
        UpdateUnitAuras(ns.units[unit])
    end
end)

local loc = CreateFrame("Frame")
loc:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
loc:RegisterEvent("LOSS_OF_CONTROL_ADDED")
loc:SetScript("OnEvent", function()
    if ns.units and ns.units.player then
        UpdateUnitAuras(ns.units.player)
    end
end)

UpdatePlayerDispels()
ns.On("PLAYER_SPECIALIZATION_CHANGED", UpdateAllAuras)
ns.On("SPELLS_CHANGED", UpdateAllAuras)
ns.On("GROUP_ROSTER_UPDATE", UpdateAllAuras)
ns.On("PLAYER_TARGET_CHANGED", function()
    if ns.units and ns.units.target then
        UpdateUnitAuras(ns.units.target)
    end
end)
ns.On("PLAYER_ENTERING_WORLD", UpdateAllAuras)
ns.On("ADDON_LOADED", UpdateAllAuras)

ns.OnSetting("auraGlow", UpdateAllAuras)
ns.OnSetting("auraCC", UpdateAllAuras)
ns.OnSetting("auraBuffs", UpdateAllAuras)
ns.OnSetting("auraBoss", UpdateAllAuras)
for _, key in ipairs({ "raidGlow", "raidCC", "raidBoss", "bgGlow", "bgCC", "bossMine", "bossWidgetMine", "arenaCC",
    "arenaMine", "partyWidgetGlow", "partyWidgetCC", "partyWidgetBuffs", "partyWidgetBoss", "partyLayout" }) do
    ns.OnSetting(key, UpdateAllAuras)
end
ns.OnSetting("simParty", UpdateAllAuras)
