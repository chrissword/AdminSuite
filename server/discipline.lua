--=========================================================
--  AdminSuite – Discipline System (Server Logic)
--=========================================================

AS = AS or {}
AS.Discipline = AS.Discipline or {}

local DB      = AS.DB
local Tables  = AS.Tables
local Utils   = AS.Utils
local Audit   = AS.Audit
local Players = AS.Players
local RBAC    = AS.RBAC

---------------------------------------------------------------------
-- Minimal lib.callback stub (only if ox_lib is NOT present)
---------------------------------------------------------------------
if type(lib) ~= 'table' then lib = {} end
lib.callback = lib.callback or {}

-- Only create the stub if ox_lib (or another implementation) didn't
-- already define lib.callback.register.
if lib.callback.register == nil then
    local handlers = {}
    lib.callback._handlers = handlers

    function lib.callback.register(name, fn)
        handlers[name] = fn
    end

    -- Client → Server callback request
    RegisterNetEvent('as:lib:cb:req', function(name, id, args)
        local src     = source
        local handler = handlers[name]

        if not handler then
            print(('[AdminSuite] lib.callback handler not found: %s'):format(tostring(name)))
            TriggerClientEvent('as:lib:cb:resp', src, id, nil)
            return
        end

        local ok, result = pcall(handler, src, table.unpack(args or {}))
        if not ok then
            print(('[AdminSuite] lib.callback handler "%s" failed: %s'):format(
                tostring(name), tostring(result)
            ))
            TriggerClientEvent('as:lib:cb:resp', src, id, nil)
            return
        end

        TriggerClientEvent('as:lib:cb:resp', src, id, result)
    end)
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function debug(msg, ...)
    if Utils and Utils.Info then
        Utils.Info('[Discipline] ' .. msg, ...)
    else
        print(('[AdminSuite:Discipline] ' .. msg):format(...))
    end
end

local function getTableName()
    -- Migrations hard-coded this to "adminsuite_discipline",
    -- but allow override later via Tables.Discipline if you want.
    if Tables and Tables.Discipline then
        return Tables.Discipline
    end
    return 'adminsuite_discipline'
end

local function sanitize(text, maxLen)
    if not text then return '' end
    text = tostring(text)
    if maxLen and #text > maxLen then
        text = string.sub(text, 1, maxLen)
    end
    return text
end

local function getStaffIdentity(src)
    src = tonumber(src) or 0
    local name       = GetPlayerName(src) or ('[%d] Unknown'):format(src)
    local identifier = ('license:%s'):format(src) -- simple fallback

    if Players and Players.ResolveIdentifier then
        local id = Players.ResolveIdentifier(src)
        if id then identifier = id end
    end

    return name, identifier
end

local function ensureDb()
    if not DB or not DB.execute or not DB.fetchAll then
        debug('Database handle not available; discipline disabled.')
        return false
    end
    return true
end

---------------------------------------------------------------------
-- Core operations
---------------------------------------------------------------------

