AS = AS or {}
AS.ClientVehicles = AS.ClientVehicles or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientVehicles.List = AS.ClientVehicles.List or {}

-------------------------------------------------
-- Small helpers
-------------------------------------------------

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Vehicles:Client] ' .. msg, ...)
    else
        print(('[AdminSuite:Vehicles:Client] ' .. msg):format(...))
    end
end

local function notify(label, ntype)
    if Utils and Utils.Notify then
        Utils.Notify(label, ntype or 'info')
    end
end

local function getRelevantVehicle(radius)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh and veh ~= 0 then
        return veh
    end

    local coords = GetEntityCoords(ped)
    radius = radius or 6.0

    local closest = 0
    local closestDist = radius + 0.01

    -- Use GetClosestVehicle which is cheap enough for this radius
    local v = GetClosestVehicle(coords.x, coords.y, coords.z, radius, 0, 70)
    if v and v ~= 0 then
        closest = v
    end

    return closest
end

-------------------------------------------------
-- Server → Client: Vehicles list (future view)
-------------------------------------------------

if Events and Events.Vehicles then
    RegisterNetEvent(Events.Vehicles.GetList, function(list)
        AS.ClientVehicles.List = list or {}
        debug('Vehicles list received (%d)', #AS.ClientVehicles.List)

        if AS.ClientUtils and AS.ClientUtils.SendNUI then
            AS.ClientUtils.SendNUI(
                (AS.Events.NUI and AS.Events.NUI.VehiclesLoad) or 'as:nui:vehicles:load',
                list or {}
            )
        end
    end)

    RegisterNetEvent(Events.Vehicles.RefreshList, function(list)
        AS.ClientVehicles.List = list or {}
        debug('Vehicles list refreshed (%d)', #AS.ClientVehicles.List)

        if AS.ClientUtils and AS.ClientUtils.SendNUI then
            AS.ClientUtils.SendNUI(
                (AS.Events.NUI and AS.Events.NUI.VehiclesRefresh) or 'as:nui:vehicles:refresh',
                list or {}
            )
        end
    end)
end

-------------------------------------------------
-- Quick Action controls from server
-------------------------------------------------

-- Spawn a simple admin vehicle near the player
RegisterNetEvent('as:vehicles:client:spawn', function(model)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local modelName = type(model) == 'string' and model or 'adder'
    local modelHash = GetHashKey(modelName)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        notify(('Vehicle model "%s" not found.'):format(modelName), 'error')
        return
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        notify(('Failed to load model "%s".'):format(modelName), 'error')
        return
    end

    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    if veh and veh ~= 0 then
        SetVehicleOnGroundProperly(veh)
        SetEntityAsMissionEntity(veh, true, true)
        SetPedIntoVehicle(ped, veh, -1)
        SetVehicleNumberPlateText(veh, 'FOUNDER')
        SetModelAsNoLongerNeeded(modelHash)

        notify(('Spawned %s'):format(modelName), 'success')
        debug('Spawned vehicle model=%s', modelName)
    else
        notify('Failed to create vehicle.', 'error')
    end
end)

-- Repair current / nearby vehicle
RegisterNetEvent('as:vehicles:client:repair', function()
    local veh = getRelevantVehicle(8.0)
    if not veh or veh == 0 then
        notify('No vehicle nearby to repair.', 'error')
        return
    end

    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)

    notify('Vehicle repaired.', 'success')
end)

-- Wash current / nearby vehicle
RegisterNetEvent('as:vehicles:client:wash', function()
    local veh = getRelevantVehicle(8.0)
    if not veh or veh == 0 then
        notify('No vehicle nearby to wash.', 'error')
        return
    end

    SetVehicleDirtLevel(veh, 0.0)
    notify('Vehicle washed.', 'success')
end)

-- Refuel current / nearby vehicle
RegisterNetEvent('as:vehicles:client:refuel', function()
    local veh = getRelevantVehicle(8.0)
    if not veh or veh == 0 then
        notify('No vehicle nearby to refuel.', 'error')
        return
    end

    -- Generic FiveM fuel level; compatible with most fuel scripts
    SetVehicleFuelLevel(veh, 100.0)
    notify('Vehicle refueled.', 'success')
end)

-- Temporarily delete current / nearby vehicle (no DB)
RegisterNetEvent('as:vehicles:client:deleteTemp', function()
    local ped = PlayerPedId()
    local veh = getRelevantVehicle(8.0)

    if not veh or veh == 0 then
        notify('No vehicle nearby to delete.', 'error')
        return
    end

    if IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) == veh then
        TaskLeaveVehicle(ped, veh, 16)
        Wait(500)
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end

    notify('Vehicle deleted.', 'success')
end)

-- Seat into nearest vehicle (driver seat)
RegisterNetEvent('as:vehicles:client:seatIn', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify('You are already in a vehicle.', 'error')
        return
    end

    local veh = getRelevantVehicle(8.0)
    if not veh or veh == 0 then
        notify('No vehicle nearby to seat into.', 'error')
        return
    end

    TaskWarpPedIntoVehicle(ped, veh, -1)
    notify('Seated in vehicle.', 'success')
end)

-- Seat out of current vehicle
RegisterNetEvent('as:vehicles:client:seatOut', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        notify('You are not in a vehicle.', 'error')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    TaskLeaveVehicle(ped, veh, 16)
    notify('Exited vehicle.', 'success')
end)
