-- The action buttons: Blizzard's own, moved onto the bar's windows. Keeping
-- Blizzard's buttons keeps their secure clicks, key bindings, drag and drop
-- and bar paging without a library, and by default their art too, so the
-- bar looks as Blizzard's does. The Bare icons option restyles them as
-- WeakAuras-style icons instead.
--
--   row 1   ActionButton1-12               action bar 1 (paged by stance, stealth)
--   row 2   MultiBarBottomLeftButton1-12   action bar 2, with Rows at 2 or 3
--   row 3   MultiBarBottomRightButton1-12  action bar 3, with Rows at 3
--
-- Only when the Action bar option is on (settings.lua); otherwise every bar
-- stays Blizzard's, or whichever action-bar addon the player runs. A bar
-- the Rows option leaves out stays Blizzard's too.
--
-- With Bare icons, what a WeakAuras icon shows that Blizzard's does not is drawn here: the
-- cooldown time centred on the icon, keybind text at the top-right, and range as a red tint.
-- Where the cooldown frame can draw its own countdown (Forever, retail) that text is used,
-- restyled: there a cooldown's numbers may be secret, and Lua cannot subtract them.
local _, ns = ...

local buttons = {}
ns.actionButtons = buttons

local function Part(btn, key, suffix)
    return btn[key] or _G[btn:GetName() .. (suffix or key)]
end

local function Hide(region)
    if region then region:SetAlpha(0) end
end

local function Overlay(btn, r, g, b, a)
    local t = btn:CreateTexture()
    t:SetColorTexture(r, g, b, a)
    t:SetAllPoints(btn.medaluinIcon)
    return t
end

-- Blizzard redraws a button's frame art: Classic with SetNormalTexture,
-- the Edit Mode clients with SetNormalAtlas and UpdateButtonArt (which also
-- puts its atlas on whatever the pushed texture is, here ours).
local function Reskin(btn)
    local normal = btn:GetNormalTexture()
    Hide(normal)
    ns.Mute(normal)
    if btn.medaluinPushed then
        btn.medaluinPushed:SetColorTexture(0, 0, 0, 0.35)
        btn:SetPushedTexture(btn.medaluinPushed)
    end
end

-- The cooldown's own countdown, where it has one; false keeps the ticker's.
local function NativeCountdown(cd)
    if not cd.GetCountdownFontString then return false end
    cd:SetHideCountdownNumbers(false)
    -- the global cooldown (1.5s) gets the swipe but no number
    if cd.SetMinimumCountdownDuration then cd:SetMinimumCountdownDuration(1600) end
    local fs = cd:GetCountdownFontString()
    if fs then
        fs:SetFont(ns.font, 14, "OUTLINE")
        fs:SetTextColor(unpack(ns.colors.text))
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, 0)
    end
    return true
end

-- Format raw keybind names into clean, readable abbreviations
local function FormatHotkey(text)
    if not text or text == "" then return "" end
    local range = _G.RANGE_INDICATOR
    if (range and text == range) or text == "•" or text == "●" or text == " " then
        return ""
    end
    text = text:gsub("KEY_", "")
    text = text:gsub("SHIFT%-", "s-")
    text = text:gsub("CTRL%-", "c-")
    text = text:gsub("ALT%-", "a-")
    text = text:gsub("META%-", "m-")
    text = text:gsub("STRG%-", "c-")
    text = text:gsub("BUTTON(%d+)", "M%1")
    text = text:gsub("MOUSEWHEELUP", "WU")
    text = text:gsub("MOUSEWHEELDOWN", "WD")
    text = text:gsub("NUMPAD(%d+)", "N%1")
    text = text:gsub("PAGEUP", "PU")
    text = text:gsub("PAGEDOWN", "PD")
    text = text:gsub("SPACE", "Spc")
    text = text:gsub("INSERT", "Ins")
    text = text:gsub("DELETE", "Del")
    text = text:gsub("HOME", "Hm")
    text = text:gsub("END", "End")
    return text
end

local function ButtonBindingName(btn)
    local name = btn:GetName()
    if not name then return end
    local num = name:match("^ActionButton(%d+)$")
    if num then return "ACTIONBUTTON" .. num end
    num = name:match("^MultiBarBottomLeftButton(%d+)$")
    if num then return "MULTIACTIONBAR1BUTTON" .. num end
    num = name:match("^MultiBarBottomRightButton(%d+)$")
    if num then return "MULTIACTIONBAR2BUTTON" .. num end
    num = name:match("^MultiBarRightButton(%d+)$")
    if num then return "MULTIACTIONBAR3BUTTON" .. num end
    num = name:match("^MultiBarLeftButton(%d+)$")
    if num then return "MULTIACTIONBAR4BUTTON" .. num end
    return btn.buttonType and (btn.buttonType .. (btn:GetID() or ""))
