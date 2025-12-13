AS = AS or {}
AS.Players = AS.Players or {}

local DB     = AS.DB
local Tables = AS.Tables
local Utils  = AS.Utils
local Audit  = AS.Audit
local RBAC   = AS.RBAC
local Config = AS.Config or Config
local Events = AS.Events
local Staff = AS.Staff

local QBCore = nil

---------------------------------------------------------------------
-- QBCore Attach
---------------------------------------------------------------------
CreateThread(function()
    local coreResources = { 'qb-core', 'qbx-core', 'qbcore' }

    for _, res in ipairs(coreResources) do
        local ok, obj = pcall(function()
            return exports[res]:GetCoreObject()
        end)

        if ok and obj then
            QBCore = obj
            if Utils and Utils.Info then
                Utils.Info(('[AdminSuite] QBCore attached to players.lua using resource "%s"'):format(res))
            else
                print(('[AdminSuite] QBCore attached to players.lua using resource "%s"'):format(res))
            end
            break
        end
    end

    if not QBCore then
        if Utils and Utils.Warn then
            Utils.Warn('[AdminSuite] Failed to attach QBCore in players.lua (tried qb-core / qbx-core / qbcore)')
        else
            print('[AdminSuite:WARN] Failed to attach QBCore in players.lua (tried qb-core / qbx-core / qbcore)')
        end
    end
end)


---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function buildJobsPayload()
    local out = {}

    if not QBCore or not QBCore.Shared or not QBCore.Shared.Jobs then
        return out
    end

    for name, job in pairs(QBCore.Shared.Jobs) do
        local grades = {}

        if job.grades then
            for gradeId, grade in pairs(job.grades) do
                local numericId = tonumber(gradeId)
                    or tonumber(grade.grade or grade.grade_id)
                    or gradeId

                grades[#grades + 1] = {
                    id    = numericId,
                    label = (grade.label or grade.name or tostring(gradeId)),
                }
            end

            table.sort(grades, function(a, b)
                return (a.id or 0) < (b.id or 0)
            end)
        end

        out[#out + 1] = {
            name   = name,
            label  = job.label or name,
            grades = grades,
        }
    end

    table.sort(out, function(a, b)
        return (tostring(a.label):lower()) < (tostring(b.label):lower())
    end)

    return out
end

local function buildGangsPayload()
    local out = {}

    if not QBCore or not QBCore.Shared or not QBCore.Shared.Gangs then
        return out
    end

    for name, gang in pairs(QBCore.Shared.Gangs) do
        local grades = {}

        if gang.grades then
            for gradeId, grade in pairs(gang.grades) do
                local numericId = tonumber(gradeId)
                    or tonumber(grade.grade or grade.grade_id)
                    or gradeId

                grades[#grades + 1] = {
                    id    = numericId,
                    label = (grade.label or grade.name or tostring(gradeId)),
                }
            end

            table.sort(grades, function(a, b)
                return (a.id or 0) < (b.id or 0)
            end)
        end

        out[#out + 1] = {
            name   = name,
            label  = gang.label or name,
            grades = grades,
        }
    end

    table.sort(out, function(a, b)
        return (tostring(a.label):lower()) < (tostring(b.label):lower())
    end)

    return out
end

local function buildStaffRolesPayload()
    local out = {}

    if not Staff or not Staff.Roles then
        return out
    end

    for roleName, role in pairs(Staff.Roles) do
        out[#out + 1] = {
            id       = roleName,
            label    = role.label or roleName,
            priority = role.priority or 0,
        }
    end

    -- higher priority first
    table.sort(out, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)

    return out
end




local function getPlayerFromSource(src)
    if not QBCore then return nil end
    return QBCore.Functions.GetPlayer(src)
end

local function getIdentifierFromPlayer(player)
    if not player then return nil end

    -- QBCore default identifier: citizenid
    local cid = player.PlayerData and player.PlayerData.citizenid
    if cid then
        return ('citizenid:%s'):format(cid)
    end

    return nil
end

