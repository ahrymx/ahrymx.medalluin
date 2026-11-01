-- The addon's settings: saved per account in MedaluinDB, shown as a page in
-- the game's Options > AddOns, opened by /medaluin.
--
-- Two kinds of option. The Action bar and Rows options move Blizzard's
-- secure buttons, which cannot be handed back mid-session, so they are read
-- once at login and a change waits for a reload, as do Bare icons and the
-- Chat panel. The rest are drawing only (art colour, visibility, drawer,
-- the beam's cast bars) and apply at once: modules hear about a change through ns.OnSetting.
local addonName, ns = ...

local DEFAULTS = {
    actionBar = true,       -- the bar on the console, holding action bar 1
    rows = 1,               -- 2 and 3 stack action bars 2 and 3 above it
    bareIcons = false,      -- WeakAuras-style icons instead of Blizzard's button art
    artColor = "ffffffff",  -- AARRGGBB, as the colour swatch stores it; white leaves the art as drawn
    visibility = 1,         -- see VISIBILITY
    drawer = 1,             -- which way the minimap button drawer opens: see DRAWER
    chat = true,            -- the chat in a panel on the left strip
    xpCast = false,         -- the player's casts over the experience bar
    repCast = false,        -- the target's casts over the reputation bar
    simParty = false,       -- simulate party frames and show the group art layer
    auraGlow = true,        -- border glow for dispellable debuffs
    auraCC = true,          -- large center icon for crowd control
    auraBuffs = true,       -- row of player-cast buffs on outer health corner
    auraBoss = true,        -- boss debuffs on inner health corner
}
ns.VISIBILITY = { ALWAYS = 1, COMBAT = 2, MOUSEOVER = 3, COMBAT_OR_MOUSEOVER = 4 }
ns.DRAWER = { LEFT = 1, UP = 2 }

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
    ns.db[key] = value
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

    local function Subcategory(parent, name)
        if Settings.RegisterVerticalLayoutSubcategory then
            local sub = Settings.RegisterVerticalLayoutSubcategory(parent, name)
            Settings.RegisterAddOnCategory(sub)
            return sub
        end
        return parent
    end

    local subBar = Subcategory(category, "Action Bar")
    local subUnit = Subcategory(category, "Unit Frames")
    local subCast = Subcategory(category, "Cast Bars")
    local subChat = Subcategory(category, "Chat")

    local function Setting(cat, key, kind, name)
        local s = Settings.RegisterAddOnSetting(cat, "Medaluin_" .. key, key, MedaluinDB, kind, name,
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

    -- Action Bar subcategory
    local bar = Settings.CreateCheckbox(subBar, Setting(subBar, "actionBar", B, "Action bar"),
        "Medaluin's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's bars or "
        .. "use another action-bar addon." .. RELOAD)
    local function BarOn() return MedaluinDB.actionBar end
    local children = {
        Settings.CreateDropdown(subBar, Setting(subBar, "rows", N, "Rows"), Choices({
            { 1, "1 row", "Action bar 1." },
            { 2, "2 rows", "Action bar 2 stacked above action bar 1." },
            { 3, "3 rows", "Action bars 2 and 3 stacked above action bar 1." },
        }), "Stack Blizzard's bottom bars (action bars 2 and 3) above Medaluin's bar frame instead of "
            .. "leaving them where Edit Mode puts them." .. RELOAD),
        Settings.CreateCheckbox(subBar, Setting(subBar, "bareIcons", B, "Bare icons"),
            "Square icons with a thin black edge, the cooldown time on the icon and range as a red tint, "
            .. "instead of Blizzard's button art." .. RELOAD),
        Settings.CreateColorSwatch(subBar, Setting(subBar, "artColor", S, "Art colour"),
            "Tints the bar's stone frame. White leaves it as drawn."),
        Settings.CreateDropdown(subBar, Setting(subBar, "visibility", N, "Show the bar"), Choices({
            { V.ALWAYS, "Always" },
            { V.COMBAT, "In combat", "Faded out of combat; it comes back while you drag a spell onto it." },
            { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over it, or a spell is being dragged." },
            { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
        }), "A faded bar still works: its buttons and key bindings stay live."),
        Settings.CreateDropdown(subBar, Setting(subBar, "drawer", N, "Minimap buttons"), Choices({
            { ns.DRAWER.LEFT, "Open left", "One row, out to the left of the bar." },
            { ns.DRAWER.UP, "Open up", "One column, up from the bar's left end." },
        }), "The addons' minimap buttons gather in a drawer behind the box on the bar's left end. "
            .. "This is the way it opens."),
    }
    for _, child in ipairs(children) do child:SetParentInitializer(bar, BarOn) end

    -- Unit Frames subcategory
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "simParty", B, "Simulate party frames"),
        "Show the console's party frame layer and simulated party members to preview party frames while solo.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraGlow", B, "Dispel glow on frame borders"),
        "Glow the frame's stone border in the debuff's color (purple for Curse, green for Poison, etc.) "
        .. "when an ally has a debuff you can dispel.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraCC", B, "Crowd control center icon"),
        "Display a large icon in the middle of the frame with a radial timer sweep when a unit is affected by CC.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraBuffs", B, "Player buffs on health"),
        "Show a compact row of your own buffs and HoTs on the outer corner of the health bar.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraBoss", B, "Boss debuffs"),
        "Show critical boss debuffs on the inner corner of the health bar, away from the power bar.")

    -- Cast Bars subcategory
    Settings.CreateCheckbox(subCast, Setting(subCast, "xpCast", B, "Player casts on the experience bar"),
        "The experience bar under your portrait becomes your cast bar while you cast, and goes back to "
        .. "experience when you stop.")
    Settings.CreateCheckbox(subCast, Setting(subCast, "repCast", B, "Target casts on the reputation bar"),
        "The reputation bar under your target becomes its cast bar while it casts, and goes back to "
        .. "reputation when it stops or you change target.")

    -- Chat subcategory
    Settings.CreateCheckbox(subChat, Setting(subChat, "chat", B, "Chat panel"),
        "Blizzard's chat in a panel on top of the micro menu, with the chat buttons in a column at its "
        .. "left. Untick it to keep the chat where Edit Mode puts it, or to use a chat addon." .. RELOAD)

    local function AddReload(cat)
        if CreateSettingsButtonInitializer and SettingsPanel and SettingsPanel.GetLayout then
            local layout = SettingsPanel:GetLayout(cat)
            if layout and layout.AddInitializer then
                layout:AddInitializer(CreateSettingsButtonInitializer("", "Reload UI", ReloadUI,
                    "Reload the interface so a changed option takes effect.", true))
            end
        end
    end

    AddReload(category)
    if subBar ~= category then
        if CreateSettingsButtonInitializer and SettingsPanel and SettingsPanel.GetLayout then
            local layout = SettingsPanel:GetLayout(category)
            if layout and layout.AddInitializer then
                layout:AddInitializer(CreateSettingsButtonInitializer("", "Action Bar", function()
                    Settings.OpenToCategory(subBar:GetID())
                end, "Open Action Bar settings.", true))
                layout:AddInitializer(CreateSettingsButtonInitializer("", "Unit Frames", function()
                    Settings.OpenToCategory(subUnit:GetID())
                end, "Open Unit Frames settings.", true))
                layout:AddInitializer(CreateSettingsButtonInitializer("", "Cast Bars", function()
                    Settings.OpenToCategory(subCast:GetID())
                end, "Open Cast Bars settings.", true))
                layout:AddInitializer(CreateSettingsButtonInitializer("", "Chat", function()
                    Settings.OpenToCategory(subChat:GetID())
                end, "Open Chat settings.", true))
            end
        end
        AddReload(subBar)
        AddReload(subChat)
    end

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    ns.settingsSubcategories = { bar = subBar, unit = subUnit, cast = subCast, chat = subChat }
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
SLASH_MEDALUIN2 = "/mdlui"
SLASH_MDLUI1 = "/mdlui"

local function OpenSettings(arg)
    if not ns.settingsCategory then return end
    arg = tostring(arg or ""):lower():match("^%s*(%S+)")
    local target = ns.settingsCategory
    if arg == "bar" or arg == "actionbar" or arg == "bars" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.bar or target
    elseif arg == "unit" or arg == "units" or arg == "unitframe" or arg == "unitframes"
        or arg == "uf" or arg == "party" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.unit or target
    elseif arg == "cast" or arg == "castbars" or arg == "casting" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.cast or target
    elseif arg == "chat" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.chat or target
    end
    Settings.OpenToCategory(target:GetID())
end

SlashCmdList.MEDALUIN = OpenSettings
SlashCmdList.MDLUI = OpenSettings
