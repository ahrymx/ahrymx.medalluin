-- The addon's settings: saved per account in MedalluinDB, shown in
-- Medalluin's own window (options/), opened by /medalluin; the game's
-- Options > AddOns > Medalluin is a page about it with a way in. Every option starts from
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
    hideEmpty = true,       -- hide empty buttons on extra bars (action bars 2 and 3)
    -- the bar's lower row, under the cast bar (bars/lowrow.lua): "resource"
    -- (the class's), "swing" (the swing timer, Forever only) or "mana"
    barLowRow = "resource",
    -- the bar's buttons' text and cooldowns (bars/buttons.lua); a size is a
    -- scale of what the button draws on its own, so 1 leaves it as it was
    hotkeySize = 1,         -- keybind text; 0 hides it
    -- cooldown numbers: "auto" (bare icons show them, Blizzard's art asks the game), "show", "hide"
    cooldownText = "auto",
    cooldownTextSize = 1,   -- cooldown numbers
    cooldownSwipe = true,   -- the dark sweep over a cooling-down icon
    cooldownEdge = false,   -- the bright line on the sweep's edge
    cooldownBling = true,   -- the flash when a cooldown ends
    -- where each console sits and how big (movers.lua): a scale of the size it
    -- is drawn at, and an offset from where it is drawn, in the console's own
    -- units (a 1080-high screen), so a place survives a resolution change
    consoleScale = 1, consoleX = 0, consoleY = 0,
    overheadScale = 1, overheadX = 0, overheadY = 0,
    -- the light profile's minimap (console/minimap.lua): whether it moves to
    -- the screen's corner by itself, and on what; and the corner's size and
    -- place, as the consoles' are (movers.lua)
    minimapAuto = true,
    minimapAutoCombat = true, minimapAutoTarget = true, minimapAutoSkyriding = true,
    minimapScale = 1, minimapX = 0, minimapY = 0,
    -- where it is when the game loads: "auto" (rule 3 decides), "console" or
    -- "corner", held until rule 3's answer changes or the key is pressed
    minimapStart = "auto",
    -- seconds the area shows over the hovered minimap before it fades; 0
    -- keeps it until the pointer leaves (console/minimap.lua)
    minimapAreaTime = 3,
    -- fading (console/fade.lua): the console fades while idle, which is what
    -- is ticked here not being so; its opacity shown and faded, and how long a
    -- fade takes each way, in seconds. The overhead shows whenever it holds
    -- anything, so it has only an opacity and its fade times.
    consoleFade = false,
    consoleShowCombat = true, consoleShowTarget = true, consoleShowHurt = true,
    consoleShowGroup = false, consoleShowMouse = true,
    consoleAlpha = 1, consoleFadedAlpha = 0, consoleFadeIn = 0.2, consoleFadeOut = 0.6,
    overheadAlpha = 1, overheadFadeIn = 0.2, overheadFadeOut = 0.2,
    deadColor = "ff40424a", -- a dead friend's frame (dead.lua), every frame and profile
    visibility = 1,         -- Bar 1 visibility: see VISIBILITY
    extraVisibility = 1,    -- Extra bar(s) visibility (action bars 2 and 3): see VISIBILITY
    drawer = 1,             -- which way the minimap button drawer opens: see DRAWER
    chat = true,            -- the chat in a box on the left strip, the quest tracker over it
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
    aurasTrackedBars = true, -- in combat, the Cooldown Manager's tracked bars in place of the lists
    bags = true,            -- Medalluin's bags window instead of Blizzard's bags
    bagsView = "grid",      -- "bags": each bag under its name; "grid": every slot, bag by bag; "groups": fixed groups
    bagsColumns = 10,       -- slots across the window (not on the page: the window's corner sets it, 8 to 24)
    bagsItemLevel = true,   -- item levels on weapons and armour
    bagsPoint = false,      -- where the window was dragged to: { point, relativePoint, x, y } (not on the page)
    bank = true,            -- Medalluin's bank window instead of Blizzard's (Forever)
    bankView = "grid",      -- as bagsView, for the bank
    bankDetails = true,     -- the bank window's details: its bag slots and the purchase
    bankPlace = false,      -- detached: { detached, point, relative, x, y, w, h, scale } (not on the page)
    character = true,       -- Medalluin's character window instead of Blizzard's
    characterDetails = true, -- its pages' details open (the window's chevron sets it too)
    spellbook = true,       -- Medalluin's spellbook instead of Blizzard's (Forever)
    spellbookDetails = true, -- its pages' details open (the window's chevron sets it too)
    spellbookAllRanks = false, -- every rank of a spell listed, not only its highest learned
    spellbookMissing = true, -- a red edge on a spell on no action bar (nor in a macro on one)
    spellbookUpRankAll = false, -- every spell kept on its highest rank on the bars (else only those ticked)
    talents = true,         -- Medalluin's talents instead of Blizzard's (Forever)
    talentsDetails = true,  -- its trees' details open (the window's chevron sets it too)
    professions = true,     -- Medalluin's professions instead of Blizzard's (Forever)
    professionsDetails = true, -- its recipes' details open (the window's chevron sets it too)
    quests = true,          -- Medalluin's quest tracker on the left; its full view stands in the chat box
    questsSort = "level",   -- "level", "zone" or "distance" (Questie's; the tracker's button sets it too)
    questsFolded = false,   -- the zone headings folded: { [zone] = true } (not on the page)
    questsMinimised = false, -- the tracker folded to its heading (not on the page: a click on its heading)
    questsView = "full",    -- "full": the screen's height at its left; "minimal": a box to move and size
    questsPlace = false,    -- the minimal view's place, size and scale: { point, relative, x, y, w, h, scale }
    questsFullMouseover = false, questsFullCombat = false,       -- each view hidden until the pointer is
    questsMinimalMouseover = false, questsMinimalCombat = false, -- over it, and in combat
    questsTree = false,     -- objectives on a tree's branches, the finished risen to the top; bulleted otherwise
    npcWindows = true,      -- gossip, the quest pages and the vendor in a box on the chat box (npc/window.lua)
    trainerFilter = false,  -- the trainer's type shown: "available", "unavailable" or "used"; Available if unset
    questsTitleFont = "marcellus", questsTitleSize = 12,         -- ns.Fonts()'s keys, and points
    questsObjectiveFont = "marcellus", questsObjectiveSize = 12,
    optionsPoint = false,   -- where the settings window was dragged to, the same way (options/window.lua)
    editorPoint = false,    -- and the unit-frame editor's (options/editor.lua)
    editCanvasPoint = false, -- and its edit-mode canvas (options/canvas.lua)
    xpCast = false,         -- the player's casts over the experience bar
    repCast = false,        -- the target's casts over the reputation bar
    simParty = false,       -- simulate party frames and show the group art layer
    partyPets = true,       -- show pet frames directly below party members with pets
    partyLayout = "console", -- "console": on the console, the medallion's wings or the light profile's row
                             -- under it (console/party_row.lua); "widget": a box dragged anywhere
                             -- (widgets/party.lua)
    partyRange = 40,        -- distance in yards to fade out-of-range party frames (0 = off)
    overhead = true,        -- top-of-screen cascading trapezoid structure
    bossFrames = "overhead", -- boss frames on the overhead's top tier, in the "vertical" Boss widget, or "both"
    -- where each group widget was dragged to: { point, relativePoint, x, y } (widgets/; not on the
    -- page), shared by every profile
    partyWidgetPoint = false, raidWidgetPoint = false, bossWidgetPoint = false, arenaWidgetPoint = false,
    topPet = true,          -- player pet unit frame on the middle tier
    topFocus = true,        -- focus unit frame on the middle tier
    topToT = true,          -- target of target frame on the middle tier
    topPetBar = true,       -- pet action bar on the bottom tier
    topStances = true,      -- stance bar on the bottom tier
    topTotems = true,       -- totem bar on the bottom tier (Forever's)
    auraGlow = true,        -- border glow for dispellable debuffs
    auraCC = true,          -- large center icon for crowd control
    auraBuffs = true,       -- row of player-cast buffs on outer health corner
    auraBoss = true,        -- boss debuffs on inner health corner
    bossMine = true,        -- your debuffs on the overhead's bosses
    -- The widgets' (Unit Frames' Widget groups and the Raid, Battleground and
    -- Arena tabs; console/auras.lua), shared by every profile: the Party
    -- widget's own range, pets and auras (ns.PartyOption), the raid's out of
    -- battlegrounds and in one, the Boss widget's and the arena's
    partyWidgetRange = 40, partyWidgetPets = true, partyWidgetGlow = true, partyWidgetCC = true,
    partyWidgetBuffs = true, partyWidgetBoss = true,
    raidRange = 40, raidGlow = true, raidCC = true, raidBoss = true,
    bgRange = 40, bgGlow = true, bgCC = true,
    bossWidgetMine = true,
    arenaCC = true, arenaMine = true,
    -- each box's movers (its tabs) only on mouseover (widgets/box.lua)
    partyWidgetMoverHover = false, raidMoverHover = false, bgMoverHover = false, bossMoverHover = false,
    arenaMoverHover = false,
    -- what the unit-frame editor (editor.lua) changed on each frame, piece
    -- by piece: false until something is; the console's per profile, the
    -- widgets' shared
    editUnit = false, editParty = false,
    editPartyWidget = false, editRaid = false, editBoss = false, editArena = false,
    blizzardAuras = false,  -- Blizzard's own buff and debuff rows, top right (blizzard.lua)
    consoleProfile = "default", -- "default": medallion console; "light": central console with square minimap & bar 7
    -- which page each bar shows (bars/paging.lua): "default", "stances", "page1".."page10" or
    -- "custom", with the custom conditional beside it
    bar1Paging = "default", bar1PagingCustom = "",
    row2Paging = "default", row2PagingCustom = "",
    row3Paging = "default", row3PagingCustom = "",
    gridPaging = "default", gridPagingCustom = "",
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
        .. "split Action Bars 2 & 3, and party frames in a row under the console." },
}

