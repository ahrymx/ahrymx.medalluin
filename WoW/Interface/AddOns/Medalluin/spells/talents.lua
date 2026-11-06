-- The talents: Medalluin's own (the shell is window/shell.lua), standing on
-- the right strip as the spellbook does, its margin beside the backpack's
-- medallion. Forever only: its talents are one tree of three groups, the
-- old trees, drawn by Blizzard side by side; retail's keep Blizzard's.
--
--   [tree][tree][tree]                                      [v] [x]
--   ---------------------------------------------------------------
--        [o]     [o]                (a tree's talents, where the
--         |                          tree puts them, with the
--        [o] 2/5 [o]     [o]         lines between them)
--   ...
--   ---------------------------------------------------------------
--   the chosen talent's name, rank and description
--   12 points left                                  [Reset] [Apply]
--   ---------------------------------------------------------------
--   (backpack)   [Primary] [Secondary]  [Activate]
--
-- A tab per tree, the game's own icons. A click spends a rank, a right-click
-- takes one back: both only staged, until Apply commits them (Reset
-- forgets them). The margin views the Primary or the Secondary talents;
-- the one not in use reads only, and Activate switches to it (a cast).
--
-- Nothing here is secure: the window opens and reads in combat, where the
-- game refuses every change, so they wait for its end.
--
-- Blizzard's talents are a tab of PlayerSpellsFrame, which the spellbook
-- shares: this window shows while the frame is open on it (spells/frame.lua).
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local LIT = { 0.4, 0.85, 0.35 }         -- ranks still to spend where they can be
local TREES = 3
local ICON, MARGIN = 36, 10             -- a talent's icon, the room round the tree
local STRIP = 26                        -- the points' line under the details

local W = ns.Window{
    name = "MedalluinTalents", side = 1, detailsKey = "talentsDetails",
    closeTip = "Close the talents.",
    Close = function() HideUIPanel(PlayerSpellsFrame) end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.talents = W

local view                              -- the spec group in view (1 Primary, 2 Secondary)

-- ------------------------------------------------------------- the tree
local function Active() return C_SpecializationInfo.GetActiveSpecGroup() end
local function Viewed() return view or Active() end
local function Config() return C_SpecializationInfo.GetCombatConfigIDForSpecGroup(Viewed()) end
-- the talents in view can change now: the ones in use, out of combat
local function Editable() return Viewed() == Active() and not InCombatLockdown() end

local function Tree(config)
    local info = config and C_Traits.GetConfigInfo(config)
    return info and info.treeIDs and info.treeIDs[1]
end

-- the three trees, in their order
local function Groups()
    local tree = Tree(Config())
    if not tree then return {} end
    local list = {}
    for _, g in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(tree) or {}) do table.insert(list, g) end
    table.sort(list, function(a, b) return a.orderIndex < b.orderIndex end)
    return list
end

-- points spent in each tree, by group ID
local function Spent(config, groups)
    local ids, out = {}, {}
    for _, g in ipairs(groups) do table.insert(ids, g.groupID) end
    for _, info in ipairs(config and C_Traits.GetGroupCurrencyInfo(config, ids) or {}) do
        local c = info.currencyInfos and info.currencyInfos[1]
        out[info.traitNodeGroupID] = c and c.spent or 0
    end
    return out
end

local function Left(config)
    local tree = Tree(config)
    local c = tree and C_Traits.GetTreeCurrencyInfo(config, tree, false)
    return c and c[1] and c[1].quantity or 0
end

local function InGroup(node, id)
    for _, g in ipairs(node.groupIDs or {}) do
        if g == id then return true end
    end
    return false
end

