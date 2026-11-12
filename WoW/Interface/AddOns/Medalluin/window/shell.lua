-- The shell of Medalluin's own full-height windows: the character window
-- on the left strip, the spellbook, talents and professions on the right.
-- In the console's ink and gold, standing on its strip over the side
-- panel's place, from the screen's edge to its top.
--
--   [  @  ][  @  ][  @  ][  @  ][  @  ][  @  ] [x]
--   ---------------------------------------------------------------
--   the page
--   ---------------------------------------------------------------
--   the page's details
--   ---------------------------------------------------------------
--   (medallion)  the page's band           <- the margin
--
-- (On the right the medallion is at the band's right end.) The strip's
-- medallion stands up out of the strip into the window's bottom margin: it
-- is drawn over the window while the window is open (its buttons lifted to
-- the window's strata, the medallion's art copied over them), and the
-- margin's rule runs above it, so it covers nothing. A page may put a row
-- of its own in the margin beside the medallion (the Character page's
-- shortcuts); the others have a divider there. A page with bandFlush has
-- its margin edge to edge, as the side panel's tabs: from the window's
-- outer border to 5 short of the medallion's ring, and from its foot up
-- over the margin's rule (a row of joined buttons, ns.window.Segments,
-- meets both lines).
--
-- The tabs are icons spread across the row, flush in the window's top
-- corner, with the page's name in a tooltip (tip, or the label): the glyph
-- art/strips draws for the page (named by its key, or glyph), or the game's
-- own icon (icon). The cross, a glyph of the same set, is flush in the top
-- right corner, a gap between it and the tabs (two edges, no line). A window whose pages come and
-- go (a pet's spells, a profession learned) asks for Retab, and the row is
-- shared out again. A page with row = 2 has its tab on a second row under
-- the first, shared out across the whole width; while there is one, the
-- rule and the page stand a row lower.
--
--   local w = ns.Window{ name, side (-1 left, 1 right),
--                        closeTip, Close(), Open(page) (ask Blizzard),
--                        Lifted() -> the medallion's buttons,
--                        place (a setting: the window detaches, below),
--                        detachedOnly (with a place: never docked, no view glyph),
--                        opaque (its ink solid, not the windows' 94%),
--                        exclusive (docked, it closes the other docked
--                        windows on its strip as it opens, and they close
--                        it as they open: Close() each) }
--   Its tooltips stand outside it (ns.window.Outside; w.Beside for an owner
--   not inside it).
--   w.Page{ key, label, tip, glyph, icon, frame (Blizzard's page), order, row,
--           tabless (no tab: the page's own controls Select it),
--           Available() (or Blizzard's frame exists), height, footHeight,
--           flex, bandUsed, bandFlush, events = { ... }, Build(body, foot, band),
--           Fit(height), Refresh(), OnEvent(event, ...), Shown(),
--           Showing(on) }
--   w.Build(), w.Select(page), w.Open(page) (as its tab does), w.ByFrame(name), w.Retab(), w.SetShown(on),
--   w.Detached()
--
-- A window with a place has two views, as the quest tracker has, switched
-- by a glyph left of the cross: docked, on its strip as every window
-- stands; detached, a box of its own (the bank's), dragged by its ink,
-- sized by the grip in its corner, scaled with Ctrl and the wheel over it.
-- Detached it has no medallion, its band runs edge to edge, and it is as
-- tall as it was sized, not the screen. Its place is the setting:
-- { detached, point, relative, x, y, w, h, scale }. Not in combat. A window
-- that detaches has no secure layer (Layer stands where the docked window
-- does).
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
local GLYPH, CONTROL = 20, 16                   -- a tab's glyph, the cross's
local GAP = 4                                   -- between the tabs and the cross
local TOP = TAB + RULE / 2                      -- the page's top, under the tabs' row
local MEDALLION = L.chatLeft                    -- the medallion's width: the strip's art left of the chat
local OVER = ART.height - L.stripHeight         -- how far the medallion stands above the strip
local BAND = OVER - 5                           -- the margin, up to its rule: as the chat's and the side panel's
local BOTTOM = BAND + RULE                      -- the page's (or its details') foot
local LIFT = 20                                 -- the medallion's buttons' level over the window's
local HEIGHT, LEAST = 480, { WIDTH, 240 }        -- a detached window's first height, its least size
local SCALES = { 0.6, 1.4, 0.05 }               -- a detached window's scale: least, most, a step
local GRIP = 14
local BESIDE = 4                                -- a tooltip outside the window: its gap
local GAME_ICON = 0.08                          -- the game's icons' border, trimmed

ns.window = { width = WIDTH - 2 * PAD, pad = PAD, band = BAND }

-- A secure button b set over region by numbers from its layer's (its
-- parent's) own corner and scale, never anchored to region (see w.Layer);
-- out of combat. False when the region is not laid out.
function ns.window.Over(b, region)
    local layer = b:GetParent()
    local x, y, lx, ly = region:GetLeft(), region:GetBottom(), layer:GetLeft(), layer:GetBottom()
    if not (x and y and lx and ly) then return false end
    local k = region:GetEffectiveScale() / layer:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", x * k - lx, y * k - ly)
    b:SetSize(region:GetWidth() * k, region:GetHeight() * k)
    return true
end

-- ------------------------------------------------------------ buttons
-- As the bags window's: a gold edge, an ink well, a white glow under the
-- mouse; one of a set marked when it is in use. Drawn on b, over b or over
-- another region to (a chat tab's slim box inside its taller frame). Soft:
-- the edge faint and the well thin, so the surface under it shows through
-- (the talents' controls, over the tree's ground).
local SOFT = { edge = 0.3, well = 0.35, mark = 0.3, glow = 0.07 }
local HARD = { edge = 1, well = 1, mark = 0.45, glow = 0.12 }
local function Face(b, to, soft)
    to = to or b
    local a = soft and SOFT or HARD
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints(to)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a.edge)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], a.well)
    b.mark = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.mark:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    b.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a.mark)
    b.mark:Hide()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, a.glow)
    return well, edge, glow
end
ns.window.Face = Face           -- the chat's tabs wear it too (strips/chat.lua)

-- A gold line that fades out at both ends: a parting that is not a box.
-- Anchor it as a frame; across, its height is 1, down, its width.
local function Hair(parent, down, alpha)
    local f = CreateFrame("Frame", nil, parent)
    if down then f:SetWidth(1) else f:SetHeight(1) end
    alpha = alpha or 1
    local lit, clear
    if CreateColor then
        lit = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], alpha)
        clear = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0)
    end
    f.halves = {}
    for i = 1, 2 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetPoint(down and (i == 1 and "TOPLEFT" or "BOTTOMLEFT") or (i == 1 and "TOPLEFT" or "TOPRIGHT"))
        t:SetPoint(down and (i == 1 and "BOTTOMRIGHT" or "TOPRIGHT") or (i == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT"),
            f, down and "RIGHT" or "BOTTOM")
        if t.SetGradient and lit then
            t:SetColorTexture(1, 1, 1, 1)
            -- across: clear at the ends; down: VERTICAL runs bottom to top
            if down then
                t:SetGradient("VERTICAL", i == 1 and lit or clear, i == 1 and clear or lit)
            else
                t:SetGradient("HORIZONTAL", i == 1 and clear or lit, i == 1 and lit or clear)
            end
        else
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], alpha * 0.6)
        end
        f.halves[i] = t
    end
    return f