-- The options are layered: DEFAULTS, then the chosen profile, then the
-- player's own choices on top. Only a choice that differs from the profile
-- is saved.
--
-- What shapes the console (every page under Console; under Unit Frames the
-- console's party and the overhead's bosses; the editor's player, target and console party) is
-- remembered per profile, in MedalluinDB.profiles[name]:
-- each profile keeps its own choices, so a switch brings back the ones made
-- on the profile switched to. Everything else (the group widgets, the chat,
-- the side panel, the bags, where windows were left, the party preview) has
-- nothing to do with the console and is one set, MedalluinDB.global.
-- Reset profile clears the current profile's choices and nothing else.
local PER_PROFILE = {}
for _, key in ipairs({
    "actionBar", "rows", "bareIcons", "artColor", "hideEmpty", "barLowRow", "visibility", "extraVisibility", "drawer",
    "hotkeySize", "cooldownText", "cooldownTextSize", "cooldownSwipe", "cooldownEdge", "cooldownBling",
    "consoleScale", "consoleX", "consoleY", "overheadScale", "overheadX", "overheadY",
    "minimapAuto", "minimapAutoCombat", "minimapAutoTarget", "minimapAutoSkyriding",
    "minimapScale", "minimapX", "minimapY", "minimapAreaTime", "minimapStart",
    "consoleFade", "consoleShowCombat", "consoleShowTarget", "consoleShowHurt", "consoleShowGroup",
    "consoleShowMouse", "consoleAlpha", "consoleFadedAlpha", "consoleFadeIn", "consoleFadeOut",
    "overheadAlpha", "overheadFadeIn", "overheadFadeOut",
    "bar1Paging", "bar1PagingCustom", "row2Paging", "row2PagingCustom", "row3Paging", "row3PagingCustom",
    "gridPaging", "gridPagingCustom",
    "partyPets", "partyLayout", "partyRange", "auraGlow", "auraCC", "auraBuffs", "auraBoss", "bossMine",
    "editUnit", "editParty",
    "overhead", "bossFrames", "topPet", "topFocus", "topToT", "topPetBar", "topStances", "topTotems",
    "xpCast", "repCast",
}) do PER_PROFILE[key] = true end
ns.PER_PROFILE = PER_PROFILE

-- The party's options: the console's (per profile, shaped and placed by
-- it), or, while the Party layout is the widget, the widget's own (shared).
-- The player's and target's frames keep the console's.
local PARTY_WIDGET = {
    partyRange = "partyWidgetRange", partyPets = "partyWidgetPets", auraGlow = "partyWidgetGlow",
    auraCC = "partyWidgetCC", auraBuffs = "partyWidgetBuffs", auraBoss = "partyWidgetBoss",
}
function ns.PartyKey(key)
    return ns.db.partyLayout == "widget" and PARTY_WIDGET[key] or key
end
function ns.PartyOption(key) return ns.db[ns.PartyKey(key)] end

local function Profile()
    return MedalluinDB and PROFILES[MedalluinDB.consoleProfile] and MedalluinDB.consoleProfile or "default"
end

-- What an option is when the player has not chosen: the profile's, else DEFAULTS.
local function Base(key)
    local v = PROFILES[Profile()][key]
    if v == nil then v = DEFAULTS[key] end
    return v
end

-- Where the player's choice for an option is kept.
local function Store(key)
    if PER_PROFILE[key] then return MedalluinDB.profiles[Profile()] end
    return MedalluinDB.global
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
            MedalluinDB.consoleProfile = value
        elseif value == Base(key) then
            Store(key)[key] = nil
        else
            Store(key)[key] = value
        end
    end,
})

