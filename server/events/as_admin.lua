AS = AS or {}

local Events  = AS.Events
local RBAC    = AS.RBAC
local Players = AS.Players
local Audit   = AS.Audit
local Config  = AS.Config or Config

if not Events or not Events.Moderation then
    return
end

--========================================
-- Helpers
--========================================

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

--========================================
-- Player list / detail
--========================================

RegisterNetEvent(Events.Moderation.GetPlayers, function()
    local src = source
    if not RBAC.IsStaff(src) then return end

    local list = Players.GetPlayersSnapshot()
    TriggerClientEvent(Events.Moderation.GetPlayers, src, list)
end)

RegisterNetEvent(Events.Moderation.GetPlayerDetail, function(targetSrc)
    local src = source
    if not RBAC.IsStaff(src) then return end

    local detail = Players.GetPlayerDetail(tonumber(targetSrc))
    TriggerClientEvent(Events.Moderation.GetPlayerDetail, src, detail)
end)

--========================================
-- Kick / Warn / Ban / Unban
--========================================

RegisterNetEvent(Events.Moderation.Kick, function(targetSrc, reason)
    local src = source
    if not requireFlag(src, 'can_kick') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Kick(src, targetSrc, reason)
end)

RegisterNetEvent(Events.Moderation.Warn, function(targetSrc, reason)
    local src = source
    if not requireFlag(src, 'can_warn') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.Warn(src, targetSrc, reason)

    local staffName       = GetPlayerName(src) or 'Staff'
    local sanitizedReason = tostring(reason or 'You have been warned by staff.')

    TriggerClientEvent(Events.Moderation.Warn, targetSrc, {
        reason   = sanitizedReason,
        staff    = staffName,
        keyLabel = 'E',
    })
end)

RegisterNetEvent(Events.Moderation.Ban, function(targetSrcOrIdentifier, reason, durationSeconds)
    local src = source
    durationSeconds = tonumber(durationSeconds) or 0

    local flag = durationSeconds == 0 and 'can_ban_perm' or 'can_ban_temp'
    if not requireFlag(src, flag) then return end

    Players.Ban(src, targetSrcOrIdentifier, reason, durationSeconds)
end)

RegisterNetEvent(Events.Moderation.Unban, function(targetIdentifier)
    local src = source
    if not requireFlag(src, 'can_ban_perm') then return end

    Players.Unban(src, targetIdentifier)
end)

--========================================
-- BANNED PLAYERS PANEL (NEW)
--========================================

-- Load ban list for Banned Players NUI panel
RegisterNetEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', function()
    local src = source
    if not RBAC.IsStaff(src) then return end

    local bans = Players.GetAllBans() or {}

    TriggerClientEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', src, {
        bans = bans
    })
end)

-- Unban via Banned Players panel
RegisterNetEvent(Events.NUI.BannedPlayersUnban or 'as:nui:bannedplayers:unban', function(payload)
    local src = source
    if not requireFlag(src, 'can_ban_perm') then return end

    payload = payload or {}
    local targetId = tostring(payload.target or "")
    if targetId == "" then return end

    local existing = Players.GetBanById(targetId)
    if not existing then return end

    -- Use the logical target_identifier in the bans table for the actual unban
    Players.Unban(src, existing.target_identifier)

    Audit.Log(src, targetId, 'moderation:unban', {
        reason = "Unban from Banned Players Panel",
        ban    = existing
    })

    local bans = Players.GetAllBans() or {}
    TriggerClientEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', src, {
        bans = bans
    })
end)

--========================================
-- Noclip
--========================================

do
    local noclipEvent = (Events.Core and Events.Core.ToggleNoclip) or 'as:core:toggleNoclip'

    RegisterNetEvent(noclipEvent, function()
        local src = source

        if not requireFlag(src, 'can_noclip') then return end

        if Audit and Audit.Log then
            Audit.Log(src, src, 'moderation:noclip', {
                action = 'toggle',
            })
        end

        TriggerClientEvent(noclipEvent, src)
    end)
end

--========================================
-- Messaging
--========================================

RegisterNetEvent(Events.Moderation.Message, function(targetSrc, message)
    local src = source
    if not RBAC.IsStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    TriggerClientEvent('chat:addMessage', targetSrc, {
        args = { '^8AdminSuite', tostring(message or '') }
    })

    Audit.Log(src, targetSrc, 'moderation:message', {
        message = message,
    })
end)

--========================================
-- Money / Items / Inventory
--========================================

RegisterNetEvent(Events.Moderation.GiveMoney, function(targetSrc, account, amount)
    local src = source
    if not requireFlag(src, 'can_give_money') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.GiveMoney(src, targetSrc, account, amount)
end)

