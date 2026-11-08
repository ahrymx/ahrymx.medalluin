-- The gathering nodes of Forever's world (the original continents): each
-- vein and herb, the skill it needs, and the zones it chiefly grows in.
-- The game says none of this, so it is kept here, from the Classic-era
-- record; a zone list names the main places, not every one. Read by the
-- Skills page (character/skills.lua), which lists the nodes of the
-- gathering professions a character knows, and by the profession's own
-- page of the professions window (professions/crafting.lua).
local _, ns = ...

ns.gatheringNodes = {
    -- by the profession's skill line ID, in the order the page lists them
    { skillID = 186, name = "Mining", nodes = {
        { "Copper Vein", 1, "Dun Morogh, Elwynn Forest, Tirisfal Glades, Durotar, Mulgore, Darkshore, Westfall,"
            .. " Loch Modan, Silverpine Forest, The Barrens, Redridge Mountains, Stonetalon Mountains" },
        { "Tin Vein", 65, "Loch Modan, Westfall, Redridge Mountains, Silverpine Forest, Darkshore, The Barrens,"
            .. " Stonetalon Mountains, Ashenvale, Wetlands, Hillsbrad Foothills, Duskwood, Thousand Needles" },
        { "Incendicite Mineral Vein", 65, "Wetlands (Thelgen Rock)" },
        { "Silver Vein", 75, "A rare spawn where tin grows: Redridge Mountains, Duskwood, Wetlands, Hillsbrad"
            .. " Foothills, Ashenvale, Stonetalon Mountains, Thousand Needles, Arathi Highlands, Stranglethorn Vale" },
        { "Lesser Bloodstone Deposit", 75, "Arathi Highlands" },
        { "Iron Deposit", 125, "Arathi Highlands, Alterac Mountains, Stranglethorn Vale, Badlands, Swamp of Sorrows,"
            .. " Desolace, Thousand Needles, Dustwallow Marsh, Feralas, Tanaris" },
        { "Indurium Mineral Vein", 150, "Uldaman (Badlands)" },
        { "Gold Vein", 155, "A rare spawn where iron and mithril grow: Arathi Highlands, Stranglethorn Vale,"
            .. " Badlands, Desolace, Dustwallow Marsh, Feralas, Tanaris, The Hinterlands, Searing Gorge" },
        { "Mithril Deposit", 175, "The Hinterlands, Searing Gorge, Badlands, Stranglethorn Vale, Tanaris, Feralas,"
            .. " Azshara, Felwood, Un'Goro Crater, Burning Steppes, Blasted Lands, Western Plaguelands" },
        { "Truesilver Deposit", 230, "A rare spawn where mithril grows: The Hinterlands, Searing Gorge, Tanaris,"
            .. " Feralas, Azshara, Felwood, Un'Goro Crater, Burning Steppes, Blasted Lands, Western Plaguelands" },
        { "Dark Iron Deposit", 230, "Searing Gorge, Burning Steppes, Blackrock Depths, Molten Core" },
        { "Small Thorium Vein", 245, "Un'Goro Crater, Burning Steppes, Felwood, Azshara, Winterspring, Silithus,"
            .. " Western Plaguelands, Eastern Plaguelands, Blasted Lands, Tanaris, The Hinterlands, Feralas" },
        { "Rich Thorium Vein", 275, "Un'Goro Crater, Silithus, Winterspring, Eastern Plaguelands, Burning Steppes,"
            .. " Azshara" },
    } },
    { skillID = 182, name = "Herbalism", nodes = {
        { "Peacebloom", 1, "Elwynn Forest, Dun Morogh, Tirisfal Glades, Durotar, Mulgore, Teldrassil, Westfall,"
            .. " Loch Modan, Silverpine Forest, The Barrens, Darkshore" },
        { "Silverleaf", 1, "Elwynn Forest, Dun Morogh, Tirisfal Glades, Durotar, Mulgore, Teldrassil, Westfall,"
            .. " Loch Modan, Silverpine Forest, The Barrens, Darkshore, Redridge Mountains" },
        { "Earthroot", 15, "Elwynn Forest, Dun Morogh, Tirisfal Glades, Durotar, Mulgore, Teldrassil, Westfall,"
            .. " Loch Modan, Silverpine Forest, The Barrens, Darkshore, Redridge Mountains" },
        { "Mageroyal", 50, "Westfall, Loch Modan, Silverpine Forest, The Barrens, Darkshore, Redridge Mountains,"
            .. " Duskwood, Wetlands, Hillsbrad Foothills, Stonetalon Mountains, Ashenvale" },
        { "Briarthorn", 70, "Westfall, Loch Modan, Silverpine Forest, The Barrens, Darkshore, Redridge Mountains,"
            .. " Duskwood, Wetlands, Hillsbrad Foothills, Stonetalon Mountains, Ashenvale" },
        { "Stranglekelp", 85, "Under the sea along the coasts: Westfall, Silverpine Forest, Wetlands, Hillsbrad"
            .. " Foothills, Stranglethorn Vale, Darkshore, The Barrens, Desolace, Dustwallow Marsh, Feralas" },
        { "Bruiseweed", 100, "Redridge Mountains, Duskwood, Wetlands, Hillsbrad Foothills, Arathi Highlands,"
            .. " Stranglethorn Vale, The Barrens, Stonetalon Mountains, Ashenvale, Thousand Needles, Desolace" },
        { "Wild Steelbloom", 115, "Hillsbrad Foothills, Arathi Highlands, Alterac Mountains, Stranglethorn Vale,"
            .. " Badlands, Duskwood, Stonetalon Mountains, Ashenvale, Thousand Needles, Desolace" },
        { "Grave Moss", 120, "By graves and bones: Duskwood, Wetlands, Arathi Highlands, Desolace" },
        { "Kingsblood", 125, "Hillsbrad Foothills, Arathi Highlands, Alterac Mountains, Stranglethorn Vale,"
            .. " Wetlands, Duskwood, Swamp of Sorrows, Ashenvale, Thousand Needles, Desolace, Dustwallow Marsh" },
        { "Liferoot", 150, "By water: Arathi Highlands, Stranglethorn Vale, Swamp of Sorrows, The Hinterlands,"
            .. " Western Plaguelands, Wetlands, Ashenvale, Dustwallow Marsh, Feralas" },
        { "Fadeleaf", 160, "Arathi Highlands, Alterac Mountains, Stranglethorn Vale, Swamp of Sorrows, Badlands,"
            .. " Dustwallow Marsh" },
        { "Goldthorn", 170, "Arathi Highlands, Alterac Mountains, Stranglethorn Vale, Swamp of Sorrows,"
            .. " The Hinterlands, Badlands, Dustwallow Marsh, Feralas, Azshara" },
        { "Khadgar's Whisker", 185, "Arathi Highlands, Alterac Mountains, Stranglethorn Vale, Swamp of Sorrows,"
            .. " The Hinterlands, Badlands, Dustwallow Marsh, Feralas, Azshara" },
        { "Wintersbite", 195, "Alterac Mountains" },
        { "Firebloom", 205, "Searing Gorge, Badlands, Blasted Lands, Tanaris" },
        { "Purple Lotus", 210, "Stranglethorn Vale, The Hinterlands, Badlands, Ashenvale, Feralas, Tanaris,"
            .. " Azshara, Felwood" },
        { "Arthas' Tears", 220, "Western Plaguelands, Eastern Plaguelands, Felwood" },
        { "Sungrass", 230, "The Hinterlands, Feralas, Azshara, Felwood, Un'Goro Crater, Silithus, Blasted Lands,"
            .. " Burning Steppes, Western Plaguelands, Eastern Plaguelands" },
        { "Blindweed", 235, "Swamp of Sorrows, Un'Goro Crater" },
        { "Ghost Mushroom", 245, "In caves: The Hinterlands, Maraudon" },
        { "Gromsblood", 250, "Where demons are: Felwood, Ashenvale, Desolace, Blasted Lands" },
        { "Golden Sansam", 260, "Feralas, Azshara, Un'Goro Crater, Felwood, Burning Steppes, Eastern Plaguelands,"
            .. " Silithus" },
        { "Dreamfoil", 270, "Un'Goro Crater, Felwood, Azshara, Silithus, Burning Steppes, Eastern Plaguelands" },
        { "Mountain Silversage", 280, "Winterspring, Azshara, Silithus, Un'Goro Crater, Felwood, Burning Steppes,"
            .. " Eastern Plaguelands" },
        { "Plaguebloom", 285, "Western Plaguelands, Eastern Plaguelands, Felwood" },
        { "Icecap", 290, "Winterspring" },
        { "Black Lotus", 300, "A rare spawn: Burning Steppes, Eastern Plaguelands, Silithus, Winterspring" },
    } },
}

-- A node by the chance it gives a skill point, as the game colours a
-- recipe: red out of reach, orange always, yellow mostly, green now and
-- then, grey never.
local BANDS = {
    { 25, { 1, 0.5, 0.25 }, "A skill point at every gathering." },
    { 50, { 1, 1, 0 }, "A skill point most times." },
    { 100, { 0.25, 0.75, 0.25 }, "A skill point now and then." },
}
function ns.GatheringChance(rank, need)
    if rank < need then
        return { 1, 0.1, 0.1 }, format("Out of reach: %d more skill.", need - rank)
    end
    for _, b in ipairs(BANDS) do
        if rank < need + b[1] then return b[2], b[3] end
    end
    return { 0.5, 0.5, 0.5 }, "No more skill from it."
end