-- ns.OnSetting(key, fn): fn(value) whenever the player changes that option.
-- ns.OnAnySetting(fn): fn(key, value) after any option changes (the
-- settings window, to show it).
local watchers, anyWatchers = {}, {}
function ns.OnSetting(key, fn)
    watchers[key] = watchers[key] or {}
    table.insert(watchers[key], fn)
end
function ns.OnAnySetting(fn)
    table.insert(anyWatchers, fn)
end
local function Changed(key, value)
    ns.db[key] = value
    for _, fn in ipairs(watchers[key] or {}) do fn(value) end
    for _, fn in ipairs(anyWatchers) do fn(key, value) end
end

-- What an option is when the player has not chosen one (the window's tips).
ns.OptionBase = Base

local SwitchProfile

-- ns.SetOption(key, value): an option changed, by the settings window or by
-- Medalluin's own controls (the side panel's column buttons). Choosing the
-- profile switches to it.
function ns.SetOption(key, value)
    if key == "consoleProfile" then SwitchProfile(value) end
    Changed(key, value)
end

-- Run change(), which moves layers under the options, then tell the modules
-- (and the window) about every option whose value it moved.
local function Relayer(change)
    local before = {}
    for key in pairs(DEFAULTS) do before[key] = ns.db[key] end
    change()
    for key in pairs(DEFAULTS) do
        local now = ns.db[key]
        -- the profile's own setting reports itself, as any setting does
        if now ~= before[key] and key ~= "consoleProfile" then Changed(key, now) end
    end
