-- The micro menu, on the left strip: the character portrait in the medallion
-- and one gold glyph per micro button after it. The buttons are Blizzard's
-- own, moved and redrawn, so their clicks, tooltips, level locks (talents)
-- and enable rules stay Blizzard's.
--
-- Blizzard's art is not replaced but muted: the Edit Mode clients (Forever,
-- retail) re-set a micro button's atlases and alphas whenever a panel opens
-- or the mouse passes, and a texture of ours in a state slot would be
-- overwritten. So the state textures are silenced, again after every set
-- and against every alpha or colour Blizzard gives them, and the glyph is
-- drawn over them, following the button's state.
local _, ns = ...

local L = ns.stripLayout

-- Glyph per button. A button this list does not know still gets a place,
-- with the plain lozenge, so no Blizzard panel loses its door.
local KIND = {
    ProfessionMicroButton = "profession",
    SpellbookMicroButton = "spellbook",
    PlayerSpellsMicroButton = "spellbook",       -- retail's spellbook and talents in one
    TalentMicroButton = "talents",
    LegacyMicroButton = "legacy",
    AchievementMicroButton = "achievement",
    QuestLogMicroButton = "quests",
    HousingMicroButton = "housing",
    SocialsMicroButton = "social",
    GuildMicroButton = "guild",
    LFGMicroButton = "lfg",
    LFDMicroButton = "lfg",
    WorldMapMicroButton = "map",
    CollectionsMicroButton = "collections",
    EJMicroButton = "journal",
    StoreMicroButton = "store",
    MainMenuMicroButton = "menu",
    HelpMicroButton = "help",
}

-- Clients without a MicroMenu (Classic Era): Blizzard's order. A button the
-- client lacks is skipped; LFG has gone by two names.
local CLASSIC = {
    "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton",
    "GuildMicroButton", "LFGMicroButton", "LFDMicroButton", "WorldMapMicroButton",
    "MainMenuMicroButton", "HelpMicroButton",
}

-- Blizzard's own drawing on the Edit Mode buttons, by key; Classic's by name.
local ART = { "Background", "PushedBackground", "Shadow", "PushedShadow", "Portrait",
    "FlashBorder", "FlashContent", "Emblem", "HighlightEmblem", "MainMenuBarPerformanceBar" }

-- Silenced, and kept so: Blizzard sets alphas and colours straight on these
-- textures (the normal one's alpha back to 1 as the mouse leaves, the
-- highlight's to .5 while a panel is open, a colour with no alpha, which is
-- alpha 1), so each texture puts its own zero back after every such call.
local pinned = {}
local function Silence(region)
    if not region then return end
    region:SetAlpha(0)
    ns.Mute(region)
    if pinned[region] then return end
    pinned[region] = true
    hooksecurefunc(region, "SetAlpha", function(self, a)
        if a ~= 0 then self:SetAlpha(0) end
    end)
    if region.SetVertexColor then
        hooksecurefunc(region, "SetVertexColor", function(self, _, _, _, a)
            if a ~= 0 then ns.Mute(self) end
        end)
    end
end

local function MuteStates(btn)
    Silence(btn:GetNormalTexture())
    Silence(btn:GetPushedTexture())
    Silence(btn:GetDisabledTexture())
    Silence(btn:GetHighlightTexture())
end

-- Draw our picture (tex) and its hover glow from the button's state.
local function Refresh(btn)
    local m = btn.medalluin
    local pushed = m.down or btn:GetButtonState() == "PUSHED"
    local enabled = btn:IsEnabled()
    local shade = pushed and 0.7 or 1
    m.tex:ClearAllPoints()
    m.tex:SetPoint("CENTER", 0, pushed and -1 or 0)
    m.tex:SetSize(m.size, m.size)
    m.tex:SetVertexColor(shade, shade, shade)
    if m.glyph then
        m.tex:SetDesaturated(not enabled)
        m.tex:SetAlpha(enabled and 1 or 0.45)
    end
    m.glow:SetShown(enabled and m.over or false)
end

