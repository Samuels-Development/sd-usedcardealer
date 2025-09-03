Locale = {}

-- Translation dictionary
local dict = {}

--- Flattens nested JSON structure into single-level dictionary
---@param prefix string? Current prefix for nested keys
---@param source table Source table to flatten
---@param target table Target table for flattened pairs
FlattenDict = function(prefix, source, target)
    for key, value in pairs(source) do
        local fullKey = prefix and (prefix .. "." .. key) or key
        if type(value) == "table" then
            FlattenDict(fullKey, value, target)
        else
            target[fullKey] = tostring(value)
        end
    end
end

--- Retrieves localized strings with optional dynamic content replacement
---@param key string The key for the localized string
---@param replacements table? Replacement values for dynamic content
---@return string The localized string with replacements applied
Locale.T = function(key, replacements)
    local lstr = dict[key]
    if lstr and replacements then
        for k, v in pairs(replacements) do
            lstr = lstr:gsub('{' .. tostring(k) .. '}', tostring(v))
        end
    end
    return lstr or key
end

--- Loads and applies locales from JSON file
---@param locale string The locale setting determining which file to load
Locale.LoadLocale = function(locale)
    local lang = locale or 'en'
    local path = ('locales/%s.json'):format(lang)
    local file = LoadResourceFile(GetCurrentResourceName(), path)
    
    if not file then
        error(string.format("Could not load locale file: %s", path))
        return
    end
    
    local locales = json.decode(file)
    if not locales then
        error("Failed to parse the locale JSON.")
        return
    end
    
    for k in pairs(dict) do
        dict[k] = nil
    end
    
    FlattenDict(nil, locales, dict)
end