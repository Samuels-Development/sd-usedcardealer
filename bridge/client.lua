local EnableNotifOX = false -- Enable use of ox_lib for notifications if available
local EnableNotifLation = false -- Enable use of lation_ui for notifications if available

--- Capitalizes the first letter of a string and lowercases the rest.
---@param str string The string to capitalize.
---@return string The capitalized string.
CapitalizeFirst = function(str)
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

--- Selects and returns the most appropriate notification function based on the current game setup.
-- This function checks the available libraries and configurations to determine which notification method to use.
-- It then returns a function tailored to use that method for showing notifications.
---@return function A function configured to show notifications using the determined method.
local CreateNotificationFunction = function()
    if lib ~= nil and EnableNotifOX then
        return function(message, type)
            local title = CapitalizeFirst(type or 'inform')
            lib.notify({
                id = math.random(1, 999999),
                title = title,
                description = message,
                type = type or 'inform'
            })
        end
    elseif EnableNotifLation then
        return function(message, type)
            local title = CapitalizeFirst(type or 'inform')
            exports.lation_ui:notify({
                title = title,
                message = message,
                type = type or 'info',
            })
        end
    else
        if Framework == 'esx' then
            return function(message, _)
                ESX.ShowNotification(message)
            end
        elseif Framework == 'qb' then
            return function(message, type)
                QBCore.Functions.Notify(message, type or 'info')
            end
        end

        return function(message, type)
            error(string.format("Notification system not supported. Message was: %s, Type was: %s", message, type))
        end
    end
end

--- The chosen method for showing notifications, determined at the time of script initialization.
local Notify = CreateNotificationFunction()

--- Display a notification to the user.
-- This function triggers a notification with a specific message and type.
---@param message string The text of the notification to be displayed.
---@param type string The type of notification, which may dictate the visual style or urgency.
ShowNotification = function(message, type)
    Notify(message, type)
end