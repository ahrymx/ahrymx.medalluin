-- Load Medaluin outside the game against a stubbed WoW API and print every
-- named region's resolved rectangle, in art pixels from the console's
-- top-left. tools/preview.py draws them over the art.
--
--   lua5.1 tools/harness.lua [solo|group] [strips | bar [nobar|rows2|rows3|bare]] [modern] [CLASS]
--
-- "bar" prints the action bar instead, as 1080p screen pixels to compare
-- with assets/layer2.png: the settings page, the bar, its plate and pager,
-- the class resource in the lower row (CLASS, PALADIN by default), a cast
-- over it and its interruption, the adopted buttons, then the live options
-- played through the page (art colour, each visibility mode) and a page
-- change. "nobar" plays a saved
-- Action bar option that is off; "rows2" and "rows3" a saved Rows option;
-- "bare" a saved Bare icons option.
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
local barOff = args[3] == "nobar"
local savedRows = tonumber((args[3] or ""):match("^rows(%d)$"))
local savedBare = args[3] == "bare"
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
Region.__index = function(self, k)
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
function Region:SetPoint(p, rel, rp, x, y)
    if type(rel) ~= "table" then rel, rp, x, y = self.parent, p, rel, rp end
    if type(rp) ~= "string" then rp, x, y = p, rp, x end
    self.points[p] = { rel or self.parent, rp or p, x or 0, y or 0 }
end
function Region:ClearAllPoints() self.points = {} end
function Region:SetAllPoints(rel) self.all = rel or self.parent end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale or 1 end
function Region:GetRegions()
    local out = {}
    for _, f in ipairs(self.all_ or {}) do
        if f.kind == "Texture" or f.kind == "FontString" then table.insert(out, f) end
    end
    return unpack(out)
end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetFrameLevel() return self.level end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetFrameStrata() return "LOW" end
function Region:SetParent(p) self.parent = p end
function Region:SetShown(s) self.shown = s end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetScript(k, f) self.scripts[k] = f end
function Region:SetAttribute(k, v) self.attrs[k] = v end
function Region:SetTexture(t) self.texture = t end
function Region:SetColorTexture(r, g, b, a) self.color, self.atlas = { r, g, b, a }, nil end
function Region:SetAtlas(a) self.atlas = a end
function Region:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
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
function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
local events = {}
function Region:RegisterUnitEvent(e)
    if e == "UNIT_HEALTH_FREQUENT" then error("unknown event " .. e) end
    events[e] = events[e] or {}
    table.insert(events[e], self)
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
function Region:GetText() return self.text end
function Region:IsVisible() return self.shown end
function Region:IsShown() return self.shown end
function Region:GetStringWidth() return #(self.text or "") * 7 end   -- ~Marcellus SC 15px
function Region:SetTexCoord(...) self.coords = { ... } end
function Region:SetDesaturated(d) self.desaturated = d end
function Region:CreateMaskTexture() return new("MaskTexture", self) end
local mouseOver = false
function Region:IsMouseOver() return mouseOver end
function Region:GetAlpha() return self.alpha or 1 end

-- ------------------------------------------------------------ the API
UIParent = new("Frame", nil, "UIParent")
UIParent.isScreen = true
function UIParent:GetHeight() return 768 end
Minimap = new("Frame", UIParent, "Minimap")
MinimapCluster = new("Frame", UIParent, "MinimapCluster")
GameTooltip = new("Frame", UIParent, "GameTooltip")
PlayerFrame, TargetFrame = new("Frame", UIParent), new("Frame", UIParent)
MainMenuBar = new("Frame", UIParent, "MainMenuBar")

-- Blizzard's action buttons, with the parts bars/buttons.lua restyles.
local function ActionButton(name, parent, action)
    local b = new("CheckButton", parent, name)
    b.w, b.h, b.action = 36, 36, action
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
for _, n in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot" }) do
    local b = new("CheckButton", MainMenuBar, n)
    b.w, b.h = 37, 37
    b.icon = new("Texture", b, n .. "IconTexture")
end
KeyRingButton = new("CheckButton", MainMenuBar, "KeyRingButton")
for i = 1, 12 do
    ActionButton("ActionButton" .. i, MainMenuBar, i)
    ActionButton("MultiBarBottomLeftButton" .. i, MainMenuBar, 60 + i)
    ActionButton("MultiBarBottomRightButton" .. i, MainMenuBar, 48 + i)
end

-- Forever's bar divider (a three-slice of textures) exists only on an Edit
-- Mode client; elsewhere it raises, as an unknown template does in WoW.
local DIVIDER = "HorizontalDividerTemplate"
function CreateFrame(kind, name, parent, template)
    if template == DIVIDER and not modern then error("unknown template " .. template) end
    local f = new(kind, parent, name)
    if template == DIVIDER then
        f.template, f.w = template, 12
        for _ = 1, 3 do new("Texture", f) end
    end
    function f:RegisterEvent(e) events[e] = events[e] or {}; table.insert(events[e], self) end
    return f
