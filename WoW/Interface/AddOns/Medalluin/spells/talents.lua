-- The talents: Medalluin's own (the shell is window/shell.lua), standing on
-- the right strip as the spellbook does, its margin beside the backpack's
-- medallion. Forever only: its talents are one tree of three groups, the
-- old trees, drawn by Blizzard side by side; retail's keep Blizzard's.
--
--   [tree][tree][tree]                                      [v] [x]
--   ---------------------------------------------------------------
--   [Plan] [Reset]    12 points available  ·  Elemental 5  [Follow] [Apply]
--        [o]     [o]                (a tree's talents, where the
--         |                          tree puts them, with the
--        [o] 2/5 [o]     [o]         lines between them)
--   ...
--   ---------------------------------------------------------------
--   the chosen talent's name, rank and what each rank gives
--   ---------------------------------------------------------------
--   (backpack)   [Primary] [Secondary]  [Order] [Activate]
--
-- A tab per tree, the game's own icons. A click spends a rank, a right-click
-- takes one back: both only staged, until Apply commits them (Reset
-- forgets them). A talent's tooltip and the details say what each rank
-- gives: "by 33% / 66% / 100%", the rank it is at in green. The margin views the Primary or the Secondary talents;
-- the one not in use reads only, and Activate switches to it (a cast).
--
-- A plan: the order to learn talents in, a rank an entry, kept for each
-- specialisation (MedalluinCharDB.talentPlan[specGroup], node IDs). Plan
-- turns its mode on: a click adds a rank to the plan instead of staging
-- it, a right-click takes the talent's last off (and every entry after it
-- that no longer follows), each talent reading its planned ranks. The
-- game will not judge a plan, so the rules are ours: a tier's points in
-- its tree (the node's condition, or 5 a tier), the talent before it
-- planned to its last rank, a talent's ranks, and the points a character
-- ever has (the top level less 9). The plan starts from the talents
-- learned. Out of the mode, the talents planned and not learned glow, the
-- next the brightest; Follow stages the plan's next entries, as many as
-- the points left, for Apply to learn. Order, in the margin, lists the
-- plan (the level each entry comes at, the learned ticked, the next
-- marked; a click opens its talent), with Clear plan. In the mode the
-- tree's ground turns blue, so it is never mistaken for learning.
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
local PLANNING = { 0.12, 0.24, 0.48, 0.55 }  -- the tree's ground in the plan's mode: the ink turned blue
local TREES = 3
local ICON, MARGIN = 36, 10             -- a talent's icon, the room round the tree
local STRIP = 26                        -- the points' row over the tree

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

-- ------------------------------------------------------------- the plan
local planning                          -- the plan's mode: clicks plan instead of staging

local function Plans()
    MedalluinCharDB = MedalluinCharDB or {}
    if type(MedalluinCharDB.talentPlan) ~= "table" then MedalluinCharDB.talentPlan = {} end
    return MedalluinCharDB.talentPlan
end
-- the plan of the talents in view, as kept
local function Plan()
    local all = Plans()
    if type(all[Viewed()]) ~= "table" then all[Viewed()] = {} end
    return all[Viewed()]
end
local function Keep(list)
    local plan = Plan()
    for k = #plan, 1, -1 do plan[k] = nil end
    for k, id in ipairs(list) do plan[k] = id end
end

-- the points a character ever has: one a level from 10
local function Cap() return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60) - 9 end

