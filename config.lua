return {
    -- General Settings
    SpawnDistance = 150.0, -- Distance at which peds spawn
    InteractionDistance = 2.5, -- Distance for interaction with peds

    -- Used Car Dealer Locations with Peds
    DealerLocations = {
        {
            id = 'sandy_dealer',
            label = 'Sandy Used Cars',
            ped = {
                model = 'a_m_m_business_01',
                coords = vector4(1224.78, 2728.01, 38.0, 180.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
            blip = {
                sprite = 225,
                color = 3,
                scale = 0.7,
                label = 'Used Car Dealer - Sandy'
            },
            testSpawnLocation = vector4(1248.07, 2714.82, 38.01, 191.09),
            purchasedVehicleSpawn = vector4(1209.78, 2711.48, 38.0, 180.0),
            returnListingVehicleSpawn = vector4(1214.52, 2711.48, 38.0, 180.0),
            vehicleSpots = {
                {coords = vector4(1237.07, 2699.0, 38.27, 1.5), occupied = false},
                {coords = vector4(1232.98, 2698.92, 38.27, 2.5), occupied = false},
                {coords = vector4(1228.9, 2698.78, 38.27, 3.5), occupied = false},
                {coords = vector4(1224.9, 2698.51, 38.27, 2.5), occupied = false},
                {coords = vector4(1220.93, 2698.28, 38.27, 2.5), occupied = false},
                {coords = vector4(1216.97, 2698.05, 38.27, 0.5), occupied = false},
                {coords = vector4(1216.67, 2709.21, 38.27, 1.5), occupied = false},
                {coords = vector4(1220.67, 2709.26, 38.27, 1.5), occupied = false},
                {coords = vector4(1224.53, 2709.27, 38.27, 2.5), occupied = false},
                {coords = vector4(1228.52, 2709.42, 38.27, 1.5), occupied = false},
                {coords = vector4(1232.53, 2709.49, 38.27, 1.5), occupied = false},
                {coords = vector4(1236.71, 2709.51, 38.27, 1.6), occupied = false},
                {coords = vector4(1216.41, 2717.99, 38.27, 1.5), occupied = false},
                {coords = vector4(1220.39, 2718.0, 38.27, 0.5), occupied = false},
                {coords = vector4(1224.35, 2718.07, 38.27, 1.5), occupied = false},
                {coords = vector4(1228.41, 2718.22, 38.27, 1.5), occupied = false},
                {coords = vector4(1249.63, 2707.84, 38.27, 99.5), occupied = false},
                {coords = vector4(1248.92, 2712.25, 38.27, 101.5), occupied = false},
                {coords = vector4(1247.3, 2716.59, 38.27, 120.5), occupied = false},
                {coords = vector4(1244.09, 2720.4, 38.27, 149.5), occupied = false},
                {coords = vector4(1239.93, 2722.39, 38.27, 163.5), occupied = false},
                {coords = vector4(1248.28, 2727.41, 38.53, 338.5), occupied = false},
                {coords = vector4(1251.84, 2725.65, 38.52, 331.5), occupied = false},
                {coords = vector4(1255.19, 2723.21, 38.44, 309.5), occupied = false},
                {coords = vector4(1257.28, 2719.77, 38.49, 296.5), occupied = false},
            }
        },
        {
            id = 'city_dealer',
            label = 'Los Santos Used Cars',
            ped = {
                model = 's_m_m_autoshop_01',
                coords = vector4(-26.58, -1672.37, 29.49, 145.44),
                scenario = 'WORLD_HUMAN_AA_COFFEE',
            },
            blip = {
                sprite = 225,
                color = 3,
                scale = 0.7,
                label = 'Used Car Dealer - City'
            },
            testSpawnLocation = vector4(-23.13, -1678.88, 29.46, 112.14),
            purchasedVehicleSpawn = vector4(-23.13, -1678.88, 29.46, 112.14),
            returnListingVehicleSpawn = vector4(-23.13, -1678.88, 29.46, 112.14),
            vehicleSpots = {
                {coords = vector4(-50.1711, -1675.8868, 29.2086, 262.01), occupied = false},
                {coords = vector4(-53.7389, -1678.6947, 29.0351, 262.18), occupied = false},
                {coords = vector4(-56.1510, -1681.3383, 28.7754, 261.71), occupied = false},
                {coords = vector4(-58.2071, -1683.7433, 29.0691, 256.02), occupied = false},
                {coords = vector4(-60.5399, -1687.0262, 28.7823, 278.62), occupied = false},
                {coords = vector4(-57.7724, -1689.8744, 28.7822, 313.96), occupied = false},
                {coords = vector4(-55.1575, -1692.8951, 29.0553, 356.50), occupied = false},
                {coords = vector4(-51.6922, -1694.1602, 29.0687, 358.82), occupied = false},
                {coords = vector4(-48.4373, -1692.2284, 29.0187, 359.84), occupied = false},
                {coords = vector4(-45.0339, -1691.1814, 29.0447, 355.76), occupied = false},
                {coords = vector4(-41.2019, -1689.6267, 28.5520, 355.78), occupied = false},
            }
        }
    },

    -- Commission Settings
    SalesCommission = 0.05, -- 10% commission for selling vehicles
    MinPrice = 1000, -- Minimum price for a vehicle
    MaxPrice = 999999, -- Maximum price for a vehicle

    -- Vehicle Categories (for filtering)
    VehicleCategories = {
        ['compact'] = 'Compact',
        ['sedan'] = 'Sedans',
        ['suv'] = 'SUVs',
        ['coupe'] = 'Coupes',
        ['muscle'] = 'Muscle',
        ['sport'] = 'Sports',
        ['super'] = 'Super',
        ['motorcycle'] = 'Motorcycles',
        ['offroad'] = 'Off-road',
        ['van'] = 'Vans'
    }
}