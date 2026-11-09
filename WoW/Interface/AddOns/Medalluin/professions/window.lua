-- The professions: Medalluin's own (the shell is window/shell.lua), standing
-- on the right strip as the spellbook does, its margin beside the
-- backpack's medallion. Forever only: its professions book and crafting are
-- one frame, ProfessionsFrame (the book its Overview page); retail keeps
-- Blizzard's.
--
--    Overview   primary   primary                                  x
--   ____                       (open tabs: no boxes, the one in use
--    secondary   secondary      underlined; rows on fading hairs)
--   ---------------------------------------------------------------
--   the character's header, its portrait on its rule (professions/alts.lua)
--   ------------------------- Alts --------------------------------
--   [class] an alt  its class          its primary professions
--   ------------------- Primary professions -----------------------
--               (icon)            :            (icon)
--           Blacksmithing         :            Mining
--      [====== 142 / 150 ======]  :   [====== 87 / 150 ======]
--          Train Expert now       :   Expert at skill 125, level 20
--          [spell] [spell]     x  :       [spell] [spell]      x
--   ------------------ Secondary professions ----------------------
--   (icon) Cooking   [========= 5 / 75 =========]  [spell]      x
--   ------------------------- Camping -----------------------------
--   the camp's buffs and objects, one strip (professions/camping.lua)
--   ---------------------------------------------------------------
--
-- Overview is a pillar per primary profession (an empty one when not
-- learned) and a line per secondary learned, under a heading each (none
-- learned: no heading), then Camping; each other tab is a profession with recipes, crafted here
-- (professions/crafting.lua). The tabs are Overview and one per profession
-- that crafts, six at most: Overview and the primaries on the first row,
-- the secondaries on a second under it (none: no second row); fewer
-- professions, wider tabs. The details are always open (no chevron).
--
-- Under a pillar's bar, or in a line's tooltip, its next rank: gold when its skill and level are met
-- (red when the bar is within 5 of its cap, points about to be wasted),
-- dim with what it asks otherwise. The ranks are the game's (Journeyman at
-- skill 50 and level 10, ...), a trainer's own list preferred once read
-- (spells/trainers.lua); none past what this expansion's level reaches.
--
-- A card's spells (Smelting, Find Herbs) are cast by the client: secure
-- buttons over them in a layer on the strip, as the spellbook's are, gone
-- in combat. Unlearn is Blizzard's own question.
--
-- Blizzard's frame keeps every way in: the key, the micro button, a
-- profession's spell. It opens and closes under a hidden parent, and this
-- window shows while it is open, on the page Blizzard shows: Overview for
-- its book, the open profession's tab for its crafting. A profession's tab
-- opens that profession (out of combat); Overview turns our page alone.
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local RED = { 1, 0.3, 0.25 }
local GAP, ICON, SPELL, SMALL = 6, 40, 30, 24   -- a pillar's icon and spells; a line's both
local PILLAR, LINE = 150, 32            -- a primary's pillar, a secondary's line
local HALF = math.floor((ns.window.width - GAP) / 2)    -- a pillar's width
local SPELL_Y, NAME_W = 112, 130        -- a pillar's spells' top; a line's icon and name
local CROSS, FAINT = 16, 0.45           -- Unlearn's cross, and its alpha at rest
local CARDS = 5                         -- two primaries and three secondaries
local NONE = "Interface\\Icons\\INV_Scroll_04"

local W = ns.Window{
    name = "MedalluinProfessions", side = 1,
    closeTip = "Close the professions.",
    Close = function() HideUIPanel(ProfessionsFrame) end,
    Open = function(page) if page.Open then page.Open() end end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.professions = W

local layer                             -- the cards' spells, secure, on the strip
local open                              -- the window open on Overview
local overview

-- ------------------------------------------------------------- the data
-- The professions learned, in the game's order (the two primaries, then
-- the secondaries), each { index, name, icon, rank, max, modifier, spells,
-- offset, skillLine, primary, crafts }.
function W.Learned()
    local out = {}
    local list = { GetProfessions() }
    for i = 1, math.max(2, select("#", GetProfessions())) do
        local index = list[i]
        if index then
            local name, icon, rank, max, spells, offset, skillLine, modifier = GetProfessionInfo(index)
            local item = C_SpellBook.GetSpellBookItemInfo(offset + 1, Enum.SpellBookSpellBank.Player)
            local crafts = item and item.spellID and C_TradeSkillUI.CanTradeSkillShowCraftingUI(item.spellID) or false
            table.insert(out, { index = index, name = name, icon = icon, rank = rank, max = max,
                modifier = modifier or 0, spells = spells, offset = offset, skillLine = skillLine,
                primary = i <= 2, crafts = crafts })
        elseif i <= 2 then
            table.insert(out, { primary = true })
        end
    end
    return out
