-- AdminSuite - Player Moderation (client)
AS = AS or {}
AS.ClientModeration = AS.ClientModeration or {}

local Events = AS.Events
local Utils  = AS.ClientUtils
local Config = AS.Config or Config

-- TEMP: allow self-spectate for testing
local ALLOW_SELF_SPECTATE = true

AS.ClientModeration.Players  = AS.ClientModeration.Players or {}
AS.ClientModeration.Spectate = AS.ClientModeration.Spectate or {}

local Spectate = AS.ClientModeration.Spectate

----------------------------------------------------------------------
-- NUI population (player list + detail)
----------------------------------------------------------------------

if Events and Events.Moderation then
    RegisterNetEvent(Events.Moderation.GetPlayers, function(list)
        AS.ClientModeration.Players = list or {}
        if Utils and Utils.Debug then
            Utils.Debug('Moderation players snapshot (%d)', #AS.ClientModeration.Players)
        end

        AS.ClientUtils.SendNUI(
            AS.Events.NUI.ModerationLoadPlayers or 'as:nui:moderation:loadPlayers',
            list or {}
        )
    end)

    RegisterNetEvent(Events.Moderation.GetPlayerDetail, function(detail)
        AS.ClientUtils.SendNUI(
            AS.Events.NUI.ModerationRefreshPlayer or 'as:nui:moderation:refreshPlayer',
            detail or {}
        )
    end)
end

----------------------------------------------------------------------
-- Client-side effects for moderation actions
--  (freeze, teleport, sendBack)
----------------------------------------------------------------------

local lastAdminSuitePos = nil

--========================
-- Teleport helper
--========================
local function teleportToCoords(coords)
    if not coords or (type(coords) ~= 'vector3' and type(coords) ~= 'table') then return end

    local ped = PlayerPedId()
    lastAdminSuitePos = GetEntityCoords(ped)

    local x, y, z
    if type(coords) == 'vector3' then
        x, y, z = coords.x, coords.y, coords.z
    else
        x, y, z = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
    end

    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, true)
end

--========================
-- Freeze / Unfreeze
--========================
RegisterNetEvent('AdminSuite:moderation:freeze', function(shouldFreeze)
    local ped = PlayerPedId()

    if shouldFreeze then
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
    else
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
    end
end)

--========================
-- Bring (admin → target)
--========================
RegisterNetEvent('AdminSuite:moderation:bring', function(payload)
    local ped = PlayerPedId()

    -- New path: server sends coords table
    if type(payload) == 'table' and payload.x and payload.y and payload.z then
        teleportToCoords(payload)
        return
    end

    -- Legacy path: server sent adminSrc id
    local adminSrc = tonumber(payload)
    if not adminSrc then return end

    local adminPlayer = GetPlayerFromServerId(adminSrc)
    if adminPlayer == -1 then
        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] bring: could not resolve admin player (src=%s)', tostring(adminSrc))
        end
        return
    end

    local adminPed = GetPlayerPed(adminPlayer)
    if not DoesEntityExist(adminPed) then
        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] bring: admin ped does not exist (src=%s)', tostring(adminSrc))
        end
        return
    end

    local coords = GetEntityCoords(adminPed)
    teleportToCoords(coords)
end)


