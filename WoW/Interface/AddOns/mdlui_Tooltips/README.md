# mdlui_Tooltips

> **An ornamented tooltip reskin and companion addon for [Medalluin](../../../../README.md), supporting both WoW Forever (`16001`) and Retail WoW (`120105`).**
>
> Based on [PrettyTooltip](https://github.com/FallenShard/PrettyTooltip) by **FallenShard**, distributed under the [MIT License](LICENSE).

`mdlui_Tooltips` replaces the game's tooltip with a compact, ornamented panel: the icon and name up front, the details in short colored rows grouped by kind, and the fine print gathered in a footer. Hold **ALT** (or the key you choose) at any time to see the game's own tooltip.

---

## ✨ What `mdlui_Tooltips` Adds Over Upstream

- **Medalluin Integration**: Categorized under **Medalluin** in the game's AddOn List and directly accessible from Medalluin's **Tooltips (ext)** settings page (`/mdlui`). Works both alongside Medalluin and standalone.
- **Retail WoW (`12.5` / `120105`) Support**:
  - Parses modern secondary and tertiary stats (**Mastery**, **Versatility**, **Speed**, **Avoidance**, **Leech**).
  - Supports modern class resources (**Fury**, **Pain**, **Astral Power**, **Insanity**, **Maelstrom**, **Essence**, **Holy Power**, **Soul Shards**, **Arcane Charges**, **Chi**).
  - Recognizes **Warbound** / **Warband** and **Accountbound** bindings, passing unrecognized Retail item lines cleanly to the footer/extras block.
  - Guards Classic-only static lookup tables (disenchant tables, spell coefficients, and Classic herb/ore/skinning drop tables) on Retail clients.
  - Protects native tooltip parking and unparking during combat lockdown (`InCombatLockdown()`) to prevent secret-value taint on Retail 12.x.

---

## Item tooltips

Top to bottom, an item panel shows:

- **Header.** The icon with an item level badge, the name in its quality color, and a subtitle with the item's type and slot, such as `Mail · Head` or `Staff · Two-Hand`. The subtitle also names what the game leaves unsaid: `Consumable · Potion`, `Crafting Reagent`, `Scarce`. The binding sits below it, with the required level at the right, red while you are below it. The whole panel is tinted by quality; quest items, and items that begin a quest, are tinted quest gold.
- **Weapon damage.** DPS as the prominent row, with damage and speed beneath it.
- **Armor and stats.** Armor, then the stats in two blocks: the primary attributes, and everything else under a divider. Long stat wording is shortened (see below), and each stat is colored by kind.
- **Equip effects and enchants.** Equip effects that are not a plain stat, such as a zone-limited speed bonus, join the stat list in green without the `Equip:` prefix. A chance on hit joins them too, marked with a small sword instead of its `Chance on hit:` prefix. Its numbers follow the spell tooltip's highlighting: a lighter school color when the description names that school's damage, or a neutral highlight otherwise. Holyfire blends Holy and Fire. These highlights follow **Stat colors** and a custom **Equip effects** color in the panel. Enchants follow as green rows marked with a sparkle, one per bonus: `Enchanted: Stamina +1 and Armor +8` becomes `+1 Stamina` and `+8 Armor`.
- **Use effects and flavor text,** as the game words them, each use effect marked with a small gear instead of its `Use:` prefix.
- **Item set.** The set name and how many pieces you own, the pieces you own highlighted, and the set bonuses, with active ones highlighted.
- **Disenchant (WoW Forever).** For green, blue, and purple armor and weapons on Classic/Forever clients: what the item disenchants into, each result with its icon, count, and chance, and the Enchanting it needs, red while your skill is too low and grey if you have no Enchanting. The chances are Classic's published tables (Warcraft Wiki's *Disenchanting tables*); the game has no way to ask. Turned off under **Item Details** in the style editor.
- **Footer.** Durability as a small bar, the crafter's name for crafted items, other requirements such as skills or classes, and the sell price as coins alone; a stack shows its total first, then the count and one item's price, dimmed (`2g  (20 × 10s)`), which can be turned off under **Item Details** in the style editor.

