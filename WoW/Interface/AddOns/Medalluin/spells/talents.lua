-- The talents: Medalluin's own (the shell is window/shell.lua), standing on
-- the right strip as the spellbook does, its margin beside the backpack's
-- medallion. Forever only: its talents are one tree of three groups, the
-- old trees, drawn by Blizzard side by side; retail's keep Blizzard's.
--
--   [tree][tree][tree]                                          [x]
--   ---------------------------------------------------------------
--   [Reset]       12 points available  ·  Elemental 5  [Follow] [Apply]
--        [o]     [o]                (a tree's talents, where the
--         |                          tree puts them, with the
--        [o] 2/5 [o]     [o]         lines between them)
--   ...
--   ---------------------------------------------------------------
--   the chosen talent's name, rank and what each rank gives; in the
--   plan's mode, [Exit plan] [Checkpoint] [Save plan]         [name]
--        and a hint: why a click was refused, or what comes next
--   ---------------------------------------------------------------
--   (backpack)   [Primary] [Secondary] | [Plans] [Activate]
--
-- A tab per tree, the game's own icons. A click spends a rank, a right-click
-- takes one back: both only staged, until Apply commits them (Reset
-- forgets them). A talent's tooltip and the details say what each rank
-- gives: "by 33% / 66% / 100%", the rank it is at in green. In the plan's
-- mode the foot is the plan's controls instead, and it never folds. The
-- margin views the Primary or the Secondary talents; the one not in use
-- reads only, and Activate switches to it (a cast).
--
-- A plan: the order to learn talents in, as checkpoints, one talent and
-- the ranks it takes each. Plans are named, several for each
-- specialisation, one of them active (MedalluinCharDB.talentPlans
-- [specGroup] = { active, list = { { name, steps } } }, steps the node IDs,
-- a rank an entry). Create Plan, on the plans' page, turns the plan's mode
-- on over a tree, the tree's ground blue: a
-- simulation from nothing, the talents learned left out. A click adds a
-- point, a right-click takes the talent's last off (and whatever after it
-- no longer follows). The points clicked since the last Checkpoint are its
-- draft, of one talent only: Checkpoint keeps them as a step, and another
-- talent waits for it. Save plan names the plan and keeps it (a name
-- already kept is replaced), the plan saved becoming the active one;
-- nothing is kept before, so leaving the mode, the window or the
-- specialisation unsaved loses it. The game will not judge a plan, so the
-- rules are ours: a tier's points in its tree (the node's condition, or 5
-- a tier), the talent before it planned to its last rank, a talent's
-- ranks, and the points a character ever has (the top level less 9). Out
-- of the mode, the active plan's talents not learned glow, the next the
-- brightest; Follow stages its next entries, as many as the points left,
-- for Apply to learn. Plans, in the margin, lists the plans kept, each
-- under a head that folds it (Use makes one active), with its checkpoints
-- (the levels each comes at, the learned ticked, the active one's next
-- marked; a click opens its talent); its foot has Create Plan, Edit (the
-- active plan drawn again, from its last checkpoint) and Remove.
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
local STRIP = 26                        -- a row of controls: the points' over the tree, the plan's under it
local HEAD = STRIP                      -- what stands over the tree
local FOOT = 6 + STRIP + 6 + 2 * 15     -- the plan's row and two lines of hint under it

local W = ns.Window{
    name = "MedalluinTalents", side = 1,
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
-- the plan being drawn in the mode, kept nowhere until saved: its
-- checkpoints' ranks, the draft (one talent's ranks since the last), and
-- the name it was saved or opened under
local sim

-- the plans kept for the talents in view; the one unnamed plan of before
-- (MedalluinCharDB.talentPlan) becomes the first, "Plan", and active
local function Book()
    MedalluinCharDB = MedalluinCharDB or {}
    if type(MedalluinCharDB.talentPlans) ~= "table" then MedalluinCharDB.talentPlans = {} end
    local all, spec = MedalluinCharDB.talentPlans, Viewed()
    if type(all[spec]) ~= "table" then
        all[spec] = { list = {} }
        local old = type(MedalluinCharDB.talentPlan) == "table" and MedalluinCharDB.talentPlan[spec]
        if type(old) == "table" and #old > 0 then
            all[spec].list[1], all[spec].active = { name = "Plan", steps = old }, 1
        end
        if type(MedalluinCharDB.talentPlan) == "table" then MedalluinCharDB.talentPlan[spec] = nil end
    end
    return all[spec]
