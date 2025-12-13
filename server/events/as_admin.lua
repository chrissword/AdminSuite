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

local function staffMsg(src, msg)
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^8AdminSuite', tostring(msg or '') }
    })
end

local function requireFlag(src, flag)
    if not RBAC or not RBAC.Can then
        staffMsg(src, 'RBAC not available; cannot verify permissions.')
        return false
    end

    local ok = RBAC.Can(src, flag)
    if not ok then
        staffMsg(src, ('You do not have permission (%s) for this action.'):format(flag))
        return false
    end
    return true
end

local function isStaff(src)
    return RBAC and RBAC.IsStaff and RBAC.IsStaff(src)
end

local function getScreenshotsWebhook()
    local hooks = Config and Config.Integrations and Config.Integrations.Webhooks or {}
    return tostring(hooks.Screenshots or '')
end

-- Simple base64 decode (works for Discord file upload)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function base64Decode(data)
    if not data or data == '' then return '' end
    data = data:gsub('%s', ''):gsub('=+$', '')
    local out = {}
    local buffer = 0
    local bits = 0

    for i = 1, #data do
        local c = data:sub(i, i)
        local v = b64lookup[c]
        if v ~= nil then
            buffer = (buffer << 6) | v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = (buffer >> bits) & 0xFF
                out[#out + 1] = string.char(byte)
            end
        end
    end

    return table.concat(out)
end

local function postDiscordWebhookMultipart(webhookUrl, payloadTable, fileFieldName, fileName, fileBytes)
    local boundary = '----AdminSuiteBoundary' .. tostring(math.random(100000, 999999)) .. tostring(os.time())

    local payloadJson = json.encode(payloadTable or {})

    local CRLF = '\r\n'
    local parts = {}

    -- payload_json part
    parts[#parts + 1] = '--' .. boundary .. CRLF
    parts[#parts + 1] = 'Content-Disposition: form-data; name="payload_json"' .. CRLF
    parts[#parts + 1] = 'Content-Type: application/json' .. CRLF .. CRLF
    parts[#parts + 1] = payloadJson .. CRLF

    -- file part
    parts[#parts + 1] = '--' .. boundary .. CRLF
    parts[#parts + 1] = ('Content-Disposition: form-data; name="%s"; filename="%s"'):format(fileFieldName, fileName) .. CRLF
    parts[#parts + 1] = 'Content-Type: image/jpeg' .. CRLF .. CRLF
    parts[#parts + 1] = fileBytes .. CRLF

    -- end boundary
    parts[#parts + 1] = '--' .. boundary .. '--' .. CRLF

    local body = table.concat(parts)

    PerformHttpRequest(webhookUrl, function(code, respBody, headers)
        print(('[AdminSuite] Discord webhook response code=%s'):format(tostring(code)))
        if code ~= 200 and code ~= 204 then
            print('[AdminSuite] Discord response body:', tostring(respBody))
        end
    end, 'POST', body, {
        ['Content-Type'] = ('multipart/form-data; boundary=%s'):format(boundary)
    })
end

--========================================
-- Player list / detail
--========================================

RegisterNetEvent(Events.Moderation.GetPlayers, function()
    local src = source
    if not isStaff(src) then return end

    local list = Players.GetPlayersSnapshot()
    TriggerClientEvent(Events.Moderation.GetPlayers, src, list)
end)

RegisterNetEvent(Events.Moderation.GetPlayerDetail, function(targetSrc)
    local src = source
    if not isStaff(src) then return end

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

    local flag = (durationSeconds == 0) and 'can_ban_perm' or 'can_ban_temp'
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

RegisterNetEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', function()
    local src = source
    if not isStaff(src) then return end

    local bans = Players.GetAllBans() or {}
    TriggerClientEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', src, { bans = bans })
end)

RegisterNetEvent(Events.NUI.BannedPlayersUnban or 'as:nui:bannedplayers:unban', function(payload)
    local src = source
    if not requireFlag(src, 'can_ban_perm') then return end

    payload = payload or {}
    local targetId = tostring(payload.target or "")
    if targetId == "" then return end

    local existing = Players.GetBanById(targetId)
    if not existing then return end

    Players.Unban(src, existing.target_identifier)

    if Audit and Audit.Log then
        Audit.Log(src, targetId, 'moderation:unban', {
            reason = "Unban from Banned Players Panel",
            ban    = existing
        })
    end

    local bans = Players.GetAllBans() or {}
    TriggerClientEvent(Events.NUI.BannedPlayersLoad or 'as:nui:bannedplayers:load', src, { bans = bans })
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
            Audit.Log(src, src, 'moderation:noclip', { action = 'toggle' })
        end

        TriggerClientEvent(noclipEvent, src)
    end)
end

--========================================
-- Messaging
--========================================

RegisterNetEvent(Events.Moderation.Message, function(targetSrc, message)
    local src = source
    if not isStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    TriggerClientEvent('chat:addMessage', targetSrc, {
        args = { '^8AdminSuite', tostring(message or '') }
    })

    if Audit and Audit.Log then
        Audit.Log(src, targetSrc, 'moderation:message', { message = message })
    end
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
    if not isStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    Players.ViewInventory(src, targetSrc)
end)

-------------------------------------------------
-- Screenshot Player (works with your screenshot-basic build)
-- screenshot-basic export available: requestClientScreenshot
-------------------------------------------------
RegisterNetEvent(Events.Moderation.Screenshot, function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc or 0)
    if not targetSrc or targetSrc <= 0 then return end

    -- RBAC: allow either flag name
    local ok1 = RBAC and RBAC.Can and RBAC.Can(src, 'can_screenshot_player') or false
    local ok2 = RBAC and RBAC.Can and RBAC.Can(src, 'can_screenshot') or false

    if not ok1 and not ok2 then
        staffMsg(src, 'You do not have permission to screenshot players.')
        return
    end

    if GetResourceState('screenshot-basic') ~= 'started' then
        staffMsg(src, 'screenshot-basic is not started. Install/start it to use screenshots.')
        return
    end

    local webhook = getScreenshotsWebhook()
    if webhook == '' then
        print('[AdminSuite] Screenshot: webhook is EMPTY at Config.Integrations.Webhooks.Screenshots')
        staffMsg(src, 'Screenshots webhook URL is not configured in config.lua.')
        return
    end

    -- Capture screenshot from target
    exports['screenshot-basic']:requestClientScreenshot(targetSrc, { encoding = 'jpg', quality = 0.85 }, function(err, data)
        if err then
            print('[AdminSuite] Screenshot capture error:', err)
            staffMsg(src, 'Screenshot failed (capture error). Check server console.')
            return
        end

        if not data or type(data) ~= 'string' or data == '' then
            print('[AdminSuite] Screenshot capture returned empty data')
            staffMsg(src, 'Screenshot failed (empty data).')
            return
        end

        -- data URL -> raw base64
        local b64 = data:gsub('^data:image/%w+;base64,', '')
        local bytes = base64Decode(b64)

        if not bytes or bytes == '' then
            print('[AdminSuite] Screenshot decode produced empty bytes')
            staffMsg(src, 'Screenshot failed (decode error).')
            return
        end

        local staffName  = GetPlayerName(src) or ('ID ' .. tostring(src))
        local targetName = GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))

        -- Discord will show attachment automatically; no embed required
        local payload = {
            content = ('📸 Screenshot requested by **%s** | Target: **%s** (ID %s)'):format(
                staffName,
                targetName,
                tostring(targetSrc)
            )
        }

        -- Upload to Discord webhook (multipart)
        postDiscordWebhookMultipart(webhook, payload, 'files[0]', 'screenshot.jpg', bytes)

        if Audit and Audit.Log then
            Audit.Log(src, targetSrc, 'screenshot:player', {
                ok = true,
                staff = staffName,
                target = targetName
            })
        end

        staffMsg(src, 'Screenshot captured and sent to Discord.')
    end)
end)

--========================================
-- Player Settings
--========================================

RegisterNetEvent(Events.Settings.GetPlayerSettings, function(targetSrc)
    local src = source
    if not isStaff(src) then return end

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

RegisterNetEvent(Events.Settings.SetStaffRole, function(targetSrc, value)
    local src = source
    if not requireFlag(src, 'can_manage_staff_roles') then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    if type(value) == 'boolean' then
        Players.SetWhitelist(src, targetSrc, value)
    else
        local roleName = tostring(value or ''):lower()
        if roleName == '' then return end

        local staff = AS.Staff or {}
        local roles = staff.Roles or {}
        if not roles[roleName] then
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
        Audit.Log(src, targetSrc, 'settings:removeAdmin', { identifier = licenseId })
    end

    local payload = Players.GetPlayerSettings(targetSrc)
    if payload then
        TriggerClientEvent(Events.Settings.GetPlayerSettings, src, payload)
    end
end)

RegisterNetEvent(Events.Settings.OpenClothing, function(targetSrc)
    local src = source
    if not isStaff(src) then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local integration = (Config and Config.SkinIntegration) or 'none'

    if integration == 'qb-clothing' then
        TriggerClientEvent('qb-clothing:client:openMenu', targetSrc)
    elseif integration == 'illenium-appearance' then
        TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', targetSrc, {})
    end

    if Audit and Audit.Log then
        Audit.Log(src, targetSrc, 'settings:openClothing', { integration = integration })
    end
end)
