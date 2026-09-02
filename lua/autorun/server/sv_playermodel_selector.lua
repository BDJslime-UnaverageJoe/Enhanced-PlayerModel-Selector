--util.AddNetworkString("lf_playermodel_client_sync")
util.AddNetworkString("lf_playermodel_cvar_change")
util.AddNetworkString("lf_playermodel_blacklist")
util.AddNetworkString("lf_playermodel_voxlist")
util.AddNetworkString("lf_playermodel_update")
util.AddNetworkString("lf_playermodel_workshop")
if not game.IsDedicated() then util.AddNetworkString("lf_playermodel_download") end

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

local SetMDL = FindMetaTable("Entity").SetModel

local addon_legs = false

local debugmode = GetConVar( "sv_playermodel_selector_debug" ):GetBool() or false
cvars.AddChangeCallback( "sv_playermodel_selector_debug", function() debugmode = GetConVar( "sv_playermodel_selector_debug" ):GetBool() end )

--local function client_sync( ply )
--	net.Start("lf_playermodel_client_sync")
--	net.WriteBool( addon_vox )
--	net.Send( ply )
--end
--hook.Add( "PlayerInitialSpawn", "lf_playermodel_client_sync_hook", client_sync )
--net.Receive("lf_playermodel_client_sync", function( len, ply ) client_sync( ply ) end )

net.Receive("lf_playermodel_cvar_change", function( len, ply )
    if ply:IsValid() and ply:IsPlayer() and ply:IsSuperAdmin() then
        local cvar = net.ReadString()
        if not convars[cvar] then ply:PrintMessage(HUD_PRINTCONSOLE, "Illegal convar change") return end
        convars[cvar]:SetString( net.ReadString() )
    end
end )


if not file.Exists( "lf_playermodel_selector", "DATA" ) then file.CreateDir( "lf_playermodel_selector" ) end
if file.Exists( "playermodel_selector_blacklist.txt", "DATA" ) then -- Migrate from old version
    if not file.Exists( "lf_playermodel_selector/sv_blacklist.txt", "DATA" ) then
        local content = file.Read( "playermodel_selector_blacklist.txt", "DATA" )
        file.Write( "lf_playermodel_selector/sv_blacklist.txt", content )
    end
    file.Delete( "playermodel_selector_blacklist.txt" )
end

local Blacklist = { }
if file.Exists( "lf_playermodel_selector/sv_blacklist.txt", "DATA" ) then
    local loaded = util.JSONToTable( file.Read( "lf_playermodel_selector/sv_blacklist.txt", "DATA" ) )
    if istable( loaded ) then
        for k, v in pairs( loaded ) do
            Blacklist[tostring(k)] = v
        end
        loaded = nil
    end
end

local Whitelist = { }
if file.Exists( "lf_playermodel_selector/sv_whitelist.txt", "DATA" ) then
    local loaded = util.JSONToTable( file.Read( "lf_playermodel_selector/sv_whitelist.txt", "DATA" ) )
    if istable( loaded ) then
        for k, v in pairs( loaded ) do
            Whitelist[tostring(k)] = v
        end
        loaded = nil
    end
end

local ActiveIDs = { } -- Clears on first server start, relies on Facepunch/garrysmod-issues/issues/3001
if (string.StartWith( game.GetIPAddress() , "0.0.0.0" )) then
    file.Delete( "lf_playermodel_selector/sv_activeids.txt" )
end
if file.Exists( "lf_playermodel_selector/sv_activeids.txt", "DATA" ) then
    local loaded = util.JSONToTable( file.Read( "lf_playermodel_selector/sv_activeids.txt", "DATA" ) )
    if istable( loaded ) then
        for k, v in pairs( loaded ) do
            ActiveIDs[tostring(k)] = v
        end
        loaded = nil
    end
end

for k, _ in ipairs(ActiveIDs) do
    resource.AddWorkshop(k)
end

local Queue = {}

local function CheckSteamworks()
    if steamworks and steamworks.DownloadUGC or not game.IsDedicated() then
        return true
    end

    if not util.IsBinaryModuleInstalled("workshop") then
        return false
    end

    require("workshop")

    return steamworks ~= nil
end

