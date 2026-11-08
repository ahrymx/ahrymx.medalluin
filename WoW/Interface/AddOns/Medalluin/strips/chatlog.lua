-- The chat's log: a box of its own (the window shell, detached only:
-- chatLogPlace), opened by the Log button in the chat's drawer
-- (strips/chat.lua), with the chosen chat window's history as plain text.
-- Its text can be selected by dragging across it, and copied with Ctrl+C:
-- the game lets text be selected only in an edit box, so the log is one,
-- that a key cannot change.
--
--   [ log ]                                                     [x]
--   ---------------------------------------------------------------
--   | the window's lines, oldest first, scrolled to the newest
--   ---------------------------------------------------------------
--   General · 214 lines                     drag to select, Ctrl+C
--
-- The lines are kept here, as each window's AddMessage passes them (the
-- one wrap on Blizzard's chat, strips/chat.lua): reading them back out of
-- the chat frame would be calling Blizzard's code. So the log holds what
-- came since the UI loaded, the last MAX of each window. A line the game
-- keeps secret is kept as a note that it was there. Links, icons and
-- colours are taken out, so a copy is plain text.
--
-- While the text is selected (the box has focus), new lines wait: setting
-- the text would drop the selection. The band says how many are waiting;
-- they come in when the box is left (a click outside, or Escape).
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local DIM = { 0.70, 0.66, 0.55 }
local MAX = 1000                        -- lines kept for each window
local GUTTER, STEP = 10, 14 * 3         -- the scroll bar's room, a wheel's step (three lines)
local SECRET = "(a line the game keeps hidden)"

local logs = {}                         -- a chat frame -> its lines, oldest first
ns.chatLog = { logs = logs }

-- A message as plain text: a link's shown text, no icons, no colours.
local function Plain(text)
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|K.-|k", "(Battle.net)")
    text = text:gsub("|cn[^:]*:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (text:gsub("|n", " "))
end

local W, page, box, scroller, name, note
local shown, frame = "", nil            -- the text set, and whose it is
local waiting = 0                       -- lines come while the text is selected
local dirty = false
local stick = true                      -- the list kept at its newest line

-- The chat window the log is of: the one chosen in the chat (its tab).
local function Source()
    local f = SELECTED_CHAT_FRAME or ChatFrame1
    return f and logs[f] and f or ChatFrame1
end

local function Band()
    if not name then return end
    local f = frame
    local title = f and _G[f:GetName() .. "Tab"]
    local label = title and title.GetText and title:GetText()
    if not label or ns.IsSecret(label) or label == "" then label = f and f.name or "Chat" end
    local n = f and logs[f] and #logs[f] or 0
    name:SetText(label .. " · " .. n .. (n == 1 and " line" or " lines"))
    if waiting > 0 then
        note:SetText(waiting .. (waiting == 1 and " new line" or " new lines") .. ": click outside to see")
        note:SetTextColor(unpack(GOLD))
    else
        note:SetText("Drag to select, Ctrl+C to copy")
        note:SetTextColor(unpack(DIM))
    end
end

-- The box to the list's width, the list to the box's height (a multi-line
-- box grows to its text at the next layout: OnSizeChanged calls again), and
-- to the newest line, or kept where it was when the reader had scrolled up.
local function Fit()
    local child = scroller.child
    local width = scroller.scroll:GetWidth() or 0
    child:SetWidth(width)
    box:SetWidth(width)
    child:SetHeight(math.max(box:GetHeight() or 0, 1))
    if stick then
        scroller.To(scroller.scroll:GetVerticalScrollRange() or 0, true)
    else
        scroller.To(scroller.target, true)
    end
end

-- The text from the log; not while it is selected.
local function Fill()
    if not box then return end
    if box:HasFocus() then
        Band()
        return
    end
    local range = scroller.scroll:GetVerticalScrollRange() or 0
    stick = frame ~= Source() or scroller.target >= range - 2
    frame = Source()
    local lines = logs[frame] or {}
    shown = table.concat(lines, "\n")
    box:SetText(shown)
    waiting = 0
    Fit()
    Band()
end

function ns.chatLog.Add(f, text)
    local lines = logs[f]
    if not lines then
        lines = {}
        logs[f] = lines
    end
    if ns.IsSecret(text) then
        text = SECRET
    elseif type(text) ~= "string" then
        return
    else
        text = Plain(text)
    end
    table.insert(lines, text)
    if #lines > MAX + MAX / 4 then
        -- dropped a batch at a time, not a line at a time
        local cut, n = #lines - MAX, #lines
        for i = 1, MAX do lines[i] = lines[i + cut] end
        for i = n, MAX + 1, -1 do lines[i] = nil end
    end
    if W and W.window and W.window:IsShown() and f == frame then
        if box:HasFocus() then waiting = waiting + 1 end
        dirty = true
    end
end

local function Build(body, _, band)
    scroller = ns.window.Scroller(body, GUTTER)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function(_, delta) scroller.To(scroller.target - delta * STEP) end)
    box = CreateFrame("EditBox", "MedalluinChatLogText", scroller.child)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(2, 2, 2, 2)
    box:SetPoint("TOPLEFT")
    box:SetScript("OnSizeChanged", Fit)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    -- read only: whatever a key changes is put back
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(shown) end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if waiting > 0 then Fill() end
    end)
    -- the list follows the cursor, so a drag past an edge goes on scrolling
    box:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local view = scroller.scroll:GetHeight() or 0
        local top, bottom = -y, -y + h
        if top < scroller.target then
            scroller.To(top, true)
        elseif bottom > scroller.target + view then
            scroller.To(bottom - view, true)
        end
    end)
    ns.chatLog.box = box

    name = ns.Text(band, 12)
    name:SetPoint("LEFT", 2, 0)
    name:SetTextColor(unpack(GOLD))
    note = ns.Text(band, 11)
    note:SetPoint("RIGHT", -18, 0)          -- clear of the size grip
end

local function Start()
    W = ns.Window{
        name = "MedalluinChatLog", side = -1, place = "chatLogPlace", detachedOnly = true,
        closeTip = "Close the log.",
        Close = function() W.SetShown(false) end,
        Lifted = function() return {} end,
    }
    page = { key = "log", label = "Chat log", glyph = "log", order = 1, flex = true, bandUsed = true, height = 80,
        tip = "The chosen chat window's lines: drag to select, Ctrl+C to copy.",
        Available = function() return true end,
        Build = Build,
        Refresh = function() Fill() end,
        Fit = function() if box then Fit() end end,
        -- opened at the newest line
        Shown = function()
            frame = nil
            Fill()
        end }
    W.Page(page)
    ns.chatLog.window = W.Build()
    ns.chatLog.W = W
    -- new lines, drawn at the next frame; the chosen window, followed
    W.window:HookScript("OnUpdate", function()
        if dirty or frame ~= Source() then
            dirty = false
            Fill()
        end
    end)
end

-- with the chat: the box is built at login, shown by the drawer's button
ns.On("PLAYER_LOGIN", function()
    if ns.db.chat then Start() end
end)

-- The drawer's button (strips/chat.lua) opens and closes it; the window is
-- no secure frame, so in combat too.
function ns.ToggleChatLog()
    if not W then return end
    if not W.Current() then W.Select(page) end
    W.SetShown(not W.window:IsShown())
end
