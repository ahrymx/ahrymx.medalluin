-- luacheck config for the WoW addons under WoW/Interface/AddOns.
std = "lua51"
max_line_length = 120
exclude_files = {
    -- third-party addons kept for reference only
    "WoW/Interface/AddOns/DynamicCam-2.21.5",
    "WoW/Interface/AddOns/FrameAnchorUIBuilder",
    "WoW/Interface/AddOns/WeakTextures",
    -- the offline harness defines the WoW globals it stubs
    "tools",
}
-- the generated ns.windows table and the event-handler signatures
unused_args = false

read_globals = {
    -- frames
    "UIParent", "Minimap", "MinimapCluster", "GameTooltip", "PlayerFrame", "TargetFrame",
    "PartyFrame", "CompactPartyFrame", "MainMenuBar", "CastingBarFrame", "PlayerCastingBarFrame",
    "PetFrame", "FocusFrame", "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame", "TargetFrameToT", "ShapeshiftBarFrame", "PetActionBarFrame",
    "MicroButtonAndBagsBar", "CharacterMicroButton", "MicroButtonPortrait", "MainMenuBarPerformanceBar",
    "MainMenuBarDownload", "MainMenuBarBackpackButton", "KeyRingButton",
    "MainMenuMicroButton_SetAlertsEnabled", "MainMenuMicroButton_ShowAlert", "MainMenuMicroButton_HideAlert",
    "MicroButtonPulse", "MicroButtonPulseStop", "HelpTip",
    "TalentMicroButtonAlert", "CollectionsMicroButtonAlert", "EJMicroButtonAlert",
    -- frames of the Edit Mode clients (Forever, retail)
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "StanceBar", "PetActionBar",
    "MicroMenu", "MicroMenuContainer", "BagsBar", "CharacterReagentBag0Slot", "ChatAlertFrame", "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
    -- API
    "CreateFrame", "InCombatLockdown", "RegisterUnitWatch", "UnregisterUnitWatch", "RegisterStateDriver", "UnregisterStateDriver", "IsInGroup", "UnitAffectingCombat", "UnitThreatSituation",
    "UnitExists", "GetNumShapeshiftForms", "PetHasActionBar", "UnitName", "UnitClass", "UnitIsPlayer", "UnitIsConnected", "UnitIsDeadOrGhost", "UnitGUID", "UnitIsFriend", "UnitIsUnit",
    "UnitIsTapDenied", "UnitReaction", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax",
    "UnitPowerType", "UnitLevel", "UnitXP", "UnitXPMax", "GetXPExhaustion", "GetMaxPlayerLevel",
    "GetWatchedFactionInfo", "C_Reputation", "BreakUpLargeNumbers", "GameTooltip_Hide",
    "UnitFrame_OnEnter", "UnitFrame_OnLeave", "hooksecurefunc", "GetTime",
    "UnitHasIncomingResurrection", "UnitGroupRolesAssigned", "CheckInteractDistance", "UnitInRange", "UnitIsVisible", "GetReadyCheckStatus",
    "GetActionCooldown", "HasAction", "IsUsableAction", "IsActionInRange",
    "UnitCastingInfo", "CastingInfo", "UnitChannelInfo", "ChannelInfo", "GetComboPoints",
    "SetPortraitTexture", "C_Container", "GetContainerNumSlots", "GetContainerNumFreeSlots",
    "ToggleAllBags", "OpenAllBags", "GetInventoryItemDurability", "GetInventoryItemLink", "ToggleCharacter",
    "GameTime_GetTime", "GameTime_GetLocalTime", "GameTime_GetGameTime", "LoadAddOn", "TimeManager_Toggle",
    "date", "LibStub", "C_Timer", "C_Spell", "GetSpellCharges", "C_PlayerInfo", "IsMounted",
    "QueueStatusButton", "QueueStatusMinimapButton", "MiniMapLFGFrame", "MainMenuBarVehicleLeaveButton",
    "issecurevariable", "GetMouseFoci", "GetMouseFocus", "GetNumBindings", "GetBinding", "C_CVar", "C_AddOns",
    -- the Edit Mode clients' API: secret values, curves, duration objects
    "issecretvalue", "C_ActionBar", "C_CurveUtil", "CurveConstants", "Enum", "UnitHealthPercent", "UnitPowerPercent",
    "UnitCastingDuration", "UnitChannelDuration", "ActionButton_UpdateCooldownNumberHidden",
    -- the chat (strips/chat.lua) and the player's buffs (strips/buffs.lua)
    "ChatFrame1", "CHAT_FRAMES", "CHAT_FRAME_TEXTURES", "NUM_CHAT_WINDOWS", "GENERAL_CHAT_DOCK",
    "FCFDock_GetSelectedWindow", "FCFTab_UpdateColors", "FCF_DockFrame", "FCF_UnDockFrame",
    "C_UnitAuras", "C_LossOfControl",
    -- the side panel (strips/side.lua): the meter and the loot log
    "C_DamageMeter", "C_StringUtil", "C_DurationUtil", "AbbreviateLargeNumbers", "SecondsToClock", "GetClassAtlas", "STANDARD_TEXT_FONT",
    "C_LootHistory", "C_Item", "C_CurrencyInfo", "GetItemInfo", "GetItemIcon", "ITEM_QUALITY_COLORS",
    "HandleModifiedItemClick", "Ambiguate", "GetRealZoneText",
    "LOOT_ITEM", "LOOT_ITEM_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "CURRENCY_GAINED",
    "CURRENCY_GAINED_MULTIPLE", "YOU_LOOT_MONEY", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT",
    "LOOT_MONEY_SPLIT_GUILD", "GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT",
    -- the bags window (inventory/bags.lua)
    "ContainerFrameCombinedBags", "NUM_CONTAINER_FRAMES", "NUM_BAG_SLOTS", "C_NewItems", "ItemLocation",
    "ClearItemButtonOverlay", "SetItemButtonQuality", "SetItemButtonCount", "SetItemButtonDesaturated",
    "GetMoney", "GetMoneyString", "CloseAllBags", "GetCursorPosition", "CreateColor",
    -- the settings page and the atlas sizes
    -- paging (bars/paging.lua)
    "SAVE",
    -- key binding on hover (keybind.lua)
    "GetBindingKey", "GetBindingAction", "GetBindingText", "SetBinding", "SaveBindings", "GetCurrentBindingSet",
    "GetConvertedKeyOrButton", "IsKeyPressIgnoredForBinding", "CreateKeyChordStringUsingMetaKeyState",
    "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown", "HideUIPanel", "DONE",
    "Settings", "SettingsPanel", "CreateSettingsButtonInitializer", "CreateSettingsListSectionHeaderInitializer",
    "ReloadUI", "C_Texture", "GetCursorInfo", "GetActionBarPage", "GetSpecialization",
    -- tables and strings
    "RAID_CLASS_COLORS", "FACTION_BAR_COLORS", "PowerBarColor", "MAX_PLAYER_LEVEL",
    "PLAYER_OFFLINE", "DEAD", "LEVEL", "XP", "REPUTATION", "FAILED", "INTERRUPTED",
    "BAGSLOTTEXT", "NUM_BAG_SLOTS", "DURABILITY", "TIMEMANAGER_TITLE", "TIMEMANAGER_TOOLTIP_LOCALTIME",
    "TIMEMANAGER_TOOLTIP_REALMTIME", "OKAY", "CANCEL", "StaticPopup_Show",
    -- Lua extras WoW provides
    "wipe", "format", "unpack", "CopyTable",
    -- the raid (widgets/raid.lua)
    "IsInRaid", "ColorPickerFrame", "GetAddOnMetadata", "UISpecialFrames", "IsInInstance", "GetNumGroupMembers", "GetRaidRosterInfo",
    -- the action slots (bars/skills.lua)
    "GetActionInfo", "GetActionText", "GetMacroInfo", "GetMacroIndexByName", "PickupMacro", "PickupAction",
    "PlaceAction", "ClearCursor", "GetCursorInfo", "PickupSpell", "PickupItem", "C_Item", "C_MountJournal",
    "C_PetJournal", "C_SpellBook", "C_EquipmentSet", "C_SpecializationInfo", "GetSpecialization",
    "GetActiveTalentGroup", "Enum",
}
-- the saved variables, the slash command and the reset popup's key
globals = { "_G", "MedalluinDB", "MedalluinCharDB", "SLASH_MEDALLUIN1", "SLASH_MEDALLUIN2", "SLASH_MDLUI1", "SlashCmdList",
    "StaticPopupDialogs" }