RegisterNetEvent(Events.Moderation.TakeMoney, function(targetSrc, account, amount)
    local src = source
    if not requireFlag(src, 'can_take_money') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.TakeMoney(src, targetSrc, account, amount)
end)

RegisterNetEvent(Events.Moderation.GiveItem, function(targetSrc, item, amount)
    local src = source
    if not requireFlag(src, 'can_give_item') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.GiveItem(src, targetSrc, item, amount)
end)

RegisterNetEvent(Events.Moderation.RemoveItem, function(targetSrc, item, amount)
    local src = source
    if not requireFlag(src, 'can_take_item') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.RemoveItem(src, targetSrc, item, amount)
end)

RegisterNetEvent(Events.Moderation.ViewInventory, function(targetSrc)
    local src = source
    if not RBAC.IsStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.ViewInventory(src, targetSrc)
end)

--========================================
-- Player Settings
--========================================

local Config = AS.Config or Config

RegisterNetEvent(Events.Settings.GetPlayerSettings, function(targetSrc)
    local src = source
    if not RBAC.IsStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local payload = Players.GetPlayerSettings(targetSrc)
    if not payload then return end

    TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
end)

RegisterNetEvent(Events.Settings.SetJob, function(targetSrc, jobName, grade)
    local src = source
    if not requireFlag(src, 'can_manage_jobs') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.SetJob(src, targetSrc, jobName, grade)

    local payload = Players.GetPlayerSettings(targetSrc)
    if payload then
        TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
    end
end)

RegisterNetEvent(Events.Settings.SetGang, function(targetSrc, gangName, grade)
    local src = source
    if not requireFlag(src, 'can_manage_gangs') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.SetGang(src, targetSrc, gangName, grade)

    local payload = Players.GetPlayerSettings(targetSrc)
    if payload then
        TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
    end
end)

-- Staff role / whitelist management
RegisterNetEvent(Events.Settings.SetStaffRole, function(targetSrc, value)
    local src = source
    if not requireFlag(src, 'can_manage_staff_roles') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    if type(value) == 'boolean' then
        --------------------------------------------------
        -- Legacy behavior: toggle QBCore-style whitelist
        --------------------------------------------------
        Players.SetWhitelist(src, targetSrc, value)
    else
        --------------------------------------------------
        -- New behavior: Add / Update Admin (staff role)
        --------------------------------------------------
        local roleName = tostring(value or ''):lower()
        if roleName == '' then return end

        local staff = AS.Staff or {}
        local roles = staff.Roles or {}
        if not roles[roleName] then
            -- Unknown role; do nothing
            return
        end

        local licenseId = nil
        for _, identifier in ipairs(GetPlayerIdentifiers(targetSrc)) do
            if identifier:sub(1, 8) == 'license:' then
                licenseId = identifier
                break
            end
        end

        if not licenseId then return end

        if staff.AddOrUpdateMapping then
            staff.AddOrUpdateMapping(licenseId, roleName, src, targetSrc)
        else
            staff.Mappings = staff.Mappings or {}
            staff.Mappings[licenseId] = roleName
        end

        if Audit and Audit.Log then
            Audit.Log(src, targetSrc, 'settings:addAdmin', {
                role       = roleName,
                identifier = licenseId,
            })
        end
    end

    local payload = Players.GetPlayerSettings(targetSrc)
    if payload then
        TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
    end
end)

-- Remove Admin (clear staff role for this player's license)
RegisterNetEvent(Events.Settings.ClearStaffRole, function(targetSrc)
    local src = source
    if not requireFlag(src, 'can_manage_staff_roles') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local staff = AS.Staff or {}
    staff.Mappings = staff.Mappings or {}

    local licenseId = nil
    for _, identifier in ipairs(GetPlayerIdentifiers(targetSrc)) do
        if identifier:sub(1, 8) == 'license:' then
            licenseId = identifier
            break
        end
    end

    if not licenseId then return end

    if staff.RemoveMapping then
        staff.RemoveMapping(licenseId, src, targetSrc)
    else
        staff.Mappings[licenseId] = nil
    end

    if Audit and Audit.Log then
        Audit.Log(src, targetSrc, 'settings:removeAdmin', {
            identifier = licenseId,
        })
    end

    local payload = Players.GetPlayerSettings(targetSrc)
    if payload then
        TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
    end
end)



RegisterNetEvent(Events.Settings.OpenClothing, function(targetSrc)
    local src = source
    if not RBAC.IsStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local integration = (Config and Config.SkinIntegration) or 'none'

    if integration == 'qb-clothing' then
        TriggerClientEvent('qb-clothing:client:openMenu', targetSrc)
    elseif integration == 'illenium-appearance' then
        TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', targetSrc, {})
    end

    Audit.Log(src, targetSrc, 'settings:openClothing', {
        integration = integration
    })
end)
