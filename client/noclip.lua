-- client/noclip.lua
-- AdminSuite NoClip (qb-admin style, keymapping-based)

AS         = AS or {}
AS.Noclip  = AS.Noclip or {}

local Events = AS.Events or {}
local Utils  = AS.ClientUtils or {}

local IsNoClipping      = false
local PlayerPed         = nil
local NoClipEntity      = nil
local Camera            = nil
local NoClipAlpha       = nil
local PlayerIsInVehicle = false
local ResourceName      = GetCurrentResourceName()

local MinY, MaxY        = -89.0, 89.0

-- Configurable behavior
local PedFirstPersonNoClip  = true   -- First-person when on foot
local VehFirstPersonNoClip  = false  -- Third-person by default in vehicles
local ESCEnable             = false  -- Allow ESC/map while in noclip

-- Speed settings
local Speed                 = 1.0    -- Base speed
local MaxSpeed              = 16.0   -- Max speed multiplier

-- Movement control indices (GTA/FiveM controls, NOT keycodes)
local MOVE_FORWARDS         = 32  -- W
local MOVE_BACKWARDS        = 33  -- S
local MOVE_LEFT             = 34  -- A
local MOVE_RIGHT            = 35  -- D
local MOVE_UP               = 44  -- Q
local MOVE_DOWN             = 20  -- Z (default binding)

-- Speed modifiers / wheel
local SPEED_DECREASE        = 14   -- Mouse wheel down
local SPEED_INCREASE        = 15   -- Mouse wheel up
local SPEED_RESET           = 348  -- Mouse wheel click
local SPEED_SLOW_MODIFIER   = 36   -- Left CTRL
local SPEED_FAST_MODIFIER   = 21   -- Left SHIFT
local SPEED_FASTER_MODIFIER = 19   -- Left ALT

-- Forward declarations
local ToggleNoClip, StopNoClip, RunNoClipThread

local function Notify(msg, type_)
    if Utils and Utils.Notify then
        Utils.Notify(msg, type_ or 'info')
    else
        print(('[AdminSuite] %s'):format(msg))
    end
end

-------------------------------------------------------
-- Core helpers
-------------------------------------------------------

local function DisabledControls()
    HudWeaponWheelIgnoreSelection()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)

    -- Allow look around
    EnableControlAction(0, 220, true)
    EnableControlAction(0, 221, true)

    -- Chat / PTT
    EnableControlAction(0, 245, true)

    if ESCEnable then
        EnableControlAction(0, 200, true) -- ESC
    end
end

local function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

local function IsPedDrivingVehicle(ped, veh)
    return ped == GetPedInVehicleSeat(veh, -1)
end

local function SetupCam()
    local entityRot = GetEntityRotation(NoClipEntity)
    Camera = CreateCameraWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        GetEntityCoords(NoClipEntity),
        vector3(0.0, 0.0, entityRot.z),
        75.0
    )

    SetCamActive(Camera, true)
    RenderScriptCams(true, true, 1000, false, false)

    if PlayerIsInVehicle == 1 then
        AttachCamToEntity(
            Camera,
            NoClipEntity,
            0.0,
            VehFirstPersonNoClip and 0.5 or -4.5,
            VehFirstPersonNoClip and 1.0 or 2.0,
            true
        )
    else
        AttachCamToEntity(
            Camera,
            NoClipEntity,
            0.0,
            PedFirstPersonNoClip and 0.0 or -2.0,
            PedFirstPersonNoClip and 1.0 or 0.5,
            true
        )
    end
end

local function DestroyCamera()
    SetGameplayCamRelativeHeading(0.0)
    RenderScriptCams(false, true, 1000, true, true)
    if NoClipEntity then
        DetachEntity(NoClipEntity, true, true)
    end

    if Camera then
        SetCamActive(Camera, false)
        DestroyCam(Camera, true)
        Camera = nil
    end
end

local function GetGroundCoords(coords)
    local rayCast           = StartShapeTestRay(coords.x, coords.y, coords.z, coords.x, coords.y, -10000.0, 1, 0)
    local _, hit, hitCoords = GetShapeTestResult(rayCast)
    return (hit == 1 and hitCoords) or coords
end

local function CheckInputRotation()
    if not Camera then return end

    local rightAxisX = GetControlNormal(0, 220)
    local rightAxisY = GetControlNormal(0, 221)

    local rotation = GetCamRot(Camera, 2)

    local yValue = rightAxisY * -5.0
    local newX
    local newZ = rotation.z + (rightAxisX * -10.0)

    if (rotation.x + yValue > MinY) and (rotation.x + yValue < MaxY) then
        newX = rotation.x + yValue
    end

    if newX ~= nil and newZ ~= nil then
        SetCamRot(Camera, vector3(newX, rotation.y, newZ), 2)
    end

    if NoClipEntity then
        SetEntityHeading(NoClipEntity, math.max(0.0, (rotation.z % 360.0)))
    end
end

-------------------------------------------------------
-- NoClip main loop
-------------------------------------------------------

