-- Load Medaluin outside the game against a stubbed WoW API and print every
-- named region's resolved rectangle, in art pixels from the console's
-- top-left. tools/preview.py draws them over the art.
--
--   lua5.1 tools/harness.lua [solo|group]
local ADDON = "WoW/Interface/AddOns/Medaluin/"
local grouped = arg[1] == "group"

-- ------------------------------------------------------------ regions
local Region = {}
Region.__index = function(self, k)
    local m = rawget(Region, k)
    if m then return m end
    -- unstubbed methods (Capitalised) are no-ops; fields stay nil as in WoW
    if type(k) == "string" and k:match("^%u") then return function() end end
end
local all = {}
local function new(kind, parent, name)
    local r = setmetatable({ kind = kind, parent = parent, points = {}, w = 0, h = 0,
        shown = true, scripts = {}, attrs = {}, name = name, level = 0 }, Region)
    if parent then r.level = parent.level + 1 end
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
function Region:SetColorTexture(r, g, b) self.color = { r, g, b } end
function Region:SetText(t) self.text = t end
function Region:SetFormattedText(f, ...) self.text = string.format(f, ...) end
function Region:SetReverseFill(v) self.reverse = v end
function Region:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Region:SetValue(v) self.value = v end
function Region:GetZoom() return 0 end
function Region:GetZoomLevels() return 5 end
function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:RegisterUnitEvent(e)
    if e == "UNIT_HEALTH_FREQUENT" then error("unknown event " .. e) end
end

-- Resolve a region to { left, top, right, bottom } in the console's units,
-- y growing downward. Points are relative to the console unless anchored on
-- UIParent; that is enough for this addon.
local function anchor(r, p)
    local x = p:find("LEFT") and r[1] or p:find("RIGHT") and r[3] or (r[1] + r[3]) / 2
    local y = p:find("TOP") and r[2] or p:find("BOTTOM") and r[4] or (r[2] + r[4]) / 2
    return x, y
end
local resolve
resolve = function(f)
    if f.rect then return f.rect end
    if f.isScreen then return { 0, 0, 1e6, 1e6 } end
    if f.all then f.rect = resolve(f.all); return f.rect end
    local L, T, R, B
    for p, a in pairs(f.points) do
        local ax, ay = anchor(resolve(a[1]), a[2])
        ax, ay = ax + a[3], ay - a[4]
        if p:find("LEFT") then L = ax elseif p:find("RIGHT") then R = ax end
        if p:find("TOP") then T = ay elseif p:find("BOTTOM") then B = ay end
        if not p:find("LEFT") and not p:find("RIGHT") then f.cx = ax end
        if not p:find("TOP") and not p:find("BOTTOM") then f.cy = ay end
    end
    L = L or (R and R - f.w) or (f.cx and f.cx - f.w / 2)
    R = R or (L and L + f.w)
    T = T or (B and B - f.h) or (f.cy and f.cy - f.h / 2)
    B = B or (T and T + f.h)
    f.rect = { L, T, R, B }
    return f.rect
end
function Region:GetHeight() return self.h end

-- ------------------------------------------------------------ the API
UIParent = new("Frame", nil, "UIParent")
UIParent.isScreen = true
function UIParent:GetHeight() return 768 end
Minimap = new("Frame", UIParent, "Minimap")
MinimapCluster = new("Frame", UIParent, "MinimapCluster")
GameTooltip = new("Frame", UIParent, "GameTooltip")
PlayerFrame, TargetFrame = new("Frame", UIParent), new("Frame", UIParent)

local events = {}
function CreateFrame(kind, name, parent)
    local f = new(kind, parent, name)
    function f:RegisterEvent(e) events[e] = events[e] or {}; table.insert(events[e], self) end
    return f
end
function InCombatLockdown() return false end
function RegisterUnitWatch(f) f.watched = true end
function IsInGroup() return grouped end
function UnitExists(u) return u == "player" or u == "target" or (grouped and u:match("^party[12]$")) end
function UnitName(u) return ({ player = "Ahrymx", target = "Defias Pillager", party1 = "Thalric",
    party2 = "Okun" })[u] end
function UnitClass() return "Paladin", "PALADIN" end
function UnitIsPlayer(u) return u ~= "target" end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function UnitReaction() return 2 end
function UnitHealth() return 82 end
function UnitHealthMax() return 100 end
function UnitPower() return 60 end
function UnitPowerMax() return 100 end
function UnitPowerType() return 0 end
function UnitLevel() return 30 end
function UnitXP() return 650 end
function UnitXPMax() return 1000 end
function GetXPExhaustion() return 200 end
function GetMaxPlayerLevel() return 60 end
function GetWatchedFactionInfo() return "Stormwind", 5, 0, 6000, 2200 end
function BreakUpLargeNumbers(n) return tostring(n) end
RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
FACTION_BAR_COLORS = setmetatable({}, { __index = function() return { r = 0.8, g = 0.3, b = 0.22 } end })
PowerBarColor = setmetatable({}, { __index = function() return { r = 0, g = 0, b = 1 } end })
wipe = function(t) for k in pairs(t) do t[k] = nil end end
format, unpack = string.format, unpack

-- ------------------------------------------------------------ load + fire
local ns = {}
for line in io.lines(ADDON .. "Medaluin.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(ADDON .. line:gsub("\\", "/")))
        chunk("Medaluin", ns)
    end
end
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
c.rect = { 0, 0, ns.art.width, ns.art.height }
local function out(tag, f, extra)
    local r = resolve(f)
    print(string.format("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%s", tag, r[1], r[2], r[3], r[4], extra or ""))
end
for unit, b in pairs(ns.units) do
    if UnitExists(unit) then
        out(unit .. ".health", b.health, string.format("fill=%s rev=%s", b.health.value, tostring(b.health.reverse)))
        out(unit .. ".power", b.power, string.format("fill=%s", b.power.value))
        print(string.format("%s.name\t%s", unit, b.name.text))
    end
end
out("minimap", Minimap)
