local trackerEnabled = false
local trackerThreadRunning = false
local trackedPlayers = {}
local trackerBlips = {}

lib.locale(Config.Locale ~= 'auto' and Config.Locale or nil)

local trackerSettings = {
    sprite = Config.Blip.sprite,
    colour = Config.Blip.colour,
    scale = Config.Blip.scale,
    name = locale('blip.default_name'),
    shortRange = Config.Blip.shortRange,
    display = Config.Blip.display,
    showHeading = Config.Blip.showHeading,
    pedCheckInterval = Config.PedCheckInterval
}

local function Notify(message, notifyType)
    lib.notify({
        description = message,
        type = notifyType or 'inform'
    })
end

local function GetTrackerName()
    return trackerSettings.name
end

local function GetVehicleSpriteForPed(ped)
    local blipConfig = Config.Blip or {}
    local vehicleSpriteConfig = blipConfig.vehicleSprites or {}

    if blipConfig.useVehicleSprites == false or not ped or not DoesEntityExist(ped) then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        return vehicleSpriteConfig.default or trackerSettings.sprite
    end

    local vehicleClass = GetVehicleClass(vehicle)
    local classSprites = vehicleSpriteConfig.classes or {}

    return classSprites[vehicleClass] or vehicleSpriteConfig.default or trackerSettings.sprite
end

local function GetTrackerSprite(tracker)
    return tracker.sprite or trackerSettings.sprite
end