RunNoClipThread = function()
    CreateThread(function()
        while IsNoClipping do
            Wait(0)

            CheckInputRotation()
            DisabledControls()

            -- Adjust base speed with scroll wheel
            if IsControlAlwaysPressed(2, SPEED_DECREASE) then
                Speed = Speed - 0.5
                if Speed < 0.5 then Speed = 0.5 end
            elseif IsControlAlwaysPressed(2, SPEED_INCREASE) then
                Speed = Speed + 0.5
                if Speed > MaxSpeed then Speed = MaxSpeed end
            elseif IsDisabledControlJustReleased(0, SPEED_RESET) then
                Speed = 1.0
            end

            -- Speed modifiers
            local multi = 1.0
            if IsControlAlwaysPressed(0, SPEED_FAST_MODIFIER) then
                multi = 2.0
            elseif IsControlAlwaysPressed(0, SPEED_FASTER_MODIFIER) then
                multi = 4.0
            elseif IsControlAlwaysPressed(0, SPEED_SLOW_MODIFIER) then
                multi = 0.25
            end

            -- Forward / backward
            if IsControlAlwaysPressed(0, MOVE_FORWARDS) then
                local pitch = GetCamRot(Camera, 0)
                if pitch.x >= 0.0 then
                    SetEntityCoordsNoOffset(
                        NoClipEntity,
                        GetOffsetFromEntityInWorldCoords(
                            NoClipEntity,
                            0.0,
                            0.5 * (Speed * multi),
                            (pitch.x * ((Speed / 2.0) * multi)) / 89.0
                        )
                    )
                else
                    SetEntityCoordsNoOffset(
                        NoClipEntity,
                        GetOffsetFromEntityInWorldCoords(
                            NoClipEntity,
                            0.0,
                            0.5 * (Speed * multi),
                            -1.0 * ((math.abs(pitch.x) * ((Speed / 2.0) * multi)) / 89.0)
                        )
                    )
                end
            elseif IsControlAlwaysPressed(0, MOVE_BACKWARDS) then
                local pitch = GetCamRot(Camera, 2)
                if pitch.x >= 0.0 then
                    SetEntityCoordsNoOffset(
                        NoClipEntity,
                        GetOffsetFromEntityInWorldCoords(
                            NoClipEntity,
                            0.0,
                            -0.5 * (Speed * multi),
                            -1.0 * (pitch.x * ((Speed / 2.0) * multi)) / 89.0
                        )
                    )
                else
                    SetEntityCoordsNoOffset(
                        NoClipEntity,
                        GetOffsetFromEntityInWorldCoords(
                            NoClipEntity,
                            0.0,
                            -0.5 * (Speed * multi),
                            ((math.abs(pitch.x) * ((Speed / 2.0) * multi)) / 89.0)
                        )
                    )
                end
            end

            -- Strafe
            if IsControlAlwaysPressed(0, MOVE_LEFT) then
                SetEntityCoordsNoOffset(
                    NoClipEntity,
                    GetOffsetFromEntityInWorldCoords(NoClipEntity, -0.5 * (Speed * multi), 0.0, 0.0)
                )
            elseif IsControlAlwaysPressed(0, MOVE_RIGHT) then
                SetEntityCoordsNoOffset(
                    NoClipEntity,
                    GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.5 * (Speed * multi), 0.0, 0.0)
                )
            end

            -- Up / down
            if IsControlAlwaysPressed(0, MOVE_UP) then
                SetEntityCoordsNoOffset(
                    NoClipEntity,
                    GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, 0.5 * (Speed * multi))
                )
            elseif IsControlAlwaysPressed(0, MOVE_DOWN) then
                SetEntityCoordsNoOffset(
                    NoClipEntity,
                    GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, -0.5 * (Speed * multi))
                )
            end

            local coords = GetEntityCoords(NoClipEntity)
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)

            FreezeEntityPosition(NoClipEntity, true)
            SetEntityCollision(NoClipEntity, false, false)
            SetEntityVisible(NoClipEntity, false, false)
            SetEntityInvincible(NoClipEntity, true)
            SetLocalPlayerVisibleLocally(true)
            SetEntityAlpha(NoClipEntity, NoClipAlpha, false)

            if PlayerIsInVehicle == 1 then
                SetEntityAlpha(PlayerPed, NoClipAlpha, false)
            end

            SetEveryoneIgnorePlayer(PlayerPed, true)
            SetPoliceIgnorePlayer(PlayerPed, true)
        end

        StopNoClip()
    end)
end

-------------------------------------------------------
-- Stop / Toggle
-------------------------------------------------------

