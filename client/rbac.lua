AS = AS or {}
AS.ClientRBAC = AS.ClientRBAC or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientRBAC.Self = nil

-- Receive from server/rbac.lua
if Events and Events.RBAC then
    RegisterNetEvent(Events.RBAC.GetSelf, function(data)
        AS.ClientRBAC.Self = data
        Utils.Debug('Received RBAC self: %s', json.encode(data or {}))

        -- Existing behavior: push basic role info into Settings UI
        AS.ClientUtils.SendNUI(Events.NUI.SettingsLoad or 'as:nui:settings:load', {
            role     = data and data.role or nil,
            label    = data and data.label or nil,
            color    = data and data.color or nil,
            priority = data and data.priority or nil,
        })

        -- NEW: push full RBAC payload (including flags) into NUI so JS
        -- can hide actions the role cannot use.
        AS.ClientUtils.SendNUI(
            (Events.NUI and Events.NUI.RBACUpdate) or 'as:nui:rbac:update',
            data or {}
        )
    end)
end

function AS.ClientRBAC.GetSelf()
    return AS.ClientRBAC.Self
end

-- Initial RBAC bootstrap
--===================================

CreateThread(function()
    -- Give the resource a moment to fully initialize, then
    -- ask the server for our RBAC data so it is ready when
    -- the player first tries to open the panel.
    Wait(2000)

    if Events and Events.RBAC and Events.RBAC.GetSelf then
        Utils.Debug('Requesting initial RBAC self from server...')
        TriggerServerEvent(Events.RBAC.GetSelf)
    end
end)
