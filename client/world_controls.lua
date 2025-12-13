AS = AS or {}
AS.ClientWorld = AS.ClientWorld or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientWorld.State       = AS.ClientWorld.State       or {}
AS.ClientWorld.PlayerNames = AS.ClientWorld.PlayerNames or {}

--========================================================
-- Debug helper
--========================================================

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[WorldClient] ' .. msg, ...)
    else
        print(('[AdminSuite:WorldClient] ' .. msg):format(...))
    end
end

local function requestPlayerNamesSnapshot()
    -- Ask server for the players list (with character names if QBCore is present)
    if Events and Events.World and Events.World.GetPlayers then
        TriggerServerEvent(Events.World.GetPlayers)
    else
        -- Safe fallback to literal event string
        TriggerServerEvent('as:world:getPlayers')
    end
end


--========================================================
-- Time & Weather helpers
--========================================================

local function applyTime(state)
    if not state then return end

    local hour   = tonumber(state.timeHour   or state.hour   or 12)
    local minute = tonumber(state.timeMinute or state.minute or 0)
    local second = tonumber(state.timeSecond or state.second or 0)

    NetworkOverrideClockTime(hour, minute, second)

    if state.freezeTime ~= nil then
        local freeze = state.freezeTime and true or false
        PauseClock(freeze)
    end

    debug('Applied time: %02d:%02d:%02d freeze=%s', hour, minute, second, tostring(state.freezeTime))
end

local function applyWeather(state)
    if not state or not state.weather then return end

    local weatherType = tostring(state.weather):upper()

    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeNow(weatherType)
    SetWeatherTypeNowPersist(weatherType)
    SetWeatherTypePersist(weatherType)

    debug('Applied weather: %s', weatherType)
end

--========================================================
-- 3D Text + Radar / Blip toggle helpers
--========================================================

