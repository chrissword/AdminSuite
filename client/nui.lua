AS     = AS or {}
AS.NUI = AS.NUI or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

local isOpen                 = false
local nuiHasFocus            = false

local devOverlayEnabled      = false
local devEntityInfoEnabled   = false
local superJumpEnabled       = false
local fastRunEnabled         = false
local infiniteStaminaEnabled = false
local godModeEnabled         = false

---------------------------------------------------------------------
-- Minimal lib.callback.await stub (if ox_lib is NOT present)
---------------------------------------------------------------------

if type(lib) ~= 'table' then lib = {} end
lib.callback = lib.callback or {}

if lib.callback.await == nil then
    local pendingCallbacks = {}
    local nextCallbackId   = 0

    -- Server → Client response for callbacks
    RegisterNetEvent('as:lib:cb:resp', function(id, result)
        local p = pendingCallbacks[id]
        if not p then return end
        pendingCallbacks[id] = nil
        p:resolve(result)
    end)

    function lib.callback.await(name, ...)
        nextCallbackId = nextCallbackId + 1
        local id = nextCallbackId

        local p = promise.new()
        pendingCallbacks[id] = p

        TriggerServerEvent('as:lib:cb:req', name, id, { ... })

        local result = Citizen.Await(p)
        return result
    end
end

---------------------------------------------------------------------
-- Theme helpers
---------------------------------------------------------------------

local function getDefaultDarkMode()
    return (AS.Config and AS.Config.Theme and AS.Config.Theme.DefaultDarkMode == 1) or false
end

local function getStoredDarkMode()
    -- Uses resource KVP so it persists between sessions for this player
    local value = GetResourceKvpString('AdminSuite:darkMode')
    if value == 'dark' then
        return true
    elseif value == 'light' then
        return false
    end

    return nil -- no stored preference yet
end

local function storeDarkMode(isDark)
    SetResourceKvp('AdminSuite:darkMode', isDark and 'dark' or 'light')
end

local function getEffectiveDarkMode()
    local stored = getStoredDarkMode()
    if stored ~= nil then
        return stored
    end

    return getDefaultDarkMode()
end

---------------------------------------------------------------------
-- Small 2D text helpers (for dev overlay / entity info)
---------------------------------------------------------------------

local function drawText2D(x, y, text, scale)
    scale = scale or 0.30

    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 205)
    SetTextDropShadow()
    SetTextOutline()
    SetTextJustification(1)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

---------------------------------------------------------------------
-- Focus helper (single place to control NUI focus)
---------------------------------------------------------------------

function AS.NUI.SetFocus(hasFocus)
    hasFocus    = hasFocus and true or false
    nuiHasFocus = hasFocus

    if Utils and Utils.SetNuiFocus then
        Utils.SetNuiFocus(hasFocus, hasFocus)
    else
        SetNuiFocus(hasFocus, hasFocus)
    end
end

function AS.NUI.HasFocus()
    return nuiHasFocus
end

---------------------------------------------------------------------
-- Panel open / close
---------------------------------------------------------------------

function AS.NUI.Open()
    if isOpen then return end
    isOpen = true

    if Utils and Utils.Debug then
        Utils.Debug('Opening AdminSuite panel')
    end

    AS.NUI.SetFocus(true)

    local prefersDark = getEffectiveDarkMode()

    -- Tell NUI to open the panel (existing behavior)
    Utils.SendNUI(AS.Events.NUI.PanelOpen or 'as:nui:panel:open', {
        darkMode = prefersDark,
    })

    -- Ask the server for the vehicles list right away
    if Events and Events.Vehicles and Events.Vehicles.GetList then
        if Utils and Utils.Debug then
            Utils.Debug('Requesting Vehicles list on panel open')
        end
        TriggerServerEvent(Events.Vehicles.GetList)
    end

    -- Ask the server for the ITEMS list right away
    if Events and Events.Items and Events.Items.GetList then
        if Utils and Utils.Debug then
            Utils.Debug('Requesting Items list on panel open')
        end
        TriggerServerEvent(Events.Items.GetList)
    end

    -- Ask the server for the resources list right away
    if Events and Events.Resources and Events.Resources.GetList then
        if Utils and Utils.Debug then
            Utils.Debug('Requesting Resources list on panel open')
        end
        TriggerServerEvent(Events.Resources.GetList)
    end
end


function AS.NUI.Close()
    if not isOpen then return end
    isOpen = false

    if Utils and Utils.Debug then
        Utils.Debug('Closing AdminSuite panel')
    end

    AS.NUI.SetFocus(false)

    Utils.SendNUI(AS.Events.NUI.PanelClose or 'as:nui:panel:close', {})
end

function AS.NUI.Toggle()
    if isOpen then
        AS.NUI.Close()
    else
        AS.NUI.Open()
    end
end

function AS.NUI.IsOpen()
    return isOpen
end

---------------------------------------------------------------------
-- NUI Callbacks (JS → Lua)
---------------------------------------------------------------------

-- Panel lifecycle
RegisterNUICallback('as:nui:panel:ready', function(_, cb)
    if Utils and Utils.Debug then
        Utils.Debug('NUI panel ready')
    end

    cb('ok')

    -- Ask server for initial core payload (role, theme, etc.)
    if Events and Events.Core and Events.Core.Init then
        TriggerServerEvent(Events.Core.Init)
    end
end)

RegisterNUICallback('as:nui:panel:close', function(_, cb)
    AS.NUI.Close()
    cb('ok')
end)

-- Legacy aliases
RegisterNUICallback('as_panel_close', function(_, cb)
    AS.NUI.Close()
    cb('ok')
end)

RegisterNUICallback('as_panel_navigate', function(data, cb)
    if Utils and Utils.Debug then
        Utils.Debug('NUI navigate: %s', json.encode(data or {}))
    end
    cb('ok')

    -- When navigating to specific views, request fresh data
    data = data or {}
    local view = tostring(data.view or data.targetView or data.id or '')

    -- Vehicles
    if view == 'vehicles' and Events and Events.Vehicles and Events.Vehicles.GetList then
        TriggerServerEvent(Events.Vehicles.GetList)
    end

    -- Resources
    if view == 'resources' and Events and Events.Resources and Events.Resources.GetList then
        TriggerServerEvent(Events.Resources.GetList)
    end
end)