end

-- the profession whose crafting is open, by its base skill line
function W.Skill()
    if Professions and Professions.GetEffectiveSkillLineID then return Professions.GetEffectiveSkillLineID() end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    return info and info.professionID or 0
end

-- The ranks: name, cap, the level and skill to learn it
local RANKS = {
    { "Apprentice", 75, 1, 1 }, { "Journeyman", 150, 10, 50 }, { "Expert", 225, 20, 125 },
    { "Artisan", 300, 35, 200 }, { "Master", 375, 50, 275 }, { "Grand Master", 450, 65, 350 },
}

-- the highest cap this expansion reaches: Artisan's at 60, a rank a 10 levels
local function Top()
    local level = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
    return 300 + 75 * math.max(0, math.floor((level - 60) / 10))
end

-- the rank after a profession's: { name, level, skill }, or nil at the top;
-- a trainer's service of that rank's name, when one was read, says instead
function W.NextRank(prof)
    for _, r in ipairs(RANKS) do
        if r[2] > prof.max then
            if r[2] > Top() then return nil end
            local out = { name = r[1], level = r[3], skill = r[4] }
            local list = ns.trainers and ns.trainers.Trade(prof.name) or {}
            for _, e in pairs(list) do
                if e.name:find(r[1], 1, true) or (e.rank and e.rank:find(r[1], 1, true)) then
                    out.level = e.level and e.level > 0 and e.level or out.level
                    out.skill = e.skill and e.skill > 0 and e.skill or out.skill
                    break
                end
            end
            return out
        end
    end
end

-- the line under a card's bar: its text and colour, or nil
function W.RankLine(prof)
    local r = W.NextRank(prof)
    if not r then return nil end
    if prof.rank >= r.skill and UnitLevel("player") >= r.level then
        return format("Train %s now", r.name), prof.rank >= prof.max - 5 and RED or GOLD
    end
    return format("%s at skill %d, level %d", r.name, r.skill, r.level), ns.colors.dim
end

-- ----------------------------------------------------------------- cards
-- A primary stands as a pillar, half the width, centred top to bottom; a
-- secondary lies on one line, its next rank in its tooltip:
--
--              (icon)
--            Herbalism              (icon) Fishing  [== 1 / 75 ==] [s][s] x
--     [====== 92 / 150 ======]
--   Expert at skill 125, level 20
--         [spell] [spell]     x
--
-- Neither has a box: a hair parts the pillars, and the lines.
local function Spell(card, size)
    local s = CreateFrame("Button", nil, card)
    s:SetSize(size, size)
    s.edge = s:CreateTexture(nil, "BACKGROUND")
    s.edge:SetPoint("TOPLEFT", -1, 1)
    s.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    s.edge:SetColorTexture(0.541, 0.439, 0.204, 1)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints()
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s:SetScript("OnEnter", function(self)
        if not self.slot then return end
        W.Beside(self)
        GameTooltip:SetSpellBookItem(self.slot, Enum.SpellBookSpellBank.Player)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

-- Unlearn, a faint cross that lights under the mouse; Blizzard's question
local function Cross(card)
    local x = CreateFrame("Button", nil, card)
    x:SetSize(CROSS, CROSS)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetSize(12, 12)
    x.icon:SetPoint("CENTER")
    x.icon:SetTexture(ns.media .. "strips\\close")
    x.icon:SetAlpha(FAINT)
    x:SetScript("OnClick", function(self)
        local p = self:GetParent().prof
        if p and p.name and not InCombatLockdown() then StaticPopup_Show("UNLEARN_SKILL", p.name, nil, p.skillLine) end
    end)
    x:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
        local p = self:GetParent().prof
        ns.Tip(self, W.Beside, { title = format("Unlearn %s: forget it, and every recipe of it.",
            p and p.name or ""), color = ns.colors.white, wrap = true })
    end)
    x:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(FAINT)
        GameTooltip:Hide()
    end)
    return x
