local activeTrackers = {}
local patrolIds = {}
local trackerBroadcastThreadRunning = false

lib.locale(Config.Locale ~= 'auto' and Config.Locale or nil)

local function IsJobAllowed(jobName)
    return jobName ~= nil and Config.AllowedJobs[jobName] == true
end

local function GetPlayerJobName(source)
    return Framework.GetPlayerJobName(source)
end

local function GetPlayerIdentifier(source)
    return Framework.GetPlayerIdentifier(source)
end

local function GetPatrolIdStorageKey(source)
    local identifier = GetPlayerIdentifier(source)

    if not identifier then
        return nil
    end

    local persistenceConfig = Config.Persistence or {}

    return (persistenceConfig.keyPrefix or 'patrol_id:') .. identifier
end

local function LoadStoredPatrolId(source)
    local persistenceConfig = Config.Persistence or {}

    if persistenceConfig.enabled == false or patrolIds[source] then
        return
    end

    local key = GetPatrolIdStorageKey(source)

    if not key then
        return
    end

    local storedPatrolId = GetResourceKvpString(key)

    if storedPatrolId and storedPatrolId ~= '' then
        patrolIds[source] = storedPatrolId
    end
end

local function SaveStoredPatrolId(source, patrolId)
    local persistenceConfig = Config.Persistence or {}

    if persistenceConfig.enabled == false then
        return
    end

    local key = GetPatrolIdStorageKey(source)

    if not key then
        return
    end

    SetResourceKvp(key, patrolId)
end

local function GetDefaultPatrolId(source)
    local format = Config.Blip.defaultPatrolIdFormat or '%03d'
    return format:format(source)
end

local function GetPatrolId(source)
    LoadStoredPatrolId(source)

    if patrolIds[source] then
        return patrolIds[source]
    end

    return GetDefaultPatrolId(source)
end

local function GetTrackerName(source)
    local patrolId = GetPatrolId(source)
    local playerName = Framework.GetPlayerFullName(source)
    local nameFormat = Config.Blip.nameFormat or '%s | %s'

    return nameFormat:format(patrolId, playerName)
end

local function GetTrackerColour(source)
    local jobName = GetPlayerJobName(source)
    return Config.JobColours[jobName] or Config.Blip.colour
end

local function GetTrackerSprite(source)
    local blipConfig = Config.Blip or {}
    local vehicleSpriteConfig = blipConfig.vehicleSprites or {}

    if blipConfig.useVehicleSprites == false then
        return blipConfig.sprite
    end

    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return vehicleSpriteConfig.default or blipConfig.sprite
    end

    local success, vehicle = pcall(function()
        return GetVehiclePedIsIn(ped, false)
    end)

    if not success or not vehicle or vehicle == 0 then
        return vehicleSpriteConfig.default or blipConfig.sprite
    end

    local vehicleClass = nil
    success, vehicleClass = pcall(function()
        return GetVehicleClass(vehicle)
    end)

    if not success then
        return vehicleSpriteConfig.default or blipConfig.sprite
    end

    local classSprites = vehicleSpriteConfig.classes or {}

    return classSprites[vehicleClass] or vehicleSpriteConfig.default or blipConfig.sprite
end

local function SanitizePatrolId(value)
    local patrolId = tostring(value or ''):match('^%s*(.-)%s*$')

    if patrolId == '' or #patrolId > 10 then
        return nil
    end

    if not patrolId:match('^[%w%-]+$') then
        return nil
    end

    return patrolId
end

local function GetTrackerCoords(source)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function GetActiveTrackerList()
    local trackers = {}

    for trackerSource in pairs(activeTrackers) do
        if IsJobAllowed(GetPlayerJobName(trackerSource)) then
            trackers[#trackers + 1] = {
                source = trackerSource,
                name = GetTrackerName(trackerSource),
                coords = GetTrackerCoords(trackerSource),
                colour = GetTrackerColour(trackerSource),
                sprite = GetTrackerSprite(trackerSource)
            }
        else
            activeTrackers[trackerSource] = nil
            TriggerClientEvent('ep_tracker:client:forceDisable', trackerSource, locale('notifications.job_changed_disabled'))
        end
    end

    return trackers
end

local function SendTrackerList(target, trackerList)
    if IsJobAllowed(GetPlayerJobName(target)) then
        TriggerClientEvent('ep_tracker:client:updateTrackers', target, trackerList or GetActiveTrackerList())
        return
    end

    TriggerClientEvent('ep_tracker:client:updateTrackers', target, {})
end

local function BroadcastTrackerList()
    local trackerList = GetActiveTrackerList()

    for _, playerId in ipairs(GetPlayers()) do
        SendTrackerList(tonumber(playerId), trackerList)
    end