end
ns.window.Hair = Hair

-- A round icon in a gold rim: the icon (returned, to texture and place),
-- with a gold disc and an ink one under it, all three masked round (the
-- bags' round mask, strips/bags.lua). A mask texture, not SetMask: a
-- texture SetMask has rounded refuses tex coords, and the icon trims its
-- border with them.
local function Ring(parent, size)
    local function Disc(sub, grow)
        local t = parent:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetSize(size + grow, size + grow)
        if parent.CreateMaskTexture then
            local mask = parent:CreateMaskTexture()
            mask:SetTexture(ns.media .. "strips\\round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            t:AddMaskTexture(mask)
            t.round = mask
        end
        return t
    end
    local rim, well, icon = Disc(1, 4), Disc(2, 2), Disc(3, 0)
    rim:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    rim:SetPoint("CENTER", icon)
    well:SetPoint("CENTER", icon)
    icon:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
    icon.rim, icon.well = rim, well
    return icon
end
ns.window.Ring = Ring

-- A tab with no box (Segments' soft = "open"): its mark a gold underline and a
-- glow rising from it, under the face (b.top), where the glyph is drawn.
local function Bare(b)
    b.mark = CreateFrame("Frame", nil, b)
    b.mark:SetAllPoints()
    b.mark:Hide()
    b.top = CreateFrame("Frame", nil, b)
    b.top:SetAllPoints()
    b.top:SetFrameLevel(b.mark:GetFrameLevel() + 1)
    local rise = b.mark:CreateTexture(nil, "BACKGROUND")
    rise:SetPoint("TOPLEFT", 10, -2)
    rise:SetPoint("BOTTOMRIGHT", -10, 0)
    if rise.SetGradient and CreateColor then
        rise:SetColorTexture(1, 1, 1, 1)
        rise:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.2),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
    else
        rise:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
    end
    local line = b.mark:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 10, 0)
    line:SetPoint("BOTTOMRIGHT", -10, 0)
    line:SetHeight(2)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.mark.line = line
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 4, -2)
    glow:SetPoint("BOTTOMRIGHT", -4, 0)
    glow:SetColorTexture(1, 1, 1, 0.06)
    return glow
end

-- soft: Face's soft look; "open": Bare's
-- a button's tooltip: beside the window it is in (ns.window.Outside), or
-- over it
function ns.window.OutsideTop(owner) ns.window.Outside(owner, "ANCHOR_TOP") end
local OutsideTop = function(owner) ns.window.OutsideTop(owner) end

