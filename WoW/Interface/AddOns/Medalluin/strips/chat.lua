-- The chat box, on the left strip: Blizzard's own chat, in a box standing
-- on the micro menu, from the screen's edge as wide as the character
-- window. The box wears the windows' trim over an ink that fades to the
-- right (ns.window.Dress); from its foot up:
--
--   (medallion)  [buff][buff]          <- the margin: the timeless buffs,
--   ---------------------------------     and the edit box over them
--   the messages (the panel)
--   [General][Trade]           |(*)[o P <]  <- the tabs, the cog and its
--                                               drawer, open
--
-- The quest tracker's full view stands over the box, up to the screen's
-- top, in a box of its own on it (Reach): its foot is the chat box's top
-- edge, so the two read as one, and it fades with the tracker, and goes
-- when the tracker goes minimal.
--
-- Nothing of the chat is replaced. The docked chat frames (they all follow
-- ChatFrame1) are anchored into the panel and their backgrounds and borders
-- taken away; the tabs wear the windows' box tabs (ns.window.Face); the
-- edit box lies over the margin, on an ink backing while it is typed in.
-- Blizzard's own buttons (the chat menu, the friends toast, channels,
-- voice) leave their column at the messages' left for a drawer behind a
-- cog at the tab row's right end, which opens to the right, as the minimap
-- button drawer does (bars/drawer.lua); they wear gold glyphs instead of
-- their own art.
--
-- The chat is in UIParent's scale, the panel in the console's, so the
-- room left for Blizzard's own pieces (the tab row, the scroll bar) is
-- measured in the chat's units and converted.
--
-- A window torn out of the dock gets its background back and floats as
-- Blizzard's; only its tab keeps the box tab. Edit Mode's chat frame
-- position no longer applies: the panel puts it back.
--
-- The box is under everything: BACKGROUND strata, so the strip and its
-- medallion, the chat (MEDIUM), the friends toast and the dock (LOW) all
-- draw over it.
--
-- Built at login, and only when the Chat box option is on (settings.lua).
local _, ns = ...

local L = ns.stripLayout
local PARTS = ns.media .. "strips\\"
local CAP = L.tabCap / L.tabTex
local PAD, RULE, TABS = 8, 6, 24    -- the box's edge, the gap over the margin's rule, the tabs' height
local SHORTER = 3                   -- the margin, less than the windows' (the edit box's height)
local SLIM, FOOT = 18, 3            -- a tab's box, and its foot over the hairline
local BOX = TABS - FOOT             -- the cog's box and its drawer's: up to the tab row's top
local GAP = 4                       -- either side of the divider between the tabs and the cog
local GLYPH = BOX + 4               -- a glyph in a box (its art is 20 of the 32)
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = ns.colors.dim

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

local chatBox, panel, area, edit, head
local cog, tray, open = nil, nil, false
local lift = 0                      -- the dock raised by, measured
local hang = 0                      -- the alert frame's drop from the friends slot, measured

-- A chat unit in the panel's (the chat is in UIParent's scale)
local function Ratio() return ChatFrame1:GetEffectiveScale() / panel:GetEffectiveScale() end

-- A point set only when it is not already so: Blizzard answers some moves
-- (the alert frame's) by moving something else, which would come back here
local function Put(f, point, to, relative, x, y)
    if f:GetNumPoints() == 1 then
        local p, t, r, px, py = f:GetPoint(1)
        if p == point and t == to and r == relative and px == x and py == y then return end
    end
    f:ClearAllPoints()
    f:SetPoint(point, to, relative, x, y)
end
local placing = false

-- The drawer's buttons, from the left: the chat menu, the friends toast,
-- channels, and the two voice toggles while voice is on. The voice toggles
-- keep their own art: it is their state.
local HEAD = {
    { name = "ChatFrameMenuButton", glyph = "chat" },
    { name = "QuickJoinToastButton", glyph = "character", alert = true },
    { name = "ChatFrameChannelButton", glyph = "channels" },
    { name = "ChatFrameToggleVoiceDeafenButton" },
    { name = "ChatFrameToggleVoiceMuteButton" },
}

-- The dock (Blizzard's tab row) along the chat's top, stopping short of
-- the divider before the cog. Blizzard hangs it from ChatFrame1's
-- background, which runs past the chat's right edge, under the cog; so it
-- is anchored here to ChatFrame1 itself. And it is raised, or lowered,
-- until its tabs' slim boxes stand on the hairline: the first tab's middle
-- is measured from the chat's top (the hairline: both in the chat's own
-- units, so no scale is mixed in) and the dock moved by what is missing.
-- The tabs are fitted to its width again.
local function Dock(width)
    local dock = GENERAL_CHAT_DOCK
    if not dock then return end
    local function Set()
        dock:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, lift)
        dock:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", L.chatRight - width, lift)
    end
    Set()
    if FCFDock_UpdateTabs then FCFDock_UpdateTabs(dock, true) end
    local tab = _G.ChatFrame1Tab
    local top, bottom, chat = tab:GetTop(), tab:GetBottom(), ChatFrame1:GetTop()
    if top and bottom and chat then
        local miss = (FOOT + SLIM / 2) / Ratio() - ((top + bottom) / 2 - chat)
        if math.abs(miss) > 0.5 then
            lift = lift + miss
            Set()
        end
    end