end

local function UpdateHotkey(btn)
    local hotkey = btn.medaluinHotkey or Part(btn, "HotKey")
    if not hotkey then return end
    local text = hotkey:GetText()
    local range = _G.RANGE_INDICATOR
    if not text or text == "" or (range and text == range) or text == "•" or text == "●" then
        local GetBindingKey = _G.GetBindingKey
        local GetBindingText = _G.GetBindingText
        if GetBindingKey then
            local bName = ButtonBindingName(btn)
            local key = bName and GetBindingKey(bName)
            if key then
                text = GetBindingText and GetBindingText(key, "KEY_") or key
            end
        end
    end
    local formatted = FormatHotkey(text)
    if formatted and formatted ~= "" then
        hotkey.medaluinSetting = true
        hotkey:SetText(formatted)
        hotkey.medaluinSetting = false
        hotkey:SetTextColor(unpack(ns.colors.text))
        hotkey:SetAlpha(1)
        hotkey:Show()
    else
        -- guarded like the set above: the SetText hook would call us again, forever
        hotkey.medaluinSetting = true
        hotkey:SetText("")
        hotkey.medaluinSetting = false
        hotkey:Hide()
    end
end

local function Style(btn)
    local icon = Part(btn, "icon", "Icon")
    btn.medaluinIcon = icon
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)       -- past the icon's own border
    if btn.IconMask then icon:RemoveMaskTexture(btn.IconMask) end

    Hide(Part(btn, "Border"))
    Hide(Part(btn, "Name"))
    Hide(_G[btn:GetName() .. "FloatingBG"])
    Hide(btn.SlotBackground)
    Hide(btn.SlotArt)
    ns.Mute(btn.NewActionTexture)              -- the glow on a newly learned spell
    if btn.SpellHighlightTexture then btn.SpellHighlightTexture:SetAllPoints(icon) end
    local flash = Part(btn, "Flash")
    if flash then flash:SetAllPoints(icon) end

    btn:SetHighlightTexture(Overlay(btn, 1, 1, 1, 0.15))
    btn.medaluinPushed = Overlay(btn, 0, 0, 0, 0.35)
    if btn.SetCheckedTexture then
        btn:SetCheckedTexture(Overlay(btn, 0.77, 0.65, 0.34, 0.35))
    end
    Reskin(btn)
    for _, method in ipairs({ "SetNormalTexture", "SetNormalAtlas", "UpdateButtonArt" }) do
        if btn[method] then hooksecurefunc(btn, method, Reskin) end
    end

    local cd = Part(btn, "cooldown", "Cooldown")
    cd:ClearAllPoints()
    cd:SetAllPoints(icon)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.6) end
    btn.medaluinNative = NativeCountdown(cd)
    if not btn.medaluinNative and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end

    -- Text rides above the cooldown swipe, which would otherwise dim it.
    local over = CreateFrame("Frame", nil, btn)
    over:SetAllPoints(icon)
    over:SetFrameLevel(cd:GetFrameLevel() + 1)
    btn.medaluinTimer = ns.Text(over, 16)
    btn.medaluinTimer:SetFont(ns.font, 16, "OUTLINE")
    btn.medaluinTimer:SetPoint("CENTER", 0, 0)
    local count = Part(btn, "Count")
    if count then
        count:SetParent(over)
        count:SetFont(ns.font, 12, "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local hotkey = Part(btn, "HotKey")
    if hotkey then
        btn.medaluinHotkey = hotkey
        hotkey:SetParent(over)
        hotkey:SetFont(ns.font, 11, "OUTLINE")
        hotkey:SetTextColor(unpack(ns.colors.text))
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", over, "TOPRIGHT", -1, -1)
        hotkey:SetDrawLayer("OVERLAY")
        hotkey:SetAlpha(1)
        hooksecurefunc(hotkey, "SetText", function(self)
            if self.medaluinSetting then return end
            UpdateHotkey(btn)
        end)
        hooksecurefunc(hotkey, "SetVertexColor", function(self)
            if self.medaluinSetting then return end
            self.medaluinSetting = true
            self:SetTextColor(unpack(ns.colors.text))
            self.medaluinSetting = false
        end)
        UpdateHotkey(btn)
    end
end
ns.StyleButton = Style

local function Adopt(btn, slot)
    btn:SetParent(ns.actionBar)
    btn:SetFrameStrata(ns.actionBar:GetFrameStrata())
    btn:SetFrameLevel(ns.levels.actionButtons)
    ns.PlaceOnBar(btn, slot)
    if ns.db.bareIcons then Style(btn) end
    table.insert(buttons, btn)
end

-- Blizzard hides countdown numbers unless the player's interface option
-- asks for them; bare icons always show them.
if ActionButton_UpdateCooldownNumberHidden then
    hooksecurefunc("ActionButton_UpdateCooldownNumberHidden", function(btn)
        if btn.medaluinNative then btn.cooldown:SetHideCountdownNumbers(false) end
    end)
end

if _G.ActionButton_UpdateHotkeys then
    hooksecurefunc("ActionButton_UpdateHotkeys", function(btn)
        if ns.db.bareIcons and btn and btn.medaluinHotkey then
            UpdateHotkey(btn)
        end
    end)
end

ns.On("UPDATE_BINDINGS", function()
    if not ns.db.bareIcons then return end
    for _, btn in ipairs(buttons) do
        UpdateHotkey(btn)
    end
end)

local ticker = CreateFrame("Frame")
ticker:Hide()

-- Each row's buttons, and the Blizzard bar they leave. Action bar 1's is
-- MainActionBar on the newest Edit Mode clients, MainMenuBar before them (on
-- Classic Era the bottom bars hang off MainMenuBar too, so they go with it).
local ROWS = {
    { "ActionButton", function() return MainActionBar or MainMenuBar end },
    { "MultiBarBottomLeftButton", function() return MultiBarBottomLeft end },
    { "MultiBarBottomRightButton", function() return MultiBarBottomRight end },
}

-- Secure buttons only move out of combat; a /reload in combat waits. The
-- tray is not secure, so it is drawn at once.
ns.On("PLAYER_LOGIN", function()
    if not ns.db.actionBar then return end
    local rows = math.max(1, math.min(#ROWS, tonumber(ns.db.rows) or 1))
    local _, slots = ns.BuildBar(rows)
    ns.OutOfCombat(function()
        for r = 1, rows do
            local prefix, bar = ROWS[r][1], ROWS[r][2]()
            for i, slot in ipairs(slots[r]) do Adopt(_G[prefix .. i], slot) end
            ns.Kill(bar)
        end
        -- Blizzard's own art keeps its own range and cooldown display
        if ns.db.bareIcons then ticker:Show() end
    end)
end)

-- --------------------------------------------------------------- the ticker
-- Bare icons only. Ten times a second: the usable/range tint, and the cooldown clock where
-- the cooldown frame cannot draw one. The global cooldown (1.5s and under)
-- gets the swipe but no number.
local function Clock(t)
    if t >= 3600 then return format("%dh", math.ceil(t / 3600)) end
    if t >= 60 then return format("%d:%02d", math.floor(t / 60), math.floor(t % 60)) end
    return format("%d", math.ceil(t))
end

local function Remaining(action, now)
    local start, duration, enable = ns.ActionCooldown(action)
    if ns.IsSecret(start) or ns.IsSecret(duration) then return end
    if enable == 0 or enable == false or not start or start == 0 or duration <= 1.5 then return end
    local left = start + duration - now
    if left > 0 then return left end
end

local function Tint(btn, action)
    local usable, noMana = ns.IsUsableAction(action)
    local inRange = ns.IsActionInRange(action)
    if ns.IsSecret(usable) or ns.IsSecret(noMana) or ns.IsSecret(inRange) then
        btn.medaluinIcon:SetVertexColor(1, 1, 1)
    elseif inRange == false or inRange == 0 then
        btn.medaluinIcon:SetVertexColor(0.85, 0.25, 0.25)
    elseif usable then
        btn.medaluinIcon:SetVertexColor(1, 1, 1)
    elseif noMana then
        btn.medaluinIcon:SetVertexColor(0.4, 0.45, 0.9)
    else
        btn.medaluinIcon:SetVertexColor(0.45, 0.45, 0.45)
    end
end

local function Update(btn, now)
    local action, timer = btn.action, btn.medaluinTimer
    if not action or not ns.HasAction(action) then
        timer:SetText("")
        return
    end
    Tint(btn, action)
    if btn.medaluinNative then return end
    local left = Remaining(action, now)
    local text = left and Clock(left) or ""
    if text ~= timer:GetText() then
        timer:SetFont(ns.font, #text > 2 and 13 or 16, "OUTLINE")
        timer:SetText(text)
    end
end

local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local now = GetTime()
    for _, btn in ipairs(buttons) do
        if btn:IsVisible() then Update(btn, now) end
    end
end)
