AS       = AS or {}
AS.World = AS.World or {}

local Events = AS.Events
local RBAC   = AS.RBAC
local Utils  = AS.Utils
local Audit  = AS.Audit

local hasQBWeatherSync = false

-- Detect qb-weathersync so AdminSuite can delegate time / weather to it
if GetResourceState then
    local ok, state = pcall(GetResourceState, 'qb-weathersync')
    if ok and state == 'started' then
        hasQBWeatherSync = true
        if Utils and Utils.Debug then
            Utils.Debug('[AdminSuite:World] qb-weathersync detected; delegating time/weather')
        end
    elseif Utils and Utils.Debug then
        Utils.Debug('[AdminSuite:World] qb-weathersync not started (state=%s)', tostring(state))
    end
end

local function applyExternalTime(hour, minute, freeze)
    if not hasQBWeatherSync then return end

    local ok, err = pcall(function()
        -- qb-weathersync export for time
        exports['qb-weathersync']:setTime(hour, minute or 0)

        -- Optional: sync freeze state as well
        if freeze ~= nil then
            exports['qb-weathersync']:setTimeFreeze(freeze and true or false)
        end
    end)

    if not ok then
        log('qb-weathersync setTime failed: %s', err or 'unknown')
    end
end

local function applyExternalWeather(weather)
    if not hasQBWeatherSync then return end

    local ok, err = pcall(function()
        -- qb-weathersync wants the type string; generally case-insensitive
        exports['qb-weathersync']:setWeather(string.lower(weather or 'CLEAR'))
    end)

    if not ok then
        log('qb-weathersync setWeather failed: %s', err or 'unknown')
    end
end

local function applyExternalFreeze(freeze)
    if not hasQBWeatherSync then return end

    local ok, err = pcall(function()
        exports['qb-weathersync']:setTimeFreeze(freeze and true or false)
    end)

    if not ok then
        log('qb-weathersync setTimeFreeze failed: %s', err or 'unknown')
    end
end


--========================================
-- Helpers
--========================================

local function log(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug(msg, ...)
    else
        print(('[AdminSuite:World] ' .. msg):format(...))
    end
end

local function canUseWorld(src)
    if RBAC and RBAC.Can then
        local ok = RBAC.Can(src, 'can_use_world')
        if not ok then
            log('RBAC denied can_use_world for src=%s', tostring(src))
        end
        return ok
    end
    -- If RBAC not ready, allow for now so you can test
    return true
end

local function isStaff(src)
    if RBAC and RBAC.IsStaff then
        return RBAC.IsStaff(src)
    end
    return true
end

local function audit(src, eventName, message)
    if Audit and Audit.Log then
        Audit.Log(src, nil, eventName, message or '')
    end
end

--========================================
-- World state (authoritative)
--========================================

AS.World.State = AS.World.State or {
    timeHour   = 12,
    timeMinute = 0,
    timeSecond = 0,
    freezeTime = false,

    weather    = 'CLEAR',
}

function AS.World.GetState()
    return AS.World.State
end

local function broadcastState()
    if not Events or not Events.World or not Events.World.GetState then return end
    TriggerClientEvent(Events.World.GetState, -1, AS.World.State)
end

--========================================
-- Mutators
--========================================

function AS.World.SetTime(src, hour, minute)
    hour   = tonumber(hour)   or 12
    minute = tonumber(minute) or 0

    if hour   < 0 then hour = 0 end
    if hour   > 23 then hour = 23 end
    if minute < 0 then minute = 0 end
    if minute > 59 then minute = 59 end

    AS.World.State.timeHour   = hour
    AS.World.State.timeMinute = minute

    log('World time set to %02d:%02d by src=%s', hour, minute, tostring(src))
    audit(src, 'world:setTime', ('Set time to %02d:%02d'):format(hour, minute))

    -- Tell qb-weathersync as the authoritative system (if present)
    applyExternalTime(hour, minute, AS.World.State.freezeTime)

    -- Keep AdminSuite’s own client events so NUI stays in sync
    if Events and Events.World and Events.World.SetTime then
        TriggerClientEvent(Events.World.SetTime, -1, hour, minute, AS.World.State.freezeTime)
    end

    -- Push updated state to any open world controls panel
    broadcastState()
end


function AS.World.SetWeather(src, weather)
    weather = tostring(weather or 'CLEAR'):upper()
    AS.World.State.weather = weather

    log('World weather set to %s by src=%s', weather, tostring(src))
    audit(src, 'world:setWeather', ('Set weather to %s'):format(weather))

    -- Tell qb-weathersync about the new weather (if present)
    applyExternalWeather(weather)

    -- Keep AdminSuite’s own client events for consistency / UI
    if Events and Events.World and Events.World.SetWeather then
        TriggerClientEvent(Events.World.SetWeather, -1, weather)
    end

    broadcastState()
end

--Wire freeze-time changes into the time mutator

function AS.World.SetFreezeTime(src, freeze)
    local freezeBool = freeze and true or false

    AS.World.State.freezeTime = freezeBool

    log('World freezeTime set to %s by src=%s', tostring(freezeBool), tostring(src))
    audit(src, 'world:freezeTime', ('Set freezeTime to %s'):format(tostring(freezeBool)))

    -- Tell qb-weathersync
    applyExternalFreeze(freezeBool)

    -- Let clients / NUI know
    broadcastState()
end


--========================================
-- Net events
--========================================

if not Events or not Events.World then
    log('Events.World not defined; skipping world controls.')
    return
end

-- NUI / client asks for current world state
RegisterNetEvent(Events.World.GetState, function()
    local src = source
    if not isStaff(src) then return end

    log('GetState requested by src=%s', tostring(src))
    TriggerClientEvent(Events.World.GetState, src, AS.World.GetState())
end)

-- Time from NUI
RegisterNetEvent(Events.World.SetTime, function(hour, minute)
    local src = source
    if not canUseWorld(src) then return end

    log('SetTime from src=%s (%s:%s)', tostring(src), tostring(hour), tostring(minute))
    AS.World.SetTime(src, hour, minute)
end)

-- Weather from NUI
RegisterNetEvent(Events.World.SetWeather, function(weather)
    local src = source
    if not canUseWorld(src) then return end

    log('SetWeather from src=%s (%s)', tostring(src), tostring(weather))
    AS.World.SetWeather(src, weather)
end)
