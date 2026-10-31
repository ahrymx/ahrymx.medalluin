-- The addon's settings: saved per account in MedaluinDB, shown as a page in
-- the game's Options > AddOns, opened by /medaluin.
--
-- Two kinds of option. The Action bar and Rows options move Blizzard's
-- secure buttons, which cannot be handed back mid-session, so they are read
-- once at login and a change waits for a reload, as does Bare icons. The rest
-- are drawing only (art colour, visibility) and apply at once: modules hear
-- about a change through ns.OnSetting.
local addonName, ns = ...

local DEFAULTS = {
    actionBar = true,       -- the bar on the console, holding action bar 1
    rows = 1,               -- 2 and 3 stack action bars 2 and 3 above it
    bareIcons = false,      -- WeakAuras-style icons instead of Blizzard's button art
    artColor = "ffffffff",  -- AARRGGBB, as the colour swatch stores it; white leaves the art as drawn
    visibility = 1,         -- see VISIBILITY
}
ns.VISIBILITY = { ALWAYS = 1, COMBAT = 2, MOUSEOVER = 3, COMBAT_OR_MOUSEOVER = 4 }

-- Filled in from the saved table at ADDON_LOADED; defaults until then.
ns.db = {}
for k, v in pairs(DEFAULTS) do ns.db[k] = v end

-- ns.OnSetting(key, fn): fn(value) whenever the player changes that option.
local watchers = {}
function ns.OnSetting(key, fn)
    watchers[key] = watchers[key] or {}
    table.insert(watchers[key], fn)
end
local function Changed(key, value)
    for _, fn in ipairs(watchers[key] or {}) do fn(value) end
end

-- "ffRRGGBB" -> r, g, b in 0..1, white for anything unreadable.
function ns.HexColor(hex)
    local r, g, b = tostring(hex):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local RELOAD = " Takes effect after a reload."

local function Page()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local category = Settings.RegisterVerticalLayoutCategory("Medaluin")
    local function Setting(key, kind, name)
        local s = Settings.RegisterAddOnSetting(category, "Medaluin_" .. key, key, MedaluinDB, kind, name,
            DEFAULTS[key])
        s:SetValueChangedCallback(function(_, value) Changed(key, value) end)
        return s
    end
    local function Choices(list)
        return function()
            local c = Settings.CreateControlTextContainer()
            for _, choice in ipairs(list) do c:Add(choice[1], choice[2], choice[3]) end
            return c:GetData()
        end
    end
    local V, B, N, S = ns.VISIBILITY, Settings.VarType.Boolean, Settings.VarType.Number, Settings.VarType.String

    local bar = Settings.CreateCheckbox(category, Setting("actionBar", B, "Action bar"),
        "Medaluin's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's bars or "
        .. "use another action-bar addon." .. RELOAD)
    local function BarOn() return MedaluinDB.actionBar end
    local children = {
        Settings.CreateDropdown(category, Setting("rows", N, "Rows"), Choices({
            { 1, "1 row", "Action bar 1." },
            { 2, "2 rows", "Action bar 2 stacked above action bar 1." },
            { 3, "3 rows", "Action bars 2 and 3 stacked above action bar 1." },
        }), "Stack Blizzard's bottom bars (action bars 2 and 3) above Medaluin's bar frame instead of "
            .. "leaving them where Edit Mode puts them." .. RELOAD),
        Settings.CreateCheckbox(category, Setting("bareIcons", B, "Bare icons"),
            "Square icons with a thin black edge, the cooldown time on the icon and range as a red tint, "
            .. "instead of Blizzard's button art." .. RELOAD),
        Settings.CreateColorSwatch(category, Setting("artColor", S, "Art colour"),
            "Tints the bar's stone frame. White leaves it as drawn."),
        Settings.CreateDropdown(category, Setting("visibility", N, "Show the bar"), Choices({
            { V.ALWAYS, "Always" },
            { V.COMBAT, "In combat", "Faded out of combat; it comes back while you drag a spell onto it." },
            { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over it, or a spell is being dragged." },
            { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
        }), "A faded bar still works: its buttons and key bindings stay live."),
    }
    for _, child in ipairs(children) do child:SetParentInitializer(bar, BarOn) end

    if CreateSettingsButtonInitializer then
        local layout = SettingsPanel:GetLayout(category)
        layout:AddInitializer(CreateSettingsButtonInitializer("", "Reload UI", ReloadUI,
            "Reload the interface so a changed option takes effect.", true))
    end
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    MedaluinDB = MedaluinDB or {}
    for k, v in pairs(DEFAULTS) do
        if MedaluinDB[k] == nil then MedaluinDB[k] = v end
    end
    ns.db = MedaluinDB
    Page()
end)

SLASH_MEDALUIN1 = "/medaluin"
SlashCmdList.MEDALUIN = function()
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end
