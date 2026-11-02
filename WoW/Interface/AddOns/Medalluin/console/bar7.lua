-- The 2x5 WeakTextures center grid in the "light" console profile: 10 of
-- Blizzard's Action bar 7 buttons (MultiBar6Button1-10), on page 7 (slots
-- 73..82), with state-configurable paging across pages 8, 9 and 10 (slots
-- 85..118) and the skyriding page 11 (121..130) via a state driver.
--
-- Out of combat with no target, the square minimap occupies the center bay and
-- the grid's alpha is 0. In combat, with a target, skyriding or a party row up,
-- the minimap relocates to the top-right and the grid's alpha is 1
-- (console/minimap.lua).
local _, ns = ...

local console = ns.console

ns.On("PLAYER_LOGIN", function()
    local cfg = ns.bar7
    if not cfg then return end

    local header = CreateFrame("Frame", "MedalluinBar7", console, "SecureHandlerStateTemplate")
    header:SetAllPoints(console)
    header:SetFrameLevel(ns.levels.art + 1)
    ns.bar7Frame = header

    local btns = {}
    ns.bar7Buttons = btns

    -- A button of Blizzard's template with an ID reads its page, never its
    -- "action": its own "actionpage", else its parent's, else bar 1's page.
    -- So each button carries its own (as bars/paging.lua's rows do), and
    -- the button works out its action, and redraws, from that; set an
    -- "action" only and the grid shows whatever bar 1 shows. Only the state
    -- header's snippet sets it, from the game's secure update: set from
    -- here, it would taint the buttons' clicks (ns.DriveState, core.lua).

    -- Protected buttons move, and take attributes, only out of combat; a
    -- /reload in combat waits (as bars/buttons.lua's rows do).
    ns.OutOfCombat(function()
        -- Blizzard's own Action bar 7 buttons (MultiBar6, which Edit Mode hides
        -- by default), taken as bars/buttons.lua takes rows 2 and 3. A button
        -- an addon makes from ActionBarButtonTemplate runs the template's OnLoad
        -- in the addon's code, and what that writes on it (feedback_action,
        -- bindingAction, buttonType) is tainted for good: every click on it, or
        -- press of its key, was blocked ("Medalluin has been blocked", UseAction;
        -- issecurevariable in game, 2026-11-01). Blizzard made these itself, and their keys
        -- are its own (MULTIACTIONBAR6BUTTON1-10, keybind.lua). A client without
        -- them (Classic Era) gets buttons of Medalluin's own, as before.
        local spare = _G.MultiBar6 and _G.MultiBar6Button1 and _G.MultiBar6
        for i, slot in ipairs(cfg.slots) do
            local btn
            if spare then
                btn = _G["MultiBar6Button" .. i]
            else
                local name = "MedalluinBar7Button" .. i
                btn = _G[name] or CreateFrame("CheckButton", name, header, "ActionBarButtonTemplate")
                btn:SetID(i)
                -- a command no key is bound to: Blizzard's hotkey then reads the
                -- button's click binding (keybind.lua), not action bar 1's keys
                btn.buttonType = "MEDALLUINBAR7BUTTON"
                if btn.UpdateHotkeys then btn:UpdateHotkeys(btn.buttonType) end
            end
            btn:SetParent(header)
            btn:SetFrameLevel(ns.levels.art + 2)
            ns.PlaceOnBar(btn, slot)
            if ns.StyleButton then ns.StyleButton(btn) end
            if ns.actionButtons then table.insert(ns.actionButtons, btn) end
            btns[i] = btn
        end
        if spare then
            -- the bar and the buttons the grid has no room for go out of sight
            for i = #cfg.slots + 1, 12 do ns.Park(_G["MultiBar6Button" .. i]) end
            ns.Kill(spare)
            if ns.MoveGridBindings then ns.MoveGridBindings(#cfg.slots) end
        end

        header:SetAttribute("_onstate-page", [=[
            if self:GetAttribute("medalluin-hold") then return end
            local page = tonumber(newstate) or 7
            for i = 1, 10 do
                local btn = self:GetFrameRef("btn" .. i)
                if btn then btn:SetAttribute("actionpage", page) end
            end
        ]=])
        for i, btn in ipairs(btns) do header:SetFrameRef("btn" .. i, btn) end

        -- the page by the Paging page's Centre grid option (bars/paging.lua)
        function ns.ApplyGridPaging()
            local stateDriver = ns.PagingConditional and ns.PagingConditional("gridPaging") or cfg.stateDriver
            ns.DriveState(header, "page", stateDriver)
        end
        ns.ApplyGridPaging()
    end)

    function ns.UpdateBar7Visibility(relocated)
        header:SetAlpha(relocated and 1 or 0)
    end

    -- shown by console/minimap.lua's one rule (combat, a target, skyriding, a party row),
    -- first at PLAYER_ENTERING_WORLD, which always follows login
end)
