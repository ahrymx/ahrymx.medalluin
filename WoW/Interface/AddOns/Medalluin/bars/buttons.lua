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
local extraButtons = {}
ns.actionButtons = buttons
ns.extraButtons = extraButtons

-- Extra bar buttons: empty slots (no action placed, and no grid active)
-- hide completely along with their keybind text. Action Bar 1 and the
-- light console profile center grid (bar7) stay visible when empty.
local gridShown = false

local function ButtonShowsGrid()
    if gridShown or ns.keybinding then return true end
    local GetCursorInfo = _G.GetCursorInfo
    if GetCursorInfo and GetCursorInfo() ~= nil then return true end
    return false
end

local function ButtonHasAction(btn)
    if btn.HasAction then
        local has = btn:HasAction()
        if has ~= nil then return has and true or false end
    end
    local action = btn.action
    if not action then
        if btn.CalculateAction then
            action = btn:CalculateAction()
        elseif _G.ActionButton_CalculateAction then
            action = _G.ActionButton_CalculateAction(btn)
        end
    end
    return (action and ns.HasAction(action)) and true or false
end

local function Part(btn, key, suffix)
    return btn[key] or _G[btn:GetName() .. (suffix or key)]
end

local function Hide(region)
    if region then region:SetAlpha(0) end
end

local function Overlay(btn, r, g, b, a)
    local t = btn:CreateTexture()
    t:SetColorTexture(r, g, b, a)
    t:SetAllPoints(btn.medalluinIcon)
    return t
end

-- Blizzard redraws a button's frame art: Classic with SetNormalTexture,
-- the Edit Mode clients with SetNormalAtlas and UpdateButtonArt (which also
-- puts its atlas on whatever the pushed texture is, here ours).
local function Reskin(btn)
    local normal = btn:GetNormalTexture()
    Hide(normal)
    ns.Mute(normal)
    if btn.medalluinPushed then
        btn.medalluinPushed:SetColorTexture(0, 0, 0, 0.35)
        btn:SetPushedTexture(btn.medalluinPushed)
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

-- keybind.lua names every button's command; its binder sets them
local function ButtonBindingName(btn)
    return ns.BindingCommand and ns.BindingCommand(btn)
        or btn.buttonType and (btn.buttonType .. (btn:GetID() or ""))
end

-- Keybind text at size 0 is hidden, on the buttons the bar's options look
-- after (ApplyLook); the overhead's, which share Style, keep theirs.
local function HotkeyAlpha(btn)
    return (btn.medalluinLook and (tonumber(ns.db.hotkeySize) or 1) <= 0) and 0 or 1
end

local function UpdateHotkey(btn)
    local hotkey = btn.medalluinHotkey or Part(btn, "HotKey")
    if not hotkey then return end
    if ns.db.hideEmpty and btn.medalluinExtra and not (ButtonHasAction(btn) or ButtonShowsGrid()) then
        hotkey.medalluinSetting = true
        hotkey:SetText("")
        hotkey.medalluinSetting = false
        hotkey:Hide()
        return
    end
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
        hotkey.medalluinSetting = true
        hotkey:SetText(formatted)
        hotkey.medalluinSetting = false
        hotkey:SetTextColor(unpack(ns.colors.text))
        hotkey:SetAlpha(HotkeyAlpha(btn))
        hotkey:Show()
    else
        -- guarded like the set above: the SetText hook would call us again, forever
        hotkey.medalluinSetting = true
        hotkey:SetText("")
        hotkey.medalluinSetting = false
        hotkey:Hide()
    end
end

local function UpdateExtraButton(btn)
    if not btn or not btn.medalluinExtra or btn.medalluinUpdating then return end
    btn.medalluinUpdating = true
    local show = not ns.db.hideEmpty or ButtonHasAction(btn) or ButtonShowsGrid()
    local alpha = show and 1 or 0
    if btn:GetAlpha() ~= alpha then
        btn.medalluinSettingAlpha = true
        btn:SetAlpha(alpha)
        btn.medalluinSettingAlpha = false
    end
    local hotkey = btn.medalluinHotkey or Part(btn, "HotKey")
    if not show then
        if hotkey then
            hotkey.medalluinSetting = true
            hotkey:SetText("")
            hotkey.medalluinSetting = false
            hotkey:Hide()
        end
    else
        if ns.db.bareIcons then
            UpdateHotkey(btn)
        else
            if hotkey and hotkey:GetText() and hotkey:GetText() ~= ""
                and hotkey:GetText() ~= _G.RANGE_INDICATOR then
                hotkey:Show()
            else
                UpdateHotkey(btn)
            end
        end
    end
    btn.medalluinUpdating = false
