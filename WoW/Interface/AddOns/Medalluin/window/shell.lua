-- The shell of Medalluin's own full-height windows: the character window
-- on the left strip, the spellbook, talents and professions on the right.
-- In the console's ink and gold, standing on its strip over the side
-- panel's place, from the screen's edge to its top.
--
--   [  @  ][  @  ][  @  ][  @  ][  @  ][  @  ]               [v] [x]
--   ---------------------------------------------------------------
--   the page
--   ---------------------------------------------------------------
--   the page's details                     <- the chevron folds these
--   ---------------------------------------------------------------
--   (medallion)  the page's band           <- the margin
--
-- (On the right the medallion is at the band's right end.) The strip's
-- medallion stands up out of the strip into the window's bottom margin: it
-- is drawn over the window while the window is open (its buttons lifted to
-- the window's strata, the medallion's art copied over them), and the
-- margin's rule runs above it, so it covers nothing. A page may put a row
-- of its own in the margin beside the medallion (the Character page's
-- shortcuts); the others have a divider there.
--
-- The tabs are icons spread across the row, with the page's name in a
-- tooltip (tip, or the label): the glyph art/strips draws for the page
-- (named by its key, or glyph), or the game's own icon (icon). The chevron
-- and the cross are glyphs of the same set. A window whose pages come and
-- go (a pet's spells, a profession learned) asks for Retab, and the row is
-- shared out again.
--
--   local w = ns.Window{ name, side (-1 left, 1 right), detailsKey,
--                        closeTip, Close(), Open(page) (ask Blizzard),
--                        Lifted() -> the medallion's buttons }
--   w.Page{ key, label, tip, glyph, icon, frame (Blizzard's page), order,
--           Available() (or Blizzard's frame exists), height, footHeight,
--           flex, bandUsed, events = { ... }, Build(body, foot, band),
--           Fit(height), Refresh(), OnEvent(event, ...), Shown(),
--           Showing(on) }
--   w.Build(), w.Select(page), w.ByFrame(name), w.Retab(), w.SetShown(on)
--
-- Build draws into body (the page), foot (its details) and, when the page
-- says bandUsed, the margin beside the medallion; Refresh redraws
-- both, at the next frame after the page shows or one of its events comes,
-- and only while the window is open. OnEvent (optional) hears the event
-- itself first, for what only one event changes; Shown (optional) is told
-- each time the page comes into sight: the window opening on it, or its
-- tab, and Showing (optional) each time the window opens or closes on it or
-- its tab is taken or left. height is the least a fixed page needs, and Fit (optional) is told
-- the height it has, which is the screen's; a page with flex is a list,
-- which takes the same (see Layout).
local _, ns = ...

local L, ART = ns.stripLayout, ns.stripArt
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local WIDTH = L.chatLeft + L.chatWidth          -- from the screen's edge to the chat panel's far edge
local PAD, TAB, RULE = 8, 28, 6                 -- the edge, the tab row, the gap round a rule
local GLYPH, CONTROL = 20, 16                   -- a tab's glyph, the chevron's and the cross's
local TOP = PAD + TAB + RULE                    -- the page's top
local MEDALLION = L.chatLeft                    -- the medallion's width: the strip's art left of the chat
local OVER = ART.height - L.stripHeight         -- how far the medallion stands above the strip
local BAND = OVER + 4                           -- the margin, up to its rule
local BOTTOM = BAND + RULE                      -- the page's (or its details') foot
local LIFT = 20                                 -- the medallion's buttons' level over the window's
local GAME_ICON = 0.08                          -- the game's icons' border, trimmed

ns.window = { width = WIDTH - 2 * PAD, pad = PAD, band = BAND }

-- ------------------------------------------------------------ buttons
-- As the bags window's: a gold edge, an ink well, a white glow under the
-- mouse; one of a set marked when it is in use. Drawn on b, over b or over
-- another region to (a chat tab's slim box inside its taller frame).
local function Face(b, to)
    to = to or b
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints(to)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    b.mark = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.mark:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    b.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    b.mark:Hide()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.12)
end
ns.window.Face = Face           -- the chat's tabs wear it too (strips/chat.lua)

local function Button(parent, width, click, tip, template)
    local b = CreateFrame("Button", nil, parent, template)
    b:SetSize(width, TAB)
    Face(b)
    b.label = ns.Text(b, 12)
    b.label:SetPoint("CENTER")
    if click then b:SetScript("OnClick", click) end
    b:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_TOP", { title = tip(), color = ns.colors.white, wrap = true })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
ns.window.Button = Button

-- ---------------------------------------------------------- decoration
-- A divider: a gold rule each side of a diamond, or of a word.
local function Ornament(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(12)
    local mid
    if label then
        mid = ns.Text(f, 11)
        mid:SetText(label)
        mid:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        mid = f:CreateTexture(nil, "ARTWORK")
        mid:SetSize(6, 6)
        mid:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        mid:SetRotation(math.pi / 4)
    end
    mid:SetPoint("CENTER")
    for _, side in ipairs({ -1, 1 }) do
        local rule = f:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(side < 0 and "LEFT" or "RIGHT")
        rule:SetPoint(side < 0 and "RIGHT" or "LEFT", mid, side < 0 and "LEFT" or "RIGHT", side * 8, 0)
    end
    f.mid = mid
    return f
end
ns.window.Ornament = Ornament

-- Gold brackets in a frame's four corners, inset from its edge.
local function Corners(f, inset, size)
    for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 },
        { "BOTTOMRIGHT", -1, 1 } }) do
        local across = f:CreateTexture(nil, "ARTWORK")
        across:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        across:SetSize(size, 1)
        across:SetPoint(c[1], c[2] * inset, c[3] * inset)
        local down = f:CreateTexture(nil, "ARTWORK")
        down:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        down:SetSize(1, size)
        down:SetPoint(c[1], c[2] * inset, c[3] * inset)
    end
end
ns.window.Corners = Corners

-- The chat box's frame, and the quest tracker's when there is no chat box
-- (strips/chat.lua, quests/tracker.lua): the windows' gold trim and
-- corners, the ink fading from solid at the left to a tenth at the right
-- so it can stand open over the world (the trim drawn as four lines, so
-- nothing shows through it), and the medallion's margin under its rule:
-- band high (the windows' own when not given).
local FADE = { 1, 0.10 }
local function Dress(parent, band)
    local dress = CreateFrame("Frame", nil, parent)
    dress:SetAllPoints()
    dress:SetFrameLevel(parent:GetFrameLevel())
    local tint = ns.colors.ink
    local ink = dress:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    if ink.SetGradient and CreateColor then
        ink:SetColorTexture(1, 1, 1, 1)
        ink:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], FADE[1]),
            CreateColor(tint[1], tint[2], tint[3], FADE[2]))
    else
        ink:SetColorTexture(tint[1], tint[2], tint[3], (FADE[1] + FADE[2]) / 2)
    end
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" } }) do
        local t = dress:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        t[edge[3]](t, 1)
    end
    Corners(dress, 3, 12)
    local bandRule = dress:CreateTexture(nil, "ARTWORK")
    bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    bandRule:SetHeight(1)
    bandRule:SetPoint("BOTTOMLEFT", PAD, band or BAND)
    bandRule:SetPoint("BOTTOMRIGHT", -PAD, band or BAND)
    dress.ink, dress.rule = ink, bandRule
    return dress