-- Grab license/discord/ip from FiveM identifiers for QBCore bans table
local function getIdentifiersFromSource(src)
    local identifiers = {
        license = nil,
        discord = nil,
        ip      = nil,
    }

    if not src then return identifiers end

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then
            identifiers.license = id
        elseif id:sub(1, 8) == 'discord:' then
            identifiers.discord = id
        elseif id:sub(1, 3) == 'ip:' then
            -- bans.ip is typically stored without the "ip:" prefix
            identifiers.ip = id:sub(4)
        end
    end

    return identifiers
end

---------------------------------------------------------------------
-- KICK / BAN / WARN
---------------------------------------------------------------------
function AS.Players.Kick(actorSrc, targetSrc, reason)
    reason = AS.Utils.SanitizeReason(reason)

    DropPlayer(targetSrc, ('[AdminSuite] Kicked: %s'):format(reason))

    Audit.Log(actorSrc, targetSrc, 'moderation:kick', {
        reason = reason,
    })
end

function AS.Players.Warn(actorSrc, targetSrc, reason)
    reason = AS.Utils.SanitizeReason(reason)

    -- Placeholder: simple chat warning.
    -- Future phase: red-screen NUI overlay with acknowledge key.
    TriggerClientEvent('chat:addMessage', targetSrc, {
        args = { '^8AdminSuite', ('You have been warned: %s'):format(reason) }
    })

    Audit.Log(actorSrc, targetSrc, 'moderation:warn', {
        reason = reason,
    })
end

function AS.Players.Ban(actorSrc, targetSrcOrId, reason, durationSeconds)
    reason = AS.Utils.SanitizeReason(reason)
    durationSeconds = tonumber(durationSeconds) or 0

    local identifier
    local name, license, discord, ip

    if type(targetSrcOrId) == 'number' then
        -- Online ban: we have a live player object
        local player = getPlayerFromSource(targetSrcOrId)
        identifier = getIdentifierFromPlayer(player)

        name = GetPlayerName(targetSrcOrId) or nil

        local ids = getIdentifiersFromSource(targetSrcOrId)
        license = ids.license
        discord = ids.discord
        ip      = ids.ip
    else
        -- Offline-style ban using a logical identifier (e.g. "citizenid:XYZ")
        identifier = targetSrcOrId
        -- For now we do not resolve license/discord/ip for offline targets.
        name, license, discord, ip = nil, nil, nil, nil
    end

    if not identifier then
        if Utils and Utils.Warn then
            Utils.Warn('Ban failed: no identifier for target')
        else
            print('[AdminSuite:WARN] Ban failed: no identifier for target')
        end
        return false
    end

    local tableName = (Tables and Tables.Bans) or 'bans'

    -- QBCore uses an int timestamp in "expire" for ban duration
    local expiresUnix
    if durationSeconds > 0 then
        expiresUnix = os.time() + durationSeconds
    else
        -- Treat 0 as effectively permanent: far-future expire timestamp
        expiresUnix = os.time() + (365 * 24 * 60 * 60 * 10) -- ~10 years
    end

    -- Insert BOTH:
    --  - QBCore-style fields (license/expire/etc.) so QBCore will enforce the ban
    --  - AdminSuite tracking fields for richer audit/metadata
    DB.execute(([[INSERT INTO `%s`
        (name, license, discord, ip, reason, expire, bannedby,
         actor_identifier, target_identifier, duration_seconds, expires_at)
        VALUES (@name, @license, @discord, @ip, @reason, @expire, @bannedby,
                @actor, @target, @duration, FROM_UNIXTIME(@expires))]])
        :format(tableName),
        {
            -- QBCore fields
            ['@name']     = name,
            ['@license']  = license,
            ['@discord']  = discord,
            ['@ip']       = ip,
            ['@reason']   = reason,
            ['@expire']   = expiresUnix,
            ['@bannedby'] = ('AdminSuite (%s)'):format(actorSrc or 'unknown'),

            -- AdminSuite-specific columns
            ['@actor']    = AS.Utils.SafeJsonEncode({ src = actorSrc }),
            ['@target']   = identifier,
            ['@duration'] = durationSeconds,
            ['@expires']  = expiresUnix,
        }
    )

    Audit.Log(actorSrc, identifier, 'moderation:ban', {
        reason   = reason,
        duration = durationSeconds,
    })

    if type(targetSrcOrId) == 'number' then
        DropPlayer(targetSrcOrId, ('[AdminSuite] Banned: %s'):format(reason))
    end

    return true
