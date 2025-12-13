AS = AS or {}

local Events = AS.Events
local Docs   = AS.Docs
local RBAC   = AS.RBAC

if not Events or not Events.Docs then
    return
end

RegisterNetEvent(Events.Docs.List, function()
    local src = source
    if not RBAC.IsStaff(src) then return end

    local docsList = Docs.GetFilteredList(src)
    TriggerClientEvent(Events.Docs.List, src, docsList)
end)

RegisterNetEvent(Events.Docs.Open, function(id)
    local src = source
    if not RBAC.IsStaff(src) then return end

    local doc = Docs.Open(src, id)
    TriggerClientEvent(Events.Docs.Open, src, doc)
end)

RegisterNetEvent(Events.Docs.Close, function(id)
    local src = source
    if not RBAC.IsStaff(src) then return end

    -- For now, just audit in Docs.Open/RequestEdit/UpdatePermissions.
    -- Closing is purely client-side UX.
end)

RegisterNetEvent(Events.Docs.RequestEdit, function(id)
    local src = source
    if not RBAC.IsStaff(src) then return end

    local allowed = Docs.RequestEdit(src, id)
    TriggerClientEvent(Events.Docs.RequestEdit, src, allowed)
end)

RegisterNetEvent(Events.Docs.UpdatePermissions, function(id, payload)
    local src = source
    if not RBAC.IsStaff(src) then return end

    Docs.UpdatePermissions(src, id, payload)
end)

RegisterNetEvent(Events.Docs.Refresh, function(id)
    local src = source
    if not RBAC.IsStaff(src) then return end

    local doc = Docs.Refresh(src, id)
    TriggerClientEvent(Events.Docs.Refresh, src, doc)
end)
