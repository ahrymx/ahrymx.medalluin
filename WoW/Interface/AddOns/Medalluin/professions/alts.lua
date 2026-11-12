-- The Overview's head (professions/window.lua puts it over the cards): the
-- character's banner, its Alts button at its left (the realm's other
-- characters, counted; none: no button).
--
--   [@ Alts 3]                  Ahrymx                       Level 60
--                       Human Warrior  ·  <Guild>
--   ============================(portrait)===========================
--
-- The alts are what each character recorded of itself when it last
-- played (MedalluinDB.roster[realm][name]: class, level, primaries), so a
-- character appears once it has logged in with Medalluin. The Alts button
-- opens the characters' window on its Characters tab, the banner on the
-- playing character's Professions (detached: MedalluinDB.altPlace).
--
-- The window, a page a tab, the character in each page's band ("Level 60
-- Priest · last played 3 days ago"), what it recorded of itself
-- (professions/altdata.lua):
--   Characters   every character on the realm, the playing one first, then
--                the most recently played: its class, level, primaries,
--                when last played and its soonest cooldown; the one shown
--                marked; a click shows it, on its Professions
--   Professions  a bar a profession, then every recipe it knows, searched
--                by name (its output's quality colour; its tooltip)
--   Items        its bank and bags: a filter (the bags window's groups,
--                ns.ItemGroup; altItemsFilter), a search, and a list (a
--                line an item: Bank, Bags, All) or a grid (the bank's and
--                the bags' slots) (altItemsView); its money
--   Notes        a pad, saved as it is typed; any character's to write
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local STRIP, PORTRAIT = 64, 40
-- the header: its strip, and the portrait hanging half below its rule
local BANNER = STRIP + PORTRAIT / 2 + 2
local CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
W.BANNER_H = BANNER

local function Realm() return GetRealmName and GetRealmName() or "?" end

local function Roster()
    MedalluinDB.roster = type(MedalluinDB.roster) == "table" and MedalluinDB.roster or {}
    local realm = Realm()
    MedalluinDB.roster[realm] = MedalluinDB.roster[realm] or {}
    return MedalluinDB.roster[realm]
end

-- this character, as its alts will read it
local function Record()
    if not MedalluinDB then return end
    local name = UnitName("player")
    if not name or ns.IsSecret(name) then return end
    local className, class = UnitClass("player")
    local primaries = {}
    local a, b = GetProfessions()
    for _, index in ipairs({ a or false, b or false }) do
        if index then
            local pname, icon, rank, max = GetProfessionInfo(index)
            table.insert(primaries, { name = pname, icon = icon, rank = rank, max = max })
        end
    end
    Roster()[name] = { class = class, className = className, level = UnitLevel("player"),
        primaries = primaries, seen = time and time() or 0 }
end
W.RecordAlt = Record

for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP" }) do
    ns.On(e, function() if GetProfessions then Record() end end)
end

-- the realm's other characters, most recently played first
function W.Alts()
    local out = {}
    local me = UnitName("player")
    for name, e in pairs(Roster()) do
        if name ~= me and type(e) == "table" then table.insert(out, { name = name, e = e }) end
    end
    table.sort(out, function(x, y)
        if (x.e.seen or 0) ~= (y.e.seen or 0) then return (x.e.seen or 0) > (y.e.seen or 0) end
        return x.name < y.name
    end)
    return out
end

local function Color(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and { c.r, c.g, c.b } or ns.colors.text
end

local function ClassIcon(t, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    t:SetTexture(CIRCLES)
    if coords then t:SetTexCoord(unpack(coords)) else t:SetTexCoord(0, 1, 0, 1) end
end

-- ----------------------------------------------------------- the window
-- A character's own window: detached, three pages, each with the
-- character in its band (name, level and class, when last played) and the
-- page's own line on the right. What it shows is what the character
-- recorded of itself (professions/altdata.lua, ns.alts); the playing
-- character's is read fresh as it opens.
local AW, shown, dirty
local pages = {}
local SEARCH, SLOT, FOLD = 20, 37, 24
local TOOLBAR, SKILLS_TOP, COLUMN_GAP = 28, 8, 18 -- a page's strip; over the skills; between their columns

local function Ago(t)
    local d = (time and time() or 0) - (t or 0)
    if not t or t <= 0 then return nil end
    if d < 120 then return "just now" end
    if d < 7200 then return format("%d minutes ago", d / 60) end
    if d < 172800 then return format("%d hours ago", d / 3600) end
    return format("%d days ago", d / 86400)
end

local function Data()
    if not shown then return {} end
    if shown.me then return ns.alts.Me() or {} end
    return ns.alts.Data(shown.name)
end

local function Quality(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and { c.r, c.g, c.b } or ns.colors.text
end

-- an item's name, icon and quality; an item the client has not loaded yet
-- is asked for, and the page drawn again once it comes
local function Item(id)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and GetItemInfo then name = GetItemInfo(id) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    return name or ("Item " .. id), icon, quality
end

-- A page's band: the character on the left, the page's line on the right.
local function Band(page, band)
    page.who = ns.Text(band, 13)
    page.who:SetPoint("LEFT", 4, 0)
    page.what = ns.Text(band, 11)
    page.what:SetPoint("LEFT", page.who, "RIGHT", 10, 0)
    page.what:SetTextColor(unpack(ns.colors.dim))
    page.note = ns.Text(band, 11)
    page.note:SetPoint("RIGHT", -18, 0)          -- clear of the size grip
    page.note:SetTextColor(unpack(ns.colors.dim))
end

local function Who(page)
    local e = shown and shown.e or {}
    page.who:SetText(shown and shown.name or "")
    page.who:SetTextColor(unpack(Color(e.class)))
    local when = shown and shown.me and "playing now" or Ago(e.seen)
    page.what:SetText(format("Level %d %s", e.level or 0, e.className or "")
        .. (when and ("  \194\183  " .. (shown.me and when or ("last played " .. when))) or ""))
end

-- A search box at a page's top.
local function Search(page, body, name, hint)
    local s = CreateFrame("EditBox", name, body, "SearchBoxTemplate")
    s:SetHeight(SEARCH)
    s:SetAutoFocus(false)
    if s.Instructions then s.Instructions:SetText(hint) end
    s:HookScript("OnTextChanged", function() page.Refresh() end)
    for _, k in ipairs({ "Left", "Right", "Middle" }) do
        if s[k] then s[k]:Hide() end
    end
    page.search = s
    return s
end

local function Words(page)
    local t = page.search and page.search:GetText() or ""
    return (t:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

-- pieces made as needed and kept, a pool a kind
local function Pool(page, kind, make)
    page.used[kind] = (page.used[kind] or 0) + 1
    page.parts[kind] = page.parts[kind] or {}
    local p = page.parts[kind][page.used[kind]]
    if not p then
        p = make()
        page.parts[kind][page.used[kind]] = p
    end
    p:Show()
    return p
end

local function Spare(page)
    for kind, list in pairs(page.parts) do
        for i = (page.used[kind] or 0) + 1, #list do list[i]:Hide() end
    end
end

-- an icon in its quality's edge
local function Icon(parent, size)
    local edge = parent:CreateTexture(nil, "BORDER")
    edge:SetSize(size, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return edge, icon
end

-- A heading across the list: its name in gold, a dim count after, and an
-- underline across (the Items' Bank and Bags, and the recipes'
-- professions, which fold)
local function Banded(r, sign)
    r:SetHeight(FOLD)
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetPoint("BOTTOMLEFT", 8, 2)
    r.line:SetPoint("BOTTOMRIGHT", -8, 2)
    r.line:SetHeight(1)
    r.line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.9)
    local x = 10
    if sign then
        r.sign = ns.Text(r, 14)
        r.sign:SetPoint("LEFT", x, 0)
        r.sign:SetTextColor(unpack(GOLD))
        x = x + 14
    end
    r.name = ns.Text(r, 13)
    r.name:SetPoint("LEFT", x, 0)
    r.name:SetTextColor(unpack(GOLD))
    r.count = ns.Text(r, 11)
    r.count:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
    r.count:SetTextColor(unpack(ns.colors.dim))
    return r
end

local function Heading(page, text, count, y, width)
    local h = Pool(page, "heading", function() return Banded(CreateFrame("Frame", nil, page.child)) end)
    h.name:SetText(text)
    h.count:SetText(count or "")
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetWidth(width)
    return y + FOLD + 4
end

-- the list as wide as its scroll frame, before it is laid out
local function Width(page)
    local width = math.max(1, page.scroller.scroll:GetWidth() or 1)
    page.child:SetWidth(width)
    return width
end

local function Fit(page, y)
    page.child:SetSize(math.max(1, page.scroller.scroll:GetWidth() or 1), math.max(1, y))
    page.scroller.To(page.scroller.target, true)
end

-- ------------------------------------------------------ professions page
local prof = { key = "professions", label = "Professions", glyph = "profession", order = 1, flex = true,
    bandUsed = true, height = 120, used = {}, parts = {} }

-- A skill, half the block's width: its icon, its name (gold, a primary)
-- and its recipes' count on a line, its bar under them
local SKILL_ROW = 40
local function SkillRow(page)
    return Pool(page, "skill", function()
        local r = CreateFrame("Frame", nil, page.skills)
        r:SetHeight(SKILL_ROW - 4)
        r.edge, r.icon = Icon(r, 18)
        r.edge:SetPoint("TOPLEFT", 0, 0)
        r.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        r.name = ns.Text(r, 12)
        r.name:SetPoint("LEFT", r.edge, "RIGHT", 8, 0)
        r.count = ns.Text(r, 9)
        r.count:SetPoint("RIGHT", r, "TOPRIGHT", -2, -9)
        r.count:SetTextColor(unpack(ns.colors.dim))
        r.track = r:CreateTexture(nil, "BACKGROUND")
        r.track:SetHeight(14)
        r.track:SetPoint("TOPLEFT", 26, -21)
        r.track:SetPoint("TOPRIGHT", -2, -21)
        r.track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
        r.fill = r:CreateTexture(nil, "ARTWORK")
        r.fill:SetPoint("TOPLEFT", r.track)
        r.fill:SetPoint("BOTTOMLEFT", r.track)
        r.fill:SetColorTexture(0.61, 0.48, 0.20, 1)
        r.value = ns.Text(r, 9)
        r.value:SetPoint("CENTER", r.track)
        return r
    end)
end

local function RecipeRow(page)
    return Pool(page, "recipe", function()
        local r = CreateFrame("Button", nil, page.child)
        r:SetHeight(20)
        r.edge, r.icon = Icon(r, 18)
        r.edge:SetPoint("LEFT", 8, 0)
        r.name = ns.Text(r, 12)
        r.name:SetPoint("LEFT", r.edge, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -4, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        r:SetScript("OnEnter", function(self)
            local rec = self.recipe
            if not rec then return end
            ns.window.Outside(self)
            if rec.item then GameTooltip:SetItemByID(rec.item) else GameTooltip:SetText(rec.name) end
            GameTooltip:AddLine(self.prof or "", unpack(ns.colors.dim))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
end

-- The professions folded on the Professions page (remembered by name,
-- altRecipesFolded)
local function Folded()
    local f = type(ns.db.altRecipesFolded) == "table" and ns.db.altRecipesFolded or {}
    ns.db.altRecipesFolded = f
    return f
end

local function FoldRow(page)
    return Pool(page, "fold", function()
        local r = Banded(CreateFrame("Button", nil, page.child), true)
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        r:SetScript("OnClick", function(self)
            local f = Folded()
            f[self.prof] = not f[self.prof] or nil
            page.Refresh()
        end)
        return r
    end)
end

-- the recipes' orders: the list is kept by name
local SORTS = {
    { key = "name", label = "Name", tip = "By name." },
    { key = "quality", label = "Quality", tip = "What they make, the best first." },
    { key = "newest", label = "Newest", tip = "The latest the game added, first." },
}

local function Sorted(list, how)
    local out = {}
    for i, rec in ipairs(list) do out[i] = rec end
    if how == "quality" then
        local q = {}
        for _, rec in ipairs(out) do q[rec] = rec.item and select(3, Item(rec.item)) or -1 end
        table.sort(out, function(x, y)
            if q[x] ~= q[y] then return q[x] > q[y] end
            return x.name < y.name
        end)
    elseif how == "newest" then
        table.sort(out, function(x, y) return (x.id or 0) > (y.id or 0) end)
    end
    return out
end

-- the skills, two a row, primaries first (as recorded); the block's height
local function Skills(page, skills, recipes)
    -- (before the block is laid out, the window's width less its insets)
    local across = page.skills:GetWidth() or 0
    if across < 2 then across = (AW.window:GetWidth() or 0) - 2 * ns.window.pad end
    local half = math.floor((across - COLUMN_GAP) / 2)
    for i, s in ipairs(skills) do
        local r = SkillRow(page)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", col * (half + COLUMN_GAP), -(SKILLS_TOP + row * SKILL_ROW))
        r:SetWidth(math.max(1, half))
        r.icon:SetTexture(s.icon)
        r.name:SetText(s.name or "")
        r.name:SetTextColor(unpack(s.primary and GOLD or ns.colors.text))
        local max = math.max(1, s.max or 1)
        -- (the track: the column less the icon's room and the end's)
        r.fill:SetWidth(math.max(0.01, math.max(1, half - 28) * math.min(1, (s.rank or 0) / max)))
        r.value:SetText(format("%d / %d", s.rank or 0, s.max or 0))
        local known = recipes[s.name]
        r.count:SetText(known and format(#known == 1 and "%d recipe" or "%d recipes", #known) or "")
    end
    local none = Pool(page, "none", function()
        local t = ns.Text(page.skills, 11)
        t:SetPoint("TOPLEFT", 2, -SKILLS_TOP)
        t:SetTextColor(unpack(ns.colors.dim))
        t:SetText("No professions recorded.")
        return t
    end)
    none:SetShown(#skills == 0)
    local tall = SKILLS_TOP + math.max(1, math.ceil(#skills / 2)) * SKILL_ROW
    if #skills == 0 then tall = SKILLS_TOP + 24 end
    page.skills:SetHeight(tall)
    page.strip.At(tall)
end

function prof.Draw()
    local page, d = prof, Data()
    page.used = {}
    local skills = d.skills or {}
    local recipes = type(d.recipes) == "table" and d.recipes or {}
    Skills(page, skills, recipes)
    local width = Width(page)
    local y = 4
    -- the recipes under their professions' headings, the search's words in
    -- their names: a search opens every heading it finds recipes under
    local words, any, names = Words(page), false, {}
    local folded, how = Folded(), ns.db.altRecipesSort or "name"
    for _, o in ipairs(SORTS) do page.sort:Set(o.key, { selected = how == o.key }) end
    for name in pairs(recipes) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local found = {}
        for _, rec in ipairs(recipes[name]) do
            if words == "" or rec.name:lower():find(words, 1, true) then table.insert(found, rec) end
        end
        if #found > 0 then
            local shut = folded[name] and words == ""
            local h = FoldRow(page)
            h.prof = name
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h:SetWidth(width)
            h.sign:SetText(shut and "+" or "-")
            h.name:SetText(name)
            h.count:SetText(words == "" and format("(%d)", #found)
                or format("(%d of %d)", #found, #recipes[name]))
            y = y + FOLD + 2
            if not shut then
                for _, rec in ipairs(Sorted(found, how)) do
                    local r = RecipeRow(page)
                    r.recipe, r.prof = rec, name
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -y)
                    r:SetWidth(width)
                    r.icon:SetTexture(rec.icon)
                    local quality
                    if rec.item then quality = select(3, Item(rec.item)) end
                    local c = Quality(quality)
                    r.edge:SetColorTexture(c[1], c[2], c[3], 1)
                    r.name:SetText(rec.name)
                    r.name:SetTextColor(c[1], c[2], c[3])
                    y = y + 21
                end
                y = y + 4
            end
            any = true
        end
    end
    if not any then
        local t = Pool(page, "empty", function()
            local e = ns.Text(page.child, 11)
            e:SetTextColor(unpack(ns.colors.dim))
            return e
        end)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 8, -y)
        t:SetText(#names == 0 and format("Open the professions on %s to record its recipes.", shown.name)
            or "No recipe has those words.")
        y = y + 20
    end
    Spare(page)
    Fit(page, y + 4)
    local last
    for _, t in pairs(type(d.recipesSeen) == "table" and d.recipesSeen or {}) do last = math.max(last or 0, t) end
    page.note:SetText(last and ("Recipes recorded " .. Ago(last)) or "")
end

-- ----------------------------------------------------------- items page
local items = { key = "items", label = "Items", glyph = "view-groups", order = 2, flex = true,
    bandUsed = true, height = 120, used = {}, parts = {} }
local FILTERS = {
    { key = "all", label = "All" }, { key = "equipment", label = "Equipment" },
    { key = "consumable", label = "Consumables" }, { key = "trade", label = "Trade goods" },
    { key = "quest", label = "Quest" }, { key = "other", label = "Other" }, { key = "junk", label = "Junk" },
}

-- the items kept, with their counts in the bank and the bags, that the
-- filter and the search let through, by name
local function Kept(d)
    local filter, words = ns.db.altItemsFilter or "all", Words(items)
    local all = {}
    for _, where in ipairs({ "bank", "bags" }) do
        for id, n in pairs(type(d[where]) == "table" and d[where] or {}) do
            all[id] = all[id] or { id = id, bank = 0, bags = 0 }
            all[id][where] = n
        end
    end
    local out = {}
    for id, it in pairs(all) do
        it.name, it.icon, it.quality = Item(id)
        if (filter == "all" or ns.ItemGroup(id, it.quality) == filter)
            and (words == "" or it.name:lower():find(words, 1, true)) then
            table.insert(out, it)
        end
    end
    table.sort(out, function(x, y)
        if x.name ~= y.name then return x.name < y.name end
        return x.id < y.id
    end)
    return out
end

local function ItemTip(self)
    local it = self.it
    if not it then return end
    ns.window.Outside(self)
    GameTooltip:SetItemByID(it.id)
    GameTooltip:AddLine(format("Bank %d  \194\183  Bags %d", it.bank, it.bags), unpack(GOLD))
    GameTooltip:Show()
end

local function ListRow(page)
    return Pool(page, "row", function()
        local r = CreateFrame("Button", nil, page.child)
        r:SetHeight(22)
        r.edge, r.icon = Icon(r, 20)
        r.edge:SetPoint("LEFT", 4, 0)
        r.name = ns.Text(r, 12)
        r.name:SetPoint("LEFT", r.edge, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", -160, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.cols = {}
        for i, x in ipairs({ -110, -58, -4 }) do
            local t = ns.Text(r, 11)
            t:SetPoint("RIGHT", x, 0)
            r.cols[i] = t
        end
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        r:SetScript("OnEnter", ItemTip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
end

local function Slot(page)
    return Pool(page, "slot", function()
        local b = CreateFrame("Button", nil, page.child)
        b:SetSize(SLOT, SLOT)
        b.edge, b.icon = Icon(b, SLOT)
        b.edge:SetPoint("TOPLEFT")
        b.count = ns.Text(b, 11)
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        local glow = b:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.12)
        b:SetScript("OnEnter", ItemTip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end)
end

local function Dash(n) return n > 0 and tostring(n) or "\226\128\148" end

function items.Draw()
    local page, d = items, Data()
    page.used = {}
    local width = Width(page)
    local list = Kept(d)
    local y = 4
    local grid = ns.db.altItemsView == "grid"
    if grid then
        local across = math.max(1, math.floor((width - 8 + 4) / (SLOT + 4)))
        for _, where in ipairs({ { "bank", "Bank" }, { "bags", "Bags" } }) do
            local here = {}
            for _, it in ipairs(list) do if it[where[1]] > 0 then table.insert(here, it) end end
            y = Heading(page, where[2], format("(%d)", #here), y, width)
            for i, it in ipairs(here) do
                local b = Slot(page)
                b.it = it
                local c = Quality(it.quality)
                b.edge:SetColorTexture(c[1], c[2], c[3], 1)
                b.icon:SetTexture(it.icon)
                local n = it[where[1]]
                b.count:SetText(n > 1 and n or "")
                b:ClearAllPoints()
                local col, row = (i - 1) % across, math.floor((i - 1) / across)
                b:SetPoint("TOPLEFT", 6 + col * (SLOT + 4), -(y + row * (SLOT + 4)))
            end
            y = y + math.ceil(#here / across) * (SLOT + 4) + 8
        end
    else
        local head = Pool(page, "cols", function()
            local f = CreateFrame("Frame", nil, page.child)
            f:SetHeight(18)
            f.cols = {}
            for i, x in ipairs({ { -110, "Bank" }, { -58, "Bags" }, { -4, "All" } }) do
                local t = ns.Text(f, 10)
                t:SetPoint("RIGHT", x[1], 0)
                t:SetText(x[2])
                t:SetTextColor(unpack(ns.colors.dim))
                f.cols[i] = t
            end
            return f
        end)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head:SetWidth(width)
        y = y + 20
        for _, it in ipairs(list) do
            local r = ListRow(page)
            r.it = it
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetWidth(width)
            local c = Quality(it.quality)
            r.edge:SetColorTexture(c[1], c[2], c[3], 1)
            r.icon:SetTexture(it.icon)
            r.name:SetText(it.name)
            r.name:SetTextColor(c[1], c[2], c[3])
            r.cols[1]:SetText(Dash(it.bank))
            r.cols[2]:SetText(Dash(it.bags))
            r.cols[3]:SetText(it.bank + it.bags)
            r.cols[3]:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            y = y + 24
        end
    end
    if #list == 0 then
        local t = Pool(page, "empty", function()
            local e = ns.Text(page.child, 11)
            e:SetTextColor(unpack(ns.colors.dim))
            return e
        end)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 8, -y)
        t:SetText((d.bags or d.bank) and "Nothing here." or format("Log in on %s to record its items.", shown.name))
        y = y + 20
    end
    Spare(page)
    Fit(page, y + 4)
    local bank = Ago(d.bankSeen)
    local money = d.money and GetCoinTextureString and GetCoinTextureString(d.money) or nil
    page.note:SetText((bank and ("Bank seen " .. bank) or format("Visit the bank on %s to record it", shown.name))
        .. (money and ("   " .. money) or ""))
    page.filters:Fill(page.FilterItems())
    page.view:Set("list", { selected = not grid })
    page.view:Set("grid", { selected = grid })
end

function items.FilterItems()
    local out = {}
    for _, f in ipairs(FILTERS) do
        local on = (ns.db.altItemsFilter or "all") == f.key
        table.insert(out, { key = f.key, label = f.label, group = "f", selected = on,
            click = function()
                ns.db.altItemsFilter = f.key
                items.Refresh()
            end })
    end
    return out
end

-- ----------------------------------------------------------- notes page
local notes = { key = "notes", label = "Notes", glyph = "edit", order = 3, flex = true,
    bandUsed = true, height = 120, used = {}, parts = {} }

local function NotesFit()
    local box, s = notes.box, notes.scroller
    local width = math.max(1, s.scroll:GetWidth() or 1)
    notes.measure:SetWidth(math.max(1, width - 12))
    notes.measure:SetText(box:GetText() or "")
    local tall = math.max(s.scroll:GetHeight() or 0, (notes.measure:GetStringHeight() or 0) + 16, 1)
    s.child:SetSize(width, tall)
    box:SetSize(width, tall)
    s.To(s.target, true)
end

function notes.Draw()
    local d = Data()
    -- (while it is being typed in, what is shown is what is saved)
    if not notes.box:HasFocus() then notes.box:SetText(d.notes or "") end
    NotesFit()
    notes.note:SetText("Saved as you type")
end

-- the Characters page (drawn below)
local roster = { key = "roster", label = "Characters", glyph = "social", order = 0, flex = true,
    bandUsed = true, height = 120, used = {}, parts = {} }

local function Build(page)
    return function(body, _, band)
        Band(page, band)
        if page == notes then
            page.scroller = ns.window.Scroller(body, 10)
            local box = CreateFrame("EditBox", nil, page.scroller.child)
            box:SetMultiLine(true)
            box:SetAutoFocus(false)
            box:SetMaxLetters(0)
            box:SetFontObject(ChatFontNormal)
            box:SetTextColor(1, 1, 1)
            box:SetTextInsets(6, 6, 6, 6)
            box:SetPoint("TOPLEFT")
            box:SetScript("OnEscapePressed", box.ClearFocus)
            box:SetScript("OnTextChanged", function(self, user)
                if user and shown then
                    local d = shown.me and ns.alts.Me() or ns.alts.Data(shown.name)
                    if d then d.notes = self:GetText() end
                end
                NotesFit()
            end)
            -- the caret: drawn here, as the game shows none in the pad; it
            -- blinks while the pad has focus, steady for a moment after a move.
            -- The game gives the cursor from the text's corner, inside the
            -- insets, and the line's height (the font's size is the letters')
            local INSET = 6
            local caret = box:CreateTexture(nil, "OVERLAY")
            caret:SetColorTexture(1, 1, 1, 0.9)
            caret:SetSize(1, ChatFontNormal and select(2, ChatFontNormal:GetFont()) or 14)
            caret:SetPoint("TOPLEFT", INSET, -INSET)
            caret:Hide()
            local blink = 0
            local function Blink(_, elapsed)
                blink = blink + elapsed
                caret:SetShown(blink % 1 < 0.5)
            end
            box:SetScript("OnEditFocusGained", function()
                blink = 0
                caret:Show()
                box:SetScript("OnUpdate", Blink)
            end)
            box:SetScript("OnEditFocusLost", function()
                box:SetScript("OnUpdate", nil)
                caret:Hide()
            end)
            local atX, atY
            box:SetScript("OnCursorChanged", function(_, x, y, _, h)
                -- (it fires as the pad resizes too: only a move restarts the blink)
                if x ~= atX or y ~= atY then
                    atX, atY = x, y
                    caret:SetPoint("TOPLEFT", INSET + x, y - INSET)
                    blink = 0
                    if box:HasFocus() then caret:Show() end
                end
                local s, view = page.scroller, page.scroller.scroll:GetHeight() or 0
                if -y < s.target then s.To(-y, true) elseif -y + h > s.target + view then s.To(-y + h - view, true) end
            end)
            -- a click anywhere on the pad starts typing
            body:EnableMouse(true)
            body:SetScript("OnMouseDown", function() box:SetFocus() end)
            page.box, page.caret = box, caret
            page.measure = page.scroller.child:CreateFontString(nil, "ARTWORK")
            page.measure:SetFontObject(ChatFontNormal)
            page.measure:SetJustifyH("LEFT")
            page.measure:SetWordWrap(true)
            page.measure:SetNonSpaceWrap(true)
            page.measure:Hide()
            return
        end
        local strip
        if page == roster then
            strip = ns.window.Strip(body, TOOLBAR, 0)
            local title = ns.Text(strip, 13)
            title:SetPoint("LEFT", 12, 0)
            title:SetTextColor(unpack(GOLD))
            title:SetText("Characters")
            page.realm = ns.Text(strip, 10)
            page.realm:SetPoint("RIGHT", -12, 0)
            page.realm:SetTextColor(unpack(ns.colors.dim))
            page.realm:SetText("Realm: " .. Realm())
        elseif page == items then
            -- the filters across the first strip; the search and the view
            -- in the second
            local first = ns.window.Strip(body, TOOLBAR, 0)
            page.filters = ns.window.Segments(first, { height = TOOLBAR - 2, fit = true, size = 11, soft = "open",
                items = page.FilterItems() })
            page.filters:SetPoint("LEFT", 4, 0)
            strip = ns.window.Strip(body, TOOLBAR, TOOLBAR - 1)
            page.view = ns.window.Segments(strip, { height = TOOLBAR - 2, fit = true, soft = "open", items = {
                { key = "list", label = "List", icon = "view-groups", group = "v",
                    tip = function() return "A line an item." end, click = function()
                        ns.db.altItemsView = "list"
                        page.Refresh()
                    end },
                { key = "grid", label = "Grid", icon = "view-grid", group = "v",
                    tip = function() return "Slots, bank and bags." end, click = function()
                        ns.db.altItemsView = "grid"
                        page.Refresh()
                    end },
            } })
            page.view:SetPoint("RIGHT", 0, 0)
            local s = Search(page, strip, "MedalluinAltItemsSearch", "Search its items")
            s:SetPoint("LEFT", 12, 0)
            s:SetPoint("RIGHT", page.view, "LEFT", -10, 0)
        else
            -- the skills over the recipes' strip: its name, its search and
            -- its sorts, over the professions' headings
            page.skills = CreateFrame("Frame", nil, body)
            page.skills:SetPoint("TOPLEFT", 0, 0)
            page.skills:SetPoint("TOPRIGHT", 0, 0)
            page.skills:SetHeight(1)
            strip = ns.window.Strip(body, TOOLBAR, 0)
            page.strip = strip
            local title = ns.Text(strip, 13)
            title:SetPoint("LEFT", 12, 0)
            title:SetTextColor(unpack(GOLD))
            title:SetText("Recipes")
            local bar = strip:CreateTexture(nil, "BORDER")
            bar:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
            bar:SetSize(1, TOOLBAR - 12)
            bar:SetPoint("LEFT", title, "RIGHT", 10, 0)
            local sorts = {}
            for _, o in ipairs(SORTS) do
                table.insert(sorts, { key = o.key, label = o.label, group = "s",
                    selected = (ns.db.altRecipesSort or "name") == o.key,
                    tip = function() return o.tip end, click = function()
                        ns.db.altRecipesSort = o.key
                        page.Refresh()
                    end })
            end
            page.sort = ns.window.Segments(strip, { height = TOOLBAR - 2, fit = true, size = 11, soft = "open",
                items = sorts })
            page.sort:SetPoint("RIGHT", 0, 0)
            local s = Search(page, strip, "MedalluinAltRecipesSearch", "Search its recipes")
            s:SetPoint("LEFT", bar, "RIGHT", 10, 0)
            s:SetPoint("RIGHT", page.sort, "LEFT", -10, 0)
        end
        -- the list under the strip, edge to edge as it is
        local holder = CreateFrame("Frame", nil, body)
        holder:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
        holder:SetPoint("BOTTOMRIGHT", ns.window.pad - 1, 0)
        page.scroller = ns.window.Scroller(holder, 10)
        page.child = page.scroller.child
        holder:EnableMouseWheel(true)
        holder:SetScript("OnMouseWheel", function(_, delta) page.scroller.To(page.scroller.target - delta * 60) end)
    end
end

-- ------------------------------------------------------- characters page
local CHAR_ROW, RING = 42, 24

local function CharRow(page)
    return Pool(page, "char", function()
        local r = CreateFrame("Button", nil, page.child)
        r:SetHeight(CHAR_ROW - 2)
        r.mark = r:CreateTexture(nil, "BACKGROUND")
        r.mark:SetAllPoints()
        r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
        r.edge = r:CreateTexture(nil, "BORDER")
        r.edge:SetPoint("TOPLEFT")
        r.edge:SetPoint("BOTTOMLEFT")
        r.edge:SetWidth(3)
        r.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        r.line = r:CreateTexture(nil, "BORDER")
        r.line:SetPoint("BOTTOMLEFT", 10, -1)
        r.line:SetPoint("BOTTOMRIGHT", -10, -1)
        r.line:SetHeight(1)
        r.line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        r.class = r:CreateTexture(nil, "ARTWORK")
        r.class:SetSize(RING, RING)
        r.class:SetPoint("LEFT", 12, 0)
        r.name = ns.Text(r, 13)
        r.name:SetPoint("TOPLEFT", 12 + RING + 10, -5)
        r.what = ns.Text(r, 10)
        r.what:SetPoint("BOTTOMLEFT", 12 + RING + 10, 5)
        r.what:SetTextColor(unpack(ns.colors.dim))
        r.profs = ns.Text(r, 11)
        r.profs:SetPoint("TOPLEFT", 170, -5)
        r.seen = ns.Text(r, 10)
        r.seen:SetPoint("BOTTOMLEFT", 170, 5)
        r.seen:SetTextColor(unpack(ns.colors.dim))
        r.cd = ns.Text(r, 10)
        r.cd:SetPoint("RIGHT", -12, 0)
        r.cd:SetTextColor(unpack(GOLD))
        r:SetScript("OnClick", function(self) if self.alt then W.ShowAlt(self.alt, prof) end end)
        r:SetScript("OnEnter", function(self)
            local alt = self.alt
            if not alt then return end
            ns.window.Outside(self)
            GameTooltip:SetText(alt.name, unpack(Color(alt.e.class)))
            for _, p in ipairs(alt.e.primaries or {}) do
                GameTooltip:AddDoubleLine(p.name or "?", format("%d / %d", p.rank or 0, p.max or 0), 1, 1, 1, 1, 1, 1)
            end
            for _, c in ipairs(self.cooldowns or {}) do
                local left, ready = ns.alts.Left(c.ready)
                GameTooltip:AddDoubleLine(c.name or "?", left, 1, 1, 1, unpack(ready and { 0.25, 0.85, 0.35 } or GOLD))
            end
            GameTooltip:AddLine("Click: its professions, items and notes.", unpack(ns.colors.dim))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
end

-- the playing character first, then the others, most recently played first
local function Characters()
    local list = {}
    local me = UnitName("player")
    if me and not ns.IsSecret(me) then
        Record()
        table.insert(list, { name = me, e = Roster()[me] or {}, me = true })
    end
    for _, a in ipairs(W.Alts()) do table.insert(list, a) end
    return list
end

function roster.Draw()
    local page = roster
    page.used = {}
    local width = Width(page)
    local list = Characters()
    local cooldowns = {}
    for _, c in ipairs(ns.alts.Cooldowns()) do
        cooldowns[c.who] = cooldowns[c.who] or {}
        table.insert(cooldowns[c.who], c)
    end
    local y = 2
    for _, alt in ipairs(list) do
        local r = CharRow(page)
        r.alt, r.cooldowns = alt, cooldowns[alt.name]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetWidth(width)
        ClassIcon(r.class, alt.e.class)
        r.name:SetText(alt.name)
        r.name:SetTextColor(unpack(Color(alt.e.class)))
        r.what:SetText(format("Level %d %s", alt.e.level or 0, alt.e.className or ""))
        local names = {}
        for _, p in ipairs(alt.e.primaries or {}) do table.insert(names, p.name or "?") end
        r.profs:SetText(#names > 0 and table.concat(names, "  ") or "No professions")
        r.profs:SetTextColor(unpack(#names > 0 and ns.colors.text or ns.colors.dim))
        r.seen:SetText(alt.me and "playing now" or Ago(alt.e.seen) or "")
        local c = r.cooldowns and r.cooldowns[1]
        r.cd:SetText(c and ((c.name or "?") .. "  " .. ns.alts.Left(c.ready)) or "")
        local on = shown and shown.name == alt.name
        r.mark:SetShown(on)
        r.edge:SetShown(on)
        y = y + CHAR_ROW
    end
    Spare(page)
    Fit(page, y + 4)
    page.note:SetText(format(#list == 1 and "%d character" or "%d characters", #list))
end

for _, page in ipairs({ roster, prof, items, notes }) do
    page.Available = function() return true end
    page.Build = Build(page)
    page.Refresh = function()
        if not (shown and page.who and AW and AW.window:IsShown()) then return end
        Who(page)
        page.Draw()
    end
    table.insert(pages, page)
end

local function Window()
    if AW then return AW end
    AW = ns.Window{
        name = "MedalluinAlt", side = 1, place = "altPlace", detachedOnly = true,
        closeTip = "Close.",
        Close = function() AW.SetShown(false) end,
        Lifted = function() return {} end,
    }
    for _, page in ipairs(pages) do AW.Page(page) end
    AW.Build()
    AW.window:HookScript("OnSizeChanged", function()
        local p = AW.Current()
        if p and p.Refresh then p.Refresh() end
    end)
    -- an item's data come in: the page drawn again at the next frame
    ns.On("GET_ITEM_INFO_RECEIVED", function() dirty = true end)
    AW.window:HookScript("OnUpdate", function()
        if not dirty then return end
        dirty = false
        local p = AW.Current()
        if p and p ~= notes and p.Refresh then p.Refresh() end
    end)
    ns.professions.altWindow, ns.professions.altPages = AW, pages     -- (the harness reads them)
    return AW
end

-- A character's window, open on it; the same one again closes it. alt:
-- { name, e (its roster entry), me (the playing character) }.
function W.OpenAlt(alt)
    local w = Window()
    local same = shown and shown.name == alt.name and w.window:IsShown()
    shown = alt
    if not w.Current() then w.Select(prof) end
    w.SetShown(not same)
    local p = w.Current()
    if p and p.Refresh then p.Refresh() end
end

-- A character's window, open on it (never closed by it), on page (or the
-- page it is on): the Characters tab's click.
function W.ShowAlt(alt, page)
    local w = Window()
    shown = alt
    w.Select(page or w.Current() or prof)
    w.SetShown(true)
    local p = w.Current()
    if p and p.Refresh then p.Refresh() end
end

-- the Characters tab, the playing character shown (the banner's Alts)
function W.OpenRoster()
    local name = UnitName("player")
    if not name or ns.IsSecret(name) then return end
    Record()
    W.ShowAlt({ name = name, e = Roster()[name] or {}, me = true }, roster)
end

-- the playing character's own window (the banner's click)
function W.OpenMine()
    local name = UnitName("player")
    if not name or ns.IsSecret(name) then return end
    Record()
    W.OpenAlt({ name = name, e = Roster()[name] or {}, me = true })
end

-- ---------------------------------------------------------- the banner
-- A strip darkening to warm at its foot, a gold rule under it, the name
-- and the rest centred, and the portrait in its ring on the rule.
function W.Banner(body)
    local b = CreateFrame("Frame", nil, body)
    b:SetHeight(BANNER)
    b.ground = b:CreateTexture(nil, "BACKGROUND")
    b.ground:SetPoint("TOPLEFT")
    b.ground:SetPoint("TOPRIGHT")
    b.ground:SetHeight(STRIP)
    local ink = ns.colors.ink
    if b.ground.SetGradient and CreateColor then
        b.ground:SetColorTexture(1, 1, 1, 1)
        b.ground:SetGradient("VERTICAL", CreateColor(0.16, 0.13, 0.086, 1), CreateColor(ink[1], ink[2], ink[3], 1))
    else
        b.ground:SetColorTexture(ink[1], ink[2], ink[3], 1)
    end
    b.rule = b:CreateTexture(nil, "BORDER")
    b.rule:SetPoint("TOPLEFT", 0, -STRIP)
    b.rule:SetPoint("TOPRIGHT", 0, -STRIP)
    b.rule:SetHeight(2)
    b.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    b.shine = b:CreateTexture(nil, "BORDER", nil, 1)
    b.shine:SetPoint("TOPLEFT", b.rule)
    b.shine:SetPoint("TOPRIGHT", b.rule)
    b.shine:SetHeight(1)
    b.shine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
    b.portrait = ns.window.Ring(b, PORTRAIT)
    b.portrait:SetTexCoord(0, 1, 0, 1)
    b.portrait:SetPoint("CENTER", b, "TOP", 0, -(STRIP + 1))
    b.name = ns.Text(b, 16)
    b.name:SetPoint("TOP", 0, -8)
    b.levelText = ns.Text(b, 13)
    b.levelText:SetPoint("TOPRIGHT", -8, -10)
    b.levelText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b.what = ns.Text(b, 12)
    b.what:SetPoint("TOP", b.name, "BOTTOM", 0, -6)
    b.what:SetTextColor(unpack(ns.colors.dim))
    -- the alts: counted, named in its tooltip; a click, the Characters tab
    b.alts = ns.window.Button(b, 74, function() W.OpenRoster() end, function()
        local names = {}
        for _, a in ipairs(W.Alts()) do table.insert(names, a.name) end
        return "Your alts: " .. table.concat(names, ", ") .. ".\nClick: every character, its professions, "
            .. "items and notes."
    end)
    b.alts:SetHeight(22)
    b.alts:SetPoint("TOPLEFT", 8, -6)
    b.alts.glyph = b.alts:CreateTexture(nil, "ARTWORK")
    b.alts.glyph:SetSize(14, 14)
    b.alts.glyph:SetPoint("LEFT", 8, 0)
    b.alts.glyph:SetTexture(ns.media .. "strips\\social")
    b.alts.label:ClearAllPoints()
    b.alts.label:SetPoint("LEFT", b.alts.glyph, "RIGHT", 6, 0)
    b.alts.label:SetTextColor(unpack(GOLD))
    -- a click opens the playing character's own window (its notes, items)
    b:EnableMouse(true)
    b:SetScript("OnMouseUp", function(_, mouse) if mouse == "LeftButton" then W.OpenMine() end end)
    b:SetScript("OnEnter", function(self)
        W.Beside(self)
        GameTooltip:SetText(UnitName("player") or "", unpack(Color(select(2, UnitClass("player")))))
        GameTooltip:AddLine("Click: your window (professions, items, notes).", unpack(ns.colors.dim))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b.Refresh()
        SetPortraitTexture(b.portrait, "player")
        local className, class = UnitClass("player")
        b.name:SetText(UnitName("player") or "")
        b.name:SetTextColor(unpack(Color(class)))
        b.levelText:SetText(format("Level %d", UnitLevel("player") or 0))
        local race = UnitRace and UnitRace("player")
        local guild = GetGuildInfo and GetGuildInfo("player")
        local what = (race and (race .. " ") or "") .. (className or "")
        b.what:SetText(guild and guild ~= "" and format("%s  ·  <%s>", what, guild) or what)
        local n = #W.Alts()
        b.alts:SetShown(n > 0)
        b.alts.label:SetText(format("Alts  %d", n))
    end
    return b
end