local function ApplyTrackerSettings(serverId)
    local tracker = trackerBlips[serverId]

    if not tracker or not DoesBlipExist(tracker.blip) then
        return
    end

    SetBlipSprite(tracker.blip, GetTrackerSprite(tracker))
    SetBlipColour(tracker.blip, tracker.colour or trackerSettings.colour)
    SetBlipScale(tracker.blip, trackerSettings.scale)
    SetBlipAsShortRange(tracker.blip, trackerSettings.shortRange)
    SetBlipDisplay(tracker.blip, trackerSettings.display)
    ShowHeadingIndicatorOnBlip(tracker.blip, trackerSettings.showHeading == true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(tracker.name or GetTrackerName())
    EndTextCommandSetBlipName(tracker.blip)
end

local function RemoveTrackerBlip(serverId)
    local tracker = trackerBlips[serverId]

    if not tracker then
        return
    end

    if DoesBlipExist(tracker.blip) then
        RemoveBlip(tracker.blip)
    end

    trackerBlips[serverId] = nil
end

local function RemoveAllTrackerBlips()
    for serverId in pairs(trackerBlips) do
        RemoveTrackerBlip(serverId)
    end
end

local function CreateTrackerBlip(serverId, name, coords, colour, sprite)
    local player = GetPlayerFromServerId(serverId)
    local playerPed = nil

    if player ~= -1 then
        playerPed = GetPlayerPed(player)
    end

    if playerPed and DoesEntityExist(playerPed) then
        trackerBlips[serverId] = {
            blip = AddBlipForEntity(playerPed),
            entity = playerPed,
            mode = 'entity',
            name = name or GetTrackerName(),
            colour = colour,
            sprite = GetVehicleSpriteForPed(playerPed) or sprite
        }

        ApplyTrackerSettings(serverId)
        return
    end

    if not coords then
        return
    end

    trackerBlips[serverId] = {
        blip = AddBlipForCoord(coords.x, coords.y, coords.z),
        entity = nil,
        mode = 'coords',
        name = name or GetTrackerName(),
        colour = colour,
        sprite = sprite
    }

    ApplyTrackerSettings(serverId)
end

local function UpdateTrackerBlip(serverId, name, coords, colour, sprite)
    local tracker = trackerBlips[serverId]

    if not tracker or not DoesBlipExist(tracker.blip) then
        CreateTrackerBlip(serverId, name, coords, colour, sprite)
        return
    end

    local nextName = name or tracker.name
    local nextColour = colour or tracker.colour
    local nextSprite = sprite or tracker.sprite

    if tracker.name ~= nextName or tracker.colour ~= nextColour or tracker.sprite ~= nextSprite then
        tracker.name = nextName
        tracker.colour = nextColour
        tracker.sprite = nextSprite
        ApplyTrackerSettings(serverId)
    end

    local player = GetPlayerFromServerId(serverId)

    if player == -1 then
        if coords then
            if tracker.mode ~= 'coords' then
                RemoveTrackerBlip(serverId)
                CreateTrackerBlip(serverId, name, coords, colour, sprite)
                return
            end

            SetBlipCoords(tracker.blip, coords.x, coords.y, coords.z)
        end

        return
    end

    local playerPed = GetPlayerPed(player)

    if not DoesEntityExist(playerPed) then
        if coords then
            if tracker.mode ~= 'coords' then
                RemoveTrackerBlip(serverId)
                CreateTrackerBlip(serverId, name, coords, colour, sprite)
                return
            end

            SetBlipCoords(tracker.blip, coords.x, coords.y, coords.z)
        end

        return
    end

    if tracker.mode ~= 'entity' or tracker.entity ~= playerPed then
        RemoveTrackerBlip(serverId)
        CreateTrackerBlip(serverId, name, coords, colour, sprite)
        return
    end

    local entitySprite = GetVehicleSpriteForPed(playerPed)

    if entitySprite and tracker.sprite ~= entitySprite then
        tracker.sprite = entitySprite
        ApplyTrackerSettings(serverId)
    end
end

local function StartTrackerThread()
    if trackerThreadRunning then
        return
    end

    trackerThreadRunning = true

    CreateThread(function()
        while next(trackedPlayers) ~= nil do
            for serverId, tracker in pairs(trackedPlayers) do
                UpdateTrackerBlip(serverId, tracker.name, tracker.coords, tracker.colour, tracker.sprite)
            end

            Wait(tonumber(trackerSettings.pedCheckInterval) or Config.PedCheckInterval)
        end

        trackerThreadRunning = false
    end)
end

local function EnableTracker()
    if trackerEnabled then
        return
    end

    trackerEnabled = true
    Notify(locale('notifications.enabled'), 'success')
end

local function DisableTracker(shouldNotify, message, shouldNotifyServer)
    local wasEnabled = trackerEnabled

    if shouldNotifyServer then
        TriggerServerEvent('ep_tracker:server:requestDisable')
    end

    if not wasEnabled and not next(trackerBlips) then
        return
    end

    trackerEnabled = false

    if shouldNotify then
        Notify(message or locale('notifications.disabled'), 'inform')
    end
end

local function RequestTrackerEnable()
    TriggerServerEvent('ep_tracker:server:requestEnable')
end

local function RequestTrackerList()
    TriggerServerEvent('ep_tracker:server:requestTrackerList')
end

local function SetPatrolId()
    local input = lib.inputDialog(locale('input.patrol_id_title'), {
        {
            type = 'input',
            label = locale('input.patrol_id_label'),
            description = locale('input.patrol_id_description'),
            required = true,
            min = 1,
            max = 10
        }
    })

    if not input or not input[1] then
        return
    end

    TriggerServerEvent('ep_tracker:server:setPatrolId', input[1])
end

local function OpenTrackerMenu()
    lib.registerContext({
        id = 'ep_tracker_menu',
        title = locale('menu.title'),
        options = {
            {
                title = trackerEnabled and locale('menu.disable_title') or locale('menu.enable_title'),
                description = trackerEnabled and locale('menu.disable_description') or locale('menu.enable_description'),
                icon = trackerEnabled and 'toggle-off' or 'toggle-on',
                onSelect = function()
                    if trackerEnabled then
                        DisableTracker(true, nil, true)
                        return
                    end

                    RequestTrackerEnable()
                end
            },
            {
                title = locale('menu.change_patrol_id_title'),
                description = locale('menu.change_patrol_id_description'),
                icon = 'arrow-down-wide-short',
                onSelect = SetPatrolId
            }
        }
    })

    lib.showContext('ep_tracker_menu')
end

local function RegisterConfiguredCommand(commandName, callback)
    if not commandName or commandName == '' then
        return
    end

    RegisterCommand(commandName, callback, false)
end

local commandConfig = Config.Commands or {}

RegisterConfiguredCommand(commandConfig.menu or 'tracker', function()
    OpenTrackerMenu()
end)

RegisterConfiguredCommand(commandConfig.enable or 'trackeronn', function()
    if trackerEnabled then
        return
    end

    RequestTrackerEnable()
end)

RegisterConfiguredCommand(commandConfig.disable or 'trackeroff', function()
    DisableTracker(true, nil, true)
end)

RegisterNetEvent('ep_tracker:client:setEnabled', function(enabled)
    if enabled then
        EnableTracker()
        return
    end

    DisableTracker(true, nil, false)
end)

RegisterNetEvent('ep_tracker:client:forceDisable', function(message)
    DisableTracker(true, message or locale('notifications.job_changed_disabled'), false)
end)

RegisterNetEvent('ep_tracker:client:notAuthorized', function(message)
    DisableTracker(false, nil, false)
    Notify(message or locale('notifications.not_authorized'), 'error')
end)

RegisterNetEvent('ep_tracker:client:notify', function(message, notifyType)
    Notify(message, notifyType)
end)

RegisterNetEvent('ep_tracker:client:updateTrackers', function(trackers)
    local activeServerIds = {}
    trackedPlayers = {}

    for _, tracker in ipairs(trackers or {}) do
        local serverId = tonumber(tracker.source)

        if serverId then
            activeServerIds[serverId] = true
            trackedPlayers[serverId] = {
                name = tracker.name or GetTrackerName(),
                coords = tracker.coords,
                colour = tracker.colour,
                sprite = tracker.sprite
            }

            UpdateTrackerBlip(serverId, tracker.name, tracker.coords, tracker.colour, tracker.sprite)
        end
    end

    for serverId in pairs(trackerBlips) do
        if not activeServerIds[serverId] then
            RemoveTrackerBlip(serverId)
        end
    end

    if next(trackedPlayers) ~= nil then
        StartTrackerThread()
    end
end)

FrameworkClient.RegisterEvents(function()
    RequestTrackerList()
end, function()
    if not trackerEnabled then
        RequestTrackerList()
        return
    end

    TriggerServerEvent('ep_tracker:server:validateCurrentJob')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    RequestTrackerList()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    trackerEnabled = false
    trackedPlayers = {}
    RemoveAllTrackerBlips()
end)

-- Future NUI callbacks can update trackerSettings.sprite, trackerSettings.colour,
-- trackerSettings.scale, trackerSettings.name, and trackerSettings.showHeading,
-- then call ApplyTrackerSettings().