end

local function StartTrackerBroadcastThread()
    if trackerBroadcastThreadRunning then
        return
    end

    trackerBroadcastThreadRunning = true

    CreateThread(function()
        while next(activeTrackers) ~= nil do
            BroadcastTrackerList()
            Wait(tonumber(Config.TrackerSyncInterval) or 1000)
        end

        trackerBroadcastThreadRunning = false
        BroadcastTrackerList()
    end)
end

local function DisableTracker(source, message)
    if not activeTrackers[source] then
        return
    end

    activeTrackers[source] = nil
    TriggerClientEvent('ep_tracker:client:forceDisable', source, message or locale('notifications.disabled'))
    BroadcastTrackerList()
end

RegisterNetEvent('ep_tracker:server:requestEnable', function()
    local source = source
    local jobName = GetPlayerJobName(source)

    if not IsJobAllowed(jobName) then
        activeTrackers[source] = nil
        TriggerClientEvent('ep_tracker:client:notAuthorized', source, locale('notifications.not_authorized'))
        SendTrackerList(source)
        return
    end

    activeTrackers[source] = true
    TriggerClientEvent('ep_tracker:client:setEnabled', source, true)
    BroadcastTrackerList()
    StartTrackerBroadcastThread()
end)

RegisterNetEvent('ep_tracker:server:requestDisable', function()
    activeTrackers[source] = nil
    BroadcastTrackerList()
end)

RegisterNetEvent('ep_tracker:server:requestTrackerList', function()
    SendTrackerList(source)
end)

RegisterNetEvent('ep_tracker:server:validateCurrentJob', function()
    local source = source

    if not activeTrackers[source] then
        return
    end

    local jobName = GetPlayerJobName(source)

    if IsJobAllowed(jobName) then
        return
    end

    DisableTracker(source, locale('notifications.job_changed_disabled'))
end)

RegisterNetEvent('ep_tracker:server:setPatrolId', function(value)
    local source = source

    if not IsJobAllowed(GetPlayerJobName(source)) then
        TriggerClientEvent('ep_tracker:client:notAuthorized', source, locale('notifications.not_authorized'))
        return
    end

    local patrolId = SanitizePatrolId(value)

    if not patrolId then
        TriggerClientEvent('ep_tracker:client:notify', source, locale('notifications.invalid_patrol_id'), 'error')
        return
    end

    patrolIds[source] = patrolId
    SaveStoredPatrolId(source, patrolId)

    TriggerClientEvent('ep_tracker:client:notify', source, locale('notifications.patrol_id_updated'), 'success')

    if next(activeTrackers) ~= nil then
        BroadcastTrackerList()
        StartTrackerBroadcastThread()
    end
end)

local function ResolvePlayerId(value)
    if type(value) == 'table' then
        local playerData = value.PlayerData or value
        return tonumber(playerData.source or value.source)
    end

    return tonumber(value)
end

local function HandleFrameworkJobUpdate(playerId, job)
    playerId = ResolvePlayerId(playerId)

    if not playerId then
        return
    end

    if not activeTrackers[playerId] then
        SendTrackerList(playerId)
        return
    end

    local jobName = job and job.name or GetPlayerJobName(playerId)

    if IsJobAllowed(jobName) then
        BroadcastTrackerList()
        return
    end

    DisableTracker(playerId, locale('notifications.job_changed_disabled'))
    SendTrackerList(playerId)
end

local function HandleFrameworkPlayerLoaded(playerId)
    playerId = ResolvePlayerId(playerId)

    if not playerId then
        return
    end

    LoadStoredPatrolId(playerId)
    SendTrackerList(playerId)
end

AddEventHandler('esx:setJob', HandleFrameworkJobUpdate)
AddEventHandler('esx:playerLoaded', HandleFrameworkPlayerLoaded)

AddEventHandler('QBCore:Server:OnJobUpdate', HandleFrameworkJobUpdate)
AddEventHandler('QBCore:Server:PlayerLoaded', HandleFrameworkPlayerLoaded)
AddEventHandler('QBCore:Server:OnPlayerLoaded', HandleFrameworkPlayerLoaded)

AddEventHandler('qbx_core:server:onJobUpdate', HandleFrameworkJobUpdate)
AddEventHandler('qbx_core:server:playerLoaded', HandleFrameworkPlayerLoaded)

RegisterNetEvent('ep_tracker:server:playerLoaded', function()
    HandleFrameworkPlayerLoaded(source)
end)

AddEventHandler('playerDropped', function()
    activeTrackers[source] = nil
    patrolIds[source] = nil
    BroadcastTrackerList()
end)