While the game shows a comparison, the comparison panels are tagged **Equipped**, and the game's own "If you replace this item" stat changes appear among the rows at the bottom, in their usual green and red.

Recipes are the recipe first: their own icon and name, `Plans · Blacksmithing` beneath, and the skill they need beside the binding, red while yours is too low. The item they craft follows under **Creates** as a smaller card with its icon, name, slot, required level, and its own armor, stats, and effects, then the **Reagents** with their icons and how many you carry (`4 / 10`, red while short).

### Shorter stats

Common Equip wordings become short stat rows:

| The game says | mdlui_Tooltips shows |
| --- | --- |
| Equip: Increases healing done by up to 48 and damage done by up to 16 for all magical spells and effects. | +48 Healing Power<br>+16 Spell Damage Power |
| Equip: Increases damage and healing done by magical spells and effects by up to 12. | +12 Spell Power |
| Equip: Increases damage done by Fire spells and effects by up to 20. | +20 Fire Spell Damage Power |
| Equip: Improves your chance to get a critical strike by 1%. | +1% Critical Strike Chance |
| Equip: Increased Defense +2. | +2 Defense Skill |
| Equip: Restores 3 mana per 5 sec. | +3 Mana per 5 sec |

**Spell Power** is a bonus to both damage and healing; **Spell Damage Power** is damage only. Hit, crit, haste, mastery, versatility, dodge, parry, block, ratings, attack power, tertiary stats (speed, avoidance, leech), health regeneration, and spell penetration are shortened the same way. Wording `mdlui_Tooltips` does not recognize is shown as the game writes it.

### The Blizzard layout

With **Layout Style** set to **Blizzard** on the options page, every tooltip keeps the game's own look, and so does each kind whose **Restyle** box is off. Items keep the game's tooltip with selected Equip effects shortened as in the table above and the game's line colors kept, except for magic: spell power, spell hit and crit, penetration, and healing power in their stat colors, and the damage of chance on hit effects in its school's color, while **Stat colors** is on. Combined bonuses split into separate lines. **Abbreviated Equip Effects** under **Item Details** in the style editor turns this off.

While the **Tooltip Details Modifier** is held (Shift by default), the details a panel would show appear at the bottom of the game's tooltip, below every other addon's rows: disenchant results, the spell power breakdown and rates, gathering contents, and IDs, each as its switch in the style editor allows. They show and hide as the key is pressed and released, in combat too. Holding the **Default Tooltip Modifier** shows the game's tooltip as it is, with neither.

### Colors

Each stat value takes a color and its name a lighter shade of the same hue. The category colors are soft and evenly light, so every kind of stat reads alike on the dark panel, and the vivid spell school colors stand apart from them:

| Category | Color |
| --- | --- |
| Primary attributes | Ivory |
| Attack: attack power, hit, crit, haste, mastery, versatility | Amber |
| Defense: defense, dodge, parry, block, avoidance | Steel blue |
| Magic: spell power, spell hit and crit, penetration | Lavender |
| Healing: healing power, leech | Mint |
| Mana regeneration & speed | Periwinkle |
| Spell schools and resistances | Arcane, Fire, Frost, Holy, Nature, and Shadow each in their own color |

Set **School colors** under **All Tooltips** in the style editor. The same choices color spell panels, school badges, highlighted numbers, item spell-power and resistance stats, school weapon damage, and macro accents. Holyfire and Frostfire have their own swatches; their panel gradients follow their two component schools. Click a swatch to choose its color, right-click it for the default, or use the row's reset to restore every school. With no overrides, the original colors are kept.

Turn on **Armor colors** under **Item Details** to tell armor types apart at a glance: the type that leads the subtitle, as *Plate* in *Plate · Chest*, takes its own color (cloth rose, leather tan, mail teal, plate steel), and the rest of the line keeps the quality color. A type the game shows in red, because you cannot wear it, stays red. Cloaks are left alone, since every class wears them. Each type has a swatch below the switch; the switch is off by default.

