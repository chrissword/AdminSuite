AS = AS or {}
local Events     = AS.Events
local Discipline = AS.Discipline

RegisterNetEvent(Events.Discipline.Add, function(payload)
    local src = source
    local ok, err = Discipline.AddEntry(src, payload or {})
    if not ok and AS.Utils and AS.Utils.Debug then
        AS.Utils.Debug("Discipline:Add failed (%s)", err)
    end
end)

RegisterNetEvent(Events.Discipline.Update, function(payload)
    local src = source
    local ok, err = Discipline.UpdateEntry(src, payload or {})
    if not ok and AS.Utils and AS.Utils.Debug then
        AS.Utils.Debug("Discipline:Update failed (%s)", err)
    end
end)

RegisterNetEvent(Events.Discipline.Delete, function(payload)
    local src = source
    local ok, err = Discipline.DeleteEntry(src, payload or {})
    if not ok and AS.Utils and AS.Utils.Debug then
        AS.Utils.Debug("Discipline:Delete failed (%s)", err)
    end
end)
