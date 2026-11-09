-- The spellbook: Medalluin's own (the shell is window/shell.lua), standing
-- on the right strip over the side panel's place, its margin beside the
-- backpack's medallion. Forever only: retail's spellbook is one of its
-- player-spells frame's pages, and keeps Blizzard's.
--
--   [General][spec][spec][spec][pet]                       [v] [x]
--   ---------------------------------------------------------------
--   [icon] Lightning Bolt          [icon] Earth Shock
--          Rank 4                         Rank 2
--   ...
--   ---------------------------------------------------------------
--   the chosen spell's name, rank and description
--   ---------------------------------------------------------------
--   [All ranks] [Trainer]                                (backpack)
--
-- A tab per skill line the book shows (General, then each specialisation),
-- the game's own icons, and Pet only while the pet has spells. A page holds
-- as many rows as the window's height gives it; the wheel turns the pages.
-- The margin holds All ranks (spellbookAllRanks) and, once a class trainer
-- has been visited (spells/trainers.lua), Trainer: a page without a tab,
-- of what is still to learn, now or at a later level, a section for each
-- skill line its spells belong to (Other for the rest); Trainer again goes
-- back.
--
-- A spell is listed once, at its highest rank learned, unless every rank
-- is asked for (spellbookAllRanks). One not on any action bar, nor in a
-- macro on one, wears a red edge (spellbookMissing). Asked to (its tick in
-- the details, or spellbookUpRankAll), a lower rank on a bar is swapped for
-- the highest as it is learned: out of combat, the cursor empty.
--
-- Casting is the client's: over each cell lies a secure button (type spell,
-- or flyout) in a layer parented to the strip, not the window, because a
-- frame that holds secure buttons cannot be shown or hidden in combat and
-- the window must open in combat. The layer follows the window out of
-- combat and a state driver hides it in combat: in combat the book reads,
-- pages and shows its tooltips, but casts and drags only out of it.
--
-- Blizzard's book is a tab of PlayerSpellsFrame, which the talents share:
-- this window shows while the frame is open on it (spells/frame.lua).
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local MISSING = { 0.85, 0.3, 0.2 }      -- the edge of a spell on no bar
local SLOTS = 180                       -- the action slots looked through
local LINES = 4                         -- the specialisations' and General's tabs
local ROW, ICON, GAP = 40, 34, 8        -- a cell, its icon, the gap between the columns
local GUTTER = 10                       -- the trainer's scroll bar, left of its list
local STEP = ROW * 1.5                  -- a turn of the wheel there
local BANK = Enum and Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
local TYPE = Enum and Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }

