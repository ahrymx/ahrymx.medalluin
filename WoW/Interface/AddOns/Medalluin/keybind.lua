-- Key binding on hover: /mdlui kb, or Bind keys on the settings page. While
-- it is on, every action button that takes a binding wears a gold wash; point
-- at one and press a key, a modified key, a mouse button (not the left or
-- right) or the wheel, and that key becomes the button's only binding. Esc
-- over a button removes its keys; Esc anywhere else, Done, or /mdlui kb again
-- ends it. Each change is saved at once, to the binding set in use (account
-- or character), as Blizzard's Keybindings page does.
--
-- Bindings cannot change in combat, so the mode will not start in combat and
-- ends when combat starts. Faded bars come back while it is on
-- (bars/bar.lua's fade asks ns.keybinding).
local _, ns = ...

-- A button's binding command, by its name: Blizzard's bars bind through
-- their own commands, so a key set here shows in Blizzard's Keybindings page
-- too. The centre grid (console/bar7.lua) is Blizzard's Action bar 7, so it
-- binds as bar 7; only where the client has no bar 7 (Classic Era) is it
-- Medalluin's own, with click bindings, the form Blizzard's buttons read a
-- hotkey from when they have no command of their own.
local BARS = {
    { "ActionButton", "ACTIONBUTTON", "Action bar 1", 12 },
    { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON", "Action bar 2", 12 },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON", "Action bar 3", 12 },
    { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON", "Action bar 4", 12 },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON", "Action bar 5", 12 },
    { "MultiBar5Button", "MULTIACTIONBAR5BUTTON", "Action bar 6", 12 },
    { "MultiBar6Button", "MULTIACTIONBAR6BUTTON", "Action bar 7", 12 },
    { "MultiBar7Button", "MULTIACTIONBAR7BUTTON", "Action bar 8", 12 },
    { "StanceButton", "SHAPESHIFTBUTTON", "Stance bar", 10 },
    { "PetActionButton", "BONUSACTIONBUTTON", "Pet bar", 10 },
    { "MedalluinBar7Button", false, "Centre grid", 10 },
}

local function Find(btn)
    local name = btn and btn.GetName and btn:GetName()
    if not name then return end
    for _, bar in ipairs(BARS) do
        local n = name:match("^" .. bar[1] .. "(%d+)$")
        if n then
            return (bar[2] and bar[2] .. n or "CLICK " .. name .. ":LeftButton"), bar[3] .. ", button " .. n
        end
    end
end

-- The binding command a button answers to, or nil when it takes none.
function ns.BindingCommand(btn)
    return (Find(btn))
end

local function Keys(command)
    return { GetBindingKey(command) }
end

-- The centre grid became Blizzard's Action bar 7 (console/bar7.lua): keys
-- bound to the old buttons' clicks go to bar 7's own commands, once, at
-- login. Its own commands press the button through Blizzard's code
-- (MultiActionButtonDown); a click binding clicked it from outside.
function ns.MoveGridBindings(count)
    local moved = false
    for i = 1, count do
        for _, key in ipairs(Keys("CLICK MedalluinBar7Button" .. i .. ":LeftButton")) do
            SetBinding(key, "MULTIACTIONBAR6BUTTON" .. i)
            moved = true
        end
    end
    if moved and SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
end

local function KeyText(key)
    return GetBindingText and GetBindingText(key, "KEY_") or key
end

-- Keys a binding never takes alone: the modifiers themselves, and the two
-- mouse buttons that click.
local SKIP = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true, BUTTON1 = true, BUTTON2 = true,
    LeftButton = true, RightButton = true }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

-- The key as a binding names it, with the modifiers held: ALT-CTRL-SHIFT-Q.
local function Chord(key)
    key = GetConvertedKeyOrButton and GetConvertedKeyOrButton(key) or MOUSE[key] or key
    if SKIP[key] or (IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key)) then return end
    if CreateKeyChordStringUsingMetaKeyState then return CreateKeyChordStringUsingMetaKeyState(key) end
    local chord = {}
    if IsAltKeyDown() then table.insert(chord, "ALT") end
    if IsControlKeyDown() then table.insert(chord, "CTRL") end
    if IsShiftKeyDown() then table.insert(chord, "SHIFT") end
    table.insert(chord, key)
    return table.concat(chord, "-")
end

local function Save()
    if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
end

