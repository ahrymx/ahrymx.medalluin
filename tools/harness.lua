-- Load Medaluin outside the game against a stubbed WoW API and print every
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
local ADDON = "WoW/Interface/AddOns/Medaluin/"
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
    if type(rel) ~= "table" then rel, rp, x, y = self.parent, p, rel, rp end
    if type(rp) ~= "string" then rp, x, y = p, rp, x end
    self.points[p] = { rel or self.parent, rp or p, x or 0, y or 0 }
end
function Region:ClearAllPoints() moved(); self.points, self.all = {}, nil end
function Region:SetAllPoints(rel) moved(); self.all = rel or self.parent end
function Region:SetSize(w, h) moved(); self.w, self.h = w, h end
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
            self.text = "<secret>"
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
function Region:IsEnabled() return true end
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
function Region:GetHeight() return self.h end
function Region:GetWidth() return self.w end
function Region:GetName() return self.name end
function Region:GetParent() return self.parent end
function Region:GetText() return self.text end
function Region:IsVisible() return self.shown end
function Region:IsShown() return self.shown end
function Region:UnregisterAllEvents() self.unregistered = true end
function Region:GetStringWidth() return #(self.text or "") * 7 end   -- ~Marcellus SC 15px
function Region:SetTexCoord(...) self.coords = { ... } end
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
function Region:SetPropagateKeyboardInput(v) self.propagate = v end

-- ------------------------------------------------------------ the API
UIParent = new("Frame", nil, "UIParent")
UIParent.isScreen = true
function UIParent:GetHeight() return 768 end
Minimap = new("Frame", UIParent, "Minimap")
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
MinimapCluster = new("Frame", UIParent, "MinimapCluster")
GameTooltip = new("Frame", UIParent, "GameTooltip")
PlayerFrame, TargetFrame = new("Frame", UIParent), new("Frame", UIParent)
MainMenuBar = new("Frame", UIParent, "MainMenuBar")

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

-- Forever's bar divider (a three-slice of textures) exists only on an Edit
-- Mode client; elsewhere it raises, as an unknown template does in WoW.
-- Events Forever does not have (BugSack, 2026-11-01): registering one raises
missingEvents = modern and { ROLE_POLL_UPDATE = true, QUEUE_STATUS_UPDATE = true } or {}
local DIVIDER = "HorizontalDividerTemplate"
harnessBarPage = 1      -- bar 1's page, where a button with no page of its own falls back to
function CreateFrame(kind, name, parent, template)
    if template == DIVIDER and not modern then error("unknown template " .. template) end
    local f = new(kind, parent, name)
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
-- Taint: Medaluin's code is insecure; only the game's own update (stateTick)
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
-- the player in combat, and their threat situation: nil off every threat
-- table, 0 to 3 on one (1 is "higher threat than the tank")
local threatOf = nil
function UnitAffectingCombat(u) return u == "player" and inCombat end
function UnitThreatSituation(u) if u == "player" then return threatOf end end
-- The game's unit watch runs every frame, not once: a watched button whose
-- unit does not exist is hidden again however it was shown. watchTick() is
-- that frame; a stub does not make a unit exist.
local watchedFrames = {}
function RegisterUnitWatch(f)
    f.watched = true
    watchedFrames[f] = true
    if f.unit and not UnitExists(f.unit) and not f.stub then f:Hide() end
end
function UnregisterUnitWatch(f) f.watched = false end
-- the player's stances and pet bar: none unless a pass says so
local shapeshiftForms, petBar = 0, false
function GetNumShapeshiftForms() return shapeshiftForms end
function PetHasActionBar() return petBar end
local function watchTick()
    for f in pairs(watchedFrames) do
        if f.watched and f.unit then f:SetShown(UnitExists(f.unit) and true or false) end
    end
