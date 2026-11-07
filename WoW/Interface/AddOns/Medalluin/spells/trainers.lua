-- What trainers teach, remembered: each trainer's whole list read as you
-- visit it, kept per character (MedalluinCharDB.trainer), for the
-- spellbook's Trainer tab and a profession's recipes still to learn. No
-- list ships with Medalluin: the game's own trainers fill it.
--
--   class   { name, rank, icon, level, cost, known } by "name|rank": every
--           trainer that is not a profession's (the class's, a weapon
--           master's), merged, never forgotten
--   trade   [profession] { ... skill, skillRank }: a profession trainer's,
--           by the skill line each service belongs to
--
-- Read as the game sends the list: on TRAINER_SHOW (often still empty)
-- and each TRAINER_UPDATE after. It lists the types its filter lets
-- through; the NPC box keeps all three on (npc/trainer.lua), Blizzard's own
-- window those its checkboxes ask for. The filter is never changed here: it
-- answers late, with a TRAINER_UPDATE, not as it is called.
local _, ns = ...

ns.trainers = {}

local function Store()
    MedalluinCharDB = MedalluinCharDB or {}
    local t = MedalluinCharDB.trainer
    if type(t) ~= "table" then
        t = { class = {}, trade = {} }
        MedalluinCharDB.trainer = t
    end
    t.class, t.trade = t.class or {}, t.trade or {}
    return t
end

local function Key(name, rank) return name .. "|" .. (rank or "") end

-- every service the trainer lists, merged into what was kept
local function Read()
    if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
    local trade = IsTradeskillTrainer and IsTradeskillTrainer()
    local store = Store()
    for i = 1, GetNumTrainerServices() do
        local name, kind, icon, level, rank = GetTrainerServiceInfo(i)
        if name and kind then
            rank = rank ~= "" and rank or nil
            local e = { name = name, rank = rank, icon = icon, level = level or 0,
                cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0, known = kind == "used" }
            local list = store.class
            if trade then
                local line = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
                if line and line ~= "" then
                    store.trade[line] = store.trade[line] or {}
                    list = store.trade[line]
                    if GetTrainerServiceSkillReq then
                        local _, skill = GetTrainerServiceSkillReq(i)
                        e.skill = skill
                    end
                else
                    list = nil
                end
            end
            if list then list[Key(name, rank)] = e end
        end
    end
end
ns.trainers.Read = Read

-- the spellbook's learned spells, by name and rank
local function Known()
    local SB = C_SpellBook
    local out = {}
    if not (SB and SB.GetNumSpellBookSkillLines) then return out end
    local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
            local info = SB.GetSpellBookItemInfo(slot, 0)
            if info and info.itemType == SPELL then
                out[Key(info.name, info.subName ~= "" and info.subName or nil)] = true
            end
        end
    end
    return out
end

-- The class trainers' services not known yet: { entry, now }, by level
-- (so those you can train now come first) and name.
function ns.trainers.Class()
    local store = MedalluinCharDB and type(MedalluinCharDB.trainer) == "table" and MedalluinCharDB.trainer.class
    local out = {}
    if not store then return out end
    local known, level = Known(), UnitLevel("player")
    for key, e in pairs(store) do
        if not e.known and not known[key] then
            table.insert(out, { entry = e, now = (e.level or 0) <= level })
        end
    end
    table.sort(out, function(a, b)
        if a.entry.level ~= b.entry.level then return a.entry.level < b.entry.level end
        if a.entry.name ~= b.entry.name then return a.entry.name < b.entry.name end
        return (a.entry.rank or "") < (b.entry.rank or "")
    end)
    return out
end

-- a profession trainer's services as read, by the profession's name ({}: none)
function ns.trainers.Trade(name)
    local t = MedalluinCharDB and MedalluinCharDB.trainer
    local list = type(t) == "table" and type(t.trade) == "table" and t.trade[name]
    return type(list) == "table" and list or {}
end

-- whether a class trainer has ever been read
function ns.trainers.Visited()
    local t = MedalluinCharDB and MedalluinCharDB.trainer
    return type(t) == "table" and type(t.class) == "table" and next(t.class) ~= nil
end

ns.On("TRAINER_SHOW", Read)
ns.On("TRAINER_UPDATE", Read)