-- The trees as the plan reads them: each talent's tree, its tier (its
-- height over its tree's first, in the steps the trees are drawn in), the
-- points its tree needs first, and the talents that lead to it.
local function Model(config)
    local groups = Groups()
    local tree = Tree(config)
    local m = {}
    for _, id in ipairs(tree and C_Traits.GetTreeNodes(tree) or {}) do
        local node = C_Traits.GetNodeInfo(config, id)
        if node and node.isVisible then
            for _, g in ipairs(groups) do
                if not m[id] and InGroup(node, g.groupID) then
                    m[id] = { node = node, group = g.groupID, sources = {} }
                end
            end
        end
    end
    local top, heights = {}, {}
    for _, t in pairs(m) do
        top[t.group] = math.min(top[t.group] or math.huge, t.node.posY)
        heights[t.node.posY] = true
    end
    local list, step = {}, nil
    for y in pairs(heights) do table.insert(list, y) end
    table.sort(list)
    for k = 2, #list do step = math.min(step or math.huge, list[k] - list[k - 1]) end
    for id, t in pairs(m) do
        t.tier = step and math.floor((t.node.posY - top[t.group]) / step + 0.5) or 0
        local need
        for _, cond in ipairs(t.node.conditionIDs or {}) do
            local c = C_Traits.GetConditionInfo and C_Traits.GetConditionInfo(config, cond)
            if c and c.spentAmountRequired and c.spentAmountRequired > 0 then
                need = math.max(need or 0, c.spentAmountRequired)
            end
        end
        t.need = need or 5 * t.tier
        for _, out in ipairs(t.node.visibleEdges or {}) do
            if m[out.targetNode] then table.insert(m[out.targetNode].sources, id) end
        end
    end
    return m
end

-- why one more rank of a talent cannot follow the plan so far; nil: it can
local function Refuse(m, s, id)
    local t = m[id]
    if not t then return "Not in these trees." end
    if (s.counts[id] or 0) >= t.node.maxRanks then return "Every rank is planned." end
    if #s.kept >= Cap() then return format("All %d points are planned.", Cap()) end
    if (s.spent[t.group] or 0) < t.need then return format("Needs %d points in this tree first.", t.need) end
    for _, from in ipairs(t.sources) do
        if (s.counts[from] or 0) < m[from].node.maxRanks then return "Needs the talent before it." end
    end
end

-- the plan walked: each entry kept while it can follow those before it
local function Walk(m, plan)
    local s = { kept = {}, counts = {}, spent = {} }
    for _, id in ipairs(plan) do
        if not Refuse(m, s, id) then
            table.insert(s.kept, id)
            s.counts[id] = (s.counts[id] or 0) + 1
            s.spent[m[id].group] = (s.spent[m[id].group] or 0) + 1
        end
    end
    return s
end

-- the first entry not learned yet: its place (the point it is, at level
-- place + 9), its talent and the rank it brings that talent to
local function Next(m, plan)
    local counts = {}
    for k, id in ipairs(plan) do
        counts[id] = (counts[id] or 0) + 1
        if m[id] and m[id].node.ranksPurchased < counts[id] then return k, id, counts[id] end
    end
end

-- a plan started from what is learned: tier by tier, left to right
local function Seed(m)
    local list = {}
    for id, t in pairs(m) do
        if t.node.ranksPurchased > 0 then table.insert(list, id) end
    end
    table.sort(list, function(a, b)
        if m[a].tier ~= m[b].tier then return m[a].tier < m[b].tier end
        if m[a].node.posX ~= m[b].node.posX then return m[a].node.posX < m[b].node.posX end
        return a < b
    end)
    local plan = {}
    for _, id in ipairs(list) do
        for _ = 1, m[id].node.ranksPurchased do table.insert(plan, id) end
    end
    return Walk(m, plan).kept
end

-- a rank more planned, or the talent's last taken off with whatever no
-- longer follows
local function Replan(id, less)
    local m = Model(Config())
    local plan = Plan()
    if less then
        local list = {}
        for _, v in ipairs(plan) do table.insert(list, v) end
        for k = #list, 1, -1 do
            if list[k] == id then table.remove(list, k); break end
        end
        Keep(Walk(m, list).kept)
    else
        local s = Walk(m, plan)
        if not Refuse(m, s, id) then
            table.insert(s.kept, id)
            Keep(s.kept)
        end
    end
end

