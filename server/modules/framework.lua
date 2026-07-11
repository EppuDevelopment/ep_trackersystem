Framework = Framework or {}

local loadedFramework = nil
local frameworkObject = nil

local function GetPreferredFramework()
    local framework = Config.Framework or 'auto'

    if type(framework) ~= 'string' then
        return 'auto'
    end

    return framework:lower()
end

local function IsResourceStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

local function LoadESX()
    local success, sharedObject = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if success and sharedObject then
        frameworkObject = sharedObject
        loadedFramework = 'esx'
        return true
    end

    return false
end

local function LoadQBCore()
    local success, coreObject = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if success and coreObject then
        frameworkObject = coreObject
        loadedFramework = 'qbcore'
        return true
    end

    return false
end

local function LoadQBX()
    if IsResourceStarted('qbx_core') then
        frameworkObject = exports.qbx_core
        loadedFramework = 'qbx'
        return true
    end

    return false
end

local function LoadFramework()
    if loadedFramework then
        return loadedFramework, frameworkObject
    end

    local preferredFramework = GetPreferredFramework()

    if preferredFramework == 'esx' then
        LoadESX()
    elseif preferredFramework == 'qbcore' or preferredFramework == 'qb' then
        LoadQBCore()
    elseif preferredFramework == 'qbx' then
        LoadQBX()
    else
        if IsResourceStarted('qbx_core') and LoadQBX() then
            return loadedFramework, frameworkObject
        end

        if IsResourceStarted('qb-core') and LoadQBCore() then
            return loadedFramework, frameworkObject
        end

        if IsResourceStarted('es_extended') then
            LoadESX()
        end
    end

    return loadedFramework, frameworkObject
end

local function GetPlayerData(player)
    return player and (player.PlayerData or player)
end

local function GetESXPlayer(source)
    local _, esx = LoadFramework()

    if not esx or not esx.GetPlayerFromId then
        return nil
    end

    return esx.GetPlayerFromId(source)
end

local function GetQBPlayer(source)
    local frameworkName, framework = LoadFramework()

    if frameworkName == 'qbx' then
        local success, player = pcall(function()
            return framework:GetPlayer(source)
        end)

        if not success or not player then
            success, player = pcall(function()
                return framework.GetPlayer(source)
            end)
        end

        if success then
            return player
        end

        return nil
    end

    if not framework or not framework.Functions or not framework.Functions.GetPlayer then
        return nil
    end

    return framework.Functions.GetPlayer(source)
end

local function GetPlayer(source)
    local frameworkName = LoadFramework()

    if frameworkName == 'esx' then
        return GetESXPlayer(source)
    end

    if frameworkName == 'qbcore' or frameworkName == 'qbx' then
        return GetQBPlayer(source)
    end

    return nil
end

local function GetValue(player, key)
    if not player then
        return nil
    end

    if player[key] ~= nil then
        return player[key]
    end

    if player.get then
        local success, value = pcall(function()
            return player.get(key)
        end)

        if success and value ~= nil then
            return value
        end

        success, value = pcall(function()
            return player:get(key)
        end)

        if success then
            return value
        end
    end

    return nil
end

function Framework.GetName()
    return LoadFramework() or 'standalone'
end

function Framework.GetPlayer(source)
    return GetPlayer(source)
end

function Framework.GetPlayerJobName(source)
    local frameworkName = LoadFramework()
    local player = GetPlayer(source)

    if frameworkName == 'esx' then
        return player and player.job and player.job.name or nil
    end

    local playerData = GetPlayerData(player)
    return playerData and playerData.job and playerData.job.name or nil
end

function Framework.GetPlayerIdentifier(source)
    local frameworkName = LoadFramework()
    local player = GetPlayer(source)

    if frameworkName == 'esx' and player and player.identifier then
        return player.identifier
    end

    local playerData = GetPlayerData(player)

    if playerData then
        return playerData.citizenid or playerData.license or playerData.source
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:find('license:', 1, true) == 1 then
            return identifier
        end
    end

    return nil
end

function Framework.GetPlayerFullName(source)
    local frameworkName = LoadFramework()
    local player = GetPlayer(source)

    if frameworkName == 'esx' and player then
        local firstName = GetValue(player, 'firstName') or GetValue(player, 'firstname')
        local lastName = GetValue(player, 'lastName') or GetValue(player, 'lastname')

        if firstName and lastName then
            return ('%s %s'):format(firstName, lastName)
        end

        if player.getName then
            local success, name = pcall(function()
                return player.getName()
            end)

            if not success or not name then
                success, name = pcall(function()
                    return player:getName()
                end)
            end

            if success and name and name ~= '' then
                return name
            end
        end
    end

    local playerData = GetPlayerData(player)
    local charinfo = playerData and playerData.charinfo or nil

    if charinfo then
        local firstName = charinfo.firstname or charinfo.firstName
        local lastName = charinfo.lastname or charinfo.lastName

        if firstName and lastName then
            return ('%s %s'):format(firstName, lastName)
        end
    end

    return GetPlayerName(source) or ('ID ' .. tostring(source))
end