local function AddNewModel(wsid, ply)
    if not convars["sv_playermodel_selector_workshop_enabled"]:GetBool() then return end
    if WSHL and convars["sv_playermodel_selector_workshop_load"]:GetBool() then
        wshl(wsid, false, true, 2)
        ActiveIDs[wsid] = true
        file.Write( "lf_playermodel_selector/sv_activeids.txt", util.TableToJSON(ActiveIDs))
        PrintMessage(HUD_PRINTTALK, "LF_PMS: New Model/s have been added.")
    else
        if not CheckSteamworks() then
            PrintMessage(HUD_PRINTTALK, "LF_PMS: Workshop capabilties not detected, new model will not be added.")
            return
        end
        if game.IsDedicated() then
            steamworks.DownloadUGC( wsid, function( path )
                game.MountGMA( path )
            end)
        else
            net.Start("lf_playermodel_download")
                net.WriteString(wsid)
                net.Send(Entity(1))
        end
        resource.AddWorkshop(wsid)
        ActiveIDs[wsid] = true
        file.Write( "lf_playermodel_selector/sv_activeids.txt", util.TableToJSON(ActiveIDs))
        PrintMessage(HUD_PRINTTALK, "LF_PMS: New Model/s will be added on map change.")
    end
    net.Start("lf_playermodel_cvar_change")
        net.Send(ply)
end

local function UpdateQueue(filter)
    if not filter then
        filter = RecipientFilter()

        for _, v in ipairs(player.GetAll()) do
            if v:IsValid() and v:IsAdmin() then filter:AddPlayer(v) end
        end
    end
    net.Start("lf_playermodel_workshop")
        net.WriteString(util.TableToJSON(Queue))
        net.Send(filter)
end

net.Receive("lf_playermodel_workshop", function( len, ply )
    if not convars["sv_playermodel_selector_workshop_enabled"]:GetBool() then return end
    if ply:IsValid() and ply:IsPlayer() then
        local mode = net.ReadInt( 3 )

        if mode == EPS_INFO then
            UpdateQueue(ply)
            return
        end
        local wsid = net.ReadString()

        if mode == EPS_REQUEST then
            if Whitelist[wsid] or not convars["sv_playermodel_selector_workshop_queue"]:GetBool() then
                AddNewModel(wsid, ply)
                return
            end
            steamworks.FileInfo( wsid, function( result )
                if EPS_CheckValidAddon( result ) then
                    Queue[wsid] = ply:SteamID64()
                    UpdateQueue()
                end
            end)
            return
        end

        if not ply:IsAdmin() then return end
        if mode == EPS_APPROVE then
            Whitelist[wsid] = true
            file.Write( "lf_playermodel_selector/sv_whitelist.txt", util.TableToJSON( Whitelist, true ) )
            AddNewModel(wsid, ply)
            Queue[wsid] = nil
            UpdateQueue()

        elseif mode == EPS_DENY then
            Queue[wsid] = nil
            UpdateQueue()
        elseif mode == EPS_REMOVE then
            return
        end
    end
end )

net.Receive("lf_playermodel_blacklist", function( len, ply )
    if ply:IsValid() and ply:IsPlayer() and ply:IsAdmin() then
        local mode = net.ReadInt( 3 )
        if mode == 1 then
            local gamemode = net.ReadString()
            if gamemode ~= "sandbox" then
                Blacklist[gamemode] = true
                file.Write( "lf_playermodel_selector/sv_blacklist.txt", util.TableToJSON( Blacklist, true ) )
            end
        elseif mode == 2 then
            local tbl = net.ReadTable()
            if istable( tbl ) then
                for k, v in pairs( tbl ) do
                    local name = tostring( v )
                    Blacklist[name] = nil
                end
                file.Write( "lf_playermodel_selector/sv_blacklist.txt", util.TableToJSON( Blacklist, true ) )
            end
        end
        net.Start("lf_playermodel_blacklist")
        net.WriteTable( Blacklist )
        net.Send( ply )
    end
end )



local VOXlist = { }

function lf_playermodel_selector_get_voxlist() -- global
    return VOXlist
end

local function InitVOX()
    if file.Exists( "lf_playermodel_selector/sv_voxlist.txt", "DATA" ) then
        local loaded = util.JSONToTable( file.Read( "lf_playermodel_selector/sv_voxlist.txt", "DATA" ) )
        if istable( loaded ) then
            for k, v in pairs( loaded ) do
                VOXlist[tostring(k)] = tostring(v)
            end
            loaded = nil
        end
    end