-- Follow: the plan's next entries staged while points are left, stopping
-- at the first the game refuses
local function Follow()
    local config = Config()
    if not (config and Editable()) then return end
    for _ = 1, Cap() do
        if Left(config) <= 0 then break end
        local _, id = Next(Model(config), Plan())
        if not id or not C_Traits.PurchaseRank(config, id) then break end
    end
end

-- ------------------------------------------------------------ the ranks
-- What a talent gives at a rank: the description its tooltip writes for
-- that rank, before the next rank's. Nil when the game cannot say.
local NUMBER = "%d+%.?%d*"
local function AtRank(entry, rank)
    local data = entry and C_TooltipInfo and C_TooltipInfo.GetTraitEntry
        and C_TooltipInfo.GetTraitEntry(entry, rank)
    local DESCRIPTION = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SpellDescription
    local next1 = TOOLTIP_TALENT_NEXT_RANK and TOOLTIP_TALENT_NEXT_RANK:gsub("%%s", "")
    local best
    for i, line in ipairs(data and data.lines or {}) do
        local text = type(line.leftText) == "string" and line.leftText or ""
        if (next1 and next1 ~= "" and text:find(next1, 1, true))
            or (NEXT_RANK_COLON and text == NEXT_RANK_COLON) then break end
        if i > 1 and DESCRIPTION and line.type == DESCRIPTION then return text end
        if i > 1 and (not best or #text > #best) then best = text end
    end
    return best ~= "" and best or nil
end

-- a number as a description writes it, without a sentence's full stop
local function Number(n)
    local bare = n:gsub("%.$", "")
    return bare, n:sub(#bare + 1)
end

-- Each rank's description as one: where the ranks differ only in their
-- numbers, the numbers side by side ("by 33% / 66% / 100%"), the rank at
-- in green; otherwise a line per rank.
local function Ranks(texts, at)
    if #texts < 2 then return texts[1] end
    local shape, numbers = texts[1]:gsub(NUMBER, "#"), {}
    for r, t in ipairs(texts) do
        if t:gsub(NUMBER, "#") ~= shape then
            local lines = {}
            for i, line in ipairs(texts) do
                local c = i == at and "|cff66d959" or "|cffb3a88c"
                table.insert(lines, format("%sRank %d:|r %s", c, i, line))
            end
            return table.concat(lines, "\n")
        end
        numbers[r] = {}
        for n in t:gmatch(NUMBER) do table.insert(numbers[r], (Number(n))) end
    end
    local k = 0
    return (texts[1]:gsub(NUMBER, function(n)
        k = k + 1
        local _, stop = Number(n)
        local list, same = {}, true
        for r = 1, #texts do
            list[r] = numbers[r][k]
            same = same and list[r] == list[1]
        end
        if same then return n end
        if list[at] then list[at] = "|cff66d959" .. list[at] .. "|r" end
        return table.concat(list, " / ") .. stop
    end))
end

-- a talent's description, every rank's, or its spell's when the game
-- cannot say one rank's
local function Describe(n)
    local node, texts = n.node, {}
    for r = 1, node.maxRanks do
        local t = AtRank(n.talent.entry, r)
        if not t then texts = {}; break end
        texts[r] = t
    end
    return Ranks(texts, node.ranksPurchased)
        or (n.talent.spell and C_Spell.GetSpellDescription(n.talent.spell)) or ""
end

-- --------------------------------------------------------------- talents
-- The talent's own name over its rank and every rank's description: the
-- game's own tooltip for a talent heads it with "Passive".
local function Tooltip(owner, n)
    local text, lock = Describe(n), Lock(n.node)
    local plan = planning and n.planned
    ns.Tip(owner, "ANCHOR_RIGHT", { title = n.talent.name, color = GOLD,
        { "body", format("Rank %d/%d", n.node.ranksPurchased, n.node.maxRanks)
            .. (plan and format("  ·  Planned %d/%d", n.planned, n.node.maxRanks) or ""), ns.colors.dim },
        text ~= "" and { "body", text } or false,
        plan and n.refusal and { "warn", n.refusal } or not plan and lock and { "warn", lock } or false })
end

local function Click(p, b, button)
    p.chosen = b.node.ID
    if planning then
        Replan(b.node.ID, button == "RightButton")
    elseif Editable() then
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
    -- planned and not learned: a gold ring round the edge, the next the brightest
    b.halo = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.halo:SetPoint("TOPLEFT", -5, 5)
    b.halo:SetPoint("BOTTOMRIGHT", 5, -5)
    b.halo:Hide()
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

-- A tree's talents where the tree puts them, under the points' row. One
-- scale for the three, the largest filling the page, so a tier stands at
-- one height on every tab; each tree centred across the page, from its top.
-- A tree is every talent in its group, wherever the group stands among the
-- talent's groups.
-- plan: the plan walked (planning or not), its model and its next talent
local function Draw(p, config, group, groups, plan)
    local span = { x = 0, y = 0 }
    local box, list = {}, {}
    for _, id in ipairs(C_Traits.GetTreeNodes(Tree(config)) or {}) do
        local node = C_Traits.GetNodeInfo(config, id)
        if node and node.isVisible then
            for _, g in ipairs(groups) do
                if InGroup(node, g.groupID) then
                    local b = box[g.groupID] or { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge }
                    b.x0, b.x1 = math.min(b.x0, node.posX), math.max(b.x1, node.posX)
                    b.y0, b.y1 = math.min(b.y0, node.posY), math.max(b.y1, node.posY)
                    box[g.groupID] = b
                    span.x, span.y = math.max(span.x, b.x1 - b.x0), math.max(span.y, b.y1 - b.y0)
                end
            end
            if InGroup(node, group.groupID) then table.insert(list, node) end
        end
    end
    local width = W.width - 2 * MARGIN - ICON
    local height = (p.body:GetHeight() or 0) - STRIP - 2 * MARGIN - ICON
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
            -(STRIP + MARGIN + ICON / 2 + (node.posY - y0) * scale))
        b.icon:SetTexture(b.talent.icon)
        b.planned = plan.counts[node.ID] or 0
        b.refusal = Refuse(plan.model, plan, node.ID)
        -- planning: the ranks planned, and whether one more can be;
        -- otherwise the ranks learned, and whether one more can be staged
        local ranks = planning and b.planned or node.ranksPurchased
        local maxed = ranks >= node.maxRanks
        local open
        if planning then
            open = ranks > 0 or not b.refusal
        else
            open = maxed or ranks > 0 or (node.isAvailable and node.meetsEdgeRequirements)
        end
        b.icon:SetDesaturated(not open)
        b.icon:SetAlpha(open and 1 or 0.5)
        local can = planning and not b.refusal or not planning and open and editable and node.canPurchaseRank
        local edge = maxed and GOLD or can and LIT or GOLD_D
        b.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
        b.rank:SetText(ranks .. "/" .. node.maxRanks)
        local text = maxed and GOLD or ranks > 0 and LIT or ns.colors.dim
        b.rank:SetTextColor(text[1], text[2], text[3])
        local ahead = not planning and b.planned > node.ranksPurchased
        b.halo:SetShown(ahead)
        b.halo:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], node.ID == plan.next and 0.9 or 0.35)
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
                local active = out.isActive
                if planning then active = b.planned >= b.node.maxRanks end
                local c = active and GOLD or GOLD_D
                l:SetColorTexture(c[1], c[2], c[3], active and 1 or 0.6)
                l:Show()
            end
        end
    end
    for i = e + 1, #p.edges do p.edges[i]:Hide() end
    return byID
