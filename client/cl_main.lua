local Config = require('config')
local spawnedPeds = {}
local spawnedVehicles = {}
local createdBlips = {}
local currentTestDrive = nil

local function CreateDealerBlips()
    for _, location in pairs(Config.DealerLocations) do
        if location.blip then
            local blip = AddBlipForCoord(location.ped.coords.x, location.ped.coords.y, location.ped.coords.z)
            SetBlipSprite(blip, location.blip.sprite)
            SetBlipColour(blip, location.blip.color)
            SetBlipScale(blip, location.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(location.blip.label)
            EndTextCommandSetBlipName(blip)
            createdBlips[location.id] = blip
        end
    end
end

local function SpawnDealerPed(location)
    if spawnedPeds[location.id] then return end
    
    local modelHash = lib.requestModel(location.ped.model, 5000)
    if not modelHash then
        print('^1Failed to load model: ' .. location.ped.model)
        return
    end
    
    local ped = CreatePed(4, modelHash, location.ped.coords.x, location.ped.coords.y, location.ped.coords.z - 1.0, location.ped.coords.w, false, true)
    
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    
    if location.ped.scenario then
        TaskStartScenarioInPlace(ped, location.ped.scenario, 0, true)
    end
    
    spawnedPeds[location.id] = ped
    
    local targetOptions = {
        {
            name = 'dealer_menu_' .. location.id,
            icon = 'fas fa-car',
            label = 'Browse Vehicles',
            onSelect = function()
                OpenDealerMenu(location.id)
            end,
            distance = Config.InteractionDistance
        },
        {
            name = 'dealer_manage_' .. location.id,
            icon = 'fas fa-clipboard-list',
            label = 'Manage Your Listings',
            onSelect = function()
                ManageListingsMenu(location.id)
            end,
            distance = Config.InteractionDistance
        }
    }
    
    exports.ox_target:addLocalEntity(ped, targetOptions)
end

local function DespawnDealerPed(locationId)
    local ped = spawnedPeds[locationId]
    if not ped then return end
    
    exports.ox_target:removeLocalEntity(ped, {'dealer_menu_' .. locationId, 'dealer_sell_' .. locationId, 'dealer_manage_' .. locationId})
    
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
    
    spawnedPeds[locationId] = nil
end

function RefreshDealerDisplay(locationId)
    ClearDisplayVehicles(locationId)
    
    local location = nil
    for _, loc in pairs(Config.DealerLocations) do
        if loc.id == locationId then
            location = loc
            break
        end
    end
    
    if not location then return end
    
    lib.callback('usedcardealer:getAvailableVehicles', false, function(vehicles)
        if not vehicles or #vehicles == 0 then return end
        
        if not spawnedVehicles[locationId] then
            spawnedVehicles[locationId] = {}
        end
        
        for _, spot in ipairs(location.vehicleSpots) do
            spot.occupied = false
        end
        
        for i, vehicle in ipairs(vehicles) do
            local availableSpot = nil
            for _, spot in ipairs(location.vehicleSpots) do
                if not spot.occupied then
                    availableSpot = spot
                    break
                end
            end
            
            if availableSpot then
                local modelHash = lib.requestModel(vehicle.model)
                local veh = CreateVehicle(modelHash, availableSpot.coords.x, availableSpot.coords.y, availableSpot.coords.z, availableSpot.coords.w, false, false)
                
                if veh then
                    if vehicle.props then
                        lib.setVehicleProperties(veh, vehicle.props)
                    end
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleOnGroundProperly(veh)
                    SetVehicleDoorsLocked(veh, 2)
                    SetVehicleDoorsLocked(veh, 4)
                    FreezeEntityPosition(veh, true)
                    SetEntityInvincible(veh, true)
                    SetVehicleEngineOn(veh, false, false, true)
                    SetVehicleUndriveable(veh, true)
                    SetVehicleDoorsLockedForAllPlayers(veh, true)
                    
                    availableSpot.occupied = true
                    
                    local targetOptions = {
                        {
                            name = 'view_vehicle_' .. vehicle.id,
                            icon = 'fas fa-info-circle',
                            label = 'View Details',
                            onSelect = function()
                                ViewVehicleDetails(vehicle, locationId)
                            end,
                            distance = 2.5
                        },
                    }
                    
                    exports.ox_target:addLocalEntity(veh, targetOptions)
                    
                    table.insert(spawnedVehicles[locationId], {
                        entity = veh,
                        vehicleData = vehicle
                    })
                end
            end
        end
    end, locationId)
end

RegisterNetEvent('usedcardealer:refreshDisplay', function(locationId)
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, location in pairs(Config.DealerLocations) do
        if location.id == locationId then
            local distance = #(playerCoords - vector3(location.ped.coords.x, location.ped.coords.y, location.ped.coords.z))
            if distance <= Config.SpawnDistance then
                RefreshDealerDisplay(locationId)
            end
            break
        end
    end
end)

function ClearDisplayVehicles(locationId)
    if spawnedVehicles[locationId] then
        for _, vehicleInfo in pairs(spawnedVehicles[locationId]) do
            local vehicle = vehicleInfo.entity or vehicleInfo
            if DoesEntityExist(vehicle) then
                if vehicleInfo.vehicleData then
                    exports.ox_target:removeLocalEntity(vehicle, {
                        'view_vehicle_' .. vehicleInfo.vehicleData.id,
                        'test_drive_' .. vehicleInfo.vehicleData.id,
                        'purchase_vehicle_' .. vehicleInfo.vehicleData.id
                    })
                end
                DeleteEntity(vehicle)
            end
        end
        spawnedVehicles[locationId] = {}
    end
end

CreateThread(function()
    CreateDealerBlips()
    
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(cache.ped)
        
        for _, location in pairs(Config.DealerLocations) do
            local distance = #(playerCoords - vector3(location.ped.coords.x, location.ped.coords.y, location.ped.coords.z))
            
            if distance <= Config.SpawnDistance then
                if not spawnedPeds[location.id] then
                    SpawnDealerPed(location)
                    RefreshDealerDisplay(location.id)
                end
                sleep = 500
            elseif distance > Config.SpawnDistance + 10 then
                if spawnedPeds[location.id] then
                    DespawnDealerPed(location.id)
                    ClearDisplayVehicles(location.id)
                end
            end
        end
        
        Wait(sleep)
    end
end)

function OpenDealerMenu(locationId)
    lib.callback('usedcardealer:getAvailableVehicles', false, function(vehicles)
        lib.callback('usedcardealer:getDealerCapacity', false, function(capacityInfo)
            if not vehicles or #vehicles == 0 then
                ShowNotification('No vehicles available for sale at this location', 'error')
                return
            end
            
            local options = {}
            for _, vehicle in ipairs(vehicles) do
                table.insert(options, {
                    title = vehicle.label or vehicle.model,
                    description = string.format('Price: $%s | Seller: %s', lib.math.groupdigits(vehicle.price), vehicle.sellerName or 'Unknown'),
                    icon = 'car',
                    metadata = {
                        {label = 'Plate', value = vehicle.plate},
                    },
                    onSelect = function()
                        ViewVehicleDetails(vehicle, locationId)
                    end
                })
            end
            
            local locationLabel = 'Used Car Dealer'
            for _, location in pairs(Config.DealerLocations) do
                if location.id == locationId then
                    locationLabel = location.label
                    break
                end
            end
            
            lib.registerContext({
                id = 'dealer_browse_menu',
                title = string.format('%s', locationLabel),
                options = options
            })
            
            lib.showContext('dealer_browse_menu')
        end, locationId)
    end, locationId)
end

function ViewVehicleDetails(vehicle, locationId)
    local menuOptions = {
        {
            title = 'Purchase Vehicle',
            description = string.format('Buy this %s for $%s', vehicle.label or vehicle.model, lib.math.groupdigits(vehicle.price)),
            icon = 'money-bill',
            onSelect = function()
                ConfirmPurchase(vehicle, locationId)
            end
        },
        {
            title = 'Test Drive',
            description = 'Take this vehicle for a test drive (2 minutes)',
            icon = 'road',
            onSelect = function()
                StartTestDrive(vehicle, locationId)
            end,
            disabled = currentTestDrive ~= nil
        }
    }
    
    if vehicle.description and vehicle.description ~= '' then
        table.insert(menuOptions, {
            title = 'Seller\'s Description',
            description = vehicle.description,
            icon = 'comment',
            readOnly = true
        })
    end
    
    table.insert(menuOptions, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            OpenDealerMenu(locationId)
        end
    })
    
    lib.registerContext({
        id = 'vehicle_details_menu',
        title = vehicle.label or vehicle.model,
        menu = 'dealer_browse_menu',
        options = menuOptions
    })
    
    lib.showContext('vehicle_details_menu')
