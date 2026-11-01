-- The 2x5 WeakTextures center grid in the "light" console profile: 10 buttons
-- mapped to Action Bar 7 (slots 73..82), with state-configurable paging across
-- Action Bars 8, 9, and 10 (slots 85..118) via RegisterStateDriver.
--
-- Out of combat with no target, the square minimap occupies the center bay and
-- the grid's alpha is 0. In combat or with a target, the minimap relocates to
-- the top-right and the grid's alpha is 1.
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

    local function ApplyPage(page)
        page = tonumber(page) or cfg.basePage
        header.page = page
        local base = (page - 1) * 12
        for i, btn in ipairs(btns) do
            local action = base + i
            btn.action = action
            if not InCombatLockdown() then
                btn:SetAttribute("action", action)
            end
        end
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
            local base = (page - 1) * 12
            for i = 1, 10 do
                local btn = self:GetFrameRef("btn" .. i)
                if btn then btn:SetAttribute("action", base + i) end
            end
        ]=])
        if header.SetFrameRef then
            for i, btn in ipairs(btns) do header:SetFrameRef("btn" .. i, btn) end
        end
    end

    function ns.UpdateBar7Visibility(relocated)
        header:SetAlpha(relocated and 1 or 0)
    end

    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local hasTarget = UnitExists and UnitExists("target") and true or false
    ns.UpdateBar7Visibility(inCombat or hasTarget)
end)