end

function AS.Players.Unban(actorSrc, targetIdentifier)
    local tableName = (Tables and Tables.Bans) or 'bans'

    -- QBCore checks the bans row itself, so actually delete the ban record
    -- associated with this logical identifier.
    DB.execute(([[DELETE FROM `%s`
        WHERE target_identifier = @target]])
        :format(tableName),
        { ['@target'] = targetIdentifier }
    )

    Audit.Log(actorSrc, targetIdentifier, 'moderation:unban', {})
end

---------------------------------------------------------------------
-- BANS LIST HELPERS (BANNED PLAYERS VIEW)
---------------------------------------------------------------------
-- Returns a normalized list of *active* bans for the Banned Players NUI view.
function AS.Players.GetAllBans()
    local tableName = (Tables and Tables.Bans) or 'bans'
    local now       = os.time()

    -- Note: using QBCore-style "expire" int timestamp to determine if a ban is active.
    --  - expire = 0 or NULL = treated as permanent
    --  - expire > now       = active timed ban
    -- If your schema differs, adjust this WHERE clause accordingly.
    local rows = DB.fetchAll(([[SELECT
            id,
            name,
            license,
            discord,
            ip,
            reason,
            expire,
            bannedby,
            actor_identifier,
            target_identifier,
            duration_seconds,
            UNIX_TIMESTAMP(expires_at) AS expires_at_unix
        FROM `%s`
        WHERE expire IS NULL OR expire = 0 OR expire > @now]])
        :format(tableName),
        { ['@now'] = now }
    ) or {}

    local bans = {}

    for _, row in ipairs(rows) do
        local expireTs         = tonumber(row.expire) or 0
        local expiresAtUnix    = tonumber(row.expires_at_unix) or expireTs
        local remainingSeconds = 0

        if expireTs ~= 0 and expireTs > now then
            remainingSeconds = expireTs - now
        end

        bans[#bans + 1] = {
            id                = row.id,
            name              = row.name or 'Unknown',
            reason            = row.reason or 'N/A',
            bannedBy          = row.bannedby or 'Unknown',
            license           = row.license,
            discord           = row.discord,
            ip                = row.ip,
            target_identifier = row.target_identifier,
            duration_seconds  = tonumber(row.duration_seconds) or 0,
            expire            = expireTs,
            expires_at_unix   = expiresAtUnix,
            remaining_seconds = remainingSeconds,
        }
    end

    return bans
end

-- Fetch a single ban row by its primary key id for targeted operations (e.g. unban from panel)
function AS.Players.GetBanById(banId)
    banId = tonumber(banId)
    if not banId then return nil end

    local tableName = (Tables and Tables.Bans) or 'bans'
    local now       = os.time()

    local rows = DB.fetchAll(([[SELECT
            id,
            name,
            license,
            discord,
            ip,
            reason,
            expire,
            bannedby,
            actor_identifier,
            target_identifier,
            duration_seconds,
            UNIX_TIMESTAMP(expires_at) AS expires_at_unix
        FROM `%s`
        WHERE id = @id
        LIMIT 1]])
        :format(tableName),
        { ['@id'] = banId }
    )

    local row = rows and rows[1]
    if not row then
        return nil
    end

    local expireTs         = tonumber(row.expire) or 0
    local expiresAtUnix    = tonumber(row.expires_at_unix) or expireTs
    local remainingSeconds = 0

    if expireTs ~= 0 and expireTs > now then
        remainingSeconds = expireTs - now
    end

    return {
        id                = row.id,
        name              = row.name or 'Unknown',
        reason            = row.reason or 'N/A',
        bannedBy          = row.bannedby or 'Unknown',
        license           = row.license,
        discord           = row.discord,
        ip                = row.ip,
        target_identifier = row.target_identifier,
        duration_seconds  = tonumber(row.duration_seconds) or 0,
        expire            = expireTs,
        expires_at_unix   = expiresAtUnix,
        remaining_seconds = remainingSeconds,
    }
