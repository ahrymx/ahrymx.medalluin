-- What the settings window shows: the tree's pages in order, Console's and
-- Unit Frames' pages as tabs, each page's options in groups. Data only; the window
-- (window.lua) draws it and controls.lua makes the controls.
--
-- A page's master, when it has one, is the checkbox at its top: while it is
-- off, everything else on the page is drawn but cannot be changed. An
-- option marked reload takes effect after a reload; the window's footer
-- says so once one has changed.
local _, ns = ...

local RELOAD = " Takes effect after a reload."

local function Check(key, label, tip, reload)
    return { kind = "check", key = key, label = label, tip = reload and tip .. RELOAD or tip, reload = reload }
end
local function Choice(key, label, choices, tip, reload)
    return { kind = "choice", key = key, label = label, choices = choices,
        tip = reload and tip .. RELOAD or tip, reload = reload }
end
local function Color(key, label, tip)
    return { kind = "color", key = key, label = label, tip = tip }
end
local function Button(label, click, tip)
    return { kind = "button", label = label, click = click, tip = tip }
end
-- The unit-frame editor on a frame (options/editor.lua).
local function Editor(id, label)
    return Button(label or "Edit the frames", function()
        ns.OpenEditor(type(id) == "function" and id() or id)
    end, "The unit-frame editor: move, size, show or hide each piece of these frames, and choose what their "
        .. "texts say. Also /mdlui edit.")
end

local function Group(title, ...)
    return { title = title, items = { ... } }
end

-- An opacity, as a percentage; and a fade's length, in seconds.
local function Opacity(key, label, tip, needs)
    return { kind = "slider", key = key, label = label, min = 0, max = 1, step = 0.05, tip = tip, needs = needs,
        text = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end }
end
local function Seconds(key, label, tip)
    return { kind = "slider", key = key, label = label, min = 0, max = 2, step = 0.05, tip = tip,
        text = function(v)
            if v < 0.025 then return "At once" end
            return string.format("%.2fs", v)
        end }
end

-- Lists of groups, one after another.
local function Concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, g in ipairs(list) do table.insert(out, g) end
    end
    return out
end

-- A console's place and size (movers.lua), as one group; a tip under its title.
local function Placed(id, title, tip)
    local groups = ns.ConsolePlaceGroups(Group, { { id, title } })
    if groups[1] then groups[1].tip = tip end
    return groups
end

