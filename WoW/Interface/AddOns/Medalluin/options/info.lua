-- Options > AddOns > Medalluin: a page about Medalluin, with the button that
-- opens its settings window (window.lua) and the slash commands. Nothing on
-- it is a setting: Medalluin builds none in the game's settings machinery.
local addonName, ns = ...

local UI = ns.OptionsUI
local C = UI.colors

local COMMANDS = {
    { "/mdlui", "Open the settings window." },
    { "/mdlui party, raid, boss, arena, bar, side...", "Open it on that page." },
    { "/mdlui kb", "Bind keys: point at an action button and press a key." },
    { "/mdlui edit", "Edit the unit frames: move, size, show or hide their pieces." },
    { "/mdlui taint", "Say what blocked a click, if one was blocked." },
    { "/mui, /medalluin", "The same as /mdlui, with the same words after it." },
}

local function Metadata(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return get and get(addonName, field)
end

local function Page()
    local f = CreateFrame("Frame")
    local title = UI.Serif(f, 26, C.goldBright)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Medalluin")
    local by = UI.Plain(f, 12, C.dim)
    by:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    by:SetText(("Version %s  ·  by %s"):format(Metadata("Version") or "?", Metadata("Author") or "?"))
    local rule = UI.Fill(f, "ARTWORK", C.goldDark)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", by, "BOTTOMLEFT", 0, -10)
    rule:SetPoint("RIGHT", -16, 0)

    local about = UI.Plain(f, 13)
    about:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -14)
    about:SetPoint("RIGHT", -16, 0)
    about:SetJustifyH("LEFT")
    about:SetText((Metadata("Notes") or "") .. "\n\nIts options have a window of their own.")

    local open = UI.Button(f, "Open Medalluin settings", 220, 30, function() ns.OpenOptions() end,
        "Closes this panel and opens Medalluin's own settings window.")
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)

    local head = UI.Serif(f, 14, C.goldBright)
    head:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -26)
    head:SetText("Slash commands")
    local prev = head
    for _, cmd in ipairs(COMMANDS) do
        local c = UI.Plain(f, 12, C.gold)
        c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", prev == head and 10 or 0, prev == head and -10 or -8)
        c:SetText(cmd[1])
        local d = UI.Plain(f, 12)
        d:SetPoint("LEFT", c, "LEFT", 330, 0)
        d:SetText(cmd[2])
        prev = c
    end
    return f
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local category = Settings.RegisterCanvasLayoutCategory(Page(), "Medalluin")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end)