--========================
-- Goto (admin → target)
-- Supports:
--  • New payload: { x, y, z }  (server sends coords directly)
--  • Legacy payload: targetSrc (server sends player id)
--========================
RegisterNetEvent('AdminSuite:moderation:goto', function(payload)
    local ped = PlayerPedId()

    --========================
    -- NEW PATH: server sends coord table
    --========================
    if type(payload) == 'table' and payload.x and payload.y and payload.z then
        -- This will be the path once you update the server to send coords.
        teleportToCoords(payload)
        return
    end

    --========================
    -- LEGACY PATH: server sends targetSrc (server id)
    -- (this is exactly your original logic)
    --========================
    local targetSrc = tonumber(payload)
    if not targetSrc then return end

    local targetPlayer = GetPlayerFromServerId(targetSrc)
    if targetPlayer == -1 then return end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then return end

    -- If the target is in a vehicle, try to put the staff in a passenger seat
    if IsPedInAnyVehicle(targetPed, false) then
        local vehicle = GetVehiclePedIsIn(targetPed, false)
        if vehicle ~= 0 then
            local model    = GetEntityModel(vehicle)
            local maxSeats = GetVehicleModelNumberOfSeats(model) or 0
            local seatToUse

            -- Prefer front passenger (0), then other passenger seats (1, 2, ...)
            -- Seats are usually: -1 = driver, 0..(maxSeats-2) = passengers
            for seat = 0, maxSeats - 2 do
                if IsVehicleSeatFree(vehicle, seat) then
                    seatToUse = seat
                    break
                end
            end

            if seatToUse ~= nil then
                -- Remember where the admin was before entering the vehicle
                lastAdminSuitePos = GetEntityCoords(ped)

                -- Instantly warp the staff into the vehicle
                TaskWarpPedIntoVehicle(ped, vehicle, seatToUse)
                return
            else
                -- Vehicle is full: teleport the staff just behind the vehicle
                local coords  = GetEntityCoords(targetPed)
                local forward = GetEntityForwardVector(targetPed)
                local offset  = 2.0

                teleportToCoords({
                    x = coords.x - forward.x * offset,
                    y = coords.y - forward.y * offset,
                    z = coords.z
                })
                return
            end
        end
    end

    -- Target is NOT in a vehicle: normal teleport to their position
    local coords = GetEntityCoords(targetPed)
    teleportToCoords(coords)
end)


--========================
-- SendBack (return to lastAdminSuitePos)
--========================
RegisterNetEvent('AdminSuite:moderation:sendBack', function()
    if not lastAdminSuitePos then
        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] sendBack called but no last position stored')
        end
        return
    end

    local ped = PlayerPedId()
    SetEntityCoords(
        ped,
        lastAdminSuitePos.x,
        lastAdminSuitePos.y,
        lastAdminSuitePos.z,
        false,
        false,
        false,
        true
    )
end)


----------------------------------------------------------------------
-- View Inventory
----------------------------------------------------------------------

RegisterNetEvent('AdminSuite:moderation:viewInventory', function(data)
    data = data or {}

    -- Preferred path: custom AdminSuite inventory window
    if data.items and type(data.items) == 'table' then
        if Utils and Utils.Debug then
            Utils.Debug(
                '[Moderation] viewInventory snapshot received (items=%d, target=%s)',
                #data.items,
                tostring(data.target or '?')
            )
        end

        AS.ClientUtils.SendNUI(
            AS.Events.NUI.ModerationOpenInventory or 'as:nui:moderation:openInventory',
            {
                target        = data.target,
                targetName    = data.targetName,
                targetCitizen = data.targetCitizen,
                items         = data.items,
            }
        )

        return
    end

    -- Fallback: original behavior (open underlying inventory script UI)
    local invCfg = (Config and Config.Inventory) or {}
    local system = (data.system or invCfg.System or 'qb-inventory')

    if type(system) == 'string' then
        system = system:lower()
    else
        system = 'qb-inventory'
    end

    local target = data.target or data.targetSrc or data.id
    target = tonumber(target)

    if not target then
        if Utils and Utils.Debug then
            Utils.Debug(
                '[Moderation] viewInventory: missing/invalid target id (raw=%s)',
                tostring(data.target or data.targetSrc or data.id)
            )
        else
            print('[AdminSuite] viewInventory: missing/invalid target id')
        end
        return
    end

    local oxinv = GetResourceState('ox_inventory'):find('start') ~= nil
    local qbinv = GetResourceState('qb-inventory'):find('start') ~= nil
    local qsinv = GetResourceState('qs-inventory'):find('start') ~= nil
    local psinv = GetResourceState('ps-inventory'):find('start') ~= nil

    if system == '' or system == 'auto' then
        if oxinv then
            system = 'ox_inventory'
        elseif qbinv or qsinv or psinv then
            system = 'qb-inventory'
        else
            system = 'none'
        end
    end

    if Utils and Utils.Debug then
        Utils.Debug(
            '[Moderation] viewInventory fallback fired (system=%s, target=%s)',
            tostring(system),
            tostring(target)
        )
    else
        print(('[AdminSuite] viewInventory fired (system=%s, target=%s)'):format(tostring(system), tostring(target)))
    end

    -- ======================================================
    -- UPDATED: Only fire ONE open-inventory event.
    -- (Previously this fired 2-3 events, which can cause
    --  inventory resync conflicts / duplication symptoms.)
    -- ======================================================

    if system == 'qb-inventory' or system == 'qs-inventory' or system == 'ps-inventory' then
        local customEvt = invCfg.OpenTargetInventoryEvent
        if customEvt and customEvt ~= '' then
            if Utils and Utils.Debug then
                Utils.Debug('[Moderation] viewInventory using custom event "%s"', customEvt)
            end
            TriggerServerEvent(customEvt, 'otherplayer', target)
            return
        end

        -- Prefer the most common/modern qb event name when qb/ps/qs style is in use.
        if qbinv or qsinv or psinv then
            TriggerServerEvent('qb-inventory:server:OpenInventory', 'otherplayer', target)
            return
        end

        -- Absolute fallback: only if you truly rely on a generic inventory resource.
        TriggerServerEvent('inventory:server:OpenInventory', 'otherplayer', target)

    elseif system == 'ox_inventory' or system == 'ox-inventory' then
        if oxinv and exports.ox_inventory then
            if Utils and Utils.Debug then
                Utils.Debug('[Moderation] viewInventory using ox_inventory export')
            end
            exports.ox_inventory:openInventory('player', target)
        else
            print('[AdminSuite] viewInventory: ox_inventory configured but resource not running')
        end

    else
        local evt = invCfg.OpenTargetInventoryEvent
        if evt and evt ~= '' then
            if Utils and Utils.Debug then
                Utils.Debug('[Moderation] viewInventory (fallback) using custom event "%s"', evt)
            end
            TriggerServerEvent(evt, 'otherplayer', target)
        else
            print(('[AdminSuite] ViewInventory not configured for inventory system "%s"'):format(system))
        end
    end
end)