## Spell tooltips

Spells use the same panel: the icon and name, small badges for the spell's school, its rank, and **Passive** for passive spells and talents, and a strip with cost, cast time, cooldown, and range. The description follows one sentence per line, with its numbers highlighted.

The panel is tinted by the spell's school: a class spell's comes from WoW Forever's client spell data, which the addon carries, and any other spell's is read from the damage its description names (`Fire damage`) or a school that starts its name (`Holy Light`). Spells with neither are tinted by the resource they cost.

A spell that carries another spell inside its tooltip, such as Feral Charge with its Cat Form version, shows the inner spell as a second section with its own name, strip, requirements, and description. Talents get the spell panel too.

On **WoW Forever (`16001`)**, spells that deal magic damage or heal show their spell power under the description: each amount's coefficient, one row for what lands at once and one for what comes over time, and the amount split into its base and what your spell power adds, as `Healing Power Coefficient` and `85.7% · 441 to 595 + 120`, the coefficient in the spell school's color. Turned off under **Spell Details** in the style editor.

## Players and NPCs

Units under the cursor get a panel with their portrait, the name in class color (players) or reaction color (NPCs: red hostile, yellow neutral, green friendly, grey when tapped by someone else), the guild or an NPC's role, and the level, race, and class or creature type, the level in its difficulty color. Badges mark elites, rares, bosses, a player's faction, PvP, AFK, DND, and the dead. Below sit what the unit is targeting (in red when it is you), and the unit's quest lines. Rows other addons add are kept below, and the game's own health bar closes the panel. Elites, rares, rare elites, and bosses show the dragon from the game's target frame behind the header, and players their faction's crest.

**Class colors** under **Unit Details** in the style editor has a swatch for each class. Overrides apply to player names, panel tints and glows, the guild's lighter shade, player targets, and players on the minimap. Click to choose a color, right-click for the default, or reset the row to clear all class overrides. With no override, the game's current class color is used, including changes made by other addons.

## Buffs and debuffs

Auras show their icon and name, badges for buff or debuff, the dispel type in the game's colors (Magic, Curse, Disease, Poison), and stacks, then the description one sentence per line, the time left with who cast it, and a bar that drains as the aura runs out.

## Quests

With **DialogueUI** installed, enable **Quest parchment** under **Quest Details** or **Item Details** in the style editor for its brown parchment and darker ink. The shared toggle applies to quest tooltips, items marked **Quest Item**, and items that begin a quest; the **Quest item** sample on the Items tab previews it. It is off by default. Per-part custom text colors still take precedence, and the artwork is read from DialogueUI's folder.

Quest links read like a page of the quest log: the quest's name and the dungeon it is in, then badges for its level in the game's difficulty color, tags such as Elite or Dungeon, and where it stands (in progress, ready to turn in, completed, failed, repeatable). Below sit the quest giver's words in quotes and the objectives as a checklist with their progress, ticked and green once finished. The header has no icon unless **Show icon** is turned on in the style editor. With **Questie** installed, which draws quest links itself, the panel is built from Questie's tooltip, both for a clicked link and for one hovered in chat; who starts or ends the quest and where follow as label and value rows. Quests hovered in the world map's quest log get the same panel, with the level from your quest log; rows other addons add, such as a guide's note, are kept below.

## Mail

Mail attachment summaries have their own **Mail** category and style-editor preview. They show item icons, quality-colored names and quantities, with Auctionator's price rows beneath each attachment and its total in the footer. Individual attachments retain their normal item tooltips. Turn off **Mail** under Restyle to keep the native summary.

## World objects