-- Theme / dark mode toggle from JS
RegisterNUICallback('as:nui:panel:setDarkMode', function(data, cb)
    local dark   = data and data.dark
    local isDark = dark and true or false

    if Utils and Utils.Debug then
        Utils.Debug('NUI setDarkMode: %s', tostring(isDark))
    end

    -- Persist per-player preference using resource KVP
    storeDarkMode(isDark)

    if cb then
        cb('ok')
    end
end)

---------------------------------------------------------------------
-- Dashboard
---------------------------------------------------------------------

-- Dashboard summary request (JS → Lua → server)
RegisterNUICallback('as:nui:dashboard:getSummary', function(_, cb)
    if Utils and Utils.Debug then
        Utils.Debug('NUI dashboard:getSummary')
    end

    cb('ok')

    if Events and Events.Dashboard and Events.Dashboard.GetSummary then
        TriggerServerEvent(Events.Dashboard.GetSummary)
    elseif Events and Events.Core and Events.Core.SyncState then
        -- Fallback to core sync if dashboard namespace not present
        TriggerServerEvent(Events.Core.SyncState)
    end
end)

local function getSelfServerId()
    return GetPlayerServerId(PlayerId())
end

local function sendDevCopyToNui(id, label, text)
    if not text or text == '' then
        if Utils and Utils.Debug then
            Utils.Debug('Dev copy %s produced empty text; skipping NUI send.', id or 'unknown')
        end
        return
    end

    -- This is what dashboard.js is listening for and will push to the clipboard
    Utils.SendNUI('as:nui:dashboard:copyResult', {
        id    = id,
        label = label,
        text  = text,
    })
end