-- Bar 1's choices, and the extra bars'
local function Visibility(it, them)
    local V = ns.VISIBILITY
    return {
        { V.ALWAYS, "Always" },
        { V.COMBAT, "In combat", "Faded out of combat; " .. it .. " back while you drag a spell onto " .. them .. "." },
        { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over " .. them .. ", or a spell is being dragged." },
        { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
    }
end

-- A text size, as a scale of what the button draws on its own; first, a
-- choice before them (Hidden).
local function TextSizes(first)
    local sizes = {
        { 0.8, "Small" },
        { 1, "Normal", "As the button draws it." },
        { 1.25, "Large" },
        { 1.5, "Larger" },
    }
    if first then table.insert(sizes, 1, first) end
    return sizes
end

-- How far a group's frames reach before they fade.
local function Range(key, who)
    return Choice(key, "Fade out of range", {
        { 40, "40 yards", "Standard spell and healing range." },
        { 30, "30 yards", "Mid-range distance." },
        { 20, "20 yards", "Short distance." },
        { 10, "10 yards", "Melee and interaction distance." },
        { 0, "Disabled", "Never fade " .. who .. " frames based on distance." },
    }, "Fade " .. who .. " frames when members move beyond the chosen distance.")
end
local function Glow(key)
    return Check(key, "Dispel glow on frame borders",
        "Glow the frame's border in the debuff's color (purple for Curse, green for Poison, etc.) when an ally has "
        .. "a debuff you can dispel.")
end
local function CC(key, whose)
    return Check(key, "Crowd control center icon",
        "Display a large icon in the middle of " .. whose .. " frame with a radial timer sweep when the unit is "
        .. "affected by CC.")
end
local function BossDebuffs(key)
    return Check(key, "Boss debuffs",
        "Show a critical boss debuff in the middle of the frame, where crowd control would be; crowd control "
        .. "comes first.")
end
local function Pets(key)
    return Check(key, "Show party pets", "Show pet unit frames directly below party members who have active pets.")
end
local function Buffs(key)
    return Check(key, "Player buffs on health",
        "Show a compact row of your own buffs and HoTs on the outer corner of the health bar.")
end
local function Movers(key, what)
    return Check(key, "Movers only on mouseover",
        "Hide the " .. what .. " widget's tab, the grip that moves it, until the pointer is over the widget.")
end
local function Mine(key, who)
    return Check(key, "Your debuffs",
        "Up to three of your own debuffs on " .. who .. ", small icons in the health bar's top right corner.")
end

-- Built when the window first opens: the lists come from modules loaded
-- after settings.lua (paging, the meter, the loot log).
function ns.OptionPages()
    local metrics, qualities = {}, {}
    for _, m in ipairs(ns.METER_METRICS) do table.insert(metrics, { m[1], m[2] }) end
    for _, q in ipairs(ns.LOOT_QUALITIES) do table.insert(qualities, { q[1], q[2] }) end
    local M = ns.METER_SESSION

    local paging = {}
    for _, pb in ipairs(ns.PAGING_BARS or {}) do
        table.insert(paging, {
            title = "Paging: " .. pb.name,
            tip = pb.grid and "The light profile's 2x5 grid in the centre bay."
                or pb.base and ("Shown with Rows at " .. pb.name:match("%d") .. " or more.")
                or "Action bar 1, in the bar's frame.",
            items = {
                Choice(pb.key, "Pages", ns.PagingChoices(pb),
                    "Which action page the bar shows. A page is 12 slots: page n holds slots (n-1)x12+1 to nx12."),
                Button("Edit conditional", function() ns.EditPaging(pb) end,
                    "A macro conditional naming the page, e.g. [mod:shift] 2; [stealth] 7; 1. \"possess\" is the "
                    .. "bar the game puts up for a vehicle, an override or a possessed unit. Saving it picks Custom."),
            },
        })
    end

    return {
        {
            id = "general", name = "General", intro = "Shared by every profile.",
            groups = {
                Group("Preview",
                    Check("simParty", "Simulate party frames",
                        "Show the console's party frame layer and simulated party members to preview "
                        .. "party frames while solo. The group boxes show too. A small panel on the left sets "
                        .. "what they show, a tab each for the party, the raid, the enemies and the "
                        .. "overhead frames: members and their health, deaths, range, pets, auras, "
                        .. "ready and role checks.")),
                Group("Editor",
                    Editor(nil, "Edit unit frames")),
                Group("Key bindings",
                    Button("Bind keys", function()
                        if ns.CloseOptions then ns.CloseOptions() end
                        ns.KeybindMode(true)
                    end, "Closes this window. Point at an action button and press a key to bind it; Esc "
                        .. "over a button removes its keys. Also /mdlui kb. The action bars' keys are kept "
                        .. "per profile.")),
                Group("Dead and offline",
                    Color("deadColor", "Dead frame colour",
                        "A dead or offline friend's frame: the player's, the party's (console or widget) "
                        .. "and the raid's. It shows the status icon, time or disconnection, and their name.")),
            },
        },
        {
            id = "console", name = "Console",
            tabs = {
                {
                    id = "general", name = "General",
                    intro = "Each profile remembers everything under Console, the console's party and the "
                        .. "overhead's bosses under Unit Frames, its skills on the bars and their keys. The "
                        .. "widgets, Chat, Side panel and Bags are shared. What the frames show is under Unit Frames.",
                    groups = Concat({
                        Group("Profile",
                            Choice("consoleProfile", "Console profile", ns.PROFILE_NAMES,
                                "The console the pages under Console start from. Switching brings back the options, "
                                .. "skills and keys you chose on that profile.", true),
                            Button("Reset profile", function() StaticPopup_Show("MEDALLUIN_RESET_PROFILE") end,
                                "This profile's options under Console, and its console party and overhead bosses under "
                                .. "Unit Frames, back to its own. The widgets, Chat, Side panel and Bags are left as "
                                .. "they are.")),
                        Group("Where the frames sit",
                            Choice("partyLayout", "Party layout", {
                                { "console", "Console", function()
                                    if ns.layout and ns.layout.party and ns.layout.party.row then
                                        return "A row of four frames under the Central Console, each member's pet "
                                            .. "hanging under its frame. While you are in a group the minimap stays in "
                                            .. "the top right corner and the centre grid stays out."
                                    end
                                    return "The medallion's party wings, each member's pet hanging under its frame."
                                end },
                                { "widget", "Widget", "A box of party frames, under a Party tab, that you can drag "
                                    .. "anywhere: hold the tab to move it. In a raid it gives way to the raid "
                                    .. "frames." },
                            }, "Where the party frames sit."),
                            Choice("bossFrames", "Boss frames", {
                                { "overhead", "Overhead", "On the overhead's top tier, dividing into 1, 2 or 3 "
                                    .. "columns." },
                                { "vertical", "Vertical", "A column under a Boss tab that you can drag anywhere: "
                                    .. "hold the tab to move it." },
                                { "both", "Both", "On the overhead and in the column." },
                            }, "Where the encounter's boss frames show. Raid and arena frames are boxes too: hold a "
                                .. "box's tab to move it. Simulate party frames shows them all.")),
                        Group("Cast bars",
                            Check("xpCast", "Player casts on the experience bar",
                                "The experience bar under your portrait becomes your cast bar while you cast, and "
                                .. "goes back to experience when you stop."),
                            Check("repCast", "Target casts on the reputation bar",
                                "The reputation bar under your target becomes its cast bar while it casts, and goes "
                                .. "back to reputation when it stops or you change target.")),
                    }, Placed("console", "Position",
                        "Or open Edit Mode: drag a console anywhere, and click it for its scale. Without Edit "
                        .. "Mode, /mdlui move. The corner strips keep their own size and place."), {
                        {
                            title = "Visibility",
                            tip = "A faded console still works: its buttons click and its keys press. Binding "
                                .. "keys, a spell on the pointer, Edit Mode and Simulate party frames bring it back.",
                            items = {
                                Check("consoleFade", "Fade when idle",
                                    "Fade the console while none of what is ticked here is so."),
                                Opacity("consoleFadedAlpha", "Faded opacity",
                                    "How much of it shows while it is faded.", "consoleFade"),
                                { kind = "check", key = "consoleShowCombat", label = "In combat",
                                    tip = "While you are in combat.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowTarget", label = "With a target",
                                    tip = "While you have a target.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowHurt", label = "Health not full",
                                    tip = "While your health is below its most.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowGroup", label = "In a group",
                                    tip = "While you are in a party or a raid.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowMouse", label = "On mouseover",
                                    tip = "While the pointer is over the console, its bars or its party.",
                                    needs = "consoleFade" },
                            },
                        },
                        Group("Opacity",
                            Opacity("consoleAlpha", "Opacity", "How much of the console shows while it is not "
                                .. "faded. The corner strips and the corner minimap keep their own."),
                            Seconds("consoleFadeIn", "Fade in", "How long it takes to come back."),
                            Seconds("consoleFadeOut", "Fade out", "How long it takes to fade.")),
                    }),
                },
                {
                    id = "bar", name = "Action Bars", intro = "Kept per profile.",
                    master = Check("actionBar", "Action bar",
                        "Medalluin's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's "
                        .. "bars or use another action-bar addon.", true),
                    groups = Concat({
                        Group("Look",
                            Choice("rows", "Rows", {
                                { 1, "1 row", "Action bar 1." },
                                { 2, "2 rows", "Action bar 2 stacked above action bar 1." },
                                { 3, "3 rows", "Action bars 2 and 3 stacked above action bar 1." },
                            }, "Stack Blizzard's bottom bars (action bars 2 and 3) above Medalluin's bar frame "
                                .. "instead of leaving them where Edit Mode puts them.", true),
                            Color("artColor", "Art colour", "Tints the bar's stone frame. White leaves it as drawn."),
                            Check("bareIcons", "Bare icons",
                                "Square icons with a thin black edge, the cooldown time on the icon and range as a "
                                .. "red tint, instead of Blizzard's button art.", true),
                            Check("hideEmpty", "Hide empty buttons",
                                "Hides empty buttons and their keybind text on extra bars (action bars 2 and 3).")),
                        Group("Text",
                            Choice("hotkeySize", "Keybind text size", TextSizes({ 0, "Hidden", "No keybind text." }),
                                "The key bound to each button, at its top right.")),
                        Group("Cooldowns",
                            Choice("cooldownText", "Cooldown numbers", {
                                { "auto", "Default", "Bare icons show them; Blizzard's art follows the game's "
                                    .. "Show cooldown numbers option (Options > Action Bars)." },
                                { "show", "Always", "On every button, bare icons or Blizzard's art." },
                                { "hide", "Never", "The sweep alone says how long is left." },
                            }, "The time left, on the icon. The global cooldown never shows one on bare icons."),
                            Choice("cooldownTextSize", "Cooldown number size", TextSizes(),
                                "The time left on a cooling-down button."),
                            Check("cooldownSwipe", "Sweep",
                                "The dark sweep that winds round a cooling-down icon."),
                            Check("cooldownEdge", "Sweep edge",
                                "A bright line along the sweep's leading edge."),
                            Check("cooldownBling", "Flash when ready",
                                "The flash a button gives as its cooldown ends.")),
                        Group("Fading",
                            Choice("visibility", "Bar 1 visibility", Visibility("it comes", "it"),
                                "A faded bar still works: its buttons and key bindings stay live."),
                            Choice("extraVisibility", "Extra bar(s) visibility", Visibility("they come", "them"),
                                "Manages the visibility of action bars 2 and 3. Faded bars still work: their buttons "
                                .. "and key bindings stay live.")),
                        Group("Minimap buttons",
                            Choice("drawer", "Drawer opens", {
                                { ns.DRAWER.LEFT, "Open left", "One row, out to the left of the bar." },
                                { ns.DRAWER.UP, "Open up", "One column, up from the bar's left end." },
                            }, "The addons' minimap buttons gather in a drawer behind the box on the bar's left "
                                .. "end. This is the way it opens.")),
                    }, paging),
                },
                {
                    id = "overhead", name = "Overhead", intro = "Kept per profile.",
                    master = Check("overhead", "Overhead console",
                        "Top-of-screen cascading trapezoid structure for boss frames, pet, focus, target of target, "
                        .. "and action bars.", true),
                    groups = Concat({
                        Group("Frames",
                            Check("topPet", "Player pet frame", "Player pet unit frame on the middle tier."),
                            Check("topFocus", "Focus frame", "Focus target unit frame on the middle tier."),
                            Check("topToT", "Target of target frame",
                                "Target's target unit frame on the middle tier.")),
                        Group("Bars",
                            Check("topPetBar", "Pet action bar", "Pet command and ability buttons on the bottom tier.",
                                true),
                            Check("topStances", "Stance bar",
                                "Shapeshift forms, stealth, stances, and auras on the bottom tier.", true),
                            Check("topTotems", "Totem bar",
                                "A shaman's totems on the bottom tier: each element's totem, and its choices "
                                .. "opening below it.", true)),
                    }, Placed("overhead", "Position"), {
                        Group("Opacity",
                            Opacity("overheadAlpha", "Opacity", "How much of the overhead shows. It shows "
                                .. "whenever it holds a frame or a bar."),
                            Seconds("overheadFadeIn", "Fade in", "How long it takes to appear."),
                            Seconds("overheadFadeOut", "Fade out", "How long it takes to go once it is empty.")),
                    }),
                },
                {
                    id = "minimap", name = "Minimap",
                    intro = "Kept per profile. The Central Console's minimap sits in the console's bay, or in the "
                        .. "screen's corner while the 2x5 grid takes the bay. The Medallion's stays in its ring.",
                    enabled = function() return ns.MinimapMoves and ns.MinimapMoves() end,
                    groups = Concat({
                        Group("Switching",
                            { kind = "key", label = "Minimap key", command = "MEDALLUIN_MINIMAP",
                                tip = "Moves the minimap to its other place and keeps it there. Press it again "
                                    .. "and the automatic moves decide once more. Also under Options > "
                                    .. "Keybindings > AddOns." }),
                        {
                            title = "Moving by itself",
                            tip = "A party row under the console always takes the corner: it needs the bay's foot.",
                            items = {
                                Check("minimapAuto", "Move automatically",
                                    "Into the corner on what is ticked here, and back into the console after."),
                                { kind = "check", key = "minimapAutoCombat", label = "In combat",
                                    tip = "While you are in combat.", needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoTarget", label = "With a target",
                                    tip = "While you have a target.", needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoSkyriding", label = "While skyriding",
                                    tip = "While you skyride: the grid shows the skyriding skills.",
                                    needs = "minimapAuto" },
                            },
                        },
                    }, Placed("minimap", "In the corner")),
                },
            },
        },
        {
            id = "units", name = "Unit Frames",
            tabs = {
                {
                    id = "general", name = "General",
                    intro = "Shared by every profile.",
                    groups = {
                        Group("Editor",
                            Editor(function() return ns.PartyWidgetLayout() and "partyWidget" or "party" end,
                                "Edit the party frames"),
                            Editor("unit", "Edit player and target")),
                        Group("Blizzard's auras (shared by every profile)",
                            Check("blizzardAuras", "Blizzard's buff and debuff rows",
                                "Show Blizzard's own rows of buffs and debuffs at the top right of the screen. Off, "
                                .. "Medalluin's auras stand in for them: the column over the portrait and the side "
                                .. "panel's Auras tab.")),
                    },
                },
                {
                    id = "party", name = "Party",
                    intro = "The party frames use the group their Party layout puts them in (Console > General). "
                        .. "The Console group is on the player and target frames too.",
                    groups = {
                        Group("Console (per profile)",
                            Range("partyRange", "party"), Pets("partyPets"),
                            Glow("auraGlow"), CC("auraCC", "the"), Buffs("auraBuffs"), BossDebuffs("auraBoss")),
                        Group("Widget (shared by every profile)",
                            Range("partyWidgetRange", "party"), Pets("partyWidgetPets"),
                            Glow("partyWidgetGlow"), CC("partyWidgetCC", "the"), Buffs("partyWidgetBuffs"),
                            BossDebuffs("partyWidgetBoss"), Movers("partyWidgetMoverHover", "Party")),
                    },
                },
                {
                    id = "raid", name = "Raid",
                    intro = "Shared by every profile. The Raid widget, out of battlegrounds; in one, the "
                        .. "Battleground tab's options take over.",
                    groups = {
                        Group("Raid", Range("raidRange", "raid"), Movers("raidMoverHover", "Raid")),
                        Group("Auras", Glow("raidGlow"), CC("raidCC", "a member's"), BossDebuffs("raidBoss")),
                        Group("Editor", Editor("raid")),
                    },
                },
                {
                    id = "battleground", name = "Battleground",
                    intro = "Shared by every profile. The Raid widget while you are in a battleground.",
                    groups = {
                        Group("Battleground", Range("bgRange", "battleground team"),
                            Movers("bgMoverHover", "Raid")),
                        Group("Auras", Glow("bgGlow"), CC("bgCC", "a member's")),
                        Group("Editor", Editor("raid", "Edit the raid frames")),
                    },
                },
                {
                    id = "boss", name = "Boss",
                    intro = "Where the boss frames show is Console > General > Boss frames.",
                    groups = {
                        Group("Overhead (per profile)", Mine("bossMine", "a boss")),
                        Group("Widget (shared by every profile)", Mine("bossWidgetMine", "a boss"),
                            Movers("bossMoverHover", "Boss")),
                        Group("Editor", Editor("boss", "Edit the Boss widget")),
                    },
                },
                {
                    id = "arena", name = "Arena",
                    intro = "Shared by every profile. The Arena widget's enemy frames.",
                    groups = {
                        Group("Arena", Movers("arenaMoverHover", "Arena")),
                        Group("Auras", CC("arenaCC", "an enemy's"), Mine("arenaMine", "an enemy")),
                        Group("Editor", Editor("arena")),
                    },
                },
            },
        },
        {
            id = "chat", name = "Chat", intro = "Shared by every profile.",
            master = Check("chat", "Chat panel",
                "Blizzard's chat in a panel on top of the micro menu, with the chat buttons in a column at its "
                .. "left. Untick it to keep the chat where Edit Mode puts it, or to use a chat addon.", true),
            groups = {},
        },
        {
            id = "side", name = "Side panel", intro = "Shared by every profile.",
            master = Check("side", "Side panel",
                "The chat panel's mirror on the right strip, over the stats, with an Auras tab, a Meter tab and a "
                .. "Loot tab. Untick it to keep the right corner clear, or to use a meter addon.", true),
            groups = {
                Group("Auras",
                    Check("sideAuras", "Auras tab",
                        "Your buffs and debuffs, each with the time it has left, the longest first."),
                    Choice("aurasColumns", "Aura lists", {
                        { 2, "Two", "Buffs and debuffs side by side." },
                        { 1, "One", "Buffs and debuffs in one list. In combat the game keeps the times to itself, "
                            .. "so there the list shows the debuffs first, then the buffs." },
                    }, "The column button with the bars on it switches this too."),
                    Check("aurasTimeless", "Auras that never run out",
                        "List forms, aspects, mounts and the like too, at the top. They are over the portrait "
                        .. "already. The infinity button switches this too."),
                    Check("aurasTrackedBars", "Tracked bars in combat",
                        "In combat the game keeps new buffs to itself, so the tab shows the Cooldown Manager's "
                        .. "tracked bars instead, until combat ends. Which bars, and how wide, are set in Edit Mode. "
                        .. "Only where the game has the Cooldown Manager.")),
                Group("Meter",
                    Check("sideMeter", "Meter tab",
                        "Damage, healing and more for each member of your group, from the game's own combat meter."),
                    Choice("meterColumns", "Meter lists", {
                        { 1, "One", "One list across the panel." },
                        { 2, "Two", "Two lists side by side, each showing its own thing: damage and healing, say." },
                    }, "The column button with the bars on it switches this too."),
                    Choice("meterLeft", "First list shows", metrics,
                        "Clicking a list's heading steps through these too; a right click steps back."),
                    Choice("meterRight", "Second list shows", metrics, "Shown when the meter has two lists."),
                    Choice("meterSession", "Fight", {
                        { M.CURRENT, "Current", "The fight you are in, or the last one." },
                        { M.OVERALL, "Overall", "Every fight since the meter was last reset." },
                    }, "The clock button switches this too."),
                    Check("meterRate", "Per second",
                        "Damage and healing as amounts per second instead of totals. The /s button switches this "
                        .. "too.")),
                Group("Loot",
                    Check("sideLoot", "Loot tab",
                        "What your group looted, boss by boss, with who won each roll. Not the chat's loot lines: "
                        .. "the chat keeps those."),
                    Choice("lootWho", "Whose loot", {
                        { ns.LOOT_WHO.GROUP, "The group's", "Everything the group looted, yours included." },
                        { ns.LOOT_WHO.MINE, "Mine", "Only what you looted or won." },
                    }, "The funnel button switches this too."),
                    Choice("lootQuality", "Least quality", qualities,
                        "Items below this quality are left out. The diamond button steps through these too."),
                    Check("lootMoney", "Money and currencies",
                        "Your share of looted money on each heading, and the currencies you loot as lines.")),
            },
        },
        {
            id = "bags", name = "Bags", intro = "Shared by every profile.",
            master = Check("bags", "Bags window",
                "Your backpack, bags and reagent bag in one window, with a search, the game's sort and the items "
                .. "in groups if you like. The bank stays the game's. Untick it to keep the game's bags, or to use "
                .. "a bag addon.", true),
            groups = {
                Group("Window",
                    Choice("bagsView", "Show", {
                        { "grid", "Every slot", "Every slot, bag by bag, the reagent bag on rows of its own." },
                        { "groups", "Groups", "The items in groups: new, equipment, consumables, quest items, trade "
                            .. "goods, other and junk, with one slot for the free ones." },
                    }, "The window's Groups and Grid button switches this too."),
                    Check("bagsItemLevel", "Item levels",
                        "The item level in the corner of each weapon and piece of armour, in its quality's colour.")),
            },
        },
        {
            id = "tooltips", name = "Tooltips (ext)",
            intro = "Provided by the optional mdlui_PrettyTooltip companion addon. "
                .. "Enable mdlui_PrettyTooltip in your AddOns list to reskin tooltips "
                .. "and open its style editor and options.",
            enabled = function() return SlashCmdList and SlashCmdList.PRETTYTOOLTIP ~= nil end,
            groups = {
                Group("mdlui_PrettyTooltip",
                    Button("Open style editor", function()
                        if SlashCmdList and SlashCmdList.PRETTYTOOLTIP then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.PRETTYTOOLTIP("")
                        end
                    end, "Closes this window and opens PrettyTooltip's live style editor (/ptip)."),
                    Button("Tooltip options", function()
                        if SlashCmdList and SlashCmdList.PRETTYTOOLTIP then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.PRETTYTOOLTIP("options")
                        end
                    end, "Closes this window and opens PrettyTooltip's options in the game's AddOns settings "
                        .. "(/ptip options).")),
            },
        },
    }
end
