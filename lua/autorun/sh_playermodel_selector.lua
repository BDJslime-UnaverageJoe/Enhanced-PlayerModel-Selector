-- Enhanced PlayerModel Selector
-- Upgraded code by LibertyForce https://steamcommunity.com/id/libertyforce
-- Based on: https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/sandbox/gamemode/editor_player.lua


if SERVER then
	AddCSLuaFile("enhanced_playermodel_selector/default_playermodels.lua")
	AddCSLuaFile("enhanced_playermodel_selector/modelsearch.lua")
end
if CLIENT then
	include("enhanced_playermodel_selector/modelsearch.lua")
	include("enhanced_playermodel_selector/default_playermodels.lua")
end

EPS_VERSION = "5.1.0 Experimental"

EPS_REQUEST = 0
EPS_APPROVE = 1
EPS_DENY = 2
EPS_REMOVE = 3
EPS_INFO = -1

local flag = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
local convars = { }
convars["sv_playermodel_selector_force"]		= 1
convars["sv_playermodel_selector_gamemodes"]	= 1
convars["sv_playermodel_selector_instantly"]	= 1
convars["sv_playermodel_selector_flexes"]		= 0
convars["sv_playermodel_selector_limit"]		= 1
convars["sv_playermodel_selector_debug"]		= 0
convars["sv_playermodel_selector_workshop_enabled"]		= 1
convars["sv_playermodel_selector_workshop_queue"]		= game.IsDedicated() and 1 or 0
convars["sv_playermodel_selector_workshop_descriptors"]		= 0
convars["sv_playermodel_selector_workshop_load"]		= 1
for cvar, def in pairs( convars ) do
    convars[cvar] = CreateConVar( cvar,	def, flag )
end
flag = nil

hook.Remove( "Think", "garbage_day_ChooseHandsModel" ) -- Remove the hook, so we can actually change hands. Fix for https://steamcommunity.com/sharedfiles/filedetails/?id=3226024708

function EPS_CheckValidAddon(result)
	if SERVER and result.installed then
		print("installed already")
		return
	elseif result["title"] == "Hidden addon" or result["banned"] then
		print("hidden/banned")
		return
	elseif not string.find(result["tags"], "Addon") or not string.find(result["tags"], "Model") then
		print("not an addon")
		return
	elseif CLIENT and (not table.IsEmpty(result["content_descriptors"]) and not convars["sv_playermodel_selector_workshop_descriptors"]:GetBool()) then --- Ulib is having a stroke serverside????
		print("nsfw")
		return
	elseif not string.find(string.lower(result["title"]), "playermodel") and not string.find(string.lower(result["title"]), "pm") then
		print("pm unknown")
		result["unpm"] = true
	elseif result["size"] / 100000 >= 150 then
		print("oversized")
		result["oversize"] = true
	end
	return result
end