local function Skin(btn, tex, glow, size, glyph)
    btn.medalluin = { tex = tex, glow = glow, size = size, glyph = glyph }
    glow:SetAllPoints(tex)
    -- Blizzard's micro buttons are tall, with the top of them not clickable
    btn:SetHitRectInsets(0, 0, 0, 0)
    for _, key in ipairs(ART) do Silence(btn[key]) end
    local name = btn:GetName()
    Silence(_G[name .. "Flash"])
    Silence(_G[name .. "Tabard"])                 -- Classic's guild emblem
    MuteStates(btn)
    for _, method in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture",
        "SetNormalAtlas", "SetPushedAtlas", "SetDisabledAtlas", "SetHighlightAtlas" }) do
        if btn[method] then hooksecurefunc(btn, method, MuteStates) end
    end
    local function Update() Refresh(btn) end
    for _, method in ipairs({ "SetButtonState", "Enable", "Disable", "SetEnabled" }) do
        if btn[method] then hooksecurefunc(btn, method, Update) end
    end
    btn:HookScript("OnEnter", function() btn.medalluin.over = true; MuteStates(btn); Refresh(btn) end)
    btn:HookScript("OnLeave", function() btn.medalluin.over = false; Refresh(btn) end)
    btn:HookScript("OnMouseDown", function() btn.medalluin.down = true; Refresh(btn) end)
    btn:HookScript("OnMouseUp", function() btn.medalluin.down = false; Refresh(btn) end)
    Refresh(btn)
end

local function Glyph(btn, kind)
    btn:SetParent(ns.strips[-1])
    btn:SetFrameLevel(ns.levels.stripTop)
    btn:SetSize(L.glyphTex, L.glyphTex)
    local tex = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    tex:SetTexture(ns.media .. "strips\\" .. kind)
    local glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture(ns.media .. "strips\\" .. kind)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.45)
    Skin(btn, tex, glow, L.glyphTex, true)
end

local portrait, queueEye

local function UpdateVisibility()
    if not portrait then return end
    if queueEye and queueEye:IsShown() then
        portrait:Hide()
    else
        portrait:Show()
    end
end

-- The Group Finder / LFG queue eye in the character medallion: while in queue,
-- it sits over the medallion and replaces the player portrait; when leaving
-- queue, the portrait returns.
local function SetupQueueEye()
    if queueEye then return end
    local eye = QueueStatusButton or QueueStatusMinimapButton or MiniMapLFGFrame
    if not eye then return end
    queueEye = eye

    local w = ns.stripWell
    eye:SetParent(ns.strips[-1])
    eye:SetFrameLevel(ns.levels.stripWell + 1)
    eye:ClearAllPoints()
    eye:SetPoint("CENTER", CharacterMicroButton, "CENTER", 0, 0)
    eye:SetSize(w.size, w.size)
    eye:SetScale(1)

    -- Mute outer border if Classic's minimap border is attached
    Silence(eye.Border)
    Silence(eye.HighlightBorder)
    Silence(eye.Background)
    local name = eye.GetName and eye:GetName()
    if name then
        Silence(_G[name .. "Border"])
        Silence(_G[name .. "Highlight"])
    end

    local placing = false
    local function HoldEye()
        if placing then return end
        placing = true
        eye:SetParent(ns.strips[-1])
        eye:SetFrameLevel(ns.levels.stripWell + 1)
        eye:ClearAllPoints()
        eye:SetPoint("CENTER", CharacterMicroButton, "CENTER", 0, 0)
        eye:SetSize(w.size, w.size)
        eye:SetScale(1)
        placing = false
    end
    hooksecurefunc(eye, "SetPoint", HoldEye)
    hooksecurefunc(eye, "SetParent", function(_, parent)
        if parent ~= ns.strips[-1] then HoldEye() end
    end)

    eye:HookScript("OnShow", UpdateVisibility)
    eye:HookScript("OnHide", UpdateVisibility)
    UpdateVisibility()
end

