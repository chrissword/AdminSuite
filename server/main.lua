AS = AS or {}

local Config     = AS.Config or Config
local Migrations = AS.Migrations
local Events     = AS.Events
local Utils      = AS.Utils
local RBAC       = AS.RBAC
local Reports    = AS.Reports
local Audit      = AS.Audit

local function info(msg, ...)
    if Utils and Utils.Info then
        Utils.Info(msg, ...)
    else
        print(('[AdminSuite] ' .. msg):format(...))
    end
end

local function warn(msg, ...)
    if Utils and Utils.Warn then
        Utils.Warn(msg, ...)
    else
        print(('[AdminSuite:WARN] ' .. msg):format(...))
    end
end

--=====================================================
--  MIGRATIONS
--=====================================================

local function runMigrations()
    if not Migrations or not Migrations.RunAll then
        info('Migrations module missing or incomplete.')
        return
    end

    Migrations.RunAll()
end

--=====================================================
--  RBAC HELPERS
--=====================================================

local function getRoleName(src)
    if not RBAC or not RBAC.GetRoleData or not src then return nil end
    local _, roleName = RBAC.GetRoleData(src)
    return roleName
end

local function canViewRecentActions(src)
    local roleName = getRoleName(src)
    return roleName == 'god'
end

local function canClearRecentActions(src)
    local roleName = getRoleName(src)
    return roleName == 'god'
end

--=====================================================
--  DASHBOARD SUMMARY
--=====================================================

---@param src? number
---@return table
local function buildDashboardSummary(src)
    local playerIds = GetPlayers() or {}

    -- Total players / max players
    local playersCount = #playerIds
    local maxPlayers   = GetConvarInt('sv_maxclients', 64)

    -- Online staff = players that RBAC recognizes with a role
    local staffOnline = 0
    if RBAC and RBAC.GetRoleData then
        for _, id in ipairs(playerIds) do
            local psrc = tonumber(id) or id
            local _, roleName = RBAC.GetRoleData(psrc)
            if roleName ~= nil then
                staffOnline = staffOnline + 1
            end
        end
    end

    -- Open reports
    local openReports = 0
    if Reports and Reports.GetOpen then
        local rows = Reports.GetOpen()
        if type(rows) == 'table' then
            openReports = #rows
        end
    end

    -- RBAC flags for the *caller*
    local canViewRecent  = canViewRecentActions(src)
    local canClearRecent = canClearRecentActions(src)

    -- Recent audit entries (for dashboard Recent Actions card)
    local recentAudit = nil
    if canViewRecent and Audit and Audit.GetEntries then
        recentAudit = Audit.GetEntries(10)
    end

    if Utils and Utils.Debug then
        Utils.Debug(
            '[Dashboard] Summary: players=%d max=%d staff=%d openReports=%d canViewRecent=%s canClearRecent=%s recentAudit=%d',
            playersCount or 0,
            maxPlayers or 0,
            staffOnline or 0,
            openReports or 0,
            tostring(canViewRecent),
            tostring(canClearRecent),
            recentAudit and #recentAudit or 0
        )
    end

    return {
        players               = playersCount,
        maxPlayers            = maxPlayers,
        staffOnline           = staffOnline,
        openReports           = openReports,
        recentAudit           = recentAudit,      -- only populated for god/admin
        canViewRecentActions  = canViewRecent,    -- NUI uses this to hide/show card
        canClearRecentActions = canClearRecent,   -- NUI uses this to hide/show button
    }
end

--=====================================================
--  BOOTSTRAP
--=====================================================

local function onResourceStart(resourceName)
    local this = GetCurrentResourceName()
    if resourceName ~= this then return end

    info('Starting AdminSuite for resource %s', this)

    -- Run DB migrations
    runMigrations()

    info('AdminSuite server core ready.')
end

AddEventHandler('onResourceStart', onResourceStart)

--=====================================================
--  CORE EVENTS
--=====================================================

if Events and Events.Core then
    -- Init handshake
    if Events.Core.Init then
        RegisterNetEvent(Events.Core.Init, function()
            local src = source
            local roleData, roleName = nil, nil

            if RBAC and RBAC.GetRoleData then
                roleData, roleName = RBAC.GetRoleData(src)
            end

            local payload = {
                version    = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0',
                serverName = Config and Config.Branding and Config.Branding.ServerName or 'AdminSuite',
                darkMode   = Config and Config.Theme and Config.Theme.DefaultDarkMode == 1,
                role       = roleName,
                roleLabel  = roleData and roleData.label or nil,
                roleColor  = roleData and roleData.color or nil,
            }

            -- Push core payload to client
            TriggerClientEvent(Events.Core.Init, src, payload)

            -- Optionally push an initial summary on init if dashboard module is present
            if Events.Dashboard and Events.Dashboard.UpdateSummary then
                local summary = buildDashboardSummary(src)
                TriggerClientEvent(Events.Dashboard.UpdateSummary, src, summary)
            end
        end)
    end

    -- Core state sync; includes dashboard summary
    if Events.Core.SyncState then
        RegisterNetEvent(Events.Core.SyncState, function()
            local src = source
            local summary = buildDashboardSummary(src)

            -- Feed into dashboard pipeline if available
            if Events.Dashboard and Events.Dashboard.UpdateSummary then
                TriggerClientEvent(Events.Dashboard.UpdateSummary, src, summary)
            end

            -- Generic sync payload (can be extended later)
            TriggerClientEvent(Events.Core.SyncState, src, {
                summary = summary,
            })
        end)
    end
end

--=====================================================
--  DASHBOARD EVENTS
--=====================================================

-- Dedicated dashboard summary request (for NUI -> Lua -> server)
if Events and Events.Dashboard and Events.Dashboard.GetSummary and Events.Dashboard.UpdateSummary then
    RegisterNetEvent(Events.Dashboard.GetSummary, function()
        local src = source
        local summary = buildDashboardSummary(src)
        TriggerClientEvent(Events.Dashboard.UpdateSummary, src, summary)
    end)
end

-- Clear "Recent Actions" – only 'god' is allowed
if Events and Events.Dashboard and Events.Dashboard.ClearRecent then
    RegisterNetEvent(Events.Dashboard.ClearRecent, function()
        local src = source

        if not canClearRecentActions(src) then
            warn('Player %s attempted to clear recent actions without permission.', tostring(src))
            return
        end

        if Audit and Audit.ClearRecent then
            Audit.ClearRecent()
        else
            warn('Audit.ClearRecent() is not defined; cannot clear recent actions.')
            return
        end

        -- After clearing, send the updated (empty) summary back
        local summary = buildDashboardSummary(src)
        if Events.Dashboard.UpdateSummary then
            TriggerClientEvent(Events.Dashboard.UpdateSummary, src, summary)
        end
    end)
end
