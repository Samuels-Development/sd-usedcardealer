--- Dynamically selects and returns the appropriate function for retrieving a player object
--- based on the configured framework.
---@return function A function that returns the player object when called with server ID
local CreateGetPlayerFunction = function()
    if Framework == 'esx' then
        return function(source)
            return ESX.GetPlayerFromId(source)
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(source)
            return QBCore.Functions.GetPlayer(source)
        end
    else
        return function(source)
            error(string.format("Unsupported framework. Unable to retrieve player object for source: %s", source))
            return nil
        end
    end
end

--- Creates framework-specific function for getting player identifier
---@return function Function to retrieve player identifier
local CreateGetIdentifierFunction = function()
    if Framework == 'esx' then
        return function(player)
            return player.identifier
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(player)
            return player.PlayerData.citizenid
        end
    else
        return function()
            error("Unsupported framework for GetIdentifier.")
        end
    end
end

--- Creates framework-specific function for getting player full name
---@return function Function to get player's full name
local CreateGetNameFunction = function()
    if Framework == 'esx' then
        return function(player)
            return player.get('firstName') .. ' ' .. player.get('lastName')
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(player)
            if player.PlayerData and player.PlayerData.charinfo then
                return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            end
            return 'Unknown Player'
        end
    else
        return function()
            error("Unsupported framework for GetFullName.")
        end
    end
end

--- Creates framework-specific function for getting a player from an identifier
---@return function Function to get player's full name
local CreateIdentifierPlayerFunction = function()
    if Framework == 'qb' then
        return function(identifier)
            local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
            if player and player.PlayerData then
                return GetPlayer(player.PlayerData.source)
            end
            return nil
        end
    elseif Framework == 'esx' then
        return function(identifier)
            local player = ESX.GetPlayerFromIdentifier(identifier)
            if player then
                return GetPlayer(player.source)
            end
            return nil
        end
    else
        return function(identifier)
            error(string.format("Unsupported framework: %s", Framework))
        end
    end
end

-- Initialize player management functions
GetPlayer = CreateGetPlayerFunction()
local GetIdentifierFromPlayer = CreateGetIdentifierFunction()
local GetFullNameFromPlayer = CreateGetNameFunction()
local GetPlayerByIdentifier = CreateIdentifierPlayerFunction()

--- Gets a player's identifier
---@param source number The player's server ID
---@return string|nil The player's identifier
GetIdentifier = function(source)
    local player = GetPlayer(source)
    return player and GetIdentifierFromPlayer(player) or nil
end

--- Gets a player's full name
---@param source number The player's server ID
---@return string The player's full name
GetFullName = function(source)
    local player = GetPlayer(source)
    return player and GetFullNameFromPlayer(player) or 'Unknown Player'
end

-- This function assigns the ability to retrieve a player by identifie
---@param source string The player's server identifier
---@returns a players object for the given identifier
GetPlayerFromIdentifier = function(identifier)
    return GetPlayerByIdentifier(identifier)
end