-- Dashboard Quick Actions
RegisterNUICallback('as:nui:dashboard:runQuickAction', function(data, cb)
    data = data or {}
    local group = tostring(data.group or '')
    local id    = tostring(data.id or '')

    if Utils and Utils.Debug then
        Utils.Debug('NUI dashboard:runQuickAction group=%s id=%s', group, id)
    end

    ------------------------------------------------
    -- SELF UTILITIES
    ------------------------------------------------
    if group == 'self' then
        local myServerId = getSelfServerId()
        local ped        = PlayerPedId()

        if id == 'heal' and Events.Moderation and Events.Moderation.Heal then
            TriggerServerEvent(Events.Moderation.Heal, myServerId)
            Utils.Notify('Requested self heal.')

        elseif id == 'revive' and Events.Moderation and Events.Moderation.Revive then
            TriggerServerEvent(Events.Moderation.Revive, myServerId)
            Utils.Notify('Requested self revive.')

        elseif id == 'super-jump' then
            superJumpEnabled = not superJumpEnabled
            Utils.Notify(
                ('Super Jump: %s'):format(superJumpEnabled and 'On' or 'Off'),
                superJumpEnabled and 'success' or 'error'
            )

        elseif id == 'fast-run' then
            fastRunEnabled = not fastRunEnabled
            Utils.Notify(
                ('Fast Run: %s'):format(fastRunEnabled and 'On' or 'Off'),
                fastRunEnabled and 'success' or 'error'
            )

        elseif id == 'infinite-stamina' then
            infiniteStaminaEnabled = not infiniteStaminaEnabled
            Utils.Notify(
                ('Infinite Stamina: %s'):format(infiniteStaminaEnabled and 'On' or 'Off'),
                infiniteStaminaEnabled and 'success' or 'error'
            )

        elseif id == 'god-mode' then
            godModeEnabled = not godModeEnabled
            Utils.Notify(
                ('God Mode: %s'):format(godModeEnabled and 'On' or 'Off'),
                godModeEnabled and 'success' or 'error'
            )

        elseif id == 'clear-blood' then
            ClearPedBloodDamage(ped)
            Utils.Notify('Cleared blood from ped.')

        elseif id == 'wet-clothes' then
            SetPedWetnessHeight(ped, 2.0)
            Utils.Notify('Set clothes to wet.')

        elseif id == 'dry-clothes' then
            ClearPedWetness(ped)
            Utils.Notify('Set clothes to dry.')
        end

    ------------------------------------------------
    -- DEVELOPER TOOLS
    ------------------------------------------------
    elseif group == 'dev' then
        local ped     = PlayerPedId()
        local coords  = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        if id == 'copy-v3' then
            local text = ('vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z)
            Utils.Notify("Copied to clipboard!!")
            print('[AdminSuite:Dev] ' .. text)
            sendDevCopyToNui('copy-v3', 'vector3 coords', text)

        elseif id == 'copy-v4' then
            local text = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(
                coords.x, coords.y, coords.z, heading
            )
            Utils.Notify("Copied to clipboard!!")
            print('[AdminSuite:Dev] ' .. text)
            sendDevCopyToNui('copy-v4', 'vector4 coords', text)

        elseif id == 'copy-heading' then
            local text = ('%.2f'):format(heading)
            Utils.Notify("Copied Heading")
            print('[AdminSuite:Dev] heading = ' .. text)
            sendDevCopyToNui('copy-heading', 'heading', text)

        elseif id == 'copy-cam-rot' then
            local rot  = GetGameplayCamRot(2)
            local text = ('vector3(%.2f, %.2f, %.2f)'):format(rot.x, rot.y, rot.z)
            Utils.Notify("Camera Rotation Copied")
            print('[AdminSuite:Dev] camRot = ' .. text)
            sendDevCopyToNui('copy-cam-rot', 'camera rotation', text)

        elseif id == 'copy-entity-model' then
            local entity
            if IsPedInAnyVehicle(ped, false) then
                entity = GetVehiclePedIsIn(ped, false)
            else
                entity = ped
            end

            local modelHash = GetEntityModel(entity)
            local hexHash   = ('0x%X'):format(modelHash)
            local text      = ('%d -- %s'):format(modelHash, hexHash)

            Utils.Notify("Copied Model/Hash")
            print('[AdminSuite:Dev] entity model = ' .. text)
            sendDevCopyToNui('copy-entity-model', 'entity model/hash', text)

        elseif id == 'copy-street-zone' then
            local x, y, z               = coords.x, coords.y, coords.z
            local streetHash, crossHash = GetStreetNameAtCoord(x, y, z)
            local streetName            = streetHash and GetStreetNameFromHashKey(streetHash) or 'Unknown'
            local crossingName          = crossHash and GetStreetNameFromHashKey(crossHash) or nil
            local zoneName              = GetNameOfZone(x, y, z)
            local zoneLabel             = zoneName and GetLabelText(zoneName) or zoneName

            local displayZone = (zoneLabel ~= 'NULL' and zoneLabel) or zoneName or 'Unknown'
            local text

            if crossingName and crossingName ~= '' then
                text = ('%s / %s (%s)'):format(streetName, crossingName, displayZone)
            else
                text = ('%s (%s)'):format(streetName, displayZone)
            end

            Utils.Notify(('Dev street/zone: %s'):format(text))
            print('[AdminSuite:Dev] street/zone = ' .. text)
            sendDevCopyToNui('copy-street-zone', 'street & zone', text)

        elseif id == 'toggle-dev-overlay' then
            devOverlayEnabled = not devOverlayEnabled
            if devOverlayEnabled then
                Utils.Notify('Dev overlay toggled ON.', 'success')
            else
                Utils.Notify('Dev overlay toggled OFF.', 'error')
            end

        elseif id == 'toggle-entity-info' then
            devEntityInfoEnabled = not devEntityInfoEnabled
            if devEntityInfoEnabled then
                Utils.Notify('Dev entity info toggled ON (aim at entities to see details).', 'success')
            else
                Utils.Notify('Dev entity info toggled OFF.', 'error')
            end
        end

    ------------------------------------------------
    -- VEHICLE TOOLS
    ------------------------------------------------
    elseif group == 'vehicle' then
        local ped = PlayerPedId()

        local function getRelevantVehicle(radius)
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                return veh
            end

            local coords = GetEntityCoords(ped)
            radius = radius or 8.0

            local v = GetClosestVehicle(coords.x, coords.y, coords.z, radius, 0, 70)
            if v and v ~= 0 then
                return v
            end

            return 0
        end

        if id == 'spawn' then
            if Events.VehicleTools and Events.VehicleTools.Spawn then
                -- Server controls RBAC + audit + instructs client to spawn
                TriggerServerEvent(Events.VehicleTools.Spawn, {})
                if Utils and Utils.Notify then
                    Utils.Notify('Requested vehicle spawn.')
                end
            end
        else
            local veh = getRelevantVehicle(8.0)
            if veh == 0 then
                if Utils and Utils.Notify then
                    Utils.Notify('No vehicle nearby for that action.', 'error')
                end
                cb('no-vehicle')
                return
            end

            local netId = NetworkGetNetworkIdFromEntity(veh)
            local plate = GetVehicleNumberPlateText(veh)

            if id == 'fix' and Events.VehicleTools and Events.VehicleTools.Repair then
                TriggerServerEvent(Events.VehicleTools.Repair, {
                    netId = netId,
                    plate = plate,
                })

            elseif id == 'wash' and Events.VehicleTools and Events.VehicleTools.Wash then
                TriggerServerEvent(Events.VehicleTools.Wash, {
                    netId = netId,
                    plate = plate,
                })

            elseif id == 'refuel' and Events.VehicleTools and Events.VehicleTools.Refuel then
                TriggerServerEvent(Events.VehicleTools.Refuel, {
                    netId = netId,
                    plate = plate,
                })

            elseif id == 'delete' and Events.VehicleTools and Events.VehicleTools.DeleteTemp then
                TriggerServerEvent(Events.VehicleTools.DeleteTemp, {
                    netId = netId,
                    plate = plate,
                })

            elseif id == 'seat-in' and Events.VehicleTools and Events.VehicleTools.SeatIn then
                TriggerServerEvent(Events.VehicleTools.SeatIn, {
                    netId = netId,
                    plate = plate,
                })

            elseif id == 'seat-out' and Events.VehicleTools and Events.VehicleTools.SeatOut then
                TriggerServerEvent(Events.VehicleTools.SeatOut, {
                    netId = netId,
                    plate = plate,
                })
            end
        end

        ---------------------------------------------------------------------
-- NUI: Resources actions (start / stop / restart)
---------------------------------------------------------------------
RegisterNUICallback('as:nui:resources:action', function(data, cb)
    local resource = data and data.resource
    local action   = data and data.action

    if resource and action and Events and Events.Resources and Events.Resources.Action then
        TriggerServerEvent(Events.Resources.Action, resource, action)
    end

    if cb then cb({ ok = true }) end
end)

---------------------------------------------------------------------
-- NUI: Resources refresh (refresh button in UI)
---------------------------------------------------------------------
RegisterNUICallback('as:nui:resources:refresh', function(data, cb)
    if Events and Events.Resources and Events.Resources.Request then
        TriggerServerEvent(Events.Resources.Request)
    end

    if cb then cb({ ok = true }) end
end)


    ------------------------------------------------
    -- MANAGEMENT TOOLS
    ------------------------------------------------
    elseif group == 'mgmt' then
        if id == 'toggle-ids' and Events.World and Events.World.ToggleIds then
            TriggerServerEvent(Events.World.ToggleIds)

        elseif id == 'toggle-names' and Events.World and Events.World.ToggleNames then
            TriggerServerEvent(Events.World.ToggleNames)

        elseif id == 'toggle-radar' and Events.World and Events.World.ToggleRadar then
            TriggerServerEvent(Events.World.ToggleRadar)
        end
    end

    cb('ok')
end)

---------------------------------------------------------------------
-- Player Moderation
---------------------------------------------------------------------

RegisterNUICallback('as:nui:moderation:loadPlayers', function(_, cb)
    if Utils and Utils.Debug then
        Utils.Debug('NUI moderation:loadPlayers')
    end

    if Events and Events.Moderation and Events.Moderation.GetPlayers then
        TriggerServerEvent(Events.Moderation.GetPlayers)
    else
        if Utils and Utils.Debug then
            Utils.Debug('Events.Moderation.GetPlayers is missing')
        end
    end

    cb('ok')
end)

RegisterNUICallback('as:nui:moderation:selectPlayer', function(data, cb)
    if Utils and Utils.Debug then
        Utils.Debug('NUI moderation:selectPlayer %s', json.encode(data or {}))
    end
    cb('ok')
end)

local function parseDurationSeconds(text)
    if not text or text == '' then
        return 0 -- permanent
    end

    text = string.lower(tostring(text))

    if text == 'perm' or text == 'permanent' then
        return 0
    end

    local num, unit = text:match('(%d+)%s*(%a*)')
    num = tonumber(num)
    if not num then
        return 0
    end

    unit = unit or ''
    if unit == '' or unit == 'm' or unit == 'min' or unit == 'mins' then
        return num * 60
    elseif unit == 'h' or unit == 'hr' or unit == 'hrs' then
        return num * 3600
    elseif unit == 'd' or unit == 'day' or unit == 'days' then
        return num * 86400
    else
        return num -- fallback seconds
    end
end

RegisterNUICallback('as:nui:moderation:executeAction', function(data, cb)
    data = data or {}

    local action = tostring(data.action or '')
    local target = tonumber(data.target or data.targetId or 0)
    local extra  = data.extra or {}
    local reason = extra.reason
    local durationSeconds = parseDurationSeconds(extra.duration)

    if Utils and Utils.Debug then
        Utils.Debug(
            'NUI moderation:executeAction %s -> %s (reason=%s, duration=%s)',
            action,
            target or -1,
            tostring(reason or 'nil'),
            tostring(extra.duration or 'nil')
        )
    end

    if not target or target <= 0 then
        cb('invalid-target')
        return
    end

    if not Events or not Events.Moderation then
        cb('no-events')
        return
    end

    ------------------------------------------------
    -- Core moderation
    ------------------------------------------------
    if action == 'kick' and Events.Moderation.Kick then
        TriggerServerEvent(Events.Moderation.Kick, target, reason)

    elseif action == 'warn' and Events.Moderation.Warn then
        TriggerServerEvent(Events.Moderation.Warn, target, reason)

    elseif action == 'ban' and Events.Moderation.Ban then
        TriggerServerEvent(Events.Moderation.Ban, target, reason, durationSeconds)

    elseif action == 'unban' and Events.Moderation.Unban then
        TriggerServerEvent(Events.Moderation.Unban, tostring(target))

    ------------------------------------------------
    -- Utility / movement / state
    ------------------------------------------------
    elseif action == 'heal' and Events.Moderation.Heal then
        TriggerServerEvent(Events.Moderation.Heal, target)

    elseif action == 'revive' and Events.Moderation.Revive then
        TriggerServerEvent(Events.Moderation.Revive, target)

    elseif action == 'freeze' and Events.Moderation.Freeze then
        TriggerServerEvent(Events.Moderation.Freeze, target, true)

    elseif action == 'unfreeze' and Events.Moderation.Unfreeze then
        TriggerServerEvent(Events.Moderation.Unfreeze, target, false)

    elseif action == 'bring' and Events.Moderation.Bring then
        TriggerServerEvent(Events.Moderation.Bring, target)

    elseif action == 'goto' and Events.Moderation.Goto then
        TriggerServerEvent(Events.Moderation.Goto, target)

    elseif action == 'sendBack' and Events.Moderation.SendBack then
        TriggerServerEvent(Events.Moderation.SendBack, target)

    elseif action == 'spectate:start' and Events.Moderation.SpectateStart then
        TriggerServerEvent(Events.Moderation.SpectateStart, target)

    elseif action == 'spectate:stop' and Events.Moderation.SpectateStop then
        TriggerServerEvent(Events.Moderation.SpectateStop)

    ------------------------------------------------
    -- Messaging
    ------------------------------------------------
    elseif action == 'message' and Events.Moderation.Message then
        local msg = extra.message or reason or ''
        TriggerServerEvent(Events.Moderation.Message, target, tostring(msg or ''))

    ------------------------------------------------
    -- Money
    ------------------------------------------------
    elseif action == 'giveMoney' and Events.Moderation.GiveMoney then
        local account = (extra.account or 'cash'):lower()
        local amount  = tonumber(extra.amount) or 0
        TriggerServerEvent(Events.Moderation.GiveMoney, target, account, amount)

    elseif action == 'takeMoney' and Events.Moderation.TakeMoney then
        local account = (extra.account or 'cash'):lower()
        local amount  = tonumber(extra.amount) or 0
        TriggerServerEvent(Events.Moderation.TakeMoney, target, account, amount)

    ------------------------------------------------
    -- Inventory
    ------------------------------------------------
    elseif action == 'viewInventory' and Events.Moderation.ViewInventory then
        TriggerServerEvent(Events.Moderation.ViewInventory, target)

    elseif action == 'giveItem' and Events.Moderation.GiveItem then
        local item   = tostring(extra.item or '')
        local amount = tonumber(extra.amount) or 1
        TriggerServerEvent(Events.Moderation.GiveItem, target, item, amount)

    elseif action == 'removeItem' and Events.Moderation.RemoveItem then
        local item   = tostring(extra.item or '')
        local amount = tonumber(extra.amount) or 1
        TriggerServerEvent(Events.Moderation.RemoveItem, target, item, amount)

    ------------------------------------------------
    -- Fallback
    ------------------------------------------------
    else
        if Utils and Utils.Debug then
            Utils.Debug('Unknown moderation action from NUI: %s', action)
        end
    end

    cb('ok')
end)

---------------------------------------------------------------------
-- Banned Players (NUI ↔ Lua ↔ Server)
---------------------------------------------------------------------

-- Request the current bans list from the server when the Banned Players view asks for it
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load',
    function(_, cb)
        if Utils and Utils.Debug then
            Utils.Debug('NUI bannedplayers:load -> server')
        end

        TriggerServerEvent(AS.Events.NUI and AS.Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load')

        if cb then
            cb({ ok = true })
        end
    end
)

-- Request an unban from the server for a specific ban entry
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.BannedPlayersUnban or 'as:nui:bannedplayers:unban',
    function(data, cb)
        data = data or {}

        if Utils and Utils.Debug then
            Utils.Debug('NUI bannedplayers:unban -> server payload=%s', json.encode(data))
        end

        TriggerServerEvent(
            AS.Events.NUI and AS.Events.NUI.BannedPlayersUnban or 'as:nui:bannedplayers:unban',
            data
        )

        if cb then
            cb({ ok = true })
        end
    end
)

