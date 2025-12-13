AS = AS or {}
AS.ClientResources = AS.ClientResources or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientResources.List = AS.ClientResources.List or {}

local function debug(msg, ...)
    if Utils and Utils.Debug then
        Utils.Debug('[Resources:Client] ' .. msg, ...)
    else
        print(('[AdminSuite:Resources:Client] ' .. msg):format(...))
    end
end

-------------------------------------------------
-- Server → Client: resources list
-------------------------------------------------

if Events and Events.Resources then
    RegisterNetEvent(Events.Resources.GetList, function(payload)
        payload = payload or {}
        local list = payload.resources or payload.list or payload

        if type(list) ~= 'table' then
            list = {}
        end

        AS.ClientResources.List = list

        debug('Resources list received (%d entries)', #AS.ClientResources.List)

        if Utils and Utils.SendNUI then
            Utils.SendNUI(
                (AS.Events.NUI and AS.Events.NUI.ResourcesLoad) or 'as:nui:resources:load',
                { resources = list }
            )
        end
    end)

    RegisterNetEvent(Events.Resources.Refresh, function(payload)
        payload = payload or {}
        local list = payload.resources or payload.list or payload

        if type(list) ~= 'table' then
            list = {}
        end

        AS.ClientResources.List = list

        debug('Resources list refreshed (%d entries)', #AS.ClientResources.List)

        if Utils and Utils.SendNUI then
            Utils.SendNUI(
                (AS.Events.NUI and AS.Events.NUI.ResourcesRefresh) or 'as:nui:resources:refresh',
                { resources = list }
            )
        end
    end)
else
    debug('Events.Resources not defined; client resources handlers skipped')
end