--- Checks for updates by comparing local version with GitHub releases
---@param repo string The GitHub repository in format 'owner/repository'
CheckVersion = function(repo)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resource, 'Version', 0)
    
    if currentVersion then
        currentVersion = currentVersion:match('%d+%.%d+%.%d+')
    end
    
    if not currentVersion then
        return print("^1Unable to determine current resource version for '^2" .. resource .. "^1'^0")
    end
    
    print('^3Checking for updates for ^2' .. resource .. '^3...^0')
    
    SetTimeout(1000, function()
        local url = ('https://api.github.com/repos/%s/releases/latest'):format(repo)
        PerformHttpRequest(url, function(status, response)
            if status ~= 200 then
                print('^1Failed to fetch release information for ^2' .. resource .. '^1. HTTP status: ' .. status .. '^0')
                return
            end
            
            local data = json.decode(response)
            if not data then
                print('^1Failed to parse release information for ^2' .. resource .. '^1.^0')
                return
            end
            
            if data.prerelease then
                print('^3Skipping prerelease for ^2' .. resource .. '^3.^0')
                return
            end
            
            local latestVersion = data.tag_name and data.tag_name:match('%d+%.%d+%.%d+')
            if not latestVersion then
                print('^1Failed to get valid latest version for ^2' .. resource .. '^1.^0')
                return
            end
            
            if latestVersion == currentVersion then
                print('^2' .. resource .. ' ^3is up-to-date with version ^2' .. currentVersion .. '^3.^0')
                return
            end
            
            -- Compare versions
            local parseVersion = function(version)
                local parts = {}
                for part in version:gmatch('%d+') do
                    table.insert(parts, tonumber(part))
                end
                return parts
            end
            
            local cv = parseVersion(currentVersion)
            local lv = parseVersion(latestVersion)
            
            for i = 1, math.max(#cv, #lv) do
                local current = cv[i] or 0
                local latest = lv[i] or 0
                
                if current < latest then
                    local releaseNotes = data.body or "No release notes available."
                    local message = releaseNotes:find("\n") and 
                        "Check release page or changelog channel on Discord for more information!" or 
                        releaseNotes
                    
                    print(string.format(
                        '^3An update is available for ^2%s^3 (current: ^2%s^3)\r\nLatest: ^2%s^3\r\nRelease Notes: ^7%s',
                        resource, currentVersion, latestVersion, message
                    ))
                    break
                elseif current > latest then
                    print(string.format(
                        '^2%s ^3has newer local version (^2%s^3) than latest public release (^2%s^3).^0',
                        resource, currentVersion, latestVersion
                    ))
                    break
                end
            end
        end, 'GET', '')
    end)
end

Money = {}

--- Converts money type to framework-specific variant
---@param moneyType string The original money type
---@return string The converted money type
local ConvertMoneyType = function(moneyType)
    if moneyType == 'money' and (Framework == 'qb' or Framework == 'qbx') then
        return 'cash'
    elseif moneyType == 'cash' and Framework == 'esx' then
        return 'money'
    else
        return moneyType
    end
end

--- Creates framework-specific function for adding money
---@return function Function to add money to player
local CreateAddMoneyFunction = function()
    if Framework == 'esx' then
        return function(player, moneyType, amount)
            player.addAccountMoney(ConvertMoneyType(moneyType), amount)
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(player, moneyType, amount)
            player.Functions.AddMoney(ConvertMoneyType(moneyType), amount)
        end
    else
        return function()
            error("Unsupported framework for AddMoney.")
        end
    end
end

--- Creates framework-specific function for removing money
---@return function Function to remove money from player
local CreateRemoveMoneyFunction = function()
    if Framework == 'esx' then
        return function(player, moneyType, amount)
            player.removeAccountMoney(ConvertMoneyType(moneyType), amount)
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(player, moneyType, amount)
            player.Functions.RemoveMoney(ConvertMoneyType(moneyType), amount)
        end
    else
        return function()
            error("Unsupported framework for RemoveMoney.")
        end
    end
end

--- Creates framework-specific function for getting player funds
---@return function Function to get player's account funds
local CreateGetFundsFunction = function()
    if Framework == 'esx' then
        return function(player, moneyType)
            local account = player.getAccount(ConvertMoneyType(moneyType))
            return account and account.money or 0
        end
    elseif Framework == 'qb' or Framework == 'qbx' then
        return function(player, moneyType)
            return player.PlayerData.money[ConvertMoneyType(moneyType)] or 0
        end
    else
        return function()
            error("Unsupported framework for GetPlayerFunds.")
        end
    end
end

-- Initialize money management functions
local AddMoneyToPlayer = CreateAddMoneyFunction()
local RemoveMoneyFromPlayer = CreateRemoveMoneyFunction()
local GetPlayerAccountFunds = CreateGetFundsFunction()

--- Adds money to a player's account
---@param source number The player's server ID
---@param moneyType string The type of money to add
---@param amount number The amount of money to add
Money.AddMoney = function(source, moneyType, amount)
    local player = GetPlayer(source)
    if player then 
        AddMoneyToPlayer(player, moneyType, amount) 
    end
end

--- Removes money from a player's account
---@param source number The player's server ID
---@param moneyType string The type of money to remove
---@param amount number The amount of money to remove
Money.RemoveMoney = function(source, moneyType, amount)
    local player = GetPlayer(source)
    if player then 
        RemoveMoneyFromPlayer(player, moneyType, amount) 
    end
end

--- Gets the amount of money in a player's account
---@param source number The player's server ID
---@param moneyType string The type of money to check
---@return number The amount of money
Money.GetPlayerAccountFunds = function(source, moneyType)
    local player = GetPlayer(source)
    return player and GetPlayerAccountFunds(player, moneyType) or 0
end