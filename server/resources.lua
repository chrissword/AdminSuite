AS           = AS or {}
AS.Resources = AS.Resources or {}

local Events = AS.Events
local Utils  = AS.Utils
local Audit  = AS.Audit
local RBAC   = AS.RBAC

-------------------------------------------------
-- Logging helpers
-------------------------------------------------

local function log(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Resources] ' .. msg, ...)
    else
        print(('[AdminSuite:Resources] ' .. msg):format(...))
    end
end

local function info(msg, ...)
    if Utils and Utils.Info then
        Utils.Info('[AdminSuite:Resources] ' .. msg, ...)
    else
        print(('[AdminSuite:Resources] ' .. msg):format(...))
    end
end

-------------------------------------------------
-- RBAC helpers
-------------------------------------------------

local function canViewResources(src)
    if RBAC and RBAC.Can then
        local ok = RBAC.Can(src, 'can_view_resources')
        if not ok then
            log('RBAC denied can_view_resources for src=%s', tostring(src))
        end
        return ok
    end

    -- If RBAC not ready yet, allow so you can test
    return true
end

local function canDoAction(src, action)
    if not (RBAC and RBAC.Can) then return true end

    local flag
    if action == 'start' then
        flag = 'can_start_resource'
    elseif action == 'stop' then
        flag = 'can_stop_resource'
    elseif action == 'restart' then
        flag = 'can_restart_resource'
    elseif action == 'refresh' then
        flag = 'can_refresh_resources'
    end

    if not flag then return false end

    local ok = RBAC.Can(src, flag)
    if not ok then
        log('RBAC denied %s for src=%s', flag, tostring(src))
    end
    return ok
end

-------------------------------------------------
-- Audit helper
-------------------------------------------------

local function audit(src, eventName, payload)
    if Audit and Audit.Log then
        Audit.Log(src, nil, eventName, payload or {})
    elseif Events and Events.Audit and Events.Audit.Append then
        TriggerEvent(Events.Audit.Append, eventName, nil, payload or {})
    end
end

-------------------------------------------------
-- Build resource list
-------------------------------------------------

