AS       = AS or {}
AS.Events = {}

--=====================================================
--  CORE
--=====================================================

AS.Events.Core = {
    Init         = 'as:core:init',
    SyncState    = 'as:core:syncState',
    SetTheme     = 'as:core:setTheme',
    SetDarkMode  = 'as:core:setDarkMode',
    TogglePanel  = 'as:core:togglePanel',

    -- Self-utilities / per-admin toggles
    ToggleNoclip = 'as:core:toggleNoclip',
    ToggleNames  = 'as:core:toggleNames',
    ToggleIds    = 'as:core:toggleIds',
}

--=====================================================
--  RBAC
--=====================================================

AS.Events.RBAC = {
    GetSelf      = 'as:rbac:getSelf',
    RefreshRoles = 'as:rbac:refreshRoles',
}

--=====================================================
--  DASHBOARD
--=====================================================

AS.Events.Dashboard = {
    GetSummary        = 'as:dashboard:getSummary',
    UpdateSummary     = 'as:dashboard:updateSummary',
    ClearRecent       = 'as:dash:clearRecent',

    -- Quick actions (Self / Dev / Management)
    RunSelfUtility    = 'as:dashboard:runSelfUtility',
    RunDeveloperTool  = 'as:dashboard:runDeveloperTool',
    RunManagementTool = 'as:dashboard:runManagementTool',
}

--=====================================================
--  VEHICLE TOOLS (DASHBOARD QUICK ACTIONS)
--=====================================================

AS.Events.VehicleTools = {
    -- Quick Actions / tools
    Spawn        = 'as:vehicle:spawn',
    Repair       = 'as:vehicle:repair',
    Wash         = 'as:vehicle:wash',
    Refuel       = 'as:vehicle:refuel',

    -- Quick-action delete (temporary; does NOT touch DB/ownership)
    DeleteTemp   = 'as:vehicle:deleteTemp',

    -- Seat helpers
    SeatIn       = 'as:vehicle:seatIn',
    SeatOut      = 'as:vehicle:seatOut',

    -- Future richer vehicle tools / vehicles view
    Customize    = 'as:vehicle:customize',
    AddOwned     = 'as:vehicle:addOwned',
    DeleteOwned  = 'as:vehicle:deleteOwned',
}

--=====================================================
--  ADMIN CHAT
--=====================================================

AS.Events.AdminChat = {
    SendMessage     = 'as:adminchat:sendMessage',
    Broadcast       = 'as:adminchat:broadcastMessage',
    GetHistory      = 'as:adminchat:getHistory',
    HistoryUpdated  = 'as:adminchat:historyUpdated',
    Purge           = 'as:adminchat:purge',
}

--=====================================================
--  MODERATION
--=====================================================

AS.Events.Moderation = {
    GetPlayers       = 'as:moderation:getPlayers',
    GetPlayerDetail  = 'as:moderation:getPlayerDetail',

    -- Banned players list
    GetBans          = 'as:moderation:getBans',

    Kick             = 'as:moderation:kick',
    Warn             = 'as:moderation:warn',
    Ban              = 'as:moderation:ban',
    Unban            = 'as:moderation:unban',

    Heal             = 'as:moderation:heal',
    Revive           = 'as:moderation:revive',

    Freeze           = 'as:moderation:freeze',
    Unfreeze         = 'as:moderation:unfreeze',

    Bring            = 'as:moderation:bring',
    Goto             = 'as:moderation:goto',
    SendBack         = 'as:moderation:sendBack',

    SpectateStart    = 'as:moderation:spectate:start',
    SpectateStop     = 'as:moderation:spectate:stop',

    Message          = 'as:moderation:message',

    GiveItem         = 'as:moderation:giveItem',
    RemoveItem       = 'as:moderation:removeItem',

    GiveMoney        = 'as:moderation:giveMoney',
    TakeMoney        = 'as:moderation:takeMoney',

    ViewInventory    = 'as:moderation:viewInventory',
}

--=====================================================
--  SETTINGS / PLAYER SETTINGS
--=====================================================