-- Every key of the command off; then, with a key, that key on it (a key
-- leaves whatever it did before, as a key does only one thing).
local function Rebind(command, key)
    for _, old in ipairs(Keys(command)) do SetBinding(old) end
    if key then SetBinding(key, command) end
    Save()
end
-- for the settings window's key controls (options/controls.lua)
ns.BindingKeys, ns.KeyChord, ns.Rebind, ns.KeyText = Keys, Chord, Rebind, KeyText

-- ------------------------------------------------------------ the binder
-- One frame over the button under the pointer: it takes the keys, the mouse
-- buttons and the wheel, so the button itself is not clicked.
local binder = CreateFrame("Button", "MedalluinKeybinder", UIParent)
binder:SetFrameStrata("DIALOG")
binder:Hide()
binder:EnableMouseWheel(true)
binder:RegisterForClicks("AnyUp")
local glow = binder:CreateTexture(nil, "OVERLAY")
glow:SetAllPoints()
glow:SetColorTexture(0.95, 0.80, 0.35, 0.45)
ns.keybinder = binder

local banner, marks = nil, {}

local function Tip()
    local command, label = Find(binder.target)
    if not command then return end
    local keys = Keys(command)
    for i, key in ipairs(keys) do keys[i] = KeyText(key) end
    GameTooltip:SetOwner(binder, "ANCHOR_TOP")
    GameTooltip:SetText(label)
    GameTooltip:AddLine(#keys > 0 and table.concat(keys, ", ") or "Not bound", 1, 1, 1)
    GameTooltip:AddLine("Press a key to bind it. Esc removes its keys.", 0.7, 0.66, 0.55)
    GameTooltip:Show()
end

local function Press(key)
    local command = Find(binder.target)
    if not command then return end
    if key == "ESCAPE" then
        Rebind(command)
    else
        local chord = Chord(key)
        if not chord then return end
        Rebind(command, chord)
    end
    Tip()
end

binder:SetScript("OnKeyDown", function(self, key)
    if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    Press(key)
end)
binder:SetScript("OnMouseDown", function(_, button) Press(button) end)
binder:SetScript("OnMouseWheel", function(_, delta) Press(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
binder:SetScript("OnLeave", function(self)
    self.target = nil
    self:EnableKeyboard(false)
    self:Hide()
    GameTooltip:Hide()
end)

local function Attach(btn)
    if not ns.keybinding or not Find(btn) then return end
    binder.target = btn
    binder:ClearAllPoints()
    binder:SetAllPoints(btn)
    binder:Show()
    binder:EnableKeyboard(true)
    Tip()
end

-- ------------------------------------------------------------ the mode
local hooked = {}
local function Targets()
    local out = {}
    for _, bar in ipairs(BARS) do
        for i = 1, bar[4] do
            local btn = _G[bar[1] .. i]
            if btn then table.insert(out, btn) end
        end
    end
    return out
end

local Stop

local function Banner()
    if banner then return banner end
    banner = CreateFrame("Frame", "MedalluinKeybindBanner", UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetSize(360, 58)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -120)
    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.92)
    local edge = banner:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0.88, 0.72, 0.29, 1)
    local title = ns.Text(banner, 15)
    title:SetPoint("TOP", 0, -8)
    title:SetText("Key binding")
    local hint = ns.Text(banner, 11)
    hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
    hint:SetTextColor(unpack(ns.colors.dim))
    hint:SetText("Point at a button and press a key. Esc over it removes its keys.")
    banner.hint = hint
    local done = CreateFrame("Button", "MedalluinKeybindDone", banner, "UIPanelButtonTemplate")
    done:SetSize(64, 20)
    done:SetPoint("TOPRIGHT", -6, -6)
    done:SetText(DONE or "Done")
    done:SetScript("OnClick", function() Stop() end)
    banner.done = done
    -- Esc away from every button ends the mode; every other key goes on to
    -- the game
    banner:EnableKeyboard(true)
    banner:SetScript("OnKeyDown", function(self, key)
        local stop = key == "ESCAPE"
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not stop) end
        if stop then Stop() end
    end)
    return banner
end

local function Mark(btn, on)
    local m = marks[btn]
    if not m and on then
        m = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        m:SetAllPoints()
        m:SetColorTexture(0.95, 0.80, 0.35, 0.18)
        marks[btn] = m
    end
    if m then m:SetShown(on) end