end
function IsInGroup() return grouped end
local hasTarget = true
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
local bindings, bindingSaves = {}, {}
for i = 1, 12 do bindings[tostring(i)] = "ACTIONBUTTON" .. i end
-- a key bound to the centre grid's old buttons, before it took Action bar 7's
bindings.G = "CLICK MedaluinBar7Button3:LeftButton"
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
function GetCurrentBindingSet() return 2 end
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
function IsUsableAction() return true end
function IsActionInRange() return nil end
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

    -- the micro menu in Forever's order; Help is hidden there
    MicroMenu = new("Frame", UIParent, "MicroMenu")
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
        IsUsableAction = function() return true end,
        IsActionInRange = function() return nil end,
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

-- the settings page, recorded; atlas sizes as Forever's end caps
local page = { controls = {}, buttons = {}, settings = {}, subcategories = {} }
Settings = {
    RegisterVerticalLayoutCategory = function(name)
        page.name = name
        page.root = { name = name, rows = {}, GetID = function() return 7 end }
        return page.root
    end,
    RegisterVerticalLayoutSubcategory = function(parent, name)
        local id = #page.subcategories + 8
        local sub = { name = name, parent = parent, rows = {}, GetID = function() return id end }
        table.insert(page.subcategories, sub)
        return sub
    end,
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    -- As Blizzard_Setting.lua's ProxySettingMixin: the default may be a
    -- function, asked each time; ApplyValue writes only a changed value, then
    -- always calls back; NotifyUpdate calls back with the value read again.
    RegisterProxySetting = function(_, variable, kind, name, default, get, set)
        local key = variable:match("^Medaluin_(.+)$")
        local s = { variable = variable, key = key, kind = kind, name = name, get = get, set = set }
        function s:Default() if type(default) == "function" then return default() end return default end
        function s:Get() return self.get() end
        -- what the panel does when the player changes it
        function s:SetValueChangedCallback(fn) self.callback = fn end
        function s:Set(v)
            if self.get() ~= v then self.set(v) end
            if self.callback then self.callback(self, v) end
        end
        function s:NotifyUpdate()
            self.notified = (self.notified or 0) + 1
            if self.callback then self.callback(self, self.get()) end
        end
        -- Medaluin's own controls go through the setting, so the page shows the change
        function s:SetValue(v) self.viaPage = (self.viaPage or 0) + 1; self:Set(v) end
        page.settings[key] = s
        return s
    end,
    CreateControlTextContainer = function()
        local c = { data = {} }
        function c:Add(value, label) table.insert(self.data, { value = value, label = label }) end
        function c:GetData() return self.data end
        return c
    end,
    RegisterAddOnCategory = function() page.registered = true end,
    OpenToCategory = function(id) page.opened = id end,
}
for _, kind in ipairs({ "Checkbox", "Dropdown", "ColorSwatch" }) do
    Settings["Create" .. kind] = function(_, setting, a, b)
        local options = kind == "Dropdown" and a()
        local control = { kind = kind, setting = setting, options = options }
        table.insert(_.rows, setting.name)
        function control:SetParentInitializer(parent, predicate) self.parent, self.predicate = parent, predicate end
        table.insert(page.controls, control)
        return control
    end
end
local cursor
function GetCursorInfo() return cursor end
-- a page's rows in order: settings by name, [buttons], # headings
SettingsPanel = { GetLayout = function(_, cat)
    return { AddInitializer = function(_, i)
        if not i:match("^#") then table.insert(page.buttons, i) end
        table.insert(cat.rows, i:match("^#") and i or "[" .. i .. "]")
    end }
end }
local buttonClicks = {}
function CreateSettingsButtonInitializer(_, text, click)
    buttonClicks[text] = click
    return text
