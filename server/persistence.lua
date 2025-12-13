AS = AS or {}
AS.Persistence = AS.Persistence or {}

local Config = AS.Config or Config
local Utils  = AS.Utils

local function logDebug(msg, ...)
    if Config and Config.EnableDebug then
        print(('[AdminSuite:PERSIST] ' .. msg):format(...))
    end
end

local function ensureDir(path)
    -- very lightweight: FiveM doesn’t have mkdir; assume folder exists.
    -- If it doesn’t, nothing terrible happens: writes will fail and log.
    return true
end

local function readFile(path)
    local file = io.open(path, 'r')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return content
end

local function writeFile(path, data)
    local file = io.open(path, 'w+')
    if not file then
        if Utils and Utils.Warn then
            Utils.Warn('Failed to open %s for writing', path)
        end
        return false
    end
    file:write(data)
    file:close()
    return true
end

local function isEnabled(key)
    return Config
       and Config.Persistence
       and Config.Persistence.Enable
       and Config.Persistence.Enable[key] == true
end

local function getPath(key)
    local rel = Config
        and Config.Persistence
        and Config.Persistence.Paths
        and Config.Persistence.Paths[key]

    if not rel then return nil end

    -- If it's already absolute (or Windows-style with a drive letter), just use it.
    if rel:sub(1, 1) == '/' or rel:match('^%a:[/\\]') then
        return rel
    end

    -- Otherwise, resolve relative to this resource's folder
    local resPath = GetResourcePath(GetCurrentResourceName())
    if not resPath or resPath == '' then
        return rel -- fallback: old behavior
    end

    return string.format('%s/%s', resPath, rel)
end


--=====================================================
--  PUBLIC API
--=====================================================

function AS.Persistence.Load(key)
    if not isEnabled(key) then return nil end
    local path = getPath(key)
    if not path then return nil end

    logDebug('Loading persistence key=%s path=%s', key, path)
    local raw = readFile(path)
    if not raw or raw == '' then return nil end

    return AS.Utils.SafeJsonDecode(raw)
end

function AS.Persistence.Save(key, payload)
    if not isEnabled(key) then return false end
    local path = getPath(key)
    if not path then return false end

    ensureDir(path)
    local raw = AS.Utils.SafeJsonEncode(payload or {})
    logDebug('Saving persistence key=%s path=%s', key, path)

    return writeFile(path, raw)
end

function AS.Persistence.FlushAll()
    for key, enabled in pairs(Config.Persistence.Enable or {}) do
        if enabled then
            local path = getPath(key)
            if path then
                writeFile(path, '[]') -- keep it simple: empty JSON array
            end
        end
    end
end