-- Insert a new discipline entry
function AS.Discipline.AddEntry(src, payload)
    if not ensureDb() then
        return false, 'db_unavailable'
    end

    payload = payload or {}

    local targetName    = sanitize(payload.targetName or payload.name, 100)
    local targetCID     = sanitize(payload.targetCID or payload.citizenid, 64)
    local targetLicense = sanitize(payload.targetLicense or payload.license, 64)
    local reason        = sanitize(payload.reason, 2048)
    local status        = sanitize(payload.status, 64)
    local notes         = sanitize(payload.notes, 2048)

    if targetName == '' then
        return false, 'missing_target_name'
    end

    if reason == '' then
        return false, 'missing_reason'
    end

    if status == '' then
        return false, 'missing_status'
    end

    local staffName, staffIdentifier = getStaffIdentity(src)

    local sql = ([[INSERT INTO `%s`
        (staff_name, staff_identifier, target_name, target_cid, target_license, reason, status, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ]]):format(getTableName())

    DB.execute(sql, {
        staffName,
        staffIdentifier,
        targetName,
        targetCID ~= '' and targetCID or nil,
        targetLicense ~= '' and targetLicense or nil,
        reason,
        status,
        notes ~= '' and notes or nil,
    })


    debug('AddEntry by %s (%s) → target=%s, cid=%s, license=%s',
        staffName, staffIdentifier, targetName, targetCID, targetLicense)

    if Audit and Audit.Log then
        Audit.Log(src, targetLicense or targetCID or targetName, 'discipline:add', {
            staff_name       = staffName,
            staff_identifier = staffIdentifier,
            target_name      = targetName,
            target_cid       = targetCID,
            target_license   = targetLicense,
            reason           = reason,
            status           = status,
            notes            = notes,
        })
    end

    return true
end

-- Stubs for later if you want edit/delete flows
function AS.Discipline.UpdateEntry(src, payload)
    return false, 'not_implemented'
end

function AS.Discipline.DeleteEntry(src, payload)
    if not ensureDb() then
        return false, 'db_unavailable'
    end

    payload = payload or {}

    local id = payload.id or payload.entryId or payload.entry_id
    id = tonumber(id)

    if not id or id <= 0 then
        return false, 'invalid_id'
    end

    -- RBAC: must have can_delete_discipline
    local allowed, roleName = true, 'unknown'
    if RBAC and RBAC.Can then
        allowed, roleName = RBAC.Can(src, 'can_delete_discipline')
    end

    if not allowed then
        return false, 'missing_permission'
    end

    local staffName, staffIdentifier = getStaffIdentity(src)

    local sql = ([[DELETE FROM `%s` WHERE id = ?]]):format(getTableName())
    DB.execute(sql, { id })

    debug('DeleteEntry id=%d by %s (%s)', id, staffName, staffIdentifier)

    if Audit and Audit.Log then
        Audit.Log(src, id, 'discipline:delete', {
            staff_name       = staffName,
            staff_identifier = staffIdentifier,
            entry_id         = id,
        })
    end

    return true
end


-- Recent discipline history
function AS.Discipline.GetHistory()
    if not ensureDb() then
        return {}
    end

    local sql = ([[SELECT
            id,
            UNIX_TIMESTAMP(created_at) AS created_at,
            staff_name,
            staff_identifier,
            target_name,
            target_cid,
            target_license,
            reason,
            status,
            notes
        FROM `%s`
        ORDER BY id DESC
        LIMIT 200;
    ]]):format(getTableName())

    local rows = DB.fetchAll(sql, {}) or {}

    debug('GetHistory → %d rows', #rows)

    return rows
end

-- Online players snapshot for dropdown
function AS.Discipline.GetOnlinePlayers()
    if not Players or not Players.GetPlayersSnapshot then
        debug('GetOnlinePlayers called but AS.Players.GetPlayersSnapshot is missing')
        return {}
    end

    local list = Players.GetPlayersSnapshot() or {}

    table.sort(list, function(a, b)
        return (tostring(a.name or '')):lower() < (tostring(b.name or '')):lower()
    end)

    return list
end

---------------------------------------------------------------------
-- lib.callback handlers (used by client NUI via lib.callback.await)
---------------------------------------------------------------------

-- Called by client NUI: "as:nui:discipline:getHistory"
lib.callback.register('as:discipline:getHistory', function(source, filters)
    -- filters not used yet, but keep signature for future extension
    return AS.Discipline.GetHistory()
end)

-- Called by client NUI: "as:nui:discipline:getOnlinePlayers"
lib.callback.register('as:discipline:getOnlinePlayers', function(source)
    return AS.Discipline.GetOnlinePlayers()
end)

-- Called by client NUI: "as:nui:discipline:delete"
lib.callback.register('as:discipline:delete', function(source, payload)
    local ok, err = AS.Discipline.DeleteEntry(source, payload or {})
    return { ok = ok, error = err }
end)

debug('AdminSuite Discipline server module loaded.')