end

---------------------------------------------------------------------
-- HEAL / REVIVE
---------------------------------------------------------------------
function AS.Players.Heal(actorSrc, targetSrc)
    local mode = (Config and Config.Medical and Config.Medical.Mode) or 'qb-ambulancejob'

    -- Normalize target (fallback to actor if something weird comes through)
    targetSrc = tonumber(targetSrc) or actorSrc

    if mode == 'qb-ambulancejob' then
        -- Original behavior: use qb-ambulancejob-style client event
        if not QBCore then
            TriggerClientEvent('chat:addMessage', actorSrc, {
                args = { '^8AdminSuite', 'Heal failed: QBCore not attached.' }
            })
            return
        end

        -- Full heal of injuries; qb-ambulancejob handles the rest
        TriggerClientEvent('hospital:client:HealInjuries', targetSrc, 'full')

    elseif mode == 'quasar' then
        -- qs-medical-creator (Quasar) uses ambulance:healPlayer on the client
        -- See qs-medical-creator/custom/qb/server.lua for reference
        TriggerClientEvent('ambulance:healPlayer', targetSrc, true)

    elseif mode == 'custom' then
        -- Your own server-side hook; implement this in your own resource if desired
        TriggerEvent('as:medical:healPlayer', actorSrc, targetSrc)

    else
        -- Fallback: try qb-ambulancejob-style heal without hard-failing
        TriggerClientEvent('hospital:client:HealInjuries', targetSrc, 'full')
    end

    -- Keep AdminSuite audit logging the same regardless of backend
    Audit.Log(actorSrc, targetSrc, 'moderation:heal', {})
end

function AS.Players.Revive(actorSrc, targetSrc)
    local mode = (Config and Config.Medical and Config.Medical.Mode) or 'qb-ambulancejob'

    -- Normalize target
    targetSrc = tonumber(targetSrc) or actorSrc

    if mode == 'qb-ambulancejob' then
        -- Original behavior: qb-ambulancejob client revive
        if not QBCore then
            TriggerClientEvent('chat:addMessage', actorSrc, {
                args = { '^8AdminSuite', 'Revive failed: QBCore not attached.' }
            })
            return
        end

        TriggerClientEvent('hospital:client:Revive', targetSrc)

    elseif mode == 'quasar' then
        -- qs-medical-creator (Quasar) admin revive:
        -- server/modules/commands.lua uses ambulance:revivePlayer
        TriggerClientEvent('ambulance:revivePlayer', targetSrc)

    elseif mode == 'custom' then
        -- Your own server-side revive logic
        TriggerEvent('as:medical:revivePlayer', actorSrc, targetSrc)

    else
        -- Fallback: try qb-ambulancejob-style revive
        TriggerClientEvent('hospital:client:Revive', targetSrc)
    end

    -- Keep AdminSuite audit logging
    Audit.Log(actorSrc, targetSrc, 'moderation:revive', {})
end


---------------------------------------------------------------------
-- FREEZE / TELEPORT / SPECTATE
---------------------------------------------------------------------
function AS.Players.Freeze(actorSrc, targetSrc, shouldFreeze)
    TriggerClientEvent('AdminSuite:moderation:freeze', targetSrc, shouldFreeze)
    Audit.Log(actorSrc, targetSrc, 'moderation:' .. (shouldFreeze and 'freeze' or 'unfreeze'), {})
end