Herbs, ore, chests, and quest objects get a panel too. On **WoW Forever**, a Classic herb or ore node shows the herb or ore it yields, with its icon; the skill it needs and the level, in the game's skill-up color (red while your skill is too low), beside your own skill; and in the footer the yield's sell price and, with **Auctionator** installed, its auction price. Locked chests show the lock and the Lockpicking they need, and quest objects show their quests and objectives. Rows other addons add, such as Questie's, are kept below.

## Working with other addons

- Rows other addons add to a tooltip are kept, below a thin rule in smaller, muted text, in their original order and colors.
- Comparison tooltips, screen-edge clamping, and anything anchored to the tooltip follow the panel's real size.
- With **DialogueUI** installed, the panel uses its dark tooltip backdrop, unless another **Panel style** is picked in the style editor. Text uses the game's own tooltip fonts, so a UI addon that changes the default font is followed; with **EllesmereUI** installed, names use its Expressway font. Both are used from those addons' own folders; nothing of theirs is bundled.
- Whenever a tooltip cannot be read safely, such as spell details or secret values restricted during combat, the game's own tooltip is shown instead.

## Style editor & Options

Type `/mdltip` (or `/mdltooltips`), open **Medalluin** (`/mdlui` -> **Tooltips (ext)**), or open the game's options under **AddOns > mdlui_Tooltips** (`/mdltip options`).

- **Style Editor (`/mdltip`)**: Switch between **Items**, **Spells**, **Objects**, **Units**, **Buffs**, and **Quests**. Click any part of the live sample tooltip to customize its font, size, color, and outline, or adjust **Global scale** (50%–150%), **Panel style**, **School colors**, and per-category details.
- **Options (`/mdltip options`)**: Choose **Layout Style** (`mdlui_Tooltips` or `Blizzard`), toggle **Restyle** and **Follow cursor** per tooltip category, and set the **Default Tooltip Modifier** (`ALT`, `CTRL`, or `Never`).

## Install

1. Download the `mdlui_Tooltips` release zip and extract `mdlui_Tooltips` into your World of Warcraft `Interface\AddOns` folder.
2. In the character select **AddOns** list, find **mdlui_Tooltips** under the **Medalluin** category and make sure it is enabled.

## Compatibility

- **WoW Forever 1.60.1** (`## Interface: 16001`)
- **Retail WoW 12.5** (`## Interface: 120105`)
- Supports English, German, French, Spanish (Spain and Latin America), Portuguese, Korean, Simplified Chinese, Traditional Chinese, and Russian clients.

## Known limitations

- No game API names a spell's school. Class spells take theirs from the client data the addon carries; any other spell's is read from its text, so one that never names its damage type may get no school, or the wrong one if its name starts with one.
- Spell power coefficients are not read from the game. Those marked `~` are estimates, and a talent or effect that changes a spell's damage or healing makes its base off by that much.
- Profession recipe spells do not show the crafted item as an item panel.
- Herb and ore nodes show their yield, skill level, and prices only for the classic herbs and ores; other nodes show their skill alone.
- Stat wordings not in the table above are shown unchanged.

## Bug reports

- `/mdltip dump` shows the raw data of the tooltip you are hovering, or of a link clicked in chat.
- `/mdltip trace [seconds]` records tooltip states and calls for 1–10 seconds (4 by default).
- `/mdltip perf [seconds]` measures how often the panel's work runs and how long it takes.
- `/mdltip anchors` and `/mdltip pixel` show where each panel sits and how its lines snap to screen pixels.
- `/mdltip capture <name>` saves the hovered tooltip as a test fixture (`capture list`, `capture clear`).

Each report opens in a window with its findings selected, under a line naming the addon's version, the client build, and the locale: Ctrl+C copies them, and Escape closes the window.

---

## 📜 Credits & License

`mdlui_Tooltips` is licensed under the **[MIT License](LICENSE)**.

- **Original Addon**: [PrettyTooltip](https://github.com/FallenShard/PrettyTooltip) — Copyright © 2026 **FallenShard**
- **Medalluin Companion Adaptation & Retail Port**: **AhryMX** ([Medalluin](https://github.com/ahrymx/ahrymx.medalluin))