end

local function UpdateAllExtraButtons(slot)
    for _, btn in ipairs(extraButtons) do
        local a = btn.action or (btn.CalculateAction and btn:CalculateAction())
        if not slot or slot == 0 or a == slot then
            UpdateExtraButton(btn)
        end
    end
end
ns.UpdateAllExtraButtons = UpdateAllExtraButtons

local function Style(btn)
    local icon = Part(btn, "icon", "Icon")
    btn.medalluinIcon = icon
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
    btn.medalluinPushed = Overlay(btn, 0, 0, 0, 0.35)
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
    btn.medalluinNative = NativeCountdown(cd)
    if not btn.medalluinNative and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end

    -- Text rides above the cooldown swipe, which would otherwise dim it.
    local over = CreateFrame("Frame", nil, btn)
    over:SetAllPoints(icon)
    over:SetFrameLevel(cd:GetFrameLevel() + 1)
    btn.medalluinTimer = ns.Text(over, 16)
    btn.medalluinTimer:SetFont(ns.font, 16, "OUTLINE")
    btn.medalluinTimer:SetPoint("CENTER", 0, 0)
    local count = Part(btn, "Count")
    if count then
        count:SetParent(over)
        count:SetFont(ns.font, 12, "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local hotkey = Part(btn, "HotKey")
    if hotkey then
        btn.medalluinHotkey = hotkey
        hotkey:SetParent(over)
        hotkey:SetFont(ns.font, 11, "OUTLINE")
        hotkey:SetTextColor(unpack(ns.colors.text))
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", over, "TOPRIGHT", -1, -1)
        hotkey:SetDrawLayer("OVERLAY")
        hotkey:SetAlpha(1)
        hooksecurefunc(hotkey, "SetText", function(self)
            if self.medalluinSetting then return end
            UpdateHotkey(btn)
        end)
        hooksecurefunc(hotkey, "SetVertexColor", function(self)
            if self.medalluinSetting then return end
            self.medalluinSetting = true
            self:SetTextColor(unpack(ns.colors.text))
            self.medalluinSetting = false
        end)
        UpdateHotkey(btn)
    end
end
ns.StyleButton = Style

-- ------------------------------------------------------------ the look
-- The Action Bar page's Text and Cooldowns options, on the bar's buttons
-- (bars 1-3 and the light profile's grid), bare icons or Blizzard's art.
-- A size scales what the button drew on its own, read off it the first time,
-- so 1 leaves Blizzard's art and Style's sizes as they were.
local function Scale(region, base, scale)
    if base[1] then region:SetFont(base[1], math.max(1, math.floor(base[2] * scale + 0.5)), base[3]) end
end

local function ApplyCooldown(btn)
    local cd = Part(btn, "cooldown", "Cooldown")
    if not cd then return end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(ns.db.cooldownSwipe and true or false) end
    if cd.SetDrawEdge then cd:SetDrawEdge(ns.db.cooldownEdge and true or false) end
    -- on, the flash is left to Blizzard, which turns it off on a faded bar
    if cd.SetDrawBling and not ns.db.cooldownBling then cd:SetDrawBling(false) end
    -- the ticker's buttons draw their own number and keep the cooldown's hidden
    local ticker = btn.medalluinTimer and not btn.medalluinNative
    if cd.SetHideCountdownNumbers and not ticker then
        local mode = ns.db.cooldownText
        if mode == "show" or mode == "hide" then
            cd:SetHideCountdownNumbers(mode == "hide")
            btn.medalluinForcedNumbers = true
        elseif btn.medalluinNative then
            cd:SetHideCountdownNumbers(false)          -- bare icons show them
        elseif btn.medalluinForcedNumbers then
            -- back to the game's Show cooldown numbers option
            btn.medalluinForcedNumbers = nil
            cd:SetHideCountdownNumbers(not (GetCVarBool and GetCVarBool("countdownForCooldowns")))
        end
    end
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        btn.medalluinCountdownFont = btn.medalluinCountdownFont or { fs:GetFont() }
        Scale(fs, btn.medalluinCountdownFont, tonumber(ns.db.cooldownTextSize) or 1)
    end
end

local function ApplyLook(btn)
    -- a client without the global (below) redraws through the button's own method
    if not btn.medalluinLook and not _G.ActionButton_UpdateCooldown and btn.UpdateCooldown then
        hooksecurefunc(btn, "UpdateCooldown", ApplyCooldown)
    end
    btn.medalluinLook = true
    local hotkey = btn.medalluinHotkey or Part(btn, "HotKey")
    if hotkey then
        btn.medalluinHotkeyFont = btn.medalluinHotkeyFont or { hotkey:GetFont() }
        local size = tonumber(ns.db.hotkeySize) or 1
        if size > 0 then Scale(hotkey, btn.medalluinHotkeyFont, size) end
        hotkey:SetAlpha(HotkeyAlpha(btn))
    end
    ApplyCooldown(btn)
end
ns.ApplyButtonLook = ApplyLook

-- Blizzard redraws a cooldown (and sets its edge and flash) each time one
-- starts: the options go back on after it.
if _G.ActionButton_UpdateCooldown then
    hooksecurefunc("ActionButton_UpdateCooldown", function(btn)
        if btn and btn.medalluinLook then ApplyCooldown(btn) end
    end)
end

for _, key in ipairs({ "hotkeySize", "cooldownText", "cooldownTextSize", "cooldownSwipe", "cooldownEdge" }) do
    ns.OnSetting(key, function()
        for _, btn in ipairs(buttons) do ApplyLook(btn) end
    end)
end
ns.OnSetting("cooldownBling", function(on)
    for _, btn in ipairs(buttons) do
        local cd = Part(btn, "cooldown", "Cooldown")
        if cd and cd.SetDrawBling then cd:SetDrawBling(on and true or false) end
    end
end)

local function Adopt(btn, slot, parent, isExtra)
    parent = parent or ns.actionBar
    btn:SetParent(parent)
    btn:SetFrameStrata(parent:GetFrameStrata())
    btn:SetFrameLevel(slot[3] < 0 and (ns.levels.art + 2) or ns.levels.actionButtons)
    ns.PlaceOnBar(btn, slot)
    if ns.db.bareIcons then Style(btn) end
    table.insert(buttons, btn)
    if isExtra then
        table.insert(extraButtons, btn)
        btn.medalluinExtra = true
        for _, method in ipairs({ "Update", "UpdateAction", "SetShowGrid", "SetAlpha" }) do
            if btn[method] then
                if method == "SetAlpha" then
                    hooksecurefunc(btn, "SetAlpha", function(self, a)
                        if self.medalluinExtra and not self.medalluinSettingAlpha then
                            local s = not ns.db.hideEmpty or ButtonHasAction(self) or ButtonShowsGrid()
                            local target = s and 1 or 0
                            if a ~= target then
                                self.medalluinSettingAlpha = true
                                self:SetAlpha(target)
                                self.medalluinSettingAlpha = false
                            end
                        end
                    end)
                else
                    hooksecurefunc(btn, method, UpdateExtraButton)
                end
            end
        end
        local hotkey = Part(btn, "HotKey")
        if hotkey then
            hooksecurefunc(hotkey, "Show", function(self)
                if self.medalluinSetting then return end
                if ns.db.hideEmpty and btn.medalluinExtra and not (ButtonHasAction(btn) or ButtonShowsGrid()) then
                    self.medalluinSetting = true
                    self:Hide()
                    self.medalluinSetting = false
                end
            end)
        end
        UpdateExtraButton(btn)
    end
    ApplyLook(btn)
end

-- Blizzard hides countdown numbers unless the player's interface option
-- asks for them; bare icons always show them, and the Cooldown numbers
-- option can say either way on any of the bar's buttons.
if ActionButton_UpdateCooldownNumberHidden then
    hooksecurefunc("ActionButton_UpdateCooldownNumberHidden", function(btn)
        if btn.medalluinLook then
            ApplyCooldown(btn)
        elseif btn.medalluinNative then
            btn.cooldown:SetHideCountdownNumbers(false)
        end
    end)
end

if _G.ActionButton_Update then
    hooksecurefunc("ActionButton_Update", function(btn)
        if btn and btn.medalluinExtra then UpdateExtraButton(btn) end
    end)
end

if _G.ActionButton_ShowGrid then
    hooksecurefunc("ActionButton_ShowGrid", function(btn)
        if btn and btn.medalluinExtra then UpdateExtraButton(btn) end
    end)
end

if _G.ActionButton_HideGrid then
    hooksecurefunc("ActionButton_HideGrid", function(btn)
        if btn and btn.medalluinExtra then UpdateExtraButton(btn) end
    end)
end

if _G.ActionButton_UpdateHotkeys then
    hooksecurefunc("ActionButton_UpdateHotkeys", function(btn)
        if ns.db.bareIcons and btn and btn.medalluinHotkey then
            UpdateHotkey(btn)
        end
    end)
end

ns.On("ACTIONBAR_SHOWGRID", function()
    gridShown = true
    UpdateAllExtraButtons()
end)

ns.On("ACTIONBAR_HIDEGRID", function()
    gridShown = (_G.GetCursorInfo and _G.GetCursorInfo() ~= nil) or false
    UpdateAllExtraButtons()
end)

ns.On("CURSOR_CHANGED", function()
    local hasCursor = (_G.GetCursorInfo and _G.GetCursorInfo() ~= nil) or false
    if hasCursor ~= gridShown then
        gridShown = hasCursor
        UpdateAllExtraButtons()
    end
end)

ns.On("ACTIONBAR_SLOT_CHANGED", function(slot)
    UpdateAllExtraButtons(slot)
end)

ns.On("ACTIONBAR_PAGE_CHANGED", function()
    UpdateAllExtraButtons()
end)

ns.On("UPDATE_BONUS_ACTIONBAR", function()
    UpdateAllExtraButtons()
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    UpdateAllExtraButtons()
end)

ns.On("UPDATE_BINDINGS", function()
    if ns.db.bareIcons then
        for _, btn in ipairs(buttons) do
            UpdateHotkey(btn)
        end
    end
    UpdateAllExtraButtons()
end)

ns.OnSetting("hideEmpty", function()
    UpdateAllExtraButtons()
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
    local tray, slots, extra = ns.BuildBar(rows)
    ns.OutOfCombat(function()
        for r = 1, rows do
            local prefix, bar = ROWS[r][1], ROWS[r][2]()
            local parent = (r == 1) and tray or extra
            for i, slot in ipairs(slots[r]) do Adopt(_G[prefix .. i], slot, parent, r > 1) end
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
        btn.medalluinIcon:SetVertexColor(1, 1, 1)
    elseif inRange == false or inRange == 0 then
        btn.medalluinIcon:SetVertexColor(0.85, 0.25, 0.25)
    elseif usable then
        btn.medalluinIcon:SetVertexColor(1, 1, 1)
    elseif noMana then
        btn.medalluinIcon:SetVertexColor(0.4, 0.45, 0.9)
    else
        btn.medalluinIcon:SetVertexColor(0.45, 0.45, 0.45)
    end
end

local function Update(btn, now)
    local action, timer = btn.action, btn.medalluinTimer
    if btn.medalluinExtra then UpdateExtraButton(btn) end
    if not action or not ns.HasAction(action) then
        if timer then timer:SetText("") end
        return
    end
    Tint(btn, action)
    if btn.medalluinNative then return end
    local left = ns.db.cooldownText ~= "hide" and Remaining(action, now)
    local text = left and Clock(left) or ""
    if text ~= timer:GetText() then
        local scale = btn.medalluinLook and tonumber(ns.db.cooldownTextSize) or 1
        timer:SetFont(ns.font, math.floor((#text > 2 and 13 or 16) * scale + 0.5), "OUTLINE")
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
