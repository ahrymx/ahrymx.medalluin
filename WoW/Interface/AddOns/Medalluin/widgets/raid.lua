-- The Raid widget: a column per raid group that has members, under its
-- "Group N" tab, five units down; Blizzard's raid frames are retired. Each
-- group is a SecureGroupHeaderTemplate, which makes and fills its buttons
-- itself, in combat too, so a member joining mid-fight still shows. Columns
-- move only out of combat: a group that first fills in combat shows in the
-- column it was last given, the skin widened to it with no tab over the
-- empty columns between, and the box closes up when combat ends.
local _, ns = ...

local W = ns.WIDGET
local ROWS = 5
-- a cell is 112x36 until the editor sizes it (ns.CellSize, editor.lua)
local function Size() return ns.CellSize("raid") end
local function Height()
    local _, h = Size()
    return ROWS * h + (ROWS - 1) * W.gap
end

local box = ns.WidgetBox("MedalluinRaidWidget", "raidWidgetPoint", { "TOPLEFT", "TOPLEFT", 40, -240 })
ns.raidWidget = box

-- A header's new button, styled from its initial configuration (the
-- header calls back through CallMethod; a button's unit is set after).
local function Style(_, name)
    local b = _G[name]
    if not b or b.health then return end
    ns.WidgetCell(b, Size())
    ns.DeadLook(b)
    ns.AttachAuras(b, "raid")
    ns.EditableCell(b, "raid")
    ns.ApplyEdits(b)
    b:RegisterForClicks("AnyUp")
    b:HookScript("OnAttributeChanged", function(self, key, value)
        if key == "unit" then ns.WatchWidgetUnit(self, value) end
    end)
    b:HookScript("OnShow", function(self) if self.unit then ns.UpdateWidgetCell(self) end end)
    b:SetScript("OnEnter", function(self) if UnitFrame_OnEnter then UnitFrame_OnEnter(self) end end)
    b:SetScript("OnLeave", function(self) if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end end)
    ns.WatchWidgetUnit(b, b:GetAttribute("unit"))
end

-- at the cell size of the moment: set again when the editor changes it
local function Config()
    return ([[
    self:SetWidth(%d)
    self:SetHeight(%d)
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    self:GetParent():CallMethod("Style", self:GetName())
]]):format(Size())
end

local headers = {}
for g = 1, 8 do
    local h = CreateFrame("Frame", "MedalluinRaidGroup" .. g, box, "SecureGroupHeaderTemplate")
    h.Style = Style
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("initialConfigFunction", Config())
    h:SetAttribute("showRaid", true)
    h:SetAttribute("groupFilter", tostring(g))
    h:SetAttribute("point", "TOP")
    h:SetAttribute("yOffset", -W.gap)
    h:SetAttribute("unitsPerColumn", ROWS)
    h:Show()
    headers[g] = h
end
ns.raidHeaders = headers

-- The preview's raid: two groups of five, plain frames (a header shows only
-- real members).
local PREVIEW = {
    { "Nokamii", "MAGE" }, { "Thalric", "PRIEST" }, { "Ahrymx", "PALADIN" }, { "Velis", "ROGUE" },
    { "Brannoc", "HUNTER" }, { "Isolde", "DRUID" }, { "Kerrin", "SHAMAN" }, { "Mardu", "WARLOCK" },
    { "Ysolt", "DEATHKNIGHT" }, { "Orrin", "WARRIOR" },
}
local previews = {}
local function Preview(i)
    if previews[i] then return previews[i] end
    local b = ns.WidgetCell(CreateFrame("Frame", nil, box), Size())
    ns.DeadLook(b)
    local who = PREVIEW[i]
    ns.AttachAuras(b, "raid")
    ns.EditableCell(b, "raid")
    ns.ApplyEdits(b)
    b.unit = "raidpreview" .. i
    b.stub = { name = who[1], class = who[2], health = 100 - (i * 13) % 60, maxHealth = 100,
        power = 70, maxPower = 100, powerType = 0 }
    b:Hide()
    previews[i] = b
    return b