end

-- The cog lit while its drawer is open, and the drawer's shown buttons
-- left to right in it, a box high, each anchored to the drawer itself;
-- but the friends toast. Blizzard stacks the toast on the alert frame its
-- toasts come from (its BOTTOMLEFT on the frame's TOPLEFT) and puts it back
-- there whenever it likes, so the toast keeps that anchor and the alert
-- frame is moved instead: while the drawer is open, it hangs from the
-- friends slot's foot (by `hang`, measured), so the toast stacked on it
-- fills the slot; while it
-- is shut, it sits on the cog, so the toasts still come from the head.
-- Anchoring the alert frame to the toast would close a loop.
local function Row()
    local r = Ratio()
    placing = true
    Dock((BOX + GAP + 1 + GAP) / r)
    if cog then
        if open then cog:LockHighlight() else cog:UnlockHighlight() end
        local shown, friends = {}, nil
        for _, spec in ipairs(HEAD) do
            local b = _G[spec.name]
            if b and b:IsShown() then
                if spec.alert then friends = 1 + #shown * BOX end
                table.insert(shown, b)
            end
        end
        local toast = _G.QuickJoinToastButton
        local function Hang()
            Put(ChatAlertFrame, "TOPLEFT", tray, "BOTTOMLEFT", friends / r, hang)
        end
        if ChatAlertFrame then
            ChatAlertFrame:SetSize(BOX / r, BOX / r)
            if open and friends then
                Hang()
            else
                Put(ChatAlertFrame, "CENTER", cog, "CENTER", 0, 0)
            end
        end
        for i, b in ipairs(shown) do
            b:SetSize(BOX, BOX)
            if b.medalluinGlyph then b.medalluinGlyph:SetSize(GLYPH, GLYPH) end
            if b == toast and ChatAlertFrame then
                -- Blizzard's own stack, at whatever offset it chose: only
                -- put back on the alert frame if it is somewhere else
                if select(2, b:GetPoint(1)) ~= ChatAlertFrame then
                    Put(b, "BOTTOMLEFT", ChatAlertFrame, "TOPLEFT", 0, 0)
                end
            else
                Put(b, "LEFT", tray, "LEFT", 1 + (i - 1) * BOX, 0)
            end
        end
        -- Blizzard's stack is not quite flush: the toast's middle measured
        -- against the drawer's (both in the drawer's units), and the alert
        -- frame moved by what is missing
        if open and friends and ChatAlertFrame and toast and toast:GetParent() == tray then
            local top, bottom, high, low = toast:GetTop(), toast:GetBottom(), tray:GetTop(), tray:GetBottom()
            if top and bottom and high and low then
                local miss = ((high + low) - (top + bottom)) / 2
                if math.abs(miss) > 0.25 then
                    hang = hang + miss / r
                    Hang()
                end
            end
        end
        tray:SetWidth(#shown * BOX + 2)
        tray:SetShown(open and #shown > 0)
    end
    placing = false
end

-- Where the messages go, in the panel, from the scale of the chat to the
-- panel's; and the dock's room for the cog, in the chat's.
local function Measure()
    local r = ChatFrame1:GetEffectiveScale() / panel:GetEffectiveScale()
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", panel, "TOPLEFT", L.chatPad, -L.chatTop * r)
    area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -L.chatRight * r, L.chatPad)
    Row()
end

-- ChatFrame1 into the panel; the docked windows are anchored to it.
local function Place()
    placing = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("TOPLEFT", area, "TOPLEFT")
    ChatFrame1:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    placing = false
end

-- ------------------------------------------------------------------ tabs
-- Three slices of a tab texture over the tab's whole face, the middle
-- stretched: the side panel's tabs (side.lua).
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

-- The selected tab marked and its name in gold, the others dim; after
-- Blizzard's colours (FCFTab_UpdateColors).
local function Selected(tab, selected)
    if not tab.medalluin then return end
    tab.mark:SetShown(selected and true or false)
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    local c = selected and GOLD or DIM
    if text then text:SetTextColor(c[1], c[2], c[3]) end
end

-- The windows' box tab (ns.window.Face) instead of Blizzard's pill, slim:
-- on a slot across the middle of Blizzard's taller tab, its name centred
-- in it (Row stands the slots on the hairline).
local function Slot(tab)
    tab.medalluinSlot:SetHeight(SLIM / Ratio())
end

local function SkinTab(tab)
    if not tab or tab.medalluin then return end
    for _, key in ipairs(TAB_ART) do Gone(tab[key]) end
    local slot = CreateFrame("Frame", nil, tab)
    slot:SetPoint("LEFT")
    slot:SetPoint("RIGHT")
    tab.medalluinSlot = slot
    Slot(tab)
    ns.window.Face(tab, slot)
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", slot, "CENTER")
    end
    tab.medalluin = true
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

-- The backing shows only while the box is typed in: at rest (the Classic
-- chat style keeps the box) it was an empty bar over the messages' foot.
local function Lit(box)
    local on = box.medalluinDressed and box:HasFocus() and true or false
    for _, t in ipairs(box.medalluin or {}) do t:SetShown(on) end
end

local function EditBox(frame)
    local box = frame.editBox
    if not box then return end
    local own, focus = BoxArt(box)
    for _, t in ipairs(own) do Gone(t) end
    for _, t in ipairs(focus) do Gone(t) end
    if not box.medalluin then
        box.medalluin = {}
        local ink = ns.colors.ink
        for i, colour in ipairs({ { 0.54, 0.44, 0.20, 0.9 }, { ink[1], ink[2], ink[3], 0.9 } }) do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, i)
            t:SetPoint("TOPLEFT", i - 1, 1 - i)
            t:SetPoint("BOTTOMRIGHT", 1 - i, i - 1)
            t:SetColorTexture(unpack(colour))
            box.medalluin[i] = t
        end
        box:HookScript("OnEditFocusGained", Lit)
        box:HookScript("OnEditFocusLost", Lit)
    end
    box.medalluinDressed = true
    Lit(box)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", edit, "TOPLEFT")
    box:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT")
