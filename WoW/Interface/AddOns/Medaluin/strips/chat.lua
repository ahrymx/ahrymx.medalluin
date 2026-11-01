-- The chat panel, on the left strip: Blizzard's own chat, sitting on the
-- micro menu between the portrait's medallion and the strip's top inner
-- corner. The panel is Medaluin's art (art/strips/gen_strips.py), fixed in
-- size; its foot is the strip's gold edge, which draws over it.
--
-- Nothing of the chat is replaced. The docked chat frames (they all follow
-- ChatFrame1) are anchored into the panel and their backgrounds and borders
-- taken away; the tabs wear the panel's tabs; the edit box lies over the
-- messages' foot while it is open. Blizzard's own buttons (the chat menu,
-- channels, voice) keep their column at the panel's left: Blizzard puts
-- them there itself, beside any chat frame in the left half of the screen.
-- The friends toast, which Blizzard stands above that column (out over the
-- panel's top), comes down into the column's corner of the tab row, over
-- the channel button.
--
-- The chat is in UIParent's scale, the panel in the console's, so the
-- room left for Blizzard's own pieces (the column, the tab row, the scroll
-- bar, the edit box) is measured in the chat's units and converted.
--
-- A window torn out of the dock gets its background back and floats as
-- Blizzard's; only its tab keeps the panel's look. Edit Mode's chat frame
-- position no longer applies: the panel puts it back.
--
-- The panel is under everything: BACKGROUND strata, so the chat (MEDIUM),
-- the friends toast and the dock (LOW) all draw over it.
--
-- Built at login, and only when the Chat panel option is on (settings.lua).
local _, ns = ...

local L = ns.stripLayout
local PARTS = ns.media .. "strips\\"
local CAP = L.tabCap / L.tabTex
local GAP = 5                   -- Blizzard's column stands this far left of the chat frame

-- A Blizzard region taken out of sight, and kept out: Blizzard's code shows
-- them again (a chat frame's fade-in, a tab's selection, the edit box's
-- focus). Let go when the window leaves the dock: shown again, or only left
-- for Blizzard to show (the edit box's focus art).
local gone, hooked = {}, {}
local function Gone(region)
    if not region then return end
    gone[region] = true
    region:Hide()
    if hooked[region] then return end
    hooked[region] = true
    hooksecurefunc(region, "Show", function(self)
        if gone[self] then self:Hide() end
    end)
    hooksecurefunc(region, "SetShown", function(self, shown)
        if shown and gone[self] then self:Hide() end
    end)
end
local function Back(region, shown)
    if region and gone[region] then
        gone[region] = nil
        if shown then region:Show() end
    end
end

local panel, area, edit
local placing = false

-- Where the messages and the edit box go, in the panel, from the scale of
-- the chat to the panel's.
local function Measure()
    local r = ChatFrame1:GetEffectiveScale() / panel:GetEffectiveScale()
    local left = L.chatPad + (L.chatColumn + GAP) * r
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -L.chatTop * r)
    area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -L.chatRight * r, L.chatPad)
    edit:ClearAllPoints()
    edit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", left - GAP * r, L.chatPad)
    edit:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -L.chatPad, L.chatPad + L.chatEdit * r)
end

-- ChatFrame1 into the panel; the docked windows are anchored to it.
local function Place()
    placing = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("TOPLEFT", area, "TOPLEFT")
    ChatFrame1:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    placing = false
end

-- The alert frame the friends toast stacks on: Blizzard's sits 27 above
-- the column (FloatingChatFrameAlertFrame.xml); ours at the column's top,
-- the 32-wide toast centred on the 29-wide column, as the channel button
-- under it is. Both are in the chat's scale.
local function PlaceAlerts()
    local column = ChatFrame1.buttonFrame
    placing = true
    ChatAlertFrame:SetSize(32, 32)
    ChatAlertFrame:ClearAllPoints()
    ChatAlertFrame:SetPoint("TOPLEFT", column, "TOPLEFT", (column:GetWidth() - 32) / 2, 0)
    placing = false
end

-- ------------------------------------------------------------------ tabs
-- Three slices of a tab texture over the tab's whole face, the middle
-- stretched. The side panel's tabs (side.lua) wear them too.
local function Slices(tab, file, layer, sub)
    local l = tab:CreateTexture(nil, layer, nil, sub)
    local m = tab:CreateTexture(nil, layer, nil, sub)
    local r = tab:CreateTexture(nil, layer, nil, sub)
    for _, t in ipairs({ l, m, r }) do t:SetTexture(PARTS .. file) end
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    l:SetWidth(L.tabCap)
    l:SetTexCoord(0, CAP, 0, 1)
    r:SetPoint("TOPRIGHT")
    r:SetPoint("BOTTOMRIGHT")
    r:SetWidth(L.tabCap)
    r:SetTexCoord(1 - CAP, 1, 0, 1)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    m:SetTexCoord(CAP, 1 - CAP, 0, 1)
    return { l, m, r }
end
ns.TabSlices = Slices

local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }

local function Selected(tab, selected)
    local m = tab.medaluin
    if not m then return end
    for _, t in ipairs(m.selected) do t:SetShown(selected and true or false) end
end

