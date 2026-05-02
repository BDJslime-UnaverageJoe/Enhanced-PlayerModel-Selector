// Taken from Addon Finder: In-Game Addon Locator by Stoneman https://steamcommunity.com/sharedfiles/filedetails/?id=2915483255
AddCSLuaFile()
// It seems like we have to do it for each fucking category for fuck sake
function SearchAddonsFrom(target)
    target = string.lower(target)
    local result = ModelCache[target]

    // If you can't find it, but it's an entity, search for model instead!
    if result == nil then
        local npc = list.Get( "NPC" )[target]
        if npc then
            local model = npc.Model
            if model then model = string.lower( model ) end

            result = ModelCache[model]
        end

        if result == nil then
            local vehicle = list.Get( "Vehicles" )[target]
            if not vehicle then return end
            local model = vehicle.Model
            if model then model = string.lower( model ) end

            result = ModelCache[model]
        end
    end

    return result

end

local function AddRecursive(addon, folder, wildcard, wsid)
    local files, folders = file.Find( folder .. "*", addon )
    if ( not files ) then MsgN( "Warning! Not opening '" .. folder .. "' because we cannot search in it!"  ) return false end

    for k, v in pairs( files ) do
        if wildcard == "weapon" or wildcard == "entity" then
            if ( not string.EndsWith( v, ".lua" ) ) then continue end
            local found = v

            // Remove the .lua extension
            found = string.gsub(found, ".lua", "")
            found = string.lower(found)
            ModelCache[found] = wsid

            continue
        else
            if ( not string.EndsWith( v, ".mdl" ) ) then continue end
            local found = folder .. v
            found = string.lower(found)
            ModelCache[found] = wsid

            continue
        end
    end

    for k, v in pairs( folders ) do
        if wildcard == "weapon" or wildcard == "entity" then
            local found = v
            found = string.lower(found)
            ModelCache[found] = wsid

            continue
        else
            AddRecursive( addon, folder .. v .. "/", wildcard, wsid )
        end
    end
end

local function BeginSearching()
    // Put all models into a table. Every last one.
    if WSHL and WSHL.Addons then
        for id, path in pairs(WSHL.Addons.Path) do
            AddRecursive(path, "models/", "model", id)
        end   
        return
    end
    print("WSHL cache not found")
    for _, addon in ipairs( engine.GetAddons() ) do
        if addon.mounted then
            AddRecursive(addon.title, "models/", "model", addon.wsid)
        end
    end
end

hook.Add("InitPostEntity", "StonemanAddonSearcher:Cache", function()
    timer.Simple(5, function()
        ModelCache = {}
        BeginSearching()
    end)
end)

hook.Add("WSHL.BundleInitialized", "stoneman_search_addons_reload", function()
    ModelCache = {}
    BeginSearching()
end)