end
function InCombatLockdown() return false end
function RegisterUnitWatch(f) f.watched = true end
function IsInGroup() return grouped end
function UnitExists(u) return u == "player" or u == "target" or (grouped and u:match("^party[12]$")) end
function UnitName(u) return ({ player = "Ahrymx", target = "Defias Pillager", party1 = "Thalric",
    party2 = "Okun" })[u] end
function UnitClass() return class, class end
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
function hooksecurefunc(t, k, f)
    if type(t) == "string" then t, k, f = _G, t, k end
    local old = t[k]
    t[k] = function(...) old(...); f(...) end
end
function GetActionCooldown(a) if a == 63 then return 90, 33, 1 end return 0, 0, 1 end
function HasAction() return true end
function IsUsableAction() return true end
function IsActionInRange() return nil end
local casting = false
FAILED, INTERRUPTED = "Failed", "Interrupted"
-- Frostbolt, a second into two (times in ms; GetTime is 100), cast id 7
function UnitCastingInfo()
    if casting then return "Frostbolt", nil, nil, 99000, 101000, false, 7 end
end
function SetPortraitTexture(t, u) t.portrait = u end
function GetContainerNumSlots(bag) return bag == 0 and 16 or 14 end
function GetContainerNumFreeSlots(bag) return bag == 0 and 4 or 8, 0 end
function GetInventoryItemDurability(i) if i == 5 then return 30, 100 end end
function GameTime_GetTime() return "11:39" end
function UnitChannelInfo() end
local catForm = false
function UnitPowerType() return catForm and 3 or 0 end
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
format, unpack = string.format, unpack

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
    MultiBarBottomLeft = new("Frame", UIParent, "MultiBarBottomLeft")
    MultiBarBottomRight = new("Frame", UIParent, "MultiBarBottomRight")
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
    for _, b in ipairs(bagButtons) do
        b.parent = BagsBar
        b.normalTex, b.pushedTex, b.highlightTex = new("Texture", b), new("Texture", b), new("Texture", b)
        b.SquareMask, b.SlotHighlightTexture = new("MaskTexture", b), new("Texture", b)
        function b:UpdateTextures()
            self:GetNormalTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
            self:GetPushedTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
            self:GetHighlightTexture():SetAtlas("ui-hud-actionbar-iconframe-bags")
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
    Enum = { LuaCurveType = { Linear = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
    function UnitCastingInfo()
        if casting then return "Sinister Strike", nil, nil, secret(), secret(), false, secret() end
    end
    function UnitCastingDuration() return { GetRemainingDuration = secret } end
    function UnitChannelDuration() end
end

-- the settings page, recorded; atlas sizes as Forever's end caps
local page = { controls = {}, buttons = {}, settings = {} }
Settings = {
    RegisterVerticalLayoutCategory = function(name)
        page.name = name
        return { GetID = function() return 7 end }
    end,
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    RegisterAddOnSetting = function(_, variable, key, tbl, kind, name, default)
        local s = { variable = variable, key = key, tbl = tbl, kind = kind, name = name, default = default }
        -- what the panel does when the player changes it
        function s:SetValueChangedCallback(fn) self.callback = fn end
        function s:Set(v) self.tbl[self.key] = v; if self.callback then self.callback(self, v) end end
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
        function control:SetParentInitializer(parent, predicate) self.parent, self.predicate = parent, predicate end
        table.insert(page.controls, control)
        return control
    end
end
local cursor
function GetCursorInfo() return cursor end
SettingsPanel = { GetLayout = function()
    return { AddInitializer = function(_, i) table.insert(page.buttons, i) end }
end }
function CreateSettingsButtonInitializer(_, text) return text end
SlashCmdList = {}
function ReloadUI() end
MedaluinDB = barOff and { actionBar = false } or savedRows and { rows = savedRows }
    or savedBare and { bareIcons = true } or nil
if modern then
    C_Texture = { GetAtlasInfo = function() return { width = 154, height = 95 } end }
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
for _, b in pairs(ns.units) do
    if UnitExists(b.unit) and b.scripts.OnShow then b.scripts.OnShow(b) end
end

-- The console's own rectangle defines the origin: its top-left is (0, 0).
local c = ns.console
scaleRoot = c
c.rect = { 0, 0, ns.art.width, ns.art.height }
local function out(tag, f, extra)
    local r = resolve(f)
    print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1], r[2], r[3], r[4], extra or ""))
end

