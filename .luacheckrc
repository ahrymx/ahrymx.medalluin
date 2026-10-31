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
    "PartyFrame", "CompactPartyFrame",
    -- API
    "CreateFrame", "InCombatLockdown", "RegisterUnitWatch", "IsInGroup",
    "UnitExists", "UnitName", "UnitClass", "UnitIsPlayer", "UnitIsConnected", "UnitIsDeadOrGhost",
    "UnitIsTapDenied", "UnitReaction", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax",
    "UnitPowerType", "UnitLevel", "UnitXP", "UnitXPMax", "GetXPExhaustion", "GetMaxPlayerLevel",
    "GetWatchedFactionInfo", "C_Reputation", "BreakUpLargeNumbers", "GameTooltip_Hide",
    "UnitFrame_OnEnter", "UnitFrame_OnLeave",
    -- tables and strings
    "RAID_CLASS_COLORS", "FACTION_BAR_COLORS", "PowerBarColor", "MAX_PLAYER_LEVEL",
    "PLAYER_OFFLINE", "DEAD", "LEVEL", "XP", "REPUTATION",
    -- Lua extras WoW provides
    "wipe", "format", "unpack",
}
globals = { "_G" }
