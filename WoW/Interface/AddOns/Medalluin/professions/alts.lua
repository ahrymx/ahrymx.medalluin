-- The Overview's head (professions/window.lua puts it over the cards): the
-- character's banner, and under it a slim row for each of the realm's
-- other characters, its alts, with its class and its primary professions.
--
--                               Ahrymx                       Level 60
--                       Human Warrior  ·  <Guild>
--   ============================(portrait)===========================
--   ----------------------------- Alts -----------------------------
--   [class] Medalluin    Priest            [icon] Tailoring [icon] Enchanting
--   .................................................................
--   [class] Barkhide     Druid             [icon] Herbalism [icon] Alchemy
--
-- The alts are what each character recorded of itself when it last
-- played (MedalluinDB.roster[realm][name]: class, level, primaries), so a
-- character appears once it has logged in with Medalluin; the realm's
-- most recently played first, MOST at most. An alt's row opens its window
-- (the alt's own, detached: MedalluinDB.altPlace), empty for now.
local _, ns = ...

local W = ns.professions
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local STRIP, PORTRAIT, ALT, CLASS, PROF = 64, 40, 24, 18, 16
-- the header: its strip, and the portrait hanging half below its rule
local BANNER = STRIP + PORTRAIT / 2 + 2
local MOST = 8                          -- the alts listed, at most
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
-- An alt's own window: detached, one page, nothing on it yet.
local AW, altPage
local function Window()
    if AW then return AW end
    AW = ns.Window{
        name = "MedalluinAlt", side = 1, place = "altPlace", detachedOnly = true,
        closeTip = "Close.",
        Close = function() AW.SetShown(false) end,
        Lifted = function() return {} end,
    }
    altPage = { key = "alt", label = "", glyph = "character", order = 1, flex = true, bandUsed = true, height = 80,
        Available = function() return true end,
        Build = function(_, _, band)
            altPage.name = ns.Text(band, 13)
            altPage.name:SetPoint("LEFT", 4, 0)
        end,
        Refresh = function()
            local alt = altPage.alt
            altPage.name:SetText(alt and alt.name or "")
            altPage.name:SetTextColor(unpack(Color(alt and alt.e.class)))
        end }
    AW.Page(altPage)
    AW.Build()
    ns.professions.altWindow = AW
    return AW
end

-- the alt's window, open on it; the same alt again closes it
function W.OpenAlt(alt)
    local w = Window()
    local same = altPage.alt and altPage.alt.name == alt.name and w.window:IsShown()
    altPage.alt, altPage.label = alt, alt.name
    if not w.Current() then w.Select(altPage) end
    w.SetShown(not same)
    altPage.Refresh()
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
    end
    return b
end

-- ------------------------------------------------------------ the alts
function W.AltRows(body)
    local a = CreateFrame("Frame", nil, body)
    a.rows = {}
    local function Row(i)
        local r = a.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, a)
        r:SetHeight(ALT)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * (ALT + 2))
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * (ALT + 2))
        local glow = r:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        if i > 1 then
            r.hair = ns.window.Hair(r, false, 0.6)
            r.hair:SetPoint("TOPLEFT", 20, 1)
            r.hair:SetPoint("TOPRIGHT", -20, 1)
        end
        r.class = r:CreateTexture(nil, "ARTWORK")
        r.class:SetSize(CLASS, CLASS)
        r.class:SetPoint("LEFT", 4, 0)
        r.name = ns.Text(r, 12)
        r.name:SetPoint("LEFT", r.class, "RIGHT", 6, 0)
        r.what = ns.Text(r, 11)
        r.what:SetPoint("LEFT", 140, 0)
        r.what:SetTextColor(unpack(ns.colors.dim))
        r.profs = {}
        for k = 2, 1, -1 do
            local p = {}
            p.label = ns.Text(r, 11)
            p.icon = r:CreateTexture(nil, "ARTWORK")
            p.icon:SetSize(PROF, PROF)
            p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            p.icon:SetPoint("RIGHT", p.label, "LEFT", -4, 0)
            r.profs[k] = p
        end
        r.profs[2].label:SetPoint("RIGHT", -6, 0)
        r.profs[1].label:SetPoint("RIGHT", r.profs[2].icon, "LEFT", -10, 0)
        r:SetScript("OnClick", function(self) if self.alt then W.OpenAlt(self.alt) end end)
        r:SetScript("OnEnter", function(self)
            local alt = self.alt
            if not alt then return end
            W.Beside(self)
            GameTooltip:SetText(alt.name, unpack(Color(alt.e.class)))
            GameTooltip:AddLine(format("Level %d %s", alt.e.level or 0, alt.e.className or ""), 1, 1, 1)
            for _, p in ipairs(alt.e.primaries or {}) do
                GameTooltip:AddDoubleLine(p.name or "?", format("%d / %d", p.rank or 0, p.max or 0), 1, 1, 1, 1, 1, 1)
            end
            GameTooltip:AddLine("Click: its window.", unpack(ns.colors.dim))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        a.rows[i] = r
        return r
    end
    -- the rows; the height they take (0: no alts)
    function a.Refresh()
        local alts = W.Alts()
        local n = math.min(#alts, MOST)
        for i = 1, n do
            local r, alt = Row(i), alts[i]
            r.alt = alt
            ClassIcon(r.class, alt.e.class)
            r.name:SetText(alt.name)
            r.name:SetTextColor(unpack(Color(alt.e.class)))
            r.what:SetText(alt.e.className or "")
            local primaries = alt.e.primaries or {}
            -- the first primary leftmost: with one, it takes the right slot
            for k, p in ipairs(r.profs) do
                local prof = #primaries == 2 and primaries[k] or (k == 2 and primaries[1]) or nil
                p.icon:SetShown(prof ~= nil)
                p.label:SetShown(prof ~= nil)
                if prof then
                    p.icon:SetTexture(prof.icon)
                    p.label:SetText(prof.name or "")
                end
            end
            if #primaries == 0 then
                r.profs[2].label:SetShown(true)
                r.profs[2].label:SetText("No professions")
                r.profs[2].label:SetTextColor(unpack(ns.colors.dim))
            else
                r.profs[2].label:SetTextColor(unpack(ns.colors.text))
            end
            r.profs[1].label:SetTextColor(unpack(ns.colors.text))
            r:Show()
        end
        for i = n + 1, #a.rows do a.rows[i]:Hide() end
        local height = n > 0 and n * (ALT + 2) - 2 or 0
        a:SetHeight(math.max(1, height))
        return height
    end
    return a
end