end

-- Blizzard clamps a chat window to the screen with room at its left for
-- the button column (FCF_UpdateButtonSide); in the panel, at the screen's
-- edge, that pushed the messages and the tabs right, out of the box. A
-- docked window keeps no such room; it gets Blizzard's back when it leaves.
local dressed, clamping = {}, false
local function Unclamp(frame)
    if clamping or not dressed[frame] then return end
    clamping = true
    frame:SetClampRectInsets(0, 0, 0, 0)
    clamping = false
end

local function Dress(frame)
    if not frame or dressed[frame] then return end
    dressed[frame] = true
    for _, t in ipairs(Textures(frame)) do Gone(t) end
    Gone(frame.ResizeButton)            -- the panel is a fixed size
    EditBox(frame)
    if frame.SetClampRectInsets then
        if not frame.medalluinClamp then
            frame.medalluinClamp = { frame:GetClampRectInsets() }
            hooksecurefunc(frame, "SetClampRectInsets", Unclamp)
        end
        Unclamp(frame)
    end
end

-- Back to Blizzard's look, its size grip (on an unlocked window) and its
-- edit box anchors (FloatingChatFrame.xml).
local function Undress(frame)
    if not frame or not dressed[frame] or frame == ChatFrame1 then return end
    dressed[frame] = nil
    if frame.medalluinClamp then frame:SetClampRectInsets(unpack(frame.medalluinClamp)) end
    for _, t in ipairs(Textures(frame)) do Back(t, true) end
    Back(frame.ResizeButton, not frame.isLocked)
    local box = frame.editBox
    if box then
        local own, focus = BoxArt(box)
        for _, t in ipairs(own) do Back(t, true) end
        for _, t in ipairs(focus) do Back(t) end
        box.medalluinDressed = nil
        Lit(box)
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

