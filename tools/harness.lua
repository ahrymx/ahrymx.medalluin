-- Load Medalluin outside the game against a stubbed WoW API and print every
-- named region's resolved rectangle, in art pixels from the console's
-- top-left. tools/preview.py draws them over the art.
--
--   lua5.1 tools/harness.lua [solo|group] [strips [nochat] | side [noside] | bar [nobar|rows2|rows3|bare|beamcast]
--                            | bags [nobags]]
--                            [modern] [CLASS]
--
-- "bar" prints the action bar instead, as 1080p screen pixels to compare
-- with assets/layer2.png: the settings page, the bar, its plate and pager,
-- the class resource in the lower row (CLASS, PALADIN by default), a cast
-- over it and its interruption, the adopted buttons, then the live options
-- played through the page (art colour, each visibility mode) and a page
-- change. "nobar" plays a saved
-- Action bar option that is off; "rows2" and "rows3" a saved Rows option;
-- "bare" a saved Bare icons option; "beamcast" saved Experience and
-- Reputation cast options.
--
-- "strips" prints the corner strips, the chat panel with Blizzard's chat in
-- it (and Blizzard's passes over it: its saved layout, a fade, focus, a tab
-- change, windows docking and leaving), and, with "modern", the timeless
-- buffs through a combat. "strips nochat" plays a saved Chat panel option
-- that is off.
--
-- "side" prints the side panel on the right strip, the chat panel's
-- mirror: its tabs, column buttons and scroll bar, then the Loot tab through
-- the chat's loot lines, money and currency (and, with "modern", the loot
-- history's boss drops and the rolls the chat tells twice), its column
-- buttons and options; then, with "modern", the Meter tab over a stubbed
-- C_DamageMeter, out of combat and in it (every number and name secret),
-- through its column buttons, headings, scroll and reset; then the Auras
-- tab over stubbed buffs and debuffs, sorted, through combat (every time,
-- name and stack secret), its column buttons, scroll, ticks and right
-- clicks; then the tab options. "side noside" plays a saved Side panel
-- option that is off.
--
-- "bags" (with "modern") prints the bags window over a stubbed C_Container
-- and Blizzard's bag frames: hidden under ns.hidden, their opening and
-- closing followed, every slot in the grid, then the groups, the search, the
-- sort, the item levels, a bag swapped for a smaller one, events while shown
-- and while closed, dragging and the options. Without "modern" there are no
-- combined bags and no window. "bags nobags" plays a saved Bags window
-- option that is off.
--
-- "modern" swaps the Classic-era world for an Edit Mode one shaped like
-- Forever 1.60 and retail 12.x: secret values (health, power, combo points,
-- cooldowns, a secret cast), C_ActionBar with no globals, MainActionBar and
-- MultiBarBottomLeft, a MicroMenu in Forever's order, BagsBar, the reagent
-- bag, and Blizzard's re-skinning methods. Lua's own arithmetic, comparison
-- and concatenation on a secret raise, as in the game; a truth test cannot
-- be trapped here.
local ADDON = "WoW/Interface/AddOns/Medalluin/"
local args, modern = {}, false
local argClass
for _, a in ipairs(arg) do
    if a == "modern" then modern = true
    elseif a:match("^%u+$") then argClass = a
    else table.insert(args, a) end
end
local grouped = args[1] == "group"
local stripsPass = args[2] == "strips"
local barPass = args[2] == "bar"
local sidePass = args[2] == "side"
local savedNoSide = args[3] == "noside"
local bagsPass = args[2] == "bags"
local savedNoBags = args[3] == "nobags"
-- "bank" (with "modern") plays the bank (inventory/bank.lua) over a stubbed
-- C_Bank: Blizzard's BankFrame parked and followed, the views, the search,
-- Sort, the bag slots and Purchase, the window detached and docked, the
-- character window standing over it, the tracker and the NPC box under it,
-- and the Warband page. "bank nobank" plays the option off.
local bankPass = args[2] == "bank"
-- "character" (with "modern": Forever's six pages; "modern retail": retail's
-- three) plays the character window (character/): Blizzard's window kept
-- under ns.hidden and followed, its page switches, the tabs, the details'
-- chevron, and each page over stubbed data. "character nochar" plays a
-- saved Character window option that is off.
local characterPass = args[2] == "character"
local characterRetail = characterPass and args[3] == "retail"
local savedNoCharacter = characterPass and args[3] == "nochar"
-- "spellbook" (with "modern": Forever's book; "modern retail": retail, where
-- it is not built) plays the spellbook window (spells/): Blizzard's
-- player-spells frame loaded on demand and followed, a tab per skill line and
-- the pet's coming and going, the pages, and the secure layer through combat.
local spellPass = args[2] == "spellbook"
local spellRetail = spellPass and args[3] == "retail"
-- "talents" (with "modern": Forever's; "modern retail": not built) plays the
-- talents window (spells/talents.lua) over a stubbed tree of three groups:
-- staging, Apply and Reset, the Primary and Secondary talents, combat, and
-- the frame it shares with the spellbook.
local talentPass = args[2] == "talents"
local talentRetail = talentPass and args[3] == "retail"
-- "professions" (with "modern": Forever's; "modern retail": not built) plays
-- the professions window (professions/) over stubbed professions: the
-- overview's cards and their spells, a tab per profession that crafts, the
-- recipes, Create, the filters, a profession learned, combat, and one window
-- on the right strip.
local profPass = args[2] == "professions"
local profRetail = profPass and args[3] == "retail"
-- "quests" (with "modern") plays the quest tracker (quests/) over a stubbed
-- quest log of three zones: the anchor, the sorts, a fold, the minimise, the
-- clicks, the item buttons, combat holding the rows still, and the character
-- window standing over it. "quests questie" adds a stub of Questie that
-- becomes ready after login (its tracked set, its items, its untrack);
-- "quests broken" one whose every call raises.
local questPass = args[2] == "quests"
local questieStub = questPass and args[3] == "questie"
local questieBroken = questPass and args[3] == "broken"
-- "npc" (with "modern") plays the NPC box (npc/): gossip, the four quest
-- pages and the vendor over stubbed APIs, Blizzard's three frames parked and
-- followed, the tracker covered, the chat box held. "npc nochat" plays the
-- chat box off: nothing built, nothing parked; "npc nonpc" the option off.
local npcPass = args[2] == "npc"
-- "mail" (with "modern") plays the mailbox's page of the NPC box
-- (npc/mail.lua): six letters, Open all step by step (the bags filling, the
-- mailbox closing, Stop), the send form and its wells, and the names it keeps.
local mailPass = args[2] == "mail"
local barOff = args[3] == "nobar"
local savedRows = tonumber((args[3] or ""):match("^rows(%d)$"))
local savedBare = args[3] == "bare"
local savedNoChat = args[3] == "nochat"
local savedBeam = args[3] == "beamcast"
local savedSimParty = args[2] == "simparty" or args[3] == "simparty" or args[4] == "simparty"
local lightPass = args[2] == "light"
-- "profiles" loads a saved table from before profiles (flat, every option at
-- the top, the light profile's forced rows) and plays the layers: a choice
-- per profile (the console's) and global (the rest) through profile switches,
-- each profile's own choices coming back with it, and Reset profile.
-- "profiles saved" loads one already layered, as every later login does.
local profilesPass = args[2] == "profiles"
local movePass = args[2] == "move"      -- moving and scaling the consoles (movers.lua)
local lookPass = args[2] == "look"      -- the Action Bar page's Text and Cooldowns options
-- "keybind" (alone, or after "light") plays the hover binding mode
-- (keybind.lua): /mdlui kb and the page's button, binding through the
-- binder, the chords, the keys it skips, a key moved off another button,
-- Esc, the fade it lifts, and combat ending it.
local keybindPass = args[2] == "keybind" or args[3] == "keybind"
-- "paging" (alone, with rows at 3, or after "light" for the centre grid)
-- plays the Paging page (bars/paging.lua): each bar's state driver by its
-- option, the secure snippet run as the game would run it, Custom's editor,
-- combat holding a change back, and the options kept per profile.
local pagingPass = args[2] == "paging" or args[3] == "paging"
-- "row" (after "light") plays the horizontal party row (console/party_row.lua):
-- the Party layout option saved on the light profile, each member's frame by
-- its pet's state driver, the snippet run from the game's secure update (in
-- combat too), pets turned off, the row with no group, and the option played
-- out to the widget and back again. Seeded with the retired "horizontal",
-- which the migration turns into the console's own; the light pass alone
-- is seeded with the retired "vertical", which comes to the same.
local rowPass = args[3] == "row"
-- "minimap" (alone: the Medallion; after "light": the Central Console) plays
-- Console > Minimap: the rule's triggers, the key's pin, the corner's size and place.
-- "light minimap corner" (or "console") is saved with that place for the load.
local minimapPass = args[2] == "minimap" or args[3] == "minimap"
local savedStart = (args[4] == "corner" or args[4] == "console") and args[4] or nil
local fadePass = args[2] == "fade" or args[3] == "fade"      -- the console's and the overhead's fading
local actionPage = 1
local class = argClass or "PALADIN"

-- ------------------------------------------------------------ secrets
local Secret = {}
local function refuse() error("secret value used in Lua arithmetic or comparison", 2) end
for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat",
    "__lt", "__le", "__eq", "__len", "__index", "__newindex", "__call" }) do Secret[m] = refuse end
Secret.__tostring = function() return "<secret>" end
local function secret() return setmetatable({}, Secret) end
local function isSecret(v) return getmetatable(v) == Secret end
local secretsUsed = 0

-- ------------------------------------------------------------ regions
local Region = {}
local noTimer = false   -- a client whose status bars have no timer (the auras' fallback)
Region.__index = function(self, k)
    if noTimer and k == "SetTimerDuration" then return nil end
    local m = rawget(Region, k)
    if m then return m end
    -- unstubbed widget methods (verbs) are no-ops; anything else, a part a
    -- button may lack (SlotArt) or a mixin method a client lacks
    -- (UpdateButtonArt), stays nil as in WoW
    if type(k) == "string" and k:match("^[SG]et%u") or k:match("^Is%u") or k:match("^Enable")
        or k:match("^Disable") or k:match("^Register") or k:match("^Unregister") or k:match("^Hook")
        or k:match("^Add%u") or k:match("^Remove%u") or k:match("^Clear%u") then
        if not modern and (k == "GetCountdownFontString" or k == "SetTimerDuration"
            or k == "SetMinimumCountdownDuration") then return nil end
        return function() end
    end
end
-- a cooldown's Clear (the game's; not a verb the stub knows)
function Region:Clear() self.start, self.duration = nil, nil end
local all = {}
local function new(kind, parent, name)
    local r = setmetatable({ kind = kind, parent = parent, points = {}, w = 0, h = 0,
        shown = true, scripts = {}, attrs = {}, name = name, level = 0 }, Region)
    if parent then
        r.level = parent.level + 1
        parent.all_ = parent.all_ or {}
        table.insert(parent.all_, r)
    end
    table.insert(all, r)
    if name then _G[name] = r end
    return r
end
-- resolved rectangles are cached; any move or resize after one has been
-- read drops them all, so a region placed again is measured again
local function moved()
    for _, f in ipairs(all) do f.rect = nil end
end
function Region:SetPoint(p, rel, rp, x, y)
    moved()
    -- the game's own check: a point by name, offsets as plain numbers
    if type(p) ~= "string" or isSecret(rp) or isSecret(x) or isSecret(y) then
        error(self.kind .. ':SetPoint(): Usage: ("point" [, region or nil] [, "relativePoint"] [, offsetX, offsetY]', 2)
    end
    if type(rel) ~= "table" then rel, rp, x, y = self.parent, p, rel, rp end
    if type(rp) ~= "string" then rp, x, y = p, rp, x end
    if not self.points[p] then
        self.order = self.order or {}
        table.insert(self.order, p)
    end
    self.points[p] = { rel or self.parent, rp or p, x or 0, y or 0 }
end
function Region:ClearAllPoints() moved(); self.points, self.all, self.order = {}, nil, nil end
-- the points in the order they were set, as the game numbers them
-- (SetAllPoints is two: the corners, as the game reports it)
function Region:GetNumPoints()
    if self.all then return 2 end
    return self.order and #self.order or 0
end
-- a font: the face, the size, the flags (the editor reads and sets it)
function Region:SetFont(face, size, flags) self.font = { face, size, flags } end
function Region:SetSpacing(n) self.spacing = n end
function Region:GetFont()
    if self.font then return self.font[1], self.font[2], self.font[3] end
end
function Region:SetAllPoints(rel) moved(); self.all = rel or self.parent end
function Region:SetSize(w, h) moved(); self.w, self.h = w, h end
function Region:SetHitRectInsets(l, r, t, b) self.hitInsets = { l, r, t, b } end
function Region:SetMaskTexture(path) self.mask = path end
function Region:SetIgnoreParentAlpha(on) self.ignoreParentAlpha = on end
function Region:SetScale(s) moved(); self.scale = s end
function Region:GetScale() return self.scale or 1 end
-- against the screen: every scale up the parents (UIParent's counts as 1)
function Region:GetEffectiveScale()
    local s, f = 1, self
    while f do s, f = s * (f.scale or 1), f.parent end
    return s
end
function Region:GetRegions()
    local out = {}
    for _, f in ipairs(self.all_ or {}) do
        if f.kind == "Texture" or f.kind == "FontString" then table.insert(out, f) end
    end
    return unpack(out)
end
function Region:SetWidth(w) moved(); self.w = w end
function Region:SetHeight(h) moved(); self.h = h end
function Region:GetFrameLevel() return self.level end
function Region:SetFrameLevel(l) self.level = l end
function Region:SetID(id) self.idOf = id end
function Region:GetID() return self.idOf end
function Region:GetFrameStrata() return self.strata or "LOW" end
function Region:SetFrameStrata(s) self.strata = s end
function Region:SetParent(p) self.parent = p end
function Region:SetClipsChildren(on) self.clipsChildren = on end
function Region:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(s)
    if s then self:Show() else self:Hide() end
end
function Region:SetScript(k, f) self.scripts[k] = f end
function Region:GetScript(k) return self.scripts[k] end
function Region:SetAttribute(k, v) self.attrs[k] = v end
function Region:RegisterForClicks(...) self.clicks = { ... } end
function Region:RegisterForDrag(...) self.drag = { ... } end
function Region:SetAltArrowKeyMode(on) self.altArrows = on end
function Region:GetAttribute(k) return self.attrs[k] end
function Region:SetFrameRef(k, f) self.refs = self.refs or {}; self.refs[k] = f end
function Region:GetFrameRef(k) return self.refs and self.refs[k] end
function Region:SetTexture(t) self.texture, self.atlas = t, nil end
function Region:GetTexture() return self.texture end
function Region:SetColorTexture(r, g, b, a) self.color, self.atlas = { r, g, b, a }, nil end
function Region:SetAtlas(a) self.atlas = a end
function Region:GetAtlas() return self.atlas end
function Region:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
function Region:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Region:SetBlendMode(m) self.blend = m end
function Region:GetBlendMode() return self.blend or "BLEND" end
function Region:SetText(t)
    if isSecret(t) then secretsUsed = secretsUsed + 1 end
    self.text = t
end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetFormattedText(f, ...)
    for i = 1, select("#", ...) do
        if isSecret(select(i, ...)) then
            secretsUsed = secretsUsed + 1
            -- the game's text is secret too: GetText hands back a secret
            self.text = secret()
            return
        end
    end
    self.text = string.format(f, ...)
end
-- a button's state textures, and the atlases Blizzard puts on them
for _, state in ipairs({ "Normal", "Pushed", "Highlight", "Checked", "Disabled" }) do
    -- a path makes a texture of it, as in WoW
    Region["Set" .. state .. "Texture"] = function(self, t)
        if type(t) == "string" then
            local path = t
            t = new("Texture", self)
            t:SetTexture(path)
        end
        self[state:lower() .. "Tex"] = t
    end
    Region["Get" .. state .. "Texture"] = function(self) return rawget(self, state:lower() .. "Tex") end
    -- the worst case: the atlas arrives on a fresh texture, so nothing set on
    -- the old one (a mute, a colour) carries over
    Region["Set" .. state .. "Atlas"] = function(self, a)
        local t = new("Texture", self)
        t:SetAtlas(a)
        self[state:lower() .. "Tex"] = t
    end
end
function Region:GetChildren()
    local out = {}
    for _, f in ipairs(self.all_ or {}) do table.insert(out, f) end
    return unpack(out)
end
function Region:GetButtonState() return self.state or "NORMAL" end
function Region:IsEnabled() return not self.disabled end
function Region:SetEnabled(on) self.disabled = not on end
function Region:Enable() self.disabled = false end
function Region:Raise() self.raised = (self.raised or 0) + 1 end
function Region:Disable() self.disabled = true end
function Region:SetReverseFill(v) self.reverse = v end
function Region:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Region:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end
function Region:SetValue(v)
    if isSecret(v) then secretsUsed = secretsUsed + 1 end
    self.value = v
end
function Region:GetZoom() return 0 end
function Region:GetZoomLevels() return 5 end
function Region:CreateTexture(_, layer, _, sub)
    local t = new("Texture", self)
    t.layer, t.sub = layer, sub
    return t
end
function Region:CreateFontString() return new("FontString", self) end
-- a line: its two ends, each a point on a region
function Region:CreateLine(_, layer)
    local l = new("Line", self)
    l.layer = layer
    function l:SetStartPoint(point, rel, x, y) self.from = { point, rel, x or 0, y or 0 } end
    function l:SetEndPoint(point, rel, x, y) self.to = { point, rel, x or 0, y or 0 } end
    function l:SetThickness(t) self.thickness = t end
    return l
end
local events = {}
-- registering one already registered changes nothing, as in WoW
local function listening(f, e)
    for _, g in ipairs(events[e] or {}) do
        if g == f then return true end
    end
end
function Region:RegisterUnitEvent(e, unit)
    if e == "UNIT_HEALTH_FREQUENT" then error("unknown event " .. e) end
    events[e] = events[e] or {}
    if not listening(self, e) then table.insert(events[e], self) end
    self.unitOf = self.unitOf or {}
    self.unitOf[e] = unit
end
function Region:GetStatusBarTexture()
    self.fill = self.fill or new("Texture", self)
    return self.fill
end
function Region:SetHideCountdownNumbers(h) self.hideNumbers = h end
-- a cooldown's sweep, its edge and its end flash (the Action Bar's Cooldowns options)
function Region:SetDrawSwipe(on) self.drawSwipe = on end
function Region:SetDrawEdge(on) self.drawEdge = on end
function Region:SetDrawBling(on) self.drawBling = on end
function Region:GetCountdownFontString()
    if not modern then return end
    self.countdown = self.countdown or new("FontString", self)
    return self.countdown
end
function Region:SetTimerDuration(d, _, direction) self.timer = { d, direction } end

-- Resolve a region to { left, top, right, bottom } in the console's units,
-- y growing downward. Points are relative to the console unless anchored on
-- UIParent; that is enough for this addon.
local function anchor(r, p)
    local x = p:find("LEFT") and r[1] or p:find("RIGHT") and r[3] or (r[1] + r[3]) / 2
    local y = p:find("TOP") and r[2] or p:find("BOTTOM") and r[4] or (r[2] + r[4]) / 2
    return x, y
end
-- A region's offsets and size are in its own scale: its own SetScale times
-- every parent's (the console's own counts as 1, the units printed).
local scaleRoot
local function scaleOf(f)
    local s = 1
    while f and f ~= scaleRoot do
        s = s * (f.scale or 1)
        f = f.parent
    end
    return s
end
local resolve
resolve = function(f)
    if f.fixed then return f.fixed end     -- the console, and the screen, as the passes pin them
    if f.rect then return f.rect end
    if f.isScreen then return { 0, 0, 1e6, 1e6 } end
    if f.all then f.rect = resolve(f.all); return f.rect end
    local L, T, R, B
    local k = scaleOf(f)
    local w, h = f.w * k, f.h * k
    for p, a in pairs(f.points) do
        local ax, ay = anchor(resolve(a[1]), a[2])
        ax, ay = ax + a[3] * k, ay - a[4] * k
        if p:find("LEFT") then L = ax elseif p:find("RIGHT") then R = ax end
        if p:find("TOP") then T = ay elseif p:find("BOTTOM") then B = ay end
        if not p:find("LEFT") and not p:find("RIGHT") then f.cx = ax end
        if not p:find("TOP") and not p:find("BOTTOM") then f.cy = ay end
    end
    L = L or (R and R - w) or (f.cx and f.cx - w / 2)
    R = R or (L and L + w)
    T = T or (B and B - h) or (f.cy and f.cy - h / 2)
    B = B or (T and T + h)
    f.rect = { L, T, R, B }
    return f.rect
end
-- a text sized by secret words has a secret size, as in the game
local function secretText(r) return r.kind == "FontString" and isSecret(r.text) end
local function heldAcross(r)
    local left, right = false, false
    for q in pairs(r.points or {}) do
        if q:match("LEFT$") then left = true elseif q:match("RIGHT$") then right = true end
    end
    return r.all or (left and right)
end
function Region:GetHeight() if secretText(self) then return secret() end return self.h end
function Region:GetWidth()
    if secretText(self) and not heldAcross(self) then return secret() end
    return self.w
end
function Region:GetName() return self.name end
function Region:GetParent() return self.parent end
function Region:GetText() return self.text end
-- shown, and every parent up the chain shown too, as in WoW
function Region:IsVisible()
    local f = self
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
function Region:IsShown() return self.shown end
-- as in WoW: the frame hears none of them after, until registered again
function Region:UnregisterAllEvents()
    self.unregistered = true
    for _, list in pairs(events) do
        for i = #list, 1, -1 do
            if list[i] == self then table.remove(list, i) end
        end
    end
end
-- ~Marcellus SC 15px; an inline icon (|T...|t) two letters wide, colour codes none
function Region:GetStringWidth()
    local t = (self.text or ""):gsub("|T.-|t", "..")
    return #t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 7
end
-- wrapped at its width, 6 a character, 14 a line; each line of a text
-- with line breaks wrapped on its own
function Region:GetStringHeight()
    if self.wrap == false then return 14 end
    local w = self.w > 0 and self.w or 1e9
    local rows = 0
    for l in ((self.text or "") .. "\n"):gmatch("(.-)\n") do
        rows = rows + math.max(1, math.ceil(#l * 6 / w))
    end
    return rows * 14
end
-- a scroll frame: its child, scrolled by as much as the child is taller (a
-- new child keeps the offset, as the game's does)
function Region:SetScrollChild(c)
    self.scrollChild = c
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
end
function Region:GetVerticalScroll() return self.scroll or 0 end
function Region:SetVerticalScroll(v) self.scroll = v end
function Region:GetVerticalScrollRange()
    local c = self.scrollChild
    if not c then return 0 end
    local r = resolve(self)
    return math.max(0, c.h - (r[4] - r[2]))
end
-- the game's rule: a texture rounded by SetMask takes no tex coords (a
-- mask texture, AddMaskTexture, does)
function Region:SetMask(path) self.setMask = path end
function Region:SetTexCoord(...)
    if self.setMask then error("Texture:SetTexCoord(): Cannot set tex coords when texture has mask.", 2) end
    self.coords = { ... }
end
-- the game's eight corners (UL, LL, UR, LR), from the four-number form
function Region:GetTexCoord()
    local c = self.coords or { 0, 1, 0, 1 }
    if #c == 8 then return unpack(c) end
    return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
end
function Region:SetDesaturated(d) self.desaturated = d end
function Region:CreateMaskTexture() return new("MaskTexture", self) end
local mouseOver = false
-- true: the pointer is over everything; a region: over that one only
function Region:IsMouseOver() return mouseOver == true or mouseOver == self end
function Region:IsObjectType(t) return self.kind == t or t == "Button" and self.kind == "CheckButton" end
function Region:IsProtected() return false end
function Region:LockHighlight() self.highlightLocked = true end
function Region:UnlockHighlight() self.highlightLocked = false end
function Region:HookScript(k, f)
    self.hooked = self.hooked or {}
    self.hooked[k] = true
    local old = self.scripts[k]
    self.scripts[k] = function(...)
        if old then old(...) end
        f(...)
    end
end
function Region:GetAlpha() return self.alpha or 1 end
-- an edit box's focus: one at a time, with its two scripts
local focused
function Region:HasFocus() return focused == self end
function Region:HighlightText() self.highlighted = true end
function Region:SetRotation(r) self.rotation = r end
function Region:SetFocus()
    if focused == self then return end
    local old = focused
    focused = self
    if old and old.scripts.OnEditFocusLost then old.scripts.OnEditFocusLost(old) end
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function Region:ClearFocus()
    if focused ~= self then return end
    focused = nil
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
-- a restricted snippet's self:GetParent():CallMethod(name, ...) (widgets/raid.lua)
function Region:CallMethod(name, ...) return self[name](self, ...) end
-- the first of a region's points, as GetPoint() gives it; GetPoint(i) the
-- i-th, in the order they were set
function Region:GetPoint(i)
    if i then
        -- a point on a text of secret size has secret offsets
        local function out(p, a)
            local rel = a[1]
            if type(rel) == "table" and secretText(rel) and not heldAcross(rel) then
                return p, rel, a[2], secret(), secret()
            end
            return p, a[1], a[2], a[3], a[4]
        end
        if self.all then
            local p = i == 1 and "TOPLEFT" or i == 2 and "BOTTOMRIGHT"
            if p then return p, self.all, p, 0, 0 end
            return
        end
        local p = self.order and self.order[i]
        local a = p and self.points[p]
        if a then return out(p, a) end
        return
    end
    for p, a in pairs(self.points) do return p, a[1], a[2], a[3], a[4] end
end
-- the left edge, in the harness's own units (only compared, never shown)
function Region:GetLeft()
    local ok, r = pcall(resolve, self)
    -- a rect that rests on a secret size is secret
    if not ok and tostring(r):find("secret") then return secret() end
    return ok and r and r[1] or nil
end
function Region:GetRight()
    local ok, r = pcall(resolve, self)
    if not ok and tostring(r):find("secret") then return secret() end
    return ok and r and r[3] or nil
end
-- the top and bottom edges, up from the screen's foot (1080 high)
function Region:GetTop()
    local ok, r = pcall(resolve, self)
    return ok and r and 1080 - r[2] or nil
end
function Region:GetBottom()
    local ok, r = pcall(resolve, self)
    return ok and r and 1080 - r[4] or nil
end
-- Every tooltip a side window shows stands outside it, beside the edge
-- towards the screen's middle, its top level with what is hovered
-- (ns.window.Outside): each shown frame in root with a hover that takes the
-- tooltip, hovered. Prints how many stood beside it (and on which side) and
-- how many anywhere else. bare: the screen as the harness has it, no width
-- (the side the window declares decides). from: the frames hovered are
-- this one's instead (a cast layer over root). owned: they are Blizzard's,
-- whose own Lua owns the tooltip by SetOwner (the gear slots), or by the
-- default place when the value is "default" (the gear and bag items on
-- clients that do), or owned with no anchor and placed beside the button
-- when it is "button" (the bags' items): that is done, the pointer over it.
function harnessBeside(tag, root, bare, from, owned)
    local left, right, other = 0, 0, {}
    -- the harness's screen is 1920 wide (its UIParent has no width)
    local width = UIParent.GetWidth
    if not bare then function UIParent:GetWidth() return 1920 end end
    local middle = bare and "declared" or (root:GetLeft() + root:GetRight()) / 2 < 1920 / 2 and "right" or "left"
    local function walk(f)
        for _, c in ipairs(f.all_ or {}) do
            if c.shown and (owned and owned[c] or not owned and c.scripts and c.scripts.OnEnter) then
                GameTooltip.owner, GameTooltip.points = nil, {}
                local was = mouseOver
                mouseOver = c
                if owned and owned[c] == "button" then
                    GameTooltip:SetOwner(c, "ANCHOR_NONE")
                    GameTooltip:SetPoint("BOTTOMLEFT", c, "TOPRIGHT")
                elseif owned and owned[c] == "default" then GameTooltip_SetDefaultAnchor(GameTooltip, c)
                elseif owned then GameTooltip:SetOwner(c, "ANCHOR_RIGHT") else c.scripts.OnEnter(c) end
                mouseOver = was
                if GameTooltip.owner == c and owned and GameTooltip.anchor ~= "ANCHOR_NONE" then
                    table.insert(other, tostring(c:GetName()) .. ":anchor " .. tostring(GameTooltip.anchor))
                elseif GameTooltip.owner == c then
                    local p = GameTooltip.points
                    local at = p.TOPRIGHT or p.TOPLEFT
                    local top, edge = c:GetTop(), root:GetTop()
                    local level = at and type(at[4]) == "number" and top and edge and math.abs(at[4] - (top - edge)
                        * root:GetEffectiveScale() / GameTooltip:GetEffectiveScale()) < 0.01
                    if level and p.TOPRIGHT and at[1] == root and at[2] == "TOPLEFT" and at[3] == -4 then
                        left = left + 1
                    elseif level and p.TOPLEFT and at[1] == root and at[2] == "TOPRIGHT" and at[3] == 4 then
                        right = right + 1
                    else
                        local name = c.label and c.label.text or c:GetName() or "?"
                        table.insert(other, tostring(name) .. ":" .. tostring(GameTooltip.anchor))
                    end
                end
                if c.scripts and c.scripts.OnLeave then c.scripts.OnLeave(c) end
            end
            if c.shown then walk(c) end
        end
    end
    if owned then walk({ all_ = (function() local t = {} for c in pairs(owned) do t[#t + 1] = c end return t end)() })
    else walk(from or root) end
    UIParent.GetWidth = width
    print(tag, "facing " .. middle, "at its left=" .. left, "at its right=" .. right,
        "elsewhere: " .. (#other > 0 and table.concat(other, ",") or "none"))
end
-- A secure button over a region by numbers, as the windows' cast layers
-- set them (window/shell.lua, Over): "over" when it covers the region and
-- is anchored to its layer alone; "anchored" when it rests on anything else
-- (which would make that, and the window, protected); "off" when misplaced.
function harnessOver(b, region)
    if b.all then return "anchored" end
    for _, p in pairs(b.points) do
        if p[1] ~= b.parent then return "anchored" end
    end
    local function near(a, c) return a and c and math.abs(a - c) < 0.01 end
    return (near(b:GetLeft(), region:GetLeft()) and near(b:GetBottom(), region:GetBottom())
        and near(b.w, region:GetWidth()) and near(b.h, region:GetHeight())) and "over" or "off"
end
-- a drag: StartMoving takes the frame, StopMovingOrSizing leaves it where
-- harnessDropAt says, on UIParent, as the game re-anchors a moved frame
function Region:StartMoving() self.isMoving = true end
-- the grip: StartSizing takes the corner, StopMovingOrSizing leaves the
-- size harnessSizeTo says
function Region:StartSizing(point) self.isSizing = point end
function Region:StopMovingOrSizing()
    if self.isSizing then
        self.isSizing = nil
        if harnessSizeTo then self:SetSize(harnessSizeTo[1], harnessSizeTo[2]) end
        return
    end
    if not self.isMoving then return end
    self.isMoving = nil
    local at = harnessDropAt or { "TOPLEFT", "TOPLEFT", 0, 0 }
    self:ClearAllPoints()
    self:SetPoint(at[1], UIParent, at[2], at[3], at[4])
end
function Region:SetPropagateKeyboardInput(v) self.propagate = v end
function Region:EnableKeyboard(on) self.keyboard = on end
-- a text wraps until told not to, as in the game
function Region:SetWordWrap(on) self.wrap = on end
function Region:CanWordWrap() return self.wrap ~= false end
function Region:SetJustifyH(j) self.justifyH = j end
function Region:GetJustifyH() return self.justifyH or "CENTER" end

-- ------------------------------------------------------------ the API
UIParent = new("Frame", nil, "UIParent")
UIParent.isScreen = true
function UIParent:GetHeight() return 768 end
-- Edit Mode tells addons it opened and closed through EventRegistry (movers.lua)
EventRegistry = { registered = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self.registered[event] = self.registered[event] or {}
    table.insert(self.registered[event], { fn, owner })
end
function EventRegistry:TriggerEvent(event, ...)
    for _, r in ipairs(self.registered[event] or {}) do r[1](r[2], ...) end
end
Minimap = new("Frame", UIParent, "Minimap")
-- the quest, bonus-objective and dig-site rings at the round map's edge
Minimap.blobRing = {}
for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
    for _, what in ipairs({ "Scalar", "Alpha" }) do
        Minimap["Set" .. kind .. "BlobRing" .. what] = function(self, v) self.blobRing[kind .. what] = v end
    end
end
local function BlobRing()
    local out = {}
    for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
        for _, what in ipairs({ "Scalar", "Alpha" }) do
            table.insert(out, kind .. what .. "=" .. tostring(Minimap.blobRing[kind .. what]))
        end
    end
    return table.concat(out, " ")
end
-- what addons and Blizzard hang on the minimap: three LibDBIcon buttons (one
-- hidden by its addon), a button of an addon's own, Blizzard's tracking,
-- and two map pins (one unnamed)
local function MinimapButton(name, size, shown)
    local b = new("Button", Minimap, name)
    b:SetSize(size, size)
    b:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
    b.shown = shown ~= false
    return b
end
MinimapButton("LibDBIcon10_Zeta", 31)
MinimapButton("LibDBIcon10_Alpha", 31, false)
MinimapButton("LibDBIcon10_MapPins", 31)              -- an addon whose name looks like a pin's
MinimapButton("BagnonMinimapButton", 33)
MinimapButton("MiniMapTracking", 32)
MinimapButton("HandyNotesPin3", 12)
MinimapButton(nil, 12)
-- HereBeDragons' pins, named like buttons: Questie's quest icons, one shown
-- and one its addon has removed (hidden, still on the minimap), and a pin
-- placed after the drawer is built
do
    local hbd = { minimapPins = {} }
    function hbd:AddMinimapIconMap(_, icon) icon:SetParent(Minimap); self.minimapPins[icon] = {} end
    function hbd:AddMinimapIconWorld(ref, icon) self:AddMinimapIconMap(ref, icon) end
    function hbd:RemoveMinimapIcon(_, icon) self.minimapPins[icon] = nil; icon:Hide() end
    local libs = { ["HereBeDragons-Pins-2.0"] = hbd }
    function LibStub(major) return libs[major] end
    hbd:AddMinimapIconMap("Questie", MinimapButton("QuestieFrame1", 16))
    local gone = MinimapButton("QuestieFrame2", 16)
    hbd:AddMinimapIconMap("Questie", gone)
    hbd:RemoveMinimapIcon("Questie", gone)
    hbd:AddMinimapIconMap("Questie", gone)
    hbd:RemoveMinimapIcon("Questie", gone)
    QuestieLate = function() hbd:AddMinimapIconWorld("Other", MinimapButton("OtherAddonIcon7", 16)) end
end
MinimapCluster = new("Frame", UIParent, "MinimapCluster")
GameTooltip = new("Frame", UIParent, "GameTooltip")
-- an owner, and the clear every SetOwner fires (core.lua's ns.Tip hooks it)
function GameTooltip:SetOwner(owner, anchor)
    self.owner, self.anchor = owner, anchor
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
end
function GameTooltip:GetOwner() return self.owner end
-- the anchor the game applies again as the text fills it, changed alone
function GameTooltip:SetAnchorType(anchor) self.anchor = anchor end
-- the game's default place: owned with no anchor, then the screen's corner
function GameTooltip_SetDefaultAnchor(tooltip, parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 64)
end
function GameTooltip:ClearLines()
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
end
-- the spec ns.Tip handed over, as its parts' roles: what mdlui_Tooltips draws
function tipSpec()
    local s = Medalluin_TooltipSpec and Medalluin_TooltipSpec(GameTooltip)
    if not s then return "spec=none" end
    local parts = {}
    for _, p in ipairs(s) do
        if p and p[1] == "bar" then table.insert(parts, string.format("bar %s/%s", tostring(p[2]), tostring(p[3])))
        elseif p and p[1] == "item" then table.insert(parts, "item icon=" .. tostring(p[2]) .. " right=" .. p[4])
        elseif p then table.insert(parts, p[1]) end
    end
    return "spec=" .. tostring(s.title) .. " [" .. table.concat(parts, ",") .. "]"
end
PlayerFrame, TargetFrame = new("Frame", UIParent), new("Frame", UIParent)
-- Blizzard's buff and debuff rows, top right (Forever and retail)
BuffFrame, DebuffFrame = new("Frame", UIParent, "BuffFrame"), new("Frame", UIParent, "DebuffFrame")
MainMenuBar = new("Frame", UIParent, "MainMenuBar")

-- what IsActionInRange answers, by action: nil (nothing to check) unless set
local rangeOf = {}
local manaShort = {}        -- actions short of mana: not usable, noMana
-- Blizzard's range mark: the hotkey's colour (ActionButton.lua)
function ActionButton_UpdateRangeIndicator(self, checksRange, inRange)
    if checksRange and not inRange then self.HotKey:SetVertexColor(1, 0.1, 0.1)
    else self.HotKey:SetVertexColor(0.6, 0.6, 0.6) end
end
-- Blizzard's action buttons, with the parts bars/buttons.lua restyles.
local function ActionButton(name, parent, action)
    local b = new("CheckButton", parent, name)
    b.w, b.h, b.action = 36, 36, action
    -- Blizzard's own buttons are tainted the same way as the template's
    -- (harnessSecure, below)
    function b:SetAttribute(k, v)
        Region.SetAttribute(self, k, v)
        if not harnessSecure then self.taintedBy = k end
    end
    b.icon = new("Texture", b, name .. "Icon")
    for _, part in ipairs({ "Count", "HotKey", "Name", "Border", "Flash" }) do
        b[part] = new("FontString", b, name .. part)
    end
    b.cooldown = new("Cooldown", b, name .. "Cooldown")
    b.showgrid = 1
    function b:GetShowGrid() return self.showgrid and self.showgrid > 0 end
    -- Blizzard's usable colours, as ActionBarActionButtonMixin:UpdateUsable
    function b:UpdateUsable()
        local usable, noMana = (C_ActionBar and C_ActionBar.IsUsableAction or IsUsableAction)(self.action)
        if usable then self.icon:SetVertexColor(1, 1, 1)
        elseif noMana then self.icon:SetVertexColor(0.5, 0.5, 1)
        else self.icon:SetVertexColor(0.4, 0.4, 0.4) end
    end
    function b:HasAction() return HasAction and HasAction(self.action) or false end
    return b
end
-- Classic-era micro buttons (no Guild or LFG) and the bag buttons.
for _, n in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
    "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton" }) do
    local b = new("Button", MainMenuBar, n)
    b.w, b.h = 28, 58
end
MicroButtonPortrait = new("Texture", CharacterMicroButton, "MicroButtonPortrait")
QueueStatusButton = new("Button", UIParent, "QueueStatusButton")
QueueStatusButton.w, QueueStatusButton.h = 32, 32
QueueStatusButton.shown = false
QueueStatusButton.Eye = new("Frame", QueueStatusButton, "QueueStatusButtonEye")
for _, n in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot" }) do
    local b = new("CheckButton", MainMenuBar, n)
    b.w, b.h = 37, 37
    b.icon = new("Texture", b, n .. "IconTexture")
end
MainMenuBarBackpackButton.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
KeyRingButton = new("CheckButton", MainMenuBar, "KeyRingButton")
for i = 1, 12 do
    ActionButton("ActionButton" .. i, MainMenuBar, i)
    ActionButton("MultiBarBottomLeftButton" .. i, MainMenuBar, 60 + i)
    ActionButton("MultiBarBottomRightButton" .. i, MainMenuBar, 48 + i)
end
StanceBar = new("Frame", UIParent, "StanceBar")
PetActionBar = new("Frame", UIParent, "PetActionBar")
for i = 1, 6 do
    ActionButton("StanceButton" .. i, StanceBar, 100 + i)
end
for i = 1, 10 do
    local b = ActionButton("PetActionButton" .. i, PetActionBar, 200 + i)
    -- Blizzard's AutoCastOverlay: the corner brackets and the autocast shine.
    -- The last button's corners have no key, only their atlas, as a template
    -- that names them differently would.
    b = b or _G["PetActionButton" .. i]
    local o = new("Frame", b, nil)
    o.Shine = o:CreateTexture(nil, "OVERLAY")
    o.Shine:SetAtlas("UI-HUD-ActionBar-PetAutoCast-Ants")
    local corners = o:CreateTexture(nil, "OVERLAY")
    corners:SetAtlas("UI-HUD-ActionBar-PetAutoCast-Corners")
    if i < 10 then o.Corners = corners end
    o.cornersTex = corners
    b.AutoCastOverlay = o
end
-- Forever's totem bar (MultiCastActionBarFrame.lua): shown only while the
-- player has a totem element. Three pages of four elements, the summon and
-- recall spells, and the flyout of an element's totems with the arrow that
-- opens it; Blizzard's functions as far as the overhead hooks them.
MultiCastActionBarFrame = new("Frame", UIParent, "MultiCastActionBarFrame")
MultiCastActionBarFrame.shown = false
MultiCastActionBarFrame.currentPage = 1
NUM_MULTI_CAST_PAGES, NUM_MULTI_CAST_BUTTONS_PER_PAGE = 3, 4
for p = 1, 3 do
    local page = new("Frame", MultiCastActionBarFrame, "MultiCastActionPage" .. p)
    page.shown = p == 1
    for i = 1, 4 do
        local n = (p - 1) * 4 + i
        local b = ActionButton("MultiCastActionButton" .. n, page, 132 + n)
        b.overlayTex = new("Texture", b, nil)
    end
end
ActionButton("MultiCastSummonSpellButton", MultiCastActionBarFrame, 150)
ActionButton("MultiCastRecallSpellButton", MultiCastActionBarFrame, 151)
-- MultiCastSpellButton's $parentHighlight: the totem bar's ring, always drawn
for _, n in ipairs({ "MultiCastSummonSpellButton", "MultiCastRecallSpellButton" }) do
    _G[n .. "Highlight"] = new("Texture", _G[n], nil)
end
MultiCastFlyoutFrame = new("Frame", MultiCastActionBarFrame, "MultiCastFlyoutFrame")
MultiCastFlyoutFrame.shown, MultiCastFlyoutFrame.w = false, 32
MultiCastFlyoutFrame.top = new("Texture", MultiCastFlyoutFrame, nil)
MultiCastFlyoutFrame.middle = new("Texture", MultiCastFlyoutFrame, nil)
MultiCastFlyoutFrame.buttons = {}
for i = 1, 3 do
    local b = new("CheckButton", MultiCastFlyoutFrame, "MultiCastFlyoutButton" .. i)
    b.w, b.h = 24, 24
    b.icon = new("Texture", b, nil)
    MultiCastFlyoutFrame.buttons[i] = b
end
MultiCastFlyoutFrameCloseButton = new("Button", MultiCastFlyoutFrame, "MultiCastFlyoutFrameCloseButton")
MultiCastFlyoutFrameCloseButton.normalTexture = new("Texture", MultiCastFlyoutFrameCloseButton, nil)
MultiCastFlyoutFrameOpenButton = new("Button", MultiCastActionBarFrame, "MultiCastFlyoutFrameOpenButton")
MultiCastFlyoutFrameOpenButton.shown = false
MultiCastFlyoutFrameOpenButton.normalTexture = new("Texture", MultiCastFlyoutFrameOpenButton, nil)
function MultiCastFlyoutFrame_ToggleFlyout(self, _, parent)
    if self:IsShown() and self.parent == parent then self:Hide(); return end
    self.parent = parent
    self:SetPoint("BOTTOM", parent, "TOP", 0, 0)
    self:Show()
    self.top:SetTexCoord(0, 1, 0.1, 0.2)
    self.middle:SetTexCoord(0, 1, 0.3, 0.4)
    MultiCastFlyoutFrameCloseButton.normalTexture:SetTexCoord(0, 1, 0.5, 0.6)
    -- an element's: the first clears the slot (a piece of the totem bar), the rest are totems, whole
    for i, b in ipairs(self.buttons) do
        b.spellId = i == 1 and 0 or 8070 + i
        if i == 1 then b.icon:SetTexCoord(0.1, 0.3, 0.5, 0.7) else b.icon:SetTexCoord(0, 1, 0, 1) end
    end
end
function MultiCastFlyoutFrameOpenButton_Show(self, _, parent)
    self.normalTexture:SetTexCoord(0, 1, 0.7, 0.8)
    self.parent = parent
    self:SetParent(parent)
    self:SetPoint("BOTTOM", parent, "TOP", 0, 0)
    self:Show()
end
function ChangeMultiCastActionPage(page)
    MultiCastActionBarFrame.currentPage = page
    for p = 1, 3 do _G["MultiCastActionPage" .. p]:SetShown(p == page) end
end
function MultiCastRecallSpellButton_Update(self) self:SetPoint("LEFT", MultiCastActionBarFrame, "LEFT", 140, 0) end

-- Forever's bar divider (a three-slice of textures) exists only on an Edit
-- Mode client; elsewhere it raises, as an unknown template does in WoW.
-- Events Forever does not have (BugSack, 2026-11-01): registering one raises
missingEvents = modern and { ROLE_POLL_UPDATE = true, QUEUE_STATUS_UPDATE = true } or {}
local DIVIDER = "HorizontalDividerTemplate"
harnessBarPage = 1      -- bar 1's page, where a button with no page of its own falls back to
function CreateFrame(kind, name, parent, template)
    if template == DIVIDER and not modern then error("unknown template " .. template) end
    local f = new(kind, parent, name)
    f.template = template
    -- a container item button born in combat runs its clicks tainted
    if template == "ContainerFrameItemButtonTemplate" and InCombatLockdown() then f.bornInCombat = true end
    if template == DIVIDER then
        f.template, f.w = template, 12
        for _ = 1, 3 do new("Texture", f) end
    elseif template == "ActionBarButtonTemplate" then
        f.template, f.w, f.h = template, 36, 36
        -- made by an addon, the template's own OnLoad runs in the addon's
        -- execution, and the fields it writes are tainted from birth
        if not harnessSecure then f.taintedBy = "created" end
        -- the game's CalculateAction (C, and Classic's Lua before it): a
        -- button with an ID takes the page from its own "actionpage", else
        -- its parent's (the template sets useparent-actionpage), else bar
        -- 1's; its "action" attribute counts only at ID 0. UpdateAction runs
        -- on every attribute change.
        f.attrs["useparent-actionpage"] = true
        function f:SetAttribute(k, v)
            Region.SetAttribute(self, k, v)
            if not harnessSecure then self.taintedBy = k end
            local id = self:GetID() or 0
            if id > 0 then
                local page = self.attrs.actionpage or self.parent and self.parent.attrs.actionpage
                    or harnessBarPage
                self.action = (page - 1) * 12 + id
            else
                self.action = self.attrs.action
            end
        end
        f.icon = new("Texture", f, (name or "") .. "Icon")
        for _, part in ipairs({ "Count", "HotKey", "Name", "Border", "Flash" }) do
            f[part] = new("FontString", f, (name or "") .. part)
        end
        f.cooldown = new("Cooldown", f, (name or "") .. "Cooldown")
    elseif template == "SecureHandlerStateTemplate" then
        -- a state-<name> attribute runs the _onstate-<name> snippet
        function f:SetAttribute(k, v)
            Region.SetAttribute(self, k, v)
            local state = type(k) == "string" and k:match("^state%-(.+)$")
            local body = state and self.attrs["_onstate-" .. state]
            if body then setfenv(assert(loadstring(body)), harnessSnippetEnv(self, v))() end
        end
    end
    function f:RegisterEvent(e)
        -- an event the client does not have raises, as in WoW
        if missingEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"", 2) end
        events[e] = events[e] or {}
        if not listening(self, e) then table.insert(events[e], self) end
    end
    return f
end
-- The macro conditional as the game reads it: the first clause whose every
-- [condition] is in harnessHolds, or the bare fallback.
harnessHolds = {}
function harnessPick(conditional, holds)
    holds = holds or harnessHolds
    for clause in (conditional .. ";"):gmatch("%s*(.-)%s*;") do
        local conds, value = clause:match("^(.*%])%s*(%S+)$")
        if not conds then return clause end
        local ok = true
        for c in conds:gmatch("%[(.-)%]") do ok = ok and holds[c] or false end
        if ok then return value end
    end
end
-- Taint: Medalluin's code is insecure; only the game's own update (stateTick)
-- runs secure. An attribute set on an action button outside it runs the
-- button's OnAttributeChanged tainted, and its clicks are blocked after that
-- (UseAction, BugSack 2026-11-01): the button keeps the attribute's name.
harnessSecure = false
-- The restricted environment a state snippet runs in.
harnessWorld = { vehicle = false, override = false, temp = false, bonus = false }
local function SnippetEnv(self, newstate)
    local w = harnessWorld
    return {
        self = self, newstate = newstate, tonumber = tonumber,
        HasVehicleActionBar = function() return w.vehicle end, GetVehicleBarIndex = function() return 16 end,
        HasOverrideActionBar = function() return w.override end, GetOverrideBarIndex = function() return 18 end,
        HasTempShapeshiftActionBar = function() return w.temp end,
        GetTempShapeshiftBarIndex = function() return 17 end,
        HasBonusActionBar = function() return w.bonus end, GetBonusBarIndex = function() return 7 end,
    }
end
harnessSnippetEnv = SnippetEnv
-- SecureStateDriverManager's resolveDriver: the conditional's state, set
-- only when it differs from the frame's ("nil" is no state).
local drivenFrames = {}
local function Resolve(f, attribute, values)
    local v = harnessPick(values)
    if v == "nil" then v = nil else v = tonumber(v) or v end
    -- the "visibility" state shows or hides the frame itself
    if attribute == "state-visibility" then
        if v == "show" then f:Show() elseif v == "hide" then f:Hide() end
    end
    if v ~= f.attrs[attribute] then
        f:SetAttribute(attribute, v)
        if f.scripts.OnAttributeChanged then f.scripts.OnAttributeChanged(f, attribute, v) end
    end
end
-- RegisterStateDriver applies the state at once, in the caller (tainted)
function RegisterStateDriver(f, state, values)
    f.stateDrivers = f.stateDrivers or {}
    f.stateDrivers[state] = values
    drivenFrames[f] = true
    Resolve(f, "state-" .. state, values)
end
-- The manager's OnUpdate (every 0.2 s): secure.
function stateTick()
    harnessSecure = true
    for f in pairs(drivenFrames) do
        for state, values in pairs(f.stateDrivers or {}) do Resolve(f, "state-" .. state, values) end
    end
    harnessSecure = false
end
function UnregisterStateDriver(f, state)
    if f.stateDrivers then f.stateDrivers[state] = nil end
end
local inCombat = false
function InCombatLockdown() return inCombat end
-- a frame's mouse, and whether it was set during the lockdown (blocked on a
-- protected frame in WoW)
function Region:EnableMouse(on)
    self.mouse = on and true or false
    if inCombat then self.mouseInCombat = true end
end
function Region:IsMouseEnabled() return self.mouse ~= false end
function Region:EnableMouseWheel(on) self.wheel = on and true or false end
-- A secure wrap: the snippet runs before the frame's own script, with the
-- frame as self and the header as owner, in the restricted environment's
-- few functions.
--
-- Frames reach the snippet as handles, and in combat a handle to a frame
-- that is not protected is refused: anchoring a cell to one errors, as the
-- game's did (2026-11-02: the cell was cleared of its points, then refused,
-- and vanished). There is no math library: the snippet has its own.
local function Handle(f)
    if f == nil then return nil end
    local h = { frame = f }
    local protected = type(f.template) == "string" and f.template:match("^Secure") ~= nil
    local function frameOf(rel)
        if type(rel) ~= "table" then return rel end
        if inCombat and not rel.protected then error("Invalid frame handle", 3) end
        return rel.frame
    end
    h.protected = protected
    for _, m in ipairs({ "IsShown", "GetAttribute", "SetWidth", "ClearAllPoints" }) do
        h[m] = function(self, ...) return f[m](f, ...) end
    end
    function h:GetFrameRef(k) return Handle(f:GetFrameRef(k)) end
    function h:SetPoint(p, rel, rp, x, y) return f:SetPoint(p, frameOf(rel), rp, x, y) end
    return h
end
function SecureHandlerWrapScript(f, script, header, pre)
    local old = f.scripts[script]
    f.scripts[script] = function(self, ...)
        local env = {
            self = Handle(self), owner = Handle(header),
            PlayerInCombat = function() return inCombat end,
            newtable = function(...) return { ... } end,
        }
        -- an error in the snippet is reported, and the frame's own script still runs
        local ok, err = pcall(setfenv(assert(loadstring(pre)), env))
        if not ok then print("secure snippet error", err) end
        if old then return old(self, ...) end
    end
end
-- the player in combat, and their threat situation: nil off every threat
-- table, 0 to 3 on one (1 is "higher threat than the tank")
local threatOf = nil
function UnitAffectingCombat(u) return u == "player" and inCombat end
function UnitThreatSituation(u) if u == "player" then return threatOf end end
-- The game's unit watch runs every frame, not once: a watched button whose
-- unit does not exist is hidden again however it was shown. watchTick() is
-- that frame; a stub does not make a unit exist.
--
-- The manager walks its list of watched frames and shows or hides each from
-- inside the walk. Registering or letting go of a watch from inside it
-- (a layout run from a cell's OnShow) changes the list mid-walk; in game
-- that froze the client into a disconnect (2026-11-03), so here it raises.
local watchedFrames = {}
local watchWalking = false
harnessWatchCalls = 0      -- RegisterUnitWatch and UnregisterUnitWatch, counted
local function watchListChanged(what)
    harnessWatchCalls = harnessWatchCalls + 1
    if watchWalking then error(what .. " inside the unit watch's walk over its frames", 3) end
end
function harnessWatchWalking() return watchWalking end
function RegisterUnitWatch(f)
    watchListChanged("RegisterUnitWatch")
    f.watched = true
    watchedFrames[f] = true
    if f.unit and not UnitExists(f.unit) and not f.stub then f:Hide() end
end
function UnregisterUnitWatch(f)
    watchListChanged("UnregisterUnitWatch")
    f.watched = false
    watchedFrames[f] = nil
end
-- the player's stances and pet bar: none unless a pass says so
local shapeshiftForms, petBar = 0, false
function GetNumShapeshiftForms() return shapeshiftForms end
function PetHasActionBar() return petBar end
local function watchTick()
    watchWalking = true
    local ok, err = pcall(function()
        for f in pairs(watchedFrames) do
            -- as the game's: a frame shown or hidden only when that changes
            local want = UnitExists(f.unit) and true or false
            if f.watched and f.unit and (f.shown and true or false) ~= want then f:SetShown(want) end
        end
    end)
    watchWalking = false
    if not ok then print("unit watch error", err) end
end
-- The next frame: the unit watch, then what was asked to run on it (the
-- overhead's layout a cell asked for: console/overhead.lua's soon).
function harnessNextFrame()
    watchTick()
    local soon = harnessNS and harnessNS.overheadSoon
    if soon and soon.shown and soon.scripts.OnUpdate then soon.scripts.OnUpdate(soon, 0) end
end
function IsInGroup() return grouped end
-- the group's leader: the second member, so the player's frame has none
harnessLeader = "party2"
-- (on "modern", a unit the pass names answers with a secret)
function UnitIsGroupLeader(u)
    if modern and u == harnessSecretLeader then return secret() end
    return grouped and u == harnessLeader
end
-- each console button's crown: worn or not, and where
function HarnessCrowns(tag)
    local o = {}
    for _, u in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
        local b = harnessNS.units[u]
        local f = b and b.leaderFrame
        if f then
            local p, rel, rp, x, y = f:GetPoint(1)
            table.insert(o, string.format("%s=%s@%s:%s:%s:%s,%s", u, f.shown and "crown" or "-", tostring(p),
                rel == b and "self" or rel and (rel.name or "?") or "-", tostring(rp), tostring(x), tostring(y)))
        end
    end
    print(tag, table.concat(o, " "))
end
-- a raid: none, unless the widgets pass makes one (widgets/raid.lua)
raidRoster = {}
function IsInRaid() return #raidRoster > 0 end
-- the instance the player stands in: "none", "party", "raid", "pvp" (a battleground), "arena"
harnessInstance = "none"
function IsInInstance() return harnessInstance ~= "none", harnessInstance end
function GetNumGroupMembers() return #raidRoster > 0 and #raidRoster or grouped and 3 or 0 end
function GetRaidRosterInfo(i)
    local m = raidRoster[i]
    if m then return m[1], 0, m[2] end
end
local hasTarget = true
local targetHostile = true
function UnitCanAttack(_, u) return u == "target" and hasTarget and targetHostile end
function UnitExists(u) return u == "player" or (u == "target" and hasTarget) or (grouped and u:match("^party[12]$")) end
function UnitName(u) return ({ player = "Ahrymx", target = "Defias Pillager", party1 = "Thalric",
    party2 = "Okun", npc = "Karen Taylor" })[u] end
-- a group's classes, by name: the loot log asks UnitClass for a name
local classOf = { Mira = "PRIEST", Thalen = "MAGE", Aldren = "WARRIOR" }
function UnitClass(u) local c = classOf[u] or class; return c, c end
function UnitIsPlayer(u) return u ~= "target" end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function UnitReaction() return 2 end
function UnitHealth() return 82 end
function UnitHealthMax() return 100 end
function UnitPower() return 60 end
function UnitPowerMax(_, kind) return kind == 4 and 5 or 100 end
function GetComboPoints() return 3 end
local now = 100
function GetTime() return now end
-- the game's bindings, key -> command: the number keys on action bar 1
bindings, bindingSaves = {}, {}
for i = 1, 12 do bindings[tostring(i)] = "ACTIONBUTTON" .. i end
-- a key bound to the centre grid's old buttons, before it took Action bar 7's
bindings.G = "CLICK MedalluinBar7Button3:LeftButton"
function GetBindingKey(action)
    local keys = {}
    for k, c in pairs(bindings) do if c == action then table.insert(keys, k) end end
    table.sort(keys)
    return unpack(keys)
end
function SetBinding(key, command)
    if inCombat then error("SetBinding in combat") end
    bindings[key] = command
    return true
end
function GetBindingAction(key) return bindings[key] or "" end
bindingSet = 2
function GetCurrentBindingSet() return bindingSet end
function SaveBindings(set) table.insert(bindingSaves, set) end
function GetBindingText(key) return key end
-- override bindings: key -> owner's name:button, ! when priority
overrides, overrideSets = {}, 0
function SetOverrideBindingClick(owner, prio, key, name, button)
    if inCombat then error("SetOverrideBindingClick in combat") end
    overrideSets = overrideSets + 1
    overrides[key] = name .. ":" .. tostring(button) .. (prio and "!" or "")
end
-- (clearing is allowed: PLAYER_REGEN_DISABLED's handlers run before the lockdown)
function ClearOverrideBindings(owner)
    for k in pairs(overrides) do overrides[k] = nil end
end
local modsDown = {}
function IsAltKeyDown() return modsDown.ALT end
function IsControlKeyDown() return modsDown.CTRL end
function IsShiftKeyDown() return modsDown.SHIFT end
function hooksecurefunc(t, k, f)
    if type(t) == "string" then t, k, f = _G, t, k end
    local old = t[k]
    -- the hook runs after, and the original's results are the call's, as in WoW
    t[k] = function(...)
        local results = { old(...) }
        f(...)
        return unpack(results)
    end
end
function GetActionCooldown(a) if a == 63 then return 90, 33, 1 end return 0, 0, 1 end
function HasAction() return true end
function IsUsableAction(a) return not manaShort[a], manaShort[a] or false end
function IsActionInRange(a) return rangeOf[a] end
local casting, castUnit = false, "player"
FAILED, INTERRUPTED = "Failed", "Interrupted"
-- Frostbolt, a second into two (times in ms; GetTime is 100), cast id 7, by
-- castUnit
function UnitCastingInfo(u)
    if casting and u == castUnit then return "Frostbolt", nil, nil, 99000, 101000, false, 7 end
end
function SetPortraitTexture(t, u) t.portrait = u end
function GetContainerNumSlots(bag) return bag == 0 and 16 or 14 end
function GetContainerNumFreeSlots(bag) return bag == 0 and 4 or 8, 0 end
function GetInventoryItemDurability(i) if i == 5 then return 30, 100 end end
function GameTime_GetTime() return "11:39" end
function UnitChannelInfo() end
local catForm = false
function UnitPowerType() return catForm and 3 or 0 end
-- Forever's swing timer API (Blizzard_SwingTimer); retail has none
C_SwingTimer = {}
local isDragonriding = false
local vigorCharges = 6
local vigorStart = 0
local vigorDur = 5
local vigorModRate = 1
function IsMounted() return isDragonriding end
function GetSpellCharges(id)
    if not isDragonriding then return nil end
    if id == 372610 or id == 372608 then
        return vigorCharges, 6, vigorStart, vigorDur, vigorModRate
    end
end
C_PlayerInfo = {
    GetGlidingInfo = function()
        return isDragonriding, isDragonriding, isDragonriding and 65 or 0
    end,
}
C_Spell = {
    GetSpellCharges = function(id)
        if not isDragonriding then return nil end
        if id == 372610 or id == 372608 then
            return {
                currentCharges = vigorCharges,
                maxCharges = 6,
                cooldownStartTime = vigorStart,
                cooldownDuration = vigorDur,
                chargeModRate = vigorModRate,
            }
        end
    end,
}
function UnitLevel() return 30 end
-- the realm, a player's full name, and what the chat can learn of a speaker:
-- a line's sender (line ID -> GUID), a GUID's class and level, the guild,
-- friends and /who (strips/chat.lua's names)
function GetNormalizedRealmName() return "Medalluin" end
function UnitFullName(u) return UnitName(u), nil end
chatSenders, guidInfo, harnessGuild, harnessFriends, harnessWho = {}, {}, {}, {}, {}
C_ChatInfo = { GetChatLineSenderGUID = function(line) return chatSenders[assert(line, "chatLine")] end }
function GetPlayerInfoByGUID(guid)
    -- a secret GUID: allowed, and every answer secret
    if isSecret(guid) then return secret(), secret(), secret(), secret(), secret(), secret(), secret(), secret() end
    local i = guidInfo[guid]
    if i then return i[1], i[1], "Human", "Human", 2, "?", "", i[2] end
end
function GetNumGuildMembers() return #harnessGuild end
function GetGuildRosterInfo(i) local m = harnessGuild[i]; return m[1], "Member", 1, m[2] end
C_FriendList = {
    GetNumFriends = function() return #harnessFriends end,
    GetFriendInfoByIndex = function(i) return harnessFriends[i] end,
    GetNumWhoResults = function() return #harnessWho end,
    GetWhoInfo = function(i) return harnessWho[i] end,
}
-- the target an elite, its level coloured by how hard it is
function UnitClassification(u) return u == "target" and "elite" or "normal" end
function GetQuestDifficultyColor() return { r = 1, g = 0.82, b = 0 } end
function UnitXP() return 650 end
function UnitXPMax() return 1000 end
function GetXPExhaustion() return 200 end
function GetMaxPlayerLevel() return 60 end
function GetWatchedFactionInfo() return "Stormwind", 5, 0, 6000, 2200 end
function BreakUpLargeNumbers(n) return tostring(n) end
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.96, g = 0.55, b = 0.73 } end })
FACTION_BAR_COLORS = setmetatable({}, { __index = function() return { r = 0.8, g = 0.3, b = 0.22 } end })
PowerBarColor = setmetatable({}, { __index = function() return { r = 0, g = 0, b = 1 } end })
wipe = function(t) for k in pairs(t) do t[k] = nil end end

-- the loot log's world: the client's chat strings (enUS), a clock, a zone
LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %s.", "You receive loot: %sx%d."
LOOT_ITEM, LOOT_ITEM_MULTIPLE = "%s receives loot: %s.", "%s receives loot: %sx%d."
CURRENCY_GAINED, CURRENCY_GAINED_MULTIPLE = "You receive currency: %s.", "You receive currency: %s x%d."
YOU_LOOT_MONEY, YOU_LOOT_MONEY_GUILD = "You loot %s", "You loot %s (%s deposited to guild bank)"
LOOT_MONEY_SPLIT, LOOT_MONEY_SPLIT_GUILD = "Your share of the loot is %s.",
    "Your share of the loot is %s. (%s deposited to guild bank)"
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
local clock = "21:02"
function date() return clock end
local zone = "Black Temple"
function GetRealZoneText() return zone end
local subzone = "Illidari Training Grounds"
function GetMinimapZoneText() return subzone end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
ITEM_QUALITY_COLORS = {}
for q, c in pairs({ [0] = { 0.62, 0.62, 0.62, "9d9d9d" }, { 1, 1, 1, "ffffff" }, { 0.12, 1, 0, "1eff00" },
    { 0, 0.44, 0.87, "0070dd" }, { 0.64, 0.21, 0.93, "a335ee" } }) do
    ITEM_QUALITY_COLORS[q] = { r = c[1], g = c[2], b = c[3], hex = "|cff" .. c[4] }
end
format, unpack = string.format, unpack

-- Blizzard's chat, as FloatingChatFrame.xml builds it: ten windows, the
-- first two docked (General, the combat log) and the rest floating, each
-- with the textures FCF fades, a size grip, a scroll bar, an edit box with
-- its art and its focus art, and a tab with its nine slices.
CHAT_FRAME_TEXTURES = {}
for _, part in ipairs({ "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture",
    "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }) do
    table.insert(CHAT_FRAME_TEXTURES, part)
    table.insert(CHAT_FRAME_TEXTURES, "ButtonFrame" .. part)
end
NUM_CHAT_WINDOWS, CHAT_FRAMES = 10, {}
local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }
local function ChatWindow(i)
    local name = "ChatFrame" .. i
    local f = new("ScrollingMessageFrame", UIParent, name)
    f.w, f.h = 430, 120
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32 + 40 * i, 95)
    for _, part in ipairs(CHAT_FRAME_TEXTURES) do new("Texture", f, name .. part) end
    f.Background = _G[name .. "Background"]
    -- over the frame and its scroll bar (FloatingChatFrame.lua's
    -- UpdateBackgroundAnchors, with a 16 wide bar)
    f.Background:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 3)
    f.Background:SetPoint("TOPRIGHT", f, "TOPRIGHT", 7 + 16, 3)
    -- room for the button column at the left (FloatingChatFrame.xml)
    f.clampInsets = { -35, 35, 38, -50 }
    function f.SetClampRectInsets(self, ...) self.clampInsets = { ... } end
    function f.GetClampRectInsets(self) return unpack(self.clampInsets) end
    f.ResizeButton = new("Button", f, name .. "ResizeButton")
    f.ScrollBar = new("Frame", f)
    f.ScrollBar.w = 8
    f.ScrollBar:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
    f.ScrollBar:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0)
    local box = new("EditBox", f, name .. "EditBox")
    box.w, box.h = 5, 32
    box.altArrows = true                    -- the template's ignoreArrows
    f.said = {}
    function f:AddMessage(text, ...) table.insert(self.said, { text = text, n = select("#", ...), r = ... }) end
    box:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -5, -2)
    box:SetPoint("RIGHT", f.ScrollBar, "RIGHT", 8, 0)
    for _, k in ipairs({ "Left", "Mid", "Right" }) do new("Texture", box, name .. "EditBox" .. k) end
    for _, k in ipairs({ "focusLeft", "focusMid", "focusRight" }) do
        box[k] = new("Texture", box)
        box[k].shown = false
    end
    f.editBox = box
    local tab = new("Button", UIParent, name .. "Tab")
    for _, k in ipairs(TAB_ART) do tab[k] = new("Texture", tab) end
    tab.w, tab.h = 60, 32
    tab.Text = new("FontString", tab)
    tab.Text:SetText(i == 1 and "General" or i == 2 and "Combat Log" or ("Chat " .. i))
    tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -5)     -- under the pill's middle
    table.insert(CHAT_FRAMES, name)
    return f
end
for i = 1, NUM_CHAT_WINDOWS do ChatWindow(i) end
GENERAL_CHAT_DOCK = new("Frame", UIParent, "GeneralDockManager")
GENERAL_CHAT_DOCK.h = 26
-- along the top of ChatFrame1's background, which runs past its right
-- edge (FCFDock_SetPrimary: two SetPoints, no ClearAllPoints)
local function dockAnchor()
    GENERAL_CHAT_DOCK:SetPoint("BOTTOMLEFT", ChatFrame1.Background, "TOPLEFT")
    GENERAL_CHAT_DOCK:SetPoint("BOTTOMRIGHT", ChatFrame1.Background, "TOPRIGHT")
end
dockAnchor()
local tabsFitted = 0
-- a tab rests faded until the mouse comes (FloatingChatFrame.lua's values)
CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA, CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 1.0, 0.4
CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA, CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = 1.0, 1.0
CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA, CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0.6, 0.2
function FCFTab_UpdateAlpha(f)
    local selected = not f.isDocked or f == FCFDock_GetSelectedWindow()
    _G[f.name .. "Tab"]:SetAlpha(selected and CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA or CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA)
end
-- the docked tabs in a line on the dock's foot (FCFDock_UpdateTabs)
function FCFDock_UpdateTabs()
    tabsFitted = tabsFitted + 1
    local prev
    for _, name in ipairs(CHAT_FRAMES) do
        if _G[name].isDocked then
            FCFTab_UpdateAlpha(_G[name])
            local t = _G[name .. "Tab"]
            t:ClearAllPoints()
            if prev then
                t:SetPoint("LEFT", prev, "RIGHT", 1, 0)
            else
                t:SetPoint("BOTTOMLEFT", GENERAL_CHAT_DOCK, "BOTTOMLEFT")
            end
            prev = t
        end
    end
end
local selectedChat = ChatFrame1
function FCFDock_GetSelectedWindow() return selectedChat end
function FCFTab_UpdateColors(tab, selected)
    for _, k in ipairs({ "ActiveLeft", "ActiveMiddle", "ActiveRight" }) do tab[k]:SetShown(selected) end
end
function FCF_DockFrame(f)
    f.isDocked = true
    f:ClearAllPoints()
    f:SetAllPoints(ChatFrame1)
end
function FCF_UnDockFrame(f)
    f.isDocked = nil
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
function FCF_OpenTemporaryWindow()
    local f = ChatWindow(#CHAT_FRAMES + 1)
    FCF_DockFrame(f)
    return f
end
ChatFrame1.isDocked = true
FCF_DockFrame(ChatFrame2)
FCFDock_UpdateTabs()
tabsFitted = 0
-- ChatFrame1's button column, where FCF_SetButtonSide puts it on the left
-- (its background's corners, less 3, are the frame's less 5), and the alert
-- frame the friends toast stacks on, 27 above it
ChatFrame1.buttonFrame = new("Frame", ChatFrame1, "ChatFrame1ButtonFrame")
ChatFrame1.buttonFrame.w = 29
ChatFrame1.buttonFrame:SetPoint("TOPRIGHT", ChatFrame1, "TOPLEFT", -5, 0)
ChatFrame1.buttonFrame:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMLEFT", -5, 0)
local function alertAnchor() ChatAlertFrame:SetPoint("BOTTOMLEFT", ChatFrame1.buttonFrame, "TOPLEFT", -1, 27) end
ChatAlertFrame = new("Frame", UIParent, "ChatAlertFrame")
ChatAlertFrame.w, ChatAlertFrame.h = 10, 10
-- counts its moves: Blizzard re-stacks the friends toast on every one
ChatAlertFrame.moves = 0
function ChatAlertFrame:SetPoint(...)
    self.moves = self.moves + 1
    return Region.SetPoint(self, ...)
end
alertAnchor()
QuickJoinToastButton = new("Button", UIParent, "QuickJoinToastButton")
QuickJoinToastButton.w, QuickJoinToastButton.h = 32, 32
-- stacked on the alert frame: above it, as its subsystems are
local function toastAnchor()
    QuickJoinToastButton:ClearAllPoints()
    -- not flush: the in-game toast stood a little high on it
    QuickJoinToastButton:SetPoint("BOTTOMLEFT", ChatAlertFrame, "TOPLEFT", 0, 2)
end
toastAnchor()
QuickJoinToastButton.FriendsButton = new("Texture", QuickJoinToastButton)
QuickJoinToastButton.QueueButton = new("Texture", QuickJoinToastButton)
QuickJoinToastButton.FriendCount = new("FontString", QuickJoinToastButton)
QuickJoinToastButton.FriendCount:SetPoint("BOTTOM", QuickJoinToastButton, "BOTTOM", 0, -4)
QuickJoinToastButton:SetNormalTexture("friends")
-- Blizzard's buttons in the column: channels and the
-- two voice toggles (shown with voice) down from its top, the menu at its
-- foot; their art as FloatingChatFrame.xml's
for _, n in ipairs({ "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "ChatFrameMenuButton" }) do
    local b = new("Button", ChatFrame1.buttonFrame, n)
    b.w, b.h = 26, 26
    b:SetNormalTexture(n .. "-up")
    b:SetPushedTexture(n .. "-down")
    b:SetHighlightTexture("hilight")
    b.Icon = new("Texture", b)
end
ChatFrameChannelButton:SetPoint("TOP", ChatFrame1.buttonFrame, "TOP")
ChatFrameToggleVoiceDeafenButton:SetPoint("TOP", ChatFrameChannelButton, "BOTTOM")
ChatFrameToggleVoiceMuteButton:SetPoint("TOP", ChatFrameToggleVoiceDeafenButton, "BOTTOM")
ChatFrameToggleVoiceDeafenButton.shown, ChatFrameToggleVoiceMuteButton.shown = false, false
ChatFrameMenuButton:SetPoint("BOTTOM", ChatFrame1.buttonFrame, "BOTTOM")

-- ------------------------------------------------------------ modern
CastingBarFrame = new("Frame", UIParent, "CastingBarFrame")
if modern then
    CastingBarFrame = nil
    PlayerCastingBarFrame = new("Frame", UIParent, "PlayerCastingBarFrame")
    MainMenuBar = nil                                   -- Forever has none
    -- the XP and reputation bars: two containers in their manager, each
    -- finding the manager as its parent, as Edit Mode does on retail
    StatusTrackingBarManager = new("Frame", UIParent, "StatusTrackingBarManager")
    function StatusTrackingBarManager.CheckForLayoutChange() end
    for _, n in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local c = new("Frame", StatusTrackingBarManager, n)
        function c.UpdateShownState(self) self:GetParent():CheckForLayoutChange() end
    end
    -- the action buttons sit in containers on their bars; their art pass
    -- puts atlases on the normal and on whatever the pushed texture is
    MainActionBar = new("Frame", UIParent, "MainActionBar")
    -- the page arrows and number, on the bar's left at an icon-size scale
    local pager = new("Frame", MainActionBar)
    pager.w, pager.h, pager.scale = 17, 34, 0.9
    pager:SetPoint("BOTTOMRIGHT", MainActionBar, "BOTTOMLEFT", -4, 9)
    pager.Text, pager.UpButton, pager.DownButton = new("FontString", pager), new("Button", pager), new("Button", pager)
    pager.Text:SetText("1")
    MainActionBar.ActionBarPageNumber = pager
    -- the leave-vehicle button, on the bar and hidden until a vehicle can be
    -- left: Blizzard's XML crops its normal and pushed art and gives it a
    -- square highlight
    MainMenuBarVehicleLeaveButton = new("Button", MainActionBar, "MainMenuBarVehicleLeaveButton")
    MainMenuBarVehicleLeaveButton.w, MainMenuBarVehicleLeaveButton.h = 32, 32
    MainMenuBarVehicleLeaveButton.shown = false
    MainMenuBarVehicleLeaveButton.level = 70
    MainMenuBarVehicleLeaveButton:SetPoint("BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", 0, 0)
    for state, file in pairs({ Normal = "UI-Vehicles-Button-Exit-Up", Pushed = "UI-Vehicles-Button-Exit-Down" }) do
        MainMenuBarVehicleLeaveButton["Set" .. state .. "Texture"](MainMenuBarVehicleLeaveButton,
            "Interface\\Vehicles\\" .. file)
        MainMenuBarVehicleLeaveButton["Get" .. state .. "Texture"](MainMenuBarVehicleLeaveButton)
            :SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    end
    MainMenuBarVehicleLeaveButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    MultiBarBottomLeft = new("Frame", UIParent, "MultiBarBottomLeft")
    MultiBarBottomRight = new("Frame", UIParent, "MultiBarBottomRight")
    -- Action bar 7, hidden by default: its buttons made by Blizzard's own
    -- OnLoad (secure), on page 14 by their bar
    MultiBar6 = new("Frame", UIParent, "MultiBar6")
    MultiBar6.shown = false
    MultiBar6.attrs.actionpage = 14
    MultiBar6.actionButtons = {}
    harnessSecure = true
    for i = 1, 12 do
        local b = CreateFrame("CheckButton", "MultiBar6Button" .. i, MultiBar6, "ActionBarButtonTemplate")
        b:SetID(i)
        b.bar, b.buttonType = MultiBar6, "MULTIACTIONBAR6BUTTON"
        b:SetAttribute("useparent-actionpage", true)
        MultiBar6.actionButtons[i] = b
    end
    harnessSecure = false
    for _, bar in ipairs({ { MainActionBar, "ActionButton" }, { MultiBarBottomLeft, "MultiBarBottomLeftButton" },
        { MultiBarBottomRight, "MultiBarBottomRightButton" } }) do
        for i = 1, 12 do
            local b = _G[bar[2] .. i]
            b.parent, b.bar = new("Frame", bar[1]), bar[1]
            b.w, b.h, b.scale = 45, 45, 0.9      -- Edit Mode's icon size at 90%
            b.NormalTexture = new("Texture", b)
            b.normalTex, b.pushedTex = b.NormalTexture, new("Texture", b)
            b.SlotArt, b.SlotBackground, b.NewActionTexture = new("Texture", b), new("Texture", b), new("Texture", b)
            b.SpellHighlightTexture = new("Texture", b)
            function b:UpdateButtonArt()
                self:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
                self:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
            end
        end
    end
    function ActionButton_UpdateCooldownNumberHidden(btn) btn.cooldown:SetHideCountdownNumbers(true) end

    -- the micro menu in Forever's order; Help is hidden there. Each button's
    -- SetParent calls MicroMenuContainer:Layout -> MicroMenu:Layout ->
    -- UpdateHelpTicketButtonAnchor -> GetEdgeButton (MainMenuBarMicroButtons.lua:494),
    -- which compares nil with a number once the buttons have left MicroMenu.
    MicroMenuContainer = new("Frame", UIParent, "MicroMenuContainer")
    MicroMenu = new("Frame", MicroMenuContainer, "MicroMenu")
    function MicroMenu:UpdateHelpTicketButtonAnchor()
        local edge
        for _, c in ipairs(self.all_ or {}) do
            if c.parent == self and c.layoutIndex and (not edge or c.layoutIndex < edge) then
                edge = c.layoutIndex
            end
        end
        if edge < 1 then return end
    end
    function MicroMenu:Layout() self:UpdateHelpTicketButtonAnchor() end
    function MicroMenuContainer:Layout() MicroMenu:Layout() end
    MicroButtonPortrait = nil
    for i, n in ipairs({ "Character", "Profession", "Spellbook", "Talent", "Legacy", "QuestLog", "Housing",
        "Guild", "LFD", "Collections", "EJ", "Help", "Store", "MainMenu" }) do
        local b = new("Button", MicroMenu, n .. "MicroButton")
        b.w, b.h, b.layoutIndex = 32, 40, i
        b.shown = n ~= "Help"
        for _, k in ipairs({ "Background", "PushedBackground", "FlashBorder", "Shadow", "PushedShadow", "Portrait" }) do
            b[k] = new("Texture", b)
        end
        b.normalTex, b.pushedTex = new("Texture", b), new("Texture", b)
        b.highlightTex, b.disabledTex = new("Texture", b), new("Texture", b)
        hooksecurefunc(b, "SetParent", function() MicroMenuContainer:Layout() end)
    end
    new("Frame", MicroMenu)                             -- a child that is no button

    -- the bag bar re-places its buttons and re-sets their atlases
    BagsBar = new("Frame", UIParent, "BagsBar")
    CharacterReagentBag0Slot = new("CheckButton", BagsBar, "CharacterReagentBag0Slot")
    CharacterReagentBag0Slot.icon = new("Texture", CharacterReagentBag0Slot)
    local bagButtons = { MainMenuBarBackpackButton, CharacterReagentBag0Slot, KeyRingButton }
    for i = 0, 3 do table.insert(bagButtons, _G["CharacterBag" .. i .. "Slot"]) end
    -- ItemButtons, which are plain buttons: no checked state, the open mark
    -- hidden until a bag opens; the backpack has no icon, its picture is the
    -- normal texture's atlas
    MainMenuBarBackpackButton.icon:SetTexture(nil)
    for _, b in ipairs(bagButtons) do
        b.parent = BagsBar
        b.SetCheckedTexture = false
        b.normalTex, b.pushedTex, b.highlightTex = new("Texture", b), new("Texture", b), new("Texture", b)
        b.SquareMask, b.SlotHighlightTexture = new("MaskTexture", b), new("Texture", b)
        b.SlotHighlightTexture.shown = false
        function b:UpdateTextures()
            self:GetNormalTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
            self:GetPushedTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
            self:GetHighlightTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
            self.SlotHighlightTexture:SetAtlas("bag-border-highlight")
        end
        function b:SetBarExpanded(expanded) self:SetShown(expanded) end
    end
    MainMenuBarBackpackButton.FreeSlots = new("FontString", MainMenuBarBackpackButton)
    function BagsBar:Layout()
        for _, b in ipairs(bagButtons) do
            b:ClearAllPoints()
            b:SetPoint("RIGHT", BagsBar, "LEFT", -1000, 0)
        end
    end
    -- what Blizzard calls: the function as it was at load (GenerateClosure,
    -- EventRegistry), so a hook on the field never hears it
    BagsBar.layoutAtLoad = BagsBar.Layout

    -- the API: no action globals, secrets where Forever has them
    GetActionCooldown, HasAction, IsUsableAction, IsActionInRange = nil, nil, nil, nil
    C_ActionBar = {
        GetActionBarPage = function() return actionPage end,
        HasAction = function() return true end,
        IsUsableAction = function(a) return not manaShort[a], manaShort[a] or false end,
        IsActionInRange = function(a) return rangeOf[a] end,
        GetActionCooldown = function(a)
            if a == 63 then return { startTime = secret(), duration = secret(), isEnabled = true, modRate = 1 } end
            return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
        end,
    }
    issecretvalue = isSecret
    function GetSpecialization() return 2 end           -- a fire mage, a mistweaver: no class resource
    UnitHealth, UnitHealthMax = secret, secret
    UnitHealthPercent = secret
    function UnitPower() return secret() end
    function UnitPowerMax(_, kind) if kind == 4 then return 5 end return secret() end
    GetComboPoints = secret
    C_CurveUtil = { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
    Enum = { LuaCurveType = { Linear = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        UnitAuraSortRule = { Unsorted = 0, Default = 1, BigDefensive = 2, Expiration = 3, ExpirationOnly = 4,
            Name = 5, NameOnly = 6 },
        UnitAuraSortDirection = { Normal = 0, Reverse = 1 },
        DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5,
            Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 } }
end

-- The client's combat meter (Forever 1.60, retail 12.x): per type, the
-- sources in the order the client sorts them. In combat every amount and
-- name is secret (GetCombatSessionFromType is SecretWhenInCombat); the class
-- and spec icon never are. Overall is three times the current fight.
local meter = { available = true, reason = "", asked = {}, resets = 0, data = {} }
local function meterData()
    local function list(n, top)
        local names = { "Thalen", "Aldren", "Ahrymx", "Kesh", "Varo", "Mira", "Brann", "Ylla", "Dorn", "Esk" }
        local classes = { "MAGE", "WARRIOR", "HUNTER", "ROGUE", "WARLOCK", "PRIEST", "PALADIN", "SHAMAN", "",
            "DRUID" }
        local out = {}
        for i = 1, n do out[i] = { names[i], classes[i], top - (i - 1) * 1000, i == 3 and 0 or 60 + i } end
        return out
    end
    meter.data = { [0] = list(10, 12400), [2] = list(5, 9880), [5] = list(2, 4) }
end
meterData()
if modern then
    C_DamageMeter = {
        IsDamageMeterAvailable = function() return meter.available, meter.reason end,
        GetCombatSessionFromType = function(sessionType, kind)
            table.insert(meter.asked, sessionType .. "/" .. kind)
            -- a rate type reads its total's sources, per second
            local base = (kind == 1 or kind == 3) and kind - 1 or kind
            local function v(x) if inCombat then return secret() end return x end
            local out, top = {}, 0
            for _, src in ipairs(meter.data[base] or {}) do
                local amount = src[3] * (sessionType == 0 and 3 or 1)
                top = math.max(top, amount)
                table.insert(out, { name = inCombat and secret() or src[1], classFilename = src[2],
                    specIconID = v(src[4]), totalAmount = v(amount), amountPerSecond = v(amount / 100),
                    isLocalPlayer = src[1] == "Ahrymx" })
            end
            return { combatSources = out, maxAmount = v(top), totalAmount = v(0), durationSeconds = v(102) }
        end,
        GetSessionDurationSeconds = function(sessionType) return sessionType == 0 and 750 or 102 end,
        ResetAllCombatSessions = function() meter.resets = meter.resets + 1; meter.data = {} end,
    }
    function GetClassAtlas(c) return "classicon-" .. c:lower() end
    -- Blizzard's formatter, which takes a secret and gives one back
    function AbbreviateLargeNumbers(n)
        if isSecret(n) then return secret() end
        if n >= 1000 then return string.format("%.1fK", n / 1000) end
        return tostring(n)
    end
end

-- The loot history (Mainline): a boss from before the reload, with a roll
-- won; later passes add drops. An item's quality comes from C_Item, or not
-- yet (nil), as for an item the client has not cached.
local loot = { encounters = {}, drops = {}, quality = { [30001] = 4, [30002] = 4, [30003] = 3, [30004] = 2,
    [30005] = 0, [30006] = 1 } }
-- Mainline links name their quality; older ones carry its colour
local function itemLink(id, name, q)
    if not modern then return string.format("%s|Hitem:%d::|h[%s]|h|r", ITEM_QUALITY_COLORS[q].hex, id, name) end
    return string.format("|cnIQ%d:|Hitem:%d::|h[%s]|h|r", q, id, name)
end
if modern then
    loot.encounters[1] = { encounterID = 601, encounterName = "High Warlord Naj'entus", startTime = 5 }
    loot.drops[601] = { { lootListKey = 1, itemHyperlink = itemLink(30001, "Naj'entus Spine", 4),
        winner = { playerName = "Aldren-Realm", playerClass = "WARRIOR", isSelf = false, state = 0, roll = 64 },
        allPassed = false, rollInfos = {} } }
    C_LootHistory = {
        GetAllEncounterInfos = function() return loot.encounters end,
        GetInfoForEncounter = function(id)
            for _, e in ipairs(loot.encounters) do if e.encounterID == id then return e end end
        end,
        GetSortedDropsForEncounter = function(id) return loot.drops[id] end,
    }
    C_CurrencyInfo = { GetCurrencyInfoFromLink = function(link)
        return { iconFileID = "currency" .. link:match("currency:(%d+)") }
    end }
    C_Item = { GetItemQualityByID = function(link) return loot.quality[tonumber(link:match("item:(%d+)"))] end,
        GetItemIconByID = function(link) return "icon" .. link:match("item:(%d+)") end }
    function UnitCastingInfo(u)
        if casting and u == castUnit then return "Sinister Strike", nil, nil, secret(), secret(), false, secret() end
    end
    function UnitCastingDuration(u)
        if u == castUnit then return { GetRemainingDuration = secret } end
    end
    function UnitChannelDuration() end
end

-- The player's buffs on the modern clients: a mount and a form (timeless,
-- the form with three stacks), Arcane Intellect (timed). In combat whether
-- a buff runs out is secret, as DoesAuraHaveExpirationTime is restricted.
local buffs = {
    { id = 31, icon = "mount", timed = false },
    { id = 12, icon = "intellect", timed = true },
    { id = 17, icon = "form", timed = false, count = 3 },
}
local cancelled = {}
local function Buff(id)
    for _, b in ipairs(buffs) do
        if b.id == id then return b end
    end
end
local function AuraData(b)
    return b and { auraInstanceID = b.id, icon = b.icon, applications = b.count or 0, name = b.name,
        expirationTime = b.expires or b.timed and 160 or 0 }
end
-- loss of control: none until a pass hands one over (lossOfControl)
local lossOfControl
C_LossOfControl = {
    GetActiveLossOfControlDataCount = function() return lossOfControl and 1 or 0 end,
    GetActiveLossOfControlData = function() return lossOfControl end,
}
if modern then
    C_UnitAuras = {
        GetAuraDataByIndex = function(_, i) return AuraData(buffs[i]) end,
        GetAuraDataByAuraInstanceID = function(_, id) return AuraData(Buff(id)) end,
        DoesAuraHaveExpirationTime = function(_, id)
            if inCombat then return secret() end
            return Buff(id).timed
        end,
        CancelAuraByInstanceID = function(_, id) table.insert(cancelled, id) end,
    }
end

-- Options > AddOns: Medalluin's page is a canvas (options/info.lua); a proxy
-- setting, if Medalluin ever built one again, is counted. The settings
-- themselves are Medalluin's own window (options/), reached through
-- page.settings[key], which works the window's control for that option the
-- way a click does; page.opened is the window's page while it is shown.
local page = { proxies = 0 }
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        page.name, page.frame = name, frame
        page.root = { name = name, GetID = function() return 7 end }
        return page.root
    end,
    RegisterVerticalLayoutCategory = function() page.proxies = page.proxies + 1 end,
    RegisterProxySetting = function() page.proxies = page.proxies + 1 end,
    RegisterAddOnCategory = function() page.registered = true end,
    OpenToCategory = function(id) page.blizzardOpened = id end,
}
UISpecialFrames = {}
C_AddOns = C_AddOns or {}
C_AddOns.GetAddOnMetadata = function(_, field)
    return ({ Version = "0.1.0", Author = "ahrymx", Notes = "The console and its strips." })[field]
end
-- the game's colour picker: shown with its setup, then turned by the test
ColorPickerFrame = new("Frame", UIParent, "ColorPickerFrame")
ColorPickerFrame.shown = false
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self.info, self.rgb, self.shown = info, { info.r, info.g, info.b }, true
end
function ColorPickerFrame:GetColorRGB() return unpack(self.rgb) end
local cursor
function GetCursorInfo() return cursor end
-- The action slots and what can go in them (bars/skills.lua): a slot holds
-- { type, id }; the cursor holds what a pickup took. Spells known, items in
-- the bags and macros are the "skills" pass's to change.
actionSlots, known, inBags, macros = {}, { [133] = true, [116] = true, [2136] = true, [122] = true }, { [6948] = true },
    { "Heal", "Focus" }
function GetActionInfo(slot)
    local a = actionSlots[slot]
    if a then return a[1], a[1] == "macro" and 7 or a[2] end
end
function GetActionText(slot)
    local a = actionSlots[slot]
    return a and a[1] == "macro" and a[2] or nil
end
function PickupAction(slot) cursor, actionSlots[slot] = actionSlots[slot], nil end
function PlaceAction(slot)
    if type(cursor) ~= "table" then return end
    cursor, actionSlots[slot] = actionSlots[slot], cursor
end
function ClearCursor() cursor = nil end
function CursorHasItem() return cursor ~= nil end
function GetMacroIndexByName(name)
    for i, m in ipairs(macros) do if m == name then return i end end
    return 0
end
function PickupMacro(i) cursor = { "macro", macros[i] } end
C_Item = C_Item or {}
C_Item.PickupItem = function(id) if inBags[id] then cursor = { "item", id } end end
-- a page's rows in order: settings by name, [buttons], # headings
SettingsPanel = new("Frame", UIParent, "SettingsPanel")
SettingsPanel.shown = false
function HideUIPanel(f) f.shown = false end
StaticPopupDialogs = {}
SlashCmdList = {}
function ReloadUI() end
MedalluinDB = profilesPass and args[3] == "saved" and { consoleProfile = "light",
        profiles = { default = { drawer = 2, topBoss = true }, light = { rows = 2, topBoss = false, partyRange = 30,
            partyWidgetPoint = { "TOPLEFT", "TOPLEFT", 50, -60 } } },
        global = { lootMoney = false } }
    or profilesPass and { consoleProfile = "light", rows = 3, actionBar = true, bareIcons = true,
        artColor = "ffffffff", drawer = 2, sideTab = "loot", bagsPoint = { "TOP", "TOP", 4, -8 },
        bagsColumns = 12, retired = "kept" }
    or lightPass and { consoleProfile = "light", bareIcons = true, simParty = grouped,
        partyLayout = rowPass and "horizontal" or "vertical", minimapStart = savedStart }
    or barOff and { actionBar = false } or savedRows and { rows = savedRows }
    or pagingPass and { rows = 3 }
    or savedBare and { bareIcons = true } or savedNoChat and { chat = false }
    or savedBeam and { xpCast = true, repCast = true }
    or savedSimParty and { simParty = true } or savedNoSide and { side = false }
    or savedNoBags and { bags = false } or bankPass and args[3] == "nobank" and { bank = false }
    or savedNoCharacter and { character = false }
    or npcPass and args[3] == "nonpc" and { npcWindows = false }
    or mailPass and { mail = { Nordanaar = { alts = { "Thalassa" }, recent = { "Thalric", "Okun" } } } } or nil
if modern then
    function CreateColor(r, g, b, a) return { r, g, b, a } end
    function Region:SetGradient(o, a, b) self.gradient = { o, a, b } end
    C_Texture = { GetAtlasInfo = function() return { width = 154, height = 95 } end }
end

-- ------------------------------------------------------------ the bags
-- A backpack of 16, bag 1 of 12, no bag in slot 2, bags 3 and 4 of 10, and
-- a reagent bag of 8; items of each group. Only for the bags pass, and only
-- on an Edit Mode client: elsewhere there are no combined bags.
local bagWorld
-- a Classic-era client has C_Container, but not the combined bags
if bagsPass and not modern then
    C_Container = { GetContainerNumSlots = function() return 16 end, GetContainerNumFreeSlots = function() return 16 end,
        GetContainerItemInfo = function() end }
end
if (bagsPass or bankPass) and modern then
    bagWorld = { sizes = { [0] = 16, [1] = 12, [2] = 0, [3] = 10, [4] = 10, [5] = 8 }, items = {},
        new = {}, removed = {}, sorted = 0, search = nil, reads = 0 }
    Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
    NUM_BAG_SLOTS, NUM_CONTAINER_FRAMES = 4, 13
    -- itemID -> name, class, quality, item level
    local ITEMS = {
        [101] = { "Glaive of the Fallen", 2, 4, 489 }, [102] = { "Felforged Breastplate", 4, 3, 476 },
        [103] = { "Healing Potion", 0, 1 }, [104] = { "Sealed Orders", 15, 1 }, [111] = { "Ashtongue Cowl Fragment", 12, 1 },
        [105] = { "Fel Iron Ore", 7, 1 }, [106] = { "Broken Fang", 15, 0 }, [107] = { "Hearthstone", 15, 1 },
        [108] = { "Netherweave Cloth", 7, 1 }, [109] = { "Mana Potion", 0, 1 }, [110] = { "Draenic Dust", 7, 2 },
    }
    bagWorld.ITEMS = ITEMS
    local function put(bag, slot, id, count, extra)
        local it = ITEMS[id]
        local info = { iconFileID = 9000 + id, stackCount = count or 1, isLocked = false, quality = it[3],
            itemID = id, itemName = it[1], hyperlink = "item:" .. id, isFiltered = false, hasNoValue = it[3] == 0 }
        for k, v in pairs(extra or {}) do info[k] = v end
        bagWorld.items[bag .. ":" .. slot] = info
    end
    bagWorld.put = put
    put(0, 1, 107); put(0, 2, 103, 12); put(0, 3, 101); put(0, 5, 104); put(0, 6, 106, 3)
    put(0, 9, 102, 1, { isLocked = true }); put(1, 1, 109, 4); put(3, 2, 105, 20); put(4, 10, 108, 7)
    put(5, 1, 110, 40); put(5, 2, 105, 5); put(4, 1, 111)
    bagWorld.new["0:3"] = true                 -- the glaive was just looted
    C_Container = {
        GetContainerNumSlots = function(bag) return bagWorld.sizes[bag] or 0 end,
        GetContainerNumFreeSlots = function(bag)
            local n = 0
            for slot = 1, bagWorld.sizes[bag] or 0 do
                if not bagWorld.items[bag .. ":" .. slot] then n = n + 1 end
            end
            return n
        end,
        GetContainerItemInfo = function(bag, slot)
            bagWorld.reads = bagWorld.reads + 1
            return bagWorld.items[bag .. ":" .. slot]
        end,
        -- the equipped bags' names; the backpack and the reagent bag left to
        -- the window's own
        GetBagName = function(bag)
            return ({ [1] = "Netherweave Bag", [3] = "Mooncloth Bag", [4] = "Frostweave Bag" })[bag]
        end,
        GetContainerItemQuestInfo = function(bag, slot)
            local info = bagWorld.items[bag .. ":" .. slot]
            return { isQuestItem = info ~= nil and info.itemID == 104, questID = 9, isActive = false }
        end,
        -- the client's search: an item whose name lacks the text is filtered
        SetItemSearch = function(text)
            bagWorld.search = text
            for _, info in pairs(bagWorld.items) do
                info.isFiltered = text ~= "" and not info.itemName:lower():find(text:lower(), 1, true)
            end
        end,
        SortBags = function() bagWorld.sorted = bagWorld.sorted + 1 end,
        GetContainerItemLink = function(bag, slot)
            local info = bagWorld.items[bag .. ":" .. slot]
            return info and info.hyperlink
        end,
        PickupContainerItem = function(bag, slot) table.insert(bagWorld.picked, bag .. ":" .. slot) end,
    }
    bagWorld.picked = {}
    IsModifiedClick = IsModifiedClick or function() return false end
    function GameTooltip:SetBagItem(bag, slot) self.item = "bag" .. bag .. ":" .. slot end
    -- the item tooltips' post-calls (inventory/locks.lua's "Locked")
    bagWorld.posts = {}
    Enum.TooltipDataType = { Item = 0 }
    TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, fn) table.insert(bagWorld.posts, { kind = kind, fn = fn }) end,
    }
    C_NewItems = {
        IsNewItem = function(bag, slot) return bagWorld.new[bag .. ":" .. slot] == true end,
        RemoveNewItem = function(bag, slot)
            bagWorld.new[bag .. ":" .. slot] = nil
            table.insert(bagWorld.removed, bag .. ":" .. slot)
        end,
    }
    C_Item = C_Item or {}
    C_Item.GetItemInfoInstant = function(id)
        local it = ITEMS[id]
        if it then return id, "type", "subtype", "", 9000 + id, it[2] end
    end
    C_Item.GetCurrentItemLevel = function(loc)
        local info = bagWorld.items[loc.bag .. ":" .. loc.slot]
        return info and ITEMS[info.itemID][4]
    end
    ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
    function GetMoney() return 1234567 end
    function GetMoneyString(c) return string.format("%dg %ds %dc", math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
    -- Blizzard's slot functions and the template's mixin, recording what they were told
    function ClearItemButtonOverlay(b) b.overlayCleared = true end
    function SetItemButtonQuality(b, q) b.quality = q end
    function SetItemButtonCount(b, n) b.count = n end
    function SetItemButtonDesaturated(b, d) b.desat = d end
    function Region:SetID(id) self.idOf = id end
    function Region:GetID() return self.idOf end
    local plain = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local f = plain(kind, name, parent, template)
        f.template = template
        if template == "ContainerFrameItemButtonTemplate" then
            function f:SetHasItem(t) self.hasItem = t end
            function f:SetItemButtonTexture(t) self.icon = t end
            function f:UpdateNewItem() self.newGlow = C_NewItems.IsNewItem(self:GetParent():GetID(), self:GetID()) end
            function f:UpdateQuestItem(q) self.quest = q end
            function f:UpdateJunkItem(q, noValue) self.junk = q == 0 and noValue end
            function f:SetMatchesSearch(m) self.matches = m end
            function f:UpdateCooldown() end
            function f:SetReadable() end
            function f:UpdateItemContextMatching() end
            function f:CheckUpdateTooltip() end
        end
        return f
    end
    -- Blizzard's bag frames: the combined bags, and one frame per bag
    ContainerFrameCombinedBags = new("Frame", UIParent, "ContainerFrameCombinedBags")
    ContainerFrameCombinedBags.shown = false
    for i = 1, NUM_CONTAINER_FRAMES do
        local f = new("Frame", UIParent, "ContainerFrame" .. i)
        f.shown = false
    end
    function OpenAllBags() ContainerFrameCombinedBags:Show() end
    function CloseAllBags()
        ContainerFrameCombinedBags:Hide()
        for i = 1, NUM_CONTAINER_FRAMES do _G["ContainerFrame" .. i]:Hide() end
    end
    function ToggleAllBags()
        if ContainerFrameCombinedBags:IsShown() then CloseAllBags() else OpenAllBags() end
    end
end

-- ------------------------------------------------------------ the character
-- Blizzard's character window and its pages (Forever's six, or retail's
-- three), its gear slot buttons, a shaman's gear and stats on Forever and a
-- rogue's on retail. Only for the character pass.
local charWorld
if characterPass or questPass or npcPass or bankPass then
    charWorld = { toggles = {} }
    function Region:SetUnit(u) self.unit, self.unitSets = u, (self.unitSets or 0) + 1 end
    function Region:SetFacing(f) self.facing = f end
    function Region:GetFacing() return self.facing end
    local subs = characterRetail and { "PaperDollFrame", "ReputationFrame", "TokenFrame" }
        or { "PaperDollFrame", "ReputationFrame", "TokenFrame", "PVPRankFrame", "SkillsFrame", "StatisticsFrame" }
    charWorld.subs = subs
    CharacterFrame = new("Frame", UIParent, "CharacterFrame")
    CharacterFrame.shown = false
    for _, n in ipairs(subs) do
        local f = new("Frame", CharacterFrame, n)
        f.shown = n == "PaperDollFrame"
    end
    function CharacterFrame:ShowSubFrame(name)
        for _, n in ipairs(subs) do
            if n ~= name then _G[n]:Hide() end
        end
        _G[name]:Show()
    end
    function ShowUIPanel(f) f:Show() end
    function HideUIPanel(f) f:Hide() end
    -- Blizzard's own, as CharacterFrame.lua has it
    function ToggleCharacter(tab, onlyShow)
        table.insert(charWorld.toggles, tab)
        local sub = _G[tab]
        if CharacterFrame:IsShown() then
            if sub:IsShown() then
                if not onlyShow then HideUIPanel(CharacterFrame) end
            else
                CharacterFrame:ShowSubFrame(tab)
            end
        else
            CharacterFrame:ShowSubFrame(tab)
            ShowUIPanel(CharacterFrame)
        end
    end
    -- the slots by name, their inventory ids, and what is in them:
    -- { quality, item level }
    local SLOTS = { Head = 1, Neck = 2, Shoulder = 3, Shirt = 4, Chest = 5, Waist = 6, Legs = 7, Feet = 8,
        Wrist = 9, Hands = 10, Finger0 = 11, Finger1 = 12, Trinket0 = 13, Trinket1 = 14, Back = 15,
        MainHand = 16, SecondaryHand = 17, Ranged = 18, Tabard = 19, Ammo = 0 }
    charWorld.gear = characterRetail
        and { [1] = { 4, 321 }, [3] = { 4, 321 }, [5] = { 4, 331 }, [16] = { 4, 334 }, [17] = { 4, 321 },
            [4] = { 1, 1 }, [11] = { 3, 315 } }
        or { [1] = { 2, 14 }, [5] = { 1, 10 }, [7] = { 2, 16 }, [16] = { 3, 18 }, [17] = { 2, 15 },
            [4] = { 1, 1 }, [19] = { 1, 1 } }
    local PARENT = new("Frame", PaperDollFrame, "PaperDollItemsFrame")
    -- the equipment flyout's settings, which the slot hover reads off its parent
    PARENT.flyoutSettings = { parent = PaperDollFrame, anchorX = 0, anchorY = -3, hasPopouts = true }
    for slotName, id in pairs(SLOTS) do
        local forever = slotName == "Ranged" or slotName == "Ammo"
        if not (characterRetail and forever) then
            local name = "Character" .. slotName .. "Slot"
            local b = new("Button", PARENT, name)
            b:SetID(id)
            b.icon = new("Texture", b, name .. "IconTexture")
            b.normal = new("Texture", b)
            b.IconBorder = new("Texture", b)
            function b:GetNormalTexture() return self.normal end
            -- a shaman uses no ammo: Blizzard hides the slot at load
            if slotName == "Ammo" then b.shown = false end
        end
    end
    function GetInventoryItemLink(_, slot)
        if charWorld.gear[slot] then return "|Hitem:" .. slot .. "|h" end
    end
    function GetInventoryItemQuality(_, slot) return charWorld.gear[slot] and charWorld.gear[slot][1] end
    ItemLocation = ItemLocation or {}
    function ItemLocation.CreateFromEquipmentSlot(_, slot)
        return { equip = slot, IsValid = function() return true end }
    end
    C_Item = C_Item or {}
    function C_Item.GetCurrentItemLevel(loc) return charWorld.gear[loc.equip][2] end
    function UnitPVPName() return characterRetail and "Vasheron, Famed Slayer" or "Ahry Medalluin" end
    function GetAverageItemLevel()
        if characterRetail then return 322.4, 322.0 end
        return 15.8, 15.1
    end
    function UnitStat(_, i)
        local v = characterRetail and ({ 900, 2505, 38553, 700, 0 })[i] or ({ 32, 20, 40, 29, 31 })[i]
        return v, v
    end
    function UnitArmor() return 300, characterRetail and 1086 or 334 end
    function GetCritChance() return characterRetail and 39 or 5.2 end
    function GetRangedCritChance() return 4 end
    function GetSpellCritChance(school) return school == 4 and 6.5 or 2 end
    function GetDodgeChance() return characterRetail and 15 or 4.5 end
    function GetParryChance() return characterRetail and 3 or 5 end
    function GetCombatRatingBonus(cr) return cr == 29 and 10 or 0 end
    function UnitSpellHaste() return characterRetail and 25 or 2.5 end
    if characterRetail then
        CR_VERSATILITY_DAMAGE_DONE = 29
        function GetHaste() return 25 end
        function GetMasteryEffect() return 14 end
        function GetVersatilityBonus() return 2 end
        function GetLifesteal() return 9 end
        function GetAvoidance() return 2 end
        function GetUnitSpeed() return 0, 8.05 end
        function GetSpecialization() return 2 end
        function GetSpecializationInfo(i) return i, "Outlaw" end
    else
        CR_HIT_MELEE, CR_HIT_SPELL = 6, 8
        function GetHitModifier() return 1 end
        function GetSpellHitModifier() return 3 end
        function GetMeleeHaste() return 0 end
        function GetRangedHaste() return 0 end
        function UnitAttackPower() return 60, 8, 0 end
        function GetSpellBonusDamage(school) return school == 4 and 12 or 5 end
        function GetSpellBonusHealing() return 20 end
        function UnitDefenseSkill() return 60, 0 end
        function GetBlockChance() return 5 end
        function UnitResistance(_, class) return 0, 0, class * 2, 0 end
    end
    function UnitSex() return 2 end
    function UnitFactionGroup() return "Alliance" end
    function GetText(key) return _G[key] end
    FACTION_STANDING_LABEL4, FACTION_STANDING_LABEL5, FACTION_STANDING_LABEL8 = "Neutral", "Friendly", "Exalted"
    charWorld.calls = {}
    local function called(s) table.insert(charWorld.calls, s) end
    charWorld.called = called
    -- a list whose headings fold: the rows the game hands out are the ones
    -- not under a folded heading (a top heading folds to the next top one)
    local function visible(all)
        local out, hidden = {}, false
        for _, e in ipairs(all) do
            if e.isHeader and not e.isChild then
                hidden = false
                table.insert(out, e)
                hidden = e.isCollapsed
            elseif not hidden then
                table.insert(out, e)
            end
        end
        return out
    end
    charWorld.visible = visible
    -- reputations: Darnassus friendly, Ironforge friendly, Stormwind exalted,
    -- the Argent Dawn neutral
    local factions = {
        { name = "Alliance", isHeader = true, factionID = 1 },
        { name = "Darnassus", factionID = 69, reaction = 5, currentStanding = 3100, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, description = "The Alliance capital of the night elves.",
            canToggleAtWar = false, canSetInactive = true },
        { name = "Ironforge", factionID = 47, reaction = 5, currentStanding = 6000, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, canSetInactive = true },
        { name = "Stormwind", factionID = 72, reaction = 8, currentStanding = 42000, currentReactionThreshold = 42000,
            nextReactionThreshold = 43000, canSetInactive = true },
        { name = "Other", isHeader = true, factionID = 2 },
        { name = "Argent Dawn", factionID = 529, reaction = 4, currentStanding = 500, currentReactionThreshold = 0,
            nextReactionThreshold = 3000, canToggleAtWar = true, canSetInactive = true },
        { name = "Inactive", isHeader = true, factionID = 3 },
    }
    charWorld.factions = factions
    local function shown() return visible(factions) end
    C_Reputation = {
        GetNumFactions = function() return #shown() end,
        GetFactionDataByIndex = function(i) return shown()[i] end,
        ExpandFactionHeader = function(i) shown()[i].isCollapsed = false; called("rep expand " .. i) end,
        CollapseFactionHeader = function(i) shown()[i].isCollapsed = true; called("rep collapse " .. i) end,
        ToggleFactionAtWar = function(i)
            local f = shown()[i]
            f.atWarWith = not f.atWarWith
            called("rep war " .. f.name)
        end,
        IsFactionActive = function(i) return not shown()[i].inactive end,
        -- inactive: moved under the Inactive heading, at the end
        SetFactionActive = function(i, on)
            local f = shown()[i]
            called("rep active " .. f.name .. " " .. tostring(on))
            f.inactive = not on
            for k, e in ipairs(factions) do
                if e == f then table.remove(factions, k) break end
            end
            if on then table.insert(factions, 2, f) else table.insert(factions, f) end
        end,
        SetWatchedFactionByIndex = function(i)
            for _, e in ipairs(factions) do e.isWatched = nil end
            if i > 0 then shown()[i].isWatched = true end
            called("rep watch " .. i)
        end,
    }
    -- currencies: honor (capped), arena points (weekly)
    local currencies = {
        { name = "Player vs. Player", isHeader = true, isHeaderExpanded = true },
        { name = "Honor Points", currencyID = 1901, quantity = 1250, iconFileID = 101, maxQuantity = 75000 },
        { name = "Arena Points", currencyID = 1900, quantity = 0, iconFileID = 102, canEarnPerWeek = true,
            maxWeeklyQuantity = 1500, quantityEarnedThisWeek = 300 },
    }
    charWorld.currencies = currencies
    local function curShown()
        local out, hidden = {}, false
        for _, c in ipairs(currencies) do
            if c.isHeader then
                hidden = not c.isHeaderExpanded
                table.insert(out, c)
            elseif not hidden then
                table.insert(out, c)
            end
        end
        return out
    end
    C_CurrencyInfo = {
        GetCurrencyListSize = function() return #curShown() end,
        GetCurrencyListInfo = function(i) return curShown()[i] end,
        ExpandCurrencyList = function(i, on) curShown()[i].isHeaderExpanded = on; called("cur expand " .. i .. " "
            .. tostring(on)) end,
        GetCurrencyDescription = function(id) return "Currency " .. id .. "." end,
        SetCurrencyBackpack = function(i, on) curShown()[i].isShowInBackpack = on; called("cur backpack " .. i
            .. " " .. tostring(on)) end,
        SetCurrencyUnused = function(i, on) curShown()[i].isTypeUnused = on; called("cur unused " .. i .. " "
            .. tostring(on)) end,
        GetCurrencyListLink = function(i) return "[currency " .. i .. "]" end,
    }
    function ChatEdit_InsertLink(link) called("link " .. link) end
    charWorld.modified = false
    function IsModifiedClick(action) return action == "CHATLINK" and charWorld.modified end
    if not characterRetail then
        -- skills: the class's own heading and a parented line are left out;
        -- defense takes its bonus from UnitDefenseSkill
        local skills = {
            { name = "Weapon Skills", isHeader = true, skillLineCategoryID = 6 },
            { name = "Defense", skillID = 95, rank = 53, maxRank = 60, modifier = 0, skillLineCategoryID = 6 },
            { name = "Maces", skillID = 54, rank = 52, maxRank = 60, modifier = 0, skillLineCategoryID = 6 },
            { name = "Class Skills", isHeader = true, skillLineCategoryID = 7 },
            { name = "Enhancement", skillID = 373, rank = 1, maxRank = 1, skillLineCategoryID = 7 },
            { name = "Professions", isHeader = true, skillLineCategoryID = 11 },
            { name = "Herbalism", skillID = 182, rank = 45, maxRank = 75, modifier = 0, skillLineCategoryID = 11,
                description = "Higher herbalism skill allows you to harvest more difficult herbs." },
            { name = "Apprentice Herbalism", skillID = 9182, rank = 1, maxRank = 1, parentSkillLineID = 182,
                skillLineCategoryID = 11 },
            { name = "Mining", skillID = 186, rank = 140, maxRank = 150, modifier = 0, skillLineCategoryID = 11 },
        }
        charWorld.skills = skills
        local function skShown()
            local out, hidden = {}, false
            for _, e in ipairs(skills) do
                if e.isHeader then
                    hidden = e.isCollapsed
                    table.insert(out, e)
                elseif not hidden then
                    table.insert(out, e)
                end
            end
            return out
        end
        C_SkillInfo = {
            GetNumSkillLines = function() return #skShown() end,
            GetSkillLineInfo = function(i)
                local e = skShown()[i]
                return e and setmetatable({}, { __index = e })
            end,
            ExpandSkillHeader = function(i) skShown()[i].isCollapsed = false; called("skill expand " .. i) end,
            CollapseSkillHeader = function(i) skShown()[i].isCollapsed = true; called("skill collapse " .. i) end,
        }
        function UnitDefenseSkill() return 60, 5 end
        -- the PvP rank: rank 2, 300 of 750 points; the cap 5 ranks this week, 4 the last
        C_MajorFactions = {
            GetMajorFactionProgressionInfo = function(id)
                if id ~= 2800 then return end
                return { renownLevel = 2, renownReputationEarned = 300, renownLevelThreshold = 750, maxLevel = 14,
                    currentWeekProgressiveMaxLevel = 5, previousWeekProgressiveMaxLevel = 4 }
            end,
            GetTotalReputationForRenownLevel = function(_, level) return level * 750 end,
            GetRenownRewardsForLevel = function(_, r)
                if r == 3 then return { { icon = 123, description = "Faction Tabard" } } end
                return {}
            end,
        }
        PVP_RANK_6_1 = "Corporal"
        Enum.PvPRanks = { Rank_1 = 5 }
        function GetCurrentArenaSeason() return 1 end
        -- statistics: Character (two, one nought), Kills (one skipped) and
        -- its child Creatures
        local CATS = { [130] = { "Character", -1 }, [131] = { "Kills", -1 }, [132] = { "Creatures", 131 } }
        local STATS = { [130] = { { "309", false, 1001 }, { "0", false, 1002 } },
            [131] = { { "--", false, 1003 }, { "5", true, 1004 } }, [132] = { { "308", false, 1005 } } }
        local STAT_NAMES = { [1001] = "Total kills", [1002] = "Total deaths", [1003] = "Total honorable kills",
            [1004] = "Hidden", [1005] = "Creatures killed" }
        function GetStatisticsCategoryList() return { 130, 131, 132 } end
        function GetCategoryInfo(id) return CATS[id][1], CATS[id][2] end
        function GetCategoryNumAchievements(id) return #STATS[id] end
        function GetStatistic(id, i) return unpack(STATS[id][i]) end
        function GetAchievementInfo(id) return id, STAT_NAMES[id] end
    end
    -- titles: four of five known, one of those not a player's; the
    -- explorer's worn. Blizzard's names come with a space at an end.
    local TITLES = { { "Private ", true }, { " the Explorer", true }, { "Corporal ", true }, { "Unknown ", true },
        { "Guild Master", false } }
    local KNOWN = { true, true, true, false, true }
    charWorld.title = 2
    function GetNumTitles() return #TITLES end
    function IsTitleKnown(i) return KNOWN[i] or false end
    function GetTitleName(i) return TITLES[i][1], TITLES[i][2] end
    function GetCurrentTitle() return charWorld.title end
    function SetCurrentTitle(i) charWorld.title = i; called("title " .. i) end
    PLAYER_TITLE_NONE = "No Title"
    -- equipment sets: one worn (its shirt ignored), one with two items lost;
    -- room for three
    local sets = { { id = 0, name = "Tanking", icon = 111, worn = true, lost = 0, ignored = { [4] = true } },
        { id = 1, name = "Healing", icon = 222, worn = false, lost = 2, ignored = { [4] = false, [19] = true } } }
    charWorld.sets = sets
    local function setBy(id)
        for i, e in ipairs(sets) do
            if e.id == id then return e, i end
        end
    end
    local ignoring = {}
    local function ignored()
        local out = {}
        for slot in pairs(ignoring) do table.insert(out, slot) end
        table.sort(out)
        return table.concat(out, ",")
    end
    C_EquipmentSet = {
        GetEquipmentSetIDs = function()
            local ids = {}
            for _, e in ipairs(sets) do table.insert(ids, e.id) end
            return ids
        end,
        GetEquipmentSetInfo = function(id)
            local e = setBy(id)
            if e then return e.name, e.icon, e.id, e.worn, 5, 5, 0, e.lost, 0 end
        end,
        GetNumEquipmentSets = function() return #sets end,
        GetEquipmentSetID = function(name)
            for _, e in ipairs(sets) do
                if e.name == name then return e.id end
            end
        end,
        GetIgnoredSlots = function(id) return setBy(id).ignored end,
        ClearIgnoredSlotsForSave = function() ignoring = {} end,
        IgnoreSlotForSave = function(slot) ignoring[slot] = true end,
        SaveEquipmentSet = function(id) called("set save " .. id .. " ignoring " .. ignored()) end,
        CreateEquipmentSet = function(name, icon)
            table.insert(sets, { id = 7, name = name, icon = icon, worn = true, lost = 0, ignored = {} })
            called("set new " .. name .. " icon " .. tostring(icon) .. " ignoring " .. ignored())
        end,
        DeleteEquipmentSet = function(id)
            table.remove(sets, select(2, setBy(id)))
            called("set remove " .. id)
        end,
    }
    function EquipmentManager_EquipSet(id)
        for _, e in ipairs(sets) do e.worn = e.id == id end
        called("set equip " .. id)
    end
    function GetInventoryItemTexture(_, slot) if slot == 1 then return 999 end end
    -- the professions' micro button (the harness's world has the rest)
    ProfessionMicroButton = new("Button", MainMenuBar, "ProfessionMicroButton")
    MAX_EQUIPMENT_SETS_PER_PLAYER = 3
    -- a dialog shown is noted; the test answers it
    charWorld.popups = {}
    function StaticPopup_Show(which, a, _, data)
        table.insert(charWorld.popups, which .. ":" .. tostring(a))
        charWorld.popup = { which = which, data = data }
        return {}
    end
end

-- ------------------------------------------------------------- the bank
-- Forever's bank: the bank (container 6, 98 slots: taller than the window) and one bag slot bought
-- of three (container 7, a bag of 12: an item in Characterbanktab's slot 2); the warband's
-- (containers 12 and 13) seen only once bankWorld.account is set.
if bankPass and modern then
    bankWorld = { calls = {}, account = false, worn = { ["-2:2"] = 4242 }, active = 0 }
    local B = bankWorld
    local function called(s) table.insert(B.calls, s) end
    Enum.BankType = { Character = 0, Account = 2 }
    Enum.BagIndex.Characterbanktab, Enum.BagIndex.Accountbanktab = -2, -3
    B.tabs = { [0] = { { ID = 6, name = "" }, { ID = 7, name = "" } },
        [2] = { { ID = 12, name = "Warband" }, { ID = 13, name = "" } } }
    B.max = { [0] = 4, [2] = 3 }
    B.next = { [0] = 6 + 2, [2] = 14 }                 -- the next container each buys
    bagWorld.sizes[6], bagWorld.sizes[7], bagWorld.sizes[12], bagWorld.sizes[13] = 98, 12, 20, 20
    bagWorld.put(6, 1, 105, 20); bagWorld.put(6, 2, 108, 7); bagWorld.put(6, 4, 103, 5)
    bagWorld.put(7, 1, 109, 2); bagWorld.put(12, 1, 110, 9)
    C_Container.SortBankBags = function() called("SortBankBags") end
    C_Container.PickupContainerItem = function(bag, slot) called("PickupContainerItem " .. bag .. " " .. slot) end
    C_Item.DoesItemExist = function(at) return B.worn[at.bag .. ":" .. at.slot] ~= nil end
    C_Item.GetItemIcon = function(at) return B.worn[at.bag .. ":" .. at.slot] end
    C_Bank = {
        FetchPurchasedBankTabData = function(kind) return B.tabs[kind] end,
        FetchMaxNumBankTabs = function(kind) return B.max[kind] end,
        ShouldUsePlayerBagsInBank = function() return true end,
        FetchNextPurchasableBankTabData = function(kind)
            if #B.tabs[kind] < B.max[kind] then
                return { tabCost = 100000 * #B.tabs[kind], canAfford = B.poor ~= true }
            end
        end,
        PurchaseBankTab = function(kind)
            called("PurchaseBankTab " .. kind)
            table.insert(B.tabs[kind], { ID = B.next[kind], name = "" })
            bagWorld.sizes[B.next[kind]] = 0               -- bought, and empty: no bag in it
            B.next[kind] = B.next[kind] + 1
        end,
        CanViewBank = function(kind) return kind == 0 or B.account end,
        DoesBankTypeSupportAutoDeposit = function(kind) return kind == 2 end,
        AutoDepositItemsIntoBank = function(kind) called("AutoDeposit " .. kind) end,
        CloseBankFrame = function() called("CloseBankFrame"); BankFrame:Hide() end,
    }
    BankFrame = new("Frame", UIParent, "BankFrame")
    BankFrame.shown = false
    function GameTooltip:SetBagItem(bag, slot) self.item = "bag" .. bag .. ":" .. slot end
    -- Blizzard's panel, its bank tab, and its Purchase: a click is its popup,
    -- whose Yes the test gives
    BankFrame.BankPanel = new("Frame", BankFrame, "BankPanel")
    function BankFrame.BankPanel:GetActiveBankType() return B.active end
    local purchase = new("Button", BankFrame.BankPanel, "BankFramePurchaseButton")
    BankFrame.BankPanel.PurchaseButton = purchase
    purchase.scripts.OnClick = function() called("popup CONFIRM_BUY_BANK_TAB " .. B.active) end
    -- the next frame's timers, run by the pass's frame()
    B.timers = {}
    C_Timer = C_Timer or {}
    C_Timer.After = function(_, fn) table.insert(B.timers, fn) end
end

-- ------------------------------------------------------------ the quest log
-- Three zones of quests, Black Temple (the zone you are in) last in the log:
-- six tracked and shown, one tracked but hidden, one not tracked; one with a
-- usable item, one complete, one failed. Questie's stub, for "questie" and
-- "broken", tracks its own set. Only for the quests pass.
local questWorld
if questPass then
    questWorld = { calls = {} }
    local W = questWorld
    local function called(s) table.insert(W.calls, s) end
    local function o(text, done) return { text = text, finished = done } end
    W.log = {
        { title = "Elwynn Forest", isHeader = true },
        { title = "The Fargodeep Mine", level = 10, questID = 101, objectives = { o("Kobold Laborer slain: 4/10") } },
        { title = "Princess Must Die!", level = 12, questID = 102, complete = true,
            objectives = { o("Princess slain: 1/1", true) } },
        { title = "A Threat Within", level = 5, questID = 103, frequency = 1, objectives = {} },
        { title = "Westfall", isHeader = true },
        { title = "The Defias Brotherhood", level = 18, questID = 201, suggestedGroup = 5,
            objectives = { o("Defias Messenger: 0/1"),
                o("Report to Gryan Stoutmantle at the Sentinel Hill tower, on the road south of Moonbrook", true) } },
        { title = "Westfall Stew", level = 14, questID = 202, failed = true, objectives = { o("Stringy meat: 2/3") } },
        { title = "Red Leather Bandanas", level = 15, questID = 203, objectives = { o("Bandana: 6/15") } },
        { title = "Black Temple", isHeader = true },
        { title = "Seek Out the Ashtongue", level = 70, questID = 301, objectives = { o("Akama: 0/1") } },
        { title = "A Hidden Errand", level = 70, questID = 302, isHidden = true, objectives = {} },
    }
    W.watched = { [101] = true, [102] = true, [201] = true, [202] = true, [203] = true, [301] = true, [302] = true }
    W.special = { [2] = 5001, [3] = 5002, [10] = 5003 }   -- by log index; 5002 not once complete
    W.tags = { [301] = { tagID = 62 }, [203] = { tagID = 0, isElite = true } }   -- a raid's, an elite
    W.bags = { [5001] = 3, [5003] = 1, [6001] = 0 }
    local function byId(id)
        for _, e in ipairs(W.log) do if e.questID == id then return e end end
    end
    W.byId = byId
    function GetRealZoneText() return "Westfall" end   -- not the first by name
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #W.log end,
        GetInfo = function(i) return W.log[i] end,
        IsComplete = function(id) return byId(id).complete or false end,
        IsFailed = function(id) return byId(id).failed or false end,
        GetQuestObjectives = function(id) return byId(id).objectives end,
        GetQuestWatchType = function(id) return W.watched[id] and 0 or nil end,
        RemoveQuestWatch = function(id) W.watched[id] = nil; called("unwatch " .. id) end,
        GetQuestTagInfo = function(id) return W.tags[id] end,
        SetSelectedQuest = function(id) called("select " .. id) end,
    }
    function GetQuestLogSpecialItemInfo(i)
        local item = W.special[i]
        if item then return "|Hitem:" .. item .. "|h[Thing]|h", 1000 + item, 1, false end
    end
    function GetQuestLink(id) return "[quest " .. id .. "]" end
    function QuestMapFrame_OpenToQuestDetails(id) called("map " .. id) end
    function GetQuestDifficultyColor(level)
        return level >= 70 and { r = 1, g = 0.1, b = 0.1 } or level >= 15 and { r = 1, g = 1, b = 0 }
            or { r = 0.25, g = 0.75, b = 0.25 }
    end
    C_Item = C_Item or {}
    C_Item.GetItemCount = function(id) return W.bags[id] or 0 end
    C_Item.GetItemIconByID = function(id) return "icon" .. id end
    C_Container = C_Container or {}
    C_Container.GetItemCooldown = function(id) if id == 5003 then return 100, 30, 1 end return 0, 0, 1 end
    function GameTooltip:SetItemByID(id) self.item = id end
    function Region:SetCooldown(start, duration) self.start, self.duration = start, duration end
    function ChatEdit_InsertLink(link) called("link " .. link) end
    -- Blizzard's tracker: protected when the pass says
    ObjectiveTrackerFrame = new("Frame", UIParent, "ObjectiveTrackerFrame")
    function ObjectiveTrackerFrame:IsProtected() return W.protected or false end
    -- Questie's stub: ready when the pass says, tracking its own set
    if questieStub or questieBroken then
        local Z = { ready = {}, updates = {}, broken = questieBroken, tracked = { [101] = true, [103] = true, [201] = true, [301] = true },
            items = { [201] = 6001 } }
        W.questie = Z
        local function call(name, fn)
            return function(...)
                if Z.broken then error("Questie " .. name .. " changed") end
                return fn(...)
            end
        end
        local tracker = { Update = function() end }
        tracker.IsTrackedByQuestie = call("IsTrackedByQuestie", function(id) return Z.tracked[id] or false end)
        tracker.UntrackQuestId = call("UntrackQuestId", function(_, id) Z.tracked[id] = nil; called("questie untrack " .. id) end)
        local utils = {
            GetQuestItemIds = call("GetQuestItemIds", function(q) return { Z.items[q.id] } end),
            ShowQuestLog = call("ShowQuestLog", function(_, q) called("questie log " .. q.id) end),
            FocusQuest = call("FocusQuest", function(_, id) called("questie focus " .. id) end),
            SetQuestTomTomTarget = call("SetQuestTomTomTarget", function(id) called("questie arrow " .. id) end),
        }
        local data = { GetQuest = call("GetQuest", function(id) return { id = id } end) }
        local modules = { QuestieTracker = tracker, TrackerUtils = utils, TrackerData = data }
        QuestieLoader = { ImportModule = function(_, name) return modules[name] end }
        Questie = { db = { profile = { trackerEnabled = true } }, API = { isReady = false,
            RegisterOnReady = function(fn) table.insert(Z.ready, fn) end,
            RegisterForQuestUpdates = function(fn) table.insert(Z.updates, fn) end } }
        function Z.Ready()
            Questie.API.isReady = true
            for _, fn in ipairs(Z.ready) do fn() end
        end
        -- its quest updates, and its own tracker redrawn: each alone
        function Z.Changed()
            for _, fn in ipairs(Z.updates) do fn() end
        end
        function Z.Redrawn() tracker.Update() end
    end
end

-- ------------------------------------------------------------ the spellbook
-- Forever's book: General and three specialisations' skill lines, a pet that
-- comes and goes, Blizzard's player-spells frame loaded on demand. Only for
-- the spellbook pass; on retail the micro menu has no spellbook button.
local bookWorld
if spellPass or talentPass or profPass then
    bookWorld = { calls = {}, pet = 0, loaded = false }
    if spellRetail or talentRetail or profRetail then SpellbookMicroButton = nil end
    Enum = Enum or {}
    Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
    Enum.SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
    local S, P, F, X = 1, 2, 3, 4      -- spell, passive, future spell, flyout
    local lines = {
        { name = "General", iconID = 101, spells = { { "Attack", S }, { "Hearthstone", S }, { "Teleports", X } } },
        { name = "Elemental", iconID = 102, spells = { { "Lightning Bolt", S, "Rank 4" }, { "Earth Shock", S, "Rank 2" },
            { "Searing Totem", S, "Rank 1" }, { "Elemental Focus", P }, { "Chain Lightning", F, 32 },
            { "Earth Shock", F, 30 } } },
        -- a spell's two ranks, the book's order: low to high
        { name = "Enhancement", iconID = 103, spells = { { "Rockbiter Weapon", S, "Rank 2" },
            { "Rockbiter Weapon", S, "Rank 3" }, { "Lightning Shield", S } } },
        { name = "Restoration", iconID = 104, spells = { { "Healing Wave", S, "Rank 5" } } },
    }
    local items, offset = {}, 0
    for i, l in ipairs(lines) do
        l.itemIndexOffset, l.numSpellBookItems, l.shouldHide = offset, #l.spells, false
        for j, sp in ipairs(l.spells) do
            local id = i * 100 + j
            items[offset + j] = { actionID = id, spellID = sp[2] ~= X and id or nil,
                itemType = sp[2] == X and 4 or sp[2] == F and 2 or 1, name = sp[1], subName = sp[2] == S and sp[3] or "",
                iconID = 1000 + id, isPassive = sp[2] == P, isOffSpec = false, skillLineIndex = i, level = sp[2] == F and sp[3] }
        end
        offset = offset + #l.spells
    end
    local pets = { { actionID = 901, spellID = 901, itemType = 3, name = "Bite", subName = "", iconID = 1901,
        isPassive = false }, { actionID = 902, spellID = 902, itemType = 3, name = "Growl", subName = "",
        iconID = 1902, isPassive = false } }
    bookWorld.lines, bookWorld.items = lines, items
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return #lines end,
        GetSpellBookSkillLineInfo = function(i) return lines[i] end,
        GetSpellBookItemInfo = function(slot, bank)
            if bank == 1 then return slot <= bookWorld.pet and pets[slot] or nil end
            return items[slot]
        end,
        GetSpellBookItemLevelLearned = function(slot) return items[slot] and items[slot].level or 0 end,
        GetSpellBookItemDescription = function(slot, bank)
            local i = bank == 1 and pets[slot] or items[slot]
            return i and ("About " .. i.name .. ".")
        end,
        HasPetSpells = function() if bookWorld.pet > 0 then return bookWorld.pet, "PET" end end,
        PickupSpellBookItem = function(slot, bank) table.insert(bookWorld.calls, "pickup " .. slot .. "/" .. bank) end,
    }
    function GetPetIcon() return 132599 end
    -- the next frame's timers, run by the pass's frame()
    bookWorld.timers = {}
    C_Timer = { After = function(_, fn) table.insert(bookWorld.timers, fn) end }
    function bookWorld.Tick()
        local now = bookWorld.timers
        bookWorld.timers = {}
        for _, fn in ipairs(now) do fn() end
    end
    C_AddOns.IsAddOnLoaded = function(name) return name == "Blizzard_PlayerSpells" and bookWorld.loaded end
    -- the client's load: the addon's files run, then its ADDON_LOADED
    C_AddOns.LoadAddOn = function(name)
        if name == "Blizzard_PlayerSpells" and not bookWorld.loaded then
            print("book.load at", inCombat and "combat" or "rest")
            bookWorld.Load()
        end
    end
    function ShowUIPanel(f) f:Show() end
    function HideUIPanel(f) f:Hide() end
    -- Blizzard_PlayerSpells, loaded when the book is first asked for: one
    -- frame, a tab each for the book and the talents (Camelot's, without
    -- the tab row); the tab shows its page and hides the other
    PlayerSpellsUtil = { FrameTabs = { ClassSpecializations = 1, ClassTalents = 2, SpellBook = 3 } }
    function bookWorld.Load()
        local f = new("Frame", UIParent, "PlayerSpellsFrame")
        PlayerSpellsFrame = f
        f.shown = false
        f.SpellBookFrame = new("Frame", f)
        f.TalentsFrame = new("Frame", f)
        f.TalentsFrame.shown = false
        f.tab = 3
        -- it holds the book's secure buttons: protected, so in combat it
        -- cannot be moved
        function f:IsProtected() return true end
        function f:GetTab() return self.tab end
        function f:IsFrameTabActive(tab) return self.tab == tab end
        -- bookWorld.stale: a turn that shows the new page and leaves the
        -- other one marked shown, as the in-game N seemed to
        function f:SetTab(tab)
            self.tab = tab
            if bookWorld.stale then
                (tab == 2 and self.TalentsFrame or self.SpellBookFrame):Show()
                return
            end
            self.TalentsFrame:SetShown(tab == 2)
            self.SpellBookFrame:SetShown(tab == 3)
        end
        function f:TrySetTab(tab)
            if self.minimized and tab ~= 3 then
                local shown = self:IsShown()
                if shown then HideUIPanel(self) end
                self:SetTab(tab)
                if shown then ShowUIPanel(self) end
                self.minimized = false
                return true
            end
            self:SetTab(tab)
            return true
        end
        bookWorld.loaded = true
        for _, h in ipairs(events.ADDON_LOADED or {}) do h.scripts.OnEvent(h, "ADDON_LOADED", "Blizzard_PlayerSpells") end
    end
    -- Forever's own toggle (PlayerSpellsUtil.lua): turn the tab, then show.
    -- With another panel open (bookWorld.others) the panel manager minimises
    -- the frame as it shows, and minimised it can show only the book; a
    -- tab turned on a minimised frame maximises it (ForceMaximize).
    function PlayerSpellsUtil.TogglePlayerSpellsFrame(tab)
        if not bookWorld.loaded then bookWorld.Load() end
        local f = PlayerSpellsFrame
        if f:IsShown() and (not tab or f:IsFrameTabActive(tab)) then HideUIPanel(f) return true end
        if tab then f:TrySetTab(tab) end
        if f:IsShown() then return true end
        bookWorld.Panel(f)
        return true
    end
    function PlayerSpellsUtil.OpenToClassTalentsTab()
        if not bookWorld.loaded then bookWorld.Load() end
        PlayerSpellsFrame:TrySetTab(2)
        bookWorld.Panel(PlayerSpellsFrame)
    end
    -- ShowUIPanel's EvaluateAutoMinimize
    function bookWorld.Panel(f)
        ShowUIPanel(f)
        if bookWorld.others and not f.minimized then
            f.minimized = true
            if f.tab ~= 3 then
                f:Hide()
                f:SetTab(3)
                f:Show()
            end
        end
    end
    -- PlayerSpellsUtil's toggles: open, then turn the tab; again on the
    -- open tab, close
    function bookWorld.Toggle(page)
        if not bookWorld.loaded then bookWorld.Load() end
        local f = PlayerSpellsFrame
        local tab = page == "talents" and 2 or 3
        if f:IsShown() and f.tab == tab then HideUIPanel(f) return end
        if not f:IsShown() then ShowUIPanel(f) end
        f:SetTab(tab)
    end
end

-- ------------------------------------------------------------ the talents
-- One tree of three groups (Forever's old trees side by side), a config per
-- spec group: Primary with Elemental's first talent learned, Secondary
-- empty. Ranks are staged, then committed or rolled back.
local talentWorld
if talentPass then
    talentWorld = { calls = {}, active = 1, groups = 1 }
    local T = talentWorld
    -- id, group, x, y, ranks, the talents it opens, locked by tier, a group
    -- listed before its tree's (Shamanistic Focus: the tree's deepest, so
    -- Enhancement is the tallest and the trees' scale is the height's)
    local NODES = {
        { 1, 11, 0, 0, 5, { 3 } }, { 2, 11, 600, 0, 3 }, { 3, 11, 0, 600, 1 }, { 4, 11, 1200, 1800, 1, nil, true },
        { 5, 12, 3000, 0, 5, { 6 } }, { 6, 12, 3600, 600, 2 },
        { 7, 13, 6000, 0, 5 }, { 8, 12, 3000, 3600, 1, nil, true, 99 },
    }
    local NAMES = { "Convection", "Concussion", "Call of Flame", "Elemental Mastery", "Ancestral Knowledge",
        "Shield Specialization", "Improved Healing Wave", "Shamanistic Focus" }
    -- each rank's tooltip: Concussion's ranks differ in a number, Convection's
    -- in their words, Ancestral Knowledge has only its first; the rest have
    -- none, and read their spell's description
    local RANKS = {
        [20] = function(r)
            return "Increases the damage of your Shock spells by " .. ({ "33", "66.5", "100" })[r] .. "% for 10 sec. Stacks up to " .. r .. "."
        end,
        [50] = function(r) return r == 1 and "Increases your maximum Mana by 1%." or nil end,
        [10] = function(r) return r == 1 and "Reduces the mana cost of your spells by 2%." or
            ("Reduces the mana cost of your spells by " .. 2 * r .. "% and their threat.") end,
    }
    NEXT_RANK_COLON = "Next rank:"
    C_TooltipInfo = { GetTraitEntry = function(entry, rank)
        local f = RANKS[entry]
        if not (f and f(rank)) then return nil end
        return { lines = { { leftText = NAMES[entry / 10] }, { leftText = "Rank " .. rank }, { leftText = f(rank) },
            { leftText = "Next rank:" },
            { leftText = (f(math.min(rank + 1, 3)) or f(rank)) .. " A longer line than the rank's own." } } }
    end }
    local byID = {}
    for _, n in ipairs(NODES) do byID[n[1]] = n end
    -- Elemental Mastery's gate is a condition: 8 points in Elemental, where
    -- its tier alone would ask 15
    local CONDS = { [4] = { 904 } }
    T.names = NAMES
    T.committed = { [1] = { [1] = 5 }, [2] = {} }
    T.staged = { [1] = {}, [2] = {} }
    T.points = 12
    local function rank(config, id) return (T.committed[config][id] or 0) + (T.staged[config][id] or 0) end
    local function spent(config, group)
        local n = 0
        for _, d in ipairs(NODES) do
            if not group or d[2] == group then n = n + rank(config, d[1]) end
        end
        return n
    end
    local function meets(config, id)
        for _, d in ipairs(NODES) do
            for _, to in ipairs(d[6] or {}) do
                if to == id and rank(config, d[1]) < d[5] then return false end
            end
        end
        return true
    end
    C_Traits = {
        GetConfigInfo = function(config) return { ID = config, treeIDs = { 500 } } end,
        GetGroupDisplayInfoByTreeID = function()
            return { { groupID = 12, orderIndex = 2, displayName = "Enhancement", icon = 136051 },
                { groupID = 11, orderIndex = 1, displayName = "Elemental", icon = 136048 },
                { groupID = 13, orderIndex = 3, displayName = "Restoration", icon = 136052 } }
        end,
        GetGroupCurrencyInfo = function(config, ids)
            local out = {}
            for _, g in ipairs(ids) do
                table.insert(out, { traitNodeGroupID = g, currencyInfos = { { spent = spent(config, g) } } })
            end
            return out
        end,
        GetTreeCurrencyInfo = function(config) return { { quantity = T.points - spent(config) } } end,
        GetTreeNodes = function() return { 1, 2, 3, 4, 5, 6, 7, 8 } end,
        GetNodeInfo = function(config, id)
            local d = byID[id]
            local r = rank(config, id)
            local edges = {}
            for _, to in ipairs(d[6] or {}) do
                table.insert(edges, { targetNode = to, type = 0, visualStyle = 1, isActive = r >= d[5] })
            end
            local available = not d[7]
            local ok = meets(config, id)
            return { ID = id, posX = d[3], posY = d[4], groupIDs = d[8] and { d[8], d[2] } or { d[2] },
                entryIDs = { id * 10 },
                activeEntry = r > 0 and { entryID = id * 10, rank = r } or nil, ranksPurchased = r,
                maxRanks = d[5], isVisible = true, isAvailable = available, meetsEdgeRequirements = ok,
                canPurchaseRank = available and ok and r < d[5] and T.points - spent(config) > 0,
                canRefundRank = (T.staged[config][id] or 0) > 0, visibleEdges = edges, conditionIDs = CONDS[id] or {} }
        end,
        GetConditionInfo = function(_, cond)
            if cond == 904 then return { condID = 904, isGate = true, type = 0, spentAmountRequired = 8 } end
        end,
        GetEntryInfo = function(_, entry) return { definitionID = entry } end,
        GetDefinitionInfo = function(def) return { spellID = def, overrideName = "", overrideIcon = 0 } end,
        PurchaseRank = function(config, id)
            local info = C_Traits.GetNodeInfo(config, id)
            table.insert(T.calls, "purchase " .. config .. "/" .. id)
            if not info.canPurchaseRank then return false end
            T.staged[config][id] = (T.staged[config][id] or 0) + 1
            return true
        end,
        RefundRank = function(config, id)
            table.insert(T.calls, "refund " .. config .. "/" .. id)
            if (T.staged[config][id] or 0) == 0 then return false end
            T.staged[config][id] = T.staged[config][id] - 1
            return true
        end,
        ConfigHasStagedChanges = function(config)
            for _, n in pairs(T.staged[config]) do
                if n > 0 then return true end
            end
            return false
        end,
        RollbackConfig = function(config)
            table.insert(T.calls, "rollback " .. config)
            T.staged[config] = {}
            return true
        end,
    }
    C_ClassTalents = {
        CommitConfig = function(saved)
            local config = T.active
            table.insert(T.calls, "commit " .. tostring(saved) .. " (config " .. config .. ")")
            for id, n in pairs(T.staged[config]) do T.committed[config][id] = (T.committed[config][id] or 0) + n end
            T.staged[config] = {}
            return true
        end,
    }
    C_SpecializationInfo = C_SpecializationInfo or {}
    C_SpecializationInfo.GetActiveSpecGroup = function() return T.active end
    C_SpecializationInfo.GetCombatConfigIDForSpecGroup = function(g) return g <= T.groups and g or nil end
    C_SpecializationInfo.SetActiveSpecGroup = function(g) table.insert(T.calls, "activate " .. g) end
    function GetNumSpecGroups() return T.groups end
    C_Spell.GetSpellName = function(id) return NAMES[id / 10] end
    C_Spell.GetSpellTexture = function(id) return 2000 + id end
    C_Spell.GetSpellDescription = function(id) return "About " .. NAMES[id / 10] .. "." end
end

-- -------------------------------------------------------- the professions
-- Blacksmithing and Mining, Fishing and Cooking learned (First Aid comes
-- later); Blizzard's ProfessionsFrame loaded on demand, its book a page.
local profWorld
if profPass then
    profWorld = { calls = {}, open = 0, makeable = false, filter = nil, loaded = false }
    local P = profWorld
    -- index -> name, icon, rank, max, spells, offset, skill line, modifier
    P.info = {
        { "Blacksmithing", 136241, 142, 150, 1, 50, 164, 0 },
        { "Mining", 136248, 120, 150, 2, 52, 186, 5 },
        { "First Aid", 135966, 60, 75, 1, 59, 129, 0 },
        { "Fishing", 136245, 60, 75, 1, 55, 356, 0 },
        { "Cooking", 133971, 80, 150, 1, 57, 185, 0 },
    }
    P.learned = { 1, 2, nil, 4, 5 }       -- prof1, prof2, first aid, fishing, cooking
    function GetProfessions() return P.learned[1], P.learned[2], P.learned[3], P.learned[4], P.learned[5] end
    function GetProfessionInfo(i) return unpack(P.info[i]) end
    -- the professions' spells, in the book after the specialisations'
    local spells = { [51] = { 2018, "Blacksmithing" }, [53] = { 2656, "Smelting" }, [54] = { 2580, "Find Minerals" },
        [56] = { 7620, "Fishing" }, [58] = { 2550, "Cooking" }, [60] = { 3273, "First Aid" } }
    local crafts = { [2018] = true, [2656] = true, [2550] = true, [3273] = true }
    local book = C_SpellBook.GetSpellBookItemInfo
    C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
        local s = bank == 0 and spells[slot]
        if s then return { actionID = s[1], spellID = s[1], itemType = 1, name = s[2], iconID = 3000 + slot,
            isPassive = false, subName = "" } end
        return book(slot, bank)
    end
    -- each profession's recipes: id, name, category, difficulty, reagents { item, need }
    P.recipes = {
        [164] = { { 2662, "Copper Chain Pants", 1, 2, { { 2840, 4 } } },
            { 2663, "Copper Bracers", 1, 3, { { 2840, 2 } } },
            { 3115, "Rough Sharpening Stone", 2, 0, { { 2835, 1 } } },
            { 7408, "Heavy Copper Maul", 1, 1, { { 2840, 12 }, { 2880, 1 } } } },
        [186] = { { 2657, "Smelt Copper", 3, 2, { { 2770, 1 } } } },
        [185] = { { 2538, "Charred Wolf Meat", 4, 3, { { 2672, 1 } } },
            { 9001, "Basic Campfire Kit", 6, 2, { { 2589, 1 } } } },
        [129] = { { 3275, "Linen Bandage", 5, 0, { { 2589, 1 } } } },
    }
    -- where a recipe greys, its points a craft, whether it can skill up at all
    P.trivial = { [2662] = { 165, 1 }, [7408] = { 170, 2 }, [3115] = { 95, 1, false }, [2657] = { 70, 1 } }
    local CATS = { "Armor", "Materials", "Smelting", "Meat", "Bandages", "Camping" }
    local ITEMS = { [2840] = "Copper Bar", [2835] = "Rough Stone", [2880] = "Weak Flux", [2770] = "Copper Ore",
        [2672] = "Stringy Wolf Meat", [2589] = "Linen Cloth" }
    P.bags = { [2840] = 10, [2835] = 3, [2770] = 5, [2672] = 0, [2589] = 7 }
    local byID = {}
    for _, list in pairs(P.recipes) do
        for _, r in ipairs(list) do byID[r[1]] = r end
    end
    C_Item = C_Item or {}
    C_Item.GetItemCount = function(id) return P.bags[id] or 0 end
    C_Item.GetItemNameByID = function(id) return ITEMS[id] end
    local function count(id)
        local n = math.huge
        for _, g in ipairs(byID[id][5]) do n = math.min(n, math.floor((P.bags[g[1]] or 0) / g[2])) end
        return n
    end
    C_TradeSkillUI = {
        CanTradeSkillShowCraftingUI = function(spell) return crafts[spell] or false end,
        GetBaseProfessionInfo = function() return { professionID = P.open } end,
        IsDataSourceChanging = function() return P.changing or false end,
        OpenTradeSkill = function(line)
            table.insert(P.calls, "open " .. line)
            return true
        end,
        GetFilteredRecipeIDs = function()
            local out = {}
            for _, r in ipairs(P.recipes[P.open] or {}) do
                if (not P.makeable or count(r[1]) > 0)
                    and (not P.filter or r[2]:lower():find(P.filter:lower(), 1, true)) then
                    table.insert(out, r[1])
                end
            end
            return out
        end,
        GetRecipeInfo = function(id)
            local r = byID[id]
            local t = P.trivial[id] or {}
            return { recipeID = id, name = r[2], icon = 4000 + id % 100, categoryID = r[3],
                relativeDifficulty = r[4], learned = true, maxTrivialLevel = t[1] or 0, numSkillUps = t[2] or 0,
                canSkillUp = t[3] ~= false }
        end,
        GetCategoryInfo = function(cat) return { categoryID = cat, name = CATS[cat] } end,
        GetCraftableCount = count,
        GetRecipeSchematic = function(id)
            local slots = {}
            for _, g in ipairs(byID[id][5]) do
                table.insert(slots, { reagents = { { itemID = g[1] } }, quantityRequired = g[2], required = true })
            end
            -- smelting names its bar; the others are the item they are named for
            return { recipeID = id, quantityMax = id == 3115 and 2 or 1, reagentSlotSchematics = slots,
                outputItemID = id == 2657 and 2840 or nil }
        end,
        GetRecipeCooldown = function(id) return id == 7408 and 3600 or nil end,
        CraftRecipe = function(id, n) table.insert(P.calls, "craft " .. id .. " x" .. n) end,
        SetOnlyShowMakeableRecipes = function(on) P.makeable = on end,
        GetOnlyShowMakeableRecipes = function() return P.makeable end,
        SetRecipeItemNameFilter = function(text) P.filter = text end,
    }
    local loaded = C_AddOns.IsAddOnLoaded
    C_AddOns.IsAddOnLoaded = function(name)
        if name == "Blizzard_Professions" then return P.loaded end
        return loaded(name)
    end
    function SecondsToTime(s) return format("%d min", s / 60) end
    StaticPopup_Show = function(which, a1, _, data)
        table.insert(P.calls, "popup " .. which .. " " .. tostring(a1) .. " " .. tostring(data))
    end
    -- Blizzard_Professions: the frame, its book and crafting pages
    function P.Load()
        local f = new("Frame", UIParent, "ProfessionsFrame")
        ProfessionsFrame = f
        f.shown = false
        f.BookPage = new("Frame", f)
        f.CraftingPage = new("Frame", f)
        f.CraftingPage.shown = false
        P.loaded = true
        for _, h in ipairs(events.ADDON_LOADED or {}) do h.scripts.OnEvent(h, "ADDON_LOADED", "Blizzard_Professions") end
    end
    -- ToggleProfessionsBook: the frame, on its book the first time
    function P.Toggle()
        if not P.loaded then
            P.Load()
            ProfessionsFrame.BookPage:Show()
            ProfessionsFrame.CraftingPage:Hide()
            ShowUIPanel(ProfessionsFrame)
            return
        end
        if ProfessionsFrame:IsShown() then HideUIPanel(ProfessionsFrame) else ShowUIPanel(ProfessionsFrame) end
    end
    -- a profession's list opened (its spell, OpenTradeSkill): TRADE_SKILL_SHOW,
    -- and Blizzard turns to its crafting page
    function P.Show(line)
        if not P.loaded then P.Load() end
        P.open = line
        local f = ProfessionsFrame
        f.BookPage:Hide()
        f.CraftingPage:Show()
        ShowUIPanel(f)
        for _, h in ipairs(events.TRADE_SKILL_SHOW or {}) do h.scripts.OnEvent(h, "TRADE_SKILL_SHOW") end
        for _, h in ipairs(events.TRADE_SKILL_LIST_UPDATE or {}) do h.scripts.OnEvent(h, "TRADE_SKILL_LIST_UPDATE") end
    end
end

-- ------------------------------------------------------------ the NPC
-- Blizzard's three conversation frames, and the APIs our pages read: a
-- gossip of text, a quest each way and two options; the quest pages; a
-- vendor of three (one an extended cost, one above the high price), two
-- bought back, a repair bill and two grey items in the bags. Every act is
-- logged in npcWorld.calls. Only for the npc pass.
local npcWorld
if npcPass or bankPass then
    npcWorld = { calls = {}, combat = false }
    local W = npcWorld
    local function called(...)
        local parts = {}
        for i = 1, select("#", ...) do table.insert(parts, tostring((select(i, ...)))) end
        table.insert(W.calls, table.concat(parts, " "))
    end
    W.called = called
    for _, n in ipairs({ "GossipFrame", "QuestFrame", "MerchantFrame" }) do
        local f = new("Frame", UIParent, n)
        f.shown = false
    end
    MerchantFrame.selectedTab = 1
    -- the shared quest info: a rewards frame of its own, shown by Blizzard on
    -- QUEST_ITEM_UPDATE whether or not QuestInfo_Display took it in
    QuestInfoRewardsFrame = new("Frame", nil, "QuestInfoRewardsFrame")
    QuestInfoRewardsFrame.shown = false
    QuestInfoFrame = new("Frame", nil, "QuestInfoFrame")
    QuestInfoFrame.rewardsFrame = QuestInfoRewardsFrame
    function QuestInfo_ShowRewards() QuestInfoFrame.rewardsFrame:Show() end
    W.gossip = { text = "Who is this shaman who goes before the Court?",
        active = { { title = "WANTED: Gath'Ilzogg", questID = 201, isComplete = true } },
        available = { { title = "Messenger to Westfall", questID = 202, frequency = 1 } },
        options = { { name = "Let me browse your goods.", icon = 132060, gossipOptionID = 302, orderIndex = 1 },
            { name = "I would like to train.", icon = 132058, gossipOptionID = 301, orderIndex = 0 } } }
    C_GossipInfo = {
        GetText = function() return W.gossip.text end,
        GetActiveQuests = function() return W.gossip.active end,
        GetAvailableQuests = function() return W.gossip.available end,
        GetOptions = function() local o = {} for i, v in ipairs(W.gossip.options) do o[i] = v end return o end,
        SelectOption = function(id) called("SelectOption", id) end,
        SelectActiveQuest = function(id) called("SelectActiveQuest", id) end,
        SelectAvailableQuest = function(id) called("SelectAvailableQuest", id) end,
        CloseGossip = function() called("CloseGossip"); GossipFrame:Hide() end,
    }
    -- the quest pages
    W.quest = { title = "Solomon's Law", text = "Bring me the pendants.", objectives = "Turn in 10 pendants.",
        progress = "Have you the pendants?", reward = "You have done well.", completable = false,
        required = 1, choices = 2, rewards = 1, money = 1550, xp = 450, auto = false }
    local Q = W.quest
    function GetGreetingText() return "Greetings, traveller." end
    function GetNumActiveQuests() return 1 end
    function GetNumAvailableQuests() return 1 end
    function GetActiveTitle() return "Solomon's Law" end
    function GetAvailableTitle() return "Look to the Stars" end
    function GetActiveQuestID() return 203 end
    function GetAvailableQuestInfo() return false, 0 end
    function SelectActiveQuest(i) called("SelectActiveQuest(i)", i) end
    function SelectAvailableQuest(i) called("SelectAvailableQuest(i)", i) end
    -- an empty quest log, so the tracker is built and can be covered
    C_QuestLog = C_QuestLog or {}
    C_QuestLog.IsComplete = C_QuestLog.IsComplete or function() return false end
    C_QuestLog.GetInfo = C_QuestLog.GetInfo or function() end
    C_QuestLog.GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries or function() return 0 end
    C_Timer = C_Timer or { After = function() end }
    C_Timer.NewTicker = C_Timer.NewTicker or function() end
    function GetTitleText() return Q.title end
    function GetQuestText() return Q.text end
    function GetObjectiveText() return Q.objectives end
    function GetProgressText() return Q.progress end
    function GetRewardText() return Q.reward end
    function GetNumQuestItems() return Q.required end
    function GetQuestMoneyToGet() return 0 end
    function GetNumQuestChoices() return Q.choices end
    function GetNumQuestRewards() return Q.rewards end
    function GetRewardMoney() return Q.money end
    function GetRewardXP() return Q.xp end
    function GetQuestItemInfo(kind, i) return kind .. i, "icon-" .. kind .. i, kind == "required" and 10 or 1, 2, true end
    function IsQuestCompletable() return Q.completable end
    function QuestGetAutoAccept() return Q.auto end
    function AcceptQuest() called("AcceptQuest") end
    function AcknowledgeAutoAcceptQuest() called("AcknowledgeAutoAcceptQuest") end
    function DeclineQuest() called("DeclineQuest") end
    function CompleteQuest() called("CompleteQuest") end
    function GetQuestReward(i) called("GetQuestReward", i) end
    function CloseQuest() called("CloseQuest"); QuestFrame:Hide() end
    -- the vendor
    W.items = { { name = "Mining Pick", texture = 1, price = 81, stackCount = 1, numAvailable = -1, isUsable = true },
        { name = "Elemental Flux", texture = 2, price = 1500, stackCount = 5, numAvailable = 3, isUsable = true,
            hasExtendedCost = true },
        -- not cached yet: no name, and no link
        { texture = 4, price = 125, stackCount = 5, numAvailable = -1, isUsable = true },
        { name = "Swift Mount", texture = 3, price = 2000000, stackCount = 1, numAvailable = -1, isUsable = false } }
    W.buyback = { { "Linen Cloth", 4, 13, 20 }, { "Broken Fang", 5, 7, 1 } }
    W.repair, W.canRepair, W.guild, W.money = 104, true, false, 23655
    C_MerchantFrame = { GetItemInfo = function(i) return W.items[i] end }
    function GetMerchantNumItems() return #W.items end
    function GetMerchantItemLink(i) return W.items[i].name and "|Hitem:" .. (900 + i) .. "|h" or nil end
    function GetMerchantItemMaxStack(i) return i == 2 and 20 or 1 end
    function GetMerchantItemCostInfo(i) return i == 2 and 1 or 0 end
    function GetMerchantItemCostItem() return "icon-mark", 2 end
    function BuyMerchantItem(i, n) called("BuyMerchantItem", i, n) end
    function GetNumBuybackItems() return #W.buyback end
    function GetBuybackItemInfo(i) local b = W.buyback[i] return b[1], b[2], b[3], b[4], nil, true end
    function BuybackItem(i) called("BuybackItem", i) end
    function CanMerchantRepair() return W.canRepair end
    function CanGuildBankRepair() return W.guild end
    function GetRepairAllCost() return W.repair, W.repair > 0 end
    function RepairAllItems(guild) called("RepairAllItems", guild) end
    function GetMoney() return W.money end
    function CloseMerchant() called("CloseMerchant"); MerchantFrame:Hide() end
    function IsModifiedClick(action) return W.modified == action end
    function ChatEdit_GetActiveWindow() return W.chatOpen end
    function ChatEdit_InsertLink(l) called("ChatEdit_InsertLink", l) end
    function DressUpItemLink(l) called("DressUpItemLink", l) end
    -- two grey items in the backpack, one that sells for nothing
    W.bag = { [1] = { itemID = 701, quality = 0, stackCount = 3 }, [2] = { itemID = 702, quality = 0, stackCount = 1 },
        [3] = { itemID = 703, quality = 0, hasNoValue = true }, [4] = { itemID = 704, quality = 2 },
        [5] = { itemID = 705, quality = 3, stackCount = 2, itemName = "Star Ruby", iconFileID = 55, hyperlink = "ruby" },
        [6] = { itemID = 706, quality = 1 } }      -- the vendor buys it for nothing
    C_Container = bankPass and C_Container or {     -- the bank's pass keeps the bags'
        GetContainerNumSlots = function(bag) return bag == 0 and 6 or 0 end,
        GetContainerNumFreeSlots = function() return 0 end,
        GetContainerItemInfo = function(bag, slot) return bag == 0 and W.bag[slot] or nil end,
        UseContainerItem = function(bag, slot) called("UseContainerItem", bag, slot) end,
    }
    C_Item = C_Item or {}
    C_Item.GetItemInfo = function(id)
        if type(id) == "string" then return "x", id, id:match("901") and 1 or 3 end
        return "junk" .. id, nil, 0, nil, nil, nil, nil, nil, nil, nil, id == 701 and 25 or id == 705 and 400 or id == 706 and 0 or 10
    end
    ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.1, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
    function GameTooltip:SetMerchantItem(i) self.item = "merchant" .. i end
    function GameTooltip:SetBuybackItem(i) self.item = "buyback" .. i end
    function GameTooltip:SetBagItem(bag, slot) self.item = "bag" .. bag .. ":" .. slot end
    function GameTooltip:SetQuestItem(kind, i) self.item = kind .. i end
    -- the trainer: two to learn (one beyond your money), one not yet (level
    -- 40, a skill and a rank before it), one known, flat as Forever lists
    -- them. The game's filter decides which it lists; training one makes it
    -- known. ClassTrainerFrame comes only with Blizzard_TrainerUI. Each
    -- has its skill line, but Blink, which has none (Other).
    W.services = {
        { name = "Fireball", rank = "Rank 2", category = "available", cost = 100, desc = "Hurls a fiery ball.",
            line = "Fire" },
        { name = "Blink", rank = "", category = "available", cost = 400 },
        { name = "Frost Armor", rank = "Rank 2", category = "available", cost = 150, line = "Frost" },
        { name = "Pyroblast", rank = "Rank 1", category = "available", cost = 50000, line = "Fire" },
        { name = "Fire Ward", rank = "", category = "unavailable", cost = 200, level = 40, line = "Fire",
            skill = { "Fire", 50, false }, abilities = { { "Fireball (Rank 3)", false }, { "Arcane Mind", true } } },
        { name = "Frostbolt", rank = "Rank 1", category = "used", cost = 0, line = "Frost" },
    }
    W.tfilter = { available = true, unavailable = true, used = true }
    local function listed()
        local out = {}
        for _, v in ipairs(W.services) do
            if W.tfilter[v.category] then table.insert(out, v) end
        end
        return out
    end
    function GetNumTrainerServices() return #listed() end
    -- the NPC's tooltip: its name, then its trade or (none) its level
    W.trade = nil
    C_TooltipInfo = C_TooltipInfo or {}
    C_TooltipInfo.GetUnit = function(unit)
        if unit ~= "npc" then return end
        return { lines = { { leftText = UnitName("npc") }, { leftText = W.trade or "Level 30" } } }
    end
    -- Forever's order: name, type, icon, level, rank
    function GetTrainerServiceInfo(i)
        local v = listed()[i]
        if v then return v.name, v.category, "icon-" .. v.name, v.level or 0, v.rank or "" end
    end
    function GetTrainerServiceCost(i) return listed()[i].cost end
    function GetTrainerServiceDescription(i) return listed()[i].desc end
    function GetTrainerServiceSkillLine(i) return listed()[i].line or "" end
    function GetTrainerServiceLevelReq(i) return listed()[i].level or 0 end
    function GetTrainerServiceSkillReq(i) local k = listed()[i].skill if k then return k[1], k[2], k[3] end end
    function GetTrainerServiceNumAbilityReq(i) return #(listed()[i].abilities or {}) end
    function GetTrainerServiceAbilityReq(i, j) local a = listed()[i].abilities[j] return a[1], a[2] end
    function GetTrainerGreetingText() return "Hello, mage." end
    function GetTrainerServiceTypeFilter(t) return W.tfilter[t] end
    -- the game's own check: on/off is a boolean
    function SetTrainerServiceTypeFilter(t, on)
        if type(on) ~= "boolean" then error("Missing on/off parameter in SetTrainerServiceTypeFilter", 2) end
        W.tfilter[t] = on
        called("SetTrainerServiceTypeFilter", t, on)
    end
    function ExpandTrainerSkillLine(i) called("ExpandTrainerSkillLine", i) end
    function BuyTrainerService(i)
        local v = listed()[i]
        called("BuyTrainerService", i, v.name)
        v.category = "used"
    end
    function CloseTrainer() called("CloseTrainer"); ClassTrainerFrame:Hide() end
    function GameTooltip:SetTrainerService(i) self.item = "trainer" .. i end
    -- Blizzard_TrainerUI's own show: the panel, then the trainer closed
    -- at once if the frame is not visible (a frame under a hidden parent)
    function W.ShowTrainer()
        ClassTrainerFrame:Show()
        if not ClassTrainerFrame:IsVisible() then CloseTrainer() end
    end
    function W.LoadTrainer()
        if ClassTrainerFrame then return end
        local f = new("Frame", UIParent, "ClassTrainerFrame")
        f.shown = false
        for _, h in ipairs(events.ADDON_LOADED or {}) do h.scripts.OnEvent(h, "ADDON_LOADED", "Blizzard_TrainerUI") end
    end
    -- the flight map: Forever's TaxiFrame, there from the start. Ironforge
    -- is here; Algaz sits on it (pushed off); Menethil one hop; Sentinel
    -- Hill two, through distant Darkshire, and beyond your money; Aerie
    -- Peak out of reach, on Darkshire (a distant node pushes no near one);
    -- a seventh is no node at all.
    local taxi = new("Frame", UIParent, "TaxiFrame")
    taxi.shown = false
    W.nodes = {
        { name = "Ironforge", kind = "CURRENT", x = 0.5, y = 0.5 },
        { name = "Menethil Harbor", kind = "REACHABLE", x = 0.3, y = 0.6, cost = 5000, legs = { { 1, 2 } } },
        { name = "Sentinel Hill", kind = "REACHABLE", x = 0.2, y = 0.1, cost = 10500, legs = { { 1, 4 }, { 4, 3 } } },
        { name = "Darkshire", kind = "DISTANT", x = 0.6, y = 0.2 },
        { name = "Aerie Peak", kind = "UNREACHABLE", x = 0.605, y = 0.205 },
        { name = "Algaz Station", kind = "REACHABLE", x = 0.505, y = 0.505, cost = 800, legs = { { 1, 6 } } },
        { name = "Nowhere", kind = "NONE", x = 0, y = 0 },
    }
    function NumTaxiNodes() return #W.nodes end
    function TaxiNodeName(i) return W.nodes[i].name end
    function TaxiNodeGetType(i) return W.nodes[i].kind end
    function TaxiNodePosition(i) return W.nodes[i].x, W.nodes[i].y end
    function TaxiNodeCost(i) return W.nodes[i].cost or 0 end
    function GetNumRoutes(i) return #(W.nodes[i].legs or {}) end
    function TaxiGetNodeSlot(i, leg, src) return W.nodes[i].legs[leg][src and 1 or 2] end
    function TaxiIsDirectFlight(i) return #(W.nodes[i].legs or {}) == 1 end
    function TakeTaxiNode(i) called("TakeTaxiNode", i, W.nodes[i].name) end
    function SetTaxiMap(t) t:SetTexture("taxi-map"); called("SetTaxiMap") end
    -- the game: closing fires TAXIMAP_CLOSED, on which Blizzard hides its frame
    function CloseTaxiMap()
        called("CloseTaxiMap")
        if TaxiFrame.shown then TaxiFrame:Hide() end
    end
    ERR_TAXINOPATHS = "You know no flight paths connected to this one."
    UIErrorsFrame = new("Frame", UIParent, "UIErrorsFrame")
    function UIErrorsFrame:AddMessage(m) called("error", m) end
    W.tip = {}
    function GameTooltip:AddLine(t) table.insert(W.tip, tostring(t)) end
end

-- ------------------------------------------------------------ the mailbox
-- Blizzard's MailFrame and the mail API over six letters: cloth from a
-- friend (two items, unread), an auction's money, a COD order, a game
-- master's gift, a letter of words only, and one that came back. A take
-- happens at once but answers (MAIL_INBOX_UPDATE, MAIL_SUCCESS, or
-- MAIL_FAILED with the bags full) only on mailWorld.Answer(); until then a
-- command is pending. mailWorld.busy refuses that many commands outright
-- (MAIL_FAILED, no item named); an item in mailWorld.kept is refused by name.
-- Every act is logged in mailWorld.calls.
local mailWorld
if mailPass then
    mailWorld = { calls = {}, free = 10, money = 23655, send = {}, tickers = {} }
    local M = mailWorld
    local function called(...)
        local parts = {}
        for i = 1, select("#", ...) do table.insert(parts, tostring((select(i, ...)))) end
        table.insert(M.calls, table.concat(parts, " "))
    end
    MailFrame = new("Frame", UIParent, "MailFrame")
    MailFrame.shown = false
    function M.Fresh()
        M.inbox = {
            { sender = "Thalric", subject = "Spare cloth", money = 0, days = 9.5, reply = true, body = "Here is the cloth.",
                items = { { "Linen Cloth", 2589, "icon-linen", 20 }, { "Wool Cloth", 2592, "icon-wool", 5 } } },
            { sender = "Alliance Auction House", subject = "Auction successful: Linen Cloth", money = 12000, days = 29,
                read = true,
                canDelete = true },
            { sender = "Okun", subject = "Your order", money = 0, cod = 10000, days = 2.4, reply = true,
                items = { { "Heavy Leather", 4234, "icon-leather", 10 } } },
            { sender = "Blizzard", subject = "Welcome", money = 500, days = 1.5, gm = true, read = true, canDelete = true },
            { sender = "Mira", subject = "Hello", money = 0, days = 0.5, read = true, reply = true,
                body = "Just saying hello." },
            { sender = "Thalen", subject = "Back to you", money = 300, days = 20, returned = true },
        }
        M.pending, M.answers, M.busy, M.kept = false, {}, 0, {}
    end
    M.Fresh()
    local function count(l)
        local n = 0
        for a = 1, 16 do if l.items and l.items[a] then n = n + 1 end end
        return n
    end
    -- a letter emptied of all it held, and that the game may delete, goes
    local function emptied(i)
        local l = M.inbox[i]
        if l and l.canDelete and l.money == 0 and count(l) == 0 then table.remove(M.inbox, i) end
    end
    function GetInboxNumItems() return #M.inbox, M.total or #M.inbox end
    function GetInboxHeaderInfo(i)
        local l = M.inbox[i]
        if not l then return end
        local n = count(l)
        return "pkg", "icon-letter" .. i, l.sender, l.subject, l.money, l.cod or 0, l.days, n > 0 and n or nil,
            l.read or false, l.returned or false, false, l.reply or false, l.gm or false
    end
    function GetInboxText(i) M.inbox[i].read = true return M.inbox[i].body end
    function GetInboxItem(i, a)
        local it = M.inbox[i] and M.inbox[i].items and M.inbox[i].items[a]
        if it then return it[1], it[2], it[3], it[4] end
    end
    function InboxItemCanDelete(i) return M.inbox[i].canDelete or false end
    local function command(name, answer)
        called(name)
        M.pending = true
        table.insert(M.answers, answer)
    end
    -- the mailbox busy: the command refused, nothing done
    local function busy(name)
        if M.busy == 0 then return end
        M.busy = M.busy - 1
        command(name .. " (refused)", { "MAIL_FAILED" })
        return true
    end
    function TakeInboxMoney(i)
        local l = M.inbox[i]
        if busy("TakeInboxMoney " .. i) then return end
        command("TakeInboxMoney " .. i .. " " .. l.money, "MAIL_SUCCESS")
        M.money, l.money = M.money + l.money, 0
        emptied(i)
    end
    function TakeInboxItem(i, a)
        local l = M.inbox[i]
        if busy("TakeInboxItem " .. i .. " " .. a) then return end
        if M.free == 0 then return command("TakeInboxItem " .. i .. " " .. a .. " (bags full)", "MAIL_FAILED") end
        if M.kept[l.items[a][2]] then
            return command("TakeInboxItem " .. i .. " " .. a .. " (kept)", { "MAIL_FAILED", l.items[a][2] })
        end
        command("TakeInboxItem " .. i .. " " .. a, "MAIL_SUCCESS")
        l.items[a], M.free = nil, M.free - 1
        if (l.cod or 0) > 0 then M.money, l.cod = M.money - l.cod, 0 end
        emptied(i)
    end
    function AutoLootMailItem(i) called("AutoLootMailItem", i) end
    function ReturnInboxItem(i) called("ReturnInboxItem", i) table.remove(M.inbox, i) end
    function DeleteInboxItem(i) called("DeleteInboxItem", i) table.remove(M.inbox, i) end
    -- the game's answer to the command waiting: the inbox drawn again, then the outcome
    function M.Answer()
        local e = table.remove(M.answers, 1)
        M.pending = #M.answers > 0
        if type(e) ~= "table" then e = { e } end
        for _, f in ipairs(events.MAIL_INBOX_UPDATE or {}) do f.scripts.OnEvent(f, "MAIL_INBOX_UPDATE") end
        for _, f in ipairs(events[e[1]] or {}) do f.scripts.OnEvent(f, e[1], e[2]) end
    end
    C_Mail = { IsCommandPending = function() return M.pending end,
        SetOpeningAll = function(on) called("SetOpeningAll", on) end }
    function CloseMail() called("CloseMail") MailFrame:Hide() end
    function GetSendMailItem(i)
        local v = M.send[i]
        if v then return v[1], v[2], v[3], v[4] end
    end
    function GetSendMailPrice()
        local n = 0
        for i = 1, 12 do if M.send[i] then n = n + 1 end end
        return 30 * math.max(1, n)
    end
    -- an item on the cursor goes in; with clear, or nothing on the cursor, it comes back
    function ClickSendMailItemButton(i, clear)
        called("ClickSendMailItemButton", i, clear)
        local held = GetCursorInfo()
        if not clear and type(held) == "table" and held[1] == "item" then
            M.send[i] = { "Item" .. held[2], held[2], "icon-" .. held[2], 1 }
            ClearCursor()
        elseif clear or not held then
            M.send[i] = nil
        end
    end
    function ClearSendMail() called("ClearSendMail") M.send = {} end
    function SetSendMailMoney(c) called("SetSendMailMoney", c) end
    function SetSendMailCOD(c) called("SetSendMailCOD", c) end
    function SendMail(to, subject, body) called("SendMail", to, subject, body) end
    function SetSendMailShowing(on) called("SetSendMailShowing", on) end
    function GetRealmName() return "Nordanaar" end
    -- at a mailbox the "npc" is the mailbox, by that name
    local unitName = UnitName
    function UnitName(u) if u == "npc" then return "Mailbox" end return unitName(u) end
    -- the game's names for a letter: an alt never played since, a friend
    M.known = { "Ahry", "Aeryn", "Thalric" }
    function GetAutoCompleteResults(text, n)
        local out = {}
        for _, who in ipairs(M.known) do
            if who:lower():sub(1, #text) == text:lower() and #out < n then table.insert(out, { name = who, priority = 1 }) end
        end
        return out
    end
    function GetMoney() return M.money end
    MAIL_REPLY_PREFIX = "RE:"
    C_Container = C_Container or {}
    C_Container.CalculateTotalNumberOfFreeBagSlots = function() return M.free end
    C_Timer = C_Timer or { After = function() end }
    C_Timer.NewTicker = function(_, fn)
        local t = { fn = fn }
        function t.Cancel() t.cancelled = true end
        table.insert(M.tickers, t)
        return t
    end
    -- the ticker's beats, as many as asked, time moving on with them
    function M.Tick(n)
        for _ = 1, n or 1 do
            now = now + 0.15
            for _, t in ipairs(M.tickers) do if not t.cancelled then t.fn() end end
        end
    end
end

-- ------------------------------------------------------------ load + fire
local ns = {}
harnessNS = ns     -- for the helpers above it (harnessNextFrame)
for line in io.lines(ADDON .. "Medalluin.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(ADDON .. line:gsub("\\", "/")))
        chunk("Medalluin", ns)
    end
end
for _, f in ipairs(events.ADDON_LOADED or {}) do f.scripts.OnEvent(f, "ADDON_LOADED", "Medalluin") end
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do
    for _, f in ipairs(events[e] or {}) do
        local h = f.scripts.OnEvent
        if h then h(f, e) end
    end
end
-- the state driver manager's first update after login: the pages land
stateTick()
for _, b in pairs(ns.units) do
    if (UnitExists(b.unit) or b.stub) and b.scripts.OnShow then b.scripts.OnShow(b) end
end
if savedSimParty then HarnessCrowns("crowns, simulated") end

-- The settings window's controls, as page.settings[key]: Set works the
-- control as a player would (a checkbox clicked, a dropdown opened and its
-- row clicked); a value the control already shows, or a colour, goes through
-- ns.SetOption, as the old page's setting reported itself either way. A
-- control that is greyed out (its page's master off) is still set, and says so.
-- What a control shows, in words: a tick, a dropdown's text, a swatch.
function optionShown(c)
    local k = c.spec.kind
    if k == "check" then return tostring(c.tick.shown) end
    if k == "choice" then return c.button.value.text end
    if k == "color" then return table.concat(c.swatch.color, ",", 1, 3) end
    if k == "slider" then return c.value.text end
    if k == "key" then return c.box.text.text end
    return "-"
end
function optionShows(key)
    ns.BuildOptions()
    return optionShown(ns.optionControls[key])
end
-- The options whose control shows something other than the option.
function optionsStale()
    ns.BuildOptions()
    local stale = {}
    for key, c in pairs(ns.optionControls) do
        local k, v = c.spec.kind, ns.db[key]
        local want = k == "check" and tostring(v and true or false) or nil
        if k == "choice" then
            want = tostring(v)
            for _, ch in ipairs(c.spec.choices) do if ch[1] == v then want = ch[2] end end
        elseif k == "color" then
            want = table.concat({ ns.HexColor(v) }, ",")
        elseif k == "slider" then
            want = c.spec.text and c.spec.text(v) or tostring(v)
        elseif k == "key" then
            local keys = ns.BindingKeys(c.spec.command)
            want = c.box.listening and "Press a key" or #keys == 0 and "Not bound" or ns.KeyText(keys[1])
        end
        if want ~= optionShown(c) then table.insert(stale, key) end
    end
    table.sort(stale)
    return table.concat(stale, " ")
end
-- The Party layout's list, as this profile shows it: each choice and its tip.
function partyLayoutMenu(tag)
    ns.OpenOptions("console/general")
    local layout = ns.optionControls.partyLayout
    layout.button.scripts.OnClick(layout.button)
    for _, row in ipairs(MedalluinOptionsMenu.rows) do
        if row.shown then
            print("party layout menu " .. tag, (row.mark.shown and "*" or "") .. row.text.text, row.tip)
        end
    end
    layout.button.scripts.OnClick(layout.button)
    ns.CloseOptions()
end

local function menuRow(value)
    for _, row in ipairs(MedalluinOptionsMenu and MedalluinOptionsMenu.rows or {}) do
        if row.shown and row.value == value then return row end
    end
end
setmetatable(page, {
    __index = function(_, k)
        if k == "opened" then return ns.OptionsShown() end
        if k ~= "settings" then return nil end
        local settings = setmetatable({}, { __index = function(t, key)
            ns.BuildOptions()
            local c = ns.optionControls[key]
            if not c then return nil end
            local s = { key = key, control = c }
            function s:Get() return ns.db[key] end
            function s:Default() return ns.OptionBase(key) end
            function s:Set(v)
                local hit = c.spec.kind == "choice" and c.button or c.less or c.box or c
                if not hit:IsEnabled() then print("settings: " .. key .. " set while greyed out") end
                if c.spec.kind == "check" and ns.db[key] ~= v then
                    c.scripts.OnClick(c)
                elseif c.spec.kind == "choice" and ns.db[key] ~= v then
                    hit.scripts.OnClick(hit)
                    local row = menuRow(v)
                    if row then
                        row.scripts.OnClick(row)
                    else
                        print("settings: " .. key .. " offers no " .. tostring(v))
                        ns.SetOption(key, v)
                    end
                else
                    ns.SetOption(key, v)
                end
            end
            rawset(t, key, s)
            return s
        end })
        rawset(page, "settings", settings)
        return settings
    end,
    __newindex = function(t, k, v)
        if k == "opened" then
            if v == nil then ns.CloseOptions() end
        else
            rawset(t, k, v)
        end
    end,
})

-- The console's own rectangle defines the origin: its top-left is (0, 0).
local c = ns.console
scaleRoot = c
c.fixed = { 0, 0, ns.art.width, ns.art.height }
local function out(tag, f, extra)
    local r = resolve(f)
    print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1], r[2], r[3], r[4], extra or ""))
end

if barPass then
    -- the screen in console units: the console's top-left is (612, 916)
    UIParent.fixed = { -612, -916, 1308, 164 }
    local function screen(tag, f, extra)
        local r = resolve(f)
        print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1] + 612, r[2] + 916, r[3] + 612,
            r[4] + 916, extra or ""))
    end
    print("page", page.name, page.registered and "registered" or "-", "proxy settings=" .. page.proxies)
    -- Options > AddOns > Medalluin: its words in order, and its one button
    local function texts(f, out)
        for _, r in ipairs(f.all_ or {}) do
            if r.kind == "FontString" and r.text then table.insert(out, r.text) end
            texts(r, out)
        end
        return out
    end
    print("info", table.concat(texts(page.frame, {}), " | "))
    for _, r in ipairs(page.frame.all_) do
        if r.kind == "Button" then
            SettingsPanel.shown = true
            r.scripts.OnClick(r)
            print("info button", "opens=" .. tostring(page.opened), "panel closed=" .. tostring(not SettingsPanel.shown))
        end
    end
    -- the window: each page, its tree row and tabs, its controls in order
    -- (where each sits on the page, what it shows, whether it can be changed)
    local win = MedalluinOptions
    local shows = optionShown
    local function lit(list, on)
        local o = {}
        for _, x in ipairs(list) do
            if x.shown ~= false then table.insert(o, (on(x) and "*" or "") .. x.text.text) end
        end
        return table.concat(o, " ")
    end
    local function dump(path)
        ns.OpenOptions(path)
        local f = ns.optionPages[page.opened]
        print("window " .. tostring(page.opened), "tree=" .. lit(win.tree.rows, function(r) return r.lit.shown end),
            "tabs=" .. lit(win.tabs, function(t) return not t.edge[2].shown end),
            "height=" .. f.h, "range=" .. win.scroll:GetVerticalScrollRange(),
            "thumb=" .. tostring(win.thumb.shown))
        -- a group's heading must draw over its border, not under it: on a
        -- frame no lower than the one the border is drawn on
        local over, groups = 0, 0
        for _, e in ipairs(f.all_ or {}) do
            if e.title then
                groups = groups + 1
                if e.title.parent.level >= e.level then over = over + 1 end
            end
        end
        print("  headings over their borders", over .. "/" .. groups)
        local top = resolve(f)
        for _, c in ipairs(f.controls) do
            local r = resolve(c)
            local choices = {}
            for _, ch in ipairs(c.spec.choices or {}) do table.insert(choices, tostring(ch[1]) .. "=" .. ch[2]) end
            local hit = c.spec.kind == "choice" and c.button or c.less or c.box or c
            print("  " .. c.spec.kind, c.spec.label, tostring(c.spec.key), "shows=" .. shows(c),
                hit:IsEnabled() and "live" or "grey", string.format("at=%d,%d %dx%d", r[1] - top[1], r[2] - top[2],
                    c.w, c.h), c.spec.reload and "reload" or "", table.concat(choices, "; "))
        end
    end
    print("window", "size=" .. win.w .. "x" .. win.h, "strata=" .. tostring(win.strata),
        "esc=" .. tostring(UISpecialFrames[1]), "title=" .. win.title.text)
    for _, path in ipairs({ "general", "console/general", "console/bar", "console/overhead",
        "console/minimap", "units/general", "units/party", "units/raid", "units/battleground", "units/boss",
        "units/arena", "chat", "side/general", "side/auras", "side/meter", "side/loot", "bags" }) do dump(path) end
    -- a master off greys its page; the footer asks for a reload
    page.settings.bags:Set(false)
    dump("bags")
    print("  footer", win.footProfile.text, "reload=" .. tostring(win.footReload.shown))
    page.settings.bags:Set(true)
    print("  bags back", "reload=" .. tostring(win.footReload.shown))
    -- the side panel off greys its tabs' pages, each tab's own master too
    page.settings.side:Set(false)
    dump("side/auras")
    page.settings.side:Set(true)
    -- a dropdown's list: its choices, the one in use marked; a row chosen
    ns.OpenOptions("units/party")
    local range = ns.optionControls.partyRange
    range.button.scripts.OnClick(range.button)
    local menu = MedalluinOptionsMenu
    local rows = {}
    for _, row in ipairs(menu.rows) do
        if row.shown then table.insert(rows, (row.mark.shown and "*" or "") .. row.text.text) end
    end
    print("menu partyRange", "shown=" .. tostring(menu.shown), "strata=" .. tostring(menu.strata), table.concat(rows, " | "))
    for _, row in ipairs(menu.rows) do
        if row.value == 30 then row.scripts.OnClick(row) end
    end
    print("menu chosen", "partyRange=" .. tostring(ns.db.partyRange), "shows=" .. shows(range),
        "menu shown=" .. tostring(menu.shown))
    range.button.scripts.OnClick(range.button)
    range.button.scripts.OnClick(range.button)
    print("menu again closes", "shown=" .. tostring(menu.shown))
    -- a font's list: each in its own font, asked as it opens (a shared one
    -- registered since), and past sixteen in columns
    ns.OpenOptions("quests")
    local fontChoice = ns.optionControls.questsTitleFont
    local stub = LibStub
    local shared = { names = {} }
    for i = 1, 14 do table.insert(shared.names, "Shared " .. i) end
    table.insert(shared.names, "Marcellus Again")
    function shared:List() return self.names end
    function shared:Fetch(_, name)
        return name == "Marcellus Again" and ns.font or "Fonts\\" .. name:gsub(" ", "") .. ".ttf"
    end
    LibStub = function(major) if major == "LibSharedMedia-3.0" then return shared end end
    local function fonts(tag)
        fontChoice.button.scripts.OnClick(fontChoice.button)
        local out = {}
        for _, row in ipairs(menu.rows) do
            if row.shown then
                local p = row.points.TOPLEFT
                table.insert(out, string.format("%s%s(%s)@%d,%d", row.mark.shown and "*" or "", row.text.text,
                    tostring(row.text.font[1]):match("[^\\]+$"), p[3], p[4]))
            end
        end
        print(tag, "size=" .. menu.w .. "x" .. menu.h, table.concat(out, " "))
        fontChoice.button.scripts.OnClick(fontChoice.button)
    end
    fonts("menu fonts")
    for _, row in ipairs(menu.rows) do
        if row.value == "lsm:Shared 3" then row.scripts.OnClick(row) end
    end
    print("menu font chosen", tostring(ns.db.questsTitleFont), "shows=" .. shows(fontChoice))
    LibStub = stub
    ns.RefreshOptions()
    print("menu font gone", "shows=" .. shows(fontChoice), "path=" .. ns.FontPath(ns.db.questsTitleFont))
    page.settings.questsTitleFont:Set("marcellus")
    menu:SetSize(0, 0)
    fonts("menu fonts plain")
    page.settings.partyRange:Set(40)
    partyLayoutMenu("medallion")
    -- the colour swatch: the game's picker, turned, then cancelled
    local art = ns.optionControls.artColor
    art.scripts.OnClick(art)
    local info = ColorPickerFrame.info
    print("colour picker", "shown=" .. tostring(ColorPickerFrame.shown), "from=" .. table.concat(ColorPickerFrame.rgb, ","))
    ColorPickerFrame.rgb = { 1, 0.5, 0 }
    info.swatchFunc()
    print("colour turned", "artColor=" .. ns.db.artColor, "swatch=" .. shows(art))
    info.cancelFunc()
    print("colour cancelled", "artColor=" .. ns.db.artColor, "swatch=" .. shows(art))
    -- the long page scrolls, and a new page starts at its top
    ns.OpenOptions("console/overhead")
    win.scroll.scripts.OnMouseWheel(win.scroll, -1)
    print("scroll overhead", "at=" .. win.scroll:GetVerticalScroll(), "thumb=" .. tostring(win.thumb.shown))
    win.scroll.scripts.OnMouseWheel(win.scroll, -100)
    print("scroll overhead bottom", "at=" .. win.scroll:GetVerticalScroll() .. "/" .. win.scroll:GetVerticalScrollRange())
    ns.OpenOptions("console/bar")
    print("scroll bar", "at=" .. win.scroll:GetVerticalScroll(), "thumb at=" .. win.thumb.points.TOPRIGHT[4])
    -- the Console page comes back on the tab it was left on
    ns.OpenOptions("console/overhead")
    ns.OpenOptions("general")
    ns.OpenOptions("console")
    print("console again", tostring(page.opened))
    -- the title drags the window; where it is left is kept
    harnessDropAt = { "TOPLEFT", "TOPLEFT", 120.4, -80.6 }
    local grip = win.titleBox
    grip.scripts.OnDragStart(grip)
    grip.scripts.OnDragStop(grip)
    print("dragged", "optionsPoint=" .. table.concat(ns.db.optionsPoint, ","))
    win.closeX.scripts.OnClick(win.closeX)
    print("closed", "opened=" .. tostring(page.opened))
    SlashCmdList.MEDALLUIN()
    print("/medalluin opens", tostring(page.opened))
    -- /medalluin and /mui are one command; /mdlui is its own, to the same place
    local slashes = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^SLASH_") then slashes[#slashes + 1] = k .. "=" .. tostring(v) end
    end
    table.sort(slashes)
    print("slash commands", table.concat(slashes, " "), "same=" .. tostring(SlashCmdList.MEDALLUIN == SlashCmdList.MDLUI))
    SlashCmdList.MDLUI("console")
    print("/mdlui console opens", tostring(page.opened))
    SlashCmdList.MDLUI()
    print("/mdlui opens", tostring(page.opened))
    SlashCmdList.MDLUI("unit")
    print("/mdlui unit opens", tostring(page.opened))
    -- Medalluin's minimap button: in the drawer, or on the minimap without one
    do
        local mb = ns.minimapButton
        local where = mb.parent == ns.drawer and "drawer" or mb.parent == Minimap and "minimap" or tostring(mb.parent)
        local p = mb.points.CENTER
        print("minimapButton", where, "texture=" .. tostring(mb.icon.texture):match("[^\\]+$"),
            "size=" .. mb.w .. "x" .. mb.h, "above the map=" .. tostring(mb.level > Minimap.level),
            mb.parent == Minimap and p and ("at=" .. p[2] .. string.format("%+.0f,%+.0f", p[3], p[4])
                .. " of " .. string.format("%.0f", Minimap.w)) or "")
        local lines = {}
        local add = GameTooltip.AddLine
        GameTooltip.AddLine = function(_, t) table.insert(lines, t) end
        local function tip(tag)
            lines = {}
            mb.scripts.OnEnter(mb)
            print(tag, GameTooltip.text, table.concat(lines, " | "), tipSpec())
        end
        tip("minimapButton tip")
        page.opened = nil
        mb.scripts.OnClick(mb, "LeftButton")
        print("minimapButton left", "opens=" .. tostring(page.opened), "simParty=" .. tostring(ns.db.simParty))
        mb.scripts.OnClick(mb, "RightButton")
        print("minimapButton right", "simParty=" .. tostring(ns.db.simParty),
            "window shows=" .. optionShows("simParty"), "opens=" .. tostring(page.opened))
        tip("minimapButton tip on")
        mb.scripts.OnClick(mb, "RightButton")
        print("minimapButton right again", "simParty=" .. tostring(ns.db.simParty))
        GameTooltip.AddLine = add
    end
    if StatusTrackingBarManager then
        local c = MainStatusTrackingBarContainer
        print("status bars", "manager=" .. (StatusTrackingBarManager.parent == ns.hidden and "hidden" or "kept"),
            "container in manager=" .. tostring(c.parent == StatusTrackingBarManager),
            "silenced=" .. tostring(c.unregistered and SecondaryStatusTrackingBarContainer.unregistered or false),
            "edit mode=" .. (pcall(c.UpdateShownState, c) and "ok" or "error"))
    end
    if not ns.actionBar then
        print("tray none")
        -- no bar, no cast bar of Medalluin's: Blizzard's stays
        for _, k in ipairs({ "CastingBarFrame", "PlayerCastingBarFrame" }) do
            if _G[k] then print(k .. ".parent", _G[k].parent == ns.hidden and "hidden" or "kept") end
        end
    else
        screen("bar", ns.actionBar)
        screen("plate", ns.barPlate, "texture=" .. tostring(ns.barPlate.texture):match("[^\\]+$")
            .. " level=" .. ns.barPlate.parent.level)
        -- behind the slots, a dark band; the plate stands over the bars and
        -- the toggle, so its trapezoid and round window crop them
        local bk = ns.barBacking
        screen("backing", bk, "colour=" .. (bk.color and string.format("%.2f,%.2f,%.2f,%s", bk.color[1],
            bk.color[2], bk.color[3], tostring(bk.color[4] or 1)) or "-") .. " level=" .. bk.parent.level)
        local stoneLevel = ns.barPlate.parent.level
        print("under the plate", "power=" .. tostring(ns.barPower.level < stoneLevel),
            "cast=" .. tostring(ns.barCast.level < stoneLevel), "toggle=" .. tostring(ns.drawerToggle.level < stoneLevel),
            "backing=" .. tostring(bk.parent.level < stoneLevel))
        print("over the plate", "buttons=" .. tostring(ActionButton1.level > stoneLevel),
            "pager=" .. tostring(not ns.pager or ns.pager.level > stoneLevel),
            "cast text inset=" .. ns.barCast.name.points.LEFT[3] .. "," .. ns.barCast.clock.points.RIGHT[3])
        local strip, shown = ns.barPower, {}
        screen("lowRow", strip, "level=" .. strip.level)
        -- the hybrid row: the lower row on its own frame, its piece under
        -- the bars, so it outlives Bar 1's fade
        local hy, hb = ns.hybridBar, ns.hybridBacking
        if hy then
            screen("hybrid", hb, "texture=" .. tostring(hb.texture):match("[^\\]+$") .. " layer=" .. tostring(hb.layer)
                .. " level=" .. hy.level .. " holds power=" .. tostring(strip.parent == hy)
                .. " cast=" .. tostring(ns.barCast.parent == hy) .. " in the tray=" .. tostring(hy.parent == ns.actionBar))
        else
            print("hybrid", "none")
        end
        for i, b in ipairs(strip.segments) do
            if b.shown then table.insert(shown, i) end
        end
        print("power", class, "segments=" .. #shown)
        if class == "DRUID" then
            -- into cat form: the combo points come up
            catForm = true
            for _, f in ipairs(events.UPDATE_SHAPESHIFT_FORM or {}) do f.scripts.OnEvent(f, "UPDATE_SHAPESHIFT_FORM") end
            shown = {}
            for i, b in ipairs(strip.segments) do
                if b.shown then table.insert(shown, i) end
            end
            print("power", "cat form", "segments=" .. #shown)
        end
        for _, i in ipairs({ shown[1], shown[#shown] }) do
            local b = strip.segments[i]
            screen("segment" .. i, b, string.format("min=%s max=%s value=%s", b.min, b.max, tostring(b.value)))
        end
        -- dragonriding: mounting a skyriding mount shows 6 vigor charges in cyan
        isDragonriding = true
        vigorCharges = 4
        vigorStart = now - 2.5
        vigorDur = 5
        for _, f in ipairs(events.PLAYER_CAN_GLIDE_CHANGED or {}) do f.scripts.OnEvent(f, "PLAYER_CAN_GLIDE_CHANGED", true) end
        local vigorShown = {}
        for i, b in ipairs(strip.segments) do
            if b.shown then table.insert(vigorShown, i) end
        end
        local col = strip.segments[1].barColor
        print("dragonriding", "segments=" .. #vigorShown,
            string.format("colour=%.2f,%.2f,%.2f", col[1], col[2], col[3]),
            "val=" .. tostring(strip.segments[5].value))
        isDragonriding = false
        for _, f in ipairs(events.PLAYER_CAN_GLIDE_CHANGED or {}) do f.scripts.OnEvent(f, "PLAYER_CAN_GLIDE_CHANGED", false) end
        local backShown = {}
        for i, b in ipairs(strip.segments) do
            if b.shown then table.insert(backShown, i) end
        end
        col = strip.segments[1].barColor
        print("dismounted", "segments=" .. #backShown,
            string.format("colour=%.2f,%.2f,%.2f", col[1], col[2], col[3]))
        -- the cast bar over the class resource: idle, a cast, its interruption
        local cb = ns.barCast
        local function castState(tag)
            print(tag, string.format("alpha=%s value=%s name=%s clock=%s colour=%s", tostring(cb.alpha),
                tostring(cb.value), tostring(cb.name.text), tostring(cb.clock.text),
                cb.barColor and string.format("%.2f", cb.barColor[1]) or "-"))
        end
        screen("cast", cb, "level=" .. cb.level .. " over power=" .. tostring(cb.level > strip.level))
        castState("cast idle")
        -- a unit event reaches the frames registered for that unit only
        local function cast(e, id, unit)
            unit = unit or "player"
            for _, f in ipairs(events[e] or {}) do
                if not f.unitOf or f.unitOf[e] == unit then f.scripts.OnEvent(f, e, unit, id) end
            end
            cb.scripts.OnUpdate(cb, 0.1)
        end
        casting = true
        cast("UNIT_SPELLCAST_START", 7)
        castState("cast start")
        cast("UNIT_SPELLCAST_INTERRUPTED", 7)
        castState("cast interrupted")
        casting = false
        now = now + 1
        cb.scripts.OnUpdate(cb, 1)
        castState("cast faded")
        now = now - 1
        -- a cast that completes: full, then fades in gold
        casting = true
        cast("UNIT_SPELLCAST_START", 7)
        casting = false
        cast("UNIT_SPELLCAST_STOP", 7)
        castState("cast done")
        now = now + 1
        cb.scripts.OnUpdate(cb, 1)
        castState("cast done, faded")
        now = now - 1

        -- the lower row's other two, chosen on the page: the swing timer
        -- (Forever's PLAYER_SWING) and mana; the cast bar over each
        local sw, mn = ns.barSwing, ns.barMana
        local function heard(f, e)
            for _, g in ipairs(events[e] or {}) do
                if g == f then return "y" end
            end
            return "n"
        end
        local function rowState(tag)
            local function one(b)
                return string.format("%s value=%.2f/%s clock=%s", b.shown and "shown" or "hidden", b.value,
                    tostring(b.max), tostring(b.clock.text))
            end
            print("low row " .. tag, "resource=" .. tostring(strip.shown), "swing " .. one(sw), "mana " .. one(mn),
                "hears swing=" .. heard(sw, "PLAYER_SWING") .. " mana=" .. heard(mn, "UNIT_POWER_FREQUENT"))
        end
        ns.BuildOptions()
        print("low row", "choices=" .. #ns.optionControls.barLowRow.spec.choices,
            string.format("swing colour=%.2f,%.2f,%.2f", sw.barColor[1], sw.barColor[2], sw.barColor[3]),
            string.format("mana colour=%.2f,%.2f,%.2f", mn.barColor[1], mn.barColor[2], mn.barColor[3]),
            "level=" .. sw.level .. "," .. mn.level .. " cast over=" .. tostring(cb.level > sw.level),
            "on the row=" .. tostring(sw.points.TOPLEFT[4] == strip.points.TOPLEFT[4]
                and mn.points.BOTTOMRIGHT[3] == strip.points.BOTTOMRIGHT[3]))
        rowState("as saved")
        local function swing(d, hand)
            for _, f in ipairs(events.PLAYER_SWING or {}) do f.scripts.OnEvent(f, "PLAYER_SWING", d, hand) end
        end
        local function later(s)
            now = now + s
            if sw.shown and sw.scripts.OnUpdate then sw.scripts.OnUpdate(sw, s) end
        end
        page.settings.barLowRow:Set("swing")
        rowState("swing, idle")
        swing(2.6, 0)
        rowState("swing, main hand")
        later(1.3)
        rowState("swing, halfway")
        swing(1.4, 1)
        rowState("swing, the off hand's")
        swing(3, 2)
        rowState("swing, a ranged shot")
        later(1.5)
        rowState("swing, ranged halfway")
        later(1.5)
        rowState("swing, landed")
        local ticking = sw.scripts.OnUpdate ~= nil
        local realPower = UnitPower
        UnitPower = function(_, kind) return kind == 0 and 12345 or 60 end
        page.settings.barLowRow:Set("mana")
        rowState("mana")
        UnitPower = function(_, kind) return kind == 0 and 777 or 60 end
        local function power(kind)
            for _, f in ipairs(events.UNIT_POWER_FREQUENT or {}) do
                if f == mn then f.scripts.OnEvent(f, "UNIT_POWER_FREQUENT", "player", kind) end
            end
        end
        power("ENERGY")
        rowState("mana, energy changed")
        power("MANA")
        rowState("mana, mana changed")
        local realMax = UnitPowerMax
        UnitPowerMax = function() return 0 end
        power("MANA")
        rowState("mana, a class without")
        UnitPowerMax = realMax
        swing(2, 0)
        print("low row", "swing ticking after it landed=" .. tostring(ticking),
            "swing heard while hidden=" .. tostring(sw.scripts.OnUpdate ~= nil))
        -- retail: no swing timer, and a profile holding it shows the resource
        local realSwing = C_SwingTimer
        C_SwingTimer = nil
        page.settings.barLowRow:Set("swing")
        rowState("swing, on retail")
        C_SwingTimer = realSwing
        UnitPower = realPower
        page.settings.barLowRow:Set("resource")
        rowState("resource again")
        casting = true
        cast("UNIT_SPELLCAST_START", 7)
        castState("cast over the row")
        casting = false
        cast("UNIT_SPELLCAST_STOP", 7)
        now = now + 1
        cb.scripts.OnUpdate(cb, 1)
        now = now - 1 - 4.3
        -- the beam as cast bars: off by default; on, the player's casts over
        -- experience and the target's over reputation, each clear while its
        -- unit is idle
        local beam = ns.beamCast
        local function tick()
            for _, b in pairs(beam) do b.scripts.OnUpdate(b, 0.1) end
        end
        local function beamState(tag)
            local function one(b)
                return string.format("shown=%s alpha=%s value=%s timer=%s", tostring(b.shown), tostring(b.alpha),
                    tostring(b.value), b.timer and "yes" or "-")
            end
            print(tag, "player " .. one(beam.player), "target " .. one(beam.target))
        end
        for _, k in ipairs({ "player", "target" }) do
            local b = beam[k]
            local spark, ink
            for _, t in ipairs(b.all_) do
                if t.points.CENTER then spark = t end
                if t.color and t.color[1] == ns.colors.ink[1] then ink = t.layer end
            end
            screen("beam " .. k, b, string.format("reverse=%s level=%d spark=%s ink=%s", tostring(b.reverse),
                b.level, spark.points.CENTER[2], tostring(ink)))
        end
        beamState("beam as saved")
        casting = true
        cast("UNIT_SPELLCAST_START", 7)
        beamState("beam off, casting")
        casting = false
        cast("UNIT_SPELLCAST_STOP", 7)
        page.settings.xpCast:Set(true)
        page.settings.repCast:Set(true)
        beamState("beam on")
        casting = true
        cast("UNIT_SPELLCAST_START", 7)
        tick()
        beamState("beam player casting")
        casting = false
        cast("UNIT_SPELLCAST_STOP", 7)
        now = now + 1
        tick()
        now = now - 1
        beamState("beam player done")
        castUnit, casting = "target", true
        cast("UNIT_SPELLCAST_START", 7, "target")
        tick()
        beamState("beam target casting")
        -- a new target that is not casting
        casting = false
        for _, f in ipairs(events.PLAYER_TARGET_CHANGED or {}) do
            if f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_TARGET_CHANGED") end
        end
        beamState("beam target changed")
        -- the option switched off mid-cast
        castUnit, casting = "player", true
        cast("UNIT_SPELLCAST_START", 7)
        page.settings.xpCast:Set(false)
        beamState("beam option off")
        -- and on again, the cast still under way
        page.settings.xpCast:Set(true)
        beamState("beam option on mid-cast")
        page.settings.xpCast:Set(false)
        casting = false
        cast("UNIT_SPELLCAST_STOP", 7)
        now = now + 1
        cb.scripts.OnUpdate(cb, 1)
        now = now - 1
        page.settings.repCast:Set(false)
        -- the minimap button drawer: closed, then open each way
        local toggle, drawer = ns.drawerToggle, ns.drawer
        local function glyph()
            local function name(t) return tostring(t and t.texture):match("[^\\]+$") end
            return name(toggle:GetNormalTexture()) .. "/" .. name(toggle:GetPushedTexture())
                .. " lit=" .. tostring(toggle.highlightLocked)
        end
        local function drawerState(tag)
            local names = {}
            for _, f in ipairs({ Minimap:GetChildren() }) do
                if f.parent == drawer then table.insert(names, f.name) end
            end
            print(tag, "glyph=" .. glyph(), "open=" .. tostring(drawer.shown), "taken=" .. table.concat(names, ","))
            if drawer.shown then
                screen("drawer", drawer, "level=" .. drawer.level)
                for _, name in ipairs({ "BagnonMinimapButton", "LibDBIcon10_Zeta", "LibDBIcon10_Late" }) do
                    local b = _G[name]
                    if b and b.parent == drawer and b.shown then
                        screen(name, b, string.format("scale=%.3f level=%d", b:GetScale(), b.level))
                    end
                end
            end
        end
        screen("drawerToggle", toggle, "level=" .. toggle.level)
        drawerState("drawer closed")
        toggle.scripts.OnClick(toggle)
        drawerState("drawer open")
        -- LibDBIcon re-places a button round the minimap: it goes back
        LibDBIcon10_Zeta:ClearAllPoints()
        LibDBIcon10_Zeta:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
        screen("Zeta re-placed", LibDBIcon10_Zeta)
        page.settings.drawer:Set(2)
        drawerState("drawer up")
        -- an addon hides its button, and one loads late
        BagnonMinimapButton:Hide()
        BagnonMinimapButton.scripts.OnHide(BagnonMinimapButton)
        MinimapButton("LibDBIcon10_Late", 31)
        QuestieLate()
        toggle.scripts.OnClick(toggle)
        toggle.scripts.OnClick(toggle)
        drawerState("drawer rescanned")
        -- a secure button taken makes the line protected: what comes in
        -- combat (an addon loading, a button shown) waits for its end
        drawer.IsProtected = function() return true end
        inCombat = true
        BagnonMinimapButton:Show()
        BagnonMinimapButton.scripts.OnShow(BagnonMinimapButton)
        ns.drawerScan()
        print("drawer in combat", string.format("%.0fx%.0f", drawer.w, drawer.h))
        inCombat = false
        for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
        print("drawer after combat", string.format("%.0fx%.0f", drawer.w, drawer.h))
        drawer.IsProtected = nil
        BagnonMinimapButton:Hide()
        BagnonMinimapButton.scripts.OnHide(BagnonMinimapButton)
        -- the pointer on the open drawer, outside the tray, keeps a faded bar up
        page.settings.visibility:Set(3)
        mouseOver = drawer
        for _ = 1, 20 do ns.barFade.scripts.OnUpdate(ns.barFade, 0.05) end
        print("drawer hover", string.format("%.2f", ns.actionBar.alpha or 1))
        mouseOver = false
        page.settings.visibility:Set(1)
        for _ = 1, 20 do ns.barFade.scripts.OnUpdate(ns.barFade, 0.05) end
        BagnonMinimapButton:Show()
        page.settings.drawer:Set(1)
        toggle.scripts.OnClick(toggle)
        for _, k in ipairs({ "CastingBarFrame", "PlayerCastingBarFrame" }) do
            if _G[k] then print(k .. ".parent", _G[k].parent == ns.hidden and "hidden" or "kept") end
        end
        if ns.pager then
            local p = ns.pager
            screen("pager", p, "parent=" .. tostring(p.parent == ns.actionBar and "bar" or "other")
                .. " level=" .. p.level .. " scale=" .. p:GetScale() .. " text=" .. tostring(p.Text.text))
            for _, k in ipairs({ "UpButton", "DownButton" }) do
                local b, tex = p[k], {}
                for _, state in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
                    local t = b["Get" .. state .. "Texture"](b)
                    table.insert(tex, (t and t.texture and t.texture:match("[^\\]+$") or "-")
                        .. (t and t.desaturated and "(grey)" or ""))
                end
                screen(k, b, table.concat(tex, " "))
            end
            local t = p.Text
            resolve(t)
            print(string.format("pagerText\t%.1f\t%.1f", t.cx + 612, t.cy + 916))
        else
            print("pager none")
        end
    end
    local adopted = {}
    for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }) do
        local n = 0
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if (ns.actionBar and b.parent == ns.actionBar) or (ns.extraBars and b.parent == ns.extraBars) then
                n = n + 1
                if i == 1 or i == 12 then
                    screen(b.name, b, "level=" .. b.level .. " scale=" .. b:GetScale()
                        .. " styled=" .. tostring(b.medalluinIcon ~= nil))
                    if b.HotKey then
                        print(b.name .. ".hotkey", tostring(b.HotKey.text), tostring(b.HotKey.shown))
                    end
                end
            end
        end
        table.insert(adopted, prefix .. "=" .. n)
    end
    print("adopted", table.concat(adopted, " "))
    -- a tenth of a second on every frame that is shown and updating: a
    -- ticker that should be hidden would run over Blizzard's own buttons
    local ticking = 0
    for _, f in ipairs(all) do
        if f.shown and f.scripts.OnUpdate and f ~= ns.barFade and f ~= ns.extraBarFade then
            f.scripts.OnUpdate(f, 0.2)
            ticking = ticking + 1
        end
    end
    print("ticking", ticking)
    for _, bar in ipairs({ "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight" }) do
        if _G[bar] then print(bar .. ".parent", _G[bar].parent == ns.hidden and "hidden" or "kept") end
    end
    if not ns.actionBar then return end

    -- the live options, as the panel changes them
    local S = page.settings
    local function v(t) return t.vertex and string.format("%.2f,%.2f,%.2f", t.vertex[1], t.vertex[2], t.vertex[3]) end
    local tex = ns.barPlate
    print("tint", v(tex))
    S.artColor:Set("ff806040")
    print("tint ff806040", v(tex))
    -- the range tint: red only out of range of an enemy target, and the
    -- usable colour back after it (Blizzard's numbers, or the bare icons')
    do
        local b = ActionButton1
        local function range(tag, inRange, hostile, target)
            rangeOf[b.action], targetHostile, hasTarget = inRange, hostile, target
            ActionButton_UpdateRangeIndicator(b, inRange ~= nil, inRange)
            print("range " .. tag, "icon=" .. tostring(v(b.icon)))
        end
        b:UpdateUsable()
        print("range usable", "icon=" .. tostring(v(b.icon)))
        range("enemy out", false, true, true)
        b:UpdateUsable()
        print("range enemy out, usable update", "icon=" .. tostring(v(b.icon)))
        range("enemy in", true, true, true)
        range("friend out", false, false, true)
        range("enemy out again", false, true, true)
        hasTarget = false
        for _, f in ipairs(events.PLAYER_TARGET_CHANGED or {}) do f.scripts.OnEvent(f, "PLAYER_TARGET_CHANGED") end
        print("range target cleared", "icon=" .. tostring(v(b.icon)))
        range("no range check", nil, true, true)
        manaShort[b.action] = true
        b:UpdateUsable()
        range("short of mana, enemy out", false, true, true)
        range("short of mana, enemy in", true, true, true)
        manaShort[b.action] = nil
        -- walking into range with the target held: no event, no usable
        -- update, only the ticker (2026-11-05: with the art it stuck red)
        local function walk(tag, inRange)
            rangeOf[b.action] = inRange
            ns.barTicker.scripts.OnUpdate(ns.barTicker, 0.2)
            print("range " .. tag, "ticker=" .. tostring(ns.barTicker.shown), "icon=" .. tostring(v(b.icon)))
        end
        walk("walked out, ticker", false)
        walk("walked in, ticker", true)
        b:UpdateUsable()
        rangeOf[b.action], targetHostile, hasTarget = nil, true, true
    end
    if ns.pager then
        actionPage = 2
        for _, f in ipairs(events.ACTIONBAR_PAGE_CHANGED or {}) do f.scripts.OnEvent(f, "ACTIONBAR_PAGE_CHANGED") end
        print("page 2", tostring(ns.pager.Text.text))
    end
    local function fire(e)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e) end
    end
    local function settle()
        for _ = 1, 20 do ns.barFade.scripts.OnUpdate(ns.barFade, 0.05) end
        return string.format("%.2f", ns.actionBar.alpha or 1)
    end
    -- what is left of the lower row: its alpha down the parents
    local function low()
        local a, r = 1, ns.barPower
        while r do a, r = a * (r.alpha or 1), r.parent end
        return string.format("%.2f", a)
    end
    local function settleExtra()
        for _ = 1, 20 do ns.extraBarFade.scripts.OnUpdate(ns.extraBarFade, 0.05) end
        return string.format("%.2f", ns.extraBars.alpha or 1)
    end
    for mode = 1, 4 do
        S.visibility:Set(mode)
        local line = {}
        mouseOver, cursor = false, nil
        table.insert(line, "idle=" .. settle() .. "(low=" .. low() .. ")")
        mouseOver = true
        table.insert(line, "hover=" .. settle())
        mouseOver = false
        fire("PLAYER_REGEN_DISABLED")
        table.insert(line, "combat=" .. settle())
        fire("PLAYER_REGEN_ENABLED")
        cursor = "spell"
        table.insert(line, "dragging=" .. settle())
        cursor = nil
        print("visibility " .. mode, table.concat(line, " "))
    end
    S.visibility:Set(1)
    settle()
    for mode = 1, 4 do
        S.extraVisibility:Set(mode)
        local line = {}
        mouseOver, cursor = false, nil
        table.insert(line, "idle=" .. settleExtra() .. "(bar1=" .. settle() .. ")")
        mouseOver = true
        table.insert(line, "hover=" .. settleExtra())
        mouseOver = false
        fire("PLAYER_REGEN_DISABLED")
        table.insert(line, "combat=" .. settleExtra())
        fire("PLAYER_REGEN_ENABLED")
        cursor = "spell"
        table.insert(line, "dragging=" .. settleExtra())
        cursor = nil
        print("extraVisibility " .. mode, table.concat(line, " "))
    end
    return
end

if sidePass then
    -- the screen in console units: the console's top-left is (612, 916)
    UIParent.fixed = { -612, -916, 1308, 164 }
    local function rect(f)
        local r = resolve(f)
        return r[1] + 612, r[2] + 916, r[3] + 612, r[4] + 916
    end
    local function screen(tag, f, extra)
        local l, t, r, b = rect(f)
        print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, l, t, r, b, extra or ""))
    end
    -- the group's own class colours, for this pass only
    for k, c in pairs({ PRIEST = { 1, 1, 1 }, WARRIOR = { 0.78, 0.61, 0.43 }, MAGE = { 0.25, 0.78, 0.92 },
        HUNTER = { 0.67, 0.83, 0.45 } }) do
        rawset(RAID_CLASS_COLORS, k, { r = c[1], g = c[2], b = c[3] })
    end
    local side = ns.side
    if not side.panel then
        print("side none", "panel=" .. tostring(_G.MedalluinSide ~= nil))
        return
    end
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local p = side.panel
    local ink = side.dress.ink.gradient
    screen("sidePanel", p, string.format("strata=%s ink=%s %.2f>%.2f rule=%s", tostring(p.strata), ink[1],
        ink[2][4], ink[3][4], tostring(side.dress.rule.points.BOTTOMLEFT[4])))
    screen("side area", side.area, "wheel=" .. tostring(side.area.wheel))
    screen("side row", side.row)
    -- the mirror of the chat box about the screen's middle (1920 wide)
    if ns.chat then
        local cl, ct, cr, cb = rect(ns.chat.box)
        local sl, st, sr, sb = rect(p)
        print("mirror", string.format("left=%.1f right=%.1f top=%.1f bottom=%.1f", sl - (1920 - cr),
            sr - (1920 - cl), st - ct, sb - cb))
    end
    local views = {}
    for _, v in ipairs(side.views) do views[v.key] = v end
    local function tabs()
        local list = {}
        for _, v in ipairs(side.views) do
            if v.tab and v.tab.shown then
                local l, _, r, b = rect(v.tab)
                local name = v.tab.glyph.texture:match("side%-(.*)$") or v.key
                table.insert(list, string.format("%s@%.0f-%.0f,%.0f(%.2f)%s", name, l, r, b,
                    v.tab.glyph.alpha or 1, v.tab.mark.shown and "*" or ""))
            end
        end
        print("tabs", p.shown and "panel" or "panel hidden", string.format("h=%d", p:GetHeight()),
            #list > 0 and table.concat(list, " ") or "none")
    end
    local function column(v)
        local list = {}
        for _, b in ipairs(v.paint) do
            local l, t, r, bt = rect(b)
            table.insert(list, string.format("%s%s%s@%.0f,%.0f", b.glyph.texture:match("side%-(.*)$"),
                b.mark.shown and "+" or "", b.glyph.vertex and string.format("(%.2f,%.2f,%.2f)",
                b.glyph.vertex[1], b.glyph.vertex[2], b.glyph.vertex[3]) or "", (l + r) / 2, (t + bt) / 2))
        end
        print("column " .. v.key, v.column.shown and "shown" or "hidden", table.concat(list, " "))
    end
    -- the scroll bar: its track, and the thumb when there is more than shows
    local track, bar
    for _, r in ipairs(side.area.all_) do
        if r.kind == "Texture" and r.w == 8 then track = r elseif r.kind == "Texture" and r.w == 6 then bar = r end
    end
    screen("track", track)
    local function thumb(tag)
        if not bar.shown then print("thumb " .. tag, "hidden") return end
        bar.rect = nil
        screen("thumb " .. tag, bar)
    end
    local function click(v, i, mouse)
        local b = v.paint[i]
        b.scripts.OnClick(b, mouse or "LeftButton")
    end
    tabs()
    for _, v in ipairs(side.views) do
        if v.body then
            screen("body " .. v.key, v.body)
            column(v)
        end
    end

    -- every tooltip the panel shows stands outside it, at its left, level
    -- with what is hovered: each frame in it with a hover that takes the
    -- tooltip, by its view
    local function sideTips(tag)
        local beside, other = {}, {}
        local panel = side.panel
        local function walk(f, view)
            for _, c in ipairs(f.all_ or {}) do
                local v = view
                for _, sv in ipairs(side.views) do
                    if c == sv.body or c == sv.column then v = sv.key end
                end
                if c.scripts and c.scripts.OnEnter then
                    GameTooltip.owner, GameTooltip.points = nil, {}
                    c.scripts.OnEnter(c)
                    if GameTooltip.owner == c then
                        local at = GameTooltip.points.TOPRIGHT
                        local top, edge = c:GetTop(), panel:GetTop()
                        local level = at and top and edge and math.abs(at[4] - (top - edge)
                            * panel:GetEffectiveScale() / GameTooltip:GetEffectiveScale()) < 0.01
                        local ok = at and at[1] == panel and at[2] == "TOPLEFT" and at[3] == -4 and level
                        local t = ok and beside or other
                        t[v or "panel"] = (t[v or "panel"] or 0) + 1
                    end
                    if c.scripts.OnLeave then c.scripts.OnLeave(c) end
                end
                walk(c, v)
            end
        end
        walk(panel)
        local function list(t)
            local o = {}
            for k, n in pairs(t) do table.insert(o, k .. "=" .. n) end
            table.sort(o)
            return #o > 0 and table.concat(o, ",") or "none"
        end
        print(tag, "beside: " .. list(beside), "elsewhere: " .. list(other))
    end
    -- ---------------------------------------------------------- loot
    local L = views.loot
    local function lootState(tag)
        print(tag)
        for _, f in ipairs(L.body.all_) do
            if f.shown and f.kind == "Frame" and f.title then
                local _, t = rect(f)
                print("", string.format("head@%.0f", t), f.title.text, f.when.text)
            elseif f.shown and f.kind == "Button" and f.item then
                local _, t = rect(f)
                print("", string.format("row@%.0f", t), f.link.text, string.format("edge=%.2f,%.2f,%.2f",
                    unpack(f.edge.color)), "icon=" .. tostring(f.icon.texture), f.who.text,
                    f.who.textColor and string.format("(%.2f,%.2f,%.2f)", unpack(f.who.textColor)) or "",
                    f.how.text, f.die.shown and tostring(f.die.texture):match("[^\\]+$") or "-")
            end
        end
        local _, shown, total = L.Thumb()
        print("", "thumb", L.Thumb(), shown, total)
    end
    side.views[1].tab.scripts.OnClick(side.views[1].tab)
    lootState("loot at login")
    -- chat lines: the player's loot, a group member's, a stack, trash money
    local function chat(e, msg) fire(e, msg, "") end
    chat("CHAT_MSG_LOOT", "You receive loot: " .. itemLink(30003, "Ashtongue Signet", 3) .. ".")
    chat("CHAT_MSG_LOOT", "Thalen-Realm receives loot: " .. itemLink(30004, "Felsteel Bar", 2) .. "x4.")
    chat("CHAT_MSG_LOOT", "You receive loot: " .. itemLink(30005, "Broken Fang", 0) .. ".")
    chat("CHAT_MSG_LOOT", "You receive loot: " .. itemLink(30099, "Uncached Thing", 2) .. ".")
    chat("CHAT_MSG_MONEY", "You loot 6 Gold, 75 Silver")
    chat("CHAT_MSG_MONEY", "Your share of the loot is 1 Gold, 5 Copper.")
    chat("CHAT_MSG_CURRENCY", "You receive currency: |cffffffff|Hcurrency:1792|h[Honor]|h|r x15.")
    chat("CHAT_MSG_LOOT", "Ahrymx creates: something.")        -- not loot: left to the chat
    lootState("loot after trash")
    -- a boss: its drop rolls, the chat tells the win first, then the history
    now = now + 300
    clock = "21:14"
    loot.encounters[2] = { encounterID = 602, encounterName = "Gurtogg Bloodboil", startTime = 9 }
    loot.drops[602] = { { lootListKey = 1, itemHyperlink = itemLink(30002, "Shoulderpads of Renewed Life", 4),
        allPassed = false, rollInfos = {} } }
    fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 602)
    lootState("loot rolling")
    chat("CHAT_MSG_LOOT", "Mira-Realm receives loot: " .. itemLink(30002, "Shoulderpads of Renewed Life", 4) .. ".")
    loot.drops[602][1].winner = { playerName = "Mira-Realm", playerClass = "PRIEST", isSelf = false, state = 0,
        roll = 87 }
    fire("LOOT_HISTORY_UPDATE_DROP", 602, 1)
    -- a second drop the player wins on greed, the history first this time
    table.insert(loot.drops[602], { lootListKey = 2, itemHyperlink = itemLink(30006, "Bloodboil's Cord", 1),
        winner = { playerName = "Ahrymx", playerClass = "HUNTER", isSelf = true, state = 3, roll = 51 },
        allPassed = false, rollInfos = {} })
    fire("LOOT_HISTORY_UPDATE_DROP", 602, 2)
    chat("CHAT_MSG_LOOT", "You receive loot: " .. itemLink(30006, "Bloodboil's Cord", 1) .. ".")
    chat("CHAT_MSG_MONEY", "You loot 14 Gold, 20 Silver")
    lootState("loot after the boss")
    -- the item the client had not cached arrives
    loot.quality[30099] = 2
    fire("GET_ITEM_INFO_RECEIVED", 30099)
    -- the column: yours only, then the least quality up (and back), money off
    column(L)
    click(L, 1)
    column(L)
    lootState("loot mine")
    click(L, 1)
    click(L, 2)
    click(L, 2)
    column(L)
    lootState("loot epic and up")
    click(L, 2, "RightButton")
    click(L, 2, "RightButton")
    click(L, 2, "RightButton")
    column(L)
    -- down past poor wraps round to epic, and up past epic to poor
    click(L, 2, "RightButton")
    click(L, 2, "RightButton")
    print("lootQuality down past poor", ns.db.lootQuality)
    click(L, 2)
    print("lootQuality up past epic", ns.db.lootQuality)
    page.settings.lootQuality:Set(1)
    print("lootQuality", ns.db.lootQuality, "window shows", optionShows("lootQuality"),
        "lootWho window shows", optionShows("lootWho"))
    page.settings.lootMoney:Set(false)
    lootState("loot money off")
    page.settings.lootMoney:Set(true)
    -- the wheel: three lines down, then past the end
    thumb("loot")
    side.area.scripts.OnMouseWheel(side.area, -3)
    lootState("loot scrolled")
    sideTips("side tips with loot")
    -- a row passes the wheel on to the panel
    for _, f in ipairs(L.body.all_) do
        if f.kind == "Button" and f.item and f.shown then
            f.scripts.OnMouseWheel(f, -1)
            break
        end
    end
    print("loot scrolled from a row", L.Thumb())
    side.area.scripts.OnMouseWheel(side.area, 1)
    thumb("loot scrolled")
    side.area.scripts.OnMouseWheel(side.area, -50)
    print("loot scrolled to the end", L.Thumb())
    thumb("loot at the end")
    side.area.scripts.OnMouseWheel(side.area, 99)
    -- a chat line can be secret in combat: left to the chat
    fire("CHAT_MSG_LOOT", secret(), "")
    -- clear: the history's old rolls do not come back with its next update
    L.foot.click()
    side.Changed()
    lootState("loot cleared")
    fire("LOOT_HISTORY_UPDATE_DROP", 602, 2)
    lootState("loot after a stale update")
    -- money alone makes a heading, with its copper; the option takes it away
    chat("CHAT_MSG_MONEY", "You loot 42 Silver, 35 Copper")
    lootState("loot money only")
    page.settings.lootMoney:Set(false)
    lootState("loot money only, money off")
    page.settings.lootMoney:Set(true)

    -- --------------------------------------------------------- meter
    local M = views.meter
    if not M.body then
        print("meter none")
    else
        local function meterState(tag)
            print(tag)
            for _, list in ipairs({ M.body.all_[1], M.body.all_[2] }) do
                if list.shown then
                    local head
                    for _, c in ipairs(list.all_) do if c.kind == "Button" then head = c end end
                    local l, _, r = rect(list)
                    local title, when
                    for _, fs in ipairs(head.all_) do
                        if fs.kind == "FontString" then
                            if title then when = fs else title = fs end
                        end
                    end
                    print("", string.format("list %.0f-%.0f", l, r), title.text, when.text)
                    for _, row in ipairs(list.all_) do
                        if row.kind == "StatusBar" and row.shown then
                            local _, t = rect(row)
                            print("", string.format("bar@%.0f", t), tostring(row.label.text), tostring(row.amount.text),
                                string.format("%s/%s", tostring(row.value), tostring(row.max)),
                                string.format("(%.2f,%.2f,%.2f)", unpack(row.barColor)),
                                tostring(row.icon.atlas or row.icon.texture))
                        elseif row.kind == "FontString" and row.shown and row.text ~= "" then
                            print("", "empty", row.text)
                        end
                    end
                end
            end
        end
        local function tick(dt) M.body.scripts.OnUpdate(M.body, dt or 0.3) end
        side.views[2].tab.scripts.OnClick(side.views[2].tab)
        tabs()
        print("sideTab", ns.db.sideTab)
        column(M)
        meterState("meter")
        -- in combat: every amount and name secret
        local before = secretsUsed
        inCombat = true
        fire("PLAYER_REGEN_DISABLED")
        fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
        tick()
        meterState("meter in combat")
        print("secrets to the meter", secretsUsed - before)
        -- the column: overall, totals, two lists
        click(M, 1)
        click(M, 2)
        click(M, 3)
        column(M)
        meterState("meter overall, totals, two lists, in combat")
        inCombat = false
        fire("PLAYER_REGEN_ENABLED")
        tick()
        meterState("meter after combat")
        -- the headings step their lists; per second again
        local function heading(i, mouse)
            local list = M.body.all_[i]
            for _, c in ipairs(list.all_) do
                if c.kind == "Button" then c.scripts.OnClick(c, mouse or "LeftButton") end
            end
        end
        heading(2)
        heading(1, "RightButton")
        print("lists", ns.db.meterLeft, ns.db.meterRight)
        click(M, 2)
        click(M, 1)
        meterState("meter stepped, per second, current")
        heading(1)
        heading(2, "RightButton")
        click(M, 3)
        -- the wheel: ten sources, eight rows
        thumb("meter")
        side.area.scripts.OnMouseWheel(side.area, -1)
        meterState("meter scrolled one")
        thumb("meter scrolled one")
        side.area.scripts.OnMouseWheel(side.area, -10)
        print("meter scrolled to the end", M.Thumb())
        -- the clock ticks on its own; the bars only when told, and at most
        -- four times a second
        meter.asked = {}
        tick(1)
        print("asked on a quiet tick", #meter.asked)
        fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
        tick(0.01)
        print("asked when told", #meter.asked, table.concat(meter.asked, ","))
        fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
        tick(0.1)
        print("asked again within a quarter second", #meter.asked)
        tick(0.2)
        print("asked after it", #meter.asked)
        -- reset
        M.foot.click()
        fire("DAMAGE_METER_RESET")
        tick()
        print("resets", meter.resets, "first", M.Thumb())
        meterState("meter reset")
        meterData()
        -- unavailable
        meter.available, meter.reason = false, "Not available in this instance."
        tick()
        fire("DAMAGE_METER_RESET")
        tick()
        meterState("meter unavailable")
        meter.available = true
    end

    -- --------------------------------------------------------- auras
    local A = views.auras
    if not A or not A.body then
        print("auras none")
    else
        -- the lists sit in a frame of their own, the tracked bars' beside it
        local AL = A.body.all_[1]
        -- the player's auras: buffs and debuffs, as the client keeps them.
        -- In combat every time, name, stack and dispel type is secret; the
        -- instance ids are not (the player's own).
        local world = {
            HELPFUL = {
                { id = 31, name = "Swift Mount", icon = "mount" },
                { id = 17, name = "Bear Form", icon = "form", count = 3 },
                { id = 12, name = "Arcane Intellect", icon = "intellect", left = 3500, full = 3600 },
                { id = 40, name = "Flask of the Currents", icon = "flask", left = 4360, full = 7200 },
                { id = 41, name = "Bloodlust", icon = "lust", left = 28, full = 40, count = 1 },
                { id = 42, name = "Rejuvenation", icon = "rejuv", left = 11, full = 15 },
            },
            HARMFUL = {
                { id = 50, name = "Sated", icon = "sated", left = 492, full = 600 },
                { id = 51, name = "Fel Rage", icon = "felrage", left = 18, full = 30, count = 3, dispel = "Magic" },
                { id = 52, name = "Crippling Poison", icon = "poison", left = 6, full = 12, dispel = "Poison" },
            },
        }
        local born = now
        local function find(id)
            for _, kind in pairs(world) do
                for _, a in ipairs(kind) do if a.id == id then return a end end
            end
        end
        local function hide(v) if inCombat then return secret() end return v end
        local function data(a)
            return { auraInstanceID = a.id, name = hide(a.name), icon = a.icon, applications = hide(a.count or 0),
                dispelName = hide(a.dispel), duration = hide(a.full or 0),
                expirationTime = hide(a.left and born + a.left or 0) }
        end
        local asked, formatted = {}, 0
        -- the addon holds the client's table from load: change it in place
        local base, saved = C_UnitAuras, {}
        for k, v in pairs(C_UnitAuras) do saved[k] = v end
        for k, v in pairs({
            GetAuraDataByIndex = function(unit, i, filter)
                if unit ~= "player" or not world[filter or "HELPFUL"] then
                    return saved.GetAuraDataByIndex(unit, i, filter)
                end
                local a = world[filter or "HELPFUL"][i]
                return a and data(a)
            end,
            -- the client's sort: the longest first, and the ones that never
            -- run out after them all (where the client puts them is not
            -- known; the tab must not rest on it)
            GetUnitAuras = function(_, filter, _, rule, direction)
                table.insert(asked, filter .. ":" .. tostring(rule) .. "/" .. tostring(direction))
                local list = {}
                for _, a in ipairs(world[filter]) do table.insert(list, a) end
                table.sort(list, function(x, y)
                    if (x.left ~= nil) ~= (y.left ~= nil) then return x.left ~= nil end
                    if x.left then return x.left > y.left end
                    return x.id > y.id
                end)
                local out = {}
                for i, a in ipairs(list) do out[i] = data(a) end
                return out
            end,
            DoesAuraHaveExpirationTime = function(unit, id)
                if not find(id) then return saved.DoesAuraHaveExpirationTime(unit, id) end
                return hide(find(id).left ~= nil)
            end,
            GetAuraDuration = function(_, id)
                local a = find(id)
                return { aura = id, GetRemainingDuration = function()
                    return hide(a.left and math.max(0, born + a.left - now) or 0)
                end }
            end,
            GetAuraApplicationDisplayCount = function(_, id, least)
                local a = find(id)
                return hide((a.count or 0) >= least and tostring(a.count) or "")
            end,
        }) do base[k] = v end
        C_DurationUtil = { CreateDuration = function() return { aura = "zero" } end }
        C_StringUtil = { CreateSecondsFormatter = function()
            return { Format = function(_, v)
                formatted = formatted + 1
                if isSecret(v) then return "~time" end
                return v .. " sec"
            end }
        end }
        local function aurasState(tag)
            print(tag)
            for _, list in ipairs({ AL.all_[1], AL.all_[2] }) do
                if list.shown then
                    local l, _, r = rect(list)
                    local fs = {}
                    for _, c in ipairs(list.all_) do
                        if c.kind == "FontString" then table.insert(fs, c) end
                    end
                    print("", string.format("list %.0f-%.0f", l, r), fs[1].text, fs[2].text,
                        fs[3].shown and ("empty: " .. fs[3].text) or "")
                    for _, row in ipairs(list.all_) do
                        if row.kind == "StatusBar" and row.shown then
                            local _, t = rect(row)
                            local tc = row.left.textColor
                            print("", string.format("row@%.0f", t), tostring(row.label.text),
                                "x" .. tostring(row.count.text), tostring(row.icon.texture),
                                string.format("edge=%.2f,%.2f,%.2f", unpack(row.edge.color)),
                                string.format("bar=%.2f,%.2f,%.2f", unpack(row.barColor)),
                                row.timer and ("timer=" .. tostring(row.timer[1] and row.timer[1].aura) .. "/"
                                    .. tostring(row.timer[2])) or string.format("%s/%s", tostring(row.value),
                                    tostring(row.max)),
                                tostring(row.left.text), tc and string.format("(%.2f,%.2f,%.2f)", tc[1], tc[2], tc[3])
                                    or "")
                        end
                    end
                end
            end
            print("", "thumb", A.Thumb())
        end
        local function tick(dt) A.body.scripts.OnUpdate(A.body, dt or 0.3) end
        local unitAura = {}
        for _, f in ipairs(events.UNIT_AURA or {}) do table.insert(unitAura, f) end
        local function changed()
            for _, f in ipairs(unitAura) do f.scripts.OnEvent(f, "UNIT_AURA", "player", { isFullUpdate = true }) end
        end
        side.views[3].tab.scripts.OnClick(side.views[3].tab)
        tabs()
        print("sideTab", ns.db.sideTab)
        column(A)
        aurasState("auras")
        print("sorted by", table.concat(asked, " "))
        -- the times run down on their own, five times a second (a part
        -- second left counts as a second)
        now = now + 2.5
        tick(0.1)
        aurasState("auras a tenth later")
        tick(0.15)
        aurasState("auras three seconds on")
        -- the timeless ones listed, then one list of both
        click(A, 2)
        column(A)
        aurasState("auras timeless")
        click(A, 1)
        column(A)
        aurasState("auras one list")
        sideTips("side tips")
        -- the wheel: eleven auras, fewer rows; a row passes it on
        AL.all_[1].all_[5].scripts.OnMouseWheel(AL.all_[1].all_[5], -2)
        aurasState("auras scrolled two")
        thumb("auras")
        side.area.scripts.OnMouseWheel(side.area, -50)
        print("auras scrolled to the end", A.Thumb())
        -- the list shrinks under the scroll: back to what it can show
        click(A, 2)
        print("auras scrolled, timeless off", A.Thumb())
        click(A, 2)
        side.area.scripts.OnMouseWheel(side.area, 99)
        -- in combat: every time secret; the client's order
        local before = secretsUsed
        inCombat = true
        fire("PLAYER_REGEN_DISABLED")
        changed()
        tick()
        aurasState("auras one list in combat")
        click(A, 1)
        aurasState("auras two lists in combat")
        print("secrets to the auras", secretsUsed - before, "formatted", formatted)
        -- a buff gained in combat, whether it runs out not known: kept
        -- where the client puts it, and listed even with the timeless off
        table.insert(world.HELPFUL, { id = 43, name = "Mystery", icon = "mystery" })
        click(A, 2)
        changed()
        tick()
        aurasState("auras a new buff in combat, timeless off")
        -- the debuffs wear off: their rows are no longer asked for times
        local debuffs = world.HARMFUL
        world.HARMFUL = {}
        changed()
        tick()
        local asks = formatted
        tick(0.25)
        print("times asked on a tick in combat", formatted - asks)
        world.HARMFUL = debuffs
        changed()
        tick()
        -- a right click in combat cancels nothing
        local row = AL.all_[1].all_[5]
        local rowsOf = {}
        for _, c in ipairs(AL.all_[1].all_) do if c.kind == "StatusBar" then table.insert(rowsOf, c) end end
        row = rowsOf[1]
        row.scripts.OnMouseUp(row, "RightButton")
        print("cancelled in combat", #cancelled)
        inCombat = false
        fire("PLAYER_REGEN_ENABLED")
        tick()
        aurasState("auras after combat")
        -- out of combat: a right click cancels a buff, not a debuff, and a
        -- left click nothing
        row.scripts.OnMouseUp(row, "LeftButton")
        row.scripts.OnMouseUp(row, "RightButton")
        local debuffRow
        for _, c in ipairs(AL.all_[2].all_) do if c.kind == "StatusBar" and not debuffRow then debuffRow = c end end
        debuffRow.scripts.OnMouseUp(debuffRow, "RightButton")
        print("cancelled", table.concat(cancelled, ","))
        -- the auras are read only when they change, at most four times a second
        asked = {}
        tick(1)
        print("read on a quiet tick", #asked)
        changed()
        tick(0.01)
        print("read when told", #asked)
        changed()
        tick(0.1)
        print("read again within a quarter second", #asked)
        tick(0.2)
        print("read after it", #asked)
        -- a client whose status bars have no timer: the range is the full
        -- duration and the time left is set on each tick
        noTimer = true
        for _, list in ipairs({ AL.all_[1], AL.all_[2] }) do
            for _, r in ipairs(list.all_) do r.timer = nil end
        end
        changed()
        tick()
        aurasState("auras without a client timer")
        now = now + 1
        tick(0.25)
        aurasState("auras without a client timer, a second on")
        -- past an aura's end, before the client takes it away: nothing left, not less
        now = now + 5
        tick(0.25)
        aurasState("auras past the poison's end")
        noTimer = false
        -- nothing at all
        world.HELPFUL, world.HARMFUL = {}, {}
        changed()
        tick()
        aurasState("auras none")
        page.settings.aurasColumns:Set(1)
        aurasState("auras none, one list")
        print("aurasColumns window shows", optionShows("aurasColumns"),
            "aurasTimeless window shows", optionShows("aurasTimeless"))
        -- the Cooldown Manager's tracked buff bars take over in combat when
        -- Blizzard_CooldownViewer is present and aurasTrackedBars is on
        local host = _G.MedalluinAurasTrackedBars
        local cdm = CreateFrame("Frame", "BuffBarCooldownViewer", UIParent)
        -- the Cooldown Manager's own option, off as on a new character
        local cvars, writes = { cooldownViewerEnabled = "0" }, 0
        local savedCVar = C_CVar
        C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            SetCVar = function(name, value)
                cvars[name], writes = tostring(value), writes + 1
                return true
            end,
        }
        fire("ADDON_LOADED", "Blizzard_CooldownViewer")
        -- and leave it be once it is on
        fire("ADDON_LOADED", "Blizzard_CooldownViewer")
        print("tracked bars turn the Cooldown Manager on", cvars.cooldownViewerEnabled, "writes", writes)
        print("tracked bars adopted", cdm.parent == host,
            "holder out of combat", AL.shown, "host out of combat", host.shown)
        cdm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("tracked bars re-anchored after Edit Mode", cdm.points.TOPLEFT[1] == host)
        harnessHolds.combat = true
        stateTick()
        print("tracked bars in combat", "holder", AL.shown, "host", host.shown,
            "thumb", select(3, A.Thumb()))
        harnessHolds.combat = nil
        stateTick()
        -- unticked: the Cooldown Manager is left as the player has it
        cvars.cooldownViewerEnabled = "0"
        page.settings.aurasTrackedBars:Set(false)
        print("tracked bars off", cdm.parent == UIParent,
            "holder", AL.shown, "host", host.shown, "Cooldown Manager left", cvars.cooldownViewerEnabled)
        -- ticked again: on again, and a client with no such setting is left alone
        cvars.cooldownViewerEnabled = "0"
        page.settings.aurasTrackedBars:Set(true)
        local again = cvars.cooldownViewerEnabled
        cvars.cooldownViewerEnabled = nil
        page.settings.aurasTrackedBars:Set(false)
        page.settings.aurasTrackedBars:Set(true)
        print("tracked bars ticked again", again, "no setting", tostring(cvars.cooldownViewerEnabled),
            "writes", writes)
        page.settings.aurasTrackedBars:Set(false)
        C_CVar = savedCVar
        _G.BuffBarCooldownViewer = nil
        for k in pairs(base) do base[k] = saved[k] end
    end

    -- the tabs come and go with their options; none, no panel
    page.settings.sideMeter:Set(false)
    tabs()
    page.settings.sideLoot:Set(false)
    tabs()
    page.settings.sideAuras:Set(false)
    tabs()
    page.settings.sideMeter:Set(true)
    tabs()
    page.settings.sideLoot:Set(true)
    page.settings.sideAuras:Set(true)
    tabs()
    SlashCmdList.MDLUI("meter")
    print("/mdlui meter opens", tostring(page.opened))
    return
end

if stripsPass then
    -- the screen in console units: the console's top-left is (612, 916)
    UIParent.fixed = { -612, -916, 1308, 164 }
    local function screen(tag, f, extra)
        local r = resolve(f)
        print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1] + 612, r[2] + 916, r[3] + 612,
            r[4] + 916, extra or ""))
    end
    screen("stripLeft", ns.strips[-1])
    screen("stripRight", ns.strips[1])
    -- Blizzard's buff and debuff rows: out of sight by default, back on
    -- UIParent with the option, and a change in combat waits for its end
    local function rows(tag)
        local function where(f) return f.parent == UIParent and "UIParent" or f.parent == ns.hidden and "hidden"
            or tostring(f.parent) end
        print("blizzard auras " .. tag, "option=" .. tostring(ns.db.blizzardAuras),
            "buffs=" .. where(BuffFrame), "debuffs=" .. where(DebuffFrame))
    end
    rows("at login")
    page.settings.blizzardAuras:Set(true)
    rows("on")
    inCombat = true
    page.settings.blizzardAuras:Set(false)
    rows("off in combat")
    inCombat = false
    for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    rows("after combat")
    if modern then
        -- Blizzard's own passes, after login: they must not undo the strips
        BagsBar.layoutAtLoad(BagsBar)
        for _, b in ipairs({ MainMenuBarBackpackButton, CharacterReagentBag0Slot, CharacterBag0Slot }) do
            b:UpdateTextures()
            b:SetBarExpanded(false)
        end
        CharacterBag0Slot.SlotHighlightTexture:SetShown(true)     -- its bag is open
        for _, f in ipairs(all) do
            if f.layoutIndex then f:SetHighlightAtlas("UI-HUD-MicroMenu-Down"); f:SetPushedAtlas("x") end
        end
        -- and straight on the textures: LoadMicroButtonTextures' colour (no
        -- alpha), then SetPushed's highlight at .5 and the normal back to 1
        -- as the mouse leaves
        for _, f in ipairs(all) do
            if f.layoutIndex then
                for _, t in ipairs({ f:GetNormalTexture(), f:GetPushedTexture(), f:GetDisabledTexture(),
                    f:GetHighlightTexture() }) do t:SetVertexColor(1, 0.82, 0) end
                f:GetHighlightTexture():SetAlpha(0.5)
                f:GetNormalTexture():SetAlpha(1)
            end
        end
    end
    -- how much of a button's Blizzard state art shows, the most of any
    -- state: its alpha and its colour's alpha apart, since either one
    -- given back by Blizzard would be a bug
    local function lit(f)
        local alpha, vertex = 0, 0
        for _, t in ipairs({ f:GetNormalTexture() or false, f:GetPushedTexture() or false,
            f:GetDisabledTexture() or false, f:GetHighlightTexture() or false }) do
            if t then
                alpha = math.max(alpha, t.alpha or 1)
                vertex = math.max(vertex, t.vertex and t.vertex[4] or 1)
            end
        end
        return string.format("a%gv%g", alpha, vertex)
    end
    -- the textures a button draws whatever its state: shown, seen, and not
    -- one of its state slots (those draw only in their state)
    local function drawn(f)
        local states = {}
        for _, t in ipairs({ f:GetNormalTexture() or false, f:GetPushedTexture() or false,
            f:GetDisabledTexture() or false, f:GetHighlightTexture() or false,
            f.GetCheckedTexture and f:GetCheckedTexture() or false }) do
            if t then states[t] = true end
        end
        local n = 0
        for _, t in ipairs(f.all_ or {}) do
            if t.kind == "Texture" and t.shown and not states[t] and t.layer ~= "HIGHLIGHT"
                and (t.alpha or 1) > 0 and not (t.vertex and t.vertex[4] == 0)
                and (t.texture or t.atlas or t.color and t.color[4] ~= 0) then
                n = n + 1
            end
        end
        return n
    end
    local micro = {}
    for _, f in ipairs(all) do
        if type(f.name) == "string" and f.name:match("MicroButton$") and _G[f.name] == f then table.insert(micro, f) end
    end
    table.sort(micro, function(a, b) return (resolve(a)[1] or 1e9) < (resolve(b)[1] or 1e9) end)
    for _, f in ipairs(micro) do
        if f.shown and resolve(f)[1] then
            local m, hl = f.medalluin, f:GetHighlightTexture()
            screen(f.name, f, string.format("parent=%s glyph=%s hl.alpha=%s lit=%s", tostring(f.parent.name),
                m and m.tex.texture and m.tex.texture:match("[^\\]+$") or "-",
                hl and hl.vertex and tostring(hl.vertex[4]) or "-", tostring(lit(f))))
        else
            print(f.name, "hidden")
        end
    end
    local blizzPortrait = MicroButtonPortrait or CharacterMicroButton.Portrait
    screen("portrait", CharacterMicroButton, "blizzard=" .. tostring(blizzPortrait.alpha))
    -- queue eye: in group finder, the eye appears over the character medallion, hiding the portrait
    QueueStatusButton:Show()
    print("queue eye queued", "shown=" .. tostring(QueueStatusButton.shown),
        "portrait=" .. tostring(CharacterMicroButton.medalluin.tex.shown),
        "level=" .. tostring(QueueStatusButton.level),
        "over=" .. tostring(QueueStatusButton.level > CharacterMicroButton.level))
    screen("queueEye", QueueStatusButton)
    QueueStatusButton:Hide()
    print("queue eye unqueued", "shown=" .. tostring(QueueStatusButton.shown),
        "portrait=" .. tostring(CharacterMicroButton.medalluin.tex.shown))
    -- the leave-vehicle seat: Blizzard's button over the backpack's well
    -- while a vehicle can be left, wearing our round art through Blizzard's
    -- own passes (Edit Mode placing it, Update's square highlight)
    local seat = MainMenuBarVehicleLeaveButton
    if seat then
        local function art(t)
            if not t then return "-" end
            return string.format("%s@%s%s%s", tostring(t.texture):match("[^\\]+$"),
                t.coords and table.concat(t.coords, ",") or "full",
                t.vertex and ("/" .. tostring(t.vertex[1])) or "", t.desaturated and "/grey" or "")
                .. (t.alpha and t.alpha < 1 and ("/a" .. t.alpha) or "")
        end
        local function seatState(tag)
            print("vehicle " .. tag, "shown=" .. tostring(seat.shown), "parent=" .. tostring(seat.parent.name),
                "packAlpha=" .. tostring(MainMenuBarBackpackButton.alpha),
                "over=" .. tostring(seat.level > MainMenuBarBackpackButton.level),
                "under art=" .. tostring(seat.level < ns.levels.stripArt))
        end
        seatState("parked")
        seat:Show()
        seatState("can leave")
        screen("vehicleSeat", seat, string.format("normal=%s pushed=%s disabled=%s highlight=%s",
            art(seat:GetNormalTexture()), art(seat:GetPushedTexture()), art(seat:GetDisabledTexture()),
            art(seat:GetHighlightTexture())))
        -- Edit Mode puts it back where its layout says; Update and the
        -- taxi click set Blizzard's square highlight
        seat:SetScale(1.4)
        print("vehicle rescaled", "scale=" .. tostring(seat.scale))
        seat:SetParent(MainActionBar)
        print("vehicle reparented", "parent=" .. tostring(seat.parent.name))
        seat:ClearAllPoints()
        seat:SetPoint("BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", 0, 0)
        -- in WoW a path lands on the texture already there (our glow), so
        -- the square is put on it first
        seat:GetHighlightTexture():SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        seat:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        seat:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
        screen("vehicleSeat placed again", seat, string.format("scale=%s normal=%s highlight=%s",
            tostring(seat.scale), art(seat:GetNormalTexture()), art(seat:GetHighlightTexture())))
        seat:Hide()
        seatState("left")
    else
        print("vehicle", "no leave button")
    end
    local pack = MainMenuBarBackpackButton
    local mark = pack.SlotHighlightTexture
    screen("backpack", pack, string.format("picture=%s drawn=%d open=%s", tostring(pack.icon.texture):match("[^\\]+$"),
        drawn(pack), mark and (mark.atlas or tostring(mark.texture):match("[^\\]+$") .. "@" .. tostring(mark.vertex and mark.vertex[1])) or "-"))
    -- no bag drawer (removed 2026-11-01): the slots stay with Blizzard's BagsBar
    local left = {}
    for _, n in ipairs({ "CharacterBag3Slot", "CharacterBag2Slot", "CharacterBag1Slot", "CharacterBag0Slot",
        "CharacterReagentBag0Slot", "KeyRingButton" }) do
        local b = _G[n]
        if b then table.insert(left, n:gsub("Character", ""):gsub("Slot", "") .. "@" .. tostring(b.parent and b.parent.name)) end
    end
    print("bags", "drawer=" .. tostring(_G.MedalluinBagDrawer ~= nil), table.concat(left, " "))
    for _, f in ipairs(all) do
        if f.kind == "FontString" and f.parent and f.parent.parent == ns.strips[1] and f.text then
            screen("stat", f.parent, string.format("%q", f.text))
        end
    end
    -- their tooltips, handed to the companion as specs; and the lines they
    -- still write into the game's tooltip
    local lines
    local set, add, double = GameTooltip.SetText, GameTooltip.AddLine, GameTooltip.AddDoubleLine
    GameTooltip.SetText = function(_, t) lines = { t } end
    GameTooltip.AddLine = function(_, t) table.insert(lines, t) end
    GameTooltip.AddDoubleLine = function(_, l, r) table.insert(lines, l .. " = " .. r) end
    XP = XP or "Experience"
    GameTime_GetLocalTime = GameTime_GetLocalTime or function() return "9:15 PM" end
    GameTime_GetGameTime = GameTime_GetGameTime or function() return "8:15 PM" end
    GetInventoryItemLink = GetInventoryItemLink or function(_, slot) return "[Item " .. slot .. "]" end
    GetInventoryItemTexture = GetInventoryItemTexture or function(_, slot) return "slot" .. slot end
    for _, f in ipairs(all) do
        if f.kind == "FontString" and f.parent and f.parent.parent == ns.strips[1] and f.text
            and f.parent.scripts.OnEnter then
            f.parent.scripts.OnEnter(f.parent)
            print("stat tip", table.concat(lines, " | "), tipSpec())
        end
    end
    -- a SetOwner from anyone else ends it; so does an owner changed under it
    GameTooltip:ClearLines()
    print("stat tip cleared", tipSpec())
    ns.xpBar.hit.scripts.OnEnter(ns.xpBar.hit)
    print("xp tip", table.concat(lines, " | "), tipSpec())
    GameTooltip.owner = UIParent
    print("xp tip other owner", tipSpec())
    ns.repBar.hit.scripts.OnEnter(ns.repBar.hit)
    print("rep tip", table.concat(lines, " | "), tipSpec())
    GameTooltip.SetText, GameTooltip.AddLine, GameTooltip.AddDoubleLine = set, add, double

    -- the chat panel: the art, where the messages and the edit box go, and
    -- Blizzard's art hidden on a docked window and kept hidden
    local chat = ns.chat
    local function art(f)
        local shown = 0
        for _, part in ipairs(CHAT_FRAME_TEXTURES) do
            if _G[f.name .. part].shown then shown = shown + 1 end
        end
        local box = f.editBox
        for _, t in ipairs({ _G[box.name .. "Left"], _G[box.name .. "Mid"], box.focusLeft }) do
            if t.shown then shown = shown + 1 end
        end
        return shown .. "/" .. (#CHAT_FRAME_TEXTURES + 3) .. " shown, grip=" .. tostring(f.ResizeButton.shown)
    end
    local function tab(f)
        local t, lit = _G[f.name .. "Tab"], {}
        for _, k in ipairs(TAB_ART) do
            if t[k].shown then table.insert(lit, k) end
        end
        local c = t.Text.textColor
        local slot = ""
        if t.medalluinSlot and f.isDocked and next(t.points) then
            local sr, hr = resolve(t.medalluinSlot), resolve(ns.chat.head)
            slot = string.format(" slot=%.1f..%.1f, %.1f high, %.1f over the hairline, text=%s",
                sr[1] + 612, sr[3] + 612, sr[4] - sr[2], hr[4] - sr[4],
                tostring(t.Text.points.CENTER and t.Text.points.CENTER[1] == t.medalluinSlot))
        end
        local faced = "-"
        for _, g in ipairs({ t:GetRegions() }) do
            if g.all == t.medalluinSlot and t.medalluinSlot then faced = "slot" end
        end
        local w = t.medalluinWell and t.medalluinWell.color
        return "regions=" .. select("#", t:GetRegions()) .. " face=" .. faced .. slot
            .. (w and string.format(" well=%.2f,%.2f,%.2f", w[1], w[2], w[3]) or "")
            .. string.format(" alpha=%g", t:GetAlpha()) .. " blizzard=" .. (#lit > 0 and table.concat(lit, ",") or "none") .. " selected="
            .. tostring(t.medalluin and t.mark.shown)
            .. (c and string.format(" text=%.2f,%.2f,%.2f", c[1], c[2], c[3]) or "")
    end
    local function chatState(tag)
        local r = ChatFrame1:GetEffectiveScale() / chat.panel:GetEffectiveScale()
        print(tag, string.format("scale %.3f", r))
        screen("chatArea", chat.area)
        screen("ChatFrame1", ChatFrame1, art(ChatFrame1) .. " " .. tab(ChatFrame1))
        screen("ChatFrame2", ChatFrame2, art(ChatFrame2) .. " " .. tab(ChatFrame2))
        screen("ChatFrame3", ChatFrame3, art(ChatFrame3) .. " " .. tab(ChatFrame3))
        screen("editBox", ChatFrame1.editBox)
        -- the head: Blizzard's buttons at the tab row's right end, each
        -- with its glyph and its own art's alpha, the column's art gone
        local hairline = "-"
        for _, g in ipairs({ chat.head:GetRegions() }) do
            if g.h == 1 then hairline = "1px" end
        end
        screen("head", chat.head, "column art=" .. tostring(ChatFrame1ButtonFrameBackground.shown) .. " hairline=" .. hairline)
        screen("  cog", chat.cog, string.format("glyph=%s lit=%s strata=%s level=%s over the chat=%s regions=%d",
            chat.cog.glyph and chat.cog.glyph.texture:match("[^\\]+$") or "-",
            tostring(chat.cog.highlightLocked), tostring(chat.cog.strata), tostring(chat.cog.level),
            tostring(chat.cog.level > ChatFrame1:GetFrameLevel()), select("#", chat.cog:GetRegions())))
        screen("  drawer", chat.drawer, string.format("shown=%s strata=%s level=%s regions=%d", tostring(chat.drawer.shown),
            tostring(chat.drawer.strata), tostring(chat.drawer.level), select("#", chat.drawer:GetRegions())))
        for _, n in ipairs({ "ChatFrameMenuButton", "QuickJoinToastButton", "ChatFrameChannelButton",
            "MedalluinChatLogButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
            local b = _G[n]
            local g, own = b.medalluinGlyph, {}
            for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b.Icon, b.FriendsButton }) do
                table.insert(own, string.format("%g", t:GetAlpha()))
            end
            if b.shown then
                screen("  " .. n, b, string.format("glyph=%s %s art=%s drawer=%s",
                    g and g.texture:match("[^\\]+$") or "-", g and string.format("%.1fx%.1f", g.w, g.h) or "",
                    table.concat(own, ","), tostring(b.parent == chat.drawer)))
            else
                print("  " .. n, "hidden")
            end
        end
        screen("  alerts", ChatAlertFrame, "moves=" .. ChatAlertFrame.moves)
        local d, first = resolve(GENERAL_CHAT_DOCK), resolve(chat.cog)
        local ys = {}
        for i = 1, GENERAL_CHAT_DOCK:GetNumPoints() do
            local point, _, _, _, y = GENERAL_CHAT_DOCK:GetPoint(i)
            ys[point] = y
        end
        screen("  dock", GENERAL_CHAT_DOCK, string.format("clear of the cog=%.1f fitted=%d clamp=%s y=%s/%s",
            first[1] - d[3], tabsFitted, table.concat({ ChatFrame1:GetClampRectInsets() }, ","),
            tostring(ys.BOTTOMLEFT), tostring(ys.BOTTOMRIGHT)))
        local dv = resolve(chat.divider)
        print("  divider", string.format("%.1f high, %.1f clear of the dock, %.1f before the cog, foot %.1f over the hairline",
            dv[4] - dv[2], dv[1] - d[3], first[1] - dv[3], resolve(chat.head)[4] - dv[4]))
        print("  friend count", string.format("alpha=%g", QuickJoinToastButton.FriendCount:GetAlpha()))
    end
    if not chat then
        print("chat none")
        screen("ChatFrame1", ChatFrame1, art(ChatFrame1) .. " " .. tab(ChatFrame1))
    else
        local b = chat.box
        screen("chatBox", b, string.format("strata=%s dress=%s rule=%s", tostring(b.strata),
            tostring(chat.dress:IsShown()), resolve(b)[4] - resolve(chat.dress.rule)[4]))
        screen("chatPanel", chat.panel)
        chatState("chat")
        -- the cog opens the drawer
        chat.cog.scripts.OnClick(chat.cog)
        chatState("chat drawer")
        -- Blizzard's passes: its saved layout puts the frame back, a fade
        -- shows the background, the edit box takes focus, the tab changes
        ChatFrame1:ClearAllPoints()
        ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
        ChatFrame1Background:Show()
        ChatFrame1.ResizeButton:Show()
        ChatFrame1.editBox.focusLeft:SetShown(true)
        ChatAlertFrame:ClearAllPoints()
        alertAnchor()
        QuickJoinToastButton:ClearAllPoints()
        toastAnchor()
        ChatFrame1:SetClampRectInsets(-35, 35, 38, -50)
        dockAnchor()
        ChatFrameMenuButton:ClearAllPoints()
        ChatFrameMenuButton:SetPoint("BOTTOM", ChatFrame1.buttonFrame, "BOTTOM")
        ChatFrameChannelButton:SetNormalAtlas("voicechat-channellist-icon-headphone-on")
        ChatFrame1ButtonFrameBackground:Show()
        selectedChat = ChatFrame2
        FCFTab_UpdateColors(ChatFrame1Tab, false)
        FCFTab_UpdateColors(ChatFrame2Tab, true)
        chatState("chat after blizzard")
        -- the combat log torn off, the third window docked
        FCF_UnDockFrame(ChatFrame2)
        FCF_DockFrame(ChatFrame3)
        chatState("chat redocked")
        -- voice on: its two toggles join the head, keeping their own art
        ChatFrameToggleVoiceDeafenButton:Show()
        ChatFrameToggleVoiceMuteButton:Show()
        chatState("chat voice")
        ChatFrameToggleVoiceDeafenButton:Hide()
        ChatFrameToggleVoiceMuteButton:Hide()
        chatState("chat voice off")
        screen("ChatFrame2EditBox", ChatFrame2.editBox)
        -- the box's backing: only while it is typed in
        local function lit(box) return tostring(box.medalluin and box.medalluin[1].shown) end
        local b1 = ChatFrame1.editBox
        local rest = lit(b1)
        b1:SetFocus()
        local typing = lit(b1)
        b1:ClearFocus()
        print("editBox backing", "rest=" .. rest, "typing=" .. typing, "after=" .. lit(b1))
        local temp = FCF_OpenTemporaryWindow()
        print("whisper", art(temp), tab(temp))
        -- the arrow keys move the cursor in every box, Alt or not
        print("chat arrows", "alt only: ChatFrame1=" .. tostring(ChatFrame1.editBox.altArrows),
            "ChatFrame2 (undocked)=" .. tostring(ChatFrame2.editBox.altArrows),
            "whisper=" .. tostring(temp.editBox.altArrows))
        -- a channel's tag is its number alone; a notice keeps its name, a
        -- secret line and anything else pass as they came
        local lines = {
            "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h |Hplayer:Bob|h[Bob]|h: hi",
            "12:01 |Hchannel:channel:2|h[2. Trade - City]|h |Hplayer:Ann|h[Ann]|h: WTS [1. ore]",
            "|Hchannel:channel:14|h[14. MyChannel]|h |Hplayer:Kim|h[Kim]|h: yo",
            "Joined Channel: |Hchannel:CHANNEL:1|h[1. General - Elwynn Forest]|h",
            "|Hplayer:Bob|h[Bob]|h whispers: [1. not a tag]",
        }
        for _, frame in ipairs({ ChatFrame1, temp }) do
            frame.said = {}
            for _, line in ipairs(lines) do frame:AddMessage(line, 1, 1, 1) end
            -- the game's secret is a string to type(): never matched
            local plain = type
            type = function(v) if isSecret(v) then return "string" end return plain(v) end
            frame:AddMessage(secret())
            type = plain
            frame:AddMessage(nil)
            for i, line in ipairs(frame.said) do
                print("chat tag " .. frame:GetName() .. " " .. i,
                    isSecret(line.text) and "<secret>" or tostring(line.text), "args=" .. line.n .. " r=" .. tostring(line.r))
            end
        end
        -- a speaker's name: their class's colour, their level before it
        local function hear(e, ...) for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end end
        chatSenders[101], guidInfo["G-Bob"] = "G-Bob", { "WARRIOR", 42 }
        chatSenders[102] = secret()
        chatSenders[103], guidInfo["G-Kim"] = "G-Kim", { "MAGE", nil }
        chatSenders[104], guidInfo["G-Lu"] = "G-Lu", { secret(), secret() }
        harnessGuild = { { "Ann-Medalluin", 17 }, { "Lu-Medalluin", 0 }, { "Bob-Medalluin", 40 } }
        hear("GUILD_ROSTER_UPDATE")
        harnessWho = { { fullName = "Kim-Other", level = 33 }, { fullName = secret(), level = 9 },
            { fullName = "Pip", level = secret() } }
        hear("WHO_LIST_UPDATE")
        -- a nameplate whose name is secret: not kept
        local fullName = UnitFullName
        UnitFullName = function() return secret(), nil end
        hear("NAME_PLATE_UNIT_ADDED", "player")
        UnitFullName = function() return "Pip", secret() end
        hear("NAME_PLATE_UNIT_ADDED", "player")
        UnitFullName = fullName
        local kept, secrets = {}, 0
        for k, v in pairs(ns.chatLevels) do
            if isSecret(k) then secrets = secrets + 1 else table.insert(kept, k .. "=" .. v) end
        end
        table.sort(kept)
        print("chat names seen", table.concat(kept, " "), "secret keys=" .. secrets)
        harnessFriends = { { name = "Zed", level = 5 } }
        hear("FRIENDLIST_UPDATE")
        local names = {
            "|Hplayer:Bob-Medalluin:101:CHANNEL:1|h[|cffaabbccBob|r]|h: hi",
            "|Hplayer:Eve-Medalluin:102:SAY|h[Eve]|h says: secret sender",
            "|Hplayer:Ann|h[Ann]|h has come online.",
            "|Hplayer:Kim-Other:103:YELL|h[Kim-Other]|h yells: from afar",
            "|Hplayer:Lu-Medalluin:104:GUILD|h[Lu]|h: secret class",
            "|Hplayer:Zed:105:WHISPER|h[Zed]|h whispers: no sender",
            "|Hplayer:Ahrymx-Medalluin:106:SAY|h[Ahrymx]|h says: me",
            "|HBNplayer:Kay:1:107|h[Kay]|h: battle.net",
        }
        local function names_(tag)
            ChatFrame1.said = {}
            for _, line in ipairs(names) do ChatFrame1:AddMessage(line, 1, 1, 1) end
            for i, line in ipairs(ChatFrame1.said) do print("chat name " .. tag .. " " .. i, tostring(line.text)) end
        end
        names_("on")
        hear("PLAYER_LEVEL_UP", 31)
        ns.SetOption("chatLevels", false)
        names_("no levels")
        ns.SetOption("chatLevels", true)
        ns.SetOption("chatClassColors", false)
        names_("no colours")
        ns.SetOption("chatClassColors", true)
        -- docked again: wrapped once, not once more
        local wrapped = ChatFrame2.AddMessage
        FCF_DockFrame(ChatFrame2)
        print("chat tag redocked", "same=" .. tostring(ChatFrame2.AddMessage == wrapped))
        FCF_UnDockFrame(ChatFrame2)
        print("undocked clamp", table.concat({ ChatFrame2:GetClampRectInsets() }, ","),
            "docked", table.concat({ temp:GetClampRectInsets() }, ","))
        -- the console at a 1080-high UI: Blizzard's pieces need less room
        ns.console:SetScale(1)
        chatState("chat rescaled")
        chat.cog.scripts.OnClick(chat.cog)
        chatState("chat drawer shut")
        chat.cog.scripts.OnEnter(chat.cog)
        print("chat cog tip", tipSpec())

        -- the log: the drawer's button opens a detached box of the chosen
        -- window's lines, as plain text in a read-only edit box
        local logButton = chat.log
        logButton.scripts.OnEnter(logButton)
        print("chat log button", "tip=" .. tipSpec(), "in the drawer=" .. tostring(logButton.parent == chat.drawer))
        local log = ns.chatLog
        local lw, lbox = log.window, log.box
        local scroll = lbox:GetParent():GetParent()
        local function logState(tag)
            local lines = {}
            for l in ((lbox.text or "") .. "\n"):gmatch("(.-)\n") do table.insert(lines, l) end
            local band = {}
            for _, r in ipairs({ log.W.Current().band:GetRegions() }) do
                if r.text then table.insert(band, r.text) end
            end
            print("chat log " .. tag, "shown=" .. tostring(lw:IsShown()), "lines=" .. #lines,
                "last=" .. tostring(lines[#lines]), "band=" .. table.concat(band, " | "),
                string.format("scroll=%.0f/%.0f", scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()),
                string.format("text width=%.0f of %.0f", resolve(lbox)[3] - resolve(lbox)[1], lw.w),
                string.format("box height=%.0f", lbox.h))
        end
        logButton.scripts.OnClick(logButton, "LeftButton")
        lw.scripts.OnUpdate(lw, 0.01)
        local at, rel, rp, x, y = lw:GetPoint()
        print("chat log place", string.format("%s %s %+.0f,%+.0f", at, rp, x, y), "view glyph=" .. tostring(lw.view),
            "grip=" .. tostring(lw.grip and lw.grip.shown), "medallion=" .. tostring(lw.medal.shown),
            "tab=" .. tostring(log.W.Current().tab and log.W.Current().tab.w))
        logState("opened")
        local text = lbox.text or ""
        local i = 0
        for l in (text .. "\n"):gmatch("(.-)\n") do
            i = i + 1
            print("chat log line " .. i, l)
        end
        -- plain text: a link's words, no icon, no colour
        ChatFrame1:AddMessage("|cffff8000|Hitem:19019|h[Thunderfury]|h|r |TInterface\\Icons\\x:0|t sold |Kq7|k")
        lw.scripts.OnUpdate(lw, 0.01)
        logState("a link, an icon, a colour")
        -- a key changes nothing
        lbox.text = "typed over"
        lbox.scripts.OnTextChanged(lbox, true)
        logState("typed in")
        -- selected (it has focus): new lines wait, and the band says so
        lbox:SetFocus()
        ChatFrame1:AddMessage("one while selecting")
        ChatFrame1:AddMessage("two while selecting")
        lw.scripts.OnUpdate(lw, 0.01)
        logState("selecting, two new")
        lbox:ClearFocus()
        lw.scripts.OnUpdate(lw, 0.01)
        logState("left")
        -- another window's lines are not this one's; choosing it shows them
        ChatFrame2:AddMessage("in the combat log")
        lw.scripts.OnUpdate(lw, 0.01)
        logState("another window's line")
        local wasSelected = SELECTED_CHAT_FRAME
        SELECTED_CHAT_FRAME = ChatFrame2
        lw.scripts.OnUpdate(lw, 0.01)
        logState("ChatFrame2 chosen")
        SELECTED_CHAT_FRAME = wasSelected
        lw.scripts.OnUpdate(lw, 0.01)
        -- the last thousand kept
        for n = 1, 1300 do ChatFrame1:AddMessage("line " .. n) end
        lw.scripts.OnUpdate(lw, 0.01)
        logState("1300 more")
        print("chat log kept", #log.logs[ChatFrame1], "first=" .. tostring(log.logs[ChatFrame1][1]))
        -- the list follows the cursor past its edges
        lbox.scripts.OnCursorChanged(lbox, 0, -10, 0, 14)
        print("chat log cursor at the top", string.format("scroll=%.0f", scroll:GetVerticalScroll()))
        lbox.scripts.OnCursorChanged(lbox, 0, -2000, 0, 14)
        print("chat log cursor 2000 down", string.format("scroll=%.0f", scroll:GetVerticalScroll()))
        -- scrolled up, a new line leaves the list where the reader put it
        lw.scripts.OnUpdate(lw, 0.01)
        ChatFrame1:AddMessage("while scrolled up")
        lw.scripts.OnUpdate(lw, 0.01)
        logState("a line while scrolled up")
        -- a line longer than the box is wide wraps, and the list is taller
        ChatFrame1:AddMessage(string.rep("a long line ", 60))
        lw.scripts.OnUpdate(lw, 0.01)
        logState("a line that wraps")
        -- sized by its grip: the text follows the window's width, the long
        -- line in fewer rows
        ns.SetOption("chatLogPlace", { point = "TOPLEFT", relative = "TOPLEFT", x = 40, y = -80, w = 600, h = 400 })
        logState("sized 600 wide")
        lw.close.scripts.OnClick(lw.close, "LeftButton")
        logState("closed")
        logButton.scripts.OnClick(logButton, "LeftButton")
        logState("again")
        logButton.scripts.OnClick(logButton, "LeftButton")
    end

    -- the timeless buffs above the medallion; a right click cancels one
    if not ns.buffs then
        print("buffs none")
    else
        local function buffState(tag)
            local list = {}
            for _, b in ipairs(ns.buffs) do
                if b.shown then
                    local r = resolve(b)
                    table.insert(list, string.format("%s(%s)@%.0f-%.0f,%.0f-%.0f", tostring(b.icon.texture),
                        tostring(b.count.text), r[1] + 612, r[3] + 612, r[2] + 916, r[4] + 916))
                end
            end
            print(tag, #list > 0 and table.concat(list, " ") or "none")
            -- the chat's edit box shares the row's margin: at rest it
            -- takes the pointer only right of the row
            local box = ChatFrame1 and ChatFrame1.editBox
            if box then
                local i, r = box.hitInsets or {}, resolve(box)
                print("  edit box", string.format("left inset=%.1f at=%.0f..%.0f", i[1] or 0, r[1] + 612, r[3] + 612))
            end
        end
        buffState("buffs")
        local box = ChatFrame1 and ChatFrame1.editBox
        if box then
            box:SetFocus()
            buffState("buffs, chat typed in")
            box:ClearFocus()
        end
        local function aura(info)
            for _, f in ipairs(events.UNIT_AURA) do f.scripts.OnEvent(f, "UNIT_AURA", "player", info) end
        end
        -- in combat: a new buff cannot be sorted, one runs out, a stack drops
        inCombat = true
        table.insert(buffs, { id = 40, icon = "aura", timed = false })
        buffs[3].count = 2
        aura({ addedAuras = { AuraData(buffs[4]) }, removedAuraInstanceIDs = { 31 },
            updatedAuraInstanceIDs = { 17 } })
        table.remove(buffs, 1)
        buffState("buffs in combat")
        ns.buffs[1].scripts.OnClick(ns.buffs[1], "RightButton")
        print("cancel in combat", #cancelled)
        inCombat = false
        for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
        buffState("buffs after combat")
        ns.buffs[1].scripts.OnClick(ns.buffs[1], "RightButton")
        print("cancel", table.concat(cancelled, ","))
        -- the edit box follows the row as it shortens, and the console's scale
        local gone = ns.buffs[1].id
        for i = #buffs, 1, -1 do if buffs[i].id == gone then table.remove(buffs, i) end end
        aura({ removedAuraInstanceIDs = { gone } })
        buffState("buffs, one cancelled")
        local k = ns.console:GetScale()
        ns.console:SetScale(1.25)
        buffState("buffs, console at 125%")
        ns.console:SetScale(k)
    end
    do return end
end

if profilesPass then
    local S = page.settings
    local heard = {}
    for _, key in ipairs({ "rows", "bareIcons", "drawer", "lootMoney", "sideTab", "bagsPoint", "bagsColumns" }) do
        ns.OnSetting(key, function(v) table.insert(heard, key .. "=" .. tostring(v)) end)
    end
    local function list(t)
        local o = {}
        for k, v in pairs(t) do
            table.insert(o, k .. "=" .. (type(v) == "table" and table.concat(v, ",") or tostring(v)))
        end
        table.sort(o)
        return table.concat(o, " ")
    end
    local function state(tag)
        print("profiles " .. tag, "profile=" .. ns.db.consoleProfile, "rows=" .. tostring(ns.db.rows),
            "bare=" .. tostring(ns.db.bareIcons), "drawer=" .. tostring(ns.db.drawer),
            "lootMoney=" .. tostring(ns.db.lootMoney), "sideTab=" .. tostring(ns.db.sideTab),
            "rowsDefault=" .. tostring(S.rows:Default()), "page.rows=" .. tostring(S.rows:Get()))
        print("  default", list(MedalluinDB.profiles.default))
        print("  light", list(MedalluinDB.profiles.light))
        print("  global", list(MedalluinDB.global))
        print("  top", "rows=" .. tostring(rawget(MedalluinDB, "rows")), "bareIcons=" .. tostring(rawget(MedalluinDB,
            "bareIcons")), "retired=" .. tostring(MedalluinDB.retired))
        print("  window stale", optionsStale(), "heard", table.concat(heard, " "))
        heard = {}
    end
    state("migrated")
    S.rows:Set(2)
    S.lootMoney:Set(false)
    state("rows 2 and no loot money on the page")
    S.consoleProfile:Set("default")
    state("switched to default")
    ns.SetOption("drawer", 2)
    ns.db.sideTab = "auras"
    state("own controls on default")
    S.consoleProfile:Set("light")
    state("back to light")
    S.rows:Set(3)
    state("rows 3 = the profile's")
    StaticPopupDialogs.MEDALLUIN_RESET_PROFILE.OnAccept()
    state("light reset")
    S.consoleProfile:Set("default")
    state("default again")
    ns.ResetProfile()
    state("default reset")
    if args[3] == "saved" then
        -- the widgets' options came from the profile in use once (see
        -- "migrated"): with the party's saved in it and the raid's back to
        -- the default (so not saved), the raid's stays the default at the
        -- next login
        print("  widgets shared", "once=" .. tostring(rawget(MedalluinDB, "widgetsShared")),
            "profile=" .. MedalluinDB.consoleProfile)
        MedalluinDB.profiles[MedalluinDB.consoleProfile].partyRange, MedalluinDB.global.raidRange = 30, nil
        for _, f in ipairs(events.ADDON_LOADED or {}) do f.scripts.OnEvent(f, "ADDON_LOADED", "Medalluin") end
        print("  widgets shared, next login", "raid=" .. tostring(MedalluinDB.global.raidRange))
    end
end
-- ------------------------------------------------------------ skills per profile
-- "skills" plays each profile's own action slots (bars/skills.lua): the first
-- switch keeping the bars, the second bringing the first profile's back, a
-- switch in combat waiting, a skill that cannot come back (an item no longer
-- in the bags, a macro removed) and kept, logout, Reset profile, and a spec
-- of its own.
if args[2] == "skills" then
    C_Spell.PickupSpell = function(id) if known[id] then cursor = { "spell", id } end end
    local S = page.settings
    local function bars()
        local o = {}
        for slot = 1, 180 do
            local a = actionSlots[slot]
            if a then table.insert(o, slot .. "=" .. a[1]:sub(1, 1) .. ":" .. tostring(a[2])) end
        end
        return table.concat(o, " ")
    end
    local function saved(profile, spec)
        local t = MedalluinCharDB.layouts[profile] and MedalluinCharDB.layouts[profile][spec or "1"]
        if not t then return "none" end
        local o = {}
        for slot = 1, 180 do
            if t[slot] then table.insert(o, slot .. "=" .. t[slot][1]:sub(1, 1) .. ":" .. tostring(t[slot][2])) end
        end
        return table.concat(o, " ")
    end
    local function state(tag)
        print("skills " .. tag, "profile=" .. ns.db.consoleProfile, "cursor=" .. tostring(cursor))
        print("  bars", bars())
        print("  saved default", saved("default"), "light", saved("light"))
        local keys = {}
        for k, c in pairs(bindings) do
            table.insert(keys, k .. "=" .. c:gsub("ACTIONBUTTON", "A"):gsub("MULTIACTIONBAR(%d)BUTTON", "M%1-"))
        end
        table.sort(keys)
        print("  keys", table.concat(keys, " "), "saves=" .. #bindingSaves)
    end
    local function keySets(db)
        local o = {}
        for profile, set in pairs(db.keys or {}) do
            local n = 0
            for _ in pairs(set) do n = n + 1 end
            table.insert(o, profile .. ":" .. n .. (set.ACTIONBUTTON1 and ("(A1=" .. table.concat(set.ACTIONBUTTON1, ",")
                .. ")") or ""))
        end
        table.sort(o)
        return table.concat(o, " ")
    end
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    -- the medallion's bars: two spells, a macro, an item, and a skyriding slot
    actionSlots = { [1] = { "spell", 133 }, [2] = { "spell", 116 }, [3] = { "macro", "Heal" },
        [4] = { "item", 6948 }, [121] = { "spell", 372608 }, [181] = { "spell", 999 } }
    state("login")
    S.consoleProfile:Set("light")
    state("first switch: the bars as they are")
    -- light's own keys: Q too on button 1, 2 off, 3 to bar 2, 4 to the map
    -- (no action button: shared by both profiles)
    SetBinding("Q", "ACTIONBUTTON1")
    SetBinding("2")
    SetBinding("3", "MULTIACTIONBAR1BUTTON1")
    SetBinding("4", "TOGGLEWORLDMAP")
    actionSlots[1], actionSlots[3], actionSlots[4] = { "spell", 2136 }, nil, { "spell", 116 }
    actionSlots[12] = { "macro", "Focus" }
    actionSlots[100] = { "item", 6948 }
    state("light's own bars")
    S.consoleProfile:Set("default")
    state("back to default")
    S.consoleProfile:Set("light")
    state("light again")
    inCombat = true
    S.consoleProfile:Set("default")
    state("default in combat: waits")
    S.consoleProfile:Set("light")
    S.consoleProfile:Set("default")
    fire("PLAYER_LOGOUT")
    state("logout with two more waiting")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    state("combat over")
    inBags[6948], macros[1] = nil, "Renamed"
    S.consoleProfile:Set("light")
    S.consoleProfile:Set("default")
    state("hearthstone gone, Heal renamed: kept for default")
    actionSlots[4] = { "spell", 122 }
    S.consoleProfile:Set("light")
    state("slot 4 used on default: the hearthstone gone from it")
    StaticPopupDialogs.MEDALLUIN_RESET_PROFILE.OnAccept()
    state("light reset: the bars stay")
    fire("PLAYER_LOGOUT")
    state("logout")
    GetSpecialization = function() return 2 end
    S.consoleProfile:Set("default")
    state("other spec: its first switch")
    print("  saved on spec 2", "light", saved("light", "2"), "default", saved("default", "2"))
    print("  key sets", "character", keySets(MedalluinCharDB), "account", keySets(MedalluinDB))
    -- account bindings: kept account-wide, and put back at login, where
    -- another character left the other profile's
    bindingSet = 1
    S.consoleProfile:Set("light")
    state("account bindings: the first switch keeps the keys")
    SetBinding("E", "ACTIONBUTTON1")
    S.consoleProfile:Set("default")
    print("  key sets", "character", keySets(MedalluinCharDB), "account", keySets(MedalluinDB))
    MedalluinDB.keys.default.ACTIONBUTTON2 = { "Z" }   -- another character's default
    fire("PLAYER_LOGIN")
    state("login: the account's default keys")
end
-- ------------------------------------------------------------ group widgets
-- "widgets" (after "group", alone or after "light") plays the draggable
-- group boxes (widgets/): the Party layout's Widget taking the console's
-- party buttons and giving them back, the tab dragged (and not in combat),
-- pets off, the raid's columns by the groups in use (a header filled as the
-- game fills it), the preview, the Boss column (overhead, vertical, both;
-- one boss or more), a boss in combat lengthening the skin, and the arena;
-- then the cells' auras by their tabs (Raid, Battleground, Boss, Arena), in
-- a battleground and out, and with "modern" the client's auras on them.
if args[2] == "widgets" or args[3] == "widgets" then
    local S = page.settings
    -- the client's auras on the units here, where the client has them ("modern")
    local held = {}
    if C_UnitAuras then
        local saved = C_UnitAuras.GetAuraDataByIndex
        C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
            if not held[unit] then return saved(unit, i, filter) end
            local a = held[unit][filter] and held[unit][filter][i]
            return a and { auraInstanceID = a.id, icon = a.icon, spellId = a.spellId, isHarmful = a.isHarmful,
                applications = 0, duration = 0, expirationTime = 0 }
        end
    end
    local exists = {}
    local realExists = UnitExists
    function UnitExists(u) return exists[u] or realExists(u) end
    local realName = UnitName
    function UnitName(u) return realName(u) or (u:match("^raid%d") and "Raider" .. u:match("%d+")) or u end
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local function n(v) return string.format("%.0f", v) end
    local function at(f, box)
        local r, b = resolve(f), resolve(box)
        return n(r[1] - b[1]) .. "," .. n(b[2] - r[2]) .. " " .. n(r[3] - r[1]) .. "x" .. n(r[4] - r[2])
    end
    local function tabs(box)
        local o = {}
        for _, t in ipairs(box.tabs) do
            if t.shown then table.insert(o, t.label.text .. "@" .. at(t, box)) end
        end
        return table.concat(o, " | ")
    end
    local function widget(tag, box)
        local p = box:GetPoint()
        local _, _, rp, x, y = box:GetPoint()
        print("  " .. tag, "shown=" .. tostring(box.shown), "by=" .. tostring(box.shownBy),
            "at=" .. tostring(p) .. ">" .. tostring(rp) .. "," .. tostring(x) .. "," .. tostring(y),
            "holder=" .. n(box.w) .. "x" .. n(box.h), "skin=" .. n(box.skin.w) .. "x" .. n(box.skin.h),
            "tabs " .. tabs(box))
    end
    local function party(tag)
        local o = {}
        local pb = ns.partyWidgetPlayer
        if pb and pb.inWidget then
            table.insert(o, "player:box " .. at(pb, ns.partyWidget))
        end
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local where = b.parent == ns.partyWidget and "box " .. at(b, ns.partyWidget)
                or "console " .. at(b, ns.console)
            table.insert(o, i .. ":" .. where .. (b.pet.shown and " pet " .. (b.pet.parent == ns.partyWidget
                and at(b.pet, ns.partyWidget) or "console") or ""))
        end
        print("  party " .. tag, table.concat(o, " | "), "role1=" .. tostring(ns.units.party1.roleFrame.points.CENTER
            and ns.units.party1.roleFrame.points.CENTER[2]), "reverse2=" .. tostring(ns.units.party2.health.reverse))
    end
    local function art()
        for _, r in ipairs(all) do
            local t = type(r.texture) == "string" and r.texture:match("(console%-%a+)$")
            if t == "console-solo" or t == "console-group" then return t end
        end
        return "none"
    end
    local function state(tag)
        stateTick()
        watchTick()
        print("widgets " .. tag, "layout=" .. tostring(ns.db.partyLayout), "boss=" .. tostring(ns.db.bossFrames),
            "sim=" .. tostring(ns.db.simParty), "art=" .. art())
        widget("party", ns.partyWidget)
        party("buttons")
        widget("raid", ns.raidWidget)
        widget("boss", ns.bossWidget)
        widget("arena", ns.arenaWidget)
        -- the level: party1's where its layout put it, the first boss's
        local function level(b)
            local r = b and b.levelText
            if not r then return "none" end
            local p, to, rp, x, y = r:GetPoint(1)
            local on = to == b.health and "health" or to == b.power and "power" or to == b.text and "text" or "other"
            local c = r.textColor or {}
            return string.format("%s>%s.%s,%s,%s text=%s colour=%.2f,%.2f,%.2f shown=%s", tostring(p), on,
                tostring(rp), tostring(x), tostring(y), tostring(r.text), c[1] or 0, c[2] or 0, c[3] or 0,
                tostring(b.shown))
        end
        print("  level " .. tag, "party1 " .. level(ns.units.party1), "| boss1 " .. level(MedalluinBossWidgetUnit1))
    end
    -- the game's header: a button per member of its group, configured by
    -- its initialConfigFunction, then given its unit
    local made = {}
    local function fillHeaders()
        for g, h in ipairs(ns.raidHeaders) do
            local k = 0
            for i, m in ipairs(raidRoster) do
                if m[2] == g then
                    k = k + 1
                    local name = h.name .. "UnitButton" .. k
                    local b = _G[name] or CreateFrame("Button", name, h, "SecureUnitButtonTemplate")
                    if not made[b] then
                        made[b] = true
                        setfenv(assert(loadstring(h.attrs.initialConfigFunction)), { self = b })()
                    end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -(k - 1) * (b.h + 3))
                    b:SetAttribute("unit", "raid" .. i)
                    b.scripts.OnAttributeChanged(b, "unit", "raid" .. i)
                    b:Show()
                end
            end
        end
    end
    local function raid(tag)
        local o = {}
        for g, h in ipairs(ns.raidHeaders) do
            for _, b in ipairs(h.all_ or {}) do
                if made[b] and b.shown then
                    table.insert(o, g .. ":" .. tostring(b.unit) .. "@" .. at(b, ns.raidWidget) .. " "
                        .. tostring(b.name.text))
                end
            end
        end
        print("  raid " .. tag, table.concat(o, " | "))
    end

    harnessHolds["group:party"] = grouped
    state("login")
    HarnessCrowns("  crowns")
    S.partyLayout:Set("widget")
    state("party layout: widget")
    HarnessCrowns("  crowns")
    -- the skin to the last member shown, in combat too: one joins, a pet
    -- comes (the widget has none: the skin stays), they go; then the
    -- editor's taller cell
    inCombat = true
    exists.party3 = true
    watchTick()
    widget("party joined in combat", ns.partyWidget)
    exists.partypet3 = true
    watchTick()
    widget("party pet in combat", ns.partyWidget)
    exists.party3, exists.partypet3 = nil, nil
    watchTick()
    widget("party left in combat", ns.partyWidget)
    -- the whole party gone: the box is hidden, its skin left as it was
    grouped = false
    watchTick()
    widget("party gone in combat", ns.partyWidget)
    grouped = true
    watchTick()
    inCombat = false
    local wasCell = ns.db.editPartyWidget
    ns.SetOption("editPartyWidget", { cell = { w = 160, h = 50 } })
    widget("party taller cell", ns.partyWidget)
    ns.SetOption("editPartyWidget", wasCell)
    S.partyWidgetPlayer:Set(false)
    widget("party without player", ns.partyWidget)
    party("without player")
    S.partyWidgetPlayer:Set(true)
    widget("party with player back", ns.partyWidget)
    party("with player back")
    -- the lead passes to the first member: no roster change comes with it
    harnessLeader = "party1"
    fire("PARTY_LEADER_CHANGED")
    HarnessCrowns("  crowns, lead passed")
    -- a secret answer wears no crown
    harnessLeader, harnessSecretLeader = nil, "party1"
    fire("PARTY_LEADER_CHANGED")
    HarnessCrowns("  crowns, secret")
    harnessLeader, harnessSecretLeader = "party2", nil
    fire("PARTY_LEADER_CHANGED")
    -- the tab is the grip
    harnessDropAt = { "TOPLEFT", "TOPLEFT", 300.4, -200.6 }
    local tab = ns.partyWidget.tabs[1]
    tab.scripts.OnDragStart(tab)
    tab.scripts.OnDragStop(tab)
    print("  dragged", "saved=" .. table.concat(MedalluinDB.global.partyWidgetPoint or {}, ","),
        "in a profile=" .. tostring(MedalluinDB.profiles[ns.db.consoleProfile].partyWidgetPoint))
    inCombat = true
    harnessDropAt = { "TOPLEFT", "TOPLEFT", 10, -10 }
    tab.scripts.OnDragStart(tab)
    tab.scripts.OnDragStop(tab)
    inCombat = false
    state("dragged in combat: stays")
    -- back to front: the tab, the skin over its foot, the cells
    local pb = ns.partyWidget
    print("  levels", "box=" .. pb.level, "tab=" .. tab.level, "skin=" .. pb.skin.level,
        "cell=" .. ns.units.party1.level, "pet=" .. ns.units.party1.pet.level)
    -- movers only on mouseover: clear until the pointer is over the box or
    -- a tab, or the box is being dragged; each box by its own option
    local function movers(tag)
        ns.UpdateWidgetMovers()
        local o = {}
        for _, w in ipairs({ { "party", pb }, { "raid", ns.raidWidget }, { "boss", ns.bossWidget },
            { "arena", ns.arenaWidget } }) do
            table.insert(o, w[1] .. "=" .. tostring(w[2].tabs[1] and w[2].tabs[1].alpha))
        end
        print("  movers " .. tag, table.concat(o, " "))
    end
    movers("default")
    S.partyWidgetMoverHover:Set(true)
    movers("party on mouseover")
    mouseOver = pb.skin
    movers("pointer on the box")
    mouseOver = tab
    movers("pointer on the tab")
    mouseOver = false
    pb.moving = true
    movers("dragging")
    pb.moving = nil
    S.partyWidgetMoverHover:Set(false)
    movers("party off")
    -- the raid's: the Raid tab's, and in a battleground the Battleground tab's
    S.raidMoverHover:Set(true)
    movers("raid on mouseover")
    local wasInstance = harnessInstance
    harnessInstance = "pvp"
    movers("raid's in a battleground")
    S.bgMoverHover:Set(true)
    movers("battleground's on mouseover")
    harnessInstance = wasInstance
    S.raidMoverHover:Set(false)
    S.bgMoverHover:Set(false)
    S.bossMoverHover:Set(true)
    movers("boss on mouseover")
    S.bossMoverHover:Set(false)
    S.arenaMoverHover:Set(true)
    movers("arena on mouseover")
    S.arenaMoverHover:Set(false)
    -- the console's pets option: the widget has no pets either way
    S.partyPets:Set(false)
    state("console pets off")
    S.partyPets:Set(true)
    -- a member's pet: none in the widget, shown on the console
    exists.partypet1 = true
    ns.UpdatePartyFrames()
    watchTick()
    print("  party pet in the widget", "shown=" .. tostring(ns.units.party1.pet.shown))
    S.partyLayout:Set("console")
    watchTick()
    print("  party pet on the console", "shown=" .. tostring(ns.units.party1.pet.shown))
    S.partyPets:Set(false)
    watchTick()
    print("  party pet, console's off", "shown=" .. tostring(ns.units.party1.pet.shown))
    S.partyPets:Set(true)
    S.partyLayout:Set("widget")
    exists.partypet1 = nil
    ns.UpdatePartyFrames()
    watchTick()
    -- the range the party fades at: the widget's, not the console's
    local wasSim = ns.db.simParty
    S.simParty:Set(true)
    stateTick()
    -- (a real group's members answer for themselves: only the preview's)
    if ns.units.party2.stub then
        local function faded()
            local o = {}
            for i = 1, 4 do
                local b = ns.units["party" .. i]
                if b.alpha and b.alpha < 1 then table.insert(o, b.unit) end
            end
            return table.concat(o, ",")
        end
        -- and the preview's "In range" row dims with the range that counts
        local function rangeRow()
            local r = ns.simButtons and ns.simButtons["party.away.2"]
            if not r then return "row missing" end
            r.scripts.OnClick(r)
            r.scripts.OnClick(r)
            return "row alpha=" .. tostring(r.alpha)
        end
        ns.units.party2.stub.inRange = false
        S.partyRange:Set(0)
        print("  party faded, console's range off", faded(), rangeRow())
        S.partyWidgetRange:Set(0)
        print("  party faded, widget's range off", faded(), rangeRow())
        S.partyRange:Set(40)
        S.partyWidgetRange:Set(40)
        ns.units.party2.stub.inRange = nil
        ns.UpdatePartyRange()
    end
    S.simParty:Set(wasSim)
    stateTick()
    S.partyLayout:Set("console")
    state("back to the console")
    S.partyLayout:Set("widget")

    -- a raid of seven: groups 1 and 3
    raidRoster = { { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 3 }, { "E", 3 }, { "F", 3 }, { "G", 3 } }
    for i = 1, 7 do exists["raid" .. i] = true end
    harnessHolds["group:raid"] = true
    fillHeaders()
    fire("GROUP_ROSTER_UPDATE")
    state("raid in groups 1 and 3")
    raid("cells")
    -- the raid's leader in group 3: its cell's crown
    harnessLeader = "raid5"
    fire("PARTY_LEADER_CHANGED")
    local crowned = {}
    for _, h in ipairs(ns.raidHeaders) do
        for _, b in ipairs(h.all_ or {}) do
            if made[b] and b.shown and b.leaderFrame.shown then
                local p, _, rp, x, y = b.leaderFrame:GetPoint(1)
                table.insert(crowned, b.unit .. "@" .. p .. ":" .. rp .. ":" .. x .. "," .. y)
            end
        end
    end
    print("  raid crowns", table.concat(crowned, " "))
    harnessLeader = "party2"
    fire("PARTY_LEADER_CHANGED")
    -- group 5 fills in combat: its column waits
    inCombat = true
    raidRoster[8] = { "H", 5 }
    exists.raid8 = true
    fillHeaders()
    fire("GROUP_ROSTER_UPDATE")
    state("group 5 in combat")
    raid("cells")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    state("combat over")
    raid("cells")
    -- out of range: the Raid tab's distance, the Battleground tab's in one
    local function faded()
        local o = {}
        for _, h in ipairs(ns.raidHeaders) do
            for _, b in ipairs(h.all_ or {}) do
                if made[b] and b.shown and b.alpha < 1 then table.insert(o, b.unit) end
            end
        end
        return table.concat(o, ",")
    end
    UnitInRange = function(u) return u ~= "raid2", true end
    S.raidRange:Set(0)
    ns.widgetFade.scripts.OnUpdate(ns.widgetFade, 1)
    print("raid faded, raid's range off", faded())
    harnessInstance = "pvp"
    ns.widgetFade.scripts.OnUpdate(ns.widgetFade, 1)
    print("raid faded, in a battleground at 40", faded())
    harnessInstance = "none"
    S.raidRange:Set(40)
    ns.widgetFade.scripts.OnUpdate(ns.widgetFade, 1)
    UnitInRange = nil
    -- a member sheeped: the client's word on its cell
    if C_UnitAuras then
        held.raid1 = { HARMFUL = { { id = 905, icon = "sheep", spellId = 118, isHarmful = true } } }
        fire("UNIT_AURA", "raid1")
        local b = _G.MedalluinRaidGroup1UnitButton1
        print("raid1 sheeped", "cc=" .. tostring(b.ccWidget.shown and b.ccWidget.icon.texture))
        held.raid1 = nil
        fire("UNIT_AURA", "raid1")
    end
    raidRoster = {}
    harnessHolds["group:raid"] = nil
    for i = 1, 8 do exists["raid" .. i] = nil end

    -- the preview: every box, the raid's two groups
    S.simParty:Set(true)
    fire("GROUP_ROSTER_UPDATE")
    state("preview")
    local p = {}
    for _, f in ipairs(ns.raidWidget.all_ or {}) do
        if f.stub and f.shown then table.insert(p, f.stub.name .. "@" .. at(f, ns.raidWidget)) end
    end
    print("  raid preview", table.concat(p, " | "))
    -- a dead raid member wears the dead look; an enemy's cell has none
    for _, f in ipairs(ns.raidWidget.all_ or {}) do
        if f.stub and f.shown then
            f.stub.dead = true
            ns.UpdateWidgetCell(f)
            print("  raid dead", f.stub.name, "shown=" .. tostring(f.dead and f.dead.shown),
                "name=" .. tostring(f.dead and f.dead.name.text), "texts=" .. tostring(f.text.alpha or 1),
                "wings=" .. tostring(f.dead and f.dead.wings.w), "boss cell=" .. tostring(_G.MedalluinBossWidgetUnit1.dead))
            f.stub.dead = nil
            ns.UpdateWidgetCell(f)
            print("  raid alive", f.stub.name, "shown=" .. tostring(f.dead and f.dead.shown))
            break
        end
    end
    S.bossFrames:Set("vertical")
    state("bosses vertical (two simulated)")
    ns.sim.enemies.bosses = 1
    ns.UpdateWidgets()
    state("one boss")
    S.bossFrames:Set("both")
    state("bosses both")
    S.simParty:Set(false)
    fire("GROUP_ROSTER_UPDATE")
    state("preview off")
    -- a real boss, then a second mid-fight
    exists.boss1 = true
    harnessHolds["@boss1,exists"] = true
    fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    state("boss1 engaged")
    inCombat = true
    exists.boss2 = true
    harnessHolds["@boss2,exists"] = true
    fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    state("boss2 mid-fight")
    inCombat = false
    S.bossFrames:Set("overhead")
    state("bosses overhead")
    exists.boss1, exists.boss2 = nil, nil
    harnessHolds["@boss1,exists"], harnessHolds["@boss2,exists"] = nil, nil
    -- an arena of two
    exists.arena1, exists.arena2 = true, true
    harnessHolds["@arena1,exists"] = true
    fire("ARENA_OPPONENT_UPDATE")
    state("arena")
    exists.arena1, exists.arena2 = nil, nil
    harnessHolds["@arena1,exists"] = nil

    -- auras on the cells, each by its own tab (Unit Frames; console/auras.lua):
    -- what a cell shows, and on the overhead's bosses where the value went
    local function auras(b)
        local o = {}
        if b.dispelGlow and b.dispelGlow.shown then table.insert(o, "glow") end
        if b.ccWidget and b.ccWidget.shown then table.insert(o, "cc=" .. tostring(b.ccWidget.icon.texture)) end
        if b.bossDebuff and b.bossDebuff.shown then
            table.insert(o, "boss=" .. tostring(b.bossDebuff.icon.texture))
        end
        local buffs = 0
        for _, btn in ipairs(b.buffWidgets or {}) do if btn.shown then buffs = buffs + 1 end end
        if buffs > 0 then table.insert(o, "buffs=" .. buffs) end
        local m = {}
        for _, btn in ipairs(b.mineWidgets or {}) do
            if btn.shown then table.insert(m, tostring(btn.icon.texture):match("[^\\]+$")) end
        end
        if #m > 0 then table.insert(o, "mine=" .. table.concat(m, ",")) end
        return #o > 0 and table.concat(o, " ") or "-"
    end
    local function cells(tag)
        local o = {}
        for i, f in ipairs(ns.raidWidget.all_ or {}) do
            if f.stub and f.shown then table.insert(o, f.stub.name .. ":" .. auras(f)) end
        end
        print("auras " .. tag, "raid", table.concat(o, " | "), "range=" .. tostring(ns.RaidRange()))
        o = {}
        for i = 1, 3 do table.insert(o, i .. ":" .. auras(_G["MedalluinBossWidgetUnit" .. i])) end
        print("auras " .. tag, "boss widget", table.concat(o, " | "))
        o = {}
        for i = 1, 3 do
            local b = ns.overheadUnits["boss" .. i]
            local v = b.value.points.RIGHT
            local by = v and v[1] and (v[1] == b.value:GetParent() and "text" or "icons") or "?"
            table.insert(o, i .. ":" .. auras(b) .. " value@" .. by .. (v and "," .. tostring(v[3]) or ""))
        end
        print("auras " .. tag, "overhead", table.concat(o, " | "))
        o = {}
        for i = 1, 3 do table.insert(o, i .. ":" .. auras(_G["MedalluinArenaWidgetUnit" .. i])) end
        print("auras " .. tag, "arena", table.concat(o, " | "))
    end
    -- the party's frames answer to the console's options or the widget's,
    -- by where they stand (Unit Frames > Party)
    local function party(tag)
        local o = {}
        for i = 1, 4 do table.insert(o, i .. ":" .. auras(ns.units["party" .. i])) end
        print("auras " .. tag, "party (" .. ns.db.partyLayout .. ")", table.concat(o, " | "))
    end
    -- the fight above ended without the game's word: the overhead's layout
    -- held back for it runs now
    fire("PLAYER_REGEN_ENABLED")
    S.simParty:Set(true)
    ns.sim.enemies.bosses = 3
    S.bossFrames:Set("both")
    fire("GROUP_ROSTER_UPDATE")
    stateTick()
    watchTick()
    cells("preview")
    for _, f in ipairs(ns.raidWidget.all_ or {}) do
        if f.stub and f.shown then
            print("  raid preview cell over the skin", "cell=" .. f.level, "skin=" .. ns.raidWidget.skin.level)
            break
        end
    end
    local m = _G.MedalluinBossWidgetUnit1.mineWidgets
    print("auras mine row", "size=" .. n(m[1].w) .. "x" .. n(m[1].h), "at=" .. at(m[1], _G.MedalluinBossWidgetUnit1)
        .. " " .. at(m[3], _G.MedalluinBossWidgetUnit1), "overhead=" .. n(ns.overheadUnits.boss1.mineWidgets[1].w))
    for _, key in ipairs({ "bossMine", "bossWidgetMine", "arenaCC", "arenaMine", "raidGlow", "raidCC", "raidBoss" }) do
        S[key]:Set(false)
        cells(key .. " off")
        S[key]:Set(true)
    end
    party("preview")
    for _, pair in ipairs({ { "auraGlow", "partyWidgetGlow" }, { "auraCC", "partyWidgetCC" },
        { "auraBuffs", "partyWidgetBuffs" }, { "auraBoss", "partyWidgetBoss" } }) do
        local console, widget = pair[1], pair[2]
        S[console]:Set(false)
        party(console .. " off")
        S[widget]:Set(false)
        party(widget .. " off")
        S[console]:Set(true)
        S.partyLayout:Set("console")
        party(widget .. " off, back to the console")
        S[widget]:Set(true)
        S.partyLayout:Set("widget")
    end
    -- in a battleground the raid answers to the Battleground tab
    S.raidRange:Set(20)
    S.bgRange:Set(10)
    cells("raid range 20, battleground 10")
    harnessInstance = "pvp"
    fire("PLAYER_ENTERING_WORLD")
    cells("in a battleground")
    for _, key in ipairs({ "bgGlow", "bgCC" }) do
        S[key]:Set(false)
        cells(key .. " off")
        S[key]:Set(true)
    end
    harnessInstance = "none"
    fire("PLAYER_ENTERING_WORLD")
    cells("out again")
    S.simParty:Set(false)
    fire("GROUP_ROSTER_UPDATE")
    -- the client's auras, where it has them: your debuffs on a real boss,
    -- an arena enemy sheeped
    if C_UnitAuras then
        held.boss1 = { ["HARMFUL|PLAYER"] = { { id = 901, icon = "dot-a" }, { id = 902, icon = "dot-b" } } }
        held.arena1 = { HARMFUL = { { id = 903, icon = "sheep", spellId = 118, isHarmful = true } },
            ["HARMFUL|PLAYER"] = { { id = 904, icon = "dot-c" } } }
        exists.boss1, exists.arena1 = true, true
        harnessHolds["@boss1,exists"], harnessHolds["@arena1,exists"] = true, true
        fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
        fire("ARENA_OPPONENT_UPDATE")
        fire("UNIT_AURA", "boss1")
        fire("UNIT_AURA", "arena1")
        stateTick()
        watchTick()
        cells("the client's")
        -- a third debuff: the client says so, and the cells hear it
        table.insert(held.boss1["HARMFUL|PLAYER"], { id = 906, icon = "dot-d" })
        fire("UNIT_AURA", "boss1")
        cells("boss1's third")
        -- a boss in combat: the game's unit watch shows its cell, the layout waits
        inCombat = true
        held.boss2 = { ["HARMFUL|PLAYER"] = { { id = 907, icon = "dot-e" } } }
        exists.boss2 = true
        harnessHolds["@boss2,exists"] = true
        fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
        watchTick()
        cells("boss2 in combat")
        inCombat = false
        fire("PLAYER_REGEN_ENABLED")
    end
end
-- ------------------------------------------------------------ key binding
local function KeybindPass()
    local printed = {}
    local realPrint = print
    local function say(...) realPrint(...) end
    local function keysOf(command) return table.concat({ GetBindingKey(command) }, ",") end
    local binder = ns.keybinder
    local function state(tag)
        local marked = 0
        for _, b in ipairs({ ActionButton1, StanceButton1, PetActionButton1, ns.bar7Buttons and ns.bar7Buttons[1] }) do
            for _, t in ipairs(b and b.all_ or {}) do
                if t.kind == "Texture" and t.layer == "OVERLAY" and t.sub == 7 and t.shown then marked = marked + 1 end
            end
        end
        say("kb " .. tag, "on=" .. tostring(ns.keybinding), "banner=" .. tostring(_G.MedalluinKeybindBanner
            and _G.MedalluinKeybindBanner.shown), "binder=" .. tostring(binder.shown)
            .. (binder.shown and binder.target and ("@" .. binder.target:GetName()) or ""),
            "keyboard=" .. tostring(binder.keyboard), "marked=" .. marked, "saves=" .. #bindingSaves)
    end
    binder.EnableKeyboard = function(self, on) self.keyboard = on end
    local tip = {}
    GameTooltip.SetText = function(_, t) tip = { t } end
    GameTooltip.AddLine = function(_, t) table.insert(tip, t) end
    local function hover(btn) if btn.scripts.OnEnter then btn.scripts.OnEnter(btn) end end
    local function key(k) binder.scripts.OnKeyDown(binder, k) end
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end

    say("kb commands", ns.BindingCommand(ActionButton3), ns.BindingCommand(MultiBarBottomLeftButton2),
        ns.BindingCommand(StanceButton1), ns.BindingCommand(PetActionButton2),
        tostring(ns.BindingCommand(ns.bar7Buttons and ns.bar7Buttons[1])), tostring(ns.BindingCommand(Minimap)))
    state("at login")
    hover(ActionButton3)
    state("hover while off")
    -- refused in combat, with a word
    inCombat = true
    print = function(...) table.insert(printed, table.concat({ ... }, " ")) end
    SlashCmdList.MDLUI("kb")
    print = realPrint
    inCombat = false
    state("in combat")
    say("kb refused", printed[1] or "-")
    -- the window's button closes the window and starts it
    ns.OpenOptions("general")
    for _, c in ipairs(ns.optionPages["general"].controls) do
        if c.spec.label == "Bind keys" then c.scripts.OnClick(c) end
    end
    state("from the page")
    say("kb page closed", tostring(page.opened == nil))
    -- a faded bar comes back while binding
    local fade = ns.barFade
    if fade then
        page.settings.visibility:Set(2)
        for _ = 1, 20 do fade.scripts.OnUpdate(fade, 0.05) end
        say("kb fade", "bar1 alpha while binding=" .. tostring(ns.actionBar.alpha))
    end
    -- point, press
    hover(ActionButton3)
    state("hover 3")
    say("kb binder", "over the button=" .. tostring(binder.all == ActionButton3), "tip=" .. table.concat(tip, " | "))
    key("Q")
    say("kb Q on 3", "3=" .. keysOf("ACTIONBUTTON3"), "Q=" .. tostring(bindings.Q),
        "propagated=" .. tostring(binder.propagate), "tip=" .. table.concat(tip, " | "))
    -- a modifier alone is no binding; with a key it makes a chord
    modsDown.SHIFT = true
    key("LSHIFT")
    key("LMETA")
    say("kb LSHIFT, LMETA", "3=" .. keysOf("ACTIONBUTTON3"))
    key("E")
    modsDown.SHIFT = nil
    say("kb SHIFT-E on 3", "3=" .. keysOf("ACTIONBUTTON3"), "Q=" .. tostring(bindings.Q))
    modsDown.ALT, modsDown.CTRL = true, true
    key("4")
    modsDown.ALT, modsDown.CTRL = nil, nil
    say("kb ALT-CTRL-4 on 3", "3=" .. keysOf("ACTIONBUTTON3"), "4=" .. keysOf("ACTIONBUTTON4"))
    -- a key another button has moves over
    hover(ActionButton5)
    modsDown.ALT, modsDown.CTRL = true, true
    key("4")
    modsDown.ALT, modsDown.CTRL = nil, nil
    say("kb moved", "3=" .. keysOf("ACTIONBUTTON3"), "5=" .. keysOf("ACTIONBUTTON5"))
    -- the mouse: the two clicking buttons skipped, the rest bound, the wheel
    binder.scripts.OnMouseDown(binder, "LeftButton")
    binder.scripts.OnMouseDown(binder, "RightButton")
    say("kb clicks", "5=" .. keysOf("ACTIONBUTTON5"))
    binder.scripts.OnMouseDown(binder, "MiddleButton")
    say("kb middle", "5=" .. keysOf("ACTIONBUTTON5"))
    binder.scripts.OnMouseWheel(binder, 1)
    say("kb wheel", "5=" .. keysOf("ACTIONBUTTON5"))
    -- Esc over a button removes its keys and keeps the mode
    key("ESCAPE")
    state("Esc over 5")
    say("kb Esc", "5=" .. keysOf("ACTIONBUTTON5"), "saved to set " .. tostring(bindingSaves[#bindingSaves]))
    -- the other bars
    hover(StanceButton1); key("Z")
    hover(PetActionButton2); key("X")
    say("kb stance, pet", "SHAPESHIFTBUTTON1=" .. keysOf("SHAPESHIFTBUTTON1"),
        "BONUSACTIONBUTTON2=" .. keysOf("BONUSACTIONBUTTON2"))
    local b7 = ns.bar7Buttons and ns.bar7Buttons[1]
    if b7 then
        hover(b7); key("V")
        fire("UPDATE_BINDINGS")
        local hk = b7.medalluinHotkey or b7.HotKey
        say("kb grid", "keys=" .. keysOf(ns.BindingCommand(b7)),
            "buttonType=" .. tostring(b7.buttonType), "bare=" .. tostring(ns.db.bareIcons),
            "hotkey=" .. tostring(hk and hk.text))
    end
    binder.scripts.OnLeave(binder)
    state("left")
    -- the banner: Esc ends it, other keys go on to the game
    local banner = _G.MedalluinKeybindBanner
    banner.scripts.OnKeyDown(banner, "W")
    say("kb banner W", "propagated=" .. tostring(banner.propagate))
    banner.scripts.OnKeyDown(banner, "ESCAPE")
    say("kb banner Esc", "propagated=" .. tostring(banner.propagate))
    state("Esc away")
    hover(ActionButton3)
    state("hover after")
    if fade then
        for _ = 1, 20 do fade.scripts.OnUpdate(fade, 0.05) end
        say("kb fade", "bar1 alpha after=" .. tostring(ns.actionBar.alpha))
    end
    -- /mdlui kb toggles; Done ends it; combat ends it
    SlashCmdList.MDLUI("kb")
    state("/mdlui kb")
    SlashCmdList.MDLUI("KB")
    state("/mdlui KB again")
    SlashCmdList.MDLUI("bind")
    state("/mdlui bind")
    banner.done.scripts.OnClick(banner.done)
    state("Done")
    SlashCmdList.MDLUI("keybind")
    hover(ActionButton1)
    state("/mdlui keybind, over 1")
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    state("combat starts")
    inCombat = false
end

-- ------------------------------------------------------------ paging
local function PagingPass()
    local S = page.settings
    local shown = {}
    function StaticPopup_Show(which, a, _, data) table.insert(shown, which .. ":" .. tostring(a)); return data end
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local function driver(h) return tostring(h and h.stateDrivers and h.stateDrivers.page) end
    local H = ns.pagingHeaders
    local function bars(tag)
        local line = {}
        for _, key in ipairs({ "bar1Paging", "row2Paging", "row3Paging" }) do
            local h = H[key]
            table.insert(line, key .. "=" .. (h and driver(h) or "no header"))
        end
        if ns.bar7Frame then table.insert(line, "grid=" .. driver(ns.bar7Frame)) end
        print("paging " .. tag, table.concat(line, " | "))
    end
    -- the game's state driver: the snippet with the conditional's result, in
    -- an environment of the restricted API, run securely
    local world = harnessWorld
    local function run(h, newstate)
        harnessSecure = true
        setfenv(assert(loadstring(h.attrs["_onstate-page"])), harnessSnippetEnv(h, newstate))()
        harnessSecure = false
        local b1, b12 = h.buttons[1], h.buttons[#h.buttons]
        return string.format("page=%s b1=%s b12=%s", tostring(h.attrs.page), tostring(b1.attrs.actionpage),
            tostring(b12.attrs.actionpage))
    end
    -- which buttons Medalluin's own code set an attribute on (each a blocked
    -- click), by row
    local function taint(tag)
        local line = {}
        local rows = { { "bar1", H.bar1Paging and H.bar1Paging.buttons }, { "row2", H.row2Paging and H.row2Paging.buttons },
            { "row3", H.row3Paging and H.row3Paging.buttons }, { "grid", ns.bar7Buttons } }
        for _, row in ipairs(rows) do
            local n, by = 0, nil
            for _, b in ipairs(row[2] or {}) do
                if b.taintedBy then n, by = n + 1, b.taintedBy end
            end
            if row[2] then table.insert(line, row[1] .. "=" .. n .. (by and " (" .. by .. ")" or "")) end
        end
        print("paging tainted " .. tag, table.concat(line, " | "))
    end
    local function pages(tag)
        local line = {}
        for _, key in ipairs({ "bar1Paging", "row2Paging", "row3Paging" }) do
            local h = H[key]
            if h then table.insert(line, key .. " b1=" .. tostring(h.buttons[1].attrs.actionpage)) end
        end
        if ns.bar7Buttons then table.insert(line, "grid slot1=" .. tostring(ns.bar7Buttons[1].action)) end
        print("paging pages " .. tag, table.concat(line, " | "))
    end
    -- after login: paged by the game's first update, none by Medalluin
    pages("after login")
    taint("at login")
    print("paging headers", "bar1 buttons=" .. (H.bar1Paging and #H.bar1Paging.buttons or 0),
        "row2 first=" .. (H.row2Paging and H.row2Paging.buttons[1]:GetName() or "-"),
        "row3 first=" .. (H.row3Paging and H.row3Paging.buttons[1]:GetName() or "-"))
    bars("at login")
    if H.row2Paging then
        print("paging run row2 6", run(H.row2Paging, "6"))
        print("paging run bar1 possess, vehicle", (function() world.vehicle = true
            local r = run(H.bar1Paging, "possess"); world.vehicle = false; return r end)())
        print("paging run bar1 possess, override", (function() world.override = true
            local r = run(H.bar1Paging, "possess"); world.override = false; return r end)())
        print("paging run bar1 possess, nothing up", run(H.bar1Paging, "possess"))
        -- bar 1 on a page, then back to Blizzard's: its pages taken off again
        S.bar1Paging:Set("page3")
        bars("bar1 page3")
        print("paging run bar1 3", run(H.bar1Paging, "3"))
        S.bar1Paging:Set("stances")
        bars("bar1 stances")
        S.row2Paging:Set("stances")
        bars("row2 stances")
        S.bar1Paging:Set("default")
        bars("bar1 default")
        pages("bar1 default, before the update")
        stateTick()
        print("paging bar1 cleared", "page=" .. tostring(H.bar1Paging.attrs.page),
            "b1=" .. tostring(H.bar1Paging.buttons[1].attrs.actionpage))
        S.row2Paging:Set("default")
    end
    -- Custom with nothing yet opens the editor; its first text is the
    -- conditional in use
    S.row3Paging:Set("custom")
    print("paging custom, empty", "popups=" .. table.concat(shown, ","),
        "editor starts=" .. ns.PagingStart("row3Paging"))
    bars("custom, empty")
    local dialog = StaticPopupDialogs.MEDALLUIN_PAGING
    local box = { text = "" }
    function box:SetText(t) self.text = t end
    function box:GetText() return self.text end
    function box:HighlightText() end
    local fake = { editBox = box }
    function fake:Hide() self.hidden = true end
    box.GetParent = function() return fake end
    local bar3 = ns.PAGING_BARS[3]
    dialog.OnShow(fake, bar3)
    print("paging editor shows", box.text)
    -- cancelling a Custom with no conditional goes back to the default
    dialog.OnCancel(fake, bar3)
    print("paging cancelled", "row3=" .. ns.db.row3Paging)
    box.text = "  [mod:shift] 2; [stealth] 7; 5  "
    dialog.OnAccept(fake, bar3)
    print("paging saved", "row3=" .. ns.db.row3Paging, "custom=" .. ns.db.row3PagingCustom,
        "page shows=" .. tostring(S.row3Paging:Get()))
    bars("custom saved")
    dialog.OnShow(fake, bar3)
    print("paging editor reopens", box.text)
    box.text = ""
    dialog.EditBoxOnEnterPressed(box, bar3)
    print("paging saved empty", "row3=" .. ns.db.row3Paging, "hidden=" .. tostring(fake.hidden))
    bars("custom emptied")
    -- in combat a change waits for combat to end
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    S.row3Paging:Set("page9")
    bars("combat, row3 page9 asked")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    bars("combat over")
    -- the grid, where there is one
    if ns.bar7Frame then
        S.gridPaging:Set("page9")
        bars("grid page9")
        S.gridPaging:Set("default")
        bars("grid default")
        local pick = harnessPick
        local grid = ns.bar7Frame
        local function gridRun(newstate)
            harnessSecure = true
            setfenv(assert(loadstring(grid.attrs["_onstate-page"])), harnessSnippetEnv(grid, newstate))()
            harnessSecure = false
            local b1, b10 = grid:GetFrameRef("btn1"), grid:GetFrameRef("btn10")
            return string.format("slots %s-%s", tostring(b1.action), tostring(b10.action))
        end
        local driver = grid.stateDrivers.page
        local bar1 = H.bar1Paging and H.bar1Paging.stateDrivers and H.bar1Paging.stateDrivers.page
        print("paging bar1 with a grid", "driver=" .. tostring(bar1),
            "skyriding=" .. tostring(bar1 and pick(bar1, { ["bonusbar:5"] = true })),
            "cat=" .. tostring(bar1 and pick(bar1, { ["bonusbar:1"] = true })))
        for _, case in ipairs({ { "standing", {} }, { "cat form", { ["bonusbar:1"] = true, ["form:1"] = true } },
            { "stealth", { stealth = true } }, { "skyriding", { ["bonusbar:5"] = true } },
            { "skyriding in a form", { ["bonusbar:5"] = true, ["form:3"] = true } } }) do
            local page = pick(driver, case[2])
            print("paging grid " .. case[1], "page=" .. tostring(page), gridRun(page))
        end
        -- the game's update pages the grid in combat too: stealth
        stateTick()
        inCombat = true
        harnessHolds.stealth = true
        stateTick()
        pages("grid, stealth in combat")
        harnessHolds.stealth = nil
        stateTick()
        inCombat = false
    end
    taint("after every change")
    -- /mdlui taint: WoW's own answer for every field and global the click
    -- reads; here a stub that knows two tainted values and one of ours
    do
        -- a machinery table with one field Medalluin wrote, and a global it did
        local spareGlobal = NUM_ACTIONBAR_BUTTONS
        NUM_ACTIONBAR_BUTTONS = 12
        HarnessCVarRegistry = { cache = 1, clean = 2 }
        local tainted = { [ActionButton1] = { isExtra = "Medalluin", medalluinIcon = "Medalluin" },
            [HarnessCVarRegistry] = { cache = "Medalluin" } }
        ActionButton1.isExtra, ActionButton1.medalluinIcon = false, true
        function issecurevariable(t, k)
            if k == nil then
                if t == "NUM_ACTIONBAR_BUTTONS" then return false, "SomeAddon" end
                return true
            end
            local by = tainted[t] and tainted[t][k]
            return not by, by
        end
        SlashCmdList.MDLUI("taint")
        -- a blocked click prints it by itself, with the button under the mouse
        function GetMouseFoci() return { MultiBarBottomLeftButton1 } end
        for _, f in ipairs(events.ADDON_ACTION_FORBIDDEN or {}) do
            f.scripts.OnEvent(f, "ADDON_ACTION_FORBIDDEN", "OtherAddon", "UseAction()")
            f.scripts.OnEvent(f, "ADDON_ACTION_FORBIDDEN", "Medalluin", "UseAction()")
            f.scripts.OnEvent(f, "ADDON_ACTION_FORBIDDEN", "Medalluin", "UseAction()")
        end
        GetMouseFoci = nil
        issecurevariable = nil
        HarnessCVarRegistry, NUM_ACTIONBAR_BUTTONS = nil, spareGlobal
        ActionButton1.isExtra, ActionButton1.medalluinIcon = nil, nil
        SlashCmdList.MDLUI("debug")
    end
    -- per profile: the other profile has its own, and coming back brings these
    -- back; row 2 is Custom on both, so only its conditional moves
    ns.SetOption("row2PagingCustom", "[mod:alt] 3; 6")
    ns.SetOption("row2Paging", "custom")
    S.consoleProfile:Set(ns.db.consoleProfile == "light" and "default" or "light")
    print("paging other profile", "row3=" .. ns.db.row3Paging)
    bars("other profile")
    ns.SetOption("row2PagingCustom", "[mod:ctrl] 4; 6")
    ns.SetOption("row2Paging", "custom")
    bars("other profile, row2 custom")
    S.consoleProfile:Set(ns.db.consoleProfile == "light" and "default" or "light")
    print("paging back", "row3=" .. ns.db.row3Paging)
    bars("back")
    SlashCmdList.MDLUI("paging")
    print("/mdlui paging opens", tostring(page.opened))

    -- extra bar empty buttons hide properly, while Bar 1 empty buttons stay visible
    local bExtra = _G.MultiBarBottomLeftButton1
    local bMain = _G.ActionButton1
    local actionSlot = bExtra.action
    local oldHasAction = HasAction
    bExtra.HotKey:SetText("s-1")
    bExtra.HotKey:Show()
    print("extraButton.withAction", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown),
        "mainAlpha=" .. tostring(bMain:GetAlpha()))
    HasAction = function(a) return a ~= actionSlot end
    ns.HasAction = HasAction
    ns.UpdateAllExtraButtons()
    print("extraButton.empty", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown),
        "mainAlpha=" .. tostring(bMain:GetAlpha()))
    -- simulate Blizzard trying to reset alpha to 1 or show hotkey while empty
    bExtra:SetAlpha(1)
    bExtra.HotKey:Show()
    print("extraButton.blizzOverridePrevented", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown))
    fire("ACTIONBAR_SHOWGRID")
    print("extraButton.showgrid", "extraAlpha=" .. tostring(bExtra:GetAlpha()))
    fire("ACTIONBAR_HIDEGRID")
    print("extraButton.hidegrid", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown))
    -- toggle hideEmpty setting
    ns.SetOption("hideEmpty", false)
    print("extraButton.hideEmpty=false", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown))
    ns.SetOption("hideEmpty", true)
    print("extraButton.hideEmpty=true", "extraAlpha=" .. tostring(bExtra:GetAlpha()),
        "extraHotkey=" .. tostring(bExtra.HotKey and bExtra.HotKey.shown))
    HasAction = oldHasAction
    ns.HasAction = oldHasAction
    ns.UpdateAllExtraButtons()
    print("extraButton.restored", "extraAlpha=" .. tostring(bExtra:GetAlpha()))
end

local function RowPass()
    local S = page.settings
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local function shown(r) return tostring(r and r.shown) end
    local function console(tag)
        print(tag, "row=" .. tostring(ns.PartyRowShown()), "band=" .. shown(ns.partyRowBand),
            "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
            "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel),
            "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    end
    local function members(tag)
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            out(tag .. " party" .. i, b, string.format("health=%s power=%s", tostring(b.health.h),
                tostring(b.power.h)))
            -- the pet in its bracket under its owner, its name at its outer end
            local p, rel, rp = b.pet:GetPoint(1)
            local np = b.pet.name:GetPoint(1)
            out(tag .. " partypet" .. i, b.pet, string.format("shown=%s bracket=%s under=%s name=%s", shown(b.pet),
                shown(b.pet.bracket), tostring(rel == b and p .. ">" .. rp), tostring(np)))
            out(tag .. " partypet" .. i .. ".health", b.pet.health)
        end
    end
    print("row option", "saved=" .. tostring(ns.db.partyLayout), "profile=" .. ns.db.consoleProfile,
        "stored=" .. tostring(MedalluinDB.profiles.light.partyLayout))
    hasTarget = false
    inCombat = false
    fire("PLAYER_TARGET_CHANGED")
    fire("PLAYER_REGEN_ENABLED")
    console("row, no target")
    out("row band", ns.partyRowBand)
    for i, bg in ipairs(ns.partyRowBackings) do out("row backing " .. i, bg, "shown=" .. shown(bg)) end
    stateTick()
    members("row")
    HarnessCrowns("row crowns")
    -- which way each member faces: the row mirrors across its centre, as
    -- the console's windows do (ns.PartySide)
    local function faces(tag)
        local function pt(r)
            local p, _, rp, x, y = r:GetPoint(1)
            return string.format("%s>%s,%d,%d", p, rp, x, y)
        end
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            print(tag .. " faces party" .. i, string.format(
                "fill=%s,%s,%s name=%s,%s role=%s value=%s buff=%s,%s", tostring(b.health.reverse),
                tostring(b.power.reverse), tostring(b.pet.health.reverse), tostring(b.name.justifyH), pt(b.name),
                pt(b.roleFrame), pt(b.value), pt(b.buffWidgets[1]), pt(b.buffWidgets[2])))
        end
    end
    faces("row")
    -- an edited row (two to a line, its own way) is laid from a snapshot
    -- of how the button had it: a side change must take a fresh one
    ns.SetOption("editParty", { buffs = { cols = 2 } })
    ns.SetOption("editPartyWidget", { buffs = { cols = 2 } })
    for i = 1, 4 do ns.ApplyEdits(ns.units["party" .. i]) end
    faces("row, two to a line")
    -- pets off
    S.partyPets:Set(false)
    stateTick()
    members("row, pets off")
    S.partyPets:Set(true)
    stateTick()
    -- no group and no preview: the row folds and the minimap comes back. The
    -- group leaving and the preview going each tell the row on their own.
    local wasGrouped, wasSim = grouped, ns.db.simParty
    S.simParty:Set(false)
    console("row, preview off")
    grouped = false
    fire("GROUP_ROSTER_UPDATE")
    console("row, solo")
    for i, bg in ipairs(ns.partyRowBackings) do print("row solo backing " .. i, shown(bg)) end
    S.simParty:Set(true)
    console("row, solo, preview on")
    S.simParty:Set(false)
    console("row, solo, preview off")
    grouped = true
    fire("GROUP_ROSTER_UPDATE")
    console("row, group again")
    grouped = wasGrouped
    S.simParty:Set(wasSim)
    fire("GROUP_ROSTER_UPDATE")
    -- the option, played out to the widget and back again
    S.partyLayout:Set("widget")
    stateTick()
    console("widget")
    members("widget")
    faces("widget")
    S.partyLayout:Set("console")
    stateTick()
    console("console again")
    members("console again")
    faces("console again")
    ns.SetOption("editParty", false)
    ns.SetOption("editPartyWidget", false)
    for i = 1, 4 do ns.ApplyEdits(ns.units["party" .. i]) end
    -- a change asked for in combat waits for it to end
    inCombat = true
    S.partyLayout:Set("widget")
    out("widget asked in combat party1", ns.units.party1)
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    out("widget after combat party1", ns.units.party1)
end

local editorPass = args[2] == "editor" or args[3] == "editor" or args[4] == "editor"
-- the unit-frame editor (editor.lua, options/editor.lua): untouched it
-- moves nothing; a place is mirrored across the console's copies; sizes,
-- fonts, Shown and formats reach the buttons; cells resize; Reset gives
-- back what the frame's own code laid; the options are kept per profile or
-- shared as the frame is; edit mode's boxes drag, nudge and leave in a fight
local function EditorPass()
    local E = ns.editor
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local function n(v)
        if isSecret(v) then return "S" end
        return v and string.format("%.0f", v) or "-"
    end
    local function rel(b, r)
        if r == b then return "frame" elseif r == b.health then return "health"
        elseif r == b.power then return "power" elseif r == b.name then return "name"
        elseif r == b.text then return "text" end
        return r and (r.GetName and r:GetName() or "other") or "nil"
    end
    local function pts(b, r)
        local o = {}
        for i = 1, r:GetNumPoints() do
            local p, to, rp, x, y = r:GetPoint(i)
            o[#o + 1] = p .. ">" .. rel(b, to) .. "." .. rp .. "," .. n(x) .. "," .. n(y)
        end
        return table.concat(o, " ")
    end
    local function fonts(r)
        local f, s, fl = r:GetFont()
        return f and (n(s) .. (fl and fl ~= "" and "/" .. fl or "")) or "nofont"
    end
    local function piece(tag, b, id)
        local got = E.PIECES[id].get(b)
        if not got then print("  " .. tag, id, "none"); return end
        local r = E.PIECES[id].type == "row" and got[1] or got
        print("  " .. tag, id, pts(b, r), n(r.w) .. "x" .. n(r.h), "alpha=" .. n((r.alpha or 1) * 100),
            E.PIECES[id].type == "text" and ("font=" .. fonts(r) .. " justify=" .. tostring(r.justifyH)
                .. " text=" .. tostring(r.text)) or "")
    end
    -- every piece of every button on every frame, to compare before and after
    local function everything()
        local o = {}
        for _, frame in ipairs(E.FRAMES) do
            for i, b in ipairs(frame.buttons()) do
                for _, id in ipairs(frame.pieces) do
                    local got = E.PIECES[id].get and E.PIECES[id].get(b)
                    if got then
                        for k, r in ipairs(E.PIECES[id].type == "row" and got or { got }) do
                            o[#o + 1] = frame.id .. i .. id .. k .. "=" .. pts(b, r) .. " " .. n(r.w) .. "x"
                                .. n(r.h) .. " " .. fonts(r) .. " " .. tostring(r.GetJustifyH and r:GetJustifyH())
                        end
                    end
                end
            end
        end
        return o
    end
    local function same(a, b)
        local diff = 0
        for i = 1, math.max(#a, #b) do if a[i] ~= b[i] then diff = diff + 1 end end
        return #a .. " pieces, " .. diff .. " moved"
    end
    local function stored(key)
        local p = MedalluinDB.profiles and MedalluinDB.profiles[ns.db.consoleProfile]
        local function s(t)
            if type(t) ~= "table" then return tostring(t) end
            local k = {}
            for piece, f in pairs(t) do
                local fs = {}
                for field, v in pairs(f) do fs[#fs + 1] = field .. "=" .. tostring(v) end
                table.sort(fs)
                k[#k + 1] = piece .. "{" .. table.concat(fs, ",") .. "}"
            end
            table.sort(k)
            return table.concat(k, " ")
        end
        return "profile=" .. s(p and p[key]) .. " global=" .. s(MedalluinDB.global and MedalluinDB.global[key])
    end
    local P, T = ns.units.player, ns.units.target

    -- untouched: the editor's apply moves nothing
    ns.SetOption("simParty", true)
    stateTick()
    local before = everything()
    E.ApplyAll()
    print("editor untouched", same(before, everything()))

    -- the level: on every frame, shown but on the raid and the arena; an
    -- enemy's coloured by difficulty, a friend's dim, a boss's "??" in red
    for _, frame in ipairs(E.FRAMES) do
        local list = frame.buttons()
        if not list[1] then print("level " .. frame.id, "no buttons") end
        for i = 1, frame.id == "unit" and 2 or math.min(1, #list) do
            local b = list[i]
            local r = E.PIECES.level.get(b)
            local c = r and r.textColor or {}
            print("level " .. frame.id, tostring(b.unit), "shown=" .. tostring(E.Shown(frame, "level")),
                r and ("text=" .. tostring(r.text) .. " colour=" .. table.concat({ n((c[1] or 0) * 100),
                    n((c[2] or 0) * 100), n((c[3] or 0) * 100) }, ",") .. " at=" .. pts(b, r)
                    .. " font=" .. fonts(r) .. " alpha=" .. n((r.alpha or 1) * 100)) or "none")
        end
    end
    piece("level target", T, "level")

    -- the window: its tabs, the pieces of the chosen frame
    ns.BuildEditor()
    ns.OpenEditor("unit")
    local w = MedalluinEditor
    local function window(tag)
        local t, r = {}, {}
        for _, b in ipairs(w.tabs) do t[#t + 1] = b.text.text end
        for _, row in ipairs(w.list.rows) do
            if row.shown then r[#r + 1] = row.text.text .. (row.mark.shown and "*" or "") .. (row.lit.shown and "<" or "") end
        end
        local c = {}
        for field, ctl in pairs(w.controls) do if ctl.shown then c[#c + 1] = field end end
        table.sort(c)
        print("editor window " .. tag, "shown=" .. tostring(w.shown), "tabs=" .. table.concat(t, ","),
            "pieces=" .. table.concat(r, ","), "controls=" .. table.concat(c, ","))
        print("  title=" .. tostring(w.body.title.text), "scope=" .. tostring(w.body.scope.text))
    end
    window("unit")
    local function choose(id, which)
        for _, b in ipairs(w.tabs) do if b.frame.id == id then b.scripts.OnClick(b) end end
        for _, row in ipairs(w.list.rows) do
            if row.shown and row.piece == which then row.scripts.OnClick(row) end
        end
    end
    local function set(field, v) w.controls[field].spec.set(v) end
    local function get(field) return w.controls[field].spec.get() end

    -- a move of the name: the target's is the player's mirror
    piece("player before", P, "name")
    piece("target before", T, "name")
    choose("unit", "name")
    print("  seed", "on=" .. tostring(get("on")), "x=" .. tostring(get("x")), "y=" .. tostring(get("y")),
        "size=" .. tostring(get("size")), "outline=" .. tostring(get("outline")))
    set("x", 20)
    piece("player x20", P, "name")
    piece("target x20", T, "name")
    print("  stored", stored("editUnit"))
    set("y", -5)
    set("size", 16)
    set("outline", "thick")
    piece("player y-5 16 thick", P, "name")
    piece("target y-5 16 thick", T, "name")
    window("unit name edited")

    -- the anchor grid: the party's role, inner-top, mirrored across the wings
    choose("party", "role")
    window("party role")
    piece("party1 role before", ns.units.party1, "role")
    piece("party3 role before", ns.units.party3, "role")
    for _, c in ipairs(w.controls.anchor.cells) do
        if c.h == "inner" and c.v == "top" then c.scripts.OnClick(c) end
    end
    set("size", 20)
    for i = 1, 4 do piece("party" .. i .. " role inner-top 20", ns.units["party" .. i], "role") end
    print("  stored", stored("editParty"))

    -- Shown: a faded piece, and an aura's option
    choose("party", "status")
    set("shown", false)
    piece("party1 status hidden", ns.units.party1, "status")
    set("shown", true)
    piece("party1 status shown", ns.units.party1, "status")
    choose("party", "cc")
    local key = E.byId.party.shows.cc
    print("  cc shown", tostring(get("shown")), key .. "=" .. tostring(ns.db[key]))
    set("shown", not get("shown"))
    print("  cc toggled", tostring(get("shown")), key .. "=" .. tostring(ns.db[key]))
    set("shown", not get("shown"))
    choose("party", "value")
    print("  party value shown=" .. tostring(get("shown")))
    piece("party1 value default", ns.units.party1, "value")
    set("shown", true)
    piece("party1 value on", ns.units.party1, "value")

    -- formats
    choose("unit", "value")
    for _, f in ipairs({ "percent", "current", "both", "deficit" }) do
        set("format", f)
        print("  value " .. f, tostring(P.value.text), tostring(T.value.text))
    end
    choose("unit", "powerValue")
    for _, f in ipairs({ "both", "current", "percent" }) do
        set("format", f)
        print("  power " .. f, tostring(P.powerValue and P.powerValue.text))
    end
    choose("party", "name")
    set("format", "short")
    set("len", 4)
    for i = 1, 2 do ns.unitEvents.UNIT_NAME_UPDATE(ns.units["party" .. i]) end
    print("  party names short len4", tostring(ns.units.party1.name.text), tostring(ns.units.party2.name.text))
    set("len", 0)
    print("  len 0 stored", stored("editParty"))
    set("format", "full")
    ns.unitEvents.UNIT_NAME_UPDATE(ns.units.party1)
    print("  party name full", tostring(ns.units.party1.name.text))
    choose("unit", "name")
    set("format", "short")
    ns.unitEvents.UNIT_NAME_UPDATE(T)
    print("  target initials", tostring(T.name.text))
    set("len", 5)
    ns.unitEvents.UNIT_NAME_UPDATE(T)
    print("  target initials len5", tostring(T.name.text))
    set("format", E.NIL)
    set("len", 0)
    ns.unitEvents.UNIT_NAME_UPDATE(T)
    print("  target full again", tostring(T.name.text), stored("editUnit"))
    print("  cut", ns.CutName("Ähryméx", 3), ns.CutName("Bob", 10), tostring(ns.CutName(nil, 3)))
    if modern then print("  secret cut is whole", ns.CutName(secret(), 3) ~= nil and ns.IsSecret(ns.CutName(secret(), 3))) end

    -- a piece whose last field is cleared goes, and the frame is false again
    choose("boss", "name")
    set("len", 3)
    print("  boss len3", stored("editBoss"))
    set("len", 0)
    print("  boss len0", stored("editBoss"))

    -- cells
    for _, id in ipairs({ "raid", "boss", "arena", "partyWidget" }) do
        choose(id, "cell")
        local cw, ch = ns.CellSize(id)
        set("w", cw + 20)
        set("h", ch + 4)
        local b = E.byId[id].buttons()[1]
        print("  cell " .. id, cw .. "x" .. ch, "->", table.concat({ ns.CellSize(id) }, "x"),
            "button=" .. (b and n(b.w) .. "x" .. n(b.h) or "none"), "buttons=" .. #E.byId[id].buttons())
    end
    window("party widget cell")

    -- per profile, or shared
    print("editor storage", "unit " .. stored("editUnit"))
    print("  raid " .. stored("editRaid"))
    ns.SetOption("consoleProfile", ns.db.consoleProfile == "light" and "default" or "light")
    print("  other profile", "editUnit=" .. tostring(ns.db.editUnit), "editRaid=" .. tostring(ns.db.editRaid ~= false))
    piece("player other profile", P, "name")
    -- the other profile's party is unedited: the role's place is read off
    -- the button (still laid as at login: a console profile takes effect
    -- after a reload)
    choose("party", "role")
    print("  other profile role seed", "on=" .. tostring(get("on")), "x=" .. tostring(get("x")),
        "y=" .. tostring(get("y")), "anchor=" .. tostring(E.Seed(E.byId.party, "role").h) .. "-"
        .. tostring(E.Seed(E.byId.party, "role").v))
    ns.SetOption("consoleProfile", ns.db.consoleProfile == "light" and "default" or "light")
    piece("player back", P, "name")

    -- the party's layout: the widget's edits, the console's
    -- party2's buffs two to a line: its console copy is a right one, its
    -- cell a left one, so each place must snapshot the row afresh
    local wasEdits, wasWidgetEdits = ns.db.editParty, ns.db.editPartyWidget
    local function plus(was)
        local t = {}
        for k, v in pairs(type(was) == "table" and was or {}) do t[k] = v end
        t.buffs = { cols = 2 }
        return t
    end
    -- the console's crown moved and made bigger: in the widget, it is its
    -- own size in its own place (a stale snapshot would put it back on the
    -- console's corner)
    local console = plus(wasEdits)
    console.leader = { size = 22, h = "inner", v = "middle", x = 30, y = 0 }
    ns.SetOption("editParty", console)
    ns.SetOption("editPartyWidget", plus(wasWidgetEdits))
    local function buffs2(tag)
        local r = ns.units.party2.buffWidgets
        local p1, _, _, x1 = r[1]:GetPoint(1)
        local _, _, _, x2 = r[2]:GetPoint(1)
        print("  party2 buffs " .. tag, p1 .. "," .. x1, "second " .. x2)
    end
    ns.SetOption("partyLayout", "widget")
    buffs2("in widget")
    ns.OpenEditor()
    window("layout widget")
    choose("party", "name")
    print("  party scope", w.body.scope.text)
    choose("partyWidget", "cell")
    piece("party1 in widget", ns.units.party1, "role")
    piece("party1 in widget", ns.units.party1, "leader")
    -- then the widget's instead: on the console, its own
    ns.SetOption("editParty", plus(wasEdits))
    local widget = plus(wasWidgetEdits)
    widget.leader = { size = 18, h = "inner", v = "middle", x = 30, y = 0 }
    ns.SetOption("editPartyWidget", widget)
    piece("party1 in widget, its own edit", ns.units.party1, "leader")
    print("  party1 cell", n(ns.units.party1.w) .. "x" .. n(ns.units.party1.h), "buttons=" .. #E.byId.partyWidget.buttons())
    ns.SetOption("partyLayout", "console")
    ns.OpenEditor()
    window("layout console")
    piece("party1 on console", ns.units.party1, "role")
    piece("party1 on console", ns.units.party1, "leader")
    buffs2("on console")
    ns.SetOption("editParty", wasEdits)
    ns.SetOption("editPartyWidget", wasWidgetEdits)

    -- edit mode: the canvas window, beside the editor
    choose("unit", "name")
    w.editMode.scripts.OnClick(w.editMode)
    local cv = MedalluinEditCanvas
    local function canvas(tag)
        local rows = {}
        for _, row in ipairs(cv.tree.rows) do
            if row.shown then
                rows[#rows + 1] = row.text.text .. (row.lit.shown and "<" or "") .. (row.mark.shown and "*" or "")
            end
        end
        local k, chosen, copies = 0, 0, 0
        for _, o in ipairs(cv.boxes) do
            if o.shown then k = k + 1; if o.label.text ~= "" then chosen = chosen + 1 end end
        end
        for _, p in ipairs(cv.proxies) do if p.shown then copies = copies + 1 end end
        print("canvas " .. tag, "shown=" .. tostring(cv.shown), "editor button=" .. tostring(w.editMode.text.text),
            "keys=" .. tostring(cv.keyboard), "copies=" .. copies, "scale=" .. string.format("%.2f", cv.holder.scale or 1),
            k .. " boxes, " .. chosen .. " labelled", "note=" .. tostring(cv.stage.note.shown and cv.stage.note.text))
        print("  title=" .. tostring(cv.stage.title.text), "tree=" .. table.concat(rows, ","))
    end
    canvas("unit")
    print("  placed", "TOPLEFT>editor=" .. tostring(cv.points.TOPLEFT and cv.points.TOPLEFT[1] == w))
    -- each copy is its button, read off it: the same points, the same words
    for k, p in ipairs(cv.proxies) do
        if p.shown then
            local real = p.button
            print("  copy " .. k, "of " .. tostring(real.unit), "side=" .. p.side,
                "name " .. pts(p, p.pieces.name):gsub("other", "?") .. " / real " .. pts(real, real.name),
                "words=" .. tostring(p.pieces.name.text), "font=" .. fonts(p.pieces.name),
                "width=" .. n(p.pieces.name.w) .. "/real " .. n(real.name.w),
                "wrap=" .. tostring(p.pieces.name:CanWordWrap()) .. "/real " .. tostring(real.name:CanWordWrap()),
                "height=" .. n(p.pieces.name.h) .. "/real " .. n(real.name:GetHeight()))
        end
    end
    -- only the chosen piece is boxed; another is chosen in the tree
    local function boxed()
        local o = {}
        for _, b in ipairs(cv.boxes) do
            if b.shown then
                -- and what it is round: the copy's region for that piece
                local on, copy = b.points.TOPLEFT[1], cv.proxies[b.copy]
                local what = "?"
                for id, r in pairs(copy.pieces) do if r == on then what = id end end
                o[#o + 1] = b.piece .. "@" .. b.side .. " round " .. what
            end
        end
        return table.concat(o, ",")
    end
    print("  boxed", boxed())
    for _, row in ipairs(cv.tree.rows) do
        if row.shown and row.piece == "value" then row.scripts.OnClick(row) end
    end
    print("  boxed after the tree", boxed())
    -- drag the target's copy of the value: the editor's place, every button
    local o
    for _, b in ipairs(cv.boxes) do if b.shown and b.piece == "value" and b.side == 1 then o = b; break end end
    local scale = o:GetEffectiveScale()
    local cursorX, cursorY = 100, 100
    local realCursor = GetCursorPosition
    function GetCursorPosition() return cursorX, cursorY end
    o.scripts.OnMouseDown(o)
    cursorX, cursorY = 100 + 10 * scale, 100 + 3 * scale
    o.scripts.OnUpdate(o)
    o.scripts.OnMouseUp(o)
    GetCursorPosition = realCursor
    print("  dragged value 10,3 frame pixels", stored("editUnit"))
    piece("target value dragged", T, "value")
    for k, p in ipairs(cv.proxies) do
        if p.shown then
            print("  copy " .. k .. " value", pts(p, p.pieces.value), "words=" .. tostring(p.pieces.value.text),
                "alpha=" .. tostring(p.pieces.value.alpha), "cc alpha=" .. tostring(p.pieces.cc.alpha))
        end
    end
    canvas("dragged")
    window("dragged")
    cv.scripts.OnKeyDown(cv, "LEFT")
    cv.scripts.OnKeyDown(cv, "UP")
    print("  nudged", stored("editUnit"), "propagate=" .. tostring(cv.propagate))
    cv.scripts.OnKeyDown(cv, "A")
    print("  other key propagate=" .. tostring(cv.propagate))
    -- the tree: a frame's head opens it, a piece chooses it, in the editor too
    for _, row in ipairs(cv.tree.rows) do
        if row.shown and not row.piece and row.frame.id == "raid" then row.scripts.OnClick(row) end
    end
    canvas("raid")
    for _, row in ipairs(cv.tree.rows) do
        if row.shown and row.piece == "cc" then row.scripts.OnClick(row) end
    end
    canvas("raid cc")
    window("raid cc from the tree")
    set("shown", false)
    print("  raid cc off", "copy alpha=" .. tostring(cv.proxies[1].pieces.cc.alpha), ns.db.raidCC)
    set("shown", true)
    print("  raid cc on", "copy alpha=" .. tostring(cv.proxies[1].pieces.cc.alpha), ns.db.raidCC)
    for _, row in ipairs(cv.tree.rows) do
        if row.shown and not row.piece and row.frame.id == "partyWidget" then row.scripts.OnClick(row) end
    end
    canvas("party widget, layout console")
    for _, row in ipairs(cv.tree.rows) do
        if row.shown and not row.piece and row.frame.id == "party" then row.scripts.OnClick(row) end
    end
    canvas("party")
    -- a fight hands the keys back, and the canvas stays
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    canvas("combat")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    canvas("combat over")
    -- the editor closing closes it
    w:Hide()
    w.scripts.OnHide(w)
    print("  editor closed", "canvas shown=" .. tostring(cv.shown))
    if cv.scripts.OnHide then cv.scripts.OnHide(cv) end
    ns.OpenEditor("unit")
    w.editMode.scripts.OnClick(w.editMode)
    -- dragged somewhere, it opens there again
    cv:ClearAllPoints()
    cv:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -50)
    cv.scripts.OnDragStop(cv)
    cv:Hide()
    cv.scripts.OnHide(cv)
    print("  canvas closed", "editor button=" .. tostring(w.editMode.text.text),
        "saved=" .. table.concat(ns.db.editCanvasPoint or {}, ","))
    w.editMode.scripts.OnClick(w.editMode)
    local p, rel = cv:GetPoint()
    print("  reopened", tostring(p), rel == UIParent and "UIParent" or "editor")
    cv:Hide()
    cv.scripts.OnHide(cv)
    ns.SetOption("editCanvasPoint", false)

    -- a row: its own way and length, then Grow, Columns and Most icons;
    -- the rest of its icons hang from the first
    local function row(tag, b, id)
        local got = E.PIECES[id].get(b)
        local o, shown = {}, 0
        for k, r in ipairs(got) do
            if k > 1 and k <= 5 then o[#o + 1] = k .. ":" .. (pts(b, r):gsub("^CENTER>.-%.CENTER,", "")) end
            if r.shown then shown = shown + 1 end
        end
        print("  " .. tag, id, "max=" .. ns.RowMax(b, id), "shown=" .. shown, "first=" .. pts(b, got[1]),
            table.concat(o, " "))
    end
    local function labels()
        local o = {}
        for _, c in ipairs(w.controls.grow.spec.choices) do o[#o + 1] = c[1] .. "=" .. c[2] end
        return table.concat(o, ",")
    end
    choose("unit", "buffs")
    print("editor row unit", "grow=" .. tostring(get("grow")), "cols=" .. tostring(get("cols")),
        "max=" .. tostring(get("max")), labels())
    row("player own", P, "buffs")
    row("target own", T, "buffs")
    set("max", 6)
    set("grow", "up")
    set("cols", 2)
    row("player up, 2 columns", P, "buffs")
    row("target up, 2 columns", T, "buffs")
    set("grow", "inner")
    set("size", 20)
    row("player inward, 2, size 20", P, "buffs")
    row("target inward, 2, size 20", T, "buffs")
    set("grow", "outer")
    row("target outward, 2", T, "buffs")
    set("cols", 10)
    print("  one line", stored("editUnit"))
    set("max", 2)
    row("player most 2", P, "buffs")
    row("target most 2", T, "buffs")
    ns.ShowEditCanvas(true)
    local copies = {}
    for _, p in ipairs(cv.proxies) do
        if p.shown and p.pieces.buffs then
            local k = 0
            for _, r in ipairs(p.pieces.buffs) do if r.shown then k = k + 1 end end
            copies[#copies + 1] = k
        end
    end
    print("  canvas row copies", table.concat(copies, ","))
    ns.ShowEditCanvas(false)
    local boss = E.byId.boss.buttons()[1]
    choose("boss", "mine")
    print("editor row boss", "grow=" .. tostring(get("grow")), "max=" .. tostring(get("max")), labels())
    row("boss own", boss, "mine")
    set("grow", "down")
    set("max", 5)
    row("boss down", boss, "mine")
    set("grow", "outer")
    set("cols", 2)
    row("boss left, 2", boss, "mine")

    -- reset
    choose("unit", "name")
    w.controls.reset.scripts.OnClick(w.controls.reset)
    piece("player name reset", P, "name")
    piece("target name reset", T, "name")
    print("  stored", stored("editUnit"))
    w.reset.scripts.OnClick(w.reset)
    print("  frame reset", stored("editUnit"))
    for _, frame in ipairs(E.FRAMES) do E.ResetFrame(frame) end
    stateTick()
    local after = everything()
    print("editor all reset", same(before, after))
    for i = 1, #before do if before[i] ~= after[i] then print("  moved", before[i], "->", after[i]) end end
    -- a first touch in a group: the name's point on the value (a text whose
    -- size the modern client keeps secret) cannot be read; the canvas copies
    -- the rest, and Reset gives back what the game lets it
    ns.OpenEditor("unit")
    choose("unit", "name")
    w.editMode.scripts.OnClick(w.editMode)
    P.editShots, P.editDone, T.editShots, T.editDone = nil, nil, nil, nil
    E.ApplyAll()
    for k, p in ipairs(cv.proxies) do
        if p.shown then print("editor untouched copy " .. k .. " name", pts(p, p.pieces.name)) end
    end
    set("x", 12)
    piece("player name first touch", P, "name")
    w.controls.reset.scripts.OnClick(w.controls.reset)
    piece("player name reset", P, "name")
    cv:Hide()
    cv.scripts.OnHide(cv)

    -- the footer's Preview is simulate.lua's; the slash word opens the window
    local was = ns.db.simParty
    w.preview.scripts.OnClick(w.preview)
    print("editor preview", tostring(was) .. "->" .. tostring(ns.db.simParty), w.preview.text.text)
    w.preview.scripts.OnClick(w.preview)
    w:Hide()
    w.scripts.OnHide(w)
    SlashCmdList.MDLUI("edit")
    print("editor /mdlui edit", "shown=" .. tostring(w.shown), "title=" .. tostring(w.body.title.text))
    w:Hide()
    w.scripts.OnHide(w)
end

-- Console > Minimap (`minimap`, or `light minimap`): see minimapPass
function MinimapPass()
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local bezel = _G.MedalluinMinimapBezel
    local function set(k, v) page.settings[k]:Set(v) end
    -- the frame the map sits in, the shape shown, clipping what is on it
    local function clip()
        local c = _G.MedalluinMinimapClip
        if not c then return "clip=none" end
        local p = c.points.CENTER
        return string.format("clip=%.0fx%.0f clips=%s parent=%s on=%s", c.w, c.h, tostring(c.clipsChildren),
            tostring(Minimap.parent == c), tostring(p and p[1] == Minimap))
    end
    -- the square map drops the round map's edge rings; the round one keeps them
    print("minimap blob rings", ns.layout.minimap and ns.layout.minimap.square and "square" or "round", BlobRing())
    local function greyed()
        ns.OpenOptions("console/minimap")
        local out = {}
        for _, key in ipairs({ "MEDALLUIN_MINIMAP", "minimapStart", "minimapAuto", "minimapAutoCombat",
            "minimapScale", "minimapAreaTime" }) do
            local c = ns.optionControls[key]
            -- a slider is greyed through its - and + buttons, a choice through its box
            local hit = c.box or c.less or c.button or c
            table.insert(out, key .. "=" .. (hit:IsEnabled() and "on" or "grey"))
        end
        ns.CloseOptions()
        return table.concat(out, " ")
    end
    -- the area at the shown map's top left: shown with the pointer on the
    -- map, kept over a pin, renamed by a zone event, gone off the shape
    local function area()
        local a, c = _G.MedalluinMinimapArea, _G.MedalluinMinimapClip
        local text, well, trim = a.all_[#a.all_], 0, 0
        for _, t in ipairs(a.all_) do
            if t.layer == "BACKGROUND" then well = t.color end
            if t.layer == "BORDER" then trim = trim + 1 end
        end
        local top = Minimap.level
        for _, f in ipairs({ Minimap:GetChildren() }) do
            if f ~= a then top = math.max(top, f.level) end
        end
        local function show(tag)
            local at, p = next(a.points)
            print("minimap area " .. tag, "shown=" .. tostring(a.shown), "alpha=" .. tostring(a.alpha),
                "text=" .. tostring(text.text),
                string.format("size=%.0fx%.0f at=%s%+.0f,%+.0f of clip=%s text=%.0f/%.0f wide", a.w, a.h, at, p[3], p[4],
                    tostring(p[1] == c), text.w, c.w), "above the pins=" .. tostring(top < a.level))
        end
        show("at rest")
        mouseOver = c
        Minimap.scripts.OnEnter(Minimap)
        print("minimap area look", string.format("well=%.3f,%.3f,%.3f,%.2f trim=%d size=%s", well[1], well[2], well[3],
            well[4], trim, tostring(select(2, text:GetFont()))))
        show("hovered")
        -- it comes over half a second
        a.scripts.OnUpdate(a, 0.25)
        show("0.25s")
        a.scripts.OnUpdate(a, 0.35)
        show("0.6s")
        -- a pin takes the pointer and gives it back: the same visit
        Minimap.scripts.OnEnter(Minimap)
        show("back from a pin")
        subzone = "The Sanctuary of Shadows and the Very Long Name of a Den"
        fire("ZONE_CHANGED")
        show("zone changed")
        -- its time (3s by default), then a second's fade, then nothing
        -- until the pointer leaves, whatever pins it crosses
        a.scripts.OnUpdate(a, 2.3)
        show("2.9s")
        a.scripts.OnUpdate(a, 0.6)
        show("3.5s")
        a.scripts.OnUpdate(a, 0.6)
        show("4.1s")
        Minimap.scripts.OnEnter(Minimap)
        a.scripts.OnUpdate(a, 0.1)
        show("4.2s, back from a pin")
        mouseOver = false
        a.scripts.OnUpdate(a, 0.1)
        show("left")
        -- a new visit; left halfway, it goes over a second
        mouseOver = c
        Minimap.scripts.OnEnter(Minimap)
        a.scripts.OnUpdate(a, 0.5)
        show("entered again, 0.5s")
        mouseOver = false
        a.scripts.OnUpdate(a, 0.5)
        show("left, 0.5s")
        -- back while it goes: a new visit, coming again
        mouseOver = c
        a.scripts.OnUpdate(a, 0.1)
        show("back while it goes")
        set("minimapAreaTime", 0)
        a.scripts.OnUpdate(a, 100)
        show("Always, 100s")
        set("minimapAreaTime", 3)
        mouseOver = false
        a.scripts.OnUpdate(a, 1)
        show("left, 1s")
        subzone = "Illidari Training Grounds"
    end
    area()
    if not bezel then
        -- the Medallion: nothing moves, the page says so, the key says so
        print("minimap medallion", "moves=" .. tostring(ns.MinimapMoves()), "corner=" .. tostring(ns.MinimapInCorner()),
            "page " .. greyed())
        print("minimap shape medallion", string.format("map=%.0fx%.0f mask=%s hit insets=%s", Minimap.w, Minimap.h,
            tostring(Minimap.mask):match("[^\\]+$"), table.concat(Minimap.hitInsets or {}, ",")), clip())
        ns.ToggleMinimap()
        print("minimap medallion key", "corner=" .. tostring(ns.MinimapInCorner()), "pin=" .. tostring(ns.MinimapPinned()))
    else
        -- how many grid buttons take the pointer, and whether any was set
        -- during the lockdown (blocked on a protected button)
        local function gridMouse()
            local n, locked = 0, false
            for _, b in ipairs(ns.bar7Buttons) do
                if b:IsMouseEnabled() then n = n + 1 end
                locked = locked or b.mouseInCombat == true
            end
            return n .. "/" .. #ns.bar7Buttons .. (locked and " SET IN LOCKDOWN" or "")
        end
        local function where(tag)
            print("minimap " .. tag, "corner=" .. tostring(Minimap.points.CENTER[1] == bezel),
                "bezel=" .. tostring(bezel.shown), "grid=" .. tostring(ns.bar7Frame.alpha),
                "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"), "pin=" .. tostring(ns.MinimapPinned()),
                "grid mouse=" .. gridMouse())
        end
        -- the load's place (Console > Minimap: When the game loads) is let
        -- go: the harness logs in with a target, which has cleared by now
        where("load place " .. tostring(ns.db.minimapStart) .. ", target gone")
        inCombat, hasTarget = false, false
        fire("PLAYER_REGEN_ENABLED")
        fire("PLAYER_TARGET_CHANGED")
        ns.skyridingWatch.scripts.OnAttributeChanged(ns.skyridingWatch, "state-skyriding", "off")
        where("explore")
        -- the map is square wherever it shows; its crop is the place's shape
        local function shape(tag)
            local i = Minimap.hitInsets or {}
            local _, _, _, x, y = Minimap:GetPoint()
            print("minimap shape " .. tag, string.format("map=%.0fx%.0f mask=%s hit insets=%s,%s,%s,%s at=%.0f,%.0f",
                Minimap.w, Minimap.h, tostring(Minimap.mask):match("[^\\]+$"), tostring(i[1]), tostring(i[2]),
                tostring(i[3]), tostring(i[4]), x, y), clip())
        end
        shape("in the bay")
        hasTarget = true
        fire("PLAYER_TARGET_CHANGED")
        where("target")
        shape("in the corner")
        set("minimapAutoTarget", false)
        where("target, not ticked")
        set("minimapAutoTarget", true)
        set("minimapAuto", false)
        where("target, not automatic")
        print("minimap page, not automatic", greyed())
        set("minimapAuto", true)
        print("minimap page", greyed())
        inCombat = true
        fire("PLAYER_REGEN_DISABLED")
        set("minimapAutoCombat", false)
        where("combat and target, combat not ticked")
        set("minimapAutoTarget", false)
        where("combat and target, neither ticked")
        set("minimapAutoCombat", true)
        set("minimapAutoTarget", true)
        ns.skyridingWatch.scripts.OnAttributeChanged(ns.skyridingWatch, "state-skyriding", "on")
        inCombat, hasTarget = false, false
        fire("PLAYER_REGEN_ENABLED")
        fire("PLAYER_TARGET_CHANGED")
        where("skyriding")
        set("minimapAutoSkyriding", false)
        where("skyriding, not ticked")
        set("minimapAutoSkyriding", true)
        ns.skyridingWatch.scripts.OnAttributeChanged(ns.skyridingWatch, "state-skyriding", "off")

        -- the key: back where the game loads it when it is not there (As it
        -- moves: where rule 3 puts it, no pin); there, pinned in the other
        -- place, through every trigger
        MedalluinToggleMinimap()
        where("key (from the binding), away from the load's place")
        hasTarget, inCombat = true, true
        fire("PLAYER_TARGET_CHANGED")
        fire("PLAYER_REGEN_DISABLED")
        where("pinned, combat and target")
        ns.ToggleMinimap()
        where("key again, at the load's place")
        inCombat, hasTarget = false, false
        fire("PLAYER_REGEN_ENABLED")
        fire("PLAYER_TARGET_CHANGED")
        where("pinned, out of combat")
        -- a party row wins over a pin: it needs the bay's foot
        local realRow = ns.PartyRowShown
        ns.PartyRowShown = function() return true end
        ns.UpdateMinimapLocation()
        where("pinned, party row")
        ns.PartyRowShown = realRow
        ns.ToggleMinimap()
        where("key, the row gone")
        ns.ToggleMinimap()
        where("key, back")
        -- the grid's buttons take the pointer only while it shows. Combat's
        -- own move comes at PLAYER_REGEN_DISABLED, before the lockdown, so
        -- it is made at once; one asked in combat waits for its end
        fire("PLAYER_REGEN_DISABLED")
        inCombat = true
        where("grid, combat begins")
        ns.ToggleMinimap()
        where("grid, key in combat")
        inCombat = false
        fire("PLAYER_REGEN_ENABLED")
        where("grid, combat over, still pinned")
        ns.ToggleMinimap()
        where("grid, key out of combat")

        -- size and place, in the corner; the console's scale leaves them be
        if not ns.MinimapInCorner() then ns.ToggleMinimap() end
        local function corner(tag)
            local _, _, rp, x, y = bezel:GetPoint()
            print("minimap corner " .. tag, string.format("%s %d,%d size=%d onScreen=%.3f map=%.1f mapOnScreen=%.1f",
                rp, x, y, bezel.w, bezel:GetEffectiveScale(), Minimap.w, Minimap.w * Minimap:GetEffectiveScale()))
        end
        corner("drawn")
        set("minimapScale", 1.5)
        set("minimapX", -100)
        set("minimapY", -50)
        corner("size 150%, 100 left, 50 down")
        set("consoleScale", 1.2)
        corner("console at 120%")
        set("consoleScale", 1)
        local reset = MedalluinMoverPopup
        EventRegistry:TriggerEvent("EditMode.Enter")
        print("minimap mover", "shown=" .. tostring(ns.consoleMovers.minimap and ns.consoleMovers.minimap.shown),
            "over the corner=" .. tostring(ns.consoleMovers.minimap and ns.consoleMovers.minimap.all == bezel))
        EventRegistry:TriggerEvent("EditMode.Exit")
        ns.ResetConsolePlace("minimap")
        corner("reset")

        -- the grip: a widget's tab on the corner's top edge, the area's name
        -- on it, no wider than the corner; a drag moves the corner, as its
        -- mover does
        local grip = ns.minimapGrip
        local function gripLine(tag)
            local p, rel, rp, x, y = grip:GetPoint()
            print("minimap grip " .. tag, "visible=" .. tostring(grip:IsVisible()), "alpha=" .. tostring(grip.alpha),
                "text=" .. tostring(grip.label.text), string.format("w=%.0f of %.0f label=%.0f", grip.w, bezel.w,
                    grip.label.w or 0), string.format("%s>%s of bezel=%s %+.0f,%+.0f", p, rp, tostring(rel == bezel),
                    x, y))
        end
        gripLine("in the corner")
        local wasZone = subzone
        subzone = "The Sanctuary of Shadows and the Very Long Name of a Den"
        fire("ZONE_CHANGED")
        gripLine("long name")
        subzone = "Dalaran"
        fire("ZONE_CHANGED_NEW_AREA")
        gripLine("short name")
        local us = UIParent:GetEffectiveScale() / ((ns.layout.designHeight or 1080) / UIParent:GetHeight())
        local cursorX, cursorY = 500, 500
        local realCursor = GetCursorPosition
        function GetCursorPosition() return cursorX, cursorY end
        grip.scripts.OnMouseDown(grip, "LeftButton")
        cursorX, cursorY = 500 + 2 * us, 500
        grip.scripts.OnUpdate(grip, 0.01)
        print("minimap grip nudged 2", "x=" .. tostring(ns.db.minimapX), "y=" .. tostring(ns.db.minimapY))
        cursorX, cursorY = 500 - 60 * us, 500 - 30 * us
        grip.scripts.OnUpdate(grip, 0.01)
        set("minimapMoverHover", true)
        mouseOver = false
        ns.UpdateWidgetMovers()
        gripLine("dragging, on mouseover, pointer away")
        grip.scripts.OnMouseUp(grip, "LeftButton")
        GetCursorPosition = realCursor
        print("minimap grip dragged 60 left, 30 down", "x=" .. tostring(ns.db.minimapX),
            "y=" .. tostring(ns.db.minimapY))
        corner("grip dragged")
        ns.UpdateWidgetMovers()
        gripLine("on mouseover, pointer away")
        mouseOver = bezel                   -- the map, in the corner's square
        ns.UpdateWidgetMovers()
        gripLine("on mouseover, pointer on the map")
        mouseOver = grip
        ns.UpdateWidgetMovers()
        gripLine("on mouseover, pointer on it")
        -- the console's hover label is the bay's: not over the corner
        mouseOver = _G.MedalluinMinimapClip
        Minimap.scripts.OnEnter(Minimap)
        print("minimap grip, area in the corner", "shown=" .. tostring(_G.MedalluinMinimapArea.shown))
        mouseOver = false
        ns.UpdateWidgetMovers()
        set("minimapMoverHover", false)
        ns.ResetConsolePlace("minimap")
        gripLine("mouseover off")
        subzone = wasZone
        ns.ToggleMinimap()
        gripLine("in the bay")
        -- the bay's label, showing when the key takes the map to the corner
        mouseOver = _G.MedalluinMinimapClip
        Minimap.scripts.OnEnter(Minimap)
        local inBay = _G.MedalluinMinimapArea.shown
        ns.ToggleMinimap()
        print("minimap grip, the key takes the hovered map to the corner", "area in the bay=" .. tostring(inBay),
            "then=" .. tostring(_G.MedalluinMinimapArea.shown))
        mouseOver = false
        ns.ToggleMinimap()

        -- the page's key control binds the key, and unbinds it
        ns.OpenOptions("console/minimap")
        local key = ns.optionControls.MEDALLUIN_MINIMAP
        local box = key.box
        box.scripts.OnClick(box, "LeftButton")
        local listening = box.text.text
        modsDown.SHIFT = true
        box.scripts.OnKeyDown(box, "LSHIFT")
        local afterModifier = box.text.text
        box.scripts.OnKeyDown(box, "M")
        modsDown.SHIFT = nil
        print("minimap key bound", "listening=" .. listening, "after a modifier=" .. afterModifier,
            "shows=" .. box.text.text, "binding=" .. tostring((GetBindingKey("MEDALLUIN_MINIMAP"))))
        box.scripts.OnClick(box, "LeftButton")
        box.scripts.OnKeyDown(box, "ESCAPE")
        print("minimap key escape", "shows=" .. box.text.text, "binding=" .. tostring((GetBindingKey("MEDALLUIN_MINIMAP"))))
        box.scripts.OnClick(box, "RightButton")
        print("minimap key unbound", "shows=" .. box.text.text, "binding=" .. tostring((GetBindingKey("MEDALLUIN_MINIMAP"))))
        ns.CloseOptions()
    end
    print("minimap saved", "light=" .. tostring(MedalluinDB.profiles.light.minimapScale),
        "default=" .. tostring(MedalluinDB.profiles.default.minimapScale), "window stale=" .. optionsStale())
end

-- Time enough for every fade under way to end (console/fade.lua).
function settleFades()
    for _ = 1, 400 do
        local moving = false
        for _, f in ipairs({ ns.consoleFader, ns.overheadFader }) do
            if f and f:Moving() then
                moving = true
                f.driver.scripts.OnUpdate(f.driver, 0.05)
            end
        end
        if not moving then return end
    end
end

-- The console's fading (Console > General > Visibility, Opacity) and the
-- overhead's (Console > Overhead > Opacity): console/fade.lua.
function FadePass()
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local function set(k, v) page.settings[k]:Set(v) end
    local con, cf, top, of = ns.console, ns.consoleFader, ns.overhead, ns.overheadFader
    -- time passing: the watch looks, the faders step, 0.05s at a time
    local function run(sec)
        for _ = 1, math.floor(sec / 0.05 + 0.5) do
            ns.consoleFadeWatch.scripts.OnUpdate(ns.consoleFadeWatch, 0.05)
            for _, d in ipairs({ cf.driver, of.driver }) do
                if d.shown then d.scripts.OnUpdate(d, 0.05) end
            end
        end
    end
    local function say(tag)
        print("fade console " .. tag, string.format("alpha=%.2f", con:GetAlpha()),
            "wanted=" .. tostring(ns.ConsoleWanted()))
    end
    local health = 100
    local realHealth, realMax = UnitHealth, UnitHealthMax
    UnitHealth, UnitHealthMax = function() return health end, function() return 100 end
    local wasGrouped = grouped
    inCombat, hasTarget, grouped, mouseOver, cursor = false, false, false, false, nil
    fire("PLAYER_REGEN_ENABLED")
    fire("PLAYER_TARGET_CHANGED")

    say("not fading")
    set("consoleAlpha", 0.5)
    say("opacity 50%")
    set("consoleFade", true)
    say("fading, idle")
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    run(0.1)
    say("combat, 0.1s of a 0.2s fade in")
    run(0.1)
    say("combat, 0.2s")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    run(0.3)
    say("out of combat, 0.3s of a 0.6s fade out")
    run(0.3)
    say("out of combat, 0.6s")
    set("consoleFadeOut", 0)
    set("consoleFadeIn", 0)

    -- each tick, and with it unticked
    local function tick(tag, key, on, off)
        on()
        local yes = ns.ConsoleWanted()
        set(key, false)
        local no = ns.ConsoleWanted()
        set(key, ns.OptionBase(key))
        off()
        print("fade tick " .. tag, "shows=" .. tostring(yes), "unticked=" .. tostring(no),
            "after=" .. tostring(ns.ConsoleWanted()))
    end
    tick("combat", "consoleShowCombat", function() inCombat = true; fire("PLAYER_REGEN_DISABLED") end,
        function() inCombat = false; fire("PLAYER_REGEN_ENABLED") end)
    tick("target", "consoleShowTarget", function() hasTarget = true end, function() hasTarget = false end)
    tick("hurt", "consoleShowHurt", function() health = 82 end, function() health = 100 end)
    tick("mouse over the console", "consoleShowMouse", function() mouseOver = con end,
        function() mouseOver = false end)
    tick("mouse over the bar", "consoleShowMouse", function() mouseOver = ns.actionBar end,
        function() mouseOver = false end)
    if ns.partyRowBand then
        -- the row hangs under the console while there is a party
        grouped = true
        fire("GROUP_ROSTER_UPDATE")
        set("consoleShowGroup", false)
        tick("mouse over the party row", "consoleShowMouse", function() mouseOver = ns.partyRowBand end,
            function() mouseOver = false end)
        print("fade party row shown=" .. tostring(ns.partyRowBand:IsVisible()))
        grouped = false
        fire("GROUP_ROSTER_UPDATE")
    end
    grouped = true
    print("fade tick group, not ticked", "shows=" .. tostring(ns.ConsoleWanted()))
    set("consoleShowGroup", true)
    print("fade tick group, ticked", "shows=" .. tostring(ns.ConsoleWanted()))
    set("consoleShowGroup", false)
    grouped = false
    -- a secret health says nothing (only a client with secrets has them)
    if issecretvalue then
        health = 82
        UnitHealth, UnitHealthMax = secret, secret
        print("fade tick hurt, secret", "shows=" .. tostring(ns.ConsoleWanted()))
        health = 100
    end
    UnitHealth, UnitHealthMax = function() return health end, function() return 100 end

    -- what always wants it whole
    for _, case in ipairs({
        { "binding keys", function() ns.keybinding = true end, function() ns.keybinding = nil end },
        { "a spell on the pointer", function() cursor = "spell" end, function() cursor = nil end },
        { "Edit Mode", function() EventRegistry:TriggerEvent("EditMode.Enter") end,
            function() EventRegistry:TriggerEvent("EditMode.Exit") end },
        { "simulate party", function() set("simParty", true) end, function() set("simParty", false) end },
    }) do
        case[2]()
        run(0.1)
        local a = con:GetAlpha()
        case[3]()
        run(0.1)
        print("fade forced " .. case[1], string.format("alpha=%.2f after=%.2f", a, con:GetAlpha()))
    end
    set("consoleFadedAlpha", 0.3)
    say("faded opacity 30%")

    -- what keeps its own alpha
    local strips = {}
    for side, strip in pairs(ns.strips or {}) do
        table.insert(strips, tostring(side) .. "=" .. tostring(strip.ignoreParentAlpha))
    end
    table.sort(strips)
    print("fade own alpha", "strips " .. table.concat(strips, " "),
        "bezel=" .. tostring(ns.minimapBezel and ns.minimapBezel.ignoreParentAlpha),
        "minimap=" .. tostring(Minimap.ignoreParentAlpha),
        "corner=" .. tostring(ns.MinimapInCorner and ns.MinimapInCorner()))
    if ns.MinimapInCorner then
        hasTarget = true
        fire("PLAYER_TARGET_CHANGED")
        print("fade own alpha, minimap in the corner", "minimap=" .. tostring(Minimap.ignoreParentAlpha),
            "corner=" .. tostring(ns.MinimapInCorner()))
        hasTarget = false
        fire("PLAYER_TARGET_CHANGED")
    end
    for _, key in ipairs({ "consoleFade", "consoleAlpha", "consoleFadedAlpha", "consoleFadeIn", "consoleFadeOut" }) do
        set(key, ns.OptionBase(key))
    end
    say("back to the profile's")

    -- the overhead: it shows while it holds something, fading in and out
    local function over(tag)
        local decks = 0
        for _, r in ipairs(top.children or {}) do if r.shown then decks = decks + 1 end end
        print("fade overhead " .. tag, "shown=" .. tostring(top.shown), string.format("alpha=%.2f", top:GetAlpha()),
            "row=" .. #(ns.overheadRow or {}))
    end
    settleFades()
    over("empty")
    shapeshiftForms = 2
    fire("UPDATE_SHAPESHIFT_FORMS")
    over("stances, at once")
    run(0.1)
    over("stances, 0.1s of a 0.2s fade in")
    run(0.1)
    over("stances, 0.2s")
    shapeshiftForms = 0
    fire("UPDATE_SHAPESHIFT_FORMS")
    over("emptied, at once")
    run(0.1)
    over("emptied, 0.1s of a 0.2s fade out")
    shapeshiftForms = 2
    fire("UPDATE_SHAPESHIFT_FORMS")
    run(0.05)
    over("back before it went")
    run(0.15)
    over("back, settled")
    shapeshiftForms = 0
    fire("UPDATE_SHAPESHIFT_FORMS")
    run(0.25)
    over("emptied, gone")
    set("overheadAlpha", 0.4)
    set("overheadFadeOut", 0)
    shapeshiftForms = 2
    fire("UPDATE_SHAPESHIFT_FORMS")
    run(0.25)
    over("opacity 40%")
    shapeshiftForms = 0
    fire("UPDATE_SHAPESHIFT_FORMS")
    over("emptied, no fade out")
    -- back: from nothing, not from where it was when it went
    shapeshiftForms = 2
    fire("UPDATE_SHAPESHIFT_FORMS")
    over("back after going at once")
    run(0.25)
    shapeshiftForms = 0
    fire("UPDATE_SHAPESHIFT_FORMS")
    for _, key in ipairs({ "overheadAlpha", "overheadFadeIn", "overheadFadeOut" }) do
        set(key, ns.OptionBase(key))
    end

    UnitHealth, UnitHealthMax = realHealth, realMax
    grouped = wasGrouped
    print("fade window stale=" .. optionsStale())
end

if lightPass then
    UIParent.fixed = { -648, -904, 1272, 176 }
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    print("profile", ns.db.consoleProfile, string.format("console=%dx%d", ns.art.width, ns.art.height),
        "bar=" .. tostring(ns.barArt.file), "rows=" .. ns.db.rows)
    -- Initially hasTarget is true, so combat/target mode is active
    print("initial(targeted)", "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
        "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel),
        "bezelShown=" .. tostring(_G.MedalluinMinimapBezel.shown),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha),
        "bar7Buttons=" .. #ns.bar7Buttons,
        "bar7Slot1=" .. tostring(ns.bar7Buttons[1].action),
        "bar7Slot10=" .. tostring(ns.bar7Buttons[10].action),
        "stateDriver=" .. tostring(ns.bar7Frame.stateDrivers and ns.bar7Frame.stateDrivers.page))
    -- the load's place (Console > Minimap: When the game loads), then held
    -- through an event that leaves the triggers' answer as it was
    print("minimap load place", tostring(ns.db.minimapStart), "pin=" .. tostring(ns.MinimapPinned()),
        "corner=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel))
    if savedStart then
        fire("PLAYER_TARGET_CHANGED")
        print("minimap load place, target kept", "pin=" .. tostring(ns.MinimapPinned()),
            "corner=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel))
        -- the key, at the load's place, pins the other one: not let go when
        -- the target, which the load's place was held against, clears.
        -- Pressed again, it is back as the load left it, held until the
        -- triggers change their answer
        ns.ToggleMinimap()
        local keyed = ns.MinimapPinned()
        hasTarget = false
        fire("PLAYER_TARGET_CHANGED")
        print("minimap load place, key pressed then target gone", "pin " .. tostring(keyed) .. " -> "
            .. tostring(ns.MinimapPinned()))
        ns.ToggleMinimap()
        print("minimap load place, key again", "pin=" .. tostring(ns.MinimapPinned()),
            "corner=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel))
        hasTarget = true
        fire("PLAYER_TARGET_CHANGED")
        print("minimap load place, let go again with a target", "pin=" .. tostring(ns.MinimapPinned()))
    end
    print("bar7 buttons", ns.bar7Buttons[1]:GetName(), "parent=" .. tostring(ns.bar7Buttons[1].parent == ns.bar7Frame),
        "tainted=" .. tostring(ns.bar7Buttons[1].taintedBy), "key G=" .. tostring(bindings.G),
        "spare11=" .. tostring(_G.MultiBar6Button11 and _G.MultiBar6Button11.parent == ns.hidden),
        "bar=" .. tostring(_G.MultiBar6 and _G.MultiBar6.parent == ns.hidden))
    out("player.health", ns.units.player.health)
    out("player.power", ns.units.player.power)
    out("target.health", ns.units.target.health)
    out("target.power", ns.units.target.power)
    out("xp", ns.xpBar)
    out("rep", ns.repBar)
    out("ActionButton1", _G.ActionButton1, "level=" .. _G.ActionButton1.level)
    out("ActionButton12", _G.ActionButton12, "level=" .. _G.ActionButton12.level)
    out("MultiBarBottomLeftButton1", _G.MultiBarBottomLeftButton1, "level=" .. _G.MultiBarBottomLeftButton1.level)
    out("MultiBarBottomLeftButton6", _G.MultiBarBottomLeftButton6, "level=" .. _G.MultiBarBottomLeftButton6.level)
    out("MultiBarBottomRightButton1", _G.MultiBarBottomRightButton1, "level=" .. _G.MultiBarBottomRightButton1.level)
    out("MultiBarBottomRightButton6", _G.MultiBarBottomRightButton6, "level=" .. _G.MultiBarBottomRightButton6.level)
    out("grid button 1", ns.bar7Buttons[1], "level=" .. ns.bar7Buttons[1].level)
    out("grid button 10", ns.bar7Buttons[10], "level=" .. ns.bar7Buttons[10].level)
    out("barLow", ns.barPower)
    out("drawerToggle", ns.drawerToggle)
    -- Clear target out of combat -> exploration mode: square minimap in center bay
    hasTarget = false
    fire("PLAYER_TARGET_CHANGED")
    print("explore(no target, no combat)", "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
        "minimapInConsole=" .. tostring(Minimap.points.CENTER[1] == ns.console),
        "bezelShown=" .. tostring(_G.MedalluinMinimapBezel.shown),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    out("minimap(explore)", Minimap)
    -- Skyriding out of combat, no target: the grid comes out to fly on page
    -- 11, as the game's own conditional says, and goes back on landing
    local flight = ns.skyridingWatch
    local function sky(tag, value)
        flight.scripts.OnAttributeChanged(flight, "state-skyriding", value)
        print("skyriding " .. tag, "driver=" .. tostring(flight.stateDrivers and flight.stateDrivers.skyriding),
            "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
            "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel),
            "bezelShown=" .. tostring(_G.MedalluinMinimapBezel.shown),
            "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    end
    sky("mounted", "on")
    flight.scripts.OnAttributeChanged(flight, "state-page", "off")     -- another attribute: no answer
    print("skyriding other attribute", "skyriding=" .. tostring(ns.skyriding),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    sky("landed", "off")
    -- landing with a target keeps it out
    hasTarget = true
    sky("mounted, targeting", "on")
    sky("landed, targeting", "off")
    hasTarget = false
    fire("PLAYER_TARGET_CHANGED")
    -- Enter combat without target -> combat mode: minimap moves to TOPRIGHT bezel, bar7 revealed
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    print("combat(no target)", "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
        "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedalluinMinimapBezel),
        "bezelShown=" .. tostring(_G.MedalluinMinimapBezel.shown),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    out("minimap(combat)", Minimap)
    -- the combat aura: a glow round each piece shown, under all the art
    local function aura(tag)
        local on = {}
        for _, t in ipairs(ns.console.all_) do
            local file = t.kind == "Texture" and tostring(t.texture):match("console%-light%-aura%-(%w+)$")
            if file and t.shown then
                local p, vc = t.points.TOPLEFT, t.vertex or {}
                table.insert(on, string.format("%s@%d,%d %dx%d %s/%s %g,%g,%g@%.2f", file, p[3], p[4], t.w, t.h,
                    tostring(t.layer), tostring(t.sub), vc[1] or -1, vc[2] or -1, vc[3] or -1, vc[4] or -1))
            end
        end
        table.sort(on)
        print("aura " .. tag, #on > 0 and table.concat(on, "  ") or "none")
    end
    aura("combat")
    threatOf = 1
    fire("UNIT_THREAT_SITUATION_UPDATE", "player")
    aura("threat")
    threatOf = 0
    fire("UNIT_THREAT_SITUATION_UPDATE", "player")
    ns.actionBar:SetAlpha(0.5)
    aura("bar 1 half faded")
    ns.actionBar:SetAlpha(1)
    -- two rows: one wing, so one wing's glow
    local right = ns.barWingPlates[2]
    ns.barWingPlates[2] = nil
    ns.UpdateConsoleAura()
    aura("two rows")
    ns.barWingPlates[2] = right
    ns.UpdateConsoleAura()
    -- the minimap pinned to the bay in combat: the bay's glow is the minimap's
    ns.ToggleMinimap()
    aura("minimap pinned in the bay")
    -- back as the load left it (a load place's pin is let go at combat's end)
    if not savedStart or ns.MinimapPinned() ~= savedStart then ns.ToggleMinimap() end
    -- The game's update pages Bar 7: cat form (Bar 8, slots 85..94), then
    -- stealth in combat (Bar 10, slots 109..118); Medalluin's code never does
    stateTick()
    harnessHolds["bonusbar:1"] = true
    stateTick()
    print("bar7(cat form)", "slot1=" .. tostring(ns.bar7Buttons[1].action),
        "slot10=" .. tostring(ns.bar7Buttons[10].action))
    harnessHolds["bonusbar:1"] = nil
    harnessHolds.stealth = true
    inCombat = true
    stateTick()
    print("bar7(stealth in combat)", "slot1=" .. tostring(ns.bar7Buttons[1].action),
        "tainted=" .. tostring(ns.bar7Buttons[1].taintedBy))
    harnessHolds.stealth = nil
    stateTick()
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    aura("out of combat")
    -- the party frames: the row, which the retired "vertical" seed became
    print("party layout", "saved=" .. tostring(ns.db.partyLayout), "row=" .. tostring(ns.PartyRowLayout()))
    for i = 1, 4 do out("party" .. i, ns.units["party" .. i]) end
    partyLayoutMenu("light")
    -- the light profile's windows are rectangles: no glow traces a cut
    local cuts = {}
    for _, u in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
        local cut = ns.units[u].dispelGlow.cut
        table.insert(cuts, u .. "=" .. (cut and tostring(cut.shown) or "none"))
    end
    print("glow cuts", table.concat(cuts, " "))
    if keybindPass then KeybindPass() end
    if pagingPass then PagingPass() end
    if rowPass then RowPass() end
    if editorPass then EditorPass() end
    if minimapPass then MinimapPass() end
    if fadePass then FadePass() end
    do return end
end

for _, unit in ipairs({ "player", "target", "party1", "party2", "party3", "party4" }) do
    local b = ns.units[unit]
    if b and (UnitExists(unit) or b.stub) then
        out(unit .. ".health", b.health, string.format("fill=%s rev=%s text=%s", tostring(b.health.value),
            tostring(b.health.reverse), tostring(b.value and b.value.text)))
        out(unit .. ".power", b.power, string.format("fill=%s shown=%s text=%s", tostring(b.power.value),
            tostring(b.power.shown), tostring(b.powerValue and b.powerValue.text)))
        print(string.format("%s.name\t%s", unit, tostring(b.name.text)))
    end
end
out("minimap", Minimap)
print("secrets handed to widgets", secretsUsed)
if modern then
    -- stunned in combat: the loss of control's times are secret, so the
    -- player's CC mark takes its spiral from the aura's duration object;
    -- out of combat, from its times
    local cc = ns.units.player.ccWidget
    function Region:SetCooldownFromDurationObject(dur) self.start, self.duration = "object", dur.aura end
    local setCooldown = rawget(Region, "SetCooldown")
    function Region:SetCooldown(start, duration) self.start, self.duration = start, duration end
    local function stunned(tag)
        for _, f in ipairs(events.LOSS_OF_CONTROL_ADDED or {}) do f.scripts.OnEvent(f, "LOSS_OF_CONTROL_ADDED") end
        print(tag, "shown=" .. tostring(cc and cc.shown), "icon=" .. tostring(cc and cc.icon.texture),
            "spiral=" .. tostring(cc and cc.cooldown.start) .. "/" .. tostring(cc and cc.cooldown.duration),
            "expires=" .. tostring(cc and cc.expires))
    end
    C_UnitAuras.GetAuraDuration = function(_, id) return { aura = id } end
    lossOfControl = { iconTexture = 132091, startTime = 100, duration = 4, auraInstanceID = 77, priority = 5,
        displayType = 2 }
    stunned("cc stunned")
    lossOfControl = { iconTexture = secret(), startTime = secret(), duration = secret(), auraInstanceID = 77,
        priority = 5, displayType = 2 }
    stunned("cc stunned secret")
    C_UnitAuras.GetAuraDuration = nil
    stunned("cc stunned secret, no duration")
    lossOfControl = nil
    stunned("cc free")
    Region.SetCooldownFromDurationObject, Region.SetCooldown = nil, setCooldown
    local pBuffs = 0
    for _, btn in ipairs(ns.units.player.buffWidgets or {}) do if btn.shown then pBuffs = pBuffs + 1 end end
    print("player.buffs", pBuffs)
end
if savedSimParty then
    local p1 = ns.units.party1
    print("party1.glow", tostring(p1.dispelGlow and p1.dispelGlow.shown),
        "behindArt=" .. tostring(p1.dispelGlow.level < ns.levels.art))
    -- the medallion's party1 and unit windows are cut at 45 degrees; party2's is not
    print("glow cuts", "party1=" .. tostring(p1.dispelGlow.cut and p1.dispelGlow.cut.shown),
        "party3=" .. tostring(ns.units.party3.dispelGlow.cut and ns.units.party3.dispelGlow.cut.shown),
        "player=" .. tostring(ns.units.player.dispelGlow.cut and ns.units.player.dispelGlow.cut.shown))
    local p2 = ns.units.party2
    print("party2.cc", tostring(p2.ccWidget and p2.ccWidget.shown),
        tostring(p2.ccWidget and p2.ccWidget.timer and p2.ccWidget.timer.text))
    if p2.pet then
        print("party2.pet", tostring(p2.pet.shown), tostring(p2.pet.name and p2.pet.name.text),
            tostring(p2.pet.value and p2.pet.value.text))
    end
    local p3 = ns.units.party3
    local bCount = 0
    for _, btn in ipairs(p3.buffWidgets or {}) do if btn.shown then bCount = bCount + 1 end end
    print("party3.buffs", bCount)
    -- the editor's Most icons caps the row; the boss cells' row the same way
    ns.SetOption("editParty", { buffs = { max = 1 } })
    bCount = 0
    for _, btn in ipairs(p3.buffWidgets or {}) do if btn.shown then bCount = bCount + 1 end end
    print("party3.buffs most 1", bCount, "pool=" .. #p3.buffWidgets)
    ns.SetOption("editParty", false)
    bCount = 0
    for _, btn in ipairs(p3.buffWidgets or {}) do if btn.shown then bCount = bCount + 1 end end
    print("party3.buffs back", bCount)
    local p4 = ns.units.party4
    print("party4.boss", tostring(p4.bossDebuff and p4.bossDebuff.shown),
        tostring(p4.bossDebuff and p4.bossDebuff.timer and p4.bossDebuff.timer.text))

    -- 1. Role icons at bottom outer edges
    print("party1.role", tostring(p1.roleFrame and p1.roleFrame.shown),
        "overArt=" .. tostring(p1.roleFrame.level > ns.levels.art),
        "point=" .. tostring(p1.roleFrame.points.CENTER and p1.roleFrame.points.CENTER[2]))
    print("party3.role", tostring(p3.roleFrame and p3.roleFrame.shown), "TANK")

    -- 2. Dead: the look over the whole button, the wings, the time, the
    -- name; the button's own texts give way. The target has no look.
    local d = p1.dead
    local function dead(tag)
        local c = d.fill.color
        print(tag, "shown=" .. tostring(d.shown), "texts=" .. tostring(p1.text.alpha or 1),
            "name=" .. tostring(d.name.text), "timer=" .. tostring(d.timer.text),
            "wings=" .. tostring(d.wings.texture) .. "@" .. tostring(d.wings.w),
            "fill=" .. string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]),
            "over bars=" .. tostring((d.level or 0) > math.max(p1.health.level or 0, p1.power.level or 0)),
            "whole=" .. tostring(d.all == p1))
    end
    dead("party1.dead alive")
    p1.stub.dead = true
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    dead("party1.dead dead")
    now = now + 75
    ns.deadClock.scripts.OnUpdate(ns.deadClock, 1)
    dead("party1.dead 75s")
    now = now + 3600
    ns.deadClock.scripts.OnUpdate(ns.deadClock, 1)
    dead("party1.dead 1h")
    ns.SetOption("deadColor", "ff804020")
    dead("party1.dead recoloured")
    p1.stub.dead = false
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    dead("party1.dead revived")
    p1.stub.dead = true
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    dead("party1.dead again")
    p1.stub.name = "Party 1b"
    p1.scripts.OnEvent(p1, "UNIT_NAME_UPDATE")
    dead("party1.dead renamed")
    p1.stub.name = "Party 1"
    p1.scripts.OnEvent(p1, "UNIT_NAME_UPDATE")
    p1.stub.dead = false
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    p1.stub.offline = true
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    dead("party1.dead offline")
    p1.stub.offline = false
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    now = now - 3675
    ns.SetOption("deadColor", "ff40424a")
    -- a real unit: dead by the game, or offline; a button handed to
    -- another (alive) unit leaves the first one's time running
    local pb, rDead, rOn, rGuid = ns.units.player, UnitIsDeadOrGhost, UnitIsConnected, UnitGUID
    local guid, gone, off = "Player-A", true, false
    UnitIsDeadOrGhost = function(u) return u == "player" and gone end
    UnitIsConnected = function() return not off end
    UnitGUID = function() return guid end
    local function real(tag)
        pb.scripts.OnEvent(pb, "UNIT_HEALTH")
        print(tag, "shown=" .. tostring(pb.dead.shown), "state=" .. tostring(pb.dead.state),
            "timer=" .. tostring(pb.dead.timer.shown and pb.dead.timer.text or "-"))
    end
    real("player.dead real")
    now = now + 30
    guid, gone = "Player-B", false
    real("player.dead handed on")
    guid, gone = "Player-A", true
    real("player.dead handed back")
    off = true
    real("player.dead offline")
    now = now - 30
    UnitIsDeadOrGhost, UnitIsConnected, UnitGUID = rDead, rOn, rGuid
    pb.scripts.OnEvent(pb, "UNIT_HEALTH")
    print("target.dead", tostring(ns.units.target.dead), "player.dead", tostring(ns.units.player.dead ~= nil),
        "clock idle", tostring((function()
            ns.deadClock.scripts.OnUpdate(ns.deadClock, 1)
            return not ns.deadClock.shown
        end)()))

    -- 3. Range fade
    print("party3.range in", tostring(p3.alpha or 1))
    p3.stub.inRange = false
    ns.UpdatePartyRange()
    print("party3.range out", string.format("%.2f", p3.alpha))
    p3.stub.inRange = true
    ns.UpdatePartyRange()
    print("party3.range restored", tostring(p3.alpha or 1))

    -- 4. Ready check: hides buffs/debuffs, shows middle status
    for _, f in ipairs(events.READY_CHECK or {}) do f.scripts.OnEvent(f, "READY_CHECK") end
    local p3BuffsInCheck = 0
    for _, btn in ipairs(p3.buffWidgets or {}) do if btn.shown then p3BuffsInCheck = p3BuffsInCheck + 1 end end
    print("readyCheck.active", "party1.status=" .. tostring(p1.statusWidget and p1.statusWidget.shown),
        "p3Buffs=" .. p3BuffsInCheck, "p2CC=" .. tostring(p2.ccWidget.shown))
    for _, f in ipairs(events.READY_CHECK_CONFIRM or {}) do f.scripts.OnEvent(f, "READY_CHECK_CONFIRM", "party1", true) end
    for _, f in ipairs(events.READY_CHECK_CONFIRM or {}) do f.scripts.OnEvent(f, "READY_CHECK_CONFIRM", "party2", false) end
    for _, f in ipairs(events.READY_CHECK_FINISHED or {}) do f.scripts.OnEvent(f, "READY_CHECK_FINISHED") end
    for _, f in ipairs(events.PLAYER_REGEN_DISABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    local p3BuffsRestored = 0
    for _, btn in ipairs(p3.buffWidgets or {}) do if btn.shown then p3BuffsRestored = p3BuffsRestored + 1 end end
    print("readyCheck.cleared", "party1.status=" .. tostring(p1.statusWidget.shown),
        "p3Buffs=" .. p3BuffsRestored, "p2CC=" .. tostring(p2.ccWidget.shown))

    -- 5. The overhead: decks hung from the screen's top, cells, the command row
    -- (a druid-like player with three forms and a pet: the row is real buttons)
    shapeshiftForms, petBar = 3, true
    for i = 1, 10 do _G["PetActionButton" .. i].shown = true end
    ns.UpdateOverhead()
    local ovh = ns.overhead
    local A = ns.overheadArt
    local decks = ns.overheadDecks
    watchTick()
    -- in design pixels, from the overhead's top centre
    local function rel(f)
        local r, o = resolve(f), resolve(ovh)
        local k = scaleOf(ovh)
        local cx = (o[1] + o[3]) / 2
        return (r[1] - cx) / k, (r[2] - o[2]) / k, (r[3] - cx) / k, (r[4] - o[2]) / k
    end
    local function round(v) return math.floor(v + 0.5) end
    -- one anchor and no size is no rectangle in the game: nothing hung off it shows
    print("overhead.box", "w=" .. tostring(ovh.w), "h=" .. tostring(ovh.h), "shown=" .. tostring(ovh.shown))
    local heard = {}
    for _, u in ipairs({ "pet", "focus", "targettarget", "boss1", "boss5" }) do
        local b = ns.overheadUnits[u]
        table.insert(heard, u .. "=" .. tostring(b.unitOf and b.unitOf.UNIT_HEALTH))
    end
    print("overhead.hears", table.concat(heard, " "))
    local function deckState(tag)
        local out = {}
        for slot, d in ipairs(decks) do
            if d.shown then
                local l, t = rel(d.left)
                local r = select(3, rel(d.right))
                table.insert(out, string.format("%d:%s half=%s y=%s wings=%d..%d top=%d piece=%s", slot, d.kind,
                    tostring(d.half), tostring(d.y), round(l), round(r), round(t),
                    tostring(d.left.texture):match("[^\\]+$")))
            else
                table.insert(out, slot .. ":none")
            end
        end
        print(tag, table.concat(out, "  "))
    end
    deckState("overhead.decks")
    -- a lower deck repaints where it meets the one above, so it draws over it
    print("overhead.pieces", "lowerOver=" .. tostring(decks[3].left.sub > decks[2].left.sub
            and decks[2].left.sub > decks[1].left.sub),
        "rightMirrored=" .. tostring(decks[1].right.coords[1] > decks[1].right.coords[2]),
        "plateUnderCells=" .. tostring(decks[1].left.parent.level < ns.overheadUnits.boss1.level))
    -- every shown cell inside its deck's floor; the row centred on the line,
    -- each cell its own width however wide the deck (2026-11-02: stretched to
    -- the floor, a pet over a full pet bar ran under the ToT beside it)
    local function cellState(tag)
        for slot, d in ipairs(decks) do
            if d.shown and d.kind ~= "tray" then
                local h = A.deck[d.kind]
                local inside, lo, hi, n = true, 1e9, -1e9, 0
                for _, b in pairs(ns.overheadUnits) do
                    if b.shown and b.kind == d.kind then
                        local l, t, r, bt = rel(b)
                        n = n + 1
                        lo, hi = math.min(lo, l), math.max(hi, r)
                        if l < -d.half + h or r > d.half - h or t < d.y or bt > d.y + h - 3 then inside = false end
                    end
                end
                local w
                for _, b in pairs(ns.overheadUnits) do if b.shown and b.kind == d.kind then w = b.w end end
                print(tag, slot .. ":" .. d.kind, "cells=" .. n, "insideFloor=" .. tostring(inside),
                    "centred=" .. tostring(round(lo + hi) == 0), string.format("span=%d..%d", round(lo), round(hi)),
                    "ownWidth=" .. tostring(w == A.cell[d.kind]), "w=" .. tostring(w))
            end
        end
    end
    cellState("overhead.cells")
    local chips = {}
    for _, u in ipairs({ "boss1", "pet", "focus", "targettarget" }) do
        local b = ns.overheadUnits[u]
        local cl = rel(b.chip)
        local bl = rel(b)
        table.insert(chips, u .. "=" .. tostring(b.chip.texture):match("[^\\]+$") .. "@" .. round(cl - bl))
    end
    print("overhead.chips", table.concat(chips, " "))
    print("overhead.names", tostring(ns.overheadUnits.boss1.name.text), tostring(ns.overheadUnits.pet.name.text))
    -- the command row: stances, a gap, the pet bar; centred inside the tray,
    -- the bottom deck, with every icon inside the tray's floor
    local function rowState(tag)
        local row = ns.overheadRow or {}
        if #row == 0 then print(tag, "none"); return end
        local first, last = rel(row[1]), select(3, rel(row[#row]))
        local _, top = rel(row[1])
        local gaps = {}
        for i = 2, #row do
            local g = rel(row[i]) - select(3, rel(row[i - 1]))
            gaps[round(g)] = (gaps[round(g)] or 0) + 1
        end
        local g = {}
        for k2, v in pairs(gaps) do table.insert(g, k2 .. "x" .. v) end
        table.sort(g)
        local tray, bottom
        for slot, d in ipairs(decks) do
            if d.shown then bottom = slot end
            if d.shown and d.kind == "tray" then tray = d end
        end
        local inTray = tray ~= nil and decks[bottom] == tray
        if tray then
            local h = A.deck.tray
            for _, btn in ipairs(row) do
                local l, t, r, bt = rel(btn)
                if l < -tray.half + h or r > tray.half - h or t < tray.y or bt > tray.y + h then inTray = false end
            end
        end
        print(tag, "n=" .. #row, "stances=" .. tostring(ns.overheadRowStances),
            "centred=" .. tostring(round(first + last) == 0), "top=" .. round(top),
            "tray=" .. (tray and (tray.y .. "+" .. A.deck.tray) or "none"), "inTray=" .. tostring(inTray),
            "gaps=" .. table.concat(g, ","),
            "size=" .. tostring(row[1].w), "bare=" .. tostring(row[1].icon.coords and row[1].icon.coords[1]))
    end
    rowState("overhead.row")
    -- each icon edged in gold outside, black inside, both behind the icon
    do
        local btn = ns.overheadRow[1]
        local gold, black
        for _, r in ipairs(btn.all_) do
            if r.kind == "Texture" and r.layer == "BACKGROUND" and r.sub == -8 then gold = r end
            if r.kind == "Texture" and r.layer == "BACKGROUND" and r.sub == -7 then black = r end
        end
        local g = gold.gradient
        print("overhead.iconFrame", "gold=" .. gold.points.TOPLEFT[3] .. "," .. gold.points.TOPLEFT[4] .. "/"
            .. gold.points.BOTTOMRIGHT[3] .. "," .. gold.points.BOTTOMRIGHT[4],
            g and string.format("gradient=%s foot=%.3f,%.3f,%.3f top=%.3f,%.3f,%.3f", g[1], g[2][1], g[2][2], g[2][3],
                g[3][1], g[3][2], g[3][3])
                or string.format("solid=%.3f,%.3f,%.3f", gold.color[1], gold.color[2], gold.color[3]),
            "black=" .. tostring(black and black.all == btn and black.color[1] == 0 and black.color[4] == 1),
            "every icon=" .. tostring((function()
                for _, b in ipairs(ns.overheadRow) do if not b.medalluinFrame then return false end end
                return true
            end)()))
    end
    -- Blizzard's yellow autocast corners are faded, by key or by atlas; the shine stays
    local faded, shine = 0, 0
    for i = 1, 10 do
        local o = _G["PetActionButton" .. i].AutoCastOverlay
        if o.cornersTex:GetAlpha() == 0 then faded = faded + 1 end
        if o.Shine:GetAlpha() == 1 and o:GetAlpha() == 1 and o.shown ~= false then shine = shine + 1 end
    end
    print("overhead.autocast", "cornersFaded=" .. faded .. "/10", "shineKept=" .. shine .. "/10")
    print("overhead.parked", "stance=" .. tostring(StanceBar.parent == ns.hidden),
        "stanceEvents=" .. tostring(not StanceBar.unregistered),
        "pet=" .. tostring(PetActionBar.parent == ns.hidden),
        "petEvents=" .. tostring(not PetActionBar.unregistered),
        "totems=" .. tostring(MultiCastActionBarFrame.parent == ns.hidden),
        "totemEvents=" .. tostring(not MultiCastActionBarFrame.unregistered))

    -- no bosses (they are in the Boss widget): the companion deck moves to
    -- the top, on its own pieces
    page.settings.bossFrames:Set("vertical")
    deckState("overhead.noBoss")
    cellState("overhead.noBoss.cells")
    rowState("overhead.noBoss.row")
    -- the pet alone over the full row (the 2026-11-01 screenshot): the row's
    -- tray is wider than one cell's deck, so the deck grows; the cell keeps its
    -- width, centred (2026-11-02: a stretched pet ran under the ToT)
    page.settings.topFocus:Set(false)
    page.settings.topToT:Set(false)
    deckState("overhead.petOnly")
    cellState("overhead.petOnly.cells")
    -- and with bosses over it: the grown pet deck must grow the boss deck in
    -- turn, so the growth runs bottom up
    page.settings.bossFrames:Set("overhead")
    deckState("overhead.bossPet")
    cellState("overhead.bossPet.cells")
    page.settings.topFocus:Set(true)
    page.settings.topToT:Set(true)
    -- every deck width a stack can reach keeps the row's total even (centred
    -- on whole pixels), the cells inside the floor, and each cell its own
    -- width: a widened deck centres its cells, it does not stretch them
    local odd, over = 0, 0
    for _, kind in ipairs({ "boss", "unit" }) do
        for n = 1, 5 do
            local least = n * A.cell[kind] + (n - 1) * A.gap + 2 * A.deck[kind] + 2 * A.margin
            for w = least, least + 400, 2 do
                local cw = ns.OverheadCellWidth(kind, n, w)
                local total = n * cw + (n - 1) * A.gap
                if total % 2 == 1 then odd = odd + 1 end
                if total > w - 2 * A.deck[kind] - 2 * A.margin or cw ~= A.cell[kind] then over = over + 1 end
            end
        end
    end
    print("overhead.cellWidth", "oddTotals=" .. odd, "outOfFloor=" .. over)
    -- a switched-off frame stays off when its unit is there (target exists here)
    local tot = ns.overheadUnits.targettarget
    tot.unit = "target"
    ns.UpdateOverhead()     -- a real unit now: the watch has it
    page.settings.topToT:Set(false)
    watchTick()
    print("overhead.totOff", "shown=" .. tostring(tot.shown))
    tot.unit = "targettarget"
    page.settings.topToT:Set(true)
    -- in combat the cells' secure buttons are not moved; the layout waits
    local b1 = ns.overheadUnits.boss1
    local before = b1.points
    inCombat = true
    ns.UpdateOverhead()
    ns.UpdateOverhead()
    local held = b1.points == before
    inCombat = false
    for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    print("overhead.combat", "held=" .. tostring(held), "after=" .. tostring(b1.points ~= before and b1.shown))

    -- simulating a class with no stances (the 2026-11-01 hunter): no invented
    -- stance slots, so the pet bar alone is centred in the tray
    shapeshiftForms = 0
    ns.UpdateOverhead()
    rowState("overhead.simHunter.row")
    petBar = false
    ns.UpdateOverhead()
    rowState("overhead.simNoPet.row")
    -- a shaman: summon, four elements, recall, as the totem bar has them;
    -- then Ghost Wolf before them, a separator between; then page two
    do
        local bar = MultiCastActionBarFrame
        bar.shown = true
        for _, e in ipairs({ "UPDATE_MULTI_CAST_ACTIONBAR" }) do
            for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e) end
        end
        rowState("overhead.shaman.row")
        local names = {}
        for _, b in ipairs(ns.overheadRow or {}) do table.insert(names, (b:GetName():gsub("MultiCast", ""))) end
        print("overhead.shaman.order", table.concat(names, " "),
            "overlay=" .. tostring(MultiCastActionButton1.overlayTex.alpha),
            "pageParent=" .. tostring(MultiCastActionPage1.parent == ns.overhead),
            -- a button stays in its page, so a hidden page hides its four
            "inPage=" .. tostring(MultiCastActionButton5.parent == MultiCastActionPage2),
            "rings=" .. tostring(MultiCastSummonSpellButtonHighlight.alpha) .. ","
                .. tostring(MultiCastRecallSpellButtonHighlight.alpha))
        -- an element not learned yet, and no summon spell: the row closes up
        MultiCastActionButton4:Hide()
        MultiCastSummonSpellButton:Hide()
        rowState("overhead.shamanThree.row")
        MultiCastActionButton4:Show()
        MultiCastSummonSpellButton:Show()
        shapeshiftForms = 1
        ns.UpdateOverhead()
        rowState("overhead.shamanWolf.row")
        ChangeMultiCastActionPage(2)
        print("overhead.shaman.page2", tostring(ns.overheadRow[3] and ns.overheadRow[3]:GetName()))
        MultiCastRecallSpellButton_Update(MultiCastRecallSpellButton)
        print("overhead.shaman.recall", "relaid=" .. tostring(MultiCastRecallSpellButton.points.LEFT == nil))
        ChangeMultiCastActionPage(1)
        -- an element's flyout and its arrow open below the button
        local fly, el = MultiCastFlyoutFrame, MultiCastActionButton2
        -- before it opens: Blizzard's own field for the button it opens from
        -- is "parent", which in this mock is also the frame's parent
        local under = fly:GetParent() == ns.overhead
        local function tc(t) return t.coords[3] .. "," .. t.coords[4] end
        MultiCastFlyoutFrameOpenButton_Show(MultiCastFlyoutFrameOpenButton, "slot", el)
        local arrow = MultiCastFlyoutFrameOpenButton.points
        MultiCastFlyoutFrame_ToggleFlyout(fly, "slot", el)
        local function at(f, p)
            local pt = f.points[p]
            return pt and (p .. ">" .. (pt[1] == el and "el" or pt[1] == fly and "fly"
                or tostring(pt[1] and pt[1]:GetName())) .. "." .. pt[2] .. "," .. pt[4]) or "-"
        end
        local c = MultiCastFlyoutFrameCloseButton
        print("overhead.shaman.flyout", at(fly, "TOP"), "bottom=" .. at(fly, "BOTTOM"),
            "first=" .. at(fly.buttons[1], "TOP"), "close=" .. at(c, "BOTTOM"), "cap=" .. at(fly.top, "BOTTOM"),
            "top=" .. tc(fly.top), "middle=" .. tc(fly.middle), "closeTc=" .. tc(c.normalTexture),
            "under=" .. tostring(under))
        local icons = {}
        for _, b in ipairs(fly.buttons) do table.insert(icons, b.icon.coords[1] .. "-" .. b.icon.coords[2]) end
        print("overhead.shaman.flyout icons", table.concat(icons, " "))
        print("overhead.shaman.arrow", arrow.TOP and "below" or "above", "bottom=" .. tostring(arrow.BOTTOM ~= nil),
            "tc=" .. tc(MultiCastFlyoutFrameOpenButton.normalTexture))
        MultiCastFlyoutFrame_ToggleFlyout(fly, "slot", el)
        MultiCastFlyoutFrameOpenButton:Hide()
        bar.shown, shapeshiftForms = false, 0
        ns.UpdateOverhead()
        rowState("overhead.shamanGone.row")
    end
    -- not simulating: nothing to show; then a pet arrives (UNIT_PET for the
    -- player) with its bar, and the row stands alone at the top
    page.settings.simParty:Set(false)
    settleFades()       -- the emptied overhead fades out before it hides
    print("overhead.solo", "shown=" .. tostring(ovh.shown))
    rowState("overhead.solo.row")
    petBar = true
    -- shown without firing OnShow: the adopted-button hook would relayout on
    -- its own and hide whether UNIT_PET reaches the layout at all
    for i = 1, 10 do _G["PetActionButton" .. i].shown = true end
    for _, f in ipairs(events.UNIT_PET or {}) do f.scripts.OnEvent(f, "UNIT_PET", "player") end
    print("overhead.petArrives", "shown=" .. tostring(ovh.shown))
    rowState("overhead.petArrives.row")
    petBar = false
    page.settings.simParty:Set(true)

    -- 6. The simulation panel: shown while simulating, a tab per set of
    -- frames; its buttons by id (ns.simButtons)
    local sp = _G.MedalluinSimPanel
    local spb = ns.simButtons
    local function press(id)
        assert(spb[id], "no sim button " .. id)
        spb[id].scripts.OnClick(spb[id], "LeftButton")
    end
    -- the tabs, then the buttons the panel shows: those of the tab shown
    local function panelState(tag)
        local out = {}
        for _, b in ipairs(spb) do
            local page = b.parent ~= sp and b.parent
            if not page or page.shown then
                table.insert(out, string.format("%s=%s%s%s", b.id, b.label.text, b.on.shown and "*" or "",
                    b.alpha == 0.4 and "(off)" or ""))
            end
        end
        print(tag, "shown=" .. tostring(sp.shown), "h=" .. tostring(sp.h), table.concat(out, " "))
    end
    local function overhead(tag)
        local out = {}
        for _, u in ipairs({ "pet", "focus", "targettarget", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
            local b = ns.overheadUnits[u]
            if b and b.shown then
                table.insert(out, string.format("%s:%s,hp=%s", u, tostring(b.name.text), tostring(b.health.value)))
            end
        end
        print(tag, #out .. " " .. table.concat(out, " "))
    end
    local function members(tag)
        local out = {}
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local st = b.statusWidget
            local s = st.shown and st.icon.coords and string.format("%.2f", st.icon.coords[1]) or "-"
            local pet = b.pet and b.pet.shown and "pet" or "-"
            table.insert(out, string.format("p%d:%s,hp=%s,value=%s,dead=%s,a=%.2f,check=%s,%s", i,
                tostring(b.shown), tostring(b.health.value), tostring(b.value.text), tostring(b.dead.shown),
                b.alpha or 1, s, pet))
        end
        print(tag, table.concat(out, " "))
    end
    local function raid(tag)
        local out = {}
        for _, f in ipairs(ns.raidWidget.all_ or {}) do
            if f.stub and f.shown then
                table.insert(out, string.format("%s:hp=%s,%s%s%s%s%s%sa=%.2f", f.stub.name, tostring(f.health.value),
                    f.stub.dead and "dead," or "", f.stub.offline and "offline," or "",
                    f.stub.inRange == false and "away," or "",
                    f.dispelGlow and f.dispelGlow.shown and "glow," or "",
                    f.ccWidget and f.ccWidget.shown and "cc," or "",
                    f.bossDebuff and f.bossDebuff.shown and "boss," or "", f.alpha or 1))
            end
        end
        print(tag, #out .. " " .. table.concat(out, " "))
    end
    local function enemies(tag)
        local out = {}
        for _, kind in ipairs({ "Boss", "Arena" }) do
            for i = 1, 5 do
                local b = _G["Medalluin" .. kind .. "WidgetUnit" .. i]
                if b and b.shown and b.stub then
                    table.insert(out, string.format("%s%d:hp=%s%s", kind, i, tostring(b.health.value),
                        b.stub.dead and ",dead" or ""))
                end
            end
        end
        print(tag, #out .. " " .. table.concat(out, " "))
    end
    local function wait(seconds)
        for _ = 1, math.floor(seconds / 0.1 + 0.5) do sp.scripts.OnUpdate(sp, 0.1) end
    end
    print("simPanel.box", string.format("w=%s h=%s", tostring(sp.w), tostring(sp.h)),
        "strata=" .. tostring(sp.strata), "point=" .. tostring(sp.points.LEFT and sp.points.LEFT[2]))
    panelState("simPanel")
    -- every button inside its page (or the panel's margin), every tab
    local function fit()
        local out = {}
        for _, b in ipairs(spb) do
            local pt = b.points.TOPLEFT
            local x = pt and pt[3] or 0
            local inner = b.parent == sp and sp.w - 12 or b.parent.w
            local left = b.parent == sp and 12 or 0
            if x < left or x + b.w > inner + 0.01 then
                table.insert(out, string.format("%s(%s..%s of %s)", b.id, x, x + b.w, inner))
            end
        end
        return #out == 0 and "all inside" or table.concat(out, " ")
    end
    print("simPanel.fit", fit())
    members("simPanel.members")
    -- the party: one member at a time
    press("party.dead.1")
    press("party.away.2")
    press("party.offline.3")
    press("party.pet.2")
    press("party.pet.4")
    panelState("simPanel.dead1 away2 offline3 pets2,4")
    members("simPanel.members set")
    press("party.dead.1")
    press("party.away.2")
    press("party.offline.3")
    press("party.pet.2")
    press("party.pet.4")
    members("simPanel.members restored")
    -- health, click by click: 85 is not in the cycle, so 100, then 60, 25, 100
    for k = 1, 4 do
        press("party.health.1")
        members("simPanel.health " .. k)
    end
    page.settings.partyRange:Set(0)
    panelState("simPanel.range fade off")
    page.settings.partyRange:Set(40)
    -- two members: the others go, and their columns switch off
    press("party.count.less")
    press("party.count.less")
    panelState("simPanel.two members")
    members("simPanel.two members")
    press("party.count")
    print("simPanel.count none-or-all", spb["party.count"].label.text)
    press("party.count")
    press("party.count.more")
    press("party.count.more")
    press("party.count.more")
    members("simPanel.four again")
    -- the party's auras
    local function partyAuras(tag)
        local out = {}
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local o = {}
            if b.dispelGlow and b.dispelGlow.shown then table.insert(o, "glow") end
            if b.ccWidget and b.ccWidget.shown then table.insert(o, "cc") end
            if b.bossDebuff and b.bossDebuff.shown then table.insert(o, "boss") end
            local n = 0
            for _, btn in ipairs(b.buffWidgets or {}) do if btn.shown then n = n + 1 end end
            if n > 0 then table.insert(o, "buffs=" .. n) end
            table.insert(out, "p" .. i .. ":" .. (#o > 0 and table.concat(o, ",") or "-"))
        end
        print(tag, table.concat(out, " "))
    end
    partyAuras("simPanel.party auras")
    press("party.aura.cc")
    press("party.aura.buffs")
    panelState("simPanel.party auras cc,buffs off")
    partyAuras("simPanel.party auras cc,buffs off")
    press("party.count.less")
    press("party.count.less")
    press("party.aura.cc")
    partyAuras("simPanel.party auras two members")
    press("party.aura.cc")
    press("party.count.more")
    press("party.count.more")
    press("party.aura.cc")
    press("party.aura.buffs")

    -- the raid: whole sets, each toggle on at least one cell
    press("tab.raid")
    panelState("simPanel.raid")
    raid("simPanel.raid cells")
    press("raid.dead")
    press("raid.offline")
    press("raid.away")
    press("raid.hurt")
    raid("simPanel.raid dead offline away whole")
    press("raid.groups.less")
    raid("simPanel.raid one group")
    press("raid.groups")
    raid("simPanel.raid eight groups")
    press("raid.groups")
    press("raid.groups.more")
    page.settings.raidRange:Set(0)
    page.settings.bgRange:Set(0)
    panelState("simPanel.raid range fade off")
    raid("simPanel.raid range fade off")
    page.settings.raidRange:Set(40)
    page.settings.bgRange:Set(40)
    press("raid.dead")
    press("raid.offline")
    press("raid.away")
    press("raid.hurt")
    raid("simPanel.raid back")

    -- the enemies
    press("tab.enemies")
    panelState("simPanel.enemies")
    enemies("simPanel.enemies")
    overhead("simPanel.enemies overhead")
    press("enemies.bosses.more")
    press("enemies.bosses.more")
    press("enemies.bosses.more")
    press("enemies.arena.less")
    press("enemies.dead")
    panelState("simPanel.enemies five bosses, two arena, dead")
    enemies("simPanel.enemies five bosses, two arena, dead")
    overhead("simPanel.enemies five bosses overhead")
    press("enemies.bosses")
    overhead("simPanel.enemies no bosses overhead")
    press("enemies.bosses")
    for _ = 1, 3 do press("enemies.bosses.less") end
    press("enemies.arena.more")
    press("enemies.dead")
    enemies("simPanel.enemies back")

    -- the overhead
    press("tab.overhead")
    panelState("simPanel.overhead")
    overhead("simPanel.overhead")
    press("overhead.focus")
    press("overhead.hurt")
    overhead("simPanel.overhead no focus, whole")
    press("overhead.focus")
    press("overhead.hurt")
    press("tab.party")

    -- a ready check: all waiting, then one answer each STEP, then cleared
    press("party.ready")
    panelState("simPanel.ready")
    members("ready.start")
    wait(1.2)
    members("ready.two answered")
    wait(1.2)
    members("ready.all answered")
    wait(2.0)
    members("ready.held")
    wait(1.6)
    members("ready.cleared")
    panelState("simPanel.after ready")
    -- a role check, cut short by a fight; party4 is a real member here
    -- (no stub), who answers for themselves and is left alone
    local p4stub = ns.units.party4.stub
    ns.units.party4.stub = nil
    press("party.role")
    ns.units.party4.stub = p4stub
    panelState("simPanel.role")
    wait(0.6)
    members("role.one answered")
    for _, f in ipairs(events.PLAYER_REGEN_DISABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    members("role.fight")
    panelState("simPanel.after fight")
    -- a check under way when the simulation ends is cleared with it
    press("party.ready")
    press("end")
    print("simPanel.ended", "simParty=" .. tostring(ns.db.simParty), "shown=" .. tostring(sp.shown))
    members("ended")
    page.settings.simParty:Set(true)
    panelState("simPanel.again")
end

if bagsPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local w = _G.MedalluinBags
    print("bags", "window=" .. tostring(w ~= nil), "combined=" .. tostring(ContainerFrameCombinedBags ~= nil),
        "setting=" .. tostring(ns.db.bags))
    if not w then return end
    local W = bagWorld
    -- a slot's place in the body: column, and its top in pixels
    local function at(b)
        local p = b.points.TOPLEFT
        return string.format("%d,%d", p[3] / 41, -p[4])
    end
    local function slot(bag, i) return _G["MedalluinBagsItem" .. bag .. "_" .. i] end
    local function grid(tag)
        print(tag, "shown=" .. tostring(w.shown), string.format("size=%dx%d", w.w, w.h),
            "body=" .. string.format("%dx%d", w.parent and _G.MedalluinBagsBag0.parent.w or 0, _G.MedalluinBagsBag0.parent.h))
        for _, bag in ipairs({ 0, 1, 2, 3, 4, 5 }) do
            local first, last, n, items = nil, nil, 0, {}
            for i = 1, 20 do
                local b = slot(bag, i)
                if b and b.shown then
                    n = n + 1
                    first, last = first or at(b), at(b)
                    if b.hasItem then
                        table.insert(items, string.format("%d@%s q=%s n=%s%s%s%s%s%s", i, at(b), tostring(b.quality),
                            tostring(b.count), b.newGlow and " new" or "", b.quest and " quest" or "",
                            b.junk and " junk" or "", b.desat and " locked" or "", b.matches == false and " dim" or "")
                            .. (b.lock.shown and " padlock" or ""))
                    end
                    if b.itemLevel.text and b.itemLevel.text ~= "" then
                        items[#items] = items[#items] .. " ilvl=" .. b.itemLevel.text
                            .. string.format("(%.2f)", b.itemLevel.textColor and b.itemLevel.textColor[1] or -1)
                    end
                    if b.spare.text and b.spare.text ~= "" then
                        table.insert(items, string.format("%d@%s free=%s", i, at(b), tostring(b.spare.text)))
                    end
                end
            end
            print("  bag" .. bag, "slots=" .. n, "first=" .. tostring(first), "last=" .. tostring(last),
                "id=" .. tostring(_G["MedalluinBagsBag" .. bag] and _G["MedalluinBagsBag" .. bag]:GetID()),
                table.concat(items, "; "))
        end
        local heads = {}
        for _, r in ipairs(_G.MedalluinBagsBag0.parent.all_) do
            if r.kind == "FontString" and r.shown and r.text then
                table.insert(heads, r.text .. "@" .. -r.points.TOPLEFT[4])
            end
        end
        if #heads > 0 then print("  headings", table.concat(heads, ", ")) end
    end
    local function chrome(tag)
        local labels = {}
        for _, r in ipairs(w.all_) do
            if r.kind == "Button" and r.label then table.insert(labels, r.label.text) end
        end
        local texts = {}
        for _, r in ipairs(w.all_) do
            if r.kind == "FontString" and r.text then table.insert(texts, r.text) end
        end
        print(tag, "buttons=" .. table.concat(labels, "|"), "texts=" .. table.concat(texts, "|"))
    end
    local function blizz(tag)
        local parents, open = {}, {}
        for _, f in ipairs(ns.bags.blizzard) do
            if f.parent ~= ns.hidden then table.insert(parents, f.name) end
            if f.shown then table.insert(open, f.name) end
        end
        print(tag, "kept=" .. #ns.bags.blizzard, "not hidden=" .. (#parents > 0 and table.concat(parents, ",") or "none"),
            "open=" .. (#open > 0 and table.concat(open, ",") or "none"), "window=" .. tostring(w.shown))
    end

    -- 1. at login: Blizzard's frames out of sight, the window closed
    blizz("bags.login")
    print("bags.strata", w.strata, "parent=" .. tostring(w.parent == UIParent), "search=" .. tostring(_G.MedalluinBagsSearch ~= nil))

    -- the slots are made at login, before any open (one made in combat
    -- would use items tainted until /reload)
    local function made(tag)
        local n, fought = 0, 0
        for bag = 0, 5 do
            for i = 1, 20 do
                local b = slot(bag, i)
                if b then
                    n = n + 1
                    if b.bornInCombat then fought = fought + 1 end
                end
            end
        end
        print(tag, "made=" .. n, "in combat=" .. fought)
    end
    made("bags.made at login")

    -- 2. Blizzard opens the bags (the B key): the window follows
    W.reads = 0
    OpenAllBags()
    blizz("bags.open")
    print("bags.reads on open", W.reads)
    grid("bags.grid")
    chrome("bags.chrome")
    -- a click is Blizzard's: the template alone, and nothing its OnClick reads
    -- (GetBagID, bagID) written by us, or UseContainerItem is blocked as tainted
    do
        local b = slot(0, 1)
        local ours, hooked = {}, {}
        for _, key in ipairs({ "OnClick", "PreClick", "PostClick" }) do
            if b.scripts[key] and not (b.hooked and b.hooked[key]) then table.insert(ours, key) end
            if b.hooked and b.hooked[key] then table.insert(hooked, key) end
        end
        for _, key in ipairs({ "GetBagID", "bagID", "GetSlotAndBagID" }) do
            if rawget(b, key) ~= nil then table.insert(ours, key) end
        end
        print("bags.item click", "template=" .. tostring(b.template), "ours=" .. (#ours > 0 and table.concat(ours, ",") or "none"),
            "hooked after it=" .. (#hooked > 0 and table.concat(hooked, ",") or "none"))
    end
    print("bags.anchor", tostring(w.points.BOTTOMRIGHT and w.points.BOTTOMRIGHT[1].name),
        tostring(w.points.BOTTOMRIGHT and w.points.BOTTOMRIGHT[2]))

    -- 3. Blizzard moves its frame for a full-screen panel: it goes back
    ContainerFrameCombinedBags:SetParent(UIParent)
    blizz("bags.reparented")

    -- 4. events while open: one refresh, at the next frame
    W.reads = 0
    W.put(1, 2, 108, 3)
    fire("BAG_UPDATE_DELAYED")
    print("bags.reads before the frame", W.reads)
    w.scripts.OnUpdate(w, 0.02)
    print("bags.reads after the frame", W.reads)
    w.scripts.OnUpdate(w, 0.02)
    print("bags.reads next frame", W.reads)
    grid("bags.picked up")
    -- an item picked up is locked: the client says so with its own event
    W.items["3:2"].isLocked = true
    fire("ITEM_LOCK_CHANGED", 3, 2)
    w.scripts.OnUpdate(w, 0.02)
    print("bags.lock", "3:2 desaturated=" .. tostring(_G.MedalluinBagsItem3_2.desat))
    W.items["3:2"].isLocked = false

    -- 4b. Alt+click locks an item from the vendor and from destroying: a
    -- padlock in the slot's bottom left, on every one of that item
    do
        local stone, ore = slot(0, 1), slot(3, 2)
        local lock = stone.lock
        local p = lock.points.BOTTOMLEFT
        print("bags.padlock", string.format("size=%dx%d", lock.w, lock.h),
            string.format("at=%s %d,%d", tostring(p[2]), p[3] or 0, p[4] or 0),
            "above=" .. tostring((lock.level or 0) - (stone.level or 0)), "shown=" .. tostring(lock.shown))
        for _, blend in ipairs({ "BLEND", "ADD" }) do
            local t = lock[blend]
            print("  padlock " .. blend, "atlas=" .. tostring(t.atlas), "grey=" .. tostring(t.desaturated),
                string.format("tint=%.2f,%.2f,%.2f", unpack(t.vertex or { 1, 1, 1 })), "blend=" .. tostring(t.blend))
        end
        local function db() return MedalluinCharDB and MedalluinCharDB.lockedItems or {} end
        local function marks(tag)
            local on = {}
            for bag = 0, 5 do
                for i = 1, 20 do
                    local b = slot(bag, i)
                    if b and b.lock.shown then table.insert(on, bag .. ":" .. i) end
                end
            end
            local ids = {}
            for id in pairs(db()) do table.insert(ids, id) end
            table.sort(ids)
            print(tag, "padlocks=" .. (#on > 0 and table.concat(on, ",") or "none"),
                "stored=" .. (#ids > 0 and table.concat(ids, ",") or "none"))
        end
        stone.scripts.OnClick(stone, "LeftButton")
        marks("bags.lock plain click")
        modsDown.ALT = true
        stone.scripts.OnClick(stone, "LeftButton")
        marks("bags.lock alt")
        ore.scripts.OnClick(ore, "RightButton")
        marks("bags.lock alt right, ore")
        -- with Shift or Ctrl too, or an item held: not a lock
        modsDown.SHIFT = true
        ore.scripts.OnClick(ore, "LeftButton")
        modsDown.SHIFT, modsDown.CTRL = nil, true
        ore.scripts.OnClick(ore, "LeftButton")
        modsDown.CTRL = nil
        local held = CursorHasItem
        CursorHasItem = function() return true end
        ore.scripts.OnClick(ore, "LeftButton")
        CursorHasItem = held
        marks("bags.lock alt with more, or held")
        -- an empty slot: nothing to lock
        slot(0, 4).scripts.OnClick(slot(0, 4), "LeftButton")
        marks("bags.lock empty slot")
        modsDown.ALT = nil
        -- the lock follows the item: ore put in another bag wears it there
        W.put(4, 3, 105, 2)
        fire("BAG_UPDATE_DELAYED")
        w.scripts.OnUpdate(w, 0.02)
        marks("bags.lock follows the item")
        -- destroying a locked item: put back, and said why; an unlocked one is left to the game
        local info, clear = GetCursorInfo, ClearCursor
        local put = 0
        ClearCursor = function() put = put + 1 end
        GetCursorInfo = function() return "item", 107 end
        W.said = {}
        local errors = UIErrorsFrame
        UIErrorsFrame = { AddMessage = function(_, m) table.insert(W.said, m) end }
        fire("DELETE_ITEM_CONFIRM", "Hearthstone", 1, 0, 0)
        GetCursorInfo = function() return "item", 103 end
        fire("DELETE_ITEM_CONFIRM", "Healing Potion", 1, 0, 0)
        GetCursorInfo = function() return "spell", 107 end
        fire("DELETE_ITEM_CONFIRM", "x", 1, 0, 0)
        print("bags.destroy locked", "put back=" .. put, "said=" .. table.concat(W.said, " / "))
        UIErrorsFrame = errors
        GetCursorInfo, ClearCursor = info, clear
        -- Alt+click again: unlocked
        modsDown.ALT = true
        stone.scripts.OnClick(stone, "LeftButton")
        slot(4, 3).scripts.OnClick(slot(4, 3), "LeftButton")
        modsDown.ALT = nil
        marks("bags.unlocked")

        -- the tooltip: "Locked" under a locked item's, in the padlock's blue
        local function tip(tag, id)
            local lines = {}
            local t = { AddLine = function(_, text, r, g, b)
                table.insert(lines, string.format("%s(%.2f,%.2f,%.2f)", text, r, g, b))
            end }
            for _, post in ipairs(W.posts) do
                if post.kind == Enum.TooltipDataType.Item then post.fn(t, { id = id }) end
            end
            print(tag, "lines=" .. (#lines > 0 and table.concat(lines, " / ") or "none"),
                "shared=" .. tostring(Medalluin_LockedLine))
        end
        ns.locks.Toggle(107)
        tip("bags.tip locked", 107)
        tip("bags.tip not locked", 103)
        -- a secret id is never a key: the game refuses one
        setmetatable(MedalluinCharDB.lockedItems, { __index = function(_, k)
            if isSecret(k) then error("a secret value as a table key") end
        end })
        tip("bags.tip secret", secret())
        setmetatable(MedalluinCharDB.lockedItems, nil)
        tip("bags.tip no id", nil)

        -- at a vendor: a guard over each locked slot takes its clicks, so the
        -- template's right click (a sale) never runs
        local function guards(tag)
            local on = {}
            for bag = 0, 5 do
                for i = 1, 20 do
                    local b = slot(bag, i)
                    if b and b.guard.shown then table.insert(on, bag .. ":" .. i) end
                end
            end
            print(tag, "guards=" .. (#on > 0 and table.concat(on, ",") or "none"))
        end
        guards("bags.guard before a vendor")
        fire("MERCHANT_SHOW")
        guards("bags.guard at a vendor")
        harnessBeside("bags guard tips", MedalluinBags)
        local g = stone.guard
        print("bags.guard", "covers=" .. tostring(g.all == stone),
            "above padlock=" .. tostring((g.level or 0) > (stone.lock.level or 0)),
            "clicks=" .. tostring(g.clicks and table.concat(g.clicks, ",")),
            "drag=" .. tostring(g.drag and table.concat(g.drag, ",")))
        local errors = UIErrorsFrame
        W.said = {}
        UIErrorsFrame = { AddMessage = function(_, m) table.insert(W.said, m) end }
        local modified, inserted = IsModifiedClick, {}
        local chat, insert = ChatEdit_GetActiveWindow, ChatEdit_InsertLink
        ChatEdit_GetActiveWindow = function() return true end
        ChatEdit_InsertLink = function(l) table.insert(inserted, l) end
        W.picked = {}
        g.scripts.OnClick(g, "RightButton")
        g.scripts.OnClick(g, "LeftButton")
        g.scripts.OnDragStart(g, "LeftButton")
        g.scripts.OnReceiveDrag(g)
        IsModifiedClick = function(action) return action == "CHATLINK" end
        g.scripts.OnClick(g, "LeftButton")
        IsModifiedClick = modified
        g.scripts.OnEnter(g)
        print("bags.guard clicks", "said=" .. table.concat(W.said, " / "), "picked=" .. table.concat(W.picked, ","),
            "linked=" .. table.concat(inserted, ","), "tip=" .. tostring(GameTooltip.item))
        g.scripts.OnLeave(g)
        ChatEdit_GetActiveWindow, ChatEdit_InsertLink = chat, insert
        UIErrorsFrame = errors
        -- a lock made at the vendor is guarded at once; Alt+click on the guard unlocks
        modsDown.ALT = true
        ore.scripts.OnClick(ore, "LeftButton")
        guards("bags.guard locked at the vendor")
        W.picked = {}
        ore.guard.scripts.OnClick(ore.guard, "LeftButton")
        modsDown.ALT = nil
        guards("bags.guard unlocked at the vendor")
        print("bags.guard alt picks up", #W.picked > 0 and table.concat(W.picked, ",") or "nothing")
        fire("MERCHANT_CLOSED")
        guards("bags.guard vendor gone")
        ns.locks.Toggle(107)
        W.items["4:3"] = nil
        fire("BAG_UPDATE_DELAYED")
        w.scripts.OnUpdate(w, 0.02)
    end

    -- 5. the groups
    page.settings.bagsView:Set("groups")
    grid("bags.groups")
    chrome("bags.groups chrome")
    -- the window's own button goes back, through the page
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "Grid" then r.scripts.OnClick(r) end
    end
    print("bags.view button", ns.db.bagsView, "window shows=" .. optionShows("bagsView"))
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "Groups" then
            r.scripts.OnEnter(r)
            print("bags.view tip", tostring(GameTooltip.text))
        end
    end

    -- the bags, each under its name; the empty bag slot (bag 2) left out.
    -- The choice is the saved table's, so a reload keeps it
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.mark and r.label.text == "Bags" then r.scripts.OnClick(r) end
    end
    print("bags.view bags", ns.db.bagsView, "saved=" .. tostring(MedalluinDB.global.bagsView),
        "window shows=" .. optionShows("bagsView"))
    grid("bags.by bag")
    do
        local lit = {}
        for _, r in ipairs(w.all_) do
            if r.kind == "Button" and r.mark then
                local c = r.label.textColor or {}
                table.insert(lit, string.format("%s=%s/g%.2f", r.label.text, tostring(r.mark.shown), c[2] or -1))
            end
        end
        print("bags.view lit", table.concat(lit, " "))
    end
    page.settings.bagsView:Set("grid")
    print("bags.view grid", "saved=" .. tostring(MedalluinDB.global.bagsView))

    -- 6. the search, the client's: what does not match is dimmed
    local box = _G.MedalluinBagsSearch
    box.text = "potion"
    box.scripts.OnTextChanged(box)
    fire("INVENTORY_SEARCH_UPDATE")
    w.scripts.OnUpdate(w, 0.02)
    print("bags.search", tostring(W.search))
    grid("bags.searched")
    box.text = ""
    box.scripts.OnTextChanged(box)
    fire("INVENTORY_SEARCH_UPDATE")
    w.scripts.OnUpdate(w, 0.02)

    -- 7. sort
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "Sort" then r.scripts.OnClick(r) end
    end
    print("bags.sort", W.sorted)

    -- 8. options: eight across, no item levels
    ns.SetOption("bagsColumns", 8)
    page.settings.bagsItemLevel:Set(false)
    grid("bags.eight across")
    ns.SetOption("bagsColumns", 10)
    page.settings.bagsItemLevel:Set(true)

    -- 9. bag 1 swapped for a bag of 6: its other slots go
    W.sizes[1] = 6
    W.items["1:2"] = nil
    fire("BAG_CONTAINER_UPDATE")
    w.scripts.OnUpdate(w, 0.02)
    grid("bags.smaller bag")

    -- 9b. a bigger bag in a fight: its new slots wait for the fight's end
    -- rather than be made in it
    W.sizes[1] = 20
    inCombat = true
    fire("BAG_CONTAINER_UPDATE")
    w.scripts.OnUpdate(w, 0.02)
    grid("bags.bigger bag in combat")
    made("bags.bigger bag in combat")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    w.scripts.OnUpdate(w, 0.02)
    grid("bags.bigger bag after combat")
    made("bags.bigger bag after combat")
    -- and with the bags closed when the fight ends: made then, ready for
    -- an open in the next fight
    W.sizes[3] = 20
    inCombat = true
    fire("BAG_CONTAINER_UPDATE")
    CloseAllBags()
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    made("bags.bigger bag, closed, after combat")
    OpenAllBags()
    W.sizes[3] = 10
    W.sizes[1] = 6
    fire("BAG_CONTAINER_UPDATE")
    w.scripts.OnUpdate(w, 0.02)

    -- 10. closed with the window's button: Blizzard's close, the new items seen
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "x" then r.scripts.OnClick(r) end
    end
    blizz("bags.closed")
    print("bags.seen", table.concat(W.removed, ","), "still new=" .. tostring(W.new["0:3"]))

    -- 11. events while closed: no reads until it opens again
    W.reads = 0
    fire("BAG_UPDATE_DELAYED")
    w.scripts.OnUpdate(w, 0.02)
    print("bags.reads while closed", W.reads)

    -- the groups again: nothing is new now, so New has no heading
    page.settings.bagsView:Set("groups")
    OpenAllBags()
    grid("bags.groups, nothing new")
    CloseAllBags()
    page.settings.bagsView:Set("grid")

    -- 12. one bag of Blizzard's opened alone (the bag button), then Esc
    ContainerFrame3:Show()
    blizz("bags.one bag")
    CloseAllBags()
    blizz("bags.esc")

    -- 13. dragged: where it was left, after a reload too
    w.points = { TOPLEFT = { UIParent, "TOPLEFT", 300, -200 } }
    function w:GetPoint() return "TOPLEFT", UIParent, "TOPLEFT", 300, -200 end
    function w:StopMovingOrSizing() self.moving = false end
    w.scripts.OnDragStop(w)
    print("bags.dragged", ns.db.bagsPoint and table.concat(ns.db.bagsPoint, ","))
    ToggleAllBags()
    print("bags.reopened", tostring(w.points.TOPLEFT and w.points.TOPLEFT[3]), tostring(w.points.TOPLEFT and w.points.TOPLEFT[4]),
        "bottomright=" .. tostring(w.points.BOTTOMRIGHT ~= nil))
    ToggleAllBags()

    -- 14. the page and the slash command
    ns.BuildOptions()
    for _, c in ipairs(ns.optionPages.bags.controls) do
        local spec, choices = c.spec, {}
        for _, o in ipairs(spec.choices or {}) do table.insert(choices, tostring(o[1]) .. "=" .. o[2]) end
        local hit = spec.kind == "choice" and c.button or c.less or c.box or c
        print("bags.page", spec.kind, spec.label, "default=" .. tostring(ns.OptionBase(spec.key)),
            hit:IsEnabled() and "live" or "grey", table.concat(choices, "; "))
    end
    SlashCmdList.MDLUI("bags")
    print("/mdlui bags opens", tostring(page.opened))

    -- 15. the head's rule: under the buttons, over the slots
    OpenAllBags()
    local rule, closeTop = w.rule, nil
    print("bags.rule", "y=" .. -rule.points.TOPLEFT[4], "inset=" .. rule.points.TOPLEFT[3] .. "," .. rule.points.TOPRIGHT[3],
        "h=" .. rule.h, "slots from=" .. -_G.MedalluinBagsBag0.parent.points.TOPLEFT[4])

    -- 16. the drawer: Bags opens it above the window, growing to the right
    local title = w.title
    title.scripts.OnEnter(title)
    print("bags.title tip", tostring(GameTooltip.text))
    title.scripts.OnClick(title)
    local d = _G.MedalluinBagsDrawer
    local function drawerState(tag)
        local order = {}
        for _, n in ipairs({ "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
            "CharacterReagentBag0Slot", "KeyRingButton" }) do
            local b = _G[n]
            local p = b.points.TOPLEFT
            table.insert(order, string.format("%s@%s,%dx%d%s", n:gsub("Character", ""):gsub("Slot", ""),
                p and p[3] or "-", b.w, b.h, b.parent == d.inner and "" or " NOT IN DRAWER"))
        end
        print(tag, "shown=" .. tostring(d.shown), "width=" .. string.format("%.0f", d.w), "full=" .. tostring(d.full),
            "anchor=" .. tostring(d.points.BOTTOMLEFT and d.points.BOTTOMLEFT[2]), table.concat(order, " "))
    end
    drawerState("bags.drawer opened")
    d.scripts.OnUpdate(d, 0.05)
    drawerState("bags.drawer growing")
    d.scripts.OnUpdate(d, 0.5)
    drawerState("bags.drawer grown")
    print("bags.drawer styled", "edge=" .. tostring(CharacterBag0Slot.medalluin ~= nil),
        "ring styled=" .. tostring(KeyRingButton.medalluin ~= nil))
    -- Blizzard re-sets the ring's art for its own button: fitted again
    KeyRingButton:GetNormalTexture():ClearAllPoints()
    KeyRingButton:UpdateTextures()
    print("bags.ring art", "fitted=" .. tostring(KeyRingButton:GetNormalTexture().all == KeyRingButton))
    -- and a bag slot's: its frame hidden again
    CharacterBag0Slot:GetNormalTexture():SetAlpha(1)
    CharacterBag0Slot:UpdateTextures()
    print("bags.slot art", "normal alpha=" .. tostring(CharacterBag0Slot:GetNormalTexture():GetAlpha()))
    -- Blizzard's bag bar collapsing would hide them
    CharacterBag2Slot:SetBarExpanded(false)
    print("bags.collapsed", "bag 2 shown=" .. tostring(CharacterBag2Slot.shown))
    -- Blizzard's bag bar places its buttons again: they come back
    BagsBar.layoutAtLoad()
    drawerState("bags.drawer after BagsBar")
    title.scripts.OnEnter(title)
    print("bags.title tip open", tostring(GameTooltip.text))
    title.scripts.OnClick(title)
    drawerState("bags.drawer closed")
    title.scripts.OnEnter(title)
    print("bags.title tip closed", tostring(GameTooltip.text))
    title.scripts.OnClick(title)
    CloseAllBags()
    drawerState("bags.drawer with the window closed")

    -- 17. the corner: six dots; held, the window keeps its top-left and the
    -- columns follow the pointer
    OpenAllBags()
    local g = _G.MedalluinBagsGrip
    local dots = {}
    for _, t in ipairs(g.dots) do table.insert(dots, t.points.BOTTOMRIGHT[3] .. "," .. t.points.BOTTOMRIGHT[4]) end
    for _, r in ipairs(w.all_) do
        if r.kind == "FontString" and r.points.BOTTOMRIGHT then
            print("bags.free text", "right=" .. r.points.BOTTOMRIGHT[3], "clear of the dots=" .. tostring(-r.points.BOTTOMRIGHT[3] > 3 + 12))
        end
    end
    print("bags.grip", "at=" .. g.points.BOTTOMRIGHT[3] .. "," .. g.points.BOTTOMRIGHT[4], "dots=" .. table.concat(dots, " "),
        "colour=" .. string.format("%.2f", g.dots[1].color[1]))
    g.scripts.OnEnter(g)
    print("bags.grip hover", string.format("%.2f", g.dots[1].color[1]))
    function w:GetLeft() return 500 end
    function w:GetTop() return 700 end
    local cursorX = 500 + 422
    function GetCursorPosition() return cursorX, 0 end
    g.scripts.OnMouseDown(g)
    print("bags.grip held", "anchor=" .. tostring(w.points.TOPLEFT and w.points.TOPLEFT[2] .. "@" .. w.points.TOPLEFT[3]
        .. "," .. w.points.TOPLEFT[4]))
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip still", "columns=" .. ns.db.bagsColumns, "viaPage=" .. tostring(page.settings.bagsColumns))
    cursorX = 500 + 422 + 90           -- two slots and a bit wider
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip wider", "columns=" .. ns.db.bagsColumns, "size=" .. w.w .. "x" .. w.h)
    cursorX = 500 + 422 + 15            -- under half a slot past ten: rounds back
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip back", "columns=" .. ns.db.bagsColumns)
    cursorX = 500 + 447                 -- over half a slot past ten: rounds up
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip over half", "columns=" .. ns.db.bagsColumns)
    cursorX = 500 + 30
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip narrowest", "columns=" .. ns.db.bagsColumns)
    cursorX = 500 + 5000
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip widest", "columns=" .. ns.db.bagsColumns)
    function w:GetPoint() return "TOPLEFT", UIParent, "BOTTOMLEFT", 500, 700 end
    g.scripts.OnMouseUp(g)
    print("bags.grip let go", "point=" .. table.concat(ns.db.bagsPoint, ","), "colour=" .. string.format("%.2f", g.dots[1].color[1]))
    g.scripts.OnUpdate(g, 0.02)
    cursorX = 500 + 422
    g.scripts.OnUpdate(g, 0.02)
    print("bags.grip not held", "columns=" .. ns.db.bagsColumns)
    -- a place saved before the corner, { point, x, y }, still reads
    ns.db.bagsPoint = { "TOPLEFT", 300, -200 }
    CloseAllBags()
    OpenAllBags()
    local p = w.points.TOPLEFT
    harnessBeside("bags tips", MedalluinBags)
    do
        local items = {}
        for i = 1, 4 do local b = _G["MedalluinBagsItem0_" .. i]; if b then items[b] = "default" end end
        harnessBeside("bags item default tips", MedalluinBags, nil, nil, items)
        for b in pairs(items) do items[b] = "button" end
        harnessBeside("bags item button tips", MedalluinBags, nil, nil, items)
        -- the pointer gone (a tooltip fading, or parked off the screen): left where it is put
        GameTooltip:SetOwner(MedalluinBagsItem0_1, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -10000, -10000)
        local park = GameTooltip.points.TOPRIGHT
        print("bags item parked", "kept=" .. tostring(park and park[1] == UIParent and park[3] == -10000))
        print("bags item beside", "told=" .. tostring(Medalluin_TooltipBeside(MedalluinBagsItem0_1)),
            "elsewhere=" .. tostring(Medalluin_TooltipBeside(UIParent)))
        -- another tooltip in the default place leaves GameTooltip where it is
        local other = new("Frame", UIParent)
        function other:SetOwner() end
        GameTooltip.points = {}
        GameTooltip_SetDefaultAnchor(other, MedalluinBagsItem0_1)
        print("bags item other tooltip", "GameTooltip moved=" .. tostring(next(GameTooltip.points) ~= nil))
    end
    print("bags.old point", p and (p[2] .. "," .. p[3] .. "," .. p[4]))
    CloseAllBags()
end

-- --------------------------------------------------------------- the bank
if bankPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local B = bankWorld
    local W = ns.bank and ns.bank.W
    local w = _G.MedalluinBank
    print("bank", "window=" .. tostring(w ~= nil), "setting=" .. tostring(ns.db.bank),
        "parked=" .. tostring(BankFrame.parent == ns.hidden), "cover=" .. tostring(_G.MedalluinBankCover ~= nil))
    if not w then return end
    local function frame()
        local now = B.timers
        B.timers = {}
        for _, fn in ipairs(now) do fn() end
        if w.shown and w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0) end
    end
    local function find(root, test)
        for _, r in ipairs(root.all_ or {}) do
            if test(r) then return r end
            local deeper = find(r, test)
            if deeper then return deeper end
        end
    end
    local function button(root, label)
        return find(root, function(r) return r.kind == "Button" and r.label and r.label.text == label end)
    end
    local function click(b, ...) b.scripts.OnClick(b, ...) end
    local function where(r)
        local point, p = next(r.points)
        if not point then return "nowhere" end
        return string.format("%s %s %s %g,%g", point, p[1] and (p[1].name or "?") or "-", p[2] or "-",
            p[3] or 0, p[4] or 0)
    end
    local function calls()
        local out = table.concat(B.calls, ", ")
        B.calls = {}
        return out == "" and "none" or out
    end
    local function state(tag)
        local p = W.Current()
        print(tag, "shown=" .. tostring(w.shown), "blizzard=" .. tostring(BankFrame.shown),
            "cover=" .. tostring(_G.MedalluinBankCover.shown), "tracker=" .. tostring(_G.MedalluinQuests
            and _G.MedalluinQuests.shown), "npc=" .. tostring(_G.MedalluinNPC and _G.MedalluinNPC.shown),
            "page=" .. (p and p.key or "none"), "detached=" .. tostring(W.Detached()),
            "medal=" .. tostring(w.medal.shown), "grip=" .. tostring(w.grip.shown),
            string.format("scale=%g", w.scale or 1), "at=" .. where(w),
            "band=" .. (p and p.band and tostring(p.band.points.BOTTOMLEFT[3]) or "-"),
            "portrait=" .. tostring(CharacterMicroButton.strata) .. "/" .. tostring(CharacterMicroButton.level))
    end
    local function tabs(tag)
        local list = {}
        for _, p in ipairs(W.pages) do
            if p.tab and p.tab.shown then
                table.insert(list, p.label .. (p.tab.mark.shown and "*" or "") .. "@" .. tostring(p.tab.w))
            end
        end
        print(tag, table.concat(list, " "))
    end
    local function slots(tag, p)
        local list = {}
        for _, bag in ipairs({ 6, 7, 8, 12, 13 }) do
            local h = p.set.holders[bag]
            if h then
                local n, items = 0, {}
                for i, b in pairs(p.set.slots[bag]) do
                    if b.shown then
                        n = n + 1
                        if b.hasItem then
                            local pt = b.points.TOPLEFT
                            table.insert(items, string.format("%d@%d,%d%s", i, pt[3] / 41, -pt[4],
                                b.matches == false and " dim" or ""))
                        end
                    end
                end
                table.sort(items)
                table.insert(list, string.format("%d:%d/%d[%s]", bag, n, h:GetID(), table.concat(items, " ")))
            end
        end
        local heads = {}
        for _, r in ipairs(p.scroller.child.all_ or {}) do
            if r.kind == "FontString" and r.shown and r.text and r.text ~= "" then
                table.insert(heads, r.text .. "@" .. -r.points.TOPLEFT[4])
            end
        end
        print(tag, "body=" .. p.scroller.child.w .. "x" .. p.scroller.child.h, table.concat(list, " "),
            "headings=" .. (#heads > 0 and table.concat(heads, ",") or "none"))
    end
    local function bags(tag, p)
        local list = {}
        for i, b in ipairs(p.bags) do
            if b.shown then
                table.insert(list, string.format("%d:%s at=%d:%d %s a=%g%s", i, b.bought and "bought" or "locked",
                    b.page.kind == 2 and -3 or -2, b.index + 1, tostring(b.icon.texture):gsub(".*\\", ""), b.icon.alpha or 1,
                    b.icon.desaturated and " grey" or ""))
            end
        end
        print(tag, table.concat(list, "; "), "price=" .. tostring(p.price.text),
            "purchase=" .. tostring(p.purchase.shown) .. "/" .. tostring(p.purchase.label.text)
            .. string.format("@%g", p.purchase.alpha or 1))
    end
    local function band(tag, p)
        local list = {}
        for _, r in ipairs(p.band.all_ or {}) do
            if r.kind == "Button" and r.label and r.shown then
                table.insert(list, r.label.text .. (r.mark and r.mark.shown and "*" or ""))
            end
        end
        print(tag, table.concat(list, "|"), "search=" .. tostring(p.search and p.search.name))
    end

    -- 1. at login: built, Blizzard's parked, nothing shown
    state("bank.login")
    -- over the chat's cog and its drawer, MEDIUM all three
    print("bank.levels", "window=" .. tostring(w.strata) .. "/" .. tostring(w.level),
        "cog=" .. tostring(ns.chat.cog and ns.chat.cog.strata) .. "/" .. tostring(ns.chat.cog and ns.chat.cog.level),
        "drawer=" .. tostring(ns.chat.drawer and ns.chat.drawer.level))
    tabs("bank.tabs at login")

    -- 2. the banker: Blizzard shows its frame, ours follows
    BankFrame:Show()
    frame()
    state("bank.open")
    tabs("bank.tabs")
    local p = W.Current()
    slots("bank.grid", p)
    band("bank.band", p)
    bags("bank.bag slots", p)
    print("bank.foot", "details=" .. tostring(ns.db.bankDetails), "foot=" .. tostring(p.foot.shown),
        "foot h=" .. tostring(p.foot.h))

    -- 3. the views, the band's buttons and the option's
    click(button(p.band, "Bags"))
    frame()
    print("bank.view", ns.db.bankView, "saved=" .. tostring(MedalluinDB.global.bankView))
    slots("bank.by bag", p)
    band("bank.band bags", p)
    click(button(p.band, "Groups"))
    frame()
    slots("bank.groups", p)
    page.settings.bankView:Set("grid")
    print("bank.view option", ns.db.bankView)
    slots("bank.view option grid", p)
    frame()
    local tip = button(p.band, "Grid")
    tip.scripts.OnEnter(tip)
    print("bank.view tip", tostring(GameTooltip.text))

    -- 4. the search, the client's; Sort, the bank's own; Deposit only where the bank takes it
    p.search.text = "potion"
    p.search.scripts.OnTextChanged(p.search)
    fire("INVENTORY_SEARCH_UPDATE")
    frame()
    print("bank.search", tostring(bagWorld.search))
    slots("bank.searched", p)
    p.search.text = ""
    p.search.scripts.OnTextChanged(p.search)
    frame()
    click(button(p.band, "Sort"))
    print("bank.sort", calls(), "deposit=" .. tostring(p.deposit.shown))

    -- 5. the bag slots, as Blizzard's: a bag in the bank-tab container's
    -- slot (the first tab is the bank, so bag slot 1 is its slot 2); a
    -- click, a drag and a drop all pick up there (the game swaps); a locked
    -- slot answers nothing
    local one, two = p.bags[1], p.bags[2]
    click(one)
    one.scripts.OnDragStart(one)
    one.scripts.OnReceiveDrag(one)
    print("bank.bag slot 1", calls())
    click(two)
    two.scripts.OnReceiveDrag(two)
    two.scripts.OnDragStart(two)
    print("bank.bag slot 2", calls())
    one.scripts.OnEnter(one)
    print("bank.bag tip 1", tostring(GameTooltip.item), tostring(GameTooltip.shown))
    two.scripts.OnEnter(two)
    print("bank.bag tip 2", tostring(GameTooltip.text))
    two.scripts.OnLeave(two)

    -- 6. Purchase: Blizzard's own, pressed by a secure button over ours (the
    -- game refuses PurchaseBankTab to addons); its popup's Yes buys
    local layer = ns.bank.layer
    local function buy(tag)
        local b = _G.MedalluinBankPurchase
        print(tag, "secure=" .. tostring(b ~= nil), "shown=" .. tostring(b and b.shown),
            "over=" .. tostring(b and b.shown and harnessOver(b, p.purchase)),
            "type=" .. tostring(b and b.attrs.type),
            "clicks=" .. tostring(b and b.attrs.clickbutton and b.attrs.clickbutton.name),
            "layer=" .. tostring(layer.shown) .. "/" .. tostring(layer.stateDrivers and layer.stateDrivers.visibility),
            "face=" .. tostring(p.purchase.label.text))
    end
    buy("bank.purchase")
    local secure = _G.MedalluinBankPurchase
    secure.scripts.OnEnter(secure)
    print("bank.purchase tip", tostring(GameTooltip.text))
    -- the secure click presses Blizzard's button; its popup's Yes buys
    secure.attrs.clickbutton.scripts.OnClick(secure.attrs.clickbutton)
    C_Bank.PurchaseBankTab(B.active)
    print("bank.purchase pressed", calls())
    fire("BANK_TABS_CHANGED")
    frame()
    bags("bank.bought", p)
    slots("bank.bought grid", p)
    B.poor = true
    fire("PLAYER_MONEY")
    frame()
    bags("bank.poor", p)
    p.purchase.scripts.OnEnter(p.purchase)
    print("bank.poor tip", tostring(GameTooltip.text))
    B.poor = false
    -- in combat: the layer's driver hides it; nothing moves until it ends
    inCombat = true
    harnessHolds.combat = true
    stateTick()
    fire("BANK_TABS_CHANGED")
    frame()
    buy("bank.purchase in combat")
    p.purchase.scripts.OnEnter(p.purchase)
    print("bank.purchase combat tip", tostring(GameTooltip.text))
    -- the game's bank turned to its other tab in combat: the button waits
    B.active = 2
    fire("BANK_TABS_CHANGED")
    frame()
    buy("bank.purchase tab in combat")
    inCombat = false
    harnessHolds.combat = nil
    stateTick()
    fire("PLAYER_REGEN_ENABLED")
    buy("bank.purchase tab after combat")
    B.active = 0
    fire("BANK_TABS_CHANGED")
    frame()
    -- the last slot bought: no Purchase, no secure button
    C_Bank.PurchaseBankTab(0)
    fire("BANK_TABS_CHANGED")
    frame()
    print("bank.last", calls())
    bags("bank.every slot", p)
    buy("bank.purchase none left")
    -- one more bag slot to buy, for the rest of the pass
    B.max[0] = 5
    fire("BANK_TABS_CHANGED")
    frame()
    buy("bank.purchase another")

    -- 7. the details fold
    click(w.chevron)
    frame()
    print("bank.details folded", "details=" .. tostring(ns.db.bankDetails), "foot=" .. tostring(p.foot.shown))
    buy("bank.purchase folded")
    click(w.chevron)
    frame()

    -- 8. the character window stands over it; the tracker and the NPC box under it
    CharacterFrame:Show()
    state("bank.character")
    CharacterFrame:Hide()
    state("bank.character closed")
    GossipFrame:Show()
    frame()
    state("bank.with gossip")
    BankFrame:Hide()
    state("bank.gossip alone")
    -- the NPC box first, then the bank over it
    BankFrame:Show()
    frame()
    state("bank.over gossip")
    GossipFrame:Hide()

    -- 9. detached: a box of its own, covering nothing
    -- the screen's edges, as the game has them (the harness's screen is not)
    function w:GetLeft() return 0 end
    function w:GetTop() return 1050 end
    w.view.scripts.OnEnter(w.view)
    print("bank.view glyph", tostring(w.view.icon.texture):gsub(".*\\", ""), tostring(GameTooltip.text))
    click(w.view)
    frame()
    state("bank.detached")
    buy("bank.purchase detached")
    print("bank.place", string.format("w=%s h=%s", tostring(ns.db.bankPlace.w), tostring(ns.db.bankPlace.h)),
        "size=" .. w.w .. "x" .. w.h, "saved=" .. tostring(type(MedalluinDB.global.bankPlace)))
    tabs("bank.detached tabs")
    CharacterFrame:Show()
    state("bank.detached character")
    CharacterFrame:Hide()
    -- a drag, the grip, and Ctrl+wheel
    harnessDropAt = { "TOPLEFT", "TOPLEFT", 300, -150 }
    w.scripts.OnDragStart(w)
    w.scripts.OnDragStop(w)
    print("bank.dragged", where(w), string.format("saved=%s,%s", tostring(ns.db.bankPlace.x),
        tostring(ns.db.bankPlace.y)))
    harnessBeside("bank tips", w)
    -- dragged to the screen's right half: its tooltips go to its left
    function w:GetLeft() return 1400 end
    function w:GetRight() return 1800 end
    harnessBeside("bank tips dragged right", w)
    function w:GetLeft() return 0 end
    w.GetRight = nil
    harnessSizeTo = { 560, 400 }
    w.grip.scripts.OnMouseDown(w.grip)
    w.grip.scripts.OnMouseUp(w.grip)
    frame()
    print("bank.sized", "size=" .. w.w .. "x" .. w.h, string.format("saved=%sx%s", tostring(ns.db.bankPlace.w),
        tostring(ns.db.bankPlace.h)))
    slots("bank.sized grid", p)
    -- the wheel over the slots, the box shorter than they are: two rows a notch, no further than the end
    print("bank.scroll", "view=" .. tostring(p.body.h), "target=" .. tostring(p.scroller.target))
    p.body.scripts.OnMouseWheel(p.body, -1)
    print("bank.scroll down", "target=" .. tostring(p.scroller.target))
    for _ = 1, 20 do p.body.scripts.OnMouseWheel(p.body, -1) end
    print("bank.scroll end", "target=" .. tostring(p.scroller.target))
    -- the list shorter than the scroll: back within it
    page.settings.bankView:Set("groups")
    print("bank.scroll shorter", "target=" .. tostring(p.scroller.target))
    page.settings.bankView:Set("grid")
    p.body.scripts.OnMouseWheel(p.body, 30)
    print("bank.scroll top", "target=" .. tostring(p.scroller.target))
    w.scripts.OnMouseWheel(w, 1)
    print("bank.wheel alone", string.format("scale=%g", w.scale or 1))
    modsDown.CTRL = true
    w.scripts.OnMouseWheel(w, 1)
    w.scripts.OnMouseWheel(w, 1)
    -- scaled: the game measures a frame in its own scale (the harness in the
    -- screen's), so the face's and the layer's edges as the game gives them:
    -- the face at 400,300 on the screen in a window of 1.1, the layer at
    -- 0,30 in one of 1. The button must stand at 400,270 from the layer,
    -- 92x22 times 1.1.
    do
        local face = p.purchase
        function face:GetLeft() return 400 / 1.1 end
        function face:GetBottom() return 300 / 1.1 end
        function face:GetEffectiveScale() return 1.1 end
        function layer:GetLeft() return 0 end
        function layer:GetBottom() return 30 end
        function layer:GetEffectiveScale() return 1 end
        fire("BANK_TABS_CHANGED")
        frame()
        local b = _G.MedalluinBankPurchase
        local at = b.points.BOTTOMLEFT
        print("bank.purchase scaled", string.format("at=%.1f,%.1f size=%.1fx%.1f on=%s", at[3], at[4], b.w, b.h,
            tostring(at[1] == layer)))
        face.GetLeft, face.GetBottom, face.GetEffectiveScale = nil, nil, nil
        layer.GetLeft, layer.GetBottom, layer.GetEffectiveScale = nil, nil, nil
    end
    print("bank.wheel", string.format("scale=%g saved=%.17g", w.scale or 1, ns.db.bankPlace.scale or 1), where(w))
    for _ = 1, 20 do w.scripts.OnMouseWheel(w, 1) end
    print("bank.wheel most", string.format("scale=%.17g", w.scale or 1))
    for _ = 1, 30 do w.scripts.OnMouseWheel(w, -1) end
    print("bank.wheel least", string.format("scale=%.17g", w.scale or 1))
    for _ = 1, 10 do w.scripts.OnMouseWheel(w, 1) end
    print("bank.wheel back", string.format("scale=%.17g", w.scale or 1), where(w))
    -- in combat: no drag, no grip, no wheel, no switch
    inCombat = true
    w.scripts.OnMouseWheel(w, -1)
    harnessDropAt = { "TOPLEFT", "TOPLEFT", 10, -10 }
    w.scripts.OnDragStart(w)
    w.scripts.OnDragStop(w)
    w.grip.scripts.OnMouseDown(w.grip)
    print("bank.combat", string.format("scale=%g", w.scale or 1), where(w), "sizing=" .. tostring(w.isSizing))
    click(w.view)
    print("bank.combat switch", "detached=" .. tostring(W.Detached()))
    -- a place set in combat (a profile switched) waits for its end
    local before = ns.db.bankPlace
    local moved = {}
    for k, v in pairs(before) do moved[k] = v end
    moved.x, moved.y = 500, -400
    ns.SetOption("bankPlace", moved)
    print("bank.combat place", where(w))
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    print("bank.combat place after", where(w))
    ns.SetOption("bankPlace", before)
    modsDown.CTRL = nil
    -- docked again: on the strip, its scale 1, the place kept for next time
    click(w.view)
    frame()
    state("bank.docked")
    print("bank.kept", string.format("w=%s scale=%s detached=%s", tostring(ns.db.bankPlace.w),
        tostring(ns.db.bankPlace.scale), tostring(ns.db.bankPlace.detached)))
    click(w.view)
    frame()
    state("bank.detached again")
    BankFrame:Hide()
    BankFrame:Show()
    frame()
    state("bank.reopened detached")
    click(w.view)
    frame()

    -- 10. the warband's bank, once the game lets you see it
    BankFrame:Hide()
    B.account = true
    BankFrame:Show()
    frame()
    tabs("bank.warband tabs")
    local wb = W.pages[2]
    W.Select(wb)
    frame()
    state("bank.warband")
    slots("bank.warband grid", wb)
    band("bank.warband band", wb)
    bags("bank.warband bag slots", wb)
    page.settings.bankView:Set("bags")
    slots("bank.warband by bag", wb)
    page.settings.bankView:Set("grid")
    click(wb.deposit)
    print("bank.deposit", calls())
    -- Blizzard's panel on its Bank tab: no secure button over the warband's
    buy("bank.warband purchase")
    wb.purchase.scripts.OnEnter(wb.purchase)
    print("bank.warband purchase tip", tostring(GameTooltip.text))
    -- reopened at the banker, the page it was on
    BankFrame:Hide()
    BankFrame:Show()
    frame()
    state("bank.reopened")
    -- the warband's gone (another character): back to the bank
    BankFrame:Hide()
    B.account = false
    BankFrame:Show()
    frame()
    state("bank.no warband")
    tabs("bank.no warband tabs")
    -- a warband bank not yet begun: its first tab is bought elsewhere
    BankFrame:Hide()
    B.account = true
    local saved = B.tabs[2]
    B.tabs[2] = {}
    BankFrame:Show()
    frame()
    W.Select(wb)
    frame()
    bags("bank.warband unbegun", wb)
    slots("bank.warband unbegun grid", wb)
    B.tabs[2] = saved
    B.account = false
    W.Select(W.pages[1])
    frame()

    -- 11. closed with ours: the game's close
    click(w.close)
    state("bank.closed")
    buy("bank.purchase closed")
    print("bank.close", calls())
end

-- ---------------------------------------------------- the character window
if characterPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local C = ns.character
    local w = _G.MedalluinCharacter
    print("char", "window=" .. tostring(w ~= nil), "setting=" .. tostring(ns.db.character),
        "parked=" .. tostring(CharacterFrame.parent == ns.hidden))
    if not w then return end
    local function frame()
        if w.shown and w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0) end
    end
    local function current()
        for _, p in ipairs(C.pages) do
            if p.body and p.body.shown then return p end
        end
    end
    -- the events the window listens to now
    local function heard()
        local n = 0
        for _, list in pairs(events) do
            for _, f in ipairs(list) do
                if f == C.listener then n = n + 1 end
            end
        end
        return n
    end
    local function state(tag)
        local p = current()
        local icon = w.chevron.icon.texture or ""
        print(tag, "shown=" .. tostring(w.shown), "blizzard=" .. tostring(CharacterFrame.shown),
            "page=" .. (p and p.key or "none"), string.format("size=%dx%d", w.w, w.h),
            "details=" .. tostring(p and p.foot.shown), "chevron=" .. (icon:match("chevron%-(%a+)$") or "?")
                .. (w.chevron.shown and "" or " hidden"),
            "heard=" .. heard())
    end
    local function tabs(tag)
        local list = {}
        for _, p in ipairs(C.pages) do
            if p.tab then
                local glyph = (p.tab.icon.texture or ""):match("strips\\(.+)$") or "?"
                table.insert(list, glyph .. (p.tab.mark.shown and "*" or "") .. "@" .. p.tab.w
                    .. string.format("(%.1f)", p.tab.icon.alpha or 1) .. (p.tab.top and "!open" or ""))
            end
        end
        local close = C.window.close
        print(tag, table.concat(list, " "), "close=" .. ((close.icon.texture or ""):match("strips\\(.+)$") or "?")
            .. "@" .. close.w, "toggles=" .. table.concat(charWorld.toggles, ","))
    end
    local function where(r)
        local point, p = next(r.points)
        if not point then return "nowhere" end
        return string.format("%s %s %s %d,%d", point, p[1] and (p[1].name or (p[1] == r.parent and "parent")
            or "?") or "-", p[2] or "-", p[3] or 0, p[4] or 0)
    end
    local function txt(t) return isSecret(t) and "secret" or t end
    local function character(tag)
        local S = C.slots
        local cols = {}
        for _, b in ipairs(S.columns) do
            local p = b.points.TOPLEFT or b.points.TOPRIGHT
            table.insert(cols, string.format("%s%s%d", b.slotName, b.side < 0 and "<" or ">", -p[4])
                .. (b.level.text ~= "" and ("=" .. b.level.text) or "")
                .. string.format("(%.2f)", b.edge.color[1]))
        end
        print(tag .. " columns", "parent=" .. tostring(S.columns[1].parent == current().body), table.concat(cols, " "))
        local row = {}
        for _, b in ipairs(S.weapons) do
            if b.shown then
                local p = b.points.TOPLEFT
                table.insert(row, string.format("%s@%d,%d", b.slotName, p[3], -p[4])
                    .. (b.level.text ~= "" and ("=" .. b.level.text) or ""))
            else
                table.insert(row, b.slotName .. " hidden")
            end
        end
        print(tag .. " weapons", table.concat(row, " "))
        local body = current().body
        local texts = {}
        for _, r in ipairs(body.all_) do
            if r.kind == "FontString" and r.text and r.text ~= "" then table.insert(texts, r.text) end
        end
        print(tag .. " head", table.concat(texts, " | "), "model=" .. tostring(S.model.unit) .. " x"
            .. tostring(S.model.unitSets), "muted=" .. tostring(S.columns[1].normal.vertex
            and S.columns[1].normal.vertex[4] == 0))
        local st = C.stats
        local cells = {}
        for _, c in ipairs(st.ribbon.cells) do table.insert(cells, c.label.text .. " " .. c.value.text) end
        print(tag .. " ribbon", table.concat(cells, " | "), "ilvl=" .. st.badge.value.text)
        for _, side in ipairs({ "left", "right" }) do
            local rows = {}
            for _, r in ipairs(st.columns[side]) do
                if r.shown then
                    local p = r.points.TOPLEFT or r.points.TOPRIGHT
                    table.insert(rows, r.label.text .. "=" .. txt(r.value.text) .. "@" .. -p[4])
                end
            end
            print(tag .. " " .. side, table.concat(rows, " "))
        end
        if st.resist then
            local rs = {}
            for _, c in ipairs(st.resist.cells) do table.insert(rs, c.school .. "=" .. c.value.text) end
            print(tag .. " resist", table.concat(rs, " "))
        end
    end

    -- 1. at login: Blizzard's window out of sight, ours closed
    state("char.login")
    print("char.anchor", where(w), "parent=" .. tostring(w.parent == ns.strips[-1]), "strata=" .. tostring(w.strata),
        "ignoresParentAlpha=" .. tostring(w.ignoreParentAlpha))
    tabs("char.tabs")

    -- 2. C opens Blizzard's window on its Character page: ours follows
    ToggleCharacter("PaperDollFrame")
    frame()
    state("char.open")
    character("char")

    -- 3. the chevron folds the details away, and opens them again
    w.chevron.scripts.OnClick(w.chevron)
    state("char.folded")
    print("char.folded saved", tostring(ns.db.characterDetails))
    w.chevron.scripts.OnClick(w.chevron)
    state("char.unfolded")

    -- 3b. the window is the screen's height, and the page spreads out over
    -- it; folded details give the page their room
    local function pageOf(key)
        for _, p in ipairs(C.pages) do
            if p.key == key then return p end
        end
    end
    local function fit(tag)
        local f = pageOf("character").fit
        print(tag, string.format("slot=%d pitch=%d top=%d cols=%d divider=%s", f.size, f.pitch, f.top, f.cols,
            tostring(f.divider)), string.format("size=%dx%d", w.w, w.h))
    end
    fit("char.fit")
    w.chevron.scripts.OnClick(w.chevron)
    fit("char.fit folded")
    w.chevron.scripts.OnClick(w.chevron)
    -- the medallion over the window's margin: the portrait lifted to the
    -- window's strata, the medallion's art copied over it
    local function medallion(tag)
        local b = CharacterMicroButton
        print(tag, "portrait=" .. tostring(b.strata) .. "/" .. tostring(b.level),
            "window=" .. tostring(w.strata) .. "/" .. tostring(w.level),
            "art=" .. tostring(w.medal.level) .. string.format(" %dx%d", w.medal.w, w.medal.h)
                .. " " .. where(w.medal),
            "margin=" .. where(w.bandRule))
    end
    medallion("char.medallion")
    -- the shortcuts: secure clicks on Blizzard's micro buttons, on the strip,
    -- following the window out of combat and hidden by a driver in it
    local row = _G.MedalluinCharacterShortcuts
    local function shortcuts(tag)
        local out = {}
        for _, b in ipairs(row.buttons) do
            table.insert(out, b.label.text .. ">" .. tostring(b.attrs.clickbutton and b.attrs.clickbutton.name)
                .. "(" .. tostring(b.attrs.type) .. ")")
        end
        print(tag, "shown=" .. tostring(row.shown), "driver=" .. tostring(row.stateDrivers
            and row.stateDrivers.visibility), "parent=" .. tostring(row.parent == ns.strips[-1]),
            table.concat(out, " "))
    end
    shortcuts("char.shortcuts")


    charWorld.gear[1] = { 4, 22 }
    fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
    print("char.equip before the frame", "head=" .. C.slots.columns[1].level.text)
    frame()
    print("char.equip", "head=" .. C.slots.columns[1].level.text, string.format("(%.2f)",
        C.slots.columns[1].edge.color[1]), "model x" .. C.slots.model.unitSets)

    -- 5. Blizzard places a slot of its own (it does, for the main hand):
    -- it goes back; the ammo slot shown closes the row up round four
    CharacterMainHandSlot:ClearAllPoints()
    CharacterMainHandSlot:SetPoint("BOTTOM", UIParent, "BOTTOM", -40, 30)
    character("char.replaced")
    if CharacterAmmoSlot then
        CharacterAmmoSlot:Show()
        character("char.ammo")
        CharacterAmmoSlot:Hide()
    end

    -- 6. the model turns as it is dragged
    local m = C.slots.model
    local realCursor = GetCursorPosition
    local cx = 100
    function GetCursorPosition() return cx, 0 end
    m.scripts.OnMouseDown(m, "LeftButton")
    cx = 150
    m.scripts.OnUpdate(m, 0.1)
    m.scripts.OnMouseUp(m, "LeftButton")
    cx = 300
    m.scripts.OnUpdate(m, 0.1)
    print("char.turned", string.format("%.2f", m.facing or 0))
    GetCursorPosition = realCursor

    -- 7. a stat this client lacks drops its row and the column closes up
    local parry = GetParryChance
    GetParryChance = nil
    fire("UNIT_STATS", "player")
    frame()
    character("char.no parry")
    GetParryChance = parry

    -- 7b. the shortcuts in combat: the driver hides them; closed in combat,
    -- they are put away when it ends; opened in combat, they wait for its end
    local function combat(on)
        harnessHolds.combat = on or nil
        inCombat = on
        stateTick()
        if not on then
            for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
        end
    end
    combat(true)
    shortcuts("char.shortcuts in combat")
    HideUIPanel(CharacterFrame)
    shortcuts("char.shortcuts closed in combat")
    medallion("char.medallion closed")
    combat(false)
    shortcuts("char.shortcuts closed after combat")
    combat(true)
    ToggleCharacter("PaperDollFrame")
    frame()
    shortcuts("char.shortcuts opened in combat")
    combat(false)
    shortcuts("char.shortcuts after combat")
    -- another tab puts them away
    pageOf("reputation").tab.scripts.OnClick(pageOf("reputation").tab)
    frame()
    shortcuts("char.shortcuts on reputation")
    print("rep.margin", "ornament=" .. tostring(#pageOf("reputation").band.all_ > 0))
    pageOf("character").tab.scripts.OnClick(pageOf("character").tab)
    frame()
    shortcuts("char.shortcuts back")

    -- 8. Escape closes Blizzard's window: ours follows, and stops listening;
    -- a change while closed is drawn at the next opening
    HideUIPanel(CharacterFrame)
    state("char.closed")
    shortcuts("char.shortcuts closed")
    charWorld.gear[1] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
    ToggleCharacter("PaperDollFrame")
    frame()
    print("char.reopened", "head=" .. C.slots.columns[1].level.text, string.format("(%.2f)",
        C.slots.columns[1].edge.color[1]))
    -- C again: Blizzard closes it
    ToggleCharacter("PaperDollFrame")
    state("char.toggled shut")

    -- ------------------------------------------------- the list pages
    local function page(key)
        -- the Character page's titles and sets are lists of their own
        if C[key] and C[key].list then return { list = C[key].list, body = C[key].list.body } end
        for _, p in ipairs(C.pages) do
            if p.key == key then return p end
        end
    end
    local function rows(tag, key)
        local list = page(key).list
        local out = {}
        for _, r in ipairs(list.rows) do
            if r.shown then
                local d = r.data
                local bit = string.rep(".", d.depth or 0) .. d.label
                if d.header then bit = "[" .. bit .. " " .. r.sign.text .. "]" end
                if r.fill.gradient then bit = bit .. " fade" end    -- the quest tracker's alone
                if d.icon then bit = bit .. "{" .. tostring(d.icon) .. "}" end
                if r.bar.shown then
                    bit = bit .. string.format(" <%s %s/%s>", r.bar.text.text, tostring(r.bar.bar.value),
                        tostring(r.bar.bar.max))
                end
                if r.value.shown then bit = bit .. " =" .. r.value.text end
                if r.mark.shown then bit = bit .. " *" end
                if d.dim then bit = bit .. " dim" end
                table.insert(out, bit)
            end
        end
        print(tag, "body=" .. page(key).body.h, "rows=" .. #list.data, "drawn=" .. #out
            .. (list.empty.shown and " empty:" .. list.empty.text or "")
            .. (list.track.shown and string.format(" thumb=%d@%d", list.thumb.h, -list.thumb.points.TOP[4]) or ""),
            table.concat(out, " | "))
    end
    local function details(tag, key)
        local d = page(key).details
        if d.nothing.shown then
            print(tag, "nothing: " .. d.nothing.text)
            return
        end
        local ticks = {}
        for _, t in ipairs(d.ticks) do
            table.insert(ticks, t.label.text .. "=" .. tostring(t.on) .. (t.enabled and "" or "(off)"))
        end
        print(tag, d.title.text, "| " .. tostring(d.sub.text), d.bar.shown and string.format("| <%s %s/%s>",
            d.bar.text.text, tostring(d.bar.bar.value), tostring(d.bar.bar.max)) or "| no bar",
            "| " .. tostring(d.text.text):gsub("\n", " / "), table.concat(ticks, " "))
    end
    local function click(key, label, button)
        for _, r in ipairs(page(key).list.rows) do
            if r.shown and r.data.label == label then
                r.scripts.OnClick(r, button or "LeftButton")
                frame()
                return
            end
        end
        print("  no row " .. label)
    end
    local function tick(key, i)
        local t = page(key).details.ticks[i]
        t.scripts.OnClick(t)
        frame()
    end
    local function calls(tag)
        print(tag, table.concat(charWorld.calls, "; "))
        charWorld.calls = {}
    end

    -- 8b. the Character page's details: Stats, Titles, Sets, each the stats'
    -- height, so the window keeps its own
    ToggleCharacter("PaperDollFrame")
    frame()
    local views = page("character").views
    local function view(tag)
        local on = {}
        for _, k in ipairs({ "stats", "titles", "sets" }) do
            local v = views[k]
            if v then
                table.insert(on, k .. (v.button.mark.shown and "*" or "") .. (v.frame.shown and "+" or "")
                    .. "@" .. v.button.points.TOPLEFT[3] .. "/" .. v.frame.h)
            end
        end
        print(tag, table.concat(on, " "), string.format("size=%dx%d", w.w, w.h))
    end
    local function press(key)
        views[key].button.scripts.OnClick(views[key].button)
        frame()
    end
    view("gear.views")
    press("titles")
    view("gear.titles")
    rows("gear.titles", "titles")
    click("titles", "Corporal")
    rows("gear.title worn", "titles")
    click("titles", "No Title")
    rows("gear.title none", "titles")
    calls("gear.title calls")
    -- a title the game no longer counts as known is not marked worn
    charWorld.title = 4
    fire("KNOWN_TITLES_UPDATE")
    frame()
    rows("gear.title unknown", "titles")

    press("sets")
    view("gear.sets")
    rows("gear.sets", "sets")
    local function buttons(tag)
        local out = {}
        for _, b in ipairs(C.sets.buttons) do table.insert(out, b.label.text .. "=" .. tostring(b.enabled)) end
        print(tag, table.concat(out, " "))
    end
    local function act(label)
        for _, b in ipairs(C.sets.buttons) do
            if b.label.text == label then b.scripts.OnClick(b) end
        end
        frame()
    end
    buttons("gear.sets none")
    act("Remove")
    print("gear.sets refused", "popups=" .. table.concat(charWorld.popups, ","))
    click("sets", "Healing")
    buttons("gear.sets healing")
    act("Equip")
    fire("EQUIPMENT_SETS_CHANGED")
    frame()
    rows("gear.sets equipped", "sets")
    harnessBeside("char sets tips", MedalluinCharacter)
    buttons("gear.sets worn")
    -- Save asks first; its answer keeps the set's own ignored slots
    charWorld.sets[2].worn = false
    fire("EQUIPMENT_SETS_CHANGED")
    frame()
    act("Save")
    StaticPopupDialogs[charWorld.popup.which].OnAccept({}, charWorld.popup.data)
    -- New asks for a name; the head's icon, and the shirt and tabard ignored
    act("New")
    local dialog = { editBox = { GetText = function() return "  PvP " end } }
    StaticPopupDialogs[charWorld.popup.which].OnAccept(dialog)
    frame()
    rows("gear.sets new", "sets")
    buttons("gear.sets full")
    -- a name already taken makes nothing
    StaticPopupDialogs.MEDALLUIN_SET_NEW.OnAccept({ editBox = { GetText = function() return "PvP" end } })
    act("Remove")
    StaticPopupDialogs[charWorld.popup.which].OnAccept({}, charWorld.popup.data)
    fire("EQUIPMENT_SETS_CHANGED")
    frame()
    rows("gear.sets removed", "sets")
    print("gear.popups", table.concat(charWorld.popups, ","))
    calls("gear.set calls")
    press("stats")
    view("gear.stats again")
    ToggleCharacter("PaperDollFrame")

    -- 9. the reputation key opens Blizzard's window on its page: ours follows
    ToggleCharacter("ReputationFrame")
    frame()
    state("rep.open")
    tabs("rep.tabs")
    rows("rep", "reputation")
    details("rep.none", "reputation")
    click("reputation", "Darnassus")
    rows("rep.chosen", "reputation")
    details("rep.chosen", "reputation")
    -- the ticks: inactive moves it under Inactive and it stays chosen
    tick("reputation", 2)
    rows("rep.inactive", "reputation")
    details("rep.inactive", "reputation")
    tick("reputation", 3)
    details("rep.watched", "reputation")
    -- and off again: no faction followed
    tick("reputation", 3)
    tick("reputation", 3)
    -- at war is greyed for Darnassus; the Argent Dawn's can be ticked
    tick("reputation", 1)
    click("reputation", "Argent Dawn")
    tick("reputation", 1)
    details("rep.war", "reputation")
    calls("rep.calls")
    -- a heading folds
    click("reputation", "Alliance")
    rows("rep.folded", "reputation")
    click("reputation", "Alliance")
    calls("rep.fold calls")
    -- a short screen: the list gives up height and scrolls by the wheel
    local realHeight = UIParent.GetHeight
    function UIParent:GetHeight() return 240 end
    ns.SetOption("characterDetails", true)
    frame()
    rows("rep.short", "reputation")
    local list = page("reputation").list
    list.scripts.OnMouseWheel(list, -1)
    rows("rep.scrolled", "reputation")
    list.scripts.OnMouseWheel(list, -5)
    rows("rep.scrolled to the end", "reputation")
    UIParent.GetHeight = realHeight
    ns.SetOption("characterDetails", true)
    frame()
    state("rep.tall again")

    -- 10. a tab asks Blizzard for its page out of combat; in combat it turns
    -- ours only
    charWorld.toggles = {}
    page("currency").tab.scripts.OnClick(page("currency").tab)
    frame()
    state("cur.tab")
    tabs("cur.tabs")
    print("cur.blizzard on", TokenFrame.shown and "TokenFrame" or "?")
    rows("cur", "currency")
    harnessBeside("char currency tips", MedalluinCharacter)
    click("currency", "Honor Points")
    details("cur.honor", "currency")
    click("currency", "Arena Points")
    details("cur.arena", "currency")
    tick("currency", 1)
    tick("currency", 1)
    tick("currency", 1)
    tick("currency", 2)
    rows("cur.unused", "currency")
    details("cur.ticked", "currency")
    -- a shift click links it, and chooses nothing
    charWorld.modified = true
    click("currency", "Honor Points")
    charWorld.modified = false
    details("cur.linked", "currency")
    click("currency", "Player vs. Player")
    rows("cur.folded", "currency")
    calls("cur.calls")
    -- no currencies at all, as a new character has
    local saved = {}
    for i, c in ipairs(charWorld.currencies) do saved[i] = c end
    for i = #charWorld.currencies, 1, -1 do charWorld.currencies[i] = nil end
    fire("CURRENCY_DISPLAY_UPDATE")
    frame()
    rows("cur.empty", "currency")
    details("cur.empty", "currency")
    for i, c in ipairs(saved) do charWorld.currencies[i] = c end

    if page("skills").available then
        inCombat = true
        charWorld.toggles = {}
        page("skills").tab.scripts.OnClick(page("skills").tab)
        frame()
        inCombat = false
        state("skills.tab in combat")
        tabs("skills.tabs")
        rows("skills", "skills")
        click("skills", "Defense")
        details("skills.defense", "skills")
        click("skills", "Herbalism")
        details("skills.herbalism", "skills")
        click("skills", "Weapon Skills")
        rows("skills.folded", "skills")
        calls("skills.calls")
        -- Gathering: the nodes of the gathering professions known, coloured
        -- by the chance of a skill point (Herbalism 45, Mining 140)
        local function nodes(tag)
            local out = {}
            for _, r in ipairs(page("skills").list.data) do
                if not r.header and r.depth == 2 then
                    table.insert(out, string.format("%s=%s(%.2f,%.2f,%.2f)", r.label, r.value, unpack(r.color)))
                end
            end
            print(tag, #out, table.concat(out, " "))
        end
        local function heading(label)
            for _, r in ipairs(page("skills").list.rows) do
                if r.shown and r.data.header and r.data.label == label and r.data.depth == 1 then
                    r.scripts.OnClick(r, "LeftButton")
                    frame()
                    return
                end
            end
            print("  no heading " .. label)
        end
        rows("skills.gathering", "skills")
        nodes("skills.nodes")
        for _, name in ipairs({ "Iron Deposit", "Tin Vein", "Copper Vein", "Indurium Mineral Vein", "Mageroyal",
            "Earthroot", "Peacebloom" }) do
            click("skills", name)
            details("skills.node " .. name, "skills")
        end
        -- the Professions heading folded: its lines are not given, the nodes stay
        click("skills", "Professions")
        nodes("skills.professions folded")
        details("skills.professions folded", "skills")
        click("skills", "Professions")
        -- a profession's heading, then Gathering's, folded
        heading("Mining")
        nodes("skills.mining folded")
        heading("Mining")
        click("skills", "Gathering")
        rows("skills.gathering folded", "skills")
        click("skills", "Gathering")
        -- Herbalism unlearned: its nodes go, and the chosen one with them
        local herb = table.remove(charWorld.skills, 7)
        fire("SKILL_LINES_CHANGED")
        frame()
        nodes("skills.herbalism unlearned")
        details("skills.herbalism unlearned", "skills")
        -- none known: no Gathering
        local mining = table.remove(charWorld.skills, 8)
        fire("SKILL_LINES_CHANGED")
        frame()
        rows("skills.none gathering", "skills")
        table.insert(charWorld.skills, 7, herb)
        table.insert(charWorld.skills, mining)
        fire("SKILL_LINES_CHANGED")
        frame()

        ToggleCharacter("PVPRankFrame")
        frame()
        local pv = page("pvp")
        state("pvp.key")
        print("pvp", pv.season.text, "|", pv.rank.text, "|", pv.emblem.atlas, "|", pv.bar.text.text)
        details("pvp", "pvp")
        print("pvp.fit", "emblem=" .. pv.emblemSize, "season " .. where(pv.season))
        -- a short screen: a fixed page keeps the Character page's height,
        -- the tallest, and the emblem its least
        local realHeight = UIParent.GetHeight
        function UIParent:GetHeight() return 240 end
        ns.SetOption("characterDetails", true)
        frame()
        state("pvp.short")
        print("pvp.short fit", "emblem=" .. pv.emblemSize, "season " .. where(pv.season))
        UIParent.GetHeight = realHeight
        ns.SetOption("characterDetails", true)
        frame()

        page("statistics").tab.scripts.OnClick(page("statistics").tab)
        frame()
        state("stats.tab")
        rows("stats", "statistics")
        click("statistics", "Total kills")
        details("stats.chosen", "statistics")
        click("statistics", "Kills")
        rows("stats.folded", "statistics")
        tabs("stats.tabs")
    else
        print("char.retail pages", "skills=" .. tostring(page("skills").available), "pvp=" .. tostring(page("pvp")
            .available), "stats=" .. tostring(page("statistics").available))
    end
    HideUIPanel(CharacterFrame)
    harnessBeside("char tips", MedalluinCharacter)
    do
        local p = CharacterFeetSlot.parent
        local f = p and p.flyoutSettings
        print("char flyout", "parent ours=" .. tostring(p ~= PaperDollItemsFrame),
            "settings=" .. tostring(f and f ~= PaperDollItemsFrame.flyoutSettings),
            "shown over=" .. tostring(f and f.parent == p), "copied=" .. tostring(f and f.anchorY == -3 and f.hasPopouts))
    end
    do
        local gear = {}
        for _, n in ipairs({ "Head", "Chest", "MainHand", "Trinket0" }) do gear[_G["Character" .. n .. "Slot"]] = true end
        harnessBeside("char gear tips", MedalluinCharacter, nil, nil, gear)
        for b in pairs(gear) do gear[b] = "default" end
        harnessBeside("char gear default tips", MedalluinCharacter, nil, nil, gear)
    end
    harnessBeside("char tips, no width", MedalluinCharacter, true)
    state("char.end")
    return
end

-- the combat tint over the art's grey surface: hidden out of combat,
-- yellow in it, red with any threat, and on the art the group swaps in
local function fire(e, ...)
    for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
end
-- drawn over the art: the same frame and layer, a higher sublevel
local function over(t)
    for _, o in ipairs(t.parent.all_) do
        if o ~= t and o.kind == "Texture" and o.texture and o.texture:match("console%-%a+$")
            and o.layer == t.layer and (o.sub or 0) < (t.sub or 0) then return true end
    end
    return false
end
print("tint over the art", over(ns.tint))
print("tint blend", ns.tint:GetBlendMode())
local function tintState(tag)
    local t, vc = ns.tint, ns.tint.vertex
    print(string.format("tint %s: shown=%s colour=%s texture=%s", tag, tostring(t.shown),
        vc and string.format("%g,%g,%g@%g", vc[1], vc[2], vc[3], vc[4]) or "-",
        tostring(t.texture):match("[^\\]+$")))
end
local function threat(s)
    threatOf = s
    fire("UNIT_THREAT_SITUATION_UPDATE", "player")
end
tintState("out of combat")
inCombat = true
fire("PLAYER_REGEN_DISABLED")
tintState("in combat")
threat(1)
tintState("above the tank")
threat(0)
tintState("below the tank")
threat(3)
tintState("tanking")
if modern then
    threat(secret())
    tintState("secret threat")
end
inCombat = false
fire("PLAYER_REGEN_ENABLED")
tintState("combat over")
threat(2)
tintState("threat out of combat")
-- a reload in combat, with threat
inCombat = true
fire("PLAYER_ENTERING_WORLD")
tintState("reload in combat")
inCombat, threatOf = false, nil

if keybindPass then KeybindPass() end
if pagingPass then PagingPass() end
if editorPass then EditorPass() end

-- `look [bare] [modern]`: the Action Bar page's Text and Cooldowns options
-- on the first and last of the bar's buttons: at login, changed on the page,
-- keybind text hidden, and put back, where every line matches "login" again.
-- The overhead's buttons are not the bar's and keep their own.
if lookPass then
    local function show(tag)
        local function one(b)
            local hk = b.medalluinHotkey or b.HotKey or _G[b:GetName() .. "HotKey"]
            local cd = b.cooldown or _G[b:GetName() .. "Cooldown"]
            local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
            return string.format("%s keys=%s/alpha %s sweep=%s edge=%s flash=%s hideNumbers=%s numberSize=%s",
                b:GetName(), tostring((select(2, hk:GetFont()))), tostring(hk:GetAlpha()), tostring(cd.drawSwipe),
                tostring(cd.drawEdge), tostring(cd.drawBling), tostring(cd.hideNumbers),
                tostring(fs and (select(2, fs:GetFont()))))
        end
        print("look " .. tag, one(ns.actionButtons[1]))
        print("look " .. tag, one(ns.actionButtons[#ns.actionButtons]))
    end
    local function set(values)
        for _, kv in ipairs(values) do page.settings[kv[1]]:Set(kv[2]) end
    end
    show("login")
    set({ { "hotkeySize", 1.5 }, { "cooldownTextSize", 1.25 }, { "cooldownSwipe", false },
        { "cooldownEdge", true }, { "cooldownBling", false }, { "cooldownText", "hide" } })
    show("changed")
    set({ { "hotkeySize", 0 } })
    show("hidden keys")
    local other = ns.db.consoleProfile == "light" and "default" or "light"
    print("look saved", "here=" .. tostring(MedalluinDB.profiles[ns.db.consoleProfile].hotkeySize),
        other .. "=" .. tostring(MedalluinDB.profiles[other].hotkeySize))
    set({ { "hotkeySize", 1 }, { "cooldownTextSize", 1 }, { "cooldownSwipe", true },
        { "cooldownEdge", false }, { "cooldownBling", true }, { "cooldownText", "auto" } })
    show("back")
    print("look window stale=" .. optionsStale())
end

-- `move [light]`: the consoles' place and scale. The page's sliders, the
-- strips keeping their own size, the profile switch, Edit Mode's movers (a
-- drag, a click and its popup), and a change in combat waiting for it to end.
if movePass then
    local console, overhead = ns.console, ns.overhead
    local function where(f)
        local p = f.points[f.order[#f.order]] or f.points.BOTTOM or f.points.TOP
        local _, _, rp, x, y = f:GetPoint()
        return string.format("%s %.1f,%.1f scale=%.3f", tostring(rp), x or 0, y or 0, f:GetScale())
    end
    local function state(tag)
        print("move " .. tag, "console " .. where(console), "overhead " .. where(overhead),
            string.format("strip=%.3f stripOnScreen=%.3f", ns.strips[-1]:GetScale(), ns.strips[-1]:GetEffectiveScale()),
            "movers=" .. tostring(ns.consoleMovers.console and ns.consoleMovers.console:IsShown()) .. ","
                .. tostring(ns.consoleMovers.overhead and ns.consoleMovers.overhead:IsShown()),
            "popup=" .. tostring(MedalluinMoverPopup and MedalluinMoverPopup:IsShown() and MedalluinMoverPopup.title.text))
    end
    state("drawn")
    page.settings.consoleScale:Set(1.2)
    page.settings.consoleX:Set(120)
    page.settings.consoleY:Set(40)
    page.settings.overheadScale:Set(0.8)
    page.settings.overheadY:Set(-30)
    state("page")
    local other = ns.db.consoleProfile == "light" and "default" or "light"
    local here = ns.db.consoleProfile
    page.settings.consoleProfile:Set(other)
    state("other profile")
    page.settings.consoleProfile:Set(here)
    state("back")
    print("move saved", "here=" .. tostring(MedalluinDB.profiles[here].consoleScale) .. ","
        .. tostring(MedalluinDB.profiles[here].consoleX), other .. "=" .. tostring(MedalluinDB.profiles[other].consoleScale))

    EventRegistry:TriggerEvent("EditMode.Enter")
    state("edit mode")
    -- a drag: 60 design units right and 20 down, in screen pixels (UIParent's
    -- 768 high against the design's 1080)
    local px = 768 / 1080
    local realCursor = GetCursorPosition
    local cx, cy = 500, 300
    function GetCursorPosition() return cx, cy end
    local m = ns.consoleMovers.console
    m.scripts.OnMouseDown(m, "LeftButton")
    cx, cy = 500 + 60 * px, 300 - 20 * px
    m.scripts.OnUpdate(m)
    state("dragging")
    m.scripts.OnMouseUp(m, "LeftButton")
    state("dropped")
    print("move dropped saved", "x=" .. tostring(ns.db.consoleX), "y=" .. tostring(ns.db.consoleY))
    -- a click: no move, so the popup, with this console's sliders
    local o = ns.consoleMovers.overhead
    o.scripts.OnMouseDown(o, "LeftButton")
    o.scripts.OnUpdate(o)
    o.scripts.OnMouseUp(o, "LeftButton")
    state("clicked overhead")
    GetCursorPosition = realCursor
    local shown = {}
    for _, ctl in ipairs(MedalluinMoverPopup.controls) do
        table.insert(shown, ctl.spec.key .. "=" .. ctl.value.text)
    end
    print("move popup", table.concat(shown, " "))
    MedalluinMoverPopup.reset.scripts.OnClick(MedalluinMoverPopup.reset)
    state("popup reset")

    inCombat = true
    page.settings.consoleScale:Set(0.9)
    state("set in combat")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    state("combat over")
    EventRegistry:TriggerEvent("EditMode.Exit")
    state("edit mode closed")
    print("move window stale=" .. optionsStale())
end
if minimapPass then MinimapPass() end
if fadePass then FadePass() end

-- A refused aura read (console/auras.lua's Read): inside a secure call the
-- client errors on an aura it holds secret rather than return a secret. The
-- frame must not raise, must show what it read, and scans once more after.
if (args[2] == "auraguard" or args[3] == "auraguard") and C_UnitAuras then
    local timers = {}
    C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
    local function runTimers()
        local now = timers
        timers = {}
        for _, fn in ipairs(now) do fn() end
    end
    local refuse = false
    local saved = C_UnitAuras.GetAuraDataByIndex
    C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
        if refuse then error("Auras cannot be accessed when secret while tainted by 'Medalluin'") end
        if unit == "player" and filter == "HELPFUL|PLAYER" and i <= 2 then
            return { auraInstanceID = 900 + i, icon = 136000 + i, applications = 0, duration = 30,
                expirationTime = 60 }
        end
        return nil
    end
    local savedTimed = C_UnitAuras.DoesAuraHaveExpirationTime
    C_UnitAuras.DoesAuraHaveExpirationTime = function() return true end
    page.settings.auraBuffs:Set(true)
    local b = ns.units.player
    local function state(tag, ok, err)
        local n = 0
        for _, btn in ipairs(b.buffWidgets or {}) do if btn.shown then n = n + 1 end end
        print("auraguard " .. tag, "raised=" .. tostring(not ok) .. (ok and "" or " " .. tostring(err)),
            "buffs shown=" .. n, "rescans waiting=" .. #timers)
    end
    state("readable", pcall(ns.UpdateUnitAuras, b))
    refuse = true
    state("refused", pcall(ns.UpdateUnitAuras, b))
    refuse = false
    state("the rescan", pcall(runTimers))
    -- refused again on the rescan: no third try
    refuse = true
    pcall(ns.UpdateUnitAuras, b)
    state("refused twice", pcall(runTimers))
    refuse = false
    C_UnitAuras.GetAuraDataByIndex, C_UnitAuras.DoesAuraHaveExpirationTime = saved, savedTimed
end

-- The unit row in combat (console/overhead.lua's unitRow; the 2026-11-02
-- screenshot): the pet alone over a full pet bar, then the target's target
-- turns up mid-fight. The layout waits for combat to end, so the row lays
-- itself out: no cell over another, none wider than its own width.
if args[2] == "unitrow" or args[3] == "unitrow" then
    local function fireAll(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    -- a pass before may leave a layout waiting on combat's end
    inCombat = false
    fireAll("PLAYER_REGEN_ENABLED")
    page.settings.simParty:Set(false)
    page.settings.bossFrames:Set("vertical")
    page.settings.topFocus:Set(false)
    local exists = { pet = true }
    local realExists = UnitExists
    function UnitExists(u) return exists[u] or realExists(u) end
    petBar = true
    for i = 1, 10 do _G["PetActionButton" .. i].shown = true end
    local pet, tot = ns.overheadUnits.pet, ns.overheadUnits.targettarget
    -- in design pixels from the overhead's top centre, wherever the cell is
    -- anchored (the overhead out of combat, the row's header in it)
    local function span(b)
        if not b.points.TOPLEFT then return nil end
        local r, o = resolve(b), resolve(ns.overhead)
        local k = scaleOf(ns.overhead)
        local cx = (o[1] + o[3]) / 2
        local l, t = (r[1] - cx) / k, (r[2] - o[2]) / k
        return math.floor(l + 0.5), math.floor(l + 0.5) + b.w, math.floor(t + 0.5)
    end
    -- each shown cell's span; overlap: two share pixels; fits: the row stays
    -- inside the floor of the deck drawn under it
    local A = ns.overheadArt
    local function state(tag)
        -- the unit deck's floor, from the plate Layout drew
        local floorOf = 0
        for _, d in ipairs(ns.overheadDecks) do
            if d.shown and d.kind == "unit" then floorOf = 2 * d.half - 2 * A.deck.unit - 2 * A.margin end
        end
        local out, cells = {}, {}
        for _, b in ipairs({ pet, tot }) do
            if b.shown then
                local l, r, y = span(b)
                if l then table.insert(cells, { l, r }) end
                table.insert(out, l and string.format("%s=%d..%d(w%d,y%d)", b.unit, l, r, b.w, y)
                    or b.unit .. "=unplaced")
            end
        end
        local overlap = #cells < #out
            or (#cells == 2 and cells[1][2] > cells[2][1] and cells[2][2] > cells[1][1])
        local lo, hi = math.huge, -math.huge
        for _, c in ipairs(cells) do lo, hi = math.min(lo, c[1]), math.max(hi, c[2]) end
        local fits = #cells == 0 or hi - lo <= floorOf
        print("unitrow " .. tag, table.concat(out, " "), "floor=" .. floorOf, "overlap=" .. tostring(overlap),
            "fits=" .. tostring(fits))
    end
    ns.UpdateOverhead()
    state("pet alone")
    inCombat = true
    fireAll("PLAYER_REGEN_DISABLED")
    exists.targettarget = true
    harnessNextFrame()
    state("ToT in combat")
    exists.targettarget = nil
    harnessNextFrame()
    state("ToT gone in combat")
    exists.targettarget = true
    harnessNextFrame()
    inCombat = false
    fireAll("PLAYER_REGEN_ENABLED")
    state("combat over")
    -- out of combat the watch's show lays the whole overhead out at once
    exists.targettarget = nil
    harnessNextFrame()
    state("ToT gone")
    exists.targettarget = true
    harnessNextFrame()
    state("ToT back")
    -- under a boss: the row's top is the boss deck's foot, not the overhead's
    exists.targettarget = nil
    exists.boss1 = true
    page.settings.bossFrames:Set("overhead")
    harnessNextFrame()
    state("under a boss")
    inCombat = true
    fireAll("PLAYER_REGEN_DISABLED")
    exists.targettarget = true
    harnessNextFrame()
    state("under a boss, ToT in combat")
    inCombat = false
    fireAll("PLAYER_REGEN_ENABLED")
    state("under a boss, combat over")

    -- the command row alone, then the target's target turns up mid-fight
    -- (2026-11-05: it stood over the totems). The icons step down a deck
    -- under it and the plates follow; back up when it goes.
    page.settings.bossFrames:Set("vertical")
    exists.targettarget, exists.boss1, exists.pet = nil, nil, nil
    petBar, shapeshiftForms = false, 2
    harnessNextFrame()
    ns.UpdateOverhead()
    local function rowAt(tag)
        local decks = {}
        for _, d in ipairs(ns.overheadDecks) do
            if d.shown then table.insert(decks, d.kind .. "@" .. d.y .. "w" .. 2 * d.half) end
        end
        local icons = {}
        for _, b in ipairs({ StanceButton1, StanceButton2 }) do
            local l, _, y = span(b)
            table.insert(icons, l and (l .. "," .. y) or "unplaced")
        end
        local tot = tot.shown and select(3, span(tot))
        print("unitrow " .. tag, "decks=" .. table.concat(decks, " "), "icons=" .. table.concat(icons, " "),
            "tot=" .. tostring(tot))
    end
    local function rowAlone(tag)
        rowAt(tag)
        inCombat = true
        fireAll("PLAYER_REGEN_DISABLED")
        exists.targettarget = true
        harnessNextFrame()
        rowAt(tag .. ", ToT in combat")
        exists.targettarget = nil
        harnessNextFrame()
        rowAt(tag .. ", ToT gone in combat")
        exists.targettarget = true
        harnessNextFrame()
        inCombat = false
        fireAll("PLAYER_REGEN_ENABLED")
        rowAt(tag .. ", combat over")
        -- laid out with the deck: the last cell going takes it away again
        inCombat = true
        fireAll("PLAYER_REGEN_DISABLED")
        exists.targettarget = nil
        harnessNextFrame()
        rowAt(tag .. ", ToT gone in a new fight")
        inCombat = false
        fireAll("PLAYER_REGEN_ENABLED")
        rowAt(tag .. ", that fight over")
    end
    rowAlone("row alone")
    -- a row wider than the cell's deck: the deck over it is widened to
    -- stand a ledge out from the tray, as the layout draws it
    page.settings.topPet:Set(false)
    petBar, shapeshiftForms = true, 6
    for i = 1, 10 do _G["PetActionButton" .. i].shown = true end
    harnessNextFrame()
    ns.UpdateOverhead()
    rowAlone("wide row")
    -- and under a boss: the boss deck stays on top, the rest below it
    exists.boss1 = true
    page.settings.bossFrames:Set("overhead")
    harnessNextFrame()
    ns.UpdateOverhead()
    rowAlone("under a boss")
    exists.boss1 = nil
    page.settings.bossFrames:Set("vertical")
    page.settings.topPet:Set(true)
    exists.targettarget, exists.pet = nil, true
    petBar, shapeshiftForms = true, 0

    -- Test 3 of the 2026-11-03 disconnect: the pet frame and the pet bar both
    -- on, the pet dismissed on mounting and back on landing. The watch shows
    -- the pet from inside its walk; nothing may touch its list there.
    page.settings.bossFrames:Set("vertical")
    exists.targettarget, exists.boss1 = nil, nil
    harnessNextFrame()
    -- layouts run inside the watch's walk, and watches touched by a layout
    -- that changes nothing: both none
    local ovh, inWalk = ns.overhead, 0
    local realSize = ovh.SetSize
    ovh.SetSize = function(self, ...)
        if harnessWatchWalking() then inWalk = inWalk + 1 end
        return realSize(self, ...)
    end
    harnessWatchCalls = 0
    ns.UpdateOverhead()
    print("unitrow churn", "watch calls on a layout that changes nothing=" .. harnessWatchCalls)
    exists.pet = nil
    petBar = false
    for i = 1, 10 do _G["PetActionButton" .. i]:Hide() end
    fireAll("UNIT_PET", "player")
    harnessNextFrame()
    settleFades()
    state("mounted")
    exists.pet = true
    petBar = true
    harnessNextFrame()          -- the watch sees the pet before any event
    for i = 1, 10 do _G["PetActionButton" .. i]:Show() end
    fireAll("UNIT_PET", "player")
    fireAll("PET_BAR_UPDATE")
    harnessNextFrame()
    state("landed")
    harnessNextFrame()
    print("unitrow landed, frames", "layouts inside the walk=" .. inWalk,
        "layout still asked=" .. tostring(ns.overheadSoon.shown))
    ovh.SetSize = realSize
    page.settings.bossFrames:Set("overhead")

    -- A layout that asks for itself from inside (the 2026-11-03 disconnect's
    -- shape: a loop on the stack froze the client). Here the fade in asks
    -- again; the guard stops the second level, reports once, and the
    -- overhead is still laid out.
    local fadeIn = ns.OverheadFadeIn
    local asked = 0
    ns.OverheadFadeIn = function(...)
        asked = asked + 1
        if asked > 500 then error("runaway: the guard did not stop it") end
        ns.UpdateOverhead()
        return fadeIn(...)
    end
    local ok, err = pcall(ns.UpdateOverhead)
    print("unitrow runaway", "raised=" .. tostring(not ok) .. (ok and "" or " " .. tostring(err)), "asked=" .. asked)
    asked = 0
    pcall(ns.UpdateOverhead)
    print("unitrow runaway again", "asked=" .. asked .. " (reported once)")
    ns.OverheadFadeIn = fadeIn
    ns.UpdateOverhead()
    state("after the runaway")
end

-- ------------------------------------------------------------ the spellbook
if spellPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local B = ns.spellbook
    local w = _G.MedalluinSpellbook
    print("book", "window=" .. tostring(w ~= nil and B.layer ~= nil), "setting=" .. tostring(ns.db.spellbook))
    if not (w and B.layer) then return end
    local layer = B.layer
    local function where(r)
        local point, p = next(r.points)
        if not point then return "nowhere" end
        return string.format("%s %s %s %d,%d", point, p[1] and (p[1].name or (p[1] == r.parent and "parent")
            or "?") or "-", p[2] or "-", p[3] or 0, p[4] or 0)
    end
    local function frame()
        bookWorld.Tick()
        if w.shown and w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0) end
    end
    local function state(tag)
        local p = B.Current()
        print(tag, "shown=" .. tostring(w.shown), "blizzard=" .. tostring(PlayerSpellsFrame
            and PlayerSpellsFrame.shown), "page=" .. (p and p.key or "none"),
            "layer=" .. tostring(layer.shown) .. "/" .. tostring(layer.stateDrivers
            and layer.stateDrivers.visibility or "-"))
    end
    local function tabs(tag)
        local list = {}
        for _, p in ipairs(B.pages) do
            if p.tab and p.tab.shown then
                table.insert(list, (p.label ~= "" and p.label or p.key) .. "=" .. tostring(p.tab.icon.texture)
                    .. (p.tab.mark.shown and "*" or "") .. "@" .. p.tab.w)
            end
        end
        print(tag, table.concat(list, " "))
    end
    local function cells(tag)
        local p = B.Current()
        local list = {}
        for i, c in ipairs(p.cells) do
            if c.shown then
                local b = layer.buttons[i]
                local arm = b and b.shown and b.item == c.item
                    and ((b.attrs.type or "none") .. ":" .. tostring(b.attrs.spell)
                        .. (harnessOver(b, c) == "over" and "" or "!" .. harnessOver(b, c))) or "unarmed"
                if c.head.shown then
                    -- a heading: its title and count, and the tile under them
                    -- the tiles: how many show, where the first and last
                    -- sit, how wide, and the last one's crop
                    local at, n = select(2, next(c.title.points)) or {}, 0
                    for _, t in ipairs(c.tiles) do if t.shown then n = n + 1 end end
                    local t1, tn = c.tiles[1], c.tiles[n]
                    local function tile(t)
                        local q = t.points.TOPLEFT or {}
                        return string.format("%s@%d+%d[%.3f-%.3f,%.2f-%.2f]", tostring(t.texture), q[3] or -1,
                            t.w or 0, t.coords[1], t.coords[2], t.coords[3], t.coords[4])
                    end
                    table.insert(list, string.format("#%s(%s)[%s]cell=%d,w=%d,mouse=%s,shown=%s,title=%s %d,"
                        .. "tiles=%d/%d %s..%s %s@%s:%s", c.title.text, c.count.text, arm, i, c.w or 0,
                        tostring(c.mouse), table.concat({ tostring(c.icon.shown), tostring(c.name.shown),
                            tostring(c.sub.shown), tostring(c.edge.shown) }, ","), tostring(at[2] or at[1]), at[4] or 0,
                        n, #c.tiles, tile(t1), tile(tn), tostring(t1.desaturated), tostring(t1.alpha),
                        table.concat(t1.vertex or {}, ",")))
                else
                    table.insert(list, string.format("%s(%s,%.1f%s)[%s]", c.name.text, c.sub.text, c.icon.alpha or 1,
                        c.mark.shown and ",chosen" or "", arm))
                end
            end
        end
        local function button(b)
            return b.shown == false and "-" or (b.mark.shown and "on" or "off")
                .. (b.mouse == false and string.format("/grey %.1f %s", b.alpha or 1,
                    table.concat(b.label.textColor or {}, ",")) or "")
        end
        print(tag, "page=" .. p.at .. "/" .. p.pages, "band=ranks:" .. button(p.allRanks)
            .. ",trainer:" .. button(p.trainerButton), table.concat(list, " "))
    end
    local function details(tag)
        local p = B.Current()
        local texts = {}
        for _, r in ipairs(p.foot.all_ or {}) do
            if r.kind == "FontString" and r.shown ~= false and r.text and r.text ~= "" then
                table.insert(texts, r.text)
            end
        end
        print(tag, table.concat(texts, " | "))
    end
    local function pageOf(key)
        for _, p in ipairs(B.pages) do
            if p.key == key then return p end
        end
    end

    -- 1. at login: Blizzard's book not loaded, nothing parked, ours closed
    state("book.login")
    print("book.anchor", where(w), "parent=" .. tostring(w.parent == ns.strips[1]),
        "medal=" .. where(w.medal), "medalUV=" .. table.concat(w.medal.all_[1].coords or {}, ","))
    -- the layer on the strip where the window stands, anchored to the strip
    -- alone (never the window: see harnessOver)
    print("book.layer", "parent=" .. tostring(layer.parent == ns.strips[1]), "at=" .. where(layer),
        "onWindow=" .. tostring(layer.all == w))
    tabs("book.tabs")

    -- 2. the key loads Blizzard_PlayerSpells: its frame is parked and followed
    bookWorld.Toggle("spellbook")
    frame()
    print("book.loaded", "parked=" .. tostring(PlayerSpellsFrame.parent == ns.hidden))
    -- the first show: Blizzard's own toggle opens before it turns the tab
    state("book.open")
    harnessBeside("book open tips", MedalluinSpellbook)
    harnessBeside("book casts tips", MedalluinSpellbook, nil, MedalluinSpellbookCasts)
    print("book.backpack", tostring(MainMenuBarBackpackButton.strata) .. "/" .. tostring(MainMenuBarBackpackButton.level))
    tabs("book.tabs")
    cells("book.general")

    -- 3. a click casts through the layer and chooses the spell; with
    -- ActionButtonUseKeyDown on or off, the press casts nothing (a press is
    -- where a drag to a bar starts), the release casts (Forever's
    -- SecureActionButton_OnClick: the useOnKeyDown attribute, else the CVar)
    local b = layer.buttons[1]
    local function hears(down)
        for _, c in ipairs(b.clicks or {}) do
            if c == (down and "AnyDown" or "AnyUp") or c == (down and "LeftButtonDown" or "LeftButtonUp") then
                return true
            end
        end
        return false
    end
    for _, cvar in ipairs({ true, false }) do
        local use = b.attrs.useOnKeyDown
        if use == nil then use = cvar end
        print("book.press", "keydown=" .. tostring(cvar), "press casts=" .. tostring(hears(true) and use),
            "release casts=" .. tostring(hears(false) and not use))
    end
    b.scripts.PostClick(b, "LeftButton")
    cells("book.chosen")
    details("book.details")

    -- 4. the next tab
    local elem = pageOf("line2")
    elem.tab.scripts.OnClick(elem.tab)
    frame()
    state("book.elemental")
    cells("book.elemental")
    details("book.elemental details")

    -- 5. a short screen: fewer rows, the pager turns
    local height = UIParent.GetHeight
    UIParent.GetHeight = function() return 240 end
    w:SetHeight(240)
    elem.body.h = 2 * 40 + 4
    elem.Refresh()
    cells("book.short")
    elem.body.scripts.OnMouseWheel(elem.body, -1)
    cells("book.short next")
    elem.body.scripts.OnMouseWheel(elem.body, -1)
    cells("book.short past end")
    elem.body.scripts.OnMouseWheel(elem.body, 1)
    cells("book.short back")
    elem.body.scripts.OnMouseWheel(elem.body, -1)
    UIParent.GetHeight = height
    -- on page 2 when the window grows back: one page, and it is the first
    elem.body.h = 10 * 40
    elem.Refresh()
    cells("book.tall again")

    -- 6. a pet comes: a fifth tab, the row shared out again
    bookWorld.pet = 2
    fire("UNIT_PET", "player")
    tabs("book.pet tabs")
    local pet = pageOf("pet")
    pet.tab.scripts.OnClick(pet.tab)
    frame()
    cells("book.pet")
    -- and goes, while its page is open: back to the first
    bookWorld.pet = 0
    fire("UNIT_PET", "player")
    frame()
    tabs("book.pet gone")
    state("book.pet gone")

    -- 7. combat: the layer goes, the page still turns but nothing is re-armed
    local function combat(on)
        harnessHolds.combat = on or nil
        inCombat = on
        stateTick()
        if not on then fire("PLAYER_REGEN_ENABLED") end
    end
    elem.tab.scripts.OnClick(elem.tab)
    frame()
    combat(true)
    state("book.combat")
    local gen = pageOf("line1")
    gen.tab.scripts.OnClick(gen.tab)
    frame()
    cells("book.combat general")
    gen.cells[2].scripts.OnClick(gen.cells[2])
    cells("book.combat chosen")
    layer.buttons[1].scripts.OnDragStart(layer.buttons[1])
    print("book.combat drag", table.concat(bookWorld.calls, ","))
    combat(false)
    state("book.after combat")
    cells("book.after combat")
    layer.buttons[1].scripts.OnDragStart(layer.buttons[1])
    print("book.drag", table.concat(bookWorld.calls, ","))

    -- 8. the talents' tab: Blizzard's frame comes back under UIParent and
    -- our book closes; N with the book open, then N from closed with the
    -- book the last tab (the frame shows before it turns its tab)
    local function held(tag)
        state(tag)
        print(tag .. " frame", "parent=" .. (PlayerSpellsFrame.parent == ns.hidden and "hidden"
            or PlayerSpellsFrame.parent == UIParent and "UIParent" or "?"),
            "talents=" .. tostring(PlayerSpellsFrame.TalentsFrame.shown))
    end
    bookWorld.Toggle("talents")
    frame()
    held("book.talents")
    bookWorld.Toggle("talents")
    frame()
    held("book.talents closed")
    bookWorld.Toggle("spellbook")
    frame()
    bookWorld.Toggle("spellbook")
    held("book.book closed")
    local opened = {}
    hooksecurefunc(w, "Show", function() table.insert(opened, "book") end)
    bookWorld.Toggle("talents")
    frame()
    held("book.N from closed")
    print("book.N from closed", "ours opened=" .. #opened)
    bookWorld.Toggle("spellbook")
    frame()
    held("book.again")
    -- in combat the frame cannot be moved: the talents wait for its end
    combat(true)
    bookWorld.Toggle("talents")
    frame()
    held("book.combat talents")
    combat(false)
    held("book.after combat talents")
    bookWorld.Toggle("spellbook")
    frame()
    held("book.back to book")
    -- 8b. a tab turn that leaves the book's page marked shown: the tab is
    -- the record, so N still opens the talents and closes ours
    bookWorld.stale = true
    bookWorld.Toggle("talents")
    frame()
    held("book.stale talents")
    bookWorld.Toggle("spellbook")
    frame()
    held("book.stale book")
    bookWorld.stale = false
    -- 10. ranks, bars and the trainer. The bars: Lightning Bolt on one,
    -- Earth Shock in a macro on one, Rockbiter's lower rank on one
    local calls = {}
    C_ActionBar = C_ActionBar or {}
    C_ActionBar.FindSpellActionButtons = function(id)
        local out = {}
        for slot, a in pairs(actionSlots) do if a[1] == "spell" and a[2] == id then table.insert(out, slot) end end
        return out
    end
    function GetMacroSpell(i) return i == 7 and 202 or nil end
    C_Spell.PickupSpell = function(id)
        table.insert(calls, "pickup " .. id)
        cursor = { "spell", id }
    end
    local place = PlaceAction
    function PlaceAction(slot)
        table.insert(calls, "place " .. slot)
        place(slot)
    end
    local function bars(tag)
        local out = {}
        for slot = 1, 3 do
            local a = actionSlots[slot]
            table.insert(out, slot .. "=" .. (a and a[1] .. ":" .. tostring(a[2]) or "-"))
        end
        print(tag, table.concat(out, " "), "calls=" .. (#calls > 0 and table.concat(calls, ",") or "none"))
        calls = {}
    end
    actionSlots[1], actionSlots[2], actionSlots[3] = { "spell", 201 }, { "macro", "Shock" }, { "spell", 301 }
    -- the edges: red on no bar; a tooltip says so, or names the lower rank
    local function edges(tag)
        local p = B.Current()
        local out = {}
        local add = GameTooltip.AddLine
        for _, c in ipairs(p.cells) do
            if c.shown then
                local red = c.edge.color and c.edge.color[1] > 0.8
                local said
                GameTooltip.AddLine = function(_, t) said = t end
                c.scripts.OnEnter(c)
                table.insert(out, c.name.text .. (red and "!" or "") .. (c.miss.shown and "~" or "")
                    .. (red and "@" .. tostring(-c.edge.points.TOPLEFT[3]) or "") .. (said and "<" .. said .. ">" or ""))
            end
        end
        GameTooltip.AddLine = add
        print(tag, table.concat(out, " "))
    end
    elem.tab.scripts.OnClick(elem.tab)
    frame()
    cells("book.ranks elemental")
    edges("book.bars elemental")
    local enh = pageOf("line3")
    enh.tab.scripts.OnClick(enh.tab)
    frame()
    cells("book.ranks enhancement")
    edges("book.bars enhancement")
    -- every rank: both Rockbiters, and the future Earth Shock; the margin's
    -- All ranks is the same option, both ways
    enh.allRanks.scripts.OnClick(enh.allRanks)
    print("book.band all ranks", "option=" .. tostring(ns.db.spellbookAllRanks))
    cells("book.all ranks")
    edges("book.all ranks bars")
    elem.tab.scripts.OnClick(elem.tab)
    frame()
    cells("book.all ranks elemental")
    elem.allRanks.scripts.OnClick(elem.allRanks)
    print("book.band all ranks off", "option=" .. tostring(ns.db.spellbookAllRanks))
    -- no marks when asked for none
    ns.SetOption("spellbookMissing", false)
    edges("book.no marks")
    ns.SetOption("spellbookMissing", true)
    -- the chosen Rockbiter: its other rank named, its tick
    enh.tab.scripts.OnClick(enh.tab)
    frame()
    layer.buttons[1].scripts.PostClick(layer.buttons[1], "LeftButton")
    details("book.rockbiter")
    local tick = enh.details.ticks[1]
    print("book.tick", "shown=" .. tostring(tick.shown), "on=" .. tostring(tick.on), "enabled=" .. tostring(tick.enabled))
    -- Lightning Shield, one rank: no tick
    layer.buttons[2].scripts.PostClick(layer.buttons[2], "LeftButton")
    print("book.tick one rank", "shown=" .. tostring(tick.shown))
    layer.buttons[1].scripts.PostClick(layer.buttons[1], "LeftButton")
    -- ticked: the lower rank on the bar rises at once
    tick.scripts.OnClick(tick)
    bars("book.uprank ticked")
    print("book.uprank kept", tostring(MedalluinCharDB.upRank and MedalluinCharDB.upRank["Rockbiter Weapon"]))
    -- a busy cursor waits; combat waits for its end
    actionSlots[3] = { "spell", 301 }
    cursor = { "item", 6948 }
    fire("LEARNED_SPELL_IN_SKILL_LINE")
    bars("book.uprank busy")
    cursor = nil
    combat(true)
    fire("LEARNED_SPELL_IN_SKILL_LINE")
    bars("book.uprank combat")
    combat(false)
    bars("book.uprank after combat")
    -- unticked, nothing moves; every spell asked, it does
    tick.scripts.OnClick(tick)
    actionSlots[3] = { "spell", 301 }
    fire("LEARNED_SPELL_IN_SKILL_LINE")
    bars("book.uprank unticked")
    ns.SetOption("spellbookUpRankAll", true)
    bars("book.uprank all")
    print("book.tick all", "on=" .. tostring(tick.on), "enabled=" .. tostring(tick.enabled))
    ns.SetOption("spellbookUpRankAll", false)
    -- the trainer: no tab until one is read; then what is left to learn,
    -- now first, the filter put back as the box's tab had it
    tabs("book.no trainer")
    local services = {
        { "Rockbiter Weapon", "used", 9, 1, "Rank 3", 0 }, { "Flame Shock", "available", 8, 10, "Rank 1", 800 },
        { "Frost Shock", "unavailable", 7, 20, "Rank 1", 1500 }, { "Purge", "available", 6, 12, "", 900 },
        { "Lightning Shield", "available", 5, 8, "", 100 }, { "Ghost Wolf", "used", 4, 10, "", 0 },
        { "Earth Shock", "unavailable", 3, 30, "Rank 3", 2000 }, { "Rockbiter Weapon", "available", 9, 12, "Rank 4", 600 },
    }
    -- as the game: an empty list at TRAINER_SHOW, the services with the
    -- TRAINER_UPDATE after; the filter Blizzard's window left, Available only
    local tfilter = { available = true, unavailable = false, used = false }
    local arrived = false
    local function listed()
        local out = {}
        for _, v in ipairs(arrived and services or {}) do if tfilter[v[2]] then table.insert(out, v) end end
        return out
    end
    function GetNumTrainerServices() return #listed() end
    function GetTrainerServiceInfo(i) local v = listed()[i] if v then return v[1], v[2], v[3], v[4], v[5] end end
    function GetTrainerServiceCost(i) return listed()[i][6] end
    function GetTrainerServiceTypeFilter(t) return tfilter[t] end
    function SetTrainerServiceTypeFilter(t, on)
        if type(on) ~= "boolean" then error("Missing on/off parameter") end
        tfilter[t] = on
    end
    function IsTradeskillTrainer() return false end
    function UnitLevel() return 12 end
    fire("TRAINER_SHOW")
    tabs("book.trainer shown, empty")
    arrived = true
    fire("TRAINER_UPDATE")
    print("book.trainer read", "filter=" .. tostring(tfilter.available) .. "/" .. tostring(tfilter.unavailable)
        .. "/" .. tostring(tfilter.used))
    tabs("book.trainer tabs")
    -- no tab of its own: the margin's Trainer opens it, and goes back
    local tr = pageOf("trainer")
    print("book.trainer tab", tostring(tr.tab ~= nil))
    local from = B.Current()
    cells("book.band before trainer")
    from.trainerButton.scripts.OnClick(from.trainerButton)
    frame()
    print("book.band trainer", "current=" .. B.Current().key)
    tr.trainerButton.scripts.OnClick(tr.trainerButton)
    print("book.band back", "current=" .. B.Current().key, "same=" .. tostring(B.Current() == from))
    cells("book.band after trainer")
    from.trainerButton.scripts.OnClick(from.trainerButton)
    frame()
    cells("book.trainer")
    details("book.trainer summary")
    -- the first cell a heading: the first spell is the third
    -- All ranks on: still unmarked here, where it means nothing
    ns.SetOption("spellbookAllRanks", true)
    cells("book.trainer all ranks on")
    ns.SetOption("spellbookAllRanks", false)
    -- no secure buttons over a list that scrolls: the cells answer
    local armed = 0
    for _, b in ipairs(layer.buttons) do if b.shown then armed = armed + 1 end end
    print("book.trainer secure buttons", armed)
    tr.cells[3].scripts.OnEnter(tr.cells[3])
    print("book.trainer tooltip", tostring(GameTooltip.shown))
    tr.cells[3].scripts.OnClick(tr.cells[3])
    details("book.trainer chosen")
    -- a short body: the list scrolls, the bar at the left
    local function scrolled(tag)
        local bar, th = tr.scroller.bar, tr.scroller.bar.thumb
        print(tag, string.format("range=%d at=%.1f target=%.1f easing=%s bar=%s thumb=%.1f@%.1f", 
            tr.scroller.scroll:GetVerticalScrollRange(), tr.scroller.scroll:GetVerticalScroll(), tr.scroller.target or 0,
            tostring(tr.scroller.scroll.scripts.OnUpdate ~= nil), tostring(bar.shown), th.h or 0,
            th.points.TOP and th.points.TOP[4] or 0), "bar@" .. tostring(bar.points.TOPLEFT and bar.points.TOPLEFT[3]),
            "list@" .. tostring(tr.scroller.scroll.points.TOPLEFT[3]), "cells in list=" .. tostring(tr.cells[1].parent == tr.scroller.child))
    end
    scrolled("book.trainer tall")
    local trH = tr.body.h
    tr.body.h = 3 * 40
    tr.scroller.scroll.h = 3 * 40         -- the mock's GetHeight does not resolve anchors
    tr.Refresh()
    scrolled("book.trainer short")
    tr.body.scripts.OnMouseWheel(tr.body, -1)
    scrolled("book.trainer wheel")
    tr.scroller.scroll.scripts.OnUpdate(tr.scroller.scroll, 0.05)
    scrolled("book.trainer easing")
    for _ = 1, 40 do if tr.scroller.scroll.scripts.OnUpdate then tr.scroller.scroll.scripts.OnUpdate(tr.scroller.scroll, 0.05) end end
    scrolled("book.trainer eased")
    for _ = 1, 10 do tr.body.scripts.OnMouseWheel(tr.body, -1) end
    for _ = 1, 80 do if tr.scroller.scroll.scripts.OnUpdate then tr.scroller.scroll.scripts.OnUpdate(tr.scroller.scroll, 0.05) end end
    scrolled("book.trainer bottom")
    -- the bar pressed at its top: the list there at once, and following
    local cursorAt = GetCursorPosition
    -- the cursor in the screen's units, as the game gives it
    function GetCursorPosition() return 0, tr.scroller.bar:GetTop() * tr.scroller.bar:GetEffectiveScale() end
    tr.scroller.bar.scripts.OnMouseDown(tr.scroller.bar)
    scrolled("book.trainer bar pressed")
    function GetCursorPosition() return 0, tr.scroller.bar:GetBottom() * tr.scroller.bar:GetEffectiveScale() end
    tr.scroller.bar.scripts.OnUpdate(tr.scroller.bar, 0.05)
    scrolled("book.trainer bar dragged")
    tr.scroller.bar.scripts.OnMouseUp(tr.scroller.bar)
    print("book.trainer bar let go", tostring(tr.scroller.bar.scripts.OnUpdate ~= nil))
    GetCursorPosition = cursorAt
    tr.body.h, tr.scroller.scroll.h = trH, 0
    tr.Refresh()
    scrolled("book.trainer tall again")
    -- a level later: Frost Shock's time comes
    function UnitLevel() return 20 end
    tr.Refresh()
    cells("book.trainer level 20")
    details("book.trainer level 20 summary")
    -- a profession's trainer: its services kept by skill line, not the class's
    services = { { "Journeyman Mining", "available", 4, 10, "", 500 }, { "Smelt Tin", "available", 3, 0, "", 50 } }
    function IsTradeskillTrainer() return true end
    function GetTrainerServiceSkillLine() return "Mining" end
    function GetTrainerServiceSkillReq(i) return "Mining", ({ 50, 65 })[i] end
    fire("TRAINER_SHOW")
    local trade = {}
    for line, list in pairs(MedalluinCharDB.trainer.trade) do
        for key, e in pairs(list) do table.insert(trade, line .. ":" .. key .. "@" .. tostring(e.skill)) end
    end
    table.sort(trade)
    local class = 0
    for _ in pairs(MedalluinCharDB.trainer.class) do class = class + 1 end
    print("book.trade trainer", table.concat(trade, " "), "class=" .. class)
    -- 9. the close button
    w.close.scripts.OnClick(w.close)
    harnessBeside("book tips", MedalluinSpellbook)
    state("book.closed")
    print("book.backpack", tostring(MainMenuBarBackpackButton.strata) .. "/" .. tostring(MainMenuBarBackpackButton.level))
end

-- -------------------------------------------------------------- the talents
if talentPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local T = talentWorld
    local W = ns.talents
    local w = _G.MedalluinTalents
    print("talents", "window=" .. tostring(w ~= nil), "setting=" .. tostring(ns.db.talents))
    if not w then return end
    local book = _G.MedalluinSpellbook
    local function frame()
        bookWorld.Tick()
        if w.shown and w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0) end
    end
    local function where(r)
        local point, p = next(r.points)
        if not point then return "nowhere" end
        return string.format("%s %s %s %d,%d", point, p[1] and (p[1].name or (p[1] == r.parent and "parent")
            or "?") or "-", p[2] or "-", p[3] or 0, p[4] or 0)
    end
    local function state(tag)
        local p = W.Current()
        print(tag, "shown=" .. tostring(w.shown), "book=" .. tostring(book and book.shown),
            "blizzard=" .. tostring(PlayerSpellsFrame and PlayerSpellsFrame.shown),
            "parked=" .. tostring(PlayerSpellsFrame and PlayerSpellsFrame.parent == ns.hidden),
            "page=" .. (p and p.key or "none"))
    end
    local function tabs(tag)
        local list = {}
        for _, p in ipairs(W.pages) do
            if p.tab and p.tab.shown then
                table.insert(list, p.label .. "=" .. tostring(p.tab.icon.texture) .. (p.tab.mark.shown and "*" or "")
                    .. "@" .. p.tab.w .. "[" .. p.tip .. "]")
            end
        end
        print(tag, table.concat(list, " "))
    end
    local function c3(c) return c and string.format("%.2f", c[1]) or "-" end
    local function tree(tag)
        local p = W.Current()
        local list = {}
        for _, b in ipairs(p.nodes) do
            if b.shown and b.node then
                local pt = b.points.CENTER
                table.insert(list, string.format("%s@%d,%d %s%s edge=%s", b.talent.name, pt[3], -pt[4], b.rank.text,
                    b.icon.desaturated and " dim" or "", c3(b.edge.color))
                    .. (b.halo.shown and string.format(" halo=%.2f", b.halo.color[4]) or ""))
            end
        end
        print(tag, "body=" .. p.body.w .. "x" .. p.body.h, table.concat(list, " | "))
        local lines = {}
        for _, l in ipairs(p.edges) do
            if l.shown then
                table.insert(lines, l.from[2].talent.name .. ">" .. l.to[2].talent.name .. "(" .. c3(l.color) .. ")")
            end
        end
        print(tag .. " lines", table.concat(lines, " "))
    end
    local function foot(tag)
        local p = W.Current()
        local d = p.details
        print(tag, p.hint.shown and ("hint: " .. p.hint.text .. (d.nothing.shown and " +nothing" or "")
            .. (d.title.shown and " +details" or "")) or d.nothing.shown and ("nothing: " .. d.nothing.text)
            or (d.title.text .. " | " .. d.sub.text .. " | " .. d.text.text), "points=" .. p.points.text,
            "apply=" .. tostring(p.apply.shown) .. string.format("(%.1f)", p.apply.alpha or 1),
            "reset=" .. tostring(p.reset.shown))
        local specs = {}
        for _, b in ipairs(p.specs) do
            table.insert(specs, b.label.text .. (b.mark.shown and "*" or "") .. "(" .. c3(b.label.textColor)
                .. string.format(",%.1f)", b.alpha or 1))
        end
        print(tag .. " margin", table.concat(specs, " "), "activate=" .. tostring(p.activate.shown)
            .. string.format("(%.1f)", p.activate.alpha or 1), "calls=" .. table.concat(T.calls, ","))
    end
    local function node(name)
        for _, b in ipairs(W.Current().nodes) do
            if b.shown and b.talent.name == name then return b end
        end
    end
    local function click(name, button)
        local b = node(name)
        b.scripts.OnClick(b, button or "LeftButton")
        frame()
    end
    local function pageOf(key)
        for _, p in ipairs(W.pages) do
            if p.key == key then return p end
        end
    end

    -- a talent's tooltip, as its lines
    local function tip(tag, name)
        local lines = {}
        local set, add = GameTooltip.SetText, GameTooltip.AddLine
        GameTooltip.SetText = function(_, t, r) lines = { t .. string.format("(%.2f)", r or 1) } end
        GameTooltip.AddLine = function(_, t, r)
            table.insert(lines, t .. ((r or 1) ~= 1 and string.format("(%.2f)", r) or ""))
        end
        local b = node(name)
        b.scripts.OnEnter(b)
        GameTooltip.SetText, GameTooltip.AddLine = set, add
        print(tag, table.concat(lines, " | "), tipSpec())
    end
    -- the points' row: where it, its text and its buttons stand
    local function row(tag)
        local p = W.Current()
        local strip = p.points.parent
        print(tag, where(strip), "h=" .. strip.h, "body=" .. tostring(strip.parent == p.body),
            "reset=" .. where(p.reset), "points=" .. where(p.points), "apply=" .. where(p.apply))
    end

    -- 1. at login: a tab per tree, in the trees' order
    state("talents.login")
    print("talents.anchor", where(w), "parent=" .. tostring(w.parent == ns.strips[1]))
    tabs("talents.tabs")

    -- 2. N opens Blizzard's frame on its talents tab: ours shows, parked
    bookWorld.Toggle("talents")
    frame()
    state("talents.open")
    tree("talents.elemental")
    foot("talents.foot")

    -- 3. a click stages a rank; the details read the talent
    click("Concussion")
    tree("talents.staged")
    foot("talents.staged")
    row("talents.row")
    tip("talents.tip", "Concussion")
    tip("talents.tip words", "Convection")
    tip("talents.tip spell", "Elemental Mastery")
    -- a right-click takes it back; a locked talent stages nothing
    click("Concussion", "RightButton")
    click("Elemental Mastery")
    foot("talents.locked")
    -- two ranks, then Reset
    click("Concussion")
    click("Concussion")
    W.Current().reset.scripts.OnClick(W.Current().reset)
    frame()
    foot("talents.reset")
    -- a rank, then Apply
    click("Concussion")
    W.Current().apply.scripts.OnClick(W.Current().apply)
    fire("TRAIT_CONFIG_UPDATED", 1)
    frame()
    tree("talents.applied")
    foot("talents.applied")

    -- 4. the next tree
    local enh = pageOf("tree2")
    enh.tab.scripts.OnClick(enh.tab)
    frame()
    tree("talents.enhancement")
    tabs("talents.tabs")
    -- Enhancement's deepest talent stands inside the page
    do
        local p, low = W.Current(), 0
        for _, b in ipairs(p.nodes) do
            if b.shown and b.node then low = math.max(low, -b.points.CENTER[4] + 36 / 2) end
        end
        print("talents.inside", "lowest=" .. low, "body=" .. p.body.h, tostring(low <= p.body.h))
    end

    -- 5. Secondary: not learned, then learned; it reads, and Activate
    local sec = W.Current().specs[2]
    sec.scripts.OnClick(sec)
    frame()
    foot("talents.no secondary")
    click("Ancestral Knowledge")
    click("Ancestral Knowledge", "RightButton")
    foot("talents.no secondary click")
    T.groups = 2
    sec.scripts.OnClick(sec)
    frame()
    tree("talents.secondary")
    foot("talents.secondary")
    click("Ancestral Knowledge")
    foot("talents.secondary click")
    W.Current().activate.scripts.OnClick(W.Current().activate)
    T.active = 2
    fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    frame()
    foot("talents.activated")
    local prim = W.Current().specs[1]
    prim.scripts.OnClick(prim)
    frame()
    foot("talents.primary viewed")

    -- 6. combat: it reads, and changes nothing
    T.active = 1
    fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
    frame()
    -- the spec changed elsewhere: the window turns to the one in use
    prim.scripts.OnClick(prim)
    frame()
    T.active = 2
    fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    frame()
    foot("talents.swapped elsewhere")
    T.active = 1
    fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
    frame()
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    frame()
    click("Ancestral Knowledge")
    foot("talents.combat")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    frame()
    foot("talents.after combat")

    -- 7. the plan. Elemental, with Convection 5/5 and Concussion 1/3 learned
    local elemT = pageOf("tree1")
    elemT.tab.scripts.OnClick(elemT.tab)
    frame()
    -- the plans kept for a specialisation: each name, its talents, the
    -- active one starred
    local function plan(tag, spec)
        local b = MedalluinCharDB.talentPlans and MedalluinCharDB.talentPlans[spec or 1]
        local list = {}
        for k, kept in ipairs(b and b.list or {}) do
            local names = {}
            for _, id in ipairs(kept.steps) do table.insert(names, T.names[id]) end
            table.insert(list, kept.name .. (k == b.active and "*" or "") .. " " .. #names .. ": "
                .. table.concat(names, ", "))
        end
        print(tag, #list == 0 and "none" or table.concat(list, " / "))
    end
    local function strip(tag)
        local p = W.Current()
        print(tag, "points=" .. p.points.text, "plan=" .. (p.planRow.shown and "on" or "off"),
            "wash=" .. (p.wash.shown and table.concat(p.wash.color, ",") .. "@" .. (p.wash.all == p.body and "body"
                or "?") or "off"),
            "follow=" .. tostring(p.follow.shown) .. "@" .. where(p.follow),
            "checkpoint=" .. tostring(p.checkpoint.shown),
            "save=" .. tostring(p.save.shown) .. string.format("(%.1f)", p.save.alpha or 1) .. "@"
                .. (p.save.points.LEFT[1] == p.checkpoint and "checkpoint" or p.save.points.LEFT[1] == p.exit
                    and "exit" or "?"),
            "name=" .. (p.name.shown and tostring(p.name.text) or "off"),
            "hint=" .. (p.hint.shown and p.hint.text or p.details.nothing.shown and p.details.nothing.text or "-"))
    end
    local function press(b)
        b.scripts.OnClick(b, "LeftButton")
        frame()
    end
    -- the plan's mode on (Create Plan, on the plans' page, back to the
    -- tree it was opened from) or off (Exit plan)
    local function toggle()
        local p = W.Current()
        if p.planRow and p.planRow.shown then
            press(p.exit)
        else
            press(p.plans)
            press(pageOf("plans").create)
        end
    end
    -- Save plan, its name typed and Enter pressed
    local function save(name)
        press(elemT.save)
        local box = elemT.name
        print("talents.plan name offered", "shown=" .. tostring(box.shown), "text=" .. tostring(box.text),
            "focus=" .. tostring(box:HasFocus()), "highlighted=" .. tostring(box.highlighted))
        box:SetText(name)
        box.scripts.OnEnterPressed(box)
        frame()
    end
    -- Plan: a simulation from nothing, the talents learned (Convection 5/5,
    -- Concussion 1/3, Call of Flame) left out
    T.committed[1][3] = 1
    toggle()
    plan("talents.plan none kept")
    tree("talents.plan tree")
    -- the chrome: the points' row over the tree, the plan's in the foot
    -- (no chevron folds it), the buttons soft (each texture's alpha: edge,
    -- well, mark, glow), a hairline before Plans
    do
        local function face(b)
            local a = {}
            for _, t in ipairs({ b:GetRegions() }) do
                if t.color then table.insert(a, string.format("%.2f", t.color[4] or 1)) end
            end
            return table.concat(a, ",")
        end
        local function row(b)
            local host = b.parent.parent == elemT.foot and "foot" or b.parent.parent == elemT.body and "body" or "?"
            return host .. (b.parent.points.TOPLEFT and string.format("%d", -b.parent.points.TOPLEFT[4]) or "?")
        end
        print("talents.chrome", "exit@" .. row(elemT.exit), "checkpoint@" .. row(elemT.checkpoint),
            "save@" .. row(elemT.save), "name@" .. row(elemT.name), "points@" .. row(elemT.points),
            "reset@" .. row(elemT.reset), "apply@" .. row(elemT.apply), "follow@" .. row(elemT.follow),
            "face=" .. face(elemT.exit), "margin=" .. face(elemT.specs[1]),
            "rule=" .. (elemT.rule.w .. "x" .. elemT.rule.h .. " " .. (elemT.rule.points.LEFT[1] == elemT.specs[2]
                and "secondary" or "?") .. string.format(" %.2f", elemT.rule.color[4])),
            "plans@" .. (elemT.plans.points.LEFT[1] == elemT.rule and "rule" or "?") .. " "
                .. elemT.plans.points.LEFT[3])
        local hint = elemT.hint
        print("talents.chrome foot", "height=" .. elemT.footHeight, "shown=" .. tostring(elemT.foot.shown),
            "chevron=" .. tostring(W.window.chevron ~= nil), "hint@" .. tostring(hint.parent == elemT.foot and "foot"
                or "?") .. " " .. hint.points.TOPLEFT[3] .. "," .. hint.points.TOPLEFT[4] .. ">"
                .. hint.points.TOPRIGHT[3], "wrap=" .. tostring(hint.wrap))
    end
    strip("talents.plan fresh")
    -- the draft: Convection's points, of one talent only
    click("Convection")
    click("Convection")
    strip("talents.plan draft")
    click("Concussion")
    foot("talents.plan draft refused")
    tip("talents.plan draft tip", "Concussion")
    -- Save plan waits for the checkpoint
    press(elemT.save)
    strip("talents.plan save refused")
    -- the draft's own last point off, then on again, and every rank
    click("Convection", "RightButton")
    strip("talents.plan draft less")
    for _ = 1, 5 do click("Convection") end
    foot("talents.plan every rank")
    press(elemT.checkpoint)
    strip("talents.plan checkpoint")
    -- the gate: 8 points in Elemental (the condition's), 5 planned
    click("Elemental Mastery")
    foot("talents.plan gate why")
    tip("talents.plan tip", "Elemental Mastery")
    for _ = 1, 3 do click("Concussion") end
    press(elemT.checkpoint)
    click("Elemental Mastery")
    press(elemT.checkpoint)
    click("Call of Flame")
    tree("talents.plan full")
    strip("talents.plan full")
    -- a rank of Convection off its checkpoint: Call of Flame (the draft)
    -- needs it whole, and Elemental Mastery the gate's point, so both go
    click("Convection", "RightButton")
    tree("talents.plan cascade tree")
    strip("talents.plan cascade")
    -- Convection again: one point, its own checkpoint's run going on
    click("Convection")
    press(elemT.checkpoint)
    -- the cap: the top level less 9
    GetMaxLevelForPlayerExpansion = function() return 17 end
    click("Elemental Mastery")
    foot("talents.plan cap why")
    GetMaxLevelForPlayerExpansion = nil
    click("Elemental Mastery")
    press(elemT.checkpoint)
    -- the tiers' own gate where no condition says: Shamanistic Focus, six
    -- tiers down, wants 30 in Enhancement
    local enhT = pageOf("tree2")
    enhT.tab.scripts.OnClick(enhT.tab)
    frame()
    click("Shamanistic Focus")
    foot("talents.plan tier gate")
    elemT.tab.scripts.OnClick(elemT.tab)
    frame()
    -- nothing kept until Save plan: the name offered, Enter keeps it
    plan("talents.plan unsaved")
    save("Fire")
    plan("talents.plan saved")
    strip("talents.plan saved")
    -- Escape keeps nothing; a blank name keeps nothing
    press(elemT.save)
    elemT.name.scripts.OnEscapePressed(elemT.name)
    frame()
    strip("talents.plan escaped")
    save("   ")
    plan("talents.plan blank")
    -- a point added while the name is asked for: Enter keeps nothing until
    -- it is checkpointed
    press(elemT.save)
    click("Call of Flame")
    elemT.name:SetText("Draft")
    elemT.name.scripts.OnEnterPressed(elemT.name)
    frame()
    plan("talents.plan draft unsaved")
    click("Call of Flame", "RightButton")
    -- the box goes with the mode
    press(elemT.save)
    toggle()
    strip("talents.plan box left")
    toggle()
    -- out of the mode: the active plan's glow, the next brightest; Follow
    -- stages the next entries for Apply
    elemT.chosen = nil
    toggle()
    tree("talents.plan glow")
    strip("talents.plan next")
    T.calls = {}
    press(elemT.follow)
    tree("talents.followed")
    strip("talents.followed")
    foot("talents.followed")
    press(elemT.reset)
    -- one point left: Follow stages one
    local points = T.points
    T.points = T.points - 4       -- 7 spent: one left
    T.calls = {}
    press(elemT.follow)
    print("talents.followed one", table.concat(T.calls, ","))
    press(elemT.reset)
    T.points = points
    -- talents staged are not the plan's: Apply and Reset wait out the mode
    click("Concussion")
    toggle()
    foot("talents.plan staged")
    toggle()
    press(elemT.reset)
    -- unsaved work is lost: leaving the mode, closing the window, or
    -- viewing the other specialisation
    toggle()
    click("Concussion")
    toggle()
    toggle()
    strip("talents.plan left unsaved")
    click("Concussion")
    W.window:Hide()
    W.window:Show()
    frame()
    strip("talents.plan window closed")
    T.groups = 2
    toggle()
    click("Concussion")
    local sec2 = W.Current().specs[2]
    press(sec2)
    strip("talents.plan secondary")
    plan("talents.plan kept still")
    -- its own plans; Follow stages nothing in talents not in use
    toggle()
    click("Convection")
    press(elemT.checkpoint)
    save("Water")
    toggle()
    T.calls = {}
    press(elemT.follow)
    print("talents.plan secondary follow", "calls=" .. table.concat(T.calls, ","))
    plan("talents.plan secondary kept", 2)
    local prim2 = W.Current().specs[1]
    press(prim2)
    -- Plans: the plans kept and the active one's checkpoints, no tab
    local ord = pageOf("plans")
    print("talents.plans tab", tostring(ord.tab ~= nil))
    press(elemT.plans)
    local function plans(tag)
        local p = W.Current()
        local list = {}
        -- heads and checkpoints in the list's order, each at its top
        for _, h in ipairs(p.heads) do
            if h.shown then
                table.insert(list, { -h.points.TOPLEFT[4], string.format("[%s %s%s | %s%s]@%d",
                    (h.fold.rotation or 0) == 0 and "v" or ">", h.name.text, "(" .. c3(h.name.textColor) .. ")", h.count.text, h.use.shown and " Use" or "", -h.points.TOPLEFT[4]) })
            end
        end
        for _, l in ipairs(p.labels) do
            if l.shown then
                table.insert(list, { -l.points.TOPLEFT[4], string.format("{%s|%s|%s|%s|%s}@%d", l.at.text, l.name.text,
                    l.goal.text, l.progress.text, l.spec.text, -l.points.TOPLEFT[4]) })
            end
        end
        for _, r in ipairs(p.rows) do
            if r.shown then
                table.insert(list, { -r.points.TOPLEFT[4], string.format("%s|%s|%s|%s|%s%s a%.2f@%d", r.at.text, r.name.text,
                    r.goal.text, (r.progress.shown and r.progress.text or "") .. (r.tick.shown and "✓" or ""),
                    tostring(r.spec.texture), r.mark.shown and " <" or "", r.alpha or 1, -r.points.TOPLEFT[4]) })
            end
        end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        for k, e in ipairs(list) do list[k] = e[2] end
        print(tag, "page=" .. p.key, "list@" .. string.format("%d", -p.list.scroll.parent.points.TOPLEFT[4]),
            "edit=" .. tostring(p.edit.shown) .. "@" .. (p.edit.parent.parent == p.foot and "foot" or "?")
                .. string.format("%d", -p.edit.parent.points.TOPLEFT[4]),
            "remove=" .. tostring(p.remove.shown) .. "(" .. p.remove.label.text .. ")",
            "plans=" .. tostring(p.plans.mark.shown), "rows: " .. table.concat(list, "; "))
        print(tag .. " foot", p.hint.text, "foot=" .. p.footHeight .. "/" .. tostring(p.foot.shown))
    end
    plans("talents.plans")
    -- a short window: the list scrolls under the wheel
    local ordH = ord.body.h
    ord.body.h = 120
    ord.list.scroll.h = 120 - 26
    ord.Refresh()
    local area = ord.list.scroll.parent
    area.scripts.OnMouseWheel(area, -1)
    print("talents.plans scroll", "range=" .. ord.list.scroll:GetVerticalScrollRange(), "target=" .. ord.list.target,
        "bar=" .. tostring(ord.list.bar.shown))
    ord.list.To(0, true)
    ord.body.h, ord.list.scroll.h = ordH, 0
    ord.Refresh()
    -- a checkpoint's row opens its talent's tree, the talent chosen
    press(ord.rows[2])
    foot("talents.plans opened")
    -- Plans from Enhancement, and back to it
    enhT.tab.scripts.OnClick(enhT.tab)
    frame()
    press(W.Current().plans)
    press(ord.plans)
    print("talents.plans back", "page=" .. W.Current().key)
    -- Edit: the active plan drawn again; saved under a new name, a second
    -- plan, the active one
    press(W.Current().plans)
    press(ord.edit)
    strip("talents.plan edit")
    print("talents.plan edit page", W.Current().key)
    elemT.tab.scripts.OnClick(elemT.tab)
    frame()
    -- opened at its last checkpoint: Elemental Mastery is the draft, and
    -- another talent waits for its Checkpoint
    click("Concussion")
    foot("talents.plan edit locked")
    click("Concussion", "RightButton")
    strip("talents.plan edited")
    save("Frost")
    plan("talents.plan saved as")
    -- the same name replaces
    click("Call of Flame")
    press(elemT.checkpoint)
    -- a step in another tree: its row wears that tree's icon
    enhT.tab.scripts.OnClick(enhT.tab)
    frame()
    click("Ancestral Knowledge")
    press(enhT.checkpoint)
    elemT.tab.scripts.OnClick(elemT.tab)
    frame()
    save("Fire")
    plan("talents.plan replaced")
    toggle()
    -- each plan under its head; Use makes another active
    press(elemT.plans)
    plans("talents.plans two")
    press(ord.heads[2].use)
    plans("talents.plans chosen")
    -- a head folds its checkpoints away, and back; kept with the plan
    press(ord.heads[1])
    plans("talents.plans folded")
    print("talents.plans folded kept", tostring(MedalluinCharDB.talentPlans[1].list[1].collapsed))
    press(ord.heads[1])
    plans("talents.plans unfolded")
    -- Remove asks twice; leaving disarms it. The first plan removed, none
    -- is active
    press(ord.heads[1].use)
    press(ord.remove)
    plans("talents.plans remove armed")
    ord.remove.scripts.OnLeave(ord.remove)
    press(ord.remove)
    press(ord.remove)
    plans("talents.plans removed")
    plan("talents.plans removed kept")
    press(ord.heads[1].use)
    press(ord.remove)
    press(ord.remove)
    plans("talents.plans none")
    -- the one plan of before becomes "Plan", active
    MedalluinCharDB.talentPlans = nil
    local id = {}
    for k, name in pairs(T.names) do id[name] = k end
    MedalluinCharDB.talentPlan = { { id.Convection, id.Convection, id.Concussion, id.Concussion } }
    ord.Refresh()
    plans("talents.plans migrated")
    print("talents.plans migrated old", tostring(MedalluinCharDB.talentPlan[1]))
    -- Edit reopens the whole last checkpoint: both Concussion ranks are the
    -- draft, so one off leaves one to checkpoint
    press(ord.edit)
    elemT.tab.scripts.OnClick(elemT.tab)
    frame()
    click("Concussion", "RightButton")
    strip("talents.plan edit run")
    toggle()
    press(elemT.plans)
    enhT.tab.scripts.OnClick(enhT.tab)
    frame()

    -- 8. the book takes the frame, and the talents take it back
    bookWorld.Toggle("spellbook")
    frame()
    state("talents.book")
    bookWorld.Toggle("talents")
    frame()
    state("talents.again")
    w.close.scripts.OnClick(w.close)
    frame()
    state("talents.closed")

    -- 8b. in combat the frame cannot be moved: left under UIParent (the
    -- specialisations' tab, not ours), the talents asked for in combat
    -- leave it unseen, and parked at the fight's end
    local function spells(tag)
        state(tag)
        print(tag .. " frame", "parent=" .. (PlayerSpellsFrame.parent == ns.hidden and "hidden"
            or PlayerSpellsFrame.parent == UIParent and "UIParent" or "?"),
            "alpha=" .. PlayerSpellsFrame:GetAlpha())
    end
    ShowUIPanel(PlayerSpellsFrame)
    PlayerSpellsFrame:TrySetTab(1)
    frame()
    HideUIPanel(PlayerSpellsFrame)
    frame()
    spells("talents.specs left")
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    bookWorld.Toggle("talents")
    frame()
    spells("talents.combat N")
    -- turned to a tab not ours in combat, it is seen again; back, unseen
    PlayerSpellsFrame:TrySetTab(1)
    frame()
    spells("talents.combat specs")
    PlayerSpellsFrame:TrySetTab(2)
    frame()
    spells("talents.combat talents again")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    frame()
    spells("talents.combat N ended")
    HideUIPanel(PlayerSpellsFrame)
    frame()
    -- entering the world in combat (a reload mid-fight) leaves the load to
    -- the first N; the mock forgets it loaded, and is told again after
    bookWorld.loaded = false
    inCombat = true
    fire("PLAYER_ENTERING_WORLD")
    print("talents.world in combat", "loaded=" .. tostring(bookWorld.loaded))
    inCombat = false
    bookWorld.loaded = true

    -- 9. Forever's own N with another panel open (the parked character
    -- frame): Blizzard minimises the frame onto the book; ours turns it back
    bookWorld.others = true
    PlayerSpellsUtil.TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.ClassTalents)
    frame()
    state("talents.N minimised")
    PlayerSpellsUtil.TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.ClassTalents)
    frame()
    state("talents.N again")
    -- the book's own toggle is left on the book
    PlayerSpellsUtil.TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.SpellBook)
    frame()
    state("talents.P minimised")
    HideUIPanel(PlayerSpellsFrame)
    PlayerSpellsUtil.OpenToClassTalentsTab()
    frame()
    state("talents.opened to")
    harnessBeside("talents tips", MedalluinTalents)
    HideUIPanel(PlayerSpellsFrame)
    frame()
    bookWorld.others = false
end

if profPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local P = profWorld
    local W = ns.professions
    local w = _G.MedalluinProfessions
    print("prof", "window=" .. tostring(w ~= nil), "setting=" .. tostring(ns.db.professions))
    if not w then return end
    local layer = W.layer
    local book = _G.MedalluinSpellbook
    local function frame()
        bookWorld.Tick()
        if w.shown and w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0) end
    end
    local function where(r)
        local point, p = next(r.points)
        if not point then return "nowhere" end
        return string.format("%s %s %s %d,%d", point, p[1] and (p[1].name or (p[1] == r.parent and "parent")
            or "?") or "-", p[2] or "-", p[3] or 0, p[4] or 0)
    end
    local function state(tag)
        local p = W.Current()
        print(tag, "shown=" .. tostring(w.shown), "book=" .. tostring(book and book.shown),
            "blizzard=" .. tostring(ProfessionsFrame and ProfessionsFrame.shown),
            "parked=" .. tostring(ProfessionsFrame and ProfessionsFrame.parent == ns.hidden),
            "spells=" .. tostring(PlayerSpellsFrame and PlayerSpellsFrame.shown),
            "page=" .. (p and p.key or "none"), "layer=" .. tostring(layer.shown))
    end
    local function tabs(tag)
        local list = {}
        for _, p in ipairs(W.pages) do
            if p.tab and p.tab.shown then
                -- a row's first tab says where the row stands
                local at, _, _, _, y = p.tab:GetPoint()
                table.insert(list, p.label .. "=" .. tostring(p.tab.icon.texture):gsub(".*\\", "")
                    .. (p.tab.mark.shown and "*" or "") .. "@" .. p.tab.w
                    .. (at == "TOPLEFT" and ("," .. y) or ""))
            end
        end
        local _, _, _, _, top = W.Current().body:GetPoint()
        -- open tabs: no box (a face over the mark), the rows on hairs
        local hairs = {}
        for _, h in ipairs(W.window.hairs or {}) do
            local _, _, _, _, hy = h:GetPoint()
            table.insert(hairs, h.shown and tostring(hy) or "hidden")
        end
        print(tag, table.concat(list, " "), "top=" .. top, "chevron=" .. tostring(W.window.chevron ~= nil),
            "open=" .. tostring(W.pages[1].tab.top ~= nil and W.window.close.top ~= nil),
            "hairs=" .. table.concat(hairs, ","))
    end
    local function c3(c) return c and string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) or "-" end
    local function pageOf(key)
        for _, p in ipairs(W.pages) do
            if p.key == key then return p end
        end
    end
    local function cards(tag)
        for i, c in ipairs(pageOf("overview").cards) do
            if c.shown then
                -- a pillar's spells by their x across it, a line's by their
                -- place from the right
                local spells = {}
                for _, sp in ipairs(c.spells) do
                    if sp.shown then
                        local at = sp.points.TOPLEFT or sp.points.RIGHT
                        table.insert(spells, sp.slot .. "@" .. at[3] .. (at[1] == c.unlearn and "<x" or ""))
                    end
                end
                local _, _, _, x, y = c:GetPoint()
                local rank = c.rank.text ~= "" and (c.rank.text .. "(" .. c3(c.rank.textColor) .. ")"
                    .. (c.rank.shown and ((c.rank.points.TOP or {})[1] == c.bar and "" or "!loose") or ":tip"))
                    or "rank=-"
                print(tag .. i, (c.pillar and "pillar" or "line") .. string.format("@%d,%d", x, y)
                    .. (c.pillar and ("w" .. c.w) or "") .. (c.hair and c.hair.shown and "~" or ""),
                    c.name.text, c.icon.desaturated and "dim" or "lit",
                    c.bar.shown and (c.bar.text.text .. (c.bar.points.RIGHT and ">" .. tostring(
                        c.bar.points.RIGHT[1] == c.unlearn and "x" or c.bar.points.RIGHT[1] == c.spells[1] and "s1"
                        or c.bar.points.RIGHT[1] == c.spells[2] and "s2" or "?") or ""))
                        or ("none: " .. c.none.text),
                    rank, "spells=" .. table.concat(spells, ","), "unlearn=" .. tostring(c.unlearn.shown))
            end
        end
        local secure = {}
        for _, b in ipairs(layer.buttons) do
            if b.shown then
                table.insert(secure, b.attrs.type .. ":" .. tostring(b.attrs.spell)
                    .. (harnessOver(b, b.cell) == "over" and "" or "!" .. harnessOver(b, b.cell)))
            end
        end
        print(tag .. " layer", "parent=" .. tostring(layer.parent == ns.strips[1]),
            "driver=" .. tostring(layer.stateDrivers and layer.stateDrivers.visibility), table.concat(secure, " "))
    end
    local function rows(tag)
        local p = W.Current()
        local list = {}
        for _, r in ipairs(p.list.rows) do
            if r.shown then
                table.insert(list, (r.data.header and (r.sign.text .. r.label.text)
                    or (r.label.text .. "(" .. c3(r.label.textColor) .. ")" .. (r.value.shown and r.value.text or "")
                    .. (r.mark.shown and "*" or ""))))
            end
        end
        print(tag, #list > 0 and table.concat(list, " | ") or ("empty: " .. p.list.empty.text))
    end
    local function foot(tag)
        local p = W.Current()
        local d = p.details
        -- the tree: its rows, then "> product" at the stem's x and row
        local tree = {}
        if p.tree.shown then
            for _, fs in ipairs(p.tree.lines) do
                if fs.shown then table.insert(tree, fs.text) end
            end
            local _, _, _, sx, sy = p.tree.stem:GetPoint()
            local _, _, _, ax, ay = p.tree.arm:GetPoint()
            local _, _, _, px, py = p.tree.product:GetPoint()
            table.insert(tree, string.format("stem@%d,%d h%d arm@%d,%d > %s@%d,%d", sx, sy, p.tree.stem.h, ax, ay,
                p.tree.product.text, px, py))
        end
        print(tag, d.nothing.shown and ("nothing: " .. d.nothing.text)
            or (d.title.text .. " | " .. d.sub.text .. " | " .. d.text.text:gsub("\n", "; ")
                .. (#tree > 0 and " | " .. table.concat(tree, "; ") or "")),
            "tick=" .. tostring(p.have.on), "count=" .. p.counter.text,
            string.format("create=%.1f all=%.1f", p.create.alpha or 1, p.createAll.alpha or 1),
            "calls=" .. table.concat(P.calls, ","))
    end
    local function row(label)
        for _, r in ipairs(W.Current().list.rows) do
            if r.shown and r.label.text == label then
                r.scripts.OnClick(r, "LeftButton")
                frame()
                return
            end
        end
        print("no row " .. label)
    end
    local function click(b)
        b.scripts.OnClick(b, "LeftButton")
        frame()
    end

    -- 1. at login: Overview and a tab per profession that crafts (Fishing none)
    state("prof.login")
    print("prof.anchor", where(w), "parent=" .. tostring(w.parent == ns.strips[1]))
    tabs("prof.tabs")

    -- 2. the key loads Blizzard_Professions on its book: parked, Overview
    P.Toggle()
    frame()
    state("prof.open")
    cards("prof.card")
    -- a spell's secure button casts; Unlearn asks Blizzard's question
    click(pageOf("overview").cards[2].unlearn)
    print("prof.unlearn", table.concat(P.calls, ","))
    P.calls = {}
    -- in combat the cross asks nothing
    inCombat = true
    click(pageOf("overview").cards[2].unlearn)
    print("prof.unlearn combat", table.concat(P.calls, ","))
    inCombat = false
    P.calls = {}

    -- 2b. the next rank: red near the cap, dim when the level or skill is
    -- short, none at the expansion's top; a trainer's list says instead
    local function card(tag, i)
        local c = pageOf("overview").cards[i]
        fire("SKILL_LINES_CHANGED")
        frame()
        print(tag, c.name.text, c.bar.text.text, c.rank.shown and (c.rank.text .. "(" .. c3(c.rank.textColor) .. ")")
            or "rank=-")
    end
    local smithInfo = P.info[1]
    P.info[1] = { "Blacksmithing", 136241, 145, 150, 1, 50, 164, 0 }
    card("prof.rank cap", 1)
    P.info[1] = { "Blacksmithing", 136241, 144, 150, 1, 50, 164, 0 }
    card("prof.rank under cap", 1)
    P.info[1] = { "Blacksmithing", 136241, 124, 150, 1, 50, 164, 0 }
    card("prof.rank skill short", 1)
    P.info[1] = { "Blacksmithing", 136241, 30, 75, 1, 50, 164, 0 }
    card("prof.rank journeyman", 1)
    local level = UnitLevel
    UnitLevel = function() return 19 end
    P.info[1] = { "Blacksmithing", 136241, 130, 150, 1, 50, 164, 0 }
    card("prof.rank level short", 1)
    UnitLevel = level
    P.info[1] = { "Blacksmithing", 136241, 290, 300, 1, 50, 164, 0 }
    card("prof.rank top", 1)
    GetMaxLevelForPlayerExpansion = function() return 70 end
    card("prof.rank master", 1)
    GetMaxLevelForPlayerExpansion = function() return 80 end
    P.info[1] = { "Blacksmithing", 136241, 370, 375, 1, 50, 164, 0 }
    card("prof.rank grand master", 1)
    GetMaxLevelForPlayerExpansion = nil
    MedalluinCharDB.trainer = { class = {}, trade = { Blacksmithing = {
        ["Blacksmithing|Expert"] = { name = "Blacksmithing", rank = "Expert", level = 22, skill = 130, icon = 1 } } } }
    P.info[1] = { "Blacksmithing", 136241, 128, 150, 1, 50, 164, 0 }
    card("prof.rank trainer", 1)
    P.info[1] = { "Blacksmithing", 136241, 131, 150, 1, 50, 164, 0 }
    card("prof.rank trainer met", 1)
    MedalluinCharDB.trainer = nil
    P.info[1] = smithInfo
    card("prof.rank back", 1)

    -- 3. Blacksmithing's tab opens it: the crafting page follows
    local smith = pageOf("craft1")
    click(smith.tab)
    print("prof.opened", table.concat(P.calls, ","))
    P.calls = {}
    rows("prof.waiting")
    P.Show(164)
    frame()
    state("prof.smith")
    rows("prof.rows")
    foot("prof.none chosen")

    -- 4. a recipe chosen: its reagents; the count, Create, Create all
    row("Copper Chain Pants")
    rows("prof.chosen")
    foot("prof.pants")
    -- the craft buttons along the foot's bottom, under the tree; the tick in the band
    print("prof.foot", "height=" .. smith.footHeight, "create in foot=" .. tostring(smith.create.parent == smith.foot),
        "have in band=" .. tostring(smith.have.parent == smith.band))
    click(smith.create)
    for _ = 1, 3 do click(smith.more) end
    foot("prof.count 4")
    click(smith.createAll)
    foot("prof.created")
    P.calls = {}
    row("Heavy Copper Maul")
    foot("prof.maul")
    click(smith.create)
    print("prof.no craft", table.concat(P.calls, ","))
    row("Rough Sharpening Stone")
    foot("prof.stone")

    -- 5. the filters: Have materials, the search, a heading folded
    click(smith.have)
    rows("prof.makeable")
    click(smith.have)
    smith.search:SetText("copper")
    smith.search.scripts.OnTextChanged(smith.search)
    rows("prof.search")
    smith.search:SetText("")
    smith.search.scripts.OnTextChanged(smith.search)
    row("Armor")
    rows("prof.folded")
    row("Armor")

    -- 5b. favourites: a right-click stars a recipe, listed first and not
    -- again in its category; its tooltip says so
    local tipLines = {}
    local addLine = GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) table.insert(tipLines, tostring(t)) end
    local function rowOf(label)
        for _, r in ipairs(W.Current().list.rows) do
            if r.shown and r.label.text == label then return r end
        end
    end
    local function hint(label)
        tipLines = {}
        local r = rowOf(label)
        r.scripts.OnEnter(r)
        r.scripts.OnLeave(r)
        print("prof.hint " .. label, table.concat(tipLines, ";"))
    end
    hint("Copper Bracers")
    local function right(label)
        local r = rowOf(label)
        if not r then print("no row " .. label) return end
        r.scripts.OnClick(r, "RightButton")
        frame()
    end
    right("Copper Bracers")
    rows("prof.starred")
    hint("Copper Bracers")
    print("prof.favourites", tostring(MedalluinCharDB.recipeFavourites and MedalluinCharDB.recipeFavourites[2663]),
        "chosen=" .. tostring(smith.chosen))
    right("Heavy Copper Maul")
    rows("prof.starred two")
    row("Favourites")
    rows("prof.favourites folded")
    row("Favourites")
    right("Copper Bracers")
    right("Heavy Copper Maul")
    rows("prof.unstarred")
    -- the skill-up line: greys at, points a craft, none left
    row("Copper Chain Pants")
    foot("prof.worth pants")
    row("Copper Bracers")
    foot("prof.worth trivial")
    row("Rough Sharpening Stone")
    foot("prof.worth no skill-up")

    -- 5c. at the trainer: the services not learned, those allowed first
    MedalluinCharDB.trainer = { class = {}, trade = { Blacksmithing = {
        ["Copper Mace|"] = { name = "Copper Mace", level = 1, skill = 15, cost = 100, icon = 11 },
        ["Copper Bracers|"] = { name = "Copper Bracers", level = 1, skill = 1, cost = 10, icon = 12 },
        ["Copper Axe|"] = { name = "Copper Axe", level = 1, skill = 35, cost = 50, icon = 13, known = true },
        ["Iron Buckle|"] = { name = "Iron Buckle", level = 1, skill = 150, cost = 900, icon = 14 },
        ["Silver Rod|"] = { name = "Silver Rod", level = 40, skill = 100, cost = 500, icon = 15 },
        ["Blacksmithing|Expert"] = { name = "Blacksmithing", rank = "Expert", level = 20, skill = 125,
            cost = 10000, icon = 16 },
    } } }
    local tall = smith.list.body.h
    smith.list.body.h = 22 * 20
    fire("TRAINER_UPDATE")
    frame()
    rows("prof.trainer")
    row("Iron Buckle")
    rows("prof.trainer picked")
    foot("prof.trainer later")
    click(smith.create)
    click(smith.createAll)
    print("prof.trainer craft", table.concat(P.calls, ","))
    row("Blacksmithing (Expert)")
    foot("prof.trainer now")
    right("Copper Mace")
    print("prof.trainer right", tostring(MedalluinCharDB.recipeFavourites[11]), "trained=" .. tostring(smith.trained))
    row("Copper Chain Pants")
    foot("prof.trainer back to a recipe")
    smith.search:SetText("mace")
    smith.search.scripts.OnTextChanged(smith.search)
    rows("prof.trainer search")
    smith.search:SetText("")
    smith.search.scripts.OnTextChanged(smith.search)
    click(smith.have)
    rows("prof.trainer makeable")
    print("prof.unknown makeable", "on=" .. tostring(smith.unknown.on), "enabled=" .. tostring(smith.unknown.enabled))
    click(smith.have)
    -- Show unknown unticked: the trainer's services go, until ticked again
    click(smith.unknown)
    frame()
    rows("prof.unknown off")
    print("prof.unknown off", "on=" .. tostring(smith.unknown.on), "enabled=" .. tostring(smith.unknown.enabled),
        "kept=" .. tostring(MedalluinCharDB.recipesUnknownHidden))
    click(smith.unknown)
    frame()
    row("At the trainer (4)")
    rows("prof.trainer folded")
    row("At the trainer (4)")
    -- a picked service gone from the list: the details let it go
    row("Iron Buckle")
    MedalluinCharDB.trainer.trade.Blacksmithing["Iron Buckle|"].known = true
    fire("TRAINER_UPDATE")
    frame()
    foot("prof.trainer learned")
    -- back on the list (forgotten, say): no longer picked
    MedalluinCharDB.trainer.trade.Blacksmithing["Iron Buckle|"].known = nil
    fire("TRAINER_UPDATE")
    frame()
    rows("prof.trainer unpicked")
    -- the tab taken by another profession: what was picked there goes
    row("Iron Buckle")
    P.learned[1] = nil
    smith.Available()
    print("prof.trainer retabbed", smith.label, "trained=" .. tostring(smith.trained))
    P.learned[1] = 1
    smith.Available()
    print("prof.trainer tab back", smith.label, "trained=" .. tostring(smith.trained))
    MedalluinCharDB.trainer = nil
    smith.list.body.h = tall
    GameTooltip.AddLine = addLine
    smith.chosen, smith.trained = nil, nil
    fire("TRAINER_UPDATE")
    frame()
    rows("prof.trainer gone")

    -- 6. Cooking's spell cast: Blizzard opens it, the window follows
    P.Show(185)
    frame()
    state("prof.cooking")
    tabs("prof.tabs")
    rows("prof.cooking")
    -- Overview turns our page alone
    click(pageOf("overview").tab)
    state("prof.overview")

    -- 6b. the Overview's sections: the primaries, the secondaries, Camping
    local ov = pageOf("overview")
    local function overview(tag)
        local function y(f)
            local _, _, _, _, at = f:GetPoint()
            return f.shown and tostring(-at) or "hidden"
        end
        local cards = {}
        for _, c in ipairs(ov.cards) do
            if c.shown then table.insert(cards, c.name.text .. "@" .. y(c)) end
        end
        -- the header's portrait on its rule; the hair down between the pillars
        local portrait = ov.banner.portrait.points.CENTER
        print(tag, "need=" .. ov.height, "window=" .. w.h, "primary@" .. y(ov.heads.primary), "secondary@" .. y(ov.heads.secondary),
            "camp@" .. y(ov.heads.camp) .. "/" .. y(ov.camp), table.concat(cards, " "),
            "portrait@" .. -portrait[4] .. "/" .. ov.banner.h, "split@" .. y(ov.split) .. "h" .. ov.split.h)
        local slots, tiles = {}, {}
        for _, s in ipairs(ov.camp.slots) do
            table.insert(slots, s.spec.name .. "=" .. s.time.text .. (s.icon.desaturated and "(grey)" or ""))
        end
        for _, tile in ipairs(ov.camp.tiles) do
            if tile.shown then
                local _, _, _, x, ty = tile:GetPoint()
                table.insert(tiles, string.format("%s[%s|%s]%s@%d,%d", tile.name, tile.sub, tile.corner.text,
                    tile.mark.shown and "*" or "", x, -ty))
            end
        end
        print(tag .. " camp", table.concat(slots, " | "), "h=" .. ov.camp.h)
        print(tag .. " objects", table.concat(tiles, " | "))
        local d = ov.camp.drawer
        if d.shown then
            local rows = {}
            for _, r in ipairs(d.rows) do
                if r.shown then
                    table.insert(rows, r.name.text .. " {" .. r.state.text .. "} " .. r.what.text
                        .. (r.tier and " (makes)" or ""))
                end
            end
            local _, _, _, _, dy = d:GetPoint()
            print(tag .. " drawer", "@" .. -dy, "h=" .. d.h, table.concat(rows, " | "))
        end
    end
    overview("prof.sections")
    -- every tooltip the window shows stands outside it, at its left, level
    -- with what is hovered
    local function beside(tag, region)
        GameTooltip.points = {}
        region.scripts.OnEnter(region)
        local at = GameTooltip.points.TOPRIGHT
        local top, edge = region:GetTop(), w:GetTop()
        print(tag, "anchor=" .. tostring(GameTooltip.anchor), at and string.format("TOPRIGHT>%s %s %d,%d",
            at[1] == w and "window" or "?", at[2], at[3], at[4]) or "unplaced",
            -- the window's offset, in the tooltip's scale
            "level=" .. tostring(at and top and edge and math.abs(at[4] - (top - edge) * w:GetEffectiveScale()
                / GameTooltip:GetEffectiveScale()) < 0.01))
        region.scripts.OnLeave(region)
    end
    beside("prof.tip spell", ov.cards[1].spells[1])
    beside("prof.tip cross", ov.cards[2].unlearn)
    beside("prof.tip line", ov.cards[3])
    beside("prof.tip buff", ov.camp.slots[1])
    beside("prof.tip object", ov.camp.tiles[1])
    beside("prof.tip tab", ov.tab)
    beside("prof.tip close", W.window.close)
    -- a short screen: the window is as tall as what the Overview shows,
    -- running past the screen only by that, not by the most it could show
    do
        local tall = UIParent.GetHeight
        UIParent.GetHeight = function() return 400 end
        W.Retab()
        frame()
        overview("prof.short screen")
        UIParent.GetHeight = tall
        W.Retab()
        frame()
    end
    -- the banner, and this character as its alts will read it
    do
        local b = ov.banner
        print("prof.banner me", b.name.text, string.format("(%.2f,%.2f,%.2f)", unpack(b.name.textColor or { -1, -1, -1 })),
            b.levelText.text, b.what.text, "portrait=" .. tostring(b.portrait.portrait))
        local realm = GetRealmName and GetRealmName() or "?"
        local me = MedalluinDB.roster[realm][UnitName("player")]
        local profs = {}
        for _, p in ipairs(me.primaries) do table.insert(profs, p.name .. " " .. p.rank .. "/" .. p.max) end
        print("prof.roster me", me.class, me.level, table.concat(profs, ", "))
        -- two alts recorded: listed, most recently played first, a click opens one's window
        local roster = MedalluinDB.roster[realm]
        roster.Barkhide = { class = "DRUID", className = "Druid", level = 40, seen = 5,
            primaries = { { name = "Herbalism", icon = 1, rank = 200, max = 225 },
                { name = "Alchemy", icon = 2, rank = 190, max = 225 } } }
        roster.Medalluin = { class = "PRIEST", className = "Priest", level = 60, seen = 9,
            primaries = { { name = "Tailoring", icon = 3, rank = 300, max = 300 } } }
        roster.Newbie = { class = "MAGE", className = "Mage", level = 1, seen = 1, primaries = {} }
        fire("SKILL_LINES_CHANGED")
        frame()
        click(pageOf("overview").tab)
        frame()
        local function alts(tag)
            local o = {}
            for _, r in ipairs(ov.alts.rows) do
                if r.shown then
                    local _, _, _, _, y = r:GetPoint()
                    local p = {}
                    for k, q in ipairs(r.profs) do
                        if q.label.shown then table.insert(p, k .. ":" .. q.label.text) end
                    end
                    table.insert(o, string.format("%s %s [%s]@%d", r.name.text, r.what.text, table.concat(p, " "), -y))
                end
            end
            local _, _, _, _, hy = ov.heads.alts:GetPoint()
            print(tag, "head=" .. (ov.heads.alts.shown and tostring(-hy) or "hidden"), table.concat(o, " | "))
        end
        alts("prof.alts")
        beside("prof.tip alt", ov.alts.rows[1])
        overview("prof.alts")
        local aw = function()
            local f = _G.MedalluinAlt
            return f and f.shown and W.altWindow.Current().name.text or "closed"
        end
        click(ov.alts.rows[1])
        print("prof.alt open", aw())
        click(ov.alts.rows[2])
        print("prof.alt other", aw())
        click(ov.alts.rows[2])
        print("prof.alt again", aw())
        roster.Barkhide, roster.Medalluin, roster.Newbie = nil, nil, nil
        fire("SKILL_LINES_CHANGED")
        frame()
        click(pageOf("overview").tab)
        frame()
        alts("prof.alts gone")
    end
    -- no secondary learned: no heading for them
    P.learned[4], P.learned[5] = nil, nil
    fire("SKILL_LINES_CHANGED")
    frame()
    overview("prof.no secondaries")
    tabs("prof.no secondaries")
    P.learned[4], P.learned[5] = 4, 5
    fire("SKILL_LINES_CHANGED")
    frame()
    click(pageOf("overview").tab)
    frame()
    -- the camp's buffs: near the fire, settling in, then Camp Benefits and food, ticking down
    local camp = { name = "Campfire Nearby", id = 90, icon = "fire" }
    table.insert(buffs, camp)
    now = now + 1
    frame()
    overview("prof.camp near")
    camp.name = "Welcoming Campfire"
    now = now + 1
    frame()
    overview("prof.camp welcome")
    camp.name, camp.expires = "Camp Benefits", now + 3600
    table.insert(buffs, { name = "Well Fed", id = 91, icon = "fed", expires = now + 600 })
    now = now + 1
    frame()
    overview("prof.camp benefits")
    now = now + 1200
    frame()
    overview("prof.camp later")
    table.remove(buffs)
    table.remove(buffs)
    -- an object's drawer: its tiers; a known one is made on its tab
    local cook
    for _, tile in ipairs(ov.camp.tiles) do
        if tile.shown and tile.name == "Basic Campfire" then cook = tile end
    end
    click(cook)
    overview("prof.drawer")
    click(cook)
    overview("prof.drawer shut")
    click(cook)
    P.calls = {}
    local made = ov.camp.drawer.rows[1]
    made.scripts.OnClick(made, "LeftButton")
    frame()
    P.Show(185)
    frame()
    print("prof.drawer made", "page=" .. W.Current().key, "chosen=" .. tostring(W.Current().chosen),
        "calls=" .. table.concat(P.calls, ","))
    foot("prof.drawer made")
    -- the kit forgotten: the tile says how to learn it
    local kit = P.recipes[185][2]
    table.remove(P.recipes[185])
    fire("TRADE_SKILL_LIST_UPDATE")
    frame()
    click(pageOf("overview").tab)
    frame()
    overview("prof.kit forgotten")
    table.insert(P.recipes[185], kit)
    P.Show(185)
    frame()
    click(pageOf("overview").tab)
    frame()

    -- 7. First Aid learned: a fifth tab, the others narrower
    P.learned[3] = 3
    fire("SKILL_LINES_CHANGED")
    frame()
    tabs("prof.first aid")
    cards("prof.card")
    -- Mining forgotten: its card says how to learn one, its tab goes
    P.learned[2] = nil
    fire("SKILL_LINES_CHANGED")
    frame()
    tabs("prof.no mining")
    cards("prof.card")
    P.learned[2] = 2
    fire("SKILL_LINES_CHANGED")
    frame()

    -- 8. combat: the list waits, Create does nothing, the layer goes
    click(pageOf("craft1").tab)
    P.Show(164)
    frame()
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    frame()
    P.calls = {}
    row("Copper Chain Pants")
    rows("prof.combat")
    foot("prof.combat")
    click(smith.create)
    click(smith.createAll)
    click(pageOf("craft2").tab)
    rows("prof.combat mining")
    print("prof.combat calls", table.concat(P.calls, ","))
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    frame()
    print("prof.after combat calls", table.concat(P.calls, ","))
    P.Show(186)
    frame()
    state("prof.after combat")
    rows("prof.mining")
    -- the banner: the profession, its next rank, its skill across
    do
        local b = W.Current().banner
        local _, _, _, hx, hy = W.Current().hair:GetPoint()
        -- the rank under the name; a diamond at each end of the bar
        local under = b.rank.points.TOPLEFT and b.rank.points.TOPLEFT[1] == b.name
        local caps = {}
        for _, cap in ipairs(b.caps) do
            local _, rel, rp, cx = cap:GetPoint()
            table.insert(caps, (rel == b.bar and rp or "?") .. cx)
        end
        print("prof.banner", b.name.text, b.rank.shown and b.rank.text or "-", b.bar.text.text,
            "bar=" .. tostring(b.bar.bar.value) .. "/" .. tostring(b.bar.bar.max),
            "hair@" .. hx .. "," .. hy, "rank=" .. (under and "under" or "loose"), "caps=" .. table.concat(caps, ","))
        beside("prof.tip tick", W.Current().have)
        beside("prof.tip create", W.Current().create)
        local first
        for _, r in ipairs(W.Current().list.rows) do
            if r.shown and not r.data.header and not first then first = r end
        end
        beside("prof.tip recipe", first)
    end
    -- ornate headings: a rim, a margin above and below; the list scrolls
    -- to its last row whatever the rows' heights
    do
        local list = W.Current().list
        local function geometry(tag)
            local o = {}
            for _, r in ipairs(list.rows) do
                if r.shown then
                    local _, _, _, _, y = r:GetPoint()
                    local _, _, _, _, fy = r.fill:GetPoint()
                    table.insert(o, string.format("%s@%d h%d%s", r.label.text, -y, r.h,
                        r.rim.TOP.shown and string.format(" rim fill%d", -fy) or ""))
                end
            end
            print(tag, "offset=" .. list.offset, "track=" .. tostring(list.track.shown), table.concat(o, " | "))
        end
        geometry("prof.ornate")
        local tall = list.body.h
        list.body.h = 100
        list:Draw()
        geometry("prof.ornate short")
        list:Scroll(99)
        geometry("prof.ornate end")
        list:Scroll(-99)
        list.body.h = tall
        list:Draw()
    end
    -- Mining's nodes: read one; the search finds them, Have materials hides them
    row("Tin Vein")
    foot("prof.node")
    -- a service at the trainer, read next, is the one row chosen
    MedalluinCharDB.trainer = { class = {}, trade = {} }
    MedalluinCharDB.trainer.trade.Mining = {
        ["Smelt Iron|"] = { name = "Smelt Iron", level = 1, skill = 125, cost = 500, icon = 17 } }
    fire("TRAINER_UPDATE")
    frame()
    row("Smelt Iron")
    rows("prof.node to trainer")
    MedalluinCharDB.trainer = nil
    fire("TRAINER_UPDATE")
    frame()
    row("Tin Vein")
    local mine = W.Current()
    mine.search:SetText("silver")
    mine.search.scripts.OnTextChanged(mine.search)
    frame()
    rows("prof.node search")
    mine.search:SetText("")
    mine.search.scripts.OnTextChanged(mine.search)
    P.makeable = true
    fire("TRADE_SKILL_LIST_UPDATE")
    frame()
    rows("prof.node makeable")
    foot("prof.node makeable")
    P.makeable = false
    fire("TRADE_SKILL_LIST_UPDATE")
    frame()
    -- a node hidden is let go: back, it is not read again
    foot("prof.node back")
    -- a recipe read next is the one read
    row("Tin Vein")
    -- smelting says where it turns yellow, green and grey
    row("Smelt Copper")
    foot("prof.smelt copper")
    -- an open on its way: the game says no profession is open; the tab
    -- chosen again asks nothing (a second open would close it)
    local overviewTab, smeltTab = W.pages[1].tab, W.Current().tab
    P.changing, P.open = true, 0
    P.calls = {}
    click(overviewTab)
    click(smeltTab)
    print("prof.open on its way", "calls=" .. table.concat(P.calls, ","), "page=" .. W.Current().key)
    -- it came, another profession's: the tab chosen meanwhile opens now
    P.changing, P.open = false, 164
    fire("TRADE_SKILL_LIST_UPDATE")
    frame()
    print("prof.open came", "calls=" .. table.concat(P.calls, ","))
    P.Show(186)
    frame()
    -- six reagents share the tree's five rows
    local copper = P.recipes[186][1][5]
    for _, item in ipairs({ 2835, 2880, 2672, 2589, 2840 }) do table.insert(copper, { item, 1 }) end
    fire("BAG_UPDATE_DELAYED")
    frame()
    foot("prof.six reagents")
    for _ = 1, 5 do table.remove(copper) end
    fire("BAG_UPDATE_DELAYED")
    frame()

    -- 9. one window on the right strip: the book closes ours, ours the book
    bookWorld.Toggle("spellbook")
    frame()
    state("prof.book")
    P.Toggle()
    frame()
    state("prof.again")
    w.close.scripts.OnClick(w.close)
    frame()
    state("prof.closed")
    -- reopened on its book (its Overview tab) with Blacksmithing still open
    ProfessionsFrame.BookPage:Show()
    ProfessionsFrame.CraftingPage:Hide()
    P.Toggle()
    frame()
    state("prof.book again")
end

-- ------------------------------------------------------- the quest tracker
if questPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local W = questWorld
    local T = ns.quests
    local f = _G.MedalluinQuests
    print("quests", "tracker=" .. tostring(f ~= nil), "setting=" .. tostring(ns.db.quests),
        "sort=" .. tostring(ns.db.questsSort))
    if not f then return end
    local list, layer = T.list, T.layer
    list.body.h = 22 * 12               -- twelve rows tall: the screen's height, which the mock has not
    T.Refresh()
    local function frame()
        if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0) end
    end
    local function where(r)
        local out = {}
        for point, p in pairs(r.points) do
            table.insert(out, string.format("%s>%s:%s %d,%d", point, p[1] and (p[1].name or (p[1] == r.parent
                and "parent") or "?") or "-", p[2] or "-", p[3] or 0, p[4] or 0))
        end
        table.sort(out)
        return table.concat(out, " ")
    end
    local function c3(c) return c and string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) or "-" end
    -- a footer button's tooltip
    local function tip(b)
        b.scripts.OnEnter(b)
        local text = GameTooltip.text
        b.scripts.OnLeave(b)
        return tostring(text)
    end
    local function state(tag)
        print(tag, "shown=" .. tostring(f.shown), "sort=" .. tip(T.sort),
            "minimised=" .. tostring(ns.db.questsMinimised), "all=" .. T.foldAll.glyph,
            "view=" .. T.view.glyph, "body=" .. tostring(list.body.shown), "foot=" .. tostring(T.footer.shown),
            "empty=" .. tostring(list.empty.shown), "offset=" .. list.offset)
    end
    local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local LEADS = { bullet = "* ", mid = "|- ", last = "`- ", pass = "|  ", blank = "   " }
    local function rows(tag)
        local out = {}
        for _, r in ipairs(list.rows) do
            if r.shown then
                local d = r.data
                table.insert(out, d.header and (r.sign.text .. plain(r.label.text) .. (d.bright and "(bright)" or "")
                    .. (r.fill.gradient and string.format(" a=%.2f", r.fill.gradient[2][4]) or ""))
                    or (string.rep(">", d.depth or 0) .. (r.badge.shown and ("{" .. tostring(r.badge.atlas or tostring(r.badge.texture):match("[^\\]+$")) .. "} ")
                        or "")
                        .. (LEADS[d.lead] or "") .. plain(r.label.text)
                        .. (d.quest and ("(" .. c3(r.label.textColor) .. ")") or (d.dim and "(dim)" or ""))
                        .. (d.quest and r.value.text ~= "" and (" @" .. r.value.text) or "")))
            end
        end
        print(tag, #out > 0 and table.concat(out, " | ") or "none")
    end
    -- each shown item button: its item, the row it stands beside, its count
    local function items(tag)
        local out = {}
        for i, b in ipairs(layer.buttons) do
            if b.shown then
                local p = b.points.TOPRIGHT
                local at = (-p[4] - T.top - (list.row - 20) / 2) / list.row + 1
                local r = list.rows[at]
                table.insert(out, string.format("%d:%s %s,%d row%s=%s n=%s%s%s", i, b.attrs.type, tostring(b.attrs.item),
                    p[3], at, r and r.data and r.data.quest and r.data.quest.id or "?", b.count.text or "",
                    b.icon.desaturated and " dim" or "", b.cooldown.start and (" cd" .. b.cooldown.start) or ""))
            end
        end
        print(tag, "layer=" .. where(layer) .. (layer.all == f and " all" or ""), #out > 0 and table.concat(out, " ")
            or "none")
    end
    local function calls(tag)
        print(tag, #W.calls > 0 and table.concat(W.calls, ", ") or "none")
        W.calls = {}
    end
    local function row(label, button)
        for _, r in ipairs(list.rows) do
            if r.shown and r.label.text:find(label, 1, true) then
                r.scripts.OnClick(r, button or "LeftButton")
                return
            end
        end
        print("  no row " .. label)
    end
    local Z = W.questie

    -- 1. at login: the frame's place, the game's tracked quests by level,
    -- Blizzard's tracker gone
    local blizzard = ObjectiveTrackerFrame
    print("quests.blizzard", "shown=" .. tostring(blizzard.shown), "parent=" .. tostring(blizzard.parent == UIParent))
    print("quests.frame", "width=" .. f.w, "strata=" .. tostring(f.strata), "mouse=" .. tostring(f.mouse),
        where(f), "parent=" .. tostring(f.parent == ns.strips[-1]))
    state("quests.login")
    rows("quests.level")
    -- a heading's band: full at the left, clear at the right
    local fill = list.rows[1].fill
    local g = fill.gradient
    print("quests.heading", g and string.format("%s %.2f>%.2f", g[1], g[2][4], g[3][4]) or ("flat "
        .. tostring(fill.color and fill.color[4])))
    -- the shade: as tall as what shows, up under the pointer, away after
    local shade = T.shade
    local sg = shade.fill.gradient
    local function shaded(tag)
        print(tag, "h=" .. shade.h, string.format("alpha=%.2f", shade:GetAlpha()),
            sg and string.format("%s %.2f>%.2f", sg[1], sg[2][4], sg[3][4]) or "flat")
    end
    local function tick(n)
        for _ = 1, n do f.scripts.OnUpdate(f, 0.05) end
    end
    shaded("quests.shade")
    mouseOver = shade
    tick(1)
    shaded("quests.shade, pointer over")
    tick(3)
    shaded("quests.shade, a moment on")
    mouseOver = false
    tick(1)
    shaded("quests.shade, pointer gone")
    tick(4)
    shaded("quests.shade, gone")
    items("quests.items")
    harnessBeside("quests item tips", ns.quests.layer)

    -- 2. Questie ready: its set, its items
    if Z then
        Z.Ready()
        frame()
        state("quests.questie ready")
        rows("quests.questie")
        items("quests.questie items")
    end

    -- 3. the sorts: each click the next
    for _ = 1, 2 do
        T.sort.scripts.OnClick(T.sort, "LeftButton")
        frame()
        state("quests.sorted")
        rows("quests.sorted")
    end
    print("quests.saved sort", ns.db.questsSort)
    if ns.db.questsSort ~= "level" then        -- back to level, where every quest shows
        T.sort.scripts.OnClick(T.sort, "LeftButton")
        frame()
    end

    -- 4. Westfall folds, and is remembered; the whole tracker minimises
    row("Westfall")
    frame()
    rows("quests.westfall folded")
    items("quests.folded items")
    print("quests.saved folds", tostring(ns.db.questsFolded and ns.db.questsFolded.Westfall))
    row("Westfall")
    frame()
    T.head.scripts.OnClick(T.head, "LeftButton")
    frame()
    state("quests.minimised")
    rows("quests.minimised")
    print("quests.minimised shade", "h=" .. T.shade.h)
    items("quests.minimised items")
    T.head.scripts.OnClick(T.head, "LeftButton")
    frame()
    state("quests.restored")

    -- 5. the clicks: the quest log, a link, Alt's focus, a right click
    row("The Fargodeep Mine")
    calls("quests.click")
    charWorld.modified = true
    row("The Fargodeep Mine")
    charWorld.modified = false
    calls("quests.shift")
    modsDown.ALT = true
    row("The Fargodeep Mine")
    modsDown.ALT = nil
    calls("quests.alt")
    row("The Defias Brotherhood", "RightButton")
    calls("quests.right")
    -- Questie's untrack leaves the game's watches alone: only its own update says so
    if Z and not Z.broken then Z.Changed() else fire("QUEST_WATCH_LIST_CHANGED") end
    frame()
    rows("quests.untracked")
    items("quests.untracked items")

    -- 6. combat: counts change in place, a quest gone waits for the end,
    -- sort, fold and scroll do nothing, the items keep their places
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    W.byId(101).objectives[1].text = "Kobold Laborer slain: 5/10"
    W.bags[5001] = 2
    fire("QUEST_LOG_UPDATE")
    frame()
    rows("quests.combat count")
    items("quests.combat items")
    W.watched[203] = nil
    if Z then Z.tracked[103] = nil end
    fire("QUEST_WATCH_LIST_CHANGED")
    frame()
    rows("quests.combat removed")
    T.sort.scripts.OnClick(T.sort, "LeftButton")
    T.head.scripts.OnClick(T.head, "LeftButton")
    T.foldAll.scripts.OnClick(T.foldAll, "LeftButton")
    list:Scroll(2)
    row("Elwynn Forest")
    frame()
    state("quests.combat")
    print("quests.combat folds", tostring(ns.db.questsFolded and ns.db.questsFolded["Elwynn Forest"]))
    items("quests.combat still")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    frame()
    state("quests.after combat")
    rows("quests.after combat")
    items("quests.after combat items")

    -- 7. the character window stands over it, and its items go
    ToggleCharacter("PaperDollFrame")
    frame()
    state("quests.character")
    items("quests.character items")
    ToggleCharacter("PaperDollFrame")
    frame()
    state("quests.character closed")
    items("quests.character closed items")

    -- 7b. Blizzard's tracker shows itself again: hidden at once, and when
    -- it is protected, in combat, at combat's end
    blizzard:Show()
    print("quests.blizzard again", "shown=" .. tostring(blizzard.shown))
    W.protected, inCombat = true, true
    blizzard:Show()
    print("quests.blizzard combat", "shown=" .. tostring(blizzard.shown))
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    print("quests.blizzard after combat", "shown=" .. tostring(blizzard.shown))
    W.protected = false

    -- 8. a shorter screen: the wheel over a row scrolls, and the items follow
    list.body.h = 22 * 4
    T.Refresh()
    items("quests.short items")
    local first = list.rows[1]
    first.scripts.OnMouseWheel(first, -1)
    frame()
    state("quests.scrolled")
    rows("quests.scrolled")
    items("quests.scrolled items")
    list:Scroll(-5)
    list.body.h = 22 * 12
    T.Refresh()

    -- 9. Questie redrawn, and its own tracker off
    W.watched[201], W.watched[203] = true, true
    if Z then
        Z.tracked[201], Z.tracked[103] = true, true
        Z.Redrawn()
        frame()
        rows("quests.questie redrawn")
    end
    -- Questie's own tracker off: it no longer hears the quest log's track
    -- box, so its set is stale (102 ticked again, never in it) and the
    -- game's watch decides; the untrack is the game's too, even of a
    -- quest Questie's set still holds (101)
    if Z and not Z.broken then
        Questie.db.profile.trackerEnabled = false
        fire("QUEST_WATCH_LIST_CHANGED")
        frame()
        rows("quests.questie off")
        row("The Fargodeep Mine", "RightButton")
        calls("quests.questie off untrack")
        W.watched[101], Z.tracked[101] = true, true
        Questie.db.profile.trackerEnabled = true
        fire("QUEST_WATCH_LIST_CHANGED")
        frame()
    end
    -- a Questie that raised, mended
    if Z and Z.broken then
        Z.broken = false
        fire("QUEST_LOG_UPDATE")
        frame()
        state("quests.mended")
        rows("quests.mended")
    end

    -- 10. the views. The full one: the ink, fading to the right; the footer
    -- above the medallion's lip, the list down to its rule
    ns.db.questsSort = "level"
    T.Refresh()
    local function view(tag)
        local ink = T.ink
        local g = ink.gradient
        print(tag, "strata=" .. tostring(f.strata) .. "/" .. tostring(layer.strata),
            string.format("scale=%.2f/%.2f", f:GetScale(), layer:GetScale()), "size=" .. tostring(f.w) .. "x" .. tostring(f.h),
            where(f), "dress=" .. tostring(T.dress.shown) .. (g and string.format(" %.2f>%.2f", g[2][4], g[3][4]) or ""),
            "grip=" .. tostring(T.grip.shown), "foot=" .. where(T.footer), "body=" .. where(list.body))
        local icons = {}
        for _, b in ipairs(ns.buffs or {}) do
            if b.shown then icons[#icons + 1] = tostring(b.icon.texture) .. "@" .. where(b) end
        end
        print(tag .. " buffs", #icons > 0 and table.concat(icons, " ") or "none")
        if ns.chat then
            local box = ns.chat.box
            print(tag .. " chat", "box=" .. where(box), "h=" .. tostring(box.h), "level=" .. box:GetFrameLevel()
                .. "<" .. f:GetFrameLevel(), "panel=" .. where(ns.chat.panel), "rule=" .. tostring(T.chatRule.shown)
                .. " " .. where(T.chatRule))
        end
    end
    view("quests.full")
    -- the footer: the settings and the quest log at the left, the list's
    -- own three at the right, each its glyph and its tooltip
    for _, k in ipairs({ "gear", "book", "sort", "foldAll", "view" }) do
        local b = T[k]
        print("quests.footer " .. k, b.glyph, b.w .. "x" .. b.h, where(b), tip(b))
    end
    SetBinding("L", "TOGGLEQUESTLOG")
    print("quests.footer book bound", tip(T.book))
    local open, toggled = ns.OpenOptions, 0
    ns.OpenOptions = function(path) print("quests.footer gear opens", tostring(path)) end
    T.gear.scripts.OnClick(T.gear, "LeftButton")
    ns.OpenOptions = open
    ToggleQuestLog = function() toggled = toggled + 1 end
    T.book.scripts.OnClick(T.book, "LeftButton")
    ToggleQuestLog = nil
    print("quests.footer book toggles", toggled)
    -- the Defias Brotherhood's report, as the lines it wraps to
    local function wrapped(tag)
        local out, on = {}, false
        for _, d in ipairs(list.data) do
            if d.quest then on = d.quest.id == 201 elseif on and d.dim then table.insert(out, d.label) end
        end
        print(tag, #out .. " lines", table.concat(out, " / "))
    end
    wrapped("quests.full wrap")
    -- no timeless buffs: the divider from the margin's edge, and back
    local had = {}
    for i = #buffs, 1, -1 do table.insert(had, 1, table.remove(buffs, i)) end
    local function auras()
        for _, u in ipairs(events.UNIT_AURA or {}) do
            u.scripts.OnEvent(u, "UNIT_AURA", "player", { isFullUpdate = true })
        end
    end
    auras()
    view("quests.no buffs")
    for _, b in ipairs(had) do table.insert(buffs, b) end
    auras()
    -- every quest's title stops short of the item column, item or not
    local edges = {}
    for _, r in ipairs(list.rows) do
        if r.shown and r.data.quest then edges[#edges + 1] = tostring(r.label.points.RIGHT[3]) end
    end
    print("quests.title edges", table.concat(edges, " "))
    -- the full view does not move
    T.head.scripts.OnDragStart(T.head)
    print("quests.full drag", "moving=" .. tostring(f.isMoving))
    T.head.scripts.OnDragStop(T.head)
    -- every zone folded, then every zone open
    T.foldAll.scripts.OnClick(T.foldAll, "LeftButton")
    frame()
    state("quests.fold all")
    rows("quests.fold all")
    T.foldAll.scripts.OnClick(T.foldAll, "LeftButton")
    frame()
    state("quests.open all")
    print("quests.open all saved", tostring(ns.db.questsFolded))
    -- the minimal view: its button, its first place and size
    T.view.scripts.OnClick(T.view, "LeftButton")
    frame()
    state("quests.minimal")
    view("quests.minimal")
    -- its shade comes up under the pointer; the box's height
    mouseOver = T.shade
    tick(4)
    shaded("quests.minimal shade")
    mouseOver = false
    tick(5)
    -- a drag by the heading: kept where it was dropped
    harnessDropAt = { "TOPLEFT", "BOTTOMLEFT", 120, 700 }
    T.head.scripts.OnDragStart(T.head)
    T.head.scripts.OnDragStop(T.head)
    harnessDropAt = nil
    local function place(tag)
        local at = ns.db.questsPlace
        print(tag, at and string.format("%s>%s %d,%d %sx%s scale=%s", at.point, at.relative, at.x, at.y,
            tostring(at.w), tostring(at.h), tostring(at.scale)) or "none")
    end
    place("quests.dragged")
    view("quests.dragged")
    -- the grip: a narrower box, and the long objective wraps to it
    harnessSizeTo = { 340, 300 }
    T.grip.scripts.OnMouseDown(T.grip, "LeftButton")
    T.grip.scripts.OnMouseUp(T.grip, "LeftButton")
    harnessSizeTo = nil
    frame()
    place("quests.sized")
    view("quests.sized")
    wrapped("quests.sized wrap")
    items("quests.sized items")
    -- Ctrl-wheel scales, the anchor staying put on the screen; a plain
    -- wheel scrolls
    modsDown.CTRL = true
    T.head.scripts.OnMouseWheel(T.head, 1)
    place("quests.scaled")
    view("quests.scaled")
    for _ = 1, 30 do T.head.scripts.OnMouseWheel(T.head, 1) end
    place("quests.scaled most")
    for _ = 1, 30 do T.head.scripts.OnMouseWheel(T.head, -1) end
    place("quests.scaled least")
    modsDown.CTRL = nil
    list.body.h = 22 * 4
    T.Refresh()
    T.head.scripts.OnMouseWheel(T.head, -1)
    frame()
    state("quests.heading wheel")
    list:Scroll(-5)
    list.body.h = 22 * 12
    -- in combat: the view, a drag, the grip and the scale change nothing
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    T.view.scripts.OnClick(T.view, "LeftButton")
    T.head.scripts.OnDragStart(T.head)
    print("quests.combat drag", "moving=" .. tostring(f.isMoving))
    T.head.scripts.OnDragStop(T.head)
    harnessSizeTo = { 500, 500 }
    T.grip.scripts.OnMouseDown(T.grip, "LeftButton")
    T.grip.scripts.OnMouseUp(T.grip, "LeftButton")
    harnessSizeTo = nil
    modsDown.CTRL = true
    T.head.scripts.OnMouseWheel(T.head, 1)
    modsDown.CTRL = nil
    frame()
    print("quests.combat view", tostring(ns.db.questsView))
    place("quests.combat place")
    view("quests.combat view")
    -- the options page in combat: the view waits for regen
    ns.SetOption("questsView", "full")
    frame()
    view("quests.combat option")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    frame()
    view("quests.regen option")
    ns.SetOption("questsView", "minimal")
    frame()
    -- the options' Reset, then the full view again
    ns.SetOption("questsPlace", false)
    frame()
    place("quests.reset")
    view("quests.reset")
    T.view.scripts.OnClick(T.view, "LeftButton")
    frame()
    state("quests.full again")
    view("quests.full again")
    mouseOver = T.shade
    tick(4)
    shaded("quests.full shade")
    mouseOver = false
    -- with no chat box (the chat panel off), the full view is a frame of
    -- its own on the strip, the margin and the buffs at its foot; and back
    local chat = ns.chat
    ns.chat = nil
    T.Layout()
    view("quests.no chat")
    T.view.scripts.OnClick(T.view, "LeftButton")
    frame()
    view("quests.no chat minimal")
    T.view.scripts.OnClick(T.view, "LeftButton")
    ns.chat = chat
    T.Layout()
    view("quests.chat again")
    do
        -- the reach: a box of its own from the screen's top to the chat
        -- box's top edge, its foot open (no corners, no band rule)
        local r = ns.chat.reach
        local pts = {}
        for i = 1, r:GetNumPoints() do
            local p, rel, rp, x, y = r:GetPoint(i)
            pts[#pts + 1] = string.format("%s>%s:%s %d,%d", p, rel and rel:GetName() or "?", rp, x, y)
        end
        table.sort(pts)
        local dress
        for _, c in ipairs({ r:GetChildren() }) do if c.corners then dress = c end end
        print("quests.reach", table.concat(pts, " "), "level=" .. r:GetFrameLevel() .. "/" .. ns.chat.box:GetFrameLevel(),
            "corners top=" .. tostring(dress.corners.TOPLEFT[1].shown) .. "/" .. tostring(dress.corners.TOPRIGHT[2].shown),
            "bottom=" .. tostring(dress.corners.BOTTOMLEFT[1].shown) .. "/" .. tostring(dress.corners.BOTTOMRIGHT[2].shown),
            "rule=" .. tostring(dress.rule.shown))
    end

    -- each view hidden on its own options: until the pointer is over it, and
    -- in combat (the secure items by the game's driver, the rest taking no mouse)
    local function hidden(tag)
        tick(10)
        print(tag, string.format("alpha=%.2f items=%.2f", f:GetAlpha(), layer:GetAlpha()),
            "items shown=" .. tostring(layer.shown),
            "driver=" .. tostring(layer.stateDrivers and layer.stateDrivers.visibility),
            "head mouse=" .. tostring(T.head.mouse), "footer mouse=" .. tostring(T.gear.mouse),
            "row mouse=" .. tostring(list.rows[1] and list.rows[1].mouse),
            string.format("reach=%s %.2f chat corners=%.2f/%.2f", tostring(ns.chat.reach.shown),
                ns.chat.reach:GetAlpha(), ns.chat.dress.corners.TOPLEFT[1]:GetAlpha(),
                ns.chat.dress.corners.TOPRIGHT[2]:GetAlpha()))
    end
    local function combat(on)
        inCombat = on
        harnessHolds.combat = on or nil
        fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
        stateTick()
    end
    hidden("quests.hide none")
    ns.SetOption("questsFullMouseover", true)
    hidden("quests.hide mouseover away")
    -- laid out again while hidden: the reach stays as faded as the list
    T.Layout()
    print("quests.hide relaid", string.format("reach=%.2f", ns.chat.reach:GetAlpha()))
    mouseOver = f
    hidden("quests.hide mouseover over")
    mouseOver = false
    ns.SetOption("questsFullMouseover", false)
    ns.SetOption("questsFullCombat", true)
    hidden("quests.hide combat, out of it")
    combat(true)
    hidden("quests.hide combat, in it")
    combat(false)
    hidden("quests.hide combat, after it")
    -- turned off in combat: it waits for combat's end, and the items come
    -- back then, before the driver's next update
    combat(true)
    ns.SetOption("questsFullCombat", false)
    inCombat, harnessHolds.combat = false, nil
    fire("PLAYER_REGEN_ENABLED")
    hidden("quests.hide combat, turned off in it")
    ns.SetOption("questsFullCombat", true)
    -- the minimal view: its own options, not the full view's
    T.view.scripts.OnClick(T.view, "LeftButton")
    frame()
    combat(true)
    hidden("quests.hide minimal, in combat")
    combat(false)
    ns.SetOption("questsMinimalMouseover", true)
    hidden("quests.hide minimal mouseover")
    ns.SetOption("questsMinimalMouseover", false)
    ns.SetOption("questsFullCombat", false)
    T.view.scripts.OnClick(T.view, "LeftButton")
    frame()
    hidden("quests.hide off again")

    -- 12. reading. The pointer over an objective lights its quest and all
    -- its objectives, its own glow off; away, none
    T.Refresh()
    local function lit(tag)
        local out = {}
        for i, r in ipairs(list.rows) do
            if r.shown and r.lit.shown then table.insert(out, i .. ":" .. plain(r.label.text):sub(1, 12)) end
        end
        local glows = 0
        for _, r in ipairs(list.rows) do if r.shown and r.glow.shown then glows = glows + 1 end end
        print(tag, #out > 0 and table.concat(out, " ") or "none", "glows=" .. glows)
    end
    local over
    for _, r in ipairs(list.rows) do
        if r.shown and r.label.text:find("Defias Messenger", 1, true) then over = r end
    end
    over.scripts.OnEnter(over)
    lit("quests.lit")
    print("quests.lit tip", "owner=" .. tostring(GameTooltip.owner == over))
    over.scripts.OnClick(over, "LeftButton")
    calls("quests.lit click")
    -- the rows drawn again under it (a scroll): the light keeps to its quest
    list:Scroll(1)
    lit("quests.lit scrolled")
    list:Scroll(-1)
    over.scripts.OnLeave(over)
    lit("quests.unlit")
    -- one quest's rows, shown or scrolled past: its lead and words
    local function quest(tag, id)
        local out = {}
        for _, d in ipairs(list.data) do
            if d.group == id then
                table.insert(out, (d.badge and ("{" .. (d.badge.atlas or d.badge.file:match("[^\\]+$")) .. "} ") or "") .. (LEADS[d.lead] or "")
                    .. plain(d.label) .. (d.dim and "(dim)" or ""))
            end
        end
        print(tag, table.concat(out, " | "))
    end
    -- each lead as drawn: the dot, the stem (to the middle on the last), the
    -- branch to the words, and where the words start
    local function leads(tag)
        local seen, out = {}, {}
        for _, r in ipairs(list.rows) do
            local kind = r.shown and r.data.lead
            if kind and not seen[kind] then
                seen[kind] = true
                local st, sb, b = r.stem.points.TOPLEFT, r.stem.points.BOTTOMLEFT, r.branch.points
                table.insert(out, string.format("%s dot=%s stem=%s branch=%s label=%d", kind,
                    r.dot.shown and tostring(r.dot.points.CENTER[3]) or "-",
                    r.stem.shown and (st[3] .. ":" .. st[4] .. ">" .. sb[4]) or "-",
                    r.branch.shown and (b.LEFT[3] .. ">" .. b.RIGHT[3]) or "-", r.label.points.LEFT[3]))
            end
        end
        print(tag, table.concat(out, " | "))
    end
    quest("quests.bullets 201", 201)
    leads("quests.bullet leads")
    -- the tree: the finished objectives risen, on its branches
    ns.SetOption("questsTree", true)
    frame()
    rows("quests.tree")
    quest("quests.tree 201", 201)
    list:Scroll(8)
    leads("quests.tree leads")
    list:Scroll(-8)
    -- a daily's marks, blue: its ! and, once it is done, its ?
    W.byId(101).frequency = 1
    fire("QUEST_LOG_UPDATE")
    frame()
    rows("quests.daily")
    W.byId(101).complete = true
    fire("QUEST_LOG_UPDATE")
    frame()
    rows("quests.daily ready")
    W.byId(101).complete, W.byId(101).frequency = nil, nil
    -- the marks without the client's atlases: the gossip window's, tinted
    local atlases = C_Texture.GetAtlasInfo
    C_Texture.GetAtlasInfo = function() end
    T.Refresh()
    local marks = {}
    for _, r in ipairs(list.rows) do
        if r.shown and r.badge.shown then
            table.insert(marks, string.format("%s %s %s%s", tostring(r.data.quest.id), tostring(r.badge.texture):match("[^\\]+$"),
                c3(r.badge.vertex), r.badge.desaturated and " desat" or ""))
        end
    end
    print("quests.marks filed", table.concat(marks, " | "))
    C_Texture.GetAtlasInfo = atlases
    -- the fonts and sizes: every row as tall as the larger, the marks and
    -- the items with them; in combat, waiting for its end
    local function type_(tag)
        local q, o
        for _, r in ipairs(list.rows) do
            if r.shown and r.data.quest and not q then q = r end
            if r.shown and r.data.lead and not o then o = r end
        end
        print(tag, "row=" .. list.row, "h=" .. tostring(q.h), "title=" .. tostring(q.label.font[1]):match("[^\\]+$")
            .. "/" .. q.label.font[2], "objective=" .. tostring(o.label.font[1]):match("[^\\]+$") .. "/" .. o.label.font[2],
            "mark=" .. tostring(q.badge.w), "wrap=" .. tostring(T.measure.font[1]):match("[^\\]+$") .. "/"
            .. T.measure.font[2])
    end
    type_("quests.type")
    combat(true)
    ns.SetOption("questsTitleSize", 18)
    frame()
    -- a quest's count changing then redraws in place: the size still waits
    fire("QUEST_LOG_UPDATE")
    type_("quests.type combat")
    combat(false)
    frame()
    type_("quests.type after combat")
    ns.SetOption("questsObjectiveFont", "friz")
    ns.SetOption("questsObjectiveSize", 20)
    frame()
    type_("quests.type objectives")
    rows("quests.type rows")
    items("quests.type items")
    ns.SetOption("questsObjectiveFont", "lsm:Gone")
    frame()
    harnessBeside("quests tips", MedalluinQuests)
    type_("quests.type font gone")
end

-- ------------------------------------------------------------ the NPC box
if npcPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local W = npcWorld
    local box = ns.npc and ns.npc.box
    local function parked()
        local out = {}
        for _, n in ipairs({ "GossipFrame", "QuestFrame", "MerchantFrame" }) do
            table.insert(out, n .. "=" .. (_G[n].parent == ns.hidden and "hidden" or "kept"))
        end
        return table.concat(out, " ")
    end
    print("npc", "box=" .. tostring(box ~= nil), "setting=" .. tostring(ns.db.npcWindows),
        "chat=" .. tostring(ns.chat ~= nil), parked())
    -- what Blizzard's merchant frame holds, to show nothing of ours wrote there
    local function keys(f)
        local out = {}
        for k, v in pairs(f) do
            if type(v) ~= "table" or k == "selectedTab" then table.insert(out, k .. "=" .. tostring(v)) end
        end
        table.sort(out)
        return table.concat(out, ",")
    end
    local merchantBefore = keys(MerchantFrame)
    local merchantFns = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^MerchantFrame_") then merchantFns[k] = v end
    end
    if not box then return end
    -- the screen in console units, as the bar pass pins it: the cap has a top
    UIParent.fixed = { -612, -916, 1308, 164 }
    box:SetHeight(box.h)
    -- pinned in the console's units, the screen's scale is the console's
    -- (the mock's tops are all in those units)
    function UIParent:GetEffectiveScale() return ns.console:GetEffectiveScale() end
    local tracker = _G.MedalluinQuests
    local reach = ns.chat.reach
    -- the tracker's full view drawn before anyone talks: the reach is up
    ns.chat.Reach(true, 1)
    local head, under, headFrame     -- the title, and the NPC's name under it
    for _, c in ipairs(box.all_) do
        if not headFrame and c.points.TOPRIGHT and c.points.TOPLEFT then
            headFrame = c
            for _, t in ipairs(c.all_ or {}) do
                if t.kind == "FontString" then
                    if not head then head = t elseif not under then under = t end
                end
            end
        end
    end
    -- the head's and foot's ink over the box's fade, the portrait, the body's face
    local function inks()
        local out = {}
        for _, c in ipairs(box.all_) do
            if c.ink and c.ink.color then table.insert(out, string.format("%.3f", c.ink.color[4])) end
        end
        return table.concat(out, ",")
    end
    local portraitOf
    for _, t in ipairs(headFrame.all_ or {}) do if t.portrait then portraitOf = t.portrait end end
    local scrollOf
    for _, c in ipairs(box.all_) do if c.kind == "ScrollFrame" then scrollOf = c end end
    local function state(tag)
        local p = box.points.BOTTOMLEFT
        print(tag, "shown=" .. tostring(box.shown), "h=" .. tostring(box.h),
            "anchor=" .. (p and string.format("%s:%s %d,%d", p[1] == ns.chat.box and "chat" or "?", p[2], p[3], p[4])
                or "-"),
            "tracker=" .. tostring(tracker and tracker.shown), "reach=" .. tostring(reach.shown),
            "name=" .. tostring(head and head.text) .. (under and (under.text or "") ~= "" and "/" .. under.text or ""),
            "pinned=" .. tostring(ns.npc.bar.shown), "scrollTop=" .. tostring(scrollOf.points.TOPLEFT[4]))
    end
    -- what the page shows: each visible row and tile, top down, and the foot
    local function pool(f, out, depth)
        for _, c in ipairs(f.all_ or {}) do
            if c.shown and c.data then
                local d = c.data
                local text = type(d) == "table" and (d[1] == "columns" and "{" .. tostring(d.left) .. "|"
                    .. tostring(d.right) .. "}" or d.label) or "?" .. tostring(d)
                table.insert(out, { y = -(c.points.TOPLEFT and c.points.TOPLEFT[4] or 0), x = c.points.TOPLEFT
                    and c.points.TOPLEFT[3] or 0, s = text .. (d.value and d.value ~= "" and " [" .. d.value .. "]" or "")
                    .. (d.badge and " mark=" .. tostring(d.badge.file or d.badge.atlas or "?"):match("[^\\]+$") or "")
                    .. (c.mark and c.mark.shown and " *" or "")
                    -- an icon cut past its square border
                    .. (c.icon and c.icon.coords and c.icon.coords[1] > 0 and " #" or "")
                    .. (type(d) == "table" and d.color and string.format(" c=%.2f,%.2f,%.2f", d.color[1], d.color[2],
                        d.color[3]) or ""), c = c })
            end
        end
    end
    local function page(tag)
        local child = box.all_ and nil
        local out = {}
        for _, s in ipairs(box.all_) do
            if s.kind == "ScrollFrame" then pool(s.scrollChild, out) end
        end
        table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
        -- a fold says whether it is folded
        for _, r in ipairs(out) do
            if r.c.sign then r.s = "[" .. r.s .. " " .. tostring(r.c.sign.text) .. "]" end
        end
        -- the tabs held under the head come first, marked ^, outside the scroll
        local pinned = {}
        if ns.npc.bar.shown then pool(ns.npc.bar, pinned) end
        table.sort(pinned, function(a, b) return a.x < b.x end)
        for i = #pinned, 1, -1 do
            pinned[i].s = "^" .. pinned[i].s
            table.insert(out, 1, pinned[i])
        end
        local rows = {}
        for _, r in ipairs(out) do table.insert(rows, r.s) end
        print(tag .. " rows", table.concat(rows, " | "))
        return out
    end
    -- a shop's table: what stays put (the words, the hairline), then each
    -- run's heading (its words' places and rule: H) and each row's shading,
    -- rule and label's reach
    local bar = ns.npc.bar
    local function shop(tag)
        local function x(t, p) return t.shown and t.points[p] and tostring(t.points[p][3]) or "-" end
        print(tag .. " shop", "say=" .. (bar.say.shown and tostring(bar.say.text) or "-"),
            "hairline=" .. (bar.rule.shown and tostring(-bar.rule.points.TOPLEFT[4]) or "-"),
            "bar=" .. tostring(bar.h))
        local out = {}
        for _, r in ipairs(page(tag .. " shop")) do
            local c = r.c
            if c.right then
                table.insert(out, "H" .. tostring(c.left.text) .. "@" .. x(c.left, "LEFT") .. "/" .. tostring(c.right.text)
                    .. "@" .. x(c.right, "RIGHT") .. "/" .. x(c.rule, "TOPLEFT") .. ":" .. tostring(c.h))
            elseif c.zebra then
                table.insert(out, (c.icon.shown and "i" or "") .. (c.zebra.shown and "#" or ".") .. (c.rule.shown and x(c.rule, "TOPLEFT") or "-")
                    .. ":" .. tostring(c.label.points.RIGHT and c.label.points.RIGHT[3]))
            end
        end
        print(tag .. " shop rows", table.concat(out, " "))
    end
    local function foot(tag)
        local f
        for _, c in ipairs(box.all_) do
            if c.kind == "Frame" and c.points.BOTTOMLEFT and not c.scrollChild then f = c end
        end
        local out = {}
        for _, b in ipairs(f.all_ or {}) do
            if b.shown and b.data then
                -- where it stands and how wide; * the primary's red
                table.insert(out, b.data.label .. (b.disabled and "(off)" or "") .. "@" .. tostring(b.points.LEFT
                    and b.points.LEFT[3]) .. "/" .. tostring(math.floor(b.w + 0.5)) .. (b.deed.shown and "*" or ""))
            end
        end
        local left
        for _, t in ipairs(f.all_ or {}) do if t.kind == "FontString" then left = t.text end end
        print(tag .. " foot", "left=" .. tostring(left), table.concat(out, " "))
        local t
        for _, c in ipairs(f.all_ or {}) do if c.kind == "FontString" then t = c end end
        if t and t.points.RIGHT then print(tag .. " foot text", "right=" .. tostring(t.points.RIGHT[3])) end
        return f
    end
    local function button(f, label)
        for _, b in ipairs(f.all_ or {}) do
            if b.shown and b.data and b.data.label == label then return b end
        end
    end
    local function press(tag, label)
        local f = foot(tag)
        local b = button(f, label)
        if not b then print(tag, "no " .. label) return end
        if b.disabled then print(tag .. " " .. label, "disabled") return end
        b.scripts.OnClick(b, "LeftButton")
    end
    local function tipOf(label)
        local f = foot("tip")
        local b = button(f, label)
        return b and b.data.tip or "-"
    end
    local function calls(tag)
        print(tag .. " calls", #W.calls > 0 and table.concat(W.calls, "; ") or "none")
        W.calls = {}
    end
    local function click(rows, label, button)
        for _, r in ipairs(rows) do
            if r.c.data.label == label then return r.c.scripts.OnClick(r.c, button or "LeftButton") end
        end
        print("npc", "no row " .. label)
    end

    -- gossip: Blizzard shows its frame, then the event
    state("npc closed")
    GossipFrame:Show()
    fire("GOSSIP_SHOW")
    state("npc gossip")
    for _, t in ipairs(headFrame.all_ or {}) do if t.portrait then portraitOf = t.portrait end end
    print("npc look", "bands=" .. inks(), "portrait=" .. tostring(portraitOf))
    -- the tracker asks for its reach while the box holds the chat: kept for after
    ns.chat.Reach(true, 0.5)
    state("npc gossip reach asked")
    local rows = page("npc gossip")
    shop("npc gossip")                   -- not a shop: no table
    foot("npc gossip")
    for _, r in ipairs(rows) do click(rows, r.c.data.label) end
    calls("npc gossip clicks")
    -- the keys: each clickable row numbered, the twelve keys bound over the bars
    local function bound(tag)
        local out = {}
        for k, v in pairs(overrides) do table.insert(out, k .. "=" .. v) end
        table.sort(out)
        print(tag .. " keys", #out > 0 and table.concat(out, " ") or "none", "sets=" .. overrideSets)
    end
    local function numbers(tag)
        local out = {}
        for _, r in ipairs(page(tag)) do
            local k = r.c.key
            table.insert(out, (k and k.shown ~= false and (k.text or "") ~= "" and k.text
                .. string.format("(%.2f,%.1f)", k.textColor and k.textColor[1] or -1, k.alpha or 1) or "-")
                .. "@" .. tostring(r.c.label.points.LEFT and r.c.label.points.LEFT[3]))
        end
        print(tag .. " numbers", table.concat(out, " "))
    end
    numbers("npc gossip")
    bound("npc gossip")
    local keyer = _G.MedalluinNPCKeys
    local function key(k) keyer.scripts.OnClick(keyer, k) end
    key("2"); key("4"); key("9"); key("SPACE")
    calls("npc gossip keys pressed")
    -- combat: the bars have their keys back until it ends
    inCombat = true
    fire("PLAYER_REGEN_DISABLED")
    bound("npc gossip combat")
    key("2")
    calls("npc gossip combat key")
    fire("GOSSIP_SHOW")
    bound("npc gossip combat redraw")
    inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    bound("npc gossip combat over")
    -- more choices than keys: the first twelve are numbered, = picks the twelfth
    local options = W.gossip.options
    W.gossip.options = {}
    for i = 1, 12 do
        table.insert(W.gossip.options, { name = "Choice " .. i, icon = 132060, gossipOptionID = 400 + i, orderIndex = i })
    end
    fire("GOSSIP_SHOW")
    numbers("npc gossip many")
    key("="); key("0")
    calls("npc gossip many keys")
    -- the log changes under the open gossip: nothing left to pick, nothing bound
    local active, available = W.gossip.active, W.gossip.available
    W.gossip.options, W.gossip.active, W.gossip.available = {}, {}, {}
    fire("QUEST_LOG_UPDATE")
    bound("npc gossip emptied")
    W.gossip.options, W.gossip.active, W.gossip.available = options, active, available
    fire("GOSSIP_SHOW")
    -- Escape: Blizzard hides its frame, and ours follows
    harnessBeside("npc gossip tips", MedalluinNPC)
    GossipFrame:Hide()
    state("npc gossip escaped")
    fire("GOSSIP_CLOSED")
    bound("npc gossip closed")

    -- the quest pages
    QuestFrame:Show()
    fire("QUEST_GREETING")
    state("npc greeting")
    rows = page("npc greeting")
    numbers("npc greeting")
    bound("npc greeting")
    key("1")
    calls("npc greeting key")
    for _, r in ipairs(rows) do click(rows, r.c.data.label) end
    calls("npc greeting clicks")
    fire("QUEST_DETAIL")
    state("npc detail")
    numbers("npc detail")
    bound("npc detail")
    key("1")
    key("SPACE")
    calls("npc detail space")
    ns.SetOption("npcSpace", false)
    bound("npc detail space off")
    key("SPACE")
    calls("npc detail space off")
    ns.SetOption("npcSpace", true)
    bound("npc detail space on")
    -- a reward's item arrives: Blizzard shows its rewards frame; ours puts it away
    local function rewardsAt(tag)
        local r = QuestInfoRewardsFrame
        print(tag, "rewards shown=" .. tostring(r.shown), "parent=" .. (r.parent == ns.hidden and "hidden"
            or r.parent and (r.parent.name or "?") or "none"))
    end
    QuestInfo_ShowRewards()
    rewardsAt("npc detail item update")
    -- the quest log's own rewards are left where the log put them
    local logChild = new("Frame", UIParent, "QuestLogDetailScrollChildFrame")
    QuestInfoRewardsFrame:SetParent(logChild)
    QuestInfoFrame.questLog = true
    QuestInfo_ShowRewards()
    rewardsAt("npc quest log rewards")
    QuestInfoFrame.questLog = nil
    page("npc detail")
    -- the blocks down the page: what each is, where it starts, the text's face
    -- (the dock's, under the list, after it: _)
    local function stack(tag)
        local function blocks(parent)
            local out = {}
            for _, c in ipairs(parent.all_ or {}) do
                if c.shown and c.points.TOPLEFT and c.points.TOPLEFT[3] == 0 then
                    local what = c.kind == "FontString" and ("text:" .. tostring(c.font and c.font[1]):match("[^\\]+$")
                        .. "/" .. tostring(c.font and c.font[2]) .. "+" .. tostring(c.spacing)
                        .. (c.textColor and c.textColor[1] == 1 and c.textColor[2] < 0.5 and "(red)" or ""))
                        or c.mid and ("pill:" .. c.mid.text .. "/" .. c.w) or c.sign and ("fold:" .. c.label.text)
                        or c.data and "item" or c.kind
                    table.insert(out, { -c.points.TOPLEFT[4], what })
                end
            end
            table.sort(out, function(a, b) return a[1] < b[1] end)
            return out
        end
        local parts = {}
        for _, s in ipairs(box.all_) do
            if s.kind == "ScrollFrame" then
                for _, o in ipairs(blocks(s.scrollChild)) do table.insert(parts, o[1] .. "=" .. o[2]) end
            end
        end
        local dock = ns.npc.dock
        if dock.shown then
            for _, o in ipairs(blocks(dock.body)) do table.insert(parts, "_" .. o[1] .. "=" .. o[2]) end
        end
        print(tag .. " stack", table.concat(parts, " "))
    end
    stack("npc detail")
    press("npc detail", "Accept")
    press("npc detail", "Decline")
    calls("npc detail")
    W.quest.auto = true
    fire("QUEST_DETAIL")
    press("npc detail auto", "Okay")
    calls("npc detail auto")
    fire("QUEST_PROGRESS")
    page("npc progress")
    -- Continue is off until the items are in: Space does nothing
    key("SPACE")
    calls("npc progress space")
    press("npc progress", "Continue")
    print("npc progress tip", tipOf("Continue"))
    W.quest.completable = true
    fire("QUEST_ITEM_UPDATE")
    press("npc progress ready", "Continue")
    calls("npc progress")
    fire("QUEST_COMPLETE")
    rows = page("npc reward")
    harnessBeside("npc reward tips", MedalluinNPC)
    bound("npc reward")
    -- back to the greeting: its rows again, and no button for Space
    fire("QUEST_GREETING")
    bound("npc greeting again")
    key("SPACE")
    calls("npc greeting space")
    fire("QUEST_COMPLETE")
    rows = page("npc reward")
    press("npc reward", "Complete Quest")
    print("npc reward tip", tipOf("Complete Quest"))
    -- the second choice picked: marked, and Complete hands it over
    click(rows, "choice2")
    page("npc reward picked")
    press("npc reward picked", "Complete Quest")
    calls("npc reward")
    W.quest.choices = 1
    fire("QUEST_COMPLETE")
    press("npc reward one", "Complete Quest")
    calls("npc reward one")
    W.quest.choices = 2
    -- a long text: the box stops at the screen's top, and scrolls
    W.quest.text = string.rep("A long tale of the pendants and the people who lost them. ", 400)
    fire("QUEST_DETAIL")
    state("npc detail long")
    -- on the screen: the box's top against the screen's (the console's units)
    print("npc detail long", "top=" .. tostring(math.floor(Region.GetTop(box) + 0.5)) .. "/"
        .. tostring(math.floor(UIParent:GetTop() + 0.5)),
        "range=" .. tostring(box.all_ and (function()
            for _, s in ipairs(box.all_) do if s.kind == "ScrollFrame" then return s:GetVerticalScrollRange() > 0 end end
        end)()))
    CloseQuest()
    fire("QUEST_FINISHED")
    state("npc quest closed")
    bound("npc quest closed")
    calls("npc quest closed")

    -- the vendor, whose tooltip names its trade
    W.trade = "General Goods"
    MerchantFrame:Show()
    fire("MERCHANT_SHOW")
    state("npc merchant")
    rows = page("npc merchant")
    harnessBeside("npc buy tips", MedalluinNPC)
    shop("npc merchant")
    foot("npc merchant")
    -- the uncached item arrives
    W.items[3].name = "Light Feather"
    fire("GET_ITEM_INFO_RECEIVED", 904)
    rows = page("npc merchant cached")
    print("npc merchant tips", "junk=" .. tipOf("Sell junk"), "repair=" .. tipOf("Repair"))
    -- a plain click buys one bundle; the extended cost and the high price ask
    click(rows, "Mining Pick")
    calls("npc merchant pick")
    click(rows, "Elemental Flux  x5  (3)")
    foot("npc merchant ask flux")
    press("npc merchant ask flux", "+")
    foot("npc merchant ask flux+")
    press("npc merchant ask flux+", "Buy")
    calls("npc merchant flux")
    click(rows, "Swift Mount")
    foot("npc merchant ask mount")
    press("npc merchant ask mount", "Cancel")
    calls("npc merchant mount cancelled")
    -- Shift asks up to a stack; chat-link and dress-up go elsewhere
    modsDown.SHIFT = true
    click(rows, "Elemental Flux  x5  (3)")
    modsDown.SHIFT = nil
    foot("npc merchant shift")
    press("npc merchant shift", "Cancel")
    W.modified, W.chatOpen = "CHATLINK", true
    click(rows, "Mining Pick")
    W.modified = "DRESSUP"
    click(rows, "Mining Pick")
    W.modified, W.chatOpen = nil, nil
    click(rows, "Mining Pick", "RightButton")
    calls("npc merchant modified")
    -- the guild bank's repair, where the guild allows it
    W.guild = true
    fire("UPDATE_INVENTORY_DURABILITY")
    press("npc merchant guild", "Guild")
    press("npc merchant guild", "Repair")
    calls("npc merchant repair")
    W.money = 50
    fire("PLAYER_MONEY")
    foot("npc merchant poor")
    W.money, W.repair = 23655, 0
    fire("UPDATE_INVENTORY_DURABILITY")
    foot("npc merchant repaired")
    print("npc merchant repaired tip", tipOf("Repair"))
    -- sell junk: the game's own where it has it, else each, out of combat
    press("npc merchant junk", "Sell junk")
    calls("npc merchant junk each")
    inCombat = true
    press("npc merchant junk combat", "Sell junk")
    calls("npc merchant junk combat")
    inCombat = false
    C_MerchantFrame.SellAllJunkItems = function() W.called("SellAllJunkItems") end
    press("npc merchant junk api", "Sell junk")
    calls("npc merchant junk api")
    -- no grey items left: nothing to sell
    local bag = W.bag
    W.bag = { [4] = bag[4] }
    fire("BAG_UPDATE_DELAYED")
    foot("npc merchant no junk")
    print("npc merchant no junk tip", tipOf("Sell junk"))
    W.bag = bag
    -- the sell tab: the bags' items the vendor buys, the most money first;
    -- a purchase being asked about is dropped on the way
    modsDown.SHIFT = true
    click(rows, "Elemental Flux  x5  (3)")
    modsDown.SHIFT = nil
    click(rows, "Sell")
    foot("npc sell")
    rows = page("npc sell")
    W.calls = {}
    click(rows, "junk701  x3")
    calls("npc sell click")
    for _, r in ipairs(rows) do
        if r.c.data.label == "Star Ruby  x2" then r.c.scripts.OnEnter(r.c) end
    end
    print("npc sell tip", tostring(GameTooltip.item))
    harnessBeside("npc vendor beside", MedalluinNPC)
    -- never in combat, and never once the vendor has gone
    inCombat = true
    click(rows, "junk701  x3")
    inCombat = false
    MerchantFrame:Hide()
    click(rows, "junk701  x3")
    MerchantFrame:Show()
    click(rows, "junk701  x3", "RightButton")
    calls("npc sell refused")
    -- chat-link and dress-up go elsewhere
    W.modified, W.chatOpen = "CHATLINK", true
    click(rows, "Star Ruby  x2")
    W.modified = "DRESSUP"
    click(rows, "Star Ruby  x2")
    W.modified, W.chatOpen = nil, nil
    calls("npc sell modified")
    -- nothing to sell
    W.bag = { [3] = bag[3] }
    fire("BAG_UPDATE_DELAYED")
    page("npc sell empty")
    W.bag = bag
    fire("BAG_UPDATE_DELAYED")
    -- the buyback tab
    click(rows, "Buyback")
    rows = page("npc buyback")
    harnessBeside("npc buyback tips", MedalluinNPC)
    click(rows, "Linen Cloth  x20")
    calls("npc buyback")
    -- locked items (inventory/locks.lua): on neither Sell nor Sell junk, and
    -- the game's own junk sale, which would take them, not used
    ns.locks.Toggle(705)
    ns.locks.Toggle(701)
    click(rows, "Sell")
    page("npc sell locked")
    foot("npc sell locked")
    print("npc sell locked junk tip", tipOf("Sell junk"))
    W.calls = {}
    press("npc sell locked", "Sell junk")
    calls("npc sell locked junk")
    ns.locks.Toggle(705)
    ns.locks.Toggle(701)
    fire("MERCHANT_SHOW")
    click(page("npc unlocked"), "Buyback")
    -- the character window over the chat: the box hides under it
    local character = ns.character and ns.character.window
    if character then
        character:Show()
        state("npc under character")
        character:Hide()
        state("npc after character")
    end
    -- the close cross goes through the game
    for _, c in ipairs(box.all_) do
        for _, b in ipairs(c.all_ or {}) do
            if b.kind == "Button" and b.scripts.OnClick and not b.data and c.points.TOPLEFT then
                b.scripts.OnClick(b, "LeftButton")
            end
        end
    end
    fire("MERCHANT_CLOSED")
    state("npc merchant closed")
    calls("npc merchant closed")
    local fns = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^MerchantFrame_") and merchantFns[k] ~= v then table.insert(fns, k) end
    end
    -- the trainer, from gossip: Blizzard loads its frame, our handler runs
    -- before the game shows it, and gossip is still open then
    print("npc trainer before load", "frame=" .. tostring(ClassTrainerFrame ~= nil))
    GossipFrame:Show()
    fire("GOSSIP_SHOW")
    W.LoadTrainer()
    W.trade = "Mage Trainer"
    local trainerBefore = keys(ClassTrainerFrame)
    W.calls = {}
    fire("TRAINER_SHOW")
    W.ShowTrainer()
    print("npc trainer", "parked=" .. tostring(ClassTrainerFrame.parent == ns.veil and "veil"
        or ClassTrainerFrame.parent == ns.hidden and "hidden"), "veil=" .. tostring(ns.veil.alpha) .. "/"
        .. tostring(ns.veil.scale) .. "/" .. tostring(ns.veil.shown))
    -- taken back by another hand: it returns to the veil, not the hidden parent
    ClassTrainerFrame:SetParent(UIParent)
    print("npc trainer reparked", ClassTrainerFrame.parent == ns.veil and "veil"
        or ClassTrainerFrame.parent == ns.hidden and "hidden" or "other",
        "visible=" .. tostring(ClassTrainerFrame:IsVisible()))
    state("npc trainer")
    calls("npc trainer show")
    rows = page("npc trainer")
    shop("npc trainer")
    -- nothing listed: no heading over no prices
    local services = W.services
    W.services = {}
    ns.npc.Update("trainer")
    shop("npc trainer empty")
    W.services = services
    -- a trade the game keeps secret is not written
    W.trade = secret()
    ns.npc.Update("trainer")
    state("npc trainer secret trade")
    W.trade = "Mage Trainer"
    ns.npc.Update("trainer")
    foot("npc trainer")
    stack("npc trainer")
    -- gossip closes after; the trainer stays
    GossipFrame:Hide()
    fire("GOSSIP_CLOSED")
    state("npc trainer gossip gone")
    -- the tabs, one at a time: each given to the game with the others off,
    -- and kept; on each, a pick: the one not yet, the known one
    local function pick(label)
        click(rows, label)
        stack("npc trainer pick " .. label)
        foot("npc trainer pick " .. label)
        print("npc trainer pick " .. label .. " tip", tipOf("Train"))
        rows = page("npc trainer pick " .. label)
    end
    click(rows, "Unavailable")
    calls("npc trainer unavailable")
    rows = page("npc trainer unavailable")
    print("npc trainer kept", tostring(ns.db.trainerFilter))
    pick("Fire Ward")
    click(rows, "Known")
    calls("npc trainer known")
    rows = page("npc trainer known")
    print("npc trainer kept", tostring(ns.db.trainerFilter))
    pick("Frostbolt (Rank 1)")
    -- back on Available: the one beyond your money
    click(rows, "Available")
    rows = page("npc trainer available")
    pick("Pyroblast (Rank 1)")
    -- Fireball: Train learns it by its index in the list as shown
    click(rows, "Fireball (Rank 2)")
    W.calls = {}
    press("npc trainer train", "Train")
    calls("npc trainer train")
    fire("TRAINER_UPDATE")
    rows = page("npc trainer trained")
    -- the pick follows its name when the list moves under it: a skill
    -- the game adds above it
    click(rows, "Pyroblast (Rank 1)")
    table.insert(W.services, 2, { name = "Flamestrike", rank = "Rank 1", category = "available", cost = 300 })
    fire("TRAINER_UPDATE")
    rows = page("npc trainer list moved")
    -- the folds: a skill line each in the game's order, those with none
    -- last (Other); the one picked stays docked under the list, the list's
    -- foot raised over it
    local function docked(tag)
        local sb = scrollOf.points.BOTTOMRIGHT
        print(tag .. " dock", "shown=" .. tostring(ns.npc.dock.shown), "h=" .. tostring(ns.npc.dock.h),
            "scrollFoot=" .. tostring(sb and sb[4]), "box=" .. tostring(box.h))
    end
    docked("npc trainer")
    stack("npc trainer folds")
    click(rows, "Fire (1)")
    rows = page("npc trainer Fire folded")
    stack("npc trainer Fire folded")
    foot("npc trainer Fire folded")
    click(rows, "Frost (1)", "RightButton")
    rows = page("npc trainer Frost right-clicked")
    click(rows, "Frost (1)")
    rows = page("npc trainer Frost folded too")
    click(rows, "Fire (1)")
    rows = page("npc trainer Fire unfolded")
    -- kept while the trainer is shown again
    fire("TRAINER_SHOW")
    rows = page("npc trainer folds kept")
    click(rows, "Frost (1)")
    -- the game gives no skill line: flat, as before
    local lines = {}
    for i, v in ipairs(W.services) do lines[i], v.line = v.line, nil end
    ns.npc.Update("trainer")
    rows = page("npc trainer no lines")
    for i, v in ipairs(W.services) do v.line = lines[i] end
    ns.npc.Update("trainer")
    -- nothing picked: no dock, the list down to the foot
    local picks = W.services
    W.services = {}
    ns.npc.Update("trainer")
    docked("npc trainer none")
    W.services = picks
    ns.npc.Update("trainer")
    docked("npc trainer back")
    -- Escape: the game hides its frame, the box follows
    harnessBeside("npc trainer tips", MedalluinNPC)
    ClassTrainerFrame:Hide()
    state("npc trainer escaped")
    fire("TRAINER_CLOSED")
    -- a second visit starts on the first you can learn (Flamestrike), not
    -- the last pick (Pyroblast);
    -- a filter kept from when the tabs were toggles reads as Available
    ns.db.trainerFilter = { used = true, unavailable = true }
    fire("TRAINER_SHOW")
    W.ShowTrainer()
    page("npc trainer again")
    CloseTrainer()
    fire("TRAINER_CLOSED")
    state("npc trainer closed")
    print("npc trainer untouched", tostring(keys(ClassTrainerFrame) == trainerBefore))
    -- the flight map: Blizzard's TaxiFrame parked, ours in the box's place
    local fl = _G.MedalluinFlight
    print("npc flight", "parked=" .. tostring(TaxiFrame.parent == ns.hidden), "frame=" .. tostring(fl ~= nil),
        "covered=" .. tostring(fl and fl.scripts.OnShow ~= nil))
    local taxiBefore = keys(TaxiFrame)
    local fstrip, fmap, flist = fl.all_[1], fl.all_[2], fl.all_[3]
    local fart, ftitle
    for _, t in ipairs(fmap.all_) do if t.kind == "Texture" and t.layer == "ARTWORK" then fart = t end end
    for _, t in ipairs(fstrip.all_) do if t.kind == "FontString" then ftitle = t end end
    -- the list's ground: as dark as a window's body
    for _, t in ipairs(flist.all_) do
        if t.kind == "Texture" and t.layer == "BACKGROUND" then print("npc flight list ink", "alpha=" .. t.color[4]) end
    end
    local function fstate(tag)
        local p = fl.points.BOTTOMLEFT
        print(tag, "flight=" .. tostring(fl.shown), "box=" .. tostring(box.shown), "h=" .. tostring(fl.h),
            "anchor=" .. (p and string.format("%s:%s %d,%d", p[1] == ns.chat.box and "chat" or "?", p[2], p[3], p[4])
                or "-"),
            "tracker=" .. tostring(tracker and tracker.shown), "title=" .. tostring(ftitle.text),
            "strip=" .. fstrip.h, "map=" .. fmap.w .. "x" .. fmap.h, "art=" .. fart.w .. "x" .. fart.h .. ":"
                .. tostring(fart.texture), "list=" .. tostring(flist.shown) .. "/" .. flist.h)
    end
    local function fnodes(tag)
        local out = {}
        for _, n in ipairs(fmap.all_) do
            if n.kind == "Button" and n.icon then
                local c = n.points.CENTER
                table.insert(out, string.format("%s@%d,%d:%s%s%s", n.shown and "on" or "off", c and c[3] or -1,
                    c and c[4] or -1, tostring(n.icon.texture):match("Icon%-(%a+)$") or "?",
                    n.glow.alpha == 1 and "+glow" or "", n.lit.shown and "+lit" or ""))
            end
        end
        print(tag .. " nodes", table.concat(out, " "))
    end
    local function froutes(tag)
        local out = {}
        for _, l in ipairs(fmap.all_) do
            if l.kind == "Line" and l.shown then
                table.insert(out, string.format("%.1f,%.1f>%.1f,%.1f", l.from[3], l.from[4], l.to[3], l.to[4]))
            end
        end
        print(tag .. " routes", #out > 0 and table.concat(out, " ") or "none")
    end
    local function frows(tag)
        local child
        for _, c in ipairs(flist.all_) do if c.kind == "ScrollFrame" then child = c.scrollChild end end
        local out, list = {}, {}
        for _, r in ipairs(child.all_) do
            if r.shown and r.data then
                local c = r.label.textColor
                table.insert(list, { y = -r.points.TOPLEFT[4], s = r.label.text .. " [" .. tostring(r.value.text) .. "]"
                    .. (c and string.format(" c=%.2f,%.2f,%.2f", c[1], c[2], c[3]) or ""), r = r })
            end
        end
        table.sort(list, function(x, y) return x.y < y.y end)
        for _, r in ipairs(list) do table.insert(out, r.s) end
        print(tag .. " rows", table.concat(out, " | "))
        return list
    end
    local function frow(list, label)
        for _, r in ipairs(list) do if r.r.label.text == label then return r.r end end
    end
    local function fnode(i)
        local k = 0
        for _, n in ipairs(fmap.all_) do
            if n.kind == "Button" and n.icon then
                k = k + 1
                if k == i then return n end
            end
        end
    end
    -- from gossip: the game shows its map while gossip is still open
    W.money = 10000
    GossipFrame:Show()
    fire("GOSSIP_SHOW")
    W.calls = {}
    fire("TAXIMAP_OPENED")
    TaxiFrame:Show()
    fstate("npc flight")
    calls("npc flight show")
    GossipFrame:Hide()
    fire("GOSSIP_CLOSED")
    fstate("npc flight gossip gone")
    bound("npc flight")
    fnodes("npc flight")
    froutes("npc flight")
    local frs = frows("npc flight")
    -- hovering: the two-leg flight through Darkshire, then out of reach, then a row
    W.tip = {}
    fnode(3).scripts.OnEnter(fnode(3))
    fnodes("npc flight hover sentinel")
    froutes("npc flight hover sentinel")
    print("npc flight hover sentinel tip", table.concat(W.tip, " / "))
    fnode(3).scripts.OnLeave(fnode(3))
    fnodes("npc flight left")
    froutes("npc flight left")
    fnode(5).scripts.OnEnter(fnode(5))
    fnodes("npc flight hover aerie")
    froutes("npc flight hover aerie")
    fnode(5).scripts.OnLeave(fnode(5))
    W.tip = {}
    local menethil = frow(frs, "Menethil Harbor")
    menethil.scripts.OnEnter(menethil)
    fnodes("npc flight hover row")
    froutes("npc flight hover row")
    print("npc flight hover row tip", table.concat(W.tip, " / "))
    menethil.scripts.OnLeave(menethil)
    -- flying: a row, a node; never from here or out of reach
    W.calls = {}
    local algaz = frow(frs, "Algaz Station")
    algaz.scripts.OnClick(algaz, "LeftButton")
    fnode(3).scripts.OnClick(fnode(3), "LeftButton")
    fnode(5).scripts.OnClick(fnode(5), "LeftButton")
    local here = frow(frs, "Ironforge")
    here.scripts.OnClick(here, "LeftButton")
    calls("npc flight fly")
    -- richer: Sentinel Hill no longer red
    W.money = 20000
    fire("PLAYER_MONEY")
    frows("npc flight richer")
    harnessBeside("npc flight tips", MedalluinFlight)
    -- Escape: the game hides its frame; ours follows and tells the game
    W.calls = {}
    TaxiFrame:Hide()
    fstate("npc flight escaped")
    calls("npc flight escaped")
    fire("TAXIMAP_CLOSED")
    -- no route from here: the game's words, and closed
    W.nodes[2].kind, W.nodes[3].kind, W.nodes[4].kind, W.nodes[6].kind = "UNREACHABLE", "UNREACHABLE", "NONE", "NONE"
    W.calls = {}
    TaxiFrame:Show()
    fstate("npc flight no paths")
    calls("npc flight no paths")
    print("npc flight untouched", tostring(keys(TaxiFrame) == taxiBefore))
    MerchantFrame.shown = false
    print("npc merchant untouched", tostring(keys(MerchantFrame) == merchantBefore),
        "fns=" .. (#fns > 0 and table.concat(fns, ",") or "none"))
end

if mailPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local M = mailWorld
    local box = ns.npc and ns.npc.box
    print("mail", "box=" .. tostring(box ~= nil), "parked=" .. tostring(MailFrame.parent == ns.hidden),
        "page=" .. tostring(ns.npc.pages.mail ~= nil))
    if not box then return end
    UIParent.fixed = { -612, -916, 1308, 164 }
    function UIParent:GetEffectiveScale() return ns.console:GetEffectiveScale() end
    local bar = ns.npc.bar
    local head, under, portrait
    for _, c in ipairs(box.all_) do
        if not head and c.points.TOPRIGHT and c.points.TOPLEFT then
            for _, t in ipairs(c.all_ or {}) do
                if t.kind == "FontString" and head and not under then under = t end
                if t.kind == "FontString" and not head then head = t end
                if t.kind == "Texture" and t.w == 42 then portrait = t end
            end
        end
    end
    local scroll
    for _, c in ipairs(box.all_) do if c.kind == "ScrollFrame" then scroll = c end end
    local function calls(tag)
        print(tag .. " calls", #M.calls > 0 and table.concat(M.calls, "; ") or "none")
        M.calls = {}
    end
    -- what the page shows, top down: a row or tile by its label and value, a
    -- box as label=text with the names it offers, the coins, the wells
    -- an icon cut past its square border: "#"
    local function Cut(t) return t and t.coords and t.coords[1] > 0 and "#" or "" end
    local function shown(tag)
        local out = {}
        for _, c in ipairs(scroll.scrollChild.all_ or {}) do
            -- the words and the pills
            local words = c.shown and (c.kind == "FontString" and c.text or c.mid and c.mid.text)
            if words then
                table.insert(out, { y = -(c.points.TOPLEFT and c.points.TOPLEFT[4] or 0), x = 0,
                    s = (c.mid and "[" .. words .. "]" or '"' .. words .. '"'), c = c })
            end
            if c.shown and c.data then
                local d, s = c.data, nil
                if c.edit then
                    local names = {}
                    for _, t in ipairs(c.names) do
                        if t.shown then table.insert(names, t.name .. (t.mark.shown and "*" or "")) end
                    end
                    s = d.label .. "=" .. tostring(c.edit:GetText()) .. (#names > 0 and " {" .. table.concat(names, ",")
                        .. "}" or "") .. (c.edit:HasFocus() and " _" or "") .. "/" .. (c.well or c.edit).h .. "/" .. c.h
                elseif c.boxes then
                    local t = {}
                    for _, e in ipairs(c.boxes) do table.insert(t, tostring(e:GetText())) end
                    s = d.label .. "=" .. table.concat(t, ".")
                elseif d.receive then
                    s = "well" .. (d.icon and ":" .. d.icon .. Cut(c.icon) or "")
                else
                    s = tostring(d.label) .. (c.icon and c.icon.shown ~= false and d.icon and Cut(c.icon) or "")
                        .. (d.value and d.value ~= "" and " [" .. d.value .. "]" or "")
                        .. (c.mark and c.mark.shown and " *" or "") .. (d.dim and " (dim)" or "")
                end
                table.insert(out, { y = -(c.points.TOPLEFT and c.points.TOPLEFT[4] or 0),
                    x = c.points.TOPLEFT and c.points.TOPLEFT[3] or 0, s = s, c = c })
            end
        end
        table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
        local tabs = {}
        for _, t in ipairs(bar.all_ or {}) do
            if t.shown and t.data then table.insert(tabs, t.data.label .. (t.mark.shown and "*" or "")) end
        end
        local rows = {}
        for _, r in ipairs(out) do table.insert(rows, r.s) end
        print(tag .. " page", "say=" .. (bar.say.shown and tostring(bar.say.text) or "-"), "tabs=" .. table.concat(tabs, ","))
        print(tag .. " rows", table.concat(rows, " | "))
        return out
    end
    local function footOf()
        for _, c in ipairs(box.all_) do
            if c.kind == "Frame" and c.points.BOTTOMLEFT and not c.scrollChild then return c end
        end
    end
    local function foot(tag)
        local f, out, left = footOf(), {}, nil
        for _, b in ipairs(f.all_ or {}) do
            if b.shown and b.data then
                table.insert(out, b.data.label .. (b.disabled and "(off)" or "") .. (b.deed.shown and "*" or ""))
            end
            if b.kind == "FontString" then left = b.text end
        end
        print(tag .. " foot", "left=" .. tostring(left), table.concat(out, " "))
    end
    local function press(tag, label)
        for _, b in ipairs(footOf().all_ or {}) do
            if b.shown and b.data and b.data.label == label then
                if b.disabled then print(tag .. " " .. label, "disabled: " .. tostring(b.data.tip)) return end
                return b.scripts.OnClick(b, "LeftButton")
            end
        end
        print(tag, "no " .. label)
    end
    local function tip(label)
        for _, b in ipairs(footOf().all_ or {}) do
            if b.shown and b.data and b.data.label == label then return tostring(b.data.tip) end
        end
        return "-"
    end
    local function click(tag, label, button)
        for _, r in ipairs(shown(tag)) do
            if r.s:sub(1, #label) == label then return r.c.scripts.OnClick(r.c, button or "LeftButton") end
        end
        print(tag, "no row " .. label)
    end
    local function tab(label)
        for _, t in ipairs(bar.all_ or {}) do
            if t.shown and t.data and t.data.label == label then return t.scripts.OnClick(t) end
        end
    end
    local function field(label)
        for _, c in ipairs(scroll.scrollChild.all_ or {}) do
            if c.shown and c.data and (c.edit or c.boxes) and c.data.label == label then return c end
        end
    end
    -- typing: the box takes focus, its text changes as the player's
    local function type_(label, text)
        local f = field(label)
        f.edit:SetFocus()
        f.edit:SetText(text)
        f.edit.scripts.OnTextChanged(f.edit, true)
    end
    local function book()
        local b = MedalluinDB.mail.Nordanaar
        return "alts=" .. table.concat(b.alts, ",") .. " recent=" .. table.concat(b.recent, ",")
    end

    -- ------------------------------------------------ the inbox
    print("mail book at login", book())
    MailFrame:Show()
    fire("MAIL_SHOW")
    print("mail open", "shown=" .. tostring(box.shown), "title=" .. tostring(head and head.text),
        "portrait=" .. tostring(portrait and portrait.texture), "under=" .. tostring(under and under.text))
    shown("mail inbox")
    foot("mail inbox")
    -- the box as tall on every tab and letter: the Send tab's height
    local function size(what) print("mail size " .. what, "h=" .. tostring(box.h)) end
    size("inbox")
    print("mail open all tip", tip("Open all"))
    -- the soonest beyond three days: the days no longer red
    local soon = M.inbox[5].days
    for _, l in ipairs(M.inbox) do l.days = l.days + 3 end
    fire("MAIL_INBOX_UPDATE")
    shown("mail later")
    for _, l in ipairs(M.inbox) do l.days = l.days - 3 end
    M.inbox[5].days = soon
    M.total = 60
    fire("MAIL_INBOX_UPDATE")
    shown("mail overflow")
    for a = 7, 30 do M.inbox[a] = { sender = "Alt" .. a, subject = "Spare", money = 0, days = 20 } end
    fire("MAIL_INBOX_UPDATE")
    size("long inbox")
    for a = 30, 7, -1 do M.inbox[a] = nil end
    fire("MAIL_INBOX_UPDATE")
    M.total = nil

    -- reading: the cloth, an item taken
    click("mail inbox", "Thalric")
    shown("mail read cloth")
    size("read")
    foot("mail read cloth")
    click("mail read cloth", "Linen Cloth")
    calls("mail take linen")
    M.Answer()
    shown("mail read cloth after")
    harnessBeside("mail letter tips", MedalluinNPC)
    press("mail read cloth", "Take all")
    calls("mail take all")
    click("mail read cloth", "‹ Inbox")
    shown("mail back")

    -- COD: the foot asks, and Cancel takes nothing; Pay takes it
    click("mail back", "Okun")
    shown("mail read cod")
    foot("mail read cod")
    click("mail read cod", "Heavy Leather")
    foot("mail cod asked")
    shown("mail cod asked")
    press("mail cod asked", "Cancel")
    calls("mail cod cancelled")
    foot("mail cod cancelled")
    click("mail read cod", "Heavy Leather")
    local money = M.money
    M.money = 5000
    fire("PLAYER_MONEY")
    foot("mail cod poor")
    M.money = money
    fire("PLAYER_MONEY")
    press("mail cod asked", "Pay")
    calls("mail cod paid")
    M.Answer()

    -- the auction's money: taken by its row, then the letter can go
    click("mail read cod", "‹ Inbox")
    click("mail back", "AH — Sold")
    shown("mail read auction")
    foot("mail read auction")
    -- the game deletes an auction letter it emptied: the page goes back
    click("mail read auction", "Take ")
    calls("mail auction money")
    M.Answer()
    shown("mail auction emptied")
    -- a letter of words only: Return, not Delete
    click("mail auction emptied", "Mira")
    shown("mail read words")
    foot("mail read words")
    press("mail read words", "Return")
    calls("mail returned")
    shown("mail after return")
    -- one that came back: it cannot go again
    click("mail after return", "Thalen")
    foot("mail read returned")
    print("mail return tip", tip("Return"))
    click("mail read returned", "‹ Inbox")
    -- a letter the game may delete, with money still in it: Take first
    M.inbox[#M.inbox + 1] = { sender = "Alliance Auction House", subject = "Outbid on Copper Ore", money = 700,
        days = 30, canDelete = true }
    fire("MAIL_INBOX_UPDATE")
    click("mail back", "AH — Outbid")
    foot("mail read outbid")
    print("mail delete tip", tip("Delete"))
    M.inbox[#M.inbox].money = 0
    M.inbox[#M.inbox].items = nil
    M.inbox[#M.inbox].canDelete = true
    fire("MAIL_INBOX_UPDATE")
    foot("mail outbid empty")
    press("mail outbid empty", "Delete")
    calls("mail deleted")
    shown("mail after delete")
    -- the letter read vanishes (the game closed it): back to the inbox
    click("mail after delete", "Thalric")
    fire("CLOSE_INBOX_ITEM", 1)
    shown("mail closed item")

    -- an auction's letter in words with a pattern's characters in them (another language)
    AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired - %s (100%)"
    M.inbox[#M.inbox + 1] = { sender = "Alliance Auction House", subject = "Auction expired - Copper Bar (100%)",
        money = 0, days = 30, canDelete = true }
    fire("MAIL_INBOX_UPDATE")
    shown("mail auction words")
    table.remove(M.inbox)
    AUCTION_EXPIRED_MAIL_SUBJECT = nil
    -- a letter of your own: no reply; one already a reply keeps its subject
    M.inbox[#M.inbox + 1] = { sender = "Ahrymx", subject = "Note", money = 0, days = 10, reply = true }
    M.inbox[#M.inbox + 1] = { sender = "Okun", subject = "RE: Your order", money = 0, days = 10, reply = true }
    fire("MAIL_INBOX_UPDATE")
    click("mail own", "Ahrymx")
    foot("mail read own")
    click("mail read own", "‹ Inbox")
    click("mail back", "Okun — RE:")
    press("mail read re", "Reply")
    shown("mail reply re")
    tab("Inbox")
    table.remove(M.inbox)
    table.remove(M.inbox)
    fire("MAIL_INBOX_UPDATE")
    M.calls = {}
    -- reply: the Send tab, To and Subject written, the game told
    click("mail closed item", "Thalric")
    press("mail read cloth", "Reply")
    calls("mail reply")
    shown("mail reply")

    -- ------------------------------------------------ open all
    tab("Inbox")
    calls("mail inbox tab")
    M.Fresh()
    M.free, M.money = 10, 23655
    fire("MAIL_INBOX_UPDATE")
    foot("mail fresh")
    press("mail fresh", "Open all")
    calls("mail open all 1")
    foot("mail opening 1")
    -- pending: the ticker's beats take nothing more
    M.Tick(3)
    calls("mail opening waits")
    -- the inbox drawn again while the command still waits: the game is asked
    fire("MAIL_INBOX_UPDATE")
    M.Tick(3)
    calls("mail opening still pending")
    local guard = 0
    while M.pending and guard < 20 do
        guard = guard + 1
        M.Answer()
        M.Tick(1)
        foot("mail opening " .. guard)
    end
    calls("mail opened")
    shown("mail opened")
    foot("mail opened")
    print("mail opening all off", "tickers=" .. #M.tickers, "cancelled=" .. tostring(M.tickers[1].cancelled))

    -- the bags fill: no free slot before an item
    M.Fresh()
    M.free, M.tickers = 1, {}
    fire("MAIL_INBOX_UPDATE")
    press("mail bags", "Open all")
    for _ = 1, 4 do M.Answer() M.Tick(1) end
    calls("mail bags full")
    foot("mail bags full")
    -- the pace: an answer alone sends nothing; the next goes a beat later
    M.Fresh()
    M.free, M.tickers = 10, {}
    fire("MAIL_INBOX_UPDATE")
    press("mail pace", "Open all")
    M.calls = {}
    M.Answer()
    calls("mail pace answered")
    M.Tick(1)
    calls("mail pace beat")
    press("mail pace", "Stop")
    M.calls = {}
    -- an item the game will not give (one of a kind): left, the rest taken
    M.Fresh()
    M.free, M.kept = 5, { [2589] = true }
    fire("MAIL_INBOX_UPDATE")
    press("mail kept", "Open all")
    for _ = 1, 6 do M.Answer() M.Tick(1) end
    calls("mail kept")
    foot("mail kept")
    shown("mail kept")
    -- the mailbox busy: refused, tried again after a pause, the count
    -- starting over on a success; refused twice and twice again, it goes on
    M.Fresh()
    M.free, M.busy = 10, 2
    fire("MAIL_INBOX_UPDATE")
    press("mail busy", "Open all")
    M.Answer()
    M.Tick(3)
    calls("mail busy paused")
    for _ = 1, 4 do M.Answer() M.Tick(7) end
    M.busy = 2
    for _ = 1, 6 do M.Answer() M.Tick(7) end
    calls("mail busy")
    foot("mail busy")
    -- refused three times running: it stops, and says why
    M.Fresh()
    M.free, M.busy = 10, 3
    fire("MAIL_INBOX_UPDATE")
    press("mail refused", "Open all")
    for _ = 1, 4 do M.Answer() M.Tick(7) end
    calls("mail refused")
    foot("mail refused")
    -- Stop
    M.Fresh()
    M.free = 10
    fire("MAIL_INBOX_UPDATE")
    press("mail stop", "Open all")
    foot("mail stop opening")
    press("mail stop opening", "Stop")
    M.Answer()
    M.Tick(2)
    harnessBeside("mail tips", MedalluinNPC)
    calls("mail stopped")
    foot("mail stopped")
    -- the mailbox closes mid-way
    M.Fresh()
    fire("MAIL_INBOX_UPDATE")
    press("mail closing", "Open all")
    MailFrame:Hide()
    fire("MAIL_CLOSED")
    M.Answer()
    M.Tick(2)
    calls("mail closed mid-way")
    print("mail closed", "shown=" .. tostring(box.shown))
    -- a command whose answer never comes: the next goes after a while
    MailFrame:Show()
    fire("MAIL_SHOW")
    M.Fresh()
    fire("MAIL_INBOX_UPDATE")
    press("mail lost", "Open all")
    M.pending, M.answers = false, {}
    M.Tick(3)
    calls("mail lost answer early")
    M.Tick(12)
    calls("mail lost answer late")
    press("mail lost", "Stop")
    M.calls = {}

    -- ------------------------------------------------ send
    tab("Send")
    calls("mail send tab")
    size("send")
    shown("mail send")
    foot("mail send")
    print("mail send tip", tip("Send"))
    -- To completes from the names kept
    type_("To", "th")
    shown("mail to th")
    type_("To", "o")
    shown("mail to o")
    type_("To", "a")
    shown("mail to a")
    type_("To", "ahr")
    shown("mail to ahr")
    type_("To", "Thalric")
    shown("mail to full")
    -- the box left: its names go
    type_("To", "Th")
    field("Subject").edit:SetFocus()
    shown("mail to left")
    type_("To", "Th")
    local to = field("To").edit
    to.scripts.OnTabPressed(to)
    shown("mail to tabbed")
    -- Tab with no names offered: on to Subject
    to.scripts.OnTabPressed(to)
    print("mail tab moves", "subject focused=" .. tostring(field("Subject").edit:HasFocus()))
    -- a click anywhere in the letter's well types in it
    local letter = field("Letter")
    letter.well.scripts.OnMouseDown(letter.well)
    print("mail letter well", "focused=" .. tostring(letter.edit:HasFocus()))
    -- a name clicked
    type_("To", "Th")
    for _, t in ipairs(field("To").names) do
        if t.shown and t.name == "Thalassa" then t.scripts.OnClick(t) end
    end
    shown("mail name clicked")
    print("mail send tip", tip("Send"))
    -- the box's text changed, not by typing (the game's SetText): the page is not told
    local toBox = field("To").edit
    toBox:SetText("Zed")
    toBox.scripts.OnTextChanged(toBox, false)
    fire("PLAYER_MONEY")
    print("mail set not typed", "to=" .. tostring(toBox:GetText()))
    -- a redraw while typing leaves the box alone
    type_("Subject", "Cloth")
    local subject, sets = field("Subject").edit, 0
    local set = subject.SetText
    subject.SetText = function(self, t) sets = sets + 1 set(self, t) end
    fire("PLAYER_MONEY")
    print("mail typing kept", "text=" .. tostring(subject:GetText()), "sets=" .. sets)
    subject.SetText = nil
    -- an item dropped in a well; a click with one on the cursor too
    local wells = {}
    for _, c in ipairs(scroll.scrollChild.all_) do if c.shown and c.data and c.data.receive then table.insert(wells, c) end end
    print("mail wells", #wells)
    C_Item.PickupItem(6948)
    wells[1].scripts.OnReceiveDrag(wells[1])
    fire("MAIL_SEND_INFO_UPDATE")
    calls("mail dropped")
    shown("mail attached")
    harnessBeside("mail attached tips", MedalluinNPC)
    foot("mail attached")
    inBags[6949] = true
    C_Item.PickupItem(6949)
    wells[2].scripts.OnClick(wells[2], "LeftButton")
    fire("MAIL_SEND_INFO_UPDATE")
    calls("mail clicked in")
    -- COD, only with items
    click("mail attached", "Cash on delivery")
    local coins = field("COD")
    coins.boxes[1]:SetText("1")
    coins.boxes[1].scripts.OnTextChanged(coins.boxes[1], true)
    coins.boxes[2]:SetText("05")
    coins.boxes[2].scripts.OnTextChanged(coins.boxes[2], true)
    shown("mail cod set")
    foot("mail cod set")
    print("mail cod tip", tip("Send"))
    coins.boxes[3]:SetText("7")
    coins.boxes[3].scripts.OnTextChanged(coins.boxes[3], false)
    fire("PLAYER_MONEY")
    shown("mail coins set not typed")
    -- where the boxes and the wells stand
    local at = {}
    for _, c in ipairs(scroll.scrollChild.all_) do
        if c.shown and c.data and (c.edit or c.boxes or c.data.receive) then
            table.insert(at, c.points.TOPLEFT[3] .. "," .. c.points.TOPLEFT[4])
        end
    end
    print("mail send layout", table.concat(at, " "))
    -- taken back: a right click, and a click with nothing on the cursor
    wells[2].scripts.OnClick(wells[2], "RightButton")
    wells[1].scripts.OnClick(wells[1], "LeftButton")
    fire("MAIL_SEND_INFO_UPDATE")
    calls("mail taken back")
    shown("mail no items")
    -- money beyond the purse
    coins = field("Money")
    coins.boxes[1]:SetText("50")
    coins.boxes[1].scripts.OnTextChanged(coins.boxes[1], true)
    print("mail poor tip", tip("Send"))
    coins.boxes[1]:SetText("")
    coins.boxes[1].scripts.OnTextChanged(coins.boxes[1], true)
    foot("mail money")
    -- sent: money, then cleared on success, the name first in the book
    type_("To", "Mira")
    press("mail send", "Send")
    calls("mail sent")
    foot("mail on its way")
    M.send = {}            -- the game takes the items with the letter
    fire("MAIL_SEND_SUCCESS")
    shown("mail sent")
    print("mail book", book())
    -- cash on delivery sent: the money is COD
    C_Item.PickupItem(6948)
    wells[1].scripts.OnReceiveDrag(wells[1])
    fire("MAIL_SEND_INFO_UPDATE")
    type_("To", "Okun")
    click("mail cod send", "Cash on delivery")
    coins = field("COD")
    coins.boxes[3]:SetText("50")
    coins.boxes[3].scripts.OnTextChanged(coins.boxes[3], true)
    M.calls = {}
    press("mail cod send", "Send")
    calls("mail cod sent")
    -- a failure lets it go again
    fire("MAIL_FAILED")
    foot("mail send failed")
    -- the book keeps ten
    for i = 1, 12 do
        type_("To", "Name" .. i)
        type_("Subject", "Hello")
        press("mail many", "Send")
        M.send = {}
        fire("MAIL_SEND_SUCCESS")
    end
    print("mail book many", book())
    press("mail clear", "Clear")
    calls("mail clear")
    -- no Close in the foot: the head's cross closes
    press("mail close", "Close")
    for _, c in ipairs(box.all_) do
        for _, b in ipairs(c.all_ or {}) do
            if b.icon and tostring(b.icon.texture):match("strips\\close$") then b.scripts.OnClick(b) end
        end
    end
    calls("mail close")
end