end
-- the active plan, and its ranks in order (none: an empty list)
local function Chosen()
    local b = Book()
    return b.active and b.list[b.active]
end
local function Plan()
    local plan = Chosen()
    return plan and plan.steps or {}
end
local function Copy(list)
    local out = {}
    for k, v in ipairs(list) do out[k] = v end
    return out
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

-- a rank added to a walk
local function Push(m, s, id)
    table.insert(s.kept, id)
    s.counts[id] = (s.counts[id] or 0) + 1
    s.spent[m[id].group] = (s.spent[m[id].group] or 0) + 1
end

-- the plan walked: each entry kept while it can follow those before it
local function Walk(m, plan)
    local s = { kept = {}, counts = {}, spent = {} }
    for _, id in ipairs(plan) do
        if not Refuse(m, s, id) then Push(m, s, id) end
    end
    return s
end

-- the plan being drawn: its checkpoints' ranks, then the draft's
local function Drawn()
    local list = Copy(sim.steps)
    for _ = 1, sim.draft and sim.draft.n or 0 do table.insert(list, sim.draft.id) end
    return list
end

-- why a point cannot be added to the plan being drawn: the draft holds
-- another talent, or the rules refuse it
local function Why(m, s, id)
    local d = sim and sim.draft
    if d and d.id ~= id and m[d.id] then
        return format("Checkpoint %s first.", Entry(Config(), m[d.id].node).name)
    end
    return Refuse(m, s, id)
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

-- a point added to the draft
local function Add(id)
    local m = Model(Config())
    if Why(m, Walk(m, Drawn()), id) then return end
    sim.draft = { id = id, n = (sim.draft and sim.draft.n or 0) + 1 }
    sim.saved = false
end

-- the talent's last point taken off: from the draft when it is the
-- draft's, else from its last checkpoint, with whatever no longer follows
-- (the draft too, as far as it no longer does)
local function Remove(id)
    local m = Model(Config())
    local steps, d = sim.steps, sim.draft
    local n = d and d.n or 0
    if d and d.id == id then
        n = n - 1
    else
        local list, found = Copy(steps), false
        for k = #list, 1, -1 do
            if list[k] == id then table.remove(list, k); found = true; break end
        end
        if not found then return end
        steps = Walk(m, list).kept
    end
    local s, kept = Walk(m, steps), 0
    while kept < n and not Refuse(m, s, d.id) do
        Push(m, s, d.id)
        kept = kept + 1
    end
    sim.steps = steps
    sim.draft = kept > 0 and { id = d.id, n = kept } or nil
    sim.saved = false
end

-- the draft kept as a checkpoint
local function Checkpoint()
    local d = sim.draft
    if not d then return end
    for _ = 1, d.n do table.insert(sim.steps, d.id) end
    sim.draft = nil
end

-- the plan drawn kept under a name, replacing one of that name, and made
-- the active plan
local function Save(name)
    local b = Book()
    local at
    for k, plan in ipairs(b.list) do
        if plan.name == name then at = k end
    end
    if at then
        b.list[at].steps = Copy(sim.steps)
    else
        table.insert(b.list, { name = name, steps = Copy(sim.steps) })
        at = #b.list
    end
    b.active = at
    sim.name, sim.saved = name, true
end

