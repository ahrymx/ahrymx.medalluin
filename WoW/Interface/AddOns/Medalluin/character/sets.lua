-- The Character page's equipment sets (one of its details, beside the stats
-- and the titles): the sets, each with its icon and whether it is worn;
-- under them Equip, Save, New and Remove for the chosen one.
--
--   [icon] Tanking                      worn
--   [icon] Healing                 2 missing
--   [ Equip ] [ Save ] [ New ] [ Remove ]
--
-- From C_EquipmentSet, as Blizzard's own pane does it: Equip through
-- EquipmentManager_EquipSet (which refuses while casting), Save over the
-- chosen set keeping the slots it ignores, New with the head's icon and the
-- shirt and tabard ignored, Remove after a question. Blizzard's icon
-- picker and its per-slot ignore are not here: a set made here can be
-- changed in Blizzard's (which the sets are shared with).
local _, ns = ...

local ES = C_EquipmentSet
local SHIRT, TABARD, HEAD = 4, 19, 1
local QUESTION = 134400                 -- Interface\Icons\INV_Misc_QuestionMark
local BUTTONS, GAP = 22, 6
local list, buttons
local selected                          -- a set's ID
local sets = { available = ES ~= nil and ES.GetEquipmentSetIDs ~= nil }
ns.character.sets = sets

local function Info(id)
    local name, icon, setID, worn, _, _, _, lost = ES.GetEquipmentSetInfo(id)
    if not name then return end
    return { name = name, icon = icon or QUESTION, id = setID or id, worn = worn, lost = lost or 0 }
end

local function Chosen()
    return selected and Info(selected)
end

local function Error(text)
    local errors = _G.UIErrorsFrame
    if errors then errors:AddMessage(text, 1.0, 0.1, 0.1, 1.0) end
end

-- the slots a save leaves alone: the set's own, or a new set's
local function Ignore(slots)
    ES.ClearIgnoredSlotsForSave()
    for slot, ignored in pairs(slots or {}) do
        if ignored then ES.IgnoreSlotForSave(slot) end
    end
end

local function Create(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then return end
    if ES.GetEquipmentSetID(name) then
        Error(format("There is a set called %s already.", name))
        return
    end
    Ignore({ [SHIRT] = true, [TABARD] = true })
    ES.CreateEquipmentSet(name, GetInventoryItemTexture("player", HEAD) or QUESTION)
    selected = ES.GetEquipmentSetID(name)
    sets.Refresh()
end

local function Box(dialog) return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox()) end

-- Only keys are added: assigning StaticPopupDialogs itself would taint it.
StaticPopupDialogs.MEDALLUIN_SET_NEW = {
    text = "A new equipment set, of what you are wearing:",
    button1 = SAVE or "Save",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 16,
    OnShow = function(self) Box(self):SetText("") end,
    OnAccept = function(self) Create(Box(self):GetText()) end,
    EditBoxOnEnterPressed = function(self)
        local dialog = self:GetParent()
        Create(self:GetText())
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs.MEDALLUIN_SET_SAVE = {
    text = "Save what you are wearing to %s?",
    button1 = SAVE or "Save",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, id)
        Ignore(ES.GetIgnoredSlots(id))
        ES.SaveEquipmentSet(id)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs.MEDALLUIN_SET_REMOVE = {
    text = "Remove the equipment set %s?",
    button1 = REMOVE or "Remove",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, id) ES.DeleteEquipmentSet(id) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function Equip(s)
    if EquipmentManager_EquipSet then EquipmentManager_EquipSet(s.id) else ES.UseEquipmentSet(s.id) end
end

local ACTIONS = {
    { "Equip", "Put this set on.", function(s) Equip(s) end, function(s) return s and not s.worn end },
    { "Save", "Save what you are wearing to this set.",
        function(s) StaticPopup_Show("MEDALLUIN_SET_SAVE", s.name, nil, s.id) end,
        function(s) return s and not s.worn end },
    { "New", "A new set, of what you are wearing.",
        function() StaticPopup_Show("MEDALLUIN_SET_NEW") end,
        function() return ES.GetNumEquipmentSets() < (MAX_EQUIPMENT_SETS_PER_PLAYER or 10) end },
    { "Remove", "Remove this set (the gear stays where it is).",
        function(s) StaticPopup_Show("MEDALLUIN_SET_REMOVE", s.name, nil, s.id) end,
        function(s) return s ~= nil end },
}

function sets.Refresh()
    local rows = {}
    for _, id in ipairs(ES.GetEquipmentSetIDs() or {}) do
        local s = Info(id)
        if s then
            table.insert(rows, { label = s.name, icon = s.icon, depth = 0, selected = s.id == selected,
                value = s.worn and "worn" or s.lost > 0 and format("%d missing", s.lost) or nil,
                dim = s.lost > 0,
                click = function()
                    selected = s.id
                    sets.Refresh()
                end,
                enter = function(r)
                    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                    GameTooltip:SetEquipmentSet(s.id)
                    GameTooltip:Show()
                end })
        end
    end
    list:Set(rows)
    local s = Chosen()
    if not s then selected = nil end
    for i, b in ipairs(buttons) do
        b.enabled = ACTIONS[i][4](s) and true or false
        b:SetAlpha(b.enabled and 1 or 0.5)
    end
end

function sets.Build(frame, height)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT")
    holder:SetSize(ns.character.width, height - BUTTONS - GAP)
    list = ns.character.List(holder, "No equipment sets yet.")
    buttons = {}
    local w = (ns.character.width - 3 * GAP) / 4
    for i, a in ipairs(ACTIONS) do
        local b = ns.character.Button(frame, w, function(self)
            if self.enabled then a[3](Chosen()) end
        end, function() return a[2] end)
        b:SetHeight(BUTTONS)
        b.label:SetText(a[1])
        b:SetPoint("BOTTOMLEFT", (i - 1) * (w + GAP), 0)
        buttons[i] = b
    end
    sets.list, sets.buttons = list, buttons
end
