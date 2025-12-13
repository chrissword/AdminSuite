AS        = AS or {}
AS.Audit  = AS.Audit or {}

local DB          = AS.DB
local Tables      = AS.Tables
local Utils       = AS.Utils
local Persistence = AS.Persistence
local Config      = AS.Config or Config
local Events      = AS.Events

AS.Audit.Cache = AS.Audit.Cache or {}

--========================================
-- Identifier resolution
--========================================

local function getIdentifiers(source)
    local list = {}
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        list[#list + 1] = id
    end
    return list
end

local function resolvePreferredIdentifier(srcOrId)
    if type(srcOrId) == 'string' then
        return srcOrId
    end

    if type(srcOrId) ~= 'number' then
        return 'unknown:0'
    end

    local ids = getIdentifiers(srcOrId)
    if #ids == 0 then
        return ('source:%d'):format(srcOrId)
    end

    local priority = (Config and Config.Permissions and Config.Permissions.IdentifierPriority)
        or { 'discord', 'license', 'steam' }

    -- Pick first identifier matching the priority list
    for _, pref in ipairs(priority) do
        for _, id in ipairs(ids) do
            if id:find(pref .. ':', 1, true) == 1 then
                return id
            end
        end
    end

    -- Fallback: first identifier
    return ids[1]
end

--========================================
-- DB helper
--========================================

local function insertAudit(actorIdentifier, targetIdentifier, eventName, payload)
    local tableName   = Tables.Audit
    local jsonPayload = payload and AS.Utils.SafeJsonEncode(payload) or 'null'

    DB.execute(([[INSERT INTO `%s`
        (actor_identifier, target_identifier, event_name, payload)
        VALUES (@actor, @target, @event, @payload)]])
        :format(tableName),
        {
            ['@actor']   = actorIdentifier,
            ['@target']  = targetIdentifier,
            ['@event']   = eventName,
            ['@payload'] = jsonPayload,
        }
    )
end

--========================================
-- Public API
--========================================

function AS.Audit.Log(actorSrcOrId, targetIdOrNil, eventName, payload)
    local actorId  = resolvePreferredIdentifier(actorSrcOrId)
    local targetId = targetIdOrNil and resolvePreferredIdentifier(targetIdOrNil) or nil

    insertAudit(actorId, targetId, eventName, payload)

    -- Lightweight in-memory cache (for quick viewing / NUI)
    local entry = {
        actor_identifier  = actorId,
        target_identifier = targetId,
        event_name        = eventName,
        payload           = payload or {},
        created_at        = os.time(),
    }

    table.insert(AS.Audit.Cache, entry)

    -- Optional JSON persistence
    if Persistence then
        Persistence.Save('Audit', AS.Audit.Cache)
    end
end

function AS.Audit.GetEntries(limit)
    limit = tonumber(limit) or 100

    local count = #AS.Audit.Cache
    if count <= limit then
        return AS.Audit.Cache
    end

    local start  = count - limit + 1
    local result = {}
    for i = start, count do
        result[#result + 1] = AS.Audit.Cache[i]
    end
    return result
end

function AS.Audit.ClearRecent()
    AS.Audit.Cache = {}
    if Persistence then
        Persistence.Save('Audit', AS.Audit.Cache)
    end
end



--========================================
-- Event bindings (for other resources / dashboard)
--========================================

if Events and Events.Audit then
    -------------------------------------------------
    -- Append via event
    --   TriggerEvent(Events.Audit.Append, eventName, targetIdOrNil, payload)
    -------------------------------------------------
    RegisterNetEvent(Events.Audit.Append, function(eventName, targetIdOrNil, payload)
        local src = source
        if not eventName or eventName == '' then
            if Utils and Utils.Warn then
                Utils.Warn('Audit.Append called without eventName (src=%s)', tostring(src))
            end
            return
        end

        AS.Audit.Log(src, targetIdOrNil, eventName, payload)
    end)

    -------------------------------------------------
    -- Get recent entries for a player (dashboard, tools)
    --
    -- Clients can call, e.g.:
    --   TriggerServerEvent(Events.Audit.GetEntries, { limit = 10, forDashboard = true })
    --
    -- This will respond with:
    --   TriggerClientEvent(Events.Audit.GetEntries, src, entries, options)
    -------------------------------------------------
    RegisterNetEvent(Events.Audit.GetEntries, function(optionsOrLimit)
        local src = source

        local opts  = {}
        local limit

        if type(optionsOrLimit) == 'table' then
            opts  = optionsOrLimit
            limit = tonumber(opts.limit) or 10
        else
            limit = tonumber(optionsOrLimit) or 10
        end

        local entries = AS.Audit.GetEntries(limit)

        -- Echo back to requester. The same event name is used
        -- for server→client; client code should distinguish by
        -- argument types (first arg is table of entries).
        TriggerClientEvent(Events.Audit.GetEntries, src, entries, opts or {})
    end)
end

--========================================
-- Initialization
--========================================

local persisted = Persistence and Persistence.Load('Audit') or nil
if type(persisted) == 'table' then
    AS.Audit.Cache = persisted
end

if Utils and Utils.Info then
    Utils.Info('Audit pipeline initialized (cached entries=%d)', #AS.Audit.Cache)
else
    print(('[AdminSuite] Audit pipeline initialized (cached entries=%d)'):format(#AS.Audit.Cache))
end
