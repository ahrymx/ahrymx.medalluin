-- The side panel's Loot tab: what the group looted, yours included, boss by
-- boss. It is not a second chat log (the chat keeps its loot lines): each
-- boss, and each run of trash in one zone, is a heading with its time and
-- your share of the money, and under it a line per item: the item, who got
-- it (in their class colour) and how (the roll that won it, or personal).
--
-- Two sources, joined:
--   C_LootHistory    the boss drops the group rolled on: the winner, their
--                    class, the roll, live while the rolls run
--   chat             CHAT_MSG_LOOT for everything else (personal loot,
--                    trash), CHAT_MSG_MONEY and CHAT_MSG_CURRENCY; read with
--                    patterns made from the client's own strings
-- A roll's winner is told twice, by the history and by the chat's "receives
-- loot" line, so a chat line for an item the history already gave that
-- player (or gives them soon after) is dropped.
--
-- In the newest-first order of the headings; within one, in the order
-- looted. Held for the session only, the newest 30 headings.
--
-- The column: whose loot (the group's or yours), the least quality shown;
-- at the foot, clear the log. All on the options page too.
local _, ns = ...

local LH = C_LootHistory
local HISTORY = LH and LH.GetSortedDropsForEncounter and LH.GetInfoForEncounter
local ROW, GAP, HEAD = 16, 2, 18
local KEEP, SAME = 30, 120      -- headings kept; seconds a chat line and a history drop count as one
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
local QUALITY = {               -- for clients without ITEM_QUALITY_COLORS
    [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 }, { 0, 0.8, 1 },
}
local HOW = {                   -- Enum.EncounterLootDropRollState: label, colour, roll icon
    [0] = { "need", { 0.91, 0.75, 0.31 }, "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    [1] = { "off-spec", { 0.91, 0.75, 0.31 }, "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    [2] = { "transmog", { 0.75, 0.6, 0.95 } },
    [3] = { "greed", { 0.5, 0.72, 0.38 }, "Interface\\Buttons\\UI-GroupLoot-Coin-Up" },
}

local groups, byEncounter = {}, {}
local ignored = {}              -- encounter:drop keys the log was cleared of
local body, rows, heads, lines
local first, shown = 0, 0

local function Now() return GetTime() end

local function Short(name)
    if not name then return nil end
    if Ambiguate then return Ambiguate(name, "short") end
    return (name:gsub("%-.*$", ""))
end

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function Quality(link)
    if not link or not link:match("item:") then return nil end
    local q
    if C_Item and C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(link) end
    if not q and GetItemInfo then q = select(3, GetItemInfo(link)) end
    if not q then q = tonumber(link:match("|cnIQ(%d):")) end
    -- an older client's link carries its quality's colour
    local hex = not q and ITEM_QUALITY_COLORS and link:match("^|c(%x%x%x%x%x%x%x%x)")
    if hex then
        for i, c in pairs(ITEM_QUALITY_COLORS) do
            if c.hex and c.hex:lower() == "|c" .. hex:lower() then q = i end
        end
    end
    return q
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    c = QUALITY[q] or QUALITY[1]
    return c[1], c[2], c[3]
end

local function Icon(item)
    local link = item.link
    if item.currency then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink
            and C_CurrencyInfo.GetCurrencyInfoFromLink(link)
        return info and info.iconFileID
    end
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(link) end
    if GetItemIcon then return GetItemIcon(link) end
end

local function Money(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then table.insert(out, g .. "g") end
    if s > 0 then table.insert(out, s .. "s") end
    if c > 0 and g == 0 then table.insert(out, c .. "c") end
    return table.concat(out, " ")
end

-- A chat string from the client ("%s receives loot: %s.") as a pattern
-- that captures what it formats.
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("%%%d%$", "%%")
    fmt = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    fmt = fmt:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end

-- ------------------------------------------------------------- the log
local function Group(title, encounterID)
    local g = { title = title, time = date and date("%H:%M") or "", at = Now(), money = 0,
        drops = {}, items = {}, encounterID = encounterID }
    table.insert(groups, 1, g)
    while #groups > KEEP do
        local old = table.remove(groups)
        if old.encounterID then byEncounter[old.encounterID] = nil end
    end
    return g
end

-- Where a chat line goes: the boss just killed, the run of trash in this
-- zone, or a new run.
local function Here()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local g = groups[1]
    if g and (g.encounterID and Now() - g.at < SAME or g.zone == zone) then return g end
    g = Group(zone ~= "" and ("Trash  \194\183  " .. zone) or "Trash")
    g.zone = zone
    return g
end

-- Whether the history gave this item to this player lately.
local function Rolled(id, who)
    for _, g in ipairs(groups) do
        if g.encounterID then
            for _, d in ipairs(g.drops) do
                if d.who == who and d.id == id and Now() - d.at < SAME then return true end
            end
        end
    end
    return false
end

-- A winner the chat told first: its line goes, the history's stays.
local function Claim(id, who)
    for _, g in ipairs(groups) do
        for i = #g.items, 1, -1 do
            local it = g.items[i]
            if it.id == id and it.who == who and Now() - it.at < SAME then table.remove(g.items, i) end
        end
    end
end

local function Encounter(id)
    local info = LH.GetInfoForEncounter(id)
    local drops = LH.GetSortedDropsForEncounter(id) or {}
    if not info and #drops == 0 then return end
    local live = {}
    for _, d in ipairs(drops) do
        if not ignored[id .. ":" .. d.lootListKey] then table.insert(live, d) end
    end
    local g = byEncounter[id]
    -- a boss the log was cleared of comes back only with a new drop
    if not g and #drops > 0 and #live == 0 then return end
    if not g then
        g = Group(info and info.encounterName or "", id)
        byEncounter[id] = g
    end
    local old = {}
    for _, d in ipairs(g.drops) do old[d.key] = d end
    g.drops = {}
    for _, d in ipairs(live) do
        local key = id .. ":" .. d.lootListKey
        local w, was = d.winner, old[key]
        local item = { key = key, link = d.itemHyperlink, id = ItemID(d.itemHyperlink),
            quality = Quality(d.itemHyperlink), at = was and was.at or Now() }
        if w then
            item.who, item.class, item.self = Short(w.playerName), w.playerClass, w.isSelf
            item.state, item.roll = w.state, w.roll
            if not (was and was.who) then Claim(item.id, item.who) end
        elseif d.allPassed then
            item.how = "passed"
        else
            item.how = "rolling"
        end
        table.insert(g.drops, item)
    end
end

local CHAT = {}
local function Patterns()
    -- longest first: "x%d" forms before the plain ones they also match
    CHAT.loot = {
        { Pattern(LOOT_ITEM_SELF_MULTIPLE), true, true },
        { Pattern(LOOT_ITEM_SELF), true },
        { Pattern(LOOT_ITEM_MULTIPLE), false, true },
        { Pattern(LOOT_ITEM), false },
    }
    CHAT.currency = { Pattern(CURRENCY_GAINED_MULTIPLE), Pattern(CURRENCY_GAINED) }
    CHAT.money = { Pattern(YOU_LOOT_MONEY_GUILD), Pattern(YOU_LOOT_MONEY), Pattern(LOOT_MONEY_SPLIT_GUILD),
        Pattern(LOOT_MONEY_SPLIT) }
    CHAT.coins = { { Pattern(GOLD_AMOUNT), 10000 }, { Pattern(SILVER_AMOUNT), 100 }, { Pattern(COPPER_AMOUNT), 1 } }
    for _, c in ipairs(CHAT.coins) do
        if c[1] then c[1] = c[1]:sub(2, -2) end     -- found anywhere in the amount, not anchored
    end
end

local function Me() return Short(UnitName("player")) end

local function ClassOf(who)
    if UnitClass then
        local _, class = UnitClass(who)
        return class
    end
end

local function Loot(msg)
    for _, p in ipairs(CHAT.loot) do
        local pat, self, many = p[1], p[2], p[3]
        if pat then
            local a, b, c = msg:match(pat)
            if a then
                local who, link, count
                if self then
                    who, link, count = Me(), a, many and b
                else
                    who, link, count = Short(a), b, many and c
                end
                local id = ItemID(link)
                if not id or Rolled(id, who) then return true end
                table.insert(Here().items, { link = link, id = id, count = tonumber(count), who = who,
                    class = ClassOf(self and "player" or who), self = self, how = "personal", quality = Quality(link),
                    at = Now() })
                return true
            end
        end
    end
end

local function Currency(msg)
    for _, pat in ipairs(CHAT.currency) do
        local link, count = msg:match(pat)
        if link then
            table.insert(Here().items, { link = link, count = tonumber(count), who = Me(), class = ClassOf("player"),
                self = true, how = "personal", currency = true, at = Now() })
            return true
        end
    end
end

local function Coins(msg)
    for _, pat in ipairs(CHAT.money) do
        local amount = msg:match(pat)
        if amount then
            local copper = 0
            for _, c in ipairs(CHAT.coins) do
                local n = c[1] and amount:match(c[1])
                if n then copper = copper + tonumber(n) * c[2] end
            end
            if copper > 0 then
                local g = Here()
                g.money = g.money + copper
            end
            return true
        end
    end
end

-- ------------------------------------------------------------ the lines
local function Shows(item)
    if ns.db.lootWho == ns.LOOT_WHO.MINE and not item.self then return false end
    if item.currency then return ns.db.lootMoney and true or false end
    if item.quality == nil then item.quality = Quality(item.link) end
    return item.quality == nil or item.quality >= ns.db.lootQuality
end

local function Lines()
    local out = {}
    for _, g in ipairs(groups) do
        local list = {}
        for _, set in ipairs({ g.drops, g.items }) do
            for _, item in ipairs(set) do
                if Shows(item) then table.insert(list, item) end
            end
        end
        local money = ns.db.lootMoney and g.money > 0
        if #list > 0 or money then
            table.insert(out, { head = g })
            for _, item in ipairs(list) do table.insert(out, { item = item }) end
        end
    end
    return out
end

local function Head(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(HEAD)
    h.title = ns.Text(h, 11)
    h.title:SetPoint("LEFT", 2, 1)
    h.title:SetTextColor(unpack(GOLD))
    h.when = ns.PlainText(h, 10)
    h.when:SetPoint("RIGHT", -2, 1)
    h.when:SetTextColor(unpack(DIM))
    h.title:SetPoint("RIGHT", h.when, "LEFT", -6, 0)
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    local line = h:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", 0, 2)
    return h
end

local function Row(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW)
    r.edge = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.edge:SetSize(ROW, ROW)
    r.edge:SetPoint("LEFT", 2, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK", nil, 2)
    r.icon:SetSize(ROW - 2, ROW - 2)
    r.icon:SetPoint("CENTER", r.edge)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- right to left: how (the roll icon and number, or "personal"), who, the item
    r.how = ns.Text(r, 10)
    r.how:SetPoint("LEFT", r, "RIGHT", -42, 0)
    r.die = r:CreateTexture(nil, "ARTWORK")
    r.die:SetSize(12, 12)
    r.die:SetPoint("LEFT", r, "RIGHT", -56, 0)
    r.who = ns.Text(r, 10)
    r.who:SetPoint("RIGHT", r, "RIGHT", -60, 0)
    r.link = ns.PlainText(r, 10)
    r.link:SetPoint("LEFT", ROW + 6, 0)
    r.link:SetPoint("RIGHT", r.who, "LEFT", -6, 0)
    r.link:SetJustifyH("LEFT")
    r.link:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        ns.side.Beside(self)
        GameTooltip:SetHyperlink(self.item.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if self.item and HandleModifiedItemClick then HandleModifiedItemClick(self.item.link) end
    end)
    ns.side.PassWheel(r)
    return r
end

local function FillRow(r, item)
    r.item = item
    local q = item.quality or 1
    r.edge:SetColorTexture(QualityColor(q))
    local icon = Icon(item)
    if icon then r.icon:SetTexture(icon) else r.icon:SetColorTexture(0.071, 0.067, 0.063, 1) end
    r.link:SetText(item.link .. (item.count and item.count > 1 and (" x" .. item.count) or ""))
    r.who:SetText(item.who or "")
    local c = item.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.class]
    if c then r.who:SetTextColor(c.r, c.g, c.b) else r.who:SetTextColor(unpack(ns.colors.text)) end
    local how = item.state and HOW[item.state]
    if how then
        r.how:SetText(item.roll and tostring(item.roll) or how[1])
        r.how:SetTextColor(unpack(how[2]))
        r.die:SetShown(how[3] ~= nil)
        if how[3] then r.die:SetTexture(how[3]) end
        r.how:ClearAllPoints()
        r.how:SetPoint("LEFT", r, "RIGHT", how[3] and -42 or -56, 0)
    else
        r.how:SetText(item.how or "")
        r.how:SetTextColor(unpack(DIM))
        r.die:Hide()
        r.how:ClearAllPoints()
        r.how:SetPoint("LEFT", r, "RIGHT", -56, 0)
    end
    r:Show()
end

local empty
local function Refresh()
    if not body then return end
    lines = Lines()
    if first > 0 and first >= #lines then first = math.max(0, #lines - 1) end
    local y, nh, nr = 0, 0, 0
    local height = body:GetHeight()
    shown = 0
    for i = first + 1, #lines do
        local l = lines[i]
        local h = l.head and HEAD + 1 or ROW + GAP
        if y + h - (l.head and 1 or GAP) > height then break end
        if l.head then
            nh = nh + 1
            local f = heads[nh] or Head(body)
            heads[nh] = f
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetPoint("TOPRIGHT", 0, -y)
            f.title:SetText(l.head.title)
            local money = ns.db.lootMoney and l.head.money > 0 and Money(l.head.money)
            f.when:SetText(l.head.time .. (money and ("  \194\183  " .. money) or ""))
            f:Show()
        else
            nr = nr + 1
            local r = rows[nr] or Row(body)
            rows[nr] = r
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            FillRow(r, l.item)
        end
        y = y + h
        shown = shown + 1
    end
    for i = nh + 1, #heads do heads[i]:Hide() end
    for i = nr + 1, #rows do
        rows[i]:Hide()
        rows[i].item = nil
    end
    empty:SetShown(#lines == 0)
    ns.side.Changed()
end

-- New loot: drawn now if the tab is up, else when it is next shown.
local function Update()
    if ns.side.IsCurrent(ns.side.loot) then Refresh() end
end

-- ------------------------------------------------------------- the view
local view = {
    key = "loot", label = "Loot", option = "sideLoot",
    Available = function() return true end,
}
ns.side.loot = view

function view.Build(f)
    body, rows, heads = f, {}, {}
    empty = ns.Text(f, 10)
    empty:SetPoint("TOPLEFT", 4, -6)
    empty:SetTextColor(unpack(DIM))
    empty:SetText("Nothing looted yet.")
    Patterns()
    if HISTORY then
        local infos = LH.GetAllEncounterInfos and LH.GetAllEncounterInfos() or {}
        table.sort(infos, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
        for _, info in ipairs(infos) do Encounter(info.encounterID) end
        -- from before a reload: no chat line now belongs to these
        for _, g in ipairs(groups) do g.at = Now() - SAME end
        ns.On("LOOT_HISTORY_UPDATE_ENCOUNTER", function(_, id)
            Encounter(id)
            Update()
        end)
        ns.On("LOOT_HISTORY_UPDATE_DROP", function(_, id)
            Encounter(id)
            Update()
        end)
    end
    -- in combat a chat line can be secret; such a line is left to the chat
    local function Chat(read)
        return function(_, msg)
            if type(msg) ~= "string" or ns.IsSecret(msg) then return end
            if read(msg) then Update() end
        end
    end
    ns.On("CHAT_MSG_LOOT", Chat(Loot))
    ns.On("CHAT_MSG_CURRENCY", Chat(Currency))
    ns.On("CHAT_MSG_MONEY", Chat(Coins))
    -- an item's quality and icon arrive after its line, the first time it is seen
    ns.On("GET_ITEM_INFO_RECEIVED", Update)
    for _, key in ipairs({ "lootWho", "lootQuality", "lootMoney" }) do ns.OnSetting(key, Refresh) end
end

view.Refresh = Refresh

function view.Scroll(by)
    first = math.max(0, math.min(first + by, #(lines or {}) - shown))
    Refresh()
end

function view.Thumb()
    return first, shown, #(lines or {})
end

local function Step(by)
    local q = (ns.db.lootQuality + by) % #ns.LOOT_QUALITIES
    ns.SetOption("lootQuality", q)
end

view.buttons = {
    {
        glyph = function() return "side-filter" end,
        lit = function() return ns.db.lootWho == ns.LOOT_WHO.MINE end,
        click = function()
            ns.SetOption("lootWho", ns.db.lootWho == ns.LOOT_WHO.MINE and ns.LOOT_WHO.GROUP or ns.LOOT_WHO.MINE)
        end,
        tip = function()
            if ns.db.lootWho == ns.LOOT_WHO.MINE then
                return "Mine", "Only what you looted or won. Click for the group's."
            end
            return "The group's", "Everything the group looted, yours included. Click for yours only."
        end,
    },
    {
        glyph = function() return "side-quality" end,
        lit = function() return false end,
        tint = function() return QualityColor(ns.db.lootQuality) end,
        click = function(mouse) Step(mouse == "RightButton" and -1 or 1) end,
        tip = function()
            local name = "?"
            for _, q in ipairs(ns.LOOT_QUALITIES) do
                if q[1] == ns.db.lootQuality then name = q[2] end
            end
            return "Least quality: " .. name, "Click for the next quality up; right click for the one down."
        end,
    },
}
view.foot = {
    glyph = function() return "side-reset" end,
    lit = function() return false end,
    click = function()
        for _, g in ipairs(groups) do
            for _, d in ipairs(g.drops) do ignored[d.key] = true end
        end
        wipe(groups)
        wipe(byEncounter)
        first = 0
        Refresh()
    end,
    tip = function() return "Clear", "Clear the loot log. The game's own loot history keeps its rolls." end,
}

ns.SideView(view)