local function Character()
    local btn = CharacterMicroButton
    btn:SetParent(ns.strips[-1])
    btn:SetFrameLevel(ns.levels.stripWell)
    local w = ns.stripWell
    ns.OnStrip(btn, -1, w.x, w.y, w.size, w.size)
    Silence(MicroButtonPortrait)
    -- our own portrait: SetPortraitTexture draws it round, so the well can
    -- show it whole instead of Blizzard's cropped, tall version
    portrait = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    SetPortraitTexture(portrait, "player")
    Skin(btn, portrait, ns.RoundGlow(btn, 1, 0.9, 0.6, 0.18), w.size)
end

-- The buttons after the portrait, in the client's order.
local function Buttons()
    local list = {}
    if MicroMenu and MicroMenu.GetChildren then
        for _, child in ipairs({ MicroMenu:GetChildren() }) do
            if child.layoutIndex and child ~= CharacterMicroButton then table.insert(list, child) end
        end
        table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    if #list == 0 then
        for _, name in ipairs(CLASSIC) do
            if _G[name] then table.insert(list, _G[name]) end
        end
    end
    return list
end

-- The shown buttons close up, so a button Blizzard hides (Help on Forever,
-- the Store where it is closed) leaves no gap.
local buttons = {}
local function Layout()
    local x = L.firstGlyph
    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            ns.OnStrip(btn, -1, x, ns.stripRow)
            x = x + L.pitch
        end
    end
end

-- Micro menu notification banners (unspent talents, profession knowledge,
-- fanfare, journal): muted on their own regions so HelpTip.framePool,
-- info.callback and g_microButtonAlertsEnabledLocks stay untainted for
-- Blizzard_NewPlayerExperience and Blizzard_TutorialManager.
local function MuteHelpTips()
    if not (HelpTip and HelpTip.framePool and HelpTip.framePool.EnumerateActive) then return end
    for frame in HelpTip.framePool:EnumerateActive() do
        local micro = frame.info and frame.info.system == "MicroButtons"
        frame:SetAlpha(micro and 0 or 1)
        if frame.EnableMouse then frame:EnableMouse(not micro) end
    end
end

local function SilenceAlerts()
    MuteHelpTips()
    for _, name in ipairs({ "TalentMicroButtonAlert", "CollectionsMicroButtonAlert", "EJMicroButtonAlert" }) do
        ns.Kill(_G[name])
    end
end

ns.On("PLAYER_LOGIN", function()
    local noop = nop or function() end
    local mmc, mm = _G.MicroMenuContainer, _G.MicroMenu
    if mmc then mmc.Layout = noop end
    if mm then
        mm.Layout = noop
        mm.UpdateHelpTicketButtonAnchor = noop
    end
    Character()
    SetupQueueEye()
    buttons = Buttons()
    for _, btn in ipairs(buttons) do
        Glyph(btn, KIND[btn:GetName() or ""] or "misc")
        btn:HookScript("OnShow", Layout)
        btn:HookScript("OnHide", Layout)
    end
    ns.OutOfCombat(function() ns.Kill(MicroMenuContainer) end)
    Silence(MainMenuBarPerformanceBar)            -- Classic's latency bar on the menu button
    Silence(MainMenuBarDownload)
    SilenceAlerts()
    if HelpTip and HelpTip.Show then
        hooksecurefunc(HelpTip, "Show", MuteHelpTips)
    end
    Layout()
end)

local function UpdatePortrait()
    if not portrait then return end
    SetPortraitTexture(portrait, "player")
    if queueEye and queueEye:IsShown() then
        portrait:Hide()
    end
end
ns.On("PLAYER_ENTERING_WORLD", function()
    SilenceAlerts()
    SetupQueueEye()
    UpdatePortrait()
end)
ns.On("ADDON_LOADED", function(_, addon)
    if addon == "Blizzard_MicroMenu" then
        SilenceAlerts()
    end
end)
ns.On("PORTRAITS_UPDATED", UpdatePortrait)
ns.On("QUEUE_STATUS_UPDATE", function()
    SetupQueueEye()
    UpdateVisibility()
end)
local events = CreateFrame("Frame")
ns.RegisterUnitEvent(events, "UNIT_PORTRAIT_UPDATE", "player")
events:SetScript("OnEvent", UpdatePortrait)