-- a talent's entry, spell, name and icon
local function Entry(config, node)
    local entry = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
    local e = entry and C_Traits.GetEntryInfo(config, entry)
    local def = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
    local spell = def and (def.overriddenSpellID or def.spellID)
    local name = def and def.overrideName ~= "" and def.overrideName or (spell and C_Spell.GetSpellName(spell)) or "?"
    local icon = def and def.overrideIcon and def.overrideIcon ~= 0 and def.overrideIcon
        or (spell and C_Spell.GetSpellTexture(spell))
    return { entry = entry, spell = spell, name = name, icon = icon }
end

-- what keeps a talent locked, if anything does
local function Lock(node)
    if node.ranksPurchased >= node.maxRanks then return nil end
    if not node.meetsEdgeRequirements then return "Needs the talent before it." end
    if not node.isAvailable then return "Needs more points in this tree." end
    return nil
end

-- --------------------------------------------------------------- talents
local function Tooltip(owner, n)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if n.talent.entry and GameTooltip.SetTraitEntry then
        GameTooltip:SetTraitEntry(n.talent.entry, n.node.ranksPurchased)
    elseif n.talent.spell then
        GameTooltip:SetSpellByID(n.talent.spell)
    else
        GameTooltip:SetText(n.talent.name)
    end
    GameTooltip:Show()
end

local function Click(p, b, button)
    p.chosen = b.node.ID
    if Editable() then
        if button == "RightButton" then
            C_Traits.RefundRank(Config(), b.node.ID)
        else
            C_Traits.PurchaseRank(Config(), b.node.ID)
        end
    end
    p.Refresh()
end