-- When the server pushes a bans list down, forward it into NUI so bannedplayers.js can update the table
RegisterNetEvent(AS.Events.NUI and AS.Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', function(payload)
    payload = payload or {}

    if Utils and Utils.Debug then
        Utils.Debug('Client received bans payload from server; forwarding to NUI.')
    end

    Utils.SendNUI(
        AS.Events.NUI and AS.Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load',
        payload
    )
end)

---------------------------------------------------------------------
-- Docs: staff panel NUI callbacks
---------------------------------------------------------------------

if Events and Events.Docs then
    -- Load filtered docs list for this staff member
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.DocsList or 'as:nui:docs:list',
        function(_, cb)
            if Utils and Utils.Debug then
                Utils.Debug('NUI docs:list -> server')
            end

            TriggerServerEvent(Events.Docs.List)

            if cb then
                cb({ ok = true })
            end
        end
    )

    -- Open a specific document (by id)
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.DocsOpen or 'as:nui:docs:open',
        function(data, cb)
            data = data or {}
            local id = data.id

            if Utils and Utils.Debug then
                Utils.Debug('NUI docs:open -> server (id=%s)', tostring(id or 'nil'))
            end

            if id and Events.Docs.Open then
                TriggerServerEvent(Events.Docs.Open, id)
            end

            if cb then
                cb({ ok = true })
            end
        end
    )

    -- Request elevated edit permissions (audited server-side)
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.DocsRequestEdit or 'as:nui:docs:requestEdit',
        function(data, cb)
            data = data or {}
            local id = data.id

            if Utils and Utils.Debug then
                Utils.Debug('NUI docs:requestEdit -> server (id=%s)', tostring(id or 'nil'))
            end

            if id and Events.Docs.RequestEdit then
                TriggerServerEvent(Events.Docs.RequestEdit, id)
            end

            if cb then
                cb({ ok = true })
            end
        end
    )

    -- Refresh a document (for now just re-opens server-side)
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.DocsRefresh or 'as:nui:docs:refresh',
        function(data, cb)
            data = data or {}
            local id = data.id

            if Utils and Utils.Debug then
                Utils.Debug('NUI docs:refresh -> server (id=%s)', tostring(id or 'nil'))
            end

            if id and Events.Docs.Refresh then
                TriggerServerEvent(Events.Docs.Refresh, id)
            end

            if cb then
                cb({ ok = true })
            end
        end
    )
