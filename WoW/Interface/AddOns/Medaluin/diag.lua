-- The taint report, a debug tool: /mdlui taint (or /mdlui debug), and by
-- itself, at most once a minute, whenever the game blocks Medaluin ("Medaluin
-- has been blocked"). It prints to chat, for a screenshot: the client this is
-- played on cannot copy text out. Every verdict is WoW's own
-- (issecurevariable), so each tainted value names the addon that wrote it.
--
-- What it covers, from the blocked clicks of 2026-11-01 (0c5ed3e: grid
-- buttons made from Blizzard's template; then settings built from a
-- function default, settings.lua):
--   - the button under the mouse, and one button of each bar, MultiBarRight's
--     as a control (a bar Medaluin never touches): every field (Medaluin's
--     own medaluin* fields left out: no Blizzard code reads them), the page
--     it carries, and the bar it reads one from when it carries none
--     (btn.bar, else its parent) with that bar's tainted fields;
--   - the globals an action button's click reads, and the fields of the
--     tables it reads through;
--   - the keys bound to clicks (a click binding runs OnClick, as the mouse
--     does);
--   - Blizzard's Combat options page, setting by setting in the order it
--     builds them: the first one built tainted marks where Blizzard's own
--     code started running tainted (a proxy setting is always built clean,
--     so says nothing);
--   - every tainted global, and the tainted fields of every global table of
--     the settings, callback and event machinery.
-- Clean is the normal answer; any line naming Medaluin is a lead.
local _, ns = ...

local BUTTONS = { "ActionButton1", "MultiBarBottomLeftButton1", "MultiBarBottomRightButton1",
    "grid", "MultiBarRightButton1", "ExtraActionButton1" }

-- What ActionBarActionButtonMixin.OnClick, SecureActionButton_OnClick and
-- the "action" handler read on the way to UseAction.
local GLOBALS = { "KeybindFrames_InQuickKeybindMode", "QuickKeybindFrame", "GetCursorInfo", "C_ActionBar",
    "Settings", "IsModifiedClick", "SecureActionButton_OnClick", "SecureButton_GetAttribute",
    "SecureButton_GetModifiedAttribute", "SecureButton_GetModifierPrefix", "SecureButton_GetButtonSuffix",
    "SecureButton_GetModifiedUnit", "SecureButton_GetEffectiveButton", "GetCVarBool", "SECURE_ACTIONS",
    "ATTRIBUTE_NOOP", "NUM_ACTIONBAR_BUTTONS", "SpellFlyout", "GetActionInfo", "UseAction", "UnitExists",
    "UnitCanAttack", "UnitCanAssist", "SpellCanTargetItem", "SpellCanTargetItemID", "SpellIsTargeting",
    "securecallfunction", "MacroFrame_SaveMacro", "ActionBarActionButtonMixin",
    "ActionBarActionButtonDerivedMixin", "QuickKeybindButtonTemplateMixin", "SecureActionButtonMixin",
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight" }

local function Say(text) print("|cffe0b84aMedaluin taint|r " .. text) end

-- The tainted fields of a table, as "key(addon)".
local function Fields(t, skipOwn)
    local out = {}
    if type(t) ~= "table" then return out end
    for k in pairs(t) do
        if type(k) == "string" and not (skipOwn and k:match("^medaluin")) then
            local ok, secure, by = pcall(issecurevariable, t, k)
            if ok and not secure then table.insert(out, k .. "(" .. tostring(by) .. ")") end
        end
    end
    table.sort(out)
    return out
end

local function Report(label, list)
    if #list == 0 then
        Say(label .. ": clean")
    else
        Say(label .. ": " .. table.concat(list, ", "))
    end
end

-- The button under the mouse, where the click came from.
local function Pointed()
    local foci = GetMouseFoci and GetMouseFoci()
    local f = foci and foci[1] or GetMouseFocus and GetMouseFocus()
    return f and f.GetName and f:GetName() and f or nil
end

-- A button's fields, then what it carries: its page, and the bar it would
-- read one from without (CalculateAction, SecureTemplates.lua) with that
-- bar's tainted fields.
local function Button(btn, label)
    Report(label, Fields(btn, true))
    local bar = btn.bar or btn:GetParent()
    local name = bar and bar.GetName and bar:GetName() or tostring(bar)
    local page = btn.GetAttribute and btn:GetAttribute("actionpage")
    local list = Fields(bar, true)
    Say(string.format("  page=%s bar=%s: %s", tostring(page), tostring(name),
        #list > 0 and table.concat(list, ", ") or "clean"))
end

-- Keys bound to a button's click: pressed through OnClick, as a mouse click is.
local function Clicks()
    local out = {}
    if not (GetNumBindings and GetBinding) then return out end
    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if type(command) == "string" and command:match("^CLICK ") and (key1 or key2) then
            table.insert(out, tostring(key1 or key2) .. "=" .. command:sub(7))
        end
    end
    return out
end

-- Blizzard's Combat options page (Blizzard_SettingsDefinitions_Frame/
-- Combat.lua, run once after login) wrote three tainted fields, so it ran
-- tainted from some point on. Each setting it makes is built in whatever
-- code is running then, so the first one built tainted marks the step.
-- In the order the page makes them.
local COMBAT = { "nameplateShowSelf", "PROXY_SELF_HIGHLIGHT", "occludedSilhouettePlayer", "showTargetOfTarget",
    "doNotFlashLowHealthWarning", "lossOfControl", "enableFloatingCombatText",
    "floatingCombatTextFloatMode_v2", "enableMouseoverCast", "MOUSEOVERCAST", "PROXY_SELF_CAST",
    "SELFCAST", "FOCUSCAST", "empowerTapControls", "spellActivationOverlayOpacity",
    "ActionButtonUseKeyHeldSpell", "PROXY_ACTION_TARGETING" }

local function Built(variable)
    local setting = Settings and Settings.GetSetting and Settings.GetSetting(variable)
    if not setting then return variable .. "=absent" end
    local secure, by = issecurevariable(setting, "variable")
    return variable .. "=" .. (secure and "ok" or ("T(" .. tostring(by) .. ")"))
end

local function CVar(name)
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name)
end

local function CombatPage()
    local list = {}
    for _, variable in ipairs(COMBAT) do table.insert(list, Built(variable)) end
    Say("combat page: " .. table.concat(list, " "))
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CombatText")
    Say(string.format("fct=%s classicWorldText=%s combatTextLoaded=%s %s %s",
        tostring(CVar("enableFloatingCombatText")), tostring(CVar("classicStyleWorldText")),
        tostring(loaded), Built("lockActionBars"), Built("Medaluin_consoleProfile")))
end

-- Anything Blizzard's own code could have read on the way: every tainted
-- global, and the tainted fields of every global table whose name says it
-- is part of the settings machinery. Medaluin's own globals are left out.
local MACHINERY = { "Setting", "Mixin", "CVar", "Combat", "Registr", "Callback", "Event", "Inbound" }
local function Machinery(name)
    for _, word in ipairs(MACHINERY) do
        if name:find(word, 1, true) then return true end
    end
end

local function Sweep()
    local globals, fields = {}, {}
    for name, value in pairs(_G) do
        if type(name) == "string" and not name:match("^Medaluin") and not name:match("^SLASH_MEDALUIN")
            and not name:match("^SLASH_MDLUI") then
            local secure, by = issecurevariable(name)
            if not secure then table.insert(globals, name .. "(" .. tostring(by) .. ")") end
            if type(value) == "table" and Machinery(name) and name ~= "Settings" then
                for _, f in ipairs(Fields(value, true)) do table.insert(fields, name .. "." .. f) end
            end
        end
    end
    table.sort(globals)
    table.sort(fields)
    Report("all globals", globals)
    Report("machinery", fields)
end

function ns.TaintReport()
    if not issecurevariable then
        Say("this client has no issecurevariable")
        return
    end
    local pointed = Pointed()
    if pointed then Button(pointed, "under the mouse " .. pointed:GetName()) end
    for _, name in ipairs(BUTTONS) do
        -- the centre grid's first button, whichever it is (console/bar7.lua)
        local btn = name == "grid" and ns.bar7Buttons and ns.bar7Buttons[1] or _G[name]
        if btn then Button(btn, btn:GetName() or name) end
    end
    local globals = {}
    for _, name in ipairs(GLOBALS) do
        local secure, by = issecurevariable(name)
        if not secure then table.insert(globals, name .. "(" .. tostring(by) .. ")") end
    end
    Report("globals", globals)
    local tables = {}
    for _, name in ipairs({ "SECURE_ACTIONS", "Settings", "SpellFlyout", "ActionBarActionButtonMixin",
        "SecureActionButtonMixin", "C_ActionBar" }) do
        for _, f in ipairs(Fields(_G[name])) do table.insert(tables, name .. "." .. f) end
    end
    local lock = Settings and Settings.GetSetting and Settings.GetSetting("lockActionBars")
    for _, f in ipairs(Fields(lock)) do table.insert(tables, "lockActionBars." .. f) end
    Report("tables", tables)
    local clicks = Clicks()
    Say("click bindings: " .. (#clicks > 0 and table.concat(clicks, ", ") or "none"))
    CombatPage()
    Sweep()
end

-- When a click is blocked, the report prints itself (once a minute at most),
-- so one screenshot of the chat has it.
local last
ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, func)
    if addon ~= "Medaluin" then return end
    local now = GetTime()
    if last and now - last < 60 then return end
    last = now
    Say("blocked: " .. tostring(func) .. ", profile " .. tostring(ns.db and ns.db.consoleProfile))
    ns.TaintReport()
end)
