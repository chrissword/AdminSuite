AS = AS or {}
AS.AdminChat = AS.AdminChat or {}

local Events      = AS.Events
local RBAC        = AS.RBAC
local Utils       = AS.Utils
local Persistence = AS.Persistence
local Audit       = AS.Audit

AS.AdminChat.Messages = AS.AdminChat.Messages or {}

--========================================
-- Helpers
--========================================

local function broadcastUpdate()
    if not Events or not Events.AdminChat then return end
    TriggerClientEvent(Events.AdminChat.HistoryUpdated, -1, AS.AdminChat.Messages)
end

local function appendMessage(src, message)
    if not message or message == '' then
        return nil
    end

    local name = GetPlayerName(src) or ('ID %d'):format(src)

    local entry = {
        id        = #AS.AdminChat.Messages + 1,
        author    = name,
        authorSrc = src,
        message   = tostring(message),
        time      = os.time(),
    }

    AS.AdminChat.Messages[#AS.AdminChat.Messages + 1] = entry

    if Persistence then
        Persistence.Save('AdminChat', AS.AdminChat.Messages)
    end

    if Audit and Audit.Log then
        Audit.Log(src, nil, 'adminchat:message', {
            message = message,
        })
    end

    return entry
end

--========================================
-- Net events
--========================================

if Events and Events.AdminChat then
    RegisterNetEvent(Events.AdminChat.SendMessage, function(message)
        local src = source

        if not RBAC or not RBAC.IsStaff or not RBAC.IsStaff(src) then
            return
        end

        local entry = appendMessage(src, message)
        if not entry then
            return
        end

        TriggerClientEvent(Events.AdminChat.Broadcast, -1, entry)
        broadcastUpdate()
    end)

    RegisterNetEvent(Events.AdminChat.GetHistory, function()
        local src = source

        if not RBAC or not RBAC.IsStaff or not RBAC.IsStaff(src) then
            return
        end

        TriggerClientEvent(Events.AdminChat.GetHistory, src, AS.AdminChat.Messages)
    end)

    RegisterNetEvent(Events.AdminChat.Purge, function()
        local src = source

        local ok = RBAC and RBAC.Can and RBAC.Can(src, 'can_use_adminchat_purge')
        if not ok then
            return
        end

        AS.AdminChat.Messages = {}

        if Persistence then
            Persistence.Save('AdminChat', AS.AdminChat.Messages)
        end

        if Audit and Audit.Log then
            Audit.Log(src, nil, 'adminchat:purge', {})
        end

        broadcastUpdate()
    end)
end

--========================================
-- Initialization
--========================================

local persisted = Persistence and Persistence.Load('AdminChat') or nil
if type(persisted) == 'table' then
    AS.AdminChat.Messages = persisted
end

if Utils and Utils.Info then
    Utils.Info('Admin chat initialized (messages=%d)', #AS.AdminChat.Messages)
end