local function SkinTab(tab)
    if not tab or tab.medaluin then return end
    for _, key in ipairs(TAB_ART) do Gone(tab[key]) end
    Slices(tab, "tab", "BACKGROUND", 1)
    local glow = Slices(tab, "tab", "HIGHLIGHT", 1)
    for _, t in ipairs(glow) do
        t:SetBlendMode("ADD")
        t:SetAlpha(0.35)
    end
    tab.medaluin = { selected = Slices(tab, "tab-selected", "BACKGROUND", 2) }
    local frame = _G[tab:GetName():gsub("Tab$", "")]
    Selected(tab, frame and FCFDock_GetSelectedWindow
        and frame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK))
end

-- ------------------------------------------------------------- windows
-- A docked window loses its own background, border, size grip and edit box
-- art; its edit box moves over the messages' foot, on an ink backing.
local function Textures(frame)
    local name, list = frame:GetName(), {}
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local t = _G[name .. suffix]
        if t then table.insert(list, t) end
    end
    return list
end

-- The edit box's own art, and its focus art, which Blizzard shows itself.
local function BoxArt(box)
    local name = box:GetName()
    return { _G[name .. "Left"], _G[name .. "Mid"], _G[name .. "Right"] },
        { box.focusLeft, box.focusMid, box.focusRight }
end

local function EditBox(frame)
    local box = frame.editBox
    if not box then return end
    local own, focus = BoxArt(box)
    for _, t in ipairs(own) do Gone(t) end
    for _, t in ipairs(focus) do Gone(t) end
    if not box.medaluin then
        box.medaluin = {}
        local ink = ns.colors.ink
        for i, colour in ipairs({ { 0.54, 0.44, 0.20, 0.9 }, { ink[1], ink[2], ink[3], 0.9 } }) do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, i)
            t:SetPoint("TOPLEFT", i - 1, 1 - i)
            t:SetPoint("BOTTOMRIGHT", 1 - i, i - 1)
            t:SetColorTexture(unpack(colour))
            box.medaluin[i] = t
        end
    end
    for _, t in ipairs(box.medaluin) do t:Show() end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", edit, "TOPLEFT")
    box:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT")
end

local dressed = {}
local function Dress(frame)
    if not frame or dressed[frame] then return end
    dressed[frame] = true
    for _, t in ipairs(Textures(frame)) do Gone(t) end
    Gone(frame.ResizeButton)            -- the panel is a fixed size
    EditBox(frame)
end

-- Back to Blizzard's look, its size grip (on an unlocked window) and its
-- edit box anchors (FloatingChatFrame.xml).
local function Undress(frame)
    if not frame or not dressed[frame] or frame == ChatFrame1 then return end
    dressed[frame] = nil
    for _, t in ipairs(Textures(frame)) do Back(t, true) end
    Back(frame.ResizeButton, not frame.isLocked)
    local box = frame.editBox
    if box then
        local own, focus = BoxArt(box)
        for _, t in ipairs(own) do Back(t, true) end
        for _, t in ipairs(focus) do Back(t) end
        for _, t in ipairs(box.medaluin or {}) do t:Hide() end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -5, -2)
        if frame.ScrollBar then box:SetPoint("RIGHT", frame.ScrollBar, "RIGHT", 8, 0) end
    end
end

local function Frames()
    local list = {}
    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do table.insert(list, _G[name]) end
    else
        for i = 1, NUM_CHAT_WINDOWS or 10 do table.insert(list, _G["ChatFrame" .. i]) end
    end
    return list
end

local function Sweep()
    for _, frame in ipairs(Frames()) do
        SkinTab(_G[frame:GetName() .. "Tab"])
        if frame == ChatFrame1 or frame.isDocked then Dress(frame) end
    end
end

-- ----------------------------------------------------------------- build
local function Build()
    local strip = ns.strips[-1]
    panel = CreateFrame("Frame", "MedaluinChat", strip)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetSize(L.chatWidth, L.chatHeight)
    panel:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", L.chatLeft, L.stripHeight)
    local tex = panel:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(ns.media .. "chat")
    tex:SetTexCoord(0, L.chatWidth / L.chatTexWidth, 0, L.chatHeight / L.chatTexHeight)
    area = CreateFrame("Frame", nil, panel)
    edit = CreateFrame("Frame", nil, panel)
    ns.chat = { panel = panel, area = area, edit = edit }

    Measure()
    Place()
    Sweep()
    -- Blizzard re-places the chat frame from its saved layout and Edit Mode
    hooksecurefunc(ChatFrame1, "SetPoint", function()
        if not placing then Place() end
    end)
    if ChatAlertFrame and ChatFrame1.buttonFrame then
        PlaceAlerts()
        hooksecurefunc(ChatAlertFrame, "SetPoint", function()
            if not placing then PlaceAlerts() end
        end)
    end
    -- a scale change moves the room the chat's own pieces need
    local function Rescaled()
        Measure()
        Place()
    end
    hooksecurefunc(ns.console, "SetScale", Rescaled)
    hooksecurefunc(UIParent, "SetScale", Rescaled)

    if FCFTab_UpdateColors then hooksecurefunc("FCFTab_UpdateColors", Selected) end
    -- a whisper window is new, and docked here too (FCF_OpenTemporaryWindow)
    if FCF_DockFrame then
        hooksecurefunc("FCF_DockFrame", function(frame)
            SkinTab(_G[frame:GetName() .. "Tab"])
            Dress(frame)
        end)
    end
    if FCF_UnDockFrame then hooksecurefunc("FCF_UnDockFrame", Undress) end
end

ns.On("PLAYER_LOGIN", function()
    if ns.db.chat and ChatFrame1 then Build() end
end)
