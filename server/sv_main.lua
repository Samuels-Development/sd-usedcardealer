local Config = require('config')
local vehicleListings = {}
local playerListings = {}

local Banking = {}

Banking.GetPlayerAccount = function(identifier)
    local accountData = exports['RxBanking']:GetPlayerPersonalAccount(identifier)
    if type(accountData) == "table" then
        return accountData.iban
    elseif type(accountData) == "string" then
        return accountData
    end
    return nil
end

CreateThread(function()
    local success, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS usedcar_listings (
                id INT AUTO_INCREMENT PRIMARY KEY,
                seller_id VARCHAR(255) NOT NULL,
                location_id VARCHAR(50) NOT NULL,
                data JSON NOT NULL,
                active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_seller (seller_id),
                INDEX idx_location (location_id),
                INDEX idx_active (active)
            );
        ]])
    end)
    
    if not success then
        print("^1Error creating usedcar_listings table: " .. err)
    else
        print("^2Used car dealer database initialized successfully")
        LoadListings()
    end
end)

function LoadListings()
    local listings = MySQL.query.await('SELECT * FROM usedcar_listings WHERE active = 1', {})
    if listings then
        for _, listing in pairs(listings) do
            local data = json.decode(listing.data)
            
            if not vehicleListings[listing.location_id] then
                vehicleListings[listing.location_id] = {}
            end
            
            local listingData = {
                id = listing.id,
                sellerIdentifier = listing.seller_id,
                sellerName = data.sellerName,
                sellerIban = data.sellerIban,
                model = data.model,
                label = data.label,
                plate = data.plate,
                props = data.props,
                price = data.price,
                description = data.description,
                locationId = listing.location_id,
                listedAt = listing.created_at
            }
            
            table.insert(vehicleListings[listing.location_id], listingData)
            
            if not playerListings[listing.seller_id] then
                playerListings[listing.seller_id] = {}
            end
            table.insert(playerListings[listing.seller_id], listing.id)
        end
        print("^2Loaded " .. #listings .. " active vehicle listings")
    end
end

function GetVehicleLabel(model)
    return model:sub(1, 1):upper() .. model:sub(2)
end

function CreateListingData(sellerId, sellerName, vehicleProps, price, description)
    return {
        seller_id = sellerId,
        seller_name = sellerName,
        vehicle = {
            model = vehicleProps.model,
            label = GetVehicleLabel(vehicleProps.model),
            plate = vehicleProps.plate,
            props = vehicleProps
        },
        price = price,
        description = description,
        history = {
            listed_at = os.date('%Y-%m-%d %H:%M:%S'),
            price_changes = {}
        }
    }
end

lib.callback.register('usedcardealer:getAvailableVehicles', function(source, locationId)
    if not vehicleListings[locationId] then
        return {}
    end
    
    local vehicles = {}
    for _, listing in ipairs(vehicleListings[locationId]) do
        local mileage = exports["jg-vehiclemileage"]:GetMileage(listing.plate)
        if not mileage or mileage == false then
            mileage = 0
        end
        
        table.insert(vehicles, {
            id = listing.id,
            sellerName = listing.sellerName,
            model = listing.model,
            label = listing.label or listing.model,
            plate = listing.plate,
            price = listing.price,
            description = listing.description,
            mileage = mileage,
            props = listing.props
        })
    end
    
    return vehicles
end)

lib.callback.register('usedcardealer:purchaseVehicle', function(source, vehicleId, locationId)
    local buyerId = GetIdentifier(source)
    local buyerName = GetFullName(source)
    
    if not buyerId then
        return false, 'Player not found'
    end
    
    local listing = nil
    local listingIndex = nil
    
    if vehicleListings[locationId] then
        for i, veh in ipairs(vehicleListings[locationId]) do
            if veh.id == vehicleId then
                listing = veh
                listingIndex = i
                break
            end
        end
    end
    
    if not listing then
        return false, 'Vehicle not found'
    end
    
    local bankFunds = Money.GetPlayerAccountFunds(source, 'bank')
    local cashFunds = Money.GetPlayerAccountFunds(source, 'cash')
    
    if bankFunds >= listing.price then
        Money.RemoveMoney(source, 'bank', listing.price)
    elseif cashFunds >= listing.price then
        Money.RemoveMoney(source, 'cash', listing.price)
    else
        return false, 'Insufficient funds'
    end
    
    local cleanPlate = listing.plate:gsub("^%s*(.-)%s*$", "%1"):upper()
    
    local modelName = listing.model
    if type(modelName) == 'number' then
        modelName = listing.props.model or tostring(modelName)
    end
    
    MySQL.insert.await([[
        INSERT INTO player_vehicles (
            citizenid, vehicle, hash, mods, plate, 
            garage, fuel, engine, body, state, 
            in_garage, garage_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        buyerId,
        modelName,
        tostring(GetHashKey(modelName)),
        json.encode(listing.props),
        cleanPlate,
        'pillboxgarage',
        listing.props.fuelLevel or 100,
        listing.props.engineHealth or 1000,
        listing.props.bodyHealth or 1000,
        0,
        0,
        'pillboxgarage'
    })
    
    local currentData = MySQL.single.await('SELECT data FROM usedcar_listings WHERE id = ?', {vehicleId})
    if currentData then
        local data = json.decode(currentData.data)
        data.sold = {
            buyer_id = buyerId,
            buyer_name = buyerName,
            sold_at = os.date('%Y-%m-%d %H:%M:%S'),
            final_price = listing.price
        }
        
        MySQL.update.await('UPDATE usedcar_listings SET active = 0, data = ? WHERE id = ?', {
            json.encode(data),
            vehicleId
        })
    end
    
    table.remove(vehicleListings[locationId], listingIndex)
    
    if playerListings[listing.sellerIdentifier] then
        for i, id in ipairs(playerListings[listing.sellerIdentifier]) do
            if id == vehicleId then
                table.remove(playerListings[listing.sellerIdentifier], i)
                break
            end
        end
    end
    
    local commission = math.floor(listing.price * Config.SalesCommission)
    local sellerAmount = listing.price - commission
    
    local sellerIban = listing.sellerIban
    
    if not sellerIban then
        local dbListing = MySQL.single.await('SELECT data FROM usedcar_listings WHERE id = ?', {vehicleId})
        if dbListing then
            local dbData = json.decode(dbListing.data)
            sellerIban = dbData.sellerIban
        end
        
        if not sellerIban then
            sellerIban = Banking.GetPlayerAccount(listing.sellerIdentifier)
        end
    end
    
    if sellerIban then
        exports['RxBanking']:AddAccountMoney(
            sellerIban, 
            sellerAmount, 
            'payment', 
            'Vehicle sale: ' .. (listing.label or listing.model),
            nil
        )
        
        local sellerPlayer = GetPlayerFromIdentifier(listing.sellerIdentifier)
        if sellerPlayer then
            local sellerSource = sellerPlayer.PlayerData and sellerPlayer.PlayerData.source or sellerPlayer.source
            TriggerClientEvent('usedcardealer:vehicleSold', sellerSource, {
                vehicleLabel = listing.label or listing.model,
                salePrice = listing.price,
                commission = commission
            })
        end
    end
    
    local vehiclePropsToSpawn = listing.props
    vehiclePropsToSpawn.plate = cleanPlate
    
    TriggerClientEvent('usedcardealer:spawnPurchasedVehicle', source, vehiclePropsToSpawn, locationId)
    TriggerClientEvent('usedcardealer:refreshDisplay', -1, locationId)
    
    return true, 'Vehicle purchased successfully!'
end)

function GetLabelFromModel(model)
    if QBCore then
        if QBCore.Shared and QBCore.Shared.Vehicles then
            local vehicles = QBCore.Shared.Vehicles
            local modelKey = type(model) == 'number' and model or GetHashKey(model)
            
            for k, v in pairs(vehicles) do
                if GetHashKey(k) == modelKey or k == model then
                    if v.brand and v.name then
                        return v.brand .. ' ' .. v.name
                    elseif v.name then
                        return v.name
                    end
                end
            end
        end
        
        if QBCore.Functions and QBCore.Functions.GetVehicles then
            local vehicles = QBCore.Functions.GetVehicles()
            if vehicles and vehicles[model] then
                if vehicles[model].brand and vehicles[model].name then
                    return vehicles[model].brand .. ' ' .. vehicles[model].name
                elseif vehicles[model].name then
                    return vehicles[model].name
                end
            end
        end
    end
    
    if type(model) == 'string' then
        local label = model:gsub('_', ' ')
        label = label:gsub("(%a)([%w_']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        return label
    end
    
    return tostring(model)
end

lib.callback.register('usedcardealer:listVehicle', function(source, vehicleProps, price, description, locationId)
    local seller = GetPlayer(source)
    if not seller then
        return false, 'Player not found'
    end
    
    local sellerIdentifier = GetIdentifier(source)
    local sellerName = GetFullName(source)
    
    if price < Config.MinPrice or price > Config.MaxPrice then
        return false, string.format('Price must be between $%s and $%s', Config.MinPrice, Config.MaxPrice)
    end
    
    local dealerConfig = nil
    for _, location in pairs(Config.DealerLocations) do
        if location.id == locationId then
            dealerConfig = location
            break
        end
    end
    
    if not dealerConfig then
        return false, 'Invalid dealer location'
    end
    
    local maxCapacity = #dealerConfig.vehicleSpots
    local currentListings = vehicleListings[locationId] and #vehicleListings[locationId] or 0
    
    if currentListings >= maxCapacity then
        return false, string.format('This dealer is at full capacity (%d/%d vehicles)', currentListings, maxCapacity)
    end
    
    local cleanPlate = string.gsub(vehicleProps.plate or "", "%s+", ""):upper()
    vehicleProps.plate = cleanPlate
    
    local existingListing = MySQL.query.await([[
        SELECT id FROM usedcar_listings 
        WHERE JSON_EXTRACT(data, '$.plate') = ? 
        AND active = 1
    ]], {
        cleanPlate
    })
    
    local ownershipCheck = MySQL.query.await([[
        SELECT *, financed FROM player_vehicles 
        WHERE citizenid = ? 
        AND REPLACE(UPPER(plate), ' ', '') = ?
    ]], {
        sellerIdentifier,
        cleanPlate
    })

    if not ownershipCheck or #ownershipCheck == 0 then
        return false, 'You do not own this vehicle'
    end

    if ownershipCheck[1].financed and ownershipCheck[1].financed == 1 then
        return false, 'You cannot sell a vehicle that is under finance'
    end
    
    local vehicleLabel = GetLabelFromModel(vehicleProps.model)

    local sellerIban = Banking.GetPlayerAccount(sellerIdentifier)
    
    if not sellerIban then
        return false, 'No bank account found. Please open a bank account first.'
    end
    
    local listingData = {
        sellerName = sellerName,
        sellerIban = sellerIban,
        model = vehicleProps.model or 'unknown',
        label = vehicleLabel or 'Unknown Vehicle',
        plate = cleanPlate,
        props = vehicleProps,
        price = price,
        description = description or ''
    }
    
    local id = MySQL.insert.await([[
        INSERT INTO usedcar_listings (seller_id, location_id, data) 
        VALUES (?, ?, ?)
    ]], {
        sellerIdentifier,
        locationId,
        json.encode(listingData)
    })
    
    MySQL.update.await([[
        DELETE FROM player_vehicles 
        WHERE citizenid = ? 
        AND REPLACE(UPPER(plate), ' ', '') = ?
    ]], {
        sellerIdentifier,
        cleanPlate
    })
    
    if not vehicleListings[locationId] then
        vehicleListings[locationId] = {}
    end
    
    table.insert(vehicleListings[locationId], {
        id = id,
        sellerIdentifier = sellerIdentifier,
        sellerName = sellerName,
        model = vehicleProps.model,
        label = vehicleLabel,
        plate = cleanPlate,
        props = vehicleProps,
        price = price,
        description = description,
        locationId = locationId,
        listedAt = os.date('%Y-%m-%d %H:%M:%S')
    })
    
    if not playerListings[sellerIdentifier] then
        playerListings[sellerIdentifier] = {}
    end
    
    table.insert(playerListings[sellerIdentifier], id)
    
    TriggerClientEvent('usedcardealer:refreshDisplay', -1, locationId)
    
    return true, 'Vehicle listed successfully!'
end)

lib.callback.register('usedcardealer:getDealerCapacity', function(source, locationId)
    local dealerConfig = nil
    for _, location in pairs(Config.DealerLocations) do
        if location.id == locationId then
            dealerConfig = location
            break
        end
    end
    
    if not dealerConfig then
        return {current = 0, max = 0, isFull = true}
    end
    
    local maxCapacity = #dealerConfig.vehicleSpots
    local currentListings = vehicleListings[locationId] and #vehicleListings[locationId] or 0
    
    return {
        current = currentListings,
        max = maxCapacity,
        isFull = currentListings >= maxCapacity
    }
end)

lib.callback.register('usedcardealer:getPlayerListings', function(source, locationId)
    local playerIdentifier = GetIdentifier(source)
    if not playerIdentifier then
        return {}
    end
    
    local listings = MySQL.query.await([[
        SELECT id, location_id, data, active, created_at, updated_at 
        FROM usedcar_listings 
        WHERE seller_id = ? 
        ORDER BY created_at DESC
    ]], {
        playerIdentifier
    })
    
    if not listings then
        return {}
    end
    
    local result = {}
    for _, listing in ipairs(listings) do
        local data = json.decode(listing.data)
        
        local dealerLabel = 'Unknown Dealer'
        for _, location in pairs(Config.DealerLocations) do
            if location.id == listing.location_id then
                dealerLabel = location.label
                break
            end
        end
        
        table.insert(result, {
            id = listing.id,
            model = data.model,
            label = data.label,
            plate = data.plate,
            price = data.price,
            description = data.description,
            listedDate = listing.created_at,
            active = listing.active,
            sold = false,
            soldDate = nil,
            buyerName = nil,
            locationId = listing.location_id,
            dealerLabel = dealerLabel
        })
    end
    
    return result
end)

lib.callback.register('usedcardealer:updatePrice', function(source, listingId, newPrice)
    local playerId = GetIdentifier(source)
    if not playerId then
        return false, 'Player not found'
    end
    
    if newPrice < Config.MinPrice or newPrice > Config.MaxPrice then
        return false, string.format('Price must be between $%s and $%s', Config.MinPrice, Config.MaxPrice)
    end
    
    local listing = MySQL.single.await('SELECT * FROM usedcar_listings WHERE id = ? AND seller_id = ? AND active = 1', {
        listingId,
        playerId
    })
    
    if not listing then
        return false, 'Listing not found or already sold'
    end
    
    local data = json.decode(listing.data)
    
    if not data.history then
        data.history = {
            price_changes = {}
        }
    elseif not data.history.price_changes then
        data.history.price_changes = {}
    end
    
    table.insert(data.history.price_changes, {
        old_price = data.price,
        new_price = newPrice,
        changed_at = os.date('%Y-%m-%d %H:%M:%S')
    })
    
    data.price = newPrice
    
    MySQL.update.await('UPDATE usedcar_listings SET data = ? WHERE id = ?', {
        json.encode(data),
        listingId
    })
    
    for locationId, listings in pairs(vehicleListings) do
        for _, veh in ipairs(listings) do
            if veh.id == listingId then
                veh.price = newPrice
                break
            end
        end
    end
    
    return true, 'Price updated successfully!'
end)

lib.callback.register('usedcardealer:removeListing', function(source, listingId)
    local playerId = GetIdentifier(source)
    if not playerId then
        return false, 'Player not found', nil
    end
    
    local listing = MySQL.single.await('SELECT * FROM usedcar_listings WHERE id = ? AND seller_id = ? AND active = 1', {
        listingId,
        playerId
    })
    
    if not listing then
        return false, 'Listing not found or already sold', nil
    end
    
    local data = json.decode(listing.data)
    local vehicleProps = data.props
    local cleanPlate = data.plate:gsub("^%s*(.-)%s*$", "%1"):upper()
    
    local modelName = data.model
    if type(modelName) == 'number' then
        modelName = vehicleProps.model or 'unknown'
    end
    
    MySQL.insert.await([[
        INSERT INTO player_vehicles (
            citizenid, vehicle, hash, mods, plate, 
            garage, fuel, engine, body, state, 
            in_garage, garage_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        playerId,
        modelName,
        tostring(GetHashKey(modelName)),
        json.encode(vehicleProps),
        cleanPlate,
        'pillboxgarage',
        vehicleProps.fuelLevel or 100,
        vehicleProps.engineHealth or 1000,
        vehicleProps.bodyHealth or 1000,
        0,
        0,
        'pillboxgarage'
    })
    
    data.removed = {
        removed_at = os.date('%Y-%m-%d %H:%M:%S'),
        reason = 'seller_removed'
    }
    
    MySQL.update.await('UPDATE usedcar_listings SET active = 0, data = ? WHERE id = ?', {
        json.encode(data),
        listingId
    })
    
    for locationId, listings in pairs(vehicleListings) do
        for i, veh in ipairs(listings) do
            if veh.id == listingId then
                table.remove(vehicleListings[locationId], i)
                TriggerClientEvent('usedcardealer:refreshDisplay', -1, locationId)
                break
            end
        end
    end
    
    if playerListings[playerId] then
        for i, id in ipairs(playerListings[playerId]) do
            if id == listingId then
                table.remove(playerListings[playerId], i)
                break
            end
        end
    end
    
    vehicleProps.plate = cleanPlate
    
    return true, 'Listing removed! Your vehicle will be spawned.', vehicleProps
end)

lib.callback.register('usedcardealer:getOwnedVehicles', function(source)
    local playerId = GetIdentifier(source)
    if not playerId then
        return {}
    end
    
    local ownedVehicles = MySQL.query.await([[
        SELECT plate, vehicle, mods, stored, financed 
        FROM player_vehicles 
        WHERE (citizenid = ? OR owner = ?)
        AND (financed IS NULL OR financed = 0)
    ]], {playerId, playerId})
    
    if not ownedVehicles then
        return {}
    end
    
    local listedPlates = MySQL.query.await([[
        SELECT JSON_EXTRACT(data, '$.vehicle.plate') as plate 
        FROM usedcar_listings 
        WHERE seller_id = ? AND active = 1
    ]], {playerId})
    
    local listedPlatesMap = {}
    if listedPlates then
        for _, listing in ipairs(listedPlates) do
            if listing.plate then
                local cleanPlate = listing.plate:gsub('"', '')
                listedPlatesMap[cleanPlate:upper()] = true
            end
        end
    end
    
    local availableVehicles = {}
    for _, vehicle in ipairs(ownedVehicles) do
        local plate = vehicle.plate:gsub("^%s*(.-)%s*$", "%1"):upper()
        
        if vehicle.stored == 1 and not listedPlatesMap[plate] then
            local vehicleData = {
                plate = plate,
                model = vehicle.vehicle,
                stored = vehicle.stored,
                mods = vehicle.mods and json.decode(vehicle.mods) or nil
            }
            
            if vehicle.mods then
                local mods = json.decode(vehicle.mods)
                vehicleData.model = mods.model or vehicle.vehicle
            end
            
            vehicleData.label = GetVehicleLabel(vehicleData.model)
            table.insert(availableVehicles, vehicleData)
        end
    end
    
    return availableVehicles
end)

lib.callback.register('usedcardealer:checkVehicleOwnership', function(source, plate)
    local playerIdentifier = GetIdentifier(source)
    if not playerIdentifier or not plate then
        return false, 'Invalid request'
    end
    
    plate = string.gsub(plate, "%s+", ""):upper()
    
    local result = MySQL.query.await([[
        SELECT *, financed FROM player_vehicles 
        WHERE citizenid = ? 
        AND REPLACE(UPPER(plate), ' ', '') = ?
    ]], {
        playerIdentifier,
        plate
    })
    
    if not result or #result == 0 then
        return false, 'You do not own this vehicle'
    end
    
    if result[1].financed == true or result[1].financed == 1 then
        return false, 'You cannot sell a vehicle that is under finance'
    end
    
    return true, 'Vehicle can be listed'
end)

lib.callback.register('usedcardealer:startTestDrive', function(source, vehicleId)
    local playerId = GetIdentifier(source)
    if not playerId then
        return false, 'Player not found'
    end
    
    return true, 'Test drive authorized'
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print("^3Saving all active listings before shutdown...")
end)