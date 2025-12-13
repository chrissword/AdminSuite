AS = AS or {}

local Events  = AS.Events
local RBAC    = AS.RBAC
local Reports = AS.Reports

-- These are what the client is listening for:
--   as:reports:submitAck -> player who submitted the report
--   as:reports:new      -> staff "new report" notify
local SubmitAckEvent = (Events and Events.Reports and Events.Reports.SubmitAck) or 'as:reports:submitAck'
local NewReportEvent = (Events and Events.Reports and Events.Reports.New)       or 'as:reports:new'

if not Events or not Events.Reports then
    return
end

--========================================
-- Internal logging helper
--========================================
local function debug(msg, ...)
    if AS.Utils and AS.Utils.Info then
        AS.Utils.Info('[ReportsEvents] ' .. msg, ...)
    else
        print(('[AdminSuite:ReportsEvents] ' .. msg):format(...))
    end
end

--========================================
-- Helpers
--========================================

local function ensureReports()
    if not Reports then
        Reports = AS.Reports
    end
    return Reports
end

local function isStaffPlayer(src)
    if not RBAC then return false end

    -- Prefer explicit helpers if available
    if RBAC.IsStaff then
        return RBAC.IsStaff(src)
    end

    if RBAC.Can then
        -- Fallback permission used across AdminSuite for basic moderation
        return RBAC.Can(src, 'can_kick')
    end

    return false
end

local function requireReportsAccess(src)
    if not RBAC or not RBAC.Can then
        debug('RBAC not available; denying access for %s', tostring(src))
        return false
    end

    -- If you later add dedicated permissions (e.g. "can_view_reports"),
    -- you can extend this, but keep can_kick for backward compatibility.
    local ok = RBAC.Can(src, 'can_kick')
    debug('requireReportsAccess(%s) → %s', tostring(src), tostring(ok))
    return ok
end

local function getFirstIdentifier(src)
    local ids = GetPlayerIdentifiers(src)
    return ids and ids[1] or ('source:%d'):format(src)
end

-- Send a "reports updated" payload to a single staff member
local function sendReportsToStaff(src)
    local mod = ensureReports()
    if not mod or not mod.GetAll then
        return
    end

    local rows = mod.GetAll()
    debug('sendReportsToStaff(%s) → %d rows', tostring(src), type(rows) == 'table' and #rows or -1)
    TriggerClientEvent(Events.Reports.GetAll, src, rows or {})
end

-- Broadcast updated reports to all staff who have reports access
local function broadcastReportsToStaff()
    local mod = ensureReports()
    if not mod or not mod.GetAll then
        debug('broadcastReportsToStaff called but AS.Reports.GetAll is missing')
        return
    end

    local rows = mod.GetAll()
    local count = type(rows) == 'table' and #rows or -1
    debug('broadcastReportsToStaff → %d rows', count)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId) or playerId

        if isStaffPlayer(pid) and requireReportsAccess(pid) then
            TriggerClientEvent(Events.Reports.GetAll, pid, rows or {})
        end
    end
end

--========================================
-- Events
--========================================

-- Submit: allow non-staff (players) to report
RegisterNetEvent(Events.Reports.Submit, function(targetIdentifier, category, message, metadata)
    local src = source
    local mod = ensureReports()
    if not mod or not mod.Submit then
        debug('Submit event fired but AS.Reports.Submit is missing')
        return
    end

    debug('Submit from src=%s category=%s', tostring(src), tostring(category))

    -- Actually store the report
    mod.Submit(src, targetIdentifier, category, message, metadata)

    ----------------------------------------------------------------
    -- 1) ACK BACK TO PLAYER WHO SUBMITTED THE REPORT
    ----------------------------------------------------------------
    if SubmitAckEvent then
        TriggerClientEvent(SubmitAckEvent, src, {
            success = true,
            message = 'Your report has been submitted to staff.',
        })
    end

    ----------------------------------------------------------------
    -- 2) NOTIFY STAFF THAT A NEW REPORT EXISTS
    ----------------------------------------------------------------
    if NewReportEvent then
        local fromName       = GetPlayerName(src) or ('ID %d'):format(src)
        local categoryLabel  = category or 'general'
        local staffMessage   = ('New report received from %s (#%s) [%s]'):format(
            tostring(fromName),
            tostring(src),
            tostring(categoryLabel)
        )

        for _, playerId in ipairs(GetPlayers()) do
            local pid = tonumber(playerId) or playerId

            local isStaff = isStaffPlayer(pid)
            if isStaff and requireReportsAccess(pid) then
                TriggerClientEvent(NewReportEvent, pid, {
                    fromName = fromName,
                    fromId   = src,
                    category = categoryLabel,
                    message  = staffMessage,
                })
            end
        end
    end

    -- Optional: immediately broadcast updated report list to staff
    broadcastReportsToStaff()
