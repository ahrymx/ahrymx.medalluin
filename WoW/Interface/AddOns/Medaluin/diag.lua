-- /mdlui taint, and by itself when a click is blocked: which values an action
-- button's click reads that an addon has tainted, printed to chat (for a
-- screenshot: the client this is played
-- on cannot copy text out). A click that reads one is blocked ("Medaluin has
-- been blocked", UseAction). Asked by WoW itself (issecurevariable), so it
-- names the addon that wrote each value.
--
-- Every field of a button of each row (Medaluin's own medaluin* fields are
-- left out: no Blizzard code reads them), MultiBarRight's as a control (a
-- bar Medaluin never touches), the globals the click path reads, and the
-- fields of the tables it reads through.
local _, ns = ...

local BUTTONS = { "ActionButton1", "MultiBarBottomLeftButton1", "MultiBarBottomRightButton1",
    "grid", "MultiBarRightButton1" }

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

function ns.TaintReport()
    if not issecurevariable then
        Say("this client has no issecurevariable")
        return
    end
    local pointed = Pointed()
    if pointed then Report("under the mouse " .. pointed:GetName(), Fields(pointed, true)) end
    for _, name in ipairs(BUTTONS) do
        -- the centre grid's first button, whichever it is (console/bar7.lua)
        local btn = name == "grid" and ns.bar7Buttons and ns.bar7Buttons[1] or _G[name]
        if btn then Report(btn:GetName() or name, Fields(btn, true)) end
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
end

-- When a click is blocked, the report prints itself (once a minute at most),
-- so one screenshot of the chat has it.
local last
ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, func)
    if addon ~= "Medaluin" then return end
    local now = GetTime()
    if last and now - last < 60 then return end
    last = now
    Say("blocked: " .. tostring(func))
    ns.TaintReport()
end)