function AS.Players.Bring(actorSrc, targetSrc)
    actorSrc  = tonumber(actorSrc)
    targetSrc = tonumber(targetSrc)
    if not actorSrc or not targetSrc then return end

    local adminPed = GetPlayerPed(actorSrc)
    if not adminPed or adminPed == 0 then return end

    local coords = GetEntityCoords(adminPed)
    if not coords then return end

    TriggerClientEvent('AdminSuite:moderation:bring', targetSrc, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    })

    if Audit and Audit.Log then
        Audit.Log(actorSrc, targetSrc, 'moderation:bring', {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        })
    end
end

function AS.Players.Goto(actorSrc, targetSrc)
    actorSrc  = tonumber(actorSrc)
    targetSrc = tonumber(targetSrc)
    if not actorSrc or not targetSrc then return end

    local targetPed = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then return end

    local coords = GetEntityCoords(targetPed)
    if not coords then return end

    TriggerClientEvent('AdminSuite:moderation:goto', actorSrc, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    })

    if Audit and Audit.Log then
        Audit.Log(actorSrc, targetSrc, 'moderation:goto', {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        })
    end
end

function AS.Players.SendBack(actorSrc, targetSrc)
    TriggerClientEvent('AdminSuite:moderation:sendBack', targetSrc)
    Audit.Log(actorSrc, targetSrc, 'moderation:sendBack', {})
end

function AS.Players.SpectateStart(actorSrc, targetSrc)
    actorSrc  = tonumber(actorSrc)
    targetSrc = tonumber(targetSrc)
    if not actorSrc or not targetSrc then return end

    local targetPed = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then
        return
    end

    local coords = GetEntityCoords(targetPed)

    -- Send target + their coords down to the staff client
    TriggerClientEvent('AdminSuite:moderation:spectateStart', actorSrc, targetSrc, coords)

    Audit.Log(actorSrc, targetSrc, 'moderation:spectate:start', {})
end


function AS.Players.SpectateStop(actorSrc)
    TriggerClientEvent('AdminSuite:moderation:spectateStop', actorSrc)
    Audit.Log(actorSrc, nil, 'moderation:spectate:stop', {})
end

---------------------------------------------------------------------
-- MONEY / ITEMS / INVENTORY
---------------------------------------------------------------------
function AS.Players.GiveMoney(actorSrc, targetSrc, account, amount)
    if not QBCore then return end

    local player = getPlayerFromSource(targetSrc)
    if not player then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    player.Functions.AddMoney(account or 'cash', amount, 'AdminSuite giveMoney')

    Audit.Log(actorSrc, targetSrc, 'moderation:giveMoney', {
        account = account,
        amount  = amount,
    })
end

function AS.Players.TakeMoney(actorSrc, targetSrc, account, amount)
    if not QBCore then return end

    local player = getPlayerFromSource(targetSrc)
    if not player then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    player.Functions.RemoveMoney(account or 'cash', amount, 'AdminSuite takeMoney')

    Audit.Log(actorSrc, targetSrc, 'moderation:takeMoney', {
        account = account,
        amount  = amount,
    })
end

function AS.Players.GiveItem(actorSrc, targetSrc, item, amount)
    if not QBCore then return end

    local player = getPlayerFromSource(targetSrc)
    if not player then return end

    amount = tonumber(amount) or 1
    player.Functions.AddItem(item, amount, false, {}, true)

    Audit.Log(actorSrc, targetSrc, 'moderation:giveItem', {
        item   = item,
        amount = amount,
    })
end

function AS.Players.RemoveItem(actorSrc, targetSrc, item, amount)
    if not QBCore then return end

    local player = getPlayerFromSource(targetSrc)
    if not player then return end

    amount = tonumber(amount) or 1
    player.Functions.RemoveItem(item, amount, false, true)

    Audit.Log(actorSrc, targetSrc, 'moderation:removeItem', {
        item   = item,
        amount = amount,
    })
end

