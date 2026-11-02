-- Each profile's own skills on the bars, per character: switching profile
-- puts the other profile's skills back, so a layout for questing and one for
-- dungeons need not share a slot. Every action slot switches, pages 1 to 15
-- (slots 1..180): the bars, the form and stealth pages, skyriding's, and
-- bars 6 to 8. The vehicle, possess and override pages are the game's.
--
-- Kept in MedalluinCharDB (per character), per profile and per spec (the game
-- keeps bars per spec where there are specs): each slot's action as the game
-- names it (GetActionInfo), a macro by its name, as its index moves whenever
-- a macro is made or removed. Saved at a switch, before the other profile's
-- come back, and at logout; never laid out at login, as the bars the game
-- kept are that profile's already. A profile with nothing saved for the spec
-- takes the bars as they are, the first time.
--
-- An action goes in by the cursor (pick it up, place it), which the game
-- allows only out of combat, so a switch in combat waits for it to end. What
-- cannot be picked up again (an item no longer in the bags, a macro since
-- removed, a spell no longer known) leaves its slot empty, and is kept for
-- the profile until the slot is used for something else; a kind of action
-- Medalluin does not know is left where it is.
local addonName, ns = ...

local SLOTS = 180
local RANDOM_MOUNT = 268435455   -- GetActionInfo's mount id for "Summon Random Favorite Mount"

local function Say(text) print("|cffe0b84aMedalluin|r: " .. text) end

local function Spec()
    local n = GetSpecialization and GetSpecialization()
        or C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
        and C_SpecializationInfo.GetActiveSpecGroup()
        or GetActiveTalentGroup and GetActiveTalentGroup()
    return tostring(n or 1)
end

-- The saved bars of a profile on this spec, made when asked to.
local function Saved(profile, make)
    local db = MedalluinCharDB
    local spec = Spec()
    if make then
        db.layouts[profile] = db.layouts[profile] or {}
        db.layouts[profile][spec] = db.layouts[profile][spec] or {}
    end
    return db.layouts[profile] and db.layouts[profile][spec]
end

-- A slot's action as it is saved: { type, id }, or nil when empty.
local function Read(slot)
    local kind, id = GetActionInfo(slot)
    if not kind then return nil end
    if kind == "macro" then
        local name = GetActionText and GetActionText(slot)
        if not name and GetMacroInfo and id then name = GetMacroInfo(id) end
        return name and { kind, name } or nil
    end
    return { kind, id }
end

local function Same(a, b)
    if not a or not b then return a == b end
    return a[1] == b[1] and a[2] == b[2]
end

-- Put an action on the cursor; true when it is there.
local function Mount(id)
    local journal = C_MountJournal
    if not journal then return end
    if id == RANDOM_MOUNT then return journal.Pickup(0) end
    for i = 1, journal.GetNumDisplayedMounts and journal.GetNumDisplayedMounts() or 0 do
        if journal.GetDisplayedMountID(i) == id then return journal.Pickup(i) end
    end
    -- filtered out of the journal's list: the mount's spell is the mount
    local _, spell = journal.GetMountInfoByID(id)
    if spell and C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(spell) end
end

local function Flyout(id)
    local book = C_SpellBook
    if not (book and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType) then return end
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = book.GetSpellBookItemInfo(slot, bank)
            if item and item.itemType == Enum.SpellBookItemType.Flyout and item.actionID == id then
                return book.PickupSpellBookItem(slot, bank)
            end
        end
    end
end

local PICKUP = {
    spell = function(id)
        if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id) elseif PickupSpell then PickupSpell(id) end
    end,
    item = function(id)
        if C_Item and C_Item.PickupItem then C_Item.PickupItem(id) elseif PickupItem then PickupItem(id) end
    end,
    macro = function(name)
        local index = GetMacroIndexByName and GetMacroIndexByName(name)
        if index and index > 0 then PickupMacro(index) end
    end,
    summonmount = Mount,
    summonpet = function(guid)
        if C_PetJournal and C_PetJournal.PickupPet then C_PetJournal.PickupPet(guid) end
    end,
    flyout = Flyout,
    equipmentset = function(name)
        local sets = C_EquipmentSet
        local id = sets and sets.GetEquipmentSetID(name)
        if id then sets.PickupEquipmentSet(id) end
    end,
}

local function Empty(slot)
    if GetActionInfo(slot) then
        PickupAction(slot)
        ClearCursor()
    end
end

-- What could not come back on the bars now, by slot: kept for the profile
-- while its slot stays empty.
local missed = {}

local function Snapshot(profile)
    local saved = Saved(profile, true)
    for slot = 1, SLOTS do
        local now = Read(slot)
        if not now and missed[slot] then now = missed[slot] end
        saved[slot] = now
    end
end

local function Restore(profile)
    wipe(missed)
    local saved = Saved(profile)
    if not saved then return end   -- the first time: the bars as they are
    ClearCursor()
    local lost = 0
    for slot = 1, SLOTS do
        local want, now = saved[slot], Read(slot)
        if not Same(want, now) then
            if not want then
                Empty(slot)
            elseif PICKUP[want[1]] then
                PICKUP[want[1]](want[2])
                if GetCursorInfo() then
                    PlaceAction(slot)
                    ClearCursor()
                else
                    Empty(slot)
                    missed[slot] = want
                    lost = lost + 1
                end
            end
        end
    end
    if lost > 0 then
        Say(("%d %s of the %s profile could not come back (not in your bags, or not known)."):format(
            lost, lost == 1 and "skill" or "skills", profile == "light" and "Central Console" or "Medallion"))
    end
end

-- Called by the profile switch (settings.lua) before the profile changes.
-- A switch in combat waits; switches queued meanwhile run in order, each
-- saving the bars of the one before. Until they run, the bars are still the
-- profile's from before the first of them.
local waiting
function ns.SwitchSkills(from, to)
    if not MedalluinCharDB then return end
    if InCombatLockdown() then
        waiting = waiting or from
        Say("the profile's skills and keys come on the bars when combat ends.")
    end
    ns.OutOfCombat(function()
        waiting = nil
        Snapshot(from)
        Restore(to)
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.layouts = MedalluinCharDB.layouts or {}
end)

-- At logout the bars are the profile's, or, with a switch still waiting for
-- combat to end, the profile's they were before it.
ns.On("PLAYER_LOGOUT", function()
    if MedalluinCharDB and ns.db and ns.db.consoleProfile then Snapshot(waiting or ns.db.consoleProfile) end
end)
