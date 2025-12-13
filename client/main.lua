AS = AS or {}

local Events = AS.Events
local Utils  = AS.ClientUtils
local NUI    = AS.NUI
local RBAC   = AS.ClientRBAC or {}
local Theme  = AS.Theme or {}

--===================================
-- Core init response from server
--===================================

if Events and Events.Core then
    RegisterNetEvent(Events.Core.Init, function(payload)
        Utils.Debug('Core init received: %s', json.encode(payload or {}))

        -- Derive theme mode + tokens for NUI (styling only)
        local darkMode = payload.darkMode
        local mode     = darkMode and 'dark' or 'light'

        local themeTokens = nil
        if Theme and Theme.GetTokens then
            themeTokens = Theme.GetTokens(mode)
        end

-- Push core branding / theme info to NUI using a dedicated event,
-- instead of abusing the dashboard:getSummary name.
AS.ClientUtils.SendNUI('as:nui:core:init', {
    version    = payload.version,
    serverName = payload.serverName,
    darkMode   = darkMode,
    role       = payload.role,
    roleLabel  = payload.roleLabel,
    roleColor  = payload.roleColor,
    theme      = themeTokens,
})


        -- Request RBAC details (server/rbac.lua will reply)
        if Events.RBAC and Events.RBAC.GetSelf then
            TriggerServerEvent(Events.RBAC.GetSelf)
        end
    end)

RegisterNetEvent(Events.Core.SyncState, function(state)
    state = state or {}

    -- Server sends: { summary = { players, maxPlayers, staffOnline, openReports } }
    local summary = state.summary or state

    Utils.Debug('Core sync state received: %s', json.encode(summary or {}))

    AS.ClientUtils.SendNUI(
        AS.Events.NUI.DashboardUpdateSummary or 'as:nui:dashboard:updateSummary',
        summary or {}
    )
end)


end

--===================================
-- Helpers
--===================================

local function canOpenPanel()
    -- If client RBAC helper isn't present, be safe and deny.
    if not RBAC or not RBAC.GetSelf then
        if Events and Events.RBAC and Events.RBAC.GetSelf then
            -- Ask server for RBAC so next attempt has data
            TriggerServerEvent(Events.RBAC.GetSelf)
        end

        Utils.Debug('RBAC not yet loaded; denying panel open.')
        return false
    end

    local self = RBAC.GetSelf()
    if not self or not self.role then
        Utils.Debug('RBAC denies panel open: no role assigned.')
        return false
    end

    return true
end

--===================================
-- Key mapping & commands
--===================================

local toggleKey = (AS.Config and AS.Config.Keys and AS.Config.Keys.TogglePanel) or '0'

RegisterCommand('as_panel', function()
    if not canOpenPanel() then
        if Utils and Utils.Notify then
            Utils.Notify('You are not authorized to open the AdminSuite panel.')
        else
            print('[AdminSuite] You are not authorized to open the AdminSuite panel.')
        end
        return
    end

    NUI.Toggle()
end, false)




-- Register key mapping for AdminSuite panel
RegisterKeyMapping('as_panel', 'Toggle AdminSuite Panel', 'keyboard', toggleKey)

--===================================
-- Initial RBAC bootstrap
--===================================

CreateThread(function()
    -- Give the resource a moment to fully initialize, then
    -- ask the server for our RBAC data so it is ready when
    -- the player first tries to open the panel.
    Wait(2000)

    if Events and Events.RBAC and Events.RBAC.GetSelf then
        Utils.Debug('Requesting initial RBAC self from server...')
        TriggerServerEvent(Events.RBAC.GetSelf)
    end
end)