end)

-- Explicit query: open reports only (legacy support)
RegisterNetEvent(Events.Reports.GetOpen, function()
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.GetOpen then
        debug('GetOpen event fired but AS.Reports.GetOpen is missing')
        return
    end

    local rows = mod.GetOpen()
    debug('GetOpen for %s → %d rows', tostring(src), type(rows) == 'table' and #rows or -1)
    TriggerClientEvent(Events.Reports.GetOpen, src, rows or {})
end)

-- Explicit query: "my" reports (claimed by me)
RegisterNetEvent(Events.Reports.GetMine, function()
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.GetMine then
        debug('GetMine event fired but AS.Reports.GetMine is missing')
        return
    end

    local identifier = getFirstIdentifier(src)
    local rows = mod.GetMine(identifier)

    debug(
        'GetMine for %s (%s) → %d rows',
        tostring(src),
        identifier,
        type(rows) == 'table' and #rows or -1
    )

    TriggerClientEvent(Events.Reports.GetMine, src, rows or {})
end)

-- Explicit query: all reports (open + in-progress + closed)
RegisterNetEvent(Events.Reports.GetAll, function()
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.GetAll then
        debug('GetAll event fired but AS.Reports.GetAll is missing')
        return
    end

    local rows = mod.GetAll()
    debug('GetAll for %s → %d rows', tostring(src), type(rows) == 'table' and #rows or -1)
    TriggerClientEvent(Events.Reports.GetAll, src, rows or {})
end)

-- Claim a report
RegisterNetEvent(Events.Reports.Claim, function(id)
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.Claim then
        debug('Claim event fired but AS.Reports.Claim is missing')
        return
    end

    debug('Claim report %s by %s', tostring(id), tostring(src))
    mod.Claim(src, tonumber(id))

    -- Push updated list to staff for the new UI
    broadcastReportsToStaff()
end)

-- Unclaim a report
RegisterNetEvent(Events.Reports.Unclaim, function(id)
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.Unclaim then
        debug('Unclaim event fired but AS.Reports.Unclaim is missing')
        return
    end

    debug('Unclaim report %s by %s', tostring(id), tostring(src))
    mod.Unclaim(src, tonumber(id))

    broadcastReportsToStaff()
end)

-- Close a report
RegisterNetEvent(Events.Reports.Close, function(id)
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.Close then
        debug('Close event fired but AS.Reports.Close is missing')
        return
    end

    debug('Close report %s by %s', tostring(id), tostring(src))
    mod.Close(src, tonumber(id))

    broadcastReportsToStaff()
end)

-- Reopen a closed report
RegisterNetEvent(Events.Reports.Reopen, function(id)
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.Reopen then
        debug('Reopen event fired but AS.Reports.Reopen is missing')
        return
    end

    debug('Reopen report %s by %s', tostring(id), tostring(src))
    mod.Reopen(src, tonumber(id))

    broadcastReportsToStaff()
end)

-- Generic status update (if used by other flows)
RegisterNetEvent(Events.Reports.UpdateStatus, function(id, status)
    local src = source
    if not requireReportsAccess(src) then return end

    local mod = ensureReports()
    if not mod or not mod.UpdateStatus then
        debug('UpdateStatus event fired but AS.Reports.UpdateStatus is missing')
        return
    end

    debug('UpdateStatus report %s to %s by %s', tostring(id), tostring(status), tostring(src))
    mod.UpdateStatus(src, tonumber(id), status)

    broadcastReportsToStaff()
end)
