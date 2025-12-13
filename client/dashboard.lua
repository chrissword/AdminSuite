AS = AS or {}
AS.ClientDashboard = AS.ClientDashboard or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientDashboard.Summary = AS.ClientDashboard.Summary or {}

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------

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

local function getPed()
    return PlayerPedId()
end

local function getCoords()
    local ped = getPed()
    if not ped or ped == 0 then
        return nil, nil, nil
    end

    local coords = GetEntityCoords(ped)
    if not coords then
        return nil, nil, nil
    end

    return coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
end

local function getHeading()
    local ped = getPed()
    if not ped or ped == 0 then
        return nil
    end

    return GetEntityHeading(ped)
end

local function getCameraRotation()
    local rx, ry, rz = GetGameplayCamRot(2)
    return rx, ry, rz
end

local function getStreetAndZone()
    local x, y, z = getCoords()
    if not x then
        return nil, nil, nil, nil
    end

    local streetHash, crossingHash = GetStreetNameAtCoord(x, y, z)
    local streetName   = streetHash and GetStreetNameFromHashKey(streetHash) or nil
    local crossingName = crossingHash and GetStreetNameFromHashKey(crossingHash) or nil

    local zoneName  = GetNameOfZone(x, y, z)
    local zoneLabel = zoneName and GetLabelText(zoneName) or zoneName

    return streetName, crossingName, zoneName, zoneLabel
end

local function fmtFloat(num)
    if not num then return '0.00' end
    return string.format('%.2f', num)
end

---------------------------------------------------------------------
-- Dev → NUI copy bridge (clipboard results)
---------------------------------------------------------------------

local function sendCopyResult(id, label, text)
    if not Utils or not Utils.SendNUI then
        warn('sendCopyResult called but Utils.SendNUI is missing.')
        return
    end

    Utils.SendNUI(
        (AS.Events and AS.Events.NUI and AS.Events.NUI.DashboardCopyResult)
            or 'as:nui:dashboard:copyResult',
        {
            id    = id,
            label = label,
            text  = text,
        }
    )
end

---------------------------------------------------------------------
-- Developer tools: copy helpers
---------------------------------------------------------------------

local function runDevCopyVector3()
    local x, y, z = getCoords()
    if not x then
        warn('runDevCopyVector3: failed to get coords.')
        return
    end

    local text = string.format(
        'vector3(%s, %s, %s)',
        fmtFloat(x),
        fmtFloat(y),
        fmtFloat(z)
    )

    sendCopyResult('copy-v3', 'vector3', text)
end

local function runDevCopyVector4()
    local x, y, z = getCoords()
    local h       = getHeading()
    if not x or not h then
        warn('runDevCopyVector4: failed to get coords/heading.')
        return
    end

    local text = string.format(
        'vector4(%s, %s, %s, %s)',
        fmtFloat(x),
        fmtFloat(y),
        fmtFloat(z),
        fmtFloat(h)
    )

    sendCopyResult('copy-v4', 'vector4', text)
end

local function runDevCopyHeading()
    local h = getHeading()
    if not h then
        warn('runDevCopyHeading: failed to get heading.')
        return
    end

    local text = string.format('%.2f', h)
    sendCopyResult('copy-heading', 'Heading', text)
end

local function runDevCopyCamRot()
    local rx, ry, rz = getCameraRotation()
    if not rx then
        warn('runDevCopyCamRot: failed to get camera rotation.')
        return
    end

    local text = string.format(
        'vector3(%s, %s, %s) -- pitch, roll, yaw',
        fmtFloat(rx),
        fmtFloat(ry),
        fmtFloat(rz)
    )

    sendCopyResult('copy-cam-rot', 'camera rotation', text)
end

local function runDevCopyStreetZone()
    local street, crossing, zone, zoneLabel = getStreetAndZone()
    if not street and not crossing and not zoneLabel and not zone then
        warn('runDevCopyStreetZone: no street/zone info available.')
        return
    end

    local components = {}

    if street and street ~= '' then
        table.insert(components, street)
    end

    if crossing and crossing ~= '' then
        table.insert(components, crossing)
    end

    if zoneLabel and zoneLabel ~= '' and zoneLabel ~= 'NULL' then
        table.insert(components, zoneLabel)
    elseif zone and zone ~= '' then
        table.insert(components, zone)
    end

    if #components == 0 then
        warn('runDevCopyStreetZone: no components to copy.')
        return
    end

    local text = table.concat(components, ' / ')
    sendCopyResult('copy-street-zone', 'Street/Zone', text)
end

local function runDevCopyEntityModel()
    local ped = getPed()
    if not ped or ped == 0 then
        warn('runDevCopyEntityModel: no ped.')
        return
    end

    local entity = ped
    local veh    = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        entity = veh
    end

    if not entity or entity == 0 then
        warn('runDevCopyEntityModel: no entity to inspect.')
        return
    end

    local model = GetEntityModel(entity)
    if not model or model == 0 then
        warn('runDevCopyEntityModel: invalid model.')
        return
    end

    -- Numeric hash + hex string for convenience
    local text = string.format(
        '%d -- 0x%X',
        model,
        model
    )

    sendCopyResult('copy-entity-model', 'entity model/hash', text)
end

---------------------------------------------------------------------
-- Friendly street/zone label + 3D overlay
---------------------------------------------------------------------

local function getStreetZoneLabel()
    local street, crossing, zone, zoneLabel = getStreetAndZone()
    if not street and not crossing and not zoneLabel and not zone then
        return nil
    end

    local components = {}

    if street and street ~= '' then
        table.insert(components, street)
    end

    if crossing and crossing ~= '' then
        table.insert(components, crossing)
    end

    if zoneLabel and zoneLabel ~= '' and zoneLabel ~= 'NULL' then
        table.insert(components, zoneLabel)
    elseif zone and zone ~= '' then
        table.insert(components, zone)
    end

    if #components == 0 then
        return nil
    end

    return table.concat(components, ' / ')