end

function Stop()
    if not ns.keybinding then return end
    ns.keybinding = false
    binder.target = nil
    binder:EnableKeyboard(false)
    binder:Hide()
    if banner then banner:Hide() end
    for btn in pairs(marks) do Mark(btn, false) end
    GameTooltip:Hide()
    if ns.UpdateAllExtraButtons then ns.UpdateAllExtraButtons() end
end

local function Start()
    if ns.keybinding then return end
    if InCombatLockdown() then
        print("|cffe0b84aMedalluin|r: key bindings cannot change in combat.")
        return
    end
    ns.keybinding = true
    if ns.UpdateAllExtraButtons then ns.UpdateAllExtraButtons() end
    for _, btn in ipairs(Targets()) do
        if not hooked[btn] then
            hooked[btn] = true
            btn:HookScript("OnEnter", Attach)
        end
        Mark(btn, true)
    end
    Banner():Show()
end

function ns.KeybindMode(on)
    if on == nil then on = not ns.keybinding end
    if on then Start() else Stop() end
end

ns.On("PLAYER_REGEN_DISABLED", function() Stop() end)

-- ------------------------------------------------------------ keys per profile
-- Each profile's own keys on the action buttons (every command in BARS), as
-- its skills are its own (bars/skills.lua): switching profile saves the keys
-- of the one left and puts back the other's. Every other binding (movement,
-- targeting, menus) is shared, so a key the other profile has given to one
-- of those stays there. A profile with nothing saved takes the keys as they
-- are, the first time.
--
-- Kept with the binding set in use: account bindings in MedalluinDB, a
-- character's own in MedalluinCharDB. Account bindings are every character's,
-- so at login the profile's keys are put back, as another character may
-- have left the other profile's. Bindings change only out of combat.
local function Managed()
    local list = {}
    for _, bar in ipairs(BARS) do
        for i = 1, bar[4] do
            if bar[2] then
                table.insert(list, bar[2] .. i)
            elseif _G[bar[1] .. i] then
                table.insert(list, "CLICK " .. bar[1] .. i .. ":LeftButton")
            end
        end
    end
    return list
end

local function KeySets()
    local account = GetCurrentBindingSet and GetCurrentBindingSet() == 1
    local db = account and MedalluinDB or MedalluinCharDB
    if not db then return end
    db.keys = db.keys or {}
    return db.keys
end

local function SnapshotKeys(profile)
    local sets = KeySets()
    if not sets then return end
    local saved = {}
    for _, command in ipairs(Managed()) do
        local keys = Keys(command)
        if #keys > 0 then saved[command] = keys end
    end
    sets[profile] = saved
end

local function Has(list, key)
    for _, k in ipairs(list or {}) do if k == key then return true end end
end

local function RestoreKeys(profile)
    local sets = KeySets()
    local saved = sets and sets[profile]
    if not saved then return end   -- the first time: the keys as they are
    local commands, ours, changed = Managed(), {}, false
    for _, command in ipairs(commands) do ours[command] = true end
    -- off: every key on an action button the profile has elsewhere, or not at all
    for _, command in ipairs(commands) do
        for _, key in ipairs(Keys(command)) do
            if not Has(saved[command], key) then
                SetBinding(key)
                changed = true
            end
        end
    end
    -- on: the profile's keys, in their order, unless another binding holds one
    for _, command in ipairs(commands) do
        for _, key in ipairs(saved[command] or {}) do
            local now = GetBindingAction(key)
            if now ~= command and (not now or now == "" or ours[now]) then
                SetBinding(key, command)
                changed = true
            end
        end
    end
    if changed then Save() end
end

-- Called by the profile switch (settings.lua) before the profile changes;
-- as the skills do, a switch in combat waits for it to end.
local keysWaiting
function ns.SwitchKeys(from, to)
    if InCombatLockdown() then keysWaiting = keysWaiting or from end
    ns.OutOfCombat(function()
        keysWaiting = nil
        Stop()
        SnapshotKeys(from)
        RestoreKeys(to)
    end)
end

ns.On("PLAYER_LOGIN", function()
    ns.OutOfCombat(function() RestoreKeys(ns.db.consoleProfile) end)
end)
ns.On("PLAYER_LOGOUT", function()
    if ns.db and ns.db.consoleProfile then SnapshotKeys(keysWaiting or ns.db.consoleProfile) end
end)