end

function ConfirmPurchase(vehicle, locationId)
    local alert = lib.alertDialog({
        header = 'Confirm Purchase',
        content = string.format('Are you sure you want to purchase this %s for $%s?', 
            vehicle.label or vehicle.model, 
            lib.math.groupdigits(vehicle.price)),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Purchase',
            cancel = 'Cancel'
        }
    })
    
    if alert == 'confirm' then
        lib.callback('usedcardealer:purchaseVehicle', false, function(success, message)
            ShowNotification(message, success and 'success' or 'error')
            if success then
                lib.hideContext()
            end
        end, vehicle.id, locationId)
    end
end

function ListNewVehicleFromNearby(locationId)
    local closestVehicle = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, false)
    
    if not closestVehicle or closestVehicle == 0 then
        ShowNotification('No vehicle found nearby', 'error')
        return
    end
    
    local vehicleProps = lib.getVehicleProperties(closestVehicle)
    
    local modelHash = GetEntityModel(closestVehicle)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    if modelName then
        modelName = string.lower(modelName)
        vehicleProps.model = modelName
    end
    
    local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(modelHash))
    if vehicleLabel == 'NULL' then
        vehicleLabel = GetDisplayNameFromVehicleModel(modelHash)
    end
    
    if vehicleProps.plate then
        vehicleProps.plate = string.gsub(vehicleProps.plate, "%s+", ""):upper()
    end
    
    lib.callback('usedcardealer:checkVehicleOwnership', false, function(isOwner, message)
        if not isOwner then
            ShowNotification(message or 'You do not own this vehicle', 'error')
            return
        end
        
        local confirmList = lib.alertDialog({
            header = 'Confirm Vehicle Listing',
            content = string.format('Are you sure you want to list **%s** with plate **%s** for sale?', 
                vehicleLabel, 
                vehicleProps.plate),
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Yes, List This Vehicle',
                cancel = 'Cancel'
            }
        })
        
        if confirmList ~= 'confirm' then
            return
        end
        
        local dealerFeePercent = Config.SalesCommission * 100
        local input = lib.inputDialog('List Your Vehicle for Sale', {
            {
                type = 'number',
                label = 'Sale Price',
                description = string.format('Min: $%s | Max: $%s | Dealer Fee: %d%%', 
                    lib.math.groupdigits(Config.MinPrice), 
                    lib.math.groupdigits(Config.MaxPrice),
                    dealerFeePercent),
                required = true,
                min = Config.MinPrice,
                max = Config.MaxPrice
            },
            {
                type = 'input',
                label = 'Description',
                description = 'Add a description for your vehicle (optional)',
                required = false,
                max = 200
            }
        })
        
        if not input then return end
        
        local price = input[1]
        local description = input[2] or ''
        
        local dealerFee = math.floor(price * Config.SalesCommission)
        local youWillReceive = price - dealerFee
        
        local confirmWithFee = lib.alertDialog({
            header = string.format('List %s for $%s?', vehicleLabel, lib.math.groupdigits(price)),
            content = string.format('After the %d%% dealer fee, you will receive $%s when this vehicle sells.', 
                dealerFeePercent,
                lib.math.groupdigits(youWillReceive)
            ),
            centered = true,
            cancel = true,
            labels = {
                confirm = 'List Vehicle',
                cancel = 'Cancel'
            }
        })
        
        if confirmWithFee ~= 'confirm' then
            return
        end
        
        lib.callback('usedcardealer:listVehicle', false, function(success, message)
            ShowNotification(message, success and 'success' or 'error')
            if success then
                DeleteEntity(closestVehicle)
                ManageListingsMenu(locationId)
            end
        end, vehicleProps, price, description, locationId)
    end, vehicleProps.plate)
