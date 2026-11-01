-- The addon's settings: saved per account in MedaluinDB, shown as a page in
-- the game's Options > AddOns, opened by /medaluin. Every option starts from
-- the chosen console profile, and only the player's own choices are saved,
-- on top of it: the console's per profile, the rest shared (see PROFILES below).
--
-- Two kinds of option. The Action bar and Rows options move Blizzard's
-- secure buttons, which cannot be handed back mid-session, so they are read
-- once at login and a change waits for a reload, as do Bare icons and the
-- Chat and Side panels. The rest are drawing only (art colour, visibility, drawer,
-- the beam's cast bars) and apply at once: modules hear about a change through ns.OnSetting.
local addonName, ns = ...

local DEFAULTS = {
    actionBar = true,       -- the bar on the console, holding action bar 1
    rows = 1,               -- 2 and 3 stack action bars 2 and 3 above it
    bareIcons = false,      -- WeakAuras-style icons instead of Blizzard's button art
    artColor = "ffffffff",  -- AARRGGBB, as the colour swatch stores it; white leaves the art as drawn
    visibility = 1,         -- Bar 1 visibility: see VISIBILITY
    extraVisibility = 1,    -- Extra bar(s) visibility (action bars 2 and 3): see VISIBILITY
    drawer = 1,             -- which way the minimap button drawer opens: see DRAWER
    chat = true,            -- the chat in a panel on the left strip
    side = true,            -- the chat panel's mirror on the right strip: the meter, the loot, the auras
    sideAuras = true,       -- its Auras tab
    sideMeter = true,       -- its Meter tab
    sideLoot = true,        -- its Loot tab
    sideTab = "meter",      -- the tab last shown (not on the page: the tabs set it)
    meterColumns = 1,       -- 2 shows a second list beside the first
    meterLeft = "damage",   -- what the first list shows: see METER_METRICS
    meterRight = "healing", -- what the second list shows
    meterSession = 1,       -- see METER_SESSION
    meterRate = true,       -- damage and healing per second instead of totals
    lootWho = 1,            -- see LOOT_WHO
    lootQuality = 2,        -- the least item quality shown (2 = uncommon)
    lootMoney = true,       -- money and currencies in the loot log
    aurasColumns = 2,       -- 2: buffs and debuffs side by side; 1: one list of both
    aurasTimeless = false,  -- list the auras that never run out too (they are over the portrait already)
    bags = true,            -- Medaluin's bags window instead of Blizzard's bags
    bagsView = "grid",      -- "grid": every slot, bag by bag; "groups": the items in fixed groups
    bagsColumns = 10,       -- slots across the window (not on the page: the window's corner sets it, 8 to 24)
    bagsItemLevel = true,   -- item levels on weapons and armour
    bagsPoint = false,      -- where the window was dragged to: { point, relativePoint, x, y } (not on the page)
    xpCast = false,         -- the player's casts over the experience bar
    repCast = false,        -- the target's casts over the reputation bar
    simParty = false,       -- simulate party frames and show the group art layer
    partyPets = true,       -- show pet frames directly below party members with pets
    partyRange = 40,        -- distance in yards to fade out-of-range party frames (0 = off)
    overhead = true,        -- top-of-screen cascading trapezoid structure
    topBoss = true,         -- boss frames on the top tier
    topPet = true,          -- player pet unit frame on the middle tier
    topFocus = true,        -- focus unit frame on the middle tier
    topToT = true,          -- target of target frame on the middle tier
    topPetBar = true,       -- pet action bar on the bottom tier
    topStances = true,      -- stance bar on the bottom tier
    auraGlow = true,        -- border glow for dispellable debuffs
    auraCC = true,          -- large center icon for crowd control
    auraBuffs = true,       -- row of player-cast buffs on outer health corner
    auraBoss = true,        -- boss debuffs on inner health corner
    consoleProfile = "default", -- "default": medallion console; "light": central console with square minimap & bar 7
    bar7State = "[bonusbar:1] 8; [form:1] 8; [form:2] 9; [form:3] 9; [stealth] 10; 7", -- state macro for bar 7 (8-10)
}
ns.VISIBILITY = { ALWAYS = 1, COMBAT = 2, MOUSEOVER = 3, COMBAT_OR_MOUSEOVER = 4 }
ns.DRAWER = { LEFT = 1, UP = 2 }
ns.METER_SESSION = { OVERALL = 0, CURRENT = 1 }     -- Enum.DamageMeterSessionType's values
ns.LOOT_WHO = { GROUP = 1, MINE = 2 }
-- What a meter list can show: the key saved, the name on the page. The
-- client's types for each are in meter.lua.
ns.METER_METRICS = {
    { "damage", "Damage" },
    { "healing", "Healing" },
    { "absorbs", "Absorbs" },
    { "interrupts", "Interrupts" },
    { "dispels", "Dispels" },
    { "taken", "Damage taken" },
    { "avoidable", "Avoidable damage taken" },
}
-- Item qualities, as the loot log's least-quality option offers them.
ns.LOOT_QUALITIES = { { 0, "Poor" }, { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" } }

-- The built-in profiles. Each is a look the console starts from: what it
-- changes from DEFAULTS. The art the light profile draws is
-- console/light_profile.lua; this is only what it means for the options.
local PROFILES = {
    default = {},
    light = { rows = 3 },
}
ns.PROFILE_NAMES = {
    { "default", "Medallion (default)", "The classic round medallion console with integrated party wings." },
    { "light", "Central Console (light)", "Flush-top player/target wings, dynamic square minimap / 2x5 Bar 7 bay, "
        .. "split Action Bars 2 & 3, and detached vertical party frames." },
}

-- The options are layered: DEFAULTS, then the chosen profile, then the
-- player's own choices on top. Only a choice that differs from the profile
-- is saved.
--
-- What shapes the console (the Action Bar, Unit Frames, Overhead and Cast
-- Bars pages, and Bar 7's state macro) is remembered per profile, in
-- MedaluinDB.profiles[name]: each profile keeps its own choices, so a switch
-- brings back the ones made on the profile switched to. Everything else (the
-- chat, the side panel, the bags, where windows were left, the party preview)
-- has nothing to do with the console and is one set, MedaluinDB.global.
-- Reset profile clears the current profile's choices and nothing else.
local PER_PROFILE = {}
for _, key in ipairs({
    "actionBar", "rows", "bareIcons", "artColor", "visibility", "extraVisibility", "drawer", "bar7State",
    "partyPets", "partyRange", "auraGlow", "auraCC", "auraBuffs", "auraBoss",
    "overhead", "topBoss", "topPet", "topFocus", "topToT", "topPetBar", "topStances",
    "xpCast", "repCast",
}) do PER_PROFILE[key] = true end
ns.PER_PROFILE = PER_PROFILE

local function Profile()
    return MedaluinDB and PROFILES[MedaluinDB.consoleProfile] and MedaluinDB.consoleProfile or "default"
end

-- What an option is when the player has not chosen: the profile's, else DEFAULTS.
local function Base(key)
    local v = PROFILES[Profile()][key]
    if v == nil then v = DEFAULTS[key] end
    return v
end

-- Where the player's choice for an option is kept.
local function Store(key)
    if PER_PROFILE[key] then return MedaluinDB.profiles[Profile()] end
    return MedaluinDB.global
end

-- ns.db reads through the layers and writes the player's choices; it holds
-- nothing itself. Defaults only until ADDON_LOADED, before the saved table.
ns.db = {}
for k, v in pairs(DEFAULTS) do ns.db[k] = v end
local layered = setmetatable({}, {
    __index = function(_, key)
        if key == "consoleProfile" then return Profile() end
        local v = Store(key)[key]
        if v == nil then v = Base(key) end
        return v
    end,
    __newindex = function(_, key, value)
        if key == "consoleProfile" then
            MedaluinDB.consoleProfile = value
        elseif value == Base(key) then
            Store(key)[key] = nil
        else
            Store(key)[key] = value
        end
    end,
})

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

-- ns.SetOption(key, value): an option changed from Medaluin's own controls
-- (the side panel's column buttons), through the page's setting when there
-- is one, so the page shows the new value.
local registered = {}
function ns.SetOption(key, value)
    local s = registered[key]
    if s then
        s:SetValue(value)
    else
        Changed(key, value)
    end
end

-- Run change(), which moves layers under the options, then tell the page and
-- the modules about every option whose value it moved. A page setting is told
-- through NotifyUpdate, which redraws its control and calls back into Changed.
local function Relayer(change)
    local before = {}
    for key in pairs(DEFAULTS) do before[key] = ns.db[key] end
    change()
    for key in pairs(DEFAULTS) do
        local now = ns.db[key]
        -- the profile's own setting reports itself, as any setting does
        if now ~= before[key] and key ~= "consoleProfile" then
            if registered[key] then registered[key]:NotifyUpdate() else Changed(key, now) end
        end
    end
end

-- Switching profile brings back that profile's own choices; the global
-- options stay as they are.
local function SwitchProfile(profile)
    if not PROFILES[profile] or profile == Profile() then return end
    Relayer(function() MedaluinDB.consoleProfile = profile end)
end

-- Reset profile: the current profile's options back to its own.
function ns.ResetProfile()
    Relayer(function() wipe(MedaluinDB.profiles[Profile()]) end)
end

-- A saved table from before profiles is flat, every option at the top with
-- the defaults filled in. Its console options become the choices of the
-- profile it was on (the other profile starts as it is drawn), the rest the
-- global ones; only what differs from the profile is kept, and anything
-- unknown is left where it is.
local function Migrate()
    local db = MedaluinDB
    db.global = db.global or {}
    db.profiles = db.profiles or {}
    for name in pairs(PROFILES) do db.profiles[name] = db.profiles[name] or {} end
    for key in pairs(DEFAULTS) do
        local v = db[key]
        if key ~= "consoleProfile" and v ~= nil then
            if v ~= Base(key) then Store(key)[key] = v end
            db[key] = nil
        end
    end
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

    -- The tree on the left is the way round: the console's pages sit under
    -- Console, which holds the profile they are remembered by; the pages
    -- every profile shares sit beside it.
    local subConsole = Subcategory(category, "Console")
    local subBar = Subcategory(subConsole, "Action Bar")
    local subUnit = Subcategory(subConsole, "Unit Frames")
    local subOverhead = Subcategory(subConsole, "Overhead")
    local subCast = Subcategory(subConsole, "Cast Bars")
    local subChat = Subcategory(category, "Chat")
    local subSide = Subcategory(category, "Side panel")
    local subBags = Subcategory(category, "Bags")

    -- A proxy, not an add-on setting: an add-on setting reads and writes one
    -- flat table and fills it with its default, which would make every option
    -- a choice. The default is the profile's, asked for each time, so the
    -- page's Defaults button means the profile too.
    local function Setting(cat, key, kind, name)
        local get, set = function() return ns.db[key] end, function(value) ns.db[key] = value end
        if key == "consoleProfile" then set = SwitchProfile end
        local s = Settings.RegisterProxySetting(cat, "Medaluin_" .. key, kind, name,
            function() return Base(key) end, get, set)
        s:SetValueChangedCallback(function(_, value) Changed(key, value) end)
        registered[key] = s
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

    -- Rows that are not settings (headings, buttons) go straight into a
    -- page's layout, in order with the settings around them.
    local function Add(cat, initializer)
        local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(cat)
        if layout and layout.AddInitializer then layout:AddInitializer(initializer) end
    end
    local function Header(cat, name, tooltip)
        if CreateSettingsListSectionHeaderInitializer then
            Add(cat, CreateSettingsListSectionHeaderInitializer(name, tooltip))
        end
    end
    local function Button(cat, text, click, tooltip)
        if CreateSettingsButtonInitializer then
            Add(cat, CreateSettingsButtonInitializer("", text, click, tooltip, true))
        end
    end
    local function Reload(cat)
        Button(cat, "Reload UI", ReloadUI, "Reload the interface so a changed option takes effect.")
    end
    -- Each list's controls hang off a page's master checkbox. A heading is
    -- not one of them: it would be indented like a setting.
    local function Under(parent, predicate, ...)
        for _, list in ipairs({ ... }) do
            for _, child in ipairs(list) do child:SetParentInitializer(parent, predicate) end
        end
    end

    -- Root page: what belongs to no console.
    Header(category, "Preview", "Tools for seeing Medaluin's frames without a group. Shared by every profile.")
    Settings.CreateCheckbox(category, Setting(category, "simParty", B, "Simulate party frames"),
        "Show the console's party frame layer and simulated party members to preview party frames while solo. "
            .. "A small panel on the left changes the situation: bosses, deaths, range, ready and role checks.")
    Header(category, "Key bindings", "Shared by every profile: they are the game's own bindings.")
    Button(category, "Bind keys", function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        ns.KeybindMode(true)
    end, "Closes this window. Point at an action button and press a key to bind it; Esc over a button "
        .. "removes its keys. Also /mdlui kb.")
    Reload(category)

    -- Console page: the profile the pages under it are remembered by.
    Header(subConsole, "Profile", "Each profile remembers its own Action Bar, Unit Frames, Overhead and Cast Bars "
        .. "options. Chat, Side panel and Bags are shared by every profile.")
    Settings.CreateDropdown(subConsole, Setting(subConsole, "consoleProfile", S, "Console profile"),
        Choices(ns.PROFILE_NAMES), "The console the pages under Console start from. Switching brings back "
        .. "the options you chose on that profile." .. RELOAD)
    Button(subConsole, "Reset profile", function() StaticPopup_Show("MEDALUIN_RESET_PROFILE") end,
        "This profile's Action Bar, Unit Frames, Overhead and Cast Bars options back to its own. "
        .. "Chat, Side panel and Bags are left as they are.")
    Reload(subConsole)

    -- Action Bar subcategory
    local bar = Settings.CreateCheckbox(subBar, Setting(subBar, "actionBar", B, "Action bar"),
        "Medaluin's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's bars or "
        .. "use another action-bar addon." .. RELOAD)
    local function BarOn() return ns.db.actionBar end
    Header(subBar, "Look")
    local look = {
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
    }
    Header(subBar, "Fading", "A faded bar still works: its buttons and key bindings stay live.")
    local fading = {
        Settings.CreateDropdown(subBar, Setting(subBar, "visibility", N, "Bar 1 visibility"), Choices({
            { V.ALWAYS, "Always" },
            { V.COMBAT, "In combat", "Faded out of combat; it comes back while you drag a spell onto it." },
            { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over it, or a spell is being dragged." },
            { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
        }), "A faded bar still works: its buttons and key bindings stay live."),
        Settings.CreateDropdown(subBar, Setting(subBar, "extraVisibility", N, "Extra bar(s) visibility"), Choices({
            { V.ALWAYS, "Always" },
            { V.COMBAT, "In combat", "Faded out of combat; they come back while you drag a spell onto them." },
            { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over them, or a spell is being dragged." },
            { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
        }), "Manages the visibility of action bars 2 and 3. Faded bars still work: their buttons and key "
            .. "bindings stay live."),
    }
    Header(subBar, "Minimap buttons")
    local drawer = {
        Settings.CreateDropdown(subBar, Setting(subBar, "drawer", N, "Drawer opens"), Choices({
            { ns.DRAWER.LEFT, "Open left", "One row, out to the left of the bar." },
            { ns.DRAWER.UP, "Open up", "One column, up from the bar's left end." },
        }), "The addons' minimap buttons gather in a drawer behind the box on the bar's left end. "
            .. "This is the way it opens."),
    }
    Under(bar, BarOn, look, fading, drawer)

    -- Unit Frames subcategory
    Header(subUnit, "Party")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "partyPets", B, "Show party pets"),
        "Show pet unit frames directly below party members who have active pets.")
    Settings.CreateDropdown(subUnit, Setting(subUnit, "partyRange", N, "Fade out of range"), Choices({
        { 40, "40 yards", "Standard spell and healing range." },
        { 30, "30 yards", "Mid-range distance." },
        { 20, "20 yards", "Short distance." },
        { 10, "10 yards", "Melee and interaction distance." },
        { 0, "Disabled", "Never fade party frames based on distance." },
    }), "Fade party unit frames when members move beyond the chosen distance.")
    Header(subUnit, "Auras")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraGlow", B, "Dispel glow on frame borders"),
        "Glow the frame's stone border in the debuff's color (purple for Curse, green for Poison, etc.) "
        .. "when an ally has a debuff you can dispel.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraCC", B, "Crowd control center icon"),
        "Display a large icon in the middle of the frame with a radial timer sweep when a unit is affected by CC.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraBuffs", B, "Player buffs on health"),
        "Show a compact row of your own buffs and HoTs on the outer corner of the health bar.")
    Settings.CreateCheckbox(subUnit, Setting(subUnit, "auraBoss", B, "Boss debuffs"),
        "Show critical boss debuffs on the inner corner of the health bar, away from the power bar.")

    -- Overhead subcategory
    local ovh = Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "overhead", B, "Overhead console"),
        "Top-of-screen cascading trapezoid structure for boss frames, pet, focus, target of target, and action bars."
        .. RELOAD)
    local function OverheadOn() return ns.db.overhead end
    Header(subOverhead, "Frames")
    local overheadFrames = {
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topBoss", B, "Boss frames"),
            "Encounter boss frames on the top tier, dynamically dividing into 1, 2, or 3 columns."),
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topPet", B, "Player pet frame"),
            "Player pet unit frame on the middle tier."),
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topFocus", B, "Focus frame"),
            "Focus target unit frame on the middle tier."),
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topToT", B, "Target of target frame"),
            "Target's target unit frame on the middle tier."),
    }
    Header(subOverhead, "Bars")
    local overheadBars = {
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topPetBar", B, "Pet action bar"),
            "Pet command and ability buttons on the bottom tier." .. RELOAD),
        Settings.CreateCheckbox(subOverhead, Setting(subOverhead, "topStances", B, "Stance bar"),
            "Shapeshift forms, stealth, stances, and auras on the bottom tier." .. RELOAD),
    }
    Under(ovh, OverheadOn, overheadFrames, overheadBars)

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

    -- Side panel subcategory
    local side = Settings.CreateCheckbox(subSide, Setting(subSide, "side", B, "Side panel"),
        "The chat panel's mirror on the right strip, over the stats, with an Auras tab, a Meter tab and a Loot tab. "
        .. "Untick it to keep the right corner clear, or to use a meter addon." .. RELOAD)
    local function SideOn() return ns.db.side end
    local metrics = {}
    for _, m in ipairs(ns.METER_METRICS) do table.insert(metrics, { m[1], m[2] }) end
    local qualities = {}
    for _, q in ipairs(ns.LOOT_QUALITIES) do table.insert(qualities, { q[1], q[2] }) end
    local M = ns.METER_SESSION
    Header(subSide, "Auras")
    local sideAuras = {
        Settings.CreateCheckbox(subSide, Setting(subSide, "sideAuras", B, "Auras tab"),
            "Your buffs and debuffs, each with the time it has left, the longest first."),
        Settings.CreateDropdown(subSide, Setting(subSide, "aurasColumns", N, "Aura lists"), Choices({
            { 2, "Two", "Buffs and debuffs side by side." },
            { 1, "One", "Buffs and debuffs in one list. In combat the game keeps the times to itself, so "
                .. "there the list shows the debuffs first, then the buffs." },
        }), "The column button with the bars on it switches this too."),
        Settings.CreateCheckbox(subSide, Setting(subSide, "aurasTimeless", B, "Auras that never run out"),
            "List forms, aspects, mounts and the like too, at the top. They are over the portrait already. "
            .. "The infinity button switches this too."),
    }
    Header(subSide, "Meter")
    local sideMeter = {
        Settings.CreateCheckbox(subSide, Setting(subSide, "sideMeter", B, "Meter tab"),
            "Damage, healing and more for each member of your group, from the game's own combat meter."),
        Settings.CreateDropdown(subSide, Setting(subSide, "meterColumns", N, "Meter lists"), Choices({
            { 1, "One", "One list across the panel." },
            { 2, "Two", "Two lists side by side, each showing its own thing: damage and healing, say." },
        }), "The column button with the bars on it switches this too."),
        Settings.CreateDropdown(subSide, Setting(subSide, "meterLeft", S, "First list shows"), Choices(metrics),
            "Clicking a list's heading steps through these too; a right click steps back."),
        Settings.CreateDropdown(subSide, Setting(subSide, "meterRight", S, "Second list shows"), Choices(metrics),
            "Shown when the meter has two lists."),
        Settings.CreateDropdown(subSide, Setting(subSide, "meterSession", N, "Fight"), Choices({
            { M.CURRENT, "Current", "The fight you are in, or the last one." },
            { M.OVERALL, "Overall", "Every fight since the meter was last reset." },
        }), "The clock button switches this too."),
        Settings.CreateCheckbox(subSide, Setting(subSide, "meterRate", B, "Per second"),
            "Damage and healing as amounts per second instead of totals. The /s button switches this too."),
    }
    Header(subSide, "Loot")
    local sideLoot = {
        Settings.CreateCheckbox(subSide, Setting(subSide, "sideLoot", B, "Loot tab"),
            "What your group looted, boss by boss, with who won each roll. Not the chat's loot lines: "
            .. "the chat keeps those."),
        Settings.CreateDropdown(subSide, Setting(subSide, "lootWho", N, "Whose loot"), Choices({
            { ns.LOOT_WHO.GROUP, "The group's", "Everything the group looted, yours included." },
            { ns.LOOT_WHO.MINE, "Mine", "Only what you looted or won." },
        }), "The funnel button switches this too."),
        Settings.CreateDropdown(subSide, Setting(subSide, "lootQuality", N, "Least quality"), Choices(qualities),
            "Items below this quality are left out. The diamond button steps through these too."),
        Settings.CreateCheckbox(subSide, Setting(subSide, "lootMoney", B, "Money and currencies"),
            "Your share of looted money on each heading, and the currencies you loot as lines."),
    }
    Under(side, SideOn, sideAuras, sideMeter, sideLoot)

    -- Bags subcategory
    local bags = Settings.CreateCheckbox(subBags, Setting(subBags, "bags", B, "Bags window"),
        "Your backpack, bags and reagent bag in one window, with a search, the game's sort and the items in "
        .. "groups if you like. The bank stays the game's. Untick it to keep the game's bags, or to use a "
        .. "bag addon." .. RELOAD)
    local function BagsOn() return ns.db.bags end
    local bagsChildren = {
        Settings.CreateDropdown(subBags, Setting(subBags, "bagsView", S, "Show"), Choices({
            { "grid", "Every slot", "Every slot, bag by bag, the reagent bag on rows of its own." },
            { "groups", "Groups", "The items in groups: new, equipment, consumables, quest items, trade goods, "
                .. "other and junk, with one slot for the free ones." },
        }), "The window's Groups and Grid button switches this too."),
        Settings.CreateCheckbox(subBags, Setting(subBags, "bagsItemLevel", B, "Item levels"),
            "The item level in the corner of each weapon and piece of armour, in its quality's colour."),
    }
    Under(bags, BagsOn, bagsChildren)

    Reload(subBar)
    Reload(subOverhead)
    Reload(subChat)
    Reload(subSide)
    Reload(subBags)

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    ns.settingsSubcategories = { console = subConsole, bar = subBar, unit = subUnit, overhead = subOverhead,
        cast = subCast, chat = subChat, side = subSide, bags = subBags }