end
ns.window.Dress = Dress

-- a control's glyph, centred in its button
local function Glyph(b, name)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(CONTROL, CONTROL)
    b.icon:SetPoint("CENTER")
    if name then b.icon:SetTexture(ns.media .. "strips\\" .. name) end
end

-- the medallion's corner, the band's inner and outer ends: on the left the
-- medallion is at the window's left, on the right at its right
local function Outer(side, point) return side < 0 and point .. "LEFT" or point .. "RIGHT" end

-- ---------------------------------------------------------------- a window
function ns.Window(spec)
    local side = spec.side
    local pages = {}
    local w = { pages = pages, width = WIDTH - 2 * PAD, side = side,
        band = { left = side < 0 and MEDALLION + PAD or PAD, right = side < 0 and PAD or MEDALLION + PAD,
            height = BAND } }
    local window, chevron, close, footRule, medal
    local current, dirty
    local tabs = {}
    local listener = CreateFrame("Frame")
    w.listener = listener

    function w.Page(page)
        table.insert(pages, page)
    end

    local function Details() return ns.db[spec.detailsKey] and true or false end

    -- -------------------------------------------------------- medallion
    -- The medallion's buttons lifted to the window's strata while the
    -- window is open, under a copy of the medallion's art; put back when
    -- it closes. The copy fades with the strip.
    local function Lift(on)
        local strip = ns.strips[side]
        for i, f in ipairs(spec.Lifted()) do
            if not (f:IsProtected() and InCombatLockdown()) then
                if on then
                    f:SetFrameStrata(window:GetFrameStrata())
                    f:SetFrameLevel(window:GetFrameLevel() + LIFT + i - 1)
                else
                    f:SetFrameStrata(strip:GetFrameStrata())
                    f:SetFrameLevel(ns.levels.stripWell + i - 1)
                end
            end
        end
    end

    local function Medal()
        medal = CreateFrame("Frame", nil, window)
        medal:SetFrameLevel(window:GetFrameLevel() + LIFT + 2)
        medal:SetIgnoreParentAlpha(true)
        medal:SetSize(MEDALLION, ART.height)
        medal:SetPoint(Outer(side, "BOTTOM"), window, Outer(side, "BOTTOM"), 0, -L.stripHeight)
        local art = medal:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints()
        art:SetTexture(ns.media .. "strip")
        -- the right strip's art is the left's, mirrored
        local u, v = MEDALLION / ART.texWidth, ART.height / ART.texHeight
        if side < 0 then art:SetTexCoord(0, u, 0, v) else art:SetTexCoord(u, 0, 0, v) end
        window.medal = medal
    end

    -- ----------------------------------------------------------- layout
    -- How tall the window is: the screen above the strip.
    local function Room()
        local strip = ns.strips[side]
        local scale = strip:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return UIParent:GetHeight() / scale - L.stripHeight
    end

    -- What a page's details take, rule and all, with them open.
    local function Foot(page, details)
        if not (details and page.footHeight and page.footHeight > 0) then return 0 end
        return page.footHeight + 2 * RULE + 1
    end

    -- The window runs to the screen's top, on every page, so it keeps its
    -- height from tab to tab; a fixed page spreads out over it (Fit), a list
    -- fills it. On a screen too short for the tallest fixed page, that page
    -- runs off the top, and a list gives up height to fit.
    local function Layout()
        if not current then return end
        local details = Details()
        local least = 0
        for _, p in ipairs(pages) do
            if p.available and not p.flex then least = math.max(least, p.height + Foot(p, details)) end
        end
        local foot = Foot(current, details)
        local room = Room()
        local total = math.max(TOP + least + BOTTOM, room)
        if current.flex then total = math.max(TOP + 80 + foot + BOTTOM, math.min(total, room)) end
        local height = total - TOP - foot - BOTTOM
        current.body:SetHeight(height)
        if current.Fit then current.Fit(height) end
        local shown = foot > 0
        current.foot:SetShown(shown)
        footRule:SetShown(shown)
        if shown then
            footRule:ClearAllPoints()
            footRule:SetPoint("TOPLEFT", PAD, -(TOP + height + RULE))
            footRule:SetPoint("TOPRIGHT", -PAD, -(TOP + height + RULE))
            current.foot:SetHeight(current.footHeight)
        end
        window:SetHeight(total)
        chevron.icon:SetTexture(ns.media .. "strips\\" .. (details and "chevron-down" or "chevron-up"))
        dirty = true            -- a list's rows follow its height
    end

    -- ------------------------------------------------------------ pages
    local function Listen()
        listener:UnregisterAllEvents()
        if not (window:IsShown() and current) then return end
        for _, e in ipairs(current.events or {}) do
            if e:match("^UNIT_") then
                ns.RegisterUnitEvent(listener, e, "player")
            else
                pcall(listener.RegisterEvent, listener, e)
            end
        end
    end
    listener:SetScript("OnEvent", function(_, event, ...)
        if current.OnEvent then current.OnEvent(event, ...) end
        dirty = true
    end)

    -- tell each page whether the window is open on it
    local function Showing()
        for _, p in ipairs(pages) do
            if p.Showing then p.Showing(window:IsShown() and p == current) end
        end
    end

    local function Select(page)
        if not page.available then return end
        current = page
        for _, p in ipairs(pages) do
            if p.body then
                p.body:SetShown(p == page)
                p.band:SetShown(p == page)
                if p ~= page then p.foot:Hide() end
            end
            if p.tab then
                p.tab.mark:SetShown(p == page)
                p.tab.icon:SetAlpha(p == page and 1 or 0.6)
            end
        end
        Layout()
        Listen()
        if window:IsShown() and page.Shown then page.Shown() end
        Showing()
        dirty = true
    end
    w.Select = Select

    function w.Current() return current end

    function w.ByFrame(name)
        for _, p in ipairs(pages) do
            if p.frame == name then return p end
        end
    end

    -- A tab asks Blizzard for its page (the hook on that page's Show selects
    -- ours); in combat it turns ours alone.
    local function Open(page)
        if not InCombatLockdown() and spec.Open then spec.Open(page) end
        if current ~= page then Select(page) end
    end

    -- ------------------------------------------------------------ build
    local function Available(p)
        if p.Available then return p.Available() and true or false end
        return _G[p.frame] ~= nil
    end

    -- a page's frames, built the first time it is there
    local function Make(p)
        p.body = CreateFrame("Frame", nil, window)
        p.body:SetPoint("TOPLEFT", PAD, -TOP)
        p.body:SetPoint("TOPRIGHT", -PAD, -TOP)
        p.foot = CreateFrame("Frame", nil, window)
        p.foot:SetPoint("BOTTOMLEFT", PAD, BOTTOM)
        p.foot:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
        p.band = CreateFrame("Frame", nil, window)
        p.band:SetPoint("BOTTOMLEFT", w.band.left, 0)
        p.band:SetPoint("BOTTOMRIGHT", -w.band.right, 0)
        p.band:SetHeight(BAND)
        p.body:Hide()
        p.foot:Hide()
        p.band:Hide()
        p.Build(p.body, p.foot, p.band)
        if not p.bandUsed then
            local o = Ornament(p.band)
            o:SetPoint("LEFT", 0, 0)
            o:SetPoint("RIGHT", 0, 0)
        end
    end

    -- the row less the chevron and the cross, shared out among the pages
    -- that are there; the tabs overlap a pixel, sharing their edges
    local function Tabs()
        local shown = {}
        for _, p in ipairs(pages) do
            if p.available then table.insert(shown, p) end
            p.tab = nil
        end
        local room = WIDTH - 2 * PAD - 2 * (TAB + 4)
        local width = math.floor((room + #shown - 1) / #shown)
        local prev
        for i, p in ipairs(shown) do
            local b = tabs[i]
            if not b then
                b = Button(window, width, function(self) Open(self.page) end,
                    function() return tabs[i].page.tip or tabs[i].page.label end)
                b.icon = b:CreateTexture(nil, "ARTWORK")
                b.icon:SetSize(GLYPH, GLYPH)
                b.icon:SetPoint("CENTER")
                tabs[i] = b
            end
            b.page = p
            b:SetWidth(width)
            if p.icon then
                b.icon:SetTexture(p.icon)
                b.icon:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
            else
                b.icon:SetTexture(ns.media .. "strips\\" .. (p.glyph or p.key))
                b.icon:SetTexCoord(0, 1, 0, 1)
            end
            b:ClearAllPoints()
            if prev then b:SetPoint("LEFT", prev, "RIGHT", -1, 0) else b:SetPoint("TOPLEFT", PAD, -PAD) end
            b.mark:SetShown(p == current)
            b.icon:SetAlpha(p == current and 1 or 0.6)
            b:Show()
            p.tab, prev = b, b
        end
        for i = #shown + 1, #tabs do tabs[i]:Hide() end
    end

    -- Which pages are there now: a page that has come is built, one that
    -- has gone is left, for the first that is still there.
    function w.Retab()
        if not window then return end
        for _, p in ipairs(pages) do
            p.available = Available(p)
            if p.available and not p.body then Make(p) end
        end
        Tabs()
        if current and not current.available then
            current = nil
            for _, p in ipairs(pages) do
                if p.body then p.body:Hide(); p.foot:Hide(); p.band:Hide() end
            end
            for _, p in ipairs(pages) do
                if p.available then Select(p); break end
            end
        elseif current then
            Layout()
        end
    end

    function w.Build()
        local strip = ns.strips[side]
        window = CreateFrame("Frame", spec.name, strip)
        w.window = window
        -- the strip's scale, so it stands on the strip as the side panels
        -- do, but not the console's fading
        window:SetIgnoreParentAlpha(true)
        window:SetFrameStrata("MEDIUM")
        window:EnableMouse(true)
        window:SetWidth(WIDTH)
        window:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        window:Hide()
        local edge = window:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local bg = window:CreateTexture(nil, "BACKGROUND", nil, 2)
        bg:SetPoint("TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", -1, 1)
        bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)
        local rule = window:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetPoint("TOPLEFT", PAD, -(PAD + TAB + RULE / 2))
        rule:SetPoint("TOPRIGHT", -PAD, -(PAD + TAB + RULE / 2))
        rule:SetHeight(1)
        footRule = window:CreateTexture(nil, "ARTWORK")
        footRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        footRule:SetHeight(1)
        -- the margin's edge, over the medallion
        local bandRule = window:CreateTexture(nil, "ARTWORK")
        bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        bandRule:SetHeight(1)
        bandRule:SetPoint("BOTTOMLEFT", PAD, BAND)
        bandRule:SetPoint("BOTTOMRIGHT", -PAD, BAND)
        window.bandRule = bandRule
        Corners(window, 3, 12)
        Medal()

        close = Button(window, TAB, function() spec.Close() end, function() return spec.closeTip end)
        Glyph(close, "close")
        close:SetPoint("TOPRIGHT", -PAD, -PAD)
        chevron = Button(window, TAB, function() ns.SetOption(spec.detailsKey, not ns.db[spec.detailsKey]) end,
            function() return ns.db[spec.detailsKey] and "Hide the details." or "Show the details." end)
        Glyph(chevron)
        chevron:SetPoint("RIGHT", close, "LEFT", -4, 0)
        window.close, window.chevron = close, chevron

        table.sort(pages, function(a, b) return a.order < b.order end)
        for _, p in ipairs(pages) do
            p.available = Available(p)
            if p.available then Make(p) end
        end
        Tabs()

        window:SetScript("OnShow", function()
            Lift(true)
            Layout()
            Listen()
            Showing()
            if current and current.Shown then current.Shown() end
            dirty = true
        end)
        window:SetScript("OnHide", function()
            Lift(false)
            Listen()
            Showing()
        end)
        -- a change is drawn once, at the next frame, and only while it is open
        window:SetScript("OnUpdate", function()
            medal:SetAlpha(strip:GetEffectiveAlpha())
            if dirty and current then
                dirty = false
                current.Refresh()
            end
        end)
        ns.OnSetting(spec.detailsKey, Layout)
        -- the screen's height is the window's
        for _, e in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
            ns.On(e, function() if window:IsShown() then Layout() end end)
        end
        return window
    end

    function w.SetShown(open)
        if window and open ~= window:IsShown() then window:SetShown(open) end
    end

    return w
end