StopNoClip = function()
    if not NoClipEntity or not PlayerPed then return end

    FreezeEntityPosition(NoClipEntity, false)
    SetEntityCollision(NoClipEntity, true, true)
    SetEntityVisible(NoClipEntity, true, false)
    SetLocalPlayerVisibleLocally(true)
    ResetEntityAlpha(NoClipEntity)
    ResetEntityAlpha(PlayerPed)
    SetEveryoneIgnorePlayer(PlayerPed, false)
    SetPoliceIgnorePlayer(PlayerPed, false)
    SetEntityInvincible(NoClipEntity, false)

    if GetVehiclePedIsIn(PlayerPed, false) ~= 0 then
        while (not IsVehicleOnAllWheels(NoClipEntity)) and not IsNoClipping do
            Wait(0)
        end
    else
        if (IsPedFalling(NoClipEntity) and math.abs(1.0 - GetEntityHeightAboveGround(NoClipEntity)) > 1.00) then
            while (IsPedStopped(NoClipEntity) or not IsPedFalling(NoClipEntity)) and not IsNoClipping do
                Wait(0)
            end
        end

        while not IsNoClipping do
            Wait(0)
            if (not IsPedFalling(NoClipEntity)) and (not IsPedRagdoll(NoClipEntity)) then
                break
            end
        end
    end
end

ToggleNoClip = function(state)
    IsNoClipping      = state ~= nil and state or not IsNoClipping
    PlayerPed         = PlayerPedId()
    PlayerIsInVehicle = IsPedInAnyVehicle(PlayerPed, false) and 1 or 0

    if PlayerIsInVehicle == 1 and IsPedDrivingVehicle(PlayerPed, GetVehiclePedIsIn(PlayerPed, false)) then
        NoClipEntity = GetVehiclePedIsIn(PlayerPed, false)
        SetVehicleEngineOn(NoClipEntity, not IsNoClipping, true, IsNoClipping)
        NoClipAlpha = PedFirstPersonNoClip and 0 or 51
    else
        NoClipEntity = PlayerPed
        NoClipAlpha  = VehFirstPersonNoClip and 0 or 51
    end

    if IsNoClipping then
        FreezeEntityPosition(PlayerPed, true)
        SetupCam()
        PlaySoundFromEntity(-1, 'SELECT', PlayerPed, 'HUD_LIQUOR_STORE_SOUNDSET', 0, 0)

        if not PlayerIsInVehicle then
            ClearPedTasksImmediately(PlayerPed)
            if PedFirstPersonNoClip then
                Wait(1000)
            end
        else
            if VehFirstPersonNoClip then
                Wait(1000)
            end
        end
    else
        local groundCoords = GetGroundCoords(GetEntityCoords(NoClipEntity))
        SetEntityCoords(NoClipEntity, groundCoords.x, groundCoords.y, groundCoords.z)
        Wait(50)
        DestroyCamera()
        PlaySoundFromEntity(-1, 'CANCEL', PlayerPed, 'HUD_LIQUOR_STORE_SOUNDSET', 0, 0)
    end

    Notify(IsNoClipping and 'NoClip enabled.' or 'NoClip disabled.', IsNoClipping and 'success' or 'error')
    SetUserRadioControlEnabled(not IsNoClipping)

    if IsNoClipping then
        RunNoClipThread()
    end
end

-------------------------------------------------------
-- RBAC check (mirror panel logic)
-------------------------------------------------------

local function getSelfRBAC()
    if AS and AS.ClientRBAC and AS.ClientRBAC.GetSelf then
        local data = AS.ClientRBAC.GetSelf()
        if Utils and Utils.Debug then
            Utils.Debug('Noclip RBAC self: %s', json.encode(data or {}))
        end
        return data
    end

    if Events and Events.RBAC and Events.RBAC.GetSelf then
        TriggerServerEvent(Events.RBAC.GetSelf)
    end

    if Utils and Utils.Debug then
        Utils.Debug('Noclip: RBAC helper missing; requested RBAC self from server.')
    end

    return nil
end

local function canToggleNoclip()
    local self = getSelfRBAC()
    if not self or not self.role then
        if Utils and Utils.Debug then
            Utils.Debug('RBAC denies noclip: no role assigned.')
        end
        return false
    end

    -- For now: any mapped staff role can use noclip (same as panel access).
    return true
end

-------------------------------------------------------
-- Keymapping + Events
-------------------------------------------------------

local NoclipCommandName = 'as_noclip_toggle'
local DefaultBind       = 'INSERT'

local function getConfiguredBind()
    if AS and AS.Config and AS.Config.Keys and AS.Config.Keys.ToggleNoclip then
        return AS.Config.Keys.ToggleNoclip
    end
    return DefaultBind
end

RegisterCommand(NoclipCommandName, function()
    if not canToggleNoclip() then
        Notify('You are not authorized to use noclip.', 'error')
        return
    end

    -- If server-side noclip toggle exists, prefer that for auditing.
    if Events and Events.Core and Events.Core.ToggleNoclip then
        TriggerServerEvent(Events.Core.ToggleNoclip)
    else
        ToggleNoClip()
    end
end, false)

RegisterKeyMapping(
    NoclipCommandName,
    'AdminSuite - Toggle NoClip',
    'keyboard',
    getConfiguredBind()
)

if Events and Events.Core and Events.Core.ToggleNoclip then
    RegisterNetEvent(Events.Core.ToggleNoclip, function(state)
        ToggleNoClip(state)
    end)
end



-------------------------------------------------------
-- Cleanup on resource stop
-------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= ResourceName then return end

    if IsNoClipping and NoClipEntity and PlayerPed then
        IsNoClipping = false
        StopNoClip()
        DestroyCamera()
    end
end)