end

-- Only a key is added: assigning StaticPopupDialogs itself would taint it.
StaticPopupDialogs.MEDALUIN_RESET_PROFILE = {
    text = "Put this console profile's options back to its own?\n\n"
        .. "Options that take effect after a reload need one.",
    button1 = OKAY or "Okay",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ResetProfile() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    MedaluinDB = MedaluinDB or {}
    Migrate()
    ns.db = layered
    if ns.db.consoleProfile == "light" and ns.ApplyLightProfile then
        ns.ApplyLightProfile()
    end
    Page()
end)

SLASH_MEDALUIN1 = "/medaluin"
SLASH_MEDALUIN2 = "/mdlui"
SLASH_MDLUI1 = "/mdlui"

local KEYBIND = { kb = true, keybind = true, keybinds = true, bind = true, binds = true }

local function OpenSettings(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%S+)")
    if KEYBIND[arg] then
        if ns.KeybindMode then ns.KeybindMode() end
        return
    end
    if not ns.settingsCategory then return end
    local target = ns.settingsCategory
    if arg == "console" or arg == "profile" or arg == "profiles" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.console or target
    elseif arg == "bar" or arg == "actionbar" or arg == "bars" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.bar or target
    elseif arg == "unit" or arg == "units" or arg == "unitframe" or arg == "unitframes"
        or arg == "uf" or arg == "party" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.unit or target
    elseif arg == "overhead" or arg == "top" or arg == "boss" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.overhead or target
    elseif arg == "cast" or arg == "castbars" or arg == "casting" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.cast or target
    elseif arg == "chat" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.chat or target
    elseif arg == "meter" or arg == "loot" or arg == "auras" or arg == "side" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.side or target
    elseif arg == "bags" or arg == "bag" or arg == "inventory" then
        target = ns.settingsSubcategories and ns.settingsSubcategories.bags or target
    end
    Settings.OpenToCategory(target:GetID())
end

SlashCmdList.MEDALUIN = OpenSettings
SlashCmdList.MDLUI = OpenSettings