end

-- ------------------------------------------------------------- the foot
-- the margin: which talents are in view, which in use, and Order marked
-- while the plan's list shows
local function Band(p)
    local active, groupsLearned = Active(), GetNumSpecGroups and GetNumSpecGroups() or 1
    for i, b in ipairs(p.specs) do
        b.mark:SetShown(i == Viewed())
        local c = i == active and GOLD or ns.colors.dim
        b.label:SetTextColor(c[1], c[2], c[3])
        b:SetAlpha(i <= groupsLearned and 1 or 0.4)
    end
    p.activate:SetShown(Viewed() ~= active)
    p.activate:SetAlpha(InCombatLockdown() and 0.4 or 1)
    p.order.mark:SetShown(p.list and true or false)
end

local function Refresh(p)
    local config = Config()
    local groups = Groups()
    local group = groups[p.tree]
    if not (config and group) then return end
    local m = Model(config)
    local plan = Walk(m, Plan())
    local place, nextID, nextRank = Next(m, plan.kept)
    plan.model, plan.next = m, nextID
    local byID = Draw(p, config, group, groups, plan)
    local chosen = p.chosen and byID[p.chosen]
    if chosen then
        local node, t = chosen.node, chosen.talent
        local why = planning and chosen.refusal or not planning and Lock(node)
        p.details:Set({ title = t.name, sub = format("Rank %d/%d", node.ranksPurchased, node.maxRanks)
            .. (planning and format("  ·  Planned %d/%d", chosen.planned, node.maxRanks) or "")
            .. (why and ("  ·  " .. why) or ""), text = Describe(chosen) })
    else
        -- nothing chosen: what a click does in the plan's mode, or the
        -- plan's next talent
        local nextOne = nextID and m[nextID]
        p.details.nothing:SetText(planning and "Click a talent to plan a rank of it; right-click takes one off."
            or nextOne and format("Next in your plan: %s %d/%d, at level %d.", Entry(config, nextOne.node).name,
                nextRank, nextOne.node.maxRanks, place + 9)
            or "Choose a talent to read it.")
        p.details:Set(nil)
    end
    -- the points: left to spend (or planned), and in this tree (the tabs'
    -- tips say each)
    local spent = Spent(config, groups)
    if planning then
        p.points:SetText(format("Plan %d/%d  ·  %s %d", #plan.kept, Cap(), group.displayName,
            plan.spent[group.groupID] or 0))
    else
        p.points:SetText(format("%d |4point:points; available  ·  %s %d", Left(config), group.displayName,
            spent[group.groupID] or 0))
    end
    local staged = C_Traits.ConfigHasStagedChanges(config)
    p.apply:SetShown(staged)
    p.reset:SetShown(staged)
    p.apply:SetAlpha(Editable() and 1 or 0.4)
    p.planButton.mark:SetShown(planning and true or false)
    p.wash:SetShown(planning and true or false)
    p.follow:SetShown(not planning and nextID ~= nil and Editable() and Left(config) > 0)
    p.follow:ClearAllPoints()
    if staged then p.follow:SetPoint("RIGHT", p.apply, "LEFT", -4, 0) else p.follow:SetPoint("RIGHT", -4, 0) end
    Band(p)
