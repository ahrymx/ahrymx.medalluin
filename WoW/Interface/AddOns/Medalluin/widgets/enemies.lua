-- The Boss and Arena widgets: one column of up to five units under its tab,
-- "Boss" or "Bosses", "Arena". The buttons hang in fixed rows and show by
-- their units (RegisterUnitWatch), so a boss coming mid-fight shows at
-- once; the box's skin, not protected, lengthens to the last one shown.
--
-- Boss frames are on the overhead, here, or both (Console > Unit Layout >
-- Boss frames); Blizzard's are retired either way (blizzard.lua).
-- Blizzard's arena frames give way to the Arena widget.
local _, ns = ...

local W = ns.WIDGET

-- A column's cells are its spec's size until the editor sizes them
-- (ns.CellSize, editor.lua): laid again, out of combat, when that changes.
local function Column(spec)
    local box = ns.WidgetBox(spec.name, spec.key, spec.default)
    local buttons = {}
    for i = 1, 5 do
        local width, height = ns.CellSize(spec.unit)
        local b = ns.WidgetUnit(box, spec.name .. "Unit" .. i, spec.unit .. i, width, height, spec.unit)
        b:SetFrameLevel(box:GetFrameLevel() + 2)
        RegisterUnitWatch(b)
        buttons[i] = b
    end
    local function Step()
        local _, height = ns.CellSize(spec.unit)
        return height + W.gap
    end
    local function Lay()
        local width, height = ns.CellSize(spec.unit)
        for i, b in ipairs(buttons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", box, "TOPLEFT", ns.WidgetColumnX(1, width), ns.WidgetRowY(i, Step()))
            ns.SizeWidgetCell(b, width, height)
        end
    end
    Lay()

    -- the conditional showing the box: any of its units there
    local parts = {}
    for i = 1, 5 do parts[i] = ("[@%s%d,exists] show"):format(spec.unit, i) end
    local shown = table.concat(parts, "; ") .. "; hide"

    -- The units shown, real or simulated: the skin to the last of them.
    local function Skin()
        local last = 0
        for i, b in ipairs(buttons) do
            if b.stub or UnitExists(b.unit) then last = i end
        end
        last = math.max(last, 1)
        local width = ns.CellSize(spec.unit)
        ns.WidgetSkin(box, { spec.title(last) }, width, last * Step() - W.gap)
    end

    local function Update()
        local on = spec.on()
        local count = on and ns.db.simParty and spec.preview() or 0
        ns.OutOfCombat(function()
            ns.WidgetHolder(box, ns.WidgetSize(1, ns.CellSize(spec.unit), 5 * Step() - W.gap))
            for i, b in ipairs(buttons) do
                local stub = i <= count and spec.stubs[i] or nil
                if stub ~= b.stub then
                    b.stub = stub
                    if stub then
                        UnregisterUnitWatch(b)
                        b:Show()
                    else
                        RegisterUnitWatch(b)
                    end
                end
                ns.UpdateWidgetCell(b)
            end
            ns.WidgetVisibility(box, not on and "hide" or count > 0 and "show" or shown)
        end)
        Skin()
    end
    ns.OnWidgetUpdate(Update)
    local laidSize
    local function Resize()
        local width, height = ns.CellSize(spec.unit)
        if width .. "x" .. height == laidSize then return end
        laidSize = width .. "x" .. height
        ns.OutOfCombat(Lay)
        Update()
    end
    ns.OnSetting(spec.editKey, Resize)
    ns.On("PLAYER_LOGIN", Resize)
    box:HookScript("OnShow", Skin)
    for _, b in ipairs(buttons) do
        b:HookScript("OnShow", Skin)
        b:HookScript("OnHide", Skin)
    end
    return box, buttons
end

-- ------------------------------------------------------------ boss
local function BossesHere()
    local where = ns.db.bossFrames
    return where == "vertical" or where == "both"
end
ns.BossWidgetShown = BossesHere

ns.bossWidget = Column({
    name = "MedalluinBossWidget", key = "bossWidgetPoint", default = { "RIGHT", "RIGHT", -260, 160 },
    unit = "boss", editKey = "editBoss",
    title = function(n) return n > 1 and "Bosses" or "Boss" end,
    on = BossesHere,
    preview = function() return ns.sim.bosses end,
    -- the overhead's simulated bosses, with the power a cell here draws
    stubs = (function()
        local list = {}
        for i, stub in ipairs(ns.bossStubs) do
            list[i] = { name = stub.name, class = stub.class, health = stub.health, maxHealth = stub.maxHealth,
                power = stub.power, maxPower = 100, powerType = 1 }
        end
        return list
    end)(),
})
ns.OnSetting("bossFrames", function() ns.UpdateWidgets() end)

-- ------------------------------------------------------------ arena
local ARENA_STUBS = {
    { name = "Arena 1", class = "ROGUE", health = 90, maxHealth = 100, power = 60, maxPower = 100, powerType = 3 },
    { name = "Arena 2", class = "PRIEST", health = 70, maxHealth = 100, power = 80, maxPower = 100, powerType = 0 },
    { name = "Arena 3", class = "WARRIOR", health = 50, maxHealth = 100, power = 30, maxPower = 100, powerType = 1 },
}
ns.arenaWidget = Column({
    name = "MedalluinArenaWidget", key = "arenaWidgetPoint", default = { "RIGHT", "RIGHT", -260, -120 },
    unit = "arena", editKey = "editArena",
    title = function() return "Arena" end,
    on = function() return true end,
    preview = function() return #ARENA_STUBS end,
    stubs = ARENA_STUBS,
})

-- Blizzard's arena frames: the Edit Mode one, and the older one its
-- load-on-demand addon makes.
local function RetireArena()
    ns.Kill(_G.CompactArenaFrame)
    ns.Kill(_G.ArenaEnemyFramesContainer)
    ns.Kill(_G.ArenaEnemyFrames)
    ns.Kill(_G.ArenaPrepFrames)
end
ns.On("PLAYER_LOGIN", RetireArena)
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_ArenaUI" then ns.OutOfCombat(RetireArena) end
end)
