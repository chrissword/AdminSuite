AS = AS or {}

local Events  = AS.Events
local RBAC    = AS.RBAC
local Players = AS.Players

if not Events or not Events.Moderation then
    return
end

local function requireFlag(src, flag)
    local ok, roleName = RBAC.Can(src, flag)
    if not ok then
        TriggerClientEvent('chat:addMessage', src, {
            args = { '^8AdminSuite', ('You do not have permission (%s) for this action.'):format(flag) }
        })
        return false
    end
    return true
end

-- Heal / Revive

RegisterNetEvent(Events.Moderation.Heal, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_heal_revive') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Heal(src, targetSrc)
end)

RegisterNetEvent(Events.Moderation.Revive, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_heal_revive') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Revive(src, targetSrc)
end)

-- Freeze / Unfreeze

RegisterNetEvent(Events.Moderation.Freeze, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_freeze') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Freeze(src, targetSrc, true)
end)

RegisterNetEvent(Events.Moderation.Unfreeze, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_freeze') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Freeze(src, targetSrc, false)
end)

-- Teleport / Spectate

RegisterNetEvent(Events.Moderation.Bring, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_teleport') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Bring(src, targetSrc)
end)

RegisterNetEvent(Events.Moderation.Goto, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_teleport') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Goto(src, targetSrc)
end)

RegisterNetEvent(Events.Moderation.SendBack, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_teleport') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.SendBack(src, targetSrc)
end)

RegisterNetEvent(Events.Moderation.SpectateStart, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_spectate') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.SpectateStart(src, targetSrc)
end)

RegisterNetEvent(Events.Moderation.SpectateStop, function()
    local src = source
    if not requireFlag(src, 'can_spectate') then return end

    Players.SpectateStop(src)
end)