if barPass then
    -- the screen in console units: the console's top-left is (612, 916)
    UIParent.rect = { -612, -916, 1308, 164 }
    local function screen(tag, f, extra)
        local r = resolve(f)
        print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1] + 612, r[2] + 916, r[3] + 612,
            r[4] + 916, extra or ""))
    end
    print("page", page.name, page.registered and "registered" or "-", "buttons=" .. table.concat(page.buttons, ","))
    for _, c in ipairs(page.controls) do
        local s, choices = c.setting, {}
        for _, o in ipairs(c.options or {}) do table.insert(choices, o.value .. "=" .. o.label) end
        print(c.kind, s.name, s.variable, "saved=" .. tostring(s.tbl[s.key]), "default=" .. tostring(s.default),
            c.parent and ("child, live=" .. tostring(c.predicate())) or "top", table.concat(choices, "; "))
    end
    SlashCmdList.MEDALUIN()
    print("/medaluin opens", tostring(page.opened))
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
        local strip, shown = ns.barPower, {}
        screen("lowRow", strip, "level=" .. strip.level)
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
        -- the cast bar over the class resource: idle, a cast, its interruption
        local cb = ns.barCast
        local function castState(tag)
            print(tag, string.format("alpha=%s value=%s name=%s clock=%s colour=%s", tostring(cb.alpha),
                tostring(cb.value), tostring(cb.name.text), tostring(cb.clock.text),
                cb.barColor and string.format("%.2f", cb.barColor[1]) or "-"))
        end
        screen("cast", cb, "level=" .. cb.level .. " over power=" .. tostring(cb.level > strip.level))
        castState("cast idle")
        local function cast(e, id)
            for _, f in ipairs(events[e] or {}) do f.scripts.OnEvent(f, e, "player", id) end
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
            if ns.actionBar and b.parent == ns.actionBar then
                n = n + 1
                if i == 1 or i == 12 then
                    screen(b.name, b, "level=" .. b.level .. " scale=" .. b:GetScale()
                        .. " styled=" .. tostring(b.medaluinIcon ~= nil))
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
        if f.shown and f.scripts.OnUpdate and f ~= ns.barFade then
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
    for mode = 1, 4 do
        S.visibility:Set(mode)
        local line = {}
        mouseOver, cursor = false, nil
        table.insert(line, "idle=" .. settle())
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
    return
end

if stripsPass then
    -- the screen in console units: the console's top-left is (612, 916)
    UIParent.rect = { -612, -916, 1308, 164 }
    local function screen(tag, f, extra)
        local r = resolve(f)
        print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1] + 612, r[2] + 916, r[3] + 612,
            r[4] + 916, extra or ""))
    end
    screen("stripLeft", ns.strips[-1])
    screen("stripRight", ns.strips[1])
    if modern then
        -- Blizzard's own passes, after login: they must not undo the strips
        BagsBar:Layout()
        for _, b in ipairs({ MainMenuBarBackpackButton, CharacterReagentBag0Slot, CharacterBag0Slot }) do
            b:UpdateTextures()
            b:SetBarExpanded(false)
        end
        for _, f in ipairs(all) do
            if f.layoutIndex then f:SetHighlightAtlas("UI-HUD-MicroMenu-Down"); f:SetPushedAtlas("x") end
        end
    end
    local micro = {}
    for _, f in ipairs(all) do
        if type(f.name) == "string" and f.name:match("MicroButton$") and _G[f.name] == f then table.insert(micro, f) end
    end
    table.sort(micro, function(a, b) return (resolve(a)[1] or 1e9) < (resolve(b)[1] or 1e9) end)
    for _, f in ipairs(micro) do
        if f.shown and resolve(f)[1] then
            local m, hl = f.medaluin, f:GetHighlightTexture()
            screen(f.name, f, string.format("parent=%s glyph=%s hl.alpha=%s", tostring(f.parent.name),
                m and m.tex.texture and m.tex.texture:match("[^\\]+$") or "-",
                hl and hl.vertex and tostring(hl.vertex[4]) or "-"))
        else
            print(f.name, "hidden")
        end
    end
    local blizzPortrait = MicroButtonPortrait or CharacterMicroButton.Portrait
    screen("portrait", CharacterMicroButton, "blizzard=" .. tostring(blizzPortrait.alpha))
    screen("backpack", MainMenuBarBackpackButton)
    for i = 3, 0, -1 do
        local b = _G["CharacterBag" .. i .. "Slot"]
        local pushed = b:GetPushedTexture()
        screen("bag" .. i, b, string.format("shown=%s pushed=%s", tostring(b.shown),
            pushed and (pushed.atlas or (pushed.color and "ours")) or "-"))
    end
    if CharacterReagentBag0Slot then screen("reagent", CharacterReagentBag0Slot) end
    screen("drawer", ns.bagDrawer, "shown=" .. tostring(ns.bagDrawer.shown))
    for _, f in ipairs(all) do
        if f.kind == "FontString" and f.parent and f.parent.parent == ns.strips[1] and f.text then
            screen("stat", f.parent, string.format("%q", f.text))
        end
    end
    do return end
end

for unit, b in pairs(ns.units) do
    if UnitExists(unit) then
        out(unit .. ".health", b.health, string.format("fill=%s rev=%s text=%s", tostring(b.health.value),
            tostring(b.health.reverse), tostring(b.value and b.value.text)))
        out(unit .. ".power", b.power, string.format("fill=%s shown=%s", tostring(b.power.value),
            tostring(b.power.shown)))
        print(string.format("%s.name\t%s", unit, tostring(b.name.text)))
    end
end
out("minimap", Minimap)
print("secrets handed to widgets", secretsUsed)