local function Button(parent, width, click, tip, template, soft)
    local b = CreateFrame("Button", nil, parent, template)
    b:SetSize(width, TAB)
    if soft == "open" then Bare(b) else Face(b, nil, soft) end
    b.label = ns.Text(b, 12)
    b.label:SetPoint("CENTER")
    if click then b:SetScript("OnClick", click) end
    b:SetScript("OnEnter", function(self)
        ns.Tip(self, self.tipAt or OutsideTop, { title = tip(), color = ns.colors.white, wrap = true })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
ns.window.Button = Button

-- ------------------------------------------------------------- segments
-- A row of joined buttons, as the chat's and the side panel's tabs: each
-- wears the box (Face), neighbours share their edge (a pixel's overlap),
-- and where the group changes the two edges stand a little apart: a
-- double line, as before the chat's tools. Stretched, the buttons share out the
-- row's width (an icon keeps its own, 2026-11-11); fit, each is as wide as its word and the row as wide as
-- they come to (anchor it by the end it grows from).
--
--   local row = ns.window.Segments(parent, { height, fit, size (the
--               words', 12), iconSize (24), tipAt, items, soft (true:
--               Face's soft look; "open": tabs with no box, Bare's) })
--   row:Fill({ { key, label, icon, group, tip() -> text, click(button),
--                selected, enabled, shown, color } ... })   (again: the
--               buttons kept, their words and deeds changed)
--   row:Set(key, { selected, enabled, shown, color })        one's state
--   row:Layout()          shared out again (as its width changes)
--   row.byKey[key], row.buttons, row.gaps (where each gap starts)
--
-- Selected: the mark, its word gold. Off (enabled false): its word dim
-- and no glow, its tooltip still saying why; its click still goes to the
-- page, which asks the game itself (a state set a moment ago may already
-- be stale: a specialization just learned). color overrides the word's
-- colour (the talents' spec in use).
--
-- An icon (a glyph of media/strips, by name) stands in for the word: dim
-- (as the window's tabs) until selected, faint when off; the word heads
-- its tooltip, over the tip.
local SEG_PAD, SEG_MIN, BREAK = 20, 36, 4       -- a fit button's room past its word, its least; the gap between groups
local ICON_PAD = 12                              -- a fit button's room past its icon
local function Paint(b)
    b.mark:SetShown(b.selected and true or false)
    b.glow:SetShown(b.enabled)
    local c = not b.enabled and ns.colors.dim or b.color or b.selected and GOLD or ns.colors.text
    b.label:SetTextColor(c[1], c[2], c[3])
    b.icon:SetAlpha(not b.enabled and 0.3 or b.selected and 1 or 0.6)
end

local function Segments(parent, spec)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(spec.height)
    row.buttons, row.byKey, row.gaps = {}, {}, {}
    local n = 0                         -- the buttons in use

    function row:Layout()
        local shown = {}
        for i = 1, n do
            local b = self.buttons[i]
            b:SetShown(b.shown)
            if b.shown then table.insert(shown, b) end
        end
        local breaks = 0
        for i = 2, #shown do
            if shown[i].data.group ~= shown[i - 1].data.group then breaks = breaks + 1 end
        end
        -- the width less the gaps, the shared edges given back; none yet
        -- (not placed): as wide as their words until it comes
        -- (OnSizeChanged lays them out again)
        local total = math.floor(self:GetWidth() or 0) - breaks * BREAK + (#shown - 1 - breaks)
        local fit = spec.fit or total < #shown * SEG_MIN
        local widths = {}
        -- stretched, an icon keeps its own width and the words share the rest
        local words, icons = 0, 0
        for _, b in ipairs(shown) do
            if b.data.icon then icons = icons + (spec.iconSize or 24) + ICON_PAD else words = words + 1 end
        end
        local share, k = total - icons, 0
        for i, b in ipairs(shown) do
            local inner = b.data.icon and (spec.iconSize or 24) + ICON_PAD or math.ceil(b.label:GetStringWidth()) + SEG_PAD
            if fit or b.data.icon then
                widths[i] = fit and math.max(SEG_MIN, inner) or inner
            else
                k = k + 1
                widths[i] = math.floor(k * share / words) - math.floor((k - 1) * share / words)
            end
        end
        local x = 0
        self.gaps = {}
        for i, b in ipairs(shown) do
            if i > 1 then
                if b.data.group ~= shown[i - 1].data.group then
                    table.insert(self.gaps, x)  -- where the gap starts
                    x = x + BREAK
                else
                    x = x - 1               -- the edge shared
                end
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, 0)
            b:SetWidth(widths[i])
            x = x + widths[i]
        end
        if spec.fit then self:SetWidth(math.max(1, x)) end
    end

    function row:Set(key, state)
        local b = self.byKey[key]
        if not b then return end
        local was = b.shown
        b.selected = state.selected and true or false
        b.enabled = state.enabled ~= false
        b.shown = state.shown ~= false
        b.color = state.color
        Paint(b)
        if b.shown ~= was then self:Layout() end
    end

    function row:Fill(items)
        wipe(self.byKey)
        n = #items
        for i, d in ipairs(items) do
            local b = self.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, self)
                b:SetHeight(spec.height)
                local face = b
                if spec.soft == "open" then
                    b.glow = Bare(b)
                    face = b.top                -- over the mark's glow
                else
                    local _, _, glow = Face(b, nil, spec.soft)
                    b.glow = glow
                end
                b.label = ns.Text(face, spec.size or 12)
                b.label:SetPoint("CENTER")
                b.icon = face:CreateTexture(nil, "ARTWORK")
                b.icon:SetSize(spec.iconSize or 24, spec.iconSize or 24)
                b.icon:SetPoint("CENTER")
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                b:SetScript("OnClick", function(self, button)
                    if self.data.click then self.data.click(button) end
                end)
                b:SetScript("OnEnter", function(self)
                    local d = self.data
                    local tip = d.tip and d.tip()
                    if d.icon and d.label then
                        ns.Tip(self, spec.tipAt or OutsideTop, { title = d.label, color = GOLD, wrap = true,
                            tip and { "body", tip } or nil })
                    elseif tip then
                        ns.Tip(self, spec.tipAt or OutsideTop, { title = tip, color = ns.colors.white, wrap = true })
                    end
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.buttons[i] = b
            end
            b.data = d
            b.label:SetText(not d.icon and d.label or "")
            b.icon:SetShown(d.icon and true or false)
            if d.icon then b.icon:SetTexture(ns.media .. "strips\\" .. d.icon) end
            b.selected, b.enabled, b.shown, b.color = d.selected and true or false, d.enabled ~= false,
                d.shown ~= false, d.color
            Paint(b)
            if d.key ~= nil then self.byKey[d.key] = b end
        end
        for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
        self:Layout()
    end

    row:SetScript("OnSizeChanged", function(self) if not spec.fit then self:Layout() end end)
    if spec.items then row:Fill(spec.items) end
    return row
end
ns.window.Segments = Segments

-- ------------------------------------------------------------- scrolling
-- A list that scrolls, in a scroll frame filling the body but for a gutter
-- at the left, where its bar stands: a track and a gold thumb, which a
-- press or a drag places. To(y) eases the list there (the wheel), or sends
-- it at once (now: the bar dragged). Lay the list out in s.child, and call
-- To(s.target) as it changes, to keep it in range. s.Moved, if set, is
-- called as the list moves.
local function Scroller(body, gutter)
    local s = { target = 0, offset = 0 }
    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", gutter, 0)
    scroll:SetPoint("BOTTOMRIGHT")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local bar = CreateFrame("Frame", nil, body)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(gutter - 4)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(1)
    track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    bar.thumb = bar:CreateTexture(nil, "ARTWORK")
    bar.thumb:SetWidth(3)
    bar.thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    s.scroll, s.child, s.bar = scroll, child, bar

    -- the bar: shown while there is more than fits, its thumb as long as
    -- the share that shows, as far down as the list is
    function s.Thumb()
        local range = scroll:GetVerticalScrollRange() or 0
        bar:SetShown(range > 0)
        if range <= 0 then return end
        local h = scroll:GetHeight()
        local size = math.max(16, h * h / (h + range))
        bar.thumb:SetHeight(size)
        bar.thumb:ClearAllPoints()
        bar.thumb:SetPoint("TOP", bar, "TOP", 0, -(h - size) * s.offset / range)
        bar.size = size
    end

    local function Ease(_, elapsed)
        s.offset = s.offset + (s.target - s.offset) * math.min(1, elapsed * 12)
        if math.abs(s.target - s.offset) < 0.5 then
            s.offset = s.target
            scroll:SetScript("OnUpdate", nil)
        end
        scroll:SetVerticalScroll(s.offset)
        s.Thumb()
        if s.Moved then s.Moved() end
    end
    function s.To(to, now)
        local range = scroll:GetVerticalScrollRange() or 0
        s.target = math.max(0, math.min(range, to or 0))
        s.offset = math.max(0, math.min(range, s.offset))
        if now then s.offset = s.target end
        scroll:SetVerticalScroll(s.offset)
        s.Thumb()
        scroll:SetScript("OnUpdate", s.offset ~= s.target and Ease or nil)
        if s.Moved then s.Moved() end
    end

    -- pressed: the thumb's middle goes to the cursor, and follows it
    local function Drag()
        local range = scroll:GetVerticalScrollRange() or 0
        local h, size = scroll:GetHeight(), bar.size or 16
        if range <= 0 or h <= size then return end
        local _, y = GetCursorPosition()
        y = y / bar:GetEffectiveScale()
        s.To((bar:GetTop() - y - size / 2) / (h - size) * range, true)
    end
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function()
        Drag()
        bar:SetScript("OnUpdate", Drag)
    end)
    bar:SetScript("OnMouseUp", function() bar:SetScript("OnUpdate", nil) end)
    bar:SetScript("OnHide", function() bar:SetScript("OnUpdate", nil) end)
    bar:Hide()
    return s
end
ns.window.Scroller = Scroller

-- GameTooltip for owner, outside frame: beside its inner edge (side 1, a
-- frame on the right strip: its left; -1: its right), its top level with
-- the owner's; the offset is in the tooltip's own scale. Done in place of
-- SetOwner, and an anchor ns.Tip takes. The windows' (w.Beside,
-- ns.window.Outside), the side panel's (ns.side.Beside).
local placing                                  -- PlaceTip's own SetPoint (the hook below)
local function PlaceTip(frame, owner, side)
    placing = true
    GameTooltip:ClearAllPoints()
    local top, edge = owner:GetTop(), frame:GetTop()
    local dy = top and edge and (top - edge) * frame:GetEffectiveScale() / GameTooltip:GetEffectiveScale() or 0
    if side > 0 then
        GameTooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -BESIDE, dy)
    else
        GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", BESIDE, dy)
    end
    placing = false
end

function ns.window.Beside(frame, owner, side)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    PlaceTip(frame, owner, side)
end

-- A frame tooltips stand outside: side its default (1: it stands on the
-- right, -1: the left), taken from where it is when it can be (a window
-- dragged across); at: the frame they stand beside instead (a cast layer
-- marks its window). ns.window.Outside(owner, fallback) is GameTooltip for
-- an owner inside one, beside the nearest such frame up its parents, on the
-- side towards the screen's middle; outside any, SetOwner by fallback
-- ("ANCHOR_RIGHT" when not given). An anchor ns.Tip takes, as is.
-- The marks are kept here, not on the frame: Blizzard's may be marked too
-- (the Cooldown Manager's window), and nothing is written onto those.
local marks = setmetatable({}, { __mode = "k" })    -- frame: { side, at }
function ns.window.Mark(frame, side, at) marks[frame] = { side = side, at = at } end

local function Facing(frame)
    local l, r, w = frame:GetLeft(), frame:GetRight(), UIParent:GetWidth()
    if not (l and r and w and w > 0) then return marks[frame] and marks[frame].side or 1 end
    return (l + r) / 2 * frame:GetEffectiveScale() > w * UIParent:GetEffectiveScale() / 2 and 1 or -1
end

-- the marked frame owner is inside (or the one it marks), or nil
local function Marked(owner)
    local f = owner
    while f and not marks[f] do f = f.GetParent and f:GetParent() end
    return f and (marks[f].at or f)
end

function ns.window.Outside(owner, fallback)
    local f = Marked(owner)
    if f then return ns.window.Beside(f, owner, Facing(f)) end
    GameTooltip:SetOwner(owner, type(fallback) == "string" and fallback or "ANCHOR_RIGHT")
end

-- Blizzard's own buttons in a marked frame (the gear slots, the bags' items)
-- own the tooltip by their own Lua, on every refresh too: by an anchor the
-- game applies again as the text fills it (ANCHOR_RIGHT), or by points of
-- their own set after SetOwner (beside the bag item, the default place).
-- So: once owned, no anchor of the game's (SetAnchorType, which keeps the
-- text); and whenever it is placed by anyone else while its owner is under
-- the mouse, placed back beside the frame. The tooltip's C methods alone.
-- Not under the mouse: a tooltip fading out, or parked by mdlui_Tooltips.
local function Own(owner)
    local f = owner and Marked(owner)
    if not f then return end
    if GameTooltip.SetAnchorType then GameTooltip:SetAnchorType("ANCHOR_NONE") end
    PlaceTip(f, owner, Facing(f))
