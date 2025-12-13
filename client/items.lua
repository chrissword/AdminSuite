AS = AS or {}
AS.ClientItems = AS.ClientItems or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientItems.List = AS.ClientItems.List or {}

-------------------------------------------------
-- Small helpers
-------------------------------------------------

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Items:Client] ' .. msg, ...)
    else
        print(('[AdminSuite:Items:Client] ' .. msg):format(...))
    end
end

-------------------------------------------------
-- Server → Client: items list (for Items view)
-------------------------------------------------

if Events and Events.Items then

    -- Initial / full list
    RegisterNetEvent(Events.Items.GetList, function(payload)
        payload = payload or {}
        local list = payload.items or payload.list or payload

        if type(list) ~= 'table' then
            list = {}
        end

        AS.ClientItems.List = list or {}
        debug('Items list received (%d entries)', #AS.ClientItems.List)

        if Utils and Utils.SendNUI then
            Utils.SendNUI(
                -- We can later add AS.Events.NUI.ItemsLoad, but this fallback keeps it self-contained.
                'as:nui:items:load',
                { items = list }
            )
        end
    end)

    -- Refresh/update
    RegisterNetEvent(Events.Items.RefreshList, function(payload)
        payload = payload or {}
        local list = payload.items or payload.list or payload

        if type(list) ~= 'table' then
            list = {}
        end

        AS.ClientItems.List = list or {}
        debug('Items list refreshed (%d entries)', #AS.ClientItems.List)

        if Utils and Utils.SendNUI then
            Utils.SendNUI(
                'as:nui:items:refresh',
                { items = list }
            )
        end
    end)

else
    debug('Events.Items not defined; client items handlers skipped')
end

-------------------------------------------------
-- Public helper: request items list from server
-------------------------------------------------

function AS.ClientItems.RequestList()
    if not Events or not Events.Items or not Events.Items.GetList then
        debug('Cannot request items list: Events.Items.GetList missing')
        return
    end

    TriggerServerEvent(Events.Items.GetList)
end

function AS.ClientItems.Refresh()
    if not Events or not Events.Items or not Events.Items.RefreshList then
        debug('Cannot refresh items list: Events.Items.RefreshList missing')
        return
    end

    TriggerServerEvent(Events.Items.RefreshList)
end