end

net.Receive("lf_playermodel_voxlist", function( len, ply )
    if TFAVOX_Models and ply:IsValid() and ply:IsPlayer() and ply:IsAdmin() then
        local function tfa_reload()
            TFAVOX_Packs_Initialize()
            TFAVOX_PrecachePacks()
            for k,v in pairs( player.GetAll() ) do
                print("Resetting the VOX of " .. v:Nick() )
                if IsValid(v) then TFAVOX_Init(v,true,true) end
            end
        end
        local mode = net.ReadInt( 3 )
        if mode == 1 then
            local k = net.ReadString()
            local v = net.ReadString()
            VOXlist[k] = v
            file.Write( "lf_playermodel_selector/sv_voxlist.txt", util.TableToJSON( VOXlist, true ) )
            --TFAVOX_Models = { }
            tfa_reload()
        elseif mode == 2 then
            local tbl = net.ReadTable()
            if istable( tbl ) then
                for k, v in pairs( tbl ) do
                    local name = tostring( v )
                    VOXlist[name] = nil
                    if istable( TFAVOX_Models ) then TFAVOX_Models[name] = nil end
                end
                file.Write( "lf_playermodel_selector/sv_voxlist.txt", util.TableToJSON( VOXlist, true ) )
                --TFAVOX_Models = { }
                tfa_reload()
            end
        end
        net.Start("lf_playermodel_voxlist")
        net.WriteTable( VOXlist )
        net.Send( ply )
    end
end )


local plymeta = FindMetaTable( "Player" )
local CurrentPlySetModel

local function Allowed( ply )
    if GAMEMODE_NAME == "sandbox" or ( not Blacklist[GAMEMODE_NAME] and ( ply:IsAdmin() or GetConVar( "sv_playermodel_selector_gamemodes"):GetBool() ) ) then
        return true	else return false
    end
end

