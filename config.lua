Config = {}

Config.Framework = 'esx' -- auto, esx, qbcore, qbx
Config.Locale = 'en' -- auto, fi, en

Config.AllowedJobs = {
    police = true,
    lspd = false,
    sheriff = true,
    ambulance = true,
    sasp = false,
    lssd = false
}

Config.JobColours = {
    police = 3, --- 3 on sininen / blue
    lspd = 3,
    sheriff = 3,
    sasp = 3,
    lssd = 3,
    ambulance = 1 --- 1 on punainen / red
}

Config.PedCheckInterval = 1000 --- 1000ms = 1s
Config.TrackerSyncInterval = 1000 --- 1000ms = 1s

Config.Commands = {
    menu = 'tracker', --- to open the menu
    enable = 'trackeron',
    disable = 'trackeroff'
}

Config.Persistence = {
    enabled = true,
    keyPrefix = 'patrol_id:'
}

Config.Blip = {
    sprite = 1, --- 1 on sininen / blue
    colour = 3, --- 3 on sininen / blue
    scale = 0.85,
    shortRange = false,
    display = 4,
    showHeading = true,
    nameFormat = '%s | %s',
    defaultPatrolIdFormat = '%03d',
    useVehicleSprites = true,
    vehicleSprites = {
        default = 1,
        bicycle = 348,
        motorcycle = 226,
        car = 225,
        boat = 427,
        helicopter = 43,
        plane = 423,
        train = 795,
        classes = {
            [0] = 225, -- Compacts
            [1] = 225, -- Sedans
            [2] = 225, -- SUVs
            [3] = 225, -- Coupes
            [4] = 225, -- Muscle
            [5] = 225, -- Sports Classics
            [6] = 225, -- Sports
            [7] = 225, -- Super
            [8] = 226, -- Motorcycles
            [9] = 225, -- Off-road
            [10] = 225, -- Industrial
            [11] = 225, -- Utility
            [12] = 225, -- Vans
            [13] = 348, -- Cycles
            [14] = 427, -- Boats
            [15] = 43, -- Helicopters
            [16] = 423, -- Planes
            [17] = 225, -- Service
            [18] = 225, -- Emergency
            [19] = 225, -- Military
            [20] = 225, -- Commercial
            [21] = 795, -- Trains
            [22] = 225 -- Open Wheel
        }
    }
}
