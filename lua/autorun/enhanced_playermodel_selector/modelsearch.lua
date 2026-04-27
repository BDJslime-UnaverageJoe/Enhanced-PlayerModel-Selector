// Taken from Addon Finder: In-Game Addon Locator by Stoneman https://steamcommunity.com/sharedfiles/filedetails/?id=2915483255
AddCSLuaFile()
// It seems like we have to do it for each fucking category for fuck sake
function SearchAddonsFrom(target)
    target = string.lower(target)
    local result = StonemanAddonSearcherCache[target]

    // If you can't find it, but it's an entity, search for model instead!
    if result == nil then
        local npc = list.Get( "NPC" )[target]
        if npc then
            local model = npc.Model
            if model then model = string.lower( model ) end
            
            result = StonemanAddonSearcherCache[model]
        end

        if result == nil then
            local vehicle = list.Get( "Vehicles" )[target]
            if not vehicle then return end
            local model = vehicle.Model
            if model then model = string.lower( model ) end

            result = StonemanAddonSearcherCache[model]
        end
    end

    for _, addon in pairs( engine.GetAddons() ) do
        if result == addon.title then
            return addon
        end
    end
end

local function AddRecursive(addon, folder, wildcard)
    local files, folders = file.Find( folder .. "*", addon )
    if ( !files ) then MsgN( "Warning! Not opening '" .. folder .. "' because we cannot search in it!"  ) return false end

    for k, v in pairs( files ) do
        if wildcard == "weapon" or wildcard == "entity" then
            if ( !string.EndsWith( v, ".lua" ) ) then continue end
            local found = v
            
            // Remove the .lua extension
            found = string.gsub(found, ".lua", "")
            found = string.lower(found)
            StonemanAddonSearcherCache[found] = addon

            continue
        else
            if ( !string.EndsWith( v, ".mdl" ) ) then continue end
            local found = folder..v
            found = string.lower(found)
            StonemanAddonSearcherCache[found] = addon

            continue
        end
    end

    for k, v in pairs( folders ) do 
        if wildcard == "weapon" or wildcard == "entity" then
            local found = v
            found = string.lower(found)
            StonemanAddonSearcherCache[found] = addon

            continue
        else
            AddRecursive( addon, folder .. v .. "/", wildcard )
        end
    end
end

local function BeginSearching()
    // Put all models into a table. Every last one.
    for _, addon in SortedPairsByMemberValue( engine.GetAddons(), "title" ) do
        if addon.mounted and addon.downloaded then
            AddRecursive(addon.title, "models/", "model")
        end
    end
end

hook.Add("InitPostEntity", "StonemanAddonSearcher:Cache", function()
    StonemanAddonSearcherCache = {}
    BeginSearching()
end)

hook.Add("GameContentChanged", "stoneman_search_addons_reload", function()
    StonemanAddonSearcherCache = {}
    BeginSearching()
end)
