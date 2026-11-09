-- The character window: Medalluin's own (the shell is window/shell.lua),
-- standing on the left strip over the chat panel's place, its margin
-- beside the portrait's medallion.
--
-- Blizzard's window keeps every way in: the keys (C, the reputation and
-- currency keys), the portrait's medallion, ToggleCharacter, Escape. It
-- still opens and closes, and still switches its pages, but under a hidden
-- parent, as the bags window keeps Blizzard's bags (inventory/bags.lua):
-- this window shows while it is open, on the page Blizzard last showed.
-- A tab asks Blizzard for its page in turn, so the next key press knows
-- which page is open; in combat it only turns our page, leaving Blizzard's
-- panel code alone.
--
-- The pages are our own, drawn from the game's API, one per Blizzard page
-- this client has (Forever has six, retail three), each a page of the
-- shell's (ns.CharacterPage{ ... }, see window/shell.lua).
--
-- Built at login, and only when the Character window option is on.
local _, ns = ...

local W = ns.Window{
    name = "MedalluinCharacter", side = -1, detailsKey = "characterDetails",
    closeTip = "Close the character window.",
    Close = function() HideUIPanel(CharacterFrame) end,
    Open = function(page)
        if ToggleCharacter and _G[page.frame] then ToggleCharacter(page.frame, true) end
    end,
    -- the portrait, and the queue's eye when it sits in its place
    Lifted = function()
        local list = { CharacterMicroButton }
        local eye = QueueStatusButton or QueueStatusMinimapButton or MiniMapLFGFrame
        if eye and eye:GetParent() == ns.strips[-1] then table.insert(list, eye) end
        return list
    end,
}

ns.character = { pages = W.pages, width = W.width, band = { left = W.band.left, height = W.band.height },
    Button = ns.window.Button, Ornament = ns.window.Ornament }
ns.CharacterPage = W.Page

-- ----------------------------------------------- Blizzard's character window
local function Sync()
    W.SetShown(CharacterFrame:IsShown())
end

local function Start()
    if not ns.db.character or not CharacterFrame or not C_Reputation then return end
    W.Build()
    ns.Park(CharacterFrame)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        hooksecurefunc(CharacterFrame, method, Sync)
    end
    -- Blizzard's page switches (its keys, ToggleCharacter) turn ours
    for _, p in ipairs(W.pages) do
        local f = p.available and _G[p.frame]
        if f then
            hooksecurefunc(f, "Show", function() W.Select(p) end)
            if f:IsShown() and not W.Current() then W.Select(p) end
        end
    end
    if not W.Current() then W.Select(W.ByFrame("PaperDollFrame") or W.pages[1]) end
    ns.character.window, ns.character.Select, ns.character.listener = W.window, W.Select, W.listener
    Sync()
end

ns.On("PLAYER_LOGIN", Start)
