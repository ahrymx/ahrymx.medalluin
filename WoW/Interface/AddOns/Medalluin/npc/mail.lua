-- The mailbox, in the NPC box (npc/window.lua): the inbox and a letter to
-- send, on two tabs of our own.
--
--   12 letters · 4g 20s waiting · the first goes in 2 days   <- red under 3
--   [Inbox][Send]
--   Thalric — Spare cloth                       3 items  9d
--   Auction House — Sale: Linen Cloth           1g 20s  29d
--   Okun — Your order                          COD 1g  2d   <- red: it costs
--   2g 36s 55c                                            [Open all]
--
-- A click reads a letter in the same tab: what it says, its money as a row
-- to take, its items as tiles to take; Take all, Reply, Return or Delete
-- in the foot. Taking from a letter sent cash on delivery pays for it, so
-- the foot asks first, as the vendor's does.
--
-- Open all takes the money and items of every letter but one sent cash on
-- delivery or by a game master: the last letter first, so the letters
-- before it keep their places as it goes, one command at a time, while
-- the game has none waiting (C_Mail.IsCommandPending). It stops when the
-- bags are full, the mailbox closes, or on Stop:
--
--   Opening 4 of 12 · 3g 20s taken                          [Stop]
--
-- Send: To (completed from the names this account mails: its characters
-- on the realm, and the last ten written to, MedalluinDB.mail[realm]),
-- Subject, the letter, money (or, with items, cash on delivery), and
-- twelve wells for items: a drop or a click with an item on the cursor
-- attaches it, a click takes it back. A bag item's right click attaches as
-- Blizzard's own Send tab lets it: the game is told the Send tab is up
-- (SetSendMailShowing, Blizzard's own call), and does it itself.
--
-- Taint: as every page, nothing of MailFrame is written or called.
local _, ns = ...

local RED = { 1, 0.3, 0.25 }
local RED_CODE = "|cffff4d40"
local SOON = 3                                   -- days: a letter going sooner is red
local RECENT = 10                                -- the names last written to, kept
local STEP = 0.15                                -- Open all's pace, as Blizzard's
local WAIT = 2                                   -- seconds: a command's answer waited for, at most
local AGAIN, REFUSALS = 1, 3                     -- a refused command: tried again after, and given up after
local RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local SEND = ATTACHMENTS_MAX_SEND or 12

local Money = ns.npc.Money
local function Update() ns.npc.Update("mail") end

local tab = "inbox"
local reading                    -- the letter read, by index
local readAs                     -- and by who sent it and what about: the index of a letter the game removed
                                 -- is the next one's
local pending                    -- an item of a COD letter to pay for: { index, attachment, name, cod }
local opening                    -- Open all: { total, at, taken, ticker, waiting (since when), next (no
                                 -- command before), asked (the money in flight), refused (in a row),
                                 -- skip (items the game would not give, by id) }
local said                       -- what Open all said when it stopped, until the next tab
local form = { to = "", subject = "", body = "", copper = 0, cod = false }
local sending                    -- the name a letter on its way was sent to

-- ------------------------------------------------------------ the names
local function Book()
    MedalluinDB = MedalluinDB or {}
    MedalluinDB.mail = MedalluinDB.mail or {}
    local realm = GetRealmName and GetRealmName() or "?"
    local book = MedalluinDB.mail[realm] or {}
    book.alts, book.recent = book.alts or {}, book.recent or {}
    MedalluinDB.mail[realm] = book
    return book
end

-- a name to the front of a list, once, and the list cut to most
local function Front(list, name, most)
    for i = #list, 1, -1 do
        if list[i]:lower() == name:lower() then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    while most and #list > most do table.remove(list) end
end

-- the game's own names for a letter's To, as Blizzard's box asks for them:
-- this account's characters, friends, the guild, those met lately
local function Game(text)
    local out = {}
    if not GetAutoCompleteResults then return out end
    local list = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
    local ok, results = pcall(GetAutoCompleteResults, text, 10, #text, false,
        list and list.include or AUTOCOMPLETE_FLAG_ALL or 0xffffffff, list and list.exclude or 0)
    for _, r in ipairs(ok and type(results) == "table" and results or {}) do
        local who = type(r) == "table" and r.name or r
        if type(who) == "string" and not ns.IsSecret(who) then table.insert(out, who) end
    end
    return out
end

-- the names that begin with what is typed: the last written to first, then
-- the game's, then this account's characters remembered, never the one
-- playing
local function Complete(text)
    local book, out, seen = Book(), {}, {}
    local me = (UnitName("player") or ""):lower()
    local typed = text:lower()
    for _, list in ipairs({ book.recent, Game(text), book.alts }) do
        for _, name in ipairs(list) do
            local low = name:lower()
            if not seen[low] and low ~= me and low:sub(1, #typed) == typed then
                seen[low] = true
                table.insert(out, name)
            end
        end
    end
    return out
end

-- -------------------------------------------------------------- a letter
local function Header(i)
    local _, stationery, sender, subject, money, cod, days, items, read, returned, _, reply, gm = GetInboxHeaderInfo(i)
    return { sender = sender or UNKNOWN or "Unknown", subject = subject or "", money = money or 0, cod = cod or 0,
        days = days or 0, items = items, read = read, returned = returned, reply = reply, gm = gm,
        icon = stationery }
end

-- An auction house's letters, as the game titles them ("Auction successful:
-- %s"), shortened to what happened and to what: "Sold: Linen Cloth", from
-- "AH". The game's own words, so any language reads.
local AUCTION = {
    { "AUCTION_SOLD_MAIL_SUBJECT", "Auction successful: %s", "Sold" },
    { "AUCTION_WON_MAIL_SUBJECT", "Auction won: %s", "Won" },
    { "AUCTION_OUTBID_MAIL_SUBJECT", "Outbid on %s", "Outbid" },
    { "AUCTION_EXPIRED_MAIL_SUBJECT", "Auction expired: %s", "Expired" },
    { "AUCTION_REMOVED_MAIL_SUBJECT", "Auction cancelled: %s", "Cancelled" },
    { "AUCTION_INVOICE_MAIL_SUBJECT", "Sale Pending: %s", "Pending" },
}
local function Short(h)
    for _, a in ipairs(AUCTION) do
        local words = _G[a[1]] or a[2]
        -- every character a pattern reads escaped, then the escaped %s the item
        local pattern = "^" .. words:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
        local what = h.subject:match(pattern)
        if what then return "AH — " .. a[3] .. ": " .. what end
    end
    return h.sender .. " — " .. h.subject
end

local function Days(days)
    local text
    if days >= 1 then
        text = format("%dd", math.floor(days))
    else
        text = format("%dh", math.max(1, math.floor(days * 24)))
    end
    return days < SOON and RED_CODE .. text .. "|r" or text
end

-- the same, in words: "in 2 days"
local function When(days)
    local d = math.floor(days)
    local when = days < 1 and "today" or d == 1 and "in 1 day" or format("in %d days", d)
    return days < SOON and RED_CODE .. when .. "|r" or when
end

local function Count(n) return n == 1 and "1 item" or format("%d items", n) end

-- what a letter holds, as its row's value
local function Holds(h)
    local parts = {}
    if h.cod > 0 then table.insert(parts, RED_CODE .. "COD " .. Money(h.cod) .. "|r") end
    if h.money > 0 then table.insert(parts, Money(h.money)) end
    if h.items and h.items > 0 then table.insert(parts, Count(h.items)) end
    table.insert(parts, Days(h.days))
    return table.concat(parts, "  ")
end

-- what Open all may take from: not COD, not a game master's (and only one
-- with money or an item it may take: Left)
local function Takeable(h) return not h.gm and h.cod == 0 end

local function Key(h) return h.sender .. "\n" .. h.subject end

local function Read(i)
    reading, pending = i, nil
    readAs = i and Key(Header(i))
    Update()
end

-- the letter read still there, at its place: else back to the inbox
local function Still()
    if reading and (reading > (GetInboxNumItems() or 0) or Key(Header(reading)) ~= readAs) then
        reading, pending = nil, nil
    end
end

-- -------------------------------------------------------------- Open all
local Step
local function Stop(why)
    if not opening then return end
    if opening.ticker then opening.ticker:Cancel() end
    if C_Mail and C_Mail.SetOpeningAll then C_Mail.SetOpeningAll(false) end
    local taken = opening.taken > 0 and " · " .. Money(opening.taken) .. " taken" or ""
    local kept = 0
    for _ in pairs(opening.skip) do kept = kept + 1 end
    said = (why or kept > 0 and format("Opened all but %d item%s the mailbox kept", kept, kept == 1 and "" or "s")
        or "Opened all") .. taken
    opening = nil
    Update()
end

-- a letter's first item Open all may take: not one the game refused it
local function Next(i)
    for a = 1, RECEIVE do
        local name, id = GetInboxItem(i, a)
        if name and not (opening and opening.skip[id]) then return a, id end
    end
end

-- the letters left to open, last first
local function Left()
    local out = {}
    for i = GetInboxNumItems() or 0, 1, -1 do
        local h = Header(i)
        if Takeable(h) and (h.money > 0 or Next(i)) then table.insert(out, i) end
    end
    return out
end

local function Free()
    local C = C_Container
    return C and C.CalculateTotalNumberOfFreeBagSlots and C.CalculateTotalNumberOfFreeBagSlots() or 1
end

-- one command, when the game has none waiting and has told us the last
-- one's outcome
function Step()
    if not opening then return end
    -- a beat of the ticker apart (Blizzard's own pace), and never inside a refusal's pause
    if GetTime() < opening.next then return end
    -- an answer that never came: the next goes after a while all the same
    if opening.waiting and GetTime() - opening.waiting < WAIT then return end
    if C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending() then return end
    local left = Left()
    local i = left[1]
    if not i then return Stop() end
    local h = Header(i)
    -- the money asked for, counted only once the game says it came
    opening.waiting, opening.asked = GetTime(), h.money
    if h.money > 0 then
        TakeInboxMoney(i)
    else
        if Free() == 0 then return Stop("Stopped: the bags are full") end
        TakeInboxItem(i, (Next(i)))
    end
    opening.at = opening.total - #left + 1
    Update()
end

local function Start()
    local total = #Left()
    if total == 0 then return end
    said, reading, pending = nil, nil, nil
    opening = { total = total, taken = 0, at = 1, next = 0, refused = 0, skip = {} }
    if C_Mail and C_Mail.SetOpeningAll then C_Mail.SetOpeningAll(true) end
    if C_Timer and C_Timer.NewTicker then opening.ticker = C_Timer.NewTicker(STEP, Step) end
    Step()
end

-- the last command answered: the next may go
local function Answered()
    if opening then opening.waiting = nil end
end

-- ------------------------------------------------------------ the inbox
local function Totals(n, total)
    local money, soonest = 0, nil
    for i = 1, n do
        local h = Header(i)
        money = money + h.money
        soonest = math.min(soonest or h.days, h.days)
    end
    local parts = { total == 1 and "1 letter" or format("%d letters", total) }
    if money > 0 then table.insert(parts, Money(money) .. " waiting") end
    if soonest then table.insert(parts, "the first goes " .. When(soonest)) end
    return table.concat(parts, " · ")
end

local function Inbox(out)
    local n, total = GetInboxNumItems()
    n, total = n or 0, total or n or 0
    if n == 0 then
        table.insert(out, { "text", "No mail.", ns.colors.dim })
        return
    end
    table.insert(out, { "text", Totals(n, total), pin = true })
    for i = 1, n do
        local h = Header(i)
        table.insert(out, { "row", label = Short(h), icon = h.icon, crop = true, value = Holds(h),
            dim = h.read,
            click = function(button) if button ~= "RightButton" then Read(i) end end,
            enter = function(row)
                ns.window.Outside(row)
                GameTooltip:SetText(h.subject ~= "" and h.subject or h.sender)
                GameTooltip:AddLine(h.sender, 1, 1, 1)
                GameTooltip:Show()
            end })
    end
    if total > n then
        table.insert(out, { "text", format("%d more wait on the server: take some to make room for them.",
            total - n), ns.colors.dim })
    end
end

local function TakeItem(i, a, name, cod)
    if cod > 0 then
        pending = { index = i, attachment = a, name = name, cod = cod }
        Update()
    else
        TakeInboxItem(i, a)
    end
end

local function Letter(out, i)
    local h = Header(i)
    table.insert(out, { "row", label = "‹ Inbox", dim = true, click = function() Read(nil) end })
    table.insert(out, { "heading", h.subject ~= "" and h.subject or "(no subject)" })
    table.insert(out, { "text", "From " .. h.sender .. " · "
        .. (InboxItemCanDelete(i) and "deleted " or "goes back ") .. When(h.days), ns.colors.dim })
    local body = GetInboxText(i)
    if body and body ~= "" then table.insert(out, { "text", body }) end
    if h.cod > 0 then
        table.insert(out, { "text", "Cash on delivery: taking an item pays " .. Money(h.cod) .. ".", RED })
    end
    if h.money > 0 then
        table.insert(out, { "row", label = "Take " .. Money(h.money), crop = true,
            icon = "Interface\\Icons\\INV_Misc_Coin_01",
            click = function(button) if button ~= "RightButton" then TakeInboxMoney(i) end end })
    end
    local tiles = { "tiles" }
    for a = 1, RECEIVE do
        local name, _, icon, count = GetInboxItem(i, a)
        if name then
            table.insert(tiles, { icon = icon, crop = true, label = name, count = count,
                selected = pending and pending.attachment == a,
                click = function(button) if button ~= "RightButton" then TakeItem(i, a, name, h.cod) end end,
                enter = function(tile)
                    ns.window.Outside(tile)
                    GameTooltip:SetInboxItem(i, a)
                    GameTooltip:Show()
                end })
        end
    end
    if #tiles > 1 then table.insert(out, tiles) end
end

-- ------------------------------------------------------------ send
local function Attached()
    local out = {}
    for i = 1, SEND do
        local name, _, icon, count = GetSendMailItem(i)
        out[i] = name and { name = name, icon = icon, count = count } or false
    end
    return out
end

local function Any(items)
    for _, v in ipairs(items) do if v then return v end end
end

local function Changed(key)
    return function(value)
        form[key] = value
        Update()
    end
end

local function Send(out)
    local items = Attached()
    if not Any(items) then form.cod = false end
    table.insert(out, { "input", key = "to", label = "To", text = form.to, complete = Complete,
        changed = Changed("to") })
    table.insert(out, { "input", key = "subject", label = "Subject", text = form.subject,
        changed = Changed("subject") })
    table.insert(out, { "input", key = "body", label = "Letter", text = form.body, lines = 5,
        changed = Changed("body") })
    table.insert(out, { "money", key = "money", label = form.cod and "COD" or "Money", copper = form.copper,
        changed = Changed("copper") })
    if Any(items) then
        table.insert(out, { "row", label = "Cash on delivery: they pay the money to take the items",
            selected = form.cod, dim = not form.cod, click = function()
                form.cod = not form.cod
                Update()
            end })
    end
    local wells = { "slots" }
    for i = 1, SEND do
        local v = items[i]
        table.insert(wells, { icon = v and v.icon, count = v and v.count,
            click = function(button) ClickSendMailItemButton(i, button == "RightButton" or not GetCursorInfo()) end,
            receive = function() ClickSendMailItemButton(i) end,
            enter = function(well)
                if not v then return end
                ns.window.Outside(well)
                GameTooltip:SetSendMailItem(i)
                GameTooltip:Show()
            end })
    end
    table.insert(out, { "heading", "Items" })
    table.insert(out, wells)
end

local function Clear()
    form = { to = "", subject = "", body = "", copper = 0, cod = false }
    if ClearSendMail then ClearSendMail() end
    Update()
end

local function Post()
    local first = Any(Attached())
    local subject = form.subject ~= "" and form.subject or first and first.name or ""
    SetSendMailCOD(0)
    SetSendMailMoney(0)
    if form.copper > 0 then
        if form.cod and first then SetSendMailCOD(form.copper) else SetSendMailMoney(form.copper) end
    end
    sending = form.to
    SendMail(form.to, subject, form.body)
    Update()
end

-- the game told which tab is up, as Blizzard's own tabs tell it: a bag
-- item's right click attaches only while Send is
local function Showing()
    if SetSendMailShowing then SetSendMailShowing(tab == "send") end
end

local function Tab(key)
    return function()
        tab, reading, pending, said = key, nil, nil, nil
        Showing()
        Update()
    end
end

local function Blocks()
    local out = { { "tabs", { label = "Inbox", selected = tab == "inbox", click = Tab("inbox") },
        { label = "Send", selected = tab == "send", click = Tab("send") } } }
    if tab == "send" then
        Send(out)
    elseif reading then
        Letter(out, reading)
    else
        Inbox(out)
    end
    return out
end

-- ------------------------------------------------------------ the foot
local function Foot()
    local money = Money(GetMoney and GetMoney() or 0)
    if tab == "send" then
        local postage = GetSendMailPrice and GetSendMailPrice() or 0
        local first = Any(Attached())
        -- cash on delivery sends no money: they pay it
        local cost = postage + (form.cod and 0 or form.copper)
        local why = form.to == "" and "Write who it goes to."
            or form.subject == "" and not first and "Give it a subject."
            or cost > (GetMoney and GetMoney() or 0) and "Not enough money."
            or sending and "On its way."
        return { left = "Postage " .. Money(postage),
            { label = "Send", primary = true, enabled = not why, click = Post,
                tip = why or format("Sends it to %s, for %s.", form.to, Money(cost)) },
            { label = "Clear", click = Clear } }
    end
    if pending then
        local p = pending
        return { left = format("Pay %s to take %s?", Money(p.cod), p.name),
            { label = "Pay", primary = true, enabled = (GetMoney and GetMoney() or 0) >= p.cod,
                tip = "Not enough money.", click = function()
                    pending = nil
                    TakeInboxItem(p.index, p.attachment)
                    Update()
                end },
            { label = "Cancel", click = function()
                pending = nil
                Update()
            end } }
    end
    if reading then
        local i = reading
        local h = Header(i)
        local holds = h.money > 0 or (h.items or 0) > 0
        local canDelete = InboxItemCanDelete(i)
        local foot = { left = money,
            { label = "Take all", enabled = holds and h.cod == 0,
                tip = h.cod > 0 and "Sent cash on delivery: take each item, and pay." or nil,
                click = function() AutoLootMailItem(i) end },
            { label = "Reply", enabled = h.reply and h.sender ~= UnitName("player") or false, click = function()
                tab, reading = "send", nil
                form.to = h.sender
                local prefix = (MAIL_REPLY_PREFIX or "RE:") .. " "
                form.subject = h.subject:sub(1, #prefix) == prefix and h.subject or prefix .. h.subject
                Showing()
                Update()
            end } }
        if canDelete then
            table.insert(foot, { label = "Delete", enabled = not holds,
                tip = holds and "Take what it holds first." or nil, click = function()
                    reading = nil
                    DeleteInboxItem(i)
                    Update()
                end })
        else
            table.insert(foot, { label = "Return", enabled = not h.returned,
                tip = h.returned and "It came back to you: it cannot go again." or nil, click = function()
                    reading = nil
                    ReturnInboxItem(i)
                    Update()
                end })
        end
        return foot
    end
    if opening then
        return { left = format("Opening %d of %d", opening.at, opening.total)
            .. (opening.taken > 0 and " · " .. Money(opening.taken) .. " taken" or ""),
            { label = "Stop", primary = true, click = function() Stop("Stopped") end } }
    end
    local left = #Left()
    return { left = said or money,
        { label = "Open all", primary = left > 0, enabled = left > 0,
            tip = left > 0 and format("Takes the money and items of %d letter%s; not one sent cash on delivery.",
                left, left == 1 and "" or "s") or "Nothing to take.", click = Start } }
end

ns.npc.Page{
    -- a mailbox has no face: Medalluin's round envelope stands in its portrait
    -- (art/strips/gen_strips.py mailbox), the game's letter icon being square
    key = "mail", frame = "MailFrame", icon = ns.media .. "strips\\mailbox",
    Title = function() return "Mailbox" end,
    Blocks = Blocks, Foot = Foot, Close = function() CloseMail() end,
    -- as tall as the Send tab, whichever is shown
    Steady = function()
        local out = { { "tabs", { label = "Inbox" }, { label = "Send" } } }
        Send(out)
        return out
    end,
    Start = function()
        local me = UnitName("player")
        if me then Front(Book().alts, me) end
        ns.On("MAIL_SHOW", function()
            tab, reading, pending, said = "inbox", nil, nil, nil
            ns.npc.Show("mail")
        end)
        ns.On("MAIL_CLOSED", function()
            Stop("Stopped: the mailbox closed")
            reading, pending, sending = nil, nil, nil
            ns.npc.Sync()
        end)
        ns.On("MAIL_INBOX_UPDATE", function()
            Still()
            Answered()
            Update()
        end)
        ns.On("CLOSE_INBOX_ITEM", function(_, i)
            if i == reading then reading, pending = nil, nil end
            Update()
        end)
        -- the next goes on the ticker, at its pace: never straight after
        ns.On("MAIL_SUCCESS", function()
            if opening then
                opening.taken = opening.taken + (opening.asked or 0)
                opening.asked, opening.refused = nil, 0
            end
            Answered()
            Update()
        end)
        -- A command refused. With an item named, the game will not give that
        -- one (unique, or no room for it): it is left, as Blizzard's Open all
        -- leaves it. Without, the mailbox was busy: tried again after a
        -- pause, and given up after a few in a row.
        ns.On("MAIL_FAILED", function(_, itemID)
            sending = nil
            if opening then
                opening.waiting = nil
                if itemID then
                    opening.skip[itemID] = true
                else
                    opening.refused = opening.refused + 1
                    opening.next = GetTime() + AGAIN
                    if opening.refused >= REFUSALS then Stop("Stopped: the mailbox kept refusing") end
                end
            end
            Update()
        end)
        ns.On("MAIL_SEND_SUCCESS", function()
            if sending and sending ~= "" then Front(Book().recent, sending, RECENT) end
            sending = nil
            form = { to = "", subject = "", body = "", copper = 0, cod = false }
            Update()
        end)
        for _, e in ipairs({ "MAIL_SEND_INFO_UPDATE", "PLAYER_MONEY", "BAG_UPDATE_DELAYED" }) do ns.On(e, Update) end
    end,
}