end
function HideUIPanel(f) f.shown = false end
function CreateSettingsListSectionHeaderInitializer(name) return "# " .. name end
StaticPopupDialogs = {}
SlashCmdList = {}
function ReloadUI() end
MedaluinDB = profilesPass and args[3] == "saved" and { consoleProfile = "light",
        profiles = { default = { drawer = 2 }, light = { rows = 2 } }, global = { lootMoney = false } }
    or profilesPass and { consoleProfile = "light", rows = 3, actionBar = true, bareIcons = true,
        artColor = "ffffffff", drawer = 2, sideTab = "loot", bagsPoint = { "TOP", "TOP", 4, -8 },
        bagsColumns = 12, retired = "kept" }
    or lightPass and { consoleProfile = "light", bareIcons = true, simParty = grouped }
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
for line in io.lines(ADDON .. "Medaluin.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(ADDON .. line:gsub("\\", "/")))
        chunk("Medaluin", ns)
    end
end
for _, f in ipairs(events.ADDON_LOADED or {}) do f.scripts.OnEvent(f, "ADDON_LOADED", "Medaluin") end
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
    print("page", page.name, page.registered and "registered" or "-", "buttons=" .. table.concat(page.buttons, ","))
    for _, c in ipairs(page.controls) do
        local s, choices = c.setting, {}
        for _, o in ipairs(c.options or {}) do table.insert(choices, o.value .. "=" .. o.label) end
        print(c.kind, s.name, s.variable, "saved=" .. tostring(s:Get()), "default=" .. tostring(s:Default()),
            c.parent and ("child, live=" .. tostring(c.predicate())) or "top", table.concat(choices, "; "))
    end
    -- the tree on the left, each page with its rows in order
    local function tree(cat, depth)
        print("tree", string.rep("  ", depth) .. cat.name, table.concat(cat.rows, " | "))
        for _, sub in ipairs(page.subcategories) do
            if sub.parent == cat then tree(sub, depth + 1) end
        end
    end
    tree(page.root, 0)
    SlashCmdList.MEDALUIN()
    print("/medaluin opens", tostring(page.opened))
    SlashCmdList.MDLUI("console")
    print("/mdlui console opens", tostring(page.opened))
    SlashCmdList.MDLUI()
    print("/mdlui opens", tostring(page.opened))
    SlashCmdList.MDLUI("unit")
    print("/mdlui unit opens", tostring(page.opened))
    -- Medaluin's minimap button: in the drawer, or on the minimap without one
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
            "viaPage=" .. tostring(page.settings.simParty.viaPage), "opens=" .. tostring(page.opened))
        tip("minimapButton tip on")
        mb.scripts.OnClick(mb, "RightButton")
        print("minimapButton right again", "simParty=" .. tostring(ns.db.simParty))
        GameTooltip.AddLine = add
    end
    if not ns.actionBar then
        print("tray none")
        -- no bar, no cast bar of Medaluin's: Blizzard's stays
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
                        .. " styled=" .. tostring(b.medaluinIcon ~= nil))
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
        print("side none", "panel=" .. tostring(_G.MedaluinSide ~= nil))
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
    print("lootQuality", ns.db.lootQuality, "through the page", page.settings.lootQuality.viaPage,
        "lootWho through the page", page.settings.lootWho.viaPage)
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
            for _, list in ipairs({ A.body.all_[1], A.body.all_[2] }) do
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
        A.body.all_[1].all_[5].scripts.OnMouseWheel(A.body.all_[1].all_[5], -2)
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
        local row = A.body.all_[1].all_[5]
        local rowsOf = {}
        for _, c in ipairs(A.body.all_[1].all_) do if c.kind == "StatusBar" then table.insert(rowsOf, c) end end
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
        for _, c in ipairs(A.body.all_[2].all_) do if c.kind == "StatusBar" and not debuffRow then debuffRow = c end end
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
        for _, list in ipairs({ A.body.all_[1], A.body.all_[2] }) do
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
        print("aurasColumns through the page", page.settings.aurasColumns.viaPage,
            "aurasTimeless through the page", page.settings.aurasTimeless.viaPage)
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
            local m, hl = f.medaluin, f:GetHighlightTexture()
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
        "portrait=" .. tostring(CharacterMicroButton.medaluin.tex.shown),
        "level=" .. tostring(QueueStatusButton.level),
        "over=" .. tostring(QueueStatusButton.level > CharacterMicroButton.level))
    screen("queueEye", QueueStatusButton)
    QueueStatusButton:Hide()
    print("queue eye unqueued", "shown=" .. tostring(QueueStatusButton.shown),
        "portrait=" .. tostring(CharacterMicroButton.medaluin.tex.shown))
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
    print("bags", "drawer=" .. tostring(_G.MedaluinBagDrawer ~= nil), table.concat(left, " "))
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
        local m = t.medaluin
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
        local n = {}
        for k, s in pairs(S) do if s.notified then table.insert(n, k .. "x" .. s.notified); s.notified = nil end end
        table.sort(n)
        print("profiles " .. tag, "profile=" .. ns.db.consoleProfile, "rows=" .. tostring(ns.db.rows),
            "bare=" .. tostring(ns.db.bareIcons), "drawer=" .. tostring(ns.db.drawer),
            "lootMoney=" .. tostring(ns.db.lootMoney), "sideTab=" .. tostring(ns.db.sideTab),
            "rowsDefault=" .. tostring(S.rows:Default()), "page.rows=" .. tostring(S.rows:Get()))
        print("  default", list(MedaluinDB.profiles.default))
        print("  light", list(MedaluinDB.profiles.light))
        print("  global", list(MedaluinDB.global))
        print("  top", "rows=" .. tostring(rawget(MedaluinDB, "rows")), "bareIcons=" .. tostring(rawget(MedaluinDB,
            "bareIcons")), "retired=" .. tostring(MedaluinDB.retired))
        print("  notified", table.concat(n, " "), "heard", table.concat(heard, " "))
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
    StaticPopupDialogs.MEDALUIN_RESET_PROFILE.OnAccept()
    state("light reset")
    S.consoleProfile:Set("default")
    state("default again")
    ns.ResetProfile()
    state("default reset")
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
        say("kb " .. tag, "on=" .. tostring(ns.keybinding), "banner=" .. tostring(_G.MedaluinKeybindBanner
            and _G.MedaluinKeybindBanner.shown), "binder=" .. tostring(binder.shown)
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
    -- the page's button closes the page and starts it
    SettingsPanel.shown = true
    function SettingsPanel:IsShown() return self.shown end
    buttonClicks["Bind keys"]()
    state("from the page")
    say("kb page closed", tostring(not SettingsPanel.shown))
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
        local hk = b7.medaluinHotkey or b7.HotKey
        say("kb grid", "keys=" .. keysOf(ns.BindingCommand(b7)),
            "buttonType=" .. tostring(b7.buttonType), "bare=" .. tostring(ns.db.bareIcons),
            "hotkey=" .. tostring(hk and hk.text))
    end
    binder.scripts.OnLeave(binder)
    state("left")
    -- the banner: Esc ends it, other keys go on to the game
    local banner = _G.MedaluinKeybindBanner
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
    -- which buttons Medaluin's own code set an attribute on (each a blocked
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
    -- after login: paged by the game's first update, none by Medaluin
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
    local dialog = StaticPopupDialogs.MEDALUIN_PAGING
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
        "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedaluinMinimapBezel),
        "bezelShown=" .. tostring(_G.MedaluinMinimapBezel.shown),
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
        "bezelShown=" .. tostring(_G.MedaluinMinimapBezel.shown),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    out("minimap(explore)", Minimap)
    -- Skyriding out of combat, no target: the grid comes out to fly on page
    -- 11, as the game's own conditional says, and goes back on landing
    local flight = ns.skyridingWatch
    local function sky(tag, value)
        flight.scripts.OnAttributeChanged(flight, "state-skyriding", value)
        print("skyriding " .. tag, "driver=" .. tostring(flight.stateDrivers and flight.stateDrivers.skyriding),
            "art=" .. tostring(ns.consoleTex.texture):match("[^\\]+$"),
            "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedaluinMinimapBezel),
            "bezelShown=" .. tostring(_G.MedaluinMinimapBezel.shown),
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
        "minimapRelocated=" .. tostring(Minimap.points.CENTER[1] == _G.MedaluinMinimapBezel),
        "bezelShown=" .. tostring(_G.MedaluinMinimapBezel.shown),
        "bar7Alpha=" .. tostring(ns.bar7Frame.alpha))
    out("minimap(combat)", Minimap)
    -- The game's update pages Bar 7: cat form (Bar 8, slots 85..94), then
    -- stealth in combat (Bar 10, slots 109..118); Medaluin's code never does
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
    -- Detached vertical party frames
    for i = 1, 4 do
        local p = ns.units["party" .. i]
        out("party" .. i, p, "bezel=" .. tostring(p.detachedBezel and p.detachedBezel.shown))
    end
    if keybindPass then KeybindPass() end
    if pagingPass then PagingPass() end
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
    local p4 = ns.units.party4
    print("party4.boss", tostring(p4.bossDebuff and p4.bossDebuff.shown),
        tostring(p4.bossDebuff and p4.bossDebuff.timer and p4.bossDebuff.timer.text))

    -- 1. Role icons at bottom outer edges
    print("party1.role", tostring(p1.roleFrame and p1.roleFrame.shown),
        "overArt=" .. tostring(p1.roleFrame.level > ns.levels.art),
        "point=" .. tostring(p1.roleFrame.points.CENTER and p1.roleFrame.points.CENTER[2]))
    print("party3.role", tostring(p3.roleFrame and p3.roleFrame.shown), "TANK")

    -- 2. Dead unit resurrect icon
    print("party1.rez alive", tostring(p1.rezIcon and p1.rezIcon.shown))
    p1.stub.dead = true
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")
    print("party1.rez dead", tostring(p1.rezIcon and p1.rezIcon.shown),
        "aboveName=" .. tostring(p1.rezIcon.points.BOTTOM and p1.rezIcon.points.BOTTOM[1] == p1.name))
    p1.stub.dead = false
    p1.scripts.OnEvent(p1, "UNIT_HEALTH")

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
    -- and stretched to the floor less its margins (within the even-total pixel)
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
                local reach = d.half - h - A.margin
                local w
                for _, b in pairs(ns.overheadUnits) do if b.shown and b.kind == d.kind then w = b.w end end
                print(tag, slot .. ":" .. d.kind, "cells=" .. n, "insideFloor=" .. tostring(inside),
                    "centred=" .. tostring(round(lo + hi) == 0), string.format("span=%d..%d", round(lo), round(hi)),
                    "fills=" .. tostring(round(hi) <= reach and reach - round(hi) <= n), "w=" .. tostring(w))
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
                for _, b in ipairs(ns.overheadRow) do if not b.medaluinFrame then return false end end
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
        "petEvents=" .. tostring(not PetActionBar.unregistered))

    -- no bosses: the companion deck moves to the top, on its own pieces
    page.settings.topBoss:Set(false)
    deckState("overhead.noBoss")
    cellState("overhead.noBoss.cells")
    rowState("overhead.noBoss.row")
    -- the pet alone over the full row (the 2026-11-01 screenshot): the row's
    -- tray is wider than one cell's deck, so the deck grows and the cell stretches
    page.settings.topFocus:Set(false)
    page.settings.topToT:Set(false)
    deckState("overhead.petOnly")
    cellState("overhead.petOnly.cells")
    -- and with bosses over it: the grown pet deck must grow the boss deck in
    -- turn, so the growth runs bottom up
    page.settings.topBoss:Set(true)
    deckState("overhead.bossPet")
    cellState("overhead.bossPet.cells")
    page.settings.topFocus:Set(true)
    page.settings.topToT:Set(true)
    -- every stretched width keeps the row's total even (centred on whole pixels)
    -- and the cells inside the floor, for any deck width a stack can reach
    local odd, over = 0, 0
    for _, kind in ipairs({ "boss", "unit" }) do
        for n = 1, 5 do
            local least = n * A.cell[kind] + (n - 1) * A.gap + 2 * A.deck[kind] + 2 * A.margin
            for w = least, least + 400, 2 do
                local cw = ns.OverheadCellWidth(kind, n, w)
                local total = n * cw + (n - 1) * A.gap
                if total % 2 == 1 then odd = odd + 1 end
                if total > w - 2 * A.deck[kind] - 2 * A.margin or cw < A.cell[kind] then over = over + 1 end
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
    -- not simulating: nothing to show; then a pet arrives (UNIT_PET for the
    -- player) with its bar, and the row stands alone at the top
    page.settings.simParty:Set(false)
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

    -- 6. The simulation panel: shown while simulating, its buttons in order
    -- (bosses -, count, +; dead 1-4; in range 1-4; ready, role; end)
    local sp = _G.MedaluinSimPanel
    local spb = {}
    for _, c in ipairs(sp.all_) do if c.kind == "Button" then table.insert(spb, c) end end
    local function press(i) spb[i].scripts.OnClick(spb[i], "LeftButton") end
    local function panelState(tag)
        local out = {}
        for i, b in ipairs(spb) do
            table.insert(out, string.format("%s%s%s", b.label.text, b.on.shown and "*" or "",
                b.alpha == 0.4 and "(off)" or ""))
            if i == 3 or i == 7 or i == 11 or i == 13 then table.insert(out, "|") end
        end
        print(tag, "shown=" .. tostring(sp.shown), table.concat(out, " "))
    end
    local function bosses()
        local out = {}
        for i = 1, 5 do
            local b = ns.overheadUnits["boss" .. i]
            if b.shown then table.insert(out, tostring(b.name.text)) end
        end
        return #out .. " " .. table.concat(out, ", ")
    end
    local function members(tag)
        local out = {}
        for i = 1, 4 do
            local b = ns.units["party" .. i]
            local st = b.statusWidget
            local s = st.shown and st.icon.coords and string.format("%.2f", st.icon.coords[1]) or "-"
            table.insert(out, string.format("p%d:hp=%s,rez=%s,a=%.2f,check=%s", i, tostring(b.health.value),
                tostring(b.rezIcon.shown), b.alpha or 1, s))
        end
        print(tag, table.concat(out, " "))
    end
    local function wait(seconds)
        for _ = 1, math.floor(seconds / 0.1 + 0.5) do sp.scripts.OnUpdate(sp, 0.1) end
    end
    print("simPanel.box", string.format("w=%s h=%s", tostring(sp.w), tostring(sp.h)),
        "strata=" .. tostring(sp.strata), "point=" .. tostring(sp.points.LEFT and sp.points.LEFT[2]))
    panelState("simPanel")
    print("simPanel.bosses", bosses())
    press(3)
    press(3)
    press(3)
    panelState("simPanel.five")
    print("simPanel.bosses five", bosses())
    press(2)
    panelState("simPanel.none")
    print("simPanel.bosses none", bosses())
    press(1)
    press(2)
    print("simPanel.bosses all again", bosses())
    for _ = 1, 3 do press(1) end
    print("simPanel.bosses back to two", bosses())
    -- deaths and range
    press(4)
    press(7)
    press(9)
    panelState("simPanel.dead1,4 away2")
    members("simPanel.members")
    press(4)
    press(7)
    press(9)
    members("simPanel.members restored")
    page.settings.partyRange:Set(0)
    panelState("simPanel.range fade off")
    page.settings.partyRange:Set(40)
    -- a ready check: all waiting, then one answer each STEP, then cleared
    press(12)
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
    press(13)
    ns.units.party4.stub = p4stub
    panelState("simPanel.role")
    wait(0.6)
    members("role.one answered")
    for _, f in ipairs(events.PLAYER_REGEN_DISABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    for _, f in ipairs(events.PLAYER_REGEN_ENABLED or {}) do f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    members("role.fight")
    panelState("simPanel.after fight")
    -- a check under way when the simulation ends is cleared with it
    press(12)
    press(14)
    print("simPanel.ended", "simParty=" .. tostring(ns.db.simParty), "shown=" .. tostring(sp.shown))
    members("ended")
    page.settings.simParty:Set(true)
    panelState("simPanel.again")
end

if bagsPass then
    local function fire(e, ...)
        for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, ...) end
    end
    local w = _G.MedaluinBags
    print("bags", "window=" .. tostring(w ~= nil), "combined=" .. tostring(ContainerFrameCombinedBags ~= nil),
        "setting=" .. tostring(ns.db.bags))
    if not w then return end
    local W = bagWorld
    -- a slot's place in the body: column, and its top in pixels
    local function at(b)
        local p = b.points.TOPLEFT
        return string.format("%d,%d", p[3] / 41, -p[4])
    end
    local function slot(bag, i) return _G["MedaluinBagsItem" .. bag .. "_" .. i] end
    local function grid(tag)
        print(tag, "shown=" .. tostring(w.shown), string.format("size=%dx%d", w.w, w.h),
            "body=" .. string.format("%dx%d", w.parent and _G.MedaluinBagsBag0.parent.w or 0, _G.MedaluinBagsBag0.parent.h))
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
                "id=" .. tostring(_G["MedaluinBagsBag" .. bag] and _G["MedaluinBagsBag" .. bag]:GetID()),
                table.concat(items, "; "))
        end
        local heads = {}
        for _, r in ipairs(_G.MedaluinBagsBag0.parent.all_) do
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
    print("bags.strata", w.strata, "parent=" .. tostring(w.parent == UIParent), "search=" .. tostring(_G.MedaluinBagsSearch ~= nil))

    -- 2. Blizzard opens the bags (the B key): the window follows
    W.reads = 0
    OpenAllBags()
    blizz("bags.open")
    print("bags.reads on open", W.reads)
    grid("bags.grid")
    chrome("bags.chrome")
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
    print("bags.lock", "3:2 desaturated=" .. tostring(_G.MedaluinBagsItem3_2.desat))
    W.items["3:2"].isLocked = false

    -- 5. the groups
    page.settings.bagsView:Set("groups")
    grid("bags.groups")
    chrome("bags.groups chrome")
    -- the window's own button goes back, through the page
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "Grid" then r.scripts.OnClick(r) end
    end
    print("bags.view button", ns.db.bagsView, "viaPage=" .. tostring(page.settings.bagsView.viaPage))
    for _, r in ipairs(w.all_) do
        if r.kind == "Button" and r.label and r.label.text == "Groups" then
            r.scripts.OnEnter(r)
            print("bags.view tip", tostring(GameTooltip.text))
        end
    end

    -- 6. the search, the client's: what does not match is dimmed
    local box = _G.MedaluinBagsSearch
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
    for _, c in ipairs(page.controls) do
        local st = c.setting
        if st.key:match("^bags") then
            local choices = {}
            for _, o in ipairs(c.options or {}) do table.insert(choices, o.value .. "=" .. o.label) end
            print("bags.page", c.kind, st.name, "default=" .. tostring(st:Default()),
                c.parent and ("child, live=" .. tostring(c.predicate())) or "top", table.concat(choices, "; "))
        end
    end
    SlashCmdList.MDLUI("bags")
    print("/mdlui bags opens", tostring(page.opened))

    -- 15. the head's rule: under the buttons, over the slots
    OpenAllBags()
    local rule, closeTop = w.rule, nil
    print("bags.rule", "y=" .. -rule.points.TOPLEFT[4], "inset=" .. rule.points.TOPLEFT[3] .. "," .. rule.points.TOPRIGHT[3],
        "h=" .. rule.h, "slots from=" .. -_G.MedaluinBagsBag0.parent.points.TOPLEFT[4])

    -- 16. the drawer: Bags opens it above the window, growing to the right
    local title = w.title
    title.scripts.OnEnter(title)
    print("bags.title tip", tostring(GameTooltip.text))
    title.scripts.OnClick(title)
    local d = _G.MedaluinBagsDrawer
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
    print("bags.drawer styled", "edge=" .. tostring(CharacterBag0Slot.medaluin ~= nil),
        "ring styled=" .. tostring(KeyRingButton.medaluin ~= nil))
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
    local g = _G.MedaluinBagsGrip
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
