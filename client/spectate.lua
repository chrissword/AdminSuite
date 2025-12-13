-- AdminSuite - Spectate (client)
AS = AS or {}
AS.ClientModeration = AS.ClientModeration or {}
AS.ClientModeration.Spectate = AS.ClientModeration.Spectate or {}

local Spectate = AS.ClientModeration.Spectate

local Events = AS.Events
local Utils  = AS.ClientUtils
local Config = AS.Config or Config
----------------------------------------------------------------------
-- Spectate: state + helpers (mirrors 919, but with NUI mini HUD)
----------------------------------------------------------------------

Spectate.active             = Spectate.active or false
Spectate.currentIndex       = Spectate.currentIndex or nil
Spectate.order              = Spectate.order or {}
Spectate.currentTarget      = Spectate.currentTarget or nil

local savedSpectatePos      = nil
local spectateCursorEnabled = false

local KEY_LEFT      = 174  -- Left arrow
local KEY_RIGHT     = 175  -- Right arrow
local KEY_BACKSPACE = 177  -- Backspace (stop)

local function getRowServerId(row)
    if not row or type(row) ~= 'table' then return nil end
    return row.source or row.src or row.id or row.serverId or row.playerId or row.playerid
end

local function getRowName(row, fallbackId)
    if not row or type(row) ~= 'table' then
        return fallbackId and ('ID ' .. tostring(fallbackId)) or 'Unknown'
    end

    return row.name
        or row.playerName
        or row.fullName
        or row.charName
        or (fallbackId and ('ID ' .. tostring(fallbackId)))
        or 'Unknown'
end

local function buildSpectateOrder(targetSrc)
    local players = AS.ClientModeration.Players or {}
    local order   = {}
    local index   = nil

    targetSrc = tonumber(targetSrc)

    for _, row in ipairs(players) do
        local src = tonumber(getRowServerId(row))
        if src then
            local name       = getRowName(row, src)
            local entryIndex = #order + 1

            order[entryIndex] = {
                src  = src,
                name = name,
            }

            if targetSrc and src == targetSrc then
                index = entryIndex
            end
        end
    end

    -- If target not in snapshot, still allow single-target spectate
    if (not order[1]) and targetSrc then
        order[1] = {
            src  = targetSrc,
            name = 'ID ' .. tostring(targetSrc),
        }
        index = 1
    end

    -- Fallback: if we have an order but no index, default to first
    if order[1] and not index then
        index = 1
    end

    return order, index
end

local function sendSpectateHUDStart(entry)
    if not entry then return end

    if Utils and Utils.Debug then
        Utils.Debug(
            '[Moderation] spectate HUD start (src=%s, name=%s)',
            tostring(entry.src),
            tostring(entry.name)
        )
    end

    -- NUI mini HUD event
    AS.ClientUtils.SendNUI(
        AS.Events.NUI.ModerationSpectateStart or 'as:nui:moderation:spectate:start',
        {
            targetSrc   = entry.src,
            targetName  = entry.name,
            playerName  = entry.name,  -- matches main.js expectation
        }
    )

    -- Transparent spectate mode on
    SendNUIMessage({
        type       = 'as:spectate:enter',
        playerName = entry.name
    })
end

local function sendSpectateHUDUpdate(entry)
    if not entry then return end

    AS.ClientUtils.SendNUI(
        AS.Events.NUI.ModerationSpectateUpdate or 'as:nui:moderation:spectate:update',
        {
            targetSrc   = entry.src,
            targetName  = entry.name,
            playerName  = entry.name,
        }
    )
end

local function sendSpectateHUDStop()
    -- NUI mini HUD stop event
    AS.ClientUtils.SendNUI(
        AS.Events.NUI.ModerationSpectateStop or 'as:nui:moderation:spectate:stop',
        {}
    )

    -- Transparent spectate mode off
    SendNUIMessage({
        type = 'as:spectate:exit'
    })
end

local function setSpectateCursor(enabled)
    spectateCursorEnabled = enabled and true or false

    if AS and AS.NUI and AS.NUI.SetFocus then
        AS.NUI.SetFocus(spectateCursorEnabled)
    else
        SetNuiFocus(spectateCursorEnabled, spectateCursorEnabled)
    end

    SetNuiFocusKeepInput(spectateCursorEnabled)

    SendNUIMessage({
        type    = 'as:spectate:cursor',
        enabled = spectateCursorEnabled
    })