end

local function drawStreetZoneText3D(x, y, z, text)
    if not text or text == '' then return end

    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local streetZoneOverlayEnabled       = false
local streetZoneOverlayThreadStarted = false

local function ensureStreetZoneOverlayThread()
    if streetZoneOverlayThreadStarted then return end
    streetZoneOverlayThreadStarted = true

    CreateThread(function()
        while true do
            if streetZoneOverlayEnabled then
                local ped = getPed()
                if ped and ped ~= 0 then
                    local x, y, z = table.unpack(GetEntityCoords(ped))
                    local label   = getStreetZoneLabel()
                    if label then
                        drawStreetZoneText3D(x, y, z + 1.05, label)
                    end
                end
            end

            Wait(0)
        end
    end)
end

---------------------------------------------------------------------
-- Dev tools registry dispatcher
---------------------------------------------------------------------

local DevTools = {
    copy_vector3     = runDevCopyVector3,
    copy_vector4     = runDevCopyVector4,
    copy_heading     = runDevCopyHeading,
    copy_cam_rot     = runDevCopyCamRot,
    copy_street_zone = runDevCopyStreetZone,
    copy_entity_hash = runDevCopyEntityModel,
}

local function handleRunDeveloperTool(id, payload)
    local fn = DevTools[id]
    if not fn then
        warn('Unknown developer tool: %s', tostring(id))
        return
    end

    debug('Running developer tool %s', tostring(id))
    fn(payload)
end

---------------------------------------------------------------------
-- Management tools (placeholder for future dashboard management actions)
---------------------------------------------------------------------

local ManagementTools = {
    -- e.g. "quick_fuel_all", "cleanup_entities", etc.
}

local function handleRunManagementTool(id, payload)
    local fn = ManagementTools[id]
    if not fn then
        warn('Unknown management tool: %s', tostring(id))
        return
    end

    debug('Running management tool %s', tostring(id))
    fn(payload)
end

---------------------------------------------------------------------
-- NUI-facing summary updater
---------------------------------------------------------------------

function AS.ClientDashboard.UpdateSummary(data)
    data = data or {}

    AS.ClientDashboard.Summary = {
        players     = tonumber(data.players)     or 0,
        maxPlayers  = tonumber(data.maxPlayers)  or 0,
        staffOnline = tonumber(data.staffOnline) or 0,
        openReports = tonumber(data.openReports) or 0,
    }

    debug('Dashboard summary stored: %s', json.encode(AS.ClientDashboard.Summary))
end

---------------------------------------------------------------------
-- Event wiring (server → client → NUI)
---------------------------------------------------------------------

if Events and Events.Dashboard and Utils and Utils.SendNUI then
    -----------------------------------------------------------------
    -- Summary updates from server → forward to NUI
    -----------------------------------------------------------------
    if Events.Dashboard.UpdateSummary then
        RegisterNetEvent(Events.Dashboard.UpdateSummary, function(summary)
            summary = summary or {}

            if summary.summary and type(summary.summary) == 'table' then
                summary = summary.summary
            end

            AS.ClientDashboard.UpdateSummary(summary)

            debug('Dashboard summary update (unwrapped): %s', json.encode(summary))

            Utils.SendNUI(
                AS.Events.NUI.DashboardUpdateSummary or 'as:nui:dashboard:updateSummary',
                summary
            )
        end)
    end

    -----------------------------------------------------------------
    -- Developer tools from server (after RBAC etc.)
    --   TriggerClientEvent(Events.Dashboard.RunDeveloperTool, src, id, payload)
    -----------------------------------------------------------------
    if Events.Dashboard.RunDeveloperTool then
        RegisterNetEvent(Events.Dashboard.RunDeveloperTool, function(idOrPayload, maybePayload)
            local actionId
            local payload

            if type(idOrPayload) == 'table' then
                payload  = idOrPayload
                actionId = idOrPayload.id or idOrPayload.action or idOrPayload.tool
            else
                actionId = idOrPayload
                payload  = maybePayload
            end

            handleRunDeveloperTool(actionId, payload)
        end)
    end

    -----------------------------------------------------------------
    -- Management tools from server (after RBAC etc.)
    --   TriggerClientEvent(Events.Dashboard.RunManagementTool, src, id, payload)
    -----------------------------------------------------------------
    if Events.Dashboard.RunManagementTool then
        RegisterNetEvent(Events.Dashboard.RunManagementTool, function(idOrPayload, maybePayload)
            local actionId
            local payload

            if type(idOrPayload) == 'table' then
                payload  = idOrPayload
                actionId = idOrPayload.id or idOrPayload.action or idOrPayload.tool
            else
                actionId = idOrPayload
                payload  = maybePayload
            end

            handleRunManagementTool(actionId, payload)
        end)
    end
end

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------

-- Clear "Recent Actions" from dashboard (button in NUI)
RegisterNUICallback(
    (AS.Events.NUI and AS.Events.NUI.DashboardClearRecent) or 'as:nui:dashboard:clearRecent',
    function(_, cb)
        -- Server-side RBAC will enforce 'god' only
        if Events and Events.Dashboard and Events.Dashboard.ClearRecent then
            TriggerServerEvent(Events.Dashboard.ClearRecent)
        else
            warn('Dashboard.ClearRecent event not configured; cannot clear recent actions.')
        end

        if cb then cb({ ok = true }) end
    end
)
