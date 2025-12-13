AS = AS or {}
AS.DB = AS.DB or {}
AS.Utils = AS.Utils or {}

local Config = AS.Config or Config

--=====================================================
--  DB ADAPTER
--=====================================================

local adapter = (Config and Config.DB and Config.DB.Adapter) or 'oxmysql'
local prefix  = (Config and Config.DB and Config.DB.Prefix) or 'as_'

local function logDebug(msg, ...)
    if Config and Config.EnableDebug then
        print(('[AdminSuite:DB] ' .. msg):format(...))
    end
end

-- Normalize param nil
local function normalizeParams(params)
    if params == nil then return {} end
    return params
end

-- Shared wrappers
local function exec_oxmysql(query, params, cb)
    params = normalizeParams(params)
    if cb then
        exports.oxmysql:execute(query, params, cb)
    else
        local done, res = false, nil
        exports.oxmysql:execute(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

local function scalar_oxmysql(query, params, cb)
    params = normalizeParams(params)
    if cb then
        exports.oxmysql:scalar(query, params, cb)
    else
        local done, res = false, nil
        exports.oxmysql:scalar(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

local function exec_mysql_async(query, params, cb)
    params = normalizeParams(params)
    if cb then
        MySQL.Async.execute(query, params, cb)
    else
        local done, res = false, nil
        MySQL.Async.execute(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

local function scalar_mysql_async(query, params, cb)
    params = normalizeParams(params)
    if cb then
        MySQL.Async.fetchScalar(query, params, cb)
    else
        local done, res = false, nil
        MySQL.Async.fetchScalar(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

local function exec_ghmatti(query, params, cb)
    params = normalizeParams(params)
    if cb then
        exports.ghmattimysql:execute(query, params, cb)
    else
        local done, res = false, nil
        exports.ghmattimysql:execute(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

local function scalar_ghmatti(query, params, cb)
    params = normalizeParams(params)
    if cb then
        exports.ghmattimysql:scalar(query, params, cb)
    else
        local done, res = false, nil
        exports.ghmattimysql:scalar(query, params, function(r)
            res = r
            done = true
        end)
        while not done do Wait(0) end
        return res
    end
end

-- Public DB API
function AS.DB.execute(query, params, cb)
    logDebug('EXEC (%s): %s', adapter, query)
    if adapter == 'mysql-async' then
        return exec_mysql_async(query, params, cb)
    elseif adapter == 'ghmattimysql' then
        return exec_ghmatti(query, params, cb)
    else
        return exec_oxmysql(query, params, cb)
    end
end

function AS.DB.fetchAll(query, params, cb)
    logDebug('FETCHALL (%s): %s', adapter, query)
    if adapter == 'mysql-async' then
        return exec_mysql_async(query, params, cb)
    elseif adapter == 'ghmattimysql' then
        return exec_ghmatti(query, params, cb)
    else
        return exec_oxmysql(query, params, cb)
    end
end

function AS.DB.scalar(query, params, cb)
    logDebug('SCALAR (%s): %s', adapter, query)
    if adapter == 'mysql-async' then
        return scalar_mysql_async(query, params, cb)
    elseif adapter == 'ghmattimysql' then
        return scalar_ghmatti(query, params, cb)
    else
        return scalar_oxmysql(query, params, cb)
    end
end

--=====================================================
--  VALIDATORS / HELPERS
--=====================================================

local identifierPattern = '^[%w_:]+$'

function AS.Utils.IsValidIdentifier(id)
    if type(id) ~= 'string' then return false end
    if #id < 5 or #id > 128 then return false end
    return id:match(identifierPattern) ~= nil
end

function AS.Utils.SanitizeReason(reason)
    if type(reason) ~= 'string' then return 'No reason specified.' end
    reason = reason:sub(1, 255)
    return reason
end

function AS.Utils.SanitizeNote(note)
    if type(note) ~= 'string' then return nil end
    return note:sub(1, 1024)
end

function AS.Utils.SafeJsonEncode(payload)
    local ok, encoded = pcall(json.encode, payload)
    if not ok then
        print('[AdminSuite] Failed to JSON encode payload')
        return 'null'
    end
    return encoded
end

function AS.Utils.SafeJsonDecode(payload)
    if type(payload) ~= 'string' or payload == '' then
        return nil
    end
    local ok, decoded = pcall(json.decode, payload)
    if not ok then return nil end
    return decoded
end

-- Simple logging helpers
function AS.Utils.Info(msg, ...)
    print(('[AdminSuite] ' .. msg):format(...))
end

function AS.Utils.Warn(msg, ...)
    print(('[AdminSuite:WARN] ' .. msg):format(...))
end

function AS.Utils.Error(msg, ...)
    print(('[AdminSuite:ERROR] ' .. msg):format(...))
end