end

----------------------------------------------------------------------
-- Spectate cursor keymapping (default F2)
----------------------------------------------------------------------

local function toggleSpectateCursorKeybind()
    if not Spectate.active then
        return
    end

    setSpectateCursor(not spectateCursorEnabled)
end

RegisterCommand('as_spectate_cursor', function()
    toggleSpectateCursorKeybind()
end, false)

RegisterKeyMapping(
    'as_spectate_cursor',
    'AdminSuite - Spectate cursor toggle',
    'keyboard',
    'F2'
)

local function beginNativeSpectateOnPed(targetPed, targetSrc, targetName)
    local playerPed = PlayerPedId()

    if targetSrc == GetPlayerServerId(PlayerId()) then
        -- Self-spectate testing: no native spectate on self
        Spectate.currentTarget = targetSrc
        sendSpectateHUDUpdate({ src = targetSrc, name = targetName })
        return
    end

    local coords = GetEntityCoords(targetPed)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(200)

    NetworkSetInSpectatorMode(true, targetPed)
    SetEntityInvincible(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityCollision(playerPed, false, false)

    Spectate.currentTarget = targetSrc
    sendSpectateHUDUpdate({ src = targetSrc, name = targetName })
end

local function spectateGotoEntry(entry, teleportCoords)
    if not entry or not entry.src then return end

    local playerPed = PlayerPedId()

    -- Optional local-only teleport near the target to help streaming in their ped
    if teleportCoords and teleportCoords.x then
        SetEntityCoords(
            playerPed,
            teleportCoords.x,
            teleportCoords.y,
            (teleportCoords.z or 0.0) - 10.0,
            false, false, false, false
        )
    end

    local targetPlayer = -1
    local targetPed

    -- Retry loop similar to 919_admin: wait for the target to exist clientside
    local maxAttempts = 20      -- up to ~4 seconds if delay=200
    local delay       = 200

    for _ = 1, maxAttempts do
        targetPlayer = GetPlayerFromServerId(entry.src)

        if targetPlayer ~= -1 then
            targetPed = GetPlayerPed(targetPlayer)
            if targetPed ~= 0 and DoesEntityExist(targetPed) then
                break
            end
        end

        Wait(delay)
    end

    if not targetPed or targetPlayer == -1 or not DoesEntityExist(targetPed) then
        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] spectate: target %s not found clientside after retries', tostring(entry.src))
        end
        return
    end

    beginNativeSpectateOnPed(targetPed, entry.src, entry.name)
end

local function spectateCycle(delta)
    if not Spectate.active or not Spectate.order or #Spectate.order == 0 or not Spectate.currentIndex then
        return
    end

    local count = #Spectate.order
    if count <= 1 then return end

    local newIndex = Spectate.currentIndex + (delta or 0)
    if newIndex < 1 then
        newIndex = count
    elseif newIndex > count then
        newIndex = 1
    end

    Spectate.currentIndex = newIndex
    local entry = Spectate.order[newIndex]
    if not entry or not entry.src then return end

    -- Ask the server for this new target's coords, just like the initial spectate
    if Events and Events.Moderation and Events.Moderation.SpectateStart then
        TriggerServerEvent(Events.Moderation.SpectateStart, entry.src)
    else
        -- Fallback: pure client-side if mapping not present
        spectateGotoEntry(entry)
    end
end


local function startSpectateControlThread()
    CreateThread(function()
        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] spectate control thread started')
        end

        while Spectate.active do
            Wait(0)

            -- Make sure *we* own these keys while spectating
            DisableControlAction(0, KEY_LEFT, true)
            DisableControlAction(0, KEY_RIGHT, true)
            DisableControlAction(0, KEY_BACKSPACE, true)

            -- Left / Right arrow cycle while spectating
            if IsDisabledControlJustPressed(0, KEY_LEFT) then
                spectateCycle(-1)
            elseif IsDisabledControlJustPressed(0, KEY_RIGHT) then
                spectateCycle(1)
            end

            -- Backspace: request stop spectate
            if IsDisabledControlJustPressed(0, KEY_BACKSPACE) then
                if Events and Events.Moderation and Events.Moderation.SpectateStop then
                    TriggerServerEvent(Events.Moderation.SpectateStop)
                else
                    if Utils and Utils.Debug then
                        Utils.Debug('[Moderation] spectateStop fallback (no Events.Moderation.SpectateStop)')
                    end
                    pcall(function()
                        local fn = _G.handleSpectateStop
                        if fn then fn() end
                    end)
                end
            end
        end

        if Utils and Utils.Debug then
            Utils.Debug('[Moderation] spectate control thread ended')
        end
    end)