end
hooksecurefunc(GameTooltip, "SetOwner", function(_, owner) Own(owner) end)
hooksecurefunc(GameTooltip, "SetPoint", function(self)
    if placing then return end
    local owner = self:GetOwner()
    if owner and owner.IsMouseOver and owner:IsMouseOver() then Own(owner) end
end)
-- for mdlui_Tooltips: true when the tooltip owner shows stands beside a
-- window of ours, placed here (its cursor-following leaves it alone)
function Medalluin_TooltipBeside(owner) return owner ~= nil and Marked(owner) ~= nil end

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

-- The chat box's frame, and the quest tracker's when there is no chat box
-- (strips/chat.lua, quests/tracker.lua): the windows' gold trim, the
-- ink fading from solid at the left to a tenth at the right
-- so it can stand open over the world (the trim drawn as four lines, so
-- nothing shows through it), and the medallion's margin under its rule:
-- band high (the windows' own when not given). Mirrored (the side panel,
-- strips/side.lua), the ink is solid at the right instead.
local FADE = { 1, 0.10 }
local function Dress(parent, band, mirrored)
    local dress = CreateFrame("Frame", nil, parent)
    dress:SetAllPoints()
    dress:SetFrameLevel(parent:GetFrameLevel())
    local tint = ns.colors.ink
    local ink = dress:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    if ink.SetGradient and CreateColor then
        ink:SetColorTexture(1, 1, 1, 1)
        local from, to = FADE[1], FADE[2]
        if mirrored then from, to = to, from end
        ink:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], from),
            CreateColor(tint[1], tint[2], tint[3], to))
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

