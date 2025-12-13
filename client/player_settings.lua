AS = AS or {}
AS.ClientPlayerSettings = AS.ClientPlayerSettings or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

if Events and Events.Settings and AS.Events and AS.Events.NUI then
    RegisterNetEvent(Events.Settings.GetPlayerSettings, function(payload)
        payload = payload or {}

        if Utils and Utils.Debug then
            Utils.Debug('Player settings payload: %s', json.encode(payload or {}))
        end

        AS.ClientUtils.SendNUI(
            AS.Events.NUI.SettingsLoad or 'as:nui:settings:load',
            { player = payload or {} }
        )
    end)
end