local function UpdatePlayerModel( ply, added )
    added = added or false
    if Allowed( ply ) then

        ply.lf_playermodel_spawned = true

        if debugmode then print( "LF_PMS: Updating playermodel for: " .. tostring( ply:GetName() ) ) end

        local mdlname = ply:GetInfo( "cl_playermodel" )
        local mdlpath = player_manager.TranslatePlayerModel( mdlname )

        if mdlpath == player_manager.TranslatePlayerModel( "kleiner" ) and mdlname ~= "kleiner" then
            if ply:GetInfo( "cl_playermodelid " ) ~= "0" and not added then
                local wsid = ply:GetInfo( "cl_playermodelid" )
                if Whitelist[wsid] or not convars["sv_playermodel_selector_workshop_queue"]:GetBool() then
                    AddNewModel(wsid, ply)
                    timer.Simple(1, function()
                        UpdatePlayerModel( ply, true )
                    end)
                end
            end

            --if debugmode then print( "LF_PMS: Failed to find model from addon " .. tostring( wsid )) end
            --if debugmode then print( "LF_PMS: Missing model detected, attempting to obtain from workshop" ) end
            --if debugmode then print( "LF_PMS: Addon " .. tostring( wsid ) .. " not in whitelist, continuing using default model" ) end

        end


        SetMDL( ply, mdlpath )
        if debugmode then print( "LF_PMS: Set model to: " .. tostring( mdlname ) .. " - " .. tostring( mdlpath ) ) end

        local skin = ply:GetInfoNum( "cl_playerskin", 0 )
        ply:SetSkin( skin )
        if debugmode then print( "LF_PMS: Set model skin to no.: " .. tostring( skin ) ) end

        local groups = ply:GetInfo( "cl_playerbodygroups" )
        if ( groups == nil ) then groups = "" end
        groups = string.Explode( " ", groups )
        for k = 0, ply:GetNumBodyGroups() - 1 do
            local v = tonumber( groups[ k + 1 ] ) or 0
            ply:SetBodygroup( k, v )
            if debugmode then print( "LF_PMS: Set bodygroup no. " .. tostring( k ) .. " to: " .. tostring( v ) ) end
        end

        if GetConVar( "sv_playermodel_selector_flexes" ):GetBool() and tobool( ply:GetInfoNum( "cl_playermodel_selector_unlockflexes", 0 ) ) then
            local flexes = ply:GetInfo( "cl_playerflexes" )
            if ( flexes == nil ) or ( flexes == "0" ) then return end
            flexes = string.Explode( " ", flexes )
            for k = 0, ply:GetFlexNum() - 1 do
                ply:SetFlexWeight( k, tonumber( flexes[ k + 1 ] ) or 0 )
            end
        end

        local pcol = ply:GetInfo( "cl_playercolor" )
        local wcol = ply:GetInfo( "cl_weaponcolor" )
        ply:SetPlayerColor( Vector( pcol ) )
        ply:SetWeaponColor( Vector( wcol ) )

        timer.Simple( 0.1, function() if ply.SetupHands and isfunction( ply.SetupHands ) then ply:SetupHands() end end )
        timer.Simple( 0.2, function()
            if ply:GetInfo( "cl_playerhands" ) ~= "" then mdlname = ply:GetInfo( "cl_playerhands" ) end
            local HandsModel = player_manager.TranslatePlayerHands( mdlname )

            local HandsEntity = ply:GetHands()
            if HandsEntity and HandsModel and istable( HandsModel ) then
                if HandsEntity:GetModel() ~= HandsModel.model then
                    if debugmode then print( "LF_PMS: SetupHands failed. Gamemode doesn't implement this function correctly. Trying workaround... " ) end
                    if ( IsValid( HandsEntity ) ) then
                        HandsEntity:SetModel( HandsModel.model )
                        HandsEntity:SetSkin( HandsModel.skin )
                        HandsEntity:SetBodyGroups( HandsModel.body )

                        local skin = ply:GetInfoNum( "cl_playerhandsskin", 0 )
                        HandsEntity:SetSkin( skin )
                        if debugmode then print( "LF_PMS: Set hands model skin to no.: " .. tostring( skin ) ) end

                        local groups = ply:GetInfo( "cl_playerhandsbodygroups" )
                        if ( groups == nil ) then groups = "" end
                        groups = string.Explode( " ", groups )
                        for k = 0, HandsEntity:GetNumBodyGroups() - 1 do
                            local v = tonumber( groups[ k + 1 ] ) or 0
                            HandsEntity:SetBodygroup( k, v )
                            if debugmode then print( "LF_PMS: Set hands bodygroup no. " .. tostring( k ) .. " to: " .. tostring( v ) ) end
                        end

                        if debugmode then
                            timer.Simple( 0.2, function()
                                if not IsValid(HandsEntity) then return end
                                if HandsEntity:GetModel() ~= HandsModel.model then
                                    print( "LF_PMS: Workaround failed. Unable to setup viewmodel hands. Please check for incompatible addons." )
                                else
                                    print( "LF_PMS: Workaround successful. Hands set to: " .. HandsModel.model )
                                end
                            end )
                        end
                    end
                else
                    if debugmode then print( "LF_PMS: SetupHands successful. Hands set to: " .. tostring( HandsModel.model ) ) end
                end
            else
                if debugmode then print( "LF_PMS: ERROR - SetupHands failed. player_manager.TranslatePlayerHands didn't return valid data. Please check for incompatible addons." ) end
            end
        end )

        if addon_legs then
            hook.Run( "SetModel", ply, mdlpath )
        end

    end
end

net.Receive("lf_playermodel_update", function( len, ply )
    if ply:IsValid() and ply:IsPlayer() and ( ply:IsAdmin() or GetConVar( "sv_playermodel_selector_instantly"):GetBool() ) then
        if game.SinglePlayer() or ply:IsAdmin() then
            UpdatePlayerModel( ply )
        else
            local limit = math.Clamp( GetConVar( "sv_playermodel_selector_limit"):GetInt(), 0, 900 )
            local ct = CurTime()
            local diff1 = ct - ( ply.lf_playermodel_lastcall or limit * (-1) )
            local diff2 = ct - ( ply.lf_playermodel_lastsuccess or limit * (-1) )
            if diff1 < 0.1 then
                ply:Kick( "Too many requests. Please check your script for infinite loops" )
                if debugmode then print ( "LF_PMS: Kicked " .. tostring( ply:GetName() ) .. ". Multiple calls for playermodel change in less than: " .. tostring( diff1 ) .. " seconds" ) end
            elseif diff2 >= limit then
                ply.lf_playermodel_lastcall = ct
                ply.lf_playermodel_lastsuccess = ct
                UpdatePlayerModel( ply )
            else
                ply.lf_playermodel_lastcall = ct
                ply:ChatPrint( "Enhanced PlayerModel Selector: Too many requests. Please wait another " .. tostring( limit - math.floor( diff2 ) ) .. " seconds before trying again." )
                if debugmode then print ( "LF_PMS: Prevented " .. tostring( ply:GetName() ) .. " from changing playermodel. Last try: " .. tostring( math.floor( diff1 ) ) .. " seconds ago." ) end
            end
        end
    end
end )

