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
-- Console > Minimap: the rule's triggers, the key's pin, the corner's size and place
local minimapPass = args[2] == "minimap" or args[3] == "minimap"
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
function Region:SetAttribute(k, v) self.attrs[k] = v end
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
local events = {}
function Region:RegisterUnitEvent(e, unit)
    if e == "UNIT_HEALTH_FREQUENT" then error("unknown event " .. e) end
    events[e] = events[e] or {}
    table.insert(events[e], self)
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
function Region:IsVisible() return self.shown end
function Region:IsShown() return self.shown end
function Region:UnregisterAllEvents() self.unregistered = true end
function Region:GetStringWidth() return #(self.text or "") * 7 end   -- ~Marcellus SC 15px
-- wrapped at its width, 6 a character, 14 a line
function Region:GetStringHeight()
    local w = self.w > 0 and self.w or 1e9
    return math.max(1, math.ceil(#(self.text or "") * 6 / w)) * 14
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
function Region:SetTexCoord(...) self.coords = { ... } end
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
-- a drag: StartMoving takes the frame, StopMovingOrSizing leaves it where
-- harnessDropAt says, on UIParent, as the game re-anchors a moved frame
function Region:StartMoving() self.isMoving = true end
function Region:StopMovingOrSizing()
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
MultiCastFlyoutFrame = new("Frame", MultiCastActionBarFrame, "MultiCastFlyoutFrame")
MultiCastFlyoutFrame.shown, MultiCastFlyoutFrame.w = false, 32
MultiCastFlyoutFrame.top = new("Texture", MultiCastFlyoutFrame, nil)
MultiCastFlyoutFrame.middle = new("Texture", MultiCastFlyoutFrame, nil)
MultiCastFlyoutFrame.buttons = {}
for i = 1, 3 do
    local b = new("CheckButton", MultiCastFlyoutFrame, "MultiCastFlyoutButton" .. i)
    b.w, b.h = 24, 24
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
        table.insert(events[e], self)
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
            if f.watched and f.unit then f:SetShown(UnitExists(f.unit) and true or false) end
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
    party2 = "Okun" })[u] end
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
    f.ResizeButton = new("Button", f, name .. "ResizeButton")
    f.ScrollBar = new("Frame", f)
    f.ScrollBar.w = 8
    f.ScrollBar:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
    f.ScrollBar:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0)
    local box = new("EditBox", f, name .. "EditBox")
    box.w, box.h = 5, 32
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
    table.insert(CHAT_FRAMES, name)
    return f
end
for i = 1, NUM_CHAT_WINDOWS do ChatWindow(i) end
GENERAL_CHAT_DOCK = new("Frame", UIParent, "GeneralDockManager")
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
alertAnchor()
QuickJoinToastButton = new("Button", UIParent, "QuickJoinToastButton")
QuickJoinToastButton.w, QuickJoinToastButton.h = 32, 32
QuickJoinToastButton:SetPoint("BOTTOMLEFT", ChatAlertFrame, "BOTTOMLEFT")

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
                    specIconID = src[4], totalAmount = v(amount), amountPerSecond = v(amount / 100),
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
    return b and { auraInstanceID = b.id, icon = b.icon, applications = b.count or 0,
        expirationTime = b.timed and 160 or 0 }
