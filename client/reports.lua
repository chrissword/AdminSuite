AS = AS or {}
AS.ClientReports = AS.ClientReports or {}

-- Pull references, but don't assume they exist yet
local Events      = AS.Events or {}
local ClientUtils = AS.ClientUtils
local Debug       = AS.Utils and AS.Utils.Debug or function() end

-- Chat helper for /report command
TriggerEvent('chat:addSuggestion', '/report', 'Brings up mini UI for reports')

-- If core tables not ready yet, just bail out safely.
if not Events or not Events.Reports or not ClientUtils then
    return
end

local ReportEvents = Events.Reports or {}
local NUIEvents    = Events.NUI    or {}

-- Server-side report events (with sane fallbacks)
local EVENT_GET_OPEN   = ReportEvents.GetOpen   or 'as:reports:getOpen'
local EVENT_GET_MINE   = ReportEvents.GetMine   or 'as:reports:getMine'
local EVENT_GET_ALL    = ReportEvents.GetAll    or 'as:reports:getAll'
local EVENT_SUBMIT_ACK = ReportEvents.SubmitAck or 'as:reports:submitAck'
local EVENT_NEW_REPORT = ReportEvents.New       or 'as:reports:new'

-- NUI bridge events (Lua → JS)
local NUI_LOAD_OPEN           = NUIEvents.ReportsLoadOpen        or 'as:nui:reports:loadOpen'
local NUI_LOAD_MINE           = NUIEvents.ReportsLoadMine        or 'as:nui:reports:loadMine'
local NUI_LOAD_ALL            = NUIEvents.ReportsLoadAll         or 'as:nui:reports:loadAll'
local NUI_NOTIFY_SUBMITTED    = NUIEvents.ReportsNotifySubmitted or 'as:nui:reports:notifySubmitted'
local NUI_NOTIFY_NEW          = NUIEvents.ReportsNotifyNew       or 'as:nui:reports:notifyNew'
local NUI_OPEN_SUBMIT_OVERLAY = NUIEvents.ReportsOpenSubmit      or 'as:nui:reports:openSubmit'

AS.ClientReports.Open = {}
AS.ClientReports.Mine = {}
AS.ClientReports.All  = {}

--========================================
-- Helpers: normalize DB rows for NUI
--========================================

local function normalizeReports(rows)
    local out = {}

    if type(rows) ~= 'table' then
        return out
    end

    for _, row in pairs(rows) do
        if type(row) == 'table' then
            local normalized = {
                id      = row.id,
                message = row.message or '',
                status  = row.status or 'open',

                -- Map DB fields to what reports.js expects
                -- DB: reporter_identifier  → UI: sourceName
                sourceName = row.sourceName or row.reporter_identifier or nil,

                -- DB: claimed_by          → UI: claimedBy
                claimedBy  = row.claimedBy or row.claimed_by or nil,

                -- Pass-throughs
                metadata          = row.metadata,
                category          = row.category,
                created_at        = row.created_at,
                updated_at        = row.updated_at,
                target_identifier = row.target_identifier,
            }

            out[#out + 1] = normalized
        end
    end

    return out
end

local function sendReportsToNui(eventName, rows)
    local normalized = normalizeReports(rows or {})

    Debug(
        'AdminSuite Reports → sending %d normalized reports to NUI (%s)',
        #normalized,
        tostring(eventName)
    )

    if ClientUtils and ClientUtils.SendNUI then
        ClientUtils.SendNUI(eventName, {
            reports = normalized
        })
    else
        SendNUIMessage({
            type    = eventName,
            payload = { reports = normalized }
        })
    end
end

local function sendNuiSimple(eventName, payload)
    payload = payload or {}
    if ClientUtils and ClientUtils.SendNUI then
        ClientUtils.SendNUI(eventName, payload)
    else
        SendNUIMessage({
            type    = eventName,
            payload = payload
        })
    end
end

--========================================
-- Server → Client → NUI: Reports lists
--========================================

-- Open reports
RegisterNetEvent(EVENT_GET_OPEN, function(rows)
    rows = rows or {}

    local previousCount = #(AS.ClientReports.Open or {})
    AS.ClientReports.Open = rows

    Debug('AdminSuite Reports → open raw rows: %d', #rows)

    sendReportsToNui(NUI_LOAD_OPEN, rows)

    local newCount = #rows
    -- Only very lightly notify when staff open the tab for the first time
    if previousCount == 0 and newCount > 0 and ClientUtils and ClientUtils.Notify then
        ClientUtils.Notify('There are currently open reports.', 'info')
    end
end)

-- Mine reports
RegisterNetEvent(EVENT_GET_MINE, function(rows)
    AS.ClientReports.Mine = rows or {}
    Debug('AdminSuite Reports → mine raw rows: %d', #(rows or {}))

    sendReportsToNui(NUI_LOAD_MINE, rows)
end)

-- All reports (history / full list)
RegisterNetEvent(EVENT_GET_ALL, function(rows)
    AS.ClientReports.All = rows or {}
    Debug('AdminSuite Reports → all raw rows: %d', #(rows or {}))

    sendReportsToNui(NUI_LOAD_ALL, rows)
end)

--========================================
-- Notification pipeline
--========================================

-- Player: acknowledgement that their report was submitted (or failed)
RegisterNetEvent(EVENT_SUBMIT_ACK, function(payload)
    payload = payload or {}
    local success = payload.success and true or false

    local message = payload.message
        or (success and 'Your report has been submitted to staff.'
                      or  'Your report could not be submitted.')

    -- This drives the pill for the player (and staff who submit)
    if ClientUtils and ClientUtils.Notify then
        ClientUtils.Notify(message, success and 'success' or 'error')
    end

    -- Still forward into NUI if reports.js wants to react
    sendNuiSimple(NUI_NOTIFY_SUBMITTED, payload)
end)


-- Staff: a new report has been submitted
RegisterNetEvent(EVENT_NEW_REPORT, function(report)
    report = report or {}

    local fromName = report.fromName or 'Unknown'
    local fromId   = report.fromId   or '?'
    local category = report.category or 'general'

    -- If the server didn’t provide a message, build one.
    local msg = report.message or ('New report received from %s (#%s) [%s]'):format(
        tostring(fromName),
        tostring(fromId),
        tostring(category)
    )

    -- 1) Use the same notify helper the submit-ACK uses
    if ClientUtils and ClientUtils.Notify then
        ClientUtils.Notify(msg, 'info')
    end

    -- 2) Still forward into NUI if you want a specialized handler/UI later
    if sendNuiSimple and NUI_NOTIFY_NEW then
        report.message = msg
        sendNuiSimple(NUI_NOTIFY_NEW, report)
    end
end)


--========================================
-- Player /report command -> open NUI window
--========================================

RegisterCommand('report', function()
    -- Give focus to NUI for the lightweight report overlay
    if ClientUtils and ClientUtils.SetNuiFocus then
        ClientUtils.SetNuiFocus(true, true)
    else
        SetNuiFocus(true, true)
    end

    -- Open the minimal player report overlay
    sendNuiSimple(NUI_OPEN_SUBMIT_OVERLAY, {
        subject     = '',
        description = '',
        type        = 'general'
    })
end, false)