end

function StartTestDrive(vehicle, locationId)
    if currentTestDrive then
        ShowNotification('You are already on a test drive', 'error')
        return
    end
    
    lib.callback('usedcardealer:startTestDrive', false, function(success, message)
        if not success then
            ShowNotification(message or 'Failed to start test drive', 'error')
            return
        end
        
        local location = nil
        for _, loc in pairs(Config.DealerLocations) do
            if loc.id == locationId then
                location = loc
                break
            end
        end
        
        if not location then 
            ShowNotification('Location not found', 'error')
            return 
        end
        
        if not location.testSpawnLocation then
            ShowNotification('Test drive location not configured', 'error')
            return
        end
        
        local originalPos = GetEntityCoords(cache.ped)
        local originalHeading = GetEntityHeading(cache.ped)
        
        local modelHash = lib.requestModel(vehicle.model, 5000)
        if not modelHash then
            ShowNotification('Failed to load vehicle model', 'error')
            return
        end
        
        local spawnCoords = location.testSpawnLocation
        local testVehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
        
        if testVehicle and DoesEntityExist(testVehicle) then
            if vehicle.props then
                lib.setVehicleProperties(testVehicle, vehicle.props)
            end
            SetVehicleOnGroundProperly(testVehicle)
            SetPedIntoVehicle(cache.ped, testVehicle, -1)
            
            SetTimeout(500, function()
                local vehicleNetId = VehToNet(testVehicle)
                lib.callback.await('qbx_vehiclekeys:server:giveKeys', false, vehicleNetId)
            end)
            
            currentTestDrive = testVehicle
            ShowNotification('Test drive started! You have 2 minutes', 'success')
            
            lib.showTextUI('[Test Drive] Time Remaining: 2:00', {
                position = "right-center",
                icon = 'car',
                style = {
                    borderRadius = 5,
                    backgroundColor = '#48BB78',
                    color = 'white'
                }
            })
            
            local timeRemaining = 120
            CreateThread(function()
                while timeRemaining > 0 and DoesEntityExist(testVehicle) and currentTestDrive do
                    Wait(1000)
                    timeRemaining = timeRemaining - 1
                    
                    local minutes = math.floor(timeRemaining / 60)
                    local seconds = timeRemaining % 60
                    local timeText = string.format('[Test Drive] Time Remaining: %d:%02d', minutes, seconds)
                    
                    local bgColor = '#48BB78'
                    if timeRemaining <= 30 then
                        bgColor = '#F56565'
                    elseif timeRemaining <= 60 then
                        bgColor = '#ED8936'
                    end
                    
                    lib.showTextUI(timeText, {
                        position = "right-center",
                        icon = 'car',
                        style = {
                            borderRadius = 5,
                            backgroundColor = bgColor,
                            color = 'white'
                        }
                    })
                    
                    if GetVehiclePedIsIn(cache.ped, false) ~= testVehicle then
                        ShowNotification('Test drive ended - You left the vehicle', 'info')
                        break
                    end
                end
                
                lib.hideTextUI()
                
                SetEntityCoords(cache.ped, originalPos.x, originalPos.y, originalPos.z, false, false, false, false)
                SetEntityHeading(cache.ped, originalHeading)
                
                if DoesEntityExist(testVehicle) then
                    DeleteEntity(testVehicle)
                end
                currentTestDrive = nil
                
                if timeRemaining <= 0 then
                    ShowNotification('Test drive time expired - Returned to dealership', 'info')
                else
                    ShowNotification('Test drive ended - Returned to dealership', 'success')
                end
            end)
        else
            ShowNotification('Failed to spawn test vehicle', 'error')
        end
    end, vehicle.id)
