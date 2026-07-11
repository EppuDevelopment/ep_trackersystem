FrameworkClient = FrameworkClient or {}

local function GetPreferredFramework()
    local framework = Config.Framework or 'auto'

    if type(framework) ~= 'string' then
        return 'auto'
    end

    return framework:lower()
end

local function ShouldRegister(frameworkName)
    local preferredFramework = GetPreferredFramework()

    return preferredFramework == 'auto' or preferredFramework == frameworkName
end

function FrameworkClient.RegisterEvents(onPlayerLoaded, onJobUpdated)
    local preferredFramework = GetPreferredFramework()
    local registerQBCoreEvents = preferredFramework == 'auto' or preferredFramework == 'qbcore' or preferredFramework == 'qb' or preferredFramework == 'qbx'

    if ShouldRegister('esx') then
        AddEventHandler('esx:playerLoaded', function()
            onPlayerLoaded()
        end)

        AddEventHandler('esx:setJob', function()
            onJobUpdated()
        end)
    end

    if registerQBCoreEvents then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            onPlayerLoaded()
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
            onJobUpdated()
        end)
    end

    if ShouldRegister('qbx') then
        RegisterNetEvent('qbx_core:client:playerLoaded', function()
            onPlayerLoaded()
        end)

        RegisterNetEvent('qbx_core:client:onJobUpdate', function()
            onJobUpdated()
        end)
    end
end