-- ------------------------------------------------------------------ head
-- A head button's own art, out of sight: its states' textures, and the
-- icons Blizzard draws on it (the friends toast's two, and its count of
-- friends online: nobody reads it). Again whenever Blizzard sets a state's
-- art.
local STATES = { "Normal", "Pushed", "Disabled", "Highlight" }
local function Bare(b)
    for _, state in ipairs(STATES) do
        local get = b["Get" .. state .. "Texture"]
        local t = get and get(b)
        if t then t:SetAlpha(0) end
    end
    for _, key in ipairs({ "Icon", "FriendsButton", "QueueButton", "FriendCount" }) do
        if b[key] and b[key].SetAlpha then b[key]:SetAlpha(0) end
    end
end

-- A gold glyph instead, lit under the mouse, as the quest tracker's footer
local function Flat(b, glyph)
    Bare(b)
    for _, state in ipairs(STATES) do
        for _, kind in ipairs({ "Texture", "Atlas" }) do
            if b["Set" .. state .. kind] then hooksecurefunc(b, "Set" .. state .. kind, Bare) end
        end
    end
    local g = b:CreateTexture(nil, "OVERLAY")
    g:SetTexture(PARTS .. glyph)
    g:SetPoint("CENTER")
    local lit = b:CreateTexture(nil, "HIGHLIGHT")
    lit:SetTexture(PARTS .. glyph)
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.35)
    lit:SetAllPoints(g)
    b.medalluinGlyph = g
end

-- The cog at the tab row's right end, in a box as the tabs are but up to
-- the row's top, and its drawer: another box (ns.window.Face), out to the
-- right over the world, sharing the cog's edge. Both in MEDIUM strata,
-- over the chat frames and the dock (BACKGROUND, under them, took the
-- cog's clicks). A gold divider stands before the cog, where the tabs end.
local function Cog()
    cog = CreateFrame("Button", "MedalluinChatCog", head)
    cog:SetFrameStrata("MEDIUM")
    cog:SetFrameLevel(ChatFrame1:GetFrameLevel() + 5)
    cog:SetSize(BOX, BOX)
    cog:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, FOOT)
    ns.window.Face(cog)
    local g = cog:CreateTexture(nil, "ARTWORK")
    g:SetTexture(PARTS .. "menu")
    g:SetSize(GLYPH, GLYPH)
    g:SetPoint("CENTER")
    local lit = cog:CreateTexture(nil, "HIGHLIGHT")
    lit:SetTexture(PARTS .. "menu")
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.35)
    lit:SetAllPoints(g)
    cog:SetScript("OnClick", function()
        open = not open
        Row()
    end)
    cog:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_TOP", { title = "Chat buttons", { "body", "The chat menu, friends and channels." } })
    end)
    cog:SetScript("OnLeave", GameTooltip_Hide)
    tray = CreateFrame("Frame", "MedalluinChatDrawer", head)
    tray:SetFrameStrata("MEDIUM")
    tray:SetFrameLevel(cog:GetFrameLevel())
    tray:SetHeight(BOX)
    tray:SetPoint("LEFT", cog, "RIGHT", -1, 0)
    ns.window.Face(tray)
    -- the divider between the tabs and the cog, as tall as the cog
    local divider = head:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    divider:SetSize(1, BOX)
    divider:SetPoint("BOTTOMRIGHT", cog, "BOTTOMLEFT", -GAP, 0)
    ns.chat.cog, ns.chat.drawer, ns.chat.divider = cog, tray, divider
end

-- The column's buttons come to the drawer (its art went with the window's,
-- in CHAT_FRAME_TEXTURES), and back to their place there when Blizzard
-- moves one or shows or hides one.
local function Head()
    local function Again()
        if not placing then Row() end
    end
    Cog()
    for _, spec in ipairs(HEAD) do
        local b = _G[spec.name]
        if b then
            if spec.glyph then Flat(b, spec.glyph) end
            b:SetParent(tray)
            b:SetFrameLevel(tray:GetFrameLevel() + 2)
            hooksecurefunc(b, "SetPoint", Again)
            if spec.alert and ChatAlertFrame then hooksecurefunc(ChatAlertFrame, "SetPoint", Again) end
            b:HookScript("OnShow", Again)
            b:HookScript("OnHide", Again)
        end
    end
    if GENERAL_CHAT_DOCK then hooksecurefunc(GENERAL_CHAT_DOCK, "SetPoint", Again) end
    Row()