-- the mode on, drawing a plan from nothing or from one kept; off, the
-- plan drawn is forgotten (nothing reads it out of the mode, and the next
-- Begin replaces it). A plan kept is opened at its last checkpoint: that
-- talent's run is the draft again, so going on takes a Checkpoint first
local function Begin(steps, name)
    planning = true
    sim = { steps = Copy(steps or {}), name = name, saved = name ~= nil }
    local list, id, n = sim.steps, sim.steps[#sim.steps], 0
    while id and list[#list] == id do
        table.remove(list)
        n = n + 1
    end
    if n > 0 then sim.draft = { id = id, n = n } end
end
local function End()
    planning = nil
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
    ns.Tip(owner, ns.window.Outside, { title = n.talent.name, color = GOLD,
        { "body", format("Rank %d/%d", n.node.ranksPurchased, n.node.maxRanks)
            .. (plan and format("  ·  Planned %d/%d", n.planned, n.node.maxRanks) or ""), ns.colors.dim },
        text ~= "" and { "body", text } or false,
        plan and n.refusal and { "warn", n.refusal } or not plan and lock and { "warn", lock } or false })
end

local function Click(p, b, button)
    p.chosen = b.node.ID
    if planning then
        if button == "RightButton" then Remove(b.node.ID) else Add(b.node.ID) end
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
    local height = (p.body:GetHeight() or 0) - HEAD - 2 * MARGIN - ICON
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
            -(HEAD + MARGIN + ICON / 2 + (node.posY - y0) * scale))
        b.icon:SetTexture(b.talent.icon)
        b.planned = plan.counts[node.ID] or 0
        b.refusal = Why(plan.model, plan, node.ID)
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
-- the margin: which talents are in view (marked), which in use (gold),
-- Plans marked while the plan's list shows, Activate while another's are
-- in view (off in combat)
local function Band(p)
    local active, groupsLearned = Active(), GetNumSpecGroups and GetNumSpecGroups() or 1
    for i in ipairs(p.specs) do
        p.margin:Set(i, { selected = i == Viewed(), enabled = i <= groupsLearned,
            color = i == active and GOLD or ns.colors.dim })
    end
    p.margin:Set("activate", { shown = Viewed() ~= active, enabled = not InCombatLockdown() })
    p.margin:Set("plans", { selected = p.list and true or false })
end

local function Refresh(p)
    local config = Config()
    local groups = Groups()
    local group = groups[p.tree]
    if not (config and group) then return end
    local m = Model(config)
    local plan = Walk(m, planning and Drawn() or Plan())
    local place, nextID, nextRank = Next(m, plan.kept)
    plan.model, plan.next = m, nextID
    local d = planning and sim.draft
    local byID = Draw(p, config, group, groups, plan)
    -- the foot: in the plan's mode its row and a hint (why the talent last
    -- clicked was refused, else what the Checkpoint keeps, else what a
    -- click does); otherwise the talent chosen, or the plan's next
    local chosen = p.chosen and byID[p.chosen]
    p.planRow:SetShown(planning and true or false)
    p.hint:SetShown(planning and true or false)
    if planning then
        p.details:Set(nil)
        p.details.nothing:Hide()
        local why = chosen and chosen.refusal
        p.hint:SetText(why and format("%s: %s", chosen.talent.name, why)
            or d and format("Checkpoint keeps %s %d/%d as a step of the plan.",
                Entry(config, m[d.id].node).name, plan.counts[d.id], m[d.id].node.maxRanks)
            or "Click a talent to add a point to the plan; right-click takes its last off.")
    elseif chosen then
        local node, t = chosen.node, chosen.talent
        local why = Lock(node)
        p.details:Set({ title = t.name, sub = format("Rank %d/%d", node.ranksPurchased, node.maxRanks)
            .. (why and ("  ·  " .. why) or ""), text = Describe(chosen) })
    else
        local nextOne = nextID and m[nextID]
        p.details.nothing:SetText(nextOne and format("Next in your plan: %s %d/%d, at level %d.",
                Entry(config, nextOne.node).name, nextRank, nextOne.node.maxRanks, place + 9)
            or "Choose a talent to read it.")
        p.details:Set(nil)
    end
    -- the points: left to spend (or planned), and in this tree (the tabs'
    -- tips say each)
    local spent = Spent(config, groups)
    if planning then
        p.points:SetText(format("%s  ·  %d/%d  ·  %s %d", sim.name or "New plan", #plan.kept, Cap(),
            group.displayName, plan.spent[group.groupID] or 0))
    else
        p.points:SetText(format("%d |4point:points; available  ·  %s %d", Left(config), group.displayName,
            spent[group.groupID] or 0))
    end
    local staged = not planning and C_Traits.ConfigHasStagedChanges(config)
    p.apply:SetShown(staged)
    p.reset:SetShown(staged)
    p.checkpoint:SetShown(d and true or false)
    p.save:ClearAllPoints()
    p.save:SetPoint("LEFT", d and p.checkpoint or p.exit, "RIGHT", 4, 0)
    p.save:SetShown(planning and (#sim.steps > 0 or d) and true or false)
    p.save:SetAlpha(d and 0.4 or 1)
    if not planning then p.name:Hide() end
    p.apply:SetAlpha(Editable() and 1 or 0.4)
    p.wash:SetShown(planning and true or false)
    p.follow:SetShown(not planning and nextID ~= nil and Editable() and Left(config) > 0)
    p.follow:ClearAllPoints()
    if staged then p.follow:SetPoint("RIGHT", p.apply, "LEFT", -4, 0) else p.follow:SetPoint("RIGHT", -4, 0) end
    Band(p)
end

-- the window's buttons, soft: the surface under them shows through
local function Button(parent, width, click, tip)
    return ns.window.Button(parent, width, click, tip, nil, true)
end

local SPECS = { "Primary", "Secondary" }
local plansPage, back                   -- the plans' page, and the tree it was opened from

-- back to the tree the plans were opened from, or the first
local function Back()
    local to = back and back.available and back
    for _, page in ipairs(W.pages) do
        if not to and page.available and not page.tabless then to = page end
    end
    if to then W.Select(to) end
end

-- The margin, edge to edge: the specialisations, then the plans and
-- Activate past a divider, joined (ns.window.Segments)
local function Margin(p, band)
    local items = {}
    for i, name in ipairs(SPECS) do
        table.insert(items, { key = i, label = name, group = "specs", click = function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then return end
            if i ~= Viewed() then End() end
            view = i
            p.chosen = nil
            W.Refresh()
        end, tip = function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then
                return "Learn a second specialization to use " .. name:lower() .. " talents."
            end
            return format("View your %s talents.", name:lower()) .. (i == Active() and " They are in use." or "")
        end })
    end
    -- the plans kept, and back from them to the tree they were opened over
    table.insert(items, { key = "plans", label = "Plans", group = "plans", click = function()
        if W.Current() == plansPage then Back() else
            back = W.Current()
            W.Select(plansPage)
        end
    end, tip = function()
        return W.Current() == plansPage and "Back to the trees."
            or "The plans kept, and the order the active one learns in."
    end })
    table.insert(items, { key = "activate", label = "Activate", group = "plans", click = function()
        if InCombatLockdown() or Viewed() == Active() then return end
        C_SpecializationInfo.SetActiveSpecGroup(Viewed())
    end, tip = function()
        return InCombatLockdown() and "Not in combat." or format("Use your %s talents.", SPECS[Viewed()]:lower())
    end })
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = items })
    row:SetPoint("TOPLEFT")
    row:SetPoint("TOPRIGHT")
    p.margin = row
    p.specs = { row.byKey[1], row.byKey[2] }
    p.plans, p.activate = row.byKey.plans, row.byKey.activate
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
    p.apply = Button(strip, 64, function()
        if not Editable() then return end
        C_ClassTalents.CommitConfig()
    end, function() return InCombatLockdown() and "Not in combat." or "Learn the talents chosen." end)
    p.apply.label:SetText("Apply")
    p.apply:SetHeight(STRIP - 2)
    p.apply:SetPoint("RIGHT", -4, 0)
    p.reset = Button(strip, 64, function()
        C_Traits.RollbackConfig(Config())
        W.Refresh()
    end, function() return "Forget the talents chosen." end)
    p.reset.label:SetText("Reset")
    p.reset:SetHeight(STRIP - 2)
    p.reset:SetPoint("LEFT", 4, 0)
    p.follow = Button(strip, 64, function()
        Follow()
        W.Refresh()
    end, function() return "Choose the plan's next talents, as many as your points; Apply learns them." end)
    p.follow.label:SetText("Follow")
    p.follow:SetHeight(STRIP - 2)