local W = ns.Window{
    name = "MedalluinSpellbook", side = 1, detailsKey = "spellbookDetails",
    closeTip = "Close the spellbook.",
    Close = function() HideUIPanel(PlayerSpellsFrame) end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.spellbook = W

local layer                             -- the secure buttons, on the strip
local open                              -- the window open on one of its pages
local SB = C_SpellBook

-- ------------------------------------------------------------- the items
-- The trainer's services still to learn, as items: no slot, nothing to cast.
-- A section for each skill line, in the book's order: the line a spell's
-- name is in (a rank learned, or one the book lists as to come), and Other
-- last. A section's heading takes a whole row (a filler after it, and
-- before it when the row is half full).
local function Trained()
    local lines, of = {}, {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        if line and not line.shouldHide then
            lines[l] = { name = line.name, icon = line.iconID, items = {} }
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
                if info and not of[info.name] then of[info.name] = l end
            end
        end
    end
    local other = { name = "Other", items = {} }
    for _, t in ipairs(ns.trainers.Class()) do
        local e = t.entry
        local section = lines[of[e.name]] or other
        table.insert(section.items, { trainer = e, now = t.now, info = { name = e.name, subName = e.rank or "",
            iconID = e.icon, actionID = e.name .. "|" .. (e.rank or "") } })
    end
    local out, order = {}, {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        if lines[l] then table.insert(order, lines[l]) end
    end
    table.insert(order, other)
    for _, section in ipairs(order) do
        if #section.items > 0 then
            if #out % 2 == 1 then table.insert(out, { filler = true }) end
            local now = 0
            for _, item in ipairs(section.items) do if item.now then now = now + 1 end end
            table.insert(out, { heading = section, now = now })
            table.insert(out, { filler = true })
            for _, item in ipairs(section.items) do table.insert(out, item) end
        end
    end
    return out
end

-- A page's items: { slot, bank, info } from its skill line, or the pet's,
-- or the trainer's. A spell's ranks are its highest learned (highest; its
-- lower ranks in lower), the others left out unless every rank is asked for.
local function Items(p)
    local out = {}
    if p.trainer then return Trained() end
    if p.pet then
        for slot = 1, SB.HasPetSpells() or 0 do
            local info = SB.GetSpellBookItemInfo(slot, BANK.Pet)
            if info then table.insert(out, { slot = slot, bank = BANK.Pet, info = info }) end
        end
        return out
    end
    local line = SB.GetSpellBookSkillLineInfo(p.line)
    if not line then return out end
    local all, ranks = {}, {}
    for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
        if info then
            local item = { slot = slot, bank = BANK.Player, info = info }
            table.insert(all, item)
            if info.itemType == TYPE.Spell then
                ranks[info.name] = ranks[info.name] or {}
                table.insert(ranks[info.name], item)
            end
        end
    end
    -- the book lists a spell's ranks low to high: the last is the highest
    for _, list in pairs(ranks) do
        local top = list[#list]
        top.highest, top.lower = true, {}
        for i = 1, #list - 1 do table.insert(top.lower, list[i]) end
    end
    if ns.db.spellbookAllRanks then return all end
    for _, item in ipairs(all) do
        local info = item.info
        -- a rank not learned yet of a spell you have, too, is left out
        local kept = info.itemType == TYPE.Spell and item.highest
            or info.itemType ~= TYPE.Spell and not (info.itemType == TYPE.FutureSpell and ranks[info.name])
        if kept then table.insert(out, item) end
    end
    return out
end

-- ------------------------------------------------------------ on the bars
-- The spells a macro on a bar casts, by ID.
local function Macros()
    local out = {}
    if not GetMacroSpell then return out end
    for slot = 1, SLOTS do
        local kind, id = GetActionInfo(slot)
        if kind == "macro" and id then
            local spell = GetMacroSpell(id)
            if spell then out[spell] = true end
        end
    end
    return out
end

local function OnBar(id, macros)
    if not id then return false end
    if macros[id] then return true end
    local slots = C_ActionBar and C_ActionBar.FindSpellActionButtons and C_ActionBar.FindSpellActionButtons(id)
    return slots ~= nil and #slots > 0
end

-- Whether an item is on no bar, and the lower rank that is if one is. Only
-- a highest rank asks, and only one cast: no passive, nothing of the pet's.
local function Missing(item, macros)
    local info = item.info
    if not (ns.db.spellbookMissing and item.highest and not info.isPassive and item.bank == BANK.Player) then
        return false
    end
    if OnBar(info.spellID or info.actionID, macros) then return false end
    for _, low in ipairs(item.lower or {}) do
        if OnBar(low.info.spellID or low.info.actionID, macros) then return true, low.info.subName end
    end
    return true
end

-- ------------------------------------------------------------- up-ranking
-- A lower rank on a bar becomes the highest learned, for the spells asked:
-- out of combat (else at its end), and with the cursor empty, since the
-- swap goes through it (a busy cursor waits for the next change).
local pending
local function Wanted(name)
    if ns.db.spellbookUpRankAll then return true end
    local t = MedalluinCharDB and MedalluinCharDB.upRank
    return type(t) == "table" and t[name] == true
end

local function UpRank()
    if not SB then return end
    if InCombatLockdown() then pending = true return end
    pending = nil
    if GetCursorInfo() then return end
    -- each lower rank's ID, to its spell's highest and its name
    local to = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        local ids = {}
        for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
            local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
            if info and info.itemType == TYPE.Spell and not info.isPassive and info.spellID then
                ids[info.name] = ids[info.name] or {}
                table.insert(ids[info.name], info.spellID)
            end
        end
        for name, list in pairs(ids) do
            for i = 1, #list - 1 do to[list[i]] = { top = list[#list], name = name } end
        end
    end
    for slot = 1, SLOTS do
        local kind, id = GetActionInfo(slot)
        local up = kind == "spell" and id and to[id]
        if up and Wanted(up.name) then
            C_Spell.PickupSpell(up.top)
            PlaceAction(slot)
            ClearCursor()
        end
    end
end
ns.spellbook.UpRank = UpRank

local Money = function(c) return ns.npc and ns.npc.Money(c) or tostring(c) end

local function Sub(item)
    local info = item.info
    if item.trainer then
        local e = item.trainer
        return (e.rank and e.rank .. " · " or "") .. (item.now and "Now" or format("Level %d", e.level))
            .. ((e.cost or 0) > 0 and " · " .. Money(e.cost) or "")
    end
    if info.itemType == TYPE.FutureSpell then
        local level = SB.GetSpellBookItemLevelLearned and SB.GetSpellBookItemLevelLearned(item.slot, item.bank)
        return level and level > 0 and format("Level %d", level) or "Not learned yet"
    end
    if info.isPassive then return "Passive" end
    return info.subName ~= "" and info.subName or nil
end

-- ----------------------------------------------------------------- cells
local function Tooltip(owner, item)
    if item.trainer then
        local e = item.trainer
        ns.Tip(owner, ns.window.Outside, { title = e.name, color = GOLD,
            e.rank and { "body", e.rank, ns.colors.dim } or false,
            { "body", item.now and "You can train it now." or format("Train it at level %d.", e.level) },
            (e.cost or 0) > 0 and { "body", "Costs " .. Money(e.cost) } or false })
        return
    end
    ns.window.Outside(owner)
    GameTooltip:SetSpellBookItem(item.slot, item.bank)
    if item.missing then
        GameTooltip:AddLine(item.lowerOn and format("%s is on your bars.", item.lowerOn) or "Not on your action bars.",
            MISSING[1], MISSING[2], MISSING[3])
    end
    GameTooltip:Show()
end

local function Choose(p, item)
    p.chosen = item and item.info.actionID
    W.Refresh()
end

-- A heading's icon, a square at a time along its row, the last cut short.
-- Textures, not one repeating: Forever's icons share sheets, and a repeat
-- runs on into the neighbours.
local CROP = 0.08
local function Tiles(c, icon, width)
    local n = icon and math.ceil(width / ROW) or 0
    for k = 1, math.max(n, #c.tiles) do
        local t = c.tiles[k]
        if k <= n then
            if not t then
                t = c:CreateTexture(nil, "BACKGROUND", nil, -2)
                t:SetDesaturated(true)
                t:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
                t:SetAlpha(0.5)
                c.tiles[k] = t
            end
            local w = math.min(ROW, width - (k - 1) * ROW)
            t:SetTexture(icon)
            t:SetTexCoord(CROP, CROP + (1 - 2 * CROP) * w / ROW, CROP, 1 - CROP)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", (k - 1) * ROW, 0)
            t:SetSize(w, ROW)
            t:Show()
        elseif t then
            t:Hide()
        end
    end
end

local function Cell(p, i)
    local c = CreateFrame("Button", nil, p.scroller and p.scroller.child or p.body)
    c:SetHeight(ROW)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("LEFT", 2, 0)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.edge = c:CreateTexture(nil, "BACKGROUND")
    c.edge:SetPoint("TOPLEFT", c.icon, -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    c.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.mark = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.mark:SetAllPoints()
    c.mark:SetColorTexture(0.541, 0.439, 0.204, 0.3)
    c.mark:Hide()
    -- a section's heading: a band across the row, the line's icon repeated
    -- along it in the theme's brown, and its name centred over them
    c.head = c:CreateTexture(nil, "BACKGROUND", nil, -3)
    c.head:SetAllPoints()
    c.head:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.18)
    c.head:Hide()
    c.tiles = {}
    c.title = ns.Text(c, 13)
    c.title:SetJustifyH("CENTER")
    c.title:SetTextColor(unpack(GOLD))
    c.count = ns.Text(c, 11)
    c.count:SetPoint("TOP", c.title, "BOTTOM", 0, -2)
    c.count:SetTextColor(unpack(ns.colors.dim))
    -- a spell on no bar: a wash under the cell (with the icon's red ring)
    c.miss = c:CreateTexture(nil, "BACKGROUND", nil, -2)
    c.miss:SetAllPoints()
    c.miss:SetColorTexture(MISSING[1], MISSING[2], MISSING[3], 0.12)
    c.miss:Hide()
    c.name = ns.Text(c, 12)
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 7, -3)
    c.name:SetPoint("RIGHT", -2, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.sub = ns.Text(c, 11)
    c.sub:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 7, 3)
    c.sub:SetTextColor(unpack(ns.colors.dim))
    local glow = c:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    -- in combat, with the secure layer away, the cell answers the mouse
    c:SetScript("OnClick", function(self) Choose(p, self.item) end)
    c:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.cells[i] = c
    return c
end

-- the cells' places: two columns, as many rows as the page's height holds
local function Rows(p)
    return math.max(1, math.floor((p.body:GetHeight() or 0) / ROW))
end

-- the cells' width across: the body's, less the trainer's scroll bar
local function Width(p) return p.scroller and W.width - GUTTER or W.width end

-- count: every item at once (the trainer's, which scroll), or a page's
-- worth of rows (the rest, which turn)
local function Place(p, count)
    local rows = count and math.max(1, math.ceil(count / 2)) or Rows(p)
    local width = (Width(p) - GAP) / 2
    if p.scroller then p.scroller.child:SetSize(Width(p), rows * ROW) end
    for i = 1, rows * 2 do
        local c = p.cells[i] or Cell(p, i)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", col * (width + GAP), -row * ROW)
        c:SetWidth(width)
    end
    return rows * 2
end

-- -------------------------------------------------------- the secure layer
-- One secure button per cell, over it: the cast is the client's.
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    -- cast on the release, whatever ActionButtonUseKeyDown says: a press
    -- held to drag the spell to a bar casts nothing
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.item and not InCombatLockdown() then
            SB.PickupSpellBookItem(self.item.slot, self.item.bank)
        end
    end)
    b:SetScript("PostClick", function(self) Choose(self.page, self.item) end)
    b:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    layer.buttons[i] = b
    return b
end

-- What a cell's button casts: a spell or a flyout, or nothing (a passive,
-- one not learned yet).
local function Arm(b, item)
    local info = item and item.info
    local kind, what
    if info and not info.isPassive then
        if info.itemType == TYPE.Spell or info.itemType == TYPE.PetAction then
            kind, what = "spell", info.spellID or info.actionID
        elseif info.itemType == TYPE.Flyout then
            kind, what = "flyout", info.actionID
        end
    end
    b:SetAttribute("type", kind)
    b:SetAttribute("spell", what)
end

-- Out of combat only: the buttons over the page's cells, armed; the rest
-- away. The layer is shown while the window is open (a driver hides it in
-- combat), and hidden when it closes.
local function Follow()
    if not layer or InCombatLockdown() then return end
    local p = W.Current()
    -- the trainer's cells cast nothing, and they scroll: no secure buttons,
    -- the cells answer the mouse themselves
    local cells = open and p and not p.scroller and p.cells or {}
    for i = 1, math.max(#cells, #layer.buttons) do
        local c = cells[i]
        if c and c:IsShown() and c.item then
            local b = Secure(i)
            b.item, b.page = c.item, p
            Arm(b, c.item)
            b:SetShown(W.Over(b, c))
        elseif layer.buttons[i] then
            local b = layer.buttons[i]
            b.item = nil
            Arm(b, nil)
            b:Hide()
        end
    end
    if open then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ------------------------------------------------------------------ pages
-- The trainer's details: the one chosen, or what training now comes to.
local function Summary(p, items, chosen)
    if chosen then
        local e = chosen.trainer
        p.details:Set({ title = e.name, sub = Sub(chosen),
            text = (chosen.now and "You can train it now" or format("You can train it at level %d", e.level))
                .. ", at your class trainer." })
        return
    end
    local n, cost, soonest = 0, 0, nil
    for _, item in ipairs(items) do
        if item.trainer then
            if item.now then n, cost = n + 1, cost + (item.trainer.cost or 0) end
            if not soonest or item.trainer.level < soonest then soonest = item.trainer.level end
        end
    end
    p.details.nothing:SetText(not soonest and "Nothing left to train."
        or n == 0 and "Nothing to train yet: the next at level " .. soonest .. "."
        or format("Train now: %d |4spell:spells;, %s in all.", n, Money(cost)))
    p.details:Set(nil)
end

local Band
local function Refresh(p)
    local items = Items(p)
    local per = Place(p, p.scroller and #items)
    local pages = math.max(1, math.ceil(#items / per))
    p.at = math.min(math.max(1, p.at or 1), pages)
    local first = (p.at - 1) * per
    local chosen
    local macros = Macros()
    for i, c in ipairs(p.cells) do
        local item = i <= per and items[first + i]
        if item and item.filler then item = nil end
        local heading = item and item.heading and true or false
        for _, r in ipairs({ c.head, c.title, c.count }) do r:SetShown(heading) end
        if not heading then Tiles(c, nil, 0) end
        for _, r in ipairs({ c.icon, c.edge, c.name, c.sub }) do r:SetShown(not heading) end
        -- a heading answers no click: it would only drop the spell chosen
        c:EnableMouse(not (item and item.heading))
        if item and item.heading then
            -- a trainer's section: the line's name centred on its icon,
            -- repeated a square at a time along the row
            local s = item.heading
            c.item = nil
            c:Show()
            c:SetWidth(Width(p))
            Tiles(c, s.icon or 136243, Width(p))
            c.title:SetText(s.name)
            c.count:SetText(item.now > 0 and format("%d to train now", item.now) or "")
            c.title:ClearAllPoints()
            c.title:SetPoint("CENTER", 0, item.now > 0 and 7 or 0)
            c.mark:Hide()
            c.miss:Hide()
            item = nil
        else
            c.item = item or nil
            c:SetShown(item and true or false)
        end
        if item then
            local info = item.info
            c.icon:SetTexture(info.iconID)
            local learned = info.itemType ~= TYPE.FutureSpell
            if item.trainer then learned = item.now end
            c.icon:SetDesaturated(not learned)
            c.icon:SetAlpha((learned and not info.isPassive) and 1 or 0.6)
            c.name:SetText(info.name)
            c.name:SetTextColor(unpack(learned and (info.isPassive and ns.colors.dim or GOLD) or ns.colors.dim))
            c.sub:SetText(Sub(item) or "")
            c.mark:SetShown(info.actionID == p.chosen)
            item.missing, item.lowerOn = Missing(item, macros)
            -- on no bar: a ring two pixels wide in red, and the wash
            local edge, ring = item.missing and MISSING or GOLD_D, item.missing and 2 or 1
            c.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
            c.edge:ClearAllPoints()
            c.edge:SetPoint("TOPLEFT", c.icon, -ring, ring)
            c.edge:SetPoint("BOTTOMRIGHT", c.icon, ring, -ring)
            c.miss:SetShown(item.missing and true or false)
        end
    end
    for _, item in ipairs(items) do
        if item.info and item.info.actionID == p.chosen then chosen = item end
    end
    p.pages = pages
    if p.scroller then p.scroller.To(p.scroller.target) end
    Band(p)
    if p.trainer then
        Summary(p, items, chosen)
    elseif chosen then
        local text = SB.GetSpellBookItemDescription and SB.GetSpellBookItemDescription(chosen.slot, chosen.bank)
        local sub = Sub(chosen) or ""
        -- the ranks left out, named
        if not ns.db.spellbookAllRanks and chosen.lower and #chosen.lower > 0 then
            local names = {}
            for _, low in ipairs(chosen.lower) do table.insert(names, low.info.subName) end
            sub = (sub ~= "" and sub .. "  ·  " or "") .. "Also " .. table.concat(names, ", ")
        end
        p.details:Set({ title = chosen.info.name, sub = sub, text = text or "" })
        -- its tick: a spell with ranks to rise through, kept on its highest
        local tick = p.details.ticks[1]
        if tick then
            local ranked = chosen.highest and not chosen.info.isPassive and chosen.lower and #chosen.lower > 0
            tick:SetShown(ranked and true or false)
            tick:Set(ns.db.spellbookUpRankAll or Wanted(chosen.info.name), not ns.db.spellbookUpRankAll)
        end
    else
        p.details:Set(nil)
    end
    Follow()
end

-- Refresh keeps the page in range, as it must when the window grows
local function Turn(p, by)
    p.at = (p.at or 1) + by
    Refresh(p)
end

-- The margin, edge to edge (ns.window.Segments): All ranks (a toggle),
-- and Trainer once a class trainer has been read, which opens its page
-- and, from it, goes back.
local trainerPage, back
local function Controls(p, band)
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = {
        { key = "all", label = "All ranks", click = function()
            if p.trainer then return end            -- it means nothing there
            ns.SetOption("spellbookAllRanks", not ns.db.spellbookAllRanks)
        end, tip = function()
            if p.trainer then return "Every rank the trainer teaches is listed here." end
            return ns.db.spellbookAllRanks and "List each spell once, at its highest rank."
                or "List every rank of each spell."
        end },
        { key = "trainer", label = "Trainer", click = function()
            if W.Current() == trainerPage then
                -- the page it came from, or the first with a tab
                local to = back and back.available and back
                for _, page in ipairs(W.pages) do
                    if not to and page.available and not page.tabless then to = page end
                end
                if to then W.Select(to) end
            else
                back = W.Current()
                W.Select(trainerPage)
            end
        end, tip = function()
            return W.Current() == trainerPage and "Back to your spells."
                or "What your class trainer has still to teach you."
        end },
    } })
    row:SetPoint("TOPLEFT")
    row:SetPoint("TOPRIGHT")
    p.margin = row
    p.allRanks, p.trainerButton = row.byKey.all, row.byKey.trainer
end

-- the margin's state: All ranks marked while on, and off on the trainer's
-- page, where it means nothing; Trainer once read, marked while its page
-- shows (All ranks takes the row until then)
function Band(p)
    if not p.margin then return end
    p.margin:Set("all", { selected = not p.trainer and ns.db.spellbookAllRanks, enabled = not p.trainer })
    p.margin:Set("trainer", { selected = p.trainer, shown = ns.trainers.Visited() })
end

local function Page(spec)
    local p = spec
    p.cells = {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_ICON", "PLAYER_LEVEL_UP",
        "UNIT_PET", "PET_BAR_UPDATE", "ACTIONBAR_SLOT_CHANGED", "PLAYER_MONEY" }
    function p.Build(body, foot, band)
        -- a spell with ranks: kept on its highest on your bars, or not
        local ticks = not (p.pet or p.trainer) and { { label = "Keep on its highest rank",
            tip = "A lower rank of it on your action bars is swapped for the highest as you learn it.",
            click = function(on)
                local chosen
                for _, item in ipairs(Items(p)) do
                    if item.info and item.info.actionID == p.chosen then chosen = item end
                end
                if not chosen then return end
                MedalluinCharDB = MedalluinCharDB or {}
                MedalluinCharDB.upRank = type(MedalluinCharDB.upRank) == "table" and MedalluinCharDB.upRank or {}
                MedalluinCharDB.upRank[chosen.info.name] = on or nil
                if on then UpRank() end
                Refresh(p)
            end } } or nil
        p.details = ns.character.Details(foot, ticks, p.trainer and "" or "Choose a spell to read it.", 4)
        p.footHeight = p.details.height
        Controls(p, band)
        body:EnableMouseWheel(true)
        if p.trainer then
            p.scroller = ns.window.Scroller(body, GUTTER)
            body:SetScript("OnMouseWheel", function(_, delta) p.scroller.To(p.scroller.target - delta * STEP) end)
        else
            body:SetScript("OnMouseWheel", function(_, delta) Turn(p, delta > 0 and -1 or 1) end)
        end
    end
    function p.Refresh() Refresh(p) end
    function p.Showing(on)
        if on then open = true elseif W.Current() == p then open = false end
        Follow()
    end
    W.Page(p)
end

-- General and each specialisation, by the book's own skill lines
for i = 1, LINES do
    local p = { key = "line" .. i, line = i, order = i, label = "", frame = "SpellBookFrame" }
    function p.Available()
        local line = SB and SB.GetSpellBookSkillLineInfo(i)
        if not line or line.shouldHide then return false end
        p.label, p.icon = line.name, line.iconID
        return true
    end
    Page(p)
end
-- the pet's, while it has spells
do
    local p = { key = "pet", pet = true, order = LINES + 1, label = "Pet", frame = "SpellBookFrame" }
    function p.Available()
        if not (SB and SB.HasPetSpells and SB.HasPetSpells()) then return false end
        p.icon = GetPetIcon and GetPetIcon() or 132599
        return true
    end
    Page(p)
end

-- what the class trainers have still to teach, once one has been visited
do
    local p = { key = "trainer", trainer = true, tabless = true, order = LINES + 2, label = "Trainer",
        frame = "SpellBookFrame", icon = 136243 }
    function p.Available() return ns.trainers.Visited() end
    Page(p)
    trainerPage = p
end

function W.Refresh()
    local p = W.Current()
    if p and W.window:IsShown() then Refresh(p) end
end

local function Start()
    -- Forever's micro menu has a spellbook button of its own; retail's has
    -- one player-spells button for its combined frame
    if not ns.db.spellbook or not SpellbookMicroButton or not SB or not SB.GetSpellBookSkillLineInfo then return end
    W.Build()
    layer = W.Layer("MedalluinSpellbookCasts")
    W.layer = layer
    for _, p in ipairs(W.pages) do
        if p.available then W.Select(p); break end
    end
    -- the skill lines and the pet come and go
    for _, e in ipairs({ "SPELLS_CHANGED", "UNIT_PET", "PET_BAR_UPDATE" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("PLAYER_REGEN_ENABLED", function()
        Follow()
        if pending then UpRank() end
    end)
    -- a rank learned rises on the bars; a trainer read brings its button
    for _, e in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do ns.On(e, UpRank) end
    ns.OnSetting("spellbookUpRankAll", function(on) if on then UpRank() end end)
    for _, key in ipairs({ "spellbookAllRanks", "spellbookMissing", "spellbookUpRankAll" }) do
        ns.OnSetting(key, function() W.Refresh() end)
    end
    for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
        ns.On(e, function()
            W.Retab()
            W.Refresh()
        end)
    end
    ns.PlayerSpellsTab("SpellBook", W)
end

ns.On("PLAYER_LOGIN", Start)