end

-- Switching profile brings back that profile's own choices; the global
-- options stay as they are.
function SwitchProfile(profile)
    if not PROFILES[profile] or profile == Profile() then return end
    -- and its own skills on the bars (bars/skills.lua), and keys on them
    -- (keybind.lua)
    if ns.SwitchSkills then ns.SwitchSkills(Profile(), profile) end
    if ns.SwitchKeys then ns.SwitchKeys(Profile(), profile) end
    Relayer(function() MedalluinDB.consoleProfile = profile end)
end

-- Reset profile: the current profile's options back to its own.
function ns.ResetProfile()
    Relayer(function() wipe(MedalluinDB.profiles[Profile()]) end)
end

-- A saved table from before profiles is flat, every option at the top with
-- the defaults filled in. Its console options become the choices of the
-- profile it was on (the other profile starts as it is drawn), the rest the
-- global ones; only what differs from the profile is kept, and anything
-- unknown is left where it is.
local function Migrate()
    local db = MedalluinDB
    db.global = db.global or {}
    db.profiles = db.profiles or {}
    for name in pairs(PROFILES) do db.profiles[name] = db.profiles[name] or {} end
    -- the overhead's Boss frames checkbox became Boss frames: Overhead,
    -- Vertical or Both; turned off, the bosses were not on the overhead
    local stores = { db }
    for name in pairs(PROFILES) do table.insert(stores, db.profiles[name]) end
    -- the party layout was Vertical (the medallion's wings, the light
    -- profile's stack on the left), Horizontal (the light profile's row) or
    -- Widget; the stack is gone, and both others are now the console's own
    for _, store in ipairs(stores) do
        if store.partyLayout == "vertical" or store.partyLayout == "horizontal" then store.partyLayout = nil end
    end
    for _, store in ipairs(stores) do
        if store.topBoss == false and store.bossFrames == nil then store.bossFrames = "vertical" end
        store.topBoss = nil
    end
    for key in pairs(DEFAULTS) do
        local v = db[key]
        if key ~= "consoleProfile" and v ~= nil then
            if v ~= Base(key) then Store(key)[key] = v end
            db[key] = nil
        end
    end
    -- The widgets became shared by every profile, the console's party staying
    -- per profile. A widget's place, kept per profile until then, comes from
    -- the profile in use; the widgets' own options start from what the party
    -- (and Your debuffs, the boss's) had there, which was theirs until then.
    -- Once: an option set back to its default is not saved, and must not be
    -- copied again.
    if not db.widgetsShared then
        local here = db.profiles[Profile()]
        for _, key in ipairs({ "partyWidgetPoint", "raidWidgetPoint", "bossWidgetPoint", "arenaWidgetPoint" }) do
            if db.global[key] == nil then db.global[key] = here[key] end
            for name in pairs(PROFILES) do db.profiles[name][key] = nil end
        end
        local from = {
            partyWidgetRange = "partyRange", partyWidgetPets = "partyPets", partyWidgetGlow = "auraGlow",
            partyWidgetCC = "auraCC", partyWidgetBuffs = "auraBuffs", partyWidgetBoss = "auraBoss",
            raidRange = "partyRange", bgRange = "partyRange", bossWidgetMine = "bossMine",
        }
        for key, src in pairs(from) do
            if db.global[key] == nil then db.global[key] = here[src] end
        end
        db.widgetsShared = true
    end
end

-- "ffRRGGBB" -> r, g, b in 0..1, white for anything unreadable.
function ns.HexColor(hex)
    local r, g, b = tostring(hex):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Only a key is added: assigning StaticPopupDialogs itself would taint it.
StaticPopupDialogs.MEDALLUIN_RESET_PROFILE = {
    text = "Put this console profile's options back to its own?\n\n"
        .. "Options that take effect after a reload need one.",
    button1 = OKAY or "Okay",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ResetProfile() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- The conditional editor: the bar's conditional in use, in a text box.
-- Saving one picks Custom; saving it empty, or cancelling a Custom that has
-- none, goes back to the bar's default.
local function PagingBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end
local function SavePaging(dialog, bar)
    local text = (PagingBox(dialog):GetText() or ""):match("^%s*(.-)%s*$")
    ns.SetOption(bar.key .. "Custom", text)
    ns.SetOption(bar.key, text ~= "" and "custom" or "default")
end
StaticPopupDialogs.MEDALLUIN_PAGING = {
    text = "%s: the page, by macro conditional",
    button1 = SAVE or "Save",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    editBoxWidth = 420,
    OnShow = function(self, bar)
        local box = PagingBox(self)
        box:SetText(ns.PagingStart(bar.key))
        box:HighlightText()
    end,
    OnAccept = function(self, bar) SavePaging(self, bar) end,
    OnCancel = function(_, bar)
        if ns.db[bar.key] == "custom" and not tostring(ns.db[bar.key .. "Custom"]):match("%S") then
            ns.SetOption(bar.key, "default")
        end
    end,
    EditBoxOnEnterPressed = function(self, bar)
        local dialog = self:GetParent()
        SavePaging(dialog, bar)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
function ns.EditPaging(bar)
    StaticPopup_Show("MEDALLUIN_PAGING", bar.name, nil, bar)
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    MedalluinDB = MedalluinDB or {}
    Migrate()
    ns.db = layered
    if ns.db.consoleProfile == "light" and ns.ApplyLightProfile then
        ns.ApplyLightProfile()
    end
end)

SLASH_MEDALLUIN1 = "/medalluin"
SLASH_MEDALLUIN2 = "/mui"
SLASH_MDLUI1 = "/mdlui"

local KEYBIND = { kb = true, keybind = true, keybinds = true, bind = true, binds = true }
local EDITOR = { edit = true, editor = true, frames = true }
local MOVE = { move = true, movers = true, unlock = true }

-- /mdlui <word>: the window on that page.
local PAGES = {
    console = "console/general", profile = "console/general", profiles = "console/general",
    position = "console/general", scale = "console/general", place = "console/general",
    layout = "console/general", unitlayout = "console/general",
    cast = "console/general", castbars = "console/general", casting = "console/general",
    minimap = "console/minimap", map = "console/minimap",
    paging = "console/bar", page = "console/bar", pages = "console/bar",
    bar = "console/bar", actionbar = "console/bar", bars = "console/bar",
    unit = "units/general", units = "units/general", unitframe = "units/general", unitframes = "units/general",
    uf = "units/general", party = "units/party", raid = "units/raid", bg = "units/battleground",
    battleground = "units/battleground", pvp = "units/battleground", boss = "units/boss", bosses = "units/boss",
    arena = "units/arena",
    overhead = "console/overhead", top = "console/overhead",
    chat = "chat",
    side = "side/general", meter = "side/meter", loot = "side/loot", auras = "side/auras",
    bags = "bags", bag = "bags", inventory = "bags", bank = "bank",
    character = "character", char = "character",
    spellbook = "spellbook", spells = "spellbook", book = "spellbook",
    talents = "talents", talent = "talents",
    professions = "professions", profession = "professions", prof = "professions", craft = "professions",
    quests = "quests", quest = "quests", tracker = "quests",
    npc = "npc", gossip = "npc", vendor = "npc", merchant = "npc",
    tooltip = "tooltips", tooltips = "tooltips",
}

local function OpenSettings(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%S+)")
    if (arg == "taint" or arg == "debug") and ns.TaintReport then
        ns.TaintReport()
        return
    end
    if KEYBIND[arg] then
        if ns.KeybindMode then ns.KeybindMode() end
        return
    end
    if EDITOR[arg] then
        if ns.OpenEditor then ns.OpenEditor() end
        return
    end
    -- the consoles' movers, as Edit Mode shows them (movers.lua); again hides them
    if MOVE[arg] then
        if ns.ShowConsoleMovers then ns.ShowConsoleMovers(not ns.ConsoleMoversShown()) end
        return
    end
    if ns.OpenOptions then ns.OpenOptions(PAGES[arg]) end
end

SlashCmdList.MEDALLUIN = OpenSettings
SlashCmdList.MDLUI = OpenSettings
