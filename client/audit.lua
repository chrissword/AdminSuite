AS = AS or {}
AS.ClientAudit = AS.ClientAudit or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug(msg, ...)
    else
        print(('[AdminSuite] ' .. msg):format(...))
    end
end

local function warn(msg, ...)
    if Utils and Utils.Warn then
        Utils.Warn(msg, ...)
    else
        print(('[AdminSuite:WARN] ' .. msg):format(...))
    end
end

---------------------------------------------------------------------
-- NUI → server: request audit entries
---------------------------------------------------------------------

RegisterNUICallback(
    (AS.Events.NUI and AS.Events.NUI.AuditGetEntries) or 'as:nui:audit:getEntries',
    function(data, cb)
        data = data or {}
        local limit = tonumber(data.limit) or 100

        if not Events or not Events.Audit or not Events.Audit.GetEntries then
            warn('Audit.GetEntries event not configured; cannot request entries.')
            if cb then cb({ ok = false }) end
            return
        end

        debug('Requesting audit entries (limit=%d)', limit)

        TriggerServerEvent(Events.Audit.GetEntries, {
            limit = limit,
            forDashboard = false,
        })

        if cb then cb({ ok = true }) end
    end
)

---------------------------------------------------------------------
-- Server → client: forward audit entries to NUI
---------------------------------------------------------------------

if Events and Events.Audit and Events.Audit.GetEntries and Utils and Utils.SendNUI then
    RegisterNetEvent(Events.Audit.GetEntries, function(entries, opts)
        entries = entries or {}
        opts    = opts or {}

        debug('Received %d audit entries from server', #entries)

        Utils.SendNUI(
            (AS.Events.NUI and AS.Events.NUI.AuditEntries) or 'as:nui:audit:entries',
            {
                entries = entries,
                options = opts,
            }
        )
    end)
end
