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
-- An option greyed while another is off: for a master, whose page has no
-- other way to say so.
local function Needs(key, spec)
    spec.needs = key
    return spec
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

-- A font for reading (ns.Fonts()): its choices asked as the list opens,
-- since other addons register theirs after us; each drawn in itself. A
-- shared font chosen whose addon is gone stays listed, saying so (the text
-- is Medalluin's own meanwhile).
local function FontChoice(key, label, tip)
    local spec = { kind = "choice", key = key, label = label, tip = tip }
    function spec.list()
        local out, chosen, there = {}, ns.db and ns.db[key], false
        for _, f in ipairs(ns.Fonts()) do
            table.insert(out, { f[1], f[2], nil, f[3] })
            there = there or f[1] == chosen
        end
        local name = not there and type(chosen) == "string" and chosen:match("^lsm:(.+)$")
        if name then table.insert(out, { chosen, name .. " (not loaded)", nil, ns.font }) end
        return out
    end
    spec.choices = spec.list()
    return spec
end
local function Points(key, label, tip)
    return { kind = "slider", key = key, label = label, min = 9, max = 20, step = 1, tip = tip,
        text = function(v) return string.format("%d pt", v) end }
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

-- The lower row's choices: the swing timer only where the client has one
-- (bars/lowrow.lua)
local function LowRows()
    local out = {
        { "resource", "Class resource", "Combo points, holy power, chi, soul shards, arcane charges, essence or "
            .. "runes; vigor while skyriding. Empty for a class without one." },
    }
    if ns.SwingTimerAvailable and ns.SwingTimerAvailable() then
        table.insert(out, { "swing", "Swing timer", "Fills until your next main-hand swing or ranged shot, the "
            .. "seconds left at its right." })
    end
    table.insert(out, { "mana", "Mana", "Your mana, the amount at its right. Empty for a class without mana." })
    return out
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
-- The corner minimap's place and size, and its grip's showing.
local function MinimapCorner()
    local groups = Placed("minimap", "In the corner")
    table.insert(groups[1].items, Check("minimapMoverHover", "Movers only on mouseover",
        "Hide the corner minimap's tab, the grip with the area's name that moves it, until the pointer is over "
        .. "the minimap."))
    return groups
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
                Group("Game menu",
                    Choice("gameMenu", "Game menu", {
                        { "docked", "Docked", "A panel down the left edge: who you are at its top, the game's "
                            .. "buttons in sections under it, Log Out and Exit Game, and Return to Game at its foot." },
                        { "medallion", "Medallion", "A ring of medallions around your character: the game's "
                            .. "buttons an arch over it, Log Out, Return to Game and Exit Game below, each "
                            .. "chained to the next." },
                        { "game", "The game's", "The game's own menu, as it stands." },
                    }, "How the menu Escape opens looks. Its buttons stay the game's own.", true)),
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
                        Group("Lower row",
                            Choice("barLowRow", "Shows", LowRows(),
                                "What the row under the buttons shows. Your cast bar covers it while you cast.")),
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
                        .. "screen's corner while the 2x5 grid takes the bay. The Medallion's stays in its ring: of "
                        .. "this page, only Area name is for it too.",
                    enabled = function() return ns.MinimapMoves and ns.MinimapMoves() end,
                    groups = Concat({
                        Group("Switching",
                            { kind = "key", label = "Minimap key", command = "MEDALLUIN_MINIMAP",
                                tip = "Puts the minimap back where the game loads it (When the game loads), "
                                    .. "or, when it is there, in its other place, and keeps it there. Also under "
                                    .. "Options > Keybindings > AddOns." },
                            Choice("minimapStart", "When the game loads", {
                                { "auto", "As it moves", "Where Moving by itself puts it." },
                                { "console", "In the console" },
                                { "corner", "In the corner" },
                            }, "Where the minimap is after a login or a reload. It stays there until a ticked "
                                .. "trigger below starts or ends, or the minimap key is pressed. On the "
                                .. "Medallion console the minimap stays in its ring.")),
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
                    }, MinimapCorner(), {
                        Group("Area name",
                            { kind = "slider", key = "minimapAreaTime", label = "Shown for", min = 0, max = 10,
                                step = 0.5, always = true,
                                tip = "The area's name shows at the top of the minimap while the pointer is over "
                                    .. "it. After this long it fades out; Always keeps it until the pointer leaves. "
                                    .. "In the corner the name is on the minimap's grip instead.",
                                text = function(v)
                                    if v < 0.25 then return "Always" end
                                    return string.format("%gs", v)
                                end }),
                    }),
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
                            Range("partyWidgetRange", "party"),
                            Check("partyWidgetPlayer", "Include yourself",
                                "Show your own unit frame as the first row of the Party widget."),
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
            master = Check("chat", "Chat box",
                "Blizzard's chat in a box on top of the micro menu, with the chat buttons beside its tabs, "
                .. "the timeless buffs and the edit box under it, and the quest tracker's full view above it. "
                .. "Untick it to keep the chat where Edit Mode puts it, or to use a chat addon.", true),
            groups = {
                Group("Names",
                    Check("chatClassColors", "Class colours",
                        "A speaker's name in their class's colour, whatever the game's own chat settings say."),
                    Check("chatLevels", "Levels",
                        "A speaker's level before their name, \"[60:Name]\", when it is known: from the game for "
                        .. "the line, else from your group, target, nameplates, guild, friends or a /who.")),
            },
        },
        {
            id = "side", name = "Side panel",
            -- the panel itself, then a tab for each of its own tabs; those
            -- grey while the panel is off, through their masters
            tabs = {
                {
                    id = "general", name = "General", intro = "Shared by every profile.",
                    master = Check("side", "Side panel",
                        "The chat panel's mirror on the right strip, over the stats, with an Auras tab, a Meter tab "
                        .. "and a Loot tab. Untick it to keep the right corner clear, or to use a meter addon.", true),
                    groups = {},
                },
                {
                    id = "auras", name = "Auras", intro = "Shared by every profile.",
                    master = Needs("side", Check("sideAuras", "Auras tab",
                        "Your buffs and debuffs, each with the time it has left, the longest first.")),
                    groups = {
                        Group("Lists",
                            Choice("aurasColumns", "Aura lists", {
                                { 2, "Two", "Buffs and debuffs side by side." },
                                { 1, "One", "Buffs and debuffs in one list. In combat the game keeps the times to "
                                    .. "itself, so there the list shows the debuffs first, then the buffs." },
                            }, "The column button with the bars on it switches this too."),
                            Check("aurasTimeless", "Auras that never run out",
                                "List forms, aspects, mounts and the like too, at the top. They are over the portrait "
                                .. "already. The infinity button switches this too.")),
                        Group("In combat",
                            Check("aurasTrackedBars", "Enable tracked aura bars",
                                "In combat the game keeps new buffs to itself, so the tab shows the Cooldown "
                                .. "Manager's tracked bars instead, until combat ends. Ticking this turns the "
                                .. "Cooldown Manager on in the game's options too. Which bars, and how wide, are set "
                                .. "in Edit Mode. Only where the game has the Cooldown Manager.")),
                    },
                },
                {
                    id = "meter", name = "Meter", intro = "Shared by every profile.",
                    master = Needs("side", Check("sideMeter", "Meter tab",
                        "Damage, healing and more for each member of your group, from the game's own combat meter.")),
                    groups = {
                        Group("Lists",
                            Choice("meterColumns", "Meter lists", {
                                { 1, "One", "One list across the panel." },
                                { 2, "Two", "Two lists side by side, each showing its own thing: damage and "
                                    .. "healing, say." },
                            }, "The column button with the bars on it switches this too."),
                            Choice("meterLeft", "First list shows", metrics,
                                "Clicking a list's heading steps through these too; a right click steps back."),
                            Choice("meterRight", "Second list shows", metrics, "Shown when the meter has two lists."),
                            Choice("meterSession", "Fight", {
                                { M.CURRENT, "Current", "The fight you are in, or the last one." },
                                { M.OVERALL, "Overall", "Every fight since the meter was last reset." },
                            }, "The clock button switches this too."),
                            Check("meterRate", "Per second",
                                "Damage and healing as amounts per second instead of totals. The /s button switches "
                                .. "this too.")),
                    },
                },
                {
                    id = "loot", name = "Loot", intro = "Shared by every profile.",
                    master = Needs("side", Check("sideLoot", "Loot tab",
                        "What your group looted, boss by boss, with who won each roll. Not the chat's loot lines: "
                        .. "the chat keeps those.")),
                    groups = {
                        Group("Lists",
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
            },
        },
        {
            id = "bags", name = "Bags", intro = "Shared by every profile.",
            master = Check("bags", "Bags window",
                "Your backpack, bags and reagent bag in one window, with a search, the game's sort and the items "
                .. "in groups if you like. Untick it to keep the game's bags, or to use "
                .. "a bag addon.", true),
            groups = {
                Group("Window",
                    Choice("bagsView", "Show", {
                        { "bags", "Bags", "Each bag on rows of its own, under its name." },
                        { "grid", "Grid", "Every slot, bag by bag, the reagent bag on rows of its own." },
                        { "groups", "Groups", "The items in groups: new, equipment, consumables, quest items, trade "
                            .. "goods, other and junk, with one slot for the free ones." },
                    }, "The window's Bags, Grid and Groups buttons switch this too. Kept across reloads."),
                    Check("bagsItemLevel", "Item levels",
                        "The item level in the corner of each weapon and piece of armour, in its quality's colour.")),
            },
        },
        {
            id = "bank", name = "Bank", intro = "Forever only. Shared by every profile.",
            master = Check("bank", "Bank window",
                "The bank in a window of Medalluin's own, standing on the chat panel or, detached, wherever you "
                .. "drag it: the same views and search as the bags window, the game's sort, and the bank's bag "
                .. "slots and their purchase below. Untick it to keep the game's bank.", true),
            groups = {
                Group("Window",
                    Choice("bankView", "Show", {
                        { "bags", "Bags", "Each bank bag on rows of its own, under its name." },
                        { "grid", "Grid", "Every slot, bag by bag." },
                        { "groups", "Groups", "The items in groups: new, equipment, consumables, quest items, trade "
                            .. "goods, other and junk, with one slot for the free ones." },
                    }, "The window's Bags, Grid and Groups buttons switch this too. Kept across reloads."),
                    Check("bankDetails", "Details",
                        "The bank's bag slots and the next one's price, under the slots. The window's arrow folds "
                        .. "them too.")),
            },
        },
        {
            id = "character", name = "Character", intro = "Shared by every profile.",
            master = Check("character", "Character window",
                "Your character, reputations and currencies (and on Forever your skills, PvP rank and statistics) in "
                .. "one window standing on the chat panel, with the gear down both sides of your model and the stats "
                .. "under it. Untick it to keep the game's window.", true),
            groups = {
                Group("Window",
                    Check("characterDetails", "Details",
                        "The lower part of each page: the stats, a reputation's or currency's details, and the rest. "
                        .. "The window's arrow folds it too.")),
            },
        },
        {
            id = "spellbook", name = "Spellbook", intro = "Forever only. Shared by every profile.",
            master = Check("spellbook", "Spellbook window",
                "Your spells, a tab for General and each specialisation (and your pet's), in one window standing "
                .. "on the side panel. Cast and drag them out of combat; in combat it reads. Untick it to keep the "
                .. "game's spellbook.", true),
            groups = {
                Group("Window",
                    Check("spellbookDetails", "Details",
                        "The chosen spell's rank and description, under the spells. The window's arrow folds it too.")),
                Group("Spells",
                    Check("spellbookAllRanks", "Every rank",
                        "List each rank of a spell. Unticked, a spell is listed once, at its highest rank learned, "
                        .. "and its details name the others."),
                    Check("spellbookMissing", "Mark spells not on a bar",
                        "A red edge on a spell that is on none of your action bars, nor in a macro on one. Its "
                        .. "tooltip says so, or names the lower rank that is."),
                    Check("spellbookUpRankAll", "Keep every spell on its highest rank",
                        "As you learn a rank, a lower rank of it on your action bars is swapped for it, out of "
                        .. "combat. Unticked, only the spells whose details have it ticked.")),
            },
        },
        {
            id = "talents", name = "Talents", intro = "Forever only. Shared by every profile.",
            master = Check("talents", "Talents window",
                "Your talents, a tab for each tree, in one window standing on the side panel. Spend points, then "
                .. "Apply; switch between your Primary and Secondary talents in its margin. Plans, there, "
                .. "draws and keeps the orders to learn them in. In combat it reads. Untick it to keep the game's "
                .. "talents.", true),
            groups = {},
        },
        {
            id = "professions", name = "Professions", intro = "Forever only. Shared by every profile.",
            master = Check("professions", "Professions window",
                "Your professions in one window standing on the side panel: an overview, and a tab for each "
                .. "profession that crafts, with its recipes and Create. Crafting and the overview's spells work "
                .. "out of combat. Untick it to keep the game's professions.", true),
            groups = {},
        },
        {
            id = "quests", name = "Quests", intro = "Shared by every profile.",
            master = Check("quests", "Quest tracker",
                "Your tracked quests on the left of the screen: by zone, each zone folding, with a button for a "
                .. "quest's item. Reads Questie's tracked quests when Questie is loaded; "
                .. "Questie's own tracker is left to Questie's options.", true),
            groups = {
                Group("Tracker",
                    Choice("questsView", "View", {
                        { "full", "Full", "The character window's place, on the strip up to the screen's top, "
                            .. "fading to a tenth at the right, over the chat." },
                        { "minimal", "Minimal", "A box of its own: drag its heading, size it by its corner, "
                            .. "Ctrl-wheel over its heading to scale it." },
                    }, "How the tracker stands. Its own button changes it too."),
                    Choice("questsSort", "Sort", {
                        { "level", "Level", "The lowest quests first, and the zones by their lowest quest." },
                        { "zone", "Zone", "The zone you are in first, then the rest by name." },
                    }, "How the quests are ordered. The tracker's own button changes it too."),
                    Button("Reset the minimal view", function() ns.SetOption("questsPlace", false) end,
                        "The minimal view back to the top left, at its first size and scale.")),
                Group("Text",
                    Choice("questsTree", "Objectives", {
                        { false, "Bullets", "Each objective under its quest, bulleted, in the quest log's order." },
                        { true, "Tree", "On the branches of a tree, the finished ones risen to the top and "
                            .. "dimmed, what is left at the foot." },
                    }, "How a quest's objectives are drawn under it."),
                    FontChoice("questsTitleFont", "Title font", "The quests' titles. Fonts other addons share "
                        .. "(LibSharedMedia) are listed too."),
                    Points("questsTitleSize", "Title size", "The quests' titles, and their marks with them."),
                    FontChoice("questsObjectiveFont", "Objective font", "The objectives under each quest."),
                    Points("questsObjectiveSize", "Objective size", "The objectives under each quest. Every row "
                        .. "is as tall as the larger of the two sizes needs.")),
                Group("Full view", Check("questsFullMouseover", "Only on mouseover",
                        "Hidden until the pointer is over the tracker's column."),
                    Check("questsFullCombat", "Hidden in combat",
                        "Gone in combat, items too, and clicks go through to what is behind it.")),
                Group("Minimal view", Check("questsMinimalMouseover", "Only on mouseover",
                        "Hidden until the pointer is over the box."),
                    Check("questsMinimalCombat", "Hidden in combat",
                        "Gone in combat, items too, and clicks go through to what is behind it.")),
            },
        },
        {
            id = "questlog", name = "Quest log", intro = "Shared by every profile.",
            master = Check("questLog", "Quest log",
                "Every quest in your log in a window on the right strip, as the spellbook's: by zone, each with its "
                .. "level, experience, coin and whether it gives an item; a zone's eye tracks or stops "
                .. "tracking all its quests, Drop abandons the quests you tick, and a quest opens its own page. "
                .. "It opens on the quest log key and the Quests button, and the map no longer shows the "
                .. "game's quest log. Untick it to keep the game's.", true),
            groups = {},
        },
        {
            id = "lfg", name = "Group finder", intro = "Shared by every profile.",
            master = Check("lfgWindow", "Looking for group and Who",
                "The groups listed, your own listing and Who in one box standing on the chat box, where the quest "
                .. "tracker stands (it steps aside while the box is open): Browse shows each group's activity, "
                .. "leader, note, the roles it needs, its size and age, and a click opens its members with "
                .. "Whisper and Ask to join; List me lists you as the roles you pick, for the activities you tick, "
                .. "with a note; Who asks who is online, with your zone, your level and your guild a click away. "
                .. "It opens on the game's LFG button and key, and on the Friends window's Who tab. Forever's "
                .. "group finder only: on retail the game's stays, and the box has Who alone. Untick it to keep "
                .. "the game's.", true),
            groups = {},
        },
        {
            id = "cdm", name = "Cooldown Manager", intro = "Shared by every profile.",
            master = Check("cdmWindow", "Cooldown Manager window",
                "The game's Cooldown Manager (/cdm, Edit Mode's Cooldown Settings) in Medalluin's dress, standing "
                .. "on the chat box where the LFG window stands: its tabs across the top, its spells as round "
                .. "medallions. Everything in it is still the game's own: dragging spells between Essential, "
                .. "Utility and Not displayed, their order, the alerts on a right-click, the layouts per spec, "
                .. "import and export. It and the LFG window close each other. Untick it to keep the game's look.",
                true),
            groups = {
                Group("Display", Check("cdmDisplay", "Cooldowns over the console",
                    "The game's cooldown and buff icons as medallions in rows over the console: the tracked "
                    .. "buffs on top, Essential under them, Utility smaller at its right, their sweeps round. "
                    .. "Edit Mode moving them is undone out of combat. The tracked bars stay in the Auras tab. "
                    .. "Untick it for the game's icons in their Edit Mode places.", true)),
            },
        },
        {
            id = "npc", name = "Gossip and vendors", intro = "Shared by every profile.",
            master = Needs("chat", Check("npcWindows", "Gossip, quest, vendor, trainer, flight and mailbox windows",
                "What an NPC says, its quest pages, its wares and what it teaches in one box standing on the chat "
                .. "box, where the quest tracker stands (it steps aside while the box is open). A vendor's tabs "
                .. "show its wares and what you sold it, with buttons to repair and to sell your grey items; a "
                .. "trainer's tabs show what you can learn now, what you cannot yet, or what you know; the flight "
                .. "map stands there bare, with the places you can fly to under it (Forever's map: retail's "
                .. "other one stays the game's); the mailbox's tabs show your letters, with Open all, and a "
                .. "letter to send, the names you write to offered as you type. Needs the chat "
                .. "box. Untick it to keep the game's windows, or to use an addon for them.", true)),
            groups = {
                Group("Keys", Check("npcSpace", "Spacebar accepts quests",
                    "Space presses a quest's Accept, Continue or Complete Quest while its page is open, instead "
                    .. "of jumping. A gossip window's choices are numbered either way: the keys 1 to 0, - and = "
                    .. "pick them, and the action bar buttons on those keys wait until it closes.")),
            },
        },
        {
            id = "tooltips", name = "Tooltips (ext)",
            intro = "Provided by the optional mdlui_Tooltips companion addon. "
                .. "Enable mdlui_Tooltips in your AddOns list to reskin tooltips "
                .. "and open its style editor and options.",
            enabled = function() return SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS ~= nil end,
            groups = {
                Group("mdlui_Tooltips",
                    Button("Open style editor", function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("")
                        end
                    end, "Closes this window and opens mdlui_Tooltips' live style editor (/mdltip)."),
                    Button("Tooltip options", function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("options")
                        end
                    end, "Closes this window and opens mdlui_Tooltips' options in the game's AddOns settings "
                        .. "(/mdltip options).")),
            },
        },
    }
end