----------------------------------------------------------------------
-- Warn red-screen overlay (client)
----------------------------------------------------------------------

local warnOverlayActive   = false
local warnOverlayMessage  = nil
local warnOverlayStaff    = nil
local warnOverlayKeyLabel = 'E'
local warnOverlayKeyCode  = 38 -- INPUT_PICKUP (default: E)

local function drawCenteredText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function startWarnOverlay()
    if warnOverlayActive then
        return
    end

    warnOverlayActive = true

    CreateThread(function()
        local ped       = PlayerPedId()
        local wasFrozen = IsEntityPositionFrozen(ped)

        FreezeEntityPosition(ped, true)

        while warnOverlayActive do
            Wait(0)

            DrawRect(0.5, 0.5, 1.0, 1.0, 200, 0, 0, 200)

            local header = 'YOU HAVE BEEN WARNED BY STAFF'
            drawCenteredText(header, 0.5, 0.35, 0.9)

            local reasonText = warnOverlayMessage or 'No reason provided.'
            drawCenteredText(reasonText, 0.5, 0.45, 0.6)

            if warnOverlayStaff then
                local staffLine = ('Issued by: %s'):format(warnOverlayStaff)
                drawCenteredText(staffLine, 0.5, 0.52, 0.5)
            end

            local instruction = ('Press [%s] to acknowledge this warning'):format(warnOverlayKeyLabel or 'E')
            drawCenteredText(instruction, 0.5, 0.60, 0.5)

            DisableAllControlActions(0)

            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)

            EnableControlAction(0, warnOverlayKeyCode, true)

            if IsDisabledControlJustPressed(0, warnOverlayKeyCode) then
                warnOverlayActive = false
            end
        end

        FreezeEntityPosition(ped, wasFrozen)
    end)
end

if Events and Events.Moderation and Events.Moderation.Warn then
    RegisterNetEvent(Events.Moderation.Warn, function(payload)
        if type(payload) ~= 'table' then
            return
        end

        warnOverlayMessage  = tostring(payload.reason or 'You have been warned by staff.')
        warnOverlayStaff    = payload.staff and tostring(payload.staff) or nil
        warnOverlayKeyLabel = payload.keyLabel or 'E'
        warnOverlayKeyCode  = 38

        startWarnOverlay()
    end)
end