end

-- a foot's hint, under its row of buttons: two lines, wrapping
local function Hint(foot)
    local hint = ns.Text(foot, 12)
    hint:SetPoint("TOPLEFT", 8, -(6 + STRIP + 6))
    hint:SetPoint("TOPRIGHT", -8, -(6 + STRIP + 6))
    hint:SetJustifyH("CENTER")
    hint:SetWordWrap(true)
    hint:SetTextColor(unpack(ns.colors.dim))
    return hint
end

-- the foot: in the plan's mode, where the plan is worked ([Exit plan]
-- [Checkpoint] [Save plan] and the name asked for, a hint under them);
-- otherwise the chosen talent's details
local function Foot(p, foot)
    local row = CreateFrame("Frame", nil, foot)
    p.planRow = row
    row:SetPoint("TOPLEFT", 0, -6)
    row:SetPoint("TOPRIGHT", 0, -6)
    row:SetHeight(STRIP)
    -- out of the plan's mode (Create Plan and Edit, on the plans' page,
    -- bring it); the plan drawn is forgotten unless saved
    p.exit = Button(row, 72, function()
        End()
        p.chosen = nil
        W.Refresh()
    end, function()
        return sim.saved and "Back to learning talents." or "Back to learning talents; the plan is lost unless saved."
    end)
    p.exit.label:SetText("Exit plan")
    p.exit:SetHeight(STRIP - 2)
    p.exit:SetPoint("LEFT", 4, 0)
    p.checkpoint = Button(row, 84, function()
        Checkpoint()
        W.Refresh()
    end, function() return "Keep the points added as one step of the plan." end)
    p.checkpoint.label:SetText("Checkpoint")
    p.checkpoint:SetHeight(STRIP - 2)
    p.checkpoint:SetPoint("LEFT", p.exit, "RIGHT", 4, 0)
    -- Save plan asks for the name in a box on the row: Enter keeps it,
    -- Escape (or leaving the box) does not
    p.save = Button(row, 76, function()
        if sim.draft then return end
        p.name:SetText(sim.name or format("Plan %d", #Book().list + 1))
        p.name:Show()
        p.name:SetFocus()
        p.name:HighlightText()
    end, function()
        local d = sim.draft
        return d and format("Checkpoint %s first.", Entry(Config(), Model(Config())[d.id].node).name)
            or "Name the plan and keep it; a plan of that name is replaced."
    end)
    p.save.label:SetText("Save plan")
    p.save:SetHeight(STRIP - 2)
    p.name = CreateFrame("EditBox", nil, row)
    p.name:SetAutoFocus(false)
    p.name:SetFont(ns.font, 12, "")
    p.name:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    p.name:SetTextInsets(6, 6, 0, 0)
    p.name:SetMaxLetters(32)
    p.name:SetSize(140, STRIP - 4)
    p.name:SetPoint("RIGHT", -4, 0)
    local well = p.name:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.85)
    p.name:Hide()
    p.name:SetScript("OnEnterPressed", function(self)
        local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
        self:ClearFocus()
        if name ~= "" and planning and not sim.draft then Save(name) end
        W.Refresh()
    end)
    p.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.name:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    p.hint = Hint(foot)
    -- out of the mode, the talent chosen: its rank and what each gives
    p.details = ns.character.Details(foot, nil, "Choose a talent to read it.", 4)
    p.footHeight = math.max(FOOT, p.details.height)
end

-- ------------------------------------------------------------------ pages
for i = 1, TREES do
    local p = { key = "tree" .. i, tree = i, order = i, label = "", frame = "TalentsFrame" }
    p.nodes, p.edges = {}, {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
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

-- ------------------------------------------------------------ the plans
-- The plans kept, each under a head of its own: a fold chevron, its name,
-- its points, and Use when it is not the active one (Active when it is).
-- A click on the head folds its checkpoints away or back (kept with the
-- plan). Under it, its checkpoints: the levels each comes at, the talent
-- and the rank it reaches, its tree; learned ones ticked and dim, the
-- active plan's next marked. A checkpoint is a run of one talent in it.
local LINE, GUTTER, HEADER, GAP, LABELS = 24, 10, 28, 6, 20
local FOLD = 14

-- a plan's head: darker than the page, with an edge, as a section's
local function Head(p, i)
    local h = CreateFrame("Button", nil, p.list.child)
    h:SetHeight(HEADER)
    local edge = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    local ground = h:CreateTexture(nil, "BACKGROUND", nil, 2)
    ground:SetPoint("TOPLEFT", 1, -1)
    ground:SetPoint("BOTTOMRIGHT", -1, 1)
    ground:SetColorTexture(0, 0, 0, 0.55)
    h.ground = ground
    h.fold = h:CreateTexture(nil, "ARTWORK")
    h.fold:SetSize(FOLD, FOLD)
    h.fold:SetPoint("LEFT", 8, 0)
    h.fold:SetTexture(ns.media .. "strips\\chevron-double")
    h.name = ns.Text(h, 13)
    h.name:SetPoint("LEFT", h.fold, "RIGHT", 8, 0)
    h.name:SetJustifyH("LEFT")
    h.name:SetWordWrap(false)
    h.use = Button(h, 48, function(self)
        Book().active = self:GetParent().plan
        W.Refresh()
    end, function() return "Make this the active plan: the trees glow for it, and Follow takes its talents." end)
    h.use.label:SetText("Use")
    h.use:SetHeight(HEADER - 8)
    h.use:SetPoint("RIGHT", -4, 0)
    h.count = ns.Text(h, 11)
    h.count:SetTextColor(unpack(ns.colors.dim))
    h.name:SetPoint("RIGHT", h.count, "LEFT", -8, 0)
    local glow = h:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.05)
    h:SetScript("OnClick", function(self)
        local kept = Book().list[self.plan]
        if kept then kept.collapsed = not kept.collapsed or nil end
        W.Refresh()
    end)
    p.heads[i] = h
    return h
end

-- the checkpoints' table: its columns, from the right (the spec's icon,
-- the progress, the goal), the levels and the talent from the left
local SPEC, PROGRESS, GOAL, LVLS = 18, 58, 50, 44
local function Columns(f)
    f.at = ns.Text(f, 12)
    f.at:SetPoint("LEFT", 0, 0)
    f.at:SetWidth(LVLS)
    f.at:SetJustifyH("RIGHT")
    f.progress = ns.Text(f, 12)
    f.progress:SetPoint("RIGHT", -(4 + SPEC + 6), 0)
    f.progress:SetWidth(PROGRESS)
    f.progress:SetJustifyH("CENTER")
    f.goal = ns.Text(f, 12)
    f.goal:SetPoint("RIGHT", f.progress, "LEFT", 0, 0)
    f.goal:SetWidth(GOAL)
    f.goal:SetJustifyH("CENTER")
    f.name = ns.Text(f, 12)
    f.name:SetPoint("RIGHT", f.goal, "LEFT", -6, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
end

-- the table's head, under a plan's: what each column is
local function Labels(p, i)
    local f = CreateFrame("Frame", nil, p.list.child)
    f:SetHeight(LABELS)
    Columns(f)
    f.name:SetPoint("LEFT", LVLS + 8, 0)
    f.at:SetText("Lvls")
    f.name:SetText("Talent")
    f.goal:SetText("Goal")
    f.progress:SetText("Progress")
    f.spec = ns.Text(f, 11)
    f.spec:SetPoint("RIGHT", -2, 0)
    f.spec:SetText("Spec")
    for _, t in ipairs({ f.at, f.name, f.goal, f.progress, f.spec }) do
        t:SetFont(ns.font, 11, "")
        t:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
    end
    p.labels[i] = f
    return f
end

local function Row(p, i)
    local r = CreateFrame("Button", nil, p.list.child)
    r:SetHeight(LINE)
    r.mark = r:CreateTexture(nil, "BACKGROUND")
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    Columns(r)
    r.at:SetTextColor(unpack(ns.colors.dim))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(LINE - 4, LINE - 4)
    r.icon:SetPoint("LEFT", LVLS + 8, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.tick = r:CreateTexture(nil, "ARTWORK")
    r.tick:SetSize(14, 14)
    r.tick:SetPoint("CENTER", r.progress, "CENTER", 0, 0)
    r.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    r.spec = r:CreateTexture(nil, "ARTWORK")
    r.spec:SetSize(SPEC, SPEC)
    r.spec:SetPoint("RIGHT", -4, 0)
    r.spec:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    -- a checkpoint opens its talent's tree, the talent chosen
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

-- the walk's checkpoints: each run of one talent, its first and last
-- places and the rank it reaches
local function Checkpoints(kept)
    local out, counts = {}, {}
    for k, id in ipairs(kept) do
        counts[id] = (counts[id] or 0) + 1
        local last = out[#out]
        if last and last.id == id then
            last.to, last.rank = k, counts[id]
        else
            table.insert(out, { id = id, from = k, to = k, rank = counts[id] })
        end
    end
    return out
end

local function RefreshPlans(p)
    local config = Config()
    if not config then return end
    local m = Model(config)
    local b = Book()
    local icons = {}
    for _, g in ipairs(Groups()) do icons[g.groupID] = g.icon end
    local width = W.width - GUTTER
    local nh, nr, nl, y = 0, 0, 0, 0
    local summary
    for k, kept in ipairs(b.list) do
        local active = k == b.active
        local walk = Walk(m, kept.steps)
        local place = active and Next(m, walk.kept)
        local steps = Checkpoints(walk.kept)
        nh = nh + 1
        local h = p.heads[nh] or Head(p, nh)
        h.plan = k
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetWidth(width)
        h:Show()
        y = y + HEADER
        h.fold:SetRotation(kept.collapsed and math.pi / 2 or 0)
        h.name:SetText(kept.name)
        local c = active and GOLD or ns.colors.text
        h.name:SetTextColor(c[1], c[2], c[3])
        h.use:SetShown(not active)
        h.count:ClearAllPoints()
        if active then h.count:SetPoint("RIGHT", -10, 0) else h.count:SetPoint("RIGHT", h.use, "LEFT", -8, 0) end
        h.count:SetText(format("%s%d |4point:points;", active and "Active  ·  " or "", #walk.kept))
        if not kept.collapsed then
            nl = nl + 1
            local l = p.labels[nl] or Labels(p, nl)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", 0, -y)
            l:SetWidth(width)
            l:Show()
            y = y + LABELS
        end
        local learned = 0
        for _, step in ipairs(steps) do
            local t = m[step.id]
            local done = t.node.ranksPurchased >= step.rank
            if done then learned = learned + 1 end
            if not kept.collapsed then
                nr = nr + 1
                local r = p.rows[nr] or Row(p, nr)
                local ahead = place and place >= step.from and place <= step.to
                r.id, r.group, r.node, r.talent = step.id, t.group, t.node, Entry(config, t.node)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetWidth(width)
                r:Show()
                y = y + LINE
                r.at:SetText(step.from == step.to and tostring(step.from + 9)
                    or format("%d–%d", step.from + 9, step.to + 9))
                r.icon:SetTexture(r.talent.icon)
                r.icon:SetDesaturated(done)
                r.name:SetText(r.talent.name)
                local rc = ahead and GOLD or ns.colors.text
                r.name:SetTextColor(rc[1], rc[2], rc[3])
                -- the goal, the rank the checkpoint reaches; the progress,
                -- the ranks learned toward it, a tick once they are all
                r.goal:SetText(format("%d/%d", step.rank, t.node.maxRanks))
                r.progress:SetText(format("%d/%d", t.node.ranksPurchased, step.rank))
                r.progress:SetShown(not done)
                r.tick:SetShown(done)
                r.spec:SetTexture(icons[t.group])
                r:SetAlpha(done and 0.45 or 1)
                r.mark:SetShown(ahead and true or false)
            end
        end
        y = y + GAP
        if active then
            summary = { steps = #steps, place = place }
        end
    end
    for k = nh + 1, #p.heads do p.heads[k]:Hide() end
    for k = nr + 1, #p.rows do p.rows[k]:Hide() end
    for k = nl + 1, #p.labels do p.labels[k]:Hide() end
    p.list.child:SetSize(width, math.max(1, y))
    p.list.To(p.list.target)
    p.edit:SetShown(summary and true or false)
    p.remove:SetShown(summary and true or false)
    p.hint:SetText(#b.list == 0
        and "No plan yet: Create Plan, click talents, Checkpoint each, then Save plan."
        or not summary and "Press Use on a plan to make it the active one."
        or summary.place and format("Next: level %d. Click a checkpoint to open its talent.", summary.place + 9)
        or summary.steps > 0 and "Every talent in the plan is learned."
        or "The plan is empty.")
    Band(p)
end

-- the plans' page: no tab, Plans in the margin opens it. Over its list the
-- active plan's count; in its foot, as under a tree, Edit and Remove and a
-- hint
do
    local p = { key = "plans", tabless = true, order = TREES + 1, label = "Plans", frame = "TalentsFrame" }
    p.rows, p.heads, p.labels = {}, {}, {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    function p.Available() return C_Traits and C_SpecializationInfo and Groups()[1] ~= nil end
    function p.Build(body, foot, band)
        local top = CreateFrame("Frame", nil, foot)
        top:SetPoint("TOPLEFT", 0, -6)
        top:SetPoint("TOPRIGHT", 0, -6)
        top:SetHeight(STRIP)
        -- Create Plan draws one from nothing, in the plan's mode over a tree
        p.create = Button(top, 92, function()
            Begin()
            Back()
        end, function() return "Draw a plan from nothing: the order to learn talents in." end)
        p.create.label:SetText("Create Plan")
        p.create:SetHeight(STRIP - 2)
        p.create:SetPoint("LEFT", 4, 0)
        -- Edit draws the active plan again, in the plan's mode over a tree
        p.edit = Button(top, 52, function()
            local chosen = Chosen()
            if not chosen then return end
            Begin(chosen.steps, chosen.name)
            Back()
        end, function()
            return "Draw the active plan again, from its last checkpoint; Save plan keeps the changes."
        end)
        p.edit.label:SetText("Edit")
        p.edit:SetHeight(STRIP - 2)
        p.edit:SetPoint("LEFT", p.create, "RIGHT", 4, 0)
        -- Remove asks twice: the first press arms it, leaving disarms it
        p.remove = Button(top, 92, function(self)
            if not self.armed then
                self.armed = true
                self.label:SetText("Press again")
                return
            end
            local b = Book()
            if b.active then table.remove(b.list, b.active) end
            b.active = nil
            self.armed = nil
            self.label:SetText("Remove")
            W.Refresh()
        end, function() return "Remove the active plan." end)
        p.remove.label:SetText("Remove")
        p.remove:SetHeight(STRIP - 2)
        p.remove:SetPoint("LEFT", p.edit, "RIGHT", 4, 0)
        p.remove:HookScript("OnLeave", function(self)
            self.armed = nil
            self.label:SetText("Remove")
        end)
        local area = CreateFrame("Frame", nil, body)
        area:SetPoint("TOPLEFT", 0, -4)
        area:SetPoint("BOTTOMRIGHT")
        p.list = ns.window.Scroller(area, GUTTER)
        area:EnableMouseWheel(true)
        area:SetScript("OnMouseWheel", function(_, delta) p.list.To(p.list.target - delta * LINE * 3) end)
        p.hint = Hint(foot)
        -- as tall as a tree's foot, so the list keeps its place between them
        p.footHeight = FOOT
        for _, page in ipairs(W.pages) do
            if page.tree and page.footHeight then p.footHeight = page.footHeight end
        end
        Margin(p, band)
    end
    function p.Refresh() RefreshPlans(p) end
    W.Page(p)
    plansPage = p
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
    -- the window closed: a plan drawn and not saved is lost
    W.window:HookScript("OnHide", End)
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