end

-- The groups with members now, in order.
local function Groups()
    local used = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local _, _, group = GetRaidRosterInfo(i)
            if group then used[group] = true end
        end
    end
    local list = {}
    for g = 1, 8 do if used[g] then table.insert(list, g) end end
    return list
end

-- Each group's column, as last laid out (out of combat).
local placed = {}

-- The tabs, a column each: the groups in use in theirs, by where they were
-- last placed, which in combat may leave columns empty.
local function Titles(groups, preview)
    local titles = {}
    if preview or not next(placed) then
        for i, g in ipairs(groups) do titles[i] = "Group " .. g end
    else
        local last = 0
        for _, g in ipairs(groups) do last = math.max(last, placed[g]) end
        for i = 1, last do titles[i] = false end
        for _, g in ipairs(groups) do titles[placed[g]] = "Group " .. g end
    end
    if #titles == 0 then titles[1] = "Group 1" end
    return titles
end

local function Update()
    local CELL_W, CELL_H = Size()
    local HEIGHT = Height()
    local preview = ns.db.simParty and not IsInRaid()
    local groups = preview and { 1, 2 } or Groups()
    for i = 1, #PREVIEW do
        local b = Preview(i)
        if preview then
            local col, row = math.floor((i - 1) / ROWS) + 1, (i - 1) % ROWS + 1
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", box, "TOPLEFT", ns.WidgetColumnX(col, CELL_W), ns.WidgetRowY(row, CELL_H + W.gap))
            ns.SizeWidgetCell(b, CELL_W, CELL_H)
            b:Show()
            ns.UpdateWidgetCell(b)
        else
            b:Hide()
        end
    end
    ns.OutOfCombat(function()
        -- the groups in use in their columns; the rest after them, out of
        -- the box, where a group filling in combat waits for its column
        local col = 0
        wipe(placed)
        for _, g in ipairs(preview and {} or groups) do
            col = col + 1
            placed[g] = col
        end
        for g = 1, 8 do
            if not placed[g] then
                col = col + 1
                placed[g] = col
            end
            local h = headers[g]
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", box, "TOPLEFT", ns.WidgetColumnX(placed[g], CELL_W), ns.WidgetRowY(1, 0))
        end
        ns.WidgetHolder(box, ns.WidgetSize(math.max(#groups, 1), CELL_W, HEIGHT))
        ns.WidgetVisibility(box, preview and "show" or "[group:raid] show; hide")
    end)
    ns.WidgetSkin(box, Titles(groups, preview), CELL_W, HEIGHT)
end
ns.OnWidgetUpdate(Update)

-- The editor's cell size: every header's buttons, the ones it has and the
-- ones it will make, out of combat; the box laid again. Only when the size
-- changed (the pieces follow the editor at once, in combat too).
local laidSize
local function Resize()
    local w, h = Size()
    if w .. "x" .. h == laidSize then return end
    laidSize = w .. "x" .. h
    ns.OutOfCombat(function()
        for g, header in ipairs(headers) do
            header:SetAttribute("initialConfigFunction", Config())
            local i = 1
            while _G["MedalluinRaidGroup" .. g .. "UnitButton" .. i] do
                local b = _G["MedalluinRaidGroup" .. g .. "UnitButton" .. i]
                if b.health then ns.SizeWidgetCell(b, w, h) end
                i = i + 1
            end
            -- the header places its buttons again by their new height
            header:SetAttribute("yOffset", -W.gap)
        end
    end)
    Update()
end
ns.OnSetting("editRaid", Resize)
ns.On("PLAYER_LOGIN", Resize)

-- Blizzard's raid frames and their manager give way to the widget.
ns.On("PLAYER_LOGIN", function()
    ns.Kill(_G.CompactRaidFrameManager)
    ns.Kill(_G.CompactRaidFrameContainer)
end)