AS.Events.Settings = {
    GetPlayerSettings = 'as:settings:getPlayerSettings',
    SetJob            = 'as:settings:setJob',
    SetGang           = 'as:settings:setGang',

    -- Previously SetWhitelist (now used for staff role + legacy whitelist)
    SetStaffRole      = 'as:settings:setStaffRole',
    ClearStaffRole    = 'as:settings:clearStaffRole',

    OpenClothing      = 'as:settings:openClothing',
    SaveClothing      = 'as:settings:saveClothing',
}

--=====================================================
--  VEHICLES VIEW
--=====================================================

AS.Events.Vehicles = {
    GetList     = 'as:vehicles:getList',
    RefreshList = 'as:vehicles:refreshList',
}

--=====================================================
--  RESOURCES VIEW
--===================================================== 

AS.Events.Resources = {
    -- Server-side events
    GetList = 'as:resources:getList',      -- legacy / alias (if anything still uses it)
    Refresh = 'as:resources:refresh',      -- server -> client: push updated list

    -- Client -> server
    Request = 'as:resources:request',      -- client -> server: ask for list
    Action  = 'as:resources:action',       -- client -> server: start/stop/restart
}

--=====================================================
--  ITEMS VIEW
--=====================================================

AS.Events.Items = {
    GetList     = 'as:items:getList',
    RefreshList = 'as:items:refreshList',
}


--=====================================================
--  WORLD CONTROLS (GLOBAL / MANAGEMENT)
--=====================================================

AS.Events.World = {
    GetState    = 'as:world:getState',
    SetTime     = 'as:world:setTime',
    SetWeather  = 'as:world:setWeather',
    FreezeTime  = 'as:world:freezeTime',

    -- Global toggles (Management → Toggle IDs / Names / Blips / Radar)
    ToggleRadar = 'as:world:toggleRadar',
    ToggleBlips = 'as:world:toggleBlips',
    ToggleNames = 'as:world:toggleNames',
    ToggleIds   = 'as:world:toggleIds',

    GetPlayers  = 'as:world:getPlayers',
}

--=====================================================
--  REPORTS
--=====================================================

AS.Events.Reports = {
    Submit        = 'as:reports:submit',
    GetOpen       = 'as:reports:getOpen',
    GetMine       = 'as:reports:getMine',
    GetAll        = 'as:reports:getAll',
    Claimed       = 'as:reports:claimed',
    Claim         = 'as:reports:claim',
    Unclaim       = 'as:reports:unclaim',
    Close         = 'as:reports:close',
    Reopen        = 'as:reports:reopen',
    UpdateStatus  = 'as:reports:updateStatus',
}

--=====================================================
--  GOOGLE DOCS
--=====================================================

AS.Events.Docs = {
    List              = 'as:docs:list',
    Open              = 'as:docs:open',
    Close             = 'as:docs:close',
    RequestEdit       = 'as:docs:requestEdit',
    UpdatePermissions = 'as:docs:updatePermissions',
    Refresh           = 'as:docs:refresh',
    AuditEvent        = 'as:docs:auditEvent',
}

--=====================================================
--  AUDIT & PERSISTENCE
--=====================================================

AS.Events.Audit = {
    GetEntries = 'as:audit:getEntries',
    Append     = 'as:audit:append',
}

AS.Events.Persistence = {
    Flush  = 'as:persistence:flush',
    Reload = 'as:persistence:reload',
}

--=====================================================
--  NUI EVENTS (LUA ↔ JS)
--=====================================================

