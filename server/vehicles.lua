AS = AS or {}
AS.Vehicles = AS.Vehicles or {}

local Events = AS.Events
local Utils  = AS.Utils
local Audit  = AS.Audit
local RBAC   = AS.RBAC

AS.Vehicles.Models = AS.Vehicles.Models or {}

local QBCore = nil

-------------------------------------------------
-- QBCore attach (qb-core / qbx-core / qbcore)
-------------------------------------------------
CreateThread(function()
    local coreResources = { 'qb-core', 'qbx-core', 'qbcore' }

    for _, res in ipairs(coreResources) do
        local ok, obj = pcall(function()
            return exports[res]:GetCoreObject()
        end)

        if ok and obj then
            QBCore = obj
            if Utils and Utils.Info then
                Utils.Info(('[AdminSuite] QBCore attached to vehicles.lua using resource "%s"'):format(res))
            else
                print(('[AdminSuite] QBCore attached to vehicles.lua using resource "%s"'):format(res))
            end
            break
        end
    end

    if not QBCore then
        if Utils and Utils.Warn then
            Utils.Warn('[AdminSuite] Failed to attach QBCore in vehicles.lua (tried qb-core / qbx-core / qbcore)')
        else
            print('[AdminSuite:WARN] Failed to attach QBCore in vehicles.lua (tried qb-core / qbx-core / qbcore)')
        end
    end
end)

-------------------------------------------------
-- Small helpers
-------------------------------------------------

local function log(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Vehicles] ' .. msg, ...)
    else
        print(('[AdminSuite:Vehicles] ' .. msg):format(...))
    end
end

local function can(src, flag)
    if RBAC and RBAC.Can then
        local ok = RBAC.Can(src, flag)
        if not ok then
            log('RBAC denied %s for src=%s', flag, tostring(src))
        end
        return ok
    end
    return true
end

local function audit(src, eventName, payload)
    payload = payload or {}

    if Audit and Audit.Log then
        Audit.Log(src, nil, eventName, payload)
    elseif Events and Events.Audit and Events.Audit.Append then
        TriggerEvent(Events.Audit.Append, eventName, nil, payload)
    end
end

-------------------------------------------------
-- Vehicles list (QBCore + meta scan)
-------------------------------------------------

