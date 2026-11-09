-- The spellbook: Medalluin's own (the shell is window/shell.lua), standing
-- on the right strip over the side panel's place, its margin beside the
-- backpack's medallion. Forever only: retail's spellbook is one of its
-- player-spells frame's pages, and keeps Blizzard's.
--
--   [Spellbook][Macros]                                          [x]
--   ---------------------------------------------------------------
--   +-------------------------------------------------------------+
--   | General                                                   5 |
--   |   [icon] Attack                                     Instant |
--   +-------------------------------------------------------------+
--   | Restoration                                 Healer  ·  6  + |
--   |   [ic]]] Healing Wave                                 3 sec |
--   |          Rank 5 · Shift+Middle                     200 Mana |
--   |      |   Rank 5                       3 sec        200 Mana |
--   |      |   Rank 4                       3 sec        155 Mana |
--   ...
--   ---------------------------------------------------------------
--   [Trainer]                                            (backpack)
--
-- One list, scrolled: a card for each skill line the book shows (General,
-- then each specialisation) and Pet last while the pet has spells. A
-- card's strip wears its specialisation's role (damage red, healer green,
-- tank blue; General and the pet the theme's brown), its icon faint behind
-- its rows; a left click on the strip collapses the card
-- (MedalluinCharDB.bookShut). A spell is a row the window's width, at its
-- highest rank learned, with its cast time over its cost at the right.
-- One with ranks has its icon stacked; a left click on it lists each rank
-- under it (MedalluinCharDB.bookOpen, by name), highest first, each a row
-- that casts that rank. The right button casts; the left only drags (and
-- shows ranks). Macros is a page still to come. The margin
-- holds, once a class trainer has been visited (spells/trainers.lua),
-- Trainer: a page without a tab, in the same cards, of what is still to
-- learn, now or at a later level, a card for each skill line its spells
-- belong to (Other for the rest); Trainer again goes back.
--
-- A spell on no action bar, nor in a macro on one, wears a red edge
-- (spellbookMissing). Asked to (spellbookUpRankAll, or a spell's own
-- MedalluinCharDB.upRank), a lower rank on a bar is swapped for the highest as
-- it is learned: out of combat, the cursor empty.
--
-- Casting is the client's: over each row wholly in view lies a secure
-- button (type2 spell, or flyout: the right button) in a layer parented to the strip, not the window, because a
-- frame that holds secure buttons cannot be shown or hidden in combat and
-- the window must open in combat. The layer follows the window out of
-- combat and a state driver hides it in combat: in combat the book reads,
-- scrolls and shows its tooltips, but casts and drags only out of it.
--
-- Blizzard's book is a tab of PlayerSpellsFrame, which the talents share:
-- this window shows while the frame is open on it (spells/frame.lua).
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local MISSING = { 0.85, 0.3, 0.2 }      -- the edge of a spell on no bar
local BLUE = { 0.43, 0.63, 0.92 }       -- a cost
local SLOTS = 180                       -- the action slots looked through
local HEAD, SPELL, RANK = 28, 36, 24    -- a section's strip, a spell's row, a rank's
local SPACE, PAD = 10, 4                -- between the cards; under a card's last row
local ICON, SMALL, INDENT = 30, 26, 20  -- a spell's icon, one with ranks (stacked), the icon's left
local RIGHT = 80                        -- the cast time and cost's column
local EDGE = 12                         -- the cast time and cost, in from the card's edge
local PALE = { 1, 0.94, 0.8 }           -- a strip's title
-- a section's colour, by its specialisation's role (General, the pet's
-- and the trainer's Other: the theme's brown)
local ROLE = { TANK = { 0.35, 0.55, 0.9 }, HEALER = { 0.35, 0.78, 0.45 }, DAMAGER = { 0.84, 0.35, 0.29 } }
local ROLE_WORD = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
local ROLE_GLYPH = { TANK = "role-tank", HEALER = "role-healer", DAMAGER = "role-damage" }
local GUTTER = 10                       -- the scroll bar, left of the list
local STEP = SPELL * 1.5                -- a turn of the wheel
local BANK = Enum and Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
local TYPE = Enum and Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }

local W = ns.Window{
    name = "MedalluinSpellbook", side = 1,
    closeTip = "Close the spellbook.",
    Close = function() HideUIPanel(PlayerSpellsFrame) end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.spellbook = W

local layer                             -- the secure buttons, on the strip
local open                              -- the window open on one of its pages
local SB = C_SpellBook

-- ------------------------------------------------------------- the items
-- The list, as entries to draw top to bottom: a heading for each section,
-- its spells (each at its highest rank learned), and under a spell
-- unfolded its ranks, highest first. The book's sections are its skill
-- lines (General, then each specialisation) and the pet's last; the
-- trainer's are the skill lines a spell's name is in, Other last.
local function Open(name)
    local t = MedalluinCharDB and MedalluinCharDB.bookOpen
    return type(t) == "table" and t[name] == true
end

local function Fold(name)
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.bookOpen = type(MedalluinCharDB.bookOpen) == "table" and MedalluinCharDB.bookOpen or {}
    MedalluinCharDB.bookOpen[name] = not Open(name) or nil
end

-- A section collapsed to its heading (MedalluinCharDB.bookShut, by its
-- name; the trainer's apart from the book's)
local function Shut(key)
    local t = MedalluinCharDB and MedalluinCharDB.bookShut
    return type(t) == "table" and t[key] == true
end

local function Collapse(key)
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.bookShut = type(MedalluinCharDB.bookShut) == "table" and MedalluinCharDB.bookShut or {}
    MedalluinCharDB.bookShut[key] = not Shut(key) or nil
end

-- A skill line's role: the game's, by its specialisation, where it has
-- one; else by the tree's (English) name, damage for the rest. General
-- (the first line) has none.
local ROLE_BY_NAME = { Restoration = "HEALER", Holy = "HEALER", Discipline = "HEALER", Protection = "TANK",
    ["Feral Combat"] = "TANK" }
local function Role(line, l)
    if l == 1 or not line then return nil end
    if line.specID and GetSpecializationRoleByID then
        local ok, r = pcall(GetSpecializationRoleByID, line.specID)
        if ok and ROLE[r] then return r end
    end
    return ROLE_BY_NAME[line.name] or "DAMAGER"
end

-- a rank row: the rank's own slot (it casts that rank), under its spell
local function Rank(src, top)
    return { rank = true, of = top, slot = src.slot, bank = src.bank, info = src.info,
        key = "r" .. tostring(src.info.actionID) }
end

local function Section(out, name, list, now, trainer, role, icon)
    if #list == 0 then return end
    local key = (trainer and "trainer:" or "") .. name
    local shut = Shut(key)
    table.insert(out, { heading = name, shut = key, closed = shut, count = #list, now = now, role = role,
        icon = icon })
    if shut then return end
    for _, item in ipairs(list) do
        item.key = item.key or tostring(item.info.actionID)
        table.insert(out, item)
        if item.lower and #item.lower > 0 and Open(item.info.name) then
            table.insert(out, Rank(item, item))
            for i = #item.lower, 1, -1 do table.insert(out, Rank(item.lower[i], item)) end
        end
    end
end

-- The trainer's services still to learn: no slot, nothing to cast.
local function Trained()
    local lines, of = {}, {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        if line and not line.shouldHide then
            lines[l] = { name = line.name, items = {}, role = Role(line, l), icon = line.iconID }
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
    local out = {}
    local order = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        if lines[l] then table.insert(order, lines[l]) end
    end
    table.insert(order, other)
    for _, section in ipairs(order) do
        local now = 0
        for _, item in ipairs(section.items) do if item.now then now = now + 1 end end
        Section(out, section.name, section.items, now, true, section.role, section.icon)
    end
    return out
end

-- A skill line's spells: { slot, bank, info }, each at its highest rank
-- learned (highest; its lower ranks in lower). A rank not learned yet of a
-- spell you have is left out.
local function Line(line)
    local all, ranks, out = {}, {}, {}
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
    for _, item in ipairs(all) do
        local info = item.info
        local kept = info.itemType == TYPE.Spell and item.highest
            or info.itemType ~= TYPE.Spell and not (info.itemType == TYPE.FutureSpell and ranks[info.name])
        if kept then table.insert(out, item) end
    end
    return out
end

local function Items(p)
    if p.trainer then return Trained() end
    local out = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        if line and not line.shouldHide then
            Section(out, line.name, Line(line), nil, false, Role(line, l), line.iconID)
        end
    end
    local pet = {}
    for slot = 1, SB.HasPetSpells and SB.HasPetSpells() or 0 do
        local info = SB.GetSpellBookItemInfo(slot, BANK.Pet)
        if info then table.insert(pet, { slot = slot, bank = BANK.Pet, info = info }) end
    end
    Section(out, "Pet", pet, nil, false, nil, GetPetIcon and GetPetIcon() or nil)
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

-- ---------------------------------------------------------- click casting
-- Its bindings (spells/clickcast.lua): a bound spell's click after its rank
-- and a mouse on its icon's corner. A binding set on a lower rank marks the
-- rank shown; a pet's, only the pet's spells.
local GOLD_HEX = "|cfff0d488"

local function Clicks(item, bound)
    local info = item.info
    if not bound or item.trainer or not info then return nil end
    local ids, names = bound[1], bound[2]
    local pet = item.bank == BANK.Pet
    local out, seen = {}, {}
    local function Take(list)
        for _, b in ipairs(list or {}) do
            if b.pet == pet and not seen[b.text] then
                seen[b.text] = true
                table.insert(out, b.text)
            end
        end
    end
    Take(ids[info.actionID])
    if info.spellID then Take(ids[info.spellID]) end
    for _, low in ipairs(item.lower or {}) do Take(ids[low.info.spellID or low.info.actionID]) end
    if info.itemType == TYPE.Spell or info.itemType == TYPE.PetAction then Take(names[info.name]) end
    return #out > 0 and table.concat(out, ", ") or nil
end

-- The game's bind mode (Click Casting open): a click on a spell it can bind
-- fills its waiting slot, as the game's own book does, and casts nothing.
local function Binding()
    return ns.db.spellbookClickCast and ns.clickcast ~= nil and ns.clickcast.Binding()
end

local function Bindable(item)
    local info = item and item.info
    if not info or item.trainer or info.itemType == TYPE.FutureSpell or info.isPassive or not info.actionID then
        return false
    end
    local can = C_ClickBindings and C_ClickBindings.CanSpellBeClickBound
    if not can then return false end
    local ok, yes = pcall(can, info.actionID)
    return ok and yes and true or false
end

-- A spell bound already (any of its ranks): into the binder to change its
-- click. Else a new binding: the game's slot added if there is none (its own
-- Add binding), then filled, which loads it into the binder.
local function Bind(item)
    local f = _G.ClickBindingFrame
    local cc = ns.clickcast
    if not (f and f.AddNewAction and Bindable(item)) then return end
    local info = item.info
    local ids = { [info.actionID] = true }
    if info.spellID then ids[info.spellID] = true end
    for _, low in ipairs(item.lower or {}) do ids[low.info.spellID or low.info.actionID or 0] = true end
    local had = cc and cc.Find and cc.Find(ids, info.name)
    if had then
        cc.Load(had)
        return
    end
    if f.HasNewSlot and not f:HasNewSlot() then
        local add = f.AddBindingButton
        local click = type(add) == "table" and add.GetScript and add:GetScript("OnClick")
        if click then click(add, "LeftButton") end
        if not f:HasNewSlot() then return end
    end
    local T = Enum and Enum.ClickBindingType or { Spell = 1, PetAction = 4 }
    f:AddNewAction(item.bank == BANK.Pet and T.PetAction or T.Spell, info.actionID)
end

local Refresh                           -- below: a page drawn again

-- ------------------------------------------------------------------ rows
-- What a row's right side says: a spell's cast time over its cost, or the
-- trainer's level over its price. Nothing for a passive, a flyout, or one
-- not learned yet; a field the game will not tell is left blank.
local function Word(s) return (tostring(s or ""):lower():gsub("^%l", string.upper)) end

local function Costs(item)
    if item.trainer then
        local e = item.trainer
        return item.now and "Now" or format("Level %d", e.level or 0), (e.cost or 0) > 0 and Money(e.cost) or nil
    end
    local info = item.info
    if info.isPassive or (info.itemType ~= TYPE.Spell and info.itemType ~= TYPE.PetAction) then return nil, nil end
    local id = info.spellID or info.actionID
    if type(id) ~= "number" or not C_Spell then return nil, nil end
    local cast, cost
    if C_Spell.GetSpellInfo then
        local ok, s = pcall(C_Spell.GetSpellInfo, id)
        local ms = ok and type(s) == "table" and s.castTime
        if type(ms) == "number" then cast = ms <= 0 and "Instant" or format("%g sec", ms / 1000) end
    end
    if C_Spell.GetSpellPowerCost then
        local ok, list = pcall(C_Spell.GetSpellPowerCost, id)
        for _, c in ipairs(ok and type(list) == "table" and list or {}) do
            local word = Word(c.name and (_G[c.name] or c.name) or "")
            if (c.cost or 0) > 0 then
                cost = format("%d %s", c.cost, word)
                break
            elseif (c.costPercent or 0) > 0 then
                cost = format("%d%% of base %s", c.costPercent, word:lower())
                break
            end
        end
    end
    return cast, cost
end

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
    if Binding() and not Bindable(item) then
        GameTooltip:AddLine(_G.CLICK_BINDING_NOT_AVAILABLE or "Click casting cannot bind this.",
            MISSING[1], MISSING[2], MISSING[3])
    elseif Binding() then
        GameTooltip:AddLine(item.clicks and format("Bound to %s: click to change it.", item.clicks)
            or "Click to bind it.", GOLD[1], GOLD[2], GOLD[3])
    elseif item.clicks then
        GameTooltip:AddLine("Click casting: " .. item.clicks, GOLD[1], GOLD[2], GOLD[3])
    end
    if not Binding() and not item.rank and item.lower and #item.lower > 0 then
        local dim = ns.colors.dim
        GameTooltip:AddLine(Open(item.info.name) and "Left-click to hide its ranks." or "Left-click to show its ranks.",
            dim[1], dim[2], dim[3])
    end
    if item.missing then
        GameTooltip:AddLine(item.lowerOn and format("%s is on your bars.", item.lowerOn) or "Not on your action bars.",
            MISSING[1], MISSING[2], MISSING[3])
    end
    GameTooltip:Show()
end

-- A spell with ranks to show (a rank's own row has none)
local function Ranked(item)
    return item and not item.rank and not item.trainer and item.lower ~= nil and #item.lower > 0
end

-- A click on a spell or a rank: Click Casting open, either button binds
-- it; else the left shows or hides a spell's ranks (and does nothing on
-- the rest). The right casts: the secure button's, the client's.
local function Press(p, item, button)
    if Binding() then
        Bind(item)
    elseif button == "LeftButton" and Ranked(item) then
        Fold(item.info.name)
        Refresh(p)
    end
end

-- A section's card, pooled, under its rows: a dark box with a brown edge,
-- its specialisation's icon faint at its top right under the strip.
local function Card(p, n)
    local k = CreateFrame("Frame", nil, p.scroller.child)
    k:SetFrameLevel(p.scroller.child:GetFrameLevel() + 1)
    local ink = ns.colors.ink
    k.fill = k:CreateTexture(nil, "BACKGROUND", nil, -8)
    k.fill:SetAllPoints()
    k.fill:SetColorTexture(ink[1], ink[2], ink[3], 0.9)
    k.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = k:CreateTexture(nil, "BORDER")
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        k.edges[i] = t
    end
    p.cards[n] = k
    return k
end

-- a card from its strip's top to bottom; the icon square, as big as the
-- rows under the strip leave room for (none on a card that is only strip)
local function Finish(k, width, bottom)
    local h = bottom - k.y
    k:ClearAllPoints()
    k:SetPoint("TOPLEFT", 0, -k.y)
    k:SetSize(width, h)
    k:Show()
end

-- A row, pooled: one frame for each kind, its parts shown for the kind.
--   strip   Restoration                              Healer · 6 (+)
--   spell   [icon] Lightning Bolt                    2.5 sec
--                  Rank 4                            100 Mana
--   ranked  [ic]]] Healing Wave                      3 sec      (a stack)
--                  Rank 5 · 5 ranks                  200 Mana
--   rank       |   Rank 4                  3 sec     155 Mana
local function Row(p, i)
    local c = CreateFrame("Button", nil, p.scroller.child)
    -- over the cards
    c:SetFrameLevel(p.scroller.child:GetFrameLevel() + 3)
    -- a section's strip: its role's colour fading right, a line of it
    -- under, the title, and its role and count at the right
    c.band = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.band:SetPoint("TOPLEFT", 1, -1)
    c.band:SetPoint("BOTTOMRIGHT", -1, 1)
    c.line = c:CreateTexture(nil, "ARTWORK")
    c.line:SetHeight(1)
    c.line:SetPoint("BOTTOMLEFT", 1, 0)
    c.line:SetPoint("BOTTOMRIGHT", -1, 0)
    c.title = ns.Text(c, 14)
    c.title:SetPoint("LEFT", 12, 0)
    c.title:SetTextColor(unpack(PALE))
    c.role = c:CreateTexture(nil, "ARTWORK")
    c.role:SetSize(12, 12)
    c.role:SetPoint("RIGHT", -10, 0)
    c.role:SetVertexColor(PALE[1], PALE[2], PALE[3])
    c.count = ns.Text(c, 11)
    c.count:SetJustifyH("RIGHT")
    c.count:SetTextColor(PALE[1] * 0.92, PALE[2] * 0.92, PALE[3] * 0.92)
    -- a spell: its icon (stacked when it has ranks to show), its words
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.edge = c:CreateTexture(nil, "BACKGROUND", nil, 5)
    c.edge:SetPoint("TOPLEFT", c.icon, -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    -- the stack: a frame or two peeking out behind the icon, up and right
    c.stack = {}
    for k = 1, 2 do
        local rim = c:CreateTexture(nil, "BACKGROUND", nil, 4 - 2 * k)
        rim:SetPoint("TOPLEFT", c.icon, 3 * k - 1, 3 * k + 1)
        rim:SetPoint("BOTTOMRIGHT", c.icon, 3 * k + 1, 3 * k - 1)
        local fill = c:CreateTexture(nil, "BACKGROUND", nil, 5 - 2 * k)
        fill:SetPoint("TOPLEFT", rim, 1, -1)
        fill:SetPoint("BOTTOMRIGHT", rim, -1, 1)
        fill:SetColorTexture(0.12, 0.1, 0.08, 1)
        c.stack[k] = { rim = rim, fill = fill }
    end
    -- a spell on no bar: a wash under the row (with the icon's red ring)
    c.miss = c:CreateTexture(nil, "BACKGROUND", nil, -2)
    c.miss:SetPoint("TOPLEFT", 1, 0)
    c.miss:SetPoint("BOTTOMRIGHT", -1, 0)
    c.miss:SetColorTexture(MISSING[1], MISSING[2], MISSING[3], 0.12)
    c.miss:Hide()
    -- a click-cast binding: a small mouse in a gold ring on the icon's corner
    c.badge = CreateFrame("Frame", nil, c)
    c.badge:SetSize(20, 20)
    c.badge:SetPoint("CENTER", c.icon, "BOTTOMRIGHT", -3, 3)
    local ring = c.badge:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetAllPoints()
    ring:SetTexture(ns.media .. "strips\\round")
    ring:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local disc = c.badge:CreateTexture(nil, "ARTWORK", nil, 2)
    disc:SetPoint("TOPLEFT", 1, -1)
    disc:SetPoint("BOTTOMRIGHT", -1, 1)
    disc:SetTexture(ns.media .. "strips\\round")
    disc:SetVertexColor(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    c.badge.glyph = c.badge:CreateTexture(nil, "ARTWORK", nil, 3)
    c.badge.glyph:SetSize(15, 15)
    c.badge.glyph:SetPoint("CENTER")
    c.badge.glyph:SetTexture(ns.media .. "strips\\mouse")
    c.badge.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    c.badge:Hide()
    -- while Click Casting is open, round a spell it can bind: a gold halo
    c.halo = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.halo:SetPoint("TOPLEFT", c.icon, -4, 4)
    c.halo:SetPoint("BOTTOMRIGHT", c.icon, 4, -4)
    c.halo:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    c.halo:Hide()
    c.name = ns.Text(c, 12)
    c.name:SetPoint("TOPLEFT", INDENT + ICON + 8, -5)
    c.name:SetPoint("RIGHT", -RIGHT, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.sub = ns.Text(c, 10)
    c.sub:SetPoint("BOTTOMLEFT", INDENT + ICON + 8, 5)
    c.sub:SetPoint("RIGHT", -RIGHT, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.sub:SetTextColor(unpack(ns.colors.dim))
    c.cast = ns.Text(c, 11)
    c.cast:SetPoint("TOPRIGHT", -EDGE, -5)
    c.cast:SetJustifyH("RIGHT")
    c.cost = ns.Text(c, 10)
    c.cost:SetPoint("BOTTOMRIGHT", -EDGE, 5)
    c.cost:SetJustifyH("RIGHT")
    c.cost:SetTextColor(unpack(BLUE))
    -- a rank: a gold line down from its spell's (stacked) icon, its rank,
    -- its numbers, on a faint band
    c.rband = c:CreateTexture(nil, "BACKGROUND", nil, -3)
    c.rband:SetPoint("TOPLEFT", 1, 0)
    c.rband:SetPoint("BOTTOMRIGHT", -1, 0)
    c.rband:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.1)
    c.stem = c:CreateTexture(nil, "ARTWORK")
    c.stem:SetWidth(1)
    c.stem:SetPoint("TOPLEFT", INDENT + SMALL / 2, 0)
    c.stem:SetPoint("BOTTOMLEFT", INDENT + SMALL / 2, 0)
    c.stem:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.rank = ns.Text(c, 11)
    c.rank:SetPoint("LEFT", INDENT + ICON + 8, 0)
    c.rcast = ns.Text(c, 10)
    c.rcast:SetPoint("RIGHT", -(EDGE + 96), 0)
    c.rcast:SetJustifyH("RIGHT")
    c.rcast:SetTextColor(unpack(ns.colors.dim))
    c.rcost = ns.Text(c, 10)
    c.rcost:SetPoint("RIGHT", -EDGE, 0)
    c.rcost:SetJustifyH("RIGHT")
    c.rcost:SetTextColor(unpack(BLUE))
    -- what the secure button covers: the row within the card's edges
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetPoint("TOPLEFT", 1, 0)
    c.hit:SetPoint("BOTTOMRIGHT", -1, 0)
    c.glow = c:CreateTexture(nil, "HIGHLIGHT")
    c.glow:SetAllPoints(c.hit)
    c.glow:SetColorTexture(1, 1, 1, 0.08)
    -- A strip: a left click collapses its section, or opens it again. A
    -- spell, in combat (the secure layer away) or cut by the scroll's
    -- edge: the left button shows or hides its ranks, the right casts
    -- nothing; Click Casting open, either binds
    c:SetScript("OnClick", function(self, button)
        if self.shut then
            Collapse(self.shut)
            Refresh(p)
        elseif self.item then
            Press(p, self.item, button)
        end
    end)
    c:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = c
    return c
end

local PARTS = {
    heading = { "band", "line", "title", "role", "count" },
    spell = { "icon", "edge", "name", "sub", "cast", "cost" },
    rank = { "rband", "stem", "rank", "rcast", "rcost" },
}
local function Kind(c, kind)
    for k, list in pairs(PARTS) do
        for _, part in ipairs(list) do c[part]:SetShown(k == kind) end
    end
    for _, part in ipairs({ "miss", "badge", "halo" }) do c[part]:Hide() end
    for _, s in ipairs(c.stack) do
        s.rim:Hide()
        s.fill:Hide()
    end
    c.shut = nil
    if kind == "heading" then
        c:RegisterForClicks("LeftButtonUp")
    else
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    c.kind = kind
end

-- The entries laid out top to bottom in the scroll's child, a card under
-- each section (its strip and rows, a little room under the last), a gap
-- between the cards; the rows and cards left over hidden.
local function Place(p, items)
    local width = W.width - GUTTER
    local y, n, card = 0, 0, nil
    local function Close()
        if not card then return end
        if not card.shut then y = y + PAD end
        Finish(card, width, y)
    end
    for i, item in ipairs(items) do
        local c = p.rows[i] or Row(p, i)
        if item.heading then
            Close()
            if card then y = y + SPACE end
            n = n + 1
            card = p.cards[n] or Card(p, n)
            card.y, card.shut, card.icon = y, item.closed, item.icon
        end
        local h = item.heading and HEAD or item.rank and RANK or SPELL
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetSize(width, h)
        c.y, c.h = y, h
        c:Show()
        y = y + h
    end
    Close()
    for i = #items + 1, #p.rows do
        p.rows[i].item = nil
        p.rows[i]:Hide()
    end
    for i = n + 1, #p.cards do p.cards[i]:Hide() end
    p.scroller.child:SetSize(width, math.max(1, y))
end

-- -------------------------------------------------------- the secure layer
-- One secure button per row in view, over it: the cast is the client's.
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    -- the right button casts; the left shows a spell's ranks, and drags
    -- (Follow: in bind mode either binds)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
    -- cast on the release, whatever ActionButtonUseKeyDown says: a press
    -- held to drag the spell to a bar casts nothing
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.item and not InCombatLockdown() then
            SB.PickupSpellBookItem(self.item.slot, self.item.bank)
        end
    end)
    b:SetScript("PostClick", function(self, button, down)
        -- binding: once a click, on its release (the press comes here too)
        if down and Binding() then return end
        if self.item then Press(self.page, self.item, button) end
    end)
    b:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    layer.buttons[i] = b
    return b
end

-- What a row's button casts on the right button: a spell or a flyout, or
-- nothing (a passive, one not learned yet). type2, not type: the left
-- button (type1, else type) finds nothing, and casts nothing.
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
    b:SetAttribute("type", nil)
    b:SetAttribute("type2", kind)
    b:SetAttribute("spell", what)
end

-- Out of combat only: a button over each spell or rank row wholly in view,
-- armed; the rest away. A row the scroll's edge cuts has none (it casts
-- nothing) until it scrolls into view. The layer is shown while
-- the window is open (a driver hides it in combat), and hidden when it
-- closes.
local function Follow()
    if not layer or InCombatLockdown() then return end
    local p = W.Current()
    local rows = open and p and p.casts and p.rows or {}
    local s = p and p.scroller
    local top = s and s.offset or 0
    local bottom = top + (s and s.scroll:GetHeight() or 0)
    local n = 0
    for _, c in ipairs(rows) do
        local item = c:IsShown() and c.item
        if item and c.y >= top - 0.5 and c.y + c.h <= bottom + 0.5 then
            n = n + 1
            local b = Secure(n)
            b.item, b.page = item, p
            -- Click Casting open: nothing cast, the click binds (Press)
            Arm(b, not Binding() and item or nil)
            if Binding() then
                b:RegisterForClicks("AnyUp", "AnyDown")
            else
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
            end
            b:SetShown(W.Over(b, c.hit))
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.item = nil
        Arm(b, nil)
        b:Hide()
    end
    if open then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ------------------------------------------------------------------ pages
local Band
function Refresh(p)
    if not p.scroller then return end
    local items = Items(p)
    Place(p, items)
    local macros = Macros()
    local bound = ns.db.spellbookClickCast and ns.clickcast and { ns.clickcast.Bound() }
    local binding = Binding()
    local cbf = _G.ClickBindingFrame
    -- the halo while nothing is in the binder: pick one
    local ready = binding and cbf and ns.clickcast.Step and ns.clickcast.Step() == 1
    for i, item in ipairs(items) do
        local c = p.rows[i]
        if item.heading then
            Kind(c, "heading")
            c.item, c.shut = nil, item.shut
            -- its role's colour fading right, a line of it under
            local col = ROLE[item.role] or GOLD_D
            c.band:SetColorTexture(1, 1, 1, 1)
            if c.band.SetGradient and CreateColor then
                c.band:SetGradient("HORIZONTAL", CreateColor(col[1], col[2], col[3], 0.55),
                    CreateColor(col[1], col[2], col[3], 0.12))
            else
                c.band:SetColorTexture(col[1], col[2], col[3], 0.3)
            end
            c.line:SetColorTexture(col[1], col[2], col[3], 1)
            c.title:SetText(item.heading)
            c.role:SetShown(item.role ~= nil)
            if item.role then c.role:SetTexture(ns.media .. "strips\\" .. ROLE_GLYPH[item.role]) end
            c.count:ClearAllPoints()
            c.count:SetPoint("RIGHT", item.role and -28 or -10, 0)
            c.count:SetText((item.role and ROLE_WORD[item.role] .. "  ·  " or "") .. item.count
                .. ((item.now or 0) > 0 and format("  ·  %d to train now", item.now) or ""))
        else
            Kind(c, item.rank and "rank" or "spell")
            c.item = item
            local info = item.info
            local cast, cost = Costs(item)
            if item.rank then
                c.rank:SetText(info.subName ~= "" and info.subName or info.name)
                c.rcast:SetText(cast or "")
                c.rcost:SetText(cost or "")
                -- in bind mode, a rank it cannot bind greyed
                local grey = binding and not Bindable(item)
                c.rank:SetTextColor(unpack(grey and ns.colors.dim or ns.colors.text or { 1, 1, 1 }))
            else
                local ranks = Ranked(item) and #item.lower + 1 or 0
                local unfolded = ranks > 1 and Open(info.name)
                -- with ranks: a smaller icon, a frame or two stacked behind
                -- it, gold while they show
                c.icon:ClearAllPoints()
                if ranks > 1 then
                    c.icon:SetSize(SMALL, SMALL)
                    c.icon:SetPoint("LEFT", INDENT, -2)
                else
                    c.icon:SetSize(ICON, ICON)
                    c.icon:SetPoint("LEFT", INDENT, 0)
                end
                local rim = unfolded and GOLD or GOLD_D
                for k, st in ipairs(c.stack) do
                    local on = ranks > k
                    st.rim:SetShown(on)
                    st.fill:SetShown(on)
                    st.rim:SetColorTexture(rim[1], rim[2], rim[3], 1)
                end
                c.icon:SetTexture(info.iconID)
                local learned = info.itemType ~= TYPE.FutureSpell
                if item.trainer then learned = item.now end
                c.icon:SetDesaturated(not learned)
                c.icon:SetAlpha((learned and not info.isPassive) and 1 or 0.6)
                c.name:SetText(info.name)
                c.name:SetTextColor(unpack(learned and (info.isPassive and ns.colors.dim or GOLD) or ns.colors.dim))
                -- its rank (the trainer's), how many it has folded away, its click
                local sub
                if item.trainer then
                    sub = item.trainer.rank ~= "" and item.trainer.rank or nil
                else
                    sub = Sub(item)
                end
                if ranks > 1 and not unfolded then
                    sub = (sub and sub .. "  ·  " or "") .. format("%d ranks", ranks)
                end
                item.clicks = Clicks(item, bound)
                if item.clicks then sub = (sub and sub .. "  ·  " or "") .. GOLD_HEX .. item.clicks .. "|r" end
                c.sub:SetText(sub or "")
                c.cast:SetText(cast or "")
                c.cast:SetTextColor(unpack(item.trainer and not item.now and ns.colors.dim
                    or ns.colors.text or { 1, 1, 1 }))
                c.cost:SetText(cost or "")
                c.badge:SetShown(item.clicks ~= nil and not binding)
                -- (in bind mode the bars are not the question: no red edge)
                if binding then
                    item.missing, item.lowerOn = false, nil
                else
                    item.missing, item.lowerOn = Missing(item, macros)
                end
                -- on no bar: a ring two pixels wide in red, and the wash
                local edge, ring = item.missing and MISSING or GOLD_D, item.missing and 2 or 1
                c.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
                c.edge:ClearAllPoints()
                c.edge:SetPoint("TOPLEFT", c.icon, -ring, ring)
                c.edge:SetPoint("BOTTOMRIGHT", c.icon, ring, -ring)
                c.miss:SetShown(item.missing and true or false)
                -- Click Casting open: what it can bind lit (a halo while a
                -- slot waits), the rest grey
                local can = binding and Bindable(item)
                c.halo:SetShown(can and ready or false)
                if binding then
                    if can then
                        c.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
                    else
                        c.icon:SetDesaturated(true)
                        c.icon:SetAlpha(0.5)
                        c.name:SetTextColor(unpack(ns.colors.dim))
                    end
                end
            end
        end
    end
    p.scroller.To(p.scroller.target)
    Band(p)
    Follow()
end

-- The margin, edge to edge (ns.window.Segments): Trainer, once a class
-- trainer has been read, which opens its page and, from it, goes back.
local trainerPage, back
local function Controls(p, band)
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = {
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
    p.trainerButton = row.byKey.trainer
end

-- the margin's state: Trainer once read, marked while its page shows
function Band(p)
    if not p.margin then return end
    p.margin:Set("trainer", { selected = p.trainer, shown = ns.trainers.Visited() })
end

local function Page(spec)
    local p = spec
    p.rows, p.cards = {}, {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_ICON", "PLAYER_LEVEL_UP",
        "UNIT_PET", "PET_BAR_UPDATE", "ACTIONBAR_SLOT_CHANGED", "PLAYER_MONEY" }
    function p.Build(body, foot, band)
        Controls(p, band)
        if p.macros then
            p.note = ns.Text(body, 12)
            p.note:SetPoint("CENTER", 0, 0)
            p.note:SetTextColor(unpack(ns.colors.dim))
            p.note:SetText("Macros arrive in the next version.")
            return
        end
        p.scroller = ns.window.Scroller(body, GUTTER)
        -- the buttons over the rows follow them as they scroll
        if p.casts then p.scroller.Moved = function() Follow() end end
        body:EnableMouseWheel(true)
        body:SetScript("OnMouseWheel", function(_, delta) p.scroller.To(p.scroller.target - delta * STEP) end)
    end
    function p.Refresh()
        if p.macros then Band(p) Follow() return end
        Refresh(p)
    end
    function p.Showing(on)
        if on then open = true elseif W.Current() == p then open = false end
        Follow()
    end
    W.Page(p)
end

-- the book: every skill line, then the pet's
do
    local p = { key = "book", casts = true, order = 1, label = "Spellbook", glyph = "spellbook",
        frame = "SpellBookFrame" }
    function p.Available() return SB ~= nil end
    Page(p)
end
-- macros: a page to come
do
    local p = { key = "macros", macros = true, order = 2, label = "Macros", glyph = "log",
        frame = "SpellBookFrame" }
    function p.Available() return SB ~= nil end
    Page(p)
end
-- what the class trainers have still to teach, once one has been visited
do
    local p = { key = "trainer", trainer = true, tabless = true, order = 3, label = "Trainer",
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
    for _, key in ipairs({ "spellbookMissing", "spellbookUpRankAll", "spellbookClickCast" }) do
        ns.OnSetting(key, function() W.Refresh() end)
    end
    for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
        ns.On(e, function()
            W.Retab()
            W.Refresh()
        end)
    end
    -- click casting: its bindings saved or reset, its window open or shut,
    -- a slot waiting or filled
    local function Again() W.Refresh() end
    if C_ClickBindings then
        for _, fn in ipairs({ "SetProfileByInfo", "ResetCurrentProfile" }) do
            if C_ClickBindings[fn] then hooksecurefunc(C_ClickBindings, fn, Again) end
        end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ClickBindingFrame.UpdateFrames", Again, W)
    end
    if ns.clickcast then ns.clickcast.Stepped = Again end
    local watched
    local function Watch()
        local f = _G.ClickBindingFrame
        if watched or not f then return end
        watched = true
        f:HookScript("OnShow", Again)
        f:HookScript("OnHide", Again)
    end
    Watch()
    ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_ClickBindingUI" then Watch() end end)
    ns.PlayerSpellsTab("SpellBook", W)
end

ns.On("PLAYER_LOGIN", Start)