AS.Events.NUI = {

    -- in AS.Events.NUI
    AuditGetEntries = 'as:nui:audit:getEntries',
    AuditEntries    = 'as:nui:audit:entries',

    -- Panel / Shell
    PanelReady        = 'as:nui:panel:ready',
    PanelOpen         = 'as:nui:panel:open',
    PanelClose        = 'as:nui:panel:close',
    PanelNavigate     = 'as:nui:panel:navigate',
    PanelSetTheme     = 'as:nui:panel:setTheme',
    PanelSetDarkMode  = 'as:nui:panel:setDarkMode',

    -- Dashboard
    DashboardGetSummary     = 'as:nui:dashboard:getSummary',
    DashboardUpdateSummary  = 'as:nui:dashboard:updateSummary',
    DashboardRunQuickAction = 'as:nui:dashboard:runQuickAction',
    DashboardRecent         = 'as:nui:dashboard:recent',
    DashboardClearRecent    = 'as:nui:dashboard:clearRecent',

    -- Admin Chat
    AdminChatSendMessage    = 'as:nui:adminchat:sendMessage',
    AdminChatReceiveMessage = 'as:nui:adminchat:receiveMessage',
    AdminChatLoadHistory    = 'as:nui:adminchat:loadHistory',
    AdminChatPurge          = 'as:nui:adminchat:purge',

    -- Moderation
    ModerationLoadPlayers   = 'as:nui:moderation:loadPlayers',
    ModerationSelectPlayer  = 'as:nui:moderation:selectPlayer',
    ModerationRefreshPlayer = 'as:nui:moderation:refreshPlayer',
    ModerationExecuteAction = 'as:nui:moderation:executeAction',

    -- Banned Players (NUI ↔ Lua)
    BannedPlayersLoad       = 'as:nui:bannedplayers:load',
    BannedPlayersSelect     = 'as:nui:bannedplayers:select',
    BannedPlayersUnban      = 'as:nui:bannedplayers:unban',

    -- Settings
    SettingsLoad            = 'as:nui:settings:load',
    SettingsSaveJob         = 'as:nui:settings:saveJob',
    SettingsSaveGang        = 'as:nui:settings:saveGang',
    SettingsSaveStaffRole   = 'as:nui:settings:saveStaffRole',
    SettingsRemoveAdmin     = 'as:nui:settings:removeAdmin',
    SettingsOpenClothing    = 'as:nui:settings:openClothing',
    SettingsSaveClothing    = 'as:nui:settings:saveClothing',
    RBACUpdate              = 'as:nui:rbac:update',

    -- Vehicles
    VehiclesLoad            = 'as:nui:vehicles:load',
    VehiclesRefresh         = 'as:nui:vehicles:refresh',
    VehiclesSpawn           = 'as:nui:vehicles:spawn',

    -- Resources
    ResourcesLoad           = 'as:nui:resources:load',
    ResourcesRefresh        = 'as:nui:resources:refresh',
    ResourcesAction         = 'as:nui:resources:action',

    -- World (client-side reflection of global world state)
    WorldLoadState          = 'as:nui:world:loadState',
    WorldApplyTime          = 'as:nui:world:applyTime',
    WorldApplyWeather       = 'as:nui:world:applyWeather',
    WorldToggleRadar        = 'as:nui:world:toggleRadar',
    WorldToggleBlips        = 'as:nui:world:toggleBlips',
    WorldToggleNames        = 'as:nui:world:toggleNames',
    WorldToggleIds          = 'as:nui:world:toggleIds',

    -- Reports
    ReportsSubmit           = 'as:nui:reports:submit',
    ReportsLoadOpen         = 'as:nui:reports:loadOpen',
    ReportsLoadMine         = 'as:nui:reports:loadMine',
    ReportsLoadAll          = 'as:nui:reports:loadAll',
    ReportsClaim            = 'as:nui:reports:claim',
    ReportsUnclaim          = 'as:nui:reports:unclaim',
    ReportsClose            = 'as:nui:reports:close',
    ReportsReopen           = 'as:nui:reports:reopen',
    ReportsUpdateStatus     = 'as:nui:reports:updateStatus',

    -- Docs
    DocsList                = 'as:nui:docs:list',
    DocsOpen                = 'as:nui:docs:open',
    DocsClose               = 'as:nui:docs:close',
    DocsRequestEdit         = 'as:nui:docs:requestEdit',
    DocsRefresh             = 'as:nui:docs:refresh',
}

AS.Events.Discipline = {
    Add    = "as:discipline:add",
    Update = "as:discipline:update",
    Delete = "as:discipline:delete",
}