-- the windows on each strip, for the exclusive ones (spec.exclusive)
local docked = { [-1] = {}, [1] = {} }

-- ---------------------------------------------------------------- a window
function ns.Window(spec)
    local side = spec.side
    local pages = {}
    local w = { pages = pages, width = WIDTH - 2 * PAD, side = side,
        band = { left = side < 0 and MEDALLION + PAD or PAD, right = side < 0 and PAD or MEDALLION + PAD,
            height = BAND } }
    local window, close, rule, footRule, medal, view, grip
    local pageTop = TOP                 -- the page's top: a row lower with a second row of tabs
    local current, dirty
    local tabs = {}
    local listener = CreateFrame("Frame")
    w.listener = listener
    w.exclusive = spec.exclusive and true or false
    function w.Close() spec.Close() end
    table.insert(docked[side], w)

    function w.Page(page)
        table.insert(pages, page)
    end

    -- the detached view's place (none for a window that stays docked)
    local function At() return spec.place and type(ns.db[spec.place]) == "table" and ns.db[spec.place] or {} end
    function w.Detached() return (spec.detachedOnly or At().detached) and true or false end

    -- A page's margin: beside the medallion, inside the edge; flush, from
    -- the outer border to short of the medallion's ring (edge to edge
    -- detached), over the margin's rule.
    local function BandAt(p)
        local off = w.Detached()
        p.band:ClearAllPoints()
        if p.bandFlush then
            local medal = off and 0 or ns.stripWell.x + L.ringRadius + 5
            p.band:SetPoint("BOTTOMLEFT", side < 0 and medal or 0, 0)
            p.band:SetPoint("BOTTOMRIGHT", -(side < 0 and 0 or medal), 0)
            p.band:SetHeight(BAND + 1)
        else
            p.band:SetPoint("BOTTOMLEFT", off and PAD or w.band.left, 0)
            p.band:SetPoint("BOTTOMRIGHT", -(off and PAD or w.band.right), 0)
            p.band:SetHeight(BAND)
        end
    end

    -- -------------------------------------------------------- medallion
    -- The medallion's buttons lifted to the window's strata while the
    -- window is open, under a copy of the medallion's art; put back when
    -- it closes. The copy fades with the strip.
    local function Lift(on)
        local strip = ns.strips[side]
        if on and w.Detached() then on = false end
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
        if w.Detached() then return At().h or HEIGHT end
        local strip = ns.strips[side]
        local scale = strip:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return UIParent:GetHeight() / scale - L.stripHeight
    end

    -- What a page's details take, rule and all.
    local function Foot(page)
        if not (page.footHeight and page.footHeight > 0) then return 0 end
        return page.footHeight + 2 * RULE + 1
    end

    -- The window runs to the screen's top, on every page, so it keeps its
    -- height from tab to tab; a fixed page spreads out over it (Fit), a list
    -- fills it. On a screen too short for the tallest fixed page, that page
    -- runs off the top, and a list gives up height to fit.
    local function Layout()
        if not current then return end
        local least = 0
        for _, p in ipairs(pages) do
            if p.available and not p.flex then least = math.max(least, p.height + Foot(p)) end
        end
        local foot = Foot(current)
        local room = Room()
        local total = math.max(pageTop + least + BOTTOM, room)
        if current.flex then total = math.max(pageTop + 80 + foot + BOTTOM, math.min(total, room)) end
        local height = total - pageTop - foot - BOTTOM
        current.body:SetHeight(height)
        if current.Fit then current.Fit(height) end
        local shown = foot > 0
        current.foot:SetShown(shown)
        footRule:SetShown(shown)
        if shown then
            footRule:ClearAllPoints()
            footRule:SetPoint("TOPLEFT", PAD, -(pageTop + height + RULE))
            footRule:SetPoint("TOPRIGHT", -PAD, -(pageTop + height + RULE))
            current.foot:SetHeight(current.footHeight)
        end
        window:SetHeight(total)
        dirty = true            -- a list's rows follow its height
    end

    -- ------------------------------------------------------------ place
    local Tabs                  -- below: the tab row, shared out
    -- The view's place, scale and medallion, then the layout; out of combat.
    local function Place()
        if not window then return end
        if InCombatLockdown() then
            ns.OutOfCombat(Place)
            return
        end
        local strip, at, off = ns.strips[side], At(), w.Detached()
        window:ClearAllPoints()
        if off then
            window:SetScale(at.scale or 1)
            window:SetWidth(math.max(LEAST[1], at.w or WIDTH))
            window:SetPoint(at.point or "TOPLEFT", UIParent, at.relative or "TOPLEFT", at.x or 40, at.y or -80)
        else
            window:SetScale(1)
            window:SetWidth(WIDTH)
            window:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        end
        medal:SetShown(not off)
        if grip then grip:SetShown(off) end
        if view then view.icon:SetTexture(ns.media .. "strips\\" .. (off and "view-full" or "view-minimal")) end
        for _, p in ipairs(pages) do
            if p.band then BandAt(p) end
        end
        if window:IsShown() then Lift(not off) end
        Tabs()
        Layout()
        if spec.Placed then spec.Placed(off) end
    end
    w.Place = Place

    -- The detached place, kept: the anchor as the game left it after a drag
    -- or the grip, the size and the scale, with the changes asked.
    local function Keep(changes)
        local at = At()
        local keep = { detached = at.detached, point = at.point, relative = at.relative, x = at.x, y = at.y,
            w = at.w, h = at.h, scale = at.scale }
        -- docked, the window's anchor is the strip's: the saved place stands
        if w.Detached() then
            local point, _, relative, x, y = window:GetPoint()
            keep.point, keep.relative, keep.x, keep.y = point, relative, x, y
        end
        for k, v in pairs(changes or {}) do keep[k] = v end
        ns.SetOption(spec.place, keep)
    end

    -- Ctrl and the wheel: the scale, in steps, the anchor kept where it is on
    -- the screen (its offsets are in the window's own units)
    local function Rescale(delta)
        local at = At()
        local old = at.scale or 1
        local new = math.max(SCALES[1], math.min(SCALES[2], old + delta * SCALES[3]))
        new = math.floor(new / SCALES[3] + 0.5) * SCALES[3]
        if math.abs(new - old) < 0.001 then return end
        local point, _, relative, x, y = window:GetPoint()
        Keep({ point = point, relative = relative, x = (x or 0) * old / new, y = (y or 0) * old / new, scale = new })
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

    -- the tooltip outside this window (ns.window.Beside)
    function w.Beside(owner) ns.window.Beside(window, owner, side) end

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
    w.Open = Open

    -- ------------------------------------------------------------ build
    local function Available(p)
        if p.Available then return p.Available() and true or false end
        return _G[p.frame] ~= nil
    end

    -- a page's frames, built the first time it is there
    local function Make(p)
        p.body = CreateFrame("Frame", nil, window)
        p.body:SetPoint("TOPLEFT", PAD, -pageTop)
        p.body:SetPoint("TOPRIGHT", -PAD, -pageTop)
        p.foot = CreateFrame("Frame", nil, window)
        p.foot:SetPoint("BOTTOMLEFT", PAD, BOTTOM)
        p.foot:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
        p.band = CreateFrame("Frame", nil, window)
        BandAt(p)
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

    -- the row less the cross (and the view glyph) and the gap before
    -- them, shared out among the pages that are there, and the second row,
    -- if any, under it as wide, the cross as tall as both; flush in the
    -- window's corner, the tabs overlap a pixel, sharing their edges (the
    -- window's border too), row on row as well
    function Tabs()
        local first, second = {}, {}
        for _, p in ipairs(pages) do
            if p.available and not p.tabless then
                table.insert(p.row == 2 and second or first, p)
            end
            p.tab = nil
        end
        local controls = 1 + (view and 1 or 0)
        local full = window:GetWidth() or WIDTH
        local edge = controls * TAB - (controls - 1)    -- the cross and the view glyph, joined
        local room = full - edge - GAP
        local tall = #second > 0 and 2 * TAB - 1 or TAB
        close:SetHeight(tall)
        if view then view:SetHeight(tall) end
        local n = 0
        for r, list in ipairs({ first, second }) do
            local span = room
            local width = #list > 0 and math.floor((span + #list - 1) / #list) or 0
            local prev
            for k, p in ipairs(list) do
                n = n + 1
                local b = tabs[n]
                if not b then
                    local i = n
                    b = Button(window, width, function(self) Open(self.page) end,
                        function() return tabs[i].page.tip or tabs[i].page.label end)
                    b.icon = b:CreateTexture(nil, "ARTWORK")
                    b.icon:SetSize(GLYPH, GLYPH)
                    b.icon:SetPoint("CENTER")
                    tabs[n] = b
                end
                b.page = p
                -- the last to the row's end, exactly
                b:SetWidth(k < #list and width or span - (#list - 1) * (width - 1))
                if p.icon then
                    b.icon:SetTexture(p.icon)
                    b.icon:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
                else
                    b.icon:SetTexture(ns.media .. "strips\\" .. (p.glyph or p.key))
                    b.icon:SetTexCoord(0, 1, 0, 1)
                end
                b:ClearAllPoints()
                if prev then
                    b:SetPoint("LEFT", prev, "RIGHT", -1, 0)
                else
                    b:SetPoint("TOPLEFT", 0, -(r - 1) * (TAB - 1))
                end
                b.mark:SetShown(p == current)
                b.icon:SetAlpha(p == current and 1 or 0.6)
                b:Show()
                p.tab, prev = b, b
            end
        end
        for i = n + 1, #tabs do tabs[i]:Hide() end
        -- the rule along the last row's foot, the window's width, and the
        -- pages under it
        local rows = #second > 0 and 2 or 1
        pageTop = TOP + (rows - 1) * (TAB - 1)
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", 0, -(rows * (TAB - 1)))
        rule:SetPoint("TOPRIGHT", 0, -(rows * (TAB - 1)))
        for _, p in ipairs(pages) do
            if p.body then
                p.body:ClearAllPoints()
                p.body:SetPoint("TOPLEFT", PAD, -pageTop)
                p.body:SetPoint("TOPRIGHT", -PAD, -pageTop)
            end
        end
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
        ns.window.Mark(window, side)
        -- the strip's scale, so it stands on the strip as the side panels
        -- do, but not the console's fading
        window:SetIgnoreParentAlpha(true)
        window:SetFrameStrata("MEDIUM")
        -- over the chat's cog and drawer, MEDIUM too (strips/chat.lua)
        local cog = ns.chat and ns.chat.cog
        if cog then window:SetFrameLevel(math.max(window:GetFrameLevel(), cog:GetFrameLevel() + 1)) end
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
        bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], spec.opaque and 1 or 0.94)
        rule = window:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetPoint("TOPLEFT", 0, -(TAB - 1))
        rule:SetPoint("TOPRIGHT", 0, -(TAB - 1))
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
        Medal()

        -- the cross flush in the top right corner
        close = Button(window, TAB, function() spec.Close() end, function() return spec.closeTip end)
        Glyph(close, "close")
        close:SetPoint("TOPRIGHT", 0, 0)
        window.close = close
        if spec.place and not spec.detachedOnly then
            view = Button(window, TAB, function()
                if InCombatLockdown() then return end
                local at = At()
                if at.detached then
                    Keep({ detached = false })
                else
                    -- the first time detached: its top left where the docked
                    -- window's stood (the docked anchor is the strip's, not
                    -- the screen's); after that, where it was left
                    local left, top = window:GetLeft(), window:GetTop()
                    local first = not at.point and left and top
                        and { point = "TOPLEFT", relative = "BOTTOMLEFT", x = left, y = top } or {}
                    first.detached, first.w, first.h = true, at.w or WIDTH, at.h or HEIGHT
                    Keep(first)
                end
            end, function()
                return w.Detached() and "Docked: on the strip, as tall as the screen."
                    or "Detached: a box of its own, to move and size."
            end)
            Glyph(view)
            view:SetPoint("RIGHT", close, "LEFT", 1, 0)
            window.view = view
        end
        if spec.place then
            window:SetMovable(true)
            window:SetResizable(true)
            window:SetClampedToScreen(true)
            if window.SetResizeBounds then window:SetResizeBounds(LEAST[1], LEAST[2]) end
            window:RegisterForDrag("LeftButton")
            window:SetScript("OnDragStart", function()
                if w.Detached() and not InCombatLockdown() then window:StartMoving() end
            end)
            window:SetScript("OnDragStop", function()
                window:StopMovingOrSizing()
                if w.Detached() then Keep() end
            end)
            window:EnableMouseWheel(true)
            window:SetScript("OnMouseWheel", function(_, delta)
                if IsControlKeyDown() and w.Detached() and not InCombatLockdown() then Rescale(delta) end
            end)
            grip = CreateFrame("Button", nil, window)
            grip:SetSize(GRIP, GRIP)
            grip:SetPoint("BOTTOMRIGHT", -2, 2)
            grip:SetFrameLevel(window:GetFrameLevel() + LIFT + 4)
            for _, part in ipairs({ { 14, 2 }, { 2, 14 } }) do
                local t = grip:CreateTexture(nil, "ARTWORK")
                t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
                t:SetSize(part[1], part[2])
                t:SetPoint("BOTTOMRIGHT")
            end
            grip:SetScript("OnMouseDown", function()
                if w.Detached() and not InCombatLockdown() then window:StartSizing("BOTTOMRIGHT") end
            end)
            grip:SetScript("OnMouseUp", function()
                window:StopMovingOrSizing()
                if w.Detached() then Keep({ w = window:GetWidth(), h = window:GetHeight() }) end
            end)
            window.grip = grip
            ns.OnSetting(spec.place, Place)
        end

        table.sort(pages, function(a, b) return a.order < b.order end)
        for _, p in ipairs(pages) do
            p.available = Available(p)
            if p.available then Make(p) end
        end
        Tabs()

        window:SetScript("OnShow", function()
            -- docked beside an exclusive window (or as one): the other goes
            if not w.Detached() then
                for _, o in ipairs(docked[side]) do
                    if o ~= w and (w.exclusive or o.exclusive) and o.window and o.window:IsShown()
                        and not o.Detached() then
                        o.Close()
                    end
                end
            end
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
        if spec.place then Place() end
        -- the screen's height is the window's
        for _, e in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
            ns.On(e, function() if window:IsShown() then Layout() end end)
        end
        return window
    end

    function w.SetShown(open)
        if window and open ~= window:IsShown() then window:SetShown(open) end
    end

    -- Secure buttons over the window, on a layer of their own on the strip.
    -- Never anchored to the window or anything in it: a frame a protected
    -- frame is anchored to is protected too, and so is whatever that one is
    -- anchored to, up to the window, which then cannot open or close in
    -- combat. The layer stands where the docked window does, at its foot;
    -- Over(b, region) sets b over region by numbers from the layer's own
    -- corner and scale, so a detached, scaled window is met too; out of
    -- combat (false when the region is not laid out).
    function w.Layer(name)
        local strip = ns.strips[side]
        local layer = CreateFrame("Frame", name, strip)
        ns.window.Mark(layer, side, window)      -- its buttons' tooltips beside the window
        layer:SetFrameStrata("MEDIUM")
        layer:SetFrameLevel(window:GetFrameLevel() + 10)
        layer:SetIgnoreParentAlpha(true)
        layer:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        layer:SetSize(WIDTH, 1)
        layer:Hide()
        layer.buttons = {}
        return layer
    end
    w.Over = ns.window.Over

    return w
end