local function buildResourceList()
    local list = {}

    if not GetNumResources or not GetResourceByFindIndex then
        log('Resource natives not available on this runtime')
        return list
    end

    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and name ~= '' then
            -- Skip internal resources
            if name ~= '_cfx_internal' and name ~= 'fivem' then
                local state = 'unknown'
                if GetResourceState then
                    local ok, s = pcall(GetResourceState, name)
                    if ok and type(s) == 'string' then
                        state = s
                    end
                end

                list[#list + 1] = {
                    name  = name,
                    state = state,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    log('Built resource list (%d entries)', #list)
    return list
end

AS.Resources.GetList = buildResourceList

-------------------------------------------------
-- Send list to a single player
-------------------------------------------------

local function sendResourceListTo(src)
    if not src or src <= 0 then return end

    local list = buildResourceList()

    -- Server → client "refresh/list" event
    if Events and Events.Resources and Events.Resources.Refresh then
        TriggerClientEvent(
            Events.Resources.Refresh,
            src,
            { resources = list }
        )
    else
        -- Fallback: log only
        log('Events.Resources.Refresh not defined; cannot send list to src=%s', tostring(src))
    end
end

-------------------------------------------------
-- Events (NUI → server → client)
-------------------------------------------------

if Events and Events.Resources then
    -------------------------------------------------
    -- Normalize event names (keep backward-compatible)
    -------------------------------------------------

    -- Preferred: Request = client → server "give me list"
    Events.Resources.Request = Events.Resources.Request or Events.Resources.GetList

    -- Ensure we have a Refresh event name for server → client
    Events.Resources.Refresh = Events.Resources.Refresh or 'as:resources:refresh'
    Events.Resources.Action  = Events.Resources.Action  or 'as:resources:action'

    -------------------------------------------------
    -- Client → Server: request list (Refresh / initial load)
    -------------------------------------------------

    if Events.Resources.Request then
        RegisterNetEvent(Events.Resources.Request, function()
            local src = source
            if not canViewResources(src) then return end
            if not canDoAction(src, 'refresh') then return end

            sendResourceListTo(src)
        end)
    end

    -- For older code that might still use GetList explicitly
    if Events.Resources.GetList and Events.Resources.GetList ~= Events.Resources.Request then
        RegisterNetEvent(Events.Resources.GetList, function()
            local src = source
            if not canViewResources(src) then return end
            if not canDoAction(src, 'refresh') then return end

            sendResourceListTo(src)
        end)
    end

    -- If you had a client → server "Refresh" previously, keep it usable as alias
    if Events.Resources.Refresh and Events.Resources.Refresh ~= Events.Resources.Request then
        RegisterNetEvent(Events.Resources.Refresh, function()
            local src = source
            if not canViewResources(src) then return end
            if not canDoAction(src, 'refresh') then return end

            sendResourceListTo(src)
        end)
    end

    -------------------------------------------------
    -- Client → Server: Start / Stop / Restart
    --
    -- Supports BOTH:
    --   TriggerServerEvent(Events.Resources.Action, resourceName, action)
    --   TriggerServerEvent(Events.Resources.Action, { resource = name, action = action })
    -------------------------------------------------

    RegisterNetEvent(Events.Resources.Action, function(a, b)
        local src = source

        local name, action

        if type(a) == 'table' then
            local payload = a or {}
            name   = tostring(payload.resource or payload.name or '')
            action = tostring(payload.action or ''):lower()
        else
            name   = tostring(a or '')
            action = tostring(b or ''):lower()
        end

        if name == '' or action == '' then
            log(
                'Invalid resource action from src=%s (name=%s, action=%s)',
                tostring(src),
                tostring(name),
                tostring(action)
            )
            return
        end

        if not canViewResources(src) then return end
        if not canDoAction(src, action) then return end

        if not GetResourceState or not StartResource or not StopResource then
            log(
                'Resource natives not available; cannot perform action "%s" on "%s"',
                action,
                name
            )
            return
        end

        local ok, currentState = pcall(GetResourceState, name)
        if not ok then
            log('GetResourceState failed for "%s": %s', name, tostring(currentState))
            return
        end

        local changed = false

        if action == 'start' then
            if currentState == 'stopped' then
                StartResource(name)
                changed = true
            elseif currentState == 'started' then
                -- New: mirror client guard – resource already started
                if Utils and Utils.Notify then
                    Utils.Notify(
                        src,
                        ('Resource "%s" is already started.'):format(name),
                        'error'
                    )
                else
                    log(
                        'Start requested for "%s" but state is already "%s"',
                        name,
                        tostring(currentState)
                    )
                end
                return
            end

        elseif action == 'stop' then
            if currentState == 'started' then
                StopResource(name)
                changed = true
            end

        elseif action == 'restart' then
            -- Only allow restart when the resource is actually started.
            if currentState ~= 'started' then
                if Utils and Utils.Notify then
                    Utils.Notify(
                        src,
                        ('Resource "%s" is not started.'):format(name),
                        'error'
                    )
                else
                    log(
                        'Restart requested for "%s" but state is "%s" (not started)',
                        name,
                        tostring(currentState)
                    )
                end
                return
            end

            StopResource(name)
            Wait(250)
            StartResource(name)
            changed = true

        else
            log('Unknown resource action "%s" for "%s"', action, name)
            return
        end

        audit(src, 'resources:' .. action, {
            resource = name,
            previous = currentState,
        })

        if changed then
            -- small delay so state updates before we re-read the list
            Wait(500)
        end

        sendResourceListTo(src)
    end)

else
    log('Events.Resources not defined; skipping resources wiring.')
end

if Utils and Utils.Info then
    Utils.Info('[AdminSuite:Resources] module initialized')
else
    print('[AdminSuite:Resources] module initialized')
end