end

-- ----------------------------------------------------------------- build
local function Build()
    local strip = ns.strips[-1]
    local margin = ns.window.band - SHORTER
    local foot = margin + RULE                  -- the panel's foot, over the margin's rule
    local top = foot + L.chatHeight + TABS      -- the tabs' top
    chatBox = CreateFrame("Frame", "MedalluinChat", strip)
    chatBox:SetFrameStrata("BACKGROUND")
    chatBox:SetWidth(L.chatLeft + L.chatWidth)
    local dress = ns.window.Dress(chatBox, margin)
    panel = CreateFrame("Frame", nil, chatBox)
    panel:SetPoint("BOTTOMLEFT", PAD, foot)
    panel:SetPoint("BOTTOMRIGHT", -PAD, foot)
    panel:SetHeight(L.chatHeight)
    area = CreateFrame("Frame", nil, panel)
    -- the edit box over the margin, beside the medallion
    edit = CreateFrame("Frame", nil, chatBox)
    edit:SetPoint("BOTTOMLEFT", L.chatLeft + PAD / 2, 2)
    edit:SetPoint("TOPRIGHT", chatBox, "BOTTOMRIGHT", -PAD, margin - 2)
    -- the tab row, over the panel: the cog at its right end
    head = CreateFrame("Frame", nil, chatBox)
    head:SetPoint("BOTTOMLEFT", panel, "TOPLEFT")
    head:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT")
    head:SetHeight(TABS)
    -- the hairline between the tabs and the messages
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    ns.chat = { box = chatBox, dress = dress, panel = panel, area = area, edit = edit, head = head, top = top }

    chatBox:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, L.stripHeight)
    chatBox:SetHeight(top + PAD)
    -- The box's reach up to the screen's top, the quest tracker's full view
    -- in it: a box of its own on the chat's, its foot the chat box's top
    -- edge, so the two read as one; and the tracker fading fades it alone,
    -- the chat box's top corners coming back as it goes.
    local reach = CreateFrame("Frame", nil, strip)
    reach:SetFrameStrata("BACKGROUND")
    reach:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    reach:SetPoint("BOTTOMRIGHT", chatBox, "TOPRIGHT", 0, -1)
    local reachDress = ns.window.Dress(reach, 0)
    reachDress.rule:Hide()
    local corners = {}
    for point, lines in pairs(reachDress.corners) do
        if point:find("^BOTTOM") then for _, t in ipairs(lines) do t:Hide() end end
    end
    for point, lines in pairs(dress.corners) do
        if point:find("^TOP") then for _, t in ipairs(lines) do table.insert(corners, t) end end
    end
    -- up: the reach shown, as much of it as alpha (the tracker's fade)
    function ns.chat.Reach(up, alpha)
        alpha = up and (alpha or 1) or 0
        reach:SetShown(up and true or false)
        reach:SetAlpha(alpha)
        for _, t in ipairs(corners) do t:SetAlpha(1 - alpha) end
    end
    ns.chat.reach = reach
    ns.chat.Reach(false)
    -- the timeless buffs along the margin, beside the medallion
    ns.BuffRow({ x = L.chatLeft + PAD, y = ns.stripArt.height - L.stripHeight - margin / 2 })

    Measure()
    Place()
    Sweep()
    -- Blizzard re-places the chat frame from its saved layout and Edit Mode
    hooksecurefunc(ChatFrame1, "SetPoint", function()
        if not placing then Place() end
    end)
    -- the tabs never fade: their box and colour already say which one is
    -- chosen. FCFTab_UpdateAlpha reads these, for each docked tab, every
    -- time the dock's tabs are fitted (Dock, from Head's first Row on).
    for _, key in ipairs({ "SELECTED", "ALERTING", "NORMAL" }) do
        _G["CHAT_FRAME_TAB_" .. key .. "_MOUSEOVER_ALPHA"] = 1
        _G["CHAT_FRAME_TAB_" .. key .. "_NOMOUSE_ALPHA"] = 1
    end
    if ChatFrame1.buttonFrame then Head() end
    -- a scale change moves the room the chat's own pieces need
    local function Rescaled()
        for _, frame in ipairs(Frames()) do
            local tab = _G[frame:GetName() .. "Tab"]
            if tab and tab.medalluinSlot then Slot(tab) end
        end
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
