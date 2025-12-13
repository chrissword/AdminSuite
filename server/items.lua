AS        = AS or {}
AS.Items  = AS.Items or {}

local Config = AS.Config or Config
local Events = AS.Events
local Utils  = AS.Utils
local Audit  = AS.Audit
local RBAC   = AS.RBAC

AS.Items.List = AS.Items.List or {}

local QBCore = nil

-------------------------------------------------
-- QBCore attach (qb-core / qbx-core / qbcore)
-------------------------------------------------
CreateThread(function()
    local coreResources = { 'qb-core', 'qbx-core', 'qbcore' }

    for _, res in ipairs(coreResources) do
        local ok, obj = pcall(function()
            return exports[res]:GetCoreObject()
        end)

        if ok and obj then
            QBCore = obj
            if Utils and Utils.Info then
                Utils.Info(('[AdminSuite] QBCore attached to items.lua using resource "%s"'):format(res))
            else
                print(('[AdminSuite] QBCore attached to items.lua using resource "%s"'):format(res))
            end
            break
        end
    end

    if not QBCore then
        if Utils and Utils.Warn then
            Utils.Warn('[AdminSuite] Failed to attach QBCore in items.lua (tried qb-core / qbx-core / qbcore)')
        else
            print('[AdminSuite:WARN] Failed to attach QBCore in items.lua (tried qb-core / qbx-core / qbcore)')
        end
    end
end)

-------------------------------------------------
-- Small helpers
-------------------------------------------------

local function log(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Items] ' .. msg, ...)
    else
        print(('[AdminSuite:Items] ' .. msg):format(...))
    end
end

local function can(src, flag)
    if RBAC and RBAC.Can then
        local ok = RBAC.Can(src, flag)
        if not ok then
            log('RBAC denied %s for src=%s', flag, tostring(src))
        end
        return ok
    end
    return true
end

-- For listing items, we accept either give/take flag
local function canListItems(src)
    if not RBAC or not RBAC.Can then
        return true
    end

    local ok = RBAC.Can(src, 'can_give_item')
    if ok then return true end

    ok = RBAC.Can(src, 'can_take_item')
    if ok then return true end

    log('RBAC denied items:list for src=%s', tostring(src))
    return false
end

local function audit(src, eventName, payload)
    payload = payload or {}

    if Audit and Audit.Log then
        Audit.Log(src, nil, eventName, payload)
    elseif Events and Events.Audit and Events.Audit.Append then
        TriggerEvent(Events.Audit.Append, eventName, nil, payload)
    end
end

local function getInventorySystem()
    local inv = (Config and Config.Inventory and Config.Inventory.System) or 'qb-inventory'
    inv = tostring(inv):lower()
    return inv
end

-------------------------------------------------
-- Items list (QBCore / shared items)
-------------------------------------------------

local function buildFromQBCore()
    local out = {}

    -- Support both QBCore.Shared.Items and QBShared.Items
    local sharedItems =
        (QBCore and QBCore.Shared and QBCore.Shared.Items)
        or (QBShared and QBShared.Items)

    if not sharedItems then
        log("No QBCore items list found (QBCore.Shared.Items or QBShared.Items missing)")
        return out
    end

    for name, v in pairs(sharedItems) do
        local itemName = name
        if type(itemName) ~= "string" then
            itemName = tostring(itemName)
        end

        local label = (v and (v.label or v.name)) or itemName
        local itemType = (v and (v.type or v.category)) or ""
        local weight = v and (v.weight or v["weight"]) or nil
        local image = v and (v.image or v.icon) or nil

        out[#out+1] = {
            name   = itemName,
            label  = label,
            type   = itemType,
            weight = weight,
            image  = image,
            source = "qbshared",
        }
    end

    table.sort(out, function(a, b)
        local la = (a.label or a.name or ""):lower()
        local lb = (b.label or b.name or ""):lower()
        if la == lb then
            return (a.name or "") < (b.name or "")
        end
        return la < lb
    end)

    log(("Built %d items from qb-core shared list"):format(#out))
    return out
end

-------------------------------------------------
-- Public API
-------------------------------------------------

function AS.Items.Refresh()
    local system = getInventorySystem()

    -- For now, only qb-inventory/qb-core style is supported.
    if system == 'qb-inventory' or system == 'qbcore' or system == 'qb' then
        AS.Items.List = buildFromQBCore()
    else
        log('Inventory system "%s" not yet supported for items list; keeping previous list (%d items).',
            system, #AS.Items.List)
    end

    return AS.Items.List
end

function AS.Items.GetList()
    if not AS.Items.List or #AS.Items.List == 0 then
        AS.Items.Refresh()
    end
    return AS.Items.List
end

-------------------------------------------------
-- Items view events (server ↔ client)
-------------------------------------------------

if Events and Events.Items then

    -- Client → Server: request items list
    RegisterNetEvent(Events.Items.GetList, function()
        local src = source
        if not canListItems(src) then return end

        local list = AS.Items.GetList()
        TriggerClientEvent(Events.Items.GetList, src, { items = list })

        audit(src, 'items:list:get', { count = #list })
    end)

    -- Client → Server: force refresh items list and re-send
    RegisterNetEvent(Events.Items.RefreshList, function()
        local src = source
        if not canListItems(src) then return end

        local list = AS.Items.Refresh()
        TriggerClientEvent(Events.Items.RefreshList, src, { items = list })

        audit(src, 'items:list:refresh', { count = #list })
    end)

else
    log('Events.Items not defined; skipping items list wiring.')
end

-------------------------------------------------
-- Init message
-------------------------------------------------

local count = (AS.Items.List and #AS.Items.List) or 0
if Utils and Utils.Info then
    Utils.Info(('Items module initialized (items=%d)'):format(count))
else
    print(('[AdminSuite:Items] initialized (items=%d)'):format(count))
end
