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
    "PetFrame", "FocusFrame", "TargetFrameToT", "ShapeshiftBarFrame", "PetActionBarFrame",
    "MicroButtonAndBagsBar", "CharacterMicroButton", "MicroButtonPortrait", "MainMenuBarPerformanceBar",
    "MainMenuBarDownload", "MainMenuBarBackpackButton", "KeyRingButton",
    -- frames of the Edit Mode clients (Forever, retail)
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "StanceBar", "PetActionBar",
    "MicroMenu", "MicroMenuContainer", "BagsBar", "CharacterReagentBag0Slot", "ChatAlertFrame", "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
    -- API
    "CreateFrame", "InCombatLockdown", "RegisterUnitWatch", "UnregisterUnitWatch", "IsInGroup", "UnitAffectingCombat", "UnitThreatSituation",
    "UnitExists", "UnitName", "UnitClass", "UnitIsPlayer", "UnitIsConnected", "UnitIsDeadOrGhost", "UnitIsFriend", "UnitIsUnit",
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
    "QueueStatusButton", "QueueStatusMinimapButton", "MiniMapLFGFrame",
    -- the Edit Mode clients' API: secret values, curves, duration objects
    "issecretvalue", "C_ActionBar", "C_CurveUtil", "CurveConstants", "Enum", "UnitHealthPercent", "UnitPowerPercent",
    "UnitCastingDuration", "UnitChannelDuration", "ActionButton_UpdateCooldownNumberHidden",
    -- the chat (strips/chat.lua) and the player's buffs (strips/buffs.lua)
    "ChatFrame1", "CHAT_FRAMES", "CHAT_FRAME_TEXTURES", "NUM_CHAT_WINDOWS", "GENERAL_CHAT_DOCK",
    "FCFDock_GetSelectedWindow", "FCFTab_UpdateColors", "FCF_DockFrame", "FCF_UnDockFrame",
    "C_UnitAuras", "C_LossOfControl",
    -- the settings page and the atlas sizes
    "Settings", "SettingsPanel", "CreateSettingsButtonInitializer", "ReloadUI", "C_Texture", "GetCursorInfo", "GetActionBarPage", "GetSpecialization",
    -- tables and strings
    "RAID_CLASS_COLORS", "FACTION_BAR_COLORS", "PowerBarColor", "MAX_PLAYER_LEVEL",
    "PLAYER_OFFLINE", "DEAD", "LEVEL", "XP", "REPUTATION", "FAILED", "INTERRUPTED",
    "BAGSLOTTEXT", "NUM_BAG_SLOTS", "DURABILITY", "TIMEMANAGER_TITLE", "TIMEMANAGER_TOOLTIP_LOCALTIME",
    "TIMEMANAGER_TOOLTIP_REALMTIME",
    -- Lua extras WoW provides
    "wipe", "format", "unpack", "CopyTable",
}
-- the saved variables and the slash command
globals = { "_G", "MedaluinDB", "SLASH_MEDALUIN1", "SLASH_MEDALUIN2", "SLASH_MDLUI1", "SlashCmdList" }