end

local function handleSpectateStart(targetSrc, tgtCoords)
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local myServerId = GetPlayerServerId(PlayerId())

    if (not ALLOW_SELF_SPECTATE) and targetSrc == myServerId then
        if Utils and Utils.Notify then
            Utils.Notify('[AdminSuite] You cannot spectate yourself.')
        elseif Utils and Utils.Debug then
            Utils.Debug('[Moderation] self-spectate attempted, blocking.')
        end
        return
    end

    local ped = PlayerPedId()

    -- Close main AdminSuite panel if open
    if AS and AS.NUI and AS.NUI.IsOpen and AS.NUI.IsOpen() then
        AS.NUI.Close()
    end

    savedSpectatePos = GetEntityCoords(ped)

    local order, index = buildSpectateOrder(targetSrc)
    Spectate.order         = order or {}
    Spectate.currentIndex  = index
    Spectate.currentTarget = targetSrc
    Spectate.active        = true

    setSpectateCursor(false)

    local firstEntry
    if Spectate.currentIndex and Spectate.order[Spectate.currentIndex] then
        firstEntry = Spectate.order[Spectate.currentIndex]
    else
        firstEntry = {
            src  = targetSrc,
            name = 'ID ' .. tostring(targetSrc),
        }
    end

    sendSpectateHUDStart(firstEntry)

    -- On initial spectate start, pass coords from server (if provided)
    spectateGotoEntry(firstEntry, tgtCoords)

    startSpectateControlThread()

    if Utils and Utils.Debug then
        Utils.Debug(
            '[Moderation] spectateStart (target=%s, orderSize=%d, index=%s)',
            tostring(targetSrc),
            #Spectate.order,
            tostring(Spectate.currentIndex)
        )
    end
end

local function handleSpectateStop()
    local ped = PlayerPedId()

    if not Spectate.active then
        return
    end

    Spectate.active        = false
    Spectate.currentIndex  = nil
    Spectate.order         = {}
    Spectate.currentTarget = nil

    setSpectateCursor(false)

    NetworkSetInSpectatorMode(false, ped)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)

    if savedSpectatePos then
        RequestCollisionAtCoord(savedSpectatePos.x, savedSpectatePos.y, savedSpectatePos.z)
        Wait(200)
        SetEntityCoords(
            ped,
            savedSpectatePos.x,
            savedSpectatePos.y,
            savedSpectatePos.z,
            false,
            false,
            false,
            true
        )
    end

    savedSpectatePos = nil

    sendSpectateHUDStop()

    if AS and AS.NUI and AS.NUI.Open then
        AS.NUI.Open()
        SendNUIMessage({
            type = 'as:panel:navigate',
            view = 'moderation'
        })
    end

    if Utils and Utils.Debug then
        Utils.Debug('[Moderation] spectateStop (panel reopened)')
    end
end

-- expose for internal fallback in Backspace handler
_G.handleSpectateStop = handleSpectateStop

----------------------------------------------------------------------
-- Legacy AdminSuite spectate events (keep for compatibility)
----------------------------------------------------------------------

RegisterNetEvent('AdminSuite:moderation:spectateStart', function(targetSrc, tgtCoords)
    handleSpectateStart(targetSrc, tgtCoords)
end)

RegisterNetEvent('AdminSuite:moderation:spectateStop', function()
    handleSpectateStop()
end)

----------------------------------------------------------------------
-- Events map spectate start/stop (preferred)
----------------------------------------------------------------------

if Events and Events.Moderation and Events.Moderation.SpectateStart then
    RegisterNetEvent(Events.Moderation.SpectateStart, function(targetSrc, tgtCoords)
        handleSpectateStart(targetSrc, tgtCoords)
    end)
end

if Events and Events.Moderation and Events.Moderation.SpectateStop then
    RegisterNetEvent(Events.Moderation.SpectateStop, function()
        handleSpectateStop()
    end)
end
