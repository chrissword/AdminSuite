AS = AS or {}

-- Ensure shared tables exist
AS.World = AS.World or {}

local Events = AS.Events or {}
local World  = AS.World
local RBAC   = AS.RBAC
local Utils  = AS.Utils

-- If the Events.World map isn't defined yet, bail early
if not Events.World then
    return
end

--========================================
-- Helpers
--========================================

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[WorldRBAC] ' .. msg, ...)
    else
        -- fallback to plain print if Utils.Debug is unavailable
        print(('[AdminSuite:WorldRBAC] ' .. msg):format(...))
    end
end

local function requireWorldAccess(src)
    local ok = RBAC and RBAC.Can and RBAC.Can(src, 'can_use_world')
    if not ok then
        debug('World access denied for src=%s', tostring(src))
    end
    return ok
end

--========================================
-- Safe passthroughs for World actions
--========================================
-- These ensure that World.ToggleRadar / ToggleNames / ToggleIds / ToggleBlips
-- (and GetPlayers, if needed) always exist so the event handlers never error.
-- If you later define richer logic in another file (e.g. server/world.lua),
-- that logic will take precedence as long as it runs BEFORE this file.

-- Radar
if not World.ToggleRadar then
    function World.ToggleRadar(src, enabled)
        local ev = Events.World.ToggleRadar or 'as:world:toggleRadar'
        if src then
            TriggerClientEvent(ev, src, enabled)
        end
    end
end

-- Blips (staff map blips, etc.)
if not World.ToggleBlips then
    function World.ToggleBlips(src, enabled)
        local ev = Events.World.ToggleBlips or 'as:world:toggleBlips'
        if src then
            TriggerClientEvent(ev, src, enabled)
        end
    end
end

-- Overhead names
if not World.ToggleNames then
    function World.ToggleNames(src, enabled)
        local ev = Events.World.ToggleNames or 'as:world:toggleNames'
        if src then
            TriggerClientEvent(ev, src, enabled)
        end
    end
end

-- Overhead IDs
if not World.ToggleIds then
    function World.ToggleIds(src, enabled)
        local ev = Events.World.ToggleIds or 'as:world:toggleIds'
        if src then
            TriggerClientEvent(ev, src, enabled)
        end
    end
end

-- Fallback GetPlayers (very simple; you can replace with richer data later)
if not World.GetPlayers then
function World.GetPlayers()
        -- If Players module exists, reuse its richer snapshot
        if AS.Players and AS.Players.GetPlayersSnapshot then
            return AS.Players.GetPlayersSnapshot()
        end

        -- Fallback: just id + profile name
        local players = {}
        for _, id in ipairs(GetPlayers()) do
            local sid = tonumber(id)
            players[#players + 1] = {
                id   = sid,
                name = GetPlayerName(id) or ("[%s] Unknown"):format(tostring(id)),
            }
        end
        return players
    end
end


--========================================
-- Events
--========================================

-- Client → server: request current state for this staff member
RegisterNetEvent(Events.World.GetState, function()
    local src = source
    if not RBAC or not RBAC.IsStaff or not RBAC.IsStaff(src) then
        return
    end

    debug('GetState requested by src=%s', tostring(src))

    -- If you have a richer World.GetState defined elsewhere, this will call it.
    -- Otherwise, it may be nil; so guard it.
    if World.GetState then
        TriggerClientEvent(Events.World.GetState, src, World.GetState())
    else
        TriggerClientEvent(Events.World.GetState, src, {})
    end
end)

RegisterNetEvent(Events.World.SetTime, function(hour, minute)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('SetTime by src=%s -> %s:%s', tostring(src), tostring(hour), tostring(minute))

    if World.SetTime then
        World.SetTime(src, hour, minute)
    end
end)

RegisterNetEvent(Events.World.SetWeather, function(weather)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('SetWeather by src=%s -> %s', tostring(src), tostring(weather))

    if World.SetWeather then
        World.SetWeather(src, weather)
    end
end)

RegisterNetEvent(Events.World.FreezeTime, function(freeze)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('FreezeTime by src=%s -> %s', tostring(src), tostring(freeze))

    if World.SetFreezeTime then
        World.SetFreezeTime(src, freeze)
    end
end)

RegisterNetEvent(Events.World.ToggleRadar, function(enabled)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('ToggleRadar by src=%s enabled=%s', tostring(src), tostring(enabled))
    World.ToggleRadar(src, enabled)
end)

RegisterNetEvent(Events.World.ToggleBlips, function(enabled)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('ToggleBlips by src=%s enabled=%s', tostring(src), tostring(enabled))
    World.ToggleBlips(src, enabled)
end)

RegisterNetEvent(Events.World.ToggleNames, function(enabled)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('ToggleNames by src=%s enabled=%s', tostring(src), tostring(enabled))
    World.ToggleNames(src, enabled)
end)

-- Toggle IDs (for Management → "Toggle IDs")
RegisterNetEvent(Events.World.ToggleIds, function(enabled)
    local src = source
    if not requireWorldAccess(src) then return end

    debug('ToggleIds by src=%s enabled=%s', tostring(src), tostring(enabled))
    World.ToggleIds(src, enabled)
end)

RegisterNetEvent(Events.World.GetPlayers, function()
    local src = source
    if not RBAC or not RBAC.IsStaff or not RBAC.IsStaff(src) then
        return
    end

    local list = World.GetPlayers()
    debug('GetPlayers requested by src=%s (count=%d)', tostring(src), #list)
    TriggerClientEvent(Events.World.GetPlayers, src, list)
end)