end

----------------------------------------------------
-- Resources view (NUI callbacks)
----------------------------------------------------

if Events and Events.Resources then
    -- Refresh list from NUI
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.ResourcesRefresh or 'as:nui:resources:refresh',
        function(_, cb)
            if Utils and Utils.Debug then
                Utils.Debug('NUI resources:refresh -> server')
            end

            TriggerServerEvent(Events.Resources.Refresh)

            if cb then
                cb({ ok = true })
            end
        end
    )

    -- Start / stop / restart from NUI
    RegisterNUICallback(
        AS.Events.NUI and AS.Events.NUI.ResourcesAction or 'as:nui:resources:action',
        function(data, cb)
            data = data or {}
            local name   = tostring(data.resource or data.name or '')
            local action = tostring(data.action or ''):lower()

            if name == '' or action == '' then
                if cb then
                    cb({ ok = false, error = 'Invalid resource or action' })
                end
                return
            end

            if Utils and Utils.Debug then
                Utils.Debug('NUI resources:action -> server (%s, %s)', name, action)
            end

            TriggerServerEvent(Events.Resources.Action, {
                resource = name,
                action   = action,
            })

            if cb then
                cb({ ok = true })
            end
        end
    )
end

---------------------------------------------------------------------
-- Discipline: staff panel NUI callbacks
---------------------------------------------------------------------

