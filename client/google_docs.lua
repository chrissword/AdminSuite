AS = AS or {}
AS.ClientDocs = AS.ClientDocs or {}

local Events = AS.Events
local Utils  = AS.ClientUtils

AS.ClientDocs.List = {}

if Events and Events.Docs then
    -- Docs list -> NUI expects { docs = [...] }
    RegisterNetEvent(Events.Docs.List, function(list)
        AS.ClientDocs.List = list or {}

        if Utils and Utils.Debug then
            Utils.Debug('Docs list received (%d)', #AS.ClientDocs.List)
        end

        AS.ClientUtils.SendNUI(
            AS.Events.NUI and AS.Events.NUI.DocsList or 'as:nui:docs:list',
            { docs = AS.ClientDocs.List }
        )
    end)

    -- Open specific doc -> NUI expects { doc = { ... } }
    RegisterNetEvent(Events.Docs.Open, function(doc)
        AS.ClientUtils.SendNUI(
            AS.Events.NUI and AS.Events.NUI.DocsOpen or 'as:nui:docs:open',
            { doc = doc or nil }
        )
    end)

    -- RequestEdit stays as-is for now (no JS handler yet, but this is future-proof)
    RegisterNetEvent(Events.Docs.RequestEdit, function(allowed)
        AS.ClientUtils.SendNUI(
            AS.Events.NUI and AS.Events.NUI.DocsRequestEdit or 'as:nui:docs:requestEdit',
            { allowed = allowed and true or false }
        )
    end)

    -- Refresh doc -> same shape as Open
    RegisterNetEvent(Events.Docs.Refresh, function(doc)
        AS.ClientUtils.SendNUI(
            AS.Events.NUI and AS.Events.NUI.DocsRefresh or 'as:nui:docs:refresh',
            { doc = doc or nil }
        )
    end)
end