end

local function Card(body, pillar)
    local c = CreateFrame("Frame", nil, body)
    c.pillar = pillar
    c:SetHeight(pillar and PILLAR or LINE)
    c.icon = ns.window.Ring(c, pillar and ICON or SMALL)
    c.name = ns.Text(c, 14)
    c.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.bar = ns.character.Bar(c, pillar and HALF - 36 or 200)
    c.none = ns.Text(c, 12)
    c.none:SetTextColor(unpack(ns.colors.dim))
    c.rank = ns.Text(c, 12)
    c.unlearn = Cross(c)
    c.spells = {}
    if pillar then
        c.icon:SetPoint("TOP", 0, -6)
        c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -8)
        c.bar:SetPoint("TOP", c.name, "BOTTOM", 0, -6)
        c.none:SetPoint("TOP", c.name, "BOTTOM", 0, -8)
        c.none:SetWidth(HALF - 16)
        c.rank:SetPoint("TOP", c.bar, "BOTTOM", 0, -5)
        c.unlearn:SetPoint("BOTTOMRIGHT", -2, 2)
        for i = 1, 2 do c.spells[i] = Spell(c, SPELL) end
    else
        c.icon:SetPoint("LEFT", 6, 0)
        c.name:SetPoint("LEFT", c.icon, "RIGHT", 10, 0)
        c.bar:SetPoint("LEFT", NAME_W, 0)
        c.none:SetPoint("LEFT", NAME_W, 0)
        c.rank:SetPoint("LEFT", NAME_W, 0)
        c.unlearn:SetPoint("RIGHT", -2, 0)
        -- the first at the right
        for i = 1, 2 do
            local s = Spell(c, SMALL)
            s:SetPoint("RIGHT", c.unlearn, "LEFT", -6 - (i - 1) * (SMALL + 4), 0)
            c.spells[i] = s
        end
        c.hair = ns.window.Hair(c, false, 0.6)
        c.hair:SetPoint("TOPLEFT", 20, GAP / 2)
        c.hair:SetPoint("TOPRIGHT", -20, GAP / 2)
        -- the next rank, which a line has no room for
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            local prof = self.prof
            if not prof or not prof.name then return end
            W.Beside(self)
            GameTooltip:SetText(prof.name, GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(self.bar.text:GetText() or "", 1, 1, 1)
            if self.rank:GetText() and self.rank:GetText() ~= "" then
                GameTooltip:AddLine(self.rank:GetText(), unpack(self.rankColor or ns.colors.dim))
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return c
end

local function Fill(c, prof)
    c.prof = prof
    local learned = prof.name ~= nil
    c.icon:SetTexture(learned and prof.icon or NONE)
    c.icon:SetDesaturated(not learned)
    c.name:SetText(learned and prof.name or "Primary profession")
    c.name:SetTextColor(unpack(learned and GOLD or ns.colors.dim))
    c.bar:SetShown(learned)
    c.none:SetShown(not learned)
    c.none:SetText(learned and "" or "Not learned. A trainer teaches one.")
    c.unlearn:SetShown(learned)
    if learned then
        local text = prof.modifier > 0 and format("%d (+%d) / %d", prof.rank, prof.modifier, prof.max)
            or format("%d / %d", prof.rank, prof.max)
        c.bar:Fill({ min = 0, max = prof.max, cur = prof.rank, text = text })
    end
    local line, color
    if learned then line, color = W.RankLine(prof) end
    c.rank:SetText(line or "")
    c.rankColor = color
    if color then c.rank:SetTextColor(unpack(color)) end
    -- a line's rank is in its tooltip
    c.rank:SetShown(c.pillar and line ~= nil or false)
    local n = learned and math.min(prof.spells or 0, #c.spells) or 0
    for i, s in ipairs(c.spells) do
        local slot = i <= n and prof.offset + i or nil
        local item = slot and C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
        s.slot, s.item = item and slot or nil, item
        s:SetShown(item ~= nil)
        if item then s.icon:SetTexture(item.iconID) end
    end
    if c.pillar then
        -- the spells centred, the first at the left
        local from = (HALF - (n * SPELL + math.max(0, n - 1) * 8)) / 2
        for i, s in ipairs(c.spells) do
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", from + (i - 1) * (SPELL + 8), -SPELL_Y)
        end
    else
        -- the bar runs up to the spells, or the cross
        c.bar:SetPoint("RIGHT", n > 0 and c.spells[n] or c.unlearn, "LEFT", -10, 0)
    end
end

-- ------------------------------------------------------ the secure layer
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type", "spell")
    b:SetScript("OnDragStart", function(self)
        if self.slot and not InCombatLockdown() then
            C_SpellBook.PickupSpellBookItem(self.slot, Enum.SpellBookSpellBank.Player)
        end
    end)
    b:SetScript("OnEnter", function(self) if self.cell then self.cell:GetScript("OnEnter")(self.cell) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.12)
    layer.buttons[i] = b
    return b
end

-- Out of combat only: a button over each card's spell, the rest away; the
-- layer shown while the window is open on Overview (hidden in combat).
local function Follow()
    if not layer or InCombatLockdown() then return end
    local n = 0
    if open then
        for _, c in ipairs(overview.cards) do
            for _, s in ipairs(c.spells) do
                if c:IsShown() and s:IsShown() and s.item then
                    n = n + 1
                    local b = Secure(n)
                    b.slot, b.cell = s.slot, s
                    b:SetAttribute("spell", s.item.spellID or s.item.actionID)
                    b:SetShown(W.Over(b, s))
                end
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.slot, b.cell = nil, nil
        b:SetAttribute("spell", nil)
        b:Hide()
    end
    if open then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- -------------------------------------------------------------- Overview
overview = { key = "overview", label = "Overview", glyph = "profession", order = 0, frame = "ProfessionsFrame" }
overview.cards = {}
overview.events = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "TRADE_SKILL_LIST_UPDATE", "PLAYER_REGEN_ENABLED",
    "PLAYER_LEVEL_UP", "TRAINER_UPDATE", "BAG_UPDATE_DELAYED" }
function overview.Available() return true end
function overview.Build(body)
    for i = 1, CARDS do overview.cards[i] = Card(body, i <= 2) end
    overview.split = ns.window.Hair(body, true)
    overview.heads = {
        primary = ns.window.Ornament(body, "Primary professions"),
        secondary = ns.window.Ornament(body, "Secondary professions"),
        camp = ns.window.Ornament(body, "Camping"),
    }
    overview.camp = W.Camp(body)
    overview.camp.Changed = function() overview.Refresh() end
    overview.banner = W.Banner(body)
    overview.heads.alts = ns.window.Ornament(body, "Alts")
    overview.alts = W.AltRows(body)
    -- what it takes is measured as it is laid out (Refresh); until then, the cards
    overview.height = PILLAR + (CARDS - 2) * (LINE + GAP)
end
function overview.Refresh()
    local learned = W.Learned()
    local y = 0
    local function Put(f, height)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", 0, -y)
        f:Show()
        y = y + height
    end
    local function Head(f)
        y = y + GAP
        Put(f, 12 + GAP)
    end
    local secondaries = learned[3] ~= nil
    overview.banner.Refresh()
    Put(overview.banner, W.BANNER_H)
    -- the alts, under a heading of their own; none: neither
    local alts = overview.alts
    local tall = alts.Refresh()
    overview.heads.alts:SetShown(tall > 0)
    alts:SetShown(tall > 0)
    if tall > 0 then
        Head(overview.heads.alts)
        Put(alts, tall)
    end
    -- the primaries side by side (W.Learned has both, learned or not), a
    -- hair down between them
    Head(overview.heads.primary)
    local cards = overview.cards
    for i = 1, 2 do
        local c = cards[i]
        Fill(c, learned[i])
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", (i - 1) * (HALF + GAP), -y)
        c:SetWidth(HALF)
        c:Show()
    end
    overview.split:ClearAllPoints()
    overview.split:SetPoint("TOP", 0, -(y + 6))
    overview.split:SetHeight(PILLAR - 12)
    y = y + PILLAR + GAP
    -- the secondaries, a line each, a hair between
    overview.heads.secondary:SetShown(secondaries)
    if secondaries then Head(overview.heads.secondary) end
    for i = 3, CARDS do
        local c, prof = cards[i], learned[i]
        c:SetShown(prof ~= nil)
        if prof then
            Fill(c, prof)
            c.hair:SetShown(i > 3)
            Put(c, LINE + GAP)
        end
    end
    Head(overview.heads.camp)
    local camp = overview.camp
    camp:ClearAllPoints()
    camp:SetPoint("TOPLEFT", 0, -y)
    camp:SetPoint("TOPRIGHT", 0, -y)
    local need = y + camp.Refresh(learned)
    Follow()
    -- the window as tall as what is shown, not as the most it could show:
    -- a fixed page taller than the screen runs the window off its top
    if need ~= overview.height then
        overview.height = need
        W.Retab()
    end
end
function overview.Showing(on)
    open = on                           -- only Overview has spells to cast
    Follow()
end
W.Page(overview)

-- ----------------------------------------------------- Blizzard's frame
-- The page Blizzard's frame is on: its book, or the open profession.
local function Want()
    local f = ProfessionsFrame
    if f.BookPage and f.BookPage:IsShown() then return overview end
    local skill = W.Skill()
    for _, p in ipairs(W.pages) do
        if p.available and p.skillLine and p.skillLine == skill then return p end
    end
    return overview
end

-- Closing is at once; opening waits for the frame's end, by when Blizzard
-- has turned to the page it opens on.
local waiting
local function Sync()
    if not ProfessionsFrame:IsShown() then W.SetShown(false) return end
    if waiting then return end
    waiting = true
    C_Timer.After(0, function()
        waiting = false
        if not ProfessionsFrame:IsShown() then return end
        W.Retab()
        local p = Want()
        if W.Current() ~= p then W.Select(p) end
        W.SetShown(true)
        -- one window on the right strip: the spellbook's or talents' frame
        -- closes (out of combat), when one of ours stands on it
        local spells = PlayerSpellsFrame
        if spells and spells:IsShown() and spells:GetParent() == ns.hidden and not InCombatLockdown() then
            HideUIPanel(spells)
        end
    end)
end
W.Sync = Sync

local function Adopt()
    local f = ProfessionsFrame
    if not f or W.adopted then return end
    W.adopted = true
    ns.Park(f)
    for _, frame in ipairs({ f, f.BookPage, f.CraftingPage }) do
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            hooksecurefunc(frame, method, Sync)
        end
    end
    Sync()
end

local function Start()
    if not ns.db.professions or not SpellbookMicroButton or not C_TradeSkillUI or not GetProfessions then return end
    W.Build()
    -- the camp's timers, each second while the Overview shows (hooked
    -- once built: the shell sets the window's own OnUpdate as it builds)
    local second
    W.window:HookScript("OnUpdate", function()
        if not (overview.body and overview.body:IsVisible()) then return end
        local now = math.floor(GetTime())
        if now ~= second then
            second = now
            overview.camp.Tick()
        end
    end)
    layer = W.Layer("MedalluinProfessionsCasts")
    W.layer = layer
    W.Select(overview)
    -- a profession learned or forgotten; one opened (its spell, a tab)
    for _, e in ipairs({ "SKILL_LINES_CHANGED", "SPELLS_CHANGED" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("TRADE_SKILL_SHOW", function() if W.window:IsShown() then Sync() end end)
    -- a profession's tab chosen in combat opens it now
    ns.On("PLAYER_REGEN_ENABLED", function()
        Follow()
        local p = W.Current()
        if W.window:IsShown() and p.Open then p.Open() end
    end)
    if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        Adopt()
    else
        ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_Professions" then Adopt() end end)
    end
end

ns.On("PLAYER_LOGIN", Start)