-- Get online players for the discipline dropdown
RegisterNUICallback('as:nui:discipline:getOnlinePlayers', function(_, cb)
    cb = cb or function() end

    if lib and lib.callback and lib.callback.await then
        local players = lib.callback.await('as:discipline:getOnlinePlayers') or {}

        if Utils and Utils.Debug then
            Utils.Debug(('Discipline:getOnlinePlayers returned %d players'):format(#players))
        end

        cb({ ok = true, players = players })
    else
        if Utils and Utils.Debug then
            Utils.Debug('lib.callback.await not available for discipline:getOnlinePlayers')
        end
        cb({ ok = false, error = 'lib_not_available' })
    end
end)

-- Add a new discipline entry
RegisterNUICallback('as:nui:discipline:add', function(data, cb)
    data = data or {}
    cb   = cb or function() end

    local payload = {
        targetName    = data.targetName or data.name or '',
        targetCID     = data.targetCID or data.citizenid or nil,
        targetLicense = data.targetLicense or data.license or nil,
        reason        = data.reason or '',
        status        = data.status or '',
        notes         = data.notes or '',
    }

    if Utils and Utils.Debug then
        Utils.Debug('NUI discipline:add -> server payload=%s', json.encode(payload))
    end

    TriggerServerEvent('as:discipline:add', payload)

    cb({ ok = true })
end)

-- Get discipline history for the log table
RegisterNUICallback('as:nui:discipline:getHistory', function(_, cb)
    cb = cb or function() end

    local rows = {}

    if lib and lib.callback and lib.callback.await then
        rows = lib.callback.await('as:discipline:getHistory') or {}
    else
        if Utils and Utils.Debug then
            Utils.Debug('lib.callback.await not available for discipline:getHistory')
        end
    end

    cb({ ok = true, rows = rows })
end)

-- Delete a discipline entry (simple event-based; no hanging waits)
RegisterNUICallback('as:nui:discipline:delete', function(data, cb)
    data = data or {}
    cb   = cb or function() end

    local id = tonumber(data.id or data.entryId or data.entry_id or 0)

    if not id or id <= 0 then
        if Utils and Utils.Debug then
            Utils.Debug('NUI discipline:delete -> invalid id (%s)', tostring(data.id))
        end
        cb({ ok = false, error = 'invalid_id' })
        return
    end

    if Utils and Utils.Debug then
        Utils.Debug('NUI discipline:delete -> deleting id=%d', id)
    end

    -- Fire server-side delete handler
    TriggerServerEvent('as:discipline:delete', {
        id = id,
    })

    -- Immediately tell NUI "we sent it" – server handles actual delete
    cb({ ok = true })
end)

---------------------------------------------------------------------
-- Admin chat
---------------------------------------------------------------------

RegisterNUICallback('as:nui:adminchat:loadHistory', function(_, cb)
    if Events and Events.AdminChat and Events.AdminChat.GetHistory then
        TriggerServerEvent(Events.AdminChat.GetHistory)
    end
    cb('ok')
end)

RegisterNUICallback('as:nui:adminchat:sendMessage', function(data, cb)
    local msg = data and data.message or nil
    if msg and Events and Events.AdminChat and Events.AdminChat.SendMessage then
        TriggerServerEvent(Events.AdminChat.SendMessage, msg)
    end
    cb('ok')
end)

RegisterNUICallback('as:nui:adminchat:purge', function(_, cb)
    if Events and Events.AdminChat and Events.AdminChat.Purge then
        TriggerServerEvent(Events.AdminChat.Purge)
    end
    cb('ok')
end)

---------------------------------------------------------------------
-- Reports submit (legacy NUI name)
---------------------------------------------------------------------

RegisterNUICallback('as_reports_submit', function(data, cb)
    if not Events or not Events.Reports or not Events.Reports.Submit then
        cb('err')
        return
    end

    TriggerServerEvent(
        Events.Reports.Submit,
        data.targetIdentifier,
        data.category,
        data.message,
        data.metadata or {}
    )

    cb('ok')
end)

---------------------------------------------------------------------
-- Reports: player /report overlay NUI callbacks
---------------------------------------------------------------------

RegisterNUICallback('as:nui:reports:submitFromPlayer', function(data, cb)
    data = data or {}

    local subject     = tostring(data.subject or ''):sub(1, 120)
    local description = tostring(data.description or ''):sub(1, 1024)
    local reportType  = tostring(data.reportType or 'general'):sub(1, 32)

    -- Combine subject + description into a single message field
    local message = description
    if subject ~= '' then
        message = ('[%s] %s'):format(subject, description)
    end

    -- Map to the categories your server uses
    local category = (reportType == 'player') and 'player' or 'general'

    -- Push to server reports pipeline
    if Events and Events.Reports and Events.Reports.Submit then
        TriggerServerEvent(
            Events.Reports.Submit,
            nil,           -- targetIdentifier (none for generic /report)
            category,      -- category
            message,       -- message
            {
                subject     = subject,
                description = description,
                reportType  = reportType,
                source      = 'player_ui'
            }
        )
    end

    -- Close the overlay
    if Utils and Utils.SendNUI then
        Utils.SendNUI(
            AS.Events.NUI and AS.Events.NUI.ReportsCloseSubmit or 'as:nui:reports:closeSubmit',
            {}
        )
    else
        SendNUIMessage({
            type    = AS.Events.NUI and AS.Events.NUI.ReportsCloseSubmit or 'as:nui:reports:closeSubmit',
            payload = {}
        })
    end

    if AS.NUI and AS.NUI.SetFocus then
        AS.NUI.SetFocus(false)
    else
        SetNuiFocus(false, false)
    end

    if cb then
        cb({ ok = true })
    end
end)

RegisterNUICallback('as:nui:reports:cancelPlayer', function(_, cb)
    AS.ClientUtils.SendNUI(
        AS.Events.NUI and AS.Events.NUI.ReportsCloseSubmit or 'as:nui:reports:closeSubmit',
        {}
    )
    AS.NUI.SetFocus(false)

    if cb then
        cb({ ok = true })
    end
end)

---------------------------------------------------------------------
-- Reports: staff panel NUI callbacks
---------------------------------------------------------------------

-- Load OPEN reports into the panel
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsLoadOpen or 'as:nui:reports:loadOpen',
    function(_, cb)
        if Events and Events.Reports and Events.Reports.GetOpen then
            TriggerServerEvent(Events.Reports.GetOpen)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.GetOpen is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

-- Load reports CLAIMED by this staff member
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsLoadMine or 'as:nui:reports:loadMine',
    function(_, cb)
        if Events and Events.Reports and Events.Reports.GetMine then
            TriggerServerEvent(Events.Reports.GetMine)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.GetMine is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

-- Load ALL recent reports (for history / audit)
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsLoadAll or 'as:nui:reports:loadAll',
    function(_, cb)
        if Events and Events.Reports and Events.Reports.GetAll then
            TriggerServerEvent(Events.Reports.GetAll)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.GetAll is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

local function getReportIdFromData(data)
    if not data then return nil end
    local id = tonumber(data.id or data.reportId)
    return id
end

-- Claim a report
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsClaim or 'as:nui:reports:claim',
    function(data, cb)
        local id = getReportIdFromData(data)
        if not id then
            if cb then cb({ ok = false, error = 'Invalid report id' }) end
            return
        end

        if Events and Events.Reports and Events.Reports.Claim then
            TriggerServerEvent(Events.Reports.Claim, id)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.Claim is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

-- Unclaim a report
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsUnclaim or 'as:nui:reports:unclaim',
    function(data, cb)
        local id = getReportIdFromData(data)
        if not id then
            if cb then cb({ ok = false, error = 'Invalid report id' }) end
            return
        end

        if Events and Events.Reports and Events.Reports.Unclaim then
            TriggerServerEvent(Events.Reports.Unclaim, id)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.Unclaim is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

-- Close a report
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsClose or 'as:nui:reports:close',
    function(data, cb)
        local id = getReportIdFromData(data)
        if not id then
            if cb then cb({ ok = false, error = 'Invalid report id' }) end
            return
        end

        if Events and Events.Reports and Events.Reports.Close then
            TriggerServerEvent(Events.Reports.Close, id)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.Close is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

-- Reopen a report
RegisterNUICallback(
    AS.Events.NUI and AS.Events.NUI.ReportsReopen or 'as:nui:reports:reopen',
    function(data, cb)
        local id = getReportIdFromData(data)
        if not id then
            if cb then cb({ ok = false, error = 'Invalid report id' }) end
            return
        end

        if Events and Events.Reports and Events.Reports.Reopen then
            TriggerServerEvent(Events.Reports.Reopen, id)
        else
            if Utils and Utils.Debug then
                Utils.Debug('Events.Reports.Reopen is missing')
            end
        end

        if cb then
            cb({ ok = true })
        end
    end
)

---------------------------------------------------------------------
-- Movement / dev overlay / entity info loop
---------------------------------------------------------------------

CreateThread(function()
    while true do
        local playerId = PlayerId()
        local ped      = PlayerPedId()

        ------------------------------------------------
        -- Dev overlay: coords / heading / street / zone
        ------------------------------------------------
        if devOverlayEnabled then
            local coords  = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            local x, y, z = coords.x, coords.y, coords.z
            local streetHash, crossingHash = GetStreetNameAtCoord(x, y, z)
            local streetName   = streetHash and GetStreetNameFromHashKey(streetHash) or 'Unknown'
            local zoneName     = GetNameOfZone(x, y, z)
            local zoneLabel    = zoneName and GetLabelText(zoneName) or zoneName
            local displayZone  = (zoneLabel ~= 'NULL' and zoneLabel) or zoneName or 'Unknown'

            local line1 = ('Pos: %.2f, %.2f, %.2f | H: %.2f'):format(x, y, z, heading)
            local line2 = ('Street: %s'):format(streetName)
            local line3 = ('Zone: %s'):format(displayZone)

            drawText2D(0.015, 0.80, line1, 0.30)
            drawText2D(0.015, 0.82, line2, 0.30)
            drawText2D(0.015, 0.84, line3, 0.30)
        end

        ------------------------------------------------
        -- Dev entity info: aim at entity to see details
        ------------------------------------------------
        if devEntityInfoEnabled then
            if IsPlayerFreeAiming(playerId) then
                local success, entity = GetEntityPlayerIsFreeAimingAt(playerId)
                if success and entity and entity ~= 0 and DoesEntityExist(entity) then
                    local coords  = GetEntityCoords(entity)
                    local heading = GetEntityHeading(entity)
                    local model   = GetEntityModel(entity)
                    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)

                    if onScreen then
                        local label = ('Model: %d (0x%X)'):format(model, model)
                        local line2 = ('Pos: %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z)
                        local line3 = ('Heading: %.2f'):format(heading)

                        drawText2D(sx, sy, label, 0.32)
                        drawText2D(sx, sy + 0.02, line2, 0.28)
                        drawText2D(sx, sy + 0.04, line3, 0.28)
                    end
                end
            end
        end

        ------------------------------------------------
        -- Self ability toggles
        ------------------------------------------------
        if superJumpEnabled then
            SetSuperJumpThisFrame(playerId)
        end

        if fastRunEnabled then
            SetRunSprintMultiplierForPlayer(playerId, 1.49)
        else
            SetRunSprintMultiplierForPlayer(playerId, 1.0)
        end

        if infiniteStaminaEnabled then
            RestorePlayerStamina(playerId, 1.0)
        end

        if godModeEnabled then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(playerId, true)
        else
            SetEntityInvincible(ped, false)
            SetPlayerInvincible(playerId, false)
        end

        ------------------------------------------------
        -- Noclip movement (if active)
        ------------------------------------------------
        if noclipEnabled and noclipEntity and DoesEntityExist(noclipEntity) then
            local ent = noclipEntity

            -- align heading with camera yaw
            local camRot = GetGameplayCamRot(2)
            SetEntityHeading(ent, camRot.z)

            local coords = GetEntityCoords(ent)
            local camDir = getCamDirection()
            local right  = getCamRightVector()

            local speed = 1.5
            if IsControlPressed(0, 21) then -- SHIFT = faster
                speed = speed * 3.0
            end

            local moveX, moveY, moveZ = 0.0, 0.0, 0.0

            -- W / S (forward / back)
            if IsControlPressed(0, 32) then -- W
                moveX = moveX + camDir.x * speed
                moveY = moveY + camDir.y * speed
                moveZ = moveZ + camDir.z * speed
            end
            if IsControlPressed(0, 33) then -- S
                moveX = moveX - camDir.x * speed
                moveY = moveY - camDir.y * speed
                moveZ = moveZ - camDir.z * speed
            end

            -- A / D (strafe)
            if IsControlPressed(0, 34) then -- A
                moveX = moveX - right.x * speed
                moveY = moveY - right.y * speed
            end
            if IsControlPressed(0, 35) then -- D
                moveX = moveX + right.x * speed
                moveY = moveY + right.y * speed
            end

            -- Q / Z (vertical)
            if IsControlPressed(0, 44) then -- Q = up
                moveZ = moveZ + speed
            end
            if IsControlPressed(0, 20) then -- Z = down
                moveZ = moveZ - speed
            end

            coords = vector3(
                coords.x + moveX,
                coords.y + moveY,
                coords.z + moveZ
            )

            SetEntityCoordsNoOffset(ent, coords.x, coords.y, coords.z, true, true, true)
            SetEntityVelocity(ent, 0.0, 0.0, 0.0)

            -- Block regular movement/combat while flying
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            DisableControlAction(0, 22, true) -- jump
            DisableControlAction(0, 30, true) -- move left/right
            DisableControlAction(0, 31, true) -- move forward/back
            DisableControlAction(0, 44, true) -- cover (using Q)
            DisableControlAction(0, 20, true) -- multiplayer info (using Z)
        end

        Wait(0)
    end
end)

--========================================
--  WORLD CONTROLS: TIME & WEATHER (NUI)
--========================================

if Events and Events.World then
    -- Apply a specific time in HH:MM (24-hour) format
    RegisterNUICallback(AS.Events.NUI.WorldApplyTime or 'as:nui:world:applyTime', function(data, cb)
        data = data or {}
        cb   = cb or function() end

        local raw = tostring(data.time or data.value or data.text or '')
        if Utils and Utils.Debug then
            Utils.Debug('NUI world:applyTime raw=%s', raw)
        end

        if not Events or not Events.World or not Events.World.SetTime then
            if Utils and Utils.Notify then
                Utils.Notify('World time event not configured on server.')
            end
            cb({ ok = false, error = 'World time event not available' })
            return
        end

        local hour, minute = raw:match('^(%d%d?):(%d%d)$')
        if not hour then
            if Utils and Utils.Notify then
                Utils.Notify('Invalid time format. Use HH:MM (e.g. 12:00 or 20:30).')
            end
            cb({ ok = false, error = 'invalid_time_format' })
            return
        end

        hour   = tonumber(hour)   or 12
        minute = tonumber(minute) or 0

        -- Clamp to valid GTA clock range
        if hour   < 0 then hour = 0 end
        if hour   > 23 then hour = 23 end
        if minute < 0 then minute = 0 end
        if minute > 59 then minute = 59 end

        if Utils and Utils.Debug then
            Utils.Debug('Triggering World.SetTime -> %02d:%02d', hour, minute)
        end

        TriggerServerEvent(Events.World.SetTime, hour, minute)
        if Utils and Utils.Notify then
            Utils.Notify(('Time Suceessfully Set to: %02d:%02d'):format(hour, minute))
        end

        cb({ ok = true, hour = hour, minute = minute })
    end)

    -- Apply a specific weather preset (CLEAR, RAIN, THUNDER, etc.)
    RegisterNUICallback(AS.Events.NUI.WorldApplyWeather or 'as:nui:world:applyWeather', function(data, cb)
        data = data or {}
        cb   = cb or function() end

        if not Events or not Events.World or not Events.World.SetWeather then
            if Utils and Utils.Notify then
                Utils.Notify('World weather event not configured on server.')
            end
            cb({ ok = false, error = 'World weather event not available' })
            return
        end

        local weather = data.weather or data.preset or 'CLEAR'
        weather = string.upper(tostring(weather or 'CLEAR'))

        if Utils and Utils.Debug then
            Utils.Debug('Triggering World.SetWeather -> %s', weather)
        end

        TriggerServerEvent(Events.World.SetWeather, weather)

        if Utils and Utils.Notify then
            Utils.Notify(('Weather Sucessfully changed to: %s'):format(weather))
        end

        cb({ ok = true, weather = weather })
    end)

    -- Request latest world state for this staff member
    RegisterNUICallback(AS.Events.NUI.WorldLoadState or 'as:nui:world:loadState', function(_, cb)
        cb = cb or function() end

        if not Events or not Events.World or not Events.World.GetState then
            cb({ ok = false, error = 'World state event not available' })
            return
        end

        if Utils and Utils.Debug then
            Utils.Debug('NUI world:loadState -> server')
        end

        TriggerServerEvent(Events.World.GetState)
        cb({ ok = true })
    end)
end

--========================================
--  NUI CALLBACKS: PLAYER SETTINGS
--========================================

if Events and Events.Settings then
    RegisterNUICallback(AS.Events.NUI.SettingsLoad or 'as:nui:settings:load', function(data, cb)
        data = data or {}
        local target = tonumber(data.target or data.targetId or data.id)

        if not target or target <= 0 then
            if cb then cb({ ok = false, error = 'Invalid target id' }) end
            return
        end

        if Utils and Utils.Debug then
            Utils.Debug('NUI settings:load -> %s', target)
        end

        TriggerServerEvent(Events.Settings.GetPlayerSettings, target)
        if cb then cb({ ok = true }) end
    end)

    if Events and Events.NUI and Events.VehicleTools then
        RegisterNUICallback(
            AS.Events.NUI.VehiclesSpawn or 'as:nui:vehicles:spawn',
            function(data, cb)
                data = data or {}
                local model = data.model or data.modelName or data.spawn or data.code

                if not model or model == '' then
                    if cb then cb({ ok = false, error = 'Invalid vehicle model' }) end
                    return
                end

                -- Server-side RBAC will enforce can_spawn_vehicle
                TriggerServerEvent(Events.VehicleTools.Spawn, { model = model })

                if cb then cb({ ok = true }) end
            end
        )
    end

    -- Save job
    RegisterNUICallback(AS.Events.NUI.SettingsSaveJob or 'as:nui:settings:saveJob', function(data, cb)
        data = data or {}

        local target = tonumber(data.target or data.targetId or data.id)
        local job    = tostring(data.job or ''):lower()
        local grade  = tonumber(data.grade or data.jobGrade or 0) or 0

        if not target or target <= 0 or job == '' then
            if cb then cb({ ok = false, error = 'Invalid target or job' }) end
            return
        end

        if Utils and Utils.Debug then
            Utils.Debug('NUI settings:saveJob -> %s (%s, %d)', target, job, grade)
        end

        TriggerServerEvent(Events.Settings.SetJob, target, job, grade)

        if cb then cb({ ok = true }) end
    end)

    -- Save gang
    RegisterNUICallback(AS.Events.NUI.SettingsSaveGang or 'as:nui:settings:saveGang', function(data, cb)
        data = data or {}

        local target = tonumber(data.target or data.targetId or data.id)
        local gang   = tostring(data.gang or ''):lower()
        local grade  = tonumber(data.grade or data.gangGrade or 0) or 0

        if not target or target <= 0 or gang == '' then
            if cb then cb({ ok = false, error = 'Invalid target or gang' }) end
            return
        end

        if Utils and Utils.Debug then
            Utils.Debug('NUI settings:saveGang -> %s (%s, %d)', target, gang, grade)
        end

        TriggerServerEvent(Events.Settings.SetGang, target, gang, grade)

        if cb then cb({ ok = true }) end
    end)

    -- Save staff role / whitelist
    RegisterNUICallback(AS.Events.NUI.SettingsSaveStaffRole or 'as:nui:settings:saveStaffRole', function(data, cb)
        data = data or {}
        local target = tonumber(data.target or data.targetId or data.id)

        if not target or target <= 0 then
            if cb then cb({ ok = false, error = 'Invalid target for staff role/whitelist' }) end
            return
        end

        -- New path: Add / Update Admin (staff role assignment)
        if data.role ~= nil then
            local role = tostring(data.role or ''):lower()
            if role == '' then
                if cb then cb({ ok = false, error = 'Invalid role' }) end
                return
            end

            TriggerServerEvent(Events.Settings.SetStaffRole, target, role)
            if cb then cb({ ok = true }) end
            return
        end

        -- Legacy path: boolean whitelist toggle
        local whitelisted = data.whitelisted and true or false
        TriggerServerEvent(Events.Settings.SetStaffRole, target, whitelisted)
        if cb then cb({ ok = true }) end
    end)

    -- Remove admin (clear staff role)
    RegisterNUICallback(AS.Events.NUI.SettingsRemoveAdmin or 'as:nui:settings:removeAdmin', function(data, cb)
        data = data or {}
        local target = tonumber(data.target or data.targetId or data.id)

        if not target or target <= 0 then
            if cb then cb({ ok = false, error = 'Invalid target for remove admin' }) end
            return
        end

        TriggerServerEvent(Events.Settings.ClearStaffRole, target)
        if cb then cb({ ok = true }) end
    end)

    -- Open clothing menu
    RegisterNUICallback(AS.Events.NUI.SettingsOpenClothing or 'as:nui:settings:openClothing', function(data, cb)
        data = data or {}
        local target = tonumber(data.target or data.targetId or data.id)

        if not target or target <= 0 then
            if cb then cb({ ok = false, error = 'Invalid target for clothing' }) end
            return
        end

        TriggerServerEvent(Events.Settings.OpenClothing, target)
        if cb then cb({ ok = true }) end
    end)
end