hook.Add( "PlayerSpawn", "lf_playermodel_force_hook1", function( ply )
    if GetConVar( "sv_playermodel_selector_force" ):GetBool() and tobool( ply:GetInfoNum( "cl_playermodel_selector_force", 0 ) ) then
        UpdatePlayerModel( ply )
        ply.lf_playermodel_spawned = nil
    end
end )

hook.Add( "PlayerSetHandsModel", "lf_fe_hands_select2", function( ply, ent )
    if ply:GetInfo( "cl_playerhands" ) and ply:GetInfo( "cl_playerhands" ) ~= "" then
        local info = player_manager.TranslatePlayerHands( ply:GetInfo( "cl_playerhands" ) )

        if ( info ) then
            timer.Simple( 0, function()
                if IsValid(ent) then
                    ent:SetModel( info.model )
                    ent:SetSkin( info.skin )
                    ent:SetBodyGroups( info.body )

                    local skin = ply:GetInfoNum( "cl_playerhandsskin", 0 )
                    ent:SetSkin( skin )

                    local groups = ply:GetInfo( "cl_playerhandsbodygroups" )
                    if ( groups == nil ) then groups = "" end
                    groups = string.Explode( " ", groups )
                    for k = 0, ent:GetNumBodyGroups() - 1 do
                        local v = tonumber( groups[ k + 1 ] ) or 0
                        ent:SetBodygroup( k, v )
                    end

                end
            end)
        end
    end
end )

local function ForceSetModel( ply, mdl )
    if GetConVar( "sv_playermodel_selector_force" ):GetBool() and Allowed( ply ) and tobool( ply:GetInfoNum( "cl_playermodel_selector_force", 0 ) ) then
        if not ply.lf_playermodel_spawned then
            if debugmode then print( "LF_PMS: Detected initial call for SetModel on: " .. tostring( ply:GetName() ) ) end
            UpdatePlayerModel( ply )
        else
            if debugmode then print( "LF_PMS: Enforcer prevented " .. tostring( ply:GetName() ) .. "'s model from being changed to: " .. tostring( mdl ) ) end
        end
    elseif mdl then
        CurrentPlySetModel( ply, mdl )
        if addon_legs then hook.Run( "SetModel" , ply, mdl ) end
    end
end

local function ToggleForce()
    if plymeta.SetModel and plymeta.SetModel ~= ForceSetModel then
        CurrentPlySetModel = plymeta.SetModel
    else
        CurrentPlySetModel = SetMDL
    end

    if GetConVar( "sv_playermodel_selector_force" ):GetBool() then
        plymeta.SetModel = ForceSetModel
    else
        plymeta.SetModel = CurrentPlySetModel
    end
end
cvars.AddChangeCallback( "sv_playermodel_selector_force", ToggleForce )

hook.Add( "Initialize", "lf_playermodel_force_hook2", function( ply )
    if file.Exists( "autorun/sh_legs.lua", "LUA" ) then addon_legs = true end
    --if file.Exists( "autorun/tfa_vox_loader.lua", "LUA" ) then addon_vox = true end
    if TFAVOX_Models then InitVOX() end

    local try = 0

    ToggleForce()

    timer.Create( "lf_playermodel_force_timer", 5, 0, function()
        if plymeta.SetModel == ForceSetModel or not GetConVar( "sv_playermodel_selector_force" ):GetBool() then
            timer.Remove( "lf_playermodel_force_timer" )
        else
            ToggleForce()
            try = try + 1
            print( "LF_PMS: Addon conflict detected. Unable to initialize enforcer to protect playermodel. [Attempt: " .. tostring( try ) .. "/10]" )
            if try >= 10 then
                timer.Remove( "lf_playermodel_force_timer" )
            end
        end
    end )
end )