end

function ManageListingsMenu(locationId)
    lib.callback('usedcardealer:getPlayerListings', false, function(listings)
        lib.callback('usedcardealer:getDealerCapacity', false, function(capacityInfo)
            local options = {}
            
            table.insert(options, {
                title = 'List New Vehicle',
                description = capacityInfo.isFull and 
                    string.format('Dealer is FULL (%d/%d vehicles)', capacityInfo.current, capacityInfo.max) or
                    string.format('List a vehicle you own for sale (%d/%d spots used)', capacityInfo.current, capacityInfo.max),
                icon = 'fas fa-plus-circle',
                iconColor = capacityInfo.isFull and 'red' or 'green',
                disabled = capacityInfo.isFull,
                onSelect = function()
                    ListNewVehicleFromNearby(locationId)
                end
            })
            
            for _, listing in ipairs(listings) do
                local status = listing.sold and 'SOLD' or (listing.active and 'ACTIVE' or 'INACTIVE')
                local statusIcon = listing.sold and 'check-circle' or (listing.active and 'circle' or 'times-circle')
                local isCorrectDealer = listing.locationId == locationId
                
                local description = string.format('Price: $%s | Dealer: %s', 
                    lib.math.groupdigits(listing.price), 
                    listing.dealerLabel or 'Unknown')
                
                if not isCorrectDealer and listing.active and not listing.sold then
                    description = description .. '\nYou must be at the correct dealer to modify.'
                end
                
                table.insert(options, {
                    title = string.format('%s - %s', listing.label or listing.model, status),
                    description = description,
                    icon = statusIcon,
                    iconColor = listing.sold and '#4ade80' or (listing.active and '#3b82f6' or '#ef4444'),
                    disabled = listing.sold or not listing.active or not isCorrectDealer,
                    onSelect = function()
                        ManageSingleListing(listing, locationId)
                    end,
                    metadata = listing.sold and {
                        {label = 'Buyer', value = listing.buyerName or 'Unknown'},
                        {label = 'Sold Date', value = listing.soldDate or 'Unknown'}
                    } or nil
                })
            end
            
            lib.registerContext({
                id = 'manage_listings_menu',
                title = 'Your Vehicle Listings',
                options = options
            })
            
            lib.showContext('manage_listings_menu')
        end, locationId)
    end, locationId)
