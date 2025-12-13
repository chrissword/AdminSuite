AS = AS or {}
AS.ClientAdminChat = AS.ClientAdminChat or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientAdminChat.Messages = AS.ClientAdminChat.Messages or {}

if Events and Events.AdminChat then
    RegisterNetEvent(Events.AdminChat.Broadcast, function(entry)
        AS.ClientAdminChat.Messages[#AS.ClientAdminChat.Messages + 1] = entry
        Utils.Debug('AdminChat broadcast: %s', json.encode(entry or {}))

        AS.ClientUtils.SendNUI(AS.Events.NUI.AdminChatReceiveMessage or 'as:nui:adminchat:receiveMessage', entry)
    end)

    RegisterNetEvent(Events.AdminChat.HistoryUpdated, function(all)
        AS.ClientAdminChat.Messages = all or {}
        Utils.Debug('AdminChat history updated (%d messages)', #AS.ClientAdminChat.Messages)

        AS.ClientUtils.SendNUI(AS.Events.NUI.AdminChatLoadHistory or 'as:nui:adminchat:loadHistory', all or {})
    end)

    RegisterNetEvent(Events.AdminChat.GetHistory, function(all)
        AS.ClientAdminChat.Messages = all or {}
        Utils.Debug('AdminChat history received (%d messages)', #AS.ClientAdminChat.Messages)

        AS.ClientUtils.SendNUI(AS.Events.NUI.AdminChatLoadHistory or 'as:nui:adminchat:loadHistory', all or {})
    end)
end