local function drawText3D(x, y, z, text, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local s = scale or 0.35

    SetTextScale(s, s)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local showIds   = false
local showNames = false
local showBlips = false

-- Start from the REAL minimap state instead of hardcoding false
local showRadar     = not IsRadarHidden()
local radarOverride = nil  -- when nil, AdminSuite does NOT fight other scripts

local playerBlips = {}

local function setRadarEnabled(enabled)
    -- If no explicit value, treat this as a "toggle" using the game state
    if enabled == nil then
        -- if game says hidden, we turn it ON; if shown, we turn it OFF
        enabled = IsRadarHidden()
    end

    showRadar     = enabled and true or false
    radarOverride = showRadar

    debug(
        'Radar toggled client-side -> showRadar=%s (IsRadarHidden=%s)',
        tostring(showRadar),
        tostring(IsRadarHidden())
    )

    if Utils and Utils.Notify then
        local label = ('Toggle Radar: %s'):format(showRadar and 'On' or 'Off')
        local ntype = showRadar and 'success' or 'error'
        Utils.Notify(label, ntype)
    end
end


local function setOverheadIds(enabled)
    showIds = enabled and true or false
    debug('Overhead IDs toggled client-side -> %s', tostring(showIds))

    if Utils and Utils.Notify then
        local label = ('Toggle IDs: %s'):format(showIds and 'On' or 'Off')
        local ntype = showIds and 'success' or 'error'
        Utils.Notify(label, ntype)
    end
end


local function setOverheadNames(enabled)
    showNames = enabled and true or false
    debug('Overhead names toggled client-side -> %s', tostring(showNames))

    -- When turning names ON, fetch the latest snapshot from server
    if showNames then
        requestPlayerNamesSnapshot()
    end

    if Utils and Utils.Notify then
        local label = ('Toggle Names: %s'):format(showNames and 'On' or 'Off')
        local ntype = showNames and 'success' or 'error'
        Utils.Notify(label, ntype)
    end
end



local function clearBlips()
    for _, blip in pairs(playerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    playerBlips = {}
end

local function setBlipsEnabled(enabled)
    showBlips = enabled and true or false
    debug('Staff blips toggled client-side -> %s', tostring(showBlips))

    if not showBlips then
        clearBlips()
    end
end

--========================================================
-- Radar enforcement thread
--========================================================

-- Keep our chosen radar state applied, in case other scripts change it
CreateThread(function()
    while true do
        if radarOverride ~= nil then
            -- When AdminSuite has taken control (after first toggle),
            -- re-assert our desired radar state every frame
            DisplayRadar(radarOverride)
        end
        Wait(0)
    end
end)

--========================================================
-- Threads for overhead text + blips
--========================================================

CreateThread(function()
    while true do
        if showIds or showNames then
            local playerPed = PlayerPedId()
            local myCoords  = GetEntityCoords(playerPed)

            local players = GetActivePlayers()
            for _, pid in ipairs(players) do
                local targetPed = GetPlayerPed(pid)
                if targetPed ~= 0 and not IsEntityDead(targetPed) then
                    local coords = GetEntityCoords(targetPed)
                    local dx = coords.x - myCoords.x
                    local dy = coords.y - myCoords.y
                    local dz = coords.z - myCoords.z
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                    if dist < 250.0 then
                        local sid = GetPlayerServerId(pid)

                        -- Use character name from server snapshot if available
                        local charName = AS.ClientWorld.PlayerNames[sid]
                        local fallback = GetPlayerName(pid) or ('[%d]'):format(sid)
                        local name     = charName or fallback

                        local label

                        if showIds and showNames then
                            label = ('[%d] %s'):format(sid, name)
                        elseif showIds then
                            label = ('[%d]'):format(sid)
                        elseif showNames then
                            label = name
                        end

                        if label then
                            drawText3D(coords.x, coords.y, coords.z + 1.0, label, 0.35)
                        end
                    end
                end
            end

            Wait(0) -- update every frame while enabled
        else
            Wait(500) -- idle when nothing is active
        end
    end
end)

CreateThread(function()
    while true do
        if showBlips then
            local current = {}

            local players = GetActivePlayers()
            for _, pid in ipairs(players) do
                local sid = GetPlayerServerId(pid)
                current[sid] = true

                if not playerBlips[sid] then
                    local ped = GetPlayerPed(pid)
                    if ped ~= 0 then
                        local blip = AddBlipForEntity(ped)
                        SetBlipScale(blip, 0.85)
                        ShowHeadingIndicatorOnBlip(blip, true)

                        BeginTextCommandSetBlipName('STRING')
                        AddTextComponentString(('ID %d'):format(sid))
                        EndTextCommandSetBlipName(blip)

                        playerBlips[sid] = blip
                    end
                end
            end

            -- Remove blips for players that left
            for sid, blip in pairs(playerBlips) do
                if not current[sid] then
                    if DoesBlipExist(blip) then
                        RemoveBlip(blip)
                    end
                    playerBlips[sid] = nil
                end
            end

            Wait(1000)
        else
            if next(playerBlips) ~= nil then
                clearBlips()
            end
            Wait(1000)
        end
    end
end)

--========================================================
-- Event wiring
--========================================================

if Events and Events.World then
    -- Full state snapshot (time + weather)
    RegisterNetEvent(Events.World.GetState, function(state)
        AS.ClientWorld.State = state or {}
        debug('World state snapshot received.')
        applyTime(AS.ClientWorld.State)
        applyWeather(AS.ClientWorld.State)
    end)

    -- Direct time update
    RegisterNetEvent(Events.World.SetTime, function(hour, minute, freezeTime)
        AS.ClientWorld.State.timeHour   = tonumber(hour)   or 12
        AS.ClientWorld.State.timeMinute = tonumber(minute) or 0
        AS.ClientWorld.State.timeSecond = 0

        if freezeTime ~= nil then
            AS.ClientWorld.State.freezeTime = freezeTime and true or false
        end

        debug(
            'SetTime event -> %02d:%02d freeze=%s',
            AS.ClientWorld.State.timeHour,
            AS.ClientWorld.State.timeMinute,
            tostring(AS.ClientWorld.State.freezeTime)
        )

        applyTime(AS.ClientWorld.State)
    end)

    -- Direct weather update
    RegisterNetEvent(Events.World.SetWeather, function(weather)
        AS.ClientWorld.State.weather = tostring(weather or 'CLEAR'):upper()
        debug('SetWeather event -> %s', AS.ClientWorld.State.weather)
        applyWeather(AS.ClientWorld.State)
    end)

    -- Radar toggle
    RegisterNetEvent(Events.World.ToggleRadar, function(enabled)
        debug('ToggleRadar event received -> %s', tostring(enabled))
        setRadarEnabled(enabled)
    end)

    -- Overhead names toggle
    RegisterNetEvent(Events.World.ToggleNames, function(enabled)
        if enabled == nil then
            enabled = not showNames
        end
        debug('ToggleNames event received -> %s', tostring(enabled))
        setOverheadNames(enabled)
    end)

    -- Overhead IDs toggle
    RegisterNetEvent(Events.World.ToggleIds, function(enabled)
        if enabled == nil then
            enabled = not showIds
        end
        debug('ToggleIds event received -> %s', tostring(enabled))
        setOverheadIds(enabled)
    end)

    -- Staff map blips toggle
    RegisterNetEvent(Events.World.ToggleBlips, function(enabled)
        if enabled == nil then
            enabled = not showBlips
        end
        debug('ToggleBlips event received -> %s', tostring(enabled))
        setBlipsEnabled(enabled)
    end)

    -- Receive player snapshot (with character names) from server
    RegisterNetEvent(Events.World.GetPlayers, function(list)
        AS.ClientWorld.PlayerNames = {}

        local count = 0

        if type(list) == 'table' then
            count = #list
            for _, p in ipairs(list) do
                local sid = tonumber(p.id or p.src)
                if sid then
                    -- name here is already the character name from QBCore
                    AS.ClientWorld.PlayerNames[sid] = p.name
                end
            end
        end

        debug('World.GetPlayers snapshot received (%d players)', count)
    end)
end