end

function ManageSingleListing(listing, locationId)
    local isCorrectDealer = listing.locationId == locationId
    
    local options = {}
    
    if isCorrectDealer then
        table.insert(options, {
            title = 'Update Price',
            description = 'Change the asking price',
            icon = 'edit',
            onSelect = function()
                UpdateListingPrice(listing.id, locationId)
            end
        })
        
        table.insert(options, {
            title = 'Remove Listing',
            description = 'Remove this vehicle from sale and retrieve it',
            icon = 'times',
            iconColor = '#ef4444',
            onSelect = function()
                RemoveListing(listing.id, locationId)
            end
        })
    else
        table.insert(options, {
            title = 'Vehicle Information',
            description = string.format('This vehicle is listed at: %s\nYou must go to that dealer to manage this listing.', listing.dealerLabel or 'Unknown'),
            icon = 'info-circle',
            iconColor = '#fbbf24',
            readOnly = true
        })
    end
    
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            ManageListingsMenu(locationId)
        end
    })
    
    lib.registerContext({
        id = 'manage_single_listing',
        title = listing.label or listing.model,
        menu = 'manage_listings_menu',
        options = options
    })
    
    lib.showContext('manage_single_listing')
end

function UpdateListingPrice(listingId, locationId)
    local input = lib.inputDialog('Update Price', {
        {
            type = 'number',
            label = 'New Price',
            description = string.format('Set new price (Min: $%s, Max: $%s)', 
                lib.math.groupdigits(Config.MinPrice), 
                lib.math.groupdigits(Config.MaxPrice)),
            required = true,
            min = Config.MinPrice,
            max = Config.MaxPrice,
            icon = 'dollar-sign'
        }
    })
    
    if not input then return end
    
    lib.callback('usedcardealer:updatePrice', false, function(success, message)
        ShowNotification(message, success and 'success' or 'error')
        if success then
            ManageListingsMenu(locationId)
        end
    end, listingId, input[1])
end