end

local SPECS = { "Primary", "Secondary" }
local orderPage, back                   -- the plan's list, and the tree it was opened from

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
    -- the plan's list, and back from it to the tree it was opened over
    p.order = ns.window.Button(band, 64, function()
        if W.Current() == orderPage then
            local to = back and back.available and back
            for _, page in ipairs(W.pages) do
                if not to and page.available and not page.tabless then to = page end
            end
            if to then W.Select(to) end
        else
            back = W.Current()
            W.Select(orderPage)
        end
    end, function()
        return W.Current() == orderPage and "Back to the trees." or "The order your plan learns its talents in."
    end)
    p.order.label:SetText("Order")
    p.order:SetPoint("LEFT", prev, "RIGHT", 12, 0)
    p.activate:SetPoint("LEFT", p.order, "RIGHT", 4, 0)
end

-- the points' row over the tree: [Reset]  points available  [Apply]
local function Points(p, body)
    local strip = CreateFrame("Frame", nil, body)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(STRIP)
    p.points = ns.Text(strip, 12)
    p.points:SetPoint("CENTER", 0, 0)
    p.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    p.apply = ns.window.Button(strip, 64, function()
        if not Editable() then return end
        C_ClassTalents.CommitConfig()
    end, function() return InCombatLockdown() and "Not in combat." or "Learn the talents chosen." end)
    p.apply.label:SetText("Apply")
    p.apply:SetHeight(STRIP - 2)
    p.apply:SetPoint("RIGHT", -4, 0)
    p.reset = ns.window.Button(strip, 64, function()
        C_Traits.RollbackConfig(Config())
        W.Refresh()
    end, function() return "Forget the talents chosen." end)
    p.reset.label:SetText("Reset")
    p.reset:SetHeight(STRIP - 2)
    -- the plan's mode, started from the talents learned when there is none
    p.planButton = ns.window.Button(strip, 52, function()
        planning = not planning
        if planning and #Plan() == 0 then Keep(Seed(Model(Config()))) end
        W.Refresh()
    end, function()
        return planning and "Back to learning talents." or "Plan the order to learn talents in."
    end)
    p.planButton.label:SetText("Plan")
    p.planButton:SetHeight(STRIP - 2)
    p.planButton:SetPoint("LEFT", 4, 0)
    p.reset:SetPoint("LEFT", p.planButton, "RIGHT", 4, 0)
    p.follow = ns.window.Button(strip, 64, function()
        Follow()
        W.Refresh()
    end, function() return "Choose the plan's next talents, as many as your points; Apply learns them." end)
    p.follow.label:SetText("Follow")
    p.follow:SetHeight(STRIP - 2)