-- Custom AdminSuite inventory snapshot for NUI
function AS.Players.ViewInventory(actorSrc, targetSrc)
    if not QBCore then return end

    local targetPlayer = getPlayerFromSource(targetSrc)
    if not targetPlayer or not targetPlayer.PlayerData then return end

    local playerData = targetPlayer.PlayerData
    -- Support both "items" and "inventory" depending on QBCore version
    local rawItems   = playerData.items or playerData.inventory or {}

    local snapshot = {}

    -- QBCore often stores items as a keyed table by slot; handle both
    for slotKey, item in pairs(rawItems) do
        if item and item.name then
            local entry = {
                slot   = item.slot or tonumber(slotKey) or nil,
                name   = item.name,
                label  = item.label or item.name,
                count  = item.amount or item.count or 0,
                weight = item.weight or (item.info and item.info.weight) or nil,
            }

            -- Optional, concise metadata summary
            if item.info and type(item.info) == 'table' then
                local info = item.info
                local metaSummary = {}

                if info.quality then
                    metaSummary[#metaSummary + 1] = ('Quality: %s'):format(info.quality)
                end
                if info.serial then
                    metaSummary[#metaSummary + 1] = ('Serial: %s'):format(info.serial)
                end
                if info.description then
                    metaSummary[#metaSummary + 1] = tostring(info.description)
                end

                if #metaSummary > 0 then
                    entry.meta = table.concat(metaSummary, ' | ')
                end
            end

            snapshot[#snapshot + 1] = entry
        end
    end

    -- Sort by slot for stable, grid-like display
    table.sort(snapshot, function(a, b)
        return (a.slot or 9999) < (b.slot or 9999)
    end)

    TriggerClientEvent('AdminSuite:moderation:viewInventory', actorSrc, {
        target        = targetSrc,
        targetName    = GetPlayerName(targetSrc),
        targetCitizen = playerData.citizenid,
        items         = snapshot,
    })

    Audit.Log(actorSrc, targetSrc, 'moderation:viewInventory', {
        itemCount = #snapshot,
    })
end

---------------------------------------------------------------------
-- PLAYER LIST / DETAIL (USED BY PLAYER MODERATION + OVERHEAD NAMES)
---------------------------------------------------------------------

-- Helper: extract a nice "Firstname Lastname" from various charinfo formats
local function extractCharacterNameFromPlayer(qbPlayer, src)
    if not qbPlayer or not qbPlayer.PlayerData then
        return nil
    end

    local pd       = qbPlayer.PlayerData
    local charinfo = pd.charinfo or pd.CharInfo or pd.character or {}

    if type(charinfo) ~= "table" then
        return nil
    end

    -- Try a bunch of common key patterns
    local first = charinfo.firstname
        or charinfo.firstName
        or charinfo.first_name
        or charinfo.first
        or charinfo.name
        or ""

    local last = charinfo.lastname
        or charinfo.lastName
        or charinfo.last_name
        or charinfo.last
        or ""

    -- Trim whitespace
    first = tostring(first):gsub("^%s+", ""):gsub("%s+$", "")
    last  = tostring(last):gsub("^%s+", ""):gsub("%s+$", "")

    local full
    if first ~= "" and last ~= "" then
        full = first .. " " .. last
    elseif first ~= "" then
        full = first
    elseif last ~= "" then
        full = last
    else
        full = nil
    end

    if full and full ~= "" then
        return full
    end

    -- Fallback: if some cores store a single name field on charinfo
    if charinfo.fullname or charinfo.FullName then
        full = tostring(charinfo.fullname or charinfo.FullName)
        full = full:gsub("^%s+", ""):gsub("%s+$", "")
        if full ~= "" then
            return full
        end
    end

    return nil
end

function AS.Players.GetPlayersSnapshot()
    local players = {}

    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)

        local platformName = GetPlayerName(src)
        local name         = platformName
        local ping         = GetPlayerPing(src) or 0

        -- Prefer in-game character name from QBCore over platform profile name
        local qbPlayer = nil
        if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
            qbPlayer = QBCore.Functions.GetPlayer(src)
        end

        if qbPlayer then
            local charName = extractCharacterNameFromPlayer(qbPlayer, src)
            if charName and charName ~= "" then
                name = charName
            end
        end

        -- DEBUG: log what we actually ended up using
        if Utils and Utils.Debug then
            Utils.Debug(
                'PlayersSnapshot src=%s hasQBCore=%s platformName="%s" finalName="%s"',
                tostring(src),
                tostring(QBCore ~= nil),
                tostring(platformName or 'nil'),
                tostring(name or 'nil')
            )
        else
            print(('[AdminSuite] PlayersSnapshot src=%s hasQBCore=%s platformName="%s" finalName="%s"'):format(
                tostring(src),
                tostring(QBCore ~= nil),
                tostring(platformName or 'nil'),
                tostring(name or 'nil')
            ))
        end

        -- RBAC visual data
        local roleData, roleName = AS.RBAC.GetRoleData(src)

        -- Pull job / money from QBCore
        local jobLabel = nil
        local bank     = 0
        local cash     = 0

        if qbPlayer and qbPlayer.PlayerData then
            local job   = qbPlayer.PlayerData.job or {}
            local money = qbPlayer.PlayerData.money or {}

            jobLabel = job.label or job.name or nil
            bank     = money["bank"] or 0
            cash     = money["cash"] or 0
        end

        players[#players + 1] = {
            -- multiple aliases so all client helpers can resolve correctly
            id        = src,
            src       = src,
            source    = src,
            serverId  = src,
            playerId  = src,
            playerid  = src,

            name      = name or ("[%s] Unknown"):format(src),
            job       = jobLabel,
            bank      = bank,
            cash      = cash,
            ping      = ping,
            role      = roleName,
            roleLabel = roleData and roleData.label or nil,
            roleColor = roleData and roleData.color or nil,
            isStaff   = RBAC and RBAC.IsStaff and RBAC.IsStaff(src) or false,
        }
    end

    return players
end



function AS.Players.GetPlayerDetail(src)
    src = tonumber(src)
    if not src then return nil end

    local platformName = GetPlayerName(src)
    local name         = platformName
    local ping         = GetPlayerPing(src) or 0
    local roleData, roleName = AS.RBAC.GetRoleData(src)

    local jobLabel = nil
    local bank     = 0
    local cash     = 0

    local qbPlayer = nil
    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        qbPlayer = QBCore.Functions.GetPlayer(src)
    end

    if qbPlayer and qbPlayer.PlayerData then
        local job   = qbPlayer.PlayerData.job or {}
        local money = qbPlayer.PlayerData.money or {}

        jobLabel = job.label or job.name or nil
        bank     = money["bank"] or 0
        cash     = money["cash"] or 0

        local charName = extractCharacterNameFromPlayer(qbPlayer, src)
        if charName and charName ~= "" then
            name = charName
        end
    end

    if not name or name == '' then
        name = platformName or string.format('[%d] Unknown', src)
    end

    return {
        id        = src,
        name      = name,
        job       = jobLabel,
        bank      = bank,
        cash      = cash,
        ping      = ping,
        role      = roleName,
        roleLabel = roleData and roleData.label or nil,
        roleColor = roleData and roleData.color or nil,
        isStaff   = RBAC and RBAC.IsStaff and RBAC.IsStaff(src) or false,
    }
end



---------------------------------------------------------------------
-- PLAYER SETTINGS HELPERS
---------------------------------------------------------------------

-- Returns a payload suitable for the NUI "Manage Player Settings" view.
function AS.Players.GetPlayerSettings(targetSrc)
    if not QBCore then return nil end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return nil end

    local qbPlayer = QBCore.Functions.GetPlayer(targetSrc)
    if not qbPlayer or not qbPlayer.PlayerData then
        return nil
    end

    local pd       = qbPlayer.PlayerData
    local job      = pd.job or {}
    local gang     = pd.gang or {}
    local metadata = pd.metadata or {}

    local whitelisted = false
    if metadata.isWhitelisted ~= nil then
        whitelisted = metadata.isWhitelisted == true
    elseif metadata.whitelisted ~= nil then
        whitelisted = metadata.whitelisted == true
    end

    -- Job grade (support both numeric and table grade formats)
    local jobGrade = 0
    if job.grade ~= nil then
        if type(job.grade) == "table" then
            jobGrade = job.grade.level or job.grade.grade or job.grade_id or 0
        else
            jobGrade = tonumber(job.grade) or 0
        end
    end

    -- Gang grade (same flexibility)
    local gangGrade = 0
    if gang.grade ~= nil then
        if type(gang.grade) == "table" then
            gangGrade = gang.grade.level or gang.grade.grade or gang.grade_id or 0
        else
            gangGrade = tonumber(gang.grade) or 0
        end
    end


    -- Prefer in-game character name from QBCore over platform profile name
    local name = nil

    if QBCore and pd and pd.charinfo then
        local ci    = pd.charinfo
        local first = (ci.firstname or ''):gsub('^%s+', ''):gsub('%s+$', '')
        local last  = (ci.lastname  or ''):gsub('^%s+', ''):gsub('%s+$', '')
        local full  = (first ~= '' or last ~= '')
            and (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
            or nil

        if full and full ~= '' then
            name = full
        end
    end

    if not name or name == '' then
        name = GetPlayerName(targetSrc)
    end

    if not name or name == '' then
        name = string.format('[%d] Unknown', targetSrc)
    end

    -- Current staff role for this player (based on AS.Staff.Mappings)
    local staffRole = nil
    if RBAC and RBAC.GetRole then
        staffRole = RBAC.GetRole(targetSrc)
    end

    local jobsPayload       = buildJobsPayload()
    local gangsPayload      = buildGangsPayload()
    local staffRolesPayload = buildStaffRolesPayload()

    return {
        id          = targetSrc,
        name        = name,

        job         = job.name or '',
        jobLabel    = job.label or job.name or '',
        jobGrade    = jobGrade,

        gang        = gang.name or '',
        gangLabel   = gang.label or gang.name or '',
        gangGrade   = gangGrade,

        whitelisted = whitelisted and true or false,

        -- NEW:
        staffRole   = staffRole,
        jobs        = jobsPayload,
        gangs       = gangsPayload,
        staffRoles  = staffRolesPayload,
    }
end



function AS.Players.SetJob(actorSrc, targetSrc, jobName, grade)
    if not QBCore then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    jobName = tostring(jobName or ''):lower()
    if jobName == '' then return end

    grade = tonumber(grade) or 0

    local qbPlayer = QBCore.Functions.GetPlayer(targetSrc)
    if not qbPlayer then return end

    qbPlayer.Functions.SetJob(jobName, grade)

    if Audit and Audit.Log then
        Audit.Log(actorSrc, targetSrc, 'settings:setJob', {
            job   = jobName,
            grade = grade,
        })
    end
end

function AS.Players.SetGang(actorSrc, targetSrc, gangName, grade)
    if not QBCore then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    gangName = tostring(gangName or ''):lower()
    if gangName == '' then return end

    grade = tonumber(grade) or 0

    local qbPlayer = QBCore.Functions.GetPlayer(targetSrc)
    if not qbPlayer then return end

    if qbPlayer.Functions.SetGang then
        qbPlayer.Functions.SetGang(gangName, grade)
    end

    if Audit and Audit.Log then
        Audit.Log(actorSrc, targetSrc, 'settings:setGang', {
            gang  = gangName,
            grade = grade,
        })
    end
end

function AS.Players.SetWhitelist(actorSrc, targetSrc, whitelisted)
    if not QBCore then return end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local qbPlayer = QBCore.Functions.GetPlayer(targetSrc)
    if not qbPlayer or not qbPlayer.PlayerData then return end

    local flag = whitelisted and true or false

    if qbPlayer.Functions.SetMetaData then
        qbPlayer.Functions.SetMetaData('isWhitelisted', flag)
    else
        qbPlayer.PlayerData.metadata = qbPlayer.PlayerData.metadata or {}
        qbPlayer.PlayerData.metadata.isWhitelisted = flag
    end

    if Audit and Audit.Log then
        Audit.Log(actorSrc, targetSrc, 'settings:setWhitelist', {
            whitelisted = flag,
        })
    end
end