function RemoveListing(listingId, locationId)
    local alert = lib.alertDialog({
        header = 'Remove Listing',
        content = 'Are you sure you want to remove this listing? Your vehicle will be returned to you.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Remove',
            cancel = 'Cancel'
        }
    })
    
    if alert == 'confirm' then
        lib.callback('usedcardealer:removeListing', false, function(success, message, vehicleProps)
            ShowNotification(message, success and 'success' or 'error')
            if success and vehicleProps then
                local location = nil
                for _, loc in pairs(Config.DealerLocations) do
                    if loc.id == locationId then
                        location = loc
                        break
                    end
                end
                
                if not location then 
                    ShowNotification('Location not found', 'error')
                    return 
                end
                
                if not location.returnListingVehicleSpawn then
                    ShowNotification('Return spawn location not configured', 'error')
                    return
                end
                
                local spawnCoords = location.returnListingVehicleSpawn
                
                local modelHash = lib.requestModel(vehicleProps.model, 5000)
                if modelHash then
                    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
                    if vehicle and DoesEntityExist(vehicle) then
                        lib.setVehicleProperties(vehicle, vehicleProps)
                        SetVehicleNumberPlateText(vehicle, vehicleProps.plate)
                        SetPedIntoVehicle(cache.ped, vehicle, -1)
                        
                        SetTimeout(500, function()
                            local vehicleNetId = VehToNet(vehicle)
                            lib.callback.await('qbx_vehiclekeys:server:giveKeys', false, vehicleNetId)
                        end)
                        
                        ShowNotification('Your vehicle has been returned!', 'success')
                    else
                        ShowNotification('Failed to spawn vehicle', 'error')
                    end
                else
                    ShowNotification('Failed to load vehicle model', 'error')
                end
                
                ManageListingsMenu(locationId)
            end
        end, listingId)
    end
end

RegisterNetEvent('usedcardealer:vehicleSold', function(data)
    ShowNotification(string.format('Your %s has been sold for $%s! Commission: $%s', 
        data.vehicleLabel, 
        lib.math.groupdigits(data.salePrice), 
        lib.math.groupdigits(data.commission)
    ), 'success')
    
    PlaySoundFrontend(-1, 'PROPERTY_PURCHASE', 'HUD_AWARDS', false)
end)

RegisterNetEvent('usedcardealer:spawnPurchasedVehicle', function(vehicleProps, locationId)
    local location = nil
    for _, loc in pairs(Config.DealerLocations) do
        if loc.id == locationId then
            location = loc
            break
        end
    end
    
    if not location then 
        ShowNotification('Location not found', 'error')
        return 
    end
    
    if not location.purchasedVehicleSpawn then
        ShowNotification('Purchase spawn location not configured', 'error')
        return
    end
    
    local spawnCoords = location.purchasedVehicleSpawn
    
    local modelHash = lib.requestModel(vehicleProps.model, 5000)
    if not modelHash then
        ShowNotification('Failed to load vehicle model', 'error')
        return
    end
    
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    if vehicle and DoesEntityExist(vehicle) then
        lib.setVehicleProperties(vehicle, vehicleProps)
        
        SetVehicleNumberPlateText(vehicle, vehicleProps.plate)
        
        SetPedIntoVehicle(cache.ped, vehicle, -1)
        
        SetTimeout(500, function()
            local vehicleNetId = VehToNet(vehicle)
            lib.callback.await('qbx_vehiclekeys:server:giveKeys', false, vehicleNetId)
        end)
        
        ShowNotification('Your purchased vehicle has been delivered!', 'success')
        PlaySoundFrontend(-1, 'PROPERTY_PURCHASE', 'HUD_AWARDS', false)
    else
        ShowNotification('Failed to spawn vehicle', 'error')
    end
end)

RegisterNetEvent('usedcardealer:refreshDisplay', function(locationId)
    if locationId and spawnedVehicles[locationId] then
        ClearDisplayVehicles(locationId)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for locationId, ped in pairs(spawnedPeds) do
        DespawnDealerPed(locationId)
    end
    
    for _, blip in pairs(createdBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    for locationId, _ in pairs(spawnedVehicles) do
        ClearDisplayVehicles(locationId)
    end
    
    if currentTestDrive and DoesEntityExist(currentTestDrive) then
        DeleteEntity(currentTestDrive)
    end
end)