end
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
        partyLayout = rowPass and "horizontal" or "vertical" }
    or barOff and { actionBar = false } or savedRows and { rows = savedRows }
    or pagingPass and { rows = 3 }
    or savedBare and { bareIcons = true } or savedNoChat and { chat = false }
    or savedBeam and { xpCast = true, repCast = true }
    or savedSimParty and { simParty = true } or savedNoSide and { side = false }
    or savedNoBags and { bags = false } or nil
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
if bagsPass and modern then
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
            print(tag, GameTooltip.text, table.concat(lines, " | "))
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
    local tex = p:GetRegions()
    screen("sidePanel", p, string.format("strata=%s texture=%s coords=%.3f,%.3f,%.3f,%.3f", tostring(p.strata),
        tostring(tex.texture):match("[^\\]+$"), tex.coords[1], tex.coords[2], tex.coords[3], tex.coords[4]))
    -- the mirror of the chat panel about the screen's middle (1920 wide)
    if ns.chat then
        local cl, ct, cr, cb = rect(ns.chat.panel)
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
                local l, _, r = rect(v.tab)
                table.insert(list, string.format("%s@%.0f-%.0f%s", v.tab.label.text, l, r,
                    v.tab.selected[1].shown and "*" or ""))
            end
        end
        print("tabs", p.shown and "panel" or "panel hidden", #list > 0 and table.concat(list, " ") or "none")
    end
    local function column(v)
        local list = {}
        for _, b in ipairs(v.paint) do
            local l, t, r, bt = rect(b)
            table.insert(list, string.format("%s%s%s@%.0f,%.0f", b.glyph.texture:match("side%-(.*)$"),
                b.well.texture:match("on$") and "+" or "", b.glyph.vertex and string.format("(%.2f,%.2f,%.2f)",
                b.glyph.vertex[1], b.glyph.vertex[2], b.glyph.vertex[3]) or "", (l + r) / 2, (t + bt) / 2))
        end
        print("column " .. v.key, v.column.shown and "shown" or "hidden", table.concat(list, " "))
    end
    -- the scroll bar: its track, and the thumb when there is more than shows
    local track, bar
    for _, r in ipairs(p.all_) do
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
    p.scripts.OnMouseWheel(p, -3)
    lootState("loot scrolled")
    -- a row passes the wheel on to the panel
    for _, f in ipairs(L.body.all_) do
        if f.kind == "Button" and f.item and f.shown then
            f.scripts.OnMouseWheel(f, -1)
            break
        end
    end
    print("loot scrolled from a row", L.Thumb())
    p.scripts.OnMouseWheel(p, 1)
    thumb("loot scrolled")
    p.scripts.OnMouseWheel(p, -50)
    print("loot scrolled to the end", L.Thumb())
    thumb("loot at the end")
    p.scripts.OnMouseWheel(p, 99)
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
        p.scripts.OnMouseWheel(p, -1)
        meterState("meter scrolled one")
        thumb("meter scrolled one")
        p.scripts.OnMouseWheel(p, -10)
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
        -- the wheel: eleven auras, fewer rows; a row passes it on
        AL.all_[1].all_[5].scripts.OnMouseWheel(AL.all_[1].all_[5], -2)
        aurasState("auras scrolled two")
        thumb("auras")
        p.scripts.OnMouseWheel(p, -50)
        print("auras scrolled to the end", A.Thumb())
        -- the list shrinks under the scroll: back to what it can show
        click(A, 2)
        print("auras scrolled, timeless off", A.Thumb())
        click(A, 2)
        p.scripts.OnMouseWheel(p, 99)
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
        local m = t.medalluin
        return "blizzard=" .. (#lit > 0 and table.concat(lit, ",") or "none") .. " selected="
            .. tostring(m and m.selected[1].shown)
    end
    local function chatState(tag)
        local r = ChatFrame1:GetEffectiveScale() / chat.panel:GetEffectiveScale()
        print(tag, string.format("scale %.3f", r))
        screen("chatArea", chat.area)
        screen("ChatFrame1", ChatFrame1, art(ChatFrame1) .. " " .. tab(ChatFrame1))
        screen("ChatFrame2", ChatFrame2, art(ChatFrame2) .. " " .. tab(ChatFrame2))
        screen("ChatFrame3", ChatFrame3, art(ChatFrame3) .. " " .. tab(ChatFrame3))
        screen("editBox", ChatFrame1.editBox)
        -- the toast at the top of the button column: inside the
        -- panel, clear of the messages
        local t, c, a, p = resolve(QuickJoinToastButton), resolve(ChatFrame1.buttonFrame), resolve(chat.area),
            resolve(chat.panel)
        screen("friends", QuickJoinToastButton, string.format("inPanel=%s inColumn=%s leftOfArea=%s centred=%.1f",
            tostring(t[1] >= p[1] and t[2] >= p[2]), tostring(t[2] <= c[2] + 0.01 and t[4] <= c[4]),
            tostring(t[3] <= a[1] + 0.01), (t[1] + t[3]) / 2 - (c[1] + c[3]) / 2))
    end
    if not chat then
        print("chat none")
        screen("ChatFrame1", ChatFrame1, art(ChatFrame1) .. " " .. tab(ChatFrame1))
    else
        local p, t = chat.panel, chat.panel:GetRegions()
        screen("chatPanel", p, string.format("strata=%s texture=%s coords=%.3f,%.3f", tostring(p.strata),
            tostring(t.texture):match("[^\\]+$"), t.coords[2], t.coords[4]))
        chatState("chat")
        -- Blizzard's passes: its saved layout puts the frame back, a fade
        -- shows the background, the edit box takes focus, the tab changes
        ChatFrame1:ClearAllPoints()
        ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
        ChatFrame1Background:Show()
        ChatFrame1.ResizeButton:Show()
        ChatFrame1.editBox.focusLeft:SetShown(true)
        ChatAlertFrame:ClearAllPoints()
        alertAnchor()
        selectedChat = ChatFrame2
        FCFTab_UpdateColors(ChatFrame1Tab, false)
        FCFTab_UpdateColors(ChatFrame2Tab, true)
        chatState("chat after blizzard")
        -- the combat log torn off, the third window docked
        FCF_UnDockFrame(ChatFrame2)
        FCF_DockFrame(ChatFrame3)
        chatState("chat redocked")
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
        -- the console at a 1080-high UI: Blizzard's pieces need less room
        ns.console:SetScale(1)
        chatState("chat rescaled")
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
                    table.insert(list, string.format("%s(%s)@%.0f,%.0f", tostring(b.icon.texture),
                        tostring(b.count.text), (r[1] + r[3]) / 2 + 612, (r[2] + r[4]) / 2 + 916))
                end
            end
            print(tag, #list > 0 and table.concat(list, " ") or "none")
        end
        buffState("buffs")
        local unit = events.UNIT_AURA[1]
        local function aura(info) unit.scripts.OnEvent(unit, "UNIT_AURA", "player", info) end
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
    S.partyLayout:Set("widget")
    state("party layout: widget")
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
    -- the console's pets option is not the widget's
    S.partyPets:Set(false)
    state("console pets off: the widget keeps them")
    S.partyPets:Set(true)
    S.partyWidgetPets:Set(false)
    state("pets off")
    S.partyWidgetPets:Set(true)
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
        local function pets()
            local o = {}
            for i = 1, 4 do
                if ns.units["party" .. i].pet.shown then table.insert(o, "party" .. i) end
            end
            return table.concat(o, ",")
        end
        print("  party pets", pets())
        S.partyPets:Set(false)
        stateTick()
        print("  party pets, console's off", pets())
        S.partyWidgetPets:Set(false)
        stateTick()
        print("  party pets, widget's off", pets())
        S.partyPets:Set(true)
        S.partyWidgetPets:Set(true)
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
    ns.SetOption("editParty", plus(wasEdits))
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
    print("  party1 cell", n(ns.units.party1.w) .. "x" .. n(ns.units.party1.h), "buttons=" .. #E.byId.partyWidget.buttons())
    ns.SetOption("partyLayout", "console")
    ns.OpenEditor()
    window("layout console")
    piece("party1 on console", ns.units.party1, "role")
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
        for _, key in ipairs({ "MEDALLUIN_MINIMAP", "minimapAuto", "minimapAutoCombat", "minimapScale" }) do
            local c = ns.optionControls[key]
            -- a slider is greyed through its - and + buttons
            local hit = c.box or c.less or c
            table.insert(out, key .. "=" .. (hit:IsEnabled() and "on" or "grey"))
        end
        ns.CloseOptions()
        return table.concat(out, " ")
    end
    if not bezel then
        -- the Medallion: nothing moves, the page says so, the key says so
        print("minimap medallion", "moves=" .. tostring(ns.MinimapMoves()), "corner=" .. tostring(ns.MinimapInCorner()),
            "page " .. greyed())
        print("minimap shape medallion", string.format("map=%.0fx%.0f mask=%s hit insets=%s", Minimap.w, Minimap.h,
            tostring(Minimap.mask):match("[^\\]+$"), table.concat(Minimap.hitInsets or {}, ",")), clip())
        ns.ToggleMinimap()
        print("minimap medallion key", "corner=" .. tostring(ns.MinimapInCorner()), "pin=" .. tostring(ns.MinimapPinned()))
    else
        local function where(tag)
            print("minimap " .. tag, "corner=" .. tostring(Minimap.points.CENTER[1] == bezel),
                "bezel=" .. tostring(bezel.shown), "grid=" .. tostring(ns.bar7Frame.alpha),
                "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"), "pin=" .. tostring(ns.MinimapPinned()))
        end
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

        -- the key: pinned in the other place, through every trigger, until pressed again
        MedalluinToggleMinimap()
        where("key (from the binding)")
        hasTarget, inCombat = true, true
        fire("PLAYER_TARGET_CHANGED")
        fire("PLAYER_REGEN_DISABLED")
        where("pinned, combat and target")
        ns.ToggleMinimap()
        where("key again")
        ns.ToggleMinimap()
        where("key: pinned in the console")
        inCombat, hasTarget = false, false
        fire("PLAYER_REGEN_ENABLED")
        fire("PLAYER_TARGET_CHANGED")
        where("pinned in the console, out of combat")
        -- a party row wins over a pin: it needs the bay's foot
        local realRow = ns.PartyRowShown
        ns.PartyRowShown = function() return true end
        ns.UpdateMinimapLocation()
        where("pinned in the console, party row")
        ns.PartyRowShown = realRow
        ns.ToggleMinimap()
        where("released")

        -- size and place, in the corner; the console's scale leaves them be
        ns.ToggleMinimap()
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
            "inPage=" .. tostring(MultiCastActionButton5.parent == MultiCastActionPage2))
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
                            b.junk and " junk" or "", b.desat and " locked" or "", b.matches == false and " dim" or ""))
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
        local ours = {}
        for _, key in ipairs({ "OnClick", "PreClick", "PostClick" }) do
            if b.scripts[key] then table.insert(ours, key) end
        end
        for _, key in ipairs({ "GetBagID", "bagID", "GetSlotAndBagID" }) do
            if rawget(b, key) ~= nil then table.insert(ours, key) end
        end
        print("bags.item click", "template=" .. tostring(b.template), "ours=" .. (#ours > 0 and table.concat(ours, ",") or "none"))
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
    print("bags.old point", p and (p[2] .. "," .. p[3] .. "," .. p[4]))
    CloseAllBags()
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