local function Node(p, i)
    local b = CreateFrame("Button", nil, p.body)
    b:SetSize(ICON, ICON)
    b:SetFrameLevel(p.body:GetFrameLevel() + 2)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetPoint("TOPLEFT", -2, 2)
    b.edge:SetPoint("BOTTOMRIGHT", 2, -2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.well = b:CreateTexture(nil, "OVERLAY")
    b.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.9)
    b.rank = ns.Text(b, 11)
    b.rank:SetPoint("BOTTOMRIGHT", 3, -3)
    b.well:SetPoint("TOPLEFT", b.rank, -2, 1)
    b.well:SetPoint("BOTTOMRIGHT", b.rank, 2, -1)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", function(self, button) Click(p, self, button) end)
    b:SetScript("OnEnter", function(self) Tooltip(self, self) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.nodes[i] = b
    return b
end

local function Edge(p, i)
    local l = p.body:CreateLine(nil, "BACKGROUND")
    l:SetThickness(2)
    p.edges[i] = l
    return l
end

-- A tree's talents where the tree puts them. One scale for the three, the
-- largest filling the page, so a tier stands at one height on every tab;
-- each tree centred across the page, from its top.
local function Draw(p, config, group)
    local span = { x = 0, y = 0 }
    local box, list = {}, {}
    for _, id in ipairs(C_Traits.GetTreeNodes(Tree(config)) or {}) do
        local node = C_Traits.GetNodeInfo(config, id)
        local g = node and node.isVisible and node.groupIDs and node.groupIDs[1]
        if g then
            local b = box[g] or { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge }
            b.x0, b.x1 = math.min(b.x0, node.posX), math.max(b.x1, node.posX)
            b.y0, b.y1 = math.min(b.y0, node.posY), math.max(b.y1, node.posY)
            box[g] = b
            span.x, span.y = math.max(span.x, b.x1 - b.x0), math.max(span.y, b.y1 - b.y0)
            if InGroup(node, group.groupID) then table.insert(list, node) end
        end
    end
    local width, height = W.width - 2 * MARGIN - ICON, (p.body:GetHeight() or 0) - 2 * MARGIN - ICON
    local scale = math.min(span.x > 0 and width / span.x or 1, span.y > 0 and height / span.y or 1)
    local own = box[group.groupID] or { x0 = 0, x1 = 0, y0 = 0 }
    local x0, y0 = own.x0, own.y0
    local left = MARGIN + ICON / 2 + (width - (own.x1 - own.x0) * scale) / 2
    local at, byID = {}, {}
    local editable = Editable()
    for i, node in ipairs(list) do
        local b = p.nodes[i] or Node(p, i)
        b.node, b.talent = node, Entry(config, node)
        byID[node.ID] = b
        b:ClearAllPoints()
        b:SetPoint("CENTER", p.body, "TOPLEFT", left + (node.posX - x0) * scale,
            -(MARGIN + ICON / 2 + (node.posY - y0) * scale))
        b.icon:SetTexture(b.talent.icon)
        local maxed = node.ranksPurchased >= node.maxRanks
        local open = maxed or node.ranksPurchased > 0 or (node.isAvailable and node.meetsEdgeRequirements)
        b.icon:SetDesaturated(not open)
        b.icon:SetAlpha(open and 1 or 0.5)
        local edge = maxed and GOLD or (open and editable and node.canPurchaseRank) and LIT or GOLD_D
        b.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
        b.rank:SetText(node.ranksPurchased .. "/" .. node.maxRanks)
        local text = maxed and GOLD or node.ranksPurchased > 0 and LIT or ns.colors.dim
        b.rank:SetTextColor(text[1], text[2], text[3])
        b:Show()
        at[i] = b
    end
    for i = #list + 1, #p.nodes do p.nodes[i]:Hide(); p.nodes[i].node = nil end
    -- the lines, from each talent to the ones it opens
    local e = 0
    for _, b in ipairs(at) do
        for _, out in ipairs(b.node.visibleEdges or {}) do
            local to = byID[out.targetNode]
            if to then
                e = e + 1
                local l = p.edges[e] or Edge(p, e)
                l:SetStartPoint("CENTER", b)
                l:SetEndPoint("CENTER", to)
                local c = out.isActive and GOLD or GOLD_D
                l:SetColorTexture(c[1], c[2], c[3], out.isActive and 1 or 0.6)
                l:Show()
            end
        end
    end
    for i = e + 1, #p.edges do p.edges[i]:Hide() end
    return byID
end

-- ------------------------------------------------------------- the foot
local function Refresh(p)
    local config = Config()
    local groups = Groups()
    local group = groups[p.tree]
    if not (config and group) then return end
    local byID = Draw(p, config, group)
    local chosen = p.chosen and byID[p.chosen]
    if chosen then
        local node, t = chosen.node, chosen.talent
        local text = t.spell and C_Spell.GetSpellDescription(t.spell) or ""
        local lock = Lock(node)
        p.details:Set({ title = t.name, sub = format("Rank %d/%d", node.ranksPurchased, node.maxRanks)
            .. (lock and ("  ·  " .. lock) or ""), text = text })
    else
        p.details:Set(nil)
    end
    -- the points: left to spend, and in each tree
    local spent = Spent(config, groups)
    local trees = {}
    for _, g in ipairs(groups) do table.insert(trees, format("%s %d", g.displayName, spent[g.groupID] or 0)) end
    p.points:SetText(format("%d |4point:points; left  ·  %s", Left(config), table.concat(trees, "  ·  ")))
    local staged = C_Traits.ConfigHasStagedChanges(config)
    p.apply:SetShown(staged)
    p.reset:SetShown(staged)
    p.apply:SetAlpha(Editable() and 1 or 0.4)
    -- the margin: which talents are in view, which in use
    local active, groupsLearned = Active(), GetNumSpecGroups and GetNumSpecGroups() or 1
    for i, b in ipairs(p.specs) do
        b.mark:SetShown(i == Viewed())
        local c = i == active and GOLD or ns.colors.dim
        b.label:SetTextColor(c[1], c[2], c[3])
        b:SetAlpha(i <= groupsLearned and 1 or 0.4)
    end
    p.activate:SetShown(Viewed() ~= active)
    p.activate:SetAlpha(InCombatLockdown() and 0.4 or 1)
end

local SPECS = { "Primary", "Secondary" }

local function Margin(p, band)
    p.specs = {}
    local prev
    for i, name in ipairs(SPECS) do
        local b = ns.window.Button(band, 86, function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then return end
            view = i
            p.chosen = nil
            W.Refresh()
        end, function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then
                return "Learn a second specialization to use " .. name:lower() .. " talents."
            end
            return format("View your %s talents.", name:lower()) .. (i == Active() and " They are in use." or "")
        end)
        b.label:SetText(name)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", 4, 0) end
        p.specs[i], prev = b, b
    end
    p.activate = ns.window.Button(band, 86, function()
        if InCombatLockdown() or Viewed() == Active() then return end
        C_SpecializationInfo.SetActiveSpecGroup(Viewed())
    end, function()
        return InCombatLockdown() and "Not in combat." or format("Use your %s talents.", SPECS[Viewed()]:lower())
    end)
    p.activate.label:SetText("Activate")
    p.activate:SetPoint("LEFT", prev, "RIGHT", 12, 0)
end

local function Foot(p, foot)
    p.details = ns.character.Details(foot, nil, "Choose a talent to read it.", 4)
    -- the points' line, under the details
    local strip = CreateFrame("Frame", nil, foot)
    strip:SetPoint("BOTTOMLEFT")
    strip:SetPoint("BOTTOMRIGHT")
    strip:SetHeight(STRIP)
    p.points = ns.Text(strip, 12)
    p.points:SetPoint("LEFT", 4, 0)
    p.points:SetJustifyH("LEFT")
    p.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    p.apply = ns.window.Button(strip, 64, function()
        if not Editable() then return end
        C_ClassTalents.CommitConfig()
    end, function() return InCombatLockdown() and "Not in combat." or "Learn the talents chosen." end)
    p.apply.label:SetText("Apply")
    p.apply:SetHeight(STRIP - 2)
    p.apply:SetPoint("RIGHT", 0, 0)
    p.reset = ns.window.Button(strip, 64, function()
        C_Traits.RollbackConfig(Config())
        W.Refresh()
    end, function() return "Forget the talents chosen." end)
    p.reset.label:SetText("Reset")
    p.reset:SetHeight(STRIP - 2)
    p.reset:SetPoint("RIGHT", p.apply, "LEFT", -4, 0)
    p.footHeight = p.details.height + STRIP
end

-- ------------------------------------------------------------------ pages
for i = 1, TREES do
    local p = { key = "tree" .. i, tree = i, order = i, label = "", frame = "TalentsFrame" }
    p.nodes, p.edges = {}, {}
    p.flex, p.height, p.bandUsed = true, 0, true
    p.events = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    function p.Available()
        local g = C_Traits and C_SpecializationInfo and Groups()[i]
        if not g then return false end
        p.label, p.icon = g.displayName, g.icon
        local spent = Spent(Config(), Groups())[g.groupID] or 0
        p.tip = format("%s: %d |4point:points;", g.displayName, spent)
        return true
    end
    function p.Build(body, foot, band)
        Foot(p, foot)
        Margin(p, band)
    end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end

function W.Refresh()
    local p = W.Current()
    if p and W.window:IsShown() then Refresh(p) end
end

local function Start()
    -- Forever's micro menu has a talents button of its own; retail's has
    -- one player-spells button for its combined frame
    if not ns.db.talents or not SpellbookMicroButton or not C_Traits or not C_SpecializationInfo
        or not C_SpecializationInfo.GetCombatConfigIDForSpecGroup then return end
    W.Build()
    for _, p in ipairs(W.pages) do
        if p.available then W.Select(p); break end
    end
    -- the trees' names and points come with the config; a switch of talents
    -- views the ones now in use
    for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("ACTIVE_TALENT_GROUP_CHANGED", function()
        view = nil
        W.Retab()
    end)
    ns.PlayerSpellsTab("ClassTalents", W)
end

ns.On("PLAYER_LOGIN", Start)
