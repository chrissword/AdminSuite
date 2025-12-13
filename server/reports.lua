AS = AS or {}
AS.Reports = AS.Reports or {}

local DB          = AS.DB
local Tables      = AS.Tables
local Utils       = AS.Utils
local Audit       = AS.Audit
local Persistence = AS.Persistence

--========================================
-- Helpers
--========================================

local function debug(msg, ...)
    if Utils and Utils.Info then
        Utils.Info('[Reports] ' .. msg, ...)
    else
        print(('[AdminSuite:Reports] ' .. msg):format(...))
    end
end

local function getTableName()
    -- Prefer DB.tableName (handles prefixes, etc.)
    local logical = (Tables and Tables.Reports) or 'as_reports'
    if DB and DB.tableName then
        return DB.tableName(logical)
    end
    return logical
end

local function snapshotToPersistence()
    if not Persistence or not DB or not DB.execute then return end

    local tableName = getTableName()
    local rows = DB.execute(('SELECT * FROM `%s` ORDER BY id ASC'):format(tableName), {})
    Persistence.Save('Reports', rows)
end

local function getIdentifier(src)
    local ids = GetPlayerIdentifiers(src) or {}
    return ids[1] or ('source:%d'):format(src)
end

--========================================
-- Core operations
--========================================

function AS.Reports.Submit(src, targetIdentifier, category, message, metadata)
    if not DB or not DB.execute then
        debug('Submit called but DB is not available')
        return
    end

    local reporterId = getIdentifier(src)
    message  = tostring(message or ''):sub(1, 1024)
    category = category and tostring(category):sub(1, 64) or nil

    local tableName = getTableName()

    debug('Submit: reporter=%s category=%s message=%s', reporterId, tostring(category), message)

    DB.execute(([[INSERT INTO `%s`
        (reporter_identifier, target_identifier, status, category, message, metadata)
        VALUES (@reporter, @target, 'open', @category, @message, @metadata)]])
        :format(tableName),
        {
            ['@reporter'] = reporterId,
            ['@target']   = targetIdentifier,
            ['@category'] = category,
            ['@message']  = message,
            ['@metadata'] = metadata and AS.Utils.SafeJsonEncode(metadata) or 'null',
        }
    )

    if Audit and Audit.Log then
        Audit.Log(src, targetIdentifier, 'reports:submit', {
            category = category,
            message  = message,
        })
    end

    snapshotToPersistence()
end

function AS.Reports.GetOpen()
    if not DB or not DB.execute then
        debug('GetOpen called but DB is not available')
        return {}
    end

    local tableName = getTableName()

    -- Treat both "open" and "claimed" as active so they stay in the list.
    local rows = DB.execute(([[SELECT * FROM `%s`
        WHERE status IN ('open', 'claimed')
        ORDER BY id ASC]]):format(tableName), {}) or {}

    debug('GetOpen → %d rows from %s', #rows, tableName)
    return rows
end


function AS.Reports.GetMine(staffIdentifier)
    if not DB or not DB.execute then
        debug('GetMine called but DB is not available')
        return {}
    end

    local tableName = getTableName()
    local rows = DB.execute(([[SELECT * FROM `%s`
        WHERE claimed_by = @staff
        ORDER BY id ASC]]):format(tableName),
        { ['@staff'] = staffIdentifier }
    ) or {}

    debug('GetMine(%s) → %d rows', tostring(staffIdentifier), #rows)
    return rows
end

function AS.Reports.GetAll()
    if not DB or not DB.execute then
        debug('GetAll called but DB is not available')
        return {}
    end

    local tableName = getTableName()
    local rows = DB.execute(([[SELECT * FROM `%s` ORDER BY id DESC LIMIT 200]]):format(tableName), {}) or {}

    debug('GetAll → %d rows', #rows)
    return rows
end

local function updateReport(id, fields)
    if not DB or not DB.execute then
        debug('updateReport(%s) called but DB is not available', tostring(id))
        return
    end

    local tableName = getTableName()
    local setParts, params = {}, { ['@id'] = id }

    for k, v in pairs(fields) do
        setParts[#setParts + 1] = ('%s = @%s'):format(k, k)
        params['@' .. k] = v
    end

    if #setParts == 0 then return end

    local sql = ('UPDATE `%s` SET %s WHERE id = @id'):format(tableName, table.concat(setParts, ', '))
    DB.execute(sql, params)
    debug('updateReport(%d) with fields=%s', id, json.encode(fields))

    snapshotToPersistence()
end

function AS.Reports.Claim(src, id)
    local staffId = getIdentifier(src)
    updateReport(id, { claimed_by = staffId, status = 'claimed' })

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'reports:claim', { id = id })
    end
end

function AS.Reports.Unclaim(src, id)
    updateReport(id, { claimed_by = nil, status = 'open' })

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'reports:unclaim', { id = id })
    end
end

function AS.Reports.Close(src, id)
    updateReport(id, { status = 'closed' })

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'reports:close', { id = id })
    end
end

function AS.Reports.Reopen(src, id)
    updateReport(id, { status = 'open' })

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'reports:reopen', { id = id })
    end
end

function AS.Reports.UpdateStatus(src, id, status)
    status = tostring(status or 'open'):sub(1, 32)
    updateReport(id, { status = status })

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'reports:updateStatus', {
            id     = id,
            status = status,
        })
    end
end