end

local function Foot(p, foot)
    p.details = ns.character.Details(foot, nil, "Choose a talent to read it.", 4)
    p.footHeight = p.details.height
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
        -- the plan's mode at a glance: the tree's ground washed blue, under
        -- its lines and talents
        p.wash = body:CreateTexture(nil, "BACKGROUND", nil, -8)
        p.wash:SetAllPoints()
        p.wash:SetColorTexture(PLANNING[1], PLANNING[2], PLANNING[3], PLANNING[4])
        Points(p, body)
        Foot(p, foot)
        Margin(p, band)
    end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end

-- ------------------------------------------------------------ the order
-- The plan as a list: the level each entry comes at, the talent and the
-- rank it brings, its tree; learned ones ticked and dim, the next marked.
local LINE, GUTTER = 24, 10

local function Row(p, i)
    local r = CreateFrame("Button", nil, p.list.child)
    r:SetHeight(LINE)
    r.mark = r:CreateTexture(nil, "BACKGROUND")
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    r.at = ns.Text(r, 12)
    r.at:SetPoint("LEFT", 0, 0)
    r.at:SetWidth(24)
    r.at:SetJustifyH("RIGHT")
    r.at:SetTextColor(unpack(ns.colors.dim))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(LINE - 4, LINE - 4)
    r.icon:SetPoint("LEFT", 32, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.tick = r:CreateTexture(nil, "ARTWORK")
    r.tick:SetSize(14, 14)
    r.tick:SetPoint("RIGHT", -4, 0)
    r.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    r.tree = ns.Text(r, 11)
    r.tree:SetPoint("RIGHT", -24, 0)
    r.tree:SetTextColor(unpack(ns.colors.dim))
    r.name = ns.Text(r, 12)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.tree, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    -- a click opens the talent's tree, the talent chosen
    r:SetScript("OnClick", function(self)
        for _, page in ipairs(W.pages) do
            local g = page.tree and Groups()[page.tree]
            if g and g.groupID == self.group and page.available then
                page.chosen = self.id
                W.Select(page)
                return
            end
        end
    end)
    r:SetScript("OnEnter", function(self) if self.talent then Tooltip(self, self) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = r
    return r
end

local function RefreshOrder(p)
    local config = Config()
    if not config then return end
    local m = Model(config)
    local plan = Walk(m, Plan())
    local place = Next(m, plan.kept)
    local names = {}
    for _, g in ipairs(Groups()) do names[g.groupID] = g.displayName end
    local counts, learned = {}, 0
    for k, id in ipairs(plan.kept) do
        local r = p.rows[k] or Row(p, k)
        local t = m[id]
        counts[id] = (counts[id] or 0) + 1
        local done = t.node.ranksPurchased >= counts[id]
        if done then learned = learned + 1 end
        r.id, r.group, r.node, r.talent, r.planned = id, t.group, t.node, Entry(config, t.node), nil
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(k - 1) * LINE)
        r:SetWidth(W.width - GUTTER)
        r.at:SetText(k + 9)
        r.icon:SetTexture(r.talent.icon)
        r.icon:SetDesaturated(done)
        r.name:SetText(format("%s %d/%d", r.talent.name, counts[id], t.node.maxRanks))
        local c = done and ns.colors.dim or k == place and GOLD or ns.colors.text
        r.name:SetTextColor(c[1], c[2], c[3])
        r.tree:SetText(names[t.group] or "")
        r.tick:SetShown(done)
        r.mark:SetShown(k == place)
        r:Show()
    end
    for k = #plan.kept + 1, #p.rows do p.rows[k]:Hide() end
    p.list.child:SetSize(W.width - GUTTER, math.max(1, #plan.kept * LINE))
    p.list.To(p.list.target)
    p.points:SetText(format("Plan %d/%d  ·  %d learned", #plan.kept, Cap(), learned))
    p.clear:SetShown(#plan.kept > 0)
    p.details.nothing:SetText(#plan.kept == 0
        and "No plan yet: press Plan over a tree, then click its talents in order."
        or place and format("Next: level %d. Click an entry to open its talent.", place + 9)
        or "Every talent in the plan is learned.")
    p.details:Set(nil)
    Band(p)
end

-- the order's page: no tab, Order in the margin opens it
do
    local p = { key = "order", tabless = true, order = TREES + 1, label = "Order", frame = "TalentsFrame" }
    p.rows = {}
    p.flex, p.height, p.bandUsed = true, 0, true
    p.events = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    function p.Available() return C_Traits and C_SpecializationInfo and Groups()[1] ~= nil end
    function p.Build(body, foot, band)
        local strip = CreateFrame("Frame", nil, body)
        strip:SetPoint("TOPLEFT")
        strip:SetPoint("TOPRIGHT")
        strip:SetHeight(STRIP)
        p.points = ns.Text(strip, 12)
        p.points:SetPoint("CENTER", 0, 0)
        p.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        -- Clear plan asks twice: the first press arms it, leaving disarms it
        p.clear = ns.window.Button(strip, 92, function(self)
            if not self.armed then
                self.armed = true
                self.label:SetText("Press again")
                return
            end
            Keep({})
            planning = false
            self.armed = nil
            self.label:SetText("Clear plan")
            W.Refresh()
        end, function() return "Forget this specialisation's plan." end)
        p.clear.label:SetText("Clear plan")
        p.clear:SetHeight(STRIP - 2)
        p.clear:SetPoint("LEFT", 4, 0)
        p.clear:HookScript("OnLeave", function(self)
            self.armed = nil
            self.label:SetText("Clear plan")
        end)
        local area = CreateFrame("Frame", nil, body)
        area:SetPoint("TOPLEFT", 0, -STRIP)
        area:SetPoint("BOTTOMRIGHT")
        p.list = ns.window.Scroller(area, GUTTER)
        area:EnableMouseWheel(true)
        area:SetScript("OnMouseWheel", function(_, delta) p.list.To(p.list.target - delta * LINE * 3) end)
        p.details = ns.character.Details(foot, nil, "", 4)
        p.footHeight = p.details.height
        Margin(p, band)
    end
    function p.Refresh() RefreshOrder(p) end
    W.Page(p)
    orderPage = p
end

function W.Refresh()
    local p = W.Current()
    if p and W.window:IsShown() then p.Refresh() end
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