local function buildFromQBCore()
    local out = {}

    -- Support both QBCore.Shared.Vehicles and QBShared.Vehicles
    local sharedVehicles =
        (QBCore and QBCore.Shared and QBCore.Shared.Vehicles)
        or (QBShared and QBShared.Vehicles)

    if not sharedVehicles then
        log("No QBCore vehicle list found (QBCore.Shared.Vehicles or QBShared.Vehicles missing)")
        return out
    end

    for _, v in pairs(sharedVehicles) do
        local model = v.model or v.spawnName or v.vehicle
        if type(model) ~= "string" then
            model = tostring(model)
        end

        out[#out+1] = {
            model      = model:lower(),
            label      = v.name or v.model or model,
            brand      = v.brand or "",
            category   = v.category or "",
            classLabel = v.category or "",
            shop       = v.shop or "",
            source     = "qbshared",
        }
    end

    log(("Built %d vehicles from qb-core shared list"):format(#out))
    return out
end

local function scanMetaModelsForResource(resName)
    local models = {}

    local function scanFile(fileName, pattern)
        local content = LoadResourceFile(resName, fileName)
        if not content then return end

        for model in content:gmatch(pattern) do
            model = model:lower()
            models[#models+1] = model
        end
    end

    scanFile('vehicles.meta', '<modelName>(.-)</modelName>')
    scanFile('carvariations.meta', '<modelName>(.-)</modelName>')
    scanFile('carcols.meta', '<modelName>(.-)</modelName>')
    scanFile('handling.meta', '<handlingName>(.-)</handlingName>')

    return models
end

local function buildFromMeta()
    local out  = {}
    local seen = {}

    local totalResources = GetNumResources() or 0

    for i = 0, totalResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if resName and resName ~= GetCurrentResourceName() then
            local models = scanMetaModelsForResource(resName)
            for _, model in ipairs(models) do
                if not seen[model] then
                    seen[model] = true
                    out[#out+1] = {
                        model      = model,
                        label      = model:upper(),
                        brand      = '',
                        category   = '',
                        classLabel = '',
                        shop       = '',
                        source     = ('meta:%s'):format(resName),
                    }
                end
            end
        end
    end

    log('Built %d vehicles from meta scan', #out)
    return out
end

function AS.Vehicles.BuildList()
    local combined = {}
    local seen     = {}

    local function ingest(list)
        if not list then return end
        for _, entry in ipairs(list) do
            local model = entry.model
            if model and model ~= '' then
                model = tostring(model):lower()
                if not seen[model] then
                    seen[model] = true
                    entry.model = model
                    combined[#combined+1] = entry
                end
            end
        end
    end

    ingest(buildFromQBCore())
    ingest(buildFromMeta())

    AS.Vehicles.Models = combined
    log('Vehicles.BuildList() populated %d models', #AS.Vehicles.Models)
    return AS.Vehicles.Models
end

function AS.Vehicles.GetList()
    if not AS.Vehicles.Models or #AS.Vehicles.Models == 0 then
        AS.Vehicles.BuildList()
    end
    return AS.Vehicles.Models
end

function AS.Vehicles.Refresh()
    AS.Vehicles.BuildList()
    return AS.Vehicles.Models
end

local function modelExists(model)
    model = tostring(model or ''):lower()
    if model == '' then return false end

    for _, v in ipairs(AS.Vehicles.GetList()) do
        if v.model == model then
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Quick Action vehicle tools
-------------------------------------------------

if Events and Events.VehicleTools then

    RegisterNetEvent(Events.VehicleTools.Spawn, function(payload)
        local src = source
        if not can(src, 'can_spawn_vehicle') then return end

        local model
        if type(payload) == 'table' then
            model = payload.model
                or payload.modelName
                or payload.vehicle
                or payload.spawn
                or payload.code
        elseif type(payload) == 'string' then
            model = payload
        end

        if not model or model == '' then
            if Utils and Utils.Notify then
                Utils.Notify(src, 'No vehicle model provided.', 'error')
            end
            return
        end

        model = tostring(model):lower()

        if not modelExists(model) then
            audit(src, 'vehicle:spawn:denied', {
                model  = model,
                reason = 'unknown_model',
            })

            if Utils and Utils.Notify then
                Utils.Notify(src, ('Model "%s" is not in the vehicles list.'):format(model), 'error')
            end
            return
        end

        audit(src, 'vehicle:spawn', { model = model })
        TriggerClientEvent('as:vehicles:client:spawn', src, model)
    end)

    RegisterNetEvent(Events.VehicleTools.Repair, function(info)
        local src = source
        if not can(src, 'can_fix_vehicle') then return end

        audit(src, 'vehicle:repair', info or {})
        TriggerClientEvent('as:vehicles:client:repair', src)
    end)

    RegisterNetEvent(Events.VehicleTools.Wash, function(info)
        local src = source
        if not can(src, 'can_wash_vehicle') then return end

        audit(src, 'vehicle:wash', info or {})
        TriggerClientEvent('as:vehicles:client:wash', src)
    end)

    RegisterNetEvent(Events.VehicleTools.Refuel, function(info)
        local src = source
        if not can(src, 'can_refuel_vehicle') then return end

        audit(src, 'vehicle:refuel', info or {})
        TriggerClientEvent('as:vehicles:client:refuel', src)
    end)

    RegisterNetEvent(Events.VehicleTools.DeleteTemp, function(info)
        local src = source
        if not can(src, 'can_delete_vehicle') then return end

        audit(src, 'vehicle:deleteTemp', info or {})
        TriggerClientEvent('as:vehicles:client:deleteTemp', src)
    end)

    RegisterNetEvent(Events.VehicleTools.SeatIn, function(info)
        local src = source
        if not can(src, 'can_seat_in_vehicle') then return end

        audit(src, 'vehicle:seatIn', info or {})
        TriggerClientEvent('as:vehicles:client:seatIn', src)
    end)

    RegisterNetEvent(Events.VehicleTools.SeatOut, function(info)
        local src = source
        if not can(src, 'can_seat_out_vehicle') then return end

        audit(src, 'vehicle:seatOut', info or {})
        TriggerClientEvent('as:vehicles:client:seatOut', src)
    end)

else
    log('Events.VehicleTools not defined; vehicle quick actions will be disabled.')
end

-------------------------------------------------
-- Vehicles view events (NUI → server → client)
-------------------------------------------------

if Events and Events.Vehicles then

    RegisterNetEvent(Events.Vehicles.GetList, function()
        local src = source
        TriggerClientEvent(Events.Vehicles.GetList, src, AS.Vehicles.GetList())
    end)

    RegisterNetEvent(Events.Vehicles.RefreshList, function()
        local src = source
        TriggerClientEvent(Events.Vehicles.RefreshList, src, AS.Vehicles.Refresh())
    end)

else
    log('Events.Vehicles not defined; skipping vehicles list wiring.')
end

-------------------------------------------------
-- Init message
-------------------------------------------------

if Utils and Utils.Info then
    Utils.Info(('Vehicles module initialized (models=%d)'):format(#AS.Vehicles.Models))
else
    print(('[AdminSuite:Vehicles] initialized (models=%d)'):format(#AS.Vehicles.Models))
end
