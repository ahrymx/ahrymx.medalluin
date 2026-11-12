-- What each character keeps of itself for its alts' windows
-- (professions/alts.lua): its bags and bank, its professions and the
-- recipes it knows, and a note. In MedalluinDB.altData[realm][name], beside
-- the roster's slim summary (the Overview's rows):
--
--   { money, bags = { [itemID] = n }, bagsSeen, bank = { [itemID] = n }, bankSeen,
--     skills = { { name, icon, rank, max, primary } ... },
--     recipes = { [profession] = { { id, name, icon, item } ... } },
--     recipesSeen = { [profession] = time }, notes }
--
-- The bags are read at logout and when this character's own window opens
-- (a change only marks them stale: nothing reads the bags while they sit
-- closed); the bank while it is open (as it settles, out of combat); the professions at login and
-- as they change; the recipes when this character's own crafting has its
-- list (never a linked one, nor another's). A note is anyone's to write.
-- What the game keeps secret is left out.
--
--   ns.alts.Data(name, realm)   a character's record (made if missing)
--   ns.alts.Me()                the playing character's, read fresh first
local _, ns = ...

local Container = C_Container
local A = {}
ns.alts = A

local function Realm() return GetRealmName and GetRealmName() or "?" end
local function Now() return time and time() or 0 end

function A.Data(name, realm)
    if not MedalluinDB then return {} end
    MedalluinDB.altData = type(MedalluinDB.altData) == "table" and MedalluinDB.altData or {}
    realm = realm or Realm()
    local all = MedalluinDB.altData
    all[realm] = type(all[realm]) == "table" and all[realm] or {}
    local d = all[realm][name]
    if type(d) ~= "table" then
        d = {}
        all[realm][name] = d
    end
    return d
end

local function Mine()
    local name = UnitName("player")
    if not name or ns.IsSecret(name) then return nil end
    return A.Data(name)
end

-- -------------------------------------------------------------- items
-- The containers' items, summed by itemID.
local function Count(list)
    local out = {}
    if not Container then return out end
    for _, bag in ipairs(list) do
        for slot = 1, (Container.GetContainerNumSlots and Container.GetContainerNumSlots(bag) or 0) do
            local info = Container.GetContainerItemInfo(bag, slot)
            local id, n = info and info.itemID, info and info.stackCount
            if id and not ns.IsSecret(id) and not ns.IsSecret(n) then out[id] = (out[id] or 0) + (n or 1) end
        end
    end
    return out
end

local function Bags()
    local list = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do list[#list + 1] = bag end
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > (NUM_BAG_SLOTS or 4) then list[#list + 1] = reagent end
    return list
end

-- the character bank's containers: its tabs (Forever's, inventory/bank.lua)
-- or the bank and its bag slots
local function BankBags()
    local list = {}
    if C_Bank and C_Bank.FetchPurchasedBankTabData and Enum.BankType then
        for _, t in ipairs(C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}) do
            table.insert(list, t.ID)
        end
        return list
    end
    if BANK_CONTAINER then table.insert(list, BANK_CONTAINER) end
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 0) - 1 do table.insert(list, bag) end
    return list
end

local banking, stale = false, true
local function ReadBags()
    local d = Mine()
    if not d then return end
    stale = false
    d.bags, d.bagsSeen = Count(Bags()), Now()
    if GetMoney then d.money = GetMoney() end
    if banking then d.bank, d.bankSeen = Count(BankBags()), Now() end
end

-- --------------------------------------------------------- professions
local function ReadSkills()
    local d = Mine()
    if not d or not GetProfessions then return end
    local skills = {}
    local list = { GetProfessions() }
    for i = 1, 6 do
        local index = list[i]
        if index then
            local name, icon, rank, max = GetProfessionInfo(index)
            if name and not ns.IsSecret(name) then
                table.insert(skills, { name = name, icon = icon, rank = rank, max = max, primary = i <= 2 })
            end
        end
    end
    d.skills = skills
end

-- this character's own crafting, with its list in
local function Own()
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetBaseProfessionInfo) then return false end
    if T.IsDataSourceChanging and T.IsDataSourceChanging() then return false end
    if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
    if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
    if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
    return true
end

local function ReadRecipes()
    local d = Mine()
    if not d or not Own() then return end
    local T = C_TradeSkillUI
    local base = T.GetBaseProfessionInfo()
    local prof = base and base.professionName
    if not prof or prof == "" or ns.IsSecret(prof) then return end
    local out = {}
    for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(id)
        if info and info.learned and info.name and not ns.IsSecret(info.name) then
            local schematic = T.GetRecipeSchematic and T.GetRecipeSchematic(id, false)
            table.insert(out, { id = id, name = info.name, icon = info.icon,
                item = schematic and schematic.outputItemID or nil })
        end
    end
    if #out == 0 then return end              -- (a list not in yet)
    table.sort(out, function(x, y) return x.name < y.name end)
    d.recipes = type(d.recipes) == "table" and d.recipes or {}
    d.recipesSeen = type(d.recipesSeen) == "table" and d.recipesSeen or {}
    d.recipes[prof], d.recipesSeen[prof] = out, Now()
end

-- the playing character's record, read now
function A.Me()
    ReadSkills()
    if stale and not InCombatLockdown() then ReadBags() end
    return Mine()
end

-- at the bank, the bags settle a moment after a change: read then, out of
-- combat; elsewhere a change only marks them stale
local waiting
local function Later()
    stale = true
    if not banking or waiting or InCombatLockdown() then return end
    waiting = true
    local function Read()
        waiting = nil
        ReadBags()
    end
    if C_Timer and C_Timer.After then C_Timer.After(1, Read) else Read() end
end

ns.On("PLAYER_LOGIN", ReadSkills)
ns.On("PLAYER_LOGOUT", function()
    if stale then ReadBags() end
end)
ns.On("SKILL_LINES_CHANGED", ReadSkills)
ns.On("BAG_UPDATE_DELAYED", Later)
ns.On("PLAYER_MONEY", function()
    local d = Mine()
    if d and GetMoney then d.money = GetMoney() end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    if stale then Later() end
end)
ns.On("BANKFRAME_OPENED", function()
    banking = true
    ReadBags()
end)
ns.On("BANKFRAME_CLOSED", function()
    if banking then ReadBags() end
    banking = false
end)
ns.On("TRADE_SKILL_LIST_UPDATE", ReadRecipes)
ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", ReadRecipes)
