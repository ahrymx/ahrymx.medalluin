-- The 2x5 WeakTextures center grid in the "light" console profile: 10 buttons
-- mapped to Action Bar 7 (slots 73..82), with state-configurable paging across
-- Action Bars 8, 9, and 10 (slots 85..118) and the skyriding page 11 (121..130)
-- via RegisterStateDriver.
--
-- Out of combat with no target, the square minimap occupies the center bay and
-- the grid's alpha is 0. In combat, with a target or skyriding, the minimap
-- relocates to the top-right and the grid's alpha is 1 (console/minimap.lua).
local _, ns = ...

local console = ns.console

ns.On("PLAYER_LOGIN", function()
    local cfg = ns.bar7
    if not cfg then return end

    local header = CreateFrame("Frame", "MedaluinBar7", console, "SecureHandlerStateTemplate")
    header:SetAllPoints(console)
    header:SetFrameLevel(ns.levels.art + 1)
    ns.bar7Frame = header

    local btns = {}
    ns.bar7Buttons = btns

    -- A button of Blizzard's template with an ID reads its page, never its
    -- "action": its own "actionpage", else its parent's, else bar 1's page.
    -- So each button carries its own (as bars/paging.lua's rows do), and
    -- the button works out its action, and redraws, from that; set an
    -- "action" only and the grid shows whatever bar 1 shows.
    local function ApplyPage(page)
        page = tonumber(page) or cfg.basePage
        header.page = page
        if InCombatLockdown() then return end
        for _, btn in ipairs(btns) do btn:SetAttribute("actionpage", page) end
    end
    ns.SetBar7Page = ApplyPage

    for i, slot in ipairs(cfg.slots) do
        local name = "MedaluinBar7Button" .. i
        local btn = _G[name] or CreateFrame("CheckButton", name, header, "ActionBarButtonTemplate")
        btn:SetParent(header)
        btn:SetID(i)
        btn:SetFrameLevel(ns.levels.art + 2)
        ns.PlaceOnBar(btn, slot)
        btn:SetAttribute("type", "action")
        -- a command no key is bound to: Blizzard's hotkey then reads the
        -- button's click binding (keybind.lua), not action bar 1's keys
        btn.buttonType = "MEDALUINBAR7BUTTON"
        if btn.UpdateHotkeys then btn:UpdateHotkeys(btn.buttonType) end
        if ns.StyleButton then ns.StyleButton(btn) end
        if ns.actionButtons then table.insert(ns.actionButtons, btn) end
        btns[i] = btn
    end

    ApplyPage(cfg.basePage)

    -- the page by the Paging page's Centre grid option (bars/paging.lua)
    function ns.ApplyGridPaging()
        local stateDriver = ns.PagingConditional and ns.PagingConditional("gridPaging") or cfg.stateDriver
        header.stateDriver = stateDriver
        if RegisterStateDriver then
            RegisterStateDriver(header, "page", stateDriver)
        end
    end
    ns.ApplyGridPaging()
    if header.SetAttribute then
        header:SetAttribute("_onstate-page", [=[
            local page = tonumber(newstate) or 7
            for i = 1, 10 do
                local btn = self:GetFrameRef("btn" .. i)
                if btn then btn:SetAttribute("actionpage", page) end
            end
        ]=])
        if header.SetFrameRef then
            for i, btn in ipairs(btns) do header:SetFrameRef("btn" .. i, btn) end
        end
    end

    function ns.UpdateBar7Visibility(relocated)
        header:SetAlpha(relocated and 1 or 0)
    end

    -- shown by console/minimap.lua's one rule (combat, a target, skyriding),
    -- first at PLAYER_ENTERING_WORLD, which always follows login
end)
