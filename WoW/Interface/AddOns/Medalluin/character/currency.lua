-- The Currency page: the currencies under their headings, each with its
-- icon and how many; the details are the chosen one's: its cap as a bar
-- where it has one, what the game says of it, this week's earnings, and
-- its two ticks (shown on the backpack, unused).
--
-- All from C_CurrencyInfo, by the list's index, as Blizzard's own page
-- does; the choice is kept by currency, since marking one unused moves it.
-- A shift click links it in the chat, and the tooltip is the game's.
local _, ns = ...

local CI = C_CurrencyInfo
local list, details
local selected                          -- a currencyID

local Refresh

local function Rows()
    local rows = {}
    for i = 1, CI.GetCurrencyListSize() do
        local c = CI.GetCurrencyListInfo(i)
        if c and c.name then
            local row = { label = c.name }
            if c.isHeader then
                row.header, row.collapsed = true, not c.isHeaderExpanded
                row.depth = c.currencyListDepth or 0
                row.click = function()
                    CI.ExpandCurrencyList(i, not c.isHeaderExpanded)
                    Refresh()
                end
            else
                row.depth = (c.currencyListDepth or 0) + 1
                row.icon = c.iconFileID
                row.value = BreakUpLargeNumbers(c.quantity or 0)
                row.dim = c.isTypeUnused
                row.selected = c.currencyID == selected
                row.click = function()
                    if IsModifiedClick and IsModifiedClick("CHATLINK") and CI.GetCurrencyListLink then
                        local link = CI.GetCurrencyListLink(i)
                        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
                        return
                    end
                    selected = c.currencyID
                    Refresh()
                end
                row.enter = function(r)
                    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                    GameTooltip:SetCurrencyToken(i)
                    GameTooltip:Show()
                end
            end
            table.insert(rows, row)
        end
    end
    return rows
end

local function Chosen()
    if not selected then return end
    for i = 1, CI.GetCurrencyListSize() do
        local c = CI.GetCurrencyListInfo(i)
        if c and not c.isHeader and c.currencyID == selected then return c, i end
    end
end

local function Description(id)
    if CI.GetCurrencyDescription then return CI.GetCurrencyDescription(id) end
    local info = CI.GetCurrencyInfo and CI.GetCurrencyInfo(id)
    return info and info.description
end

local TICKS = {
    { label = "Show on backpack", tip = "Show this currency beside your money, under the bags.",
        click = function(on)
            local _, i = Chosen()
            if i then CI.SetCurrencyBackpack(i, on) end
            Refresh()
        end },
    { label = "Unused", tip = "Move this currency to the Unused heading, out of the way.",
        click = function(on)
            local _, i = Chosen()
            if i then CI.SetCurrencyUnused(i, on) end
            Refresh()
        end },
}

Refresh = function()
    list:Set(Rows())
    local c = Chosen()
    if not c then
        selected = nil
        details:Set(nil)
        return
    end
    local have = BreakUpLargeNumbers(c.quantity or 0)
    local bar
    if c.maxQuantity and c.maxQuantity > 0 then
        bar = { min = 0, max = c.maxQuantity, cur = c.quantity or 0, color = ns.colors.xp,
            text = format("%s / %s", have, BreakUpLargeNumbers(c.maxQuantity)) }
    end
    local lines = {}
    if c.canEarnPerWeek and c.maxWeeklyQuantity and c.maxWeeklyQuantity > 0 then
        table.insert(lines, format("This week: %s / %s", BreakUpLargeNumbers(c.quantityEarnedThisWeek or 0),
            BreakUpLargeNumbers(c.maxWeeklyQuantity)))
    end
    details:Set({ title = c.name, sub = format("You have %s", have), bar = bar,
        text = Description(c.currencyID), lines = lines })
    details.ticks[1]:Set(c.isShowInBackpack, true)
    details.ticks[2]:Set(c.isTypeUnused, true)
end

local page
local function Build(body, foot)
    list = ns.character.List(body, "No currencies yet.")
    details = ns.character.Details(foot, TICKS, "Choose a currency to see its details.")
    page.footHeight = details.height
    page.list, page.details = list, details
end

page = {
    key = "currency", label = "Currency", frame = "TokenFrame", order = 3,
    height = 0, flex = true,
    events = { "CURRENCY_DISPLAY_UPDATE" },
    Build = Build, Refresh = function() Refresh() end,
}
ns.CharacterPage(page)